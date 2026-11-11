extends Node

signal stats_changed(player_id: int)
signal smoke_unlocked_changed
signal money_changed(money: int)
signal booster_bought(booster: Dictionary)
signal collection_changed
signal deck_changed
signal buttons_unlock_changed
signal stamp_offers_changed
signal booster_offers_changed
signal stamp_applied(card: Card)
signal horst_changed

var booster_collected := false
var deck_edited := false

func mark_booster_collected() -> void:
	booster_collected = true
	buttons_unlock_changed.emit()

func mark_deck_edited() -> void:
	deck_edited = true
	buttons_unlock_changed.emit()

func reset_buttons_unlock() -> void:
	booster_collected = false
	deck_edited = false
	buttons_unlock_changed.emit()

const PLAYERS: Array[int] = [0, 1, 2]
const PLAYER_NAME_MAX := 12
const SMOKE_BONUS_PER_CIGARETTE := 1
const STARTING_MONEY := 16
const CIGARETTE_PACK_PRICE := 6
const CIGARETTES_PER_PACK := 6
const MAX_SMOKE_BONUS := 3
const PLAYER_SMOKE_ROOM := 999
const DRINK_PENALTY_PER_ROUND := 1
const DRINK_BONUS_PER_DRINK := 1
const DRINK_ROUND_PRICE := 5
const DRINK_ROUND_FROM_MATCH := 3
const STAMPS_FROM_MATCH := 4
const SMOKES_FROM_MATCH := 3
const ALK_BOOSTER_CARDS_FROM_MATCH := 4
const HORST_FROM_MATCH := 2
const HORST_CARDS_PER_DEAL := 3
const HORST_DEAL_PAY := 1
const HORST_DEALS_PER_VISIT := 1
const HORST_OFFER_FROM_MATCH := 4
const HORST_OFFER_PRICE := 4
const BOOSTER_OFFERS_PER_MATCH := 4
const BOOSTERS: Array[Dictionary] = [
	{"name": "Common Booster", "symbol": "common", "price": 4, "cards": 8, "specials": 1, "suits": "normal", "weight": 0, "tint": Color(0.8, 0.8, 0.84, 1), "contents": "common suits, 1 special"},
	{"name": "Random Booster", "symbol": "random", "price": 5, "cards": 8, "specials": 1, "suits": "all", "weight": 30, "tint": Color(0.78, 0.88, 1.0, 1), "contents": "any suit, 1 special"},
	{"name": "Smoke Booster", "symbol": "smoke", "price": 7, "cards": 3, "specials": 1, "suits": "smoke", "weight": 20, "tint": Color(0.62, 0.62, 0.68, 1), "contents": "smoke trumps, 1 special"},
	{"name": "Drink Booster", "symbol": "drink", "price": 7, "cards": 3, "specials": 1, "suits": "drink", "weight": 20, "from_match": ALK_BOOSTER_CARDS_FROM_MATCH, "tint": Color(0.95, 0.72, 0.45, 1), "contents": "drink trumps, 1 special"},
	{"name": "Special Booster", "symbol": "special", "price": 8, "cards": 2, "specials": 2, "suits": "all", "weight": 10, "tint": Color(1.0, 0.82, 0.35, 1), "contents": "2 specials"},
]

var smoking_stacks := {
	0: [],
	1: [],
	2: []
}

var drinking_levels := {
	0: 0,
	1: 0,
	2: 0
}

var player_name := ""
var money := 0
var starting_money_granted := false
var smoke_unlocked := false

var collection: Array[Card] = []
var active_deck: Array[Card] = []
var new_cards: Array[Card] = []
var stamp_offers: Array[int] = []
var stamp_offers_match := 0
var booster_offers: Array[int] = []
var booster_offers_match := 0
var horst_deals := 0
var horst_deals_match := 0
var horst_offer_used := false

func _ready() -> void:
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.new_match_started.connect(clear_smoking)
	GameManager.match_lost.connect(_on_match_over)
	GameManager.match_finished.connect(_on_match_over)
	GameManager.run_won.connect(_on_match_over)

func smoke(player_id: int, amount: int) -> void:
	amount = mini(amount, smoke_room(player_id))
	if amount <= 0:
		return
	smoking_stacks[player_id].append({
		"amount": amount
	})
	stats_changed.emit(player_id)

