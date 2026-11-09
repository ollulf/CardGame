extends CanvasLayer
class_name DrunkOverlay

const GROUP := "drunk_overlay"
const SEAT := 0
const SHADER := preload("res://shaders/drunk.gdshader")
const FULL_STRENGTH_DRINKS := 3.0
const FADE_TIME := 0.8
const PULSE_TIME := 1.2

var _rect: ColorRect
var _material: ShaderMaterial
var _strength_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	PlayerDataManager.stats_changed.connect(_on_stats_changed)
	_set_strength(0.0)
	_set_pulse(0.0)
	_update_visibility()


func gulp() -> void:
	_rect.visible = true
	var tween := create_tween()
	tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_update_visibility)


func _on_stats_changed(player_id: int) -> void:
	if player_id != SEAT:
		return
	var target := clampf(PlayerDataManager.get_drinking(SEAT) / FULL_STRENGTH_DRINKS, 0.0, 1.0)
	if _strength_tween:
		_strength_tween.kill()
	_rect.visible = true
	_strength_tween = create_tween()
	_strength_tween.tween_method(_set_strength, _material.get_shader_parameter("strength"), target, FADE_TIME)
	_strength_tween.tween_callback(_update_visibility)


func _set_strength(value: float) -> void:
	_material.set_shader_parameter("strength", value)


func _set_pulse(value: float) -> void:
	_material.set_shader_parameter("pulse", value)


func _update_visibility() -> void:
	var strength: float = _material.get_shader_parameter("strength")
	var pulse: float = _material.get_shader_parameter("pulse")
	_rect.visible = strength > 0.001 or pulse > 0.001
