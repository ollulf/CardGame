extends PanelContainer
class_name SpeechBubble

enum TailSide { LEFT, RIGHT, DOWN, UP }

const HIGHLIGHT_COLOR := "#ffcf6e"
const TAIL_COLOR := Color("3d3854")
const INDICATOR_COLOR := Color(HIGHLIGHT_COLOR)
const INDICATOR_BOB_TIME := 0.35
const MAX_WIDTH := 230.0
const CHARS_PER_SECOND := 32.0
const FADE_TIME := 0.15
const TYPE_EVERY := 3

@onready var label: RichTextLabel = %Text

var pitch := 1.0
var tail_side := TailSide.LEFT
var is_typed := false

var _tween: Tween
var _indicator_time := 0.0
var _typing := false
var _last_chars := 0
var _letters_seen := 0

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if _typing:
		_type_sounds()
	if visible and is_typed:
		_indicator_time += delta
		queue_redraw()

static func format_text(text: String) -> String:
	var highlight := RegEx.create_from_string("\\*([^*]+)\\*")
	var result := ""
	var last := 0
	for m in highlight.search_all(text):
		result += text.substr(last, m.get_start() - last)
		result += keyword(m.get_string(1))
		last = m.get_end()
	return result + text.substr(last)

static func keyword(text: String, color: String = HIGHLIGHT_COLOR) -> String:
	return "[wave amp=12 freq=8][color=%s]%s[/color][/wave]" % [color, text]

static func type_sounds(text_label: RichTextLabel, from_chars: int, letters_seen: int, voice_pitch: float) -> int:
	var shown := text_label.visible_characters
	var parsed := text_label.get_parsed_text()
	for i in range(from_chars, mini(shown, parsed.length())):
		var c := parsed[i]
		if c.to_upper() == c.to_lower() and not c.is_valid_int():
			continue
		letters_seen += 1
		if letters_seen % TYPE_EVERY == 1:
			Sfx.play_type(voice_pitch)
	return letters_seen

func _type_sounds() -> void:
	var seen := SpeechBubble.type_sounds(label, _last_chars, _letters_seen, pitch)
	_letters_seen = seen
	_last_chars = maxi(_last_chars, label.visible_characters)

func show_line(text: String) -> void:
	_typing = true
	_last_chars = 0
	_letters_seen = 0
	is_typed = false
	label.text = format_text(text)
	label.visible_characters = 0
	_fit_to_text()
	modulate.a = 0.0
	visible = true
	queue_redraw()

	var total := label.get_total_character_count()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_tween.parallel().tween_property(label, "visible_characters", total, total / CHARS_PER_SECOND)
	_tween.tween_callback(_on_typed)

func complete_line() -> void:
	_typing = false
	_kill_tween()
	modulate.a = 1.0
	label.visible_characters = -1
	_on_typed()

func close_line() -> void:
	_typing = false
	_kill_tween()
	is_typed = false
	visible = false

func place_at(anchor: Vector2) -> void:
	reset_size()
	match tail_side:
		TailSide.LEFT:
			position = anchor + Vector2(0.0, -size.y * 0.5)
		TailSide.RIGHT:
			position = anchor + Vector2(-size.x, -size.y * 0.5)
		TailSide.DOWN:
			position = anchor + Vector2(-size.x * 0.5, -size.y)
		TailSide.UP:
			position = anchor + Vector2(-size.x * 0.5, 15.0)
	queue_redraw()

func _fit_to_text() -> void:
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var width := font.get_string_size(label.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.custom_minimum_size.x = minf(ceilf(width) + 2.0, MAX_WIDTH)
	reset_size()

func _on_typed() -> void:
	_typing = false
	is_typed = true
	_indicator_time = 0.0
	queue_redraw()

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _draw() -> void:
	var middle := size * 0.5
	match tail_side:
		TailSide.LEFT:
			draw_rect(Rect2(-9, middle.y - 6, 9, 12), TAIL_COLOR)
			draw_rect(Rect2(-15, middle.y - 3, 6, 6), TAIL_COLOR)
		TailSide.RIGHT:
			draw_rect(Rect2(size.x, middle.y - 6, 9, 12), TAIL_COLOR)
			draw_rect(Rect2(size.x + 9, middle.y - 3, 6, 6), TAIL_COLOR)
		TailSide.DOWN:
			draw_rect(Rect2(middle.x - 6, size.y, 12, 9), TAIL_COLOR)
			draw_rect(Rect2(middle.x - 3, size.y + 9, 6, 6), TAIL_COLOR)
		TailSide.UP:
			draw_rect(Rect2(middle.x - 6, -9, 12, 9), TAIL_COLOR)
			draw_rect(Rect2(middle.x - 3, -15, 6, 6), TAIL_COLOR)
	if is_typed:
		_draw_indicator()

func _draw_indicator() -> void:
	SpeechBubble.draw_arrow(self, Vector2(size.x - 18.0, size.y - 14.0), _indicator_time)

static func draw_arrow(canvas: CanvasItem, corner: Vector2, time: float) -> void:
	var bob := float(int(time / INDICATOR_BOB_TIME) % 2) * 2.0
	corner.y += bob
	canvas.draw_rect(Rect2(corner, Vector2(10, 2)), INDICATOR_COLOR)
	canvas.draw_rect(Rect2(corner + Vector2(2, 2), Vector2(6, 2)), INDICATOR_COLOR)
	canvas.draw_rect(Rect2(corner + Vector2(4, 4), Vector2(2, 2)), INDICATOR_COLOR)
