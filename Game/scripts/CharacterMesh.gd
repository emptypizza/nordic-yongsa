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

# 투명 PNG prop을 카메라를 향하는 빌보드 Sprite3D로 만든다(나무/통나무/마차/포탈).
# world_size = 목표 크기(월드 유닛). fit="height"=높이 기준, "width"=너비 기준 스케일.
# 밑면이 바닥(y=0)에 닿도록 position.y 자동 설정(호출부가 덮어쓸 수 있음).
# 텍스처 없으면 null 반환 → 호출부가 프리미티브로 폴백.
static func build_billboard(tex_path: String, world_size: float, fit: String = "height") -> Sprite3D:
	if not ResourceLoader.exists(tex_path):
		return null
	var tex: Texture2D = load(tex_path)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	var denom := float(tex.get_height()) if fit == "height" else float(tex.get_width())
	s.pixel_size = world_size / maxf(denom, 1.0)
	s.position.y = float(tex.get_height()) * s.pixel_size * 0.5
	return s

# 발밑 블롭 그림자용 부드러운 원형 알파 텍스처(1회 생성·캐시). 빌보드 캐릭터는 실제 그림자를
# 안 드리우므로 접지감을 위해 바닥에 깔 반투명 검은 원판을 만든다.
static var _blob_tex: Texture2D

static func _blob_texture() -> Texture2D:
	if _blob_tex != null:
		return _blob_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c  # 0(중심)~~1.41(모서리)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # 가장자리 부드럽게
			img.set_pixel(x, y, Color(0, 0, 0, a * 0.5))
	_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex

# 발밑 블롭 그림자(바닥에 평평히 눕는 반투명 검은 원판). radius=월드 반경.
# 호출부가 캐릭터의 루트(hop/scale 안 받는 노드)에 add_child 해야 그림자가 바닥에 머문다.
static func make_blob_shadow(radius: float = 0.42) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()      # PlaneMesh 기본 법선 +Y → 바닥에 평평.
	q.size = Vector2(radius * 2.0, radius * 1.6)  # 살짝 타원(원근감).
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _blob_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  # 바닥 데칼이라 깊이 미기록(z-fight 방지).
	mi.material_override = m
	mi.position.y = 0.03
	return mi

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
