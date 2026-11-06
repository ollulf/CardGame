extends Area2D
class_name Wallet

signal clicked

@export var hover_offset: Vector2 = Vector2(0, -4)
@export var blocked: bool = false : set = set_blocked

@onready var sprite: Sprite2D = $Sprite2D
@onready var tooltip: Control = $Tooltip

var _base_position: Vector2
var _hovered: bool = false


func _ready() -> void:
	_base_position = sprite.position
	tooltip.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_blocked(value: bool) -> void:
	blocked = value
	if is_node_ready():
		_refresh()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh()


func _refresh() -> void:
	var active := _hovered and not blocked
	sprite.position = _base_position + hover_offset if active else _base_position
	tooltip.visible = active


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if blocked:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	clicked.emit()
