extends Area2D
class_name AshTray
@export var hover_offset: Vector2 = Vector2(0, -4)

@onready var sprite: Sprite2D = $Sprite2D

var _base_position: Vector2

func _ready() -> void:
	
	_base_position = sprite.position

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)



func _on_mouse_entered() -> void:
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	sprite.position = _base_position


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	InteractionManager.usedAshTray()
