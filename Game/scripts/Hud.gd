class_name Hud
extends CanvasLayer

signal hop_requested(dir: Vector2i)
signal retry_pressed
signal menu_pressed

var _hp_bar: ProgressBar
var _hp_label: Label
var _stage_label: Label
var _result_panel: Panel
var _result_label: Label

func _ready() -> void:
	_build_top_bar()
	_build_result_panel()
	_build_dpad()

func _build_top_bar() -> void:
	_stage_label = Label.new()
	_stage_label.text = "STAGE 1"
	_stage_label.position = Vector2(16, 12)
	add_child(_stage_label)

	_hp_label = Label.new()
	_hp_label.text = "5 / 5"
	_hp_label.position = Vector2(16, 36)
	add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 5
	_hp_bar.value = 5
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(90, 36)
	_hp_bar.custom_minimum_size = Vector2(180, 18)
	add_child(_hp_bar)

func _build_result_panel() -> void:
	_result_panel = Panel.new()
	_result_panel.visible = false
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(320, 160)
	_result_panel.position = Vector2(-160, -80)
	add_child(_result_panel)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_result_label.position = Vector2(0, 24)
	_result_panel.add_child(_result_label)

	var retry := Button.new()
	retry.text = "RETRY"
	retry.custom_minimum_size = Vector2(120, 40)
	retry.position = Vector2(24, 96)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	_result_panel.add_child(retry)

	var menu := Button.new()
	menu.text = "STAGE SELECT"
	menu.custom_minimum_size = Vector2(150, 40)
	menu.position = Vector2(150, 96)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_result_panel.add_child(menu)

const DPAD_BTN := 144.0  # 3x of the old 48px button
const DPAD_FONT := 64
const DPAD_MARGIN := 36.0
const SWIPE_MIN := 80.0  # min drag (design px) to count as a swipe; shorter = tap

var _swipe_active := false
var _swipe_start := Vector2.ZERO

func _build_dpad() -> void:
	# 모바일/마우스용 가상 d-pad (좌하단, 3배 크기 십자 배치). 같은 4방향 hop을 발생.
	var c := DPAD_MARGIN
	var s := DPAD_BTN
	# 십자 배치: 가운데 열(상/하), 가운데 행(좌/우). bottom-left 앵커, y는 위로 갈수록 음수.
	_add_dpad_button("▲", Vector2(c + s, -(c + 3 * s)), Vector2i(0, 1))
	_add_dpad_button("◀", Vector2(c, -(c + 2 * s)), Vector2i(1, 0))
	_add_dpad_button("▶", Vector2(c + 2 * s, -(c + 2 * s)), Vector2i(-1, 0))
	_add_dpad_button("▼", Vector2(c + s, -(c + s)), Vector2i(0, -1))

func _add_dpad_button(text: String, offset: Vector2, dir: Vector2i) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(DPAD_BTN, DPAD_BTN)
	btn.add_theme_font_size_override("font_size", DPAD_FONT)
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.position = offset
	btn.pivot_offset = Vector2(DPAD_BTN, DPAD_BTN) * 0.5  # center pivot for punch scale
	btn.pressed.connect(func() -> void: hop_requested.emit(dir))
	btn.button_down.connect(func() -> void: _punch(btn))
	add_child(btn)

func _punch(node: Control) -> void:
	# 누를 때 살짝 줄었다 돌아오는 쥬이시 피드백.
	node.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(0.86, 0.86), 0.05).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	# Crossy Road식 스와이프/탭. d-pad 버튼은 자체 입력을 소비하므로 빈 화면에서만 동작.
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_active = true
			_swipe_start = event.position
		elif _swipe_active:
			_swipe_active = false
			_resolve_gesture(event.position - _swipe_start)

func _resolve_gesture(delta: Vector2) -> void:
	if delta.length() < SWIPE_MIN:
		hop_requested.emit(Vector2i(0, 1))  # 탭 = 전진
		return
	if absf(delta.x) > absf(delta.y):
		hop_requested.emit(Vector2i(-1, 0) if delta.x > 0.0 else Vector2i(1, 0))
	else:
		hop_requested.emit(Vector2i(0, 1) if delta.y < 0.0 else Vector2i(0, -1))

func set_health(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]

func show_result(title: String, color: Color) -> void:
	_result_label.text = title
	_result_label.add_theme_color_override("font_color", color)
	_result_panel.visible = true

func hide_result() -> void:
	_result_panel.visible = false
