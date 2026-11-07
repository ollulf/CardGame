extends CanvasLayer

@onready var confirm_button: Button = %ConfirmDeckButton
@onready var edit_deck_button: Button = %EditDeckButton

var _hand_parent: Node
var _hand_index := 0
var _matches_finished := 0
var deck_builder: DeckBuilder

const GIFT_CIGARETTES := 8

func _ready() -> void:
	hide()
	GameManager.match_finished.connect(open)
	confirm_button.pressed.connect(_on_confirm_pressed)
	edit_deck_button.pressed.connect(_on_edit_deck_pressed)
	deck_builder = DeckBuilder.new()
	add_child(deck_builder)
	deck_builder.closed.connect(_on_deck_builder_closed)

func open(looser_ids: Array[int]) -> void:
	_matches_finished += 1
	if _matches_finished == 1:
		var pack: CigPack = InteractionManager.cigPack
		if pack != null:
			pack.add_cigarettes(GIFT_CIGARETTES)
	CardManager.load_player_decks()
	_lift_hand_pointer()
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

func _on_edit_deck_pressed() -> void:
	deck_builder.open()

func _on_deck_builder_closed() -> void:
	CardManager.load_player_decks()
