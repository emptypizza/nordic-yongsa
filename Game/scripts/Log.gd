class_name Log
extends Node3D

# 강 레인 위를 x축으로 흘러가는 통나무 플랫폼 (Crossy Road/Frogger식).
# 플레이어가 물 위에서 통나무에 올라타면 함께 떠내려가고, 없으면 익사한다.
# 마차/적 로직과는 무관 — 순수 플레이어 횡단용.

var cz: int = 0
var dir: int = 1
var speed: float = 1.2
var length: float = 2.6  # 월드 유닛 길이 (≈2~3타일)

var _body: Node3D       # 물에 둥실 떠 보이게 bob 시킬 시각 루트
var _bob_phase: float = 0.0

const _MARGIN := 1.6  # 보드 밖으로 완전히 나갔다가 반대편에서 재진입

func init(row: int, drift_dir: int, drift_speed: float, span: float, start_x: float) -> void:
	cz = row
	dir = drift_dir
	speed = drift_speed
	length = span
	position = Vector3(start_x, 0.0, float(row) * GridUtil.TILE_SIZE)
	_bob_phase = start_x * 0.7 + float(row)  # 통나무마다 bob 위상이 달라 한꺼번에 안 흔들리게

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = length
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.37, 0.22)
	body.material_override = mat
	body.rotation_degrees = Vector3(0, 0, 90)  # 원기둥 축을 x로 눕힘
	body.position = Vector3(0, 0.06, 0)
	_body.add_child(body)

	# 양 끝 나이테(컷 단면) — 통나무 방향감을 준다.
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.70, 0.55, 0.36)
	for ex in [-length * 0.5, length * 0.5]:
		var cap := MeshInstance3D.new()
		var cmesh := CylinderMesh.new()
		cmesh.top_radius = 0.30
		cmesh.bottom_radius = 0.30
		cmesh.height = 0.05
		cap.mesh = cmesh
		cap.material_override = ring_mat
		cap.rotation_degrees = Vector3(0, 0, 90)
		cap.position = Vector3(ex, 0.06, 0)
		_body.add_child(cap)

	# 위쪽 밝은 결 스트라이프 (가독성).
	var top := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length * 0.92, 0.06, 0.18)
	top.mesh = box
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.63, 0.46, 0.28)
	top.material_override = tmat
	top.position = Vector3(0, 0.30, 0)
	_body.add_child(top)

func _left_bound() -> float:
	return -_MARGIN - length * 0.5

func _right_bound() -> float:
	return float(GridUtil.COLS - 1) + _MARGIN + length * 0.5

func _process(delta: float) -> void:
	position.x += float(dir) * speed * delta
	if dir > 0 and position.x > _right_bound():
		position.x = _left_bound()
	elif dir < 0 and position.x < _left_bound():
		position.x = _right_bound()
	# 물에 둥실 떠 있는 느낌(시각 전용 — 그리드/탑승 로직과 무관).
	if _body != null:
		var t := Time.get_ticks_msec() / 1000.0
		_body.position.y = sin(t * 2.2 + _bob_phase) * 0.04
		_body.rotation.z = sin(t * 1.6 + _bob_phase) * 0.04

# 주어진 월드 x가 이 통나무 위인지 (살짝 여유).
func covers_x(world_x: float) -> bool:
	return absf(world_x - position.x) <= (length * 0.5 + 0.15)

func drift_dx(delta: float) -> float:
	return float(dir) * speed * delta
