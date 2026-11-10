extends CanvasLayer

enum Style { WIPE, CURTAINS, SLANT }

const TRANSITION_LAYER := 110
const SLANT_RATIO := 0.35
const PARALLAX_SHIFT := 28.0

@export var style: Style = Style.WIPE
@export var cover_time := 0.22
@export var hold_time := 0.06
@export var uncover_time := 0.22
@export var color := Color.BLACK

var _blocker: Control
var _bars: Array[CanvasItem] = []
var _running := false


func _ready() -> void:
	layer = TRANSITION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_set_active(false)


func is_running() -> bool:
	return _running


func play(midpoint: Callable, reverse := false, from_layer: CanvasLayer = null, to_layer: CanvasLayer = null) -> void:
	if _running:
		return
	_running = true
	_set_active(true)
	var size := _blocker.get_viewport_rect().size
	var dir := -1.0 if reverse else 1.0
	_build_bars(size)
	_place_bars(0.0, size, dir)

	var cover := create_tween().set_parallel(true)
	cover.tween_method(_place_bars.bind(size, dir), 0.0, 1.0, cover_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if style == Style.SLANT:
		cover.tween_method(_set_layer_shift.bind(from_layer), 0.0, PARALLAX_SHIFT * dir, cover_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await cover.finished

	if style == Style.SLANT:
		_set_layer_shift(0.0, from_layer)
		_set_layer_shift(-PARALLAX_SHIFT * dir, to_layer)
	await midpoint.call()
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time, true, false, true).timeout

	var uncover := create_tween().set_parallel(true)
	uncover.tween_method(_place_bars.bind(size, dir), 1.0, 2.0, uncover_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if style == Style.SLANT:
		uncover.tween_method(_set_layer_shift.bind(to_layer), -PARALLAX_SHIFT * dir, 0.0, uncover_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await uncover.finished

	if style == Style.SLANT:
		_set_layer_shift(0.0, to_layer)
	_set_active(false)
	_running = false


func _set_active(active: bool) -> void:
	visible = active
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _build_bars(size: Vector2) -> void:
	for bar in _bars:
		bar.queue_free()
	_bars.clear()
	match style:
		Style.WIPE:
			_bars.append(_make_rect(Vector2(size.x + 2.0, size.y)))
		Style.CURTAINS:
			_bars.append(_make_rect(Vector2(size.x * 0.5 + 1.0, size.y)))
			_bars.append(_make_rect(Vector2(size.x * 0.5 + 1.0, size.y)))
		Style.SLANT:
			var slant := size.y * SLANT_RATIO
			var poly := Polygon2D.new()
			poly.color = color
			poly.polygon = PackedVector2Array([
				Vector2(slant, 0.0),
				Vector2(size.x + slant * 2.0, 0.0),
				Vector2(size.x + slant, size.y),
				Vector2(0.0, size.y),
			])
			_blocker.add_child(poly)
			_bars.append(poly)


func _make_rect(rect_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = rect_size
	_blocker.add_child(rect)
	return rect


func _place_bars(t: float, size: Vector2, dir: float) -> void:
	match style:
		Style.WIPE:
			var x := (t - 1.0) * (size.x + 2.0)
			_bars[0].position = Vector2(x if dir > 0.0 else -x, 0.0)
		Style.CURTAINS:
			var closed := 1.0 - absf(t - 1.0)
			var w := size.x * 0.5 + 1.0
			_bars[0].position = Vector2(-w + closed * w, 0.0)
			_bars[1].position = Vector2(size.x - closed * w, 0.0)
		Style.SLANT:
			var slant := size.y * SLANT_RATIO
			var span := size.x + slant * 2.0
			var x := (t - 1.0) * span - slant
			if dir > 0.0:
				_bars[0].position = Vector2(x, 0.0)
				_bars[0].scale = Vector2.ONE
			else:
				_bars[0].position = Vector2(size.x - x, 0.0)
				_bars[0].scale = Vector2(-1.0, 1.0)


func _set_layer_shift(shift: float, target: CanvasLayer) -> void:
	if target:
		target.offset = Vector2(shift, 0.0)
	else:
		var viewport := get_tree().root
		var xform := viewport.canvas_transform
		xform.origin = Vector2(shift, 0.0)
		viewport.canvas_transform = xform
