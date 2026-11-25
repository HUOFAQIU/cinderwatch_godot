class_name CWMain
extends Node

# Main orchestrator: half-res SubViewport + post-processing shader, texel-snapped isometric Camera3D,
# input handling, and fixed-timestep game loop. Ported from 20-post.js and 90-main.js.

const CAM_YAW := PI * 0.25
const CAM_ELEV := deg_to_rad(38.0)
const CAM_DIST := 78.0
const BASE_VIEW_H := 25.0
const MAX_IH := 620
const MAX_PIX := 690000.0

@onready var sub_vp: SubViewport = %SubViewport
@onready var world: Node3D = %World
@onready var world_env: WorldEnvironment = %WorldEnvironment
@onready var cam: Camera3D = %Camera3D
@onready var post_rect: TextureRect = %PostProcessRect

@onready var terrain: CWTerrain = %Terrain
@onready var rig: CWRig = %Rig
@onready var fx: CWFx = %Fx
@onready var towers_sys: CWTowers = %Towers
@onready var audio: CWAudio = %Audio
@onready var monsters_sys: CWMonsters = %Monsters
@onready var game: CWGame = %Game
@onready var ui: CWUI = %UI

var post_mat: ShaderMaterial
var mist_mat: ShaderMaterial
var ao_mat: ShaderMaterial
var dof_mat: ShaderMaterial
var screen_fade: float = 0.0
var env: Environment
var gfx: CWGfx

var cam_pos := Vector3.ZERO
var cam_focus := Vector3.ZERO
var cam_zoom := 1.0
var cam_man: bool = false
var cam_mx: float = 0.0
var cam_mz: float = 0.0
var cam_mzoom: float = 1.0
var cam_base: float = BASE_VIEW_H
var cam_aspect: float = 1.7778
var cam_za: Dictionary = {}

# Left-drag pan & double-click zoom state
var _drag_down: bool = false
var _drag_panning: bool = false
var _drag_on_hud: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_last: Vector2 = Vector2.ZERO
var _last_tap_ms: int = -9999
var _last_tap_pos: Vector2 = Vector2.ZERO
var sim_time := 0.0
var sub_texel := Vector2.ZERO
var dither_ofs := Vector2.ZERO
var render_quality := 1.0
var render_lite: bool = false
var _ft_acc := 0.0
var _ft_n := 0
var _ft_hi := 0
var _ft_lo := 0
var _q_hold := 0.0
var _q_back := 12.0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_setup_viewport_and_post()
	var t1 := Time.get_ticks_msec()
	_setup_world()
	var t2 := Time.get_ticks_msec()
	_on_window_resize()
	get_viewport().size_changed.connect(_on_window_resize)
	print("[Cinderwatch Startup] viewport=%dms | world+board=%dms | total=%dms" % [t1 - t0, t2 - t1, Time.get_ticks_msec() - t0])


func _setup_viewport_and_post() -> void:
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	post_rect.texture = sub_vp.get_texture()
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post_process.gdshader")
	post_rect.material = post_mat


func _setup_world() -> void:
	env = world_env.environment

	# Shared fullscreen quad for P0-1 Screen-Space AO (priority 126) & P0-2 Ground Mist (priority 127)
	var mq := QuadMesh.new()
	mq.size = Vector2(2.0, 2.0)

	var ao_sh := load("res://shaders/atmo_ao.gdshader") as Shader
	if ao_sh != null:
		var ao_mesh := MeshInstance3D.new()
		ao_mesh.mesh = mq
		ao_mesh.extra_cull_margin = 16384.0
		ao_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ao_mat = ShaderMaterial.new()
		ao_mat.shader = ao_sh
		ao_mat.render_priority = 125
		ao_mesh.material_override = ao_mat
		cam.add_child(ao_mesh)

	var mist_sh := load("res://shaders/atmo_mist.gdshader") as Shader
	if mist_sh != null:
		var mist_mesh := MeshInstance3D.new()
		mist_mesh.mesh = mq
		mist_mesh.extra_cull_margin = 16384.0
		mist_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist_mat = ShaderMaterial.new()
		mist_mat.shader = mist_sh
		mist_mat.render_priority = 126
		mist_mesh.material_override = mist_mat
		cam.add_child(mist_mesh)

	var dof_sh := load("res://shaders/atmo_dof.gdshader") as Shader
	if dof_sh != null:
		var dof_mesh := MeshInstance3D.new()
		dof_mesh.mesh = mq
		dof_mesh.extra_cull_margin = 16384.0
		dof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dof_mat = ShaderMaterial.new()
		dof_mat.shader = dof_sh
		dof_mat.render_priority = -20
		dof_mesh.material_override = dof_mat
		cam.add_child(dof_mesh)

	# Core Systems (scene nodes wired via @onready in main.tscn)
	gfx = CWGfx.new()
	gfx.init_resources()

	audio.init_audio()
	terrain.gfx = gfx
	rig.init_kits(gfx)
	fx.init_fx()
	towers_sys.init_towers(gfx, fx, audio, rig, terrain)
	monsters_sys.init_monsters(terrain, rig, fx, audio, towers_sys)

	ui.main_ref = self
	ui.init_ui(game, audio, world, cam, sub_vp)

	# Godot signal wiring
	monsters_sys.monster_killed.connect(game.on_monster_killed)
	monsters_sys.monster_leaked.connect(game.on_monster_leaked)
	monsters_sys.boss_dying.connect(game.on_boss_dying)
	monsters_sys.new_mob_spawned.connect(ui.saw_monster)
	game.banner_requested.connect(ui.show_banner)
	game.coin_dropped.connect(ui.spawn_hud_coins)

	game.init_game(terrain, towers_sys, monsters_sys, fx, rig, audio, env)


