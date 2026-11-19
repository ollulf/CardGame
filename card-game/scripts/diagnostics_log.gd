extends Node

const MAX_AGE_SECONDS := 600.0
const MAX_ERRORS := 100
const MAX_OUTPUT_LINES := 300
const MAX_LINE_LENGTH := 400
const FINGERPRINT_ERROR_TYPES := [Logger.ERROR_TYPE_ERROR, Logger.ERROR_TYPE_SCRIPT]


class Capture extends Logger:
	var mutex := Mutex.new()
	var errors: Array[Dictionary] = []
	var output: Array[Dictionary] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var message := rationale if not rationale.is_empty() else code
		var id_file := file
		var id_function := function
		if not script_backtraces.is_empty() and script_backtraces[0].get_frame_count() > 0:
			id_file = script_backtraces[0].get_frame_file(0)
			id_function = script_backtraces[0].get_frame_function(0)
		var text := "%s: %s (%s:%d in %s)" % [_type_name(error_type), message, file, line, function]
		for backtrace in script_backtraces:
			text += "\n" + backtrace.format()
		_add(errors, MAX_ERRORS, {
			"text": text,
			"type": error_type,
			"fingerprint": ReportSanitizer.fingerprint(id_file, id_function, message),
		})

	func _log_message(message: String, error: bool) -> void:
		_add(output, MAX_OUTPUT_LINES, {"text": ("ERR " if error else "") + message.strip_edges().left(MAX_LINE_LENGTH)})

	func _add(list: Array[Dictionary], limit: int, entry: Dictionary) -> void:
		entry["at"] = Time.get_ticks_msec() / 1000.0
		mutex.lock()
		list.append(entry)
		if list.size() > limit:
			list.pop_front()
		mutex.unlock()

	func recent(list: Array[Dictionary]) -> Array[Dictionary]:
		var oldest := Time.get_ticks_msec() / 1000.0 - MAX_AGE_SECONDS
		mutex.lock()
		var result := list.filter(func(entry: Dictionary) -> bool: return entry["at"] >= oldest)
		mutex.unlock()
		return result

	func _type_name(error_type: int) -> String:
		match error_type:
			Logger.ERROR_TYPE_WARNING:
				return "WARNING"
			Logger.ERROR_TYPE_SCRIPT:
				return "SCRIPT ERROR"
			Logger.ERROR_TYPE_SHADER:
				return "SHADER ERROR"
		return "ERROR"


var _capture := Capture.new()


func _init() -> void:
	OS.add_logger(_capture)


func _exit_tree() -> void:
	OS.remove_logger(_capture)


func get_errors() -> Array[String]:
	return _lines(_capture.recent(_capture.errors))


func get_output() -> Array[String]:
	return _lines(_capture.recent(_capture.output))


func get_fingerprint() -> String:
	var errors := _capture.recent(_capture.errors)
	errors.reverse()
	for entry in errors:
		if entry["type"] in FINGERPRINT_ERROR_TYPES:
			return entry["fingerprint"]
	return ""


func _lines(entries: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for entry in entries:
		lines.append(ReportSanitizer.clean(entry["text"]))
	return lines
