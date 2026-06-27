class_name Board
extends Node3D

# mokup1.png 룩의 러시 보드를 코드로 빌드한다.
# - 레인 타입별 색 타일(잔디 명암 교차 / 파란 강 / 흙길)
# - 강 위 중앙 통나무 다리(마차·플레이어 안전 횡단로)
# - 가장자리 숲 장식(나무/덤불/바위)
# - 끝 행의 빛나는 파란 포탈(골)
# 프로젝트 규칙: 액터/배경 모두 코드-빌드, 메시는 자식 노드, 프리미티브 placeholder.

const TILE_DIR := "res://scripts/gen/map/tiles/"

var _mat_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _portal_core: MeshInstance3D
var _portal_ring: MeshInstance3D
var _portal_sprite: Sprite3D

func _ready() -> void:
	_build_tiles()
	_build_edge_forest()
	_build_flowers()
	_build_landmarks()
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

func _load_tex(tex_name: String) -> Texture2D:
	if _tex_cache.has(tex_name):
		return _tex_cache[tex_name]
	var path := TILE_DIR + tex_name + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[tex_name] = tex
	return tex

func _ground_mat(tex: Texture2D, tint: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

# 잔디/길/물처럼 명암 교차(even/odd)가 필요한 레인용. 같은 텍스처에 밝기 틴트만 다르게.
func _ground_pair(tex_name: String, flat_a: Color, flat_b: Color, emission: Color = Color.BLACK, energy: float = 1.0) -> Array:
	var tex := _load_tex(tex_name)
	if tex == null:
		return [_mat(flat_a, emission, energy), _mat(flat_b, emission, energy)]
	return [
		_ground_mat(tex, Color(1.0, 1.0, 1.0), emission, energy),
		_ground_mat(tex, Color(0.87, 0.91, 0.83), emission, energy),
	]

func _ground_single(tex_name: String, flat: Color, emission: Color = Color.BLACK, energy: float = 1.0) -> StandardMaterial3D:
	var tex := _load_tex(tex_name)
	if tex == null:
		return _mat(flat, emission, energy)
	return _ground_mat(tex, Color.WHITE, emission, energy)

static func _hash2(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663)
	return absi(h)

# 같은 메시·머티리얼 인스턴스들을 MultiMesh 1개로 묶어 그린다(드로우콜 절감).
func _multimesh_layer(mat: StandardMaterial3D, mesh: Mesh, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)

func _build_tiles() -> void:
	# 레인별 팔레트 (살짝 명암 교차해 손맛 있는 잔디 느낌).
	# 절차적 톱다운 타일 텍스처가 있으면 입히고, 없으면 평면 색으로 폴백한다.
	# 570개(19×30) 타일을 머티리얼별 MultiMesh로 배칭해 드로우콜을 ~7개로 줄인다.
	var grass := _ground_pair("grass", Color(0.46, 0.73, 0.31), Color(0.41, 0.68, 0.28))
	var path := _ground_pair("path", Color(0.64, 0.49, 0.33), Color(0.58, 0.44, 0.29))
	var water := _ground_pair("water", Color(0.20, 0.55, 0.86), Color(0.16, 0.48, 0.80), Color(0.05, 0.18, 0.32), 0.6)
	var grass_a: StandardMaterial3D = grass[0]
	var grass_b: StandardMaterial3D = grass[1]
	var path_a: StandardMaterial3D = path[0]
	var path_b: StandardMaterial3D = path[1]
	var water_a: StandardMaterial3D = water[0]
	var water_b: StandardMaterial3D = water[1]
	var plank := _ground_single("plank", Color(0.55, 0.40, 0.24))

	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)  # 모든 타일이 공유하는 단일 1×1 평면 메시.

	# 머티리얼 → 인스턴스 변환 목록. 같은 머티리얼은 한 MultiMesh로 묶인다.
	var batches: Dictionary = {}
	for z in GridUtil.ROWS:
		var lane := LaneConfig.lane_type(z)
		for x in GridUtil.COLS:
			var even := (x + z) % 2 == 0
			var mat: StandardMaterial3D
			var y := 0.0
			match lane:
				LaneConfig.LaneType.RIVER:
					if LaneConfig.is_bridge_col(x):
						mat = plank   # 통나무 다리
						y = 0.02
					else:
						mat = water_a if even else water_b
						y = -0.10
				LaneConfig.LaneType.PATH:
					mat = path_a if even else path_b
				_:
					mat = grass_a if even else grass_b
			if not batches.has(mat):
				batches[mat] = []
			batches[mat].append(Transform3D(Basis(), GridUtil.cell_to_world(x, z, y)))

	for mat in batches:
		_multimesh_layer(mat, plane, batches[mat])

