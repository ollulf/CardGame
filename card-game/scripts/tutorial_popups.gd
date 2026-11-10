extends CanvasLayer
class_name TutorialPopups

signal finished

enum Side { ABOVE, BELOW, RIGHT, LEFT, NONE }

const POPUP_LAYER := 115
const SHOW_DELAY := 0.45
const URGENT_DELAY := 0.35
const FADE_TIME := 0.15
const AUTO_HOLD := 2.5
const BG_COLOR := Color(0.121569, 0.117647, 0.14902, 1)
const BORDER_COLOR := Color("3d3854")
const TEXT_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const BUBBLE_WIDTH := 270.0
const SCREEN_MARGIN := 8.0
const TAIL_GAP := 30.0
const POINT_PAD := 36.0
const MIN_TARGET_SIZE := 4.0
const BASIC_TIPS := ["follow", "trump", "bierdeckel", "deck", "lives", "smoke"]

const TIPS := {
	"follow": {
		"title": "Your turn",
		"text": "Play one card. The [b]highest card[/b] of the [b]first suit played[/b] wins the turn. The other players must [b]follow the first suit[/b] if they can.",
	},
	"trump": {
		"title": "Trump",
		"text": "[b]Trump[/b] beats every other suit. It is shown at the top and picked [b]at random[/b] each match.",
	},
	"bierdeckel": {
		"title": "Won turns",
		"text": "Each won turn gives a [b]Bierdeckel[/b]. After [b]5 turns[/b], the fewest loses the round.",
	},
	"deck": {
		"title": "New round",
		"text": "Each round you draw [b]5 new cards[/b] from your deck. Played cards stay out until the match ends.",
	},
	"lives": {
		"title": "Lost a round",
		"text": "The loser rips a [b]life card[/b]. Lose [b]2 rounds[/b] and you are out of the match.",
	},
	"smoke": {
		"title": "Smoking cards",
		"text": "[b]Smoking cards[/b] are always trump. Each cigarette smoked gives them [b]+1[/b] this round.",
	},
	"zero": {
		"title": "Zero",
		"text": "A [b]0[/b] beats a [b]9[/b] of the [b]same suit[/b], but never a 9 of another suit.",
	},
	"tie": {
		"title": "Equal cards",
		"text": "When two cards are [b]equal[/b], the one played [b]first[/b] wins.",
	},
	"tiebreak": {
		"title": "Tie-break",
		"text": "Tied for fewest turns? Each tied player draws a card. The [b]lowest number[/b] loses; suit and trump don't count.",
	},
	"prize": {
		"title": "Prize money",
		"text": "The last loser pays the [b]prize[/b]. The [b]two winners[/b] of this match split it.",
	},
	"cigs": {
		"title": "Cigarettes",
		"text": "Tap your [b]pack[/b] to take a cigarette, then the [b]lighter[/b] to smoke it. Smoking cards get [b]+1[/b] per cigarette this round.",
	},
	"wallet": {
		"title": "Your money",
		"text": "Winners share the [b]prize money[/b]. Spend it at the [b]bar[/b] on [b]boosters[/b] with new cards.",
	},
	"deck_size": {
		"title": "Your deck",
		"text": "A deck needs [b]{min} to {max} cards[/b]. Click cards to move them in or out.",
	},
	"drinks": {
		"title": "Round of drinks",
		"text": "At the bar a [b]Round of Drinks[/b] costs [b]$5[/b]. Everyone drinks: drinking cards [b]+1[/b], all others [b]-1[/b] for the match.",
	},
	"alk": {
		"title": "Drinking cards",
		"text": "[b]Drinking cards[/b] are always trump and get [b]+1[/b] for every drink.",
	},
}

static var instance: TutorialPopups
static var shown: Array[String] = []

var _pending: Array = []
var _bubble: PointerBubble
var _blocker: Control
var _target = null
var _side := Side.NONE
var _waiting := false
var _was_blocked := false
var _paused_game := false
var _pointer_parent: Node
var _pointer_index := 0

