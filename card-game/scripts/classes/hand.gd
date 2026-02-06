extends RefCounted
class_name Hand

var cards : Array[Card]
var holder : Holder = Holder.NONE

enum Holder {
	NONE,
	HUMAN,
	AI_1,
	AI_2
}

func contains(card : Card) -> bool:
	return cards.has(card)

func contains_card_of_suit(suit: Card.Suit) -> bool:
	if suit == null:
		return true
	
	for card in cards:
		if card.suit == suit:
			return true
	return false

func has_trump_card() -> bool:
	for card in cards:
		if card.is_trump:
			return true
	return false

func get_highest_trump_card() -> Card:
	var c = get_trump_cards()
	
	if c.is_empty():
		return null
		
	var highest: Card = c[0]

	for card in c:
		if card.rank > highest.rank:
			highest = card

	return highest

func get_trump_cards() -> Array[Card]:
	return cards.filter(func(c):
		return c.is_trump
		)

func get_highest_card_of_suit(suit: Card.Suit) -> Card:
	var c = get_cards_of_suit(suit)
	
	if c.is_empty():
		return null
		
	var highest: Card = c[0]

	for card in c:
		if card.rank > highest.rank:
			highest = card

	return highest


func get_cards_of_suit(suit: Card.Suit) -> Array[Card]:
	return cards.filter(func(c):
		return c.suit == suit
		)
