extends CanvasLayer

const MENU_LAYER := 118
const FADE_TIME := 0.15
const PANEL_WIDTH := 460.0
const SLIDER_STEP := 0.05
const AMBER := Color(1, 0.811765, 0.431373, 1)
const AMBER_DARK := Color(0.901961, 0.709804, 0.321569, 1)
const TRACK_COLOR := Color(0.12549, 0.121569, 0.156863, 1)
const TRACK_BORDER := Color(0.309804, 0.286275, 0.407843, 1)
const DIM_COLOR := Color(0.03, 0.03, 0.05, 0.72)
const VALUE_COLOR := Color(0.839216, 0.819608, 0.901961, 1)
const UI_PIXEL := 3
const SWITCH_SIZE := Vector2i(14, 8)
const KNOB_SIZE := Vector2i(4, 7)
const SLIDERS := [["Master", "Master"], ["Music", "Music"], ["Ambience", "Ambience"], ["Sound effects", "SFX"]]
const QUIT_TEXT := "Quit to title"
const QUIT_CONFIRM_TEXT := "Sure? Match progress is lost"
const PAUSED_TITLE := "Paused"
const OPTIONS_TITLE := "Options"
const RESUME_TEXT := "Resume"
const BACK_TEXT := "Back"

var _content: Control
var _sliders := {}
var _value_labels := {}
var _mute_toggle: CheckButton
var _fullscreen_toggle: CheckButton
var _quit_button: Button
var _resume_button: Button
var _paused_game := false
var _was_blocked := false
var _pointer_parent: Node
var _pointer_index := 0
var _quit_armed := false
var _tween: Tween
var _title: Label

func _init() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()
	hide()
	Settings.fullscreen_changed.connect(_fullscreen_toggle.set_pressed_no_signal)

func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if visible:
		get_viewport().set_input_as_handled()
		close()
	elif not SceneTransition.is_running():
		get_viewport().set_input_as_handled()
		if get_tree().get_first_node_in_group(StartMenu.GROUP) != null:
			open_options()
		else:
			open()

func open_options() -> void:
	_open_as(true)

func open() -> void:
	_open_as(false)

func _open_as(options_mode: bool) -> void:
	if visible:
		return
	_title.text = OPTIONS_TITLE if options_mode else PAUSED_TITLE
	_resume_button.text = BACK_TEXT if options_mode else RESUME_TEXT
	_quit_button.visible = not options_mode
	InteractionManager.cancel_press()
	_was_blocked = InteractionManager.is_table_blocked()
	InteractionManager.set_table_blocked(true)
	_paused_game = not get_tree().paused
	get_tree().paused = true
	_sync_controls()
	_set_quit_armed(false)
	_lift_pointer()
	show()
	_content.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_content, "modulate:a", 1.0, FADE_TIME)
	_resume_button.grab_focus.call_deferred()

func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	if _tween:
		_tween.kill()
	hide()
	_lower_pointer()
	if _paused_game:
		get_tree().paused = false
	_paused_game = false
	InteractionManager.skip_next_double_click()
	if not _was_blocked:
		InteractionManager.set_table_blocked(false)
		if DialogueManager.is_open():
			get_viewport().physics_object_picking = false

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = center
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = Label.new()
	var title := _title
	title.text = PAUSED_TITLE
	title.theme_type_variation = &"HeadlineLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_caps("Volume"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for entry in SLIDERS:
		_add_slider_row(grid, entry[0], entry[1])
	_mute_toggle = _toggle("Mute all sound")
	_mute_toggle.toggled.connect(func(on: bool) -> void: Settings.set_muted(on))
	box.add_child(_mute_toggle)
	var display_caption := _caps("Display")
	box.add_child(display_caption)
	_fullscreen_toggle = _toggle("Fullscreen")
	_fullscreen_toggle.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(_fullscreen_toggle)
	display_caption.visible = Settings.can_fullscreen()
	_fullscreen_toggle.visible = Settings.can_fullscreen()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_resume_button = Button.new()
	_resume_button.text = RESUME_TEXT
	_resume_button.theme_type_variation = &"ButtonPrimary"
	_resume_button.custom_minimum_size = Vector2(150, 40)
	_resume_button.pressed.connect(close)
	buttons.add_child(_resume_button)
	_quit_button = Button.new()
	_quit_button.custom_minimum_size = Vector2(150, 40)
	_quit_button.pressed.connect(_on_quit_pressed)
	buttons.add_child(_quit_button)

