extends Node

const POOL_SIZE := 8
const MAX_POOL_SIZE := 12
const CIG_MACHINE_SOUND := preload("res://sounds/cig_machine.wav")
const CARD_DRAW_SOUND := preload("res://sounds/card_draw.wav")
const CARD_MOVE_INTERVAL_MSEC := 60
const CARD_MOVE_PITCH_VARIATION := 0.08
const CARD_MOVE_VOLUME_DB := -4.0
const HOVER_CARD_SOUND := preload("res://sounds/hover_card.wav")
const HOVER_CARD_DB := -12.0
const HOVER_CARD_PITCH_VARIATION := 0.05
const HOVER_CARD_INTERVAL_MSEC := 50
const CARD_FLIP_SOUND := preload("res://sounds/card_played.wav")
const CARD_FLIP_DB := 0.0
const CARD_FLIP_PITCH_VARIATION := 0.1
const BOOSTER_CHEER_SOUNDS := [
	preload("res://sounds/booster_cheer_aww.wav"),
	preload("res://sounds/booster_cheer_haha.wav"),
	preload("res://sounds/booster_cheer_oooh.wav"),
]
const BOOSTER_CHEER_DB := -4.0
const TYPE_SOUND := preload("res://sounds/type_sound.wav")
const TYPE_SOUND_DB := -14.0
const TYPE_PITCH_VARIATION := 0.06
const BUTTON_SOUND := preload("res://sounds/button_press.wav")
const WIN_CARD_SOUND := preload("res://sounds/win_card.wav")
const WIN_CARD_DB := -8.0
const WIN_CARD_PITCH_VARIATION := 0.04
const DIALOGUE_NEXT_SOUND := preload("res://sounds/dialogue_next.mp3")
const DIALOGUE_NEXT_DB := -10.0
const DIALOGUE_NEXT_PITCH_VARIATION := 0.04
const BIERDECKEL_MOVE_SOUND := preload("res://sounds/bierdeckel_move.wav")
const BIERDECKEL_MOVE_DB := -6.0
const BIERDECKEL_MOVE_PITCH_VARIATION := 0.06
const BIERDECKEL_MOVE_INTERVAL_MSEC := 90

const AMBIENT_SOUND := preload("res://sounds/bar_ambient.mp3")
const AMBIENT_VOLUME_DB := -24.0
const AMBIENT_SILENT_DB := -60.0
const AMBIENT_FADE_TIME := 2.0

const LIGHTER_SOUND := preload("res://sounds/lighter.wav")
const SMOKE_LOOP_SOUND := preload("res://sounds/smoking_loop.wav")
const SMOKE_LOOP_DB := -18.0
const LOOP_FADE_TIME := 0.4

const MUSIC_SOUND := preload("res://sounds/jazz_track.mp3")
const MUSIC_VOLUME_DB := -17.0
const MUSIC_SILENT_DB := -60.0
const MUSIC_FADE_TIME := 3.0

const MUSIC_BUS := &"Music"
const AMBIENCE_BUS := &"Ambience"
const SFX_BUS := &"SFX"
const LONG_SOUND_SEC := 1.5

const ROUND_LOST_SOUND := preload("res://sounds/stinger_round_lost.wav")
const ROUND_LOST_DB := -1.0
const MATCH_LOST_SOUND := preload("res://sounds/stinger_match_lost.wav")
const MATCH_LOST_DB := 0.0
const RUN_WON_SOUND := preload("res://sounds/stinger_run_won.wav")
const RUN_WON_DB := 0.0
const COIN_DROP_SOUND := preload("res://sounds/coin_drop.ogg")
const COIN_DROP_DB := -9.0
const COIN_DROP_PITCH_VARIATION := 0.12
const COIN_DROP_INTERVAL_MSEC := 45
const COINS_PAYOUT_SOUND := preload("res://sounds/coins_payout.ogg")
const COINS_PAYOUT_DB := -6.0
const STAMP_SOUND := preload("res://sounds/stamp.ogg")
const STAMP_DB := -3.0
const GLASS_CLINK_SOUND := preload("res://sounds/glass_clink.ogg")
const GLASS_CLINK_DB := -6.0
const GLASS_DOWN_SOUND := preload("res://sounds/glass_down.ogg")
const GLASS_DOWN_DB := -8.0
const TABLE_KNOCK_SOUND := preload("res://sounds/table_knock.ogg")
const TABLE_KNOCK_DB := -5.0
const CHAIR_SCRAPE_SOUND := preload("res://sounds/chair_scrape.ogg")
const CHAIR_SCRAPE_DB := -12.0
const LAST_CALL_SOUND := preload("res://sounds/last_call_bell.ogg")
const LAST_CALL_DB := -8.0
const COUGH_SOUNDS := [
	preload("res://sounds/cough_light.ogg"),
	preload("res://sounds/cough_mid.ogg"),
	preload("res://sounds/cough_heavy.ogg"),
]
const COUGH_DB := -10.0
const COUGH_DELAY := 0.4
const COUGH_BASE_CHANCE := 0.08
const COUGH_CHANCE_PER_MATCH := 0.18

