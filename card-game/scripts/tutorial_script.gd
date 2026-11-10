extends Node

const SCRIPT_PATH := "res://tutorial_game.yaml"
const SEAT_COUNT := 3
const HAND_SIZE := 5
const RULE_WORDS := ["highest", "lowest", "trump"]
const AUTO_WORDS := ["auto", "-"]
const SMOKE_WORD := "smoke"
const HAND_KEYS := ["you", "ai_one", "ai_two"]
const PLAY_KEYS := ["you_plays", "ai_one_plays", "ai_two_plays"]
const HUMAN_SEAT := 0
const ALLOWED_KEYS := ["match", "round", "trump", "starter", "you", "ai_one", "ai_two", "you_plays", "ai_one_plays", "ai_two_plays"]

var rounds: Dictionary = load_rounds(SCRIPT_PATH)
var _match_number := 0
var _round_index := 0
var _current: Dictionary = {}

func _ready() -> void:
	GameManager.match_finished.connect(_on_match_finished)

func begin_round() -> void:
	var match_number := DialogueManager.upcoming_match()
	if match_number != _match_number:
		_match_number = match_number
		_round_index = 0
	_round_index += 1
	_current = rounds.get(match_number, {}).get(_round_index, {})

func is_scripted() -> bool:
	return not _current.is_empty()

func starter(fallback: int) -> int:
	return _current.get("starter", fallback)

func match_trump(match_number: int, fallback: Card.Suit) -> Card.Suit:
	var match_rounds: Dictionary = rounds.get(match_number, {})
	var numbers := match_rounds.keys()
	numbers.sort()
	for number in numbers:
		if match_rounds[number].has("trump"):
			return match_rounds[number].trump
	return fallback

func hand_cards(seat: int) -> Array:
	return _current.get("hands", {}).get(seat, [])

func planned_smoke(seat: int, turn: int) -> int:
	return _current.get("smokes", {}).get(seat, {}).get(turn, 0)

func blocks_human_play(hand: Hand, card: Card, turn: int) -> bool:
	var intended := planned_card(HUMAN_SEAT, hand, turn, false)
	return intended != null and intended != card

func human_hint(hand: Hand, turn: int) -> String:
	var intended := planned_card(HUMAN_SEAT, hand, turn, false)
	if intended == null:
		return ""
	return "Play your %s %d now." % [Card.Suit.keys()[intended.suit].capitalize(), intended.base_rank]

func planned_card(seat: int, hand: Hand, turn: int, warn := true) -> Card:
	var plan: Array = _current.get("plays", {}).get(seat, [])
	if turn < 1 or turn > plan.size():
		return null
	var step = plan[turn - 1]
	var legal: Array = hand.cards.filter(func(c): return CardManager.is_legal_play(hand, c))
	if legal.is_empty():
		return null
	if step is Array:
		for card in legal:
			if card.suit == step[0] and card.base_rank == step[1]:
				return card
		if warn:
			push_warning("TutorialGame match %d round %d: seat %d cannot play %s %d on turn %d, playing normally" % [_match_number, _round_index, seat, Card.Suit.keys()[step[0]], step[1], turn])
		return null
	match step:
		"highest":
			return _pick(legal, true)
		"lowest":
			return _pick(legal, false)
		"trump":
			var trumps := legal.filter(func(c): return c.is_trump)
			if trumps.is_empty():
				return null
			return _pick(trumps, true)
	return null

func _pick(cards: Array, highest: bool) -> Card:
	var best: Card = cards[0]
	for card in cards:
		if (highest and card.rank > best.rank) or (not highest and card.rank < best.rank):
			best = card
	return best

func _on_match_finished(_loosers) -> void:
	_current = {}

func capture_state() -> Dictionary:
	return {"match": _match_number, "round_index": _round_index}

func restore_state(state: Dictionary) -> void:
	_match_number = state.get("match", 0)
	_round_index = state.get("round_index", 0)
	_current = {}

