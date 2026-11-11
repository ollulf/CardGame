extends Control
class_name BoosterShelf

signal closed
signal denied

const PANEL_WIDTH := 940.0
const ENTRY_WIDTH := 380.0
const ENTRY_GAP := 18
const ENTRY_PADDING := Vector2(18, 16)
const PANEL_PADDING := Vector2(24, 18)
const BG_COLOR := Color("17161c")
const BORDER_COLOR := Color("6b6390")
const TEXT_COLOR := Color("ffffff")
const MUTED_COLOR := Color("d6d1e6")
const PRICE_COLOR := Color("ffcf6e")
const SELECTED_COLOR := Color("ffcf6e")
const DENY_COLOR := Color(1.0, 0.45, 0.4)
const CONFIRM_TEXT := "Really?"
const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const HINT_TEXT := "Tap a pack, then tap it again to buy it"
const PACK_COLOR := Color(0.8, 0.8, 0.84, 1)
const PACK_TEXTURE := preload("res://sprites/booster_pack.png")
const SHINE_SHADER := preload("res://shaders/booster_shine.gdshader")
const SHADING_MAP := preload("res://sprites/booster_pack_map.png")
const SHINE_STAGGER := 0.35

var entries: Array[PanelContainer] = []
var _footers: Array[Label] = []
var _rank_labels: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []
var _confirm_index := -1
var _deny_tween: Tween
var _cash_label: Label
var _hint_label: Label
var _close_button: Button
var show_hint := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var panel_style := _box_style(BORDER_COLOR)
	panel_style.content_margin_left = PANEL_PADDING.x
	panel_style.content_margin_right = PANEL_PADDING.x
	panel_style.content_margin_top = PANEL_PADDING.y
	panel_style.content_margin_bottom = PANEL_PADDING.y
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var header := Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.custom_minimum_size = Vector2(0, 48)
	column.add_child(header)

	var title := HeadlineLabel.new()
	title.text = "Booster Shelf"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.add_child(title)

	_cash_label = _label("", 22, PRICE_COLOR)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.add_child(_cash_label)
	PlayerDataManager.money_changed.connect(_on_money_changed)
	_on_money_changed(PlayerDataManager.money)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ENTRY_GAP)
	column.add_child(row)
	for i in PlayerDataManager.BOOSTERS.size():
		var entry := _build_entry(PlayerDataManager.BOOSTERS[i], pack_tint(PlayerDataManager.BOOSTERS[i]))
		row.add_child(entry)
		entries.append(entry)

	_hint_label = _centered(_label(HINT_TEXT, 15, PRICE_COLOR))
	_hint_label.hide()
	column.add_child(_hint_label)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(110, 32)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	_layout_entries()


func _layout_entries() -> void:
	var shown := 0
	for i in entries.size():
		_rank_labels[i].text = rank_text(PlayerDataManager.BOOSTERS[i], DialogueManager.upcoming_match())
		entries[i].visible = PlayerDataManager.is_booster_available(PlayerDataManager.BOOSTERS[i])
		if entries[i].visible:
			shown += 1
	if shown == 0:
		return
	var inner := PANEL_WIDTH - PANEL_PADDING.x * 2.0
	var width := minf(ENTRY_WIDTH, (inner - (shown - 1) * ENTRY_GAP) / shown)
	for entry in entries:
		entry.custom_minimum_size = Vector2(width, 0)


func _build_entry(booster: Dictionary, pack_color: Color) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.custom_minimum_size = Vector2(ENTRY_WIDTH, 0)
	entry.resized.connect(func() -> void: entry.pivot_offset = entry.size / 2.0)
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
	box.add_theme_constant_override("separation", 6)
	entry.add_child(box)

	var pack_holder := CenterContainer.new()
	pack_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pack_holder)
	var pack := TextureRect.new()
	pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack.texture = PACK_TEXTURE
	pack.self_modulate = pack_color
	var shine := ShaderMaterial.new()
	shine.shader = SHINE_SHADER
	shine.set_shader_parameter("time_offset", entries.size() * SHINE_STAGGER)
	shine.set_shader_parameter("shading_map", SHADING_MAP)
	pack.material = shine
	pack_holder.add_child(pack)

	box.add_child(_centered(_label(booster["name"], 20, TEXT_COLOR)))
	box.add_child(_centered(_label("%d$" % booster["price"], 22, PRICE_COLOR)))
	box.add_child(_centered(_label("%d cards" % booster["cards"], 15, MUTED_COLOR)))
	box.add_child(_centered(_label(booster["contents"], 15, MUTED_COLOR)))
	var rank_label := _centered(_label("", 15, MUTED_COLOR))
	box.add_child(rank_label)
	_rank_labels.append(rank_label)
	var footer := _centered(_label("", 18, SELECTED_COLOR))
	footer.custom_minimum_size = Vector2(0, 26)
	footer.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	box.add_child(footer)
	_footers.append(footer)
	return entry


static func pack_tint(booster: Dictionary) -> Color:
	return booster.get("tint", PACK_COLOR)


static func rank_text(booster: Dictionary, match_number: int) -> String:
	var low := BoosterWindow.lowest_rank(booster, match_number)
	var high: int = clampi(booster.get("max_rank", BoosterWindow.MAX_RANK), low, BoosterWindow.MAX_RANK)
	return "Rank %d" % low if low == high else "Ranks %d-%d" % [low, high]


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


func open() -> void:
	_cancel_confirm()
	_hint_label.visible = show_hint
	_layout_entries()
	show()


func close() -> void:
	if not visible:
		return
	_cancel_confirm()
	hide()
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		click_at(get_global_transform() * event.position)


func click_at(point: Vector2) -> void:
	for i in entries.size():
		if entries[i].visible and entries[i].get_global_rect().has_point(point):
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
	_cancel_confirm()
	if not PlayerDataManager.buy_booster(PlayerDataManager.BOOSTERS[index]):
		deny(index)
		return
	hide()


func deny(index: int) -> void:
	if _deny_tween:
		_deny_tween.kill()
	var entry := entries[index]
	var footer := _footers[index]
	footer.text = NOT_ENOUGH_MONEY_TEXT
	footer.modulate = DENY_COLOR
	entry.rotation = 0.0
	denied.emit()
	_deny_tween = create_tween()
	for angle in [0.04, -0.04, 0.025, -0.025, 0.0]:
		_deny_tween.tween_property(entry, "rotation", angle, 0.04)
	_deny_tween.tween_interval(1.2)
	_deny_tween.tween_callback(func() -> void:
		if _confirm_index != index:
			footer.text = ""
			footer.modulate = Color.WHITE)


func _on_money_changed(money: int) -> void:
	_cash_label.text = "%d$" % money


func _cancel_confirm() -> void:
	if _confirm_index < 0:
		return
	_styles[_confirm_index].border_color = BORDER_COLOR
	_footers[_confirm_index].text = ""
	_confirm_index = -1
