class_name CWAudio
extends Node

# Procedural AudioStreamWAV synthesizer (zero external audio files)
# Pre-bakes SFX clips & seamless ambience beds at startup via pure math DSP
# Ported in spirit from 80-audio.js for Godot 4.7.2

const SAMPLE_RATE := 22050
const POOL_SIZE := 14

var muted: bool = false
var paused_by_focus: bool = false
var sfx_clips: Dictionary = {}
var sfx_pool: Array[AudioStreamPlayer2D] = []
var pool_idx: int = 0

var amb_wind: AudioStreamPlayer = null
var amb_fire: AudioStreamPlayer = null
var amb_drone: AudioStreamPlayer = null
var last_play_time: Dictionary = {}
var _bake_thread: Thread = null


const SAVE_PATH := "user://cinderwatch_save.cfg"


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
	AudioServer.set_bus_mute(0, muted)
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.max_distance = 10000.0
		p.attenuation = 0.0
		p.panning_strength = 0.85
		add_child(p)
		sfx_pool.append(p)
	# Bake procedural WAV clips on a background thread so first frame renders immediately
	_bake_thread = Thread.new()
	_bake_thread.start(_bake_all_async)


func _exit_tree() -> void:
	if _bake_thread != null and _bake_thread.is_started():
		_bake_thread.wait_to_finish()


func _bake_all_async() -> void:
	var clips := {
		"arrow": _bake_arrow(),
		"cannon": _bake_cannon(),
		"explode": _bake_explode(),
		"zap": _bake_zap(),
		"sword": _bake_sword(),
		"hit": _bake_hit(),
		"kill": _bake_kill(),
		"coin": _bake_coin(),
		"build": _bake_build(),
		"upgrade": _bake_upgrade(),
		"sell": _bake_sell(),
		"horn": _bake_horn(false),
		"horn_boss": _bake_horn(true),
		"crumble": _bake_crumble(),
		"leak": _bake_leak(),
		"ui_click": _bake_ui_click(),
		"ui_deny": _bake_ui_deny(),
		"bone_rattle": _bake_bone_rattle(),
		"rat_squeal": _bake_rat_squeal(),
		"bat_screech": _bake_bat_screech(),
		"squelch": _bake_squelch(),
		"rock_break": _bake_rock_break(),
		"ghost_fade": _bake_ghost_fade(),
		"wisp_pop": _bake_wisp_pop(),
		"clash": _bake_clash(),
	}
	var wind_w := _bake_wind_loop()
	var fire_w := _bake_fire_loop()
	var drone_w := _bake_drone_loop()
	call_deferred("_on_bake_done", clips, wind_w, fire_w, drone_w)


func _on_bake_done(clips: Dictionary, wind_w: AudioStreamWAV, fire_w: AudioStreamWAV, drone_w: AudioStreamWAV) -> void:
	sfx_clips = clips
	amb_wind = _make_loop_player(wind_w, -20.0)
	amb_fire = _make_loop_player(fire_w, -22.0)
	amb_drone = _make_loop_player(drone_w, -24.0)


func _make_loop_player(stream: AudioStreamWAV, vol_db: float) -> AudioStreamPlayer:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(float(stream.data.size()) * 0.5)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	p.play()
	return p


func _load_mute_pref() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		muted = bool(cfg.get_value("prefs", "muted", false))
		AudioServer.set_bus_mute(0, muted or paused_by_focus)


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_mute(0, muted or paused_by_focus)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("prefs", "muted", muted)
	cfg.save(SAVE_PATH)


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


func _pack_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _bake_arrow() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 28.0) * minf(1.0, t * 220.0)
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.25)
		var twang := sin(TAU * (380.0 - t * 900.0) * t) * exp(-t * 40.0)
		s[i] = (lp * 0.7 + twang * 0.45) * env
	return _pack_wav(s)


func _bake_cannon() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.42)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := lerpf(155.0, 38.0, minf(1.0, t * 4.5))
		ph += TAU * f / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.12)
		var env := exp(-t * 7.5) * minf(1.0, t * 300.0)
		s[i] = tanh((sin(ph) * 0.9 + lp * 0.7) * 1.8) * env
	return _pack_wav(s)


func _bake_explode() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.65)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := lerpf(110.0, 26.0, minf(1.0, t * 3.0))
		ph += TAU * f / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.16)
		var env := exp(-t * 5.2) * minf(1.0, t * 250.0)
		s[i] = tanh((sin(ph) * 0.7 + lp * 1.1) * 2.1) * env
	return _pack_wav(s)


func _bake_zap() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.24)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := lerpf(1400.0, 260.0, t / 0.24) + randf_range(-120.0, 120.0)
		ph += TAU * maxf(80.0, f) / float(SAMPLE_RATE)
		var env := exp(-t * 14.0) * minf(1.0, t * 400.0)
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		s[i] = tanh((saw * 0.65 + randf_range(-0.35, 0.35)) * 1.6) * env * 0.8
	return _pack_wav(s)


