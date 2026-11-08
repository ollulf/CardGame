extends CanvasLayer

@onready var confirm_button: Button = %ConfirmDeckButton
@onready var edit_deck_button: Button = %EditDeckButton

var _hand_parent: Node
var _hand_index := 0
var deck_builder: DeckBuilder

func _ready() -> void:
	hide()
	GameManager.match_finished.connect(open)
	confirm_button.pressed.connect(_on_confirm_pressed)
	edit_deck_button.pressed.connect(_on_edit_deck_pressed)
	deck_builder = DeckBuilder.new()
	add_child(deck_builder)
	deck_builder.closed.connect(_on_deck_builder_closed)
	PlayerDataManager.buttons_unlock_changed.connect(_refresh_buttons)
	_refresh_buttons(false)

func open(looser_ids: Array[int]) -> void:
	CardManager.load_player_decks()
	_lift_hand_pointer()
	_refresh_buttons(false)
	show()

func _on_confirm_pressed() -> void:
	if deck_builder.visible:
		return
	hide()
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
	_set_button(edit_deck_button, PlayerDataManager.booster_collected, animate)
	_set_button(confirm_button, PlayerDataManager.booster_collected and PlayerDataManager.deck_edited, animate)

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
