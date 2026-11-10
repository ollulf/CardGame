extends RefCounted
class_name CardEffect

enum Id {
	NONE,
	DRAW,
	COPY,
}

const WORDS := {
	Id.DRAW: "DRAW",
	Id.COPY: "COPY",
}
const NAMES := {
	Id.DRAW: "Draw",
	Id.COPY: "Copy",
}
const DESCRIPTIONS := {
	Id.DRAW: "When played, draw a card from your deck.",
	Id.COPY: "When played, copies the current rank of the last card you played this match.",
}
const COLORS := {
	Id.DRAW: Color("4fa8e0"),
	Id.COPY: Color("e0a24f"),
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
		Id.COPY:
			var last: Card = CardManager.last_played_by.get(player_id)
			if last != null and last.rank != card.rank:
				print("Effect copy: player ", player_id, " copies rank ", last.rank, " from ", last.string_info())
				card.rank = last.rank
				card.apply_modifiers()


static func modify_rank(_card: Card, rank: int, _player_id: int) -> int:
	return rank


static func ai_discount(card: Card, player_id: int) -> float:
	if card.effect == Id.DRAW:
		var deck := CardManager.deck_of(player_id)
		if deck == null or deck.cards.is_empty():
			return 0.0
	if card.effect == Id.COPY:
		var last: Card = CardManager.last_played_by.get(player_id)
		return float(card.rank - last.rank) if last != null else 0.0
	return AI_COST_DISCOUNT.get(card.effect, 0.0)
