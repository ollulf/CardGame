extends Control
class_name StampShop

signal closed
signal denied
signal stamp_applied(card: Card)

const CARD_SCENE := preload("res://scenes/Card.tscn")
const PANEL_RECT := Rect2(106, 60, 940, 540)
const ENTRY_SIZE := Vector2(262, 330)
const ENTRY_GAP := 24.0
const ENTRY_PADDING := Vector2(16, 14)
const CARD_SIZE := Vector2(60, 90)
const CARD_SCALE := 1.0
const GRID_COLUMNS := 11
const GRID_GAP := 12
const BADGE_PIXEL := 6.0
const TOOL_PIXEL := 5.0
const BG_COLOR := Color("17161c")
const BORDER_COLOR := Color("6b6390")
const TEXT_COLOR := Color("ffffff")
const MUTED_COLOR := Color("d6d1e6")
const PRICE_COLOR := Color("ffcf6e")
const SELECTED_COLOR := Color("ffcf6e")
const DENY_COLOR := Color(1.0, 0.45, 0.4)
const INELIGIBLE_COLOR := Color(0.35, 0.35, 0.38, 0.8)
const TITLE_TEXT := "Stamp Stand"
const CONFIRM_TEXT := "Really?"
const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const NO_CARD_TEXT := "No card can take it"
const SOLD_OUT_TEXT := "Sold out until the next match"
const OFFERS_HINT := "Stamps go on common or rare cards, one stamp per card. Tap a stamp, then tap it again to buy it."
const PICK_TITLE := "Stamp a card"
const PICK_HINT := "You must put your %s stamp on a card. Tap a card, then tap it again."
const PICK_CONFIRM_HINT := "Tap the card again to stamp it."

