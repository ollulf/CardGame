extends Node2D

func _ready() -> void:
	GameManager.set_table_root(%TableRoot)
	GameManager.start_match(0)
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
