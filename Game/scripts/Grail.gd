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
	# 성배마차: 판자 짐칸 + 화물 + 천막(후프 살) + 바퀴(허브/살) + 상단 발광 성배.
	_body = Node3D.new()
	add_child(_body)

	# 바닥 짐칸 판자.
	var bed := MeshInstance3D.new()
	var bedbox := BoxMesh.new()
	bedbox.size = Vector3(0.95, 0.18, 1.25)
	bed.mesh = bedbox
	bed.material_override = _mat(Color(0.50, 0.34, 0.20))
	bed.position = Vector3(0, 0.30, 0)
	_body.add_child(bed)

	# 측면 판자 2장 + 앞/뒤 보드.
	var plank_mat := _mat(Color(0.58, 0.40, 0.23))
	for sx in [-0.5, 0.5]:
		var side := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(0.06, 0.28, 1.2)
		side.mesh = sbox
		side.material_override = plank_mat
		side.position = Vector3(sx, 0.44, 0)
		_body.add_child(side)
	for sz in [-0.62, 0.62]:
		var endb := MeshInstance3D.new()
		var ebox := BoxMesh.new()
		ebox.size = Vector3(0.95, 0.30, 0.06)
		endb.mesh = ebox
		endb.material_override = plank_mat
		endb.position = Vector3(0, 0.45, sz)
		_body.add_child(endb)

	# 짐칸 화물(나무 상자).
	var cargo := MeshInstance3D.new()
	var cargob := BoxMesh.new()
	cargob.size = Vector3(0.4, 0.3, 0.4)
	cargo.mesh = cargob
	cargo.material_override = _mat(Color(0.66, 0.55, 0.34))
	cargo.position = Vector3(-0.16, 0.58, -0.18)
	_body.add_child(cargo)

	# 천막 캐노피(원기둥 눕힘) + 후프 살 3개.
	var canopy := MeshInstance3D.new()
	var ccyl := CylinderMesh.new()
	ccyl.top_radius = 0.5
	ccyl.bottom_radius = 0.5
	ccyl.height = 1.15
	canopy.mesh = ccyl
	canopy.material_override = _mat(Color(0.94, 0.91, 0.82))
	canopy.rotation_degrees = Vector3(90, 0, 0)
	canopy.position = Vector3(0, 0.78, 0)
	_body.add_child(canopy)
	var hoop_mat := _mat(Color(0.78, 0.75, 0.66))
	for hz in [-0.45, 0.0, 0.45]:
		var hoop := MeshInstance3D.new()
		var ht := TorusMesh.new()
		ht.inner_radius = 0.48
		ht.outer_radius = 0.54
		hoop.mesh = ht
		hoop.material_override = hoop_mat
		hoop.rotation_degrees = Vector3(0, 0, 90)
		hoop.position = Vector3(0, 0.78, hz)
		_body.add_child(hoop)

	# 바퀴 4개 (허브+살). 축이 x → z로 90° 회전. 전진 시 _wheels 굴림.
	var wheel_mat := _mat(Color(0.22, 0.16, 0.10))
	var hub_mat := _mat(Color(0.46, 0.34, 0.20))
	for wx in [-0.5, 0.5]:
		for wz in [-0.45, 0.45]:
			var wheel := Node3D.new()
			wheel.position = Vector3(wx, 0.22, wz)
			_body.add_child(wheel)
			_wheels.append(wheel)
			var tire := MeshInstance3D.new()
			var wcyl := CylinderMesh.new()
			wcyl.top_radius = 0.22
			wcyl.bottom_radius = 0.22
			wcyl.height = 0.1
			tire.mesh = wcyl
			tire.material_override = wheel_mat
			tire.rotation_degrees = Vector3(0, 0, 90)
			wheel.add_child(tire)
			var hub := MeshInstance3D.new()
			var hcyl := CylinderMesh.new()
			hcyl.top_radius = 0.07
			hcyl.bottom_radius = 0.07
			hcyl.height = 0.12
			hub.mesh = hcyl
			hub.material_override = hub_mat
			hub.rotation_degrees = Vector3(0, 0, 90)
			wheel.add_child(hub)
			for s in 3:
				var spoke := MeshInstance3D.new()
				var sb := BoxMesh.new()
				sb.size = Vector3(0.04, 0.38, 0.04)
				spoke.mesh = sb
				spoke.material_override = hub_mat
				spoke.rotation = Vector3(deg_to_rad(60.0 * float(s)), 0, 0)
				wheel.add_child(spoke)

	# 상단 성배 받침 + 발광 금색 성배.
	var pedestal := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.14
	pcyl.bottom_radius = 0.18
	pcyl.height = 0.12
	pedestal.mesh = pcyl
	pedestal.material_override = _mat(Color(0.62, 0.50, 0.24))
	pedestal.position = Vector3(0, 1.34, 0)
	_body.add_child(pedestal)

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
	grail.position = Vector3(0, 1.56, 0)
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
