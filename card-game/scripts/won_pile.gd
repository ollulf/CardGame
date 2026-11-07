extends Node2D
class_name WonPile

const CARD_BACK := preload("res://sprites/card_Background.png")
const CARD_SCALE := 3.0
const LAYER_STEP := Vector2(0, -3)
const MAX_LAYERS := 5
const BUMP_TIME := 0.2
const CLEAR_TIME := 0.45
const CLEAR_STAGGER := 0.06

var pile_owner: Card.Owner = Card.Owner.HUMAN
var count: int = 0

var _stack: Node2D
var _badge: Label
var _layers: Array[Sprite2D] = []
var _bump_tween: Tween


func _ready() -> void:
	add_to_group(GameManager.WON_PILE_GROUP)
	_stack = Node2D.new()
	add_child(_stack)
	for i in MAX_LAYERS:
		var sprite := Sprite2D.new()
		sprite.texture = CARD_BACK
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)
		sprite.position = LAYER_STEP * float(i)
		_stack.add_child(sprite)
		_layers.append(sprite)
	_badge = Label.new()
	_badge.z_index = 5
	_badge.position = Vector2(-16, 38)
	_badge.size = Vector2(32, 22)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_badge.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.bg_color = Color(0.08, 0.07, 0.07, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.2)
	_badge.add_theme_stylebox_override("normal", style)
	add_child(_badge)
	_refresh()


func top_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count, 0, MAX_LAYERS - 1))


func add_turn() -> void:
	count += 1
	_refresh()
	if _bump_tween != null:
		_bump_tween.kill()
	_badge.pivot_offset = _badge.size * 0.5
	_bump_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bump_tween.tween_property(_badge, "scale", Vector2.ONE * 1.4, BUMP_TIME * 0.5)
	_bump_tween.tween_property(_badge, "scale", Vector2.ONE, BUMP_TIME)


func clear(animate: bool) -> void:
	if animate and count > 0:
		var top := get_viewport().get_visible_rect().position.y - 120.0
		for i in mini(count, MAX_LAYERS):
			var card := Sprite2D.new()
			card.texture = CARD_BACK
			card.scale = Vector2(CARD_SCALE, CARD_SCALE)
			card.global_position = _layers[i].global_position
			card.z_index = 20
			get_parent().add_child(card)
			var tween := card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(card, "global_position:y", top, CLEAR_TIME).set_delay(i * CLEAR_STAGGER)
			tween.tween_callback(card.queue_free)
	count = 0
	_refresh()


func _refresh() -> void:
	if _stack == null:
		return
	for i in _layers.size():
		_layers[i].visible = i < maxi(count, 1)
	_stack.modulate = Color(1, 1, 1, 0.25) if count == 0 else Color.WHITE
	_badge.text = str(count)