func _on_window_resize() -> void:
	var win_sz := get_viewport().get_visible_rect().size
	var dw := maxf(win_sz.x, 2.0)
	var dh := maxf(win_sz.y, 2.0)
	var texel := maxf(2.0, maxf(sqrt(dw * dh / MAX_PIX), minf(dw, dh) / float(MAX_IH)))
	var ih := int(roundf(dh / texel * render_quality))
	ih = maxi(ih, mini(int(dh), 240))
	var iw := maxi(int(roundf(float(ih) * (dw / dh))), 320)
	if iw > 1500:
		ih = maxi(240, int(roundf(float(ih) * 1500.0 / float(iw))))
		iw = 1500
	sub_vp.size = Vector2i(iw, ih)
	post_mat.set_shader_parameter("u_tex_size", Vector2(iw, ih))
	post_mat.set_shader_parameter("u_out_size", Vector2(dw, dh))
	if ao_mat != null:
		ao_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))
	if dof_mat != null:
		dof_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))


func _process(delta: float) -> void:
	# D1: Adaptive internal resolution monitor (2s window, 22.5ms down / 18.6ms up)
	if delta < 0.25:
		_ft_acc += delta
		_ft_n += 1
		_q_hold = maxf(0.0, _q_hold - delta)
		if _ft_acc >= 2.0 and _ft_n > 10:
			var avg_ms := (_ft_acc / float(_ft_n)) * 1000.0
			_ft_acc = 0.0
			_ft_n = 0
			if avg_ms > 22.5:
				_ft_hi += 1
				_ft_lo = 0
				if _ft_hi >= 3 and render_quality <= 0.56 and not render_lite:
					render_lite = true
					_ft_hi = 0
					if post_mat != null:
						post_mat.set_shader_parameter("u_dof_strength", 0.0)
					if fx != null and fx.moon_light != null:
						fx.moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
						fx.moon_light.shadow_blur = 0.2
				elif _ft_hi >= 2 and render_quality > 0.56:
					render_quality = maxf(0.55, render_quality - 0.15)
					_ft_hi = 0
					_q_hold = _q_back
					_q_back = minf(480.0, _q_back * 2.0)
					_on_window_resize()
			elif avg_ms < 18.6 and _q_hold <= 0.0:
				_ft_lo += 1
				_ft_hi = 0
				if _ft_lo >= 3 and render_quality < 0.99:
					render_quality = minf(1.0, render_quality + 0.15)
					_ft_lo = 0
					_on_window_resize()
			else:
				_ft_hi = 0
				_ft_lo = 0
	else:
		_ft_acc = 0.0
		_ft_n = 0

	# D0: Split real dt (camera, UI, audio) vs simulation dt (slowmo x0.32 on Boss death)
	var rdt := minf(delta, 0.05)
	var _p_mon_ms := 0.0
	var _p_rig_ms := 0.0
	var _p_tow_ms := 0.0
	_poll_pan_keys(rdt)
	if not game.paused:
		var steps := clampi(game.speed, 1, 3)
		var t_tow_us := 0
		var t_mon_us := 0
		var t_rig_us := 0
		for _sp in range(steps):
			game.slowmo = maxf(0.0, game.slowmo - rdt)
			var sdt := rdt * lerpf(1.0, 0.32, clampf(game.slowmo / 0.35, 0.0, 1.0))
			sim_time += sdt
			rig.begin_frame()
			fx.torch_positions.clear()
			fx.dynamic_flames.clear()
			game.update_game(sdt)
			var t0_u := Time.get_ticks_usec()
			towers_sys.update_towers(sdt, monsters_sys, game.dmg_mul)
			var t1_u := Time.get_ticks_usec()
			monsters_sys.update_monsters(sdt)
			var t2_u := Time.get_ticks_usec()
			rig.update_debris(sdt, terrain)
			t_tow_us += t1_u - t0_u
			t_mon_us += t2_u - t1_u
			if game.phase == "play" and not terrain.layout.is_empty():
				var k0 := (1.0 if game.gold >= 70 else 0.45) * (1.25 if not game.ai_commander else 1.0)
				var pads_arr: Array = terrain.layout["pads"]
				for pi in range(pads_arr.size()):
					var pd: Dictionary = pads_arr[pi]
					var has_t := pd["tower"] != null
					if pd.has("marker") and is_instance_valid(pd["marker"]):
						var mk: MeshInstance3D = pd["marker"]
						mk.visible = not has_t
						if not has_t:
							mk.rotation.y = float(pd.get("marker_yaw", 0.0)) + sin(sim_time * 1.3 + float(pi) * 2.1) * 0.30
					if not has_t:
						var w_p := 0.5 + 0.5 * sin(sim_time * 2.1 + float(pi) * 1.7)
						rig.push_glow(Vector3(float(pd["x"]), float(pd["y"]) + 0.36, float(pd["z"])), Color(2.6, 1.6, 0.55), 2.8 + 0.25 * w_p, (0.20 + 0.14 * w_p) * k0)
			var t3_u := Time.get_ticks_usec()
			rig.end_frame()
			t_rig_us += Time.get_ticks_usec() - t3_u
			fx.update_fx(sdt, sim_time, cam_pos)
		_p_mon_ms = float(t_mon_us) * 0.001
		_p_rig_ms = float(t_rig_us) * 0.001
		_p_tow_ms = float(t_tow_us) * 0.001

	_update_camera(rdt)
	var mon_cnt := monsters_sys.mons.size()
	if mon_cnt > 350:
		rig.set_crowd_shadow_lod(true)
		fx.set_crowd_shadow_lod(true)
	elif mon_cnt < 300:
		rig.set_crowd_shadow_lod(false)
		fx.set_crowd_shadow_lod(false)
	var tension := clampf(float(mon_cnt) / 24.0 + (0.45 if game.boss_wave else 0.0), 0.0, 1.0)
	audio.update_ambience(tension, fx.beacon_level, float(terrain.bio.get("wind", 1.0)))
	ui.update_ui(rdt)
	ui.update_perf_overlay(
		int(Engine.get_frames_per_second()),
		monsters_sys.mons.size(),
		towers_sys.footmen.size(),
		rig.get_gpu_unit_count(),
		_p_mon_ms, _p_rig_ms, _p_tow_ms
	)

	fx.update_biome_look(rdt)
	var lc := fx.look_cur
	screen_fade = minf(1.0, screen_fade + rdt * 1.45)
	post_mat.set_shader_parameter("u_sub", sub_texel)
	post_mat.set_shader_parameter("u_dither_ofs", dither_ofs)
	post_mat.set_shader_parameter("u_grade", Vector4(float(lc.get("expo", 1.0)), float(lc.get("sat", 0.92)), 0.55, screen_fade))
	post_mat.set_shader_parameter("u_lift", lc.get("lift", Vector3(0.01, 0.016, 0.03)))
	var ml := fx.get_mist_lights()
	if mist_mat != null:
		mist_mat.set_shader_parameter("u_light_pos", ml["pos"])
		mist_mat.set_shader_parameter("u_light_col", ml["col"])
		mist_mat.set_shader_parameter("u_light_count", ml["count"])
		mist_mat.set_shader_parameter("u_mist_amb", lc.get("mist_amb", Vector3(0.05, 0.08, 0.14)))
		mist_mat.set_shader_parameter("u_mist", lc.get("mist", Vector4(-0.3, 0.42, 0.75, 0.10)))
	if fx.wx_mat != null:
		var w_pos: Array[Vector3] = []
		var w_col: Array[Vector3] = []
		var src_p: Array[Vector3] = ml["pos"]
		var src_c: Array[Vector3] = ml["col"]
		for wi in range(12):
			w_pos.append(src_p[wi] if wi < src_p.size() else Vector3.ZERO)
			w_col.append(src_c[wi] if wi < src_c.size() else Vector3.ZERO)
		fx.wx_mat.set_shader_parameter("u_light_pos", w_pos)
		fx.wx_mat.set_shader_parameter("u_light_col", w_col)
		fx.wx_mat.set_shader_parameter("u_light_count", mini(int(ml["count"]), 12))
		fx.wx_mat.set_shader_parameter("u_focus_dist", CAM_DIST)
	if ao_mat != null:
		var px_w := cam.size / maxf(float(sub_vp.size.y), 1.0)
		var ao_rad := clampf(0.85 / maxf(px_w, 0.005), 8.0, 26.0)
		ao_mat.set_shader_parameter("u_ao", Vector3(1.0, ao_rad, 0.7))
		ao_mat.set_shader_parameter("u_dither", dither_ofs)
	if dof_mat != null:
		var dsc := clampf(1.0 / maxf(cam_zoom, 0.5), 0.75, 1.8)
		var max_r := 0.5 if render_lite else clampf(minf(float(sub_vp.size.y), float(sub_vp.size.x) * 1.6) * 0.0145, 2.0, 9.0)
		dof_mat.set_shader_parameter("u_dof", Vector4(CAM_DIST, 3.6 * dsc, 12.5 * dsc, max_r))
		dof_mat.set_shader_parameter("u_near", Vector4(9.0 * dsc, 16.0 * dsc, 0.6, 0.25))
		dof_mat.set_shader_parameter("u_dither", dither_ofs)


