extends CanvasLayer

const OWNER_TITLES := {
	Card.Owner.HUMAN: "Your deck",
	Card.Owner.AI_1: "Left player's deck",
	Card.Owner.AI_2: "Right player's deck",
}

const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARD_SCALE := 0.75
const USED_ALPHA := 0.3
const LEFT_RECT := Rect2(16, 16, 210, 616)
const RIGHT_RECT := Rect2(236, 16, 900, 616)

@export var pointer: Control

var _root: Control
var _deck_head: Label
var _rows: VBoxContainer
var _left_count: Label
var _trump_icon: TextureRect
var _trump_name: Label
var _pointer_parent: Node
var _pointer_index: int
var _trump_known := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	CardManager.trump_chosen.connect(_on_trump_chosen)
	_build_backdrop()
	_build_frame()
	hide()

func _build_backdrop():
	var backdrop := ColorRect.new()
	backdrop.color = Color(DeckBuilder.BG_COLOR, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	move_child(backdrop, 0)

func _build_frame():
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var title_box := _panel(Rect2(LEFT_RECT.position, Vector2(LEFT_RECT.size.x, 56)))
	var title := _label("Deck", 34, DeckBuilder.FG_COLOR)
	title.position = Vector2(14, 6)
	title_box.add_child(title)

	var info_box := _panel(Rect2(LEFT_RECT.position + Vector2(0, 66), Vector2(LEFT_RECT.size.x, LEFT_RECT.size.y - 132)))
	var info := VBoxContainer.new()
	info.position = Vector2(12, 10)
	info.size = info_box.size - Vector2(24, 20)
	info.add_theme_constant_override("separation", 8)
	info_box.add_child(info)
	var count_line := HBoxContainer.new()
	count_line.add_theme_constant_override("separation", 6)
	info.add_child(count_line)
	_left_count = _label("", 40, DeckBuilder.FG_COLOR)
	count_line.add_child(_left_count)
	var left_text := _label("left in deck", 13, DeckBuilder.MUTED_COLOR)
	left_text.size_flags_vertical = Control.SIZE_SHRINK_END
	count_line.add_child(left_text)
	var trump_line := HBoxContainer.new()
	trump_line.add_theme_constant_override("separation", 6)
	info.add_child(trump_line)
	trump_line.add_child(_label("Trump", 13, DeckBuilder.FG_COLOR))
	_trump_icon = _suit_icon(null, 14)
	trump_line.add_child(_trump_icon)
	_trump_name = _label("", 13, DeckBuilder.ACCENT_COLOR)
	trump_line.add_child(_trump_name)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.position = Vector2(LEFT_RECT.position.x, LEFT_RECT.end.y - 56)
	close_button.size = Vector2(LEFT_RECT.size.x, 56)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_stylebox_override("normal", _box(DeckBuilder.PANEL_COLOR_2, DeckBuilder.LINE_COLOR))
	close_button.add_theme_stylebox_override("hover", _box(DeckBuilder.PANEL_COLOR_2, DeckBuilder.ACCENT_COLOR))
	close_button.add_theme_stylebox_override("pressed", _box(DeckBuilder.PANEL_COLOR, DeckBuilder.ACCENT_COLOR))
	close_button.add_theme_color_override("font_color", DeckBuilder.FG_COLOR)
	close_button.add_theme_color_override("font_hover_color", DeckBuilder.ACCENT_COLOR)
	close_button.pressed.connect(close)
	_root.add_child(close_button)

	var cards_box := _panel(RIGHT_RECT)
	_deck_head = _label("", 16, DeckBuilder.FG_COLOR)
	_deck_head.position = Vector2(12, 6)
	cards_box.add_child(_deck_head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 34)
	scroll.size = cards_box.size - Vector2(24, 44)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _box(DeckBuilder.PANEL_COLOR, DeckBuilder.LINE_COLOR))
	_root.add_child(panel)
	return panel

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(4)
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _suit_icon(texture: Texture2D, icon_size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _process(_delta):
	if Input.is_action_just_released("togge_deck_visualizer"):
		if visible:
			close()
		else:
			open_for_owner(Card.Owner.HUMAN)
	elif visible and Input.is_action_just_pressed("ui_cancel"):
		close()

func _on_trump_chosen(_suit: Card.Suit):
	_trump_known = true

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func open_for_owner(owner: Card.Owner):
	if owner != Card.Owner.HUMAN:
		return
	var deck := _deck_of(owner)
	if deck == null or DialogueManager.is_open() or InteractionManager.is_table_blocked():
		return
	if visible:
		hide_deck()
	visualize_deck(deck, owner)

func toggle_for_owner(owner: Card.Owner):
	if visible:
		close()
	else:
		open_for_owner(owner)

func close():
	if not visible:
		return
	hide_deck()
	hide()
	_release_pointer()
	InteractionManager.skip_next_double_click()
	get_tree().paused = false

func _deck_of(owner: Card.Owner) -> Deck:
	match owner:
		Card.Owner.HUMAN:
			return CardManager.player_deck
		Card.Owner.AI_1:
			return CardManager.AI_1_deck
		Card.Owner.AI_2:
			return CardManager.AI_2_deck
	return null

func _grab_pointer():
	if pointer == null or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)

