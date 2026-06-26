class_name Enemy
extends Node3D

var speed: float = 1.6
var hp: int = 0
var stun: float = 0.0

var _grail: Grail
var _mesh: MeshInstance3D
var _cell: Vector2i
var _target_pos: Vector3
var _has_target := false

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
	var body_size: float = 0.9 if is_strong else 0.6
	speed = 1.4 if is_strong else 1.6

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(body_size, body_size, body_size)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.12, 0.45) if is_strong else Color(0.5, 0.1, 0.1)
	_mesh.material_override = mat
	add_child(_mesh)

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
		add_child(eye)

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
	if stun > 0.0:
		stun -= delta
		_mesh.rotation = Vector3(0, randf() * 0.5, 0)  # 기절 흔들림
		return
	_mesh.rotation = Vector3.ZERO

	if not _has_target:
		_pick_next_target()
		return

	position = position.move_toward(_target_pos, speed * delta)
	if position.distance_to(_target_pos) < 0.01:
		_pick_next_target()

func knockback(away_dir: Vector3) -> void:
	var base_pos := GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	var pushed := base_pos + away_dir.normalized() * 2.0 * GridUtil.TILE_SIZE
	var cell := GridUtil.world_to_cell(pushed)
	_cell = Vector2i(GridUtil.clamp_col(cell.x), GridUtil.clamp_row(cell.y))
	position = GridUtil.cell_to_world(_cell.x, _cell.y, 0.0)
	stun = 0.5
	_has_target = false

func take_hit() -> bool:
	hp -= 1
	return hp <= 0
