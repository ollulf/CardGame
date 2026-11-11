extends Control
class_name DeckBuilder

signal closed

const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARD_SIZE := Vector2(60, 90)
const PREVIEW_SCALE := 1.3
const DECK_CARD_SCALE := 0.6
const COLLECTION_CARD_SCALE := 0.62
const DECK_CARD_GAP := 4.0
const COLLECTION_CARD_GAP := 6.0
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
const SPECIAL_COLOR := Color("a98bff")

const SUIT_COLORS := {
	Card.Suit.HEARTS: Color("ff6f91"),
	Card.Suit.DIAMONDS: Color("ffa36e"),
	Card.Suit.SPADES: Color("e8e4f4"),
	Card.Suit.CLUBS: Color("9a94b8"),
	Card.Suit.ALK: Color("3fc1c0"),
	Card.Suit.SMOKE: Color("f2b33d"),
}

const LEFT_RECT := Rect2(16, 16, 210, 616)
const RIGHT_RECT := Rect2(236, 16, 900, 616)

var _deck_box: Panel
var _stats_panel: VBoxContainer
var _deck_row: Control
var _deck_counter: Label
var _rows: VBoxContainer
var _card_info: Label
var _card_boxes: VBoxContainer
var _preview_holder: CenterContainer
var _close_button: Button
var _pending_rebuild := false
var _deck_cells := {}
var _stack_cells := {}
var _flights: Array[Dictionary] = []
var _touch_pick: Control = null

const TOUCH_LIFT := 10.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("deck_builder")
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
	TutorialPopups.tip("deck_size", _deck_box)


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
	var info_scroll := ScrollContainer.new()
	info_scroll.position = Vector2(12, 10)
	info_scroll.size = info_box.size - Vector2(24, 20)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_box.add_child(info_scroll)
	info.size = Vector2(info_scroll.size.x - 10, 0)
	info.add_theme_constant_override("separation", 4)
	info_scroll.add_child(info)
	_card_info = _label("", 14, FG_COLOR)
	_card_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_info.custom_minimum_size = Vector2(info.size.x, 0)
	_card_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_card_info)
	_card_boxes = VBoxContainer.new()
	_card_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_boxes.custom_minimum_size = Vector2(info.size.x, 0)
	_card_boxes.add_theme_constant_override("separation", 6)
	info.add_child(_card_boxes)
	_preview_holder = CenterContainer.new()
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_holder.custom_minimum_size = Vector2(info.size.x, 0)
	info.add_child(_preview_holder)
	_stats_panel = VBoxContainer.new()
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_panel.custom_minimum_size = Vector2(info.size.x, 0)
	_stats_panel.add_theme_constant_override("separation", 2)
	info.add_child(_stats_panel)

	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.position = Vector2(LEFT_RECT.position.x, LEFT_RECT.end.y - 56)
	_close_button.size = Vector2(LEFT_RECT.size.x, 56)
	_close_button.add_theme_color_override("font_disabled_color", WARN_COLOR)
	_close_button.pressed.connect(try_close)
	add_child(_close_button)

	var deck_height := CARD_SIZE.y * DECK_CARD_SCALE + 48
	var deck_box := _panel(Rect2(RIGHT_RECT.position, Vector2(RIGHT_RECT.size.x, deck_height)))
	_deck_box = deck_box
	var deck_head := HBoxContainer.new()
	deck_head.position = Vector2(12, 6)
	deck_head.add_theme_constant_override("separation", 10)
	deck_box.add_child(deck_head)
	deck_head.add_child(_label("Your deck", 16, FG_COLOR))
	_deck_counter = _label("", 14, WARN_COLOR)
	deck_head.add_child(_deck_counter)
	_deck_row = Control.new()
	_deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_row.position = Vector2(12, 34)
	_deck_row.size = Vector2(RIGHT_RECT.size.x - 24, CARD_SIZE.y * DECK_CARD_SCALE)
	_deck_row.set_meta("gap", DECK_CARD_GAP)
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
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(font_size))
	label.add_theme_color_override("font_color", color)
	return label


func _queue_rebuild() -> void:
	if _pending_rebuild or not visible:
		return
	_pending_rebuild = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending_rebuild = false
	_touch_pick = null
	_deck_cells.clear()
	_stack_cells.clear()
	_rebuild_deck()
	_rebuild_collection()
	_fill_stats_panel()
	_hide_flight_targets()


