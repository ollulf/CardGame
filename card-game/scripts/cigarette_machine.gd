extends Control
class_name CigaretteMachine

signal clicked

@export var hover_offset: Vector2 = Vector2(0, -6)

@onready var sprite: TextureRect = $Sprite
@onready var tooltip: Control = $Tooltip

var _base_position: Vector2


func _ready() -> void:
	_base_position = sprite.position
	tooltip.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	sprite.position = _base_position + hover_offset
	tooltip.visible = true


func _on_mouse_exited() -> void:
	sprite.position = _base_position
	tooltip.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	clicked.emit()
