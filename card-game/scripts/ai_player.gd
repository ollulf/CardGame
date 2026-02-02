extends Node2D
class_name AIPlayer

@export var player_id: int = 1

# Visual settings
@export var reveal_hand: bool = false
@export var card_spacing: float = 40.0

var hand: Array[Dictionary] = []

# Spawned visuals for the hand
var hand_card_nodes: Array[Card] = []


func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)

	_build_test_hand()
	_render_hand()


func _on_round_started(round_index: int, starting_player_id: int) -> void:
	if hand.is_empty():
		_build_test_hand()
	_render_hand()


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

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
	if lead_suit == "":
		return randi() % hand.size()

	# Find the highest card of the lead suit (if we have any)
	var best_index := -1
	var best_rank := -1

	for i in range(hand.size()):
		var c := hand[i]
		if c.get("suit", "") != lead_suit:
			continue

		var r: int = int(c.get("rank", -1))
		if r > best_rank:
			best_rank = r
			best_index = i

	# If we can follow suit, play the highest of that suit
	if best_index != -1:
		return best_index

	# Otherwise play random
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

	if GameManager.card_scene == null:
		push_warning("AIPlayer: GameManager.card_scene is null.")
		return

	var count := hand.size()
	var start_y := -(float(count - 1) * card_spacing) * 0.5

	for i in range(count):
		var card_data := hand[i]

		var card_view := GameManager.card_scene.instantiate() as Card
		add_child(card_view)
		hand_card_nodes.append(card_view)

		# Reveal or hide
		if card_view.has_method("setup"):
			card_view.call("setup", card_data, reveal_hand)


		# Position relative to this AI node (its transform is the center)
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