func _build_edge_forest() -> void:
	# 가장자리(좌우 3칸) 잔디 레인에 숲·소품을 결정론적으로 촘촘히 배치 → 보드를 둘러싼다.
	# 단일 메시 소품(덤불/바위/그루터기/상자/배럴)은 MultiMesh로 배칭. 나무/통나무더미는 다중 파츠라 개별.
	var edge_cols := [0, 1, 2, GridUtil.COLS - 3, GridUtil.COLS - 2, GridUtil.COLS - 1]
	var bush_xf: Array = []
	var rock_xf: Array = []
	var stump_xf: Array = []
	var crate_xf: Array = []
	var barrel_xf: Array = []
	for z in range(1, GridUtil.ROWS - 1):
		if LaneConfig.lane_type(z) != LaneConfig.LaneType.GRASS:
			continue
		for x in edge_cols:
			var h := _hash2(x, z)
			if h % 12 < 3:
				continue  # 일부는 빈 잔디로 남겨 숨통
			var yaw := float(h % 360) * 0.0174533
			match h % 9:
				0, 1: _make_tree(x, z, h)
				2: bush_xf.append(Transform3D(Basis(), GridUtil.cell_to_world(x, z, 0.16)))
				3: bush_xf.append(Transform3D(Basis(), GridUtil.cell_to_world(x, z, 0.16)))
				4: rock_xf.append(Transform3D(Basis.from_euler(Vector3(0.2, yaw, 0.1)), GridUtil.cell_to_world(x, z, 0.13)))
				5: stump_xf.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), GridUtil.cell_to_world(x, z, 0.16)))
				6: crate_xf.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), GridUtil.cell_to_world(x, z, 0.21)))
				7: barrel_xf.append(Transform3D(Basis(), GridUtil.cell_to_world(x, z, 0.26)))
				_: _make_log_pile(x, z, h)

	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.32
	bush_mesh.height = 0.38
	_multimesh_layer(_mat(Color(0.36, 0.62, 0.30)), bush_mesh, bush_xf)

	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.4, 0.3, 0.4)
	_multimesh_layer(_mat(Color(0.55, 0.56, 0.58)), rock_mesh, rock_xf)

	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = 0.24
	stump_mesh.bottom_radius = 0.26
	stump_mesh.height = 0.32
	_multimesh_layer(_mat(Color(0.46, 0.32, 0.19)), stump_mesh, stump_xf)

	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(0.42, 0.42, 0.42)
	_multimesh_layer(_mat(Color(0.62, 0.45, 0.26)), crate_mesh, crate_xf)

	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.20
	barrel_mesh.bottom_radius = 0.22
	barrel_mesh.height = 0.52
	_multimesh_layer(_mat(Color(0.40, 0.28, 0.16)), barrel_mesh, barrel_xf)

func _make_log_pile(cx: int, cz: int, h: int) -> void:
	# 통나무 더미: 아래 2개 + 위 1개(피라미드). 가장자리 벌목 느낌.
	var root := Node3D.new()
	root.position = GridUtil.cell_to_world(cx, cz, 0.0)
	root.rotation.y = float(h % 4) * 0.18
	add_child(root)
	var mat := _mat(Color(0.50, 0.36, 0.22))
	var cap := _mat(Color(0.66, 0.50, 0.32))
	var positions := [Vector3(-0.17, 0.15, 0), Vector3(0.17, 0.15, 0), Vector3(0, 0.42, 0)]
	for p in positions:
		var logm := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.15
		cyl.height = 0.66
		logm.mesh = cyl
		logm.material_override = mat
		logm.rotation_degrees = Vector3(90, 0, 0)  # 축을 z로 눕힘
		logm.position = p
		root.add_child(logm)
		var endcap := MeshInstance3D.new()
		var ecyl := CylinderMesh.new()
		ecyl.top_radius = 0.16
		ecyl.bottom_radius = 0.16
		ecyl.height = 0.04
		endcap.mesh = ecyl
		endcap.material_override = cap
		endcap.rotation_degrees = Vector3(90, 0, 0)
		endcap.position = p + Vector3(0, 0, 0.33)
		root.add_child(endcap)

