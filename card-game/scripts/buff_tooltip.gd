extends CanvasLayer
class_name BuffTooltip

const SMOKE_ICON := preload("res://sprites/suit_Smoke.png")
const ALK_ICON := preload("res://sprites/suit_Alk.png")
const UP_COLOR := Color(0.4, 1.0, 0.45)
const DOWN_COLOR := Color(1.0, 0.4, 0.4)
const MUTED_COLOR := Color(0.75, 0.72, 0.66)
const BG_COLOR := Color(0.07, 0.06, 0.05, 0.94)
const BORDER_COLOR := Color(0.85, 0.75, 0.5)
const TOOLTIP_LAYER := 90
const GAP := 8.0
const SCREEN_MARGIN := 6.0
const ICON_SIZE := Vector2(18, 18)
const TEXT_WIDTH := 190.0

static var _instance: BuffTooltip

var _target: CardVisual
var _box: Control
var _key := ""


static func show_for(card_visual: CardVisual, on_layer: int = TOOLTIP_LAYER) -> void:
	if card_visual.card == null or not card_visual.is_inside_tree():
		return
	if not is_instance_valid(_instance):
		_instance = BuffTooltip.new()
		card_visual.get_tree().root.add_child(_instance)
	_instance.layer = on_layer
	_instance._set_target(card_visual)


static func hide_for(card_visual: CardVisual) -> void:
	if is_instance_valid(_instance) and _instance._target == card_visual:
		_instance._set_target(null)


static func part_icon(part: Dictionary) -> Texture2D:
	match part.get("kind"):
		"smoke":
			return SMOKE_ICON
		"suit_up":
			return null
	return ALK_ICON


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
	var key := str(_target.card.rank, _target.card.buff_parts, _target.card.effect, _target.card.stamp)
	if key != _key:
		_key = key
		_rebuild()
	_place()


func _should_show() -> bool:
	if not is_instance_valid(_target) or _target.card == null:
		return false
	if _target.face_down or _target.dragging or not _target.is_visible_in_tree():
		return false
	return not _target.card.buff_parts.is_empty() or _target.card.has_effect() or _target.card.has_stamp()


func _clear() -> void:
	if _box != null:
		_box.queue_free()
	_box = null
	_key = ""


func _rebuild() -> void:
	if _box != null:
		_box.queue_free()
	_box = _build_pill(_target.card)
	add_child(_box)
	_box.reset_size()


func _place() -> void:
	_box.reset_size()
	var card_rect := _card_rect()
	var view := get_viewport().get_visible_rect().size
	var box_size := _box.size
	var pos := Vector2(card_rect.get_center().x - box_size.x * 0.5, card_rect.position.y - GAP - box_size.y)
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
	pill.add_theme_stylebox_override("panel", _style(BG_COLOR, BORDER_COLOR, 2, 6, Vector2(10, 6)))
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 6)
	pill.add_child(lines)
	if not card.buff_parts.is_empty():
		lines.add_child(_buff_row(card))
	if card.has_effect():
		lines.add_child(effect_row(card.effect, _font(14)))
	if card.has_stamp():
		lines.add_child(stamp_row(card.stamp, _font(14)))
	return pill


static func stamp_row(stamp: int, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var badge := StampBadge.create(stamp)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	column.add_child(_label(CardStamp.display_name(stamp) + " stamp", CardStamp.color(stamp).lightened(0.3), font_size))
	column.add_child(_wrapped(CardStamp.description(stamp), font_size))
	row.add_child(column)
	return row


static func effect_row(effect: int, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var badge := EffectBadge.create(effect)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	row.add_child(_wrapped(CardEffect.description(effect), font_size))
	return row


func _buff_row(card: Card) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var total := _label(str(card.rank), rank_color(card), _font(20))
	var line_height := total.get_combined_minimum_size().y
	row.add_child(_top(_label(str(card.base_rank), Color.WHITE), line_height))
	for part in card.buff_parts:
		var amount := int(part.get("amount", 0))
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		column.add_theme_constant_override("separation", 0)
		var number := _top(_label(signed(amount), amount_color(amount)), line_height)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(number)
		var icon := _icon(part_icon(part), ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		if part.get("capped", false):
			var floor_label := _label("min %d" % int(part.get("floor", 1)), MUTED_COLOR, _font(12))
			floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(floor_label)
		row.add_child(column)
	row.add_child(_top(_label("=", MUTED_COLOR), line_height))
	row.add_child(_top(total, line_height))
	return row


static func _top(label: Label, line_height: float) -> Label:
	label.custom_minimum_size.y = line_height
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


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


static func _wrapped(text: String, font_size: int) -> Label:
	var label := _label(text, Color.WHITE, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TEXT_WIDTH
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
