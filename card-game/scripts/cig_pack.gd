extends Area2D
class_name CigPack

@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var hover_offset: Vector2 = Vector2(0, -10)

@export var cig_amount:= 10
@onready var amount_label:= $Sprite2D/Amount

@onready var sprite: Sprite2D = $Sprite2D

var _base_position: Vector2

func _ready() -> void:
	InteractionManager.cigPack = self
	
	_base_position = sprite.position

	if normal_texture != null:
		sprite.texture = normal_texture

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	update_label()


func _on_mouse_entered() -> void:
	if hover_texture != null:
		sprite.texture = hover_texture
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	if normal_texture != null:
		sprite.texture = normal_texture
	sprite.position = _base_position


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	InteractionManager.pickedUpCig()
	update_label()

func update_label():
	amount_label.text = str(cig_amount);
