extends CanvasLayer
class_name ReportForm

enum Kind { BUG, FEEDBACK }

const FORM_LAYER := 119
const ACTION := "report_bug"
const PANEL_WIDTH := 460.0
const TEXT_HEIGHT := 110.0
const FADE_TIME := 0.15
const THANKS_TIME := 1.0
const REPORTS_DIR := "user://reports"
const IMPORTANCE := ["Minor", "Annoying", "Blocks progress"]
const DEFAULT_IMPORTANCE := 1
const MOODS := ["Not fun", "Okay", "Fun", "Great"]
const TITLES := {Kind.BUG: "Report a Bug", Kind.FEEDBACK: "Send Feedback"}
const PROMPTS := {Kind.BUG: "What happened?", Kind.FEEDBACK: "Your feedback"}
const HINTS := {Kind.BUG: "What did you do, and what went wrong?", Kind.FEEDBACK: "What do you like, what bugs you?"}
const THANKS_TEXT := "Saved. Thanks!"
const SEND_TEXT := "Send"
const CANCEL_TEXT := "Cancel"
const MORE_TEXT := "More options"
const LESS_TEXT := "Fewer options"

static var _instance: ReportForm

var kind := Kind.BUG
var _screenshot: Image
var _content: Control
var _title: Label
var _prompt: Label
var _text: TextEdit
var _bug_box: VBoxContainer
var _feedback_box: VBoxContainer
var _more_button: Button
var _options_box: VBoxContainer
var _shot_toggle: CheckButton
var _save_toggle: CheckButton
var _log_toggle: CheckButton
var _importance_group := ButtonGroup.new()
var _mood_group := ButtonGroup.new()
var _send_button: Button
var _cancel_button: Button
var _thanks: Label
var _paused_game := false
var _was_blocked := false
var _pause_menu_hidden := false
var _pointer_parent: Node
var _pointer_index := 0
var _tween: Tween
var _opening := false


static func is_open() -> bool:
	return _instance != null and is_instance_valid(_instance) and _instance.visible


static func open_form(form_kind: Kind) -> void:
	if _instance == null or not is_instance_valid(_instance):
		_instance = ReportForm.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(_instance)
	_instance._open(form_kind)


static func reports_folder() -> String:
	return ProjectSettings.globalize_path(REPORTS_DIR)


func _init() -> void:
	layer = FORM_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var is_escape: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if is_escape or event.is_action_pressed(ACTION, false, true):
		get_viewport().set_input_as_handled()
		close()


func _open(form_kind: Kind) -> void:
	if visible or _opening:
		return
	kind = form_kind
	InteractionManager.cancel_press()
	_was_blocked = InteractionManager.is_table_blocked()
	InteractionManager.set_table_blocked(true)
	_paused_game = not get_tree().paused
	get_tree().paused = true
	_opening = true
	await _grab_screenshot()
	_opening = false
	_reset_fields()
	_lift_pointer()
	show()
	_content.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_content, "modulate:a", 1.0, FADE_TIME)
	_text.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	hide()
	_lower_pointer()
	if _pause_menu_hidden:
		PauseMenu.show()
		_pause_menu_hidden = false
	if _paused_game:
		get_tree().paused = false
	_paused_game = false
	_screenshot = null
	InteractionManager.skip_next_double_click()
	if not _was_blocked:
		InteractionManager.set_table_blocked(false)


func _grab_screenshot() -> void:
	if PauseMenu.visible:
		PauseMenu.hide()
		_pause_menu_hidden = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_screenshot = get_viewport().get_texture().get_image()
	if _pause_menu_hidden:
		PauseMenu.show()


func _reset_fields() -> void:
	_title.text = TITLES[kind]
	_prompt.text = PROMPTS[kind].to_upper()
	_text.placeholder_text = HINTS[kind]
	_text.text = ""
	_bug_box.visible = kind == Kind.BUG
	_feedback_box.visible = kind == Kind.FEEDBACK
	_options_box.visible = false
	_more_button.text = MORE_TEXT
	_shot_toggle.button_pressed = true
	_save_toggle.button_pressed = true
	_log_toggle.button_pressed = true
	_importance_group.get_buttons()[DEFAULT_IMPORTANCE].button_pressed = true
	for button in _mood_group.get_buttons():
		button.button_pressed = false
	_thanks.hide()
	_send_button.disabled = true
	_cancel_button.disabled = false


func _on_text_changed() -> void:
	_send_button.disabled = _text.text.strip_edges().is_empty()


func _toggle_more() -> void:
	_options_box.visible = not _options_box.visible
	_more_button.text = LESS_TEXT if _options_box.visible else MORE_TEXT


func _on_send() -> void:
	if _text.text.strip_edges().is_empty():
		return
	_send_button.disabled = true
	_cancel_button.disabled = true
	var path := submit(build_report())
	if path.is_empty():
		_send_button.disabled = false
		_cancel_button.disabled = false
		return
	_thanks.show()
	await get_tree().create_timer(THANKS_TIME, true, false, true).timeout
	close()