static func tip(key: String, target = null, urgent := false) -> void:
	if instance != null and is_instance_valid(instance):
		instance.request(key, target, urgent)

static func wait_idle() -> void:
	while instance != null and is_instance_valid(instance) and instance.is_busy():
		await instance.finished

static func reset_run() -> void:
	shown.clear()

static func skip_basics() -> void:
	shown.clear()
	for key in BASIC_TIPS:
		shown.append(key)

static func load_shown(keys) -> void:
	shown.clear()
	if keys is Array:
		for key in keys:
			if key is String and TIPS.has(key) and not key in shown:
				shown.append(key)

func _init() -> void:
	layer = POPUP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self

func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.match_lost.connect(_on_match_lost)
	CardManager.card_played.connect(_on_card_played)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _on_request_play_card(player_id: int) -> void:
	if player_id == GameManager.HUMAN_ID:
		request("follow", GameManager.human_player)
		request("trump", _trump_anchor())

func _on_card_played(_player_id: int, card: Card) -> void:
	if card == null:
		return
	var visual := _table_visual(card)
	if card.suit == Card.Suit.SMOKE:
		request("smoke", visual, true)
	elif card.suit == Card.Suit.ALK:
		request("alk", visual, true)
	if card.base_rank == 0:
		request("zero", visual, true)
	var tied := _tied_card(card)
	if tied != null:
		request("tie", _table_visual(tied), true)

func _on_turn_completed(_turn_index: int, winner_id: int) -> void:
	request("bierdeckel", _won_turns_anchor(winner_id))

func _on_round_started() -> void:
	if _round_number() > 1:
		request("deck", _human_deck_pile())
	var match_number := DialogueManager.upcoming_match()
	if DialogueManager.match_pays_prize(match_number):
		request("prize", get_tree().get_first_node_in_group(GameManager.PRIZE_POT_GROUP))
	if DialogueManager.match_uses_cue("show_drinks"):
		request("drinks", get_tree().get_first_node_in_group("wallet"))

func _on_round_finished(loosers) -> void:
	var ui = get_tree().get_first_node_in_group(GameManager.WON_ROUNDS_UI_GROUP)
	var target = null
	if ui != null and loosers is Array and not loosers.is_empty():
		target = ui.get_node_or_null("Player_%d/LostRounds" % loosers[0])
	request("lives", target)

func _on_match_lost(looser_id: int) -> void:
	if looser_id != GameManager.HUMAN_ID:
		request("wallet", get_tree().get_first_node_in_group("wallet"))

func _round_number() -> int:
	return DialogueManager._round

func _trump_anchor():
	var display = get_tree().get_first_node_in_group(TrumpDisplay.GROUP)
	return display.anchor() if display != null else null

func _won_turns_anchor(winner_id: int):
	var pile := CardManager.won_pile_of(Card.Owner.AI_1)
	if pile == null or pile.count <= 0:
		pile = CardManager.won_pile_of(winner_id as Card.Owner)
	if pile == null:
		return null
	return pile.coaster(0)

func _human_deck_pile():
	for pile in get_tree().get_nodes_in_group(GameManager.DECK_PILE_GROUP):
		if pile.deck_owner == Card.Owner.HUMAN:
			return pile
	return null

func _table_visual(card: Card) -> CardVisual:
	if CardManager.table_root == null:
		return null
	for child in CardManager.table_root.get_children():
		if child is CardVisual and child.card == card:
			return child
	return null

func _tied_card(card: Card) -> Card:
	var winner := CardManager.get_turn_winning_card()
	if winner == null or winner == card or winner.rank != card.rank or CardManager.get_zero_beating_nine() != null:
		return null
	if (winner.is_trump and card.is_trump) or (not winner.is_trump and not card.is_trump and winner.suit == card.suit):
		return winner
	return null

func request(key: String, target = null, urgent := false) -> void:
	if key in shown or not TIPS.has(key):
		return
	shown.append(key)
	if urgent:
		_pending.push_front([key, target])
		await get_tree().create_timer(URGENT_DELAY, false).timeout
		await DialogueManager.wait_until_idle()
		if _bubble == null:
			_show_next()
	else:
		_pending.append([key, target])
		_schedule()

