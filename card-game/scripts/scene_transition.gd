extends CanvasLayer

const TRANSITION_LAYER := 110

@export var cover_time := 0.22
@export var hold_time := 0.06
@export var uncover_time := 0.22
@export var color := Color.BLACK

var _blocker: Control
var _bar: ColorRect
var _running := false


func _ready() -> void:
	layer = TRANSITION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_bar = ColorRect.new()
	_bar.color = color
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocker.add_child(_bar)
	_set_active(false)


func is_running() -> bool:
	return _running


func play(midpoint: Callable, reverse := false) -> void:
	if _running:
		return
	_running = true
	_set_active(true)
	var size := _blocker.get_viewport_rect().size
	var dir := -1.0 if reverse else 1.0
	_bar.size = Vector2(size.x + 2.0, size.y)
	_place(0.0, size.x, dir)

	var cover := create_tween()
	cover.tween_method(_place.bind(size.x, dir), 0.0, 1.0, cover_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await cover.finished

	await midpoint.call()
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time, true, false, true).timeout

	var uncover := create_tween()
	uncover.tween_method(_place.bind(size.x, dir), 1.0, 2.0, uncover_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await uncover.finished

	_set_active(false)
	_running = false


func _set_active(active: bool) -> void:
	visible = active
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _place(t: float, width: float, dir: float) -> void:
	var x := (t - 1.0) * (width + 2.0)
	_bar.position = Vector2(x if dir > 0.0 else -x, 0.0)
