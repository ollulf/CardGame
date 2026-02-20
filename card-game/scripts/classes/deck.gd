extends RefCounted
class_name Deck

var cards : Array[Card]

func _init(cards : Array[Card]):
	self.cards = cards

func draw(amount: int) -> Hand:
	var hand := Hand.new()

	if cards.is_empty():
		return hand

	var draw_count = min(amount, cards.size())

	for i in range(draw_count):
		var c = cards.pop_back()
		hand.add(c)

	return hand
