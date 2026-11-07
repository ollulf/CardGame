extends CanvasLayer

@export var player_0: Label
@export var player_1: Label
@export var player_2: Label

var lifes_revealed := false
var won_turns_shown := false
var fade_tween: Tween
var loosers_split := false
var _life_cue_running := false

@onready var next_round_button: Button = %NextRoundButton

func _ready() -> void:
	add_to_group(GameManager.WON_ROUNDS_UI_GROUP)
	GameManager.round_started.connect(on_round_started)
	GameManager.turn_completed.connect(on_turn_completed)
	GameManager.round_finished.connect(on_round_finished)
	GameManager.next_round_available.connect(on_next_round_available)
	GameManager.new_match_started.connect(on_new_match_started)
	
	next_round_button.pressed.connect(on_next_round_pressed)
	
	reset_UI()
	reset_lifes()
	set_won_turns_alpha(0.0)

func on_next_round_pressed():
	reset_UI()
	GameManager.restart_round()

func on_round_started():
	loosers_split = false

func on_turn_completed(turn_index: int, winner_id: int):
	_update_labels(winner_id)
	if not DialogueManager.match_uses_cue("show_won_turns"):
		show_won_turns()

func on_round_finished(_looser_id : Array[int]):
	if _life_cue_running:
		return
	if not lifes_revealed and DialogueManager.match_uses_cue("show_life_cards"):
		return
	await reveal_lifes()
	split_round_loosers()

func run_cue(cue: String):
	match cue:
		"show_won_turns":
			show_won_turns()
			if fade_tween and fade_tween.is_running():
				await fade_tween.finished
		"show_life_cards":
			_life_cue_running = true
			await reveal_lifes()
			if GameManager.round_over:
				split_round_loosers()
			_life_cue_running = false

func split_round_loosers():
	if loosers_split:
		return
	loosers_split = true
	for i in GameManager.last_round_loosers:
		update_round_looser(i)

func on_next_round_available():
	next_round_button.visible = true

func on_new_match_started():
	reset_UI()
	reset_lifes()
	if fade_tween:
		fade_tween.kill()
	set_won_turns_alpha(0.0)
	won_turns_shown = false

func show_won_turns():
	if won_turns_shown:
		return
	won_turns_shown = true
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_method(set_won_turns_alpha, 0.0, 1.0, 0.4)

func set_won_turns_alpha(alpha: float):
	for i in 3:
		var panel: Panel = get_node("Player_%d" % i)
		panel.self_modulate.a = alpha
		for child in panel.get_children():
			if child is Label:
				child.modulate.a = alpha

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
	lifes_revealed = false
	for player_id in 3:
		for life in [1, 2]:
			var card := _life_card(player_id, life)
			card.restore()
			card.modulate.a = 0.0
			card.scale = Vector2.ONE

func reveal_lifes():
	if lifes_revealed:
		return
	lifes_revealed = true
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for player_id in 3:
		for life in [1, 2]:
			var card := _life_card(player_id, life)
			card.pivot_offset = card.size / 2.0
			card.scale = Vector2(0.6, 0.6)
			tween.tween_property(card, "modulate:a", 1.0, 0.3)
			tween.tween_property(card, "scale", Vector2.ONE, 0.3)
	await tween.finished
