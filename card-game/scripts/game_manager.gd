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

# --- Cards ---
var card_scene: PackedScene = preload("res://scenes/Card.tscn")

@onready var hearts_tex: Texture2D = preload("res://sprites/suit_Herz.png")
@onready var diamonds_tex: Texture2D = preload("res://sprites/suit_Karo.png")
@onready var clubs_tex: Texture2D = preload("res://sprites/suit_Kreuz.png")
@onready var spades_tex: Texture2D = preload("res://sprites/suit_Pik.png")
@onready var alk_tex: Texture2D = preload("res://sprites/suit_Alk.png")
@onready var smoke_tex: Texture2D = preload("res://sprites/suit_Smoke.png")

var suit_textures: Dictionary = {}
var trump_suits : Array[String] = ["alk", "smoke"]

var table_root: Control

var played_card_nodes: Dictionary = {} #player_id and Card
var played_cards: Dictionary = {} #player_id and cardData

# --- State ---
var rounds_played := 0
var current_round := 0
var match_over := false

var current_starting_player := PLAYER_HUMAN
var last_round_winner := PLAYER_HUMAN

var current_round_plays: Dictionary = {}
var first_played_trump_suit := ""

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


func set_table_root(node: Control) -> void:
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

	if match_over:
		return

	if rounds_played >= MAX_ROUNDS:
		match_over = true
		message(str(PLAYERS[last_round_winner]) + " won the match!")
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
	message(str(PLAYERS[player_id]) + "'s turn")
	emit_signal("request_play_card", player_id)


# Called by human & AI controllers
func submit_play(player_id: int, card_data: Variant) -> void:
	current_round_plays[player_id] = card_data

	# Visualize played card immediately
	_show_played_card(player_id, card_data)
	
	# Check for Trump Card
	if is_trump(card_data) and first_played_trump_suit == "":
		first_played_trump_suit = card_data["suit"] 

	current_turn_index += 1

	# Delay for requesting next player (nice pacing)
	_request_current_player()


func _show_played_card(player_id: int, card_data: Variant) -> void:

	var card_view := card_scene.instantiate() as Card
	table_root.add_child(card_view)

	# If your Card scene uses the "Card" script with setup(card_data, suit_textures),
	# keep this call. If it’s named differently, adjust the type/call.
	if card_view.has_method("setup") && card_data != null:
		card_view.call("setup", card_data, true)
	
	else: 
		print("No card Data!")
	
	# Place in the center with a small offset per player so you can see all three
	var center := _get_table_center_world()

	var offset := Vector2.ZERO
	match player_id:
		PLAYER_HUMAN:
			offset = Vector2(0, -135)
		PLAYER_AI_1:
			offset = Vector2(-70, -160)
		PLAYER_AI_2:
			offset = Vector2(60, -195)

	card_view.global_position = center + offset
	card_view.scale = Vector2(1.5,1.5)
	
	card_view.z_index = played_card_nodes.size()
	
	played_card_nodes[player_id] = card_view
	played_cards[player_id] = card_data


func _get_table_center_world() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5)


func _clear_table_visuals() -> void:
	for player_id in played_card_nodes.keys():
		var n = played_card_nodes[player_id]
		if is_instance_valid(n):
			n.queue_free()
	played_card_nodes.clear()
	played_cards.clear()

func _finish_round() -> void:
	await get_tree().create_timer(2.0).timeout
	
	var winner_id := calculate_round_winner(current_round_plays)

	last_round_winner = winner_id

	message(str(PLAYERS[winner_id]) + " won the Round")
	
	await get_tree().create_timer(3.0).timeout
	
	emit_signal("round_completed", current_round, current_round_plays, winner_id)
	_start_new_round(winner_id)


func calculate_round_winner(current_plays: Dictionary) -> int:
	var lead_card: Dictionary = current_plays[current_starting_player]
	var lead_suit: String = str(lead_card.get("suit"))

	if first_played_trump_suit != "":
		var winning_player := -1
		var highest_rank := -1

		for player_id in current_plays.keys():
			var card = current_plays[player_id]
			if str(card.get("suit", "")) != first_played_trump_suit:
				continue

			var r: int = int(card.get("rank"))
			if r > highest_rank:
				highest_rank = r
				winning_player = player_id

		# If for some reason we didn't find it, fall back to lead-suit logic
		if winning_player != -1:
			round_clean_up()
			return winning_player

	# --- NORMAL RULE (lead suit wins) ---
	var winning_player: int = current_starting_player
	var highest_rank: int = int(lead_card.get("rank", -1))

	for player_id in current_plays.keys():
		var card = current_plays[player_id]
		if typeof(card) != TYPE_DICTIONARY:
			continue

		# Only cards of the lead suit can win
		if str(card.get("suit", "")) != lead_suit:
			continue

		var r: int = int(card.get("rank", -1))
		if r > highest_rank:
			highest_rank = r
			winning_player = player_id

	round_clean_up()
	return winning_player


func suit_is_trump(suit : String) -> bool:
	for s in trump_suits:
		if suit == s:
			return true
	return false

func is_trump(card_data : Variant) -> bool:
	for s in trump_suits:
		if card_data["suit"] == s:
			return true
	return false

func round_clean_up():
	first_played_trump_suit = ""

func get_highest_lead_suit_rank() -> int:

	var lead_card: Dictionary = played_cards[current_starting_player]
	var lead_suit: String = str(lead_card.get("suit", ""))

	var highest := -1

	for player_id in played_cards.keys():
		var c: Dictionary = played_cards[player_id]
		if str(c.get("suit", "")) != lead_suit:
			continue

		var r: int = int(c.get("rank", -1))
		if r > highest:
			highest = r

	return highest

func message(text: String):
	emit_signal("send_message", text)
