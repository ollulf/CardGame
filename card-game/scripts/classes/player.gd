extends Control
class_name Player

@export var player_id : int
var hand: Hand
var won_turns : int = 0
var lost_rounds : int = 0

@export var active_scale: float = 1.12
@export var active_anim_time: float = 0.2

var _active_tween: Tween

func _ready() -> void:
	GameManager.turn_completed.connect(on_turn_completed)
	GameManager.round_started.connect(on_round_started)
	GameManager.request_play_card.connect(_on_active_player_requested)
	GameManager.turn_started.connect(_on_active_turn_started)

func _on_active_player_requested(requested_player_id: int) -> void:
	set_active(requested_player_id == player_id)

func _on_active_turn_started(_turn_index: int, _starting_player_id: int) -> void:
	set_active(false)

func set_active(active: bool) -> void:
	var target := Vector2.ONE * (active_scale if active else 1.0)
	if _active_tween:
		_active_tween.kill()
	if scale.is_equal_approx(target):
		return
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", target, active_anim_time)

func on_round_started():
	won_turns = 0

func on_turn_completed(current_turn : int, winner_id: int):
	print("signal of turn lost")
	if winner_id == player_id:
		won_turns += 1

func get_card_transform(card : Card) -> Transform2D:
	for child in get_children():
		if child is CardVisual and child.card == card:
			return child.get_global_transform()
	return get_global_transform()

func get_ownership_of_hand_cards(hand : Hand):
	for card in hand.cards:
		card.owner

func player_id_to_Owner(id : int) -> Card.Owner:
	match id:
		0:
			return Card.Owner.HUMAN
		1: 
			return Card.Owner.AI_1
		2:
			return Card.Owner.AI_2
		_:
			return Card.Owner.NONE