static func load_rounds(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var yaml := YamlLite.parse_file(path)
	var result := {}
	for i in yaml.data.size():
		var entry = _clean_round(yaml.data[i], yaml.item_lines[i])
		if entry == null:
			continue
		var match_rounds: Dictionary = result.get_or_add(entry.match, {})
		if match_rounds.has(entry.round):
			push_error("TutorialGame line %d: match %d round %d is listed twice" % [yaml.item_lines[i], entry.match, entry.round])
			continue
		match_rounds[entry.round] = entry
	return result

static func _clean_round(raw, line: int):
	if not raw is Dictionary or not raw.get("round") is int or raw.round < 1:
		push_error("TutorialGame line %d: entry needs 'round' with a number of 1 or more" % line)
		return null
	for key in raw.keys():
		if not key in ALLOWED_KEYS:
			push_error("TutorialGame line %d: unknown key '%s' (allowed: %s)" % [line, key, ", ".join(ALLOWED_KEYS)])
			return null
	if raw.has("match") and (not raw.match is int or raw.match < 1):
		push_error("TutorialGame line %d: match must be a number of 1 or more" % line)
		return null
	var entry := {"match": raw.get("match", 1), "round": raw.round, "hands": {}, "plays": {}, "smokes": {}}
	if raw.has("trump"):
		var suit := _suit(raw.trump)
		if suit < 0 or suit > Card.Suit.CLUBS:
			push_error("TutorialGame line %d: trump must be DIAMONDS, HEARTS, SPADES or CLUBS" % line)
			return null
		entry["trump"] = suit
	if raw.has("starter"):
		if not raw.starter is int or raw.starter < 0 or raw.starter >= SEAT_COUNT:
			push_error("TutorialGame line %d: starter must be a seat number from 0 to %d" % [line, SEAT_COUNT - 1])
			return null
		entry["starter"] = raw.starter
	for seat in SEAT_COUNT:
		var key: String = HAND_KEYS[seat]
		if not raw.has(key):
			continue
		var cards: Array = []
		for word in _words(raw[key]):
			var card = _card(word)
			if card == null:
				push_error("TutorialGame line %d: '%s' in %s is not a card like 'HEARTS 9'" % [line, word, key])
				return null
			cards.append(card)
		if cards.is_empty() or cards.size() > HAND_SIZE:
			push_error("TutorialGame line %d: %s needs 1 to %d cards, found %d" % [line, key, HAND_SIZE, cards.size()])
			return null
		entry.hands[seat] = cards
	for seat in SEAT_COUNT:
		var key: String = PLAY_KEYS[seat]
		if not raw.has(key):
			continue
		var plan: Array = []
		var smokes := {}
		for raw_word in _words(raw[key]):
			var word: String = raw_word
			var parts := word.split("+", false, 1)
			if parts.size() == 2 and parts[0].strip_edges().to_lower() == SMOKE_WORD:
				if seat == HUMAN_SEAT:
					push_error("TutorialGame line %d: %s cannot plan a smoke, the player smokes on their own" % [line, key])
					return null
				smokes[plan.size() + 1] = 1
				word = parts[1].strip_edges()
			if word in RULE_WORDS or word in AUTO_WORDS:
				plan.append(word)
				continue
			var card = _card(word)
			if card == null:
				push_error("TutorialGame line %d: '%s' in %s is not a card or one of %s" % [line, word, key, ", ".join(RULE_WORDS + AUTO_WORDS)])
				return null
			if entry.hands.has(seat) and not entry.hands[seat].has(card):
				push_error("TutorialGame line %d: %s plays %s %d, which is not in %s" % [line, key, Card.Suit.keys()[card[0]], card[1], HAND_KEYS[seat]])
				return null
			plan.append(card)
		if plan.size() > HAND_SIZE:
			push_error("TutorialGame line %d: %s lists %d plays, a round has only %d turns" % [line, key, plan.size(), HAND_SIZE])
			return null
		entry.plays[seat] = plan
		entry.smokes[seat] = smokes
	return entry

static func _words(value) -> Array:
	var words: Array = []
	for part in str(value).split(","):
		var word := part.strip_edges()
		if word != "":
			words.append(word)
	return words

static func _suit(value) -> int:
	return Card.Suit.keys().find(str(value).strip_edges().to_upper())

static func _card(word: String):
	var parts := word.split(" ", false)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var suit := _suit(parts[0])
	var rank := parts[1].to_int()
	if suit < 0 or rank < 0 or rank > 9:
		return null
	return [suit, rank]
