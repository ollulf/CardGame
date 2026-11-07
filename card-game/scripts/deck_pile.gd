extends Area2D
class_name DeckPile

signal clicked(deck_owner: Card.Owner)

const CARD_BACK := preload("res://sprites/card_Background.png")
const CARD_SCALE := 3.0
const LAYER_STEP := Vector2(0, -3)
const CARDS_PER_LAYER := 4
const EMPTY_COLOR := Color(1, 1, 1, 0.35)

@export var deck_owner: Card.Owner = Card.Owner.HUMAN
@export var hover_offset: Vector2 = Vector2(0, -4)
@export var max_layers: int = 5

@onready var stack: Node2D = $Stack
@onready var count_label: Label = $Count

var _layers: Array[Sprite2D] = []
var _hovered: bool = false
var _last_count: int = -1


func _ready() -> void:
	for i in range(max_layers):
		var sprite := Sprite2D.new()
		sprite.texture = CARD_BACK
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)
		sprite.position = LAYER_STEP * float(i)
		stack.add_child(sprite)
		_layers.append(sprite)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_stack()


func _process(_delta: float) -> void:
	if get_card_count() != _last_count:
		_refresh_stack()
	_refresh_hover()


func get_deck() -> Deck:
	match deck_owner:
		Card.Owner.HUMAN:
			return CardManager.player_deck
		Card.Owner.AI_1:
			return CardManager.AI_1_deck
		Card.Owner.AI_2:
			return CardManager.AI_2_deck
	return null


func get_card_count() -> int:
	var deck := get_deck()
	return 0 if deck == null else deck.cards.size()


func _refresh_stack() -> void:
	_last_count = get_card_count()
	var shown := clampi(ceili(float(_last_count) / CARDS_PER_LAYER), 1, max_layers)
	for i in range(_layers.size()):
		_layers[i].visible = i < shown
	stack.modulate = EMPTY_COLOR if _last_count == 0 else Color.WHITE
	count_label.text = str(_last_count)


func _is_blocked() -> bool:
	return DialogueManager.is_open() or InteractionManager.is_table_blocked() or get_tree().paused


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false


func _refresh_hover() -> void:
	var active := _hovered and not _is_blocked()
	stack.position = hover_offset if active else Vector2.ZERO


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _is_blocked() or get_deck() == null:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		get_viewport().set_input_as_handled()
		clicked.emit(deck_owner)
