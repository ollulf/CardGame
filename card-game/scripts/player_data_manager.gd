extends Node

signal stats_changed(player_id: int)
signal money_changed(money: int)
signal booster_bought
signal collection_changed
signal deck_changed
signal buttons_unlock_changed

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
const STARTING_MONEY := 9
const CIGARETTE_PACK_PRICE := 5
const CIGARETTES_PER_PACK := 8
const BOOSTER_PRICE := 8

var smoking_stacks := {
	0: [],
	1: [],
	2: []
}

var drinking_level := 0

var money := 0
var starting_money_granted := false

var collection: Array[Card] = []
var active_deck: Array[Card] = []
var new_cards: Array[Card] = []

func _ready() -> void:
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.new_match_started.connect(clear_smoking)

func smoke(player_id: int, amount: int) -> void:
	if amount <= 0:
		return
	smoking_stacks[player_id].append({
		"amount": amount
	})
	stats_changed.emit(player_id)

func drink() -> void:
	drinking_level -= 1

func get_smoking(player_id: int) -> int:
	var total := 0
	for stack in smoking_stacks[player_id]:
		total += int(stack.get("amount", 0))
	return total

func get_smoking_stack_count(player_id: int) -> int:
	return smoking_stacks[player_id].size()

func get_drinking(player_id: int) -> int:
	return drinking_level

func clear_smoking() -> void:
	for pid in PLAYERS:
		if smoking_stacks[pid].is_empty():
			continue
		smoking_stacks[pid].clear()
		stats_changed.emit(pid)

func _on_round_finished(_loosers) -> void:
	clear_smoking()

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

func buy_cigarettes() -> bool:
	if InteractionManager.cigPack == null or not spend(CIGARETTE_PACK_PRICE):
		return false
	InteractionManager.cigPack.add_cigarettes(CIGARETTES_PER_PACK)
	return true

func buy_booster() -> bool:
	if not spend(BOOSTER_PRICE):
		return false
	booster_bought.emit()
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
		"collection": collection.duplicate(),
		"active_deck": active_deck.duplicate(),
		"new_cards": new_cards.duplicate(),
	}

func restore_state(state: Dictionary) -> void:
	starting_money_granted = state.get("starting_money_granted", false)
	set_money(state.get("money", 0))
	collection.assign(state.get("collection", []))
	active_deck.assign(state.get("active_deck", []))
	new_cards.assign(state.get("new_cards", []))
	clear_smoking()
	collection_changed.emit()
	deck_changed.emit()
