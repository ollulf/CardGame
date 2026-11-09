extends Control
class_name DeckBuilder

signal closed

const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARD_SIZE := Vector2(60, 90)
const DECK_CARD_SCALE := 0.6
const COLLECTION_CARD_SCALE := 0.62
const SUIT_ORDER: Array[Card.Suit] = [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.SPADES, Card.Suit.CLUBS, Card.Suit.ALK, Card.Suit.SMOKE]
const SUIT_NAMES := {
	Card.Suit.DIAMONDS: "Diamonds",
	Card.Suit.HEARTS: "Hearts",
	Card.Suit.SPADES: "Spades",
	Card.Suit.CLUBS: "Clubs",
	Card.Suit.ALK: "Alk",
	Card.Suit.SMOKE: "Smoke",
}
const SUIT_TEXTURES := {
	Card.Suit.DIAMONDS: preload("res://sprites/suit_Karo.png"),
	Card.Suit.HEARTS: preload("res://sprites/suit_Herz.png"),
	Card.Suit.SPADES: preload("res://sprites/suit_Pik.png"),
	Card.Suit.CLUBS: preload("res://sprites/suit_Kreuz.png"),
	Card.Suit.ALK: preload("res://sprites/suit_Alk.png"),
	Card.Suit.SMOKE: preload("res://sprites/suit_Smoke.png"),
}

const BG_COLOR := Color("121117")
const PANEL_COLOR := Color("17161c")
const PANEL_COLOR_2 := Color("24222d")
const LINE_COLOR := Color("6b6390")
const FG_COLOR := Color("ffffff")
const MUTED_COLOR := Color("d6d1e6")
const ACCENT_COLOR := Color("ffcf6e")
const NEW_COLOR := Color("7ed2a0")
const WARN_COLOR := Color("e5735e")

const LEFT_RECT := Rect2(16, 16, 210, 616)
const RIGHT_RECT := Rect2(236, 16, 900, 616)

var _deck_row: HBoxContainer
var _deck_counter: Label
var _rows: VBoxContainer
var _card_info: Label
var _stats: Label
var _close_button: Button
var _pending_rebuild := false
var _deck_cells := {}
var _stack_cells := {}
var _flights: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	PlayerDataManager.deck_changed.connect(_queue_rebuild)
	PlayerDataManager.collection_changed.connect(_queue_rebuild)
	hide()


func open() -> void:
	if not PlayerDataManager.has_active_deck() and CardManager.player_deck != null:
		PlayerDataManager.init_active_deck(CardManager.player_deck.cards)
	_rebuild()
	_show_card(null)
	show()


func try_close() -> bool:
	if not visible or not PlayerDataManager.has_active_deck():
		return false
	PlayerDataManager.clear_new_cards()
	hide()
	closed.emit()
	return true


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		try_close()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(BG_COLOR, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title_box := _panel(Rect2(LEFT_RECT.position, Vector2(LEFT_RECT.size.x, 56)))
	var title := HeadlineLabel.new()
	title.text = "Deck"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(14, 8)
	title_box.add_child(title)

	var info_box := _panel(Rect2(LEFT_RECT.position + Vector2(0, 66), Vector2(LEFT_RECT.size.x, LEFT_RECT.size.y - 132)))
	var info := VBoxContainer.new()
	info.position = Vector2(12, 10)
	info.size = info_box.size - Vector2(24, 20)
	info.add_theme_constant_override("separation", 14)
	info_box.add_child(info)
	_card_info = _label("", 14, FG_COLOR)
	_card_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_info.custom_minimum_size = Vector2(info.size.x, 0)
	info.add_child(_card_info)
	_stats = _label("", 13, MUTED_COLOR)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(info.size.x, 0)
	info.add_child(_stats)

	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.position = Vector2(LEFT_RECT.position.x, LEFT_RECT.end.y - 56)
	_close_button.size = Vector2(LEFT_RECT.size.x, 56)
	_close_button.add_theme_color_override("font_disabled_color", WARN_COLOR)
	_close_button.pressed.connect(try_close)
	add_child(_close_button)

	var deck_height := CARD_SIZE.y * DECK_CARD_SCALE + 48
	var deck_box := _panel(Rect2(RIGHT_RECT.position, Vector2(RIGHT_RECT.size.x, deck_height)))
	var deck_head := HBoxContainer.new()
	deck_head.position = Vector2(12, 6)
	deck_head.add_theme_constant_override("separation", 10)
	deck_box.add_child(deck_head)
	deck_head.add_child(_label("Your deck", 16, FG_COLOR))
	_deck_counter = _label("", 14, WARN_COLOR)
	deck_head.add_child(_deck_counter)
	_deck_row = HBoxContainer.new()
	_deck_row.position = Vector2(12, 34)
	_deck_row.add_theme_constant_override("separation", 4)
	deck_box.add_child(_deck_row)

	var cards_top := RIGHT_RECT.position.y + deck_height + 10
	var cards_box := _panel(Rect2(RIGHT_RECT.position.x, cards_top, RIGHT_RECT.size.x, RIGHT_RECT.end.y - cards_top))
	var cards_head := _label("Your cards", 16, FG_COLOR)
	cards_head.position = Vector2(12, 6)
	cards_box.add_child(cards_head)
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
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, LINE_COLOR))
	add_child(panel)
	return panel


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(2)
	style.border_color = border
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _queue_rebuild() -> void:
	if _pending_rebuild or not visible:
		return
	_pending_rebuild = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending_rebuild = false
	_deck_cells.clear()
	_stack_cells.clear()
	_rebuild_deck()
	_rebuild_collection()
	_update_stats()
	_hide_flight_targets()


