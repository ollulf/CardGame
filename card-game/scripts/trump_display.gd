extends CanvasLayer
class_name TrumpDisplay

const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARD_SIZE := Vector2(60, 90)
const TOP_MARGIN := 30.0
const DROP_DISTANCE := 40.0
const REVEAL_TIME := 0.5
const FLIP_TIME := 0.25

var _root: Control
var _holder: Control
var _label: Label
var _card_visual: CardVisual
var _tween: Tween

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_label = Label.new()
	_label.text = "Trump"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(CARD_SIZE.x * 2.0, 22.0)
	_label.position = Vector2(-CARD_SIZE.x, TOP_MARGIN - 24.0)
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

func _clear_trump() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _card_visual != null:
		_card_visual.queue_free()
		_card_visual = null
	_root.visible = false

func show_trump(suit: Card.Suit) -> void:
	if _card_visual != null:
		_card_visual.queue_free()

	_card_visual = CARD_SCENE.instantiate() as CardVisual
	_holder.add_child(_card_visual)
	_card_visual.setup(Card.new(suit, 0, Card.Owner.NONE, false), false)
	_card_visual.hover_enabled = false
	_card_visual.get_node("RankLabel").visible = false
	_card_visual.get_node("RankLabel2").visible = false
	_ignore_mouse(_card_visual)

	visible = true
	_root.visible = true
	_play_reveal()

func _play_reveal() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_holder.position.y = TOP_MARGIN - DROP_DISTANCE
	_holder.scale = Vector2(0.0, 1.0)
	_holder.modulate.a = 0.0
	_label.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_holder, "position:y", TOP_MARGIN, REVEAL_TIME)
	_tween.tween_property(_holder, "modulate:a", 1.0, REVEAL_TIME * 0.5)
	_tween.tween_property(_holder, "scale", Vector2.ONE, FLIP_TIME).set_delay(REVEAL_TIME * 0.4)
	_tween.tween_property(_label, "modulate:a", 1.0, REVEAL_TIME).set_delay(REVEAL_TIME * 0.5)

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
