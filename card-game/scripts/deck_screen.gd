extends CanvasLayer

enum GuideStep { NONE, BUY, EDIT, NEXT }

const GUIDED_MATCH := 2
const HINT_COLOR := Color(1, 0.811765, 0.431373, 1)
const HINT_OUTLINE := Color(0.0901961, 0.0862745, 0.109804, 1)
const BAR_HINT := "Tap your wallet to visit the bar and buy a booster."
const EDIT_HINT := "New cards! Tap Edit deck to put them in your deck."
const NEXT_HINT := "All set? Start the next match."

@onready var confirm_button: Button = %ConfirmDeckButton
@onready var edit_deck_button: Button = %EditDeckButton

var _hand_parent: Node
var _hand_index := 0
var deck_builder: DeckBuilder
var _hint_label: Label
var _arrow: GuideArrow
var _arrow_target: CanvasItem
var _booster_bought_this_phase := false

func _ready() -> void:
	hide()
	add_to_group("deck_screen")
	GameManager.match_finished.connect(open)
	confirm_button.pressed.connect(_on_confirm_pressed)
	edit_deck_button.pressed.connect(_on_edit_deck_pressed)
	deck_builder = DeckBuilder.new()
	add_child(deck_builder)
	deck_builder.closed.connect(_on_deck_builder_closed)
	_build_hint_label()
	_arrow = GuideArrow.new()
	add_child(_arrow)
	PlayerDataManager.buttons_unlock_changed.connect(_refresh_buttons)
	PlayerDataManager.money_changed.connect(_on_progress_changed)
	PlayerDataManager.booster_bought.connect(_on_booster_bought)
	_refresh_buttons(false)

func _build_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.custom_minimum_size = Vector2(confirm_button.custom_minimum_size.x, 0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_size_override("font_size", InteractionManager.font_px(17))
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_hint_label.add_theme_color_override("font_outline_color", HINT_OUTLINE)
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.hide()
	var buttons := confirm_button.get_parent()
	buttons.add_child(_hint_label)
	buttons.move_child(_hint_label, 0)

func open(_looser_ids: Array[int]) -> void:
	CardManager.load_player_decks()
	_booster_bought_this_phase = false
	_lift_hand_pointer()
	show()
	_refresh_buttons(false)

func _on_confirm_pressed() -> void:
	if deck_builder.visible:
		return
	hide()
	_arrow_target = null
	_lower_hand_pointer()
	InteractionManager.skip_next_double_click()
	GameManager.start_new_match()

func _lift_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	_hand_parent = hand.get_parent()
	_hand_index = hand.get_index()
	hand.reparent(self)

func _lower_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	hand.reparent(_hand_parent)
	_hand_parent.move_child(hand, _hand_index)

func _refresh_buttons(animate := true) -> void:
	var step := _guide_step()
	_set_button(edit_deck_button, step != GuideStep.BUY, animate)
	_set_button(confirm_button, _deck_ready() and step != GuideStep.BUY and step != GuideStep.EDIT, animate)
	_refresh_hint()

func _deck_ready() -> bool:
	return PlayerDataManager.has_active_deck() or PlayerDataManager.active_deck.is_empty()

func _set_button(button: Button, should_show: bool, animate: bool) -> void:
	if not should_show:
		button.hide()
		return
	if button.visible:
		return
	button.show()
	if animate:
		button.modulate.a = 0.0
		create_tween().tween_property(button, "modulate:a", 1.0, 0.4)
	else:
		button.modulate.a = 1.0

func _on_edit_deck_pressed() -> void:
	PlayerDataManager.mark_deck_edited()
	deck_builder.open()

func _on_deck_builder_closed() -> void:
	CardManager.load_player_decks()
	_refresh_buttons()

func _on_booster_bought(_booster: Dictionary) -> void:
	_booster_bought_this_phase = true
	_refresh_buttons()

func _on_progress_changed(_value = null) -> void:
	_refresh_buttons()

func guide_active() -> bool:
	return visible and DialogueManager.upcoming_match() == GUIDED_MATCH

func guide_wants_booster() -> bool:
	return _guide_step() == GuideStep.BUY

func _guide_step() -> GuideStep:
	if not guide_active():
		return GuideStep.NONE
	if not PlayerDataManager.booster_collected:
		if _booster_bought_this_phase or _can_afford_booster():
			return GuideStep.BUY
		return GuideStep.NONE
	if not PlayerDataManager.deck_edited:
		return GuideStep.EDIT
	return GuideStep.NEXT

func _can_afford_booster() -> bool:
	for booster in PlayerDataManager.BOOSTERS:
		if PlayerDataManager.is_booster_available(booster) and PlayerDataManager.can_afford(booster["price"]):
			return true
	return false

func _wallet() -> Wallet:
	return get_tree().get_first_node_in_group("wallet") as Wallet

func _process(_delta: float) -> void:
	_arrow.target = null if deck_builder.visible or DialogueManager.is_open() else _arrow_target

func _refresh_hint() -> void:
	if _hint_label == null:
		return
	match _guide_step():
		GuideStep.BUY:
			var wallet := _wallet()
			_show_hint(BAR_HINT, wallet.sprite if wallet != null else null, false)
		GuideStep.EDIT:
			_show_hint(EDIT_HINT, edit_deck_button, true)
		GuideStep.NEXT:
			_show_hint(NEXT_HINT, confirm_button, true)
		_:
			_hint_label.hide()
			_arrow_target = null

func _show_hint(text: String, target: CanvasItem, from_left: bool) -> void:
	_hint_label.text = text
	_hint_label.show()
	_arrow_target = target
	_arrow.from_left = from_left
