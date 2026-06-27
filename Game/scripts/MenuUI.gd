class_name MenuUI

# 메뉴 화면(Title / StageSelect) 공용 스타일 헬퍼.
# 인게임 HUD와 같은 따뜻한 팔레트·라운드 패널·아웃라인 텍스트로 톤을 통일한다.

const GREEN := Color(0.30, 0.70, 0.35)
const BLUE := Color(0.30, 0.55, 0.95)
const AMBER := Color(0.92, 0.70, 0.26)

static func box(bg: Color, radius: int, border_col: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border_col
		sb.set_border_width_all(border_w)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.12, 0.10, 0.9))
	l.add_theme_constant_override("outline_size", 10)
	return l

static func heading(parent: Node, text: String, top: float) -> Label:
	var l := label(text, 96, Color(1, 0.95, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + 170
	parent.add_child(l)
	return l

static func button(parent: Node, text: String, size: int, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.98, 0.98, 0.92))
	b.add_theme_stylebox_override("normal", box(color, 22))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 22, Color(1, 1, 1, 0.6), 3))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 22))
	parent.add_child(b)
	return b

# 세로 그라데이션 배경(맨 처음 추가해 다른 UI 뒤에 깔린다).
static func gradient_bg(parent: Node, top: Color, bottom: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 64
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
