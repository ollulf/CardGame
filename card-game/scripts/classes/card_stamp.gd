extends RefCounted
class_name CardStamp

enum Id {
	NONE,
	COLORLESS,
	DRAW_FIRST,
	PLUS_2,
	PLUS_3,
	PLUS_4,
	GAMBLE = 7,
}

const OFFERS_PER_MATCH := 3
const RETIRED_ID := 6

const PRICES := {
	Id.COLORLESS: 6,
	Id.DRAW_FIRST: 5,
	Id.PLUS_2: 4,
	Id.PLUS_3: 6,
	Id.PLUS_4: 8,
	Id.GAMBLE: 3,
}
const NAMES := {
	Id.COLORLESS: "Joker",
	Id.DRAW_FIRST: "Up the Sleeve",
	Id.PLUS_2: "Marked +2",
	Id.PLUS_3: "Marked +3",
	Id.PLUS_4: "Marked +4",
	Id.GAMBLE: "Sore Loser",
}
const DESCRIPTIONS := {
	Id.COLORLESS: "Can always be played, never follows suit rules. Never trump.",
	Id.DRAW_FIRST: "If it is not played in a round, it is drawn first next round.",
	Id.PLUS_2: "Permanently +2 rank. Can go above 9.",
	Id.PLUS_3: "Permanently +3 rank. Can go above 9.",
	Id.PLUS_4: "Permanently +4 rank. Can go above 9.",
	Id.GAMBLE: "If this card does not win the trick, you get 1$.",
}
const COLORS := {
	Id.COLORLESS: Color("b8b8c4"),
	Id.DRAW_FIRST: Color("4fc4a0"),
	Id.PLUS_2: Color("e0b84f"),
	Id.PLUS_3: Color("e08a3a"),
	Id.PLUS_4: Color("d8483c"),
	Id.GAMBLE: Color("5fbf6a"),
}
const GAMBLE_PAY := 1
const RANK_BONUS := {
	Id.PLUS_2: 2,
	Id.PLUS_3: 3,
	Id.PLUS_4: 4,
}


static func is_valid(id: int) -> bool:
	return Id.values().has(id)


static func all_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in Id.values():
		if id == Id.NONE:
			continue
		ids.append(id)
	return ids


static func random_id() -> int:
	return all_ids().pick_random()


static func random_ids(count: int) -> Array[int]:
	var ids := all_ids()
	ids.shuffle()
	var picked: Array[int] = []
	for i in mini(count, ids.size()):
		picked.append(ids[i])
	return picked


static func price(id: int) -> int:
	return PRICES.get(id, 0)


static func display_name(id: int) -> String:
	return NAMES.get(id, "")


static func description(id: int) -> String:
	return DESCRIPTIONS.get(id, "")


static func color(id: int) -> Color:
	return COLORS.get(id, Color.WHITE)


static func apply_rank(id: int, printed_rank: int) -> int:
	return printed_rank + RANK_BONUS.get(id, 0)


static func can_stamp(card: Card) -> bool:
	return card != null and not card.has_stamp()
