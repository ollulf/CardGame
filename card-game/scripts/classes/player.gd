extends Control
class_name Player

@export var player_id : int
var hand: Hand

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
