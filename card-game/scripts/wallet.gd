extends Area2D
class_name Wallet

signal clicked

@export var hover_offset: Vector2 = Vector2(0, -4)
@export var blocked: bool = false : set = set_blocked

@onready var sprite: Sprite2D = $Sprite2D
@onready var tooltip: Control = $Tooltip
@onready var money_label: Label = $MoneyLabel

var _base_position: Vector2
var _money_base_position: Vector2
var _hovered: bool = false
var _hidden_by_cue: bool = false


func _ready() -> void:
	_base_position = sprite.position
	TableShadow.add_to(sprite)
	_money_base_position = money_label.position
	PlayerDataManager.money_changed.connect(_on_money_changed)
	_on_money_changed(PlayerDataManager.money)
	tooltip.visible = false
	tooltip.add_theme_font_size_override("font_size", InteractionManager.font_px(13))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	add_to_group("wallet")
	GameManager.new_match_started.connect(_on_new_match_started)
	_on_new_match_started()


func _on_new_match_started() -> void:
	if DialogueManager.upcoming_match_uses_cue("show_purse"):
		_hidden_by_cue = true
		visible = false
		input_pickable = false
		modulate.a = 0.0
	else:
		visible = true
		PlayerDataManager.grant_starting_money()


func _on_money_changed(money: int) -> void:
	money_label.text = "%d$" % money


func reveal() -> void:
	if not _hidden_by_cue:
		return
	_hidden_by_cue = false
	visible = true
	PlayerDataManager.grant_starting_money()
	input_pickable = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished


func set_blocked(value: bool) -> void:
	blocked = value
	if is_node_ready():
		_refresh()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh()


func _refresh() -> void:
	var active := _hovered and not blocked
	sprite.position = _base_position + hover_offset if active else _base_position
	money_label.position = _money_base_position + hover_offset if active else _money_base_position
	tooltip.visible = active


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if blocked:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	Sfx.play_button()
	clicked.emit()
