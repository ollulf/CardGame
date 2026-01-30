extends Node2D

func _ready() -> void:
	GameManager.set_table_root(%TableRoot)
	GameManager.start_match(0)
