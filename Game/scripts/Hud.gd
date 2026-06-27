class_name Hud
extends CanvasLayer

# mokup1.png 기반 목업 HUD.
# 상단: Guardian/HP·XP바/레벨 | 스코어 + BEST | 코인 + 일시정지
# 하단: 영웅 카드 3장(라비/소희/아론) + 편집, "DRAG TO MOVE" 힌트
# 입력: Crossy Road식 스와이프/탭(드래그). 데스크톱은 WASD/방향키.
# 좌표계: 프로젝트 뷰포트 1080x1920(stretch=canvas_items) 기준.

signal hop_requested(dir: Vector2i)
signal retry_pressed
signal menu_pressed
signal hero_selected(index: int)   # 영웅 카드 탭 → 활성 영웅 라이브 교체 요청

var _hero_bar: Control
var _edit_panel: Panel

var _hp_bar: ProgressBar
var _score_label: Label
var _best_label: Label
var _coin_label: Label
var _result_panel: Panel
var _result_label: Label
var _pause_label: Label
var _paused := false

const SWIPE_MIN := 70.0   # 릴리스 시 이보다 짧은 드래그는 탭(전진)으로 처리
const DRAG_STEP := 110.0  # 누른 채 끄는 도중 이 거리를 넘으면 즉시 방향 hop + 기준점 재설정(연속 이동)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 HUD 동작
	_build_top_bar()
	_build_drag_hint()
	_build_hero_cards()
	_build_pause_overlay()
	_build_result_panel()

