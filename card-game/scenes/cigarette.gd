extends Node2D
class_name Cigarette

enum State { UNLIT, LIT, STUMP }

@export var unlit_texture: Texture2D
@export var lit_texture: Texture2D
@export var stump_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var _state: int = State.UNLIT


func _ready() -> void:
	_apply_visual()


func set_state(new_state: int) -> void:
	_state = new_state
	_apply_visual()


func get_state() -> int:
	return _state


func _apply_visual() -> void:
	if sprite == null:
		return

	match _state:
		State.UNLIT:
			if unlit_texture != null:
				sprite.texture = unlit_texture
		State.LIT:
			if lit_texture != null:
				sprite.texture = lit_texture
		State.STUMP:
			if stump_texture != null:
				sprite.texture = stump_texture
