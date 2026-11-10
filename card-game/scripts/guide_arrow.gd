extends Control
class_name GuideArrow

const ARROW_SCALE := 3.0
const GAP := 6.0

var target: CanvasItem
var from_left := false

var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		hide()
		return
	var rect := _target_rect()
	if from_left:
		position = Vector2(rect.position.x - GAP, rect.get_center().y)
	else:
		position = Vector2(rect.get_center().x, rect.position.y - GAP)
	show()
	queue_redraw()

func _target_rect() -> Rect2:
	var xform := target.get_global_transform_with_canvas()
	if target is Control:
		return xform * Rect2(Vector2.ZERO, (target as Control).size)
	if target is Sprite2D:
		return xform * (target as Sprite2D).get_rect()
	return Rect2(xform.origin, Vector2.ZERO)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, -PI / 2.0 if from_left else 0.0, Vector2(ARROW_SCALE, ARROW_SCALE))
	SpeechBubble.draw_arrow(self, Vector2(-5, -8), _time)