func unlock_smoke() -> void:
	if smoke_unlocked:
		return
	smoke_unlocked = true
	smoke_unlocked_changed.emit()

func drink(player_id: int) -> void:
	drinking_levels[player_id] += 1
	stats_changed.emit(player_id)

func get_smoking(player_id: int) -> int:
	var total := 0
	for stack in smoking_stacks[player_id]:
		total += int(stack.get("amount", 0))
	return total

func smoke_room(player_id: int) -> int:
	if player_id == 0:
		return PLAYER_SMOKE_ROOM
	return maxi(0, MAX_SMOKE_BONUS - get_smoking(player_id))

func cigarettes_until_cap(player_id: int) -> int:
	return smoke_room(player_id) / maxi(SMOKE_BONUS_PER_CIGARETTE, 1)

func get_smoking_stack_count(player_id: int) -> int:
	return smoking_stacks[player_id].size()

func get_drinking(player_id: int) -> int:
	return int(drinking_levels[player_id])

func get_drink_penalty(player_id: int) -> int:
	return get_drinking(player_id) * DRINK_PENALTY_PER_ROUND

func get_drink_bonus(player_id: int) -> int:
	return get_drinking(player_id) * DRINK_BONUS_PER_DRINK

func clear_drinking() -> void:
	for pid in PLAYERS:
		if drinking_levels[pid] == 0:
			continue
		drinking_levels[pid] = 0
		stats_changed.emit(pid)

func is_round_of_drinks_available() -> bool:
	return DialogueManager.upcoming_match() >= DRINK_ROUND_FROM_MATCH

func buy_round_of_drinks() -> bool:
	return is_round_of_drinks_available() and spend(DRINK_ROUND_PRICE)

func clear_smoking() -> void:
	for pid in PLAYERS:
		if smoking_stacks[pid].is_empty():
			continue
		smoking_stacks[pid].clear()
		stats_changed.emit(pid)

func _on_round_finished(_loosers) -> void:
	clear_smoking()

func _on_match_over(_arg = null) -> void:
	clear_drinking()

func set_player_name(value) -> void:
	player_name = clean_player_name(value)

static func clean_player_name(value) -> String:
	if not value is String:
		return ""
	return value.strip_edges().left(PLAYER_NAME_MAX)

func grant_starting_money() -> void:
	if starting_money_granted:
		return
	starting_money_granted = true
	set_money(STARTING_MONEY)

func set_money(value: int) -> void:
	value = max(value, 0)
	if value == money:
		return
	money = value
	money_changed.emit(money)

func add_money(amount: int) -> void:
	set_money(money + amount)

func can_afford(price: int) -> bool:
	return money >= price

func spend(price: int) -> bool:
	if price < 0 or not can_afford(price):
		return false
	set_money(money - price)
	return true

func is_cig_machine_available() -> bool:
	return DialogueManager.upcoming_match() >= SMOKES_FROM_MATCH

func buy_cigarettes() -> bool:
	if not is_cig_machine_available() or InteractionManager.cigPack == null or not spend(CIGARETTE_PACK_PRICE):
		return false
	return true

func deliver_cigarettes() -> void:
	if InteractionManager.cigPack != null:
		InteractionManager.cigPack.add_cigarettes(CIGARETTES_PER_PACK)

func is_booster_available(booster: Dictionary) -> bool:
	return DialogueManager.upcoming_match() >= int(booster.get("from_match", 0))

func buy_booster(booster: Dictionary) -> bool:
	if not spend(booster["price"]):
		return false
	booster_bought.emit(booster)
	return true

func get_booster_offers() -> Array[int]:
	var match_number := DialogueManager.upcoming_match()
	if booster_offers_match != match_number:
		booster_offers_match = match_number
		booster_offers.assign(roll_booster_offers())
		booster_offers_changed.emit()
	return booster_offers

func roll_booster_offers() -> Array[int]:
	var pool: Array[int] = []
	for i in range(1, BOOSTERS.size()):
		if is_booster_available(BOOSTERS[i]):
			pool.append(i)
	var offers: Array[int] = [0]
	while offers.size() < BOOSTER_OFFERS_PER_MATCH:
		if pool.is_empty():
			offers.append(-1)
			continue
		var pick := _weighted_booster(pool)
		offers.append(pick)
		pool.erase(pick)
	return offers