func _build_flowers() -> void:
	# 잔디 레인 위에 점점이 꽃(3색). 작고 납작해 게임플레이/가독성에 영향 없음. 색상별 MultiMesh.
	var reds: Array = []
	var yellows: Array = []
	var whites: Array = []
	for z in range(1, GridUtil.ROWS - 1):
		if LaneConfig.lane_type(z) != LaneConfig.LaneType.GRASS:
			continue
		for x in GridUtil.COLS:
			var h := _hash2(x * 7 + 3, z * 5 + 1)
			if h % 9 != 0:
				continue  # 약 11%만 꽃
			var xf := Transform3D(Basis(), GridUtil.cell_to_world(x, z, 0.06) + Vector3((float(h % 5) - 2.0) * 0.12, 0, (float(h % 3) - 1.0) * 0.12))
			match h % 3:
				0: reds.append(xf)
				1: yellows.append(xf)
				_: whites.append(xf)
	var petal := SphereMesh.new()
	petal.radius = 0.12
	petal.height = 0.10
	_multimesh_layer(_mat(Color(0.92, 0.30, 0.34), Color(0.30, 0.05, 0.05), 0.3), petal, reds)
	_multimesh_layer(_mat(Color(0.98, 0.86, 0.30), Color(0.35, 0.28, 0.05), 0.3), petal, yellows)
	_multimesh_layer(_mat(Color(0.96, 0.96, 0.98), Color(0.25, 0.25, 0.28), 0.2), petal, whites)

func _build_landmarks() -> void:
	# 가장자리에 소수의 작은 건물(대장간/집/상점) + 울타리를 결정론 위치에 배치(시각 전용).
	# 잔디 레인이 보장되는 행에 둔다(시작·포탈 근처 안전지대 활용).
	_make_smithy(2, 4)
	_make_house(GridUtil.COLS - 3, 9)
	_make_shop(2, 22)
	_make_house(GridUtil.COLS - 3, 26)
	_make_fence(1, 3, 4)
	_make_fence(GridUtil.COLS - 4, 24, 4)

func _building_base(cx: int, cz: int, size: Vector3, wall: Color) -> Node3D:
	var root := Node3D.new()
	root.position = GridUtil.cell_to_world(cx, cz, 0.0)
	add_child(root)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.material_override = _mat(wall)
	body.position = Vector3(0, size.y * 0.5, 0)
	root.add_child(body)
	return root

func _add_roof(root: Node3D, base_size: Vector3, color: Color) -> void:
	# 박스를 45° 돌려 마름모 단면 → 간이 박공지붕.
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(base_size.x * 0.78, base_size.x * 0.78, base_size.z * 1.06)
	roof.mesh = rb
	roof.material_override = _mat(color)
	roof.rotation_degrees = Vector3(0, 0, 45)
	roof.position = Vector3(0, base_size.y + base_size.x * 0.32, 0)
	root.add_child(roof)

func _make_house(cx: int, cz: int) -> void:
	var size := Vector3(0.9, 0.8, 0.9)
	var root := _building_base(cx, cz, size, Color(0.86, 0.78, 0.62))
	_add_roof(root, size, Color(0.62, 0.28, 0.22))
	var door := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(0.26, 0.42, 0.05)
	door.mesh = db
	door.material_override = _mat(Color(0.40, 0.27, 0.16))
	door.position = Vector3(0, 0.21, size.z * 0.5 + 0.01)
	root.add_child(door)

