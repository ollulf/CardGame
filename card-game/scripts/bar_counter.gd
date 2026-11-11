extends Control
class_name BarCounter

signal stamp_clicked(index: int)
signal booster_clicked(index: int)
signal smokes_clicked
signal drinks_clicked

const ART_SCALE := 3
const MAT := Color("1c1a1c")
const MAT_EDGE := Color("0e0c0e")
const PAPER := Color("e8d6aa")
const PAPER_D := Color("b8a47a")
const INK := Color("1a1412")
const TEXT := Color("f3e6c4")
const MUTED := Color("d6d1e6")
const PANEL_BG := Color(0.09, 0.086, 0.11, 0.92)
const PANEL_BORDER := Color("6b6390")
const TIP_BG := Color(0.0901961, 0.0862745, 0.109804, 0.96)
const LOCKED := Color(0.55, 0.55, 0.55)
const STAMP_SLOTS := [Vector2(420, 150), Vector2(580, 150), Vector2(740, 150)]
const BOOSTER_SLOTS := [Vector2(420, 390), Vector2(580, 390), Vector2(740, 390)]
const STAMP_TILT := [-3.0, 2.0, -1.5]
const BOOSTER_TILT := [-6.0, 3.0, -2.0]
const STAMP_MAT := Rect2(300, 40, 560, 230)
const BOOSTER_MAT := Rect2(300, 290, 560, 250)
const LEFT_PANEL := Rect2(24, 40, 230, 470)
const ITEMS_MAT := Rect2(880, 40, 248, 500)
const ITEM_SLOTS := [Vector2(1004, 150), Vector2(1004, 390)]
const COASTER_OFFSET := Vector2(0, 22)
const DRINKS_TITLE := "Round of drinks"
const DRINKS_DESCRIPTION := "Everyone at the table drinks: drinking cards +1, all others -1 for the match."
const PACK_SIZE := Vector2(64, 120)
const SLIP_SIZE := Vector2i(46, 52)
const HOVER_LIFT := Vector2(0, -10)
const HOVER_SCALE := 1.15
const HOVER_BORDER_PAD := 7.0
const HOVER_SHADOW_LIFT := 8.0
const HOVER_BOB := 3.0
const HOVER_BOB_SPEED := 3.0
const SOLD_OUT_TEXTURE := preload("res://sprites/sold_out_sign.png")

var stamp_items: Array[CigaretteMachine] = []
var booster_items: Array[CigaretteMachine] = []
var smokes: CigaretteMachine
var _smokes_extras: Array[Label] = []
var drinks: CigaretteMachine
var match_label: Label
var _stamp_tags: Array[Label] = []
var _booster_tags: Array[Label] = []
var _coaster: TextureRect
var _drinks_note := ""
var _drinks_tag: Label
var _booster_offers: Array[int] = []
var _stamp_offers: Array[int] = []
var _stamps_locked_text := ""
var _hovered: CigaretteMachine
var _hover_tweens := {}
var _hover_time := 0.0
var shop_tooltip: ShopTooltip
var _booster_signs: Array[Control] = []
var _stamps_sign: Control
var _items_sign: Control

static var _slip_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = RenderingServer.get_default_clear_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_panel(LEFT_PANEL, PANEL_BG, PANEL_BORDER)
	_label("THE BAR", LEFT_PANEL.position + Vector2(0, 14), 26, Color.WHITE, LEFT_PANEL.size.x)
	match_label = _label("", LEFT_PANEL.position + Vector2(0, 50), 15, MUTED, LEFT_PANEL.size.x)
	_mat(STAMP_MAT, "STAMPS")
	_mat(BOOSTER_MAT, "BOOSTERS")
	_mat(ITEMS_MAT, "ITEMS")
	for i in STAMP_SLOTS.size():
		_build_stamp_slot(i)
	for i in BOOSTER_SLOTS.size():
		_build_booster_slot(i)
	_build_smokes(ITEM_SLOTS[0])
	_build_drinks(ITEM_SLOTS[1])
	for i in BOOSTER_SLOTS.size():
		_booster_signs.append(_sold_out_sign(BOOSTER_SLOTS[i], BOOSTER_TILT[i]))
	_stamps_sign = _sold_out_sign(STAMP_MAT.get_center() + Vector2(0, 10), STAMP_TILT[0])
	_items_sign = _sold_out_sign(ITEM_SLOTS[0], -4.0)
	shop_tooltip = ShopTooltip.new()
	add_child(shop_tooltip)


