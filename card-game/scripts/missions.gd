extends Node

signal cigarettes_changed(seat: int)
signal budget_changed(seat: int)

const MISSIONS_PATH := "res://missions.yaml"
const ANY := 0
const DECK_SIZE := 21
const DECK_KEYS := ["you_deck", "ai_one_deck", "ai_two_deck"]
const CIGARETTE_KEYS := {1: "ai_one_cigarettes", 2: "ai_two_cigarettes"}
const BUDGET_KEYS := {1: "ai_one_budget", 2: "ai_two_budget"}
const CARD_LIST_KEYS := ["you_deck", "ai_one_deck", "ai_two_deck"]
const PRIZE_KEY := "prize_money"
const ALLOWED_KEYS := ["match", "you_deck", "ai_one_deck", "ai_two_deck", "ai_one_cigarettes", "ai_two_cigarettes", "ai_one_budget", "ai_two_budget", "prize_money"]
const SUIT_CODES := {
	"H": Card.Suit.HEARTS,
	"D": Card.Suit.DIAMONDS,
	"S": Card.Suit.SPADES,
	"C": Card.Suit.CLUBS,
	"SM": Card.Suit.SMOKE,
	"AL": Card.Suit.ALK,
}
const UNLIMITED := -1
const ZERO_RANK_MATCH := 2
const ALK_MATCH := 3
const LAST_MATCH := 5

var matches: Dictionary = load_missions(MISSIONS_PATH)
var _cigarettes_used := {}
var _cigarettes_added := {}
var _budget_spent := {}

func _ready() -> void:
	GameManager.new_match_started.connect(_on_new_match_started)

func deck_cards(match_number: int, seat: int) -> Array:
	return _lookup(match_number, DECK_KEYS[seat], [])

func cigarette_limit(match_number: int, seat: int) -> int:
	if not CIGARETTE_KEYS.has(seat):
		return UNLIMITED
	return _lookup(match_number, CIGARETTE_KEYS[seat], UNLIMITED)

func lowest_rank(match_number: int) -> int:
	return 0 if match_number >= ZERO_RANK_MATCH else 1

func allows_alk(match_number: int) -> bool:
	return match_number >= ALK_MATCH

func is_last_match(match_number: int) -> bool:
	return match_number >= LAST_MATCH

func prize_money(match_number: int) -> int:
	return _lookup(match_number, PRIZE_KEY, 0)

func cigarettes_left(seat: int) -> int:
	var limit := cigarette_limit(DialogueManager.upcoming_match(), seat)
	if limit == UNLIMITED:
		return UNLIMITED
	return maxi(0, limit + _cigarettes_added.get(seat, 0) - _cigarettes_used.get(seat, 0))

func can_smoke(seat: int) -> bool:
	return cigarettes_left(seat) != 0

func use_cigarette(seat: int) -> void:
	_cigarettes_used[seat] = _cigarettes_used.get(seat, 0) + 1
	cigarettes_changed.emit(seat)

func add_cigarettes(seat: int, amount: int) -> void:
	_cigarettes_added[seat] = _cigarettes_added.get(seat, 0) + amount
	cigarettes_changed.emit(seat)

func budget(match_number: int, seat: int) -> int:
	if not BUDGET_KEYS.has(seat):
		return 0
	return _lookup(match_number, BUDGET_KEYS[seat], 0)

func budget_left(seat: int) -> int:
	return maxi(0, budget(DialogueManager.upcoming_match(), seat) - _budget_spent.get(seat, 0))

func spend_budget(seat: int, amount: int) -> bool:
	if amount < 0 or budget_left(seat) < amount:
		return false
	_budget_spent[seat] = _budget_spent.get(seat, 0) + amount
	budget_changed.emit(seat)
	return true

func _on_new_match_started() -> void:
	_cigarettes_used.clear()
	_cigarettes_added.clear()
	_budget_spent.clear()
	for seat in BUDGET_KEYS:
		budget_changed.emit(seat)