func _bake_sword() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.15)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 26.0) * minf(1.0, t * 350.0)
		var ring := sin(TAU * 1120.0 * t) * 0.5 + sin(TAU * 1690.0 * t) * 0.35 + sin(TAU * 2410.0 * t) * 0.2
		s[i] = (ring + randf_range(-0.25, 0.25) * exp(-t * 45.0)) * env * 0.65
	return _pack_wav(s)


func _bake_hit() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.10)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.28)
		var env := exp(-t * 36.0)
		s[i] = (lp * 0.8 + sin(TAU * 160.0 * t) * 0.4) * env
	return _pack_wav(s)


func _bake_kill() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		var env := exp(-t * 16.0)
		var rattle := sin(TAU * (420.0 + 180.0 * sin(t * 70.0)) * t) * 0.35
		s[i] = (lp * 0.65 + rattle) * env * 0.85
	return _pack_wav(s)


func _bake_coin() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.20)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := 1318.5 if t < 0.065 else 1760.0
		var env := exp(-t * 16.0) * minf(1.0, t * 300.0)
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.2) * env * 0.5
	return _pack_wav(s)


func _bake_build() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)
		var k1 := exp(-t * 28.0)
		var k2 := exp(-maxf(0.0, t - 0.11) * 24.0) if t > 0.11 else 0.0
		s[i] = (sin(TAU * 130.0 * t) * 0.6 + lp * 0.7) * (k1 + k2 * 0.8) * 0.7
	return _pack_wav(s)


func _bake_upgrade() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.36)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := 440.0 if t < 0.1 else (554.37 if t < 0.2 else 659.25)
		var env := exp(-t * 8.0) * minf(1.0, t * 180.0)
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.5 * t) * 0.25) * env * 0.55
	return _pack_wav(s)


func _bake_sell() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := lerpf(620.0, 310.0, t / 0.22)
		var env := exp(-t * 14.0)
		s[i] = sin(TAU * f * t) * env * 0.5
	return _pack_wav(s)


func _bake_horn(is_boss: bool) -> AudioStreamWAV:
	var dur := 1.25 if is_boss else 0.75
	var n := int(SAMPLE_RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var base_f := 82.41 if is_boss else 130.81
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var atk := minf(1.0, t / 0.12)
		var rel := clampf((dur - t) / 0.35, 0.0, 1.0)
		var env := atk * rel
		var sig := sin(TAU * base_f * t) * 0.6 + sin(TAU * base_f * 2.0 * t) * 0.35 + sin(TAU * base_f * 3.0 * t) * 0.2
		if is_boss:
			sig += sin(TAU * base_f * 1.5 * t) * 0.3
		s[i] = tanh(sig * 1.5) * env * 0.7
	return _pack_wav(s)


func _bake_crumble() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.06)
		var env := minf(1.0, t * 4.0) * clampf((1.1 - t) * 2.0, 0.0, 1.0)
		s[i] = tanh((lp * 1.8 + sin(TAU * 42.0 * t) * 0.3) * 1.6) * env * 0.75
	return _pack_wav(s)


func _bake_leak() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var f := lerpf(240.0, 95.0, t / 0.35)
		var env := exp(-t * 7.0)
		s[i] = tanh(sin(TAU * f * t) * 1.8) * env * 0.65
	return _pack_wav(s)


func _bake_ui_click() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.05)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		s[i] = sin(TAU * 880.0 * t) * exp(-t * 70.0) * 0.4
	return _pack_wav(s)


func _crossfade_loop(raw: PackedFloat32Array, fade_samples: int) -> PackedFloat32Array:
	var n := raw.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = raw[i]
	var f := mini(fade_samples, n / 4)
	for i in range(f):
		var u := float(i) / float(f)
		var w := 0.5 - 0.5 * cos(PI * u)
		out[i] = lerpf(raw[n - f + i], raw[i], w)
	return out


