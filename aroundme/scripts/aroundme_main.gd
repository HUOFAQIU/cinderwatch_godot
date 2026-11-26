class_name AroundMeMain
extends Node

# Self-contained Morning Forest Clearing survival mode under res://aroundme/
# Full Cinderwatch half-res texel-snapped pixel-art pipeline with locked centered camera.

const CAM_YAW := PI * 0.25
const CAM_ELEV := deg_to_rad(38.0)
const CAM_DIST := 78.0
const BASE_VIEW_H := 25.0
const MAX_IH := 620
const MAX_PIX := 690000.0
const MAX_WX := 320

@onready var sub_vp: SubViewport = %SubViewport
@onready var world: Node3D = %World
@onready var world_env: WorldEnvironment = %WorldEnvironment
@onready var cam: Camera3D = %Camera3D
@onready var post_rect: TextureRect = %PostProcessRect
@onready var meadow_map: Node3D = %MeadowMap
@onready var game: AroundMeGame = %AroundMeGame
@onready var ui: AroundMeUI = %AroundMeUI

var post_mat: ShaderMaterial
var ao_mat: ShaderMaterial
var mist_mat: ShaderMaterial
var dof_mat: ShaderMaterial
var dof_mesh: MeshInstance3D
var wx_mat: ShaderMaterial
var mat_world: ShaderMaterial
var mat_unit: ShaderMaterial
var tex_albedo: Texture2DArray
var tex_height: Texture2DArray

var grass_mat: ShaderMaterial
var _grass_chars: Array[Vector4] = []

var cam_base: float = BASE_VIEW_H
var cam_aspect: float = 1.7778
var sub_texel := Vector2.ZERO
var dither_ofs := Vector2.ZERO
var screen_fade: float = 0.0
var paused: bool = false
var dof_enabled: bool = true
var sim_speed: int = 1
var _time: float = 0.0


func _ready() -> void:
	_init_shared_materials()
	_apply_world_material(meadow_map)
	_setup_viewport_and_post()
	_setup_weather()
	_setup_grass_carpet()
	game.init_game(mat_unit)
	ui.init_ui(self, game, cam, sub_vp)
	_on_window_resize()
	get_viewport().size_changed.connect(_on_window_resize)
	print("[AroundMe] Morning Forest Clearing initialized.")


func _load_layer_img(path: String) -> Image:
	var res := load(path)
	var img: Image = null
	if res is Texture2D:
		img = (res as Texture2D).get_image()
	elif res is Image:
		img = res as Image
	if img == null:
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 1.0))
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return img


func _init_shared_materials() -> void:
	var layer_names := [
		"00_dirt", "01_rock", "02_mason", "03_wood", "04_cobble",
		"05_metal", "06_slate", "07_cloth", "08_plain", "09_bark", "10_leaf",
	]
	var imgs_a: Array[Image] = []
	var imgs_h: Array[Image] = []
	for nm in layer_names:
		imgs_a.append(_load_layer_img("res://aroundme/assets/textures/albedo_%s.png" % nm))
		imgs_h.append(_load_layer_img("res://aroundme/assets/textures/height_%s.png" % nm))
	tex_albedo = Texture2DArray.new()
	tex_albedo.create_from_images(imgs_a)
	tex_height = Texture2DArray.new()
	tex_height.create_from_images(imgs_h)

	mat_world = ShaderMaterial.new()
	mat_world.shader = load("res://aroundme/shaders/lit_world.gdshader")
	mat_world.set_shader_parameter("u_tex_a", tex_albedo)
	mat_world.set_shader_parameter("u_tex_h", tex_height)
	mat_world.set_shader_parameter("u_bump", 0.055)
	mat_world.set_shader_parameter("u_wind", 1.1)
	mat_world.set_shader_parameter("u_is_instanced", false)
	mat_world.set_shader_parameter("u_cover", Vector4(0.42, 0.66, 0.88, 0.60))
	mat_world.set_shader_parameter("u_cover_col", Vector3(0.24, 0.42, 0.16))
	mat_world.set_shader_parameter("u_cover_p", Vector4(0.92, 0.35, 0.35, 0.0))

	mat_unit = ShaderMaterial.new()
	mat_unit.shader = load("res://aroundme/shaders/lit_unit.gdshader")
	mat_unit.set_shader_parameter("u_tex_a", tex_albedo)


