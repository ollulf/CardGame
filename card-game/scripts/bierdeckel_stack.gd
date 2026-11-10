extends Node2D
class_name BierdeckelStack

const GROUP := "bierdeckel_stack"
const TOTAL := 5
const LAYER_STEP := Vector2(0, -3)
const MAX_JITTER := 2.0

var count: int = TOTAL

var _layers: Array[Bierdeckel] = []
var _tooltip: Label


func _ready() -> void:
	add_to_group(GROUP)
	for i in TOTAL:
		var coaster := Bierdeckel.new()
		coaster.position = LAYER_STEP * float(i) + Vector2(randf_range(-MAX_JITTER, MAX_JITTER), 0)
		add_child(coaster)
		_layers.append(coaster)
	_tooltip = Label.new()
	_tooltip.z_index = 10
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_tooltip.add_theme_font_size_override("font_size", InteractionManager.font_px(13))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.07, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.8, 0.7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_tooltip.add_theme_stylebox_override("normal", style)
	_tooltip.text = "Bierdeckel: one for each turn won"
	_tooltip.visible = false
	add_child(_tooltip)
	_refresh()


func _process(_delta: float) -> void:
	var r := Bierdeckel.RADIUS_PX + 6.0
	var mouse := to_local(get_global_mouse_position())
	var active := Rect2(-r, -r - 15.0, r * 2.0, r * 2.0 + 15.0).has_point(mouse) and is_visible_in_tree()
	_tooltip.visible = active
	if active:
		_tooltip.position = Vector2(-_tooltip.size.x * 0.5, r + 4.0)


func top_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count - 1, 0, TOTAL - 1))


func next_slot_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count, 0, TOTAL - 1))


func take() -> Vector2:
	var from := top_position()
	count = maxi(count - 1, 0)
	_refresh()
	return from


func return_one() -> void:
	count = mini(count + 1, TOTAL)
	_refresh()


func reset() -> void:
	count = TOTAL
	_refresh()


func _refresh() -> void:
	for i in _layers.size():
		_layers[i].visible = i < count
