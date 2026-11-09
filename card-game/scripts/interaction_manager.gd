extends Node

var cigPack: CigPack
var hand: HandVisualisation
var human_player: HumanPlayer

@export var cigarette_scene:= preload("res://scenes/cigarette.tscn") 

const MAX_IN_HAND := 3
const BURN_SECONDS := AiSmoke.LIGHT_TIME + AiSmoke.BURN_TIME
const DRAG_THRESHOLD := 6.0

var _burn_token: int = 0

var hovered_card : CardVisual = null

var _pressed_card : CardVisual = null
var _press_position : Vector2
var _grab_offset : Vector2
var _is_dragging : bool = false
var _skip_double_click : bool = false
var _table_blocked : bool = false

func register(player : Player):
	human_player = player

func _process(delta: float) -> void:
	check_for_hovered_card()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_press()

func cancel_press() -> void:
	if not _is_press_active():
		return

	var card_visual := _pressed_card
	var was_dragging := _is_dragging
	_clear_press()
	if was_dragging:
		_return_to_hand(card_visual)

func set_table_blocked(blocked: bool) -> void:
	_table_blocked = blocked
	cancel_press()
	get_viewport().physics_object_picking = not blocked

func is_table_blocked() -> bool:
	return _table_blocked

func skip_next_double_click() -> void:
	_skip_double_click = true

func check_for_hovered_card() -> void:
	if _is_press_active():
		return

	var c: Control = null if DialogueManager.is_open() or _table_blocked else get_viewport().gui_get_hovered_control()
	var new_hovered: CardVisual = null

	# Walk up from the hovered control until we find a Card (or nothing)
	while c != null:
		if c is CardVisual:
			new_hovered = c as CardVisual
			break
		c = c.get_parent() as Control

	# If nothing changed, do nothing
	if new_hovered == hovered_card:
		return

	# Leaving old card
	if is_instance_valid(hovered_card):
		hovered_card.hover_exit()

	# Entering new card
	hovered_card = new_hovered
	if is_instance_valid(hovered_card):
		hovered_card.hover_enter()
		if _is_draggable(hovered_card) and hovered_card.hover_enabled and not hovered_card.face_down:
			Sfx.play_hover_card()



func _input(event: InputEvent) -> void:
	if _table_blocked:
		return

	if event is InputEventMouseMotion:
		_update_drag(event)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_press(event.position)
		return

	# Right click: put one unlit cigarette back into the pack
	if event is InputEventMouseButton and event.pressed:
		# Right click: put one unlit cigarette back into the pack
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_return_one_unlit_to_pack()
			return
	
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and not _skip_double_click and is_instance_valid(hovered_card):
				human_player.try_play_card(hovered_card.card)
			_skip_double_click = false
			_begin_press(event)

func _begin_press(event: InputEventMouseButton) -> void:
	if _is_press_active() or not _is_draggable(hovered_card):
		return

	_pressed_card = hovered_card
	_press_position = event.position
	_grab_offset = human_player.make_input_local(event).position - _pressed_card.position

func _update_drag(event: InputEventMouseMotion) -> void:
	if not _is_press_active():
		return

	if not _is_dragging:
		if event.position.distance_to(_press_position) < DRAG_THRESHOLD:
			return
		_is_dragging = true
		_pressed_card.begin_drag()

	_pressed_card.position = human_player.make_input_local(event).position - _grab_offset

func _release_press(mouse_position: Vector2) -> void:
	if not _is_press_active():
		return

	var card_visual := _pressed_card
	var was_dragging := _is_dragging
	_clear_press()

	if not was_dragging:
		return

	hovered_card = null

	if CardManager.is_in_play_zone(mouse_position):
		if human_player.can_play(card_visual.card):
			human_player.try_play_card(card_visual.card)
			return
		human_player.explain_refusal(card_visual.card)

	_return_to_hand(card_visual)

func _return_to_hand(card_visual: CardVisual) -> void:
	if hovered_card == card_visual:
		hovered_card = null
	card_visual.end_drag()
	human_player.layout_hand_cards()

func _is_press_active() -> bool:
	if _is_draggable(_pressed_card):
		return true
	_clear_press()
	return false

func _is_draggable(card_visual) -> bool:
	return is_instance_valid(card_visual) and human_player != null and human_player.has_hand_visual(card_visual)

func _clear_press() -> void:
	_pressed_card = null
	_is_dragging = false

func pickedUpCig() -> void:
	addCigToHand()

func usedLighter() -> void:
	CardManager.update_cards(hand.light_all_unlit())

	_burn_token += 1
	var my_token := _burn_token

	await get_tree().create_timer(BURN_SECONDS, false).timeout
	if my_token != _burn_token:
		return

	hand.burn_finished_to_stumps()

func usedAshTray() -> void:
	hand.remove_all_stumps()

func addCigToHand() -> void:
	if hand.get_total_count() >= MAX_IN_HAND:
		GameManager.message("Hand is full.")
		return

	cigPack.cig_amount -= 1
	var cig := cigarette_scene.instantiate() as Cigarette
	hand.add_cigarette(cig, Cigarette.State.UNLIT)

func held_cigarette_count() -> int:
	var count := 0
	if cigPack != null:
		count += cigPack.cig_amount
	if hand != null:
		count += hand.unlit_count()
	return count

func reset_cigarettes(amount: int) -> void:
	_burn_token += 1
	if hand != null:
		hand.clear_cigarettes()
	if cigPack != null:
		cigPack.cig_amount = amount

func _return_one_unlit_to_pack() -> void:
	var did_remove := hand.remove_one_unlit()
	
	if did_remove:
		cigPack.cig_amount += 1
		cigPack.update_label()
