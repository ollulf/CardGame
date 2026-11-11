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
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not is_click and not event.is_action_pressed("ui_accept", false, true):
		return
	get_viewport().set_input_as_handled()
	InteractionManager.skip_next_double_click()
	clicked.emit()
