extends CanvasLayer

const PILE_OFFSETS := {
	Card.Owner.HUMAN: Vector2(-428, 0),
	Card.Owner.AI_1: Vector2(0, 125),
	Card.Owner.AI_2: Vector2(0, 125),
}

var piles: Array[WonPile] = []
var lifes_revealed := false
var won_turns_shown := false
var fade_tween: Tween
var loosers_split := false
var _life_cue_running := false

func _ready() -> void:
	visible = true
	add_to_group(GameManager.WON_ROUNDS_UI_GROUP)
	GameManager.round_started.connect(on_round_started)
	GameManager.turn_completed.connect(on_turn_completed)
	GameManager.round_finished.connect(on_round_finished)
	GameManager.next_round_available.connect(on_next_round_available)
	GameManager.new_match_started.connect(on_new_match_started)
	
	reset_lifes()
	_create_piles.call_deferred()

func _create_piles() -> void:
	for deck_pile in get_tree().get_nodes_in_group(GameManager.DECK_PILE_GROUP):
		var pile := WonPile.new()
		pile.pile_owner = deck_pile.deck_owner
		pile.position = deck_pile.position + PILE_OFFSETS[deck_pile.deck_owner]
		deck_pile.get_parent().add_child(pile)
		piles.append(pile)
	set_won_turns_alpha(1.0 if won_turns_shown else 0.0)

func on_round_started():
	loosers_split = false
	reset_UI(false)

func on_turn_completed(_turn_index: int, _winner_id: int):
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
	await DialogueManager.wait_until_idle()
	await get_tree().create_timer(1.0, false).timeout
	if not GameManager.round_over:
		return
	reset_UI(true)
	GameManager.restart_round()

func on_new_match_started():
	reset_UI(false)
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
	for pile in piles:
		pile.modulate.a = alpha

func update_round_looser(looser_id : int):
	var lost_rounds: int = GameManager.id_to_player(looser_id).lost_rounds
	if lost_rounds == 1 or lost_rounds == 2:
		_life_card(looser_id, lost_rounds).split()

func _life_card(player_id: int, life: int) -> LifeCard:
	return get_node("Player_%d/LostRounds/Hearts_%d" % [player_id, life])

func reset_UI(animate: bool):
	for pile in piles:
		pile.clear(animate and won_turns_shown)
	
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
