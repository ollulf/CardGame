extends Player
class_name AIPlayer

# Visual settings
@export var show_hand: bool = false

# Layout
@export var card_space: float = 320
@export var MAX_GAP := 70.0

@export var auto_smoke: bool = true
@export_range(0.0, 1.0) var smoke_chance: float = 0.35
@export_range(0.0, 1.0) var smoke_chance_per_trump: float = 0.15
@export_range(0.0, 1.0) var smoke_chance_per_left: float = 0.03
@export var max_smokes_per_turn: int = 3
@export var smoke_offset := Vector2(46.0, 6.0)
@export var smoke_stack_step := Vector2(22.0, 26.0)

const THINK_TIME_MIN := 0.8
const THINK_TIME_MAX := 1.5

@export var auto_order_round: bool = true
@export var drink_offset := Vector2(150.0, -40.0)
@export_range(0.0, 1.0) var order_round_chance: float = 0.6

@export_range(0, 9) var lead_strong_rank: int = 8
@export_range(0.0, 1.0) var lead_strong_chance: float = 0.5
@export_range(0, 9) var safe_rank: int = 7
@export_range(0.0, 1.0) var safe_win_chance: float = 0.85
@export_range(0.0, 1.0) var bluff_chance: float = 0.03

const TRUMP_COST := 10.0
const SPECIAL_COST := 0.5
const ZERO_COST := 1.5
const PLAYERS_PER_TRICK := 3
const ENDGAME_TRICKS := 2

const DRINK_PIXEL_SCALE := 3.0
const DRINK_FADE_TIME := 0.3
const DRINK_LINGER_TIME := 0.6
const DRINK_LEFT_IN_GLASS := 0.35

var card_visuals : Array[CardVisual] = []
var _smoke_visuals: Array[AiSmoke] = []
var _ordered_this_round := false

func _ready() -> void:
	super._ready()

	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.round_started.connect(_on_round_started)

	GameManager.register(self)


func smoke(cigarettes: int = 1) -> void:
	if Missions.can_smoke(player_id):
		Missions.use_cigarette(player_id)
	var side := 1.0 if player_id == 1 else -1.0
	_smoke_visuals.assign(_smoke_visuals.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion()))
	var slot := _free_smoke_slot()
	var at := Vector2((smoke_offset.x + smoke_stack_step.x * slot) * side, smoke_offset.y + smoke_stack_step.y * slot)
	var visual := AiSmoke.spawn(self, at, 0.5 * side)
	visual.set_meta("slot", slot)
	_smoke_visuals.append(visual)
	await visual.lit
	CardManager.update_cards(cigarettes, player_id)


func drink(show_only := false) -> void:
	var side := 1.0 if player_id == 1 else -1.0
	var art := DrinkArt.new()
	art.scale = Vector2.ONE * DRINK_PIXEL_SCALE
	art.position = Vector2(drink_offset.x * side, drink_offset.y)
	art.z_index = 50
	art.modulate.a = 0.0
	add_child(art)
	var appear := art.create_tween()
	appear.tween_property(art, "modulate:a", 1.0, DRINK_FADE_TIME)
	await appear.finished
	if not show_only:
		art.sipped.connect(PlayerDataManager.drink.bind(player_id), CONNECT_ONE_SHOT)
	await art.play_sip(DRINK_LEFT_IN_GLASS, side)
	var fade := art.create_tween()
	fade.tween_interval(DRINK_LINGER_TIME)
	fade.tween_property(art, "modulate:a", 0.0, DRINK_FADE_TIME)
	fade.tween_callback(art.queue_free)


func order_round_of_drinks() -> void:
	if not Missions.spend_budget(player_id, PlayerDataManager.DRINK_ROUND_PRICE):
		return
	_ordered_this_round = true
	await GameManager.serve_round_of_drinks(player_id)


func _alk_cards_in_hand() -> int:
	var alk_cards := 0
	for card in hand.cards:
		if card.suit == Card.Suit.ALK:
			alk_cards += 1
	return alk_cards