func _flight_target(flight: Dictionary) -> Control:
	var card: Card = flight.card
	var cell: Control = null
	if flight.to_deck:
		cell = _deck_cells.get(card)
	else:
		cell = _stack_cells.get(card)
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
	var copy := _card_cell(card, from_scale, false)
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
		var cell := _card_cell(card, DECK_CARD_SCALE, false)
		cell.gui_input.connect(_on_deck_cell_input.bind(card, cell))
		_deck_cells[card] = cell
		_deck_row.add_child(cell)
	for i in Missions.DECK_MIN - deck.size():
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = CARD_SIZE * DECK_CARD_SCALE
		var style := _box(Color(0, 0, 0, 0), LINE_COLOR)
		style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)
		_deck_row.add_child(slot)
	_layout_strip(_deck_row)
	var count := deck.size()
	_deck_counter.text = "%d / %d  (min %d)" % [count, Missions.DECK_MAX, Missions.DECK_MIN]
	var enough := count >= Missions.DECK_MIN
	_deck_counter.add_theme_color_override("font_color", NEW_COLOR if enough else WARN_COLOR)
	_close_button.disabled = not enough
	_close_button.text = "Close" if enough else "Close  (%d missing)" % (Missions.DECK_MIN - count)


func _rebuild_collection() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var owned := PlayerDataManager.collection.duplicate()
	owned.sort_custom(_card_before)
	for suit in SUIT_ORDER:
		if (suit == Card.Suit.ALK or suit == Card.Suit.SMOKE) and not _owns_suit(suit):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, CARD_SIZE.y * COLLECTION_CARD_SCALE + 18)
		var icon := TextureRect.new()
		icon.texture = _suit_texture(suit)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cards := owned.filter(func(c: Card) -> bool: return c.suit == suit)
		row.add_child(icon)
		if cards.is_empty():
			row.add_child(_label("none", 12, MUTED_COLOR))
		else:
			var strip := Control.new()
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			strip.custom_minimum_size = Vector2(0, CARD_SIZE.y * COLLECTION_CARD_SCALE)
			strip.set_meta("gap", COLLECTION_CARD_GAP)
			strip.resized.connect(_layout_strip.bind(strip))
			for card in cards:
				var cell := _card_cell(card, COLLECTION_CARD_SCALE, PlayerDataManager.new_cards.has(card))
				cell.gui_input.connect(_on_collection_cell_input.bind(card, cell))
				_stack_cells[card] = cell
				strip.add_child(cell)
			row.add_child(strip)
		_rows.add_child(row)


func _layout_strip(strip: Control) -> void:
	var cells := strip.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if cells.is_empty():
		return
	var width: float = cells[0].custom_minimum_size.x
	var step: float = width + float(strip.get_meta("gap", 0.0))
	if cells.size() > 1 and width + step * (cells.size() - 1) > strip.size.x:
		step = maxf((strip.size.x - width) / (cells.size() - 1), 1.0)
	for i in cells.size():
		var cell: Control = cells[i]
		cell.position = Vector2(step * i, 0)
		cell.size = cell.custom_minimum_size


func _owns_suit(suit: Card.Suit) -> bool:
	for card in PlayerDataManager.collection:
		if card.suit == suit:
			return true
	for card in PlayerDataManager.active_deck:
		if card.suit == suit:
			return true
	return false


func _card_cell(card: Card, card_scale: float, is_new: bool) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CARD_SIZE * card_scale
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_card_visual(cell, card, card_scale)
	if is_new:
		var tag := _badge("NEW", NEW_COLOR, BG_COLOR)
		tag.position = Vector2(cell.custom_minimum_size.x / 2.0 - 14, cell.custom_minimum_size.y + 1)
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
	badge.z_index = 1
	return badge


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_cell_hovered(cell: Control, card: Card) -> void:
	cell.z_index = 10
	if not cell.has_meta("flying"):
		cell.modulate = Color(1.15, 1.1, 0.95)
		CardJuice.grid_hover(cell, true)
	_show_card(card)


func _on_cell_unhovered(cell: Control) -> void:
	cell.z_index = 0
	if not cell.has_meta("flying"):
		cell.modulate = Color.WHITE
		CardJuice.grid_hover(cell, false)


func _on_deck_cell_input(event: InputEvent, card: Card, cell: Control) -> void:
	if _is_left_click(event):
		accept_event()
		if not _confirm_touch_pick(cell, card):
			return
		if PlayerDataManager.move_to_collection(card):
			_fly_card(cell, card, false)


func _on_collection_cell_input(event: InputEvent, card: Card, cell: Control) -> void:
	if _is_left_click(event):
		accept_event()
		if not _confirm_touch_pick(cell, card):
			return
		if PlayerDataManager.move_to_deck(card):
			_fly_card(cell, card, true)


