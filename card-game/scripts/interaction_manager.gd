extends Node

var cigPack: CigPack
var hand: HandVisualisation
var human_player: HumanPlayer

@export var cigarette_scene:= preload("res://scenes/cigarette.tscn") 

const MAX_IN_HAND := 3
const BURN_SECONDS := 20.0

var _burn_token: int = 0

var hovered_card : CardVisual = null

func register(player : Player):
	human_player = player

func _process(delta: float) -> void:
	check_for_hovered_card()

func check_for_hovered_card() -> void:
	var c: Control = get_viewport().gui_get_hovered_control()
	var new_hovered: CardVisual = null

	# Walk up from the hovered control until we find a Card (or nothing)
	while c != null:
		if c is CardVisual:
			new_hovered = c as CardVisual
			break
		c = c.get_parent() as Control

	# If nothing changed, do nothing
	if new_hovered == hovered_card:
		return

	# Leaving old card
	if is_instance_valid(hovered_card):
		hovered_card.hover_exit()

	# Entering new card
	hovered_card = new_hovered
	if is_instance_valid(hovered_card):
		hovered_card.hover_enter()



func _input(event: InputEvent) -> void:
	# Right click: put one unlit cigarette back into the pack
	if event is InputEventMouseButton and event.pressed:
		# Right click: put one unlit cigarette back into the pack
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_return_one_unlit_to_pack()
			return
	
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			if is_instance_valid(hovered_card):
				human_player.try_play_card(hovered_card.card)

func pickedUpCig() -> void:
	addCigToHand()

func usedLighter() -> void:
	hand.light_all_unlit()

	_burn_token += 1
	var my_token := _burn_token

	await get_tree().create_timer(BURN_SECONDS).timeout
	if my_token != _burn_token:
		return

	hand.burn_finished_to_stumps()

func usedAshTray() -> void:
	hand.remove_all_stumps()

func addCigToHand() -> void:
	if hand.get_total_count() >= MAX_IN_HAND:
		GameManager.message("Hand is full.")
		return

	cigPack.cig_amount -= 1
	var cig := cigarette_scene.instantiate() as Cigarette
	hand.add_cigarette(cig, Cigarette.State.UNLIT)

func _return_one_unlit_to_pack() -> void:
	var did_remove := hand.remove_one_unlit()
	
	if did_remove:
		cigPack.cig_amount += 1
		cigPack.update_label()
