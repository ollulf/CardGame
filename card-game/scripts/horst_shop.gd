extends Control
class_name HorstShop

signal closed
signal denied
signal sold

const CARD_SCENE := preload("res://scenes/Card.tscn")
const PANEL_RECT := Rect2(106, 60, 940, 540)
const CARD_SIZE := Vector2(60, 90)
const GRID_COLUMNS := 12
const GRID_GAP := 12
const SLOT_GAP := 16.0
const BG_COLOR := Color("17161c")
const BORDER_COLOR := Color("6b6390")
const SLOT_COLOR := Color("24222c")
const TEXT_COLOR := Color("ffffff")
const MUTED_COLOR := Color("d6d1e6")
const PRICE_COLOR := Color("ffcf6e")
const SELECTED_COLOR := Color("ffcf6e")
const DENY_COLOR := Color(1.0, 0.45, 0.4)
const INELIGIBLE_COLOR := Color(0.35, 0.35, 0.38, 0.8)
const TITLE_TEXT := "Horst"
const HINT_TEXT := "Pick %d cards from your collection. A special card counts as %d. One deal per visit."
const HAND_OVER_TEXT := "Hand over (%d$)"
const COUNTING_TEXT := "Horst is counting"
const OFFER_TEXT := "His pick, blind (%d$)"
const SLOT_FILLED_TEXT := "x%d"
const GREETINGS := {
	"early": [
		"Three for a buck. I don't haggle, I don't do refunds.",
		"Bernd's deck? Seen it. Had most of it before him.",
	],
	"middle": [
		"Show me what you've got. *cough* Don't rush me.",
		"Manfred sold me his good deck once. Bought a round with it.",
	],
	"late": [
		"Got a smoke? ...Never mind. Show me the cards.",
		"I used to beat them both, you know. Back when they still counted.",
	],
}
const SOLD_LINES := [
	"One buck. Don't spend it all at once. You will, though.",
	"Into the box. Box fourteen. Or fifteen.",
]
const SOLD_SPECIAL_LINE := "Ooh. The weird ones. I like the weird ones."
const STAMP_LINE := "That stamp cost you money, kid."
const FLOOR_LINE := "You need those, kid. Can't play with an empty hand."
const FULL_LINE := "Three cards. I can count, even now."
const DONE_LINE := "Come back next round. I'm counting."
const EMPTY_LINE := "Nothing spare? Your deck's eating everything."
const OFFER_LINE := "I've got one for you. %d$, no peeking."
const OFFER_BOUGHT_LINE := "Don't thank me. I've got three more of those somewhere."
const POOR_LINE := "%d$, kid. I'm not a charity."

var _title: Label
var _cash_label: Label
var _line_label: Label
var _hint_label: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _slots: Array[Panel] = []
var _hand_over_button: Button
var _offer_button: Button
var _close_button: Button
var _cells := {}
var _tray: Array[Card] = []
var _line_tween: Tween
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	PlayerDataManager.money_changed.connect(_on_money_changed)
	_on_money_changed(PlayerDataManager.money)
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
	panel.add_theme_stylebox_override("panel", _box_style(BG_COLOR, BORDER_COLOR))
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

	_line_label = _centered(_label("", 18, TEXT_COLOR))
	_line_label.position = PANEL_RECT.position + Vector2(20, 58)
	_line_label.size = Vector2(PANEL_RECT.size.x - 40, 28)
	_line_label.pivot_offset = _line_label.size / 2.0
	add_child(_line_label)

	_hint_label = _centered(_label("", 14, MUTED_COLOR))
	_hint_label.position = PANEL_RECT.position + Vector2(20, 88)
	_hint_label.size = Vector2(PANEL_RECT.size.x - 40, 22)
	add_child(_hint_label)

	_scroll = ScrollContainer.new()
	_scroll.position = PANEL_RECT.position + Vector2(24, 116)
	_scroll.size = Vector2(PANEL_RECT.size.x - 48, 260)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	center.add_child(_grid)

	var tray_width := PlayerDataManager.HORST_CARDS_PER_DEAL * CARD_SIZE.x + (PlayerDataManager.HORST_CARDS_PER_DEAL - 1) * SLOT_GAP
	var tray_left := PANEL_RECT.get_center().x - tray_width / 2.0
	var tray_top := PANEL_RECT.position.y + 388
	for i in PlayerDataManager.HORST_CARDS_PER_DEAL:
		var slot := Panel.new()
		slot.position = Vector2(tray_left + i * (CARD_SIZE.x + SLOT_GAP), tray_top)
		slot.size = CARD_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _box_style(SLOT_COLOR, BORDER_COLOR))
		slot.gui_input.connect(_on_slot_input.bind(i))
		add_child(slot)
		_slots.append(slot)

	_hand_over_button = _button("", Vector2(tray_left + tray_width + 40, tray_top + 25), Vector2(200, 40))
	_hand_over_button.pressed.connect(hand_over)
	_offer_button = _button("", Vector2(tray_left - 40 - 220, tray_top + 25), Vector2(220, 40))
	_offer_button.pressed.connect(_on_offer_pressed)
	_close_button = _button("Close", Vector2(PANEL_RECT.get_center().x - 55, PANEL_RECT.end.y - 46), Vector2(110, 32))
	_close_button.pressed.connect(close)


