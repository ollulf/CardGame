extends Node2D

func _ready() -> void:
	GameManager.set_table_root(%TableRoot)
	$Wallet.clicked.connect($BarScreen.open)
	for pile: DeckPile in $DeckPiles.get_children():
		pile.clicked.connect($DeckVisualizer.toggle_for_owner)
	var rules := RulesCard.new()
	add_child(rules)
	rules.attach_button(self)
	add_child(TutorialPopups.new())
	
	await CardManager.load_player_decks()
	
	if Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var save := SaveManager.load_save()
	if save.is_empty() and not SaveManager.enabled:
		GameManager.start_round(0)
		return
	var menu := StartMenu.new()
	add_child(menu)
	menu.open(save)
	var choice: StartMenu.Choice = await menu.chosen
	match choice:
		StartMenu.Choice.CONTINUE:
			SaveManager.continue_run(save)
		StartMenu.Choice.SKIP_TUTORIAL:
			TutorialPopups.skip_basics()
			SaveManager.delete_save()
			GameManager.start_without_tutorial()
		_:
			TutorialPopups.reset_run()
			SaveManager.delete_save()
			GameManager.start_round(0)
