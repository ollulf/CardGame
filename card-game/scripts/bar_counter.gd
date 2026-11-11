extends Control
class_name BarCounter

signal stamp_clicked(index: int)
signal booster_clicked(index: int)
signal smokes_clicked
signal drinks_clicked

const ART_SCALE := 3
const ART_SIZE := Vector2i(384, 216)
const WOOD := [Color("5a3820"), Color("62402a"), Color("553522"), Color("5e3c24")]
const SEAM := Color("2e1c14")
const GRAIN := Color("4a2e1e")
const BACK := Color("140d12")
const EDGE := Color("8a5a34")
const EDGE_D := Color("3a2618")
const BRASS := Color("c89a48")
const RING := Color("3e2616")
const BUTT := Color("d8d0b8")
const BUTT_D := Color("8a7a60")
const ASH := Color("4a4440")
const SPILL := Color("3a2414")
const MAT := Color("1c1a1c")
const MAT_RIB := Color("262326")
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
const SMOKES_TINT := Color(0.85, 0.32, 0.26)
const STAMP_SLOTS := [Vector2(420, 150), Vector2(580, 150), Vector2(740, 150)]
const BOOSTER_SLOTS := [Vector2(420, 390), Vector2(580, 390), Vector2(740, 390)]
const STAMP_TILT := [-3.0, 2.0, -1.5]
const BOOSTER_TILT := [-6.0, 3.0, -2.0]
const STAMP_MAT := Rect2(300, 40, 560, 230)
const BOOSTER_MAT := Rect2(300, 290, 560, 250)
const LEFT_PANEL := Rect2(24, 40, 230, 470)
const SMOKES_POS := Vector2(914, 86)
const DRINKS_POS := Vector2(150, 360)
const PACK_SIZE := Vector2(64, 120)
const SLIP_SIZE := Vector2i(46, 52)
const SOLD_OUT_TEXT := "Sold out"
const RINGS := [Vector2i(84, 186), Vector2i(292, 40), Vector2i(232, 192), Vector2i(64, 200), Vector2i(366, 196), Vector2i(300, 120)]
const BUTTS := [Vector2i(344, 128), Vector2i(352, 132), Vector2i(200, 174), Vector2i(96, 202), Vector2i(274, 204), Vector2i(48, 174), Vector2i(132, 196), Vector2i(372, 150), Vector2i(290, 186), Vector2i(20, 196)]

var stamp_items: Array[CigaretteMachine] = []
var booster_items: Array[CigaretteMachine] = []
var smokes: CigaretteMachine
var drinks: CigaretteMachine
var match_label: Label
var _stamp_names: Array[Label] = []
var _stamp_tags: Array[Label] = []
var _booster_names: Array[Label] = []
var _booster_tags: Array[Label] = []
var _stamp_sold: Array[Label] = []
var _booster_sold: Array[Label] = []
var _art: TextureRect
var _coaster: TextureRect
var _drinks_name: Label
var _drinks_tag: Label

static var _art_cache := {}
static var _slip_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(_art)
	_panel(LEFT_PANEL, PANEL_BG, PANEL_BORDER)
	_label("THE BAR", LEFT_PANEL.position + Vector2(0, 14), 26, Color.WHITE, LEFT_PANEL.size.x)
	match_label = _label("", LEFT_PANEL.position + Vector2(0, 50), 15, MUTED, LEFT_PANEL.size.x)
	_mat(STAMP_MAT, "STAMPS")
	_mat(BOOSTER_MAT, "BOOSTERS")
	for i in STAMP_SLOTS.size():
		_build_stamp_slot(i)
	for i in BOOSTER_SLOTS.size():
		_build_booster_slot(i)
	_build_smokes()
	_build_drinks()
	set_mess(1)


func set_mess(level: int) -> void:
	_art.texture = _counter_art(clampi(level, 1, 5))


func set_match_text(text: String) -> void:
	match_label.text = text


