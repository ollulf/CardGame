extends Node2D
class_name TrumpDisplay

const GROUP := "trump_display"
const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARD_SIZE := Vector2(60, 90)
const TOP_MARGIN := 0.0
const LABEL_GAP := 4.0
const LABEL_FONT_SIZE := 16
const LABEL_COLOR := Color(1.0, 0.85, 0.3)
const LABEL_OUTLINE_COLOR := Color(0.15, 0.1, 0.0)
const DROP_DISTANCE := 40.0
const REVEAL_TIME := 0.5
const SPIN_HALF_TIMES := [0.07, 0.08, 0.09, 0.11, 0.14, 0.18, 0.23, 0.3]
const LAND_HALF_TIME := 0.4
const SWAP_POP_SCALE := 1.15
const SWAP_POP_TIME := 0.15

var _root: Control
var _holder: Control
var _label: Label
var _card_visual: CardVisual
var _tween: Tween
var _spin_tween: Tween
var _final_suit: Card.Suit

func _ready() -> void:
	add_to_group(GROUP)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_label = Label.new()
	_label.text = "Trump"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.add_theme_color_override("font_outline_color", LABEL_OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", 6)
	_label.size = Vector2(CARD_SIZE.x * 2.0, 24.0)
	_label.position = Vector2(-CARD_SIZE.x, TOP_MARGIN + CARD_SIZE.y + LABEL_GAP)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)

	_holder = Control.new()
	_holder.size = CARD_SIZE
	_holder.pivot_offset = CARD_SIZE * 0.5
	_holder.position = Vector2(-CARD_SIZE.x * 0.5, TOP_MARGIN)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_root.visible = false

	CardManager.trump_chosen.connect(show_trump)
	GameManager.new_match_started.connect(_clear_trump)

func anchor() -> Control:
	return _holder

func _clear_trump() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	if _card_visual != null:
		_card_visual.queue_free()
		_card_visual = null
	_root.visible = false

func show_trump(suit: Card.Suit) -> void:
	if _card_visual != null and _root.visible and _final_suit == suit:
		return
	if _card_visual != null and _root.visible:
		_swap_instantly(suit)
		return
	_final_suit = suit
	if _card_visual != null:
		_card_visual.queue_free()

	_card_visual = CARD_SCENE.instantiate() as CardVisual
	_holder.add_child(_card_visual)
	_card_visual.setup(Card.new(suit, 0, Card.Owner.NONE, false), false)
	_card_visual.hover_enabled = false
	_card_visual.get_node("RankLabel").visible = false
	_card_visual.get_node("RankLabel2").visible = false
	_card_visual.add_table_shadow()
	_ignore_mouse(_card_visual)

	visible = true
	_root.visible = true
	_play_reveal()

func _play_reveal() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()

	_holder.position.y = TOP_MARGIN - DROP_DISTANCE
	_holder.scale = Vector2(0.0, 1.0)
	_holder.modulate.a = 0.0
	_label.modulate.a = 0.0
	_card_visual.show_back()

	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_holder, "position:y", TOP_MARGIN, REVEAL_TIME)
	_tween.tween_property(_holder, "modulate:a", 1.0, REVEAL_TIME * 0.5)
	_tween.tween_property(_label, "modulate:a", 1.0, REVEAL_TIME).set_delay(REVEAL_TIME * 0.5)

	var spin := create_tween()
	spin.tween_interval(REVEAL_TIME * 0.4)
	var shown := int(_final_suit)
	var front_next := true
	for half in SPIN_HALF_TIMES:
		spin.tween_property(_holder, "scale:x", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		spin.tween_callback(Sfx.play_trump_tick)
		if front_next:
			shown = (shown + 1) % 4
			spin.tween_callback(_set_face.bind(shown as Card.Suit))
		else:
			spin.tween_callback(_card_visual.show_back)
		front_next = not front_next
		spin.tween_property(_holder, "scale:x", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spin.tween_property(_holder, "scale:x", 0.0, LAND_HALF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	spin.tween_callback(_set_face.bind(_final_suit))
	spin.tween_callback(Sfx.play_trump_land)
	spin.tween_property(_holder, "scale:x", 1.0, LAND_HALF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spin_tween = spin

func _swap_instantly(suit: Card.Suit) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_final_suit = suit
	_holder.position.y = TOP_MARGIN
	_holder.modulate.a = 1.0
	_label.modulate.a = 1.0
	_set_face(suit)
	_holder.scale = Vector2.ONE * SWAP_POP_SCALE
	_tween = create_tween()
	_tween.tween_property(_holder, "scale", Vector2.ONE, SWAP_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_face(suit: Card.Suit) -> void:
	if _card_visual == null or _card_visual.card == null:
		return
	_card_visual.card.suit = suit
	_card_visual.show_front()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