func _apply_world_material(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override == null:
			mi.material_override = mat_world
	for c in n.get_children():
		_apply_world_material(c)


func _setup_viewport_and_post() -> void:
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	post_rect.texture = sub_vp.get_texture()
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://aroundme/shaders/post_process.gdshader")
	post_rect.material = post_mat

	var mq := QuadMesh.new()
	mq.size = Vector2(2.0, 2.0)

	var ao_sh := load("res://aroundme/shaders/atmo_ao.gdshader") as Shader
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

	var mist_sh := load("res://aroundme/shaders/atmo_mist.gdshader") as Shader
	if mist_sh != null:
		var mist_mesh := MeshInstance3D.new()
		mist_mesh.mesh = mq
		mist_mesh.extra_cull_margin = 16384.0
		mist_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist_mat = ShaderMaterial.new()
		mist_mat.shader = mist_sh
		mist_mat.render_priority = 126
		mist_mat.set_shader_parameter("u_mist_amb", Vector3(0.52, 0.58, 0.46))
		mist_mat.set_shader_parameter("u_mist", Vector4(-0.25, 0.45, 0.72, 0.065))
		mist_mat.set_shader_parameter("u_light_count", 0)
		mist_mesh.material_override = mist_mat
		cam.add_child(mist_mesh)

	var dof_sh := load("res://aroundme/shaders/atmo_dof.gdshader") as Shader
	if dof_sh != null:
		dof_mesh = MeshInstance3D.new()
		dof_mesh.mesh = mq
		dof_mesh.extra_cull_margin = 16384.0
		dof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dof_mat = ShaderMaterial.new()
		dof_mat.shader = dof_sh
		dof_mat.render_priority = -20
		dof_mesh.material_override = dof_mat
		cam.add_child(dof_mesh)


func _setup_weather() -> void:
	var wx_sh := load("res://aroundme/shaders/weather.gdshader") as Shader
	if wx_sh == null:
		return
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = qm
	mm.instance_count = MAX_WX
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for wi in range(MAX_WX):
		mm.set_instance_transform(wi, Transform3D.IDENTITY)
		mm.set_instance_custom_data(wi, Color(rng.randf(), rng.randf(), rng.randf(), (float(wi) + 0.5) / float(MAX_WX)))

	wx_mat = ShaderMaterial.new()
	wx_mat.shader = wx_sh
	wx_mat.set_shader_parameter("u_amb", Vector3(0.68, 0.78, 0.64))
	wx_mat.set_shader_parameter("u_n", Vector2(0.40, 0.18))
	wx_mat.set_shader_parameter("u_vel_a", Vector3(0.30, -0.14, 0.16))
	wx_mat.set_shader_parameter("u_vel_b", Vector3(0.24, -0.22, 0.18))
	wx_mat.set_shader_parameter("u_sway_a", Vector2(0.65, 0.75))
	wx_mat.set_shader_parameter("u_sway_b", Vector2(0.95, 1.15))
	wx_mat.set_shader_parameter("u_size_a", Vector2(0.028, 0.052))
	wx_mat.set_shader_parameter("u_size_b", Vector2(0.042, 0.072))
	wx_mat.set_shader_parameter("u_col_a", Vector4(0.96, 0.96, 0.80, 1.0))
	wx_mat.set_shader_parameter("u_col_b", Vector4(0.75, 0.92, 0.48, 0.0))
	wx_mat.set_shader_parameter("u_al_a", Vector3(0.65, 0.0, 0.0))
	wx_mat.set_shader_parameter("u_al_b", Vector3(1.0, 2.2, 0.3))
	wx_mat.set_shader_parameter("u_ya", Vector2(-1.5, 11.0))
	wx_mat.set_shader_parameter("u_yb", Vector2(-0.5, 6.5))
	wx_mat.set_shader_parameter("u_light_count", 0)
	wx_mat.set_shader_parameter("u_focus_dist", CAM_DIST)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wx_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	world.add_child(mmi)

func _make_seamless_noise(seed_val: int, freq: float, tex_sz: int = 128) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = seed_val
	fn.frequency = freq
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var nt := NoiseTexture2D.new()
	nt.width = tex_sz
	nt.height = tex_sz
	nt.seamless = true
	nt.noise = fn
	return nt


func _setup_grass_carpet() -> void:
	var g_sh := load("res://aroundme/shaders/dusk_grass.gdshader") as Shader
	if g_sh == null:
		return

	_grass_chars.resize(64)
	for ci in range(64):
		_grass_chars[ci] = Vector4(0.0, -999.0, 0.0, 0.1)

	grass_mat = ShaderMaterial.new()
	grass_mat.shader = g_sh
	if ResourceLoader.exists("res://aroundme/assets/textures/grassleaf.png"):
		var gtex := load("res://aroundme/assets/textures/grassleaf.png")
		grass_mat.set_shader_parameter("albedo_texture", gtex)
		grass_mat.set_shader_parameter("accent_texture1", gtex)
	if ResourceLoader.exists("res://aroundme/assets/textures/accentleaf.png"):
		grass_mat.set_shader_parameter("accent_texture2", load("res://aroundme/assets/textures/accentleaf.png"))

	grass_mat.set_shader_parameter("albedo2_noise", _make_seamless_noise(101, 0.018, 128))
	grass_mat.set_shader_parameter("albedo3_noise", _make_seamless_noise(202, 0.015, 128))
	grass_mat.set_shader_parameter("wind_noise", _make_seamless_noise(303, 0.024, 128))

	# Build fine, ultra-dense MultiMesh grass carpet culled to the rotated isometric camera frustum
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var spacing := 0.135
	var half := 33.0
	var inv_s2 := 0.70710678
	var buf := PackedFloat32Array()
	var cnt := 0
	var gx := -half
	while gx <= half:
		var gz := -half
		while gz <= half:
			var x := gx + rng.randf_range(-0.065, 0.065)
			var z := gz + rng.randf_range(-0.065, 0.065)
			# Frustum-cull to visible isometric diamond so off-screen corners cost 0 GPU
			var u := absf((x - z) * inv_s2)
			var v := absf((x + z) * inv_s2)
			if u <= 25.0 and v <= 23.5:
				var r := sqrt(x * x + z * z)
				var ang := atan2(z, x)
				var dr := 2.0 + 0.45 * sin(ang * 2.0 + 0.7) + 0.30 * cos(ang * 3.0 - 0.9) + 0.18 * sin(ang * 5.0 + 1.4)
				var edge_f := clampf((r - (dr - 0.25)) / 1.15, 0.0, 1.0)
				if edge_f > 0.0 and (edge_f >= 1.0 or rng.randf() < edge_f * edge_f):
					var y := game.height_at(x, z)
					var sc_x := rng.randf_range(0.85, 1.15) * lerpf(0.72, 1.0, edge_f)
					var sc_y := rng.randf_range(0.80, 1.15) * lerpf(0.65, 1.0, edge_f)
					var off := cnt * 12
					if buf.size() < off + 12:
						buf.resize(maxi(buf.size() * 2, 120000))
					buf[off] = sc_x; buf[off + 1] = 0.0; buf[off + 2] = 0.0; buf[off + 3] = x
					buf[off + 4] = 0.0; buf[off + 5] = sc_y; buf[off + 6] = 0.0; buf[off + 7] = y
					buf[off + 8] = 0.0; buf[off + 9] = 0.0; buf[off + 10] = 1.0; buf[off + 11] = z
					cnt += 1
			gz += spacing
		gx += spacing

	buf.resize(cnt * 12)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.48, 0.36)
	qm.center_offset = Vector3(0.0, 0.13, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = cnt
	if cnt > 0:
		mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ForestGrassCarpet"
	mmi.multimesh = mm
	mmi.material_override = grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	world.add_child(mmi)


func _update_grass_trampling() -> void:
	if grass_mat == null:
		return
	var idx := 0
	if not game.soldier_dead:
		_grass_chars[0] = Vector4(game.soldier_pos.x, game.soldier_pos.y, game.soldier_pos.z, 1.35)
		idx = 1
	var mons := game.mons
	var n := mons.size()
	var step := maxi(1, n / 63)
	var i := 0
	while i < n and idx < 64:
		var m := mons[i]
		var mx := float(m["x"])
		var mz := float(m["z"])
		if mx * mx + mz * mz < 24.5 * 24.5:
			_grass_chars[idx] = Vector4(mx, float(m["y"]), mz, 0.95 * float(m["def"]["scale"]))
			idx += 1
		i += step
	grass_mat.set_shader_parameter("character_positions", _grass_chars)
	grass_mat.set_shader_parameter("character_active_count", idx)



func _on_window_resize() -> void:
	var win_sz := get_viewport().get_visible_rect().size
	var dw := maxf(win_sz.x, 2.0)
	var dh := maxf(win_sz.y, 2.0)
	var texel := maxf(2.0, maxf(sqrt(dw * dh / MAX_PIX), minf(dw, dh) / float(MAX_IH)))
	var ih := maxi(int(roundf(dh / texel)), mini(int(dh), 240))
	var iw := maxi(int(roundf(float(ih) * (dw / dh))), 320)
	if iw > 1500:
		ih = maxi(240, int(roundf(float(ih) * 1500.0 / float(iw))))
		iw = 1500
	sub_vp.size = Vector2i(iw, ih)
	post_mat.set_shader_parameter("u_tex_size", Vector2(iw, ih))
	post_mat.set_shader_parameter("u_out_size", Vector2(dw, dh))
	if ao_mat != null:
		ao_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))
	if dof_mat != null and dof_enabled:
		dof_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))


