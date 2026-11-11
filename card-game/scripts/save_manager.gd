extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const CARD_KEYS := ["collection", "active_deck", "new_cards"]

var enabled := Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless"
var save_path := SAVE_PATH

func _ready() -> void:
	GameManager.new_match_started.connect(_on_new_match_started)
	GameManager.match_finished.connect(_on_match_finished)
	GameManager.run_won.connect(delete_save)

func has_save() -> bool:
	return not load_save().is_empty()

func load_save() -> Dictionary:
	if not enabled or not FileAccess.file_exists(save_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		push_warning("Save file %s is unreadable, ignoring it" % save_path)
		return {}
	if not (data.get("version") is float or data.get("version") is int) or int(data.version) != SAVE_VERSION:
		push_warning("Save file %s has version %s, expected %d, ignoring it" % [save_path, data.get("version"), SAVE_VERSION])
		return {}
	if not data.get("state") is Dictionary or not data.get("game_start") is Dictionary:
		push_warning("Save file %s is missing its state, ignoring it" % save_path)
		return {}
	var state = state_from_data(data.state)
	var game_start = state_from_data(data.game_start)
	if state == null or game_start == null:
		push_warning("Save file %s has broken card data, ignoring it" % save_path)
		return {}
	return {
		"state": state,
		"game_start": game_start,
		"between_matches": data.get("between_matches") == true,
		"booster_collected": data.get("booster_collected") == true,
		"deck_edited": data.get("deck_edited") == true,
		"player_name": PlayerDataManager.clean_player_name(data.get("player_name")),
		"tips_shown": data.get("tips_shown", []),
	}

func continue_run(save: Dictionary) -> void:
	PlayerDataManager.booster_collected = save.booster_collected
	PlayerDataManager.deck_edited = save.deck_edited
	PlayerDataManager.set_player_name(save.player_name)
	TutorialPopups.load_shown(save.tips_shown)
	PlayerDataManager.buttons_unlock_changed.emit()
	GameManager.resume_run(save.state, save.game_start, save.between_matches)

func write_save(state: Dictionary, game_start: Dictionary, between_matches: bool) -> void:
	if not enabled:
		return
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"between_matches": between_matches,
		"booster_collected": PlayerDataManager.booster_collected,
		"deck_edited": PlayerDataManager.deck_edited,
		"player_name": PlayerDataManager.player_name,
		"tips_shown": TutorialPopups.shown,
		"state": state_to_data(state),
		"game_start": state_to_data(game_start),
	}
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(temp_path, save_path) != OK:
		push_warning("Could not replace save file %s" % save_path)

func delete_save() -> void:
	if enabled and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

func _on_new_match_started() -> void:
	var state: Dictionary = GameManager._match_start_state
	if int(state.get("match", 1)) <= 1:
		delete_save()
		return
	write_save(state, GameManager._game_start_state, false)

func _on_match_finished(_loosers) -> void:
	write_save(GameManager._capture_state(), GameManager._game_start_state, true)

static func state_to_data(state: Dictionary) -> Dictionary:
	var data := {}
	for key in state:
		if key in CARD_KEYS:
			data[key] = cards_to_data(state[key])
		else:
			data[key] = state[key]
	return data

static func state_from_data(data: Dictionary):
	var state := {
		"money": maxi(0, _int(data.get("money"), 0)),
		"starting_money_granted": data.get("starting_money_granted") == true,
		"smoke_unlocked": data.get("smoke_unlocked") == true,
		"match": maxi(1, _int(data.get("match"), 1)),
		"cigarettes": maxi(0, _int(data.get("cigarettes"), 0)),
	}
	for key in CARD_KEYS:
		var cards = cards_from_data(data.get(key, []))
		if cards == null:
			return null
		state[key] = cards
	var offers: Array[int] = []
	var raw_offers = data.get("stamp_offers", [])
	if raw_offers is Array:
		for id in raw_offers:
			var stamp := _int(id, -1)
			if stamp > 0 and CardStamp.is_valid(stamp):
				offers.append(stamp)
	state["stamp_offers"] = offers
	state["stamp_offers_match"] = _int(data.get("stamp_offers_match"), 0)
	var booster_offers: Array[int] = []
	var raw_boosters = data.get("booster_offers", [])
	if raw_boosters is Array:
		for index in raw_boosters:
			var booster := _int(index, -1)
			booster_offers.append(booster if booster < PlayerDataManager.BOOSTERS.size() else -1)
	state["booster_offers"] = booster_offers
	state["booster_offers_match"] = _int(data.get("booster_offers_match"), 0)
	state["horst_deals"] = maxi(0, _int(data.get("horst_deals"), 0))
	state["horst_deals_match"] = maxi(0, _int(data.get("horst_deals_match"), 0))
	state["horst_offer_used"] = data.get("horst_offer_used") == true
	var tutorial = data.get("tutorial", {})
	if not tutorial is Dictionary:
		tutorial = {}
	state["tutorial"] = {
		"match": maxi(0, _int(tutorial.get("match"), 0)),
		"round_index": maxi(0, _int(tutorial.get("round_index"), 0)),
	}
	var loosers: Array[int] = []
	var raw_loosers = data.get("last_match_loosers", [])
	if raw_loosers is Array:
		for id in raw_loosers:
			var seat := _int(id, -1)
			if seat >= 0 and seat <= 2:
				loosers.append(seat)
	state["last_match_loosers"] = loosers
	var trump := _int(data.get("trump"), -1)
	state["trump"] = trump if trump >= 0 and trump <= Card.Suit.CLUBS else -1
	return state

static func cards_to_data(cards: Array) -> Array:
	var data: Array = []
	for card: Card in cards:
		if card.has_stamp():
			data.append([card.suit, card.printed_rank, card.owner, card.effect, card.stamp])
		elif card.has_effect():
			data.append([card.suit, card.printed_rank, card.owner, card.effect])
		else:
			data.append([card.suit, card.printed_rank, card.owner])
	return data

static func cards_from_data(data):
	if not data is Array:
		return null
	var cards: Array[Card] = []
	for entry in data:
		if not entry is Array or entry.size() < 2:
			return null
		var suit := _int(entry[0], -1)
		var rank := _int(entry[1], -1)
		var owner := _int(entry[2], -1) if entry.size() > 2 else Card.Owner.HUMAN
		var effect := _int(entry[3], -1) if entry.size() > 3 else CardEffect.Id.NONE
		var stamp := _int(entry[4], -1) if entry.size() > 4 else CardStamp.Id.NONE
		if suit < 0 or suit >= Card.Suit.size() or rank < 0 or rank > 9 or owner < 0 or owner >= Card.Owner.size() or not CardEffect.is_valid(effect) or not CardStamp.is_valid(stamp):
			return null
		cards.append(Card.new(suit, rank, owner, false, effect, stamp))
	return cards

static func _int(value, fallback: int) -> int:
	if value is float or value is int:
		return int(value)
	return fallback