# ── 스타일 헬퍼 ────────────────────────────────────────────────
func _panel_style(bg: Color, radius: int, border_col: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_w > 0:
		sb.border_color = border_col
		sb.set_border_width_all(border_w)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.12, 0.10, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

# ── 노드 기반 아이콘 (OS 이모지 대체) ──────────────────────────
func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p

func _disc(cx: float, cy: float, r: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return _poly(pts, color)

# 금화 아이콘(겹친 디스크). pos 중심에 놓는다.
func _coin_icon(pos: Vector2, r: float) -> Node2D:
	var root := Node2D.new()
	root.position = pos
	root.add_child(_disc(0, 0, r, Color(0.78, 0.58, 0.15)))
	root.add_child(_disc(0, 0, r * 0.78, Color(1.0, 0.85, 0.30)))
	root.add_child(_disc(0, 0, r * 0.42, Color(0.85, 0.65, 0.18)))
	return root

# 역할 아이콘: 검(전사) / 하트(힐러) / 지팡이(마법사). h=대략 반높이(px).
func _role_icon(icon: String, h: float) -> Node2D:
	var root := Node2D.new()
	match icon:
		"sword":
			root.add_child(_poly(PackedVector2Array([
				Vector2(-0.12 * h, -h), Vector2(0.12 * h, -h),
				Vector2(0.17 * h, 0.30 * h), Vector2(-0.17 * h, 0.30 * h)]), Color(0.90, 0.93, 0.98)))
			root.add_child(_poly(PackedVector2Array([
				Vector2(-0.5 * h, 0.30 * h), Vector2(0.5 * h, 0.30 * h),
				Vector2(0.5 * h, 0.45 * h), Vector2(-0.5 * h, 0.45 * h)]), Color(0.88, 0.66, 0.20)))
			root.add_child(_poly(PackedVector2Array([
				Vector2(-0.10 * h, 0.45 * h), Vector2(0.10 * h, 0.45 * h),
				Vector2(0.10 * h, 0.90 * h), Vector2(-0.10 * h, 0.90 * h)]), Color(0.45, 0.30, 0.18)))
			root.add_child(_disc(0, 0.95 * h, 0.12 * h, Color(0.88, 0.66, 0.20)))
		"heart":
			var pts := PackedVector2Array()
			for i in 25:
				var t := TAU * float(i) / 24.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(Vector2(x / 16.0 * h, y / 16.0 * h * 0.9 - 0.08 * h))
			root.add_child(_poly(pts, Color(0.95, 0.42, 0.56)))
		"staff":
			root.add_child(_poly(PackedVector2Array([
				Vector2(-0.09 * h, -0.30 * h), Vector2(0.09 * h, -0.30 * h),
				Vector2(0.09 * h, 0.92 * h), Vector2(-0.09 * h, 0.92 * h)]), Color(0.52, 0.35, 0.20)))
			root.add_child(_disc(0, -0.52 * h, 0.32 * h, Color(0.45, 0.80, 1.0)))
			root.add_child(_disc(0, -0.52 * h, 0.18 * h, Color(0.88, 0.96, 1.0)))
	return root

# ── 상단 바 ────────────────────────────────────────────────────
func _build_top_bar() -> void:
	# 좌측: Guardian, HQ + HP바 + 레벨
	var left := Panel.new()
	left.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.20, 0.16, 0.78), 22))
	left.position = Vector2(28, 36)
	left.custom_minimum_size = Vector2(440, 150)
	left.size = Vector2(440, 150)
	add_child(left)

	var lv_badge := Panel.new()
	lv_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.72, 0.18), 30, Color(1, 1, 1, 0.9), 4))
	lv_badge.position = Vector2(16, 30)
	lv_badge.custom_minimum_size = Vector2(96, 96)
	lv_badge.size = Vector2(96, 96)
	left.add_child(lv_badge)
	var lv := _label("★\n80", 30, Color.WHITE)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lv_badge.add_child(lv)

	var title := _label("Guardian, HQ", 34, Color(0.96, 0.98, 0.92))
	title.position = Vector2(128, 22)
	left.add_child(title)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 5
	_hp_bar.value = 5
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(128, 80)
	_hp_bar.custom_minimum_size = Vector2(290, 40)
	_hp_bar.size = Vector2(290, 40)
	_hp_bar.add_theme_stylebox_override("background", _panel_style(Color(0.08, 0.10, 0.08, 0.9), 16))
	_hp_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.40, 0.85, 0.35), 16))
	left.add_child(_hp_bar)

	# 중앙: 큰 스코어 + BEST
	_score_label = _label("0", 120, Color(1, 1, 1))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 20
	_score_label.offset_bottom = 160
	add_child(_score_label)

	_best_label = _label("BEST 0", 38, Color(1, 0.92, 0.5))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_best_label.offset_top = 152
	_best_label.offset_bottom = 210
	add_child(_best_label)

	# 우측: 코인 + 일시정지
	var coin_pill := Panel.new()
	coin_pill.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.20, 0.16, 0.78), 24))
	coin_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coin_pill.offset_left = -260
	coin_pill.offset_right = -120
	coin_pill.offset_top = 40
	coin_pill.offset_bottom = 110
	add_child(coin_pill)
	coin_pill.add_child(_coin_icon(Vector2(34, 35), 22))  # 드로운 금화 아이콘(이모지 대체)
	_coin_label = _label("0", 36, Color(1, 0.86, 0.3))
	_coin_label.position = Vector2(62, 0)
	_coin_label.custom_minimum_size = Vector2(70, 70)
	_coin_label.size = Vector2(70, 70)
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_pill.add_child(_coin_label)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 40)
	pause_btn.add_theme_stylebox_override("normal", _panel_style(Color(0.30, 0.55, 0.95), 22))
	pause_btn.add_theme_stylebox_override("hover", _panel_style(Color(0.36, 0.62, 1.0), 22))
	pause_btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.46, 0.85), 22))
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -104
	pause_btn.offset_right = -28
	pause_btn.offset_top = 40
	pause_btn.offset_bottom = 116
	pause_btn.pressed.connect(_toggle_pause)
	add_child(pause_btn)

