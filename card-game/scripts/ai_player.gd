extends Control
class_name AIPlayer

@export var player_id: int = 1

# Visual settings
@export var reveal_hand: bool = false
@export var card_spacing: float = 40.0

# CardUI scene (root must be Control: CardUI)
@export var card_ui_scene: PackedScene = preload("res://scenes/Card.tscn")

var hand: Array[Dictionary] = []

# Spawned visuals for the hand
var hand_card_nodes: Array[Card] = []


func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)

	# UI nodes shouldn't eat input unless you want them to
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_test_hand()
	_render_hand()


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	if hand.is_empty():
		_build_test_hand()
	_render_hand()


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	# Play Delay
	await get_tree().create_timer(3.0).timeout

	if hand.is_empty():
		print("Player " + str(player_id) + " played nothing")
		GameManager.submit_play(player_id, null)
		return

	var chosen_index: int = _choose_card_index()
	var chosen_card: Dictionary = hand[chosen_index]
	hand.remove_at(chosen_index)

	_render_hand()
	GameManager.submit_play(player_id, chosen_card)


func _choose_card_index() -> int:
	var lead_suit := _get_lead_suit()

	# If no lead yet, dump a random card
	if lead_suit == "":
		return randi() % hand.size()

	# Highest rank already played in lead suit
	var highest_played := GameManager.get_highest_lead_suit_rank()

	# Find our lowest + highest card in the lead suit
	var highest_index := -1
	var highest_rank := -1
	var lowest_index := -1
	var lowest_rank := 999999

	for i in range(hand.size()):
		var c := hand[i]
		if c.get("suit", "") != lead_suit:
			continue

		var r: int = int(c.get("rank", -1))
		if r > highest_rank:
			highest_rank = r
			highest_index = i
		if r < lowest_rank:
			lowest_rank = r
			lowest_index = i

	# If we can follow suit:
	if highest_index != -1:
		# If our highest beats what's already played, use it. Otherwise dump the lowest of that suit.
		if highest_rank > highest_played:
			return highest_index
		return lowest_index

	# Can't follow suit: play random
	return randi() % hand.size()


func _get_lead_suit() -> String:
	var leader_id: int = GameManager.current_starting_player

	if GameManager.played_cards.has(leader_id):
		var lead_card = GameManager.played_cards[leader_id]
		if lead_card is Dictionary:
			return str(lead_card.get("suit", ""))

	return ""


func _render_hand() -> void:
	_clear_hand_visuals()

	var count := hand.size()
	if count <= 0:
		return

	var start_y := -(float(count - 1) * card_spacing) * 0.5

	for i in range(count):
		var card_data := hand[i]

		var card_view := card_ui_scene.instantiate() as Card
		add_child(card_view)
		hand_card_nodes.append(card_view)

		# Reveal or hide
		card_view.setup(card_data, reveal_hand)

		# Layering
		card_view.z_index = i

		# UI positioning (local to this Control)
		card_view.position = Vector2(0.0, start_y + i * card_spacing)


func _clear_hand_visuals() -> void:
	for n in hand_card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	hand_card_nodes.clear()


func _exit_tree() -> void:
	_clear_hand_visuals()


func _build_test_hand() -> void:
	hand.clear()
	var suits := ["hearts", "diamonds", "clubs", "spades", "alk", "smoke"]

	for i in range(7):
		var card: Dictionary = {
			"suit": suits[randi() % suits.size()],
			"rank": randi_range(1, 13)
		}
		hand.append(card)
