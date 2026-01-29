extends Node2D
class_name AIPlayer

@export var player_id: int = 1

# A very simple "hand". Replace with your real deck/hand logic.
var hand: Array = []


func _ready() -> void:
	# Hook into the GameManager turn requests
	GameManager.request_play_card.connect(_on_request_play_card)
	GameManager.round_started.connect(_on_round_started)

	# Optional: build a starter hand so it can play immediately
	_build_test_hand()


func _on_round_started(round_index: int, starting_player_id: int) -> void:
	# Optional: if you want to draw new cards each round, do it here.
	# For now, if the hand is empty, refill it.
	if hand.is_empty():
		_build_test_hand()


func _on_request_play_card(requested_player_id: int) -> void:
	if requested_player_id != player_id:
		return

	if hand.is_empty():
		# If the AI has nothing, it still must respond.
		# Submit a placeholder. You can change this behavior.
		print("Player " + str(player_id) + " played nothing")
		GameManager.submit_play(player_id, null)
		return

	var index := randi() % hand.size()
	var chosen_card = hand[index]
	hand.remove_at(index)

	GameManager.submit_play(player_id, chosen_card)


func _build_test_hand() -> void:
	return