# ── 드래그 힌트 ────────────────────────────────────────────────
func _build_drag_hint() -> void:
	var hint := _label("↑ DRAG TO MOVE", 34, Color(1, 1, 1, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -360
	hint.offset_bottom = -300
	add_child(hint)

# ── 하단 영웅 카드 ─────────────────────────────────────────────
func _build_hero_cards() -> void:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -280
	bar.offset_bottom = -40
	add_child(bar)
	_hero_bar = bar

	# 편집 버튼 (좌하단) → 영웅 편성/레벨업 오버레이 토글
	var edit := Button.new()
	edit.text = "편집"
	edit.add_theme_font_size_override("font_size", 32)
	edit.add_theme_stylebox_override("normal", _panel_style(Color(0.20, 0.24, 0.20, 0.85), 18))
	edit.add_theme_stylebox_override("hover", _panel_style(Color(0.26, 0.30, 0.26, 0.9), 18))
	edit.add_theme_stylebox_override("pressed", _panel_style(Color(0.16, 0.20, 0.16, 0.9), 18))
	edit.position = Vector2(36, 150)
	edit.custom_minimum_size = Vector2(120, 90)
	edit.pressed.connect(_toggle_edit)
	bar.add_child(edit)

	_populate_hero_cards()

# 카드만 다시 그린다(편집 버튼은 유지). 활성 영웅이 바뀌면 호출해 하이라이트를 옮긴다.
func _populate_hero_cards() -> void:
	for c in _hero_bar.get_children():
		if c.has_meta("hero_card"):
			c.queue_free()
	var heroes := HeroRoster.all()
	var card_w := 230.0
	var gap := 24.0
	var total := card_w * heroes.size() + gap * (heroes.size() - 1)
	var start_x := (1080.0 - total) * 0.5
	var active := HeroRoster.active_index()
	for i in heroes.size():
		_make_hero_card(_hero_bar, heroes[i], i, start_x + float(i) * (card_w + gap), card_w, i == active)

func refresh_hero_cards() -> void:
	if _hero_bar != null:
		_populate_hero_cards()

# 생성된 영웅 카드 수(셀프테스트용). 카드마다 투명 탭 버튼이 1개 붙는다.
func hero_card_count() -> int:
	if _hero_bar == null:
		return 0
	var n := 0
	for c in _hero_bar.get_children():
		if c is Button and c.has_meta("hero_card"):
			n += 1
	return n

func _make_hero_card(parent: Control, hero, index: int, x: float, w: float, selected: bool) -> void:
	var card := Panel.new()
	card.set_meta("hero_card", true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 탭은 위의 투명 버튼이 처리
	var bg := Color(0.95, 0.93, 0.86, 0.96)
	var border_col := Color(0.30, 0.78, 0.40) if selected else Color(0.55, 0.50, 0.42)
	var border_w := 8 if selected else 3
	card.add_theme_stylebox_override("panel", _panel_style(bg, 22, border_col, border_w))
	card.position = Vector2(x, 40)
	card.custom_minimum_size = Vector2(w, 200)
	card.size = Vector2(w, 200)
	parent.add_child(card)

	# 상단 포트레이트: 렌더 이미지(portrait_path)가 있으면 띄우고, 없으면 역할 아이콘.
	var portrait := Panel.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	portrait.add_theme_stylebox_override("panel", _panel_style(hero.color.darkened(0.04), 16))
	portrait.position = Vector2(16, 16)
	portrait.custom_minimum_size = Vector2(w - 32, 110)
	portrait.size = Vector2(w - 32, 110)
	card.add_child(portrait)
	if hero.portrait_path != "" and ResourceLoader.exists(hero.portrait_path):
		var tex := TextureRect.new()
		tex.texture = load(hero.portrait_path)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(tex)
		var role_badge := _role_icon(hero.role_icon, 15.0)  # 이미지 위 작은 역할 배지
		role_badge.position = Vector2(24, 28)
		portrait.add_child(role_badge)
	else:
		var icon := _role_icon(hero.role_icon, 42.0)
		icon.position = Vector2((w - 32) / 2.0, 55.0)
		portrait.add_child(icon)

	var name_lbl := _label(hero.name, 36, Color(0.20, 0.18, 0.14))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_constant_override("outline_size", 0)
	name_lbl.position = Vector2(0, 132)
	name_lbl.custom_minimum_size = Vector2(w, 46)
	name_lbl.size = Vector2(w, 46)
	card.add_child(name_lbl)

	# 레벨 배지 (우상단)
	var lv := Panel.new()
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_theme_stylebox_override("panel", _panel_style(hero.badge_color, 18, Color.WHITE, 3))
	lv.position = Vector2(w - 56, 8)
	lv.custom_minimum_size = Vector2(48, 48)
	lv.size = Vector2(48, 48)
	card.add_child(lv)
	var lv_num := _label(str(hero.level), 28, Color.WHITE)
	lv_num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lv_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_num.add_theme_constant_override("outline_size", 0)
	lv.add_child(lv_num)

	if selected:
		var check := _label("✓", 36, Color(0.20, 0.70, 0.30))
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.position = Vector2(10, 4)
		check.add_theme_constant_override("outline_size", 0)
		card.add_child(check)

	# 카드 전체를 덮는 투명 탭 버튼 → 활성 영웅 교체 요청.
	var tap := Button.new()
	tap.set_meta("hero_card", true)
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.position = Vector2(x, 40)
	tap.custom_minimum_size = Vector2(w, 200)
	tap.size = Vector2(w, 200)
	tap.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		hero_selected.emit(index))
	parent.add_child(tap)

# ── 영웅 편성/레벨업 오버레이 (편집) ───────────────────────────
func _toggle_edit() -> void:
	AudioManager.sfx("button")
	if _edit_panel != null and is_instance_valid(_edit_panel):
		_edit_panel.queue_free()
		_edit_panel = null
		return
	_build_edit_panel()

func _hero_levelup_cost(level: int) -> int:
	return level * 12  # 레벨이 오를수록 비싸진다(누적 코인 소비처).

func _build_edit_panel() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.14, 0.12, 0.97), 28, Color(1, 1, 1, 0.5), 4))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -520
	panel.offset_bottom = 320
	add_child(panel)
	_edit_panel = panel

	var title := _label("영웅 편성", 56, Color(1, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	title.offset_bottom = 110
	panel.add_child(title)

	var coin_lbl := _label("보유 코인  %d" % SaveManager.get_total_coins(), 38, Color(1, 0.86, 0.3))
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	coin_lbl.offset_top = 120
	coin_lbl.offset_bottom = 175
	panel.add_child(coin_lbl)

	var heroes := HeroRoster.all()
	var active := HeroRoster.active_index()
	var row_y := 200.0
	for i in heroes.size():
		_build_edit_row(panel, heroes[i], i, i == active, row_y)
		row_y += 175.0

	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_size_override("font_size", 38)
	close.add_theme_stylebox_override("normal", _panel_style(Color(0.30, 0.55, 0.95), 18))
	close.add_theme_stylebox_override("hover", _panel_style(Color(0.36, 0.62, 1.0), 18))
	close.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.46, 0.85), 18))
	close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	close.offset_left = 290
	close.offset_right = 590
	close.offset_top = -110
	close.offset_bottom = -30
	close.pressed.connect(_toggle_edit)
	panel.add_child(close)