func _lookup(match_number: int, key: String, fallback):
	for wanted in [match_number, ANY]:
		var entry: Dictionary = matches.get(wanted, {})
		if entry.has(key):
			return entry[key]
	return fallback

static func load_missions(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var yaml := YamlLite.parse_file(path, ["match"], CARD_LIST_KEYS)
	return _collect(yaml)

static func parse_text(text: String) -> Dictionary:
	var yaml := YamlLite.new()
	yaml.entry_keys = ["match"]
	yaml.raw_keys = CARD_LIST_KEYS
	yaml.parse(text, "missions.yaml")
	return _collect(yaml)

static func _collect(yaml: YamlLite) -> Dictionary:
	var result := {}
	for i in yaml.data.size():
		var line: int = yaml.item_lines[i]
		var entry = _clean_match(yaml.data[i], line)
		if entry == null:
			continue
		if result.has(entry.match):
			push_error("Missions line %d: match %s is listed twice" % [line, "any" if entry.match == ANY else str(entry.match)])
			continue
		result[entry.match] = entry.settings
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
	var settings := {}
	for key in CARD_LIST_KEYS:
		if not raw.has(key) or raw[key] == null:
			continue
		var cards = _deck(raw[key], key, line)
		if cards == null:
			return null
		if cards.size() > DECK_SIZE:
			push_error("Missions line %d: %s lists %d cards, a deck holds at most %d" % [line, key, cards.size(), DECK_SIZE])
			return null
		settings[key] = cards
	for key in CIGARETTE_KEYS.values() + BUDGET_KEYS.values() + [PRIZE_KEY]:
		if not raw.has(key):
			continue
		if not raw[key] is int or raw[key] < 0:
			push_error("Missions line %d: %s must be a whole number of 0 or more" % [line, key])
			return null
		settings[key] = raw[key]
	return {"match": match_number, "settings": settings}

static func _deck(value, key: String, line: int):
	if value is Dictionary and value.has("rows"):
		var cards: Array = []
		for row in value.rows:
			var row_cards = _suit_row(row.text, key, row.line)
			if row_cards == null:
				return null
			cards.append_array(row_cards)
		return cards
	var listed: Array = []
	for word in TutorialScript._words(value):
		var card = _card(word)
		if card == null:
			push_error("Missions line %d: '%s' in %s is not a card like 'H 9' or 'HEARTS 9'" % [line, word, key])
			return null
		listed.append(card)
	return listed

static func _suit_row(text: String, key: String, line: int):
	var code := ""
	var i := 0
	while i < text.length() and (text[i] >= "A" and text[i] <= "Z" or text[i] >= "a" and text[i] <= "z"):
		code += text[i]
		i += 1
	var rest := text.substr(i).strip_edges()
	if rest.begins_with(":"):
		rest = rest.substr(1).strip_edges()
	var suit := _suit(code)
	if code == "" or suit < 0:
		push_error("Missions line %d: '%s' in %s does not start with a suit code (%s)" % [line, text, key, ", ".join(SUIT_CODES.keys())])
		return null
	var cards: Array = []
	for word in TutorialScript._words(rest):
		if not word.is_valid_int() or word.to_int() < 0 or word.to_int() > 9:
			push_error("Missions line %d: '%s' in %s is not a rank from 0 to 9" % [line, word, key])
			return null
		cards.append([suit, word.to_int()])
	if cards.is_empty():
		push_error("Missions line %d: '%s' in %s lists no ranks" % [line, text, key])
		return null
	return cards

static func _suit(word: String) -> int:
	var upper := word.strip_edges().to_upper()
	if SUIT_CODES.has(upper):
		return SUIT_CODES[upper]
	return TutorialScript._suit(upper)

static func _card(word: String):
	var parts := word.split(" ", false)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var suit := _suit(parts[0])
	var rank := parts[1].to_int()
	if suit < 0 or rank < 0 or rank > 9:
		return null
	return [suit, rank]
