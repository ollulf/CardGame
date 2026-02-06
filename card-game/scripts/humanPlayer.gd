extends Player
class_name HumanPlayer

# Layout
@export var card_space: float = 400
@export var MAX_GAP := 40.0

@export var bottom_margin: float = 150

var card_visuals : Array[CardVisual] = []

var is_my_turn: bool = false

func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)
	
	InteractionManager.human_Player = self

func recieve_hand(hand: Hand):
	get_ownership_of_hand_cards(hand)
	render_hand()
	
	hand.hand_shrinked.connect(on_hand_shrinked)
	hand.hand_grew.connect(on_hand_grew)

func on_hand_shrinked():
	layout_hand_cards()

func on_hand_grew():
	render_hand()

func try_play_card(card: Card) -> void:
	if not is_my_turn:
		return

	if not hand.contains(card):
		return

	var leading_suit = CardManager.leading_card.suit
	
	# --- Follow the obay suit rule ---
	if hand.contains_card_of_suit(leading_suit) and card.suit != leading_suit:
		print("Must obay leading suit of: " + leading_suit)
		return


	hand.remove(card)
	CardManager.submit_play(player_id, card)
	
	is_my_turn = false


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	is_my_turn = false


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)


func render_hand():
	_anchor_to_bottom_of_view()

	for card in hand:
		if is_instance_valid(card):
			card.queue_free()

	for card in hand:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
		
		c.setup(card, false)
		
		add_child(c)
		card_visuals.append(c)

	layout_hand_cards()


func _anchor_to_bottom_of_view() -> void:
	# UI coordinates (this Control is the root)
	var vs := get_viewport().get_visible_rect().size
	position = Vector2(vs.x * 0.5, vs.y - bottom_margin)


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
