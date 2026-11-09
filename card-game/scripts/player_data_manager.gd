extends Node

signal stats_changed(player_id: int)
signal smoke_unlocked_changed
signal money_changed(money: int)
signal booster_bought(booster: Dictionary)
signal collection_changed
signal deck_changed
signal buttons_unlock_changed
signal cig_machine_changed(unlocked: bool)

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
const SMOKE_BONUS_PER_CIGARETTE := 1
const STARTING_MONEY := 15
const CIGARETTE_PACK_PRICE := 5
const CIGARETTES_PER_PACK := 8
const DRINK_PENALTY_PER_ROUND := 1
const DRINK_BONUS_PER_DRINK := 1
const DRINK_ROUND_PRICE := 5
const DRINK_ROUND_FROM_MATCH := 3
const DRINKING_BOOSTER_FROM_MATCH := 4
const BOOSTERS: Array[Dictionary] = [
	{"name": "Smoke Booster", "price": 8, "cards": 5, "min_rank": 1, "max_rank": 9, "smoke_min": 2, "smoke_max": 3, "contents": "2-3 Smoke + basic suits"},
	{"name": "Standard Booster", "price": 5, "cards": 8, "min_rank": 1, "max_rank": 9, "smoke_min": 0, "smoke_max": 0, "contents": "Basic suits only"},
	{"name": "Premium Booster", "price": 12, "cards": 8, "min_rank": 5, "max_rank": 9, "smoke_min": 0, "smoke_max": 0, "contents": "Basic suits, ranks 5-9"},
	{"name": "Zero Booster", "price": 7, "cards": 2, "min_rank": 0, "max_rank": 0, "smoke_min": 0, "smoke_max": 0, "contents": "Two 0 cards, any suit", "any_suit": true, "from_match": 3},
	{"name": "Drinking Booster", "price": 8, "cards": 5, "min_rank": 1, "max_rank": 9, "smoke_min": 0, "smoke_max": 0, "alk_min": 2, "alk_max": 3, "contents": "2-3 Drinking + basic suits", "from_match": DRINKING_BOOSTER_FROM_MATCH},
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

var money := 0
var starting_money_granted := false
var cig_machine_unlocked := false
var smoke_unlocked := false

var collection: Array[Card] = []
var active_deck: Array[Card] = []
var new_cards: Array[Card] = []

func _ready() -> void:
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.new_match_started.connect(clear_smoking)
	GameManager.match_lost.connect(_on_match_over)
	GameManager.match_finished.connect(_on_match_over)
	GameManager.run_won.connect(_on_match_over)

func smoke(player_id: int, amount: int) -> void:
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

func get_smoking_stack_count(player_id: int) -> int:
	return smoking_stacks[player_id].size()

func get_drinking(player_id: int) -> int:
	return int(drinking_levels[player_id])

func get_drink_penalty(player_id: int) -> int:
	return get_drinking(player_id) * DRINK_PENALTY_PER_ROUND

func get_drink_bonus(player_id: int) -> int:
	return get_drinking(player_id) * DRINK_BONUS_PER_DRINK

func take_drink(player_id: int) -> bool:
	if not Missions.can_drink(player_id):
		return false
	Missions.use_drink(player_id)
	drink(player_id)
	return true

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

func unlock_cig_machine() -> void:
	set_cig_machine_unlocked(true)

func set_cig_machine_unlocked(value: bool) -> void:
	if cig_machine_unlocked == value:
		return
	cig_machine_unlocked = value
	cig_machine_changed.emit(value)

func buy_cigarettes() -> bool:
	if not cig_machine_unlocked or InteractionManager.cigPack == null or not spend(CIGARETTE_PACK_PRICE):
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

func add_to_collection(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	collection.append_array(cards)
	new_cards.append_array(cards)
	collection_changed.emit()

func has_active_deck() -> bool:
	return active_deck.size() == Missions.DECK_SIZE

func init_active_deck(cards: Array[Card]) -> void:
	if not active_deck.is_empty():
		return
	for card in cards:
		active_deck.append(Card.new(card.suit, card.base_rank, Card.Owner.HUMAN, false))
	deck_changed.emit()

func move_to_deck(card: Card) -> bool:
	if active_deck.size() >= Missions.DECK_SIZE or not collection.has(card):
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
		cards.append(Card.new(card.suit, card.base_rank, Card.Owner.HUMAN, false))
	cards.shuffle()
	return cards

func capture_state() -> Dictionary:
	return {
		"money": money,
		"starting_money_granted": starting_money_granted,
		"cig_machine_unlocked": cig_machine_unlocked,
		"smoke_unlocked": smoke_unlocked,
		"collection": collection.duplicate(),
		"active_deck": active_deck.duplicate(),
		"new_cards": new_cards.duplicate(),
	}

func restore_state(state: Dictionary) -> void:
	starting_money_granted = state.get("starting_money_granted", false)
	smoke_unlocked = state.get("smoke_unlocked", false)
	set_money(state.get("money", 0))
	set_cig_machine_unlocked(state.get("cig_machine_unlocked", false))
	collection.assign(state.get("collection", []))
	active_deck.assign(state.get("active_deck", []))
	_top_up_active_deck()
	new_cards.assign(state.get("new_cards", []))
	clear_smoking()
	clear_drinking()
	smoke_unlocked_changed.emit()
	collection_changed.emit()
	deck_changed.emit()

func _top_up_active_deck() -> void:
	if active_deck.is_empty() or active_deck.size() >= Missions.DECK_SIZE:
		return
	active_deck.append_array(CardManager.generate_cards(Missions.DECK_SIZE - active_deck.size(), Card.Owner.HUMAN, 1))
