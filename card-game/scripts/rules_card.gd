extends CanvasLayer
class_name RulesCard

const CARD_LAYER := 110
const BUTTON_POSITION := Vector2(12, 12)
const BUTTON_SIZE := 44.0
const TOUCH_BUTTON_SIZE := 64.0
const BUTTON_Z_INDEX := 10
const PANEL_WIDTH := 600.0
const SCREEN_MARGIN := 150.0
const FADE_TIME := 0.15
const HEADING_COLOR := "#a59d94"
const RULES := """[h]GOAL[/h]
• A round has [b]5 tricks[/b]: everybody plays one card, the best card takes the trick. Whoever takes the [b]fewest tricks[/b] loses the round.
• Lose [b]2 rounds[/b] and you are out of the match.

[h]PLAYING A TRICK[/h]
• You must [b]follow the suit[/b] that was led if you can.
• The [b]highest card[/b] of the led suit takes the trick.
• The [b]trump suit[/b] beats every other suit, so the highest trump wins. It is picked at random at the start of every match and stays for the whole match.
• [b]Smoking cards[/b] and [b]drinking cards[/b] are always trump.
• A [b]0[/b] beats a 9 of the [b]same suit[/b].
• On a tie, the card played [b]first[/b] wins.

[h]SMOKING AND DRINKS[/h]
• Every cigarette you smoke gives your smoking cards [b]+1[/b] until the round ends. Smoke as many as you like.
• A [b]round of drinks[/b] makes everybody drink: drinking cards [b]+1[/b], all other cards [b]-1[/b], for the whole match."""

var _button: Button
var _dim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _text: RichTextLabel
var _pointer_parent: Node
var _pointer_index := 0
var _was_blocked := false

func _init() -> void:
	layer = CARD_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()
	hide()

func attach_button(parent: Node) -> void:
	_button = Button.new()
	_button.text = "?"
	_button.tooltip_text = "Rules"
	_button.focus_mode = Control.FOCUS_NONE
	var side := TOUCH_BUTTON_SIZE if InteractionManager.uses_touch() else BUTTON_SIZE
	_button.custom_minimum_size = Vector2(side, side)
	_button.position = BUTTON_POSITION
	_button.z_index = BUTTON_Z_INDEX
	_button.add_theme_font_size_override("font_size", InteractionManager.font_px(22))
	_button.pressed.connect(toggle)
	parent.add_child(_button)

func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.03, 0.05, 0.7)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Rules"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", InteractionManager.font_px(28))
	box.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", InteractionManager.font_px(16))
	_text.add_theme_font_size_override("bold_font_size", InteractionManager.font_px(16))
	_text.text = RULES.replace("[h]", "[color=%s]" % HEADING_COLOR).replace("[/h]", "[/color]").replace("[b]", "[color=%s]" % SpeechBubble.HIGHLIGHT_COLOR).replace("[/b]", "[/color]")
	_scroll.add_child(_text)
	var close_button := Button.new()
	close_button.text = "Got it"
	close_button.theme_type_variation = &"ButtonPrimary"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(200, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if visible:
		return
	_was_blocked = InteractionManager.is_table_blocked()
	InteractionManager.set_table_blocked(true)
	_lift_pointer()
	show()
	_scroll.scroll_vertical = 0
	_fit_scroll.call_deferred()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, FADE_TIME)

func close() -> void:
	if not visible:
		return
	hide()
	_lower_pointer()
	InteractionManager.skip_next_double_click()
	if not _was_blocked:
		InteractionManager.set_table_blocked(false)
		if DialogueManager.is_open():
			get_viewport().physics_object_picking = false

func _fit_scroll() -> void:
	var available := get_viewport().get_visible_rect().size.y - SCREEN_MARGIN
	_scroll.custom_minimum_size.y = minf(_text.get_content_height(), available)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
		_dim.accept_event()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _lift_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)

func _lower_pointer() -> void:
	var pointer: Control = InteractionManager.hand
	if pointer == null or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)