func _update_camera(dt: float) -> void:
	var has_boss := false
	if game.phase == "play" or game.phase == "defeat":
		for m: CWMonsterUnit in monsters_sys.mons:
			if not m.dead and bool(m.def.get("boss", false)):
				has_boss = true
				break

	var away := (game.phase == "clear" or game.phase == "crumble" or game.phase == "rise")
	# Keep default camera centered on the board origin (0, 0)
	cam_focus.x = CWUtil.damp(cam_focus.x, 0.0, 2.5, dt)
	cam_focus.z = CWUtil.damp(cam_focus.z, 0.0, 2.5, dt)
	var win_sz := get_viewport().get_visible_rect().size
	cam_aspect = maxf(0.5, win_sz.x / maxf(win_sz.y, 1.0))
	cam_base = maxf(BASE_VIEW_H, 45.0 / cam_aspect)

	if away:
		cam_man = false
		cam_za.clear()
	if not cam_za.is_empty():
		var z0 := cam_mzoom if cam_man else cam_zoom
		var to_z := float(cam_za["to"])
		var rate := float(cam_za.get("rate", 9.0))
		var r_step := pow(to_z / maxf(z0, 0.01), 1.0 - exp(-dt * rate))
		cam_zoom_at(r_step, float(cam_za["px"]), float(cam_za["py"]))
		if absf(log(to_z / maxf(cam_mzoom, 0.01))) < 0.012 or absf(cam_mzoom - z0) < 1e-5:
			cam_za.clear()

	if cam_man:
		cam_pos.x = cam_mx
		cam_pos.z = cam_mz
		cam_zoom = cam_mzoom
	else:
		cam_pos.x = CWUtil.damp(cam_pos.x, cam_focus.x, 0.8, dt)
		cam_pos.z = CWUtil.damp(cam_pos.z, cam_focus.z, 0.8, dt)
		var z_target := 0.62 if away else (0.92 if game.phase == "defeat" else (1.14 if has_boss else 1.0))
		cam_zoom = CWUtil.damp(cam_zoom, z_target, 1.1 if z_target < cam_zoom else 0.7, dt)
	cam_pos.y = CWUtil.damp(cam_pos.y, -2.2 if away else 0.4, 1.0, dt)

	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	var c_dir := Vector3(cos(CAM_ELEV) * sy, sin(CAM_ELEV), cos(CAM_ELEV) * cy)
	var c_right := Vector3(cy, 0.0, -sy)
	var c_up := Vector3(-sin(CAM_ELEV) * sy, cos(CAM_ELEV), -sin(CAM_ELEV) * cy)

	var vh := cam_base / cam_zoom
	var target := cam_pos + c_right * fx.shake_offset.x + c_up * fx.shake_offset.y

	# B1: Full texel snapping + sub-texel offset + world-anchored Bayer dither (90-main.js:9-14)
	var px := vh / maxf(float(sub_vp.size.y), 1.0)
	var u := target.dot(c_right)
	var v := target.dot(c_up)
	var su := roundf(u / px) * px
	var sv := roundf(v / px) * px
	sub_texel = Vector2((u - su) / px, (v - sv) / px)
	dither_ofs = Vector2(fposmod(roundf(su / px), 8.0), fposmod(roundf(sv / px), 8.0))
	target += c_right * (su - u) + c_up * (sv - v)
	cam.size = vh
	cam.look_at_from_position(target + c_dir * CAM_DIST, target, Vector3.UP)


