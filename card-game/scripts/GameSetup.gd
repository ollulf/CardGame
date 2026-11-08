extends Node2D

func _ready() -> void:
	GameManager.set_table_root(%TableRoot)
	$Wallet.clicked.connect($BarScreen.open)
	for pile: DeckPile in $DeckPiles.get_children():
		pile.clicked.connect($DeckVisualizer.toggle_for_owner)
	
	await CardManager.load_player_decks()
	
	GameManager.start_round(0)
	if Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