func _weighted_booster(pool: Array[int]) -> int:
	var total := 0
	for i in pool:
		total += _offer_weight(i)
	var roll := randi_range(1, maxi(total, 1))
	for i in pool:
		roll -= _offer_weight(i)
		if roll <= 0:
			return i
	return pool[0]

func _offer_weight(index: int) -> int:
	return int(BOOSTERS[index].get("weight", 1))

func buy_booster_offer(index: int) -> bool:
	var offers := get_booster_offers()
	if index < 0 or index >= offers.size() or offers[index] < 0:
		return false
	var booster := BOOSTERS[offers[index]]
	if not can_afford(booster["price"]):
		return false
	offers[index] = -1
	booster_offers_changed.emit()
	return buy_booster(booster)

func add_to_collection(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	collection.append_array(cards)
	new_cards.append_array(cards)
	collection_changed.emit()

func has_active_deck() -> bool:
	return active_deck.size() >= Missions.DECK_MIN and active_deck.size() <= Missions.DECK_MAX

func starter_deck() -> Array[Card]:
	var cards: Array[Card] = []
	for entry in Missions.deck_cards(1, 0):
		cards.append(Card.new(entry[0], entry[1], Card.Owner.HUMAN, false))
	return cards

func init_active_deck(cards: Array[Card]) -> void:
	if not active_deck.is_empty():
		return
	for card in cards:
		active_deck.append(card.copy_for(Card.Owner.HUMAN))
	deck_changed.emit()

func move_to_deck(card: Card) -> bool:
	if active_deck.size() >= Missions.DECK_MAX or not collection.has(card):
		return false
	collection.erase(card)
	active_deck.append(card)
	deck_changed.emit()
	return true

func move_to_collection(card: Card) -> bool:
	if not active_deck.has(card):
		return false
	active_deck.erase(card)
	collection.append(card)
	deck_changed.emit()
	return true

func clear_new_cards() -> void:
	new_cards.clear()

func active_deck_copy() -> Array[Card]:
	var cards: Array[Card] = []
	for card in active_deck:
		cards.append(card.copy_for(Card.Owner.HUMAN))
	cards.shuffle()
	return cards

func are_stamps_available() -> bool:
	return DialogueManager.upcoming_match() >= STAMPS_FROM_MATCH

func get_stamp_offers() -> Array[int]:
	var match_number := DialogueManager.upcoming_match()
	if stamp_offers_match != match_number:
		stamp_offers_match = match_number
		stamp_offers.clear()
		stamp_offers.append_array(CardStamp.random_ids(CardStamp.OFFERS_PER_MATCH))
		stamp_offers_changed.emit()
	return stamp_offers

func buy_stamp(index: int) -> int:
	var offers := get_stamp_offers()
	if not are_stamps_available() or index < 0 or index >= offers.size() or not has_stampable_card():
		return CardStamp.Id.NONE
	var stamp := offers[index]
	if not spend(CardStamp.price(stamp)):
		return CardStamp.Id.NONE
	offers.remove_at(index)
	stamp_offers_changed.emit()
	return stamp

func stampable_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for card in active_deck + collection:
		if CardStamp.can_stamp(card):
			cards.append(card)
	return cards

func has_stampable_card() -> bool:
	return not stampable_cards().is_empty()

func apply_stamp(card: Card, stamp: int) -> bool:
	if not CardStamp.can_stamp(card) or stamp == CardStamp.Id.NONE:
		return false
	var in_deck := active_deck.has(card)
	var list := active_deck if in_deck else collection
	var index := list.find(card)
	if index < 0:
		return false
	var stamped := card.copy_for(card.owner)
	stamped.set_stamp(stamp)
	list[index] = stamped
	var new_index := new_cards.find(card)
	if new_index >= 0:
		new_cards[new_index] = stamped
	stamp_applied.emit(stamped)
	if in_deck:
		deck_changed.emit()
	else:
		collection_changed.emit()
	return true

func is_horst_available() -> bool:
	return DialogueManager.upcoming_match() >= HORST_FROM_MATCH

func horst_deals_left() -> int:
	if horst_deals_match != DialogueManager.upcoming_match():
		return HORST_DEALS_PER_VISIT
	return maxi(0, HORST_DEALS_PER_VISIT - horst_deals)

static func horst_weight(card: Card) -> int:
	return HORST_CARDS_PER_DEAL if card.has_effect() else 1

static func horst_weight_of(cards: Array[Card]) -> int:
	var total := 0
	for card in cards:
		total += horst_weight(card)
	return total

func horst_keeps_floor(cards: Array[Card]) -> bool:
	return active_deck.size() + collection.size() - cards.size() >= Missions.DECK_MIN

func can_sell_to_horst(cards: Array[Card]) -> bool:
	if not is_horst_available() or horst_deals_left() <= 0 or horst_weight_of(cards) != HORST_CARDS_PER_DEAL:
		return false
	for i in cards.size():
		if not collection.has(cards[i]) or cards.find(cards[i]) != i:
			return false
	return horst_keeps_floor(cards)

func sell_to_horst(cards: Array[Card]) -> bool:
	if not can_sell_to_horst(cards):
		return false
	for card in cards:
		collection.erase(card)
		new_cards.erase(card)
	var match_number := DialogueManager.upcoming_match()
	if horst_deals_match != match_number:
		horst_deals_match = match_number
		horst_deals = 0
	horst_deals += 1
	add_money(HORST_DEAL_PAY)
	collection_changed.emit()
	horst_changed.emit()
	return true

func is_horst_offer_available() -> bool:
	return not horst_offer_used and DialogueManager.upcoming_match() >= HORST_OFFER_FROM_MATCH

func buy_horst_offer() -> Card:
	if not is_horst_offer_available() or not spend(HORST_OFFER_PRICE):
		return null
	horst_offer_used = true
	var card := roll_horst_card(DialogueManager.upcoming_match())
	var cards: Array[Card] = [card]
	add_to_collection(cards)
	horst_changed.emit()
	return card

static func roll_horst_card(match_number: int) -> Card:
	var rank := randi_range(Missions.LOWEST_RANK, 9)
	var suits: Array[Card.Suit] = [Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES, Card.Suit.CLUBS]
	var effects := BoosterWindow.special_effects()
	if not effects.is_empty() and randf() < 0.5:
		var special_suits := suits.duplicate()
		special_suits.append_array(BoosterWindow.trump_suits(match_number))
		return Card.new(special_suits.pick_random(), rank, Card.Owner.HUMAN, false, effects.pick_random())
	return Card.new(suits.pick_random(), rank, Card.Owner.HUMAN, false, CardEffect.Id.NONE, CardStamp.random_id())

func capture_state() -> Dictionary:
	return {
		"stamp_offers": stamp_offers.duplicate(),
		"stamp_offers_match": stamp_offers_match,
		"booster_offers": booster_offers.duplicate(),
		"booster_offers_match": booster_offers_match,
		"horst_deals": horst_deals,
		"horst_deals_match": horst_deals_match,
		"horst_offer_used": horst_offer_used,
		"money": money,
		"starting_money_granted": starting_money_granted,
		"smoke_unlocked": smoke_unlocked,
		"collection": collection.duplicate(),
		"active_deck": active_deck.duplicate(),
		"new_cards": new_cards.duplicate(),
	}

func restore_state(state: Dictionary) -> void:
	starting_money_granted = state.get("starting_money_granted", false)
	smoke_unlocked = state.get("smoke_unlocked", false)
	set_money(state.get("money", 0))
	collection.assign(state.get("collection", []))
	active_deck.assign(state.get("active_deck", []))
	_top_up_active_deck()
	new_cards.assign(state.get("new_cards", []))
	stamp_offers.assign(state.get("stamp_offers", []))
	stamp_offers_match = state.get("stamp_offers_match", 0)
	booster_offers.assign(state.get("booster_offers", []))
	booster_offers_match = state.get("booster_offers_match", 0)
	horst_deals = state.get("horst_deals", 0)
	horst_deals_match = state.get("horst_deals_match", 0)
	horst_offer_used = state.get("horst_offer_used", false)
	horst_changed.emit()
	booster_offers_changed.emit()
	stamp_offers_changed.emit()
	clear_smoking()
	clear_drinking()
	smoke_unlocked_changed.emit()
	collection_changed.emit()
	deck_changed.emit()

func _top_up_active_deck() -> void:
	if active_deck.is_empty() or active_deck.size() >= Missions.DECK_MIN:
		return
	active_deck.append_array(CardManager.generate_cards(Missions.DECK_MIN - active_deck.size(), Card.Owner.HUMAN, 1))
