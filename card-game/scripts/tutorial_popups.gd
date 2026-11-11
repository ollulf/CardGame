extends CanvasLayer
class_name TutorialPopups

signal finished

enum Side { ABOVE, BELOW, RIGHT, LEFT, NONE }

const POPUP_LAYER := 115
const SHOW_DELAY := 0.45
const URGENT_DELAY := 0.35
const AUTO_HOLD := 2.5
const BUBBLE_WIDTH := 270.0
const SCREEN_MARGIN := 8.0
const TAIL_GAP := 30.0
const POINT_PAD := 36.0
const MIN_TARGET_SIZE := 4.0
const BASIC_TIPS := ["follow", "trump", "enemy_suits", "bierdeckel", "deck", "lives", "boosters"]

const DEFAULT_TIPS := {
	"follow": {
		"title": "Your turn",
		"text": "Play one card. The [b]highest card[/b] of the [b]first suit played[/b] takes the trick. The other players must [b]follow the first suit[/b] if they can.",
	},
	"trump": {
		"title": "Trump",
		"text": "[b]Trump[/b] beats every other suit. It is shown at the top and picked [b]at random[/b] each match.",
	},
	"enemy_suits": {
		"title": "Their cards",
		"text": "You can see the [b]suit[/b] on the back of every card your opponents hold. Use it to guess who can [b]follow[/b] and who has [b]trump[/b].",
	},
	"bierdeckel": {
		"title": "Won tricks",
		"text": "Each trick you take gives a [b]Bierdeckel[/b]. After [b]5 tricks[/b], whoever has the fewest loses the round.",
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
		"text": "[b]Smoking cards[/b] are always [b]trump[/b]. Each *cigarette* smoked gives them [b]+1[/b] this round. No limit.",
	},
	"tie": {
		"title": "Equal cards",
		"text": "When two cards are [b]equal[/b], the one played [b]first[/b] wins.",
	},
	"tiebreak": {
		"title": "Tie-break",
		"text": "Tied for fewest tricks? Each tied player draws a card. The [b]lowest number[/b] loses; suit and [b]trump[/b] don't count.",
	},
	"prize": {
		"title": "Prize money",
		"text": "The last loser pays the [b]prize[/b]. The [b]two winners[/b] of this match split it.",
	},
	"cigs": {
		"title": "Cigarettes",
		"text": "Tap your [b]pack[/b] to take a *cigarette*, then the [b]lighter[/b] to smoke it.",
	},
	"wallet": {
		"title": "Your money",
		"text": "Winners share the [b]prize money[/b]. Spend it at the [b]bar[/b] on [b]boosters[/b] with new cards. More opens up later.",
	},
	"boosters": {
		"title": "Boosters",
		"text": "A [b]booster[/b] is a pack of new cards. Buy one, rip it open, and the cards go into your [b]collection[/b]. Hover a pack to see what's inside.",
	},
	"deck_size": {
		"title": "Your deck",
		"text": "A deck needs [b]{min} to {max} cards[/b]. Tap cards to move them in or out.",
	},
	"drinks": {
		"title": "Round of drinks",
		"text": "At the bar a [b]round of drinks[/b] costs [b]{drink_price}$[/b]. Everyone drinks: drinking cards [b]+1[/b], all others [b]-1[/b] for the match.",
	},
	"stamps": {
		"title": "Stamps",
		"text": "A [b]stamp[/b] changes one card [b]for good[/b]. Buy one, then pick the card. Each card takes one stamp, specials too.",
	},
	"alk": {
		"title": "Drinking cards",
		"text": "[b]Drinking cards[/b] are always [b]trump[/b] and get [b]+1[/b] for every drink.",
	},
}

const TEXTS_PATH := "res://tutorial_popups.yaml"
const ARROW_ROOM := 4.0
const CONTINUE_ARROW_INSET := Vector2(20, 16)

static var _loaded := false
static var _file_tips := {}

static func reload_texts() -> void:
	_loaded = true
	_file_tips = {}
	var yaml := YamlLite.parse_file(TEXTS_PATH, ["id"])
	if yaml.data.is_empty():
		push_warning("TutorialPopups: no usable texts in %s, using built-in texts" % TEXTS_PATH)
		return
	for entry in yaml.data:
		if not entry is Dictionary or not entry.get("id") is String or not DEFAULT_TIPS.has(entry.id):
			push_warning("TutorialPopups: ignoring a tip entry without a known 'id' in %s" % TEXTS_PATH)
			continue
		var tip_data: Dictionary = DEFAULT_TIPS[entry.id].duplicate()
		for field in ["title", "text"]:
			if entry.get(field) is String and entry[field] != "":
				tip_data[field] = entry[field]
			else:
				push_warning("TutorialPopups: tip '%s' has no '%s' in %s, using the built-in one" % [entry.id, field, TEXTS_PATH])
		_file_tips[entry.id] = tip_data
	for key in DEFAULT_TIPS:
		if not _file_tips.has(key):
			push_warning("TutorialPopups: tip '%s' is missing in %s, using the built-in text" % [key, TEXTS_PATH])

