extends RefCounted
class_name CardEffect

enum Id {
	NONE,
	DRAW,
}

const WORDS := {
	Id.DRAW: "DRAW",
}
const NAMES := {
	Id.DRAW: "Draw",
}
const DESCRIPTIONS := {
	Id.DRAW: "When played, draw a card from your deck.",
}
const COLORS := {
	Id.DRAW: Color("4fa8e0"),
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
}
const AI_COST_DISCOUNT := {
	Id.DRAW: 1.5,
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


static func modify_rank(_card: Card, rank: int, _player_id: int) -> int:
	return rank


static func ai_discount(card: Card, player_id: int) -> float:
	if card.effect == Id.DRAW:
		var deck := CardManager.deck_of(player_id)
		if deck == null or deck.cards.is_empty():
			return 0.0
	return AI_COST_DISCOUNT.get(card.effect, 0.0)
