extends  Node

var table_root: Control

var played_cards: Hand = Hand.new()

var player_deck: Deck
var AI_1_deck: Deck
var AI_2_deck: Deck

var player_hand: Hand
var AI_1_hand: Hand
var AI_2_hand: Hand

var leading_card : Card
var first_trump_card : Card

func load_player_decks():
	player_deck = Deck.new(generate_cards(20, Card.Owner.HUMAN))
	AI_1_deck = Deck.new(generate_cards(20, Card.Owner.AI_1))
	AI_2_deck = Deck.new(generate_cards(20, Card.Owner.AI_2))
	print("Decks generated")

func generate_player_hands():
	load_player_decks()
	
	print("Drawing player hands")
	player_hand = player_deck.draw(10)
	AI_1_hand = AI_1_deck.draw(10)
	AI_2_hand = AI_2_deck.draw(10)
	
	GameManager.human_player.recieve_hand(player_hand)
	GameManager.ai_player_1.hand = AI_1_hand
	GameManager.ai_player_2.hand = AI_2_hand 
	
	print("All Hands drawn")
	

func generate_cards(amount: int, owner : Card.Owner) -> Array[Card]:
	var cards: Array[Card] = []

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(amount):
		var random_suit: Card.Suit = rng.randi_range(0, Card.Suit.size() - 1)
		var random_rank: int = rng.randi_range(1, 13)

		var card := Card.new(
			random_suit,
			random_rank,
			owner,
			false
		)
		cards.append(card)
	return cards


# In this function the Card Manager should get through the active buffs and update the cards of that player
func update_cards():
	# Create Array of Cards for each player
	
	# For each Array of Cards, Go through each card and then apply the buff for that player
	pass

func submit_play(player_id: int, card: Card) -> void:
	# Track leading card
	if leading_card == null:
		leading_card = card
	
	# Track first played trump suit
	if first_trump_card == null and card.is_trump:
		first_trump_card = card

	played_cards.append(card)
	render_played_card(card)
	
	GameManager.play_callback(player_id)


func render_played_card(card : Card) -> void:
	
	var card_visual := preload("res://scenes/Card.tscn").instantiate() as CardVisual
	card_visual.setup(card, false)
	
	table_root.add_child(card_visual)

	var center := _get_table_center_world()

	var offset : Vector2
	
	match card.owner:
		Card.Owner.HUMAN:
			offset = Vector2(0, -135)
		Card.Owner.AI_1:
			offset = Vector2(-70, -160)
		Card.Owner.AI_2:
			offset = Vector2(60, -195)

	card_visual.global_position = center + offset
	card_visual.scale = Vector2(1.5, 1.5)

	# Layering: later plays on top
	card_visual.z_index = played_cards.size()

func round_clean_up() -> void:
	leading_card = null
	first_trump_card = null
	
	if played_cards.size() == 0:
		return
	
	played_cards.empty()

func get_round_winner() -> Card.Owner:
	var highest_trump = played_cards.get_highest_trump_card()
	if highest_trump != null:
		return highest_trump.owner
	
	var highest_lead = played_cards.get_highest_card_of_suit(leading_card.suit)
	return highest_lead.owner

# - - - HELPER - - -

func _get_table_center_world() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5)

func set_table_root(node: Control) -> void:
	table_root = node

func get_highest_lead_card() -> Card:
	return played_cards.get_highest_card_of_suit(leading_card.suit)

func get_highest_trump_card() -> Card:
	return played_cards.get_highest_trump_card()
