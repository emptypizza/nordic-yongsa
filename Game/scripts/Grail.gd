class_name Grail
extends Node3D

signal reached_goal
signal died
signal health_changed(hp: int, max_hp: int)

var cx: int = GridUtil.COLS / 2
var max_hp: int = 5
var hp: int = 0
var _invincible: float = 0.0
var _mesh: MeshInstance3D

const FORWARD_SPEED: float = GridUtil.TILE_SIZE / 1.5  # 0.667 u/s

# z 위치에서 파생되는 현재 행
func get_cz() -> int:
	return GridUtil.clamp_row(roundi(position.z / GridUtil.TILE_SIZE))

func _ready() -> void:
	hp = max_hp
	_build_visual()
	position = GridUtil.cell_to_world(cx, get_cz(), 0.0)
	health_changed.emit(hp, max_hp)

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.35
	cyl.height = 0.7
	_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.84, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.7, 0)
	mat.emission_energy_multiplier = 1.5
	_mesh.material_override = mat
	add_child(_mesh)

func _process(delta: float) -> void:
	# 위아래 bob
	_mesh.position = Vector3(0, sin(Time.get_ticks_msec() / 300.0) * 0.05, 0)

	# 무적 깜빡임
	if _invincible > 0.0:
		_invincible -= delta
		_mesh.visible = fposmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0
	else:
		_mesh.visible = true

	var goal_z := (GridUtil.ROWS - 1) * GridUtil.TILE_SIZE
	if position.z >= goal_z:
		reached_goal.emit()
		set_process(false)
		return
	position += Vector3(0, 0, FORWARD_SPEED * delta)

func take_damage() -> void:
	if _invincible > 0.0:
		return
	hp -= 1
	_invincible = 1.0
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
