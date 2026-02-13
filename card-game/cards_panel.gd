extends Panel

@onready var panel_a: Control = $UpperPanel
@onready var panel_b: Control = $LowerPanel

const EXPANDED_HEIGHT := 50
const SHRUNK_HEIGHT := 400

func _ready():
	panel_a.mouse_entered.connect(_on_panel_a_hovered)
	panel_b.mouse_entered.connect(_on_panel_b_hovered)

func _on_panel_a_hovered():
	panel_a.size.y = EXPANDED_HEIGHT
	panel_b.size.y = SHRUNK_HEIGHT

func _on_panel_b_hovered():
	panel_b.size.y = EXPANDED_HEIGHT
	panel_a.size.y = SHRUNK_HEIGHT
