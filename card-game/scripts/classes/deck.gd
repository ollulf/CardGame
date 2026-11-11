extends RefCounted
class_name Deck

var cards : Array[Card]
var all_cards : Array[Card]

func _init(cards : Array[Card]):
	self.cards = cards
	all_cards = cards.duplicate()

func replace_card(index: int, card: Card) -> void:
	var old := cards[index]
	cards[index] = card
	var slot := all_cards.find(old)
	if slot >= 0:
		all_cards[slot] = card
	else:
		all_cards.append(card)

func move_draw_first_to_top() -> void:
	var first: Array[Card] = cards.filter(func(c: Card) -> bool: return c.draws_first())
	if first.is_empty():
		return
	var rest: Array[Card] = cards.filter(func(c: Card) -> bool: return not c.draws_first())
	cards = rest + first

func draw(amount: int) -> Hand:
	var hand := Hand.new()

	if cards.is_empty():
		return hand

	var draw_count = min(amount, cards.size())

	for i in range(draw_count):
		var c = cards.pop_back()
		hand.add(c)

	return hand
