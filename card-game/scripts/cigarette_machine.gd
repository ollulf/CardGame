extends Control
class_name CigaretteMachine

signal clicked

@export var hover_offset: Vector2 = Vector2(0, -6)
@export var needs_confirm := true

@onready var sprite: TextureRect = $Sprite
@onready var tooltip: Control = $Tooltip

const DENY_COLOR := Color(1.0, 0.45, 0.4)
const DENY_DURATION := 1.2
const OUT_OF_ORDER_TEXT := "Out of order"
const CONFIRM_TEXT := "Really?"
const SIGN_TEXTURE := preload("res://sprites/out_of_order.png")

var out_of_order := false
var _sign: TextureRect
var _base_position: Vector2
var _label_text: String
var _hovered := false
var _deny_tween: Tween
var _bubble: SpeechBubble
var _confirming := false


func _ready() -> void:
	_base_position = sprite.position
	_label_text = tooltip.text
	tooltip.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_bubble = preload("res://scenes/speech_bubble.tscn").instantiate()
	_bubble.tail_side = SpeechBubble.TailSide.DOWN
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.z_index = 10
	add_child(_bubble)
	set_process_input(false)


func set_label_text(value: String) -> void:
	_label_text = value
	if _deny_tween == null or not _deny_tween.is_running():
		tooltip.text = _shown_label()


func set_out_of_order(value: bool) -> void:
	out_of_order = value
	if value:
		cancel_confirm()
		if _sign == null:
			_sign = _build_sign()
	if _sign != null:
		_sign.visible = value
	if _deny_tween == null or not _deny_tween.is_running():
		tooltip.text = _shown_label()


func _shown_label() -> String:
	return OUT_OF_ORDER_TEXT if out_of_order else _label_text


func _build_sign() -> TextureRect:
	var sign_rect := TextureRect.new()
	sign_rect.name = "OutOfOrderSign"
	sign_rect.texture = SIGN_TEXTURE
	sign_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.add_child(sign_rect)
	return sign_rect


func deny(message: String) -> void:
	if _deny_tween:
		_deny_tween.kill()
	tooltip.text = message
	tooltip.modulate = DENY_COLOR
	tooltip.visible = true
	var shake_base := _base_position + hover_offset if _hovered else _base_position
	_deny_tween = create_tween()
	for offset in [8.0, -8.0, 5.0, -5.0, 0.0]:
		_deny_tween.tween_property(sprite, "position", shake_base + Vector2(offset, 0), 0.04)
	_deny_tween.tween_interval(DENY_DURATION)
	_deny_tween.tween_callback(_end_deny)


func _end_deny() -> void:
	tooltip.text = _shown_label()
	tooltip.modulate = Color.WHITE
	tooltip.visible = _hovered


func _on_mouse_entered() -> void:
	_hovered = true
	sprite.position = _base_position + hover_offset
	tooltip.visible = true


func _on_mouse_exited() -> void:
	_hovered = false
	cancel_confirm()
	sprite.position = _base_position
	if _deny_tween == null or not _deny_tween.is_running():
		tooltip.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	if out_of_order:
		deny(OUT_OF_ORDER_TEXT)
		return
	if _confirming or not needs_confirm:
		cancel_confirm()
		clicked.emit()
		return
	_confirming = true
	tooltip.visible = false
	_bubble.show_line(CONFIRM_TEXT)
	_bubble.complete_line()
	_bubble.place_at(Vector2(size.x * 0.5, -16.0))
	set_process_input(true)


func cancel_confirm() -> void:
	if not _confirming:
		return
	_confirming = false
	_bubble.close_line()
	set_process_input(false)
	tooltip.visible = _hovered


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	and not get_global_rect().has_point(event.global_position):
		cancel_confirm()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _bubble != null and not is_visible_in_tree():
		cancel_confirm()