func _wants_to_order_round() -> bool:
	if not auto_order_round or TutorialScript.is_scripted() or hand == null:
		return false
	if not PlayerDataManager.is_round_of_drinks_available() or _ordered_this_round:
		return false
	if Missions.budget_left(player_id) < PlayerDataManager.DRINK_ROUND_PRICE:
		return false
	var alk_cards := _alk_cards_in_hand()
	if alk_cards == 0 or alk_cards < hand.cards.size() - alk_cards:
		return false
	return randf() < order_round_chance


func _free_smoke_slot() -> int:
	var used := _smoke_visuals.map(func(v): return v.get_meta("slot"))
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


func _smokes_this_turn() -> int:
	if not auto_smoke or TutorialScript.is_scripted():
		return 0
	if hand == null:
		return 0
	var trumps := hand.cards.filter(func(c): return c.suit == Card.Suit.SMOKE).size()
	if trumps == 0:
		return 0
	var left := Missions.cigarettes_left(player_id)
	if left == 0:
		return 0
	var left_bonus := 10 if left == Missions.UNLIMITED else left
	var chance := smoke_chance + smoke_chance_per_trump * (trumps - 1) + smoke_chance_per_left * left_bonus
	var count := 0
	while count < max_smokes_per_turn and count < trumps and (left == Missions.UNLIMITED or count < left):
		if randf() >= clampf(chance, 0.0, 0.95):
			break
		count += 1
		chance *= 0.5
	return count


func recieve_hand(new_hand: Hand) -> void:
	hand = new_hand
	render_hand()

	hand.hand_shrinked.connect(on_hand_shrinked)


func on_hand_shrinked() -> void:
	layout_hand_cards()


func _on_turn_started(_turn_index: int, _starting_player_id: int) -> void:
	pass


func _on_round_started() -> void:
	_ordered_this_round = false


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	var token := GameManager.round_token
	await DialogueManager.wait_until_idle()
	if token != GameManager.round_token:
		return
	var planned_cigarettes := TutorialScript.planned_smoke(player_id, GameManager.current_turn)
	if planned_cigarettes > 0:
		await smoke(planned_cigarettes)
	else:
		for i in _smokes_this_turn():
			await smoke()
	if _wants_to_order_round():
		await order_round_of_drinks()
		if token != GameManager.round_token:
			return

	# Play Delay
	await get_tree().create_timer(randf_range(THINK_TIME_MIN, THINK_TIME_MAX), false).timeout
	await DialogueManager.wait_until_idle()
	if token != GameManager.round_token:
		return

	if hand.is_empty():
		print("AI Players hand is empty")
		set_active(false)
		CardManager.submit_play(player_id, null)
		return

	var chosen_card = TutorialScript.planned_card(player_id, hand, GameManager.current_turn)
	if chosen_card == null:
		chosen_card = choose_card()

	var from := get_card_transform(chosen_card)
	hand.remove(chosen_card)
	set_active(false)
	CardManager.submit_play(player_id, chosen_card, from)


func choose_card() -> Card:
	var legal: Array[Card] = hand.cards.filter(func(c): return CardManager.is_legal_play(hand, c))
	if legal.is_empty():
		return hand.cards[0]
	var behind := won_turns <= _fewest_other_wins()
	return choose_from(legal, CardManager.played_cards_turn.cards, hand.size(), behind)


func choose_from(legal: Array[Card], table: Array[Card], tricks_left: int, behind: bool) -> Card:
	var by_cost := legal.duplicate()
	by_cost.sort_custom(func(a, b): return card_cost(a) < card_cost(b))
	if legal.size() > 1 and randf() < bluff_chance:
		return legal.pick_random()
	if table.is_empty():
		return _choose_lead(by_cost, tricks_left, behind)
	return _choose_follow(by_cost, table)


func _choose_lead(by_cost: Array[Card], tricks_left: int, behind: bool) -> Card:
	var strongest: Card = by_cost.back()
	if behind and tricks_left <= ENDGAME_TRICKS:
		return strongest
	if _is_strong_lead(strongest) and randf() < lead_strong_chance:
		return strongest
	for card in by_cost:
		if not card.is_trump:
			return card
	return by_cost.front()