func set_match_text(text: String) -> void:
	match_label.text = text


func show_stamps(offers: Array[int], locked: bool, locked_text: String) -> void:
	_stamps_locked_text = locked_text if locked else ""
	_stamps_sign.visible = offers.is_empty()
	for i in stamp_items.size():
		var has_offer := i < offers.size()
		stamp_items[i].visible = has_offer
		_stamp_tags[i].visible = has_offer
		_stamp_offers[i] = offers[i] if has_offer else -1
		if not has_offer:
			_end_hover_if(stamp_items[i])
			continue
		var id: int = offers[i]
		stamp_items[i].sprite.texture = _slip(id)
		stamp_items[i].sprite.modulate = LOCKED if locked else Color.WHITE
		_stamp_tags[i].text = "%d$" % CardStamp.price(id)
	_refresh_hover_tip()


func show_boosters(offers: Array[int]) -> void:
	for i in booster_items.size():
		var index: int = offers[i] if i < offers.size() else -1
		var has_offer := index >= 0
		booster_items[i].visible = has_offer
		_booster_tags[i].visible = has_offer
		_booster_offers[i] = index
		_booster_signs[i].visible = not has_offer
		if not has_offer:
			_end_hover_if(booster_items[i])
			continue
		var booster: Dictionary = PlayerDataManager.BOOSTERS[index]
		booster_items[i].sprite.texture = BoosterArt.pack_texture(booster)
		booster_items[i].sprite.self_modulate = BoosterArt.pack_tint(booster)
		_booster_tags[i].text = "%d$" % int(booster["price"])
	_refresh_hover_tip()


func show_smokes(available: bool, label_text: String) -> void:
	smokes.visible = available
	_items_sign.visible = not available
	for extra in _smokes_extras:
		extra.visible = available
	smokes.set_label_text(label_text)


func show_drinks(available: bool, label_text: String, ordered := false) -> void:
	drinks.visible = available
	_coaster.visible = available
	_drinks_tag.visible = available
	drinks.set_label_text(label_text)
	_drinks_note = label_text if ordered else ""
	if not available:
		_end_hover_if(drinks)
	_refresh_hover_tip()


func first_stamp_item() -> CanvasItem:
	for item in stamp_items:
		if item.visible:
			return item.sprite
	return null


func first_booster_sprite() -> CanvasItem:
	for item in booster_items:
		if item.visible:
			return item.sprite
	return null


func _build_stamp_slot(i: int) -> void:
	var center: Vector2 = STAMP_SLOTS[i]
	var size_px := Vector2(SLIP_SIZE) * 2.0
	var item := _item(size_px, center - size_px * 0.5 + Vector2(0, -10))
	item.sprite.pivot_offset = size_px * 0.5
	item.sprite.rotation_degrees = STAMP_TILT[i]
	item.clicked.connect(func() -> void: stamp_clicked.emit(i))
	stamp_items.append(item)
	_stamp_offers.append(-1)
	_add_hover(item, STAMP_TILT[i], _stamp_tip.bind(i))
	_stamp_tags.append(_tag(center + Vector2(0, 66)))


func _build_booster_slot(i: int) -> void:
	var center: Vector2 = BOOSTER_SLOTS[i]
	var item := _item(PACK_SIZE, center - PACK_SIZE * 0.5 + Vector2(0, -6))
	item.sprite.texture = BoosterArt.PACK_TEXTURE
	item.sprite.pivot_offset = PACK_SIZE * 0.5
	item.sprite.rotation_degrees = BOOSTER_TILT[i]
	var shine := ShaderMaterial.new()
	shine.shader = BoosterArt.SHINE_SHADER
	shine.set_shader_parameter("time_offset", i * BoosterArt.SHINE_STAGGER)
	shine.set_shader_parameter("shading_map", BoosterArt.SHADING_MAP)
	item.sprite.material = shine
	item.clicked.connect(func() -> void: booster_clicked.emit(i))
	booster_items.append(item)
	_booster_offers.append(-1)
	_add_hover(item, BOOSTER_TILT[i], _booster_tip.bind(i))
	_booster_tags.append(_tag(center + Vector2(0, 80)))