var pending_stamp := CardStamp.Id.NONE
var _offers_root: Control
var _pick_root: Control
var _title: Label
var _cash_label: Label
var _hint_label: Label
var _close_button: Button
var _entries: Array[PanelContainer] = []
var _footers: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []
var _sold_out_label: Label
var _grid: GridContainer
var _confirm_index := -1
var _picked_card: Card
var _picked_cell: Control
var _deny_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	PlayerDataManager.stamp_offers_changed.connect(_on_offers_changed)
	hide()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override("panel", _box_style(BORDER_COLOR))
	add_child(panel)

	_title = HeadlineLabel.new()
	_title.text = TITLE_TEXT
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = PANEL_RECT.position + Vector2(0, 14)
	_title.size = Vector2(PANEL_RECT.size.x, 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_cash_label = _label("", 22, PRICE_COLOR)
	_cash_label.position = PANEL_RECT.position + Vector2(PANEL_RECT.size.x - 140, 18)
	_cash_label.size = Vector2(120, 32)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cash_label)
	PlayerDataManager.money_changed.connect(_on_money_changed)
	_on_money_changed(PlayerDataManager.money)

	_hint_label = _centered(_label(OFFERS_HINT, 15, MUTED_COLOR))
	_hint_label.position = PANEL_RECT.position + Vector2(20, 58)
	_hint_label.size = Vector2(PANEL_RECT.size.x - 40, 40)
	add_child(_hint_label)

	_offers_root = Control.new()
	_offers_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offers_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_offers_root)
	_sold_out_label = _centered(_label(SOLD_OUT_TEXT, 22, MUTED_COLOR))
	_sold_out_label.position = PANEL_RECT.position + Vector2(0, PANEL_RECT.size.y * 0.45)
	_sold_out_label.size = Vector2(PANEL_RECT.size.x, 40)
	_offers_root.add_child(_sold_out_label)

	_pick_root = Control.new()
	_pick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pick_root.z_index = 1
	add_child(_pick_root)
	var scroll := ScrollContainer.new()
	scroll.position = PANEL_RECT.position + Vector2(24, 104)
	scroll.size = Vector2(PANEL_RECT.size.x - 48, PANEL_RECT.size.y - 124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pick_root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	center.add_child(_grid)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.size = Vector2(110, 32)
	_close_button.position = Vector2(PANEL_RECT.get_center().x - 55, PANEL_RECT.end.y - 46)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func open() -> void:
	if pending_stamp != CardStamp.Id.NONE:
		_show_pick()
	else:
		_show_offers()
	show()


func close() -> void:
	if not visible or pending_stamp != CardStamp.Id.NONE:
		return
	_cancel_confirm()
	hide()
	closed.emit()


func _show_offers() -> void:
	_cancel_confirm()
	_title.text = TITLE_TEXT
	_hint_label.text = OFFERS_HINT
	_hint_label.modulate = Color.WHITE
	_pick_root.hide()
	_offers_root.show()
	_close_button.show()
	_rebuild_offers()


func _rebuild_offers() -> void:
	for entry in _entries:
		entry.queue_free()
	_entries.clear()
	_footers.clear()
	_styles.clear()
	_confirm_index = -1
	var offers := PlayerDataManager.get_stamp_offers()
	_sold_out_label.visible = offers.is_empty()
	var row_width := offers.size() * ENTRY_SIZE.x + maxi(offers.size() - 1, 0) * ENTRY_GAP
	var left := PANEL_RECT.get_center().x - row_width / 2.0
	for i in offers.size():
		var entry := _build_entry(offers[i])
		entry.position = Vector2(left + i * (ENTRY_SIZE.x + ENTRY_GAP), PANEL_RECT.position.y + 110)
		_offers_root.add_child(entry)
		_entries.append(entry)


func _build_entry(stamp: int) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.custom_minimum_size = ENTRY_SIZE
	entry.size = ENTRY_SIZE
	entry.pivot_offset = ENTRY_SIZE / 2.0
	var style := _box_style(BORDER_COLOR)
	style.bg_color = BG_COLOR.lightened(0.06)
	style.content_margin_left = ENTRY_PADDING.x
	style.content_margin_right = ENTRY_PADDING.x
	style.content_margin_top = ENTRY_PADDING.y
	style.content_margin_bottom = ENTRY_PADDING.y
	entry.add_theme_stylebox_override("panel", style)
	_styles.append(style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	entry.add_child(box)

	var holder := HBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 14)
	box.add_child(holder)
	var tool := TextureRect.new()
	tool.texture = StampArt.tool(stamp)
	tool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tool.stretch_mode = TextureRect.STRETCH_SCALE
	tool.custom_minimum_size = Vector2(StampArt.TOOL_SIZE) * TOOL_PIXEL
	tool.size_flags_vertical = Control.SIZE_SHRINK_END
	tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tool)
	holder.add_child(StampBadge.create(stamp, BADGE_PIXEL))

	box.add_child(_centered(_label(CardStamp.display_name(stamp), 22, CardStamp.color(stamp).lightened(0.25))))
	box.add_child(_centered(_label("%d$" % CardStamp.price(stamp), 22, PRICE_COLOR)))
	box.add_child(_centered(_label(CardStamp.description(stamp), 15, MUTED_COLOR)))
	var footer := _centered(_label("", 18, SELECTED_COLOR))
	footer.custom_minimum_size = Vector2(0, 26)
	box.add_child(footer)
	_footers.append(footer)
	return entry


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if _offers_root.visible:
			click_at(event.position)


func click_at(point: Vector2) -> void:
	for i in _entries.size():
		if _entries[i].get_rect().has_point(point):
			Sfx.play_button()
			select(i)
			return
	_cancel_confirm()


func select(index: int) -> void:
	if _confirm_index != index:
		_cancel_confirm()
		_confirm_index = index
		_styles[index].border_color = SELECTED_COLOR
		_footers[index].modulate = Color.WHITE
		_footers[index].text = CONFIRM_TEXT
		return
	buy(index)


func buy(index: int) -> bool:
	_cancel_confirm()
	if not PlayerDataManager.has_stampable_card():
		deny(index, NO_CARD_TEXT)
		return false
	var stamp := PlayerDataManager.buy_stamp(index)
	if stamp == CardStamp.Id.NONE:
		deny(index, NOT_ENOUGH_MONEY_TEXT)
		return false
	pending_stamp = stamp
	_show_pick()
	return true