func _is_strong_lead(card: Card) -> bool:
	return card.is_trump and card.rank >= lead_strong_rank


func _choose_follow(by_cost: Array[Card], table: Array[Card]) -> Card:
	var winners: Array[Card] = by_cost.filter(func(c): return trick_winner(table + [c]) == c)
	if winners.is_empty():
		return by_cost.front()
	if table.size() >= PLAYERS_PER_TRICK - 1:
		return winners.front()
	var safe: Array[Card] = winners.filter(func(c): return c.is_trump or c.rank >= safe_rank)
	if not safe.is_empty() and randf() < safe_win_chance:
		return safe.front()
	return winners.front()


static func card_cost(card: Card) -> float:
	var cost := float(card.rank)
	if card.rank == 0:
		cost = ZERO_COST
	if card.is_trump:
		cost += TRUMP_COST
	if card.suit == Card.Suit.ALK or card.suit == Card.Suit.SMOKE:
		cost += SPECIAL_COST
	return cost


static func trick_winner(table: Array) -> Card:
	if table.is_empty():
		return null
	var best: Card = null
	for card in table:
		if card.is_trump and (best == null or card.rank > best.rank):
			best = card
	if best == null:
		best = table[0]
		for card in table:
			if card.suit == table[0].suit and card.rank > best.rank:
				best = card
	if best.rank >= CardManager.ZERO_BEATS_RANK:
		for card in table:
			if card.rank == 0 and card.suit == best.suit:
				return card
	return best


func _fewest_other_wins() -> int:
	var fewest := -1
	for other in [GameManager.human_player, GameManager.ai_player_1, GameManager.ai_player_2]:
		if other == self or not (other is Player):
			continue
		if fewest < 0 or other.won_turns < fewest:
			fewest = other.won_turns
	return maxi(fewest, 0)


func render_hand() -> void:
	for card_visual in card_visuals:
		if is_instance_valid(card_visual):
			card_visual.queue_free()

	card_visuals.clear()

	for card in hand.cards:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual

		c.setup(card, not show_hand)
		c.add_table_shadow()
		c.hover_enabled = false
		_make_passive(c)

		add_child(c)
		if not show_hand:
			c.show_back(true)
		card_visuals.append(c)

	layout_hand_cards()


func layout_hand_cards() -> void:
	card_visuals = card_visuals.filter(func(c):
		return is_instance_valid(c) and not c.is_queued_for_deletion()
	)

	var n = card_visuals.size()

	if n == 0:
		return

	for i in range(n):
		var cv = card_visuals[i]
		cv.position = _slot_position(i, n) - cv.size * 0.5
		cv.z_index = i
		cv.update_layout()
		_orient(cv)


func _orient(cv: CardVisual) -> void:
	cv.pivot_offset = cv.size * 0.5
	cv.rotation = _outward_rotation()


func _outward_rotation() -> float:
	return -PI * 0.5 if player_id == 1 else PI * 0.5


func _slot_position(index: int, count: int) -> Vector2:
	var gap = MAX_GAP

	if count > 1:
		gap = min(card_space / float(count - 1), MAX_GAP)

	var start_y = -gap * float(count - 1) * 0.5
	return Vector2(0.0, start_y + gap * float(index))


func deal_card(card: Card, from_center: Vector2, slot: int, slot_count: int) -> void:
	hand.append(card)
	var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
	c.setup(card, true)
	c.add_table_shadow()
	_make_passive(c)
	add_child(c)
	if not show_hand:
		c.show_back(true)
	card_visuals.append(c)
	c.position = _slot_position(slot, slot_count) - c.size * 0.5
	c.z_index = slot
	c.update_layout()
	_orient(c)
	Sfx.play_card_move()
	c.deal_from(Transform2D(0.0, Vector2.ONE, 0.0, from_center - c.pivot_offset), show_hand)


func _make_passive(card_visual: CardVisual) -> void:
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in card_visual.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func finish_deal() -> void:
	layout_hand_cards()
	for card_visual in card_visuals:
		card_visual.hover_enabled = false
