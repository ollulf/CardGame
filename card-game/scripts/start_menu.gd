extends CanvasLayer
class_name StartMenu

signal chosen(choice: Choice)

enum Choice { CONTINUE, NEW_RUN, SKIP_TUTORIAL }

const MENU_LAYER := 56
const FADE_TIME := 0.4
const TITLE_SIZE := 52
const STRIKE_COLOR := Color(0.86, 0.16, 0.16)
const CARD_TILTS := [-4.0, 2.5, -1.5, 3.5]
const SUIT_HERZ := preload("res://sprites/suit_Herz.png")
const SUIT_PIK := preload("res://sprites/suit_Pik.png")
const SUIT_KARO := preload("res://sprites/suit_Karo.png")
const SUIT_KREUZ := preload("res://sprites/suit_Kreuz.png")

var _hand_parent: Node
var _hand_index := 0
var _subtitle: Label
var _cards_row: HBoxContainer
var _cards: Array[MenuCard] = []
var _content: Control

func _init() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.78)
	add_child(dim)
	var center := CenterContainer.new()
	_content = center
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	box.add_child(_build_title())
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 22)
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cards_row)

func _build_title() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var struck := _title_label("Not")
	row.add_child(struck)
	var strike := ColorRect.new()
	strike.color = STRIKE_COLOR
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike.anchor_left = 0.0
	strike.anchor_right = 1.0
	strike.anchor_top = 0.52
	strike.anchor_bottom = 0.52
	strike.offset_left = -6
	strike.offset_right = 6
	strike.offset_top = -3
	strike.offset_bottom = 3
	strike.rotation_degrees = -4.0
	struck.add_child(strike)
	strike.resized.connect(func() -> void: strike.pivot_offset = strike.size / 2.0)
	row.add_child(_title_label("a game about smoking"))
	return row

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HeadlineLabel"
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	return label

func open(save: Dictionary) -> void:
	if save.is_empty():
		_subtitle.text = "New here? The tutorial teaches you the rules."
		_add_card("Start with tutorial", SUIT_HERZ, Choice.NEW_RUN, true)
		_add_card("Skip tutorial", SUIT_PIK, Choice.SKIP_TUTORIAL)
	else:
		var state: Dictionary = save.state
		var match_number: int = state.match
		if save.between_matches:
			_subtitle.text = "Saved before match %d  ·  %d$" % [match_number, state.money]
		else:
			_subtitle.text = "Saved at the start of match %d  ·  %d$" % [match_number, state.money]
		_add_card("Continue", SUIT_HERZ, Choice.CONTINUE, true)
		_add_card("New run", SUIT_KARO, Choice.NEW_RUN)
		_add_card("New run (skip tutorial)", SUIT_PIK, Choice.SKIP_TUTORIAL)
	if not OS.has_feature("web"):
		var quit := _new_card("Quit", SUIT_KREUZ)
		quit.pressed.connect(_quit)
	_fade_in()

func _add_card(text: String, suit: Texture2D, choice: Choice, primary: bool = false) -> void:
	var card := _new_card(text, suit, primary)
	card.pressed.connect(_choose.bind(choice))

func _new_card(text: String, suit: Texture2D, primary: bool = false) -> MenuCard:
	var card := MenuCard.new()
	card.setup(text, suit, primary, CARD_TILTS[_cards.size() % CARD_TILTS.size()])
	_cards_row.add_child(card)
	_cards.append(card)
	return card

func _fade_in() -> void:
	_lift_hand_pointer()
	show()
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, FADE_TIME)

func _disable_cards() -> void:
	for card in _cards:
		card.set_disabled(true)

func _choose(choice: Choice) -> void:
	_disable_cards()
	_lower_hand_pointer()
	InteractionManager.skip_next_double_click()
	chosen.emit(choice)
	queue_free()

func _quit() -> void:
	_disable_cards()
	get_tree().quit()

func _lift_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or hand.get_parent() == self:
		return
	_hand_parent = hand.get_parent()
	_hand_index = hand.get_index()
	hand.reparent(self)

func _lower_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or _hand_parent == null or hand.get_parent() != self:
		return
	hand.reparent(_hand_parent)
	_hand_parent.move_child(hand, _hand_index)
