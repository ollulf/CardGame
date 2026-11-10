extends Node2D
class_name AiSmoke

signal lit
signal burned_out
signal finished
signal appeared

const BURN_TEXTURES: Array[Texture2D] = [
	preload("res://sprites/cigarettes/Cigarettes_1.png"),
	preload("res://sprites/cigarettes/Cigarettes_2.png"),
	preload("res://sprites/cigarettes/Cigarettes_3.png"),
	preload("res://sprites/cigarettes/Cigarettes_4.png"),
	preload("res://sprites/cigarettes/Cigarettes_5.png"),
	preload("res://sprites/cigarettes/Cigarettes_6.png"),
	preload("res://sprites/cigarettes/Cigarettes_7.png"),
	preload("res://sprites/cigarettes/Cigarettes_8.png"),
]

const PIXEL_SCALE := 3.0
const APPEAR_TIME := 0.4
const LIGHT_TIME := 0.7
const BURN_TIME := 60.0
const PUFF_TIME := 1.6
const PUFF_PAUSE_MIN := 2.0
const PUFF_PAUSE_MAX := 4.5
const STUB_TIME := 0.6
const SMOKE_LIFETIME := 2.4

var tilt := 0.0
var wait_for_lighter := false
var has_appeared := false

var _holder: Node2D
var _sprite: Sprite2D
var _glow: Node2D
var _smoke: CPUParticles2D
var _flame := 0.0
var _ember := 0.0
var _tip_rows: Array[int] = []
var _burning := false
var _run := 0
var _loop_held := false
var _light_tween: Tween


static func spawn(parent: Node, at: Vector2, tilt_radians: float, lit_externally := false) -> AiSmoke:
	var smoke := AiSmoke.new()
	smoke.tilt = tilt_radians
	smoke.wait_for_lighter = lit_externally
	smoke.position = at
	smoke.z_index = 50
	parent.add_child(smoke)
	smoke.play()
	return smoke


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for texture in BURN_TEXTURES:
		_tip_rows.append(texture.get_image().get_used_rect().position.y)

	_holder = Node2D.new()
	_holder.rotation = tilt
	_holder.scale = Vector2.ONE * PIXEL_SCALE
	add_child(_holder)

	_sprite = Sprite2D.new()
	_sprite.texture = BURN_TEXTURES[0]
	_sprite.centered = false
	_sprite.offset = Vector2(-2.5, -32.0)
	_holder.add_child(_sprite)

	_glow = Node2D.new()
	_glow.draw.connect(_draw_glow)
	_holder.add_child(_glow)

	_smoke = _make_smoke()
	add_child(_smoke)

	_holder.modulate.a = 0.0


