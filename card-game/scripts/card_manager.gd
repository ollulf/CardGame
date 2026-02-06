extends  Node

var table_root: Control

var played_cards: Hand

var player_hand: Hand
var AI_1_hand: Hand
var AI_2_hand: Hand

var leading_card : Card
var first_trump_card : Card


# In this function the Card Manager should get through the active buffs and update the cards of that player
func update_cards():
	# Create Array of Cards for each player
	
	# For each Array of Cards, Go through each card and then apply the buff for that player
	pass

func set_table_root(node: Control) -> void:
	table_root = node

func generate_player_hands():
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


func _get_table_center_world() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y * 0.5)


func clear_table_visuals() -> void:
	for card_visual in played_cards:
		card_visual.destroy()
	
	played_cards.clear()


func round_clean_up() -> void:
	leading_card = null
	first_trump_card = null


func get_highest_lead_card() -> Card:
	return played_cards.get_highest_card_of_suit(leading_card.suit)


func get_highest_trump_card() -> Card:
	return played_cards.get_highest_trump_card()
