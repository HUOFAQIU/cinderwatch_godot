class_name AroundMeMain
extends Node

# Self-contained Dusk Meadow survival mode under res://aroundme/
# Full Cinderwatch half-res texel-snapped pixel-art pipeline with locked centered camera.

const CAM_YAW := PI * 0.25
const CAM_ELEV := deg_to_rad(38.0)
const CAM_DIST := 78.0
const BASE_VIEW_H := 25.0
const MAX_IH := 620
const MAX_PIX := 690000.0
const MAX_WX := 320

const BRAZIER_POSITIONS: Array[Vector3] = [
	Vector3(-5.2, 0.0, -4.6),
	Vector3(5.4, 0.0, -4.4),
	Vector3(-4.8, 0.0, 5.2),
	Vector3(5.0, 0.0, 4.8),
]

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

var brazier_lights: Array[OmniLight3D] = []
var brazier_halo_mats: Array[ShaderMaterial] = []

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
	_setup_braziers()
	_setup_weather()
	game.init_game(mat_unit, mat_world, meadow_map)
	ui.init_ui(self, game, cam, sub_vp)
	_on_window_resize()
	get_viewport().size_changed.connect(_on_window_resize)
	print("[AroundMe] Dusk Meadow initialized.")


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
	mat_world.set_shader_parameter("u_cover", Vector4(0.28, 0.72, 0.90, 0.55))
	mat_world.set_shader_parameter("u_cover_col", Vector3(0.22, 0.30, 0.14))
	mat_world.set_shader_parameter("u_cover_p", Vector4(0.92, 0.35, 0.35, 0.0))

	mat_unit = ShaderMaterial.new()
	mat_unit.shader = load("res://aroundme/shaders/lit_unit.gdshader")
	mat_unit.set_shader_parameter("u_tex_a", tex_albedo)
	mat_unit.set_shader_parameter("u_tex_h", tex_height)
	mat_unit.set_shader_parameter("u_bump", 0.04)


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
		mist_mat.set_shader_parameter("u_mist_amb", Vector3(0.16, 0.09, 0.12))
		mist_mat.set_shader_parameter("u_mist", Vector4(-0.35, 0.52, 0.85, 0.09))
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


