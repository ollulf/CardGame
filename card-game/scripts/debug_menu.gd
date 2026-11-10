extends CanvasLayer
class_name DebugMenu

const TOGGLE_ACTION := "toggle_debug_menu"
const UNLOCK_CUES := ["show_deck", "show_won_turns", "show_life_cards", "show_purse", "show_cigs", "show_trump", "unlock_cig_automat"]
const PANEL_WIDTH := 260.0
const MARGIN := 16.0
const TOP_OFFSET := 60.0
const CIGARETTE_BONUS := 5
const CASH_BONUS := 10

@export var pointer: Control

var unlocked := false

var _panel: PanelContainer
var _skip_buttons: Array[Button] = []
var _tutorial_button: Button
var _matches_label: Label
var _pointer_parent: Node
var _pointer_index := 0
var _was_blocked := false


func _ready() -> void:
	layer = 120
	_build()
	hide()
	GameManager.new_match_started.connect(_on_new_match_started)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(MARGIN, TOP_OFFSET)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_skip_buttons.append(_add_button(box, "You lose round", skip_round.bind(GameManager.HUMAN_ID)))
	for looser_id in [1, 2]:
		var button := _add_button(box, "Skip round: %s loses" % GameManager.PLAYER_NAMES[looser_id], skip_round.bind(looser_id))
		_skip_buttons.append(button)
	_tutorial_button = _add_button(box, "Skip tutorial", skip_tutorial)
	_add_button(box, "Unlock all UI", unlock_all)
	_add_button(box, "+%d cigarettes" % CIGARETTE_BONUS, add_cigarettes)
	_add_button(box, "+%d$" % CASH_BONUS, add_cash)
	_add_button(box, "Give Draw card", give_effect_card.bind(CardEffect.Id.DRAW))
	_matches_label = Label.new()
	box.add_child(_matches_label)
	var matches_row := HBoxContainer.new()
	box.add_child(matches_row)
	_add_button(matches_row, "+1 match", func(): Profile.set_matches_played(Profile.matches_played + 1))
	_add_button(matches_row, "Reset matches", func(): Profile.set_matches_played(0))
	_add_button(box, "Close", close)


func _add_button(box: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
		get_viewport().set_input_as_handled()
		toggle()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


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
	_refresh()
	show()


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


func skip_round(looser_id: int) -> void:
	if not GameManager.can_skip_round():
		return
	GameManager.skip_round(looser_id)
	_refresh()




func skip_tutorial() -> void:
	if not GameManager.can_skip_tutorial():
		return
	close()
	GameManager.skip_tutorial(UNLOCK_CUES)


func unlock_all() -> void:
	unlocked = true
	PlayerDataManager.mark_booster_collected()
	PlayerDataManager.mark_deck_edited()
	for cue in UNLOCK_CUES:
		GameManager.run_cue(cue)


func add_cigarettes() -> void:
	var pack: CigPack = InteractionManager.cigPack
	if pack:
		pack.add_cigarettes(CIGARETTE_BONUS)


func add_cash() -> void:
	GameManager.run_cue("show_purse")
	PlayerDataManager.add_money(CASH_BONUS)


func give_effect_card(effect: CardEffect.Id) -> void:
	var card := Card.new(randi_range(0, Card.Suit.CLUBS), randi_range(1, 9), Card.Owner.HUMAN, false, effect)
	var gift: Array[Card] = [card.copy_for(Card.Owner.HUMAN)]
	PlayerDataManager.add_to_collection(gift)
	if GameManager.can_skip_round() and CardManager.hand_of(GameManager.HUMAN_ID) != null:
		CardManager.give_card(GameManager.HUMAN_ID, card)
	GameManager.message("Debug: got %s" % card.string_info())


func _on_new_match_started() -> void:
	if unlocked:
		unlock_all.call_deferred()


func _refresh() -> void:
	_matches_label.text = "Matches played: %d" % Profile.matches_played
	var can_skip := GameManager.can_skip_round()
	for button in _skip_buttons:
		button.disabled = not can_skip
	_tutorial_button.visible = DialogueManager.upcoming_match() == 1
	_tutorial_button.disabled = not GameManager.can_skip_tutorial()


func _lift_pointer() -> void:
	if pointer == null or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)


func _lower_pointer() -> void:
	if pointer == null or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)
