extends Node

const SCRIPT_PATH := "res://tutorial_game.yaml"
const SEAT_COUNT := 3
const HAND_SIZE := 5
const RULE_WORDS := ["highest", "lowest", "trump"]
const AUTO_WORDS := ["auto", "-"]
const SMOKE_WORD := "smoke"
const HAND_KEYS := ["you", "ai_one", "ai_two"]
const PLAY_KEYS := ["ai_one_plays", "ai_two_plays"]
const ALLOWED_KEYS := ["round", "trump", "starter", "you", "ai_one", "ai_two", "ai_one_plays", "ai_two_plays"]

var rounds: Dictionary = load_rounds(SCRIPT_PATH)
var active := true
var _round_index := 0
var _current: Dictionary = {}

func _ready() -> void:
	GameManager.match_finished.connect(_on_match_finished)

func begin_round() -> void:
	_current = {}
	if not active:
		return
	_round_index += 1
	_current = rounds.get(_round_index, {})

func is_scripted() -> bool:
	return not _current.is_empty()

func starter(fallback: int) -> int:
	return _current.get("starter", fallback)

func trump(fallback: Card.Suit) -> Card.Suit:
	return _current.get("trump", fallback)

func hand_cards(seat: int) -> Array:
	return _current.get("hands", {}).get(seat, [])

func planned_smoke(seat: int, turn: int) -> int:
	return _current.get("smokes", {}).get(seat, {}).get(turn, 0)

func planned_card(seat: int, hand: Hand, turn: int) -> Card:
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
		push_warning("TutorialGame round %d: seat %d cannot play %s %d on turn %d, playing normally" % [_round_index, seat, Card.Suit.keys()[step[0]], step[1], turn])
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
	active = false
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
		if result.has(entry.round):
			push_error("TutorialGame line %d: round %d is listed twice" % [yaml.item_lines[i], entry.round])
			continue
		result[entry.round] = entry
	return result

static func _clean_round(raw, line: int):
	if raw is Dictionary and raw.has("match"):
		push_error("TutorialGame line %d: 'match' was renamed to 'round', write 'round: %s'" % [line, str(raw["match"])])
		return null
	if not raw is Dictionary or not raw.get("round") is int or raw.round < 1:
		push_error("TutorialGame line %d: entry needs 'round' with a number of 1 or more" % line)
		return null
	for key in raw.keys():
		if not key in ALLOWED_KEYS:
			push_error("TutorialGame line %d: unknown key '%s' (allowed: %s)" % [line, key, ", ".join(ALLOWED_KEYS)])
			return null
	var entry := {"round": raw.round, "hands": {}, "plays": {}, "smokes": {}}
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
		if cards.size() != HAND_SIZE:
			push_error("TutorialGame line %d: %s needs exactly %d cards, found %d" % [line, key, HAND_SIZE, cards.size()])
			return null
		entry.hands[seat] = cards
	for seat in [1, 2]:
		var key: String = PLAY_KEYS[seat - 1]
		if not raw.has(key):
			continue
		var plan: Array = []
		var smokes := {}
		for raw_word in _words(raw[key]):
			var word: String = raw_word
			var parts := word.split("+", false, 1)
			if parts.size() == 2 and parts[0].strip_edges().to_lower() == SMOKE_WORD:
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
