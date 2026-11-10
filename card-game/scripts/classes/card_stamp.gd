extends RefCounted
class_name CardStamp

enum Id {
	NONE,
	COLORLESS,
	DRAW_FIRST,
	PLUS_2,
	PLUS_3,
	PLUS_4,
	ZERO,
}

const OFFERS_PER_MATCH := 3

const PRICES := {
	Id.COLORLESS: 6,
	Id.DRAW_FIRST: 5,
	Id.PLUS_2: 4,
	Id.PLUS_3: 6,
	Id.PLUS_4: 8,
	Id.ZERO: 5,
}
const NAMES := {
	Id.COLORLESS: "Colorless",
	Id.DRAW_FIRST: "Draw First",
	Id.PLUS_2: "+2 Rank",
	Id.PLUS_3: "+3 Rank",
	Id.PLUS_4: "+4 Rank",
	Id.ZERO: "Make 0",
}
const DESCRIPTIONS := {
	Id.COLORLESS: "Can always be played, never follows suit rules. Never trump.",
	Id.DRAW_FIRST: "If it is not played in a round, it is drawn first next round.",
	Id.PLUS_2: "Permanently +2 rank. Can go above 9.",
	Id.PLUS_3: "Permanently +3 rank. Can go above 9.",
	Id.PLUS_4: "Permanently +4 rank. Can go above 9.",
	Id.ZERO: "Rank becomes 0, so it beats a 9 of its suit.",
}
const COLORS := {
	Id.COLORLESS: Color("b8b8c4"),
	Id.DRAW_FIRST: Color("4fc4a0"),
	Id.PLUS_2: Color("e0b84f"),
	Id.PLUS_3: Color("e08a3a"),
	Id.PLUS_4: Color("d8483c"),
	Id.ZERO: Color("8a5ad8"),
}
const RANK_BONUS := {
	Id.PLUS_2: 2,
	Id.PLUS_3: 3,
	Id.PLUS_4: 4,
}
const GLYPHS := {
	Id.COLORLESS: [
		"..www..",
		".w...w.",
		"w..w..w",
		"w.www.w",
		"w..w..w",
		".w...w.",
		"..www..",
	],
	Id.DRAW_FIRST: [
		"...w...",
		"..www..",
		".wwwww.",
		"...w...",
		"...w...",
		".wwwww.",
		".......",
	],
	Id.PLUS_2: [
		"....www",
		".w....w",
		"www.www",
		".w..w..",
		"....www",
	],
	Id.PLUS_3: [
		"....www",
		".w....w",
		"www.www",
		".w....w",
		"....www",
	],
	Id.PLUS_4: [
		"....w.w",
		".w..w.w",
		"www.www",
		".w....w",
		"......w",
	],
	Id.ZERO: [
		"..www..",
		".w...w.",
		".w..ww.",
		".w.w.w.",
		".ww..w.",
		".w...w.",
		"..www..",
	],
}


static func is_valid(id: int) -> bool:
	return id >= 0 and id < Id.size()


static func all_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in range(1, Id.size()):
		ids.append(id)
	return ids


static func random_id() -> int:
	return all_ids().pick_random()


static func price(id: int) -> int:
	return PRICES.get(id, 0)


static func display_name(id: int) -> String:
	return NAMES.get(id, "")


static func description(id: int) -> String:
	return DESCRIPTIONS.get(id, "")


static func color(id: int) -> Color:
	return COLORS.get(id, Color.WHITE)


static func glyph(id: int) -> Array:
	return GLYPHS.get(id, [])


static func apply_rank(id: int, printed_rank: int) -> int:
	if id == Id.ZERO:
		return 0
	return printed_rank + RANK_BONUS.get(id, 0)


static func can_stamp(card: Card) -> bool:
	return card != null and not card.has_stamp() and not card.has_effect()