func _caps(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.theme_type_variation = &"CapsLabel"
	return label

func _toggle(text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_color_override("font_hover_color", AMBER)
	toggle.add_theme_color_override("font_hover_pressed_color", AMBER)
	toggle.add_theme_color_override("font_pressed_color", Color.WHITE)
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		toggle.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	toggle.add_theme_constant_override("icon_max_width", 0)
	toggle.add_theme_icon_override("checked", _switch_icon(true, false))
	toggle.add_theme_icon_override("unchecked", _switch_icon(false, false))
	toggle.add_theme_icon_override("checked_disabled", _switch_icon(true, true))
	toggle.add_theme_icon_override("unchecked_disabled", _switch_icon(false, true))
	toggle.add_theme_icon_override("checked_mirrored", _switch_icon(true, false))
	toggle.add_theme_icon_override("unchecked_mirrored", _switch_icon(false, false))
	return toggle

func _add_slider_row(grid: GridContainer, text: String, bus: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(130, 0)
	grid.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = SLIDER_STEP
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_stylebox_override("slider", _track_style(TRACK_COLOR, TRACK_BORDER))
	slider.add_theme_stylebox_override("grabber_area", _track_style(AMBER_DARK, AMBER_DARK))
	slider.add_theme_stylebox_override("grabber_area_highlight", _track_style(AMBER, AMBER))
	slider.add_theme_icon_override("grabber", _knob_icon(Color.WHITE))
	slider.add_theme_icon_override("grabber_highlight", _knob_icon(AMBER))
	slider.add_theme_icon_override("grabber_disabled", _knob_icon(TRACK_BORDER))
	slider.value_changed.connect(_on_slider_changed.bind(bus))
	if bus == "SFX":
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play_button())
	grid.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(46, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", VALUE_COLOR)
	grid.add_child(value)
	_sliders[bus] = slider
	_value_labels[bus] = value

static func _switch_icon(on: bool, disabled: bool) -> Texture2D:
	var image := Image.create(SWITCH_SIZE.x, SWITCH_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var track := AMBER_DARK if on else TRACK_COLOR
	var edge := AMBER_DARK.darkened(0.35) if on else TRACK_BORDER
	var knob := Color.WHITE if on else VALUE_COLOR.darkened(0.25)
	if disabled:
		track = TRACK_COLOR
		edge = TRACK_BORDER
		knob = TRACK_BORDER
	image.fill_rect(Rect2i(Vector2i.ZERO, SWITCH_SIZE), edge)
	image.fill_rect(Rect2i(1, 1, SWITCH_SIZE.x - 2, SWITCH_SIZE.y - 2), track)
	for corner in [Vector2i(0, 0), Vector2i(SWITCH_SIZE.x - 1, 0), Vector2i(0, SWITCH_SIZE.y - 1), SWITCH_SIZE - Vector2i.ONE]:
		image.set_pixelv(corner, Color(0, 0, 0, 0))
	var knob_size := SWITCH_SIZE.y - 4
	var knob_x := SWITCH_SIZE.x - 2 - knob_size if on else 2
	image.fill_rect(Rect2i(knob_x, 2, knob_size, knob_size), knob)
	image.fill_rect(Rect2i(knob_x, 2 + knob_size - 1, knob_size, 1), knob.darkened(0.25))
	return _pixel_texture(image)


static func _knob_icon(color: Color) -> Texture2D:
	var image := Image.create(KNOB_SIZE.x, KNOB_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(TRACK_BORDER.darkened(0.4))
	image.fill_rect(Rect2i(1, 1, KNOB_SIZE.x - 2, KNOB_SIZE.y - 2), color)
	image.fill_rect(Rect2i(1, KNOB_SIZE.y - 2, KNOB_SIZE.x - 2, 1), color.darkened(0.25))
	return _pixel_texture(image)


static func _pixel_texture(image: Image) -> Texture2D:
	image.resize(image.get_width() * UI_PIXEL, image.get_height() * UI_PIXEL, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _track_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _sync_controls() -> void:
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(Settings.get_volume(bus))
		_update_value_label(bus)
	_mute_toggle.set_pressed_no_signal(Settings.muted)
	Settings.fullscreen = Settings.is_fullscreen()
	_fullscreen_toggle.set_pressed_no_signal(Settings.fullscreen)

func _on_slider_changed(value: float, bus: String) -> void:
	Settings.set_volume(bus, value)
	_update_value_label(bus)

func _update_value_label(bus: String) -> void:
	_value_labels[bus].text = "%d%%" % roundi(Settings.get_volume(bus) * 100.0)

func _on_quit_pressed() -> void:
	if not _quit_armed:
		_set_quit_armed(true)
		return
	Settings.save_settings()
	_quit_button.disabled = true
	_resume_button.disabled = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.reload()")
		return
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()

func _set_quit_armed(armed: bool) -> void:
	_quit_armed = armed
	_quit_button.disabled = false
	_resume_button.disabled = false
	_quit_button.text = QUIT_CONFIRM_TEXT if armed else QUIT_TEXT
	_quit_button.custom_minimum_size = Vector2(260 if armed else 150, 40)

func _lift_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or not is_instance_valid(pointer) or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)

func _lower_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or not is_instance_valid(pointer) or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, mini(_pointer_index, _pointer_parent.get_child_count() - 1))
	_pointer_parent = null
