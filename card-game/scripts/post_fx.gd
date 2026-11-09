@tool
class_name PostFX
extends CanvasLayer

enum Look { OFF, SMOKY_BAR, FILM_NOIR, NEON_GLOW, SMOKE_HAZE, LAMP_FLICKER, CRT, DRUNK, RECOMMENDED }

const LOOKS := {
	Look.OFF: {},
	Look.SMOKY_BAR: {
		"vignette_strength": 0.85,
		"grade_strength": 0.8,
	},
	Look.FILM_NOIR: {
		"vignette_strength": 1.0,
		"vignette_radius": 0.75,
		"grade_strength": 1.0,
		"grade_saturation": 0.35,
		"grade_contrast": 1.2,
		"grain_strength": 0.09,
		"aberration_strength": 0.8,
	},
	Look.NEON_GLOW: {
		"bloom_strength": 1.2,
		"bloom_threshold": 0.55,
		"vignette_strength": 0.5,
	},
	Look.SMOKE_HAZE: {
		"haze_strength": 0.75,
		"vignette_strength": 0.5,
	},
	Look.LAMP_FLICKER: {
		"flicker_strength": 0.3,
		"vignette_strength": 0.6,
	},
	Look.CRT: {
		"scanline_strength": 0.5,
		"crt_curve": 0.08,
		"aberration_strength": 1.5,
		"vignette_strength": 0.6,
	},
	Look.DRUNK: {
		"wobble_strength": 0.8,
		"aberration_strength": 2.0,
		"vignette_strength": 0.6,
	},
	Look.RECOMMENDED: {
		"vignette_strength": 0.75,
		"grade_strength": 0.6,
		"bloom_strength": 0.6,
		"bloom_threshold": 0.65,
		"haze_strength": 0.4,
		"grain_strength": 0.045,
	},
}

@export var look: Look = Look.OFF:
	set(value):
		look = value
		_apply()

@export var overrides: Dictionary = {}:
	set(value):
		overrides = value
		_apply()

var _rect: ColorRect

func _ready() -> void:
	_apply()

func set_look(value: Look) -> void:
	look = value

func set_param(param: String, value: Variant) -> void:
	overrides[param] = value
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	if _rect == null:
		_rect = get_node_or_null("Rect")
	if _rect == null:
		return
	var mat := _rect.material as ShaderMaterial
	for param in _all_params():
		mat.set_shader_parameter(param, null)
	var params: Dictionary = LOOKS.get(look, {}).duplicate()
	params.merge(overrides, true)
	for param in params:
		mat.set_shader_parameter(param, params[param])
	visible = look != Look.OFF or not overrides.is_empty()

func _all_params() -> Array:
	var names := {}
	for preset in LOOKS.values():
		for param in preset:
			names[param] = true
	for param in overrides:
		names[param] = true
	return names.keys()
