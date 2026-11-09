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
signal run_won()
signal new_match_started()
signal player_kicked()
signal send_message(text: String)

# --- Config ---
const MAX_TURNS := 5
const MAX_LIVES := 2
const TRUMP_REVEAL_TIME := 3.2
const TURN_WINNER_SHOW_TIME := 1.5
const TURN_FINISH_DELAY := 1.0
const MAX_TIE_DRAWS := 5

const HUMAN_ID := 0
const PLAYER_NAMES := ["YOU","AI player 1", "AI player 2"]
const ROUND_ORDER_LINES := {
	0: "A *round of drinks* from *YOU*? Cheers, everybody drinks!",
	1: "Bartender, a *round* for the whole table! Everybody drinks!",
	2: "This *round* is on me! Bottoms up, all of you!",
}
const ROUND_SERVE_STAGGER := 0.25
const ROUND_SERVE_TIME := 1.6

const MOVIE_WINDOW_POSITION := Vector2i(-10000, -10000)
const DECK_PILE_GROUP := "deck_piles"
const WON_PILE_GROUP := "won_piles"
const WON_ROUNDS_UI_GROUP := "won_rounds_ui"
const PRIZE_POT_GROUP := "prize_pot"

# --- State ---
var current_turn := 0

var play_order: Array[int] = []
var current_play_index := 0

var human_player = Player
var ai_player_1 = Player
var ai_player_2 = Player

var last_round_loosers : Array[int]
var last_match_loosers : Array[int] = []

var _intro_done := false
var _deal_pending := false
var _trump_pending := false
var round_over := false
var round_token := 0
var _match_start_state := {}
var _game_start_state := {}

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
	var tutorial_before := TutorialScript.capture_state()
	TutorialScript.begin_round()
	starting_player_id = TutorialScript.starter(starting_player_id)
	await CardManager.load_player_decks()
	var first_round := not _intro_done
	_intro_done = true
	if _game_start_state.is_empty():
		_game_start_state = _capture_state()
		_game_start_state["tutorial"] = tutorial_before
		_match_start_state = _game_start_state
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
		"show_drinks":
			var cigs_ui = get_tree().get_first_node_in_group("ai_cigarettes_ui")
			if cigs_ui:
				cigs_ui.reveal_drinks()
		"unlock_cig_automat":
			PlayerDataManager.unlock_cig_machine()
		"ai_1_buys_cigarettes":
			Missions.add_cigarettes(1, PlayerDataManager.CIGARETTES_PER_PACK)
		"show_won_turns", "show_life_cards":
			var ui = get_tree().get_first_node_in_group(WON_ROUNDS_UI_GROUP)
			if ui:
				await ui.run_cue(cue)
		_:
			var words := cue.split(" ", false)
			if words.size() == 2 and words[0] == DialogueManager.GIVE_CIGS_CUE:
				var pack: CigPack = InteractionManager.cigPack
				if pack != null:
					pack.add_cigarettes(words[1].to_int())
			elif not words.is_empty() and DialogueManager.PAY_CUES.has(words[0]):
				var amount := words[1].to_int() if words.size() > 1 else Missions.prize_money(DialogueManager.upcoming_match())
				await _pay_prize(DialogueManager.PAY_CUES[words[0]], amount)

func serve_round_of_drinks(buyer: int) -> void:
	var speaker := buyer if buyer != HUMAN_ID else 1
	DialogueManager.say(speaker, ROUND_ORDER_LINES[buyer])
	var glass = get_tree().get_first_node_in_group(DrinkGlass.GROUP)
	var servings: Array = []
	for seat in PlayerDataManager.PLAYERS:
		if seat == HUMAN_ID:
			if glass:
				glass.drink_round()
			else:
				PlayerDataManager.drink(seat)
		else:
			var ai: AIPlayer = ai_player_1 if seat == 1 else ai_player_2
			if ai is AIPlayer:
				servings.append(ai)
			else:
				PlayerDataManager.drink(seat)
	for ai in servings:
		await get_tree().create_timer(ROUND_SERVE_STAGGER, false).timeout
		ai.drink()
	await get_tree().create_timer(ROUND_SERVE_TIME, false).timeout

func _pay_prize(seat: int, amount: int) -> void:
	var pot = get_tree().get_first_node_in_group(PRIZE_POT_GROUP)
	if pot:
		await pot.pay(seat, amount)

func _auto_pay_prize() -> void:
	var match_number := DialogueManager.upcoming_match()
	if match_number <= 1 or last_match_loosers.is_empty() or DialogueManager.match_pays_prize(match_number):
		return
	var amount := Missions.prize_money(match_number)
	if amount <= 0:
		return
	var share := amount / last_match_loosers.size()
	for id in last_match_loosers:
		await _pay_prize(id, share)

func _pay_out_prize(loosers: Array[int]) -> void:
	var pot = get_tree().get_first_node_in_group(PRIZE_POT_GROUP)
	if pot == null:
		return
	var winners: Array[int] = []
	for id in range(3):
		if not id in loosers:
			winners.append(id)
	await pot.pay_out(winners)

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
	var total_loosers := get_total_loosers()
	var starting_player_id: int = total_loosers.pick_random() if not total_loosers.is_empty() else randi() % 3
	_match_start_state = _capture_state()

	for id in range(3):
		id_to_player(id).lost_rounds = 0
	last_round_loosers.clear()

	CardManager.clear_all_cards()

	new_match_started.emit()
	starting_over = false

	await _auto_pay_prize()

	start_round(starting_player_id)

