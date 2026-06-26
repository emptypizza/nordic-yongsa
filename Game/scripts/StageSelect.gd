extends CanvasLayer

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.16, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "STAGE SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.custom_minimum_size = Vector2(600, 80)
	title.size = Vector2(600, 80)
	title.position = Vector2(-300, -200)
	add_child(title)

	var stage := Button.new()
	stage.text = "STAGE 1"
	stage.custom_minimum_size = Vector2(300, 90)
	stage.size = Vector2(300, 90)
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.position = Vector2(-150, -45)
	stage.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://Main.tscn"))
	add_child(stage)