func _confirm_touch_pick(cell: Control, card: Card) -> bool:
	if not InteractionManager.uses_touch():
		return true
	if _touch_pick == cell:
		_clear_touch_pick()
		return true
	_clear_touch_pick()
	_touch_pick = cell
	_on_cell_hovered(cell, card)
	cell.position.y -= TOUCH_LIFT
	cell.set_meta("touch_lifted", true)
	Sfx.play_hover_card()
	return false


func _clear_touch_pick() -> void:
	if is_instance_valid(_touch_pick):
		if _touch_pick.has_meta("touch_lifted"):
			_touch_pick.position.y += TOUCH_LIFT
			_touch_pick.remove_meta("touch_lifted")
		_on_cell_unhovered(_touch_pick)
	_touch_pick = null


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _show_card(card: Card) -> void:
	_clear(_preview_holder)
	_clear(_card_boxes)
	if card == null:
		if InteractionManager.uses_touch():
			_card_info.text = "Tap a card to see it here.\nTap it again to move it between your deck and your cards."
		else:
			_card_info.text = "Hover a card to see it here.\nClick a card to move it between your deck and your cards."
		return
	_card_info.text = "%s %d" % [SUIT_NAMES[card.suit], card.base_rank]
	match card.suit:
		Card.Suit.SMOKE:
			_add_info_box("Never trump" if card.is_colorless() else "Always trump", ("Colorless. " if card.is_colorless() else "") + "Gains +1 rank per cigarette smoked.", _suit_color(card.suit))
		Card.Suit.ALK:
			_add_info_box("Never trump" if card.is_colorless() else "Always trump", "Colorless." if card.is_colorless() else "", _suit_color(card.suit))
	if card.has_effect():
		_add_info_box("Special", CardEffect.description(card.effect), SPECIAL_COLOR)
	if card.has_stamp():
		_add_info_box("%s stamp" % CardStamp.display_name(card.stamp), CardStamp.description(card.stamp), ACCENT_COLOR)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = CARD_SIZE * PREVIEW_SCALE
	_preview_holder.add_child(holder)
	_add_card_visual(holder, card, PREVIEW_SCALE)


func _add_info_box(heading: String, text: String, color: Color) -> void:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(PANEL_COLOR_2, Color(color, 0.6))
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var head := _label(heading, 13, color)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	if text != "":
		var body := _label(text, 12, FG_COLOR)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.custom_minimum_size = Vector2(_card_boxes.custom_minimum_size.x - 16, 0)
		column.add_child(body)
	_card_boxes.add_child(box)


func _count_same(cards: Array[Card], card: Card) -> int:
	var count := 0
	for other in cards:
		if other.suit == card.suit and other.base_rank == card.base_rank and other.effect == card.effect and other.stamp == card.stamp:
			count += 1
	return count


func _card_before(a: Card, b: Card) -> bool:
	var suit_a := SUIT_ORDER.find(a.suit)
	var suit_b := SUIT_ORDER.find(b.suit)
	if suit_a != suit_b:
		return suit_a < suit_b
	if a.base_rank != b.base_rank:
		return a.base_rank < b.base_rank
	if a.effect != b.effect:
		return a.effect < b.effect
	return a.stamp < b.stamp


func _suit_texture(suit: Card.Suit) -> Texture2D:
	return SUIT_TEXTURES.get(suit)


func _is_special(card: Card) -> bool:
	return card.suit == Card.Suit.ALK or card.suit == Card.Suit.SMOKE


func _suit_color(suit: Card.Suit) -> Color:
	return SUIT_COLORS.get(suit, MUTED_COLOR)


func _suit_counts(cards: Array[Card]) -> Dictionary:
	var counts := {}
	for suit in SUIT_ORDER:
		counts[suit] = 0
	for card in cards:
		counts[card.suit] += 1
	return counts


func _rank_counts(cards: Array[Card]) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(10)
	counts.fill(0)
	for card in cards:
		counts[clampi(card.base_rank, 0, 9)] += 1
	return counts


func _visible_suits() -> Array[Card.Suit]:
	var suits: Array[Card.Suit] = []
	for suit in SUIT_ORDER:
		if (suit == Card.Suit.ALK or suit == Card.Suit.SMOKE) and not _owns_suit(suit):
			continue
		suits.append(suit)
	return suits