func _make_smithy(cx: int, cz: int) -> void:
	var size := Vector3(1.0, 0.78, 0.9)
	var root := _building_base(cx, cz, size, Color(0.46, 0.42, 0.40))
	_add_roof(root, size, Color(0.30, 0.30, 0.34))
	# 굴뚝 + 발광 화로(주황).
	var chimney := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.22, 0.5, 0.22)
	chimney.mesh = cb
	chimney.material_override = _mat(Color(0.34, 0.32, 0.32))
	chimney.position = Vector3(0.3, size.y + 0.25, -0.2)
	root.add_child(chimney)
	var forge := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.3, 0.26, 0.05)
	forge.mesh = fb
	forge.material_override = _mat(Color(1.0, 0.55, 0.15), Color(1.0, 0.45, 0.10), 3.0)
	forge.position = Vector3(0, 0.22, size.z * 0.5 + 0.01)
	root.add_child(forge)

func _make_shop(cx: int, cz: int) -> void:
	var size := Vector3(0.95, 0.72, 0.9)
	var root := _building_base(cx, cz, size, Color(0.80, 0.72, 0.58))
	_add_roof(root, size, Color(0.30, 0.45, 0.62))
	# 줄무늬 차양.
	var awning := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(size.x * 1.02, 0.06, 0.32)
	awning.mesh = ab
	awning.material_override = _mat(Color(0.85, 0.35, 0.30))
	awning.position = Vector3(0, size.y * 0.62, size.z * 0.5 + 0.14)
	awning.rotation_degrees = Vector3(18, 0, 0)
	root.add_child(awning)

func _make_fence(cx: int, cz: int, count: int) -> void:
	# z축으로 이어지는 말뚝 울타리(말뚝 + 가로대).
	var root := Node3D.new()
	root.position = GridUtil.cell_to_world(cx, cz, 0.0)
	add_child(root)
	var wood := _mat(Color(0.54, 0.40, 0.24))
	for i in count:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 0.42, 0.1)
		post.mesh = pb
		post.material_override = wood
		post.position = Vector3(0, 0.21, float(i))
		root.add_child(post)
	var rail := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.06, 0.08, float(count - 1) + 0.1)
	rail.mesh = rb
	rail.material_override = wood
	rail.position = Vector3(0, 0.30, float(count - 1) * 0.5)
	root.add_child(rail)

func _make_tree(cx: int, cz: int, h: int) -> void:
	var root := Node3D.new()
	root.position = GridUtil.cell_to_world(cx, cz, 0.0)
	add_child(root)

	# 빌보드 나무 스프라이트(있으면). 없으면 아래 프리미티브 폴백.
	var sprite := CharacterMesh.build_billboard("res://scripts/gen/props/tree.png", 1.8)
	if sprite != null:
		root.add_child(sprite)
		return

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

