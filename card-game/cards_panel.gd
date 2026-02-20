extends Panel

@onready var upper: Control = $UpperPanel
@onready var lower: Control = $LowerPanel


#hover / expand stuff
const EXPANDED_HEIGHT := 400.0
const SHRUNK_HEIGHT := 100.0
const DEADZONE := 6.0 # optional

var hovered := 0 # 0 top, 1 bottom

func _ready() -> void:
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_layout()

func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return

	var y := get_local_mouse_position().y
	var divider := upper.size.y

	if hovered == 0:
		if y > divider + DEADZONE:
			hovered = 1
			_refresh_layout()
	else:
		if y < divider - DEADZONE:
			hovered = 0
			_refresh_layout()

func _refresh_layout() -> void:
	if hovered == 0:
		upper.size.y = EXPANDED_HEIGHT
		lower.size.y = SHRUNK_HEIGHT
		lower.position.y = EXPANDED_HEIGHT
	else:
		upper.size.y = SHRUNK_HEIGHT
		lower.size.y = EXPANDED_HEIGHT
		lower.position.y = SHRUNK_HEIGHT
