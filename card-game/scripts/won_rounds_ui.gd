extends CanvasLayer

@export var player_0: Label
@export var player_1: Label
@export var player_2: Label

@onready var next_round_button: Button = %NextRoundButton

func _ready() -> void:
	GameManager.turn_completed.connect(on_turn_completed)
	GameManager.round_finished.connect(on_round_finished)
	GameManager.next_round_available.connect(on_next_round_available)
	GameManager.new_match_started.connect(on_new_match_started)
	
	next_round_button.pressed.connect(on_next_round_pressed)
	
	reset_UI()
	reset_lifes()

func on_next_round_pressed():
	reset_UI()
	GameManager.restart_round()

func on_turn_completed(turn_index: int, winner_id: int):
	_update_labels(winner_id)

func on_round_finished(looser_id : Array[int]):
	for i in looser_id:
		update_round_looser(i)

func on_next_round_available():
	next_round_button.visible = true

func on_new_match_started():
	reset_UI()
	reset_lifes()

func _update_labels(id: int):
	match id:
		0: player_0.text = str(int(player_0.text)+1) 
		1: player_1.text = str(int(player_1.text)+1)
		2: player_2.text = str(int(player_2.text)+1)

func update_round_looser(looser_id : int):
	var lost_rounds: int = GameManager.id_to_player(looser_id).lost_rounds
	if lost_rounds == 1 or lost_rounds == 2:
		_life_card(looser_id, lost_rounds).split()

func _life_card(player_id: int, life: int) -> LifeCard:
	return get_node("Player_%d/LostRounds/Hearts_%d" % [player_id, life])

func reset_UI():
	next_round_button.visible = false
	
	player_0.text = "0"
	player_1.text = "0"
	player_2.text = "0"
	
func reset_lifes():
	for player_id in 3:
		for life in [1, 2]:
			_life_card(player_id, life).restore()
