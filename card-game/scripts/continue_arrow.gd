extends Control
class_name ContinueArrow

signal clicked

var _time := 0.0
var angle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(5.0, 3.0), angle, Vector2.ONE)
	SpeechBubble.draw_arrow(self, Vector2(-5.0, -3.0), _time)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	InteractionManager.skip_next_double_click()
	clicked.emit()