func _build_portal() -> void:
	# 끝 행 중앙의 빛나는 파란 포탈(골). 석재 단상+계단 + 블록 기둥 + 빛 코어 + 회전 링 + 상승 파티클.
	var cz := GridUtil.ROWS - 1
	var center := LaneConfig.bridge_center()
	var base := GridUtil.cell_to_world(center, cz, 0.0)

	# 빌보드 포탈 스프라이트(있으면) + 상승 빛 입자 유지. 없으면 아래 프리미티브 폴백.
	var sprite := CharacterMesh.build_billboard("res://scripts/gen/props/portal.png", 3.2)
	if sprite != null:
		sprite.position.x = base.x
		sprite.position.z = base.z
		_portal_sprite = sprite
		add_child(sprite)
		var motes := CPUParticles3D.new()
		motes.amount = 22
		motes.lifetime = 2.2
		motes.position = base + Vector3(0, 0.5, 0.0)
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		motes.emission_box_extents = Vector3(0.9, 0.1, 0.05)
		motes.direction = Vector3(0, 1, 0)
		motes.spread = 12.0
		motes.initial_velocity_min = 0.5
		motes.initial_velocity_max = 1.1
		motes.gravity = Vector3.ZERO
		motes.scale_amount_min = 0.05
		motes.scale_amount_max = 0.12
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.5
		mote_mesh.height = 1.0
		motes.mesh = mote_mesh
		motes.mesh.surface_set_material(0, _mat(Color(0.6, 0.85, 1.0), Color(0.5, 0.8, 1.0), 2.5))
		add_child(motes)
		return

	var stone := _mat(Color(0.48, 0.49, 0.52))
	var stone_dark := _mat(Color(0.38, 0.39, 0.43))

	# 단상 + 앞쪽(-z)으로 낮아지는 계단.
	var dais := MeshInstance3D.new()
	var daisb := BoxMesh.new()
	daisb.size = Vector3(3.6, 0.2, 1.0)
	dais.mesh = daisb
	dais.material_override = stone_dark
	dais.position = base + Vector3(0, 0.1, 0)
	add_child(dais)
	for i in 3:
		var step := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(3.0 - float(i) * 0.5, 0.12, 0.42)
		step.mesh = sb
		step.material_override = stone if i % 2 == 0 else stone_dark
		step.position = base + Vector3(0, 0.06, -0.7 - float(i) * 0.42)
		add_child(step)

	# 좌우 기둥을 개별 석재 블록 4단으로 쌓아 질감을 준다.
	for sx in [-1.35, 1.35]:
		for b in 4:
			var block := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.55, 0.5, 0.55)
			block.mesh = bb
			block.material_override = stone if b % 2 == 0 else stone_dark
			block.position = base + Vector3(sx + (0.04 if b % 2 == 0 else -0.04), 0.45 + float(b) * 0.5, 0)
			add_child(block)
	# 상인방 블록 3개.
	for lx in [-0.8, 0.0, 0.8]:
		var lintel := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.92, 0.5, 0.55)
		lintel.mesh = lb
		lintel.material_override = stone if int(lx) % 2 == 0 else stone_dark
		lintel.position = base + Vector3(lx, 2.5, 0)
		add_child(lintel)

	# 빛 코어 (납작한 구 = 포탈 면), 세로로 세워 +z 쪽을 향하게.
	_portal_core = MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = 1.05
	core.height = 2.1
	_portal_core.mesh = core
	_portal_core.material_override = _mat(Color(0.25, 0.6, 1.0), Color(0.3, 0.6, 1.0), 3.0)
	_portal_core.scale = Vector3(1.0, 1.0, 0.18)
	_portal_core.position = base + Vector3(0, 1.35, 0)
	add_child(_portal_core)

	# 회전하는 발광 링.
	_portal_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.3
	_portal_ring.mesh = torus
	_portal_ring.material_override = _mat(Color(0.5, 0.85, 1.0), Color(0.5, 0.85, 1.0), 4.0)
	_portal_ring.rotation_degrees = Vector3(90, 0, 0)  # 링 구멍이 +z를 향하도록
	_portal_ring.position = base + Vector3(0, 1.35, 0)
	add_child(_portal_ring)

	# 포탈 면에서 위로 피어오르는 푸른 빛 입자.
	var motes := CPUParticles3D.new()
	motes.amount = 22
	motes.lifetime = 2.2
	motes.position = base + Vector3(0, 0.5, 0.0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.9, 0.1, 0.05)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 12.0
	motes.initial_velocity_min = 0.5
	motes.initial_velocity_max = 1.1
	motes.gravity = Vector3.ZERO
	motes.scale_amount_min = 0.05
	motes.scale_amount_max = 0.12
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.5
	mote_mesh.height = 1.0
	motes.mesh = mote_mesh
	motes.mesh.surface_set_material(0, _mat(Color(0.6, 0.85, 1.0), Color(0.5, 0.8, 1.0), 2.5))
	add_child(motes)

	# 포탈 양옆을 바위·꽃으로 장식.
	var deco_rock := BoxMesh.new()
	deco_rock.size = Vector3(0.45, 0.34, 0.45)
	var rock_xf: Array = []
	for sx in [-2.2, -1.9, 1.9, 2.2]:
		rock_xf.append(Transform3D(Basis.from_euler(Vector3(0.15, sx, 0.1)), base + Vector3(sx, 0.16, -0.2)))
	_multimesh_layer(_mat(Color(0.52, 0.53, 0.56)), deco_rock, rock_xf)

func _process(_delta: float) -> void:
	if _portal_sprite != null:
		var s := 1.0 + sin(Time.get_ticks_msec() / 360.0) * 0.03
		_portal_sprite.scale = Vector3(s, s, 1.0)
	if _portal_ring != null:
		_portal_ring.rotate_z(_delta * 1.2)
	if _portal_core != null:
		var pulse := 2.4 + sin(Time.get_ticks_msec() / 350.0) * 0.9
		var mat := _portal_core.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = pulse