func show_stamps(offers: Array[int], locked: bool, locked_text: String) -> void:
	for i in stamp_items.size():
		var has_offer := i < offers.size()
		stamp_items[i].visible = has_offer
		_stamp_names[i].visible = has_offer
		_stamp_tags[i].visible = has_offer
		_stamp_sold[i].visible = not has_offer
		if not has_offer:
			continue
		var id: int = offers[i]
		stamp_items[i].sprite.texture = _slip(id)
		stamp_items[i].sprite.modulate = LOCKED if locked else Color.WHITE
		stamp_items[i].set_label_text(locked_text if locked else CardStamp.description(id))
		_stamp_names[i].text = CardStamp.display_name(id)
		_stamp_tags[i].text = "%d$" % CardStamp.price(id)


func show_boosters(offers: Array[int]) -> void:
	for i in booster_items.size():
		var index: int = offers[i] if i < offers.size() else -1
		var has_offer := index >= 0
		booster_items[i].visible = has_offer
		_booster_names[i].visible = has_offer
		_booster_tags[i].visible = has_offer
		_booster_sold[i].visible = not has_offer
		if not has_offer:
			continue
		var booster: Dictionary = PlayerDataManager.BOOSTERS[index]
		booster_items[i].sprite.self_modulate = BoosterShelf.pack_tint(booster)
		booster_items[i].set_label_text("%d cards: %s" % [int(booster["cards"]), String(booster["contents"])])
		_booster_names[i].text = String(booster["name"])
		_booster_tags[i].text = "%d$" % int(booster["price"])


func show_smokes(available: bool, label_text: String) -> void:
	smokes.sprite.modulate = Color.WHITE if available else LOCKED
	smokes.set_label_text(label_text)


func show_drinks(available: bool, label_text: String) -> void:
	drinks.visible = available
	_coaster.visible = available
	_drinks_name.visible = available
	_drinks_tag.visible = available
	drinks.set_label_text(label_text)


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
	_stamp_names.append(_label("", center + Vector2(-80, 46), 15, TEXT, 160))
	_stamp_tags.append(_tag(center + Vector2(0, 84)))
	_stamp_sold.append(_label(SOLD_OUT_TEXT, center + Vector2(-80, -8), 16, Color(MUTED, 0.5), 160))


func _build_booster_slot(i: int) -> void:
	var center: Vector2 = BOOSTER_SLOTS[i]
	var item := _item(PACK_SIZE, center - PACK_SIZE * 0.5 + Vector2(0, -6))
	item.sprite.texture = BoosterShelf.PACK_TEXTURE
	item.sprite.pivot_offset = PACK_SIZE * 0.5
	item.sprite.rotation_degrees = BOOSTER_TILT[i]
	var shine := ShaderMaterial.new()
	shine.shader = BoosterShelf.SHINE_SHADER
	shine.set_shader_parameter("time_offset", i * BoosterShelf.SHINE_STAGGER)
	shine.set_shader_parameter("shading_map", BoosterShelf.SHADING_MAP)
	item.sprite.material = shine
	item.clicked.connect(func() -> void: booster_clicked.emit(i))
	booster_items.append(item)
	_booster_names.append(_label("", center + Vector2(-80, 62), 15, TEXT, 160))
	_booster_tags.append(_tag(center + Vector2(0, 100)))
	_booster_sold.append(_label(SOLD_OUT_TEXT, center + Vector2(-80, -8), 16, Color(MUTED, 0.5), 160))


func _build_smokes() -> void:
	var tex: Texture2D = preload("res://sprites/Cigarettes_icon.png")
	var size_px := tex.get_size() * 4.0
	smokes = _item(size_px, SMOKES_POS)
	smokes.sprite.texture = tex
	smokes.sprite.self_modulate = SMOKES_TINT
	smokes.sprite.pivot_offset = size_px * 0.5
	smokes.sprite.rotation_degrees = 8.0
	smokes.clicked.connect(smokes_clicked.emit)
	var center := SMOKES_POS + Vector2(size_px.x * 0.5, 0)
	_label("Smokes", center + Vector2(-80, size_px.y + 12), 16, TEXT, 160)
	_tag(center + Vector2(0, size_px.y + 52)).text = "%d$" % PlayerDataManager.CIGARETTE_PACK_PRICE
	var tray := TextureRect.new()
	tray.texture = preload("res://sprites/AshTray.png")
	tray.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.scale = Vector2(3, 3)
	tray.position = Vector2(980, 380)
	add_child(tray)
	TableShadow.add_to(tray)