func _setup_braziers() -> void:
	var flame_sh := load("res://aroundme/shaders/flame.gdshader") as Shader

	# Shared GPU rising-ember particle resources (mirrors fx.tscn BeaconEmbersGPU)
	var ember_mat := StandardMaterial3D.new()
	ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ember_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.vertex_color_use_as_albedo = true
	ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mat.billboard_keep_scale = true
	if ResourceLoader.exists("res://aroundme/assets/textures/particle_soft.png"):
		ember_mat.albedo_texture = load("res://aroundme/assets/textures/particle_soft.png")

	var ember_proc := ParticleProcessMaterial.new()
	ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_proc.emission_box_extents = Vector3(0.24, 0.12, 0.24)
	ember_proc.direction = Vector3(0.22, 1.0, 0.12)
	ember_proc.spread = 28.0
	ember_proc.initial_velocity_min = 0.75
	ember_proc.initial_velocity_max = 1.8
	ember_proc.gravity = Vector3(0.32, 0.35, 0.14)
	ember_proc.damping_min = 0.25
	ember_proc.damping_max = 0.55
	ember_proc.scale_min = 0.06
	ember_proc.scale_max = 0.12
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(2.6, 1.55, 0.45, 0.0),
		Color(2.4, 1.15, 0.28, 0.95),
		Color(1.6, 0.48, 0.12, 0.65),
		Color(0.8, 0.18, 0.05, 0.0),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	ember_proc.color_ramp = grad_tex
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2.ONE

	for i in range(BRAZIER_POSITIONS.size()):
		var bp := BRAZIER_POSITIONS[i]
		var gy := game.height_at(bp.x, bp.z)
		var fpos := Vector3(bp.x, gy + 1.05, bp.z)

		var ol := OmniLight3D.new()
		ol.position = fpos + Vector3(0.0, 0.85, 0.0)
		ol.light_color = Color(1.0, 0.60, 0.22, 1.0)
		ol.light_energy = 4.6
		ol.omni_range = 15.0
		ol.omni_attenuation = 1.6
		
		#ol.shadow_enabled = false
		ol.shadow_enabled = true
		ol.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		ol.shadow_bias = 0.25
		ol.shadow_normal_bias = 1.2
		
		world.add_child(ol)
		brazier_lights.append(ol)

		if flame_sh != null:
			# Soft warm brazier halo (render_priority 7, behind flame)
			var hq := QuadMesh.new()
			hq.size = Vector2(6.5, 6.5)
			var hm := MeshInstance3D.new()
			hm.mesh = hq
			hm.position = fpos + Vector3(0.0, 0.18, 0.0)
			hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var hmat := ShaderMaterial.new()
			hmat.shader = flame_sh
			hmat.render_priority = 7
			hmat.set_shader_parameter("u_seed", float(i) * 2.17)
			hmat.set_shader_parameter("u_intensity", 0.30)
			hmat.set_shader_parameter("u_is_halo", 1.0)
			hmat.set_shader_parameter("u_is_instanced", false)
			hmat.set_shader_parameter("u_col", Vector3(1.25, 0.56, 0.16))
			hm.material_override = hmat
			world.add_child(hm)
			brazier_halo_mats.append(hmat)

			# Crisp brazier flame (render_priority 8)
			var qm := QuadMesh.new()
			qm.size = Vector2(0.95, 1.45)
			var fm := MeshInstance3D.new()
			fm.mesh = qm
			fm.position = fpos + Vector3(0.0, 0.28, 0.0)
			fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fmat := ShaderMaterial.new()
			fmat.shader = flame_sh
			fmat.render_priority = 8
			fmat.set_shader_parameter("u_seed", float(i) * 1.93 + 0.4)
			fmat.set_shader_parameter("u_intensity", 1.35)
			fmat.set_shader_parameter("u_is_halo", 0.0)
			fmat.set_shader_parameter("u_is_instanced", false)
			fmat.set_shader_parameter("u_col", Vector3(1.0, 0.56, 0.18))
			fm.material_override = fmat
			world.add_child(fm)

		# Rising GPU ember sparks drifting with dusk breeze
		var gp := GPUParticles3D.new()
		gp.position = fpos + Vector3(0.0, 0.12, 0.0)
		gp.amount = 14
		gp.lifetime = 1.75
		gp.preprocess = 0.6
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.material_override = ember_mat
		gp.process_material = ember_proc
		gp.draw_pass_1 = ember_quad
		world.add_child(gp)


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
	wx_mat.set_shader_parameter("u_amb", Vector3(0.42, 0.28, 0.24))
	wx_mat.set_shader_parameter("u_n", Vector2(0.32, 0.14))
	wx_mat.set_shader_parameter("u_vel_a", Vector3(0.36, -0.18, 0.18))
	wx_mat.set_shader_parameter("u_vel_b", Vector3(0.16, 0.35, 0.12))
	wx_mat.set_shader_parameter("u_sway_a", Vector2(0.55, 0.65))
	wx_mat.set_shader_parameter("u_sway_b", Vector2(0.85, 1.05))
	wx_mat.set_shader_parameter("u_size_a", Vector2(0.032, 0.058))
	wx_mat.set_shader_parameter("u_size_b", Vector2(0.036, 0.062))
	wx_mat.set_shader_parameter("u_col_a", Vector4(0.82, 0.64, 0.42, 1.0))
	wx_mat.set_shader_parameter("u_col_b", Vector4(2.3, 1.25, 0.28, 0.0))
	wx_mat.set_shader_parameter("u_al_a", Vector3(0.65, 0.0, 0.0))
	wx_mat.set_shader_parameter("u_al_b", Vector3(1.0, 2.2, 0.3))
	wx_mat.set_shader_parameter("u_ya", Vector2(-1.5, 11.0))
	wx_mat.set_shader_parameter("u_yb", Vector2(-0.5, 6.5))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wx_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	world.add_child(mmi)


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

	_update_braziers()
	_update_camera()

	screen_fade = minf(1.0, screen_fade + rdt * 1.45)
	post_mat.set_shader_parameter("u_sub", sub_texel)
	post_mat.set_shader_parameter("u_dither_ofs", dither_ofs)
	post_mat.set_shader_parameter("u_grade", Vector4(1.06, 0.98, 0.52, screen_fade))
	post_mat.set_shader_parameter("u_lift", Vector3(0.022, 0.013, 0.022))

	if ao_mat != null:
		var px_w := cam.size / maxf(float(sub_vp.size.y), 1.0)
		var ao_rad := clampf(0.85 / maxf(px_w, 0.005), 8.0, 26.0)
		ao_mat.set_shader_parameter("u_ao", Vector3(1.0, ao_rad, 0.7))
		ao_mat.set_shader_parameter("u_dither", dither_ofs)

	if dof_mat != null and dof_enabled:
		var max_r := clampf(minf(float(sub_vp.size.y), float(sub_vp.size.x) * 1.6) * 0.0145, 2.0, 9.0)
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


func _update_braziers() -> void:
	var m_pos: Array[Vector3] = []
	var m_col: Array[Vector3] = []
	m_pos.resize(16); m_col.resize(16)
	var w_pos: Array[Vector3] = []
	var w_col: Array[Vector3] = []
	w_pos.resize(12); w_col.resize(12)

	var n := brazier_lights.size()
	for i in range(n):
		var flk := 0.88 + 0.12 * sin(_time * 8.3 + float(i) * 2.1) * cos(_time * 13.7 + float(i) * 1.3)
		var e := 6.8 * flk
		brazier_lights[i].light_energy = e
		if i < brazier_halo_mats.size():
			brazier_halo_mats[i].set_shader_parameter("u_intensity", 0.42 * flk)
		var p := brazier_lights[i].global_position
		var c := Vector3(1.0, 0.58, 0.20) * (e * 0.13)
		m_pos[i] = p; m_col[i] = c
		if i < 12:
			w_pos[i] = p; w_col[i] = c

	if mist_mat != null:
		mist_mat.set_shader_parameter("u_light_pos", m_pos)
		mist_mat.set_shader_parameter("u_light_col", m_col)
		mist_mat.set_shader_parameter("u_light_count", n)
	if wx_mat != null:
		wx_mat.set_shader_parameter("u_light_pos", w_pos)
		wx_mat.set_shader_parameter("u_light_col", w_col)
		wx_mat.set_shader_parameter("u_light_count", mini(n, 12))
		wx_mat.set_shader_parameter("u_focus_dist", CAM_DIST)


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
