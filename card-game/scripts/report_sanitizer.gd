class_name ReportSanitizer

const MIN_USER_NAME_LENGTH := 3
const FINGERPRINT_LENGTH := 12
const TOKEN_MIN_LENGTH := 32
const ANSI_COLORS := "\\x1b\\[[0-9;]*m"
const RULES: Array = [
	["https?://[^\\s/]+:[^\\s/@]+@", "https://<credentials>@"],
	["(?i)\\b(token|password|passwd|secret|api[_-]?key|authorization)(\\s*[=:]\\s*)(?:bearer\\s+)?\\S+", "$1$2<redacted>"],
	["(?i)\\bbearer\\s+\\S+", "Bearer <redacted>"],
	["[\\w.+-]+@[\\w-]+(?:\\.[\\w-]+)+", "<email>"],
	["\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", "<ip>"],
	["\\b(?:[0-9a-fA-F]{1,4}:){5,7}[0-9a-fA-F]{1,4}\\b", "<ip>"],
	["\\b(?=[A-Za-z0-9_+/=-]*\\d)(?=[A-Za-z0-9_+/=-]*[A-Za-z])[A-Za-z0-9_+/=-]{%d,}\\b" % TOKEN_MIN_LENGTH, "<redacted>"],
	["(?i)(/home/|/Users/|[A-Z]:\\\\Users\\\\|[A-Z]:/Users/)[^/\\\\\\s]+", "$1<user>"],
]

static var _compiled: Array[Array] = []
static var _ansi: RegEx


static func clean(text: String) -> String:
	if _compiled.is_empty():
		_ansi = RegEx.create_from_string(ANSI_COLORS)
		for rule: Array in RULES:
			_compiled.append([RegEx.create_from_string(rule[0]), rule[1]])
	var result := _ansi.sub(text, "", true)
	result = result.replace(OS.get_user_data_dir(), "user:/")
	for rule: Array in _compiled:
		result = (rule[0] as RegEx).sub(result, rule[1], true)
	for variable in ["USER", "USERNAME"]:
		var user_name := OS.get_environment(variable)
		if user_name.length() >= MIN_USER_NAME_LENGTH:
			result = result.replace(user_name, "<user>")
	return result


static func fingerprint(file: String, function: String, message: String) -> String:
	var numbers := RegEx.create_from_string("0x[0-9a-fA-F]+|\\d+")
	var key := "%s|%s|%s" % [file, function, numbers.sub(message, "#", true)]
	return key.sha256_text().substr(0, FINGERPRINT_LENGTH)
