extends Player
class_name AIPlayer

# Visual settings
@export var show_hand: bool = true

# Layout
@export var card_space: float = 320
@export var MAX_GAP := 70.0

@export var auto_smoke: bool = true
@export_range(0.0, 1.0) var smoke_chance: float = 0.2
@export var smoke_offset := Vector2(46.0, 6.0)
@export var smoke_stack_step := Vector2(22.0, 26.0)

@export var auto_drink: bool = true
@export_range(0.0, 1.0) var drink_chance: float = 0.15
@export var drink_offset := Vector2(150.0, -40.0)
@export_range(0.0, 1.0) var order_round_chance: float = 0.6

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


func drink(on_the_house := false) -> void:
	if not on_the_house and not Missions.can_drink(player_id):
		return
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
	if on_the_house:
		art.sipped.connect(PlayerDataManager.drink.bind(player_id), CONNECT_ONE_SHOT)
	else:
		art.sipped.connect(func(): PlayerDataManager.take_drink(player_id), CONNECT_ONE_SHOT)
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
	if not auto_drink or TutorialScript.is_scripted() or hand == null:
		return false
	if not PlayerDataManager.is_round_of_drinks_available() or _ordered_this_round:
		return false
	if Missions.budget_left(player_id) < PlayerDataManager.DRINK_ROUND_PRICE:
		return false
	var alk_cards := _alk_cards_in_hand()
	if alk_cards == 0 or alk_cards < hand.cards.size() - alk_cards:
		return false
	return not Missions.can_drink(player_id) or randf() < order_round_chance


func _wants_to_drink() -> bool:
	if not auto_drink or TutorialScript.is_scripted():
		return false
	if not Missions.can_drink(player_id) or hand == null:
		return false
	var alk_cards := _alk_cards_in_hand()
	if alk_cards == 0:
		return false
	return alk_cards >= hand.cards.size() - alk_cards or randf() < drink_chance


func _free_smoke_slot() -> int:
	var used := _smoke_visuals.map(func(v): return v.get_meta("slot"))
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


func _wants_to_smoke() -> bool:
	if not auto_smoke or TutorialScript.is_scripted():
		return false
	if not Missions.can_smoke(player_id):
		return false
	if hand == null or not hand.has_trump_card():
		return false
	return randf() < smoke_chance


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
	elif _wants_to_smoke():
		smoke()
	if _wants_to_order_round():
		await order_round_of_drinks()
		if token != GameManager.round_token:
			return
	elif _wants_to_drink():
		await drink()
		if token != GameManager.round_token:
			return

	# Play Delay
	await get_tree().create_timer(3.0, false).timeout
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
	# If no lead yet, dump a random card
	if CardManager.leading_card == null:
		return hand.cards[randi() % hand.size()]

	var winning_zero := _zero_beating_table()
	if winning_zero != null:
		return winning_zero

	# Highest rank already played in lead suit
	var lead_card := CardManager.leading_card

	if lead_card.is_trump:
		if hand.has_trump_card():
			return hand.get_highest_trump_card()
		return hand.get_lowest_card()

	# Try play the highest card that follows the lead card
	var highest_card = hand.get_random_higher_card_than(lead_card)
	
	if highest_card != null:
		return highest_card

	# Try play the lowest now since if we can not go over the lead card
	var lowest_card = hand.get_lowest_card_of_suit(lead_card.suit)
	
	if lowest_card != null:
		return lowest_card

# --- WE DON'T HAVE TO FOLLOW THE LEADING SUIT ---

	var first_trump_card = CardManager.first_trump_card

# If no trump has been played and we have one play a random trump
	if first_trump_card == null:
		var trumps = hand.get_trump_cards()
		if trumps.size() != 0:
			return trumps[randi() % trumps.size()]
		else:
			return hand.get_lowest_card()

# If there is a first played trump card we try to play over it
	if first_trump_card != null:
		var higher_trump_card = hand.get_random_higher_card_than(first_trump_card)
		
		if higher_trump_card != null:
			return higher_trump_card

#If we cant play over it we play our lowest card
	return hand.get_lowest_card()


func _zero_beating_table() -> Card:
	if CardManager.turn_won_by_zero():
		return null
	var best := CardManager.get_normal_winning_card()
	if best == null or best.rank < CardManager.ZERO_BEATS_RANK:
		return null
	for card in hand.cards:
		if card.rank == 0 and card.suit == best.suit and CardManager.is_legal_play(hand, card):
			return card
	return null


func render_hand() -> void:
	for card_visual in card_visuals:
		if is_instance_valid(card_visual):
			card_visual.queue_free()

	card_visuals.clear()

	for card in hand.cards:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual

		c.setup(card, not show_hand)
		c.hover_enabled = false
		_make_passive(c)

		add_child(c)
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
	_make_passive(c)
	add_child(c)
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
