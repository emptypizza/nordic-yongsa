class_name Player
extends Node3D

var cx: int = GridUtil.COLS / 2 + 1
var cz: int = 0

var _hopping := false
var _move_token := 0
var _model: Node3D       # pivot 노드 (hop/squash/회전 대상). 안쪽에 빌보드 스프라이트 또는 영웅 glb.
var _anim: AnimationPlayer
var _sprite: Sprite3D    # 4방향 빌보드 주인공(있으면 glb 대신 사용)
var _dir_tex := {}       # "front"/"back"/"left"/"right" -> Texture2D

# Godot forward(local -Z)를 이동 방향으로 돌리기 위한 보정각(+180°).
const MODEL_YAW_OFFSET: float = PI
const HERO_HEIGHT := 1.3            # 1타일보다 살짝 큰 영웅 키(Test Ch ≈1.24와 유사)
const FALLBACK_GLB := "res://scripts/Test Ch.glb"
# 주인공은 흰머리(mokup 레퍼런스의 흰머리 검사). Warrior glb의 머리카락 파츠(이름 ha*/hha*)만 흰색으로.
const HAIR_COLOR := Color(0.93, 0.94, 0.97)
const HAIR_PREFIXES := ["hha", "ha"]
# 주인공 = 흰머리 기사(파란 망토·검, 레퍼런스 아트). 4방향 빌보드 스프라이트로 렌더한다.
# Game/build/ 레퍼런스 영상에서 정면/뒷면/좌측 프레임 추출 → 배경 제거 → 공통 높이(440px) 정규화,
# 우측은 좌측 좌우반전. 네 텍스처가 모두 같은 픽셀 높이라 교체해도 월드 스케일·접지가 일정하다.
const KNIGHT_HEIGHT := 1.6
const KNIGHT_TEX := {
	"front": "res://scripts/gen/hero/knight_front.png",
	"back": "res://scripts/gen/hero/knight_back.png",
	"left": "res://scripts/gen/hero/knight_left.png",
	"right": "res://scripts/gen/hero/knight_right.png",
}

func _ready() -> void:
	_build_visual()
	position = GridUtil.cell_to_world(cx, cz, 0.0)

func _build_visual() -> void:
	# 1순위: 흰머리 기사 4방향 빌보드 스프라이트(레퍼런스 아트). 실패 시 영웅 glb로 폴백.
	var spr := CharacterMesh.build_billboard(KNIGHT_TEX["front"], KNIGHT_HEIGHT)
	if spr != null:
		_dir_tex.clear()
		for d in KNIGHT_TEX.keys():
			if ResourceLoader.exists(KNIGHT_TEX[d]):
				_dir_tex[d] = load(KNIGHT_TEX[d])
		_sprite = spr
		var pivot := Node3D.new()
		pivot.add_child(spr)
		_model = pivot
		add_child(_model)
		_anim = null
		return
	# 폴백: 활성 영웅(HeroRoster) glb를 CharacterMesh로 자동 fit. 없으면 Test Ch로 폴백.
	_sprite = null
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
	# 머리카락 파츠만 골라 흰색으로(glb 폴백 시).
	var model = built.get("model")
	if model != null:
		CharacterMesh.recolor_parts(model, HAIR_PREFIXES, HAIR_COLOR)

# 활성 영웅이 바뀌면 메시만 교체(그리드 셀·hop 상태는 유지).
func rebuild_visual() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	_anim = null
	_sprite = null
	_build_visual()

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
	AudioManager.sfx("hop", 0.06)
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
	if _sprite != null:
		# 빌보드는 항상 카메라를 향하므로, 회전 대신 이동 방향에 맞는 텍스처로 교체한다.
		var key := ""
		if dz > 0:
			key = "back"    # 위로(카메라 반대) = 뒷모습
		elif dz < 0:
			key = "front"   # 아래로(카메라 쪽) = 정면
		elif dx > 0:
			key = "left"    # move_left → 좌측 3/4
		elif dx < 0:
			key = "right"   # move_right → 우측(좌측 반전)
		if key != "" and _dir_tex.has(key):
			_sprite.texture = _dir_tex[key]
		return
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