func _flight_target(flight: Dictionary) -> Control:
	var card: Card = flight.card
	var cell: Control = null
	if flight.to_deck:
		cell = _deck_cells.get(card)
	else:
		cell = _stack_cells.get(Vector2i(card.suit, card.base_rank))
	if cell != null and is_instance_valid(cell) and not cell.is_queued_for_deletion():
		return cell
	return null


func _hide_flight_targets() -> void:
	for flight in _flights:
		var target := _flight_target(flight)
		if target != null:
			target.modulate.a = 0.0
			target.set_meta("flying", true)


func _fly_card(cell: Control, card: Card, to_deck: bool) -> void:
	var from_scale := COLLECTION_CARD_SCALE if to_deck else DECK_CARD_SCALE
	var to_scale := DECK_CARD_SCALE if to_deck else COLLECTION_CARD_SCALE
	var copy := _card_cell(card, from_scale, 1, false)
	_ignore_mouse(copy)
	copy.top_level = true
	copy.z_index = 50
	add_child(copy)
	copy.global_position = cell.global_position
	var flight := {"card": card, "to_deck": to_deck, "copy": copy, "start": cell.global_position}
	_flights.append(flight)
	Sfx.play_card_move()
	await get_tree().process_frame
	if not is_instance_valid(copy):
		return
	_hide_flight_targets()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_step_flight.bind(flight, from_scale, to_scale), 0.0, 1.0, 0.3)
	tween.finished.connect(_end_flight.bind(flight))


func _step_flight(t: float, flight: Dictionary, from_scale: float, to_scale: float) -> void:
	var copy: Control = flight.copy
	if not is_instance_valid(copy):
		return
	var target := _flight_target(flight)
	var end: Vector2 = flight.start if target == null else target.global_position
	copy.global_position = flight.start.lerp(end, t)
	copy.scale = Vector2.ONE * lerpf(1.0, to_scale / from_scale, t)


func _end_flight(flight: Dictionary) -> void:
	_flights.erase(flight)
	var target := _flight_target(flight)
	if target != null:
		target.modulate.a = 1.0
		target.remove_meta("flying")
	if is_instance_valid(flight.copy):
		flight.copy.queue_free()


func _rebuild_deck() -> void:
	for child in _deck_row.get_children():
		child.queue_free()
	var deck := PlayerDataManager.active_deck.duplicate()
	deck.sort_custom(_card_before)
	for card in deck:
		var cell := _card_cell(card, DECK_CARD_SCALE, 1, false)
		cell.gui_input.connect(_on_deck_cell_input.bind(card, cell))
		_deck_cells[card] = cell
		_deck_row.add_child(cell)
	for i in Missions.DECK_SIZE - deck.size():
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = CARD_SIZE * DECK_CARD_SCALE
		var style := _box(Color(0, 0, 0, 0), LINE_COLOR)
		style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)
		_deck_row.add_child(slot)
	var count := deck.size()
	_deck_counter.text = "%d / %d" % [count, Missions.DECK_SIZE]
	var full := count == Missions.DECK_SIZE
	_deck_counter.add_theme_color_override("font_color", NEW_COLOR if full else WARN_COLOR)
	_close_button.disabled = not full
	_close_button.text = "Close" if full else "Close  (%d missing)" % (Missions.DECK_SIZE - count)


func _rebuild_collection() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var stacks := {}
	for card in PlayerDataManager.collection:
		var key := Vector2i(card.suit, card.base_rank)
		if not stacks.has(key):
			stacks[key] = []
		stacks[key].append(card)
	for suit in SUIT_ORDER:
		if (suit == Card.Suit.ALK or suit == Card.Suit.SMOKE) and not _owns_suit(suit):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, CARD_SIZE.y * COLLECTION_CARD_SCALE + 6)
		var icon := TextureRect.new()
		icon.texture = _suit_texture(suit)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var keys := stacks.keys().filter(func(k: Vector2i) -> bool: return k.x == suit)
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		if keys.is_empty():
			row.add_child(_label("none", 12, MUTED_COLOR))
		for key in keys:
			var cards: Array = stacks[key]
			var is_new := cards.any(func(c: Card) -> bool: return PlayerDataManager.new_cards.has(c))
			var cell := _card_cell(cards[0], COLLECTION_CARD_SCALE, cards.size(), is_new)
			cell.gui_input.connect(_on_collection_cell_input.bind(cards[0], cell))
			_stack_cells[key] = cell
			row.add_child(cell)
		_rows.add_child(row)


