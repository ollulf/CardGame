extends CanvasLayer

const PACK_ICON := preload("res://sprites/Cigarettes_icon.png")
const EMPTY_COLOR := Color("d9645a")
const AI_OFFSET := Vector2(6.0, 122.0)
const SEATS := [1, 2]

var chips := {}
var _hidden_by_cue := false

func _ready() -> void:
	add_to_group("ai_cigarettes_ui")
	for seat in SEATS:
		var chip := _build_chip(seat)
		chips[seat] = chip
		_place_chip(seat, chip)
	Missions.cigarettes_changed.connect(_on_cigarettes_changed)
	GameManager.new_match_started.connect(_on_new_match_started)
	GameManager.round_started.connect(_refresh_all)
	_on_new_match_started()

func reveal() -> void:
	if not _hidden_by_cue:
		return
	_hidden_by_cue = false
	visible = true
	_refresh_all()
	var tween := create_tween().set_parallel()
	for chip in chips.values():
		chip.modulate.a = 0.0
		tween.tween_property(chip, "modulate:a", 1.0, 0.4)
	await tween.finished

func _on_new_match_started() -> void:
	var pack: CigPack = InteractionManager.cigPack
	var pack_shown := pack != null and pack.cig_amount > 0
	_hidden_by_cue = DialogueManager.upcoming_match_uses_cue("show_cigs") and not pack_shown
	visible = not _hidden_by_cue
	_refresh_all()

func _refresh_all() -> void:
	for seat in SEATS:
		_refresh(seat)

func _refresh(seat: int) -> void:
	var chip: PanelContainer = chips.get(seat)
	if chip == null:
		return
	var left := Missions.cigarettes_left(seat)
	chip.visible = left != Missions.UNLIMITED
	var count: Label = chip.get_node("Row/Count")
	count.text = "x%d" % maxi(left, 0)
	count.add_theme_color_override("font_color", EMPTY_COLOR if left == 0 else Color.WHITE)

func _on_cigarettes_changed(seat: int) -> void:
	_refresh(seat)
	var chip: PanelContainer = chips.get(seat)
	if chip == null or not chip.visible or not visible:
		return
	chip.pivot_offset = chip.size / 2.0
	chip.scale = Vector2(1.2, 1.2)
	var tween := chip.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "scale", Vector2.ONE, 0.25)

func _place_chip(seat: int, chip: PanelContainer) -> void:
	add_child(chip)
	var chip_size := chip.get_combined_minimum_size()
	if seat == 1:
		chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
		chip.offset_left = AI_OFFSET.x
		chip.offset_right = AI_OFFSET.x + chip_size.x
	else:
		chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		chip.offset_left = -AI_OFFSET.x - chip_size.x
		chip.offset_right = -AI_OFFSET.x
	chip.offset_top = AI_OFFSET.y
	chip.offset_bottom = AI_OFFSET.y + chip_size.y

func _build_chip(seat: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Cigs_%d" % seat
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.theme_type_variation = &"ChipPanel"

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var icon := TextureRect.new()
	icon.texture = PACK_ICON
	icon.custom_minimum_size = Vector2(12, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var count := Label.new()
	count.name = "Count"
	count.text = "x0"
	count.add_theme_font_size_override("font_size", 14)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	return chip
