extends RefCounted
class_name CardEffect

enum Id {
	NONE,
	DRAW,
	COPY,
	SUIT_UP,
	TRUMP,
}

const TRUMP_LASTS_WHOLE_MATCH := false

const WORDS := {
	Id.DRAW: "DRAW",
	Id.COPY: "COPY",
	Id.SUIT_UP: "SUITUP",
	Id.TRUMP: "TRUMP",
}
const NAMES := {
	Id.DRAW: "Refill",
	Id.COPY: "Same Again",
	Id.SUIT_UP: "Stammtisch",
	Id.TRUMP: "Calls the Shots",
}
const DESCRIPTIONS := {
	Id.DRAW: "When played, draw a card from your deck.",
	Id.COPY: "Has the rank of the last card you played this match, already in your hand.",
	Id.SUIT_UP: "When played, all your cards of this card's suit get +1 rank for the rest of the match. Stacks.",
	Id.TRUMP: "When played, its suit becomes trump until the end of the round (smoke and drink cards are always trump).",
}
const COLORS := {
	Id.DRAW: Color("4fa8e0"),
	Id.COPY: Color("e0a24f"),
	Id.SUIT_UP: Color("e0a64f"),
	Id.TRUMP: Color("e0a43a"),
}
const ICONS := {
	Id.DRAW: [
		".#########.",
		"#ooooooooo#",
		"#owwwwoooo#",
		"#owwwwokoo#",
		"#owwwwkkko#",
		"#owwwwokoo#",
		"#owwwwoooo#",
		"#owwwwoooo#",
		"#ooooooooo#",
		".#########.",
	],
	Id.COPY: [
		".#########.",
		"#ooooooooo#",
		"#owwwooooo#",
		"#owoowwwoo#",
		"#owoowowoo#",
		"#owwwwowoo#",
		"#oooowwwoo#",
		"#ooooooooo#",
		".#########.",
	],
	Id.SUIT_UP: [
		".#########.",
		"#ooooooooo#",
		"#ooooworoo#",
		"#ooowwwooo#",
		"#oowwwwwoo#",
		"#ooooworoo#",
		"#ooooworoo#",
		"#ooooooooo#",
		"#ooooooooo#",
		".#########.",
	],
	Id.TRUMP: [
		".#########.",
		"#ooooooooo#",
		"#ooookoooo#",
		"#oookkkooo#",
		"#ookkkkkoo#",
		"#okkkkkkko#",
		"#ooookoooo#",
		"#oookkkooo#",
		"#ooooooooo#",
		".#########.",
	],
}
const AI_SUIT_CARD_BONUS := 1.0
const AI_COST_DISCOUNT := {
	Id.DRAW: 1.5,
	Id.SUIT_UP: 1.0,
	Id.TRUMP: 1.0,
}


static func is_valid(id: int) -> bool:
	return id >= 0 and id < Id.size()


static func from_word(text: String) -> int:
	var upper := text.strip_edges().to_upper()
	for id in WORDS:
		if WORDS[id] == upper:
			return id
	return -1


static func word(id: int) -> String:
	return WORDS.get(id, "")


static func display_name(id: int) -> String:
	return NAMES.get(id, "")


static func description(id: int) -> String:
	return DESCRIPTIONS.get(id, "")


static func color(id: int) -> Color:
	return COLORS.get(id, Color.WHITE)


static func icon(id: int) -> Array:
	return ICONS.get(id, [])


static func on_played(card: Card, player_id: int) -> void:
	match card.effect:
		Id.DRAW:
			await CardManager.draw_extra_card(player_id)
		Id.SUIT_UP:
			CardManager.add_suit_bonus(player_id, card.suit, 1)
		Id.TRUMP:
			CardManager.change_trump_to(card.suit, TRUMP_LASTS_WHOLE_MATCH)


static func modify_rank(card: Card, rank: int, player_id: int) -> int:
	return rank + CardManager.suit_bonus(player_id, card.suit)


static func copied_rank(card: Card, player_id: int) -> int:
	if card.effect != Id.COPY:
		return -1
	var last: Card = CardManager.last_played_by.get(player_id)
	if last == null:
		return -1
	var rank := last.rank
	for part in last.buff_parts:
		if part.get("kind") in ["drink_penalty", "drink_bonus", "smoke", "suit_up"]:
			rank -= int(part.get("amount", 0))
	return CardStamp.apply_rank(card.stamp, rank)


static func ai_discount(card: Card, player_id: int) -> float:
	if card.effect == Id.DRAW:
		var deck := CardManager.deck_of(player_id)
		if deck == null or deck.cards.is_empty():
			return 0.0
	if card.effect == Id.TRUMP:
		if card.is_trump or card.suit == Card.Suit.SMOKE or card.suit == Card.Suit.ALK:
			return 0.0
		return AI_COST_DISCOUNT[Id.TRUMP] + AI_SUIT_CARD_BONUS * _same_suit_in_hand(card, player_id)
	if card.effect == Id.SUIT_UP:
		return AI_COST_DISCOUNT[Id.SUIT_UP] + AI_SUIT_CARD_BONUS * _same_suit_in_hand(card, player_id)
	return AI_COST_DISCOUNT.get(card.effect, 0.0)


static func _same_suit_in_hand(card: Card, player_id: int) -> int:
	var hand := CardManager.hand_of(player_id)
	if hand == null:
		return 0
	var count := 0
	for other in hand.cards:
		if other != card and other.suit == card.suit:
			count += 1
	return count
