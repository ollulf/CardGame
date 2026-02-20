extends Node

# --- Signals ---
signal round_started(round_index: int, starting_player_id: int)
signal request_play_card(player_id: int)
signal round_completed(round_index: int, winner_id: int)
signal match_finished(winner_id: int)
signal match_started()
signal game_lost(looser_id: int)
signal send_message(text: String)

# --- Config ---
const MAX_ROUNDS := 5

const PLAYER_NAMES := ["YOU","AI player 1", "AI player 2"]

# --- State ---
var current_round := 0

var turn_order: Array[int] = []
var current_turn_index := 0

var human_player = Player
var ai_player_1 = Player
var ai_player_2 = Player

var last_match_loosers : Array[int]

func register(player : Player):
	match player.player_id:
		0:
			human_player = player
		1:
			ai_player_1 = player
		2:
			ai_player_2 = player
		_:
			printerr("Wrong Player ID in register()")

func set_table_root(node: Control) -> void:
	CardManager.set_table_root(node)

func start_match(starting_player_id: int) -> void:
	current_round = 0
	CardManager.played_cards_match.empty()
	await CardManager.load_player_decks()
	await CardManager.generate_player_hands()
	
	match_started.emit()
	
	start_new_round(starting_player_id)

func restart_match():
	current_round = 0
	
	await CardManager.generate_player_hands()
	
	match_started.emit()
	
	start_new_round(last_match_loosers.pick_random())

func start_new_round(starting_player_id: int) -> void:
	current_round += 1

	CardManager.round_clean_up()

	turn_order = _build_turn_order(starting_player_id)
	current_turn_index = 0

	print("Starting Player: " + PLAYER_NAMES[starting_player_id])

	emit_signal("round_started", current_round, starting_player_id)
	
	_request_current_player()


func _build_turn_order(starting_player_id: int) -> Array[int]:
	var order: Array[int] = []

	for i in range(3):
		order.append((starting_player_id + i) % 3)

	return order


func _request_current_player() -> void:
	if current_turn_index >= turn_order.size():
		_finish_round()
		return

	var player_id := turn_order[current_turn_index]
	message(str(PLAYER_NAMES[player_id]) + "'s turn")
	emit_signal("request_play_card", player_id)

# Called by human & AI controllers
func play_callback(player_id: int) -> void:
	current_turn_index += 1
	_request_current_player()


func _finish_round() -> void:
	await get_tree().create_timer(2.0).timeout

	var winner : Card.Owner = CardManager.get_round_winner()
	
	message(str(PLAYER_NAMES[winner]) + " won the Round")
	
	round_completed.emit(current_round, owner_to_id(winner))

	await get_tree().create_timer(3.0).timeout

	#Checks if match is over
	if current_round >= MAX_ROUNDS:
		last_match_loosers = get_match_looser()
		
		notify_match_loosers(last_match_loosers)
		
		if(last_match_loosers.size() == 1):
			message(str(PLAYER_NAMES[last_match_loosers[0]]) + " lost the match!")
		else:
			message(str(PLAYER_NAMES[last_match_loosers[0]]) + " and " + 
			str(PLAYER_NAMES[last_match_loosers[1]]) + " lost the match!")
		
		match_finished.emit(last_match_loosers)
		
		#Check if somebody lost twice
		var total_looser = try_get_total_looser()
		
		if(total_looser != null):
			game_lost.emit(total_looser)
		
		return
	
	start_new_round(owner_to_id(winner))

func try_get_total_looser() -> int:
	return 0

func notify_match_loosers(ids : Array[int]):
	for id in ids:
		id_to_player(id).lost_matches += 1

func get_match_looser() -> Array[int]:
	var result: Array[int] = []

	var min_wins = human_player.won_rounds

	# Find the minimum first
	min_wins = min(
		human_player.won_rounds,
		ai_player_1.won_rounds,
		ai_player_2.won_rounds
	)
	
	print(min_wins)
	
	# Collect all players that match the minimum
	if human_player.won_rounds == min_wins:
		result.append(human_player.player_id)

	if ai_player_1.won_rounds == min_wins:
		result.append(ai_player_1.player_id)

	if ai_player_2.won_rounds == min_wins:
		result.append(ai_player_2.player_id)

	print(result)
	return result

func id_to_player(id : int) -> Player:
	match id:
		0:
			return human_player
		1:
			return ai_player_1
		2:
			return ai_player_2
		_:
			return null

func owner_to_id(owner: Card.Owner) -> int:
	match owner:
		Card.Owner.HUMAN:
			return 0
		Card.Owner.AI_1:
			return 1
		Card.Owner.AI_2:
			return 2
		_:
			return 0

func message(text: String) -> void:
	send_message.emit(text)
	
