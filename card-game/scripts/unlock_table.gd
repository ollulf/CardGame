class_name UnlockTable
extends RefCounted

const UNLOCKS_PATH := "res://unlocks.yaml"
const TYPES := ["suit", "rank", "effect", "special", "booster"]
const CARD_TYPES := ["suit", "rank", "effect", "special"]
const TIERS := ["common", "rare", "special"]
const SUIT_CODES := ["H", "D", "S", "C", "SM", "AL", "CL"]
const EFFECTS := ["draw_card", "suit_plus_one", "copy_last_rank", "change_trump"]
const CONDITION_KEYS := ["played", "won", "runs_won"]
const UNLOCK_KEYS := ["unlock", "type", "suits", "ranks", "card", "effect", "tier", "weight", "played", "won", "runs_won", "needs", "title", "text"]
const BOOSTER_KEYS := ["booster", "title", "common", "rare", "special", "cards", "needs"]
const MATCHES_PER_RUN := 5
const MAX_GAP := 6

var unlocks: Array[Dictionary] = []
var boosters: Array[Dictionary] = []
var errors: Array[String] = []
var warnings: Array[String] = []

static func load_file(path: String = UNLOCKS_PATH) -> UnlockTable:
	var table := UnlockTable.new()
	var yaml := YamlLite.parse_file(path, ["unlock", "booster"])
	table._collect(yaml)
	table.validate()
	return table

static func parse_text(text: String) -> UnlockTable:
	var table := UnlockTable.new()
	var yaml := YamlLite.new()
	yaml.entry_keys = ["unlock", "booster"]
	yaml.parse(text, "unlocks.yaml")
	table._collect(yaml)
	table.validate()
	return table

func _collect(yaml: YamlLite) -> void:
	for i in yaml.data.size():
		var raw = yaml.data[i]
		var line: int = yaml.item_lines[i]
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw.duplicate()
		entry["line"] = line
		if entry.has("unlock"):
			entry["id"] = str(entry.unlock)
			unlocks.append(entry)
		else:
			entry["id"] = str(entry.booster)
			boosters.append(entry)

func validate() -> void:
	var ids := {}
	for entry in unlocks:
		_check_keys(entry, UNLOCK_KEYS)
		if ids.has(entry.id):
			_error(entry, "id '%s' is used twice (first on line %d)" % [entry.id, ids[entry.id].line])
		ids[entry.id] = entry
		var type := str(entry.get("type", ""))
		if not type in TYPES:
			_error(entry, "type must be one of %s" % ", ".join(TYPES))
			continue
		if type in CARD_TYPES:
			if not str(entry.get("tier", "")) in TIERS:
				_error(entry, "tier must be one of %s" % ", ".join(TIERS))
			if not entry.get("weight") is int or entry.weight <= 0:
				_error(entry, "weight must be a whole number above 0")
		if type == "special":
			if card_of(entry).is_empty():
				_error(entry, "card must look like 'H 9'")
		elif type in CARD_TYPES:
			for code in suits_of(entry):
				if not code in SUIT_CODES:
					_error(entry, "unknown suit code '%s' (allowed: %s)" % [code, " ".join(SUIT_CODES)])
			if suits_of(entry).is_empty():
				_error(entry, "suits lists no suit codes")
			if ranks_of(entry).is_empty():
				_error(entry, "ranks must be a rank 0-9 or a range like 1-9")
		if type == "effect" or (type == "special" and entry.has("effect")):
			if not str(entry.get("effect", "")) in EFFECTS:
				_error(entry, "effect must be one of %s" % ", ".join(EFFECTS))
		for key in CONDITION_KEYS:
			if entry.has(key) and (not entry[key] is int or entry[key] < 0):
				_error(entry, "%s must be a whole number of 0 or more" % key)
		if not entry.has("played") and not entry.has("won") and not entry.has("runs_won") and not entry.has("needs"):
			_error(entry, "needs a condition (played, won, runs_won or needs)")
		if str(entry.get("title", "")) == "":
			_warn(entry, "has no title for the unlock popup")
	for entry in unlocks + boosters:
		for need in needs_of(entry):
			if not ids.has(need):
				_error(entry, "needs unknown unlock '%s'" % need)
	for booster in boosters:
		_check_keys(booster, BOOSTER_KEYS)
		for tier in TIERS:
			if count_range(booster.get(tier, 0)).is_empty():
				_error(booster, "%s must be a count like 2 or 1-2" % tier)
	if not errors.is_empty():
		return
	_check_cycles(ids)
	_check_pacing()
	_check_empty_slots()

