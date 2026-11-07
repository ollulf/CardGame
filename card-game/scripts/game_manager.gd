extends Node

# --- Signals ---
signal turn_started(turn_index: int, starting_player_id: int)
signal request_play_card(player_id: int)
signal turn_completed(turn_index: int, winner_id: int)
signal round_finished(winner_id: int)
signal round_started()
signal match_lost(looser_id: int)
signal next_round_available()
signal match_finished(looser_ids: Array[int])
signal new_match_started()
signal send_message(text: String)

# --- Config ---
const MAX_TURNS := 5
const MAX_LIVES := 2
const TRUMP_REVEAL_TIME := 1.2

const PLAYER_NAMES := ["YOU","AI player 1", "AI player 2"]

const MOVIE_WINDOW_POSITION := Vector2i(-10000, -10000)
const DECK_PILE_GROUP := "deck_piles"
const WON_ROUNDS_UI_GROUP := "won_rounds_ui"

# --- State ---
var current_turn := 0

var play_order: Array[int] = []
var current_play_index := 0

var human_player = Player
var ai_player_1 = Player
var ai_player_2 = Player

var last_round_loosers : Array[int]

var _intro_done := false
var _deal_pending := false
var _trump_pending := false
var round_over := false
var round_token := 0

func _init() -> void:
	if Engine.get_write_movie_path() != "":
		DisplayServer.window_set_position(MOVIE_WINDOW_POSITION)

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

func start_round(starting_player_id: int) -> void:
	current_turn = 0
	round_over = false
	CardManager.played_cards_round.empty()
	TutorialScript.begin_round()
	starting_player_id = TutorialScript.starter(starting_player_id)
	await CardManager.load_player_decks()
	var first_round := not _intro_done
	_intro_done = true
	_trump_pending = first_round and DialogueManager.has_cue(1, "match_start", "show_trump")
	if first_round and DialogueManager.has_cue(1, "match_start", "show_deck"):
		for pile in get_tree().get_nodes_in_group(DECK_PILE_GROUP):
			pile.hide_pile()
	if first_round and DialogueManager.has_cue(1, "match_start", "deal_cards"):
		_deal_pending = true
	else:
		await _deal_and_reveal()

	round_started.emit()

	await DialogueManager.wait_until_idle()
	if _deal_pending:
		await _deal_and_reveal()
	if _trump_pending:
		await _reveal_pending_trump()

	start_new_turn(starting_player_id)

func run_cue(cue: String) -> void:
	match cue:
		"show_deck":
			await _show_deck_piles()
		"deal_cards":
			if _deal_pending:
				await _deal_and_reveal()
		"show_trump":
			if _trump_pending:
				await _reveal_pending_trump()
		"show_purse":
			var wallet = get_tree().get_first_node_in_group("wallet")
			if wallet:
				await wallet.reveal()
		"show_cigs":
			var cigs_ui = get_tree().get_first_node_in_group("ai_cigarettes_ui")
			if cigs_ui:
				await cigs_ui.reveal()
		"ai_one_smokes":
			if ai_player_1:
				await ai_player_1.smoke()
		"ai_two_smokes":
			if ai_player_2:
				await ai_player_2.smoke()
		"show_won_turns", "show_life_cards":
			var ui = get_tree().get_first_node_in_group(WON_ROUNDS_UI_GROUP)
			if ui:
				await ui.run_cue(cue)

func _show_deck_piles() -> void:
	var hidden_piles: Array = get_tree().get_nodes_in_group(DECK_PILE_GROUP).filter(func(pile): return not pile.visible)
	for pile in hidden_piles:
		pile.show_pile()
	if not hidden_piles.is_empty():
		await get_tree().create_timer(DeckPile.SHOW_TIME, false).timeout

func _deal_and_reveal() -> void:
	_deal_pending = false
	await CardManager.generate_player_hands()
	if _trump_pending:
		return
	await reveal_trump()

func _reveal_pending_trump() -> void:
	_trump_pending = false
	await reveal_trump()

func restart_round():
	current_turn = 0
	round_over = false
	TutorialScript.begin_round()
	
	await CardManager.generate_player_hands()

	await reveal_trump()

	round_started.emit()

	await DialogueManager.wait_until_idle()

	start_new_turn(TutorialScript.starter(last_round_loosers.pick_random()))

func reveal_trump() -> void:
	CardManager.pick_trump_suit()
	await get_tree().create_timer(TRUMP_REVEAL_TIME, false).timeout