static func tip_texts(key: String) -> Dictionary:
	if not _loaded:
		reload_texts()
	return _file_tips.get(key, DEFAULT_TIPS[key])

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
var _press_seen := false

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
			if key is String and DEFAULT_TIPS.has(key) and not key in shown:
				shown.append(key)

func _init() -> void:
	layer = POPUP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	_loaded = false

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
		request("enemy_suits", _enemy_hand_anchor())

func _on_card_played(_player_id: int, card: Card) -> void:
	if card == null:
		return
	var visual := _table_visual(card)
	if card.suit == Card.Suit.SMOKE:
		request("smoke", visual, true)
	elif card.suit == Card.Suit.ALK:
		request("alk", visual, true)
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

func _enemy_hand_anchor():
	var ai := GameManager.ai_player_1 as AIPlayer
	if ai == null or ai.card_visuals.is_empty():
		return null
	return ai.card_visuals[ai.card_visuals.size() / 2]

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
	if winner == null or winner == card or winner.rank != card.rank:
		return null
	if (winner.is_trump and card.is_trump) or (not winner.is_trump and not card.is_trump and winner.suit == card.suit):
		return winner
	return null

func request(key: String, target = null, urgent := false) -> void:
	if key in shown or not DEFAULT_TIPS.has(key):
		return
	shown.append(key)
	if urgent:
		_pending.push_front([key, target])
		await get_tree().create_timer(URGENT_DELAY, get_tree().paused).timeout
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
	await get_tree().create_timer(SHOW_DELAY, get_tree().paused).timeout
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
	var tip_data: Dictionary = tip_texts(entry[0])
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
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(box)
	box.add_child(_title(tip_data.title.replace("{player}", GameManager.player_name(GameManager.HUMAN_ID))))
	box.add_child(_body(tip_data.text.replace("{player}", GameManager.player_name(GameManager.HUMAN_ID)).format({"min": Missions.DECK_MIN, "max": Missions.DECK_MAX, "drink_price": PlayerDataManager.DRINK_ROUND_PRICE}), minf(BUBBLE_WIDTH, get_viewport().get_visible_rect().size.x - 60.0)))
	var arrow_room := Control.new()
	arrow_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_room.custom_minimum_size = Vector2(0, ARROW_ROOM)
	box.add_child(arrow_room)
	_press_seen = false
	add_child(_bubble)
	_lift_pointer()
	_side = Side.NONE
	_bubble.modulate.a = 0.0
	await get_tree().process_frame
	if _bubble == null:
		return
	_bubble.reset_size()
	_place()
	_bubble.modulate.a = 1.0
	Sfx.play_popup()
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
	return ShopTooltip.outer_style()

func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(ShopTooltip.TITLE_FONT_SIZE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _body(text: String, width: float) -> PanelContainer:
	var inner := PanelContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ShopTooltip.inner_style()
	inner.add_theme_stylebox_override("panel", style)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width - style.get_minimum_size().x, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", ShopTooltip.TEXT)
	label.add_theme_font_size_override("normal_font_size", InteractionManager.font_px(ShopTooltip.BODY_FONT_SIZE))
	label.add_theme_font_size_override("bold_font_size", InteractionManager.font_px(ShopTooltip.BODY_FONT_SIZE))
	label.text = highlight(text)
	inner.add_child(label)
	return inner


static func highlight(text: String) -> String:
	var pattern := RegEx.create_from_string("\\[b\\](.*?)\\[/b\\]|\\*([^*]+)\\*|\\bspecial(?: cards?)?\\b")
	var result := ""
	var last := 0
	for found in pattern.search_all(text):
		result += text.substr(last, found.get_start() - last)
		var inner := found.get_string(0)
		if found.get_start(1) >= 0:
			inner = found.get_string(1)
		elif found.get_start(2) >= 0:
			inner = found.get_string(2)
		var color := "#" + ShopTooltip.SPECIAL if "special" in inner.to_lower() else SpeechBubble.HIGHLIGHT_COLOR
		result += SpeechBubble.keyword(inner, color)
		last = found.get_end()
	return result + text.substr(last)

func _input(event: InputEvent) -> void:
	if _bubble == null or _overlay_open():
		return
	if event.is_action_pressed("ui_accept", false, true):
		get_viewport().set_input_as_handled()
		if _bubble.modulate.a > 0.0:
			_dismiss()
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	get_viewport().set_input_as_handled()
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_seen = true
	elif _press_seen and _bubble.modulate.a > 0.0:
		_dismiss()

func _overlay_open() -> bool:
	if PauseMenu.is_open():
		return true
	var debug := get_tree().get_first_node_in_group(DebugMenu.GROUP)
	return debug != null and debug.visible

class PointerBubble extends PanelContainer:
	var tail_target := Vector2.ZERO
	var side := TutorialPopups.Side.NONE
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		SpeechBubble.draw_arrow(self, size - TutorialPopups.CONTINUE_ARROW_INSET, _time)
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
		var color := ShopTooltip.EDGE
		draw_set_transform(anchor, angle, Vector2.ONE)
		draw_rect(Rect2(-6, 0, 12, 6), color)
		draw_rect(Rect2(-3, 6, 6, 6), color)
		SpeechBubble.draw_arrow(self, Vector2(-5, 16), _time)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
