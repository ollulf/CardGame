extends Node2D
class_name TurnIndicator

@export var player_0_sprite: Sprite2D
@export var player_1_sprite: Sprite2D
@export var player_2_sprite: Sprite2D


var last_player_id: int = -1


func _ready() -> void:
	_set_all(false)


func _process(_delta: float) -> void:
	var current_player_id := _get_current_player_id()

	# Only update when it actually changes
	if current_player_id == last_player_id:
		return

	last_player_id = current_player_id
	_update_indicator(current_player_id)


func _get_current_player_id() -> int:
	# Safety checks
	if GameManager.turn_order.is_empty():
		return -1

	if GameManager.current_turn_index < 0:
		return -1

	if GameManager.current_turn_index >= GameManager.turn_order.size():
		return -1

	return GameManager.turn_order[GameManager.current_turn_index]


func _update_indicator(player_id: int) -> void:
	_set_all(false)


func _set_all(value: bool) -> void:
	player_0_sprite.visible = value
	player_1_sprite.visible = value
	player_2_sprite.visible = value
