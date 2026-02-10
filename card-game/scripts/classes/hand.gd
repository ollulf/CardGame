extends RefCounted
class_name Hand

var cards : Array[Card]

signal hand_grew
signal hand_shrinked

func remove(card : Card) -> bool:
	if contains(card):
		cards.erase(card)
		card.remove()
		hand_shrinked.emit()
		return true
	return false

func add(card: Card):
	cards.append(card)
	hand_grew.emit()

func append(card: Card):
	cards.append(card)

func contains(card : Card) -> bool:
	return cards.has(card)

func is_empty() -> bool:
	return cards.size() == 0

func empty():
	for card in cards:
		card.remove()
	cards.clear()

func size() -> int:
	return cards.size()

func get_index_by_card(card : Card) -> int:
	return cards.find(card)

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

func get_lowest_card() -> Card:
	var lowest: Card = cards[0]

	for card in cards:
		if card.rank < lowest.rank:
			lowest = card

	return lowest

func get_lowest_card_of_suit(suit: Card.Suit) -> Card:
	var c = get_cards_of_suit(suit)
	
	if c.is_empty():
		return null
		
	var lowest: Card = c[0]

	for card in c:
		if card.rank < lowest.rank:
			lowest = card

	return lowest

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

func get_cards_higher_than(card: Card) -> Array[Card]:
	if card.is_trump:
		return cards.filter(func(c:):
			return c.is_trump and c.rank > card.rank
		)

	return cards.filter(func(c:):
		return c.suit == card.suit and c.rank > card.rank
	)

func get_random_higher_card_than(card: Card) -> Card:
	var higher := get_cards_higher_than(card)
	if higher.is_empty():
		return null
	return higher.pick_random()

func get_cards_lower_than(card: Card) -> Array[Card]:
	if card.is_trump:
		return cards.filter(func(c:):
			return c.is_trump and c.rank <= card.rank
		)

	return cards.filter(func(c:):
		return c.suit == card.suit and c.rank <= card.rank
	)

func get_random_lower_than(card: Card) -> Card:
	var lower := get_cards_lower_than(card)
	if lower.is_empty():
		return null
	return lower.pick_random()