func open() -> void:
	_busy = false
	_tray.clear()
	_title.text = TITLE_TEXT
	_hint_label.text = HINT_TEXT % [PlayerDataManager.HORST_CARDS_PER_DEAL, PlayerDataManager.HORST_CARDS_PER_DEAL]
	_rebuild_grid()
	if PlayerDataManager.horst_deals_left() <= 0:
		say(DONE_LINE)
	elif PlayerDataManager.collection.is_empty():
		say(EMPTY_LINE)
	elif PlayerDataManager.is_horst_offer_available():
		say(OFFER_LINE % PlayerDataManager.HORST_OFFER_PRICE)
	else:
		say(greeting(DialogueManager.upcoming_match()))
	_refresh()
	show()


func close() -> void:
	if not visible or _busy:
		return
	_tray.clear()
	hide()
	closed.emit()


static func stage(match_number: int) -> String:
	if match_number <= 2:
		return "early"
	if match_number == 3:
		return "middle"
	return "late"


static func greeting(match_number: int) -> String:
	return GREETINGS[stage(match_number)].pick_random()


func say(text: String, color: Color = TEXT_COLOR) -> void:
	_line_label.text = "\"%s\"" % text
	_line_label.modulate = color


func deny(text: String) -> void:
	say(text, DENY_COLOR)
	if _line_tween:
		_line_tween.kill()
	_line_label.rotation = 0.0
	_line_tween = create_tween()
	for angle in [0.02, -0.02, 0.012, -0.012, 0.0]:
		_line_tween.tween_property(_line_label, "rotation", angle, 0.04)


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	var cards: Array[Card] = []
	cards.append_array(PlayerDataManager.collection)
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		var a_rank := PlayerDataManager.horst_weight(a) * 10 + (1 if a.has_stamp() else 0)
		var b_rank := PlayerDataManager.horst_weight(b) * 10 + (1 if b.has_stamp() else 0)
		if a_rank != b_rank:
			return a_rank < b_rank
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.base_rank < b.base_rank)
	for card in cards:
		var cell := _card_cell(card)
		cell.gui_input.connect(_on_cell_input.bind(card))
		_grid.add_child(cell)
		_cells[card] = cell