const DUCK_DB := -14.0
const DUCK_IN_TIME := 0.15
const DUCK_OUT_TIME := 0.8

var _last_played: AudioStreamPlayer
var _cheer_player: AudioStreamPlayer
var card_move_count := 0
var _last_card_move_msec := -1000
var _last_hover_msec := -1000
var _last_bierdeckel_msec := -1000
var _music: AudioStreamPlayer
var _music_tween: Tween
var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _loop_counts := {}
var _loop_tweens := {}
var _ambient: AudioStreamPlayer
var _ambient_tween: Tween
var _started_msec := {}
var _protected := {}
var _duck_tween: Tween
var _duck_until_msec := 0
var _last_coin_msec := -1000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = AMBIENCE_BUS
	add_child(_ambient)
	play_ambient(AMBIENT_SOUND, AMBIENT_VOLUME_DB)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	play_music(MUSIC_SOUND, MUSIC_VOLUME_DB)
	get_tree().node_added.connect(_hook_node)
	_hook_tree(get_tree().root)
	GameManager.round_finished.connect(_on_round_finished)
	GameManager.match_lost.connect(_on_match_lost)
	GameManager.run_won.connect(play_run_won)
	GameManager.new_match_started.connect(_on_new_match_started)
	PlayerDataManager.stamp_applied.connect(play_stamp.unbind(1))

