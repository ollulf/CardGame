extends CanvasLayer

@onready var message_label := %MessageLabel

var _message_token: int = 0

func _ready() -> void:
	GameManager.connect("send_message", _message)
	clear()

func _message(text: String) -> void:
	_message_token += 1
	var my_token := _message_token

	message_label.text = text
	message_label.visible = true

	await get_tree().create_timer(3.0).timeout

	# If another message started meanwhile, abort
	if my_token != _message_token:
		return

	clear()

func clear():
	message_label.text = ""
