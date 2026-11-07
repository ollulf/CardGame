extends Node

const MISSIONS_PATH := "res://missions.yaml"
const ANY := 0
const DECK_SIZE := 20
const DECK_KEYS := ["you_deck", "ai_one_deck", "ai_two_deck"]
const ALLOWED_KEYS := ["match", "you_deck", "ai_one_deck", "ai_two_deck"]

var matches: Dictionary = load_missions(MISSIONS_PATH)

func deck_cards(match_number: int, seat: int) -> Array:
	var key: String = DECK_KEYS[seat]
	for wanted in [match_number, ANY]:
		var entry: Dictionary = matches.get(wanted, {})
		if entry.has(key):
			return entry[key]
	return []

static func load_missions(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var yaml := YamlLite.parse_file(path, ["match"])
	var result := {}
	for i in yaml.data.size():
		var line: int = yaml.item_lines[i]
		var entry = _clean_match(yaml.data[i], line)
		if entry == null:
			continue
		if result.has(entry.match):
			push_error("Missions line %d: match %s is listed twice" % [line, "any" if entry.match == ANY else str(entry.match)])
			continue
		result[entry.match] = entry.decks
	return result

static func _clean_match(raw, line: int):
	if not raw is Dictionary or not raw.has("match"):
		push_error("Missions line %d: entry needs 'match' with a number of 1 or more, or 'any'" % line)
		return null
	var match_number := ANY
	if not (raw["match"] is String and raw["match"] == "any"):
		if not raw["match"] is int or raw["match"] < 1:
			push_error("Missions line %d: 'match' must be a whole number of 1 or more, or 'any'" % line)
			return null
		match_number = raw["match"]
	for key in raw.keys():
		if not key in ALLOWED_KEYS:
			push_error("Missions line %d: unknown key '%s' (allowed: %s)" % [line, key, ", ".join(ALLOWED_KEYS)])
			return null
	var decks := {}
	for key in DECK_KEYS:
		if not raw.has(key) or raw[key] == null:
			continue
		var cards: Array = []
		for word in TutorialScript._words(raw[key]):
			var card = TutorialScript._card(word)
			if card == null:
				push_error("Missions line %d: '%s' in %s is not a card like 'HEARTS 9'" % [line, word, key])
				return null
			cards.append(card)
		if cards.size() > DECK_SIZE:
			push_error("Missions line %d: %s lists %d cards, a deck holds at most %d" % [line, key, cards.size(), DECK_SIZE])
			return null
		decks[key] = cards
	return {"match": match_number, "decks": decks}
