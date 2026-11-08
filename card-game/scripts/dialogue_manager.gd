extends Node

signal line_started(player_id: int, text: String)
signal closed

const SPEECH_BUBBLE := preload("res://scenes/speech_bubble.tscn")
const SEAT_COUNT := 3
const SEAT_OFFSETS := [Vector2(-276, -18), Vector2(66, 0), Vector2(-66, 0)]
const TRIGGERS := ["match_start", "round_start", "turn_start", "turn_end", "round_end", "match_end"]
const ROUND_TRIGGERS := ["round_start", "turn_start", "turn_end", "round_end"]
const TURN_TRIGGERS := ["turn_start", "turn_end"]
const TRIGGER_ALIASES := {"start": "match_start", "end": "match_end"}
const ANY := 0
const NO_SEAT := -1
const AUTO_ADVANCE_HOLD := 1.5
const DIALOGUE_LAYER := 100
const LINES_PATH := "res://dialogue_lines.yaml"
const CUES := ["show_deck", "deal_cards", "show_trump", "show_won_turns", "show_one_turns", "show_life_cards", "show_purse", "show_cigs", "ai_one_smokes", "ai_two_smokes", "ai_1_pays", "ai_2_pays", "you_pay"]
const PAY_CUES := {"you_pay": 0, "ai_1_pays": 1, "ai_2_pays": 2}

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
var _match := 0
var _round := 0
var _silent := false

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
	GameManager.turn_started.connect(_on_turn_started)
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

func skip_all(silent: bool) -> void:
	_silent = silent
	if not silent:
		return
	_waiting.clear()
	_queue.clear()
	if _speaking_seat != NO_SEAT:
		_bubble.close_line()
		_speaking_seat = NO_SEAT
		if not _running_cue:
			_close()

func _enqueue(player_id: int, text: String, cue: String) -> void:
	if _silent:
		if cue != "":
			for cue_name in cue.split(","):
				GameManager.run_cue(cue_name)
		return
	var was_open := is_open()
	_queue.append([player_id, text, cue])
	if not was_open:
		_open()
		_show_next()

func is_open() -> bool:
	return _speaking_seat != NO_SEAT or _running_cue or not _queue.is_empty()

func has_cue(match_number: int, trigger: String, cue: String) -> bool:
	for entry in lines:
		if entry.when != trigger or not _matches(entry.match_number, match_number):
			continue
		for line in entry.lines:
			if cue in str(line[3]).split(","):
				return true
	return false

func match_pays_prize(match_number: int) -> bool:
	for entry in lines:
		if not _matches(entry.match_number, match_number):
			continue
		for line in entry.lines:
			for cue in str(line[3]).split(",", false):
				if PAY_CUES.has(cue.split(" ")[0]):
					return true
	return false

func match_uses_cue(cue: String) -> bool:
	for trigger in TRIGGERS:
		if has_cue(_match, trigger, cue):
			return true
	return false

func upcoming_match() -> int:
	return _match if _match_running else _match + 1

func upcoming_match_uses_cue(cue: String) -> bool:
	var number := upcoming_match()
	for trigger in TRIGGERS:
		if has_cue(number, trigger, cue):
			return true
	return false

func wait_until_idle() -> void:
	while is_open():
		await closed

func clear_waiting() -> void:
	_drop_waiting()

func rewind_to_match(match_number: int) -> void:
	_match = maxi(0, match_number - 1)
	_match_running = false
	_round = 0

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventMouse or InteractionManager.is_table_blocked():
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
			for cue_name in line[2].split(","):
				await GameManager.run_cue(cue_name)
			_running_cue = false
		if line[0] == NO_SEAT:
			continue
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
	if not _match_running:
		_match_running = true
		_match += 1
		_round = 0
	_round += 1
	if _round == 1:
		_fire("match_start")
	_fire("round_start", _round)

func _on_turn_started(turn_index: int, _starting_player_id: int) -> void:
	_fire("turn_start", _round, turn_index)

func _on_turn_completed(turn_index: int, _winner_id: int) -> void:
	_fire("turn_end", _round, turn_index)

func _on_round_finished(_loosers) -> void:
	if not GameManager.get_total_loosers().is_empty():
		return
	_fire("round_end", _round)

func _on_match_lost(_looser_id: int) -> void:
	if not _match_running:
		return
	_match_running = false
	_drop_waiting()
	_fire("match_end")