func _build_edit_row(panel: Panel, hero, index: int, selected: bool, y: float) -> void:
	var swatch := Panel.new()
	swatch.add_theme_stylebox_override("panel", _panel_style(hero.color, 14))
	swatch.position = Vector2(40, y)
	swatch.custom_minimum_size = Vector2(90, 90)
	swatch.size = Vector2(90, 90)
	panel.add_child(swatch)
	var sw_icon := _role_icon(hero.role_icon, 30.0)  # 색 블록 위 역할 아이콘
	sw_icon.position = Vector2(45, 45)
	swatch.add_child(sw_icon)

	var name_lbl := _label("%s   Lv %d" % [hero.name, hero.level], 40, Color(0.96, 0.96, 0.9))
	name_lbl.position = Vector2(150, y + 16)
	name_lbl.custom_minimum_size = Vector2(360, 56)
	panel.add_child(name_lbl)

	# 선택 버튼
	var sel := Button.new()
	sel.text = "사용중" if selected else "선택"
	sel.disabled = selected
	sel.add_theme_font_size_override("font_size", 32)
	sel.add_theme_stylebox_override("normal", _panel_style(Color(0.30, 0.70, 0.35) if not selected else Color(0.30, 0.40, 0.30), 16))
	sel.add_theme_stylebox_override("hover", _panel_style(Color(0.36, 0.78, 0.40), 16))
	sel.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.60, 0.30), 16))
	sel.add_theme_stylebox_override("disabled", _panel_style(Color(0.26, 0.34, 0.26), 16))
	sel.position = Vector2(520, y)
	sel.custom_minimum_size = Vector2(150, 88)
	sel.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		hero_selected.emit(index))
	panel.add_child(sel)

	# 레벨업 버튼 (누적 코인 소비)
	var cost := _hero_levelup_cost(hero.level)
	var up := Button.new()
	up.text = "레벨업\n%d 코인" % cost
	up.add_theme_font_size_override("font_size", 28)
	up.add_theme_stylebox_override("normal", _panel_style(Color(0.85, 0.62, 0.20), 16))
	up.add_theme_stylebox_override("hover", _panel_style(Color(0.92, 0.70, 0.26), 16))
	up.add_theme_stylebox_override("pressed", _panel_style(Color(0.70, 0.50, 0.16), 16))
	up.position = Vector2(690, y)
	up.custom_minimum_size = Vector2(160, 88)
	up.pressed.connect(func() -> void: _try_levelup(hero.id, cost))
	panel.add_child(up)

func _try_levelup(hero_id: String, cost: int) -> void:
	if SaveManager.get_total_coins() < cost:
		AudioManager.sfx("lose")  # 코인 부족
		return
	SaveManager.add_coins(-cost)
	SaveManager.commit()
	SaveManager.set_hero_level(hero_id, SaveManager.get_hero_level(hero_id) + 1)
	AudioManager.sfx("power_up")
	# 편집 패널 + 하단 카드 동시 갱신.
	if _edit_panel != null and is_instance_valid(_edit_panel):
		_edit_panel.queue_free()
		_edit_panel = null
		_build_edit_panel()
	refresh_hero_cards()