func cam_grab() -> void:
	if not cam_man:
		cam_man = true
		cam_mx = cam_pos.x
		cam_mz = cam_pos.z
		cam_mzoom = cam_zoom


func cam_zoom_min() -> float:
	return minf(1.0, minf(cam_base * cam_aspect / 56.0, cam_base / 46.0))


func cam_zoom_now() -> float:
	if not cam_za.is_empty():
		return float(cam_za["to"])
	return cam_mzoom if cam_man else cam_zoom


func cam_pan(dx: float, dy: float) -> void:
	if game.phase == "crumble" or game.phase == "rise" or game.phase == "clear":
		return
	var win_sz := get_viewport().get_visible_rect().size
	if win_sz.x <= 1.0:
		return
	cam_grab()
	var upp := cam_base * cam_aspect / maxf(cam_mzoom, 0.1) / win_sz.x
	var se := sin(CAM_ELEV)
	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	var du := dx * upp
	var dv := -dy * upp
	cam_mx = clampf(cam_mx - cy * du + sy * dv / se, -17.0, 17.0)
	cam_mz = clampf(cam_mz + sy * du + cy * dv / se, -17.0, 17.0)


func cam_zoom_at(f: float, px: float, py: float) -> void:
	if game.phase == "crumble" or game.phase == "rise" or game.phase == "clear":
		return
	var win_sz := get_viewport().get_visible_rect().size
	if win_sz.x <= 1.0 or win_sz.y <= 1.0:
		return
	cam_grab()
	var z0 := cam_mzoom
	var z1 := clampf(z0 * f, cam_zoom_min(), 3.0)
	var k := 1.0 - z0 / z1
	var upp := cam_base * cam_aspect / maxf(z0, 0.1) / win_sz.x
	var a := (px - win_sz.x * 0.5) * upp * k
	var b := -(py - win_sz.y * 0.5) * upp * k / sin(CAM_ELEV)
	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	cam_mx = clampf(cam_mx + cy * a - sy * b, -17.0, 17.0)
	cam_mz = clampf(cam_mz - sy * a - cy * b, -17.0, 17.0)
	cam_mzoom = z1