func _check_keys(entry: Dictionary, allowed: Array) -> void:
	for key in entry:
		if key in ["line", "id"]:
			continue
		if not key in allowed:
			_error(entry, "unknown key '%s' (allowed: %s)" % [key, ", ".join(allowed)])

func _check_cycles(ids: Dictionary) -> void:
	for entry in unlocks:
		var seen := {}
		var stack: Array = needs_of(entry)
		while not stack.is_empty():
			var need: String = stack.pop_back()
			if need == entry.id:
				_error(entry, "needs itself through a chain of 'needs'")
				break
			if seen.has(need) or not ids.has(need):
				continue
			seen[need] = true
			stack.append_array(needs_of(ids[need]))

func _check_pacing() -> void:
	var timeline := played_timeline()
	var last := 0
	for step in timeline:
		if step.played - last > MAX_GAP:
			warnings.append("no new unlock between %d and %d matches played (gap of %d)" % [last, step.played, step.played - last])
		last = step.played
	for entry in unlocks:
		var own := int(entry.get("played", 0))
		var real := effective_played(entry.id)
		if real > own and entry.has("played"):
			_warn(entry, "says played %d but its needs delay it to %d" % [own, real])

func _check_empty_slots() -> void:
	for booster in boosters:
		var from := 0
		for need in needs_of(booster):
			from = maxi(from, effective_played(need))
		var profile := {"played": from, "won": from, "runs_won": from / MATCHES_PER_RUN}
		var open := unlocked_ids(profile)
		for tier in TIERS:
			var counts := count_range(booster.get(tier, 0))
			if counts[1] > 0 and tier_entries(open, tier).is_empty():
				warnings.append("booster '%s': %s slot is empty at %d matches, it falls back to a lower tier" % [booster.id, tier, from])

func _error(entry: Dictionary, message: String) -> void:
	errors.append("line %d '%s': %s" % [entry.line, entry.id, message])

func _warn(entry: Dictionary, message: String) -> void:
	warnings.append("line %d '%s': %s" % [entry.line, entry.id, message])

func find(id: String) -> Dictionary:
	for entry in unlocks:
		if entry.id == id:
			return entry
	return {}

func unlocked_ids(profile: Dictionary) -> Array:
	var open := {}
	var changed := true
	while changed:
		changed = false
		for entry in unlocks:
			if open.has(entry.id) or not _meets(entry, profile, open):
				continue
			open[entry.id] = true
			changed = true
	return open.keys()

func _meets(entry: Dictionary, profile: Dictionary, open: Dictionary) -> bool:
	for key in CONDITION_KEYS:
		if int(profile.get(key, 0)) < int(entry.get(key, 0)):
			return false
	for need in needs_of(entry):
		if not open.has(need):
			return false
	return true

func effective_played(id: String) -> int:
	var entry := find(id)
	if entry.is_empty():
		return 0
	var result := int(entry.get("played", 0))
	for need in needs_of(entry):
		if need != id:
			result = maxi(result, effective_played(need))
	return result

func played_timeline() -> Array:
	var steps := {}
	for entry in unlocks:
		if entry.has("won") or entry.has("runs_won"):
			continue
		var at := effective_played(entry.id)
		if not steps.has(at):
			steps[at] = []
		steps[at].append(entry.id)
	var keys := steps.keys()
	keys.sort()
	var result: Array = []
	for at in keys:
		result.append({"played": at, "ids": steps[at]})
	return result

func is_booster_open(booster: Dictionary, open: Array) -> bool:
	for need in needs_of(booster):
		if not need in open:
			return false
	return true

func tier_entries(open: Array, tier: String) -> Array:
	var result: Array = []
	for entry in unlocks:
		if entry.id in open and entry.get("type") in CARD_TYPES and entry.get("tier") == tier:
			result.append(entry)
	return result

func slot_tier(open: Array, tier: String) -> String:
	var index := TIERS.find(tier)
	while index >= 0:
		if not tier_entries(open, TIERS[index]).is_empty():
			return TIERS[index]
		index -= 1
	return ""

