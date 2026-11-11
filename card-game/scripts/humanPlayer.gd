extends Player
class_name HumanPlayer

# Layout
@export var card_space: float = 400
@export var MAX_GAP := 58.0

@export var bottom_margin: float = 150
var card_half_width := 30.0

var card_visuals : Array[CardVisual] = []

var is_my_turn: bool = false

func _ready() -> void:
	super._ready()
	
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.turn_started.connect(_on_turn_started)
	
	InteractionManager.register(self)
	GameManager.register(self)

func recieve_hand(hand: Hand):
	get_ownership_of_hand_cards(hand)
	self.hand = hand
	render_hand()
	
	hand.hand_shrinked.connect(on_hand_shrinked)
	hand.hand_grew.connect(on_hand_grew)

func on_hand_shrinked():
	await get_tree().process_frame
	layout_hand_cards()
	_refresh_playable_cards()

func on_hand_grew():
	render_hand()

func can_play(card: Card) -> bool:
	if not is_my_turn:
		return false

	if _blocked_by_tutorial(card):
		return false

	return CardManager.is_legal_play(hand, card)

func _blocked_by_tutorial(card: Card) -> bool:
	return TutorialScript.blocks_human_play(hand, card, GameManager.current_turn)

func explain_refusal(card: Card) -> void:
	if is_my_turn and _blocked_by_tutorial(card):
		GameManager.message(TutorialScript.human_hint(hand, GameManager.current_turn))

func has_hand_visual(card_visual: CardVisual) -> bool:
	return not card_visual.is_queued_for_deletion() and card_visuals.has(card_visual) and hand.contains(card_visual.card)

func try_play_card(card: Card) -> void:
	if not can_play(card):
		explain_refusal(card)
		deny_card(card)
		return

	is_my_turn = false
	var from := get_card_transform(card)
	hand.remove(card)
	_refresh_playable_cards()
	set_active(false)
	CardManager.submit_play(player_id, card, from)


func deny_card(card: Card) -> void:
	for card_visual in card_visuals:
		if is_instance_valid(card_visual) and card_visual.card == card:
			card_visual.deny()
			Sfx.play_card_move()
			return


func _on_turn_started(_turn_index: int, _starting_player_id: int) -> void:
	is_my_turn = false
	_refresh_playable_cards()


func _on_request_play_card(requested_player_id: int) -> void:
	is_my_turn = (requested_player_id == player_id)
	_refresh_playable_cards()


func _refresh_playable_cards() -> void:
	for card_visual in card_visuals:
		if is_instance_valid(card_visual):
			card_visual.set_playable(can_play(card_visual.card))
			if hand.contains(card_visual.card):
				card_visual.set_locked(is_my_turn and _blocked_by_tutorial(card_visual.card))


func render_hand():
	_anchor_to_bottom_of_view()

	for card_visual in card_visuals:
		if is_instance_valid(card_visual):
			card_visual.queue_free()
	card_visuals.clear()

	for card in hand.cards:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
		
		c.setup(card, false)
		c.add_table_shadow()

		add_child(c)
		c.enable_juice()
		card_visuals.append(c)

	layout_hand_cards(true)
	_refresh_playable_cards()


func _anchor_to_bottom_of_view() -> void:
	# UI coordinates (this Control is the root)
	var vs := get_viewport().get_visible_rect().size
	position = Vector2(vs.x * 0.5 - card_half_width, vs.y - bottom_margin)


func layout_hand_cards(snap: bool = false) -> void:
	if card_visuals.is_empty():
		return

	card_visuals = card_visuals.filter(func(c):
		return is_instance_valid(c)
	)

	var n = card_visuals.size()
	if n > 0:
		pivot_offset = card_visuals[0].size * 0.5

	if n == 1:
		card_visuals[0].set_home(Vector2.ZERO, 0.0, snap)
		return

	for i in range(n):
		var cv = card_visuals[i]
		cv.set_home(_slot_position(i, n), _slot_rotation(i, n), snap)
		cv.z_index = i
		cv.update_layout()


func _slot_position(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var gap = min(card_space / float(count - 1), MAX_GAP, _max_gap_for_deck(count))
	var start_x = -gap * float(count - 1) * 0.5
	var from_center := float(index) - float(count - 1) * 0.5
	return Vector2(start_x + gap * float(index), roundf(from_center * from_center * CardJuice.FAN_DROP_PX))


func _max_gap_for_deck(count: int) -> float:
	var limit := _right_limit()
	if limit <= 0.0:
		return MAX_GAP
	var vs := get_viewport().get_visible_rect().size
	var span := 2.0 * (limit - vs.x * 0.5 - card_half_width * 2.0)
	return maxf(span / float(count - 1), 8.0)


func _right_limit() -> float:
	for deck_pile in get_tree().get_nodes_in_group(GameManager.DECK_PILE_GROUP):
		if deck_pile.deck_owner == Card.Owner.HUMAN:
			return deck_pile.position.x - 32.0 - 14.0
	return 0.0


func _slot_rotation(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return deg_to_rad((float(index) - float(count - 1) * 0.5) * CardJuice.FAN_ANGLE_DEG)


func deal_card(card: Card, from_center: Vector2, slot: int, slot_count: int) -> void:
	hand.append(card)
	var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
	c.setup(card, true)
	c.add_table_shadow()
	add_child(c)
	card_visuals.append(c)
	c.position = _slot_position(slot, slot_count)
	c.rotation = _slot_rotation(slot, slot_count)
	c.z_index = slot
	c.enable_juice()
	c.set_home(c.position, c.rotation, true)
	c.update_layout()
	Sfx.play_card_move()
	c.deal_from(Transform2D(0.0, Vector2.ONE, 0.0, from_center - c.pivot_offset), true)


func finish_deal() -> void:
	layout_hand_cards()
	_refresh_playable_cards()
