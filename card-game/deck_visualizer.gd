extends CanvasLayer

const OWNER_TITLES := {
	Card.Owner.HUMAN: "Your deck",
	Card.Owner.AI_1: "Left player's deck",
	Card.Owner.AI_2: "Right player's deck",
}

@export var pointer: Control

#card content
@onready var card_packed_scene = preload("res://scenes/Card.tscn")
@onready var card_container_upper = $Panel/HBoxContainer/CardsPanel/UpperPanel/MarginContainer/CardContainer
@onready var card_container_lower = $Panel/HBoxContainer/CardsPanel/LowerPanel/MarginContainer/CardContainer
@onready var panel: Control = $Panel

var card_instances_upper = []
var card_instances_lower = []

var _title: Label
var _pointer_parent: Node
var _pointer_index: int

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_backdrop()
	_build_title()
	hide()

func _build_backdrop():
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	move_child(backdrop, 0)

func _build_title():
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size = Vector2(1000, 28)
	_title.position = Vector2(-500, -300 - 30)
	_title.add_theme_font_size_override("font_size", 20)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_title)

func _process(delta):
	if Input.is_action_just_released("togge_deck_visualizer"):
		if visible:
			close()
		else:
			open_for_owner(Card.Owner.HUMAN)
	elif visible and Input.is_action_just_pressed("ui_cancel"):
		close()

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func open_for_owner(owner: Card.Owner):
	if owner != Card.Owner.HUMAN:
		return
	var deck := _deck_of(owner)
	if deck == null or DialogueManager.is_open() or InteractionManager.is_table_blocked():
		return
	if visible:
		hide_deck()
	visualize_deck(deck, owner)

func toggle_for_owner(owner: Card.Owner):
	if visible:
		close()
	else:
		open_for_owner(owner)

func close():
	if not visible:
		return
	hide_deck()
	hide()
	_release_pointer()
	InteractionManager.skip_next_double_click()
	get_tree().paused = false

func _deck_of(owner: Card.Owner) -> Deck:
	match owner:
		Card.Owner.HUMAN:
			return CardManager.player_deck
		Card.Owner.AI_1:
			return CardManager.AI_1_deck
		Card.Owner.AI_2:
			return CardManager.AI_2_deck
	return null

func _grab_pointer():
	if pointer == null or pointer.get_parent() == self:
		return
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)

func _release_pointer():
	if pointer == null or _pointer_parent == null or pointer.get_parent() != self:
		return
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)

func hide_deck():
	_cleanup(card_instances_upper)
	_cleanup(card_instances_lower)

func visualize_deck(deck: Deck, owner : Card.Owner):
	var played_cards = CardManager.played_cards_match.cards

	var all_cards = []
	all_cards.append_array(deck.cards)
	for c in played_cards:
		if c.owner == owner:
			all_cards.append(c)

	for card in all_cards:
		var new_instance = card_packed_scene.instantiate() as CardVisual
		card_container_lower.add_child(new_instance)
		new_instance.setup(card, false)
		#new_instance.mouse_entered.connect(_print_info.bind(card))
		#for c in played_cards:
			#print(card.string_info(),"(",card, ") <> ", c.string_info(), "(",c, ")  = ", c == card)
		if played_cards.has(card):
			new_instance.modulate = Color.DARK_SLATE_GRAY
		card_instances_lower.append(new_instance)

	_title.text = OWNER_TITLES.get(owner, "Deck")
	InteractionManager.cancel_press()
	get_tree().paused = true
	_grab_pointer()
	show()

func _print_info(card):
	print(card.string_info())

func _cleanup(cards):
	for c : CardVisual in cards:
		c.destroy()

	cards.clear()
