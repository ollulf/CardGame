extends Player
class_name AIPlayer

# Visual settings
@export var reveal_hand: bool = false
@export var card_spacing: float = 40.0


func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	pass


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	# Play Delay
	await get_tree().create_timer(3.0).timeout


	var chosen_card = choose_card()

	CardManager.submit_play(player_id, chosen_card)


func choose_card() -> int:
	return randi() % hand.size()
	
	# If no lead yet, dump a random card
	if CardManager.leading_card == null:
		return randi() % hand.size()

	# Highest rank already played in lead suit
	var highest_played := CardManager.get_highest_lead_suit_rank(player_id)

	# Find our lowest + highest card in the lead suit
	var highest_index := -1
	var highest_rank := -1
	var lowest_index := -1
	var lowest_rank := 999999

	for i in range(hand.size()):
		var c := hand[i]
		var suit := str(c.get("suit", ""))

		# Follow suit.
		# If the lead suit is trump, any trump suit is allowed to follow.
		if suit != lead_suit:
			if not (CardManager.suit_is_trump(lead_suit) and CardManager.suit_is_trump(suit)):
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
		# If lead is NOT trump: play highest if it beats table, else lowest of lead suit.
		if not CardManager.suit_is_trump(lead_suit):
			if highest_rank > highest_played:
				return highest_index
			return lowest_index

		# Lead IS trump: only the FIRST played trump suit can win.
		var first_trump := CardManager.first_played_trump_suit
		if first_trump == "":
			return lowest_index

		if str(hand[highest_index].get("suit", "")) == first_trump:
			if highest_rank > highest_played:
				return highest_index
			return lowest_index
		else:
			return lowest_index

# --- WE DON'T HAVE TO FOLLOW THE LEADING SUIT ---

	var first_trump_suit: String = CardManager.first_played_trump_suit

	if first_trump_suit == "":
		# If we can't follow suit and we have any trump: play a random trump card.
		var trump_indices: Array[int] = []
		for i in range(hand.size()):
			var suit := str(hand[i].get("suit", ""))
			if CardManager.suit_is_trump(suit):
				trump_indices.append(i)

		if trump_indices.size() > 0:
			return trump_indices[randi() % trump_indices.size()]
	# If trump has been played: we MAY play a trump ONLY if it can beat the current first-trump-suit high.
	# Otherwise: DO NOT play trump → play a random NON-trump card.
	if first_trump_suit != "":
		var highest_trump_played := -1
		for pid in CardManager.played_cards.keys():
			var pc = CardManager.played_cards[pid]
			if typeof(pc) != TYPE_DICTIONARY:
				continue
			if str(pc.get("suit", "")) != first_trump_suit:
				continue
			highest_trump_played = maxi(highest_trump_played, int(pc.get("rank", -1)))

		# Find our best (highest) card of the FIRST played trump suit (only these can win)
		var best_first_trump_idx := -1
		var best_first_trump_rank := -1

		for i in range(hand.size()):
			var c := hand[i]
			if str(c.get("suit", "")) != first_trump_suit:
				continue
			var r: int = int(c.get("rank", -1))
			if r > best_first_trump_rank:
				best_first_trump_rank = r
				best_first_trump_idx = i

		# We can win with first-trump-suit → play it
		if best_first_trump_idx != -1 and best_first_trump_rank > highest_trump_played:
			return best_first_trump_idx

		# We can't beat trump → play RANDOM NON-TRUMP (if we have any)
		var non_trump_indices: Array[int] = []
		for i in range(hand.size()):
			var suit := str(hand[i].get("suit", ""))
			if not CardManager.suit_is_trump(suit):
				non_trump_indices.append(i)

		if non_trump_indices.size() > 0:
			return non_trump_indices[randi() % non_trump_indices.size()]

		# If we literally only have trump cards left, we have no choice.
		return randi() % hand.size()

	# No trump has been played: play random
	return randi() % hand.size()


func _get_lead_suit() -> String:
	var leader_id: int = GameManager.current_starting_player

	if CardManager.played_cards.has(leader_id):
		var lead_card = CardManager.played_cards[leader_id]
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

		var card_view := card.instantiate() as Card
		add_child(card_view)
		hand_card_nodes.append(card_view)

		# Reveal or hide
		card_view.setup(card_data, reveal_hand, player_id)

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

	for i in range(10):
		var card: Dictionary = {
			"suit": suits[randi() % suits.size()],
			"rank": randi_range(1, 13)
		}
		hand.append(card)