func cam_zoom_to(z: float, px: float = -1.0, py: float = -1.0, rate: float = 9.0) -> void:
	var win_sz := get_viewport().get_visible_rect().size
	var tx := win_sz.x * 0.5 if px < 0.0 else px
	var ty := win_sz.y * 0.5 if py < 0.0 else py
	cam_za = {"to": clampf(z, cam_zoom_min(), 3.0), "px": tx, "py": ty, "rate": rate}


func cam_zoom_by(f: float) -> void:
	cam_zoom_to(cam_zoom_now() * f)


func cam_reset() -> void:
	cam_man = false
	cam_za.clear()


func toggle_pause() -> void:
	game.paused = not game.paused
	audio.play_sfx("ui_click", 0.6)


func cycle_speed() -> void:
	game.speed = (game.speed % 3) + 1
	if game.paused:
		game.paused = false
	audio.play_sfx("ui_click", 0.6)


func _poll_pan_keys(dt: float) -> void:
	CWInputHandler.poll_pan_keys(self, dt)


func _unhandled_input(event: InputEvent) -> void:
	CWInputHandler.handle_input(self, event)


func _pick_pad(screen_pos: Vector2):
	return CWInputHandler.pick_pad(self, screen_pos)


func _notification(what: int) -> void:
	if audio == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		audio.set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		audio.set_paused(false)