func build_report() -> Dictionary:
	var is_bug := kind == Kind.BUG
	var report := {
		"id": _new_id(),
		"type": "bug" if is_bug else "feedback",
		"text": _text.text.strip_edges(),
		"importance": IMPORTANCE[_pressed_index(_importance_group)] if is_bug else "",
		"mood": "" if is_bug or _pressed_index(_mood_group) < 0 else MOODS[_pressed_index(_mood_group)],
		"match": DialogueManager.upcoming_match(),
		"round": DialogueManager._round,
		"turn": GameManager.current_turn,
		"match_active": GameManager.match_active,
		"scene": _scene_name(),
		"game_version": _game_version(),
		"engine_version": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"timestamp": Time.get_datetime_string_from_system(true),
		"screenshot": is_bug and _shot_toggle.button_pressed and _screenshot != null,
		"save": is_bug and _save_toggle.button_pressed,
		"error_fingerprint": DiagnosticsLog.get_fingerprint(),
		"errors": [],
		"output": [],
	}
	if not is_bug or _log_toggle.button_pressed:
		report["errors"] = DiagnosticsLog.get_errors()
		report["output"] = DiagnosticsLog.get_output()
	return report


func submit(report: Dictionary) -> String:
	if DirAccess.make_dir_recursive_absolute(REPORTS_DIR) != OK:
		push_warning("Could not create %s" % REPORTS_DIR)
		return ""
	var base: String = REPORTS_DIR.path_join(report["id"])
	if report.get("screenshot", false):
		_screenshot.save_png(base + ".png")
	if report.get("save", false):
		_write_json(base + ".save.json", SaveManager.current_snapshot())
	if not _write_json(base + ".json", report):
		return ""
	return base + ".json"


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _new_id() -> String:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "-")
	return "%s-%s-%04x" % ["bug" if kind == Kind.BUG else "feedback", stamp, randi() % 0x10000]


func _scene_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path.get_file().get_basename() if scene.scene_file_path != "" else String(scene.name)


func _pressed_index(group: ButtonGroup) -> int:
	var pressed := group.get_pressed_button()
	return group.get_buttons().find(pressed) if pressed != null else -1


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = PauseMenu.DIM_COLOR
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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeadlineLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_prompt = _caps("")
	box.add_child(_prompt)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, TEXT_HEIGHT)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_stylebox_override("normal", ShopTooltip.inner_style())
	_text.add_theme_stylebox_override("focus", ShopTooltip.inner_style())
	_text.add_theme_color_override("font_color", ShopTooltip.TEXT)
	_text.add_theme_color_override("font_placeholder_color", Color(PauseMenu.VALUE_COLOR, 0.45))
	_text.add_theme_color_override("caret_color", PauseMenu.AMBER)
	_text.text_changed.connect(_on_text_changed)
	box.add_child(_text)
	_bug_box = VBoxContainer.new()
	_bug_box.add_theme_constant_override("separation", 8)
	box.add_child(_bug_box)
	_bug_box.add_child(_caps("How bad is it?"))
	_bug_box.add_child(_choice_row(IMPORTANCE, _importance_group, false))
	_more_button = Button.new()
	_more_button.flat = true
	_more_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_more_button.add_theme_color_override("font_color", PauseMenu.VALUE_COLOR)
	_more_button.add_theme_color_override("font_hover_color", PauseMenu.AMBER)
	for style in ["normal", "hover", "pressed", "focus"]:
		_more_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_more_button.pressed.connect(_toggle_more)
	_bug_box.add_child(_more_button)
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	_bug_box.add_child(_options_box)
	_shot_toggle = PauseMenu.make_toggle("Attach screenshot")
	_save_toggle = PauseMenu.make_toggle("Attach save")
	_log_toggle = PauseMenu.make_toggle("Attach error log")
	for toggle in [_shot_toggle, _save_toggle, _log_toggle]:
		_options_box.add_child(toggle)
	_feedback_box = VBoxContainer.new()
	_feedback_box.add_theme_constant_override("separation", 8)
	box.add_child(_feedback_box)
	_feedback_box.add_child(_caps("How's it going? (optional)"))
	_feedback_box.add_child(_choice_row(MOODS, _mood_group, true))
	_thanks = Label.new()
	_thanks.text = THANKS_TEXT
	_thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thanks.add_theme_color_override("font_color", PauseMenu.AMBER)
	box.add_child(_thanks)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_cancel_button = Button.new()
	_cancel_button.text = CANCEL_TEXT
	_cancel_button.custom_minimum_size = Vector2(150, 40)
	_cancel_button.pressed.connect(close)
	buttons.add_child(_cancel_button)
	_send_button = Button.new()
	_send_button.text = SEND_TEXT
	_send_button.theme_type_variation = &"ButtonPrimary"
	_send_button.custom_minimum_size = Vector2(150, 40)
	_send_button.pressed.connect(_on_send)
	buttons.add_child(_send_button)


func _choice_row(labels: Array, group: ButtonGroup, can_unpress: bool) -> HBoxContainer:
	group.allow_unpress = can_unpress
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for text in labels:
		var button := Button.new()
		button.text = text
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_color_override("font_pressed_color", PauseMenu.AMBER)
		button.add_theme_color_override("font_hover_pressed_color", PauseMenu.AMBER)
		var chosen := ShopTooltip.inner_style()
		chosen.border_color = PauseMenu.AMBER
		button.add_theme_stylebox_override("pressed", chosen)
		button.add_theme_stylebox_override("hover_pressed", chosen)
		row.add_child(button)
	return row


func _caps(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.theme_type_variation = &"CapsLabel"
	return label


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


func _game_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if not version.is_empty() else "dev"
