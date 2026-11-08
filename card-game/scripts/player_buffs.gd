extends CanvasLayer

const CIGARETTE_ICON := preload("res://sprites/suit_Smoke.png")
const DRINK_ICON := preload("res://sprites/suit_Alk.png")
const BUFF_COLOR := Color("5fbf6a")
const DEBUFF_COLOR := Color(1.0, 0.4, 0.4)
const MUTED_COLOR := Color("a59d94")
const CHIP_BG := Color("2d2b38")
const CHIP_BORDER := Color("4a4658")
const PLAYER_OFFSET := Vector2(110.0, -4.0)
const AI_OFFSET := Vector2(6.0, 92.0)
const CHIP_GAP := 4.0

var chips := {}
var drink_chips := {}

func _ready() -> void:
	for player_id in PlayerDataManager.PLAYERS:
		var chip := _build_chip(player_id, CIGARETTE_ICON, "+%d" % PlayerDataManager.SMOKE_BONUS_PER_CIGARETTE, BUFF_COLOR, "x0")
		chips[player_id] = chip
		chip.visible = false
		_place_chip(player_id, chip, 0)
		var drink_chip := _build_chip(player_id, DRINK_ICON, "-0", DEBUFF_COLOR, "")
		drink_chip.name = "Drink_%d" % player_id
		drink_chips[player_id] = drink_chip
		drink_chip.visible = false
		_place_chip(player_id, drink_chip, 1)
	PlayerDataManager.stats_changed.connect(_on_stats_changed)
	PlayerDataManager.smoke_unlocked_changed.connect(_refresh_all)

func _place_chip(player_id: int, chip: PanelContainer, slot: int) -> void:
	add_child(chip)
	var chip_size := chip.get_combined_minimum_size()
	var shift := slot * (chip_size.y + CHIP_GAP)
	match player_id:
		0:
			chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			chip.grow_horizontal = Control.GROW_DIRECTION_END
			chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
			chip.offset_left = PLAYER_OFFSET.x
			chip.offset_right = PLAYER_OFFSET.x + chip_size.x
			chip.offset_top = PLAYER_OFFSET.y - chip_size.y - shift
			chip.offset_bottom = PLAYER_OFFSET.y - shift
		1:
			chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
			chip.offset_left = AI_OFFSET.x
			chip.offset_right = AI_OFFSET.x + chip_size.x
			chip.offset_top = AI_OFFSET.y - shift
			chip.offset_bottom = AI_OFFSET.y + chip_size.y - shift
		2:
			chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			chip.offset_left = -AI_OFFSET.x - chip_size.x
			chip.offset_right = -AI_OFFSET.x
			chip.offset_top = AI_OFFSET.y - shift
			chip.offset_bottom = AI_OFFSET.y + chip_size.y - shift

func _build_chip(player_id: int, icon_texture: Texture2D, bonus_text: String, bonus_color: Color, count_text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Buff_%d" % player_id
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_BG
	style.border_color = CHIP_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := Sprite2D.new()
	sprite.texture = icon_texture
	sprite.position = Vector2(8, 8)
	sprite.scale = Vector2.ONE * (16.0 / maxf(icon_texture.get_width(), icon_texture.get_height()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.add_child(sprite)
	row.add_child(icon)

	row.add_child(_make_label("Bonus", bonus_text, bonus_color))
	if count_text != "":
		row.add_child(_make_label("Count", count_text, Color.WHITE))
	row.add_child(_make_label("Duration", "· match", MUTED_COLOR))
	return chip

func _make_label(label_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _refresh_all() -> void:
	for player_id in chips:
		_on_stats_changed(player_id)

func _on_stats_changed(player_id: int) -> void:
	_refresh_drink_chip(player_id)
	var chip: PanelContainer = chips.get(player_id)
	if chip == null:
		return
	var cigarettes := PlayerDataManager.get_smoking(player_id) / PlayerDataManager.SMOKE_BONUS_PER_CIGARETTE
	if cigarettes <= 0 or not PlayerDataManager.smoke_unlocked:
		_hide_chip(chip)
		return
	var row := chip.get_child(0)
	var count_text := "x%d" % cigarettes
	if row.get_node("Count").text == count_text and chip.visible and chip.modulate.a > 0.0:
		return
	row.get_node("Count").text = count_text
	_pop_chip(chip)

func _refresh_drink_chip(player_id: int) -> void:
	var chip: PanelContainer = drink_chips.get(player_id)
	if chip == null:
		return
	var penalty := PlayerDataManager.get_drink_penalty(player_id)
	if penalty <= 0:
		_hide_chip(chip)
		return
	var label: Label = chip.get_child(0).get_node("Bonus")
	var text := "-%d" % penalty
	if label.text == text and chip.visible:
		return
	label.text = text
	_pop_chip(chip)

func _pop_chip(chip: PanelContainer) -> void:
	var was_visible := chip.visible
	chip.visible = true
	chip.pivot_offset = chip.size / 2.0
	var tween := chip.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not was_visible:
		chip.modulate.a = 0.0
		chip.scale = Vector2(0.6, 0.6)
		tween.set_parallel()
		tween.tween_property(chip, "modulate:a", 1.0, 0.2)
		tween.tween_property(chip, "scale", Vector2.ONE, 0.3)
	else:
		chip.scale = Vector2(1.2, 1.2)
		tween.tween_property(chip, "scale", Vector2.ONE, 0.25)

func _hide_chip(chip: PanelContainer) -> void:
	if not chip.visible:
		return
	var tween := chip.create_tween()
	tween.tween_property(chip, "modulate:a", 0.0, 0.25)
	tween.tween_callback(chip.hide)