func _bake_wind_loop() -> AudioStreamWAV:
	# 8.0s Paul Kellet pink noise + natural airy 380-780 Hz breeze swell (zero robotic loop or sub-bass mud)
	var dur := 8.0
	var n := int(SAMPLE_RATE * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var lp := 0.0
	var hp := 0.0
	var prev_in := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var w := randf_range(-1.0, 1.0)
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		var pink := (b0 + b1 + b2 + w * 0.1848) * 0.14
		# Gentle high-pass (~95 Hz) removes muddy sub-bass; slow low-pass (380-780 Hz) creates natural gusts
		hp = 0.972 * (hp + pink - prev_in)
		prev_in = pink
		var gust := 0.5 + 0.5 * (0.65 * sin(TAU * t / dur) + 0.35 * sin(TAU * 2.0 * t / dur + 1.3))
		var cutoff := lerpf(0.11, 0.23, gust)
		lp = lerpf(lp, hp, cutoff)
		var amp := lerpf(0.68, 1.15, gust)
		raw[i] = clampf(lp * amp * 1.4, -0.85, 0.85)
	return _pack_wav(_crossfade_loop(raw, int(SAMPLE_RATE * 0.6)))


func _bake_fire_loop() -> AudioStreamWAV:
	# 6.0s warm pink-noise hearth + crisp noise-burst wood crackles (zero sine-wave bloops)
	var dur := 6.0
	var n := int(SAMPLE_RATE * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var lp := 0.0
	var hp := 0.0
	var prev_in := 0.0
	var crack_env := 0.0
	var crack_lp := 0.0
	for i in range(n):
		var w := randf_range(-1.0, 1.0)
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		var pink := (b0 + b1 + b2 + w * 0.1848) * 0.14
		hp = 0.96 * (hp + pink - prev_in)
		prev_in = pink
		lp = lerpf(lp, hp, 0.16)
		if randf() < 0.00045:
			crack_env = randf_range(0.18, 0.42)
		crack_lp = lerpf(crack_lp, w, 0.48)
		crack_env *= 0.965
		raw[i] = clampf(lp * 1.25 + crack_lp * crack_env, -0.85, 0.85)
	return _pack_wav(_crossfade_loop(raw, int(SAMPLE_RATE * 0.5)))


func _bake_drone_loop() -> AudioStreamWAV:
	var dur := 4.0
	var n := int(SAMPLE_RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	# Exact integer cycles in 4.0s (73.5 Hz = 294 cycles, 110.25 Hz = 441 cycles) -> zero loop click
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var swell := 0.85 + 0.15 * sin(TAU * t / dur)
		var v := sin(TAU * 73.5 * t) * 0.55 + sin(TAU * 110.25 * t) * 0.25
		s[i] = v * swell * 0.35
	return _pack_wav(s)


func set_paused(b: bool) -> void:
	paused_by_focus = b
	AudioServer.set_bus_mute(0, muted or paused_by_focus)


func _bake_ui_deny() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := 1.0 if (t < 0.065 or t > 0.088) else 0.0
		var env := exp(-t * 14.0) * pulse
		var f := 175.0 if t < 0.08 else 132.0
		s[i] = (sin(TAU * f * t) * 0.65 + sin(TAU * f * 2.0 * t) * 0.25) * env * 0.45
	return _pack_wav(s)


func _bake_bone_rattle() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var clack := exp(-fmod(t, 0.055) * 75.0) * exp(-t * 8.0)
		var f := 640.0 + 380.0 * sin(t * 90.0)
		s[i] = (sin(TAU * f * t) * 0.55 + randf_range(-0.45, 0.45)) * clack * 0.55
	return _pack_wav(s)


func _bake_rat_squeal() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.14)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * clampf(t / 0.14, 0.0, 1.0)) * exp(-t * 10.0)
		var f := lerpf(1180.0, 680.0, t / 0.14)
		s[i] = sin(TAU * f * t) * env * 0.35
	return _pack_wav(s)


func _bake_bat_screech() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 14.0)
		var f := lerpf(1350.0, 820.0, t / 0.18) + sin(t * 95.0) * 90.0
		s[i] = (sin(TAU * f * t) * 0.7 + randf_range(-0.2, 0.2)) * env * 0.32
	return _pack_wav(s)


func _bake_squelch() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.20)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 16.0)
		var f := lerpf(320.0, 85.0, clampf(t / 0.16, 0.0, 1.0))
		s[i] = (sin(TAU * f * t) * 0.75 + randf_range(-0.35, 0.35) * exp(-t * 25.0)) * env * 0.55
	return _pack_wav(s)


func _bake_rock_break() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 11.0)
		s[i] = (sin(TAU * 95.0 * t) * 0.5 + randf_range(-0.65, 0.65)) * env * 0.6
	return _pack_wav(s)


func _bake_ghost_fade() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.30)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * clampf(t / 0.30, 0.0, 1.0)) * exp(-t * 4.5)
		var f := lerpf(780.0, 420.0, t / 0.30)
		s[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 1.5 * t)) * env * 0.36
	return _pack_wav(s)


func _bake_wisp_pop() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.14)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 24.0)
		var f := lerpf(540.0, 1180.0, clampf(t / 0.08, 0.0, 1.0))
		s[i] = sin(TAU * f * t) * env * 0.42
	return _pack_wav(s)


func _bake_clash() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 22.0)
		var ring := sin(TAU * 1380.0 * t) * 0.45 + sin(TAU * 2120.0 * t) * 0.35 + randf_range(-0.25, 0.25) * exp(-t * 45.0)
		s[i] = ring * env * 0.48
	return _pack_wav(s)