func _schedule() -> void:
	if _waiting:
		return
	_waiting = true
	await get_tree().create_timer(SHOW_DELAY, false).timeout
	await DialogueManager.wait_until_idle()
	_waiting = false
	if _bubble == null:
		_show_next()

func _show_next() -> void:
	if _pending.is_empty() or _bubble != null:
		return
	if DialogueManager.is_open():
		_show_after_dialogue()
		return
	var entry: Array = _pending.pop_front()
	var tip_data: Dictionary = TIPS[entry[0]]
	_target = entry[1]
	_pause_game()
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_bubble = PointerBubble.new()
	_bubble.add_theme_stylebox_override("panel", _panel_style())
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(box)
	box.add_child(_title(tip_data.title))
	box.add_child(_body(tip_data.text.format({"min": Missions.DECK_MIN, "max": Missions.DECK_MAX}),minf(BUBBLE_WIDTH, get_viewport().get_visible_rect().size.x - 60.0)))
	box.add_child(_button())
	add_child(_bubble)
	_lift_pointer()
	_side = Side.NONE
	_bubble.modulate.a = 0.0
	await get_tree().process_frame
	if _bubble == null:
		return
	_bubble.reset_size()
	_place()
	create_tween().tween_property(_bubble, "modulate:a", 1.0, FADE_TIME)
	if DialogueManager.auto_advance:
		var bubble := _bubble
		await get_tree().create_timer(AUTO_HOLD, true).timeout
		if _bubble == bubble:
			_dismiss()

func _show_after_dialogue() -> void:
	await DialogueManager.wait_until_idle()
	if _bubble == null:
		_show_next()

func _process(_delta: float) -> void:
	if _bubble != null and _bubble.modulate.a > 0.0:
		_place()

func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var size := _bubble.size
	var rect = _target_rect()
	if rect == null:
		_side = Side.NONE
		_bubble.side = Side.NONE
		_bubble.position = ((view - size) * 0.5).round()
		return
	var order: Array = [Side.ABOVE, Side.BELOW, Side.RIGHT, Side.LEFT]
	if rect.get_center().y < view.y * 0.5:
		order = [Side.BELOW, Side.ABOVE, Side.RIGHT, Side.LEFT]
	if _side != Side.NONE and _fits(_bubble_pos(_side, rect, size), size, view):
		order.erase(_side)
		order.push_front(_side)
	var chosen: int = order[0]
	for side in order:
		if _fits(_bubble_pos(side, rect, size), size, view):
			chosen = side
			break
	_side = chosen
	var pos := _bubble_pos(chosen, rect, size)
	pos.x = clampf(pos.x, SCREEN_MARGIN, view.x - size.x - SCREEN_MARGIN)
	pos.y = clampf(pos.y, SCREEN_MARGIN, view.y - size.y - SCREEN_MARGIN)
	_bubble.position = pos.round()
	_bubble.side = chosen
	_bubble.tail_target = rect.get_center() - _bubble.position
	_bubble.queue_redraw()

func _bubble_pos(side: int, rect: Rect2, size: Vector2) -> Vector2:
	var center := rect.get_center()
	match side:
		Side.ABOVE:
			return Vector2(center.x - size.x * 0.5, rect.position.y - size.y - TAIL_GAP)
		Side.BELOW:
			return Vector2(center.x - size.x * 0.5, rect.end.y + TAIL_GAP)
		Side.RIGHT:
			return Vector2(rect.end.x + TAIL_GAP, center.y - size.y * 0.5)
		_:
			return Vector2(rect.position.x - size.x - TAIL_GAP, center.y - size.y * 0.5)

func _fits(pos: Vector2, size: Vector2, view: Vector2) -> bool:
	return pos.x >= SCREEN_MARGIN and pos.y >= SCREEN_MARGIN and pos.x + size.x <= view.x - SCREEN_MARGIN and pos.y + size.y <= view.y - SCREEN_MARGIN