func deny(index: int, text: String) -> void:
	if _deny_tween:
		_deny_tween.kill()
	var entry := _entries[index]
	var footer := _footers[index]
	footer.text = text
	footer.modulate = DENY_COLOR
	entry.rotation = 0.0
	denied.emit()
	_deny_tween = create_tween()
	for angle in [0.04, -0.04, 0.025, -0.025, 0.0]:
		_deny_tween.tween_property(entry, "rotation", angle, 0.04)
	_deny_tween.tween_interval(1.2)
	_deny_tween.tween_callback(func() -> void:
		if is_instance_valid(footer) and _confirm_index != index:
			footer.text = ""
			footer.modulate = Color.WHITE)


func _cancel_confirm() -> void:
	if _confirm_index < 0 or _confirm_index >= _styles.size():
		_confirm_index = -1
		return
	_styles[_confirm_index].border_color = BORDER_COLOR
	_footers[_confirm_index].text = ""
	_confirm_index = -1


func _show_pick() -> void:
	_title.text = PICK_TITLE
	_hint_label.text = PICK_HINT % CardStamp.display_name(pending_stamp)
	_hint_label.modulate = Color.WHITE
	_offers_root.hide()
	_close_button.hide()
	_pick_root.show()
	_picked_card = null
	_picked_cell = null
	for child in _grid.get_children():
		child.queue_free()
	var cards: Array[Card] = []
	cards.append_array(PlayerDataManager.active_deck)
	cards.append_array(PlayerDataManager.collection)
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		var a_ok := CardStamp.can_stamp(a)
		var b_ok := CardStamp.can_stamp(b)
		if a_ok != b_ok:
			return a_ok
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.base_rank < b.base_rank)
	for card in cards:
		_grid.add_child(_card_cell(card))


func _card_cell(card: Card) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CARD_SIZE * CARD_SCALE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var visual: CardVisual = CARD_SCENE.instantiate()
	_ignore_mouse(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	visual.size = CARD_SIZE
	visual.pivot_offset = Vector2.ZERO
	visual.hover_enabled = false
	cell.add_child(visual)
	visual.setup(card, false)
	visual.scale = Vector2.ONE * CARD_SCALE
	visual.position = Vector2.ZERO
	if CardStamp.can_stamp(card):
		cell.gui_input.connect(_on_cell_input.bind(card, cell))
	else:
		cell.modulate = INELIGIBLE_COLOR
	return cell


func _on_cell_input(event: InputEvent, card: Card, cell: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell.accept_event()
		Sfx.play_button()
		pick(card, cell)


func pick(card: Card, cell: Control = null) -> bool:
	if pending_stamp == CardStamp.Id.NONE or not CardStamp.can_stamp(card):
		return false
	if cell != null and _picked_card != card:
		_mark_cell(_picked_cell, false)
		_picked_card = card
		_picked_cell = cell
		_mark_cell(cell, true)
		_hint_label.text = PICK_CONFIRM_HINT
		_hint_label.modulate = SELECTED_COLOR
		return false
	if not PlayerDataManager.apply_stamp(card, pending_stamp):
		return false
	pending_stamp = CardStamp.Id.NONE
	stamp_applied.emit(card)
	_show_offers()
	return true


func _mark_cell(cell: Control, active: bool) -> void:
	if cell == null or not is_instance_valid(cell):
		return
	cell.scale = Vector2.ONE * (1.12 if active else 1.0)
	cell.pivot_offset = cell.size * 0.5
	cell.z_index = 1 if active else 0
	var visual := cell.get_child(0) as CardVisual
	if visual != null:
		visual.set_playable(active)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_offers_changed() -> void:
	if visible and _offers_root.visible:
		_rebuild_offers()


func _on_money_changed(money: int) -> void:
	_cash_label.text = "%d$" % money


func _box_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(font_size))
	label.add_theme_color_override("font_color", color)
	return label


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
