extends CanvasLayer

const CIGARETTE_ICON := preload("res://sprites/suit_Smoke.png")
const DRINK_ICON := preload("res://sprites/suit_Alk.png")
const SUIT_UP_ICON := preload("res://sprites/suit_up_icon.png")
const SUIT_ORDER := [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.SPADES, Card.Suit.CLUBS, Card.Suit.SMOKE, Card.Suit.ALK]
const SUIT_TIP_TITLE := "Stammtisch"
const SUIT_TIP_YOU := "Your cards of these suits get a bonus until the match ends:"
const SUIT_TIP_OTHER := "%s's cards of these suits get a bonus until the match ends:"
const BUFF_COLOR := Color("5fbf6a")
const DEBUFF_COLOR := Color(1.0, 0.4, 0.4)
const MUTED_COLOR := Color("a59d94")
const PLAYER_OFFSET := Vector2(12.0, -8.0)
const AI_OFFSET := Vector2(8.0, 104.0)
const CHIP_GAP := 4.0

var chips := {}
var drink_chips := {}
var suit_chips := {}
var _tooltip: ShopTooltip
var _tip_owner := -1

func _ready() -> void:
	for player_id in PlayerDataManager.PLAYERS:
		var chip := _build_chip(player_id, CIGARETTE_ICON, "+%d" % PlayerDataManager.SMOKE_BONUS_PER_CIGARETTE, BUFF_COLOR, "x0")
		chips[player_id] = chip
		chip.visible = false
		_place_chip(player_id, chip, 0)
		var drink_chip := _build_chip(player_id, DRINK_ICON, "+0", BUFF_COLOR, "others -0", "· match")
		drink_chip.get_child(0).get_node("Count").add_theme_color_override("font_color", DEBUFF_COLOR)
		drink_chip.name = "Drink_%d" % player_id
		drink_chips[player_id] = drink_chip
		drink_chip.visible = false
		_place_chip(player_id, drink_chip, 1)
		var suit_chip := _build_chip(player_id, SUIT_UP_ICON, "", BUFF_COLOR, "", "· match")
		suit_chip.name = "SuitUp_%d" % player_id
		suit_chip.mouse_filter = Control.MOUSE_FILTER_PASS
		suit_chip.mouse_entered.connect(_show_suit_tip.bind(player_id))
		suit_chip.mouse_exited.connect(_hide_suit_tip)
		suit_chips[player_id] = suit_chip
		suit_chip.visible = false
		_place_chip(player_id, suit_chip, 2)
	_tooltip = ShopTooltip.new()
	add_child(_tooltip)
	PlayerDataManager.stats_changed.connect(_on_stats_changed)
	CardManager.suit_bonus_changed.connect(_refresh_suit_chip)
	GameManager.match_finished.connect(_clear_suit_chips)
	GameManager.match_lost.connect(_clear_suit_chips)
	PlayerDataManager.smoke_unlocked_changed.connect(_refresh_all)

func _place_chip(player_id: int, chip: PanelContainer, slot: int) -> void:
	add_child(chip)
	var chip_size := chip.get_combined_minimum_size()
	var shift_slot := slot if player_id == 0 or slot > 1 else 1 - slot
	var shift := shift_slot * (chip_size.y + CHIP_GAP)
	match player_id:
		0:
			chip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
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
			chip.offset_top = AI_OFFSET.y + shift
			chip.offset_bottom = AI_OFFSET.y + chip_size.y + shift
		2:
			chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			chip.offset_left = -AI_OFFSET.x - chip_size.x
			chip.offset_right = -AI_OFFSET.x
			chip.offset_top = AI_OFFSET.y + shift
			chip.offset_bottom = AI_OFFSET.y + chip_size.y + shift

func _build_chip(player_id: int, icon_texture: Texture2D, bonus_text: String, bonus_color: Color, count_text: String, duration_text := "· round") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Buff_%d" % player_id
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.theme_type_variation = &"ChipPanel"

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
	row.add_child(_make_label("Duration", duration_text, MUTED_COLOR))
	return chip

