class_name MoveGuide
extends Node3D

# mokup1.png의 발밑 이동 가이드: 플레이어 셀에 흰 하이라이트 박스(맥동)를 바닥에 깐다.
# 시각 전용 — 입력/규칙과 무관. GameManager가 생성해 attach(player) 한다.
# 공개 API: attach(player), set_visible_enabled(enabled).

var _player: Player
var _enabled := true
var _t := 0.0

func _ready() -> void:
	_build()

func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.93, 1.0)
	mat.emission_energy_multiplier = 1.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var half := 0.46
	var thick := 0.07
	var span := half * 2.0 + thick
	# 사각 외곽선 4변(얇은 박스).
	var sides := [
		[Vector3(0, 0, half), Vector3(span, thick, thick)],
		[Vector3(0, 0, -half), Vector3(span, thick, thick)],
		[Vector3(half, 0, 0), Vector3(thick, thick, span)],
		[Vector3(-half, 0, 0), Vector3(thick, thick, span)],
	]
	for s in sides:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = s[1]
		mi.mesh = b
		mi.material_override = mat
		mi.position = s[0]
		add_child(mi)
	position.y = 0.05

func attach(player: Player) -> void:
	_player = player

func set_visible_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled

func _process(delta: float) -> void:
	if not _enabled or _player == null or not is_instance_valid(_player):
		return
	position.x = _player.position.x
	position.z = _player.position.z
	_t += delta
	var p := 1.0 + sin(_t * 3.2) * 0.07  # 부드러운 맥동
	scale = Vector3(p, 1.0, p)
