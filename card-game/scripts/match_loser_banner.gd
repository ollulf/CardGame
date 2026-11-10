extends CanvasLayer
class_name MatchLoserBanner

signal dismissed

const BG_COLOR := Color(0.121569, 0.117647, 0.14902, 1)
const BORDER_COLOR := Color(0.239216, 0.219608, 0.329412, 1)
const TEXT_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const ARROW_COLOR := Color(0.956863, 0.952941, 0.968627, 1)
const FONT_SIZE := 40
const SHOW_TIME := 2.0

var target: CanvasItem
var text := ""

var _panel: PanelContainer
var _time := 0.0
var _canvas: Control

static func show_for(host: Node, looser_id: int, looser_target: CanvasItem) -> void:
	var banner := MatchLoserBanner.new()
	banner.target = looser_target
	banner.text = GameManager._message_name(looser_id) + " lost the match!"
	host.add_child(banner)
	await banner.dismissed
	banner.queue_free()

func _ready() -> void:
	layer = 110
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_arrow)
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
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
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	if Engine.get_write_movie_path() != "" or DisplayServer.get_name() == "headless":
		get_tree().create_timer(SHOW_TIME, false).timeout.connect(func(): dismissed.emit())

func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()

func _target_center() -> Vector2:
	var xform := target.get_global_transform_with_canvas()
	if target is Control:
		return xform * ((target as Control).size * 0.5)
	return xform.origin

func _draw_arrow() -> void:
	if not is_instance_valid(target):
		return
	var from := _panel.get_global_rect().get_center()
	var to := _target_center()
	var dir := (to - from).normalized()
	var edge := from + dir * _edge_distance(dir)
	var bob := sin(_time * 8.0) * 6.0
	var tip := to - dir * 70.0 + dir * bob
	if tip.distance_to(from) <= edge.distance_to(from) + 40.0:
		return
	var start := edge + dir * 10.0
	var side := Vector2(-dir.y, dir.x)
	_canvas.draw_line(start, tip - dir * 22.0, ARROW_COLOR, 6.0)
	_canvas.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 30.0 + side * 18.0, tip - dir * 30.0 - side * 18.0]), ARROW_COLOR)

func _edge_distance(dir: Vector2) -> float:
	var half := _panel.size * 0.5
	var tx := half.x / maxf(absf(dir.x), 0.0001)
	var ty := half.y / maxf(absf(dir.y), 0.0001)
	return minf(tx, ty)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	InteractionManager.skip_next_double_click()
	dismissed.emit()
