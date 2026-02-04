extends CanvasLayer
class_name TurnIndicator

@export var player_0_sprite: NinePatchRect
@export var player_1_sprite: NinePatchRect
@export var player_2_sprite: NinePatchRect

func _process(_delta: float) -> void:
	var current_player_id := _get_current_player_id()
	match current_player_id:
		-1:
			player_0_sprite.visible = false
			player_1_sprite.visible = false
			player_2_sprite.visible = false
		0: 
			player_0_sprite.visible = true
			player_1_sprite.visible = false
			player_2_sprite.visible = false
		1:
			player_0_sprite.visible = false
			player_1_sprite.visible = true
			player_2_sprite.visible = false
		2:
			player_0_sprite.visible = false
			player_1_sprite.visible = false
			player_2_sprite.visible = true


func _get_current_player_id() -> int:
	# Safety checks
	if GameManager.turn_order.is_empty():
		return -1

	if GameManager.current_turn_index < 0:
		return -1

	if GameManager.current_turn_index >= GameManager.turn_order.size():
		return -1

	return GameManager.turn_order[GameManager.current_turn_index]
