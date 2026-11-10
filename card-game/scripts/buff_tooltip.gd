extends CanvasLayer
class_name BuffTooltip

enum Concept { PILL, PANEL, BADGES }

const SETTING := "rauchen/ui/buff_tooltip_concept"
const CONCEPT_NAMES := ["Pill", "Panel", "Badges"]
const CARD_GROUP := "card_visuals"
const SMOKE_ICON := preload("res://sprites/suit_Smoke.png")
const ALK_ICON := preload("res://sprites/suit_Alk.png")
const UP_COLOR := Color(0.4, 1.0, 0.45)
const DOWN_COLOR := Color(1.0, 0.4, 0.4)
const MUTED_COLOR := Color(0.75, 0.72, 0.66)
const BG_COLOR := Color(0.07, 0.06, 0.05, 0.94)
const BORDER_COLOR := Color(0.85, 0.75, 0.5)
const UP_CHIP_COLOR := Color(0.08, 0.32, 0.12, 0.95)
const DOWN_CHIP_COLOR := Color(0.4, 0.08, 0.08, 0.95)
const TOOLTIP_LAYER := 90
const GAP := 8.0
const SCREEN_MARGIN := 6.0
const FADE_TIME := 0.1
const ICON_SIZE := Vector2(18, 18)
const BADGE_ICON_SIZE := Vector2(9, 9)
const BADGE_FONT_SIZE := 11
const BADGE_TOP := 30.0

static var _concept := -1
static var _instance: BuffTooltip

var _target: CardVisual
var _box: Control
var _key := ""
var _fade: Tween


static func get_concept() -> Concept:
	if _concept < 0:
		_concept = clampi(int(ProjectSettings.get_setting(SETTING, Concept.PILL)), 0, Concept.size() - 1)
	return _concept as Concept


static func set_concept(value: Concept, tree: SceneTree) -> void:
	_concept = value
	tree.call_group(CARD_GROUP, "refresh_buff_badges")
	if is_instance_valid(_instance):
		_instance._key = ""


static func cycle_concept(tree: SceneTree) -> void:
	set_concept(((get_concept() + 1) % Concept.size()) as Concept, tree)


static func concept_name() -> String:
	return CONCEPT_NAMES[get_concept()]


static func show_for(card_visual: CardVisual) -> void:
	if card_visual.card == null or not card_visual.is_inside_tree():
		return
	if not is_instance_valid(_instance):
		_instance = BuffTooltip.new()
		card_visual.get_tree().root.add_child(_instance)
	_instance._set_target(card_visual)


static func hide_for(card_visual: CardVisual) -> void:
	if is_instance_valid(_instance) and _instance._target == card_visual:
		_instance._set_target(null)


static func part_text(part: Dictionary) -> String:
	var count := int(part.get("count", 0))
	var text := ""
	match part.get("kind"):
		"smoke":
			text = "%d cigarette%s" % [count, "" if count == 1 else "s"]
		_:
			text = "%d round%s of drinks" % [count, "" if count == 1 else "s"]
	if part.get("capped", false):
		text += " (min %d)" % int(part.get("floor", 1))
	return text


static func part_icon(part: Dictionary) -> Texture2D:
	return SMOKE_ICON if part.get("kind") == "smoke" else ALK_ICON


static func signed(amount: int) -> String:
	return ("+%d" if amount >= 0 else "-%d") % absi(amount)


static func amount_color(amount: int) -> Color:
	if amount > 0:
		return UP_COLOR
	if amount < 0:
		return DOWN_COLOR
	return MUTED_COLOR


static func rank_color(card: Card) -> Color:
	return amount_color(card.rank - card.base_rank)


static func build_badges(card: Card) -> Control:
	var column := VBoxContainer.new()
	column.name = "BuffBadges"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	for part in card.buff_parts:
		var amount := int(part.get("amount", 0))
		if amount == 0:
			continue
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("panel", _style(UP_CHIP_COLOR if amount > 0 else DOWN_CHIP_COLOR, amount_color(amount), 1, 3, Vector2(3, 0)))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		row.add_child(_icon(part_icon(part), BADGE_ICON_SIZE))
		row.add_child(_label(signed(amount), amount_color(amount), BADGE_FONT_SIZE))
		chip.add_child(row)
		column.add_child(chip)
	if column.get_child_count() == 0:
		column.free()
		return null
	return column


func _ready() -> void:
	layer = TOOLTIP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _set_target(card_visual: CardVisual) -> void:
	if card_visual == _target:
		return
	_target = card_visual
	_key = ""
	if _target == null:
		_clear()


func _process(_delta: float) -> void:
	if not _should_show():
		if _box != null:
			_clear()
		return
	var key := str(get_concept(), _target.card.rank, _target.card.buff_parts)
	if key != _key:
		_key = key
		_rebuild()
	_place()