# ── 일시정지 ───────────────────────────────────────────────────
func _build_pause_overlay() -> void:
	_pause_label = _label("PAUSED", 90, Color(1, 1, 1))
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pause_label.offset_left = -300
	_pause_label.offset_right = 300
	_pause_label.offset_top = 700
	_pause_label.offset_bottom = 840
	_pause_label.visible = false
	add_child(_pause_label)

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_label.visible = _paused
	AudioManager.sfx("button")

# ── 결과 패널 ──────────────────────────────────────────────────
func _build_result_panel() -> void:
	_result_panel = Panel.new()
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.14, 0.12, 0.95), 28, Color(1, 1, 1, 0.5), 4))
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -360
	_result_panel.offset_right = 360
	_result_panel.offset_top = -220
	_result_panel.offset_bottom = 220
	add_child(_result_panel)

	_result_label = _label("", 64, Color.WHITE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_result_label.offset_top = 50
	_result_label.offset_bottom = 150
	_result_panel.add_child(_result_label)

	var retry := Button.new()
	retry.text = "RETRY"
	retry.add_theme_font_size_override("font_size", 40)
	retry.add_theme_stylebox_override("normal", _panel_style(Color(0.30, 0.70, 0.35), 18))
	retry.add_theme_stylebox_override("hover", _panel_style(Color(0.36, 0.78, 0.40), 18))
	retry.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.60, 0.30), 18))
	retry.position = Vector2(70, 250)
	retry.custom_minimum_size = Vector2(250, 90)
	retry.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		if _paused:
			_toggle_pause()
		retry_pressed.emit())
	_result_panel.add_child(retry)

	var menu := Button.new()
	menu.text = "STAGE"
	menu.add_theme_font_size_override("font_size", 40)
	menu.add_theme_stylebox_override("normal", _panel_style(Color(0.30, 0.55, 0.95), 18))
	menu.add_theme_stylebox_override("hover", _panel_style(Color(0.36, 0.62, 1.0), 18))
	menu.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.46, 0.85), 18))
	menu.position = Vector2(400, 250)
	menu.custom_minimum_size = Vector2(250, 90)
	menu.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		menu_pressed.emit())
	_result_panel.add_child(menu)

# ── 입력 (스와이프/탭) ─────────────────────────────────────────
var _swipe_active := false
var _swipe_moved := false
var _swipe_start := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if _paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_active = true
			_swipe_moved = false
			_swipe_start = event.position
		elif _swipe_active:
			_swipe_active = false
			if not _swipe_moved:
				_resolve_gesture(event.position - _swipe_start)  # 탭 또는 짧은 스와이프(릴리스)
	elif event is InputEventScreenDrag and _swipe_active:
		# 누른 채 충분히 끌면 즉시 방향 hop을 내고 기준점을 옮긴다 → 끌고 있는 동안 연속 이동.
		# (Player.try_hop이 hop 쿨다운으로 과다 입력을 막아준다.)
		var drag := event as InputEventScreenDrag
		var d := drag.position - _swipe_start
		if d.length() >= DRAG_STEP:
			_emit_dir(d)
			_swipe_start = drag.position
			_swipe_moved = true

func _resolve_gesture(delta: Vector2) -> void:
	if delta.length() < SWIPE_MIN:
		hop_requested.emit(Vector2i(0, 1))  # 탭 = 전진
		return
	_emit_dir(delta)

func _emit_dir(delta: Vector2) -> void:
	# 카메라가 +z를 바라보므로 화면 좌우와 월드 x축이 반대다.
	if absf(delta.x) > absf(delta.y):
		hop_requested.emit(Vector2i(-1, 0) if delta.x > 0.0 else Vector2i(1, 0))
	else:
		hop_requested.emit(Vector2i(0, 1) if delta.y < 0.0 else Vector2i(0, -1))

# ── 외부 갱신 API ──────────────────────────────────────────────
func set_health(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp

func set_score(score: int, best: int) -> void:
	_score_label.text = str(score)
	_best_label.text = "BEST %d" % best

func set_coins(n: int) -> void:
	_coin_label.text = str(n)

func show_result(title: String, color: Color) -> void:
	_result_label.text = title
	_result_label.add_theme_color_override("font_color", color)
	_result_panel.visible = true

func hide_result() -> void:
	_result_panel.visible = false
