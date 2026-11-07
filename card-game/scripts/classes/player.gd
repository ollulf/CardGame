extends Control
class_name Player

@export var player_id : int
var hand: Hand
var won_turns : int = 0
var lost_rounds : int = 0

func _ready() -> void:
	GameManager.turn_completed.connect(on_turn_completed)
	GameManager.round_started.connect(on_round_started)

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
