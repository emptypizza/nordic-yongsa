class_name Enemy
extends Node3D

var speed: float = 1.6
var hp: int = 0
var stun: float = 0.0

var _grail: Grail
var _visual: Node3D          # 흔들림/회전 대상 (glb pivot · 박스 · 스프라이트)
var _model: Node3D           # glb 모드일 때 pivot(=_visual). 이동 방향 facing 대상.
var _anim: AnimationPlayer   # glb 모드일 때만
var _mesh: MeshInstance3D    # 프리미티브 모드일 때만
var _sprite: Sprite3D        # sprite-forge 생성 시트가 있을 때만
var _anim_t: float = 0.0
var _cell: Vector2i
var _target_pos: Vector3
var _has_target := false

# 적 메시: 일반 몬스터(잡몹)=고블린 스프라이트(sprite-forge), 강한 적=Boogeyman glb(크고 느림).
# 둘 다 없으면 프리미티브 박스로 폴백. (Crow glb는 GameManager에서 마차 호위 동료로 사용)
const ENEMY_STRONG_GLB := "res://scripts/glbs/Boogeyman 01.glb"
const STRONG_HEIGHT := 1.6
const MODEL_YAW_OFFSET := PI

# generate2dsprite 파이프라인으로 만든 일반 몬스터 스프라이트 시트들(2x2 idle 빌보드).
# 존재하는 것 중 하나를 랜덤으로 골라 써서 잡몹 종류에 변화를 준다. 하나도 없으면 프리미티브 폴백.
# 생성: 마젠타 raw(make_*.py) → venv `generate2dsprite.py process` → 각 폴더 sheet-transparent.png.
const GEN_SHEETS := [
	"res://scripts/gen/goblin/sheet-transparent.png",
	"res://scripts/gen/slime/sheet-transparent.png",
	"res://scripts/gen/skeleton/sheet-transparent.png",
	"res://scripts/gen/bat/sheet-transparent.png",
]
const GEN_COLS := 2
const GEN_ROWS := 2

func init(grail: Grail, start_cell: Vector2i, hp_val: int) -> void:
	_grail = grail
	_cell = start_cell
	hp = hp_val

func _ready() -> void:
	_build_visual()
	position = GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	_pick_next_target()

func _build_visual() -> void:
	var is_strong := hp >= 2
	speed = 1.4 if is_strong else 1.6
	# 강한 적만 Boogeyman 3D 메시. 일반 몬스터는 고블린 스프라이트로.
	if is_strong and _build_glb():
		return
	if _build_sprite(is_strong):
		return
	_build_primitive(is_strong)

func _build_glb() -> bool:
	var built := CharacterMesh.build(ENEMY_STRONG_GLB, STRONG_HEIGHT, ["Idle", "Idle01", "Idle02"])
	if built.is_empty():
		return false
	_model = built["pivot"]
	_visual = _model
	_anim = built.get("anim")
	# 강한 적은 늘 성배를 향해 묵직하게 전진 → Walk 루프.
	if _anim != null:
		CharacterMesh.play_loop(_anim, ["Walk01", "Chase01", "Run01", "Idle"])
	add_child(_model)
	return true

func _build_sprite(is_strong: bool) -> bool:
	var avail: Array = []
	for p in GEN_SHEETS:
		if ResourceLoader.exists(p):
			avail.append(p)
	if avail.is_empty():
		return false
	var tex: Texture2D = load(avail[randi() % avail.size()])
	if tex == null:
		return false
	_sprite = Sprite3D.new()
	_sprite.texture = tex
	_sprite.hframes = GEN_COLS
	_sprite.vframes = GEN_ROWS
	_sprite.frame = 0
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.transparent = true
	# 한 프레임이 대략 1타일 높이가 되도록(시트 생성 후 미세 조정 가능).
	var frame_px: float = float(tex.get_height()) / float(GEN_ROWS)
	_sprite.pixel_size = (1.3 if is_strong else 1.0) / maxf(frame_px, 1.0)
	_sprite.position = Vector3(0, 0.55, 0)
	add_child(_sprite)
	_visual = _sprite
	return true

func _build_primitive(is_strong: bool) -> void:
	var body_size: float = 0.9 if is_strong else 0.6

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(body_size, body_size, body_size)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.12, 0.45) if is_strong else Color(0.5, 0.1, 0.1)
	_mesh.material_override = mat
	add_child(_mesh)
	_visual = _mesh

	var eye_offset: float = 0.23 if is_strong else 0.15
	var eye_y: float = 0.16 if is_strong else 0.1
	var eye_z := body_size * 0.5 + 0.01
	var eye_size := Vector3(0.14, 0.14, 0.06) if is_strong else Vector3(0.1, 0.1, 0.05)

	for ex in [-eye_offset, eye_offset]:
		var eye := MeshInstance3D.new()
		var ebox := BoxMesh.new()
		ebox.size = eye_size
		eye.mesh = ebox
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color.WHITE
		eye.material_override = emat
		eye.position = Vector3(ex, eye_y, eye_z)
		_mesh.add_child(eye)  # 몸통의 자식 → 기절 흔들림(_mesh 회전)에 눈도 함께 돈다

func _pick_next_target() -> void:
	var grail_cell := Vector2i(_grail.cx, _grail.get_cz())
	var step := GridUtil.step_toward(_cell, grail_cell)
	if step == Vector2i.ZERO:
		_has_target = false
		return
	_cell += step
	_target_pos = GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	_has_target = true

func _process(delta: float) -> void:
	# 스프라이트 모드면 idle 프레임 순환.
	if _sprite != null:
		_anim_t += delta
		_sprite.frame = int(_anim_t * 5.0) % (GEN_COLS * GEN_ROWS)

	if stun > 0.0:
		stun -= delta
		if _visual != null:
			_visual.rotation = Vector3(0, randf() * 0.5, 0)  # 기절 흔들림
		return

	if not _has_target:
		_pick_next_target()

	# glb 모드: 이동 방향을 바라본다. 프리미티브/스프라이트: 기절 흔들림만 리셋.
	if _model != null:
		var to := _target_pos - position
		if Vector2(to.x, to.z).length_squared() > 0.000001:
			_model.rotation.y = atan2(to.x, to.z) + MODEL_YAW_OFFSET
	elif _visual != null:
		_visual.rotation = Vector3.ZERO

	if not _has_target:
		return

	position = position.move_toward(_target_pos, speed * delta)
	if position.distance_to(_target_pos) < 0.01:
		_pick_next_target()

func knockback(away_dir: Vector3) -> void:
	# 기사와 부딪치면 살짝(1칸) 상호 넉백: 적도 1칸, 용사도 1칸으로 대칭.
	var base_pos := GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	var pushed := base_pos + away_dir.normalized() * 1.0 * GridUtil.TILE_SIZE
	var cell := GridUtil.world_to_cell(pushed)
	_cell = Vector2i(GridUtil.clamp_col(cell.x), GridUtil.clamp_row(cell.y))
	position = GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	stun = 0.5
	_has_target = false

func take_hit() -> bool:
	hp -= 1
	return hp <= 0
