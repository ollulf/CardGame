extends Node2D

func _ready() -> void:
	GameManager.set_table_root(%TableRoot)
	$Wallet.clicked.connect($BarScreen.open)
	for pile: DeckPile in $DeckPiles.get_children():
		pile.clicked.connect($DeckVisualizer.toggle_for_owner)
	
	await CardManager.load_player_decks()
	
	GameManager.start_match(0)
	if Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
