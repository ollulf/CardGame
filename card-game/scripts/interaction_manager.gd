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

const TOUCH_MOUSE_GRACE_MS := 800

var touch_mode : bool = false
var _last_touch_ms : int = -100000
var _touch_selected : CardVisual = null
var _touch_play_on_release : bool = false

const MOBILE_FONT_BONUS := 3

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		enlarge_theme_text(MOBILE_FONT_BONUS)

func enlarge_theme_text(bonus: int) -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.default_font_size += bonus
	for type in theme.get_font_size_type_list():
		for font_size_name in theme.get_font_size_list(type):
			theme.set_font_size(font_size_name, type, theme.get_font_size(font_size_name, type) + bonus)

func register(player : Player):
	human_player = player

func _process(delta: float) -> void:
	check_for_hovered_card()

func _is_touch_event(event: InputEvent) -> bool:
	return event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION)

func _track_pointer(event: InputEvent) -> void:
	if _is_touch_event(event):
		touch_mode = true
		_last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouseMotion and Time.get_ticks_msec() - _last_touch_ms > TOUCH_MOUSE_GRACE_MS:
		touch_mode = false

func _hand_card_at(canvas_pos: Vector2) -> CardVisual:
	if human_player == null:
		return null
	var candidates: Array[CardVisual] = []
	if _is_draggable(hovered_card):
		candidates.append(hovered_card)
	for i in range(human_player.card_visuals.size() - 1, -1, -1):
		candidates.append(human_player.card_visuals[i])
	for cv in candidates:
		if not _is_draggable(cv) or not cv.is_visible_in_tree():
			continue
		var local := cv.get_global_transform_with_canvas().affine_inverse() * canvas_pos
		if Rect2(Vector2.ZERO, cv.size).has_point(local):
			return cv
	return null

func _set_hovered(card_visual: CardVisual) -> void:
	if card_visual == hovered_card:
		return
	if is_instance_valid(hovered_card):
		hovered_card.hover_exit()
	hovered_card = card_visual
	if is_instance_valid(hovered_card):
		hovered_card.hover_enter()
		if hovered_card.hover_enabled and not hovered_card.face_down:
			Sfx.play_hover_card()

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

	if touch_mode and _is_draggable(_touch_selected) and not DialogueManager.is_open() and not _table_blocked:
		_set_hovered(_touch_selected)
		return

	var c: Control = null if DialogueManager.is_open() or _table_blocked else get_viewport().gui_get_hovered_control()
	var new_hovered: CardVisual = null

	# Walk up from the hovered control until we find a Card (or nothing)
	while c != null:
		if c is CardVisual:
			new_hovered = c as CardVisual
			break
		c = c.get_parent() as Control

	if touch_mode and _is_draggable(new_hovered):
		new_hovered = null

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
	_track_pointer(event)

	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_skip_double_click = false
		if not _table_blocked:
			_begin_touch_press(event)
		return

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

func _begin_touch_press(event: InputEventMouseButton) -> void:
	if DialogueManager.is_open():
		return
	var hit := _hand_card_at(event.position)
	var was_selected := hit != null and hit == _touch_selected
	_touch_selected = hit
	if hit == null:
		if hand != null and hand.is_parked_hit(event.position):
			_return_one_unlit_to_pack()
		return
	_set_hovered(hit)
	_begin_press(event)
	_touch_play_on_release = was_selected and _pressed_card == hit

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
	var play_on_tap := _touch_play_on_release
	_clear_press()

	if not was_dragging:
		if play_on_tap:
			human_player.try_play_card(card_visual.card)
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
	_touch_play_on_release = false

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
