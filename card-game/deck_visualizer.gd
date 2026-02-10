extends CanvasLayer

var card_visuals : Array[CardVisual]

func visualize_deck(deck: Deck):
	for card_visual in card_visuals:
		card_visual.queue_free()
	
	for card in deck.cards:
		var c := preload("res://scenes/Card.tscn").instantiate() as CardVisual
		
		c.setup(card, false)
		
		add_child(c)
		card_visuals.append(c)

	layout_deck_cards()
	
func layout_deck_cards():
	pass
