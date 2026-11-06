class_name YamlLite
extends RefCounted

var data: Array = []
var item_lines: Array = []

var _tokens: Array = []
var _pos := 0
var _source := ""
var _failed := false

static func parse_file(path: String) -> YamlLite:
	var result := YamlLite.new()
	result._source = path.get_file()
	if not FileAccess.file_exists(path):
		push_warning("%s: file not found (%s)" % [result._source, path])
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("%s: cannot open file (error %d)" % [result._source, FileAccess.get_open_error()])
		return result
	result.parse(file.get_as_text())
	return result

func parse(text: String, source := "") -> Array:
	if source != "":
		_source = source
	data = []
	item_lines = []
	_tokens = _tokenize(text)
	_pos = 0
	while _pos < _tokens.size():
		var indent: int = _tokens[_pos].indent
		if _is_item(_tokens[_pos].content):
			_parse_list(indent, true)
		else:
			_warn(_tokens[_pos].line, "expected a list item starting with '- '")
			_skip_block(indent)
	return data

func _tokenize(text: String) -> Array:
	var tokens: Array = []
	var number := 0
	for raw in text.replace("\r", "").split("\n"):
		number += 1
		if number == 1 and raw.begins_with("﻿"):
			raw = raw.substr(1)
		var content := raw.strip_edges()
		if content == "" or content.begins_with("#"):
			continue
		var indent := raw.length() - raw.lstrip(" ").length()
		if raw.substr(indent).begins_with("\t"):
			_warn(number, "tabs are not allowed for indentation")
			continue
		tokens.append({"indent": indent, "content": content, "line": number})
	return tokens

func _warn(line: int, message: String) -> void:
	_failed = true
	push_warning("%s line %d: %s" % [_source, line, message])

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
		if top:
			data.append(value)
			item_lines.append(token.line)
	_check_leftover(indent)
	_failed = list_failed or _failed
	return items

func _parse_block(indent: int) -> Variant:
	var content: String = _tokens[_pos].content
	if _is_item(content):
		return _parse_list(indent, false)
	if _key_split(content) >= 0:
		return _parse_map(indent)
	var line: int = _tokens[_pos].line
	_pos += 1
	return _parse_scalar(content, line)

func _parse_map(indent: int) -> Variant:
	var map := {}
	var ok := true
	while _pos < _tokens.size() and _tokens[_pos].indent == indent and not _is_item(_tokens[_pos].content):
		var token: Dictionary = _tokens[_pos]
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
		if rest == "":
			if _pos < _tokens.size() and (_tokens[_pos].indent > indent or (_tokens[_pos].indent == indent and _is_item(_tokens[_pos].content))):
				value = _parse_block(_tokens[_pos].indent)
		else:
			value = _parse_scalar(rest, token.line)
		if _failed:
			ok = false
		if map.has(key):
			_warn(token.line, "duplicate key '%s'" % key)
			ok = false
		map[key] = value
	_check_leftover(indent)
	if not ok:
		_failed = true
		return null
	return map

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