func _process(delta: float) -> void:
	var rdt := minf(delta, 0.05)
	_time += rdt

	if not paused:
		for _s in range(sim_speed):
			game.step_sim(rdt)

	_update_grass_trampling()
	_update_camera()

	screen_fade = minf(1.0, screen_fade + rdt * 1.45)
	post_mat.set_shader_parameter("u_sub", sub_texel)
	post_mat.set_shader_parameter("u_dither_ofs", dither_ofs)
	post_mat.set_shader_parameter("u_grade", Vector4(0.96, 0.90, 0.34, screen_fade))
	post_mat.set_shader_parameter("u_lift", Vector3(0.022, 0.024, 0.018))

	if ao_mat != null:
		var px_w := cam.size / maxf(float(sub_vp.size.y), 1.0)
		var ao_rad := clampf(0.85 / maxf(px_w, 0.005), 8.0, 26.0)
		ao_mat.set_shader_parameter("u_ao", Vector3(1.0, ao_rad, 0.7))
		ao_mat.set_shader_parameter("u_dither", dither_ofs)
		ao_mat.set_shader_parameter("u_dof_fade", Vector4(CAM_DIST, 3.6, 12.5, 1.0 if dof_enabled else 0.0))

	if dof_mat != null and dof_enabled:
		var max_r := clampf(minf(float(sub_vp.size.y), float(sub_vp.size.x) * 1.6) * 0.012, 2.0, 7.0)
		dof_mat.set_shader_parameter("u_dof", Vector4(CAM_DIST, 3.6, 12.5, max_r))
		dof_mat.set_shader_parameter("u_near", Vector4(9.0, 16.0, 0.6, 0.25))
		dof_mat.set_shader_parameter("u_dither", dither_ofs)

	ui.update_ui(rdt)
	ui.update_perf_overlay(
		rdt,
		int(Engine.get_frames_per_second()),
		game.mons.size(),
		game.kills,
		game.get_gpu_unit_count(),
		game.perf_sim_ms,
		game.perf_batch_ms,
		sub_vp.size
	)