func _build_drinks() -> void:
	_coaster = TextureRect.new()
	_coaster.texture = preload("res://sprites/Bierdeckel.png")
	_coaster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_coaster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coaster.scale = Vector2(3, 3)
	_coaster.pivot_offset = Vector2(12, 12)
	_coaster.rotation_degrees = -8.0
	_coaster.position = DRINKS_POS + Vector2(-96, 6)
	add_child(_coaster)
	TableShadow.add_to(_coaster)
	var tex: Texture2D = preload("res://sprites/bar/bar_beer_tap.png")
	drinks = _item(tex.get_size() * ART_SCALE, DRINKS_POS)
	drinks.sprite.texture = tex
	drinks.clicked.connect(drinks_clicked.emit)
	_drinks_name = _label("Round of drinks", Vector2(LEFT_PANEL.position.x, 446), 15, MUTED, LEFT_PANEL.size.x)
	_drinks_tag = _tag(Vector2(LEFT_PANEL.get_center().x, 484))
	_drinks_tag.text = "%d$" % PlayerDataManager.DRINK_ROUND_PRICE


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
	for y in range(int(r.position.y) + 40, int(r.end.y) - 8, 12):
		var rib := ColorRect.new()
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rib.color = MAT_RIB
		rib.position = Vector2(r.position.x + 10, y)
		rib.size = Vector2(r.size.x - 20, 3)
		add_child(rib)
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


static func _counter_art(level: int) -> ImageTexture:
	if _art_cache.has(level):
		return _art_cache[level]
	var image := Image.create(ART_SIZE.x, ART_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in ART_SIZE.y:
		var plank := y / 18
		for x in ART_SIZE.x:
			var color: Color = WOOD[plank % WOOD.size()]
			if absi(hash(Vector3i(x / 7, y, plank))) % 100 < 6:
				color = GRAIN
			image.set_pixel(x, y, color)
		if y % 18 == 0:
			image.fill_rect(Rect2i(0, y, ART_SIZE.x, 1), SEAM)
	for p in 22:
		var plank := p % 12
		var x := absi(hash(Vector2i(p, 3))) % ART_SIZE.x
		image.fill_rect(Rect2i(x, plank * 18 + 1, 1, 17), SEAM)
	var rings: int = [1, 2, 3, 4, 6][level - 1]
	for i in rings:
		_ring(image, RINGS[i], 6)
	var butts: int = [0, 2, 4, 7, 10][level - 1]
	for i in butts:
		var b: Vector2i = BUTTS[i]
		image.fill_rect(Rect2i(b.x, b.y, 3, 1), BUTT)
		image.set_pixel(b.x + 3, b.y, BUTT_D)
		if level >= 3:
			image.set_pixel(b.x - 1, b.y + 1, ASH)
	if level >= 4:
		_blob(image, Vector2i(250, 150), 9, 4, SPILL)
	if level >= 5:
		_blob(image, Vector2i(110, 176), 12, 5, SPILL)
		_blob(image, Vector2i(330, 20), 6, 3, ASH)
	image.fill_rect(Rect2i(0, 0, ART_SIZE.x, 6), BACK)
	image.fill_rect(Rect2i(0, 6, ART_SIZE.x, 2), EDGE_D)
	image.fill_rect(Rect2i(0, 206, ART_SIZE.x, 2), EDGE)
	image.fill_rect(Rect2i(0, 208, ART_SIZE.x, 8), EDGE_D)
	image.fill_rect(Rect2i(0, 210, ART_SIZE.x, 2), BRASS)
	_art_cache[level] = ImageTexture.create_from_image(image)
	return _art_cache[level]


static func _ring(image: Image, center: Vector2i, radius: int) -> void:
	for a in 48:
		if a % 7 == 3:
			continue
		var angle := a * TAU / 48.0
		var p := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius * 0.85))
		if Rect2i(Vector2i.ZERO, ART_SIZE).has_point(p):
			image.set_pixelv(p, RING)


static func _blob(image: Image, center: Vector2i, rx: int, ry: int, color: Color) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var d := Vector2(float(x) / rx, float(y) / ry).length()
			if d <= 1.0 and absi(hash(Vector2i(x, y))) % 100 > int(d * 40.0):
				var p := center + Vector2i(x, y)
				if Rect2i(Vector2i.ZERO, ART_SIZE).has_point(p):
					image.set_pixelv(p, color)
