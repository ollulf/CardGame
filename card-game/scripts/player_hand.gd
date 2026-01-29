extends Node2D
class_name PlayerHand

@export var player_id: int = 0

# Optional: assign your main Camera2D here so the hand sticks to the bottom of the camera view.
@export var camera_path: NodePath

# Layout
@export var card_spacing: float = 40.0
@export var bottom_margin: float = 90.0

var hand: Array[Dictionary] = []
var card_nodes: Array[Node2D] = []
var is_my_turn: bool = false

@onready var cam: Camera2D = get_node_or_null(camera_path) as Camera2D


func _ready() -> void:
	# Hook into the turn system
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)

	_build_test_hand()
	_render_hand()


func _process(_delta: float) -> void:
	# In world space, the camera can move every frame.
	# So we keep re-anchoring the hand position.
	_anchor_to_bottom_of_view()


func _on_round_started(round_index: int, starting_player_id: int) -> void:
	is_my_turn = false


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)


func _build_test_hand() -> void:
	hand.clear()
	var suits := ["hearts", "diamonds", "clubs", "spades", "alk", "smoke"]

	for i in range(7):
		var card := {
			"suit": suits[randi() % suits.size()],
			"rank": randi_range(1, 13)
		}
		hand.append(card)


func _render_hand() -> void:
	print("Rendering Hand")
	for n in card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	card_nodes.clear()

	for i in range(hand.size()):
		var card_data := hand[i]
		var card_view := GameManager.card_scene.instantiate() as Card
		add_child(card_view)
		card_nodes.append(card_view)

		card_view.setup(card_data)
		card_view.double_clicked.connect(_on_card_double_clicked)

	_layout_cards()


func _anchor_to_bottom_of_view() -> void:
	# If we have a camera, anchor relative to its visible rect in world coordinates.
	if cam != null:
		var viewport_size := get_viewport().get_visible_rect().size
		var half := viewport_size * 0.5

		# Camera center in world space
		var center := cam.global_position

		# Bottom center of the camera view (world space)
		var bottom_center := Vector2(center.x, center.y + half.y)

		# Place this hand node slightly above the bottom edge
		global_position = Vector2(bottom_center.x, bottom_center.y - bottom_margin)
		return

	# Fallback: anchor relative to viewport, not camera (won't follow camera movement).
	var vs := get_viewport().get_visible_rect().size
	global_position = Vector2(vs.x * 0.5, vs.y - bottom_margin)


func _layout_cards() -> void:
	# Layout cards centered around the PlayerHand node.
	var total_width := (hand.size() - 1) * card_spacing
	var start_x := -total_width * 0.5

	for i in range(card_nodes.size()):
		var n := card_nodes[i]
		if not is_instance_valid(n):
			continue
		n.position = Vector2(start_x + i * card_spacing, 0.0)


func _on_card_double_clicked(card_view: Card) -> void:
	if not is_my_turn:
		return

	var idx := _find_card_index(card_view.card_data)
	if idx == -1:
		return

	GameManager.submit_play(player_id, hand[idx])

	hand.remove_at(idx)
	_render_hand()

	is_my_turn = false


func _find_card_index(data: Dictionary) -> int:
	for i in range(hand.size()):
		if hand[i].get("suit") == data.get("suit") and hand[i].get("rank") == data.get("rank"):
			return i
	return -1
