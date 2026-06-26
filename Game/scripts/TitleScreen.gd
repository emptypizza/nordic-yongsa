extends CanvasLayer

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "GRAIL ESCORT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.custom_minimum_size = Vector2(600, 80)
	title.size = Vector2(600, 80)
	title.position = Vector2(-300, -200)
	add_child(title)

	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(300, 90)
	start.size = Vector2(300, 90)
	start.set_anchors_preset(Control.PRESET_CENTER)
	start.position = Vector2(-150, -45)
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://StageSelect.tscn"))
	add_child(start)
