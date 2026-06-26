extends Node

const DESIGN_WIDTH := 1080
const DESIGN_HEIGHT := 1920
const MIN_WIDTH := 360
const MIN_HEIGHT := 640
const TARGET_USABLE_HEIGHT_RATIO := 0.9
const MAX_USABLE_WIDTH_RATIO := 0.95
const ASPECT_RATIO := float(DESIGN_WIDTH) / float(DESIGN_HEIGHT)

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return

	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return

	var max_width := maxi(1, floori(usable.size.x * MAX_USABLE_WIDTH_RATIO))
	var max_height := maxi(1, floori(usable.size.y * TARGET_USABLE_HEIGHT_RATIO))
	var height := max_height
	var width := roundi(height * ASPECT_RATIO)

	if width > max_width:
		width = max_width
		height = roundi(width / ASPECT_RATIO)

	if max_width >= MIN_WIDTH and max_height >= MIN_HEIGHT and (width < MIN_WIDTH or height < MIN_HEIGHT):
		width = MIN_WIDTH
		height = MIN_HEIGHT

	var size := Vector2i(width, height)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
