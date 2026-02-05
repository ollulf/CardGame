signal stats_changed(player_id: int)

const PLAYERS: Array[int] = [0, 1, 2]

var smoking_stacks := {
	0: [],
	1: [],
	2: []
}

var drinking_level := 0

func _ready() -> void:
	GameManager.round_completed.connect(_on_round_completed)

func smoke(player_id: int, amount: int, duration: int) -> void:
	smoking_stacks[player_id].append({
		"amount": amount,
		"rounds_left": duration
	})
	stats_changed.emit(player_id)

func drink() -> void:
	drinking_level -= 1

func get_smoking(player_id: int) -> int:
	var total := 0
	for stack in smoking_stacks[player_id]:
		total += int(stack.get("amount", 0))
	return total

func get_drinking(player_id: int) -> int:
	return drinking_level


func _on_round_completed(_round_index: int, _plays: Dictionary, _winner_id: int) -> void:
	for pid in PLAYERS:
		var stacks: Array = smoking_stacks[pid]
		var changed := false

		for i in range(stacks.size() - 1, -1, -1):
			var stack: Dictionary = stacks[i]

			stack["rounds_left"] = int(stack.get("rounds_left", 0)) - 1
			stack["amount"] = maxi(int(stack.get("amount", 0)) - 1, 0)

			if stack["rounds_left"] <= 0 or stack["amount"] <= 0:
				stacks.remove_at(i)
				changed = true
			else:
				stacks[i] = stack
				changed = true

		if changed:
			stats_changed.emit(pid)