func _card_cell(card: Card) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CARD_SIZE
	cell.size = CARD_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.pivot_offset = CARD_SIZE / 2.0
	var visual: CardVisual = CARD_SCENE.instantiate()
	_ignore_mouse(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	visual.size = CARD_SIZE
	visual.pivot_offset = Vector2.ZERO
	visual.hover_enabled = false
	cell.add_child(visual)
	visual.setup(card, false)
	visual.position = Vector2.ZERO
	return cell


func _on_cell_input(event: InputEvent, card: Card) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		Sfx.play_button()
		add_to_tray(card)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if index < _tray.size():
			Sfx.play_button()
			remove_from_tray(_tray[index])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()


func add_to_tray(card: Card) -> bool:
	if _busy or _tray.has(card) or not PlayerDataManager.collection.has(card):
		return false
	if PlayerDataManager.horst_deals_left() <= 0:
		deny(DONE_LINE)
		return false
	if _tray_weight() + PlayerDataManager.horst_weight(card) > PlayerDataManager.HORST_CARDS_PER_DEAL:
		deny(FULL_LINE)
		return false
	var next: Array[Card] = _tray.duplicate()
	next.append(card)
	if not PlayerDataManager.horst_keeps_floor(next):
		deny(FLOOR_LINE)
		return false
	_tray.append(card)
	if card.has_stamp():
		say(STAMP_LINE, PRICE_COLOR)
	elif card.has_effect():
		say(SOLD_SPECIAL_LINE)
	_refresh()
	return true


func remove_from_tray(card: Card) -> void:
	if _busy:
		return
	_tray.erase(card)
	_refresh()


func _tray_weight() -> int:
	return PlayerDataManager.horst_weight_of(_tray)


func hand_over() -> bool:
	if _busy:
		return false
	var cards: Array[Card] = _tray.duplicate()
	if not PlayerDataManager.can_sell_to_horst(cards):
		return false
	var had_special := cards.any(func(card: Card) -> bool: return card.has_effect())
	_busy = true
	var tween := create_tween().set_parallel(true)
	for slot in _slots:
		for child in slot.get_children():
			tween.tween_property(child, "position:y", child.position.y - 40.0, 0.35)
			tween.tween_property(child, "modulate:a", 0.0, 0.35)
	await tween.finished
	PlayerDataManager.sell_to_horst(cards)
	Sfx.play_coin_drop()
	_tray.clear()
	_busy = false
	say(SOLD_SPECIAL_LINE if had_special else SOLD_LINES.pick_random())
	_rebuild_grid()
	_refresh()
	sold.emit()
	return true


func _on_offer_pressed() -> void:
	buy_offer()


func buy_offer() -> Card:
	if _busy or not PlayerDataManager.is_horst_offer_available():
		return null
	if not PlayerDataManager.can_afford(PlayerDataManager.HORST_OFFER_PRICE):
		deny(POOR_LINE % PlayerDataManager.HORST_OFFER_PRICE)
		denied.emit()
		return null
	var card := PlayerDataManager.buy_horst_offer()
	if card == null:
		return null
	Sfx.play_card_flip()
	say(OFFER_BOUGHT_LINE)
	_rebuild_grid()
	_refresh()
	var cell: Control = _cells.get(card)
	if cell != null:
		cell.scale = Vector2.ONE * 1.12
		cell.z_index = 1
		var visual := cell.get_child(0) as CardVisual
		if visual != null:
			visual.set_playable(true)
		_scroll_to.call_deferred(cell)
	return card


func _scroll_to(cell: Control) -> void:
	if is_instance_valid(cell):
		_scroll.ensure_control_visible(cell)


func _refresh() -> void:
	var deals_left := PlayerDataManager.horst_deals_left()
	var room := PlayerDataManager.HORST_CARDS_PER_DEAL - _tray_weight()
	for card in _cells:
		var cell: Control = _cells[card]
		cell.visible = not _tray.has(card)
		var fits: bool = deals_left > 0 and PlayerDataManager.horst_weight(card) <= room
		cell.modulate = Color.WHITE if fits else INELIGIBLE_COLOR
	_refresh_slots()
	var can_sell := PlayerDataManager.can_sell_to_horst(_tray)
	_hand_over_button.text = COUNTING_TEXT if deals_left <= 0 else HAND_OVER_TEXT % PlayerDataManager.HORST_DEAL_PAY
	_hand_over_button.disabled = not can_sell
	_offer_button.visible = PlayerDataManager.is_horst_offer_available()
	_offer_button.text = OFFER_TEXT % PlayerDataManager.HORST_OFFER_PRICE


func _refresh_slots() -> void:
	for slot in _slots:
		for child in slot.get_children():
			child.queue_free()
	var index := 0
	for card in _tray:
		if index >= _slots.size():
			break
		var visual := _card_cell(card)
		_ignore_mouse(visual)
		_slots[index].add_child(visual)
		index += 1
		for extra in PlayerDataManager.horst_weight(card) - 1:
			if index >= _slots.size():
				break
			var mark := _centered(_label(SLOT_FILLED_TEXT % PlayerDataManager.horst_weight(card), 22, SELECTED_COLOR))
			mark.size = CARD_SIZE
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_slots[index].add_child(mark)
			index += 1


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_money_changed(money: int) -> void:
	_cash_label.text = "%d$" % money


func _button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.size = button_size
	add_child(button)
	return button


func _box_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
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
