extends CanvasLayer
class_name MatchLoserBanner

signal dismissed

const BG_COLOR := Color(0.121569, 0.117647, 0.14902, 1)
const BORDER_COLOR := Color(0.239216, 0.219608, 0.329412, 1)
const TEXT_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const FONT_SIZE := 40
const SHOW_TIME := 2.0

var text := ""

var _panel: PanelContainer

static func show_for(host: Node, looser_id: int) -> void:
	var banner := MatchLoserBanner.new()
	banner.text = GameManager._message_name(looser_id) + " lost the match!"
	host.add_child(banner)
	await banner.dismissed
	banner.queue_free()

func _ready() -> void:
	layer = 110
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(4)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", InteractionManager.font_px(FONT_SIZE))
	_panel.add_child(label)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(_panel)
	if Engine.get_write_movie_path() != "" or DisplayServer.get_name() == "headless":
		get_tree().create_timer(SHOW_TIME, false).timeout.connect(func(): dismissed.emit())

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	InteractionManager.skip_next_double_click()
	dismissed.emit()
