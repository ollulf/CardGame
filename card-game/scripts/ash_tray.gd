extends Area2D
class_name AshTray
@export var hover_offset: Vector2 = Vector2(0, -4)

const BUTTS_PER_MATCH := 2
const SPILL_FROM := 12
const ASH_PER_BUTT := 3
const SHADOW := Color("3a3442")
const FILTER := Color("d47728")
const FILTER_DARK := Color("a8561c")
const PAPER := Color("fffcf7")
const BURNT := Color("222034")
const ASH := [Color("847e87"), Color("5b5560"), Color("a39ca5"), Color("c7c0c7")]
const BUTT_SLOTS := [
	[Vector2i(8, 12), 0], [Vector2i(17, 15), 1], [Vector2i(12, 8), 2], [Vector2i(20, 10), 0],
	[Vector2i(9, 16), 3], [Vector2i(14, 12), 0], [Vector2i(22, 14), 2], [Vector2i(16, 7), 1],
	[Vector2i(7, 9), 3], [Vector2i(19, 17), 0], [Vector2i(11, 14), 2], [Vector2i(23, 11), 1],
	[Vector2i(24, 18), 0], [Vector2i(4, 19), 1], [Vector2i(27, 21), 3], [Vector2i(1, 15), 0],
]
const BOWL := Rect2i(5, 6, 22, 14)
const SPILL_AREA := Rect2i(0, 14, 32, 14)

@onready var sprite: Sprite2D = $Sprite2D

var _base_position: Vector2
var _fill: Sprite2D
var _shown := -1

func _ready() -> void:
	
	_base_position = sprite.position
	TableShadow.add_to(sprite)
	InteractionManager.grow_touch_shape($CollisionShape2D, Vector2(100, 84))
	_fill = Sprite2D.new()
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.add_child(_fill)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	PlayerDataManager.stats_changed.connect(_refresh_fill.unbind(1))
	GameManager.new_match_started.connect(_refresh_fill)
	_refresh_fill()


func butt_count() -> int:
	var baseline := (DialogueManager.upcoming_match() - 1) * BUTTS_PER_MATCH
	var smoked := 0
	for seat in PlayerDataManager.smoking_stacks:
		smoked += PlayerDataManager.get_smoking_stack_count(seat)
	return clampi(baseline + smoked, 0, BUTT_SLOTS.size())


func _refresh_fill() -> void:
	var count := butt_count()
	if count == _shown:
		return
	_shown = count
	_fill.texture = fill_texture(count) if count > 0 else null


static func fill_texture(count: int) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count * ASH_PER_BUTT:
		var area := SPILL_AREA if count >= SPILL_FROM and i % 4 == 0 else BOWL
		var x := rng.randi_range(area.position.x, area.end.x - 1)
		var y := rng.randi_range(area.position.y, area.end.y - 1)
		image.set_pixel(x, y, ASH[rng.randi() % ASH.size()])
	for i in count:
		var slot: Array = BUTT_SLOTS[i]
		_draw_butt(image, slot[0] + Vector2i(0, 1), slot[1], true)
	for i in count:
		var slot: Array = BUTT_SLOTS[i]
		_draw_butt(image, slot[0], slot[1], false)
	return ImageTexture.create_from_image(image)


static func _draw_butt(image: Image, at: Vector2i, facing: int, shadow: bool) -> void:
	var step: Vector2i = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)][facing]
	var colors := [FILTER_DARK, FILTER, PAPER, PAPER, BURNT]
	for i in colors.size():
		var p := at + step * i
		if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
			image.set_pixelv(p, SHADOW if shadow else colors[i])


func _on_mouse_entered() -> void:
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	sprite.position = _base_position


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	InteractionManager.usedAshTray()
