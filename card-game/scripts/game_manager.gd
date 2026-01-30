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
var card_scene: PackedScene = preload("res://Card.tscn")

@onready var hearts_tex: Texture2D = preload("res://sprites/suit_Herz.png")
@onready var diamonds_tex: Texture2D = preload("res://sprites/suit_Karo.png")
@onready var clubs_tex: Texture2D = preload("res://sprites/suit_Kreuz.png")
@onready var spades_tex: Texture2D = preload("res://sprites/suit_Pik.png")
@onready var alk_tex: Texture2D = preload("res://sprites/suit_Alk.png")
@onready var smoke_tex: Texture2D = preload("res://sprites/suit_Smoke.png")

var suit_textures: Dictionary = {}

var table_root: Node2D

var played_card_nodes: Array[Node2D] = []

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


func set_table_root(node: Node2D) -> void:
	table_root = node

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

	_clear_table_visuals()

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

	if player_id != turn_order[current_turn_index]:
		return

	current_round_plays[player_id] = card_data

	# Visualize played card immediately
	_show_played_card(player_id, card_data)

	current_turn_index += 1

	# Delay for requesting next player (nice pacing)
	await get_tree().create_timer(1.0).timeout
	_request_current_player()


func _show_played_card(player_id: int, card_data: Variant) -> void:

	var card_view := card_scene.instantiate() as Card
	table_root.add_child(card_view)

	# If your Card scene uses the "Card" script with setup(card_data, suit_textures),
	# keep this call. If it’s named differently, adjust the type/call.
	if card_view.has_method("setup") && card_data != null:
		card_view.call("setup", card_data)
	
	else: 
		print("No card Data!")
	
	# Place in the center with a small offset per player so you can see all three
	var center := _get_table_center_world()

	var offset := Vector2.ZERO
	match player_id:
		PLAYER_HUMAN:
			offset = Vector2(0, 20)
		PLAYER_AI_1:
			offset = Vector2(-30, 0)
		PLAYER_AI_2:
			offset = Vector2(30, 0)

	card_view.global_position = center + offset
	played_card_nodes.append(card_view)


func _get_table_center_world() -> Vector2:
	# If you have a Camera2D, use its center for "screen center in world".
	# Otherwise fall back to the viewport center in global canvas coordinates.
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return cam.global_position

	# Fallback if no camera exists
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5)


func _clear_table_visuals() -> void:
	for n in played_card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	played_card_nodes.clear()


func _finish_round() -> void:
	
	# Delay for requesting next player (nice pacing)
	await get_tree().create_timer(2.0).timeout
	
	var winner_id := calculate_round_winner(current_round_plays)

	if winner_id not in PLAYERS:
		winner_id = current_starting_player

	last_round_winner = winner_id

	emit_signal("round_completed", current_round, current_round_plays, winner_id)
	print("Started new Round")
	_start_new_round(winner_id)


func calculate_round_winner(current_plays: Dictionary) -> int:
	print("Player 0 won")
	return 0
