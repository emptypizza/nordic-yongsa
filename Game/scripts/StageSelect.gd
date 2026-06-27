extends CanvasLayer

# 스테이지 선택. StageState의 스테이지 목록을 카드로 보여주고, SaveManager의 해금
# 상태에 따라 잠금/해제한다. 선택 시 StageState.select() 후 Main으로 전환.
# 비주얼은 인게임 HUD와 같은 따뜻한 팔레트·라운드 패널·아웃라인 텍스트로 통일(MenuUI).

func _ready() -> void:
	AudioManager.play_bgm("lobby")
	MenuUI.gradient_bg(self, Color(0.18, 0.30, 0.20), Color(0.40, 0.58, 0.42))

	MenuUI.heading(self, "스테이지 선택", 130)

	# 상단 진행 요약(최고 기록 / 누적 코인).
	var summary := MenuUI.label("BEST %d        코인 %d" % [SaveManager.get_best(), SaveManager.get_total_coins()], 40, Color(1, 0.92, 0.6))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	summary.offset_top = 250
	summary.offset_bottom = 310
	add_child(summary)

	var unlocked := SaveManager.get_unlocked_stage()
	var y := 480.0
	for i in StageState.count():
		_make_stage_card(i, i <= unlocked, y)
		y += 280.0

	var back := MenuUI.button(self, "◀ 타이틀", 44, MenuUI.BLUE)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back.offset_left = 340
	back.offset_right = 740
	back.offset_top = -180
	back.offset_bottom = -80
	back.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		get_tree().change_scene_to_file("res://Title.tscn"))

func _make_stage_card(index: int, unlocked: bool, y: float) -> void:
	var btn := Button.new()
	btn.disabled = not unlocked
	var label := "%d.  %s" % [index + 1, StageState.stage_name(index)]
	if not unlocked:
		label = "[ 잠김 ]  " + StageState.stage_name(index)
	btn.text = label
	btn.add_theme_font_size_override("font_size", 56)
	btn.add_theme_color_override("font_color", Color(0.98, 0.98, 0.92))
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.68))
	var base := MenuUI.GREEN if unlocked else Color(0.30, 0.34, 0.30)
	btn.add_theme_stylebox_override("normal", MenuUI.box(base, 26, Color(1, 1, 1, 0.5), 4))
	btn.add_theme_stylebox_override("hover", MenuUI.box(base.lightened(0.1), 26, Color(1, 1, 1, 0.7), 4))
	btn.add_theme_stylebox_override("pressed", MenuUI.box(base.darkened(0.15), 26))
	btn.add_theme_stylebox_override("disabled", MenuUI.box(Color(0.24, 0.28, 0.24, 0.9), 26, Color(0.5, 0.5, 0.5, 0.4), 3))
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	btn.offset_left = 140
	btn.offset_right = -140
	btn.offset_top = y
	btn.offset_bottom = y + 200
	if unlocked:
		btn.pressed.connect(func() -> void:
			AudioManager.sfx("button")
			StageState.select(index)
			get_tree().change_scene_to_file("res://Main.tscn"))
	add_child(btn)