func _fire(trigger: String, round_number := ANY, turn_number := ANY) -> void:
	for entry in lines:
		if entry.when != trigger or not _matches(entry.match_number, _match):
			continue
		if _matches(entry.round, round_number) and _matches(entry.turn, turn_number):
			_queue_entry(entry)

func _matches(wanted: int, actual: int) -> bool:
	return wanted == ANY or wanted == actual

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
	return rows_from_yaml(YamlLite.parse_file(path, ["match", "when"], ["lines"]))

static func rows_from_yaml(yaml: YamlLite) -> Array:
	var rows: Array = []
	for i in yaml.data.size():
		_clean_group(yaml.data[i], yaml.item_lines[i], yaml, rows)
	return rows

static func _clean_group(raw, line: int, yaml: YamlLite, rows: Array) -> void:
	if raw is Dictionary and raw.has("when"):
		push_error("DialogueLines line %d: dialogues now sit in match groups ('match: 1' with a 'dialogues:' block)" % line)
		return
	if not raw is Dictionary or not raw.get("dialogues") is Array or raw.dialogues.is_empty():
		push_error("DialogueLines line %d: a match group needs a list of 'dialogues'" % line)
		return
	for key in raw.keys():
		if not key in ["match", "dialogues"]:
			push_error("DialogueLines line %d: unknown key '%s' in a match group (allowed: match, dialogues)" % [line, key])
	var match_number := ANY
	if raw.has("match") and not (raw["match"] is String and raw["match"] == "any"):
		if not raw["match"] is int or raw["match"] < 1:
			push_error("DialogueLines line %d: 'match' must be a whole number of 1 or more, or 'any'" % line)
			return
		match_number = raw["match"]
	for dialogue in raw.dialogues:
		var row_line := yaml.line_of(dialogue)
		var row = _clean_row(dialogue, row_line if row_line > 0 else line, match_number, yaml)
		if row != null:
			rows.append(row)

static func _clean_row(raw, line: int, match_number: int, yaml: YamlLite):
	if not raw is Dictionary or not raw.get("when") is String:
		push_error("DialogueLines line %d: dialogue needs a 'when'" % line)
		return null
	if TRIGGER_ALIASES.has(raw.when):
		raw.when = TRIGGER_ALIASES[raw.when]
	if not raw.when in TRIGGERS:
		push_error("DialogueLines line %d: unknown 'when' '%s' (allowed: %s)" % [line, raw.when, ", ".join(TRIGGERS)])
		return null
	if raw.has("lines") and (raw.lines == null or (raw.lines is String and raw.lines.strip_edges().is_empty()) or ((raw.lines is Array or raw.lines is Dictionary) and raw.lines.is_empty())):
		return null
	if not (raw.get("lines") is Array or raw.get("lines") is Dictionary) or raw.lines.is_empty():
		push_error("DialogueLines line %d: dialogue needs a list of 'lines'" % line)
		return null
	for key in raw.keys():
		if not key in ["when", "round", "turn", "lines"]:
			push_error("DialogueLines line %d: unknown key '%s' in a dialogue (allowed: when, round, turn, lines)" % [line, key])
	var row := {"when": raw.when, "match_number": match_number, "round": ANY, "turn": ANY, "line": line, "lines": []}
	for filter in ["round", "turn"]:
		if not raw.has(filter):
			continue
		var allowed: Array = ROUND_TRIGGERS if filter == "round" else TURN_TRIGGERS
		if not raw.when in allowed:
			var hint := " (use when: turn_start to speak at the start of a turn)" if raw.when == "round_start" else ""
			push_error("DialogueLines line %d: '%s' only works with when: %s%s" % [line, filter, ", ".join(allowed), hint])
			return null
		if not raw[filter] is int or raw[filter] < 1:
			push_error("DialogueLines line %d: '%s' must be a whole number of 1 or more" % [line, filter])
			return null
		row[filter] = raw[filter]
	var spoken_lines = _rows_to_lines(raw.lines.rows) if raw.lines is Dictionary else _items_to_lines(raw.lines, line, yaml)
	if spoken_lines == null:
		return null
	row.lines = spoken_lines
	return row

