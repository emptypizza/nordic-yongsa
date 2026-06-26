class_name CharacterMesh

# glbs/ 의 복셀 캐릭터(Node3D 루트 + 다수 MeshInstance3D + AnimationPlayer)를
# "타일 기준 캐릭터"로 정규화해서 재사용한다. 각 glb의 native 크기가 제각각이라
# (Warrior/Healer/Wizard/Crow/Boogeyman) target_height에 맞춰 균일 스케일한다.
#
# build()가 돌려주는 구조(2단):
#   pivot(Node3D, scale=1) ─ glb 루트(model, scale=target/native, Idle 재생)
# 부모(Player/Enemy/GameManager)는 pivot에만 hop·squash·회전을 건다(base scale=ONE).
# glb 루트(model)에 직접 스케일을 거는 건 기존 Test Ch.glb(scale 0.03)에서 검증된 방식.
#
# native 높이는 헤드리스로 Idle 포즈를 정착시킨 뒤 실측한 값(_measure_glb.gd).
# bind 포즈(T-pose)는 팔이 벌어져 더 크므로 런타임 AABB 자동측정 대신 이 실측값을 쓴다.
# 발(footY)은 모든 모델에서 원점에 거의 붙어 있어(±0.7 native) 별도 보정이 필요 없다.

const NATIVE_HEIGHT := {
	"res://scripts/glbs/Warrior 01.glb": 48.2,
	"res://scripts/glbs/Healer 01.glb": 48.4,
	"res://scripts/glbs/Wizard 01.glb": 48.2,
	"res://scripts/glbs/Crow.glb": 43.7,
	"res://scripts/glbs/Boogeyman 01.glb": 113.1,
	"res://scripts/Test Ch.glb": 41.3,
}
const FALLBACK_NATIVE_H := 45.0
const DEFAULT_IDLE := ["Idle", "Idle01", "Idle02"]

# 실패 시 {} 반환 → 호출부가 스프라이트/프리미티브로 폴백.
static func build(glb_path: String, target_height: float, idle_names: Array = DEFAULT_IDLE) -> Dictionary:
	if not ResourceLoader.exists(glb_path):
		return {}
	var packed = load(glb_path)
	if packed == null:
		return {}
	var inst = packed.instantiate()
	if inst == null or not (inst is Node3D):
		return {}
	var model: Node3D = inst
	var native: float = NATIVE_HEIGHT.get(glb_path, FALLBACK_NATIVE_H)
	model.scale = Vector3.ONE * (target_height / maxf(native, 0.01))
	var pivot := Node3D.new()
	pivot.add_child(model)
	var ap := _find_anim(model)
	if ap != null:
		play_loop(ap, idle_names)
	return {"pivot": pivot, "anim": ap, "model": model}

# 루프 재생: names 중 처음 존재하는 클립을 LOOP로 재생. 없으면 첫 클립. 반환=재생한 이름.
static func play_loop(ap: AnimationPlayer, names: Array) -> String:
	for n in names:
		if ap.has_animation(n):
			_set_loop(ap, n)
			ap.play(n)
			return n
	var list := ap.get_animation_list()
	if list.size() > 0:
		_set_loop(ap, list[0])
		ap.play(list[0])
		return list[0]
	return ""

static func _set_loop(ap: AnimationPlayer, anim_name: String) -> void:
	var clip := ap.get_animation(anim_name)
	if clip != null:
		clip.loop_mode = Animation.LOOP_LINEAR

# 이름이 prefixes 중 하나로 시작하는 MeshInstance3D에 단색 material_override를 입힌다.
# 복셀 캐릭터는 파츠별 메시라, 머리카락 파츠(예: Warrior의 "ha"/"hha")만 골라 색을 바꿀 수 있다.
# 반환: 색칠한 메시 수. (material_override는 텍스처를 무시한 평면색 → 깔끔한 단색)
static func recolor_parts(root: Node, prefixes: Array, color: Color) -> int:
	var n := 0
	if root is MeshInstance3D:
		var ln := root.name.to_lower()
		for p in prefixes:
			if ln.begins_with(p):
				var m := StandardMaterial3D.new()
				m.albedo_color = color
				(root as MeshInstance3D).material_override = m
				n += 1
				break
	for c in root.get_children():
		n += recolor_parts(c, prefixes, color)
	return n

static func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null