func _rect(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var shape := ColorRect.new()
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.position = rect.position
	shape.size = rect.size
	shape.color = color
	parent.add_child(shape)
	return shape


func _suit_icon(suit: Card.Suit, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _suit_texture(suit)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _tiny_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label


func _draw_histogram(target: Control, counts: Array[int], bar_area: float, show_counts: bool) -> void:
	var top := 14.0 if show_counts else 0.0
	var slot := target.size.x / counts.size()
	var highest := maxi(counts.max(), 1)
	for rank in counts.size():
		var x := slot * rank + 2
		var width := slot - 4
		_rect(target, Rect2(x, top, width, bar_area), Color(LINE_COLOR, 0.25))
		var height := bar_area * counts[rank] / highest
		if counts[rank] > 0:
			_rect(target, Rect2(x, top + bar_area - height, width, height), ACCENT_COLOR)
		if show_counts and counts[rank] > 0:
			var count_label := _tiny_label(str(counts[rank]), FG_COLOR)
			count_label.size = Vector2(slot, 12)
			count_label.position = Vector2(slot * rank, top + bar_area - height - 14)
			target.add_child(count_label)
		var rank_label := _tiny_label(str(rank), MUTED_COLOR)
		rank_label.size = Vector2(slot, 12)
		rank_label.position = Vector2(slot * rank, top + bar_area)
		target.add_child(rank_label)


func _fill_stats_panel() -> void:
	_clear(_stats_panel)
	var deck := PlayerDataManager.active_deck.duplicate()
	deck.sort_custom(_card_before)
	var width := _stats_panel.custom_minimum_size.x
	_stats_panel.add_child(_label("Deck stats", 14, FG_COLOR))
	var counts := _suit_counts(deck)
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(width, 12)
	_rect(bar, Rect2(0, 0, width, 12), Color(LINE_COLOR, 0.25))
	var x := 0.0
	for suit in SUIT_ORDER:
		var part: float = width * counts[suit] / maxi(deck.size(), 1)
		if part > 0:
			_rect(bar, Rect2(x, 0, maxf(part - 1, 1), 12), _suit_color(suit))
		x += part
	_stats_panel.add_child(bar)
	var legend := HBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 2)
	var suits := _visible_suits()
	var compact := suits.size() > 4
	for suit in suits:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 2 if compact else 4)
		line.add_child(_suit_icon(suit, 12 if compact else 14))
		line.add_child(_label(str(counts[suit]), 12 if compact else 14, _suit_color(suit) if counts[suit] > 0 else Color(MUTED_COLOR, 0.5)))
		legend.add_child(line)
	_stats_panel.add_child(legend)
	_stats_panel.add_child(_label("Ranks", 12, MUTED_COLOR))
	var histogram := Control.new()
	histogram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	histogram.custom_minimum_size = Vector2(width, 50)
	histogram.size = histogram.custom_minimum_size
	_draw_histogram(histogram, _rank_counts(deck), 24.0, true)
	_stats_panel.add_child(histogram)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	var rank_sum := 0
	var specials := 0
	var highest := -1
	var lowest := 99
	for card in deck:
		rank_sum += card.base_rank
		highest = maxi(highest, card.base_rank)
		lowest = mini(lowest, card.base_rank)
		if _is_special(card):
			specials += 1
	var duplicates := 0
	for i in range(1, deck.size()):
		if deck[i].suit == deck[i - 1].suit and deck[i].base_rank == deck[i - 1].base_rank:
			duplicates += 1
	var empty := deck.is_empty()
	var rows := [
		["Average rank", "-" if empty else "%.1f" % (float(rank_sum) / deck.size())],
		["Low - high", "-" if empty else "%d - %d" % [lowest, highest]],
		["Always trump", str(specials)],
		["Duplicates", str(duplicates)],
		["Cards owned", str(deck.size() + PlayerDataManager.collection.size())],
	]
	for entry in rows:
		var key := _label(entry[0], 12, MUTED_COLOR)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(key)
		grid.add_child(_label(entry[1], 13, FG_COLOR))
	_stats_panel.add_child(grid)



func _add_card_visual(parent: Control, card: Card, card_scale: float) -> CardVisual:
	var visual: CardVisual = CARD_SCENE.instantiate()
	_ignore_mouse(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	visual.size = CARD_SIZE
	visual.pivot_offset = Vector2.ZERO
	visual.hover_enabled = false
	var background: CanvasItem = visual.get_node("Background")
	background.z_index = 0
	visual.move_child(background, 0)
	parent.add_child(visual)
	visual.setup(card, false)
	visual.scale = Vector2.ONE * card_scale
	visual.position = Vector2.ZERO
	return visual