static func _rows_to_lines(rows: Array):
	var spoken_lines: Array = []
	var base: int = rows[0].indent
	var cue := ""
	var wait := 0
	var last_line := NO_SEAT
	for raw_row in rows:
		var row_line: int = raw_row.line
		if raw_row.indent > base:
			if spoken_lines.is_empty() or last_line == NO_SEAT:
				push_error("DialogueLines line %d: this row is indented deeper, but there is no spoken line above it to continue" % row_line)
				return null
			spoken_lines[-1][1] += " " + raw_row.text
			continue
		if raw_row.indent < base:
			push_error("DialogueLines line %d: indentation does not match the rows above it" % row_line)
			return null
		last_line = NO_SEAT
		var colon: int = raw_row.text.find(":")
		var key: String = raw_row.text.substr(0, colon).strip_edges() if colon >= 0 else ""
		var value: String = raw_row.text.substr(colon + 1).strip_edges() if colon >= 0 else ""
		if key.is_valid_int():
			var seat := key.to_int()
			if seat < 0 or seat >= SEAT_COUNT:
				push_error("DialogueLines line %d: seat %d does not exist" % [row_line, seat])
				return null
			if value == "":
				push_error("DialogueLines line %d: seat %d has no text" % [row_line, seat])
				return null
			spoken_lines.append([seat, value, wait, cue])
			cue = ""
			wait = 0
			last_line = row_line
		elif key == "cue":
			var checked := _check_cue(value, row_line)
			if checked == "":
				return null
			cue = checked if cue == "" else cue + "," + checked
		elif key == "wait_for_cards_played":
			if wait > 0:
				push_error("DialogueLines line %d: only one 'wait_for_cards_played' per spoken line" % row_line)
				return null
			wait = _check_wait(value.to_int() if value.is_valid_int() else value, row_line)
			if wait == 0:
				return null
		else:
			push_error("DialogueLines line %d: expected '<seat>: <text>', 'cue: <name>' or 'wait_for_cards_played: <number>'" % row_line)
			return null
	if wait > 0:
		push_error("DialogueLines line %d: 'wait_for_cards_played' needs a spoken line below it" % rows[-1].line)
		return null
	if cue != "" and not spoken_lines.is_empty():
		spoken_lines.append([NO_SEAT, "", 0, cue])
	if spoken_lines.is_empty():
		push_error("DialogueLines line %d: a dialogue needs at least one spoken line" % rows[0].line)
		return null
	return spoken_lines

static func _items_to_lines(items: Array, line: int, yaml: YamlLite):
	var spoken_lines: Array = []
	for spoken in items:
		var spoken_line := yaml.line_of(spoken)
		if spoken_line == 0:
			spoken_line = line
		if not spoken is Dictionary or not spoken.get("seat") is int or not spoken.get("text") is String:
			push_error("DialogueLines line %d: every line needs a 'seat' number and a 'text'" % spoken_line)
			return null
		if spoken.seat < 0 or spoken.seat >= SEAT_COUNT:
			push_error("DialogueLines line %d: seat %d does not exist" % [spoken_line, spoken.seat])
			return null
		for key in spoken.keys():
			if key == "after_played_cards":
				push_error("DialogueLines line %d: 'after_played_cards' was renamed to 'wait_for_cards_played'" % spoken_line)
			elif not key in ["seat", "text", "wait_for_cards_played", "cue"]:
				push_error("DialogueLines line %d: unknown key '%s' in a line (allowed: seat, text, wait_for_cards_played, cue)" % [spoken_line, key])
		var wait := 0
		if spoken.has("wait_for_cards_played"):
			wait = _check_wait(spoken.wait_for_cards_played, spoken_line)
			if wait == 0:
				return null
		var cue := ""
		if spoken.has("cue"):
			cue = _check_cue(spoken.cue, spoken_line)
			if cue == "":
				return null
		spoken_lines.append([spoken.seat, spoken.text, wait, cue])
	return spoken_lines

static func _check_wait(value, line: int) -> int:
	if not value is int or value < 1:
		push_error("DialogueLines line %d: 'wait_for_cards_played' must be a whole number of 1 or more" % line)
		return 0
	return value

static func _check_cue(value, line: int) -> String:
	var words := str(value).split(" ", false)
	if words.size() == 2 and PAY_CUES.has(words[0]):
		if not words[1].is_valid_int() or words[1].to_int() < 1:
			push_error("DialogueLines line %d: '%s' needs an amount of 1 or more, like '%s 30'" % [line, words[0], words[0]])
			return ""
		return "%s %d" % [words[0], words[1].to_int()]
	if not value in CUES:
		push_error("DialogueLines line %d: unknown cue '%s' (allowed: %s)" % [line, str(value), ", ".join(CUES)])
		return ""
	if value == "show_one_turns":
		return "show_won_turns"
	return value

func _check_lines() -> void:
	for entry in lines:
		if entry.turn > GameManager.MAX_TURNS:
			push_error("DialogueLines line %d: a round only has %d turns" % [entry.line, GameManager.MAX_TURNS])
