class_name Board
extends Node3D

# mokup1.png 룩의 러시 보드를 코드로 빌드한다.
# - 레인 타입별 색 타일(잔디 명암 교차 / 파란 강 / 흙길)
# - 강 위 중앙 통나무 다리(마차·플레이어 안전 횡단로)
# - 가장자리 숲 장식(나무/덤불/바위)
# - 끝 행의 빛나는 파란 포탈(골)
# 프로젝트 규칙: 액터/배경 모두 코드-빌드, 메시는 자식 노드, 프리미티브 placeholder.

var _mat_cache: Dictionary = {}
var _portal_core: MeshInstance3D
var _portal_ring: MeshInstance3D
var _water_tiles: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_tiles()
	_build_edge_forest()
	_build_portal()

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [color, emission, energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m

static func _hash2(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663)
	return absi(h)

func _tile(cx: int, cz: int, y: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var t := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	t.mesh = plane
	t.material_override = mat
	t.position = GridUtil.cell_to_world(cx, cz, y)
	add_child(t)
	return t

func _build_tiles() -> void:
	# 레인별 팔레트 (살짝 명암 교차해 손맛 있는 잔디 느낌).
	var grass_a := _mat(Color(0.46, 0.73, 0.31))
	var grass_b := _mat(Color(0.41, 0.68, 0.28))
	var path_a := _mat(Color(0.64, 0.49, 0.33))
	var path_b := _mat(Color(0.58, 0.44, 0.29))
	var water_a := _mat(Color(0.20, 0.55, 0.86), Color(0.05, 0.18, 0.32), 0.6)
	var water_b := _mat(Color(0.16, 0.48, 0.80), Color(0.04, 0.15, 0.28), 0.6)
	var plank := _mat(Color(0.55, 0.40, 0.24))

	for z in GridUtil.ROWS:
		var lane := LaneConfig.lane_type(z)
		for x in GridUtil.COLS:
			var even := (x + z) % 2 == 0
			match lane:
				LaneConfig.LaneType.RIVER:
					if LaneConfig.is_bridge_col(x):
						_tile(x, z, 0.02, plank)  # 통나무 다리
					else:
						var wt := _tile(x, z, -0.10, water_a if even else water_b)
						_water_tiles.append(wt)
				LaneConfig.LaneType.PATH:
					_tile(x, z, 0.0, path_a if even else path_b)
				_:
					_tile(x, z, 0.0, grass_a if even else grass_b)

func _build_edge_forest() -> void:
	# 가장자리(좌우 2칸) 잔디 레인에 숲 장식을 결정론적으로 배치 → 보드를 숲으로 감싼다.
	var edge_cols := [0, 1, GridUtil.COLS - 2, GridUtil.COLS - 1]
	for z in range(1, GridUtil.ROWS - 1):
		if LaneConfig.lane_type(z) != LaneConfig.LaneType.GRASS:
			continue
		for x in edge_cols:
			var h := _hash2(x, z)
			if h % 10 < 4:
				continue  # 일부는 빈 잔디로 남겨 숨통
			match h % 3:
				0: _make_tree(x, z, h)
				1: _make_bush(x, z)
				_: _make_rock(x, z)

func _make_tree(cx: int, cz: int, h: int) -> void:
	var root := Node3D.new()
	root.position = GridUtil.cell_to_world(cx, cz, 0.0)
	add_child(root)

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.13
	cyl.height = 0.5
	trunk.mesh = cyl
	trunk.material_override = _mat(Color(0.40, 0.28, 0.17))
	trunk.position = Vector3(0, 0.25, 0)
	root.add_child(trunk)

	# 둥근 잎 덩어리 2단 (mokup의 동글동글한 나무).
	var lower := MeshInstance3D.new()
	var s1 := SphereMesh.new()
	s1.radius = 0.34
	s1.height = 0.55
	lower.mesh = s1
	lower.material_override = _mat(Color(0.24, 0.49, 0.24))
	lower.position = Vector3(0, 0.62, 0)
	root.add_child(lower)

	var upper := MeshInstance3D.new()
	var s2 := SphereMesh.new()
	s2.radius = 0.24
	s2.height = 0.42
	upper.mesh = s2
	upper.material_override = _mat(Color(0.33, 0.60, 0.30))
	upper.position = Vector3(0, 0.95, 0)
	root.add_child(upper)
	# 결정론적 살짝 회전으로 단조로움 제거.
	root.rotation.y = float(h % 360) * 0.0174533

func _make_bush(cx: int, cz: int) -> void:
	var bush := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.38
	bush.mesh = s
	bush.material_override = _mat(Color(0.36, 0.62, 0.30))
	bush.position = GridUtil.cell_to_world(cx, cz, 0.16)
	add_child(bush)

func _make_rock(cx: int, cz: int) -> void:
	var rock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.3, 0.4)
	rock.mesh = box
	rock.material_override = _mat(Color(0.55, 0.56, 0.58))
	rock.position = GridUtil.cell_to_world(cx, cz, 0.13)
	rock.rotation = Vector3(0.2, 0.6, 0.1)
	add_child(rock)

func _build_portal() -> void:
	# 끝 행 중앙의 빛나는 파란 포탈(골). 돌기둥 + 빛 코어 + 회전 링.
	var cz := GridUtil.ROWS - 1
	var center := LaneConfig.bridge_center()
	var base := GridUtil.cell_to_world(center, cz, 0.0)

	var stone := _mat(Color(0.46, 0.47, 0.50))
	for sx in [-1.3, 1.3]:
		var pillar := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.5, 2.1, 0.5)
		pillar.mesh = pb
		pillar.material_override = stone
		pillar.position = base + Vector3(sx, 1.05, 0)
		add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(3.4, 0.5, 0.5)
	lintel.mesh = lb
	lintel.material_override = stone
	lintel.position = base + Vector3(0, 2.25, 0)
	add_child(lintel)

	# 빛 코어 (납작한 구 = 포탈 면), 세로로 세워 +z 쪽을 향하게.
	_portal_core = MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = 1.05
	core.height = 2.1
	_portal_core.mesh = core
	_portal_core.material_override = _mat(Color(0.25, 0.6, 1.0), Color(0.3, 0.6, 1.0), 3.0)
	_portal_core.scale = Vector3(1.0, 1.0, 0.18)
	_portal_core.position = base + Vector3(0, 1.05, 0)
	add_child(_portal_core)

	# 회전하는 발광 링.
	_portal_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.3
	_portal_ring.mesh = torus
	_portal_ring.material_override = _mat(Color(0.5, 0.85, 1.0), Color(0.5, 0.85, 1.0), 4.0)
	_portal_ring.rotation_degrees = Vector3(90, 0, 0)  # 링 구멍이 +z를 향하도록
	_portal_ring.position = base + Vector3(0, 1.05, 0)
	add_child(_portal_ring)

func _process(_delta: float) -> void:
	if _portal_ring != null:
		_portal_ring.rotate_z(_delta * 1.2)
	if _portal_core != null:
		var pulse := 2.4 + sin(Time.get_ticks_msec() / 350.0) * 0.9
		var mat := _portal_core.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = pulse
