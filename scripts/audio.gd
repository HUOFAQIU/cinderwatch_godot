class_name CWAudio
extends Node

# Resource-driven audio manager loading pre-baked WAV clips from res://assets/audio/*.wav
# Routes SFX through a 14-slot AudioStreamPlayer2D stereo pool (SFX bus)
# and seamless ambience beds through 3 looping AudioStreamPlayers (Ambience bus).

const POOL_SIZE := 14
const SAVE_PATH := "user://cinderwatch_save.cfg"

const SFX_NAMES := [
	"arrow", "cannon", "explode", "zap", "sword", "hit", "kill", "coin",
	"build", "upgrade", "sell", "horn", "horn_boss", "crumble", "leak",
	"ui_click", "ui_deny", "bone_rattle", "rat_squeal", "bat_screech",
	"squelch", "rock_break", "ghost_fade", "wisp_pop", "clash",
]

var muted: bool = false
var paused_by_focus: bool = false
var sfx_clips: Dictionary = {}
var sfx_pool: Array[AudioStreamPlayer2D] = []
var pool_idx: int = 0
var last_play_time: Dictionary = {}

var amb_wind: AudioStreamPlayer = null
var amb_fire: AudioStreamPlayer = null
var amb_drone: AudioStreamPlayer = null


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func init_audio() -> void:
	_load_mute_pref()
	_ensure_bus("SFX")
	_ensure_bus("Ambience")
	AudioServer.set_bus_mute(0, muted or paused_by_focus)

	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.max_distance = 10000.0
		p.attenuation = 0.0
		p.panning_strength = 0.85
		add_child(p)
		sfx_pool.append(p)

	for nm: String in SFX_NAMES:
		var st := load("res://assets/audio/%s.wav" % nm) as AudioStream
		if st != null:
			sfx_clips[nm] = st

	amb_wind = _make_loop_player("amb_wind", -20.0)
	amb_fire = _make_loop_player("amb_fire", -22.0)
	amb_drone = _make_loop_player("amb_drone", -24.0)


func _make_loop_player(clip_name: String, vol_db: float) -> AudioStreamPlayer:
	var st := load("res://assets/audio/%s.wav" % clip_name) as AudioStream
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(float(w.data.size()) * 0.5)
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	p.stream = st
	p.volume_db = vol_db
	add_child(p)
	if st != null:
		p.play()
	return p


func _exit_tree() -> void:
	for p in sfx_pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for amb in [amb_wind, amb_fire, amb_drone]:
		if amb != null and is_instance_valid(amb):
			amb.stop()
			amb.stream = null
	sfx_clips.clear()


func _load_mute_pref() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		muted = bool(cfg.get_value("prefs", "muted", false))


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, muted or paused_by_focus)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("prefs", "muted", muted)
	cfg.save(SAVE_PATH)


func set_paused(p: bool) -> void:
	paused_by_focus = p
	AudioServer.set_bus_mute(0, muted or paused_by_focus)


func play_sfx(sfx_name: String, gain: float = 1.0, pitch_var: float = 0.08, world_x: float = 999.0) -> void:
	if muted or not sfx_clips.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	var prev := int(last_play_time.get(sfx_name, 0))
	if now - prev < 35:
		return
	last_play_time[sfx_name] = now

	var p := sfx_pool[pool_idx]
	pool_idx = (pool_idx + 1) % POOL_SIZE
	p.stream = sfx_clips[sfx_name]
	var pan := 0.0 if world_x > 500.0 else clampf(world_x / 18.0, -0.85, 0.85)
	p.position = Vector2(960.0 + pan * 680.0, 540.0)
	p.volume_db = linear_to_db(clampf(gain * 0.55, 0.01, 1.5))
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func update_ambience(tension: float, fire_lvl: float, wind_lvl: float) -> void:
	if muted or amb_wind == null:
		return
	amb_wind.volume_db = linear_to_db(clampf(0.065 + 0.095 * wind_lvl, 0.01, 0.28))
	amb_fire.volume_db = linear_to_db(clampf(0.055 + 0.095 * fire_lvl, 0.01, 0.28))
	var drone_g := clampf((tension - 0.08) * 0.085, 0.0005, 0.12)
	amb_drone.volume_db = linear_to_db(drone_g)
