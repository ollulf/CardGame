extends Node

const POOL_SIZE := 8
const BUTTON_SOUND := preload("res://sounds/button_press.wav")

const AMBIENT_SOUND := preload("res://sounds/bar_ambient.mp3")
const AMBIENT_VOLUME_DB := -24.0
const AMBIENT_SILENT_DB := -60.0
const AMBIENT_FADE_TIME := 2.0

const LIGHTER_SOUND := preload("res://sounds/lighter.wav")
const SMOKE_LOOP_SOUND := preload("res://sounds/smoking_loop.wav")
const SMOKE_LOOP_DB := -18.0
const LOOP_FADE_TIME := 0.4

var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _loop_counts := {}
var _loop_tweens := {}
var _ambient: AudioStreamPlayer
var _ambient_tween: Tween

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	play_ambient(AMBIENT_SOUND, AMBIENT_VOLUME_DB)
	get_tree().node_added.connect(_hook_node)
	_hook_tree(get_tree().root)

func play(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_ambient(stream: AudioStream, volume_db: float = AMBIENT_VOLUME_DB) -> void:
	if stream == null:
		return
	if _ambient_tween:
		_ambient_tween.kill()
	if _ambient.stream != stream or not _ambient.playing:
		_ambient.stream = stream
		_ambient.volume_db = AMBIENT_SILENT_DB
		_ambient.play()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient, "volume_db", volume_db, AMBIENT_FADE_TIME)


func stop_ambient() -> void:
	if _ambient_tween:
		_ambient_tween.kill()
	_ambient.stop()


func start_loop(key: String, stream: AudioStream, volume_db: float = SMOKE_LOOP_DB) -> void:
	_loop_counts[key] = int(_loop_counts.get(key, 0)) + 1
	if _loop_counts[key] > 1:
		return
	var player: AudioStreamPlayer = _loops.get(key)
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		_loops[key] = player
	if _loop_tweens.has(key):
		_loop_tweens[key].kill()
	player.stream = stream
	if not player.playing:
		player.volume_db = AMBIENT_SILENT_DB
		player.play()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, LOOP_FADE_TIME)
	_loop_tweens[key] = tween


func stop_loop(key: String) -> void:
	if int(_loop_counts.get(key, 0)) <= 0:
		return
	_loop_counts[key] -= 1
	if _loop_counts[key] > 0:
		return
	var player: AudioStreamPlayer = _loops[key]
	if _loop_tweens.has(key):
		_loop_tweens[key].kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", AMBIENT_SILENT_DB, LOOP_FADE_TIME)
	tween.tween_callback(_finish_loop.bind(key))
	_loop_tweens[key] = tween


func is_loop_playing(key: String) -> bool:
	return int(_loop_counts.get(key, 0)) > 0


func _finish_loop(key: String) -> void:
	if int(_loop_counts.get(key, 0)) == 0:
		_loops[key].stop()


func play_button() -> void:
	play(BUTTON_SOUND, 0.05)


func _hook_tree(node: Node) -> void:
	_hook_node(node)
	for child in node.get_children():
		_hook_tree(child)


func _hook_node(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_button):
		node.pressed.connect(play_button)
