extends Node

# --- Signals ---
signal round_started(round_index: int, starting_player_id: int)
signal request_play_card(player_id: int)
signal round_completed(round_index: int, plays: Dictionary, winner_id: int)
signal match_finished(winner_id: int)
signal send_message(text: String)

# --- Config ---
const MAX_ROUNDS := 10

const PLAYER_HUMAN := 0
const PLAYER_AI_1 := 1
const PLAYER_AI_2 := 2
const PLAYERS := [PLAYER_HUMAN, PLAYER_AI_1, PLAYER_AI_2]
const PLAYER_NAMES := ["YOU","AI player 1", "AI player 2"]

# --- State ---
var current_round := 0

var current_starting_player := PLAYER_HUMAN
var last_round_winner := PLAYER_HUMAN

var turn_order: Array[int] = []
var current_turn_index := 0


func set_table_root(node: Control) -> void:
	CardManager.set_table_root(node)


func start_match(starting_player_id: int = PLAYER_HUMAN) -> void:
	current_round = 0
	current_starting_player = starting_player_id
	
	await CardManager.generate_player_hands()
	
	start_new_round(current_starting_player)


func start_new_round(starting_player_id: int) -> void:
	current_round += 1

	CardManager.round_clean_up()

	current_starting_player = starting_player_id
	turn_order = _build_turn_order(starting_player_id)
	current_turn_index = 0

	print("Starting Player: " + PLAYER_NAMES[current_starting_player])

	emit_signal("round_started", current_round, starting_player_id)
	
	_request_current_player()


func _build_turn_order(starting_player_id: int) -> Array[int]:
	var order: Array[int] = []
	var start_index := PLAYERS.find(starting_player_id)

	for i in range(PLAYERS.size()):
		order.append(PLAYERS[(start_index + i) % PLAYERS.size()])

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
	last_round_winner = winner

	message(str(PLAYERS[winner]) + " won the Round")

	await get_tree().create_timer(3.0).timeout

	emit_signal("round_completed", current_round, winner)
	
	#Checks if match is over
	if current_round >= MAX_ROUNDS:
		message(str(PLAYERS[last_round_winner]) + " won the match!")
		emit_signal("match_finished", last_round_winner)
		return
	
	start_new_round(owner_to_id(winner))

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
	
