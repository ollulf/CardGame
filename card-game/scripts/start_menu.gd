extends CanvasLayer
class_name StartMenu

signal chosen(continue_run: bool)

const MENU_LAYER := 56
const FADE_TIME := 0.4

var _hand_parent: Node
var _hand_index := 0
var _continue_button: Button
var _new_run_button: Button
var _subtitle: Label
var _content: Control

func _init() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.78)
	add_child(dim)
	var center := CenterContainer.new()
	_content = center
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Welcome back"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	_continue_button = _add_button(box, "Continue", &"ButtonPrimary", 44)
	_new_run_button = _add_button(box, "New run", &"", 40)
	_continue_button.pressed.connect(_choose.bind(true))
	_new_run_button.pressed.connect(_choose.bind(false))

func open(save: Dictionary) -> void:
	var state: Dictionary = save.state
	var match_number: int = state.match
	if save.between_matches:
		_subtitle.text = "Saved before match %d  ·  %d$" % [match_number, state.money]
	else:
		_subtitle.text = "Saved at the start of match %d  ·  %d$" % [match_number, state.money]
	_lift_hand_pointer()
	show()
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, FADE_TIME)

func _add_button(box: VBoxContainer, text: String, variation: StringName, height: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if variation != &"":
		button.theme_type_variation = variation
	box.add_child(button)
	return button

func _choose(continue_run: bool) -> void:
	_continue_button.disabled = true
	_new_run_button.disabled = true
	_lower_hand_pointer()
	InteractionManager.skip_next_double_click()
	chosen.emit(continue_run)
	queue_free()

func _lift_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or hand.get_parent() == self:
		return
	_hand_parent = hand.get_parent()
	_hand_index = hand.get_index()
	hand.reparent(self)

func _lower_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or _hand_parent == null or hand.get_parent() != self:
		return
	hand.reparent(_hand_parent)
	_hand_parent.move_child(hand, _hand_index)