func _message_name(player_id: int) -> String:
	return "You" if player_id == HUMAN_ID else str(PLAYER_NAMES[player_id])


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
	message("Your turn" if player_id == HUMAN_ID else str(PLAYER_NAMES[player_id]) + "'s turn")
	emit_signal("request_play_card", player_id)

# Called by human & AI controllers
func play_callback(player_id: int) -> void:
	current_play_index += 1
	_request_current_player()


func _finish_turn() -> void:
	var token := round_token
	await get_tree().create_timer(TURN_FINISH_DELAY, false).timeout
	await DialogueManager.wait_until_idle()
	if token != round_token:
		return

	var winner : Card.Owner = CardManager.get_turn_winner()
	CardManager.highlight_turn_winner()

	message(_message_name(winner) + " won the turn")

	await get_tree().create_timer(TURN_WINNER_SHOW_TIME, false).timeout
	if token != round_token:
		return
	await CardManager.collect_table(winner)
	if token != round_token:
		return

	turn_completed.emit(current_turn, owner_to_id(winner))

	await DialogueManager.wait_until_idle()
	if token != round_token:
		return

	#Checks if round is over
	if current_turn >= MAX_TURNS:
		var loosers := await resolve_tie(get_round_looser())
		if token != round_token:
			return
		await _end_round(loosers)
		return

	start_new_turn(owner_to_id(winner))

func _end_round(loosers: Array[int]) -> void:
	last_round_loosers = loosers

	notify_round_loosers(last_round_loosers)

	if(last_round_loosers.size() == 1):
		message(_message_name(last_round_loosers[0]) + " lost the round!")
	else:
		message(_message_name(last_round_loosers[0]) + " and " +
		_message_name(last_round_loosers[1]) + " lost the round!")

	round_over = true
	round_finished.emit(last_round_loosers)

	#Check if somebody lost twice
	var total_loosers := get_total_loosers()
	for total_looser in total_loosers:
		match_lost.emit(total_looser)

	await DialogueManager.wait_until_idle()

	if total_loosers.is_empty():
		next_round_available.emit()
	elif total_loosers.has(HUMAN_ID):
		player_kicked.emit()
	else:
		last_match_loosers = total_loosers.duplicate()
		await _pay_out_prize(total_loosers)
		if Missions.is_last_match(current_match()):
			run_won.emit()
		else:
			match_finished.emit(total_loosers)

func retry_match() -> void:
	_restore_state(_match_start_state)
	start_new_match()

var starting_over := false

func start_over() -> void:
	_intro_done = false
	PlayerDataManager.reset_buttons_unlock()
	_restore_state(_game_start_state)
	starting_over = true
	start_new_match()

func resume_run(match_state: Dictionary, game_state: Dictionary, between_matches: bool) -> void:
	_intro_done = true
	_game_start_state = game_state
	_restore_state(match_state)
	_match_start_state = match_state
	if between_matches:
		new_match_started.emit()
		match_finished.emit(last_match_loosers.duplicate())
	else:
		start_new_match()

func current_match() -> int:
	return _match_start_state.get("match", 1)

func _capture_state() -> Dictionary:
	var state := PlayerDataManager.capture_state()
	state["match"] = DialogueManager.upcoming_match()
	state["tutorial"] = TutorialScript.capture_state()
	state["cigarettes"] = InteractionManager.held_cigarette_count()
	state["last_match_loosers"] = last_match_loosers.duplicate()
	return state

func _restore_state(state: Dictionary) -> void:
	round_token += 1
	DialogueManager.clear_waiting()
	DialogueManager.rewind_to_match(state.get("match", 1))
	TutorialScript.restore_state(state.get("tutorial", {}))
	PlayerDataManager.restore_state(state)
	InteractionManager.reset_cigarettes(state.get("cigarettes", 0))
	last_match_loosers.assign(state.get("last_match_loosers", []))
	var pot = get_tree().get_first_node_in_group(PRIZE_POT_GROUP)
	if pot:
		pot.clear()

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

func can_skip_tutorial() -> bool:
	return can_skip_round() and DialogueManager.upcoming_match() == 1

func skip_tutorial(cues: Array) -> void:
	if not can_skip_tutorial():
		return
	DialogueManager.skip_all(true)
	for cue in cues:
		run_cue(cue)
	ai_player_1.lost_rounds = MAX_LIVES - 1
	var life_ui = get_tree().get_first_node_in_group(WON_ROUNDS_UI_GROUP)
	if life_ui:
		life_ui.sync_lost_lifes(1)
	DialogueManager.skip_all(false)
	await skip_round(1)

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

func resolve_tie(loosers: Array[int]) -> Array[int]:
	var token := round_token
	var attempts := 0
	while loosers.size() > 1 and attempts < MAX_TIE_DRAWS:
		attempts += 1
		var draws := {}
		var any_card := false
		for id in loosers:
			draws[id] = CardManager.draw_tie_card(id)
			any_card = any_card or draws[id] != null
		if not any_card:
			return loosers
		message("Tie! Drawing...")
		var lowest := 99
		for id in loosers:
			lowest = mini(lowest, tie_rank(draws[id]))
		var next: Array[int] = []
		for id in loosers:
			if tie_rank(draws[id]) == lowest:
				next.append(id)
		await CardManager.show_tie_break(draws, next)
		if token != round_token:
			return next
		loosers = next
	return loosers

func tie_rank(card: Card) -> int:
	return 0 if card == null else card.base_rank

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
	
