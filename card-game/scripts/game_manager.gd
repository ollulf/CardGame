extends Node
class_name GameManagerClass

# --- Signals ---
signal round_started(round_index: int, starting_player_id: int)
signal request_play_card(player_id: int)
signal round_completed(round_index: int, plays: Dictionary, winner_id: int)
signal match_finished(winner_id: int)


# --- Config ---
const MAX_ROUNDS := 10

const PLAYER_HUMAN := 0
const PLAYER_AI_1 := 1
const PLAYER_AI_2 := 2
const PLAYERS := [PLAYER_HUMAN, PLAYER_AI_1, PLAYER_AI_2]

# --- Cards ---
var card_scene = preload("res://Card.tscn")

# Suit textures: assign in Inspector (or preload in code if you prefer)
@export var hearts_tex: Texture2D
@export var diamonds_tex: Texture2D
@export var clubs_tex: Texture2D
@export var spades_tex: Texture2D
@export var alk_tex: Texture2D
@export var smoke_tex: Texture2D

var suit_textures: Dictionary = {}

# --- State ---
var rounds_played := 0
var current_round := 0
var match_over := false

var current_starting_player := PLAYER_HUMAN
var last_round_winner := PLAYER_HUMAN

var current_round_plays: Dictionary = {}

var turn_order: Array[int] = []
var current_turn_index := 0

func _ready() -> void:
	suit_textures = {
	"hearts": hearts_tex,
	"diamonds": diamonds_tex,
	"clubs": clubs_tex,
	"spades": spades_tex,
	"alk": alk_tex,
	"smoke": smoke_tex 
	}
	
	await get_tree().process_frame
	start_match(0)

func start_match(starting_player_id: int = PLAYER_HUMAN) -> void:
	match_over = false
	rounds_played = 0
	current_round = 0
	current_round_plays.clear()

	current_starting_player = starting_player_id
	last_round_winner = starting_player_id

	_start_new_round(current_starting_player)


func _start_new_round(starting_player_id: int) -> void:
	
	await get_tree().create_timer(3.0).timeout
	
	if match_over:
		return

	if rounds_played >= MAX_ROUNDS:
		match_over = true
		emit_signal("match_finished", last_round_winner)
		return

	current_round += 1
	rounds_played += 1
	current_round_plays.clear()

	current_starting_player = starting_player_id
	turn_order = _build_turn_order(starting_player_id)
	current_turn_index = 0

	print("Starting Player: " + str(current_starting_player))
	
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
	print("Waiting for play of player: " + str(player_id))
	emit_signal("request_play_card", player_id)


# Called by human & AI controllers
func submit_play(player_id: int, card_data: Variant) -> void:
	if match_over:
		return

	# Only allow the correct player to play
	if player_id != turn_order[current_turn_index]:
		return

	current_round_plays[player_id] = card_data
	current_turn_index += 1

	_request_current_player()


func _finish_round() -> void:
	var winner_id := calculate_round_winner(current_round_plays)

	# Safety fallback
	if winner_id not in PLAYERS:
		winner_id = current_starting_player

	last_round_winner = winner_id
	
	emit_signal("round_completed", current_round, current_round_plays, winner_id)
	print("Started new Round")
	_start_new_round(winner_id)


func calculate_round_winner(current_plays: Dictionary) -> int:
	print("Player 0 won")
	return 0
