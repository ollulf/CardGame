extends Node

signal line_started(player_id: int, text: String)

const SPEECH_BUBBLE := preload("res://scenes/speech_bubble.tscn")
const SEAT_COUNT := 3
const SEAT_OFFSETS := [Vector2(-276, -18), Vector2(66, 0), Vector2(-66, 0)]
const TRIGGERS_WITH_COUNT := ["after_turns", "every_turns", "after_rounds"]
const TRIGGERS_WITHOUT_COUNT := ["game_start", "between_rounds", "game_over"]

var lines: Array = DialogueLines.LINES

var _bubbles: Array[SpeechBubble] = []
var _seat_queues: Array[Array] = [[], [], []]
var _entry_queue: Array = []
var _playing_entries := false
var _game_running := false
var _turns := 0
var _rounds := 0

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for seat in SEAT_COUNT:
		var bubble: SpeechBubble = SPEECH_BUBBLE.instantiate()
		layer.add_child(bubble)
		_bubbles.append(bubble)

	GameManager.match_started.connect(_on_match_started)
	GameManager.round_completed.connect(_on_round_completed)
	GameManager.match_finished.connect(_on_match_finished)
	GameManager.game_lost.connect(_on_game_lost)

	_check_lines()

func say(player_id: int, text: String) -> void:
	if player_id < 0 or player_id >= SEAT_COUNT:
		push_warning("DialogueManager.say: no seat %d" % player_id)
		return
	_seat_queues[player_id].append(text)

func is_seat_talking(player_id: int) -> bool:
	return _bubbles[player_id].is_talking or not _seat_queues[player_id].is_empty()

func _process(_delta: float) -> void:
	for seat in SEAT_COUNT:
		var seat_node := _seat_node(seat)
		if seat_node == null:
			continue
		var bubble := _bubbles[seat]
		if not bubble.is_talking and not _seat_queues[seat].is_empty():
			var text: String = _seat_queues[seat].pop_front()
			bubble.tail_side = _tail_side(seat)
			bubble.show_line(text)
			line_started.emit(seat, text)
		if bubble.is_talking:
			bubble.place_at(seat_node.global_position + SEAT_OFFSETS[seat])

func _seat_node(seat: int) -> Player:
	var players: Array = [GameManager.human_player, GameManager.ai_player_1, GameManager.ai_player_2]
	var player = players[seat]
	if is_instance_valid(player) and player is Player:
		return player
	return null

func _tail_side(seat: int) -> SpeechBubble.TailSide:
	match seat:
		1:
			return SpeechBubble.TailSide.LEFT
		2:
			return SpeechBubble.TailSide.RIGHT
		_:
			return SpeechBubble.TailSide.DOWN

func _on_match_started() -> void:
	_turns = 0
	if not _game_running:
		_game_running = true
		_rounds = 0
		_fire("game_start")

func _on_round_completed(_round_index: int, _winner_id: int) -> void:
	_turns += 1
	for entry in lines:
		if entry.when == "after_turns" and entry.count == _turns:
			_queue_entry(entry)
		elif entry.when == "every_turns" and _turns % int(entry.count) == 0:
			_queue_entry(entry)

func _on_match_finished(_loosers) -> void:
	_rounds += 1
	if not GameManager.get_total_loosers().is_empty():
		return
	for entry in lines:
		if entry.when == "after_rounds" and entry.count == _rounds:
			_queue_entry(entry)
	_fire("between_rounds")

func _on_game_lost(_looser_id: int) -> void:
	if not _game_running:
		return
	_game_running = false
	_turns = 0
	_rounds = 0
	_fire("game_over")

func _fire(trigger: String) -> void:
	for entry in lines:
		if entry.when == trigger:
			_queue_entry(entry)

func _queue_entry(entry: Dictionary) -> void:
	_entry_queue.append(entry)
	if not _playing_entries:
		_play_entries()

func _play_entries() -> void:
	_playing_entries = true
	while not _entry_queue.is_empty():
		var entry: Dictionary = _entry_queue.pop_front()
		for line in entry.lines:
			say(line[0], line[1])
			while is_seat_talking(line[0]):
				await _bubbles[line[0]].finished
	_playing_entries = false

func _check_lines() -> void:
	for entry in lines:
		var trigger: String = entry.get("when", "")
		if trigger in TRIGGERS_WITH_COUNT:
			if int(entry.get("count", 0)) < 1:
				push_warning("DialogueLines: '%s' needs a count of 1 or more" % trigger)
		elif not trigger in TRIGGERS_WITHOUT_COUNT:
			push_warning("DialogueLines: unknown trigger '%s'" % trigger)
		if trigger in ["after_turns", "every_turns"] and int(entry.get("count", 0)) > GameManager.MAX_ROUNDS:
			push_warning("DialogueLines: a round only has %d turns" % GameManager.MAX_ROUNDS)
