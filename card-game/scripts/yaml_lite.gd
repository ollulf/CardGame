class_name YamlLite
extends RefCounted

const TAB_WIDTH := 4

var data: Array = []
var item_lines: Array = []
var entry_keys: Array = []
var raw_keys: Array = []

var _all_items: Array = []
var _tokens: Array = []
var _pos := 0
var _source := ""
var _failed := false

static func parse_file(path: String, entry_keys_list: Array = [], raw_keys_list: Array = []) -> YamlLite:
	var result := YamlLite.new()
	result._source = path.get_file()
	result.entry_keys = entry_keys_list
	result.raw_keys = raw_keys_list
	if not FileAccess.file_exists(path):
		push_error("%s: file not found (%s)" % [result._source, path])
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("%s: cannot open file (error %d)" % [result._source, FileAccess.get_open_error()])
		return result
	result.parse(file.get_as_text())
	return result

func parse(text: String, source := "") -> Array:
	if source != "":
		_source = source
	data = []
	item_lines = []
	_all_items = []
	_tokens = _tokenize(text)
	_pos = 0
	while _pos < _tokens.size():
		var indent: int = _tokens[_pos].indent
		if _is_item(_tokens[_pos].content):
			_parse_list(indent, true)
		elif _starts_entry(_tokens[_pos].content):
			_parse_entries(indent, true)
		else:
			_warn(_tokens[_pos].line, "expected a list item starting with '- '")
			_skip_block(indent)
	return data

func line_of(item: Variant) -> int:
	for entry in _all_items:
		if is_same(entry[0], item):
			return entry[1]
	return 0

func _tokenize(text: String) -> Array:
	var tokens: Array = []
	var lines := text.replace("\r", "").split("\n")
	var number := 0
	while number < lines.size():
		var raw: String = lines[number]
		number += 1
		var start := number
		if start == 1 and not raw.is_empty() and raw.unicode_at(0) == 0xFEFF:
			raw = raw.substr(1)
		var content := raw.strip_edges()
		if content == "" or content.begins_with("#"):
			continue
		var indent := 0
		for c in raw:
			if c == " ":
				indent += 1
			elif c == "\t":
				indent += TAB_WIDTH - indent % TAB_WIDTH
			else:
				break
		while _has_open_quote(content) and number < lines.size():
			var next := String(lines[number]).strip_edges()
			if next.begins_with("- ") or next == "-" or _key_split(next) >= 0:
				break
			content += " " + next
			number += 1
		tokens.append({"indent": indent, "content": content, "line": start})
	return tokens

func _has_open_quote(content: String) -> bool:
	var rest := content
	while rest.begins_with("- "):
		rest = rest.substr(2).strip_edges(true, false)
	var split := _key_split(rest)
	if split >= 0:
		rest = rest.substr(split + 1).strip_edges(true, false)
	if rest.begins_with("\""):
		var i := 1
		while i < rest.length():
			if rest[i] == "\\":
				i += 1
			elif rest[i] == "\"":
				return false
			i += 1
		return true
	if rest.begins_with("'"):
		var j := 1
		while j < rest.length():
			if rest[j] == "'":
				if j + 1 < rest.length() and rest[j + 1] == "'":
					j += 1
				else:
					return false
			j += 1
		return true
	return false

func _warn(line: int, message: String) -> void:
	_failed = true
	push_error("%s line %d: %s" % [_source, line, message])

func _is_item(content: String) -> bool:
	return content == "-" or content.begins_with("- ")

func _key_split(content: String) -> int:
	var colon := content.find(":")
	while colon > 0:
		if colon + 1 == content.length() or content[colon + 1] == " ":
			var key := content.substr(0, colon)
			for c in key:
				if not (c.is_valid_identifier() or c == "-"):
					return -1
			return colon
		colon = content.find(":", colon + 1)
	return -1

func _starts_entry(content: String) -> bool:
	var split := _key_split(content)
	return split >= 0 and content.substr(0, split) in entry_keys

func _skip_block(indent: int) -> void:
	_pos += 1
	while _pos < _tokens.size() and _tokens[_pos].indent > indent:
		_pos += 1

func _check_leftover(indent: int) -> void:
	if _pos < _tokens.size() and _tokens[_pos].indent > indent:
		_warn(_tokens[_pos].line, "unexpected indentation")
		while _pos < _tokens.size() and _tokens[_pos].indent > indent:
			_pos += 1

func _parse_list(indent: int, top: bool) -> Variant:
	var items: Array = []
	var list_failed := false
	while _pos < _tokens.size() and _tokens[_pos].indent == indent and _is_item(_tokens[_pos].content):
		var token: Dictionary = _tokens[_pos]
		var rest: String = token.content.substr(1).strip_edges(true, false)
		var offset: int = token.content.length() - rest.length()
		_failed = false
		var value: Variant = null
		if rest == "":
			_pos += 1
			if _pos < _tokens.size() and _tokens[_pos].indent > indent:
				value = _parse_block(_tokens[_pos].indent)
			else:
				_warn(token.line, "empty list item")
		else:
			_tokens[_pos] = {"indent": indent + offset, "content": rest, "line": token.line}
			value = _parse_block(indent + offset)
		if _failed or value == null:
			list_failed = true
			continue
		items.append(value)
		_all_items.append([value, token.line])
		if top:
			data.append(value)
			item_lines.append(token.line)
	_check_leftover(indent)
	_failed = list_failed or _failed
	return items

