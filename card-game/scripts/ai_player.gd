extends Player
class_name AIPlayer

# Visual settings
@export var show_hand: bool = false

# Layout
@export var card_space: float = 320
@export var MAX_GAP := 70.0

@export var auto_smoke: bool = true
@export_range(0.0, 1.0) var smoke_chance: float = 0.35
@export var smoke_offset := Vector2(120.0, 190.0)

var card_visuals : Array[CardVisual] = []
var _smoked_this_round := false

func _ready() -> void:
	super._ready()

	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.round_started.connect(_on_round_started)

	GameManager.register(self)


func smoke(cigarettes: int = 1) -> void:
	_smoked_this_round = true
	var side := 1.0 if player_id == 1 else -1.0
	var visual := AiSmoke.spawn(self, Vector2(smoke_offset.x * side, smoke_offset.y), 0.5 * side)
	await visual.lit
	CardManager.update_cards(cigarettes, player_id)


func _wants_to_smoke() -> bool:
	if not auto_smoke or _smoked_this_round or TutorialScript.is_scripted():
		return false
	if hand == null or not hand.has_trump_card():
		return false
	return randf() < smoke_chance


func _on_round_started() -> void:
	_smoked_this_round = false


func recieve_hand(new_hand: Hand) -> void:
	hand = new_hand
	render_hand()

	hand.hand_shrinked.connect(on_hand_shrinked)


func on_hand_shrinked() -> void:
	layout_hand_cards()


func _on_turn_started(_turn_index: int, _starting_player_id: int) -> void:
	pass


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	var planned_cigarettes := TutorialScript.planned_smoke(player_id, GameManager.current_turn)
	if planned_cigarettes > 0:
		await smoke(planned_cigarettes)
	elif _wants_to_smoke():
		smoke()

	# Play Delay
	await get_tree().create_timer(3.0, false).timeout
	await DialogueManager.wait_until_idle()

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


func render_hand() -> void:
	for card_visual in card_visuals:
		if is_instance_valid(card_visual):
			card_visual.queue_free()

	card_visuals.clear()

	for card in hand.cards:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual

		c.setup(card, not show_hand)
		c.hover_enabled = false

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
	add_child(c)
	card_visuals.append(c)
	c.position = _slot_position(slot, slot_count) - c.size * 0.5
	c.z_index = slot
	c.update_layout()
	_orient(c)
	c.deal_from(Transform2D(0.0, Vector2.ONE, 0.0, from_center - c.pivot_offset), show_hand)


func finish_deal() -> void:
	layout_hand_cards()
	for card_visual in card_visuals:
		card_visual.hover_enabled = false