func _stamp_tip(i: int) -> Array:
	var id := _stamp_offers[i]
	if id < 0:
		return []
	var body := ShopTooltip.highlight_numbers(CardStamp.description(id))
	if _stamps_locked_text != "":
		body += "\n[color=#%s]%s[/color]" % [ShopTooltip.LOCKED, _stamps_locked_text]
	return [CardStamp.display_name(id), body]


func _booster_tip(i: int) -> Array:
	if _booster_offers[i] < 0:
		return []
	var booster: Dictionary = PlayerDataManager.BOOSTERS[_booster_offers[i]]
	return [String(booster.get("name", "Booster")), ShopTooltip.describe(booster, DialogueManager.upcoming_match())]


func _add_hover(item: CigaretteMachine, tilt: float, tip: Callable) -> void:
	item.tooltip_enabled = false
	item.hover_offset = HOVER_LIFT
	item.set_meta("tilt", tilt)
	item.set_meta("tip", tip)
	var border := Panel.new()
	border.name = "HoverBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.visible = false
	border.position = -Vector2.ONE * HOVER_BORDER_PAD
	border.size = item.size + Vector2.ONE * HOVER_BORDER_PAD * 2.0
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = ShopTooltip.EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	border.add_theme_stylebox_override("panel", style)
	item.sprite.add_child(border)
	item.mouse_entered.connect(_set_hover.bind(item, true))
	item.mouse_exited.connect(_set_hover.bind(item, false))


func _end_hover_if(item: CigaretteMachine) -> void:
	if _hovered == item:
		_set_hover(item, false)


func _set_hover(item: CigaretteMachine, on: bool) -> void:
	if on and (item.get_meta("tip") as Callable).call().is_empty():
		return
	if not on and _hovered != item:
		return
	_hovered = item if on else null
	item.z_index = 1 if on else 0
	item.sprite.get_node("HoverBorder").visible = on
	var shadow := TableShadow.add_to(item.sprite)
	if _hover_tweens.has(item):
		(_hover_tweens[item] as Tween).kill()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item.sprite, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.18)
	tween.tween_property(item.sprite, "rotation_degrees", 0.0 if on else float(item.get_meta("tilt")), 0.18)
	tween.tween_property(shadow, "lift", HOVER_SHADOW_LIFT if on else 0.0, 0.18)
	_hover_tweens[item] = tween
	if on:
		_hover_time = 0.0
		_refresh_hover_tip()
	else:
		shop_tooltip.hide()


func _refresh_hover_tip() -> void:
	if _hovered == null:
		return
	var tip: Array = (_hovered.get_meta("tip") as Callable).call()
	if tip.is_empty():
		return
	var anchor := Rect2(_hovered.position, _hovered.size).grow(HOVER_BORDER_PAD * HOVER_SCALE)
	shop_tooltip.show_text(tip[0], tip[1], anchor)


func _process(delta: float) -> void:
	if _hovered == null or _hovered.is_denying():
		return
	_hover_time += delta
	_hovered.sprite.position = HOVER_LIFT + Vector2(0, sin(_hover_time * HOVER_BOB_SPEED) * HOVER_BOB)


func _build_smokes(center: Vector2) -> void:
	var tex: Texture2D = preload("res://sprites/Cigarettes_icon.png")
	var size_px := tex.get_size() * 3.0
	smokes = _item(size_px, (center - size_px * 0.5).floor() + Vector2(0, -10))
	smokes.sprite.texture = tex
	smokes.sprite.pivot_offset = size_px * 0.5
	smokes.sprite.rotation_degrees = 8.0
	smokes.clicked.connect(smokes_clicked.emit)
	_smokes_extras.append(_label("Smokes", center + Vector2(-80, 46), 15, TEXT, 160))
	_smokes_extras.append(_tag(center + Vector2(0, 84)))
	_smokes_extras[1].text = "%d$" % PlayerDataManager.CIGARETTE_PACK_PRICE