func play_card_move(delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	var now := Time.get_ticks_msec()
	if now - _last_card_move_msec < CARD_MOVE_INTERVAL_MSEC:
		return
	_last_card_move_msec = now
	card_move_count += 1
	play(CARD_DRAW_SOUND, CARD_MOVE_PITCH_VARIATION, CARD_MOVE_VOLUME_DB)

func play_bierdeckel_move() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_bierdeckel_msec < BIERDECKEL_MOVE_INTERVAL_MSEC:
		return
	_last_bierdeckel_msec = now
	play(BIERDECKEL_MOVE_SOUND, BIERDECKEL_MOVE_PITCH_VARIATION, BIERDECKEL_MOVE_DB)

func play_hover_card() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < HOVER_CARD_INTERVAL_MSEC:
		return
	_last_hover_msec = now
	play(HOVER_CARD_SOUND, HOVER_CARD_PITCH_VARIATION, HOVER_CARD_DB)


func play(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0, important: bool = false) -> void:
	if stream == null:
		return
	_last_played = null
	var is_protected := important or stream.get_length() > LONG_SOUND_SEC
	var player := _pick_player(is_protected)
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	_started_msec[player] = Time.get_ticks_msec()
	_protected[player] = is_protected
	_last_played = player


func _pick_player(is_protected: bool) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			return p
		if _protected.get(p, false):
			continue
		if oldest == null or _started_msec.get(p, 0) < _started_msec.get(oldest, 0):
			oldest = p
	if oldest == null and is_protected and _players.size() < MAX_POOL_SIZE:
		var extra := AudioStreamPlayer.new()
		extra.bus = SFX_BUS
		add_child(extra)
		_players.append(extra)
		return extra
	return oldest


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
		player.bus = AMBIENCE_BUS
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


func play_music(stream: AudioStream, volume_db: float = MUSIC_VOLUME_DB) -> void:
	if stream == null:
		return
	if _music_tween:
		_music_tween.kill()
	if _music.stream != stream or not _music.playing:
		_music.stream = stream
		_music.volume_db = MUSIC_SILENT_DB
		_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", volume_db, MUSIC_FADE_TIME)


func stop_music() -> void:
	if _music_tween:
		_music_tween.kill()
	_music.stop()


func play_cig_machine() -> float:
	play(CIG_MACHINE_SOUND, 0.0, 0.0, true)
	return CIG_MACHINE_SOUND.get_length()

func play_dialogue_next() -> void:
	play(DIALOGUE_NEXT_SOUND, DIALOGUE_NEXT_PITCH_VARIATION, DIALOGUE_NEXT_DB)

func play_type(base_pitch: float) -> void:
	play(TYPE_SOUND, 0.0, TYPE_SOUND_DB)
	if _last_played != null:
		_last_played.pitch_scale = base_pitch * (1.0 + randf_range(-TYPE_PITCH_VARIATION, TYPE_PITCH_VARIATION))

func play_win_card() -> void:
	play(WIN_CARD_SOUND, WIN_CARD_PITCH_VARIATION, WIN_CARD_DB)

func play_card_flip() -> void:
	play(CARD_FLIP_SOUND, CARD_FLIP_PITCH_VARIATION, CARD_FLIP_DB)

func play_booster_cheer() -> void:
	if _cheer_player != null and _cheer_player.playing:
		return
	play(BOOSTER_CHEER_SOUNDS.pick_random(), 0.03, BOOSTER_CHEER_DB)
	_cheer_player = _last_played

func play_button() -> void:
	play(BUTTON_SOUND, 0.05)


func play_coin_drop() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_coin_msec < COIN_DROP_INTERVAL_MSEC:
		return
	_last_coin_msec = now
	play(COIN_DROP_SOUND, COIN_DROP_PITCH_VARIATION, COIN_DROP_DB)

func play_coins_payout() -> void:
	play(COINS_PAYOUT_SOUND, 0.04, COINS_PAYOUT_DB)

func play_stamp() -> void:
	play(STAMP_SOUND, 0.04, STAMP_DB)

func play_drink_round() -> void:
	play(GLASS_CLINK_SOUND, 0.05, GLASS_CLINK_DB)

func play_glass_down() -> void:
	play(GLASS_DOWN_SOUND, 0.06, GLASS_DOWN_DB)

func play_table_knock() -> void:
	play(TABLE_KNOCK_SOUND, 0.03, TABLE_KNOCK_DB)

func play_chair_scrape() -> void:
	play(CHAIR_SCRAPE_SOUND, 0.08, CHAIR_SCRAPE_DB)

func play_last_call() -> void:
	play(LAST_CALL_SOUND, 0.0, LAST_CALL_DB, true)

func play_cough(match_number: int) -> void:
	var level := clampi(match_number - 1, 0, 4)
	var index := clampi(roundi((level + randf_range(-1.0, 1.0)) / 2.0), 0, COUGH_SOUNDS.size() - 1)
	play(COUGH_SOUNDS[index], 0.06, COUGH_DB)


func _on_new_match_started() -> void:
	if Missions.is_last_match(GameManager.current_match()):
		play_last_call()


func _on_smoke_burned_out() -> void:
	var match_number := GameManager.current_match()
	if randf() > COUGH_BASE_CHANCE + COUGH_CHANCE_PER_MATCH * (match_number - 1):
		return
	await get_tree().create_timer(COUGH_DELAY, false).timeout
	play_cough(match_number)


func play_round_lost() -> void:
	_play_stinger(ROUND_LOST_SOUND, ROUND_LOST_DB)

func play_match_lost() -> void:
	_play_stinger(MATCH_LOST_SOUND, MATCH_LOST_DB)

func play_run_won() -> void:
	_play_stinger(RUN_WON_SOUND, RUN_WON_DB)


func _play_stinger(stream: AudioStream, volume_db: float) -> void:
	play(stream, 0.0, volume_db, true)
	duck_music(stream.get_length())


func duck_music(duration: float) -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var duck := AudioServer.get_bus_effect(bus, 0) as AudioEffectAmplify
	if duck == null:
		return
	var hold_msec := Time.get_ticks_msec() + int(duration * 1000.0)
	if hold_msec <= _duck_until_msec and _duck_tween != null and _duck_tween.is_running():
		return
	_duck_until_msec = hold_msec
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(duck, "volume_db", DUCK_DB, DUCK_IN_TIME)
	_duck_tween.tween_interval(maxf(duration - DUCK_IN_TIME, 0.0))
	_duck_tween.tween_property(duck, "volume_db", 0.0, DUCK_OUT_TIME)


func _on_round_finished(loosers) -> void:
	if loosers is Array and loosers.has(GameManager.HUMAN_ID):
		play_round_lost()


func _on_match_lost(looser_id: int) -> void:
	if looser_id == GameManager.HUMAN_ID:
		play_match_lost()


func _hook_tree(node: Node) -> void:
	_hook_node(node)
	for child in node.get_children():
		_hook_tree(child)


func _hook_node(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_button):
		node.pressed.connect(play_button)
	elif node is AiSmoke and not node.burned_out.is_connected(_on_smoke_burned_out):
		node.burned_out.connect(_on_smoke_burned_out)