func _should_show() -> bool:
	if not is_instance_valid(_target) or _target.card == null:
		return false
	if _target.face_down or _target.dragging or not _target.is_visible_in_tree():
		return false
	return not _target.card.buff_parts.is_empty()


func _clear() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if _box != null:
		_box.queue_free()
	_box = null
	_key = ""


func _rebuild() -> void:
	var fresh := _box == null
	if _box != null:
		_box.queue_free()
	match get_concept():
		Concept.PILL:
			_box = _build_pill(_target.card)
		Concept.PANEL:
			_box = _build_panel(_target)
		_:
			_box = _build_detail(_target.card)
	add_child(_box)
	_box.reset_size()
	if fresh:
		_box.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_box, "modulate:a", 1.0, FADE_TIME)


func _place() -> void:
	_box.reset_size()
	var card_rect := _card_rect()
	var view := get_viewport().get_visible_rect().size
	var box_size := _box.size
	var pos := Vector2.ZERO
	if get_concept() == Concept.PANEL:
		pos = Vector2(card_rect.end.x + GAP, card_rect.get_center().y - box_size.y * 0.5)
		if pos.x + box_size.x > view.x - SCREEN_MARGIN:
			pos.x = card_rect.position.x - GAP - box_size.x
	else:
		pos = Vector2(card_rect.get_center().x - box_size.x * 0.5, card_rect.position.y - GAP - box_size.y)
		if pos.y < SCREEN_MARGIN:
			pos.y = card_rect.end.y + GAP
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.x - box_size.x - SCREEN_MARGIN))
	pos.y = clampf(pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.y - box_size.y - SCREEN_MARGIN))
	_box.position = pos.round()


func _card_rect() -> Rect2:
	var xf := _target.get_global_transform_with_canvas()
	var rect := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(_target.size.x, 0), _target.size, Vector2(0, _target.size.y)]:
		rect = rect.expand(xf * corner)
	return rect


func _build_pill(card: Card) -> Control:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _style(BG_COLOR, BORDER_COLOR, 2, 14, Vector2(10, 2)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	row.add_child(_label(str(card.base_rank), Color.WHITE))
	for part in card.buff_parts:
		var amount := int(part.get("amount", 0))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(2, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		row.add_child(_label(signed(amount), amount_color(amount)))
		row.add_child(_icon(part_icon(part), ICON_SIZE))
		if part.get("capped", false):
			row.add_child(_label("min %d" % int(part.get("floor", 1)), MUTED_COLOR, _font(12)))
	row.add_child(_label("=", MUTED_COLOR))
	row.add_child(_label(str(card.rank), rank_color(card), _font(20)))
	return pill


func _build_panel(card_visual: CardVisual) -> Control:
	var card := card_visual.card
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(BG_COLOR, BORDER_COLOR, 2, 0, Vector2(10, 8)))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	column.add_child(_label("RANK", BORDER_COLOR, _font(12)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	_panel_row(grid, card_visual.suit_to_texture(card), "Base", str(card.base_rank), Color.WHITE)
	for part in card.buff_parts:
		var amount := int(part.get("amount", 0))
		_panel_row(grid, part_icon(part), part_text(part), signed(amount), amount_color(amount))
	var line := ColorRect.new()
	line.color = BORDER_COLOR
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	var total := HBoxContainer.new()
	total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(total)
	var total_label := _label("Now", MUTED_COLOR)
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(total_label)
	total.add_child(_label(str(card.rank), rank_color(card), _font(20)))
	return panel


func _panel_row(grid: GridContainer, icon: Texture2D, text: String, amount: String, color: Color) -> void:
	grid.add_child(_icon(icon, ICON_SIZE))
	var name_label := _label(text, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var amount_label := _label(amount, color)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(amount_label)


func _build_detail(card: Card) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(BG_COLOR, BORDER_COLOR, 1, 4, Vector2(8, 4)))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_label("Base rank %d" % card.base_rank, Color.WHITE, _font(14)))
	for part in card.buff_parts:
		var amount := int(part.get("amount", 0))
		var source := "smoking" if part.get("kind") == "smoke" else "drinking"
		column.add_child(_label("%s %s: %s" % [signed(amount), source, part_text(part)], amount_color(amount), _font(14)))
	column.add_child(_label("= %d" % card.rank, rank_color(card), _font(14)))
	return panel


static func _style(bg: Color, border: Color, border_width: int, radius: int, padding: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	style.anti_aliasing = false
	return style


static func _label(text: String, color: Color, font_size: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


static func _icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


static func _font(base: int) -> int:
	return InteractionManager.font_px(base)
