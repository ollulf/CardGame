extends Player
class_name AIPlayer

# Visual settings
@export var show_hand: bool = false

# Layout
@export var card_space: float = 320
@export var MAX_GAP := 70.0

var card_visuals : Array[CardVisual] = []

func _ready() -> void:
	super._ready()
	
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)
	
	GameManager.register(self)


func recieve_hand(new_hand: Hand) -> void:
	hand = new_hand
	render_hand()

	hand.hand_shrinked.connect(on_hand_shrinked)


func on_hand_shrinked() -> void:
	layout_hand_cards()


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	pass


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	# Play Delay
	await get_tree().create_timer(3.0, false).timeout

	if hand.is_empty():
		print("AI Players hand is empty")
		CardManager.submit_play(player_id, null)
		return

	var chosen_card = choose_card()

	var from := get_card_transform(chosen_card)
	hand.remove(chosen_card)
	CardManager.submit_play(player_id, chosen_card, from)


func choose_card() -> Card:
	# If no lead yet, dump a random card
	if CardManager.leading_card == null:
		return hand.cards[randi() % hand.size()]

	# Highest rank already played in lead suit
	var lead_card := CardManager.leading_card

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

	var gap = MAX_GAP

	if n > 1:
		gap = min(card_space / float(n - 1), MAX_GAP)

	var total_span = gap * float(n - 1)
	var start_y = -total_span * 0.5

	for i in range(n):
		var cv = card_visuals[i]
		cv.position = Vector2(0.0, start_y + gap * float(i)) - cv.size * 0.5
		cv.z_index = i
		cv.update_layout()
