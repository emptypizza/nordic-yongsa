class_name Grail
extends Node3D

signal reached_goal
signal died
signal health_changed(hp: int, max_hp: int)

var cx: int = GridUtil.COLS / 2
var max_hp: int = 5
var hp: int = 0
var _invincible: float = 0.0
var _body: Node3D            # bob/무적 깜빡임 대상 (마차 전체)
var _wheels: Array[Node3D] = []
var _grail_glow: StandardMaterial3D

const FORWARD_SPEED: float = GridUtil.TILE_SIZE / 1.5  # 0.667 u/s

# z 위치에서 파생되는 현재 행
func get_cz() -> int:
	return GridUtil.clamp_row(roundi(position.z / GridUtil.TILE_SIZE))

func _ready() -> void:
	hp = max_hp
	_build_visual()
	position = GridUtil.cell_to_world(cx, get_cz(), 0.0)
	health_changed.emit(hp, max_hp)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _build_visual() -> void:
	# 성배마차: 나무 짐칸 + 천 캐노피 + 바퀴 4개 + 상단 발광 성배.
	_body = Node3D.new()
	add_child(_body)

	var cart := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.95, 0.4, 1.25)
	cart.mesh = cbox
	cart.material_override = _mat(Color(0.55, 0.38, 0.22))
	cart.position = Vector3(0, 0.38, 0)
	_body.add_child(cart)

	# 천 캐노피 (원기둥을 z축으로 눕혀 덮개 모양).
	var canopy := MeshInstance3D.new()
	var ccyl := CylinderMesh.new()
	ccyl.top_radius = 0.5
	ccyl.bottom_radius = 0.5
	ccyl.height = 1.15
	canopy.mesh = ccyl
	canopy.material_override = _mat(Color(0.93, 0.90, 0.80))
	canopy.rotation_degrees = Vector3(90, 0, 0)
	canopy.position = Vector3(0, 0.72, 0)
	_body.add_child(canopy)

	# 바퀴 4개 (축이 x → z축으로 90° 회전). 전진 시 굴림.
	var wheel_mat := _mat(Color(0.22, 0.16, 0.10))
	for wx in [-0.5, 0.5]:
		for wz in [-0.45, 0.45]:
			var wheel := MeshInstance3D.new()
			var wcyl := CylinderMesh.new()
			wcyl.top_radius = 0.22
			wcyl.bottom_radius = 0.22
			wcyl.height = 0.12
			wheel.mesh = wcyl
			wheel.material_override = wheel_mat
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = Vector3(wx, 0.22, wz)
			_body.add_child(wheel)
			_wheels.append(wheel)

	# 상단 신성한 성배 (발광 금색).
	var grail := MeshInstance3D.new()
	var gcup := CylinderMesh.new()
	gcup.top_radius = 0.2
	gcup.bottom_radius = 0.08
	gcup.height = 0.32
	grail.mesh = gcup
	_grail_glow = StandardMaterial3D.new()
	_grail_glow.albedo_color = Color(1, 0.84, 0)
	_grail_glow.emission_enabled = true
	_grail_glow.emission = Color(1, 0.7, 0)
	_grail_glow.emission_energy_multiplier = 1.8
	grail.material_override = _grail_glow
	grail.position = Vector3(0, 1.32, 0)
	_body.add_child(grail)

func _process(delta: float) -> void:
	# 위아래 bob
	_body.position.y = sin(Time.get_ticks_msec() / 300.0) * 0.05

	# 바퀴 굴림 (전진 속도 기반).
	var spin := FORWARD_SPEED / 0.22 * delta
	for w in _wheels:
		w.rotate_x(spin)

	# 성배 은은한 맥동.
	if _grail_glow != null:
		_grail_glow.emission_energy_multiplier = 1.6 + sin(Time.get_ticks_msec() / 250.0) * 0.4

	# 무적 깜빡임
	if _invincible > 0.0:
		_invincible -= delta
		_body.visible = fposmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0
	else:
		_body.visible = true

	var goal_z := (GridUtil.ROWS - 1) * GridUtil.TILE_SIZE
	if position.z >= goal_z:
		reached_goal.emit()
		set_process(false)
		return
	position += Vector3(0, 0, FORWARD_SPEED * delta)

func take_damage() -> bool:
	# 실제로 피해를 입혔으면 true, 무적이라 무시했으면 false.
	if _invincible > 0.0:
		return false
	hp -= 1
	_invincible = 1.0
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return true
