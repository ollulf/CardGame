extends  Node

var card_scene: PackedScene = preload("res://scenes/Card.tscn")

@onready var hearts_tex: Texture2D = preload("res://sprites/suit_Herz.png")
@onready var diamonds_tex: Texture2D = preload("res://sprites/suit_Karo.png")
@onready var clubs_tex: Texture2D = preload("res://sprites/suit_Kreuz.png")
@onready var spades_tex: Texture2D = preload("res://sprites/suit_Pik.png")
@onready var alk_tex: Texture2D = preload("res://sprites/suit_Alk.png")
@onready var smoke_tex: Texture2D = preload("res://sprites/suit_Smoke.png")

var suit_textures: Dictionary = {}

# Suits that count as trump
var trump_suits: Array[String] = ["alk", "smoke"]

# Table / played tracking
var table_root: Control
var played_card_nodes: Dictionary = {} # player_id -> Card node
var played_cards: Dictionary = {}      # player_id -> cardData Dictionary

var player_hands: Dictionary = {} # player_id -> Array[Cards (Dictionary)]

# Trick state
var first_played_trump_suit: String = ""


func _ready() -> void:
	suit_textures = {
		"hearts": hearts_tex,
		"diamonds": diamonds_tex,
		"clubs": clubs_tex,
		"spades": spades_tex,
		"alk": alk_tex,
		"smoke": smoke_tex
	}

# In this function the Card Manager should get through the active buffs and update the cards of that player
func update_cards():
	# Create Array of Cards for each player
	
	# For each Array of Cards, Go through each card and then apply the buff for that player
	pass

func set_table_root(node: Control) -> void:
	table_root = node

func generate_player_hands():
	pass
	

func register_play(player_id: int, card_data: Variant) -> void:
	# Track first played trump suit
	if first_played_trump_suit == "" and is_trump_card(card_data):
		first_played_trump_suit = str(card_data.get("suit", ""))

	# Store data
	played_cards[player_id] = card_data

	# Visualize
	_show_played_card(player_id, card_data)


func _show_played_card(player_id: int, card_data: Variant) -> void:
	if table_root == null:
		push_warning("CardManager: table_root not set; cannot show played cards.")
		return

	var card_view := card_scene.instantiate() as Card
	table_root.add_child(card_view)

	if card_view.has_method("setup") and card_data != null:
		card_view.call("setup", card_data, true, player_id)
	else:
		print("No card Data!")

	var center := _get_table_center_world()

	var offset := Vector2.ZERO
	match player_id:
		GameManagerClass.PLAYER_HUMAN:
			offset = Vector2(0, -135)
		GameManagerClass.PLAYER_AI_1:
			offset = Vector2(-70, -160)
		GameManagerClass.PLAYER_AI_2:
			offset = Vector2(60, -195)

	card_view.global_position = center + offset
	card_view.scale = Vector2(1.5, 1.5)

	# Layering: later plays on top
	card_view.z_index = played_card_nodes.size()

	played_card_nodes[player_id] = card_view


func _get_table_center_world() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5)


func clear_table_visuals() -> void:
	for player_id in played_card_nodes.keys():
		var n = played_card_nodes[player_id]
		if is_instance_valid(n):
			n.queue_free()
	played_card_nodes.clear()
	played_cards.clear()


func round_clean_up() -> void:
	first_played_trump_suit = ""


# --- Trump helpers ---

func suit_is_trump(suit: String) -> bool:
	return suit in trump_suits


func is_trump_card(card_data: Variant) -> bool:
	return str(card_data.get("suit", "")) in trump_suits


func get_highest_lead_suit_rank(starting_player_id: int) -> int:
	if not played_cards.has(starting_player_id):
		return -1

	var lead_card: Dictionary = played_cards[starting_player_id]
	var lead_suit: String = str(lead_card.get("suit", ""))

	var highest := -1
	for pid in played_cards.keys():
		var c: Dictionary = played_cards[pid]
		if str(c.get("suit", "")) != lead_suit:
			continue
		highest = maxi(highest, int(c.get("rank", -1)))

	return highest


func get_highest_first_trump_rank_played() -> int:
	if first_played_trump_suit == "":
		return -1

	var highest := -1
	for pid in played_cards.keys():
		var c = played_cards[pid]
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if str(c.get("suit", "")) != first_played_trump_suit:
			continue
		highest = maxi(highest, int(c.get("rank", -1)))

	return highest
