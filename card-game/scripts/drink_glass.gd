extends Area2D
class_name DrinkGlass

const GROUP := "drink_glass"
const SEAT := 0
const PIXEL_SCALE := 3.0
const HOVER_OFFSET := Vector2(0, -6)
const EMPTY_TINT := Color(0.7, 0.7, 0.7, 0.75)
const DENY_COLOR := Color(1.0, 0.45, 0.4)
const TOOLTIP_TEXT := "Drink: Alk +1, others -1\nfor the whole match"
const EMPTY_TEXT := "No drinks left"
const TOOLTIP_BG := Color(0.09, 0.08, 0.1, 0.92)
const ROUND_TINT := Color(1.0, 0.95, 0.8)
const ROUND_LEFT_IN_GLASS := 0.2
const ROUND_REFILL_TIME := 0.5

var art: DrinkArt
var _count_label: Label
var _tooltip: Label
var _hovered := false
var _busy := false
var _hidden_by_cue := false


func _ready() -> void:
	add_to_group(GROUP)
	input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DrinkArt.WIDTH + 8.0, DrinkArt.HEIGHT + 4.0) * PIXEL_SCALE
	shape.shape = rect
	shape.position = Vector2(4.0, -DrinkArt.HEIGHT * 0.5) * PIXEL_SCALE
	add_child(shape)

	art = DrinkArt.new()
	art.scale = Vector2.ONE * PIXEL_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.position = Vector2(-10.0, 2.0)
	_count_label.size = Vector2(20.0, 18.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	_tooltip = Label.new()
	_tooltip.z_index = 10
	_tooltip.add_theme_font_size_override("font_size", 13)
	_tooltip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	var style := StyleBoxFlat.new()
	style.bg_color = TOOLTIP_BG
	style.set_content_margin_all(5.0)
	style.set_corner_radius_all(3)
	_tooltip.add_theme_stylebox_override("normal", style)
	_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	add_child(_tooltip)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	Missions.drinks_changed.connect(_on_drinks_changed)
	GameManager.new_match_started.connect(_on_new_match_started)
	_on_new_match_started()


func reveal() -> void:
	if not _hidden_by_cue:
		return
	_hidden_by_cue = false
	_refresh()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished


func _on_new_match_started() -> void:
	_hidden_by_cue = DialogueManager.upcoming_match_uses_cue("show_drinks")
	_refresh()


func _on_drinks_changed(seat: int) -> void:
	if seat == SEAT and not _busy:
		_refresh()


func _limit() -> int:
	return Missions.drink_limit(DialogueManager.upcoming_match(), SEAT)


func _refresh() -> void:
	var limit := _limit()
	visible = limit > 0 and not _hidden_by_cue
	input_pickable = visible
	if not visible:
		_tooltip.visible = false
		return
	var left := Missions.drinks_left(SEAT)
	art.fill = float(left) / float(limit)
	art.modulate = Color.WHITE if left > 0 else EMPTY_TINT
	_count_label.text = "x%d" % left
	_count_label.add_theme_color_override("font_color", Color.WHITE if left > 0 else DENY_COLOR)
	_tooltip.text = TOOLTIP_TEXT if left > 0 else EMPTY_TEXT
	_place_tooltip()


func _place_tooltip() -> void:
	_tooltip.reset_size()
	_tooltip.position = Vector2(-_tooltip.size.x * 0.5, -DrinkArt.HEIGHT * PIXEL_SCALE - _tooltip.size.y - 14.0)


func _on_mouse_entered() -> void:
	_hovered = true
	_update_hover()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_hover()


func _update_hover() -> void:
	if _busy:
		return
	art.position = HOVER_OFFSET if _hovered else Vector2.ZERO
	_tooltip.visible = _hovered


func _can_drink_now() -> bool:
	if _busy or not Missions.can_drink(SEAT) or DialogueManager.is_open():
		return false
	return GameManager.current_turn > 0 and not GameManager.round_over


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		on_clicked()


func on_clicked() -> void:
	if not _can_drink_now():
		_deny()
		return
	drink()


func drink() -> void:
	_busy = true
	_tooltip.visible = false
	art.position = Vector2.ZERO
	var target := float(Missions.drinks_left(SEAT) - 1) / float(maxi(_limit(), 1))
	art.sipped.connect(_on_sipped, CONNECT_ONE_SHOT)
	await art.play_sip(target, 1.0)
	_busy = false
	_refresh()
	_update_hover()


func drink_round() -> void:
	if _busy or not visible:
		PlayerDataManager.drink(SEAT)
		get_tree().call_group(DrunkOverlay.GROUP, "gulp")
		return
	_busy = true
	_tooltip.visible = false
	art.position = Vector2.ZERO
	art.modulate = ROUND_TINT
	var level := art.fill
	art.fill = 1.0
	art.sipped.connect(_on_round_sipped, CONNECT_ONE_SHOT)
	await art.play_sip(ROUND_LEFT_IN_GLASS, 1.0)
	var refill := create_tween()
	refill.tween_property(art, "fill", level, ROUND_REFILL_TIME)
	await refill.finished
	_busy = false
	_refresh()
	_update_hover()


func _on_round_sipped() -> void:
	PlayerDataManager.drink(SEAT)
	get_tree().call_group(DrunkOverlay.GROUP, "gulp")


func _on_sipped() -> void:
	PlayerDataManager.take_drink(SEAT)
	get_tree().call_group(DrunkOverlay.GROUP, "gulp")


func _deny() -> void:
	Sfx.play_button()
	var tween := create_tween()
	art.modulate = DENY_COLOR
	for i in 3:
		tween.tween_property(art, "rotation", 0.15, 0.05)
		tween.tween_property(art, "rotation", -0.15, 0.05)
	tween.tween_property(art, "rotation", 0.0, 0.05)
	tween.tween_callback(_refresh)
