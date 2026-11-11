extends Node2D
class_name DrinkGlass

const GROUP := "drink_glass"
const SEAT := 0
const PIXEL_SCALE := 3.0
const ROUND_LEFT_IN_GLASS := 0.2
const FADE_TIME := 0.3
const LINGER_TIME := 0.6

var art: DrinkArt
var _busy := false


func _ready() -> void:
	add_to_group(GROUP)
	art = DrinkArt.new()
	art.scale = Vector2.ONE * PIXEL_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	TableShadow.add_to(art, [&"fill"])
	visible = false


func drink_round(show_only := false) -> void:
	if _busy:
		if not show_only:
			_on_round_sipped()
		return
	_busy = true
	art.fill = 1.0
	art.position = Vector2.ZERO
	art.rotation = 0.0
	modulate.a = 0.0
	visible = true
	var appear := create_tween()
	appear.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	await appear.finished
	if not show_only:
		art.sipped.connect(_on_round_sipped, CONNECT_ONE_SHOT)
	await art.play_sip(ROUND_LEFT_IN_GLASS, 1.0)
	Sfx.play_glasses_down()
	var fade := create_tween()
	fade.tween_interval(LINGER_TIME)
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade.finished
	visible = false
	_busy = false


func _on_round_sipped() -> void:
	PlayerDataManager.drink(SEAT)
	get_tree().call_group(DrunkOverlay.GROUP, "gulp")
