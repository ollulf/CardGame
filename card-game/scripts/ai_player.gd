extends Player
class_name AIPlayer

# Visual settings
@export var show_hand: bool = false

# Layout
@export var card_space: float = 400
@export var MAX_GAP := 40.0

var card_visuals : Array[CardVisual] = []

func _ready() -> void:
	super._ready()
	
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)
	
	GameManager.register(self)


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	pass


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	# Play Delay
	await get_tree().create_timer(3.0).timeout

	if hand.is_empty():
		print("AI Players hand is empty")
		CardManager.submit_play(player_id, null)

	var chosen_card = choose_card()

	CardManager.submit_play(player_id, chosen_card)


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


func render_hand():

	for card in hand:
		if is_instance_valid(card):
			card.queue_free()

	for card in hand:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
		
		c.setup(card, show_hand)
		
		add_child(c)
		card_visuals.append(c)

	layout_hand_cards()


func layout_hand_cards() -> void:
	if card_visuals.is_empty():
		return

	var n = card_visuals.size()

	if n == 1:
		card_visuals[0].position = Vector2.ZERO
		return

	var ideal_gap := card_space / float(n - 1)
	var gap = min(ideal_gap, MAX_GAP)
	var total_span = gap * float(n - 1)
	var start_x = -total_span * 0.5

	for i in range(n):
		var cv = card_visuals[i]
		cv.position = Vector2(start_x + gap * float(i), 0.0)
		cv.z_index = i
