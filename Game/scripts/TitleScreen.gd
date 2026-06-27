extends CanvasLayer

# 타이틀 화면. 게임명 + START + 사운드 토글. 인게임 HUD 톤(MenuUI)으로 통일.
# 로비 BGM을 재생한다(게임 진입 시 AudioManager가 gameplay로 교체).

var _sound_btn: Button

func _ready() -> void:
	AudioManager.play_bgm("lobby")
	MenuUI.gradient_bg(self, Color(0.20, 0.34, 0.46), Color(0.52, 0.68, 0.52))

	# 게임명(2단) + 부제.
	var title := MenuUI.label("길건너 용사들", 132, Color(1, 0.95, 0.66))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 430
	title.offset_bottom = 620
	add_child(title)

	var subtitle := MenuUI.label("GRAIL  ESCORT", 56, Color(0.92, 0.96, 1.0, 0.92))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 640
	subtitle.offset_bottom = 720
	add_child(subtitle)

	# 최고 기록 표시(있으면).
	var best := SaveManager.get_best()
	if best > 0:
		var best_lbl := MenuUI.label("⚔ BEST %d" % best, 44, Color(1, 0.88, 0.5))
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		best_lbl.offset_top = 760
		best_lbl.offset_bottom = 820
		add_child(best_lbl)

	# START
	var start := MenuUI.button(self, "START", 70, MenuUI.GREEN)
	start.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	start.offset_left = -300
	start.offset_right = 300
	start.offset_top = 120
	start.offset_bottom = 260
	start.pressed.connect(func() -> void:
		AudioManager.sfx("button")
		get_tree().change_scene_to_file("res://StageSelect.tscn"))

	# 사운드 토글(우상단).
	_sound_btn = MenuUI.button(self, _sound_glyph(), 34, MenuUI.BLUE)
	_sound_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_sound_btn.offset_left = -330
	_sound_btn.offset_right = -40
	_sound_btn.offset_top = 50
	_sound_btn.offset_bottom = 150
	_sound_btn.pressed.connect(_toggle_sound)

func _sound_glyph() -> String:
	return "BGM OFF" if AudioManager.is_muted() else "BGM ON"

func _toggle_sound() -> void:
	AudioManager.toggle_muted()
	AudioManager.sfx("button")
	_sound_btn.text = _sound_glyph()
	if not AudioManager.is_muted():
		AudioManager.play_bgm("lobby")
