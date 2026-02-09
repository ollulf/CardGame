extends CanvasLayer

@export var player_0: Label
@export var player_1: Label
@export var player_2: Label

func _ready() -> void:
	GameManager.round_completed.connect(_on_round_completed)
	GameManager.match_finished.connect(_on_match_finished)
	_reset_labels()

func _on_round_completed(round_index: int, winner_id: int):
	_update_labels(winner_id)

func _on_match_finished():
	_reset_labels()

func _update_labels(id: int):
	match id:
		0: player_0.text = str(int(player_0.text)+1) 
		1: player_1.text = str(int(player_1.text)+1)
		2: player_2.text = str(int(player_2.text)+1)

func _reset_labels():
	player_0.text = "0"
	player_1.text = "0"
	player_2.text = "0"