func start_new_match() -> void:
	var starting_player_id: int = get_total_loosers().pick_random()

	for id in range(3):
		id_to_player(id).lost_rounds = 0
	last_round_loosers.clear()

	CardManager.clear_all_cards()

	new_match_started.emit()

	start_round(starting_player_id)

func start_new_turn(starting_player_id: int) -> void:
	current_turn += 1

	CardManager.turn_clean_up()

	play_order = _build_play_order(starting_player_id)
	current_play_index = 0

	print("Starting Player: " + PLAYER_NAMES[starting_player_id])

	emit_signal("turn_started", current_turn, starting_player_id)
	
	_request_current_player()


func _build_play_order(starting_player_id: int) -> Array[int]:
	var order: Array[int] = []

	for i in range(3):
		order.append((starting_player_id + i) % 3)

	return order


func _request_current_player() -> void:
	var token := round_token
	await DialogueManager.wait_until_idle()
	if token != round_token:
		return

	if current_play_index >= play_order.size():
		_finish_turn()
		return

	var player_id := play_order[current_play_index]
	message(str(PLAYER_NAMES[player_id]) + "'s turn")
	emit_signal("request_play_card", player_id)

# Called by human & AI controllers
func play_callback(player_id: int) -> void:
	current_play_index += 1
	_request_current_player()


func _finish_turn() -> void:
	var token := round_token
	await get_tree().create_timer(2.0, false).timeout
	await DialogueManager.wait_until_idle()
	if token != round_token:
		return

	var winner : Card.Owner = CardManager.get_turn_winner()
	CardManager.highlight_turn_winner()

	message(str(PLAYER_NAMES[winner]) + " won the turn")

	await get_tree().create_timer(1.0, false).timeout
	if token != round_token:
		return
	await CardManager.clear_table()
	if token != round_token:
		return

	turn_completed.emit(current_turn, owner_to_id(winner))

	await get_tree().create_timer(3.0, false).timeout
	await DialogueManager.wait_until_idle()
	if token != round_token:
		return

	#Checks if round is over
	if current_turn >= MAX_TURNS:
		await _end_round(get_round_looser())
		return

	start_new_turn(owner_to_id(winner))

func _end_round(loosers: Array[int]) -> void:
	last_round_loosers = loosers

	notify_round_loosers(last_round_loosers)

	if(last_round_loosers.size() == 1):
		message(str(PLAYER_NAMES[last_round_loosers[0]]) + " lost the round!")
	else:
		message(str(PLAYER_NAMES[last_round_loosers[0]]) + " and " +
		str(PLAYER_NAMES[last_round_loosers[1]]) + " lost the round!")

	round_over = true
	round_finished.emit(last_round_loosers)

	#Check if somebody lost twice
	var total_loosers := get_total_loosers()
	for total_looser in total_loosers:
		match_lost.emit(total_looser)

	await DialogueManager.wait_until_idle()

	if total_loosers.is_empty():
		next_round_available.emit()
	else:
		match_finished.emit(total_loosers)

func can_skip_round() -> bool:
	return current_turn > 0 and not round_over

func skip_round(looser_id: int) -> void:
	if not can_skip_round():
		return
	round_token += 1
	current_turn = MAX_TURNS
	round_over = true
	if human_player is HumanPlayer:
		human_player.is_my_turn = false
	for id in range(3):
		id_to_player(id).set_active(false)
	DialogueManager.clear_waiting()
	await CardManager.clear_table()
	CardManager.clear_all_cards()
	var loosers: Array[int] = [looser_id]
	await _end_round(loosers)

func get_total_loosers() -> Array[int]:
	var result: Array[int] = []

	for id in last_round_loosers:
		if id_to_player(id).lost_rounds == MAX_LIVES:
			result.append(id)

	return result

func notify_round_loosers(ids : Array[int]):
	for id in ids:
		id_to_player(id).lost_rounds += 1

func get_round_looser() -> Array[int]:
	var result: Array[int] = []

	var min_wins = human_player.won_turns

	# Find the minimum first
	min_wins = min(
		human_player.won_turns,
		ai_player_1.won_turns,
		ai_player_2.won_turns
	)
	
	print(min_wins)
	
	# Collect all players that match the minimum
	if human_player.won_turns == min_wins:
		result.append(human_player.player_id)

	if ai_player_1.won_turns == min_wins:
		result.append(ai_player_1.player_id)

	if ai_player_2.won_turns == min_wins:
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
	
