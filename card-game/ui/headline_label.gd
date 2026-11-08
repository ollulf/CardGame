class_name HeadlineLabel
extends Label

const TICK_SIZE := Vector2(28, 3)
const TICK_COLOR := Color("ffcf6e")


func _ready() -> void:
	theme_type_variation = &"HeadlineLabel"
	uppercase = true
	resized.connect(queue_redraw)


func _draw() -> void:
	var x := 0.0
	if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - TICK_SIZE.x) * 0.5
	elif horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - TICK_SIZE.x
	draw_rect(Rect2(Vector2(x, size.y - TICK_SIZE.y), TICK_SIZE), TICK_COLOR)