func _target_rect():
	if _target == null or not is_instance_valid(_target) or not _target is CanvasItem or not _target.is_visible_in_tree():
		return null
	var xf: Transform2D = _target.get_global_transform_with_canvas()
	if _target is Control:
		var rect := Rect2(xf.origin, _target.size * xf.get_scale()).abs()
		if rect.size.x >= MIN_TARGET_SIZE and rect.size.y >= MIN_TARGET_SIZE:
			return rect
		var merged = null
		for child in _target.get_children():
			if child is Control and child.visible:
				var child_xf: Transform2D = child.get_global_transform_with_canvas()
				var child_rect := Rect2(child_xf.origin, child.size * child_xf.get_scale()).abs()
				merged = child_rect if merged == null else merged.merge(child_rect)
		if merged != null:
			return merged
	return Rect2(xf.origin - Vector2(POINT_PAD, POINT_PAD), Vector2(POINT_PAD, POINT_PAD) * 2.0)

func _dismiss() -> void:
	if _bubble == null:
		return
	_bubble.queue_free()
	_bubble = null
	_target = null
	_lower_pointer()
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	_resume_game()
	if not _pending.is_empty():
		_schedule()
	else:
		finished.emit()

func is_busy() -> bool:
	return _bubble != null or not _pending.is_empty()

func _pause_game() -> void:
	InteractionManager.cancel_press()
	_was_blocked = InteractionManager.is_table_blocked()
	InteractionManager.set_table_blocked(true)
	_paused_game = not get_tree().paused
	get_tree().paused = true

func _resume_game() -> void:
	if _paused_game:
		get_tree().paused = false
	_paused_game = false
	InteractionManager.skip_next_double_click()
	if not _was_blocked:
		InteractionManager.set_table_blocked(false)
		if DialogueManager.is_open():
			get_viewport().physics_object_picking = false

func _lift_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or not is_instance_valid(pointer) or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)

func _lower_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or not is_instance_valid(pointer) or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, mini(_pointer_index, _pointer_parent.get_child_count() - 1))
	_pointer_parent = null

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(SpeechBubble.HIGHLIGHT_COLOR))
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(18))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _body(text: String, width: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", TEXT_COLOR)
	label.add_theme_font_size_override("normal_font_size", InteractionManager.font_px(16))
	label.add_theme_font_size_override("bold_font_size", InteractionManager.font_px(16))
	label.text = text.replace("[b]", "[color=%s]" % SpeechBubble.HIGHLIGHT_COLOR).replace("[/b]", "[/color]")
	return label

func _button() -> Button:
	var button := Button.new()
	button.text = "Got it"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if InteractionManager.is_phone:
		button.custom_minimum_size = Vector2(120, 44)
	button.pressed.connect(_dismiss)
	return button

class PointerBubble extends PanelContainer:
	var tail_target := Vector2.ZERO
	var side := TutorialPopups.Side.NONE
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var anchor: Vector2
		var angle := 0.0
		match side:
			TutorialPopups.Side.ABOVE:
				anchor = Vector2(clampf(tail_target.x, 16.0, size.x - 16.0), size.y)
			TutorialPopups.Side.BELOW:
				anchor = Vector2(clampf(tail_target.x, 16.0, size.x - 16.0), 0.0)
				angle = PI
			TutorialPopups.Side.RIGHT:
				anchor = Vector2(0.0, clampf(tail_target.y, 16.0, size.y - 16.0))
				angle = PI / 2.0
			TutorialPopups.Side.LEFT:
				anchor = Vector2(size.x, clampf(tail_target.y, 16.0, size.y - 16.0))
				angle = -PI / 2.0
			_:
				return
		var color := TutorialPopups.BORDER_COLOR
		draw_set_transform(anchor, angle, Vector2.ONE)
		draw_rect(Rect2(-6, 0, 12, 6), color)
		draw_rect(Rect2(-3, 6, 6, 6), color)
		SpeechBubble.draw_arrow(self, Vector2(-5, 16), _time)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
