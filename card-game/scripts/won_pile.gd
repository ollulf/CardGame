extends Node2D
class_name WonPile

const LAYER_STEP := Vector2(0, -4)
const MAX_LAYERS := 5
const BUMP_TIME := 0.2
const RETURN_STAGGER := 0.08
const MAX_JITTER := 3.0

var pile_owner: Card.Owner = Card.Owner.HUMAN
var count: int = 0
var badge_alpha: float = 1.0:
	set(value):
		badge_alpha = value
		if _badge != null:
			_badge.modulate.a = value

var _stack: Node2D
var _badge: Label
var _layers: Array[Bierdeckel] = []
var _bump_tween: Tween
var _tooltip: Label


func _ready() -> void:
	add_to_group(GameManager.WON_PILE_GROUP)
	_stack = Node2D.new()
	add_child(_stack)
	for i in MAX_LAYERS:
		var coaster := Bierdeckel.new()
		_stack.add_child(coaster)
		TableShadow.add_to(coaster)
		_layers.append(coaster)
		_scatter(i)
	_badge = Label.new()
	_badge.z_index = 5
	_badge.position = Vector2(-16, Bierdeckel.RADIUS_PX + 6.0)
	_badge.size = Vector2(32, 22)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_badge.add_theme_font_size_override("font_size", InteractionManager.font_px(13))
	var style := StyleBoxFlat.new()
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.bg_color = Color(0.08, 0.07, 0.07, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.2)
	_badge.add_theme_stylebox_override("normal", style)
	_badge.modulate.a = badge_alpha
	add_child(_badge)
	_tooltip = Label.new()
	_tooltip.z_index = 10
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_tooltip.add_theme_font_size_override("font_size", InteractionManager.font_px(13))
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.08, 0.07, 0.07, 0.92)
	tip_style.set_border_width_all(2)
	tip_style.border_color = Color(0.85, 0.8, 0.7)
	tip_style.content_margin_left = 10
	tip_style.content_margin_right = 10
	tip_style.content_margin_top = 6
	tip_style.content_margin_bottom = 6
	_tooltip.add_theme_stylebox_override("normal", tip_style)
	_tooltip.visible = false
	add_child(_tooltip)
	_refresh()


func _scatter(i: int) -> void:
	var coaster := _layers[i]
	if i == 0:
		coaster.position = Vector2.ZERO
		return
	coaster.position = LAYER_STEP * float(i) + Vector2(randf_range(-MAX_JITTER, MAX_JITTER), randf_range(-MAX_JITTER, MAX_JITTER) * 0.5)


func _process(_delta: float) -> void:
	var r := Bierdeckel.RADIUS_PX + 4.0
	var mouse := to_local(get_global_mouse_position())
	var over := Rect2(-r, -r - 20.0, r * 2.0, r * 2.0 + 20.0).has_point(mouse)
	var active := over and is_visible_in_tree() and badge_alpha > 0.5
	_tooltip.visible = active
	if active:
		_tooltip.text = "Won turns: %d" % count
		_tooltip.position = Vector2(-_tooltip.size.x * 0.5, -r - 20.0 - _tooltip.size.y - 6.0)


func top_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count, 0, MAX_LAYERS - 1))


func add_turn() -> void:
	count += 1
	if count <= MAX_LAYERS:
		_scatter(count - 1)
	_refresh()
	if _bump_tween != null:
		_bump_tween.kill()
	_badge.pivot_offset = _badge.size * 0.5
	_bump_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bump_tween.tween_property(_badge, "scale", Vector2.ONE * 1.4, BUMP_TIME * 0.5)
	_bump_tween.tween_property(_badge, "scale", Vector2.ONE, BUMP_TIME)


func clear(animate: bool) -> void:
	var stack: BierdeckelStack = get_tree().get_first_node_in_group(BierdeckelStack.GROUP)
	var shown := mini(count, MAX_LAYERS)
	var froms: Array[Vector2] = []
	for i in range(shown - 1, -1, -1):
		froms.append(_layers[i].global_position)
	count = 0
	_refresh()
	if stack == null:
		return
	if not animate:
		stack.reset()
		return
	for i in froms.size():
		_return_coaster(stack, froms[i], i * RETURN_STAGGER)


func _return_coaster(stack: BierdeckelStack, from: Vector2, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	var slot := stack.next_slot_position()
	await Bierdeckel.fly(get_parent(), from, slot)
	stack.return_one()


func _refresh() -> void:
	if _stack == null:
		return
	for i in _layers.size():
		_layers[i].visible = i < count
	_badge.text = str(count)
