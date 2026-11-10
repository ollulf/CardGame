extends CanvasLayer

@onready var message_label := %MessageLabel

var _message_token: int = 0

const BG_COLOR := Color(0.121569, 0.117647, 0.14902, 1)
const BORDER_COLOR := Color(0.239216, 0.219608, 0.329412, 1)
const TEXT_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const FONT_SIZE := 20
const TEXT_WIDTH := 360.0
const BOX_CENTER_Y_OFFSET := 113.0

var _panel: PanelContainer

func _build_box() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	message_label.reparent(_panel, false)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	message_label.add_theme_color_override("font_color", TEXT_COLOR)
	message_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_panel.resized.connect(_place_box)
	_place_box()

func _place_box() -> void:
	var view := _panel.get_viewport_rect().size
	_panel.position = Vector2((view.x - _panel.size.x) * 0.5, view.y * 0.5 + BOX_CENTER_Y_OFFSET - _panel.size.y * 0.5).round()

func _ready() -> void:
	_build_box()
	GameManager.connect("send_message", _message)
	clear()

func _message(text: String) -> void:
	_message_token += 1
	var my_token := _message_token

	message_label.text = text
	visible = true
	message_label.visible = true
	_panel.reset_size()
	_place_box()

	await get_tree().create_timer(3.0, false).timeout

	# If another message started meanwhile, abort
	if my_token != _message_token:
		return

	clear()

func clear():
	message_label.text = ""
	visible = false
