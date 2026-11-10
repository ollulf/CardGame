extends CanvasLayer
class_name TutorialPopups

enum Mode { DIALOGUE, POINTER, CARD, SIDE }

const MODE_NAMES := ["Off", "A Pointer", "B Card", "C Side tip"]
const POPUP_LAYER := 105
const SHOW_DELAY := 0.45
const FADE_TIME := 0.15
const BG_COLOR := Color(0.121569, 0.117647, 0.14902, 1)
const BORDER_COLOR := Color("3d3854")
const TEXT_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const DIM_COLOR := Color(0.03, 0.03, 0.05, 0.6)
const POINTER_WIDTH := 270.0
const CARD_WIDTH := 340.0
const SIDE_WIDTH := 300.0
const SIDE_TOP := 10.0
const SIDE_MARGIN := 12.0
const SIDE_HOLD := 7.0
const SLIDE_TIME := 0.25
const TAIL_GAP := 18.0
const MINI_CARD_SIZE := Vector2(60, 90)
const RULES_BUTTON_CENTER := Vector2(34, 34)
const TRUMP_POINT_Y := 75.0
const HAND_POINT_Y := 170.0

const TIPS := {
	"follow": {
		"title": "Your turn",
		"text": "Play one card. The [b]highest card[/b] of the [b]first suit played[/b] wins the turn.",
		"target": "hand",
		"art": [[Card.Suit.CLUBS, 4, false], "<", [Card.Suit.CLUBS, 8, false]],
	},
	"trump": {
		"title": "Trump",
		"text": "[b]Trump[/b] beats every other suit. Others must [b]follow suit[/b] if they can.",
		"target": "trump",
		"art": [[Card.Suit.SPADES, 9, false], "<", [Card.Suit.HEARTS, 2, true]],
	},
	"bierdeckel": {
		"title": "Won turns",
		"text": "Each won turn gives a [b]Bierdeckel[/b]. After [b]5 turns[/b], the fewest loses the round.",
		"target": "won",
		"art": [],
	},
	"lives": {
		"title": "Lost a round",
		"text": "The loser rips a [b]life card[/b]. Lose [b]2 rounds[/b] and you are out.",
		"target": "table",
		"art": [],
	},
	"smoke": {
		"title": "Smoking cards",
		"text": "[b]Smoking cards[/b] are always trump. Each cigarette smoked: [b]+1[/b] this round.",
		"target": "table",
		"art": [[Card.Suit.CLUBS, 9, false], "<", [Card.Suit.SMOKE, 2, true]],
	},
	"zero": {
		"title": "Zero",
		"text": "A [b]0[/b] beats a [b]9[/b] of the [b]same suit[/b].",
		"target": "table",
		"art": [[Card.Suit.SPADES, 9, false], "<", [Card.Suit.SPADES, 0, false]],
	},
}

const CUT_LINES := [
	"Your goal is to have the *highest card*, after everybody played *one card*.",
	"I have to *follow* your *played suit* if I have a card on my hand with that *suit.*",
	"If I don't have it, my other cards of a *different suit* are *worthless*.",
	"That means the *highest* card of the *first played suit* wins the turn.",
	"... unless ...",
	"Unless it's of the *trump color*, that is *always higher*, right?",
	"But the *trump* is picked *at random* for every match and stays the same for the whole match.",
	"Yes.",
	"But in that case, the *highest trump* card *wins*.",
	"Since *hearts* is *trump* for this match, it's the *highest*.",
	"And if I have the *first played suit*, I have to play that.",
	"For winning the turn I get a *Bierdeckel* from the stack next to the *ashtray*.",
	"The *Bierdeckel* show how many *turns* each of us *won* this round. The played cards go to our *discard piles*.",
	"After we played *5* turns, the players with the *least* won *turns* loses the round.",
	"Since, I played *hearts* now, and it's *trump* everybody who has trump, has to *play trump* now too.",
	"I don't have *hearts*, so I have to play something different.",
	"If I lose one more time I *lose* the whole *game*.",
	"It basically is *always* a *trump* card.",
	"But if *YOU* would play a *higher hearts* trump card now, *YOU* would win this turn.",
	"See that *0*? Those are in our decks now. A *0* beats a *9* of the *same suit*.",
	"Hehe, exactly! A *trump 0* beats a *trump 9*, but a *hearts 0* cannot beat a *smoking 9*.",
	"And a drink can't make a *0*, so keep that in mind too.",
]