func _parse_entries(indent: int, top: bool) -> Variant:
	var items: Array = []
	var list_failed := false
	while _pos < _tokens.size() and _tokens[_pos].indent == indent and _starts_entry(_tokens[_pos].content):
		var line: int = _tokens[_pos].line
		_failed = false
		var value: Variant = _parse_map(indent, true)
		if _failed or value == null:
			list_failed = true
			continue
		items.append(value)
		_all_items.append([value, line])
		if top:
			data.append(value)
			item_lines.append(line)
	_check_leftover(indent)
	_failed = list_failed or _failed
	return items

func _parse_block(indent: int) -> Variant:
	var content: String = _tokens[_pos].content
	if _is_item(content):
		return _parse_list(indent, false)
	if _starts_entry(content):
		return _parse_entries(indent, false)
	if _key_split(content) >= 0:
		return _parse_map(indent)
	var line: int = _tokens[_pos].line
	_pos += 1
	return _parse_scalar(content, line)

func _parse_map(indent: int, entry := false) -> Variant:
	var map := {}
	var ok := true
	while _pos < _tokens.size() and _tokens[_pos].indent == indent and not _is_item(_tokens[_pos].content):
		var token: Dictionary = _tokens[_pos]
		if entry and not map.is_empty() and _starts_entry(token.content):
			break
		var split := _key_split(token.content)
		_pos += 1
		if split < 0:
			_warn(token.line, "expected 'key: value'")
			ok = false
			continue
		var key: String = token.content.substr(0, split)
		var rest: String = token.content.substr(split + 1).strip_edges()
		if rest.begins_with("#"):
			rest = ""
		var value: Variant = null
		if rest == "" and key in raw_keys and _pos < _tokens.size() and _tokens[_pos].indent > indent and not _is_item(_tokens[_pos].content):
			value = {"rows": _collect_rows(indent)}
		elif rest == "":
			if _pos < _tokens.size() and (_tokens[_pos].indent > indent or (_tokens[_pos].indent == indent and _is_item(_tokens[_pos].content))):
				value = _parse_block(_tokens[_pos].indent)
		else:
			value = _parse_scalar(rest, token.line)
		if _failed:
			ok = false
		if map.has(key):
			_warn(token.line, "duplicate key '%s': each key may appear only once per entry, start a new entry for a second block" % key)
			ok = false
		map[key] = value
		if entry and map.size() == 1 and rest != "" and _pos < _tokens.size() and _tokens[_pos].indent > indent and not _is_item(_tokens[_pos].content) and _key_split(_tokens[_pos].content) >= 0:
			var inner_line: int = _tokens[_pos].line
			var inner: Variant = _parse_map(_tokens[_pos].indent)
			if inner == null:
				ok = false
				continue
			for inner_key in inner:
				if map.has(inner_key):
					_warn(inner_line, "duplicate key '%s'" % inner_key)
					ok = false
				map[inner_key] = inner[inner_key]
	_check_leftover(indent)
	if not ok:
		_failed = true
		return null
	return map

func _collect_rows(indent: int) -> Array:
	var rows: Array = []
	while _pos < _tokens.size() and _tokens[_pos].indent > indent:
		var token: Dictionary = _tokens[_pos]
		rows.append({"line": token.line, "indent": token.indent, "text": token.content})
		_pos += 1
	return rows

func _parse_scalar(text: String, line: int) -> Variant:
	if text.begins_with("\""):
		return _parse_quoted(text, line, "\"")
	if text.begins_with("'"):
		return _parse_quoted(text, line, "'")
	var comment := text.find(" #")
	if comment >= 0:
		text = text.substr(0, comment).strip_edges()
	if text.is_valid_int():
		return text.to_int()
	return text

func _parse_quoted(text: String, line: int, quote: String) -> Variant:
	var out := ""
	var i := 1
	while i < text.length():
		var c := text[i]
		if quote == "\"" and c == "\\":
			i += 1
			if i >= text.length():
				break
			match text[i]:
				"n":
					out += "\n"
				"t":
					out += "\t"
				_:
					out += text[i]
		elif c == quote:
			if quote == "'" and i + 1 < text.length() and text[i + 1] == "'":
				out += "'"
				i += 1
			else:
				var tail := text.substr(i + 1).strip_edges()
				if tail != "" and not tail.begins_with("#"):
					_warn(line, "unexpected text after closing quote")
					return null
				return out
		else:
			out += c
		i += 1
	_warn(line, "string is missing its closing quote")
	return null