func _make_label(label_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(16))
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
	var text := "+%d" % PlayerDataManager.get_drink_bonus(player_id)
	if label.text == text and chip.visible:
		return
	label.text = text
	chip.get_child(0).get_node("Count").text = "others -%d" % penalty
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

func _clear_suit_chips(_arg = null) -> void:
	for player_id in suit_chips:
		_hide_chip(suit_chips[player_id])
	_hide_suit_tip()

func _refresh_suit_chip(player_id: int) -> void:
	var chip: PanelContainer = suit_chips.get(player_id)
	if chip == null:
		return
	var row := chip.get_child(0)
	var bonus: Label = row.get_node("Bonus")
	var parts: Array[String] = []
	for suit in SUIT_ORDER:
		var amount := CardManager.suit_bonus(player_id, suit)
		if amount != 0:
			parts.append("%d:%d" % [suit, amount])
	var key := ",".join(parts)
	if parts.is_empty():
		bonus.set_meta("key", "")
		_hide_chip(chip)
		if player_id == _tip_owner:
			_hide_suit_tip()
		return
	if bonus.get_meta("key", "") == key and chip.visible:
		return
	bonus.set_meta("key", key)
	for old in row.get_children():
		if old.name.begins_with("Suit_"):
			old.free()
	var index := 1
	for suit in SUIT_ORDER:
		var amount := CardManager.suit_bonus(player_id, suit)
		if amount == 0:
			continue
		var icon := _suit_icon(suit)
		icon.name = "Suit_icon_%d" % suit
		row.add_child(icon)
		row.move_child(icon, index)
		var label := _make_label("Suit_%d" % suit, "%+d" % amount, BUFF_COLOR)
		row.add_child(label)
		row.move_child(label, index + 1)
		index += 2
	bonus.visible = false
	chip.reset_size()
	_reanchor.call_deferred(player_id, chip)
	_pop_chip(chip)

func _suit_icon(suit: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(16, 16)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := Sprite2D.new()
	var texture: Texture2D = load(ShopTooltip.SUIT_ICONS.get(suit, ""))
	sprite.texture = texture
	sprite.position = Vector2(8, 8)
	sprite.scale = Vector2.ONE * (16.0 / maxf(texture.get_width(), texture.get_height()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(sprite)
	return holder

func _reanchor(player_id: int, chip: PanelContainer) -> void:
	var width := chip.get_combined_minimum_size().x
	if player_id != 2:
		chip.offset_right = chip.offset_left + width
	else:
		chip.offset_right = -AI_OFFSET.x
		chip.offset_left = -AI_OFFSET.x - width

func _show_suit_tip(player_id: int) -> void:
	var chip: PanelContainer = suit_chips.get(player_id)
	if chip == null or not chip.visible:
		return
	_tip_owner = player_id
	var body := SUIT_TIP_YOU if player_id == 0 else SUIT_TIP_OTHER % GameManager.PLAYER_NAMES[player_id]
	var lines: Array[String] = []
	for suit in SUIT_ORDER:
		var amount := CardManager.suit_bonus(player_id, suit)
		if amount != 0:
			lines.append("[img=%dx%d]%s[/img]%s%s" % [ShopTooltip.SUIT_ICON_SIZE, ShopTooltip.SUIT_ICON_SIZE, ShopTooltip.SUIT_ICONS.get(suit, ""), ShopTooltip.ICON_GAP, ShopTooltip.highlight_numbers("%+d" % amount)])
	body += "\n" + "   ".join(lines) + "\nEach [color=#%s]Stammtisch[/color] card played adds %s to its suit." % [ShopTooltip.SPECIAL, ShopTooltip.highlight_numbers("+1")]
	_tooltip.show_text(SUIT_TIP_TITLE, body, chip.get_global_rect())

func _hide_suit_tip() -> void:
	_tip_owner = -1
	if _tooltip != null:
		_tooltip.hide()
