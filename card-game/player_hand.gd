extends CanvasLayer
class_name PlayerHand

@export var player_id: int = 0

# Drag your CardView2D.tscn here in the Inspector
@export var card_scene: PackedScene

# Suit textures: assign in Inspector (or preload in code if you prefer)
@export var hearts_tex: Texture2D
@export var diamonds_tex: Texture2D
@export var clubs_tex: Texture2D
@export var spades_tex: Texture2D

# Layout
@export var card_spacing: float = 120.0
@export var bottom_margin: float = 90.0

var suit_textures: Dictionary = {}
var hand: Array[Dictionary] = []
var card_nodes: Array[Node] = []

var is_my_turn: bool = false


func _ready() -> void:
	suit_textures = {
		"hearts": hearts_tex,
		"diamonds": diamonds_tex,
		"clubs": clubs_tex,
		"spades": spades_tex
	}

	# Hook into the turn system
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)

	# Temporary: generate a starter hand so you see something immediately
	# Remove this later when your deck/deal system exists.
	_build_test_hand()
	_render_hand()


func _on_round_started(round_index: int, starting_player_id: int) -> void:
	# New round starts: you are NOT automatically allowed to play
	# until GameManager actually requests your player_id.
	is_my_turn = false


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)


func _build_test_hand() -> void:
	hand.clear()
	var suits := ["hearts", "diamonds", "clubs", "spades"]

	for i in range(7):
		var card := {
			"suit": suits[randi() % suits.size()],
			"rank": randi_range(1, 13)
		}
		hand.append(card)


func _render_hand() -> void:
	# Clear old nodes
	for n in card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	card_nodes.clear()

	if card_scene == null:
		push_warning("PlayerHand: card_scene is not assigned.")
		return

	# Spawn new nodes
	for i in range(hand.size()):
		var card_data := hand[i]
		var card_view := card_scene.instantiate() as CardView2D
		add_child(card_view)
		card_nodes.append(card_view)

		card_view.setup(card_data, suit_textures)
		card_view.double_clicked.connect(_on_card_double_clicked)

	# Layout
	_layout_cards()


func _layout_cards() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var y := viewport_size.y - bottom_margin

	var total_width := (hand.size() - 1) * card_spacing
	var start_x := (viewport_size.x * 0.5) - (total_width * 0.5)

	for i in range(card_nodes.size()):
		var n := card_nodes[i]
		if not is_instance_valid(n):
			continue
		n.global_position = Vector2(start_x + i * card_spacing, y)


func _notification(what: int) -> void:
	# Keep the hand glued to the bottom on resize
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_cards()


func _on_card_double_clicked(card_view: CardView2D) -> void:
	if not is_my_turn:
		return

	# Find the card in the hand
	var idx := _find_card_index(card_view.card_data)
	if idx == -1:
		return

	# Submit the play to GameManager
	GameManager.submit_play(player_id, hand[idx])

	# Remove from hand + re-render
	hand.remove_at(idx)
	_render_hand()

	# Your turn is consumed. GameManager will request the next player.
	is_my_turn = false


func _find_card_index(data: Dictionary) -> int:
	# This is “good enough” for now.
	# Later you may want unique IDs on cards to avoid duplicates ambiguity.
	for i in range(hand.size()):
		if hand[i].get("suit") == data.get("suit") and hand[i].get("rank") == data.get("rank"):
			return i
	return -1
