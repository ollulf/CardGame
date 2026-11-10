extends Node2D
class_name GraveyardPile

const GROUP := "graveyard_piles"
const CARD_BACK := preload("res://sprites/card_backside.png")
const CARD_SCALE := 3.0
const LAYER_STEP := Vector2(0, -3)
const CARDS_PER_LAYER := 3
const MAX_LAYERS := 5
const MAX_TILT := deg_to_rad(6.0)
const MAX_JITTER := 3.0

var pile_owner: Card.Owner = Card.Owner.HUMAN
var count: int = 0

var _layers: Array[Sprite2D] = []
var _tooltip: Label


func _ready() -> void:
	add_to_group(GROUP)
	for i in MAX_LAYERS:
		var sprite := Sprite2D.new()
		sprite.texture = CARD_BACK
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)
		sprite.modulate = Color(0.8, 0.78, 0.75)
		if i > 0:
			sprite.rotation = randf_range(-MAX_TILT, MAX_TILT)
			sprite.position = LAYER_STEP * float(i) + Vector2(randf_range(-MAX_JITTER, MAX_JITTER), 0)
		add_child(sprite)
		_layers.append(sprite)
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
	_tooltip.visible = false
	add_child(_tooltip)
	_refresh()


func _process(_delta: float) -> void:
	var half := CARD_BACK.get_size() * CARD_SCALE * 0.5
	var mouse := to_local(get_global_mouse_position())
	var over := Rect2(-half.x, -half.y - 15.0, half.x * 2.0, half.y * 2.0 + 15.0).has_point(mouse)
	var active := over and is_visible_in_tree() and count > 0
	_tooltip.visible = active
	if active:
		_tooltip.text = "Played cards: %d" % count
		_tooltip.position = Vector2(-_tooltip.size.x * 0.5, -half.y - 15.0 - _tooltip.size.y - 6.0)


func top_position() -> Vector2:
	return global_position + LAYER_STEP * float(_shown_layers(count + 1) - 1)


func add_cards(amount: int) -> void:
	count += amount
	_refresh()


func clear() -> void:
	count = 0
	_refresh()


func _shown_layers(cards: int) -> int:
	return clampi(ceili(float(cards) / CARDS_PER_LAYER), 1, MAX_LAYERS)


func _refresh() -> void:
	if _layers.is_empty():
		return
	var shown := _shown_layers(count)
	for i in _layers.size():
		_layers[i].visible = count > 0 and i < shown
