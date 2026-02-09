extends Control
class_name Player

@export var player_id : int
var hand: Hand
var won_rounds := 0

func _ready() -> void:
	GameManager.round_completed.connect(on_round_completed)
	GameManager.match_finished.connect(on_match_finished)

func on_match_finished():
	won_rounds = 0

func on_round_completed(current_cound : int, winner_id: int):
	if winner_id == player_id:
		won_rounds += 1

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