func _owns_suit(suit: Card.Suit) -> bool:
	for card in PlayerDataManager.collection:
		if card.suit == suit:
			return true
	for card in PlayerDataManager.active_deck:
		if card.suit == suit:
			return true
	return false


func _card_cell(card: Card, card_scale: float, amount: int, is_new: bool) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CARD_SIZE * card_scale
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = cell.custom_minimum_size
	var face_style := _box(PANEL_COLOR_2, LINE_COLOR)
	face_style.set_border_width_all(1)
	face.add_theme_stylebox_override("panel", face_style)
	cell.add_child(face)
	var visual: CardVisual = CARD_SCENE.instantiate()
	_ignore_mouse(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	visual.size = CARD_SIZE
	visual.pivot_offset = Vector2.ZERO
	visual.hover_enabled = false
	cell.add_child(visual)
	visual.setup(card, false)
	visual.scale = Vector2.ONE * card_scale
	visual.position = Vector2.ZERO
	if amount > 1:
		var badge := _badge("x%d" % amount, FG_COLOR, BG_COLOR)
		badge.position = Vector2(cell.custom_minimum_size.x - 18, -6)
		cell.add_child(badge)
	if is_new:
		var tag := _badge("NEW", NEW_COLOR, BG_COLOR)
		tag.position = Vector2(cell.custom_minimum_size.x / 2.0 - 14, cell.custom_minimum_size.y - 10)
		cell.add_child(tag)
	cell.mouse_entered.connect(_on_cell_hovered.bind(cell, card))
	cell.mouse_exited.connect(_on_cell_unhovered.bind(cell))
	return cell


func _badge(text: String, fill: Color, text_color: Color) -> Label:
	var badge := _label(text, 10, text_color)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	badge.add_theme_stylebox_override("normal", style)
	badge.z_index = 2
	return badge


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_cell_hovered(cell: Control, card: Card) -> void:
	if not cell.has_meta("flying"):
		cell.modulate = Color(1.15, 1.1, 0.95)
	_show_card(card)


func _on_cell_unhovered(cell: Control) -> void:
	if not cell.has_meta("flying"):
		cell.modulate = Color.WHITE


func _on_deck_cell_input(event: InputEvent, card: Card, cell: Control) -> void:
	if _is_left_click(event):
		accept_event()
		if PlayerDataManager.move_to_collection(card):
			_fly_card(cell, card, false)


func _on_collection_cell_input(event: InputEvent, card: Card, cell: Control) -> void:
	if _is_left_click(event):
		accept_event()
		if PlayerDataManager.move_to_deck(card):
			_fly_card(cell, card, true)


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _show_card(card: Card) -> void:
	if card == null:
		_card_info.text = "Hover a card to see it here.\nClick a card to move it between your deck and your cards."
		return
	var lines: Array[String] = ["%s %d" % [SUIT_NAMES[card.suit], card.base_rank]]
	match card.suit:
		Card.Suit.SMOKE:
			lines.append("Always trump. Gains +1 rank per cigarette smoked.")
		Card.Suit.ALK:
			lines.append("Always trump.")
		_:
			lines.append("Trump when %s is the trump suit." % SUIT_NAMES[card.suit])
	var owned := _count_same(PlayerDataManager.collection, card) + _count_same(PlayerDataManager.active_deck, card)
	lines.append("Owned: %d  (in deck: %d)" % [owned, _count_same(PlayerDataManager.active_deck, card)])
	_card_info.text = "\n".join(lines)


func _count_same(cards: Array[Card], card: Card) -> int:
	var count := 0
	for other in cards:
		if other.suit == card.suit and other.base_rank == card.base_rank:
			count += 1
	return count


func _update_stats() -> void:
	var deck := PlayerDataManager.active_deck
	var lines: Array[String] = ["Deck stats"]
	var rank_sum := 0
	var specials := 0
	for suit in SUIT_ORDER:
		var count := 0
		for card in deck:
			if card.suit == suit:
				count += 1
		lines.append("%s: %d" % [SUIT_NAMES[suit], count])
		if suit == Card.Suit.ALK or suit == Card.Suit.SMOKE:
			specials += count
	for card in deck:
		rank_sum += card.base_rank
	lines.append("Special cards: %d" % specials)
	if not deck.is_empty():
		lines.append("Average rank: %.1f" % (float(rank_sum) / deck.size()))
	lines.append("Cards owned: %d" % (deck.size() + PlayerDataManager.collection.size()))
	_stats.text = "\n".join(lines)


func _card_before(a: Card, b: Card) -> bool:
	var suit_a := SUIT_ORDER.find(a.suit)
	var suit_b := SUIT_ORDER.find(b.suit)
	if suit_a != suit_b:
		return suit_a < suit_b
	return a.base_rank < b.base_rank


func _suit_texture(suit: Card.Suit) -> Texture2D:
	return SUIT_TEXTURES.get(suit)
