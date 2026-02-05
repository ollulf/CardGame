extends Node
class_name GameManagerClass

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

var current_round_plays: Dictionary = {}
var turn_order: Array[int] = []
var current_turn_index := 0


func set_table_root(node: Control) -> void:
	CardManager.set_table_root(node)


func start_match(starting_player_id: int = PLAYER_HUMAN) -> void:
	current_round = 0
	current_round_plays.clear()
	
	current_starting_player = starting_player_id
	
	await CardManager.generate_player_hands()
	
	_start_new_round(current_starting_player)


func _start_new_round(starting_player_id: int) -> void:
	current_round += 1
	current_round_plays.clear()

	CardManager.clear_table_visuals()
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
func submit_play(player_id: int, card_data: Variant) -> void:
	current_round_plays[player_id] = card_data

	# Card bookkeeping + visuals now live in CardManager
	CardManager.register_play(player_id, card_data)

	current_turn_index += 1
	_request_current_player()


func _finish_round() -> void:
	await get_tree().create_timer(2.0).timeout

	var winner_id := calculate_round_winner(current_round_plays)
	last_round_winner = winner_id

	message(str(PLAYERS[winner_id]) + " won the Round")

	await get_tree().create_timer(3.0).timeout

	emit_signal("round_completed", current_round, current_round_plays, winner_id)
	
	#Checks if match is over
	if current_round >= MAX_ROUNDS:
		message(str(PLAYERS[last_round_winner]) + " won the match!")
		emit_signal("match_finished", last_round_winner)
		return
	
	_start_new_round(winner_id)


func calculate_round_winner(current_plays: Dictionary) -> int:
	# Safety
	if not current_plays.has(current_starting_player):
		push_warning("Starting player has no card – fallback winner used.")
		CardManager.round_clean_up()
		return current_starting_player
	
	var lead_card: Dictionary = current_plays[current_starting_player]
	var lead_suit: String = str(lead_card.get("suit", ""))
	
	# --- TRUMP RULE ---
	# If any trump was played, highest rank of the FIRST played trump suit wins.
	if CardManager.first_played_trump_suit != "":
		var trump_suit = CardManager.first_played_trump_suit
		var winning_player := -1
		var highest_rank := -1
	
		for player_id in current_plays.keys():
			var card = current_plays[player_id]
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("suit", "")) != trump_suit:
				continue
	
			var r: int = int(card.get("rank", -1))
			if r > highest_rank:
				highest_rank = r
				winning_player = player_id
	
		if winning_player != -1:
			CardManager.round_clean_up()
			return winning_player
	
	# --- NORMAL RULE (lead suit wins) ---
	var winning_player: int = current_starting_player
	var highest_rank: int = int(lead_card.get("rank", -1))
	
	for player_id in current_plays.keys():
		var card = current_plays[player_id]
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if str(card.get("suit", "")) != lead_suit:
			continue
	
		var r: int = int(card.get("rank", -1))
		if r > highest_rank:
			highest_rank = r
			winning_player = player_id
	
	return winning_player

func message(text: String) -> void:
	emit_signal("send_message", text)