static var mode := Mode.DIALOGUE

var _shown: Array[String] = []
var _pending: Array[String] = []
var _popup: Control
var _blocker: Control
var _was_blocked := false
var _paused_game := false
var _side_token := 0
var _last_winner := 0

static func is_active() -> bool:
	return mode != Mode.DIALOGUE

static func cuts_line(text: String) -> bool:
	return is_active() and CUT_LINES.has(text)

static func next_mode() -> void:
	mode = ((mode + 1) % MODE_NAMES.size()) as Mode

static func mode_name() -> String:
	return MODE_NAMES[mode]

func _init() -> void:
	layer = POPUP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.round_finished.connect(_on_round_finished)
	CardManager.card_played.connect(_on_card_played)

func _on_request_play_card(player_id: int) -> void:
	if player_id == GameManager.HUMAN_ID and DialogueManager.upcoming_match() == 1:
		request("follow")

func _on_card_played(player_id: int, card: Card) -> void:
	if card == null:
		return
	if card.suit == Card.Suit.SMOKE:
		request("smoke")
	elif card.is_trump and player_id != GameManager.HUMAN_ID:
		request("trump")
	if card.base_rank == 0:
		request("zero")

func _on_turn_completed(_turn_index: int, winner_id: int) -> void:
	_last_winner = winner_id
	request("bierdeckel")

func _on_round_finished(_loosers) -> void:
	request("lives")

func request(key: String) -> void:
	if not is_active() or key in _shown or not TIPS.has(key):
		return
	_shown.append(key)
	_pending.append(key)
	if _pending.size() == 1 and _popup == null:
		await get_tree().create_timer(SHOW_DELAY, false).timeout
		await DialogueManager.wait_until_idle()
		_show_next()

func show_now(key: String) -> void:
	_shown.append(key)
	_pending.append(key)
	if _popup == null:
		_show_next()

func _show_next() -> void:
	if _pending.is_empty() or _popup != null or not is_active():
		return
	var key: String = _pending.pop_front()
	var tip: Dictionary = TIPS[key]
	match mode:
		Mode.POINTER:
			_show_pointer(tip)
		Mode.CARD:
			_show_card(tip)
		Mode.SIDE:
			_show_side(tip)

func _pause_game() -> void:
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

func _add_blocker(dim: bool) -> void:
	if dim:
		var rect := ColorRect.new()
		rect.color = DIM_COLOR
		_blocker = rect
	else:
		_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

func _dismiss() -> void:
	if _popup == null:
		return
	var popup := _popup
	_popup = null
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	popup.queue_free()
	_resume_game()
	if not _pending.is_empty():
		_show_next.call_deferred()

