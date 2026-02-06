extends Player
class_name HumanPlayer

# Layout
@export var card_space: float = 400
@export var bottom_margin: float = 150

# CardUI scene (root must be Control, e.g. CardUI)
@export var card_ui_scene: PackedScene = preload("res://scenes/Card.tscn")

var is_my_turn: bool = false

func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)
	
	InteractionManager.human_player = self


func try_play_card(card: Card) -> void:
	if not is_my_turn:
		return

	if not hand.contains(card):
		return

	var leading_suit = CardManager.leading_card.suit
	
	# --- Follow the obay suit rule ---
	if hand.contains_card_of_suit(leading_suit) and card.suit != leading_suit:
		print("Must obay leading suit of: " + leading_suit)
		return

	# Move is legal
	CardManager.submit_play(player_id, card)
	
	_render_hand()
	
	is_my_turn = false


func _on_round_started(_round_index: int, _starting_player_id: int) -> void:
	is_my_turn = false


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)


func _render_hand() -> void:
	_anchor_to_bottom_of_view()

	for card in hand:
		if is_instance_valid(card):
			n.queue_free()
	card_nodes.clear()

	for i in range(hand.size()):
		var card_data := hand[i]
		var card_view := card_ui_scene.instantiate() as Card
		card_view._base_z = i
		card_view.z_index = i
		add_child(card_view)
		card_nodes.append(card_view)
		card_view.setup(card_data, true, player_id)

	_layout_cards()


func _anchor_to_bottom_of_view() -> void:
	# UI coordinates (this Control is the root)
	var vs := get_viewport().get_visible_rect().size
	position = Vector2(vs.x * 0.5, vs.y - bottom_margin)


func _layout_cards() -> void:
	var count := card_nodes.size()
	if count <= 0:
		return

	if count == 1:
		var n := card_nodes[0]
		if is_instance_valid(n):
			n.position = Vector2.ZERO
		return

	var half_width := card_space * 0.5
	var step := card_space / float(count - 1)

	for i in range(count):
		var n := card_nodes[i]
		if not is_instance_valid(n):
			continue

		var x := -half_width + i * step
		n.position = Vector2(x, 0.0)
