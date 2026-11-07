extends Node

signal line_started(player_id: int, text: String)
signal closed

const SPEECH_BUBBLE := preload("res://scenes/speech_bubble.tscn")
const SEAT_COUNT := 3
const SEAT_OFFSETS := [Vector2(-276, -18), Vector2(66, 0), Vector2(-66, 0)]
const TRIGGERS_WITH_COUNT := ["after_turns", "every_turns", "after_rounds"]
const TRIGGERS_WITHOUT_COUNT := ["game_start", "between_rounds", "game_over"]
const NO_SEAT := -1
const AUTO_ADVANCE_HOLD := 1.5
const DIALOGUE_LAYER := 100
const LINES_PATH := "res://dialogue_lines.yaml"
const CUES := ["show_deck", "deal_cards"]

var lines: Array = load_lines(LINES_PATH)
var auto_advance := Engine.get_write_movie_path() != "" or DisplayServer.get_name() == "headless"

var _bubble: SpeechBubble
var _mouse_blocker: Control
var _queue: Array = []
var _waiting: Array = []
var _speaking_seat := NO_SEAT
var _running_cue := false
var _auto_advance_time := 0.0
var _match_running := false
var _turns := 0
var _rounds := 0

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = DIALOGUE_LAYER
	add_child(layer)
	_mouse_blocker = Control.new()
	_mouse_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mouse_blocker.visible = false
	layer.add_child(_mouse_blocker)
	_bubble = SPEECH_BUBBLE.instantiate()
	layer.add_child(_bubble)

	GameManager.round_started.connect(_on_round_started)
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.match_lost.connect(_on_match_lost)
	GameManager.new_match_started.connect(_drop_waiting)
	CardManager.card_played.connect(_on_card_played)

	_check_lines()

func say(player_id: int, text: String) -> void:
	if player_id < 0 or player_id >= SEAT_COUNT:
		push_error("DialogueManager.say: no seat %d" % player_id)
		return
	_enqueue(player_id, text, "")

func _enqueue(player_id: int, text: String, cue: String) -> void:
	var was_open := is_open()
	_queue.append([player_id, text, cue])
	if not was_open:
		_open()
		_show_next()

func is_open() -> bool:
	return _speaking_seat != NO_SEAT or _running_cue or not _queue.is_empty()

func has_cue(trigger: String, cue: String) -> bool:
	for entry in lines:
		if entry.when != trigger:
			continue
		for line in entry.lines:
			if line[3] == cue:
				return true
	return false

func wait_until_idle() -> void:
	while is_open():
		await closed

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventMouse:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		InteractionManager.skip_next_double_click()
		_advance()

func _process(delta: float) -> void:
	if _speaking_seat == NO_SEAT:
		return
	var seat_node := _seat_node(_speaking_seat)
	if seat_node == null:
		_end_line()
		return
	_bubble.place_at(seat_node.global_position + SEAT_OFFSETS[_speaking_seat])
	if auto_advance and _bubble.is_typed:
		_auto_advance_time += delta
		if _auto_advance_time >= AUTO_ADVANCE_HOLD:
			_advance()

func _advance() -> void:
	if _running_cue or _speaking_seat == NO_SEAT:
		return
	if _bubble.is_typed:
		_end_line()
	else:
		_bubble.complete_line()

func _end_line() -> void:
	_bubble.close_line()
	_speaking_seat = NO_SEAT
	_show_next()

func _show_next() -> void:
	while not _queue.is_empty():
		var line: Array = _queue.pop_front()
		if line[2] != "":
			_running_cue = true
			await GameManager.run_cue(line[2])
			_running_cue = false
		var seat_node := _seat_node(line[0])
		if seat_node == null:
			push_error("DialogueManager: seat %d is not at the table" % line[0])
			continue
		_speaking_seat = line[0]
		_auto_advance_time = 0.0
		_bubble.tail_side = _tail_side(_speaking_seat)
		_bubble.show_line(line[1])
		_bubble.place_at(seat_node.global_position + SEAT_OFFSETS[_speaking_seat])
		line_started.emit(_speaking_seat, line[1])
		return
	_close()

func _open() -> void:
	InteractionManager.cancel_press()
	get_viewport().physics_object_picking = false
	_mouse_blocker.visible = true

func _close() -> void:
	get_viewport().physics_object_picking = true
	_mouse_blocker.visible = false
	_refresh_hover.call_deferred()
	closed.emit()

func _refresh_hover() -> void:
	if is_open():
		return
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_mouse_position()
	motion.global_position = motion.position
	get_viewport().push_input(motion)

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

func _on_round_started() -> void:
	_turns = 0
	if not _match_running:
		_match_running = true
		_rounds = 0
		_fire("game_start")