func _panel_style(border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(border)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _title(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(SpeechBubble.HIGHLIGHT_COLOR))
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _body(text: String, width: float, size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", TEXT_COLOR)
	label.add_theme_font_size_override("normal_font_size", InteractionManager.font_px(size))
	label.add_theme_font_size_override("bold_font_size", InteractionManager.font_px(size))
	label.text = text.replace("[b]", "[color=%s]" % SpeechBubble.HIGHLIGHT_COLOR).replace("[/b]", "[/color]")
	return label

func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		button.theme_type_variation = &"ButtonPrimary"
	button.size_flags_horizontal = Control.SIZE_SHRINK_END if not primary else Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_dismiss)
	return button

func _target_point(target: String) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	match target:
		"trump":
			return Vector2(view.x * 0.5 + MINI_CARD_SIZE.x * 0.5, TRUMP_POINT_Y)
		"hand":
			return Vector2(view.x * 0.5, view.y - HAND_POINT_Y)
		"won":
			var pile := CardManager.won_pile_of(_last_winner as Card.Owner)
			if pile != null:
				return pile.global_position
	return CardManager._get_table_center_world() + Vector2(MINI_CARD_SIZE.x, 0)

func _show_pointer(tip: Dictionary) -> void:
	_pause_game()
	_add_blocker(false)
	var bubble := PointerBubble.new()
	bubble.add_theme_stylebox_override("panel", _panel_style(3))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(box)
	box.add_child(_title(tip.title, 18))
	box.add_child(_body(tip.text, POINTER_WIDTH, 16))
	box.add_child(_button("Got it", false))
	_popup = bubble
	add_child(bubble)
	var point := _target_point(tip.target)
	bubble.tail_down = tip.target == "hand"
	await get_tree().process_frame
	if _popup != bubble:
		return
	bubble.reset_size()
	var view := get_viewport().get_visible_rect().size
	var pos: Vector2
	if bubble.tail_down:
		pos = Vector2(point.x - bubble.size.x * 0.5, point.y - bubble.size.y - TAIL_GAP)
	else:
		pos = Vector2(point.x + TAIL_GAP, point.y - bubble.size.y * 0.5)
	pos.x = clampf(pos.x, 8.0, view.x - bubble.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, view.y - bubble.size.y - 8.0)
	bubble.position = pos.round()
	bubble.tail_target = point - bubble.position
	bubble.queue_redraw()
	_fade_in(bubble)

func _show_card(tip: Dictionary) -> void:
	_pause_game()
	_add_blocker(true)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(4))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _title(tip.title, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if not tip.art.is_empty():
		box.add_child(_art_row(tip.art))
	var body := _body(tip.text, CARD_WIDTH, 18)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var button := _button("Got it", true)
	button.custom_minimum_size = Vector2(180, 40)
	box.add_child(button)
	_popup = center
	add_child(center)
	_fade_in(panel)

func _art_row(art: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in art:
		if item is Array:
			var card := Card.new(item[0], item[1], Card.Owner.NONE, false)
			var visual := TrumpDisplay.CARD_SCENE.instantiate() as CardVisual
			row.add_child(visual)
			visual.setup(card, false)
			visual.hover_enabled = false
			visual.z_index = 1
			visual.get_node("PlayableOutline").visible = true
			_ignore_mouse(visual)
		else:
			var sign_label := _title(str(item), 30)
			sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(sign_label)
	return row

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _show_side(tip: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(3))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var title := _title("TIP  " + tip.title, 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	box.add_child(_body(tip.text, SIDE_WIDTH, 15))
	var hint := Label.new()
	hint.text = "Tap to file under ?"
	hint.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.55))
	hint.add_theme_font_size_override("font_size", InteractionManager.font_px(12))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)
	_popup = panel
	add_child(panel)
	panel.gui_input.connect(_on_side_input)
	await get_tree().process_frame
	if _popup != panel:
		return
	panel.reset_size()
	var view := get_viewport().get_visible_rect().size
	var shown_x := view.x - panel.size.x - SIDE_MARGIN
	panel.position = Vector2(view.x + 4.0, SIDE_TOP)
	var tween := create_tween()
	tween.tween_property(panel, "position:x", shown_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_side_token += 1
	var token := _side_token
	await get_tree().create_timer(SIDE_HOLD, true).timeout
	if token == _side_token and _popup == panel:
		_file_side(false)

func _on_side_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_file_side(true)

func _file_side(to_rules: bool) -> void:
	var panel := _popup
	if panel == null:
		return
	_popup = null
	_side_token += 1
	var tween := create_tween().set_parallel()
	if to_rules:
		panel.pivot_offset = Vector2.ZERO
		tween.tween_property(panel, "position", RULES_BUTTON_CENTER, SLIDE_TIME * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "scale", Vector2(0.08, 0.08), SLIDE_TIME * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		var view := get_viewport().get_visible_rect().size
		tween.tween_property(panel, "position:x", view.x + 4.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(panel.queue_free)
	if not _pending.is_empty():
		_show_next.call_deferred()

func _fade_in(node: Control) -> void:
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, FADE_TIME)

class PointerBubble extends PanelContainer:
	var tail_target := Vector2.ZERO
	var tail_down := false
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var color := TutorialPopups.BORDER_COLOR
		if tail_down:
			var x := clampf(tail_target.x, 16.0, size.x - 16.0)
			draw_rect(Rect2(x - 6, size.y, 12, 6), color)
			draw_rect(Rect2(x - 3, size.y + 6, 6, 6), color)
			SpeechBubble.draw_arrow(self, Vector2(x - 5, size.y + 16), _time)
		else:
			var y := clampf(tail_target.y, 16.0, size.y - 16.0)
			draw_rect(Rect2(-6, y - 6, 6, 12), color)
			draw_rect(Rect2(-12, y - 3, 6, 6), color)
			draw_set_transform(Vector2(-16, y), PI / 2.0, Vector2.ONE)
			SpeechBubble.draw_arrow(self, Vector2(-5, -2), _time)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
