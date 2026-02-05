extends Control
class_name PlayerHand

@export var player_id: int = 0

# Layout
@export var card_space: float = 400
@export var bottom_margin: float = 150

# CardUI scene (root must be Control, e.g. CardUI)
@export var card_ui_scene: PackedScene = preload("res://scenes/Card.tscn")

var hand: Array[Dictionary] = []
var card_nodes: Array[Card] = []
var is_my_turn: bool = false


func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)
	
	InteractionManager.player_hand = self

	_build_test_hand()
	_render_hand()


func submit_card(card: Card) -> void:
	if not is_my_turn:
		return

	var idx := _find_card_index(card.card_data)
	if idx == -1:
		return

	var chosen_card: Dictionary = hand[idx]
	var chosen_suit := str(chosen_card.get("suit", ""))

	var lead_suit := _get_lead_suit()

	# --- Follow suit rule ---
	if lead_suit != "":
		# Lead suit is TRUMP: you must play ANY trump if you have one
		if CardManager.suit_is_trump(lead_suit):
			if _has_any_trump_in_hand() and not CardManager.suit_is_trump(chosen_suit):
				print("Illegal move: must play a trump card.")
				return

		# Lead suit is NOT trump: you must follow that exact suit if you can
		else:
			if _has_suit_in_hand(lead_suit) and chosen_suit != lead_suit:
				print("Illegal move: must follow suit:", lead_suit)
				return

	# Move is legal
	GameManager.submit_play(player_id, chosen_card)

	hand.remove_at(idx)
	_render_hand()
	is_my_turn = false


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	is_my_turn = false


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)


func _build_test_hand() -> void:
	hand.clear()
	var suits := ["hearts", "diamonds", "clubs", "spades", "alk", "smoke"]

	for i in range(10):
		var card := {
			"suit": suits[randi() % suits.size()],
			"rank": randi_range(1, 13)
		}
		hand.append(card)

	# Sort by suit, then by rank (ascending)
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var suit_a := suits.find(str(a.get("suit", "")))
		var suit_b := suits.find(str(b.get("suit", "")))

		# First: suit order
		if suit_a != suit_b:
			return suit_a < suit_b

		# Second: rank order
		return int(a.get("rank", 0)) < int(b.get("rank", 0))
	)


func _render_hand() -> void:
	_anchor_to_bottom_of_view()

	for n in card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	card_nodes.clear()

	for i in range(hand.size()):
		var card_data := hand[i]
		var card_view := card_ui_scene.instantiate() as Card
		card_view._base_z = i
		card_view.z_index = i
		add_child(card_view)
		card_nodes.append(card_view)
		card_view.setup(card_data, true, player_id)

	_layout_cards()


func _anchor_to_bottom_of_view() -> void:
	# UI coordinates (this Control is the root)
	var vs := get_viewport().get_visible_rect().size
	position = Vector2(vs.x * 0.5, vs.y - bottom_margin)


func _layout_cards() -> void:
	var count := card_nodes.size()
	if count <= 0:
		return

	if count == 1:
		var n := card_nodes[0]
		if is_instance_valid(n):
			n.position = Vector2.ZERO
		return

	var half_width := card_space * 0.5
	var step := card_space / float(count - 1)

	for i in range(count):
		var n := card_nodes[i]
		if not is_instance_valid(n):
			continue

		var x := -half_width + i * step
		n.position = Vector2(x, 0.0)


func _get_lead_suit() -> String:
	var leader_id: int = GameManager.current_starting_player
	if CardManager.played_cards.has(leader_id):
		var lead_card = CardManager.played_cards[leader_id]
		if typeof(lead_card) == TYPE_DICTIONARY:
			return str(lead_card.get("suit", ""))
	return ""


func _has_suit_in_hand(suit: String) -> bool:
	for c in hand:
		if c.get("suit", "") == suit:
			return true
	return false

func _has_any_trump_in_hand() -> bool:
	for c in hand:
		if CardManager.suit_is_trump(str(c.get("suit", ""))):
			return true
	return false

func _find_card_index(data: Dictionary) -> int:
	for i in range(hand.size()):
		if hand[i].get("suit") == data.get("suit") and hand[i].get("rank") == data.get("rank"):
			return i
	return -1