func _update_camera() -> void:
	var win_sz := get_viewport().get_visible_rect().size
	cam_aspect = maxf(0.5, win_sz.x / maxf(win_sz.y, 1.0))
	cam_base = maxf(BASE_VIEW_H, 42.0 / cam_aspect)

	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	var c_dir := Vector3(cos(CAM_ELEV) * sy, sin(CAM_ELEV), cos(CAM_ELEV) * cy)
	var c_right := Vector3(cy, 0.0, -sy)
	var c_up := Vector3(-sin(CAM_ELEV) * sy, cos(CAM_ELEV), -sin(CAM_ELEV) * cy)

	var vh := cam_base
	var target := Vector3(0.0, 0.25, 0.0) + c_right * game.shake_offset.x + c_up * game.shake_offset.y
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


func toggle_pause() -> void:
	paused = not paused
	game.play_ui_click()


func cycle_speed() -> void:
	sim_speed = (sim_speed % 3) + 1
	paused = false
	game.play_ui_click()


func toggle_mute() -> void:
	game.toggle_mute()


func toggle_dof() -> void:
	dof_enabled = not dof_enabled
	if dof_mesh != null:
		dof_mesh.visible = dof_enabled
	game.play_ui_click()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_P or ke.keycode == KEY_SPACE:
			toggle_pause()
		elif ke.keycode == KEY_TAB:
			cycle_speed()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_R:
			game.reset_run()
			game.play_ui_click()
		elif ke.keycode == KEY_K:
			game.spawn_stress_wave(100)
			game.play_ui_click()
			print("[AroundMe StressTest] Spawned +100 units | total_mons=%d | fps=%d" % [game.mons.size(), int(Engine.get_frames_per_second())])
		elif ke.keycode == KEY_L:
			ui.toggle_perf_overlay()
			game.play_ui_click()
		elif ke.keycode == KEY_M:
			toggle_mute()