func _build_drinks(center: Vector2) -> void:
	_coaster = TextureRect.new()
	_coaster.texture = preload("res://sprites/Bierdeckel.png")
	_coaster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_coaster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coaster.scale = Vector2(3, 3)
	_coaster.pivot_offset = Vector2(12, 12)
	_coaster.rotation_degrees = -8.0
	_coaster.position = center + COASTER_OFFSET - _coaster.pivot_offset
	add_child(_coaster)
	TableShadow.add_to(_coaster)
	var tex: Texture2D = preload("res://sprites/bar/bar_beer_tap.png")
	var size_px := tex.get_size() * ART_SCALE
	drinks = _item(size_px, (center - size_px * 0.5).floor() + Vector2(0, -10))
	drinks.sprite.texture = tex
	drinks.sprite.pivot_offset = size_px * 0.5
	drinks.clicked.connect(drinks_clicked.emit)
	_add_hover(drinks, 0.0, _drinks_tip)
	_drinks_tag = _tag(center + Vector2(0, 84))
	_drinks_tag.text = "%d$" % PlayerDataManager.DRINK_ROUND_PRICE


func _drinks_tip() -> Array:
	if not drinks.visible:
		return []
	var body := ShopTooltip.highlight_numbers(DRINKS_DESCRIPTION)
	if _drinks_note != "":
		body += "
[color=#%s]%s[/color]" % [ShopTooltip.LOCKED, _drinks_note]
	return [DRINKS_TITLE, body]


func _item(size_px: Vector2, pos: Vector2) -> CigaretteMachine:
	var item := CigaretteMachine.new()
	item.position = pos
	item.size = size_px
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.size = size_px
	item.add_child(sprite)
	var tip := Label.new()
	tip.name = "Tooltip"
	tip.visible = false
	tip.z_index = 10
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.size = Vector2(240, 32)
	tip.position = Vector2((size_px.x - 240.0) * 0.5, -44)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = TIP_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tip.add_theme_stylebox_override("normal", style)
	tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	item.add_child(tip)
	add_child(item)
	TableShadow.add_to(sprite)
	return item


func _panel(r: Rect2, bg: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = r.position
	panel.size = r.size
	add_child(panel)
	return panel


func _mat(r: Rect2, title: String) -> void:
	var panel := _panel(r, MAT, MAT_EDGE)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(4, 8)
	style.shadow_size = 2
	_label(title, r.position + Vector2(14, 6), 18, MUTED)


func _label(text: String, pos: Vector2, font_size: int, color: Color, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	if width > 0.0:
		label.size.x = width
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _sold_out_sign(center: Vector2, tilt: float) -> Control:
	var size_px := SOLD_OUT_TEXTURE.get_size() * ART_SCALE
	var sign := TextureRect.new()
	sign.texture = SOLD_OUT_TEXTURE
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.size = size_px
	sign.position = center - size_px * 0.5
	sign.pivot_offset = size_px * 0.5
	sign.rotation_degrees = tilt
	sign.visible = false
	add_child(sign)
	TableShadow.add_to(sign)
	return sign


func _tag(center: Vector2) -> Label:
	var tag := Label.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size = Vector2(56, 28)
	tag.position = center - tag.size * 0.5
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", INK)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(2, 4)
	tag.add_theme_stylebox_override("normal", style)
	add_child(tag)
	return tag


static func _slip(id: int) -> ImageTexture:
	if _slip_cache.has(id):
		return _slip_cache[id]
	var image := Image.create(SLIP_SIZE.x, SLIP_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(0, 2, 40, 48), PAPER_D)
	image.fill_rect(Rect2i(1, 3, 38, 46), PAPER)
	image.fill_rect(Rect2i(1, 47, 38, 2), PAPER.darkened(0.08))
	var imprint := StampArt.imprint(id).get_image()
	imprint.resize(imprint.get_width() * 2, imprint.get_height() * 2, Image.INTERPOLATE_NEAREST)
	for y in imprint.get_height():
		for x in imprint.get_width():
			var ink := imprint.get_pixel(x, y)
			if ink.a > 0.0:
				imprint.set_pixel(x, y, ink.darkened(0.2))
	image.blend_rect(imprint, Rect2i(Vector2i.ZERO, imprint.get_size()), Vector2i(5, 8))
	var tool := StampArt.tool(id).get_image()
	image.blend_rect(tool, Rect2i(Vector2i.ZERO, tool.get_size()), Vector2i(35, 34))
	_slip_cache[id] = ImageTexture.create_from_image(image)
	return _slip_cache[id]

