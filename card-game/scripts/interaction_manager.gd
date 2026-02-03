extends Node

var cigPack: CigPack
var hand: Hand

@export var cigarette_scene:= preload("res://scenes/cigarette.tscn") 

const MAX_IN_HAND := 3
const BURN_SECONDS := 20.0

var _burn_token: int = 0


func _ready() -> void:
	# Autoload nodes receive input, but only if input processing is on.
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	# Right click: put one unlit cigarette back into the pack
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_return_one_unlit_to_pack()


# Called when player clicks CigPack
func pickedUpCig() -> void:
	addCigToHand()


# Called when player clicks Lighter
func usedLighter() -> void:
	if hand == null:
		return

	# Light all currently unlit cigs
	hand.light_all_unlit()


	GameManager.message("Lighting...")

	# Restart burn countdown if lighter is used again
	_burn_token += 1
	var my_token := _burn_token

	await get_tree().create_timer(BURN_SECONDS).timeout
	if my_token != _burn_token:
		return

	hand.burn_finished_to_stumps()
	GameManager.message("Done. Stumps remain. Use ashtray.")


# Called when player clicks Ashtray
func usedAshTray() -> void:
	if hand == null:
		return

	hand.remove_all_stumps()


func addCigToHand() -> void:
	if hand.get_total_count() >= MAX_IN_HAND:
		GameManager.message("Hand is full.")
		return

	var cig := cigarette_scene.instantiate() as Cigarette
	hand.add_cigarette(cig, Cigarette.State.UNLIT)


func _return_one_unlit_to_pack() -> void:
	if hand == null:
		return

	var did_remove := hand.remove_one_unlit()
	if did_remove:
		# If your cigpack tracks amount, you can increase it here
		# Example: cigPack.cig_amount += 1; cigPack.update_label()
		GameManager.message("Put cigarette back into pack.")
	else:
		GameManager.message("No unlit cigarette to put back.")
