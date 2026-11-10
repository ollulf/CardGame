extends Control
class_name MenuCard

signal pressed

const CARD_FACE := preload("res://sprites/card_Background.png")
const CARD_SIZE := Vector2(140, 210)
const LIFT := 26.0
const HOVER_SCALE := 1.08
const ANIM_TIME := 0.12
const TEXT_COLOR := Color(0.92, 0.9, 0.96)
const PRIMARY_COLOR := Color(1.0, 0.55, 0.62)

var _button: Button
var _label: Label
var _icons: Array[TextureRect] = []
var _tween: Tween
var _lifted := false
var _tilt := 0.0

func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.size = CARD_SIZE
	_button.pivot_offset = CARD_SIZE / 2.0
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(_button)
	var face := TextureRect.new()
	face.texture = CARD_FACE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.size = CARD_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(face)
	for corner in [Vector2(12, 12), CARD_SIZE - Vector2(30, 30)]:
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.position = corner
		icon.size = Vector2(18, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_button.add_child(icon)
		_icons.append(icon)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.position = Vector2(14, 36)
	_label.size = Vector2(CARD_SIZE.x - 28, CARD_SIZE.y - 72)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_font_size_override("font_size", 20)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_label)
	_button.pressed.connect(func() -> void: pressed.emit())
	_button.mouse_entered.connect(_set_lifted.bind(true))
	_button.mouse_exited.connect(_set_lifted.bind(false))

func setup(text: String, suit: Texture2D, primary: bool = false, tilt_degrees: float = 0.0) -> void:
	_tilt = tilt_degrees
	_button.rotation_degrees = tilt_degrees
	_label.text = text
	_label.add_theme_color_override("font_color", PRIMARY_COLOR if primary else TEXT_COLOR)
	for icon in _icons:
		icon.texture = suit

func set_disabled(value: bool) -> void:
	_button.disabled = value
	if value:
		_set_lifted(false)

func _set_lifted(value: bool) -> void:
	if value == _lifted or (value and _button.disabled):
		return
	_lifted = value
	z_index = 1 if value else 0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_button, "position:y", -LIFT if value else 0.0, ANIM_TIME)
	_tween.tween_property(_button, "scale", Vector2.ONE * (HOVER_SCALE if value else 1.0), ANIM_TIME)
	_tween.tween_property(_button, "rotation_degrees", 0.0 if value else _tilt, ANIM_TIME)
	if value:
		Sfx.play_hover_card()
