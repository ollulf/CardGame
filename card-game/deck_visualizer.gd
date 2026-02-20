extends CanvasLayer

#card content
@onready var card_packed_scene = preload("res://scenes/Card.tscn")
@onready var card_container_upper = $Panel/HBoxContainer/CardsPanel/UpperPanel/MarginContainer/CardContainer
@onready var card_container_lower = $Panel/HBoxContainer/CardsPanel/LowerPanel/MarginContainer/CardContainer

var card_instances_upper = []
var card_instances_lower = []

func _ready():
	hide()
	
func _process(delta):
	if Input.is_action_just_released("togge_deck_visualizer"):
		if visible:
			hide_deck()
			hide()
		else:
			visualize_deck(CardManager.player_deck, Card.Owner.HUMAN)

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

	show()

func _print_info(card):
	print(card.string_info())

func _cleanup(cards):
	for c : CardVisual in cards:
		c.destroy()
		
	cards.clear()
