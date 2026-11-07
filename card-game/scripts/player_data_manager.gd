extends Node

signal stats_changed(player_id: int)

const PLAYERS: Array[int] = [0, 1, 2]
const SMOKE_BONUS_PER_CIGARETTE := 1

var smoking_stacks := {
	0: [],
	1: [],
	2: []
}

var drinking_level := 0

func _ready() -> void:
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.new_match_started.connect(clear_smoking)

func smoke(player_id: int, amount: int) -> void:
	if amount <= 0:
		return
	smoking_stacks[player_id].append({
		"amount": amount
	})
	stats_changed.emit(player_id)

func drink() -> void:
	drinking_level -= 1

func get_smoking(player_id: int) -> int:
	var total := 0
	for stack in smoking_stacks[player_id]:
		total += int(stack.get("amount", 0))
	return total

func get_smoking_stack_count(player_id: int) -> int:
	return smoking_stacks[player_id].size()

func get_drinking(player_id: int) -> int:
	return drinking_level

func clear_smoking() -> void:
	for pid in PLAYERS:
		if smoking_stacks[pid].is_empty():
			continue
		smoking_stacks[pid].clear()
		stats_changed.emit(pid)

func _on_round_finished(_loosers) -> void:
	clear_smoking()
