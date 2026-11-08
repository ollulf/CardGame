extends CanvasLayer

const FADE_TIME := 0.5

@onready var dim: ColorRect = %Dim
@onready var content: Control = %Content
@onready var subtitle_label: Label = %SubtitleLabel
@onready var retry_button: Button = %RetryButton
@onready var start_over_button: Button = %StartOverButton

var _hand_parent: Node
var _hand_index := 0
var _fade_tween: Tween

func _ready() -> void:
	hide()
	GameManager.player_kicked.connect(open)
	retry_button.pressed.connect(_on_retry_pressed)
	start_over_button.pressed.connect(_on_start_over_pressed)

func open() -> void:
	var match_number := GameManager.current_match()
	subtitle_label.text = "You lost two rounds in match %d." % match_number
	retry_button.text = "Retry last match"
	_set_buttons_disabled(false)
	_lift_hand_pointer()
	dim.modulate.a = 0.0
	content.modulate.a = 0.0
	show()
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(dim, "modulate:a", 1.0, FADE_TIME)
	_fade_tween.tween_property(content, "modulate:a", 1.0, FADE_TIME)

func _on_retry_pressed() -> void:
	_close()
	GameManager.retry_match()

func _on_start_over_pressed() -> void:
	_close()
	GameManager.start_over()

func _close() -> void:
	_set_buttons_disabled(true)
	if _fade_tween:
		_fade_tween.kill()
	hide()
	_lower_hand_pointer()
	InteractionManager.skip_next_double_click()

func _set_buttons_disabled(disabled: bool) -> void:
	retry_button.disabled = disabled
	start_over_button.disabled = disabled

func _lift_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or hand.get_parent() == self:
		return
	_hand_parent = hand.get_parent()
	_hand_index = hand.get_index()
	hand.reparent(self)

func _lower_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	if hand == null or _hand_parent == null or hand.get_parent() != self:
		return
	hand.reparent(_hand_parent)
	_hand_parent.move_child(hand, _hand_index)
