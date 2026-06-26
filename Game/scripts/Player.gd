class_name Player
extends Node3D

var cx: int = GridUtil.COLS / 2 + 1
var cz: int = 0

var _hopping := false
var _move_token := 0
var _model: Node3D       # pivot 노드 (hop/squash/회전 대상). 안쪽에 fit된 영웅 glb.
var _anim: AnimationPlayer

# Godot forward(local -Z)를 이동 방향으로 돌리기 위한 보정각(+180°).
const MODEL_YAW_OFFSET: float = PI
const HERO_HEIGHT := 1.3            # 1타일보다 살짝 큰 영웅 키(Test Ch ≈1.24와 유사)
const FALLBACK_GLB := "res://scripts/Test Ch.glb"

func _ready() -> void:
	_build_visual()
	position = GridUtil.cell_to_world(cx, cz, 0.0)

func _build_visual() -> void:
	# 활성 영웅(HeroRoster) glb를 CharacterMesh로 자동 fit. 없으면 Test Ch로 폴백.
	var hero = HeroRoster.active_hero()
	var built := CharacterMesh.build(hero.glb, HERO_HEIGHT)
	if built.is_empty():
		built = CharacterMesh.build(FALLBACK_GLB, HERO_HEIGHT)
	if built.is_empty():
		_model = Node3D.new()  # 최후 폴백: 빈 pivot (게임 로직은 유지).
		add_child(_model)
		return
	_model = built["pivot"]
	add_child(_model)
	_anim = built.get("anim")

func _process(_delta: float) -> void:
	if _hopping:
		return
	# 누르고 있으면 hop 완료 후 다음 프레임에 연속 hop
	if Input.is_action_pressed("move_up"):
		try_hop(0, 1)
	elif Input.is_action_pressed("move_down"):
		try_hop(0, -1)
	elif Input.is_action_pressed("move_left"):
		try_hop(1, 0)
	elif Input.is_action_pressed("move_right"):
		try_hop(-1, 0)

func try_hop(dx: int, dz: int) -> void:
	if _hopping:
		return
	_face_direction(dx, dz)  # 경계에 막혀도 누른 방향은 바라본다
	var nx := GridUtil.clamp_col(cx + dx)
	var nz := GridUtil.clamp_row(cz + dz)
	if nx == cx and nz == cz:
		return  # 경계에 막힘
	cx = nx
	cz = nz
	_hopping = true
	_move_token += 1
	var move_token := _move_token
	var target := GridUtil.cell_to_world(cx, cz, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		if move_token == _move_token:
			_hopping = false
	)
	_hop_arc()

func _hop_arc() -> void:
	# Crossy Road식 깡총 점프 + 착지 스쿼시 (모델 로컬 변형만, 그리드 로직과 무관).
	var arc := create_tween()
	arc.tween_property(_model, "position:y", 0.35, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(_model, "position:y", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var base := Vector3.ONE
	var squash := create_tween()
	squash.tween_property(_model, "scale", base * Vector3(0.85, 1.2, 0.85), 0.06)
	squash.tween_property(_model, "scale", base * Vector3(1.12, 0.82, 1.12), 0.05)
	squash.tween_property(_model, "scale", base, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _face_direction(dx: int, dz: int) -> void:
	var yaw := atan2(dx, dz) + MODEL_YAW_OFFSET
	_model.rotation = Vector3(0, yaw, 0)

func is_hopping() -> bool:
	return _hopping

# 통나무에 실려 x축으로 떠내려감 (hop 중이 아닐 때만). 논리 셀 cx도 함께 갱신.
func ride(dx_world: float) -> void:
	if _hopping:
		return
	position.x += dx_world
	cx = GridUtil.clamp_col(roundi(position.x / GridUtil.TILE_SIZE))

# 익사 → 안전한 셀로 첨벙 복귀. 진행 중 hop/탑승을 무효화한다.
func splash_reset(ncx: int, ncz: int) -> void:
	cx = GridUtil.clamp_col(ncx)
	cz = GridUtil.clamp_row(ncz)
	_move_token += 1
	_hopping = true
	var move_token := _move_token
	var target := GridUtil.cell_to_world(cx, cz, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		if move_token == _move_token:
			_hopping = false
	)
	# 첨벙 스쿼시 피드백.
	var base := Vector3.ONE
	var sp := create_tween()
	sp.tween_property(_model, "scale", base * Vector3(1.3, 0.6, 1.3), 0.08)
	sp.tween_property(_model, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func knockback(away_dir: Vector3) -> void:
	if away_dir.length_squared() < 0.0001:
		return
	var base_pos := GridUtil.cell_to_world(cx, cz, 0.0)
	var pushed := base_pos + away_dir.normalized() * GridUtil.TILE_SIZE
	var cell := GridUtil.world_to_cell(pushed)
	cx = GridUtil.clamp_col(cell.x)
	cz = GridUtil.clamp_row(cell.y)
	_hopping = true
	_move_token += 1
	var move_token := _move_token
	var target := GridUtil.cell_to_world(cx, cz, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		if move_token == _move_token:
			_hopping = false
	)