func booster_odds(booster: Dictionary, open: Array) -> Dictionary:
	var expected := {}
	for tier in TIERS:
		var counts := count_range(booster.get(tier, 0))
		var slots: float = (counts[0] + counts[1]) / 2.0
		if slots <= 0.0:
			continue
		var real := slot_tier(open, tier)
		if real == "":
			continue
		var entries := tier_entries(open, real)
		var total := 0
		for entry in entries:
			total += int(entry.weight)
		for entry in entries:
			expected[entry.id] = expected.get(entry.id, 0.0) + slots * float(entry.weight) / total
	return expected

func roll_booster(booster: Dictionary, open: Array, rng: RandomNumberGenerator) -> Array:
	var cards: Array = []
	for tier in TIERS:
		var counts := count_range(booster.get(tier, 0))
		var real := slot_tier(open, tier)
		if real == "":
			continue
		var entries := tier_entries(open, real)
		for i in rng.randi_range(counts[0], counts[1]):
			cards.append(_roll_card(_pick(entries, rng), rng))
	return cards

func _pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in entries:
		total += int(entry.weight)
	var roll := rng.randi_range(1, total)
	for entry in entries:
		roll -= int(entry.weight)
		if roll <= 0:
			return entry
	return entries.back()

func _roll_card(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if entry.type == "special":
		var card := card_of(entry)
		return {"id": entry.id, "suit": card[0], "rank": card[1], "effect": str(entry.get("effect", ""))}
	var suits := suits_of(entry)
	var ranks := ranks_of(entry)
	return {"id": entry.id, "suit": suits[rng.randi_range(0, suits.size() - 1)], "rank": ranks[rng.randi_range(0, ranks.size() - 1)], "effect": str(entry.get("effect", ""))}

func simulate_players(players: int, runs: int, win_chance: float, seed_value: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var reached := {}
	for entry in unlocks:
		reached[entry.id] = []
	for p in players:
		var profile := {"played": 0, "won": 0, "runs_won": 0}
		var found := {}
		for run in range(1, runs + 1):
			for m in MATCHES_PER_RUN:
				profile.played += 1
				if rng.randf() >= win_chance:
					break
				profile.won += 1
				if m == MATCHES_PER_RUN - 1:
					profile.runs_won += 1
			for id in unlocked_ids(profile):
				if not found.has(id):
					found[id] = run
		for entry in unlocks:
			reached[entry.id].append(found.get(entry.id, runs + 1))
	var result := {}
	for id in reached:
		var list: Array = reached[id]
		list.sort()
		result[id] = {"median": list[list.size() / 2], "p90": list[int(list.size() * 0.9)], "never": list.count(runs + 1)}
	return result

static func needs_of(entry: Dictionary) -> Array:
	return _words(entry.get("needs", ""))

static func suits_of(entry: Dictionary) -> Array:
	var result: Array = []
	for word in _words(entry.get("suits", "")):
		result.append(word.to_upper())
	return result

static func ranks_of(entry: Dictionary) -> Array:
	var span := count_range(entry.get("ranks", ""))
	if span.is_empty() or span[0] > 9 or span[1] > 9:
		return []
	return range(span[0], span[1] + 1)

static func card_of(entry: Dictionary) -> Array:
	var parts := str(entry.get("card", "")).split(" ", false)
	if parts.size() != 2 or not parts[0].to_upper() in SUIT_CODES or not parts[1].is_valid_int():
		return []
	var rank := parts[1].to_int()
	if rank < 0 or rank > 9:
		return []
	return [parts[0].to_upper(), rank]

static func count_range(value) -> Array:
	if value is int:
		return [value, value] if value >= 0 else []
	var parts := str(value).split("-", false)
	if parts.size() == 1 and parts[0].strip_edges().is_valid_int():
		var single := parts[0].strip_edges().to_int()
		return [single, single]
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
		return []
	var low := parts[0].strip_edges().to_int()
	var high := parts[1].strip_edges().to_int()
	if low < 0 or high < low:
		return []
	return [low, high]

static func _words(value) -> Array:
	var result: Array = []
	for word in str(value).replace(",", " ").split(" ", false):
		result.append(word)
	return result
