extends CanvasLayer

@export var player_0: Label
@export var player_1: Label
@export var player_2: Label

@onready var next_match_button: Button = %NextMatchButton

func _ready() -> void:
	GameManager.round_completed.connect(on_round_completed)
	GameManager.match_finished.connect(on_match_finished)
	GameManager.next_match_available.connect(on_next_match_available)
	GameManager.new_game_started.connect(on_new_game_started)
	
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

func on_next_match_available():
	next_match_button.visible = true

func on_new_game_started():
	reset_UI()
	reset_lifes()

func _update_labels(id: int):
	match id:
		0: player_0.text = str(int(player_0.text)+1) 
		1: player_1.text = str(int(player_1.text)+1)
		2: player_2.text = str(int(player_2.text)+1)

func update_match_looser(looser_id : int):
	var lost_matches: int = GameManager.id_to_player(looser_id).lost_matches
	if lost_matches == 1 or lost_matches == 2:
		_life_card(looser_id, lost_matches).split()

func _life_card(player_id: int, life: int) -> LifeCard:
	return get_node("Player_%d/LostMatches/Hearts_%d" % [player_id, life])

func reset_UI():
	next_match_button.visible = false
	
	player_0.text = "0"
	player_1.text = "0"
	player_2.text = "0"
	
func reset_lifes():
	for player_id in 3:
		for life in [1, 2]:
			_life_card(player_id, life).restore()
