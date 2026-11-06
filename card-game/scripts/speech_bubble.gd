extends PanelContainer
class_name SpeechBubble

signal finished

enum TailSide { LEFT, RIGHT, DOWN }

const HIGHLIGHT_COLOR := "#ffcf6e"
const TAIL_COLOR := Color("3d3854")
const MAX_WIDTH := 230.0
const CHARS_PER_SECOND := 32.0
const HOLD_BASE := 1.8
const HOLD_PER_CHAR := 0.035
const FADE_TIME := 0.15

@onready var label: RichTextLabel = %Text

var tail_side := TailSide.LEFT
var is_talking := false

func _ready() -> void:
	visible = false

static func format_text(text: String) -> String:
	var highlight := RegEx.create_from_string("\\*([^*]+)\\*")
	return highlight.sub(text, "[color=%s]$1[/color]" % HIGHLIGHT_COLOR, true)

func show_line(text: String) -> void:
	is_talking = true
	label.text = format_text(text)
	label.visible_characters = 0
	_fit_to_text()
	modulate.a = 0.0
	visible = true
	queue_redraw()

	var total := label.get_total_character_count()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tween.parallel().tween_property(label, "visible_characters", total, total / CHARS_PER_SECOND)
	tween.tween_interval(HOLD_BASE + total * HOLD_PER_CHAR)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_on_line_done)

func place_at(anchor: Vector2) -> void:
	reset_size()
	match tail_side:
		TailSide.LEFT:
			position = anchor + Vector2(0.0, -size.y * 0.5)
		TailSide.RIGHT:
			position = anchor + Vector2(-size.x, -size.y * 0.5)
		TailSide.DOWN:
			position = anchor + Vector2(-size.x * 0.5, -size.y)
	queue_redraw()

func _fit_to_text() -> void:
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var width := font.get_string_size(label.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.custom_minimum_size.x = minf(ceilf(width) + 2.0, MAX_WIDTH)
	reset_size()

func _on_line_done() -> void:
	visible = false
	is_talking = false
	finished.emit()

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