func _release_pointer():
	if pointer == null or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)

func hide_deck():
	for child in _rows.get_children():
		child.queue_free()

func visualize_deck(deck: Deck, owner : Card.Owner):
	var all_cards: Array[Card] = deck.all_cards.duplicate()
	for card in deck.cards:
		if not all_cards.has(card):
			all_cards.append(card)
	var trump := CardManager.trump_suit
	for suit in DeckBuilder.SUIT_ORDER:
		var cards := all_cards.filter(func(c: Card) -> bool: return c.suit == suit)
		if cards.is_empty():
			continue
		cards.sort_custom(func(a: Card, b: Card) -> bool: return a.base_rank > b.base_rank)
		_rows.add_child(_suit_row(suit, cards, deck, _trump_known and suit == trump))

	_deck_head.text = OWNER_TITLES.get(owner, "Deck")
	_left_count.text = str(deck.cards.size())
	_trump_icon.visible = _trump_known
	_trump_icon.texture = DeckBuilder.SUIT_TEXTURES.get(trump)
	_trump_name.text = DeckBuilder.SUIT_NAMES.get(trump, "") if _trump_known else "not picked yet"
	InteractionManager.cancel_press()
	get_tree().paused = true
	_grab_pointer()
	show()

func _suit_row(suit: Card.Suit, cards: Array, deck: Deck, is_trump: bool) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if is_trump:
		style.bg_color = Color(DeckBuilder.ACCENT_COLOR, 0.1)
		style.border_color = Color(DeckBuilder.ACCENT_COLOR, 0.45)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0, 0, 0, 0)
	frame.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, DeckBuilder.CARD_SIZE.y * CARD_SCALE)
	frame.add_child(row)
	row.add_child(_suit_icon(DeckBuilder.SUIT_TEXTURES.get(suit), 18))
	if cards.is_empty():
		var none := _label("none", 12, DeckBuilder.MUTED_COLOR)
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(none)
	var hand := CardManager.hand_of(0)
	for card in cards:
		var in_hand: bool = hand != null and hand.cards.has(card)
		row.add_child(_card_cell(card, not deck.cards.has(card) and not in_hand, is_trump, in_hand))
	return frame

func _card_cell(card: Card, used: bool, is_trump: bool, in_hand: bool = false) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = DeckBuilder.CARD_SIZE * CARD_SCALE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = cell.custom_minimum_size
	var face_style := _box(DeckBuilder.PANEL_COLOR_2, DeckBuilder.ACCENT_COLOR if is_trump else DeckBuilder.LINE_COLOR)
	face_style.set_border_width_all(1)
	face.add_theme_stylebox_override("panel", face_style)
	cell.add_child(face)
	var visual: CardVisual = CARD_SCENE.instantiate()
	_ignore_mouse(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	visual.size = DeckBuilder.CARD_SIZE
	visual.pivot_offset = Vector2.ZERO
	visual.hover_enabled = false
	cell.add_child(visual)
	visual.setup(card, false)
	visual.scale = Vector2.ONE * CARD_SCALE
	visual.position = Vector2.ZERO
	if in_hand:
		var glow := _box(Color(0, 0, 0, 0), Color("#ffcf6e"))
		glow.set_border_width_all(3)
		glow.shadow_color = Color(1, 0.81, 0.43, 0.6)
		glow.shadow_size = 6
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.size = cell.custom_minimum_size
		ring.add_theme_stylebox_override("panel", glow)
		cell.add_child(ring)
		var tag := _label("IN HAND", 10, Color("#1b1b1b"))
		tag.position = Vector2(4, cell.custom_minimum_size.y - 18)
		tag.add_theme_stylebox_override("normal", _box(Color("#ffcf6e"), Color("#ffcf6e")))
		cell.add_child(tag)
	if used:
		cell.modulate = Color(1, 1, 1, USED_ALPHA)
	return cell

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
