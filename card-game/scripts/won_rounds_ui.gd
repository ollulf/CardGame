extends CanvasLayer

@export var player_0: Label
@export var player_1: Label
@export var player_2: Label

@onready var next_match_button: Button = %NextMatchButton

func _ready() -> void:
	GameManager.round_completed.connect(on_round_completed)
	GameManager.match_finished.connect(on_match_finished)
	
	next_match_button.pressed.connect(on_next_match_pressed)
	
	reset_UI()
	reset_lifes()

func on_next_match_pressed():
	reset_UI()
	GameManager.restart_match()

func on_round_completed(round_index: int, winner_id: int):
	_update_labels(winner_id)

func on_match_finished(looser_id : Array[int]):
	for i in looser_id:
		update_match_looser(i)
	next_match_button.visible = true

func _update_labels(id: int):
	match id:
		0: player_0.text = str(int(player_0.text)+1) 
		1: player_1.text = str(int(player_1.text)+1)
		2: player_2.text = str(int(player_2.text)+1)

func update_match_looser(looser_id : int):
	match looser_id:
		0:
			if GameManager.human_player.lost_matches == 1:
				$Player_0/LostMatches/Hearts_1/x_image.visible = true
			if GameManager.human_player.lost_matches == 2:
				$Player_0/LostMatches/Hearts_2/x_image.visible = true
		1:
			if GameManager.ai_player_1.lost_matches == 1:
				$Player_1/LostMatches/Hearts_1/x_image.visible = true
			if GameManager.ai_player_1.lost_matches == 2:
				$Player_1/LostMatches/Hearts_2/x_image.visible = true
		2:
			if GameManager.ai_player_2.lost_matches == 1:
				$Player_2/LostMatches/Hearts_1/x_image.visible = true
			if GameManager.ai_player_2.lost_matches == 2:
				$Player_2/LostMatches/Hearts_2/x_image.visible = true

func reset_UI():
	next_match_button.visible = false
	
	player_0.text = "0"
	player_1.text = "0"
	player_2.text = "0"
	
func reset_lifes():
	$Player_0/LostMatches/Hearts_1/x_image.visible = false
	$Player_0/LostMatches/Hearts_2/x_image.visible = false
	$Player_1/LostMatches/Hearts_1/x_image.visible = false
	$Player_1/LostMatches/Hearts_2/x_image.visible = false
	$Player_2/LostMatches/Hearts_1/x_image.visible = false
	$Player_2/LostMatches/Hearts_2/x_image.visible = false
