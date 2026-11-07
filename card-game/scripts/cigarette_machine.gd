extends Control
class_name CigaretteMachine

signal clicked

@export var hover_offset: Vector2 = Vector2(0, -6)

@onready var sprite: TextureRect = $Sprite
@onready var tooltip: Control = $Tooltip

const DENY_COLOR := Color(1.0, 0.45, 0.4)
const DENY_DURATION := 1.2

var _base_position: Vector2
var _label_text: String
var _hovered := false
var _deny_tween: Tween


func _ready() -> void:
	_base_position = sprite.position
	_label_text = tooltip.text
	tooltip.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_label_text(value: String) -> void:
	_label_text = value
	if _deny_tween == null or not _deny_tween.is_running():
		tooltip.text = value


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
	tooltip.text = _label_text
	tooltip.modulate = Color.WHITE
	tooltip.visible = _hovered


func _on_mouse_entered() -> void:
	_hovered = true
	sprite.position = _base_position + hover_offset
	tooltip.visible = true


func _on_mouse_exited() -> void:
	_hovered = false
	sprite.position = _base_position
	if _deny_tween == null or not _deny_tween.is_running():
		tooltip.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	clicked.emit()
