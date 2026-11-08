extends Control
class_name BoosterShelf

signal closed
signal denied

const PANEL_RECT := Rect2(206, 104, 740, 440)
const ENTRY_SIZE := Vector2(222, 300)
const ENTRY_GAP := 18.0
const ENTRY_PADDING := Vector2(18, 16)
const BG_COLOR := Color("17161c")
const BORDER_COLOR := Color("6b6390")
const TEXT_COLOR := Color("ffffff")
const MUTED_COLOR := Color("d6d1e6")
const PRICE_COLOR := Color("ffcf6e")
const SELECTED_COLOR := Color("ffcf6e")
const DENY_COLOR := Color(1.0, 0.45, 0.4)
const CONFIRM_TEXT := "Really?"
const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const PACK_COLORS: Array[Color] = [Color(0.8, 0.8, 0.84, 1), Color(0.78, 0.88, 1.0, 1), Color(1.0, 0.86, 0.6, 1), Color(0.72, 1.0, 0.78, 1)]
const PACK_TEXTURE := preload("res://sprites/booster_pack.png")
const SHINE_SHADER := preload("res://shaders/booster_shine.gdshader")
const SHADING_MAP := preload("res://sprites/booster_pack_map.png")
const SHINE_STAGGER := 0.35

var entries: Array[PanelContainer] = []
var _footers: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []
var _confirm_index := -1
var _deny_tween: Tween
var _cash_label: Label


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

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override("panel", _box_style(BORDER_COLOR))
	add_child(panel)

	var title := HeadlineLabel.new()
	title.text = "Booster Shelf"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = PANEL_RECT.position + Vector2(0, 18)
	title.size = Vector2(PANEL_RECT.size.x, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_cash_label = _label("", 22, PRICE_COLOR)
	_cash_label.position = PANEL_RECT.position + Vector2(PANEL_RECT.size.x - 140, 20)
	_cash_label.size = Vector2(120, 32)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cash_label)
	PlayerDataManager.money_changed.connect(_on_money_changed)
	_on_money_changed(PlayerDataManager.money)

	for i in PlayerDataManager.BOOSTERS.size():
		var entry := _build_entry(PlayerDataManager.BOOSTERS[i], pack_tint(i))
		add_child(entry)
		entries.append(entry)
	_layout_entries()

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size = Vector2(110, 32)
	close_button.position = Vector2(PANEL_RECT.get_center().x - 55, PANEL_RECT.end.y - 50)
	close_button.pressed.connect(close)
	add_child(close_button)


func _layout_entries() -> void:
	var shown: Array[PanelContainer] = []
	for i in entries.size():
		entries[i].visible = PlayerDataManager.is_booster_available(PlayerDataManager.BOOSTERS[i])
		if entries[i].visible:
			shown.append(entries[i])
	if shown.is_empty():
		return
	var fit_width := (PANEL_RECT.size.x - (shown.size() + 1) * ENTRY_GAP) / shown.size()
	var entry_size := Vector2(minf(ENTRY_SIZE.x, fit_width), ENTRY_SIZE.y)
	var row_width := shown.size() * entry_size.x + (shown.size() - 1) * ENTRY_GAP
	var left := PANEL_RECT.get_center().x - row_width / 2.0
	for i in shown.size():
		shown[i].custom_minimum_size = entry_size
		shown[i].size = entry_size
		shown[i].pivot_offset = entry_size / 2.0
		shown[i].position = Vector2(left + i * (entry_size.x + ENTRY_GAP), PANEL_RECT.position.y + 70)


func _build_entry(booster: Dictionary, pack_color: Color) -> PanelContainer:
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
	var ranks := "Rank %d" % booster["min_rank"] if booster["min_rank"] == booster["max_rank"] else "Ranks %d-%d" % [booster["min_rank"], booster["max_rank"]]
	box.add_child(_centered(_label(ranks, 15, MUTED_COLOR)))
	var footer := _centered(_label("", 18, SELECTED_COLOR))
	footer.custom_minimum_size = Vector2(0, 26)
	box.add_child(footer)
	_footers.append(footer)
	return entry


static func pack_tint(index: int) -> Color:
	return PACK_COLORS[index % PACK_COLORS.size()]


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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func open() -> void:
	_cancel_confirm()
	_layout_entries()
	show()
	_layout_entries.call_deferred()


func close() -> void:
	if not visible:
		return
	_cancel_confirm()
	hide()
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		click_at(event.position)


func click_at(point: Vector2) -> void:
	for i in entries.size():
		if entries[i].visible and entries[i].get_rect().has_point(point):
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
