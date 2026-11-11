extends PanelContainer
class_name ShopTooltip

const WIDTH := 250.0
const GAP := 14.0
const EDGE := Color(0.86, 0.84, 0.95)
const BG := Color(0.0901961, 0.0862745, 0.109804, 0.96)
const INNER_BG := Color(0.27, 0.26, 0.3)
const NUMBER := "f2a94a"
const SPECIAL := "a98bff"
const LOCKED := "ff7a6b"
const SUIT_ICON_SIZE := 18
const NO_BREAK := "\u00a0"
const ICON_GAP := "\u202f"
const SUIT_ICONS := {
	Card.Suit.DIAMONDS: "res://sprites/suit_Karo.png",
	Card.Suit.HEARTS: "res://sprites/suit_Herz.png",
	Card.Suit.SPADES: "res://sprites/suit_Pik.png",
	Card.Suit.CLUBS: "res://sprites/suit_Kreuz.png",
	Card.Suit.ALK: "res://sprites/suit_Alk.png",
	Card.Suit.SMOKE: "res://sprites/suit_Smoke.png",
}

var _title: Label
var _body: RichTextLabel
var _shown := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	visible = false
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", _box(BG, 3, 8, 12))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(_title)
	var inner := PanelContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", _box(INNER_BG, 2, 6, 10))
	column.add_child(inner)
	_body = RichTextLabel.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.bbcode_enabled = true
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_color_override("default_color", Color(0.95, 0.94, 0.9))
	inner.add_child(_body)


func show_text(title: String, body: String, anchor: Rect2) -> void:
	_title.text = title
	_body.text = body
	_shown += 1
	var token := _shown
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	if token != _shown or not visible:
		return
	size = Vector2(WIDTH, 0)
	reset_size()
	modulate.a = 1.0
	var x := anchor.position.x - size.x - GAP
	if x < GAP:
		x = anchor.end.x + GAP
	position = Vector2(x, anchor.get_center().y - size.y * 0.5).round()


static func describe(booster: Dictionary, match_number: int) -> String:
	var count := int(booster.get("cards", 0))
	var specials := mini(int(booster.get("specials", 0)), count)
	var low := BoosterWindow.lowest_rank(booster, match_number)
	var high := clampi(int(booster.get("max_rank", BoosterWindow.MAX_RANK)), low, BoosterWindow.MAX_RANK)
	var ranks := str(low) if low == high else "%d%s-%s%d" % [low, NO_BREAK, NO_BREAK, high]
	var text := "Contains %s cards of suit %s" % [_number(str(count)), _suit_list(booster, match_number)]
	if specials >= count and count > 0:
		text += ", %s" % _special("all" + NO_BREAK + "special")
	elif specials > 0:
		text += ", and %s" % _special(str(specials) + NO_BREAK + "special")
	return text + " from rank %s." % _number(ranks)


static func _suit_list(booster: Dictionary, match_number: int) -> String:
	var icons: Array[String] = []
	for suit in BoosterWindow.pack_suits(booster, match_number):
		var icon := "[img=%dx%d]%s[/img]" % [SUIT_ICON_SIZE, SUIT_ICON_SIZE, SUIT_ICONS.get(suit, "")]
		if not icon in icons:
			icons.append(icon)
	return ICON_GAP.join(icons)


static func _number(text: String) -> String:
	return "[color=#%s]%s[/color]" % [NUMBER, text]


static func _special(text: String) -> String:
	return "[color=#%s]%s[/color]" % [SPECIAL, text]


static func _box(bg: Color, border: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = EDGE
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func highlight_numbers(text: String) -> String:
	var regex := RegEx.create_from_string("[+-]?[0-9]+")
	return regex.sub(text, "[color=#%s]$0[/color]" % NUMBER, true)