func _on_turn_completed(_turn_index: int, _winner_id: int) -> void:
	_turns += 1
	for entry in lines:
		if entry.when == "after_turns" and entry.count == _turns:
			_queue_entry(entry)
		elif entry.when == "every_turns" and _turns % int(entry.count) == 0:
			_queue_entry(entry)

func _on_round_finished(_loosers) -> void:
	_rounds += 1
	if not GameManager.get_total_loosers().is_empty():
		return
	for entry in lines:
		if entry.when == "after_rounds" and entry.count == _rounds:
			_queue_entry(entry)
	_fire("between_rounds")

func _on_match_lost(_looser_id: int) -> void:
	if not _match_running:
		return
	_match_running = false
	_drop_waiting()
	_turns = 0
	_rounds = 0
	_fire("game_over")

func _fire(trigger: String) -> void:
	for entry in lines:
		if entry.when == trigger:
			_queue_entry(entry)

func _queue_entry(entry: Dictionary) -> void:
	_queue_lines(entry.lines)

func _queue_lines(spoken_lines: Array) -> void:
	for i in spoken_lines.size():
		var line: Array = spoken_lines[i]
		if line[2] > 0:
			var rest := spoken_lines.slice(i)
			rest[0] = [line[0], line[1], 0, line[3]]
			_waiting.append({"cards_left": line[2], "lines": rest})
			return
		_enqueue(line[0], line[1], line[3])

func _on_card_played(_player_id: int, _card: Card) -> void:
	var due: Array = []
	for waiting in _waiting:
		waiting.cards_left -= 1
		if waiting.cards_left <= 0:
			due.append(waiting)
	for waiting in due:
		_waiting.erase(waiting)
		_queue_lines(waiting.lines)

func _drop_waiting() -> void:
	_waiting.clear()

static func load_lines(path: String) -> Array:
	return rows_from_yaml(YamlLite.parse_file(path))

static func rows_from_yaml(yaml: YamlLite) -> Array:
	var rows: Array = []
	for i in yaml.data.size():
		var row = _clean_row(yaml.data[i], yaml.item_lines[i])
		if row != null:
			rows.append(row)
	return rows

static func _clean_row(raw, line: int):
	if not raw is Dictionary or not raw.get("when") is String:
		push_error("DialogueLines line %d: row needs a 'when'" % line)
		return null
	if not raw.get("lines") is Array or raw.lines.is_empty():
		push_error("DialogueLines line %d: row needs a list of 'lines'" % line)
		return null
	var row := {"when": raw.when, "lines": []}
	if raw.has("count"):
		if not raw.count is int:
			push_error("DialogueLines line %d: 'count' must be a whole number" % line)
			return null
		row["count"] = raw.count
	for spoken in raw.lines:
		if not spoken is Dictionary or not spoken.get("seat") is int or not spoken.get("text") is String:
			push_error("DialogueLines line %d: every line needs a 'seat' number and a 'text'" % line)
			return null
		if spoken.seat < 0 or spoken.seat >= SEAT_COUNT:
			push_error("DialogueLines line %d: seat %d does not exist" % [line, spoken.seat])
			return null
		for key in spoken.keys():
			if not key in ["seat", "text", "after_played_cards", "cue"]:
				push_error("DialogueLines line %d: unknown key '%s' in a line (allowed: seat, text, after_played_cards, cue)" % [line, key])
		var wait := 0
		if spoken.has("after_played_cards"):
			if not spoken.after_played_cards is int or spoken.after_played_cards < 1:
				push_error("DialogueLines line %d: 'after_played_cards' must be a whole number of 1 or more" % line)
				return null
			wait = spoken.after_played_cards
		var cue := ""
		if spoken.has("cue"):
			if not spoken.cue in CUES:
				push_error("DialogueLines line %d: unknown cue '%s' (allowed: %s)" % [line, str(spoken.cue), ", ".join(CUES)])
				return null
			cue = spoken.cue
		row.lines.append([spoken.seat, spoken.text, wait, cue])
	return row

func _check_lines() -> void:
	for entry in lines:
		var trigger: String = entry.get("when", "")
		if trigger in TRIGGERS_WITH_COUNT:
			if int(entry.get("count", 0)) < 1:
				push_error("DialogueLines: '%s' needs a count of 1 or more" % trigger)
		elif not trigger in TRIGGERS_WITHOUT_COUNT:
			push_error("DialogueLines: unknown trigger '%s'" % trigger)
		if trigger in ["after_turns", "every_turns"] and int(entry.get("count", 0)) > GameManager.MAX_TURNS:
			push_error("DialogueLines: a round only has %d turns" % GameManager.MAX_TURNS)