func play() -> void:
	var appear := create_tween().set_parallel()
	appear.tween_property(_holder, "modulate:a", 1.0, APPEAR_TIME)
	appear.tween_property(_holder, "position", Vector2.ZERO, APPEAR_TIME).from(Vector2(0.0, 18.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await appear.finished
	has_appeared = true
	appeared.emit()

	if not wait_for_lighter:
		ignite()
	await burned_out

	var stub := create_tween().set_parallel()
	stub.tween_property(_holder, "scale", Vector2(PIXEL_SCALE * 1.25, PIXEL_SCALE * 0.6), STUB_TIME)
	stub.tween_property(_holder, "modulate:a", 0.0, STUB_TIME).set_delay(STUB_TIME * 0.5)
	await stub.finished
	finished.emit()

	await get_tree().create_timer(SMOKE_LIFETIME, false).timeout
	queue_free()


func show_unlit() -> void:
	_stop()
	_holder.modulate.a = 1.0
	_set_texture(0)
	_set_ember(0.0)


func ignite() -> void:
	_stop()
	var run := _run
	_holder.modulate.a = 1.0
	_set_texture(0)
	Sfx.play(Sfx.LIGHTER_SOUND)

	_light_tween = create_tween()
	_light_tween.tween_method(_set_flame, 0.0, 1.0, LIGHT_TIME * 0.4)
	_light_tween.tween_method(_set_flame, 1.0, 0.0, LIGHT_TIME * 0.6)
	_light_tween.parallel().tween_method(_set_ember, 0.0, 1.0, LIGHT_TIME * 0.6)
	await _light_tween.finished
	if run != _run:
		return
	lit.emit()

	_burning = true
	_hold_loop()
	_smoke.emitting = true
	_puff_loop(run)
	var step_time := BURN_TIME / float(BURN_TEXTURES.size() - 1)
	for index in range(1, BURN_TEXTURES.size()):
		await get_tree().create_timer(step_time, false).timeout
		if run != _run:
			return
		_set_texture(index)

	_burn_out()
	burned_out.emit()


func show_stub() -> void:
	var was_burning := _burning
	_stop()
	_holder.modulate.a = 1.0
	_set_texture(BURN_TEXTURES.size() - 1)
	if was_burning:
		_burn_out()
	else:
		_set_ember(0.0)


func _hold_loop() -> void:
	if not _loop_held:
		_loop_held = true
		Sfx.start_loop("smoke", Sfx.SMOKE_LOOP_SOUND)


func _release_loop() -> void:
	if _loop_held:
		_loop_held = false
		Sfx.stop_loop("smoke")


func _exit_tree() -> void:
	_release_loop()


func _stop() -> void:
	_release_loop()
	_run += 1
	_burning = false
	_smoke.emitting = false
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_set_flame(0.0)


func _burn_out() -> void:
	_release_loop()
	_burning = false
	_smoke.emitting = false
	create_tween().tween_method(_set_ember, _ember, 0.0, STUB_TIME * 0.5)


func _set_texture(index: int) -> void:
	_sprite.texture = BURN_TEXTURES[index]
	_glow.queue_redraw()
	_place_smoke()


func _puff_loop(run: int) -> void:
	await get_tree().create_timer(PUFF_TIME, false).timeout
	while _burning and run == _run:
		_smoke.emitting = false
		await get_tree().create_timer(randf_range(PUFF_PAUSE_MIN, PUFF_PAUSE_MAX), false).timeout
		if not _burning or run != _run:
			return
		_smoke.emitting = true
		await get_tree().create_timer(PUFF_TIME, false).timeout


func _process(_delta: float) -> void:
	if _flame > 0.0 or _ember > 0.0:
		_glow.queue_redraw()


func tip_global_position() -> Vector2:
	return _holder.get_global_transform() * _tip_local()


func _tip_local() -> Vector2:
	var index := BURN_TEXTURES.find(_sprite.texture)
	return Vector2(0.0, float(_tip_rows[max(index, 0)]) - 32.0)


func _place_smoke() -> void:
	_smoke.position = _holder.transform * _tip_local()


func _set_flame(value: float) -> void:
	_flame = value
	_glow.queue_redraw()


func _set_ember(value: float) -> void:
	_ember = value
	_glow.queue_redraw()


func _draw_glow() -> void:
	var tip := _tip_local()
	var time := Time.get_ticks_msec() / 1000.0
	if _ember > 0.0:
		var pulse := 0.75 + 0.25 * sin(time * 6.0)
		_glow.draw_circle(tip, 2.2 * _ember, Color(1.0, 0.45, 0.1, 0.35 * _ember * pulse))
		_glow.draw_circle(tip, 1.0 * _ember, Color(1.0, 0.75, 0.3, 0.9 * _ember))
	if _flame > 0.0:
		var flicker := 1.0 + 0.15 * sin(time * 40.0)
		var flame_tip := tip + Vector2(0.0, -2.0) * _flame
		_glow.draw_circle(flame_tip, 3.0 * _flame * flicker, Color(1.0, 0.55, 0.1, 0.45 * _flame))
		_glow.draw_circle(flame_tip, 1.6 * _flame * flicker, Color(1.0, 0.9, 0.5, 0.95 * _flame))


func _make_smoke() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 28
	particles.lifetime = SMOKE_LIFETIME
	particles.local_coords = false
	particles.direction = Vector2.UP
	particles.spread = 12.0
	particles.gravity = Vector2(6.0, -18.0)
	particles.initial_velocity_min = 14.0
	particles.initial_velocity_max = 26.0
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.6

	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	particles.scale_amount_curve = grow

	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.85, 0.85, 0.55))
	fade.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	particles.color_ramp = fade

	var puff := Gradient.new()
	puff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	puff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var puff_texture := GradientTexture2D.new()
	puff_texture.gradient = puff
	puff_texture.fill = GradientTexture2D.FILL_RADIAL
	puff_texture.fill_from = Vector2(0.5, 0.5)
	puff_texture.fill_to = Vector2(0.5, 0.0)
	puff_texture.width = 32
	puff_texture.height = 32
	particles.texture = puff_texture
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	particles.position = _holder.transform * Vector2(0.0, float(_tip_rows[0]) - 32.0)
	return particles
