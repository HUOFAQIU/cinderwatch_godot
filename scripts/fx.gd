class_name CWFx
extends Node3D

# Dynamic light pool (moon, fill, shadow-casting beacon + 3 pooled tower spots + 12 tower omnis + 4 flashes)
# Plus MultiMesh particles, chain lightning segments, and biome weather
# Ported from 40-fx.js and 41-weather.js

var moon_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var beacon_light: OmniLight3D
var beacon_flame_root: Node3D
var beacon_flame_mats: Array[ShaderMaterial] = []
var beacon_halo_mat: ShaderMaterial
var lantern_flames: Array[MeshInstance3D] = []
var spot_pool: Array[Dictionary] = []
var tower_lights: Array[OmniLight3D] = []
var torch_lights: Array[OmniLight3D] = []
var torch_positions: Array[Vector3] = []
var dynamic_flames: Array[Dictionary] = []
var flame_mmi: MultiMeshInstance3D
var flame_mm: MultiMesh
const MAX_FLAMES := 96
var env_lights: Array[OmniLight3D] = []
var env_srcs: Array[Dictionary] = []
var keep_fires: Array[Vector3] = []
const MIST_GAIN_ENV := 2.7
var flash_pool: Array[Dictionary] = []
var emitters: Array[Dictionary] = []

var beacon_pos: Vector3 = Vector3.ZERO
var waterfall_pos: Vector3 = Vector3.ZERO
var has_waterfall: bool = false
var biome_key: String = "ashen"
var look_cur: Dictionary = {}
var look_to: Dictionary = {}
var env_ref: Environment = null
var pond_centers: Array[Vector3] = []
var coins: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var decal_mmi: MultiMeshInstance3D
var decal_mm: MultiMesh
var ring_mmi: MultiMeshInstance3D
var ring_mm: MultiMesh
var beacon_mul: float = 1.0
var beacon_level: float = 1.0
var beacon_on: float = 1.0
var beacon_gutter: float = 0.0
var shake_mag: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

# Particle / Lightning / Weather MultiMeshes
var part_mmi: MultiMeshInstance3D
var part_mm: MultiMesh
var particles: Array[Dictionary] = []

var bolt_mmi: MultiMeshInstance3D
var bolt_mm: MultiMesh
var bolts: Array[Dictionary] = []

var wx_mmi: MultiMeshInstance3D
var wx_mm: MultiMesh
var wx_mat: ShaderMaterial
var wx_fade: float = 1.0

const MAX_PARTS := 900
const MAX_BOLTS := 240
const MAX_WX := 2600


func init_fx() -> void:
	# Moon & Fill directional lights
	moon_light = DirectionalLight3D.new()
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon_light.directional_shadow_max_distance = 72.0
	moon_light.shadow_bias = 0.06
	moon_light.shadow_normal_bias = 0.85
	moon_light.shadow_blur = 0.25
	add_child(moon_light)

	fill_light = DirectionalLight3D.new()
	fill_light.shadow_enabled = false
	add_child(fill_light)

	# Shadow-casting Beacon OmniLight3D
	beacon_light = OmniLight3D.new()
	beacon_light.light_color = Color(1.0, 0.54, 0.22)
	beacon_light.omni_range = 75.0
	beacon_light.omni_attenuation = 1.42
	beacon_light.shadow_enabled = true
	beacon_light.shadow_bias = 0.06
	beacon_light.shadow_normal_bias = 0.75
	beacon_light.shadow_blur = 0.35
	add_child(beacon_light)

	# 3-layer volumetric Great Beacon flame column + warm golden bloom halo (40-fx.js:338-346)
	var fl_sh := load("res://shaders/flame.gdshader") as Shader
	beacon_flame_root = Node3D.new()
	add_child(beacon_flame_root)
	if fl_sh != null:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE
		for k in range(3):
			var kk := float(k) / 3.0
			var fmat := ShaderMaterial.new()
			fmat.shader = fl_sh
			fmat.render_priority = 8
			fmat.set_shader_parameter("u_seed", 1.3 + float(k) * 3.7)
			fmat.set_shader_parameter("u_intensity", 1.15)
			fmat.set_shader_parameter("u_is_halo", 0.0)
			beacon_flame_mats.append(fmat)
			var fmi := MeshInstance3D.new()
			fmi.mesh = qm
			fmi.material_override = fmat
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fw := 3.25 * (1.0 - kk * 0.20)
			var fh := 4.45 * (1.0 - kk * 0.14)
			fmi.scale = Vector3(fw, fh, 1.0)
			fmi.position = Vector3(sin(float(k) * 2.1) * 0.28 if k > 0 else 0.0, fh * 0.43, cos(float(k) * 1.7) * 0.28 if k > 0 else 0.0)
			beacon_flame_root.add_child(fmi)
		beacon_halo_mat = ShaderMaterial.new()
		beacon_halo_mat.shader = fl_sh
		beacon_halo_mat.render_priority = 7
		beacon_halo_mat.set_shader_parameter("u_is_halo", 1.0)
		beacon_halo_mat.set_shader_parameter("u_col", Vector3(1.25, 0.56, 0.16))
		beacon_halo_mat.set_shader_parameter("u_intensity", 0.36)
		var hmi := MeshInstance3D.new()
		hmi.mesh = qm
		hmi.material_override = beacon_halo_mat
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hmi.scale = Vector3(13.5, 13.5, 1.0)
		hmi.position = Vector3(0.0, 1.65, 0.0)
		beacon_flame_root.add_child(hmi)
		# 2 keep gatehouse wall-lantern flame tongues
		for lk in range(2):
			var lmat := ShaderMaterial.new()
			lmat.shader = fl_sh
			lmat.render_priority = 8
			lmat.set_shader_parameter("u_seed", 11.0 + float(lk) * 4.3)
			lmat.set_shader_parameter("u_intensity", 1.05)
			lmat.set_shader_parameter("u_is_halo", 0.0)
			var lmi := MeshInstance3D.new()
			lmi.mesh = qm
			lmi.material_override = lmat
			lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lmi.scale = Vector3(0.42, 0.68, 1.0)
			lmi.visible = false
			add_child(lmi)
			lantern_flames.append(lmi)

	# 3 pooled shadow-casting SpotLight3D assigned to focus-nearest towers
	for _i in range(3):
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.6, 0.28)
		sp.spot_range = 20.0
		sp.spot_angle = 58.0
		sp.shadow_enabled = true
		sp.shadow_normal_bias = 0.45
		sp.shadow_blur = 0.35
		sp.light_energy = 0.0
		add_child(sp)
		spot_pool.append({"light": sp, "owner": null, "fade": 0.0})

	# 12 non-shadow tower OmniLight3D
	for _i in range(12):
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.58, 0.26)
		ol.omni_range = 15.0
		ol.omni_attenuation = 1.8
		ol.shadow_enabled = false
		ol.light_energy = 0.0
		add_child(ol)
		tower_lights.append(ol)

	# 8 moving torch OmniLight3D following footmen & torch-bearing skeletons
	for _i in range(8):
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.65, 0.28)
		tl.omni_range = 7.5
		tl.omni_attenuation = 1.9
		tl.shadow_enabled = false
		tl.light_energy = 0.0
		add_child(tl)
		torch_lights.append(tl)

	# 3 environment OmniLight3D (keep lanterns / bridge / waterfall glow)
	for _i in range(3):
		var el := OmniLight3D.new()
		el.shadow_enabled = false
		el.light_energy = 0.0
		add_child(el)
		env_lights.append(el)

	# 4 flash OmniLight3D for explosions/lightning
	for _i in range(4):
		var fl := OmniLight3D.new()
		fl.omni_range = 18.0
		fl.shadow_enabled = false
		fl.light_energy = 0.0
		add_child(fl)
		flash_pool.append({"light": fl, "t": 1.0, "dur": 1.0, "energy": 0.0})

	_init_particle_meshes()


func _init_particle_meshes() -> void:
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p_mat.billboard_keep_scale = true
	p_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# Soft circular radial-falloff texture so smoke/dust/embers are round clouds instead of sharp squares
	var pimg := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for py in range(16):
		for px in range(16):
			var dx := (float(px) + 0.5) / 8.0 - 1.0
			var dy := (float(py) + 0.5) / 8.0 - 1.0
			var rr := sqrt(dx * dx + dy * dy)
			var w := pow(clampf(1.0 - rr, 0.0, 1.0), 1.7)
			pimg.set_pixel(px, py, Color(1.0, 1.0, 1.0, w))
	p_mat.albedo_texture = ImageTexture.create_from_image(pimg)

	var quad_m := QuadMesh.new()
	quad_m.size = Vector2.ONE
	var box_m := BoxMesh.new()
	box_m.size = Vector3.ONE

	part_mm = MultiMesh.new()
	part_mm.transform_format = MultiMesh.TRANSFORM_3D
	part_mm.use_colors = true
	part_mm.mesh = quad_m
	part_mm.instance_count = MAX_PARTS
	part_mm.visible_instance_count = 0
	part_mmi = MultiMeshInstance3D.new()
	part_mmi.multimesh = part_mm
	part_mmi.material_override = p_mat
	part_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part_mmi)

	# Chain lightning segments
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.vertex_color_use_as_albedo = true
	bolt_mm = MultiMesh.new()
	bolt_mm.transform_format = MultiMesh.TRANSFORM_3D
	bolt_mm.use_colors = true
	bolt_mm.mesh = box_m
	bolt_mm.instance_count = MAX_BOLTS
	bolt_mm.visible_instance_count = 0
	bolt_mmi = MultiMeshInstance3D.new()
	bolt_mmi.multimesh = bolt_mm
	bolt_mmi.material_override = b_mat
	bolt_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt_mmi)

	# 2600-instance GPU dual-layer point-lit weather (exact 41-weather.js port)
	wx_mm = MultiMesh.new()
	wx_mm.transform_format = MultiMesh.TRANSFORM_3D
	wx_mm.use_custom_data = true
	wx_mm.mesh = quad_m
	wx_mm.instance_count = MAX_WX
	var wx_rng := CWUtil.Rng.new(4242)
	for wi in range(MAX_WX):
		wx_mm.set_instance_transform(wi, Transform3D.IDENTITY)
		wx_mm.set_instance_custom_data(wi, Color(wx_rng.next_f(), wx_rng.next_f(), wx_rng.next_f(), (float(wi) + 0.5) / float(MAX_WX)))
	wx_mmi = MultiMeshInstance3D.new()
	wx_mmi.multimesh = wx_mm
	wx_mmi.extra_cull_margin = 16384.0
	var wx_sh := load("res://shaders/weather.gdshader") as Shader
	if wx_sh != null:
		wx_mat = ShaderMaterial.new()
		wx_mat.shader = wx_sh
		wx_mat.render_priority = 4
		wx_mmi.material_override = wx_mat
	else:
		wx_mmi.material_override = p_mat
	wx_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wx_mmi)

	# 96-instance animated dancing billboard flame pool for all tower braziers, torches & handheld fires
	var fl_inst_sh := load("res://shaders/flame.gdshader") as Shader
	if fl_inst_sh != null:
		var fl_mat := ShaderMaterial.new()
		fl_mat.shader = fl_inst_sh
		fl_mat.render_priority = 8
		fl_mat.set_shader_parameter("u_is_instanced", true)
		fl_mat.set_shader_parameter("u_is_halo", 0.0)
		fl_mat.set_shader_parameter("u_col", Vector3(1.0, 0.58, 0.22))
		flame_mm = MultiMesh.new()
		flame_mm.transform_format = MultiMesh.TRANSFORM_3D
		flame_mm.use_custom_data = true
		flame_mm.mesh = quad_m
		flame_mm.instance_count = MAX_FLAMES
		flame_mm.visible_instance_count = 0
		flame_mmi = MultiMeshInstance3D.new()
		flame_mmi.multimesh = flame_mm
		flame_mmi.material_override = fl_mat
		flame_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame_mmi)

	# Ground scorch decals (flat dark quads, no depth write so AO/mist stay clean)
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.vertex_color_use_as_albedo = true
	d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	d_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var dq := QuadMesh.new()
	dq.size = Vector2.ONE
	dq.orientation = PlaneMesh.FACE_Y
	decal_mm = MultiMesh.new()
	decal_mm.transform_format = MultiMesh.TRANSFORM_3D
	decal_mm.use_colors = true
	decal_mm.mesh = dq
	decal_mm.instance_count = 64
	decal_mm.visible_instance_count = 0
	decal_mmi = MultiMeshInstance3D.new()
	decal_mmi.multimesh = decal_mm
	decal_mmi.material_override = d_mat
	decal_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(decal_mmi)

	# Expanding shockwave & build-ping ground rings
	var ring_st := SurfaceTool.new()
	ring_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in range(24):
		var a0 := TAU * float(ri) / 24.0
		var a1 := TAU * float(ri + 1) / 24.0
		var p0 := Vector3(cos(a0) * 0.86, 0.0, sin(a0) * 0.86)
		var p1 := Vector3(cos(a0), 0.0, sin(a0))
		var p2 := Vector3(cos(a1), 0.0, sin(a1))
		var p3 := Vector3(cos(a1) * 0.86, 0.0, sin(a1) * 0.86)
		ring_st.add_vertex(p0); ring_st.add_vertex(p1); ring_st.add_vertex(p2)
		ring_st.add_vertex(p0); ring_st.add_vertex(p2); ring_st.add_vertex(p3)
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.vertex_color_use_as_albedo = true
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	r_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	r_mat.render_priority = 6
	ring_mm = MultiMesh.new()
	ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	ring_mm.use_colors = true
	ring_mm.mesh = ring_st.commit()
	ring_mm.instance_count = 24
	ring_mm.visible_instance_count = 0
	ring_mmi = MultiMeshInstance3D.new()
	ring_mmi.multimesh = ring_mm
	ring_mmi.material_override = r_mat
	ring_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mmi)


func apply_biome(bio: Dictionary, env: Environment, p_beacon_pos: Vector3, is_mirrored: bool = false) -> void:
	beacon_pos = p_beacon_pos
	biome_key = String(bio.get("key", "ashen"))
	beacon_mul = float(bio.get("beacon", 1.0))
	env_ref = env

	var moon_cfg: Array = bio["moon"]
	var mp0: Vector3 = bio["moon_pos"]
	var mpos := Vector3(mp0.z, mp0.y, mp0.x) if is_mirrored else mp0
	moon_light.look_at_from_position(mpos, Vector3.ZERO, Vector3.UP)
	var fill_cfg: Array = bio["fill"]
	fill_light.look_at_from_position(Vector3(30, 14, 34), Vector3.ZERO, Vector3.UP)
	var hemi_cfg: Array = bio["hemi"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = false

	look_to = {
		"moon_c": CWUtil.hex_color(moon_cfg[0]),
		"moon_e": float(moon_cfg[1]) * 0.96,
		"fill_c": CWUtil.hex_color(fill_cfg[0]),
		"fill_e": float(fill_cfg[1]) * 0.45,
		"amb_c": CWUtil.hex_color(hemi_cfg[0]).lerp(CWUtil.hex_color(hemi_cfg[1]), 0.30),
		"amb_e": float(hemi_cfg[2]) * 0.24,
		"clear": bio["clear"],
		"mist_amb": bio.get("mist_amb", Vector3(0.05, 0.08, 0.14)),
		"mist": bio.get("mist", Vector4(-0.3, 0.42, 0.75, 0.10)),
		"lift": bio.get("lift", Vector3(0.01, 0.016, 0.03)),
		"sat": float(bio.get("sat", 0.92)),
		"expo": float(bio.get("expo", 1.0)),
	}
	if look_cur.is_empty():
		look_cur = look_to.duplicate()
		_apply_look_now()

	# Apply dual-layer GPU weather uniforms (41-weather.js:40-45)
	if wx_mat != null and bio.has("wx"):
		var wx: Dictionary = bio["wx"]
		wx_mat.set_shader_parameter("u_n", wx["n"])
		wx_mat.set_shader_parameter("u_vel_a", wx["vel_a"])
		wx_mat.set_shader_parameter("u_vel_b", wx["vel_b"])
		wx_mat.set_shader_parameter("u_sway_a", wx["sway_a"])
		wx_mat.set_shader_parameter("u_sway_b", wx["sway_b"])
		wx_mat.set_shader_parameter("u_size_a", wx["size_a"])
		wx_mat.set_shader_parameter("u_size_b", wx["size_b"])
		wx_mat.set_shader_parameter("u_col_a", wx["col_a"])
		wx_mat.set_shader_parameter("u_col_b", wx["col_b"])
		wx_mat.set_shader_parameter("u_al_a", wx["al_a"])
		wx_mat.set_shader_parameter("u_al_b", wx["al_b"])
		wx_mat.set_shader_parameter("u_ya", wx["ya"])
		wx_mat.set_shader_parameter("u_yb", wx["yb"])
		wx_mat.set_shader_parameter("u_amb", wx["amb"])
		wx_fade = 0.0
		wx_mat.set_shader_parameter("u_fade", 0.0)


func _apply_look_now() -> void:
	if look_cur.is_empty():
		return
	moon_light.light_color = look_cur["moon_c"]
	moon_light.light_energy = float(look_cur["moon_e"])
	fill_light.light_color = look_cur["fill_c"]
	fill_light.light_energy = float(look_cur["fill_e"])
	if env_ref != null:
		env_ref.ambient_light_color = look_cur["amb_c"]
		env_ref.ambient_light_energy = float(look_cur["amb_e"])
		env_ref.background_color = look_cur["clear"]


func update_biome_look(dt: float) -> void:
	if look_cur.is_empty() or look_to.is_empty():
		return
	var k := 1.0 - exp(-dt * 1.6)
	look_cur["moon_c"] = (look_cur["moon_c"] as Color).lerp(look_to["moon_c"], k)
	look_cur["moon_e"] = lerpf(float(look_cur["moon_e"]), float(look_to["moon_e"]), k)
	look_cur["fill_c"] = (look_cur["fill_c"] as Color).lerp(look_to["fill_c"], k)
	look_cur["fill_e"] = lerpf(float(look_cur["fill_e"]), float(look_to["fill_e"]), k)
	look_cur["amb_c"] = (look_cur["amb_c"] as Color).lerp(look_to["amb_c"], k)
	look_cur["amb_e"] = lerpf(float(look_cur["amb_e"]), float(look_to["amb_e"]), k)
	look_cur["clear"] = (look_cur["clear"] as Color).lerp(look_to["clear"], k)
	look_cur["mist_amb"] = (look_cur["mist_amb"] as Vector3).lerp(look_to["mist_amb"], k)
	look_cur["mist"] = (look_cur["mist"] as Vector4).lerp(look_to["mist"], k)
	look_cur["lift"] = (look_cur["lift"] as Vector3).lerp(look_to["lift"], k)
	look_cur["sat"] = lerpf(float(look_cur["sat"]), float(look_to["sat"]), k)
	look_cur["expo"] = lerpf(float(look_cur["expo"]), float(look_to["expo"]), k)
	_apply_look_now()


func add_emitter(pos: Vector3, col: Color, energy: float, rng: float) -> Dictionary:
	var e := {"pos": pos, "col": col, "energy": energy, "range": rng, "alive": true, "seed": randf_range(0.0, 100.0)}
	emitters.append(e)
	return e


func remove_emitter(e: Dictionary) -> void:
	e["alive"] = false
	emitters.erase(e)


func flash(pos: Vector3, col: Color, energy: float, dur: float = 0.25, rng: float = 18.0) -> void:
	var best: Dictionary = flash_pool[0]
	for f in flash_pool:
		if float(f["t"]) >= 1.0:
			best = f
			break
		if float(f["t"]) > float(best["t"]):
			best = f
	var l: OmniLight3D = best["light"]
	l.position = pos
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	best["energy"] = energy
	best["dur"] = maxf(dur, 0.05)
	best["t"] = 0.0


func add_shake(amount: float) -> void:
	shake_mag = minf(1.2, shake_mag + amount)


func spawn_coins(pos: Vector3, count: int) -> void:
	for _i in range(count):
		if coins.size() >= 120:
			break
		coins.append({
			"pos": pos + Vector3(randf_range(-0.25, 0.25), 0.35, randf_range(-0.25, 0.25)),
			"vel": Vector3(randf_range(-2.2, 2.2), randf_range(3.2, 5.6), randf_range(-2.2, 2.2)),
			"life": randf_range(0.85, 1.35),
		})


func get_mist_lights() -> Dictionary:
	var pos_arr: Array[Vector3] = []
	var col_arr: Array[Vector3] = []
	# 1. Beacon
	pos_arr.append(beacon_light.position)
	var bc := beacon_light.light_color
	col_arr.append(Vector3(bc.r, bc.g, bc.b) * beacon_light.light_energy * 0.10)
	# 2. Brightest active flash
	for f in flash_pool:
		var fl: OmniLight3D = f["light"]
		if fl.light_energy > 0.2:
			pos_arr.append(fl.position)
			var fc := fl.light_color
			col_arr.append(Vector3(fc.r, fc.g, fc.b) * fl.light_energy)
			break
	# 3. Up to 3 environment lights (keep lanterns / bridge / waterfall)
	for el in env_lights:
		if el.light_energy > 0.05 and pos_arr.size() < 12:
			pos_arr.append(el.position)
			var ec := el.light_color
			col_arr.append(Vector3(ec.r, ec.g, ec.b) * el.light_energy * MIST_GAIN_ENV)
	# 4. Remaining slots up to 12 for towers
	for e in emitters:
		if pos_arr.size() >= 12:
			break
		if bool(e["alive"]):
			pos_arr.append(e["pos"])
			var tc: Color = e["col"]
			col_arr.append(Vector3(tc.r, tc.g, tc.b) * float(e["energy"]))
	var cnt := pos_arr.size()
	while pos_arr.size() < 16:
		pos_arr.append(Vector3.ZERO)
		col_arr.append(Vector3.ZERO)
	return {"pos": pos_arr, "col": col_arr, "count": cnt}


func spawn_dust(pos: Vector3, count: int, spd: float = 2.0, life: float = 1.4, size: float = 0.45) -> void:
	for _i in range(count):
		if particles.size() >= MAX_PARTS:
			break
		particles.append({
			"pos": pos + Vector3(randf_range(-0.25, 0.25), 0.1, randf_range(-0.25, 0.25)),
			"vel": Vector3(randf_range(-spd, spd), randf_range(0.2, spd * 0.4), randf_range(-spd, spd)),
			"col": Color(0.62, 0.55, 0.46, 0.55),
			"size": randf_range(size * 0.5, size),
			"life": randf_range(life * 0.6, life),
			"max_life": life,
			"grav": 2.0,
			"grow": 0.5,
		})


func spawn_smoke(pos: Vector3, count: int, spd: float = 2.0, up: float = 1.6, life: float = 1.8) -> void:
	for _i in range(count):
		if particles.size() >= MAX_PARTS:
			break
		particles.append({
			"pos": pos + Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2)),
			"vel": Vector3(randf_range(-spd * 0.6, spd * 0.6), randf_range(up * 0.5, up), randf_range(-spd * 0.6, spd * 0.6)),
			"col": Color(0.28, 0.26, 0.24, 0.50),
			"size": randf_range(0.50, 0.85),
			"life": randf_range(life * 0.65, life),
			"max_life": life,
			"grav": -0.6,
			"grow": 1.6,
		})


func spawn_embers(pos: Vector3, count: int, life: float = 1.6) -> void:
	for _i in range(count):
		if particles.size() >= MAX_PARTS:
			break
		particles.append({
			"pos": pos + Vector3(randf_range(-0.5, 0.5), randf_range(-0.1, 0.4), randf_range(-0.5, 0.5)),
			"vel": Vector3(randf_range(-1.2, 1.2), randf_range(1.4, 3.6), randf_range(-1.2, 1.2)),
			"col": Color(2.2, 0.9, 0.3, 0.92),
			"size": randf_range(0.06, 0.14),
			"life": randf_range(life * 0.5, life),
			"max_life": life,
			"grav": -0.4,
			"grow": 0.0,
		})


func spawn_flame_puff(pos: Vector3, sc: float = 0.3) -> void:
	if particles.size() >= MAX_PARTS:
		return
	particles.append({
		"pos": pos + Vector3(randf_range(-0.12, 0.12), 0.04, randf_range(-0.12, 0.12)),
		"vel": Vector3(randf_range(-0.25, 0.25), randf_range(1.1, 2.2), randf_range(-0.25, 0.25)),
		"col": Color(2.4, randf_range(0.85, 1.45), 0.28, 0.95),
		"size": randf_range(0.14, 0.28) * sc / 0.25,
		"life": randf_range(0.22, 0.45),
		"max_life": 0.45,
		"grav": -1.5,
	})


func spawn_sparks(pos: Vector3, count: int, speed: float, col: Color) -> void:
	for _i in range(count):
		if particles.size() >= MAX_PARTS:
			break
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.4), randf_range(-1, 1)).normalized()
		particles.append({
			"pos": pos,
			"vel": dir * randf_range(speed * 0.4, speed),
			"col": col,
			"size": randf_range(0.07, 0.16),
			"life": randf_range(0.25, 0.65),
			"max_life": 0.65,
			"grav": 9.8,
		})


func spawn_decal(pos: Vector3, size: float, col: Color, life: float = 18.0) -> void:
	if decals.size() >= 64:
		decals.pop_front()
	decals.append({"pos": Vector3(pos.x, pos.y + 0.05, pos.z), "size": size, "col": col, "life": life, "max_life": life})


func spawn_ring(pos: Vector3, r_max: float, col: Color, dur: float = 0.45) -> void:
	if rings.size() >= 24:
		rings.pop_front()
	rings.append({"pos": Vector3(pos.x, pos.y + 0.14, pos.z), "r_max": r_max, "col": col, "t": 0.0, "dur": dur})


func spawn_explosion(pos: Vector3, sc: float = 1.0) -> void:
	flash(pos + Vector3(0, 1.0, 0), Color(1.0, 0.65, 0.25), 9.0 * sc, 0.32, 18.0 * sc)
	add_shake(0.35 * sc)
	spawn_decal(pos, 1.4 * sc, Color(0.05, 0.04, 0.04, 0.62), 20.0)
	spawn_ring(pos, 2.2 * sc, Color(1.6, 0.78, 0.25, 0.85), 0.36)
	spawn_sparks(pos + Vector3(0, 0.4, 0), int(18 * sc), 7.5 * sc, Color(1.0, 0.68, 0.22))
	for _i in range(int(10 * sc)):
		if particles.size() >= MAX_PARTS:
			break
		particles.append({
			"pos": pos + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)),
			"vel": Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.2), randf_range(-1.5, 1.5)),
			"col": Color(0.22, 0.2, 0.22, 0.75),
			"size": randf_range(0.35, 0.75) * sc,
			"life": randf_range(0.45, 0.95),
			"max_life": 0.95,
			"grav": -1.2,
		})


func spawn_bolt(a: Vector3, b: Vector3, col: Color = Color(0.55, 0.85, 1.8), life: float = 0.22) -> void:
	var segs := 6
	var pts: Array[Vector3] = [a]
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var p := a.lerp(b, t) + Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.35), randf_range(-0.35, 0.35))
		pts.append(p)
	pts.append(b)
	for i in range(segs):
		if bolts.size() >= MAX_BOLTS:
			break
		bolts.append({"a": pts[i], "b": pts[i + 1], "col": col, "life": life, "max_life": life})


func update_fx(dt: float, t: float, focus: Vector3) -> void:
	# Beacon flicker & ember sparks
	beacon_gutter = maxf(0.0, beacon_gutter - dt * 1.6)
	var flick := 0.86 + 0.10 * CWUtil.n1(t * 6.3, 1.0) + 0.06 * CWUtil.n1(t * 17.0, 2.0)
	var lvl := beacon_level * beacon_on * (1.0 - 0.5 * beacon_gutter)
	beacon_light.position = beacon_pos + Vector3(CWUtil.n1(t * 5.0, 3.0) * 0.12, 1.65 + CWUtil.n1(t * 4.0, 4.0) * 0.10, CWUtil.n1(t * 5.0, 5.0) * 0.12)
	beacon_light.light_energy = 175.0 * beacon_mul * beacon_on * (0.35 + 0.65 * lvl) * flick
	if beacon_flame_root != null:
		beacon_flame_root.position = beacon_pos + Vector3(0.0, 0.05, 0.0)
		var f_sc := clampf(beacon_on * (0.45 + 0.55 * lvl), 0.0, 1.12) * (0.94 + 0.08 * flick)
		beacon_flame_root.visible = f_sc > 0.02
		beacon_flame_root.scale = Vector3(f_sc, f_sc, f_sc)
		for fm in beacon_flame_mats:
			fm.set_shader_parameter("u_intensity", 1.05 * beacon_on * flick)
		if beacon_halo_mat != null:
			beacon_halo_mat.set_shader_parameter("u_intensity", 0.36 * beacon_on * (0.45 + 0.55 * lvl) * flick)
	for li in range(lantern_flames.size()):
		if li < keep_fires.size():
			lantern_flames[li].visible = true
			lantern_flames[li].position = keep_fires[li] + Vector3(0.0, 0.16, 0.0)
		else:
			lantern_flames[li].visible = false
	if beacon_on > 0.2 and randf() < dt * 22.0 * beacon_on:
		spawn_flame_puff(beacon_pos + Vector3(randf_range(-0.35, 0.35), randf_range(0.2, 1.4), randf_range(-0.35, 0.35)), 0.60 * beacon_on)
	if beacon_on > 0.2 and randf() < dt * 5.0 * beacon_on:
		if particles.size() < MAX_PARTS:
			particles.append({
				"pos": beacon_pos + Vector3(randf_range(-0.45, 0.45), randf_range(2.2, 2.8), randf_range(-0.45, 0.45)),
				"vel": Vector3(randf_range(-0.35, 0.35), randf_range(1.0, 1.7), randf_range(-0.35, 0.35)),
				"col": Color(0.95, 0.58, 0.24, 0.34),
				"size": randf_range(0.75, 1.25),
				"life": randf_range(2.2, 3.6),
				"max_life": 3.6,
				"grav": -0.35,
				"grow": 1.6,
			})
	# Biome-accurate waterfall spray (29-biome.js: frost=none, ember=lava embers, others=water mist)
	if has_waterfall and biome_key != "frost" and randf() < dt * 26.0:
		if particles.size() < MAX_PARTS:
			if biome_key == "ember":
				var is_spark := randf() < 0.65
				particles.append({
					"pos": waterfall_pos + Vector3(randf_range(-0.85, 0.85), randf_range(-0.2, 0.5), randf_range(-0.2, 0.3)),
					"vel": Vector3(randf_range(-0.7, 0.7), randf_range(1.0, 2.4), randf_range(0.2, 0.9)),
					"col": Color(2.4, 0.85, 0.16, 0.95) if is_spark else Color(0.24, 0.14, 0.12, 0.42),
					"size": randf_range(0.10, 0.22) if is_spark else randf_range(0.40, 0.72),
					"life": randf_range(0.6, 1.25),
					"max_life": 1.25,
					"grav": -0.6 if is_spark else -0.3,
					"grow": 0.0 if is_spark else 1.2,
				})
			else:
				var mist_c := Color(0.48, 0.68, 0.56, 0.45) if biome_key == "fen" else Color(0.75, 0.85, 0.95, 0.52)
				particles.append({
					"pos": waterfall_pos + Vector3(randf_range(-0.85, 0.85), randf_range(-0.2, 0.4), randf_range(-0.2, 0.3)),
					"vel": Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.5), randf_range(0.2, 0.9)),
					"col": mist_c,
					"size": randf_range(0.28, 0.52),
					"life": randf_range(0.45, 0.85),
					"max_life": 0.85,
					"grav": 0.5,
				})
	# Biome pond ambient FX (Emberscar lava pool embers; Mirefen marsh wisps)
	if not pond_centers.is_empty() and beacon_on > 0.2 and particles.size() < MAX_PARTS:
		if biome_key == "ember" and randf() < dt * 10.0:
			var pc: Vector3 = pond_centers[randi() % pond_centers.size()]
			particles.append({
				"pos": pc + Vector3(randf_range(-1.2, 1.2), 0.12, randf_range(-1.2, 1.2)),
				"vel": Vector3(randf_range(-0.3, 0.3), randf_range(0.8, 1.9), randf_range(-0.3, 0.3)),
				"col": Color(2.5, 0.82, 0.14, 0.92),
				"size": randf_range(0.08, 0.16),
				"life": randf_range(0.9, 1.8),
				"max_life": 1.8,
				"grav": -0.35,
			})
		elif biome_key == "fen" and randf() < dt * 5.0:
			var pc: Vector3 = pond_centers[randi() % pond_centers.size()]
			particles.append({
				"pos": pc + Vector3(randf_range(-1.3, 1.3), 0.18, randf_range(-1.3, 1.3)),
				"vel": Vector3(randf_range(-0.2, 0.2), randf_range(0.25, 0.55), randf_range(-0.2, 0.2)),
				"col": Color(0.28, 0.62, 0.42, 0.26),
				"size": randf_range(0.45, 0.85),
				"life": randf_range(1.6, 2.8),
				"max_life": 2.8,
				"grav": -0.05,
				"grow": 0.9,
			})
	if randf() < dt * 10.0:
		spawn_sparks(beacon_pos + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3)), 1, 2.2, Color(1.0, 0.58, 0.18))

	# Flashes
	for f in flash_pool:
		var l: OmniLight3D = f["light"]
		if float(f["t"]) < 1.0:
			f["t"] = float(f["t"]) + dt / float(f["dur"])
			var k := maxf(0.0, 1.0 - float(f["t"]))
			l.light_energy = float(f["energy"]) * k * k
		else:
			l.light_energy = 0.0

	# Tower OmniLights + 3 focus-nearest shadow SpotLights
	var active: Array[Dictionary] = []
	for e in emitters:
		if e["alive"]:
			active.append(e)
	active.sort_custom(func(a, b): return a["pos"].distance_squared_to(focus) < b["pos"].distance_squared_to(focus))

	for i in range(tower_lights.size()):
		var ol := tower_lights[i]
		if i < active.size():
			var e := active[i]
			var fl := 0.88 + 0.12 * CWUtil.n1(t * 7.5 + float(e["seed"]), float(e["seed"]))
			ol.position = e["pos"]
			ol.light_color = e["col"]
			ol.omni_range = float(e["range"]) * 0.95
			# Match 40-fx.js:76: reduce omni by 68% when covered by a shadow spotlight so they never double-blowout
			var spot_dim := 0.42 if i < spot_pool.size() else 1.0
			ol.light_energy = float(e["energy"]) * 0.68 * fl * spot_dim
		else:
			ol.light_energy = 0.0

	for i in range(spot_pool.size()):
		var s: Dictionary = spot_pool[i]
		var sp: SpotLight3D = s["light"]
		if i < active.size():
			var e := active[i]
			sp.position = e["pos"] + Vector3(0, 0.35, 0)
			sp.look_at(e["pos"] + Vector3(0.2, -3.5, 0.2), Vector3.UP)
			sp.light_color = e["col"]
			sp.light_energy = float(e["energy"]) * 0.72
		else:
			sp.light_energy = 0.0

	# Moving handheld torch lights (5 closest to focus; offset slightly above tip so holder's white bones don't blow out)
	if not torch_positions.is_empty():
		torch_positions.sort_custom(func(a, b): return a.distance_squared_to(focus) < b.distance_squared_to(focus))
	for i in range(torch_lights.size()):
		var tl := torch_lights[i]
		if i < torch_positions.size():
			tl.position = torch_positions[i] + Vector3(0.0, 0.36, 0.0)
			tl.omni_range = 8.2
			tl.omni_attenuation = 1.15
			tl.light_energy = 3.15 * (0.86 + 0.14 * CWUtil.n1(t * 11.0 + float(i) * 3.1, float(i)))
		else:
			tl.light_energy = 0.0

	# Environment lights & keep wall lantern flames
	for i in range(env_lights.size()):
		var el := env_lights[i]
		if i < env_srcs.size():
			var src := env_srcs[i]
			el.position = src["pos"]
			el.light_color = src["col"]
			el.omni_range = float(src["range"])
			var flk := (0.82 + 0.18 * CWUtil.n1(t * 1.7 + float(i) * 5.0, float(i) + 11.0)) if bool(src.get("flick", false)) else 1.0
			el.light_energy = float(src["energy"]) * flk * beacon_on
		else:
			el.light_energy = 0.0
	if beacon_on > 0.3:
		for kf in keep_fires:
			if randf() < dt * 6.0:
				spawn_flame_puff(kf, 0.18)

	# A5: Smooth squared noise camera shake (40-fx.js:385-386)
	shake_mag = maxf(0.0, shake_mag - dt * 2.6)
	var sh := shake_mag * shake_mag * 0.22
	shake_offset = Vector2(CWUtil.n1(t * 31.0, 7.0), CWUtil.n1(t * 37.0, 9.0)) * sh if sh > 1e-5 else Vector2.ZERO

	# Update particles
	var pi := particles.size() - 1
	while pi >= 0:
		var p: Dictionary = particles[pi]
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			particles.remove_at(pi)
		else:
			var vel: Vector3 = p["vel"]
			vel.y -= float(p["grav"]) * dt
			p["vel"] = vel
			p["pos"] = Vector3(p["pos"]) + vel * dt
		pi -= 1

	var p_vis := mini(particles.size(), MAX_PARTS)
	for i in range(p_vis):
		var p := particles[i]
		var a := clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var sz := float(p["size"]) * (0.4 + 0.6 * a) * (1.0 + float(p.get("grow", 0.0)) * (1.0 - a))
		part_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sz), p["pos"]))
		var c: Color = p["col"]
		part_mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * a))
	var ci := coins.size() - 1
	while ci >= 0:
		var c: Dictionary = coins[ci]
		c["life"] = float(c["life"]) - dt
		if float(c["life"]) <= 0.0:
			coins.remove_at(ci)
		else:
			var cv: Vector3 = c["vel"]
			cv.y -= 14.0 * dt
			var cp: Vector3 = Vector3(c["pos"]) + cv * dt
			if cp.y < 0.12:
				cp.y = 0.12
				cv.y = absf(cv.y) * 0.45
			c["vel"] = cv
			c["pos"] = cp
			if p_vis < MAX_PARTS:
				part_mm.set_instance_transform(p_vis, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.18), cp))
				part_mm.set_instance_color(p_vis, Color(1.6, 1.25, 0.25, clampf(float(c["life"]) * 2.0, 0.0, 1.0)))
				p_vis += 1
		ci -= 1
	part_mm.visible_instance_count = p_vis

	# Update lightning bolts
	var bi := bolts.size() - 1
	while bi >= 0:
		bolts[bi]["life"] = float(bolts[bi]["life"]) - dt
		if float(bolts[bi]["life"]) <= 0.0:
			bolts.remove_at(bi)
		bi -= 1
	var b_vis := mini(bolts.size(), MAX_BOLTS)
	for i in range(b_vis):
		var b := bolts[i]
		var pa: Vector3 = b["a"]
		var pb: Vector3 = b["b"]
		var mid := (pa + pb) * 0.5
		var d := pb - pa
		var length := maxf(d.length(), 0.01)
		var dn := d.normalized()
		var up_v := Vector3.FORWARD if absf(dn.y) > 0.98 else Vector3.UP
		var b_basis := Basis.looking_at(dn, up_v)
		var w := 0.09 * clampf(float(b["life"]) / float(b["max_life"]), 0.2, 1.0)
		bolt_mm.set_instance_transform(i, Transform3D(b_basis.scaled_local(Vector3(w, w, length)), mid))
		bolt_mm.set_instance_color(i, b["col"])
	bolt_mm.visible_instance_count = b_vis

	# Render all animated flickering flames (tower torches/braziers, roadside torches, handheld torches)
	if flame_mm != null:
		var f_idx := 0
		# 1) Tower braziers, guardhouse torches, bombard lanterns
		for df in dynamic_flames:
			if f_idx >= MAX_FLAMES:
				break
			var fp: Vector3 = df["pos"]
			var fw: float = float(df["w"])
			var fh: float = float(df["h"])
			var fseed: float = float(df["seed"])
			var flk := 0.88 + 0.16 * CWUtil.n1(t * 9.5 + fseed * 3.1, fseed)
			var f_int := float(df.get("intensity", 0.95)) * 0.88 * flk * beacon_on
			flame_mm.set_instance_transform(f_idx, Transform3D(Basis.IDENTITY.scaled(Vector3(fw, fh * flk, 1.0)), fp + Vector3(0.0, fh * 0.38, 0.0)))
			flame_mm.set_instance_custom_data(f_idx, Color(fseed, f_int, 0.0, 1.0))
			f_idx += 1
		# 2) Handheld torches carried by footmen, torch skeletons & sappers
		for ti in range(torch_positions.size()):
			if f_idx >= MAX_FLAMES:
				break
			var tp: Vector3 = torch_positions[ti]
			var tseed := 17.0 + float(ti) * 2.7
			var tflk := 0.86 + 0.18 * CWUtil.n1(t * 11.0 + tseed * 2.3, tseed)
			flame_mm.set_instance_transform(f_idx, Transform3D(Basis.IDENTITY.scaled(Vector3(0.42, 0.62 * tflk, 1.0)), tp + Vector3(0.0, 0.18, 0.0)))
			flame_mm.set_instance_custom_data(f_idx, Color(tseed, 1.12 * tflk * beacon_on, 0.0, 1.0))
			f_idx += 1
		# 3) Roadside wooden torches (keep_fires beyond first 2 wall lanterns)
		for ki in range(2, keep_fires.size()):
			if f_idx >= MAX_FLAMES:
				break
			var kp: Vector3 = keep_fires[ki]
			var kseed := 31.0 + float(ki) * 3.3
			var kflk := 0.88 + 0.16 * CWUtil.n1(t * 9.0 + kseed * 1.9, kseed)
			flame_mm.set_instance_transform(f_idx, Transform3D(Basis.IDENTITY.scaled(Vector3(0.36, 0.58 * kflk, 1.0)), kp + Vector3(0.0, 0.20, 0.0)))
			flame_mm.set_instance_custom_data(f_idx, Color(kseed, 0.94 * kflk * beacon_on, 0.0, 1.0))
			f_idx += 1
		flame_mm.visible_instance_count = f_idx

	# Update GPU weather fade & point-light illumination
	if wx_mat != null:
		var want_wx := 1.0 if (beacon_on > 0.05 or has_waterfall) else 0.0
		wx_fade = CWUtil.damp(wx_fade, want_wx, 2.5 if want_wx < 0.5 else 0.9, dt)
		wx_mat.set_shader_parameter("u_fade", wx_fade)

	var di := decals.size() - 1
	while di >= 0:
		decals[di]["life"] = float(decals[di]["life"]) - dt
		if float(decals[di]["life"]) <= 0.0:
			decals.remove_at(di)
		di -= 1
	var d_vis := mini(decals.size(), 64)
	for i in range(d_vis):
		var dc := decals[i]
		var a := clampf(float(dc["life"]) / 3.0, 0.0, 1.0)
		var c: Color = dc["col"]
		decal_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(float(dc["size"]), 1.0, float(dc["size"]))), dc["pos"]))
		decal_mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * a))
	decal_mm.visible_instance_count = d_vis

	var ri_i := rings.size() - 1
	while ri_i >= 0:
		rings[ri_i]["t"] = float(rings[ri_i]["t"]) + dt / float(rings[ri_i]["dur"])
		if float(rings[ri_i]["t"]) >= 1.0:
			rings.remove_at(ri_i)
		ri_i -= 1
	var r_vis := mini(rings.size(), 24)
	for i in range(r_vis):
		var rg := rings[i]
		var u := clampf(float(rg["t"]), 0.0, 1.0)
		var rad := lerpf(0.35, float(rg["r_max"]), 1.0 - pow(1.0 - u, 2.0))
		var c: Color = rg["col"]
		ring_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(rad, 1.0, rad)), rg["pos"]))
		ring_mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * (1.0 - u)))
	ring_mm.visible_instance_count = r_vis


func clear_fx() -> void:
	particles.clear()
	coins.clear()
	decals.clear()
	rings.clear()
	bolts.clear()
	if part_mm != null: part_mm.visible_instance_count = 0
	if bolt_mm != null: bolt_mm.visible_instance_count = 0
	dynamic_flames.clear()
	if flame_mm != null: flame_mm.visible_instance_count = 0
	if decal_mm != null: decal_mm.visible_instance_count = 0
	if ring_mm != null: ring_mm.visible_instance_count = 0
	for e in emitters:
		e["alive"] = false
	emitters.clear()
	for ol in tower_lights:
		ol.light_energy = 0.0
	for tl in torch_lights:
		tl.light_energy = 0.0
	torch_positions.clear()
	for el in env_lights:
		el.light_energy = 0.0
	env_srcs.clear()
	keep_fires.clear()
	pond_centers.clear()
	has_waterfall = false
	beacon_on = 0.0
	if beacon_light != null:
		beacon_light.light_energy = 0.0
	if beacon_flame_root != null:
		beacon_flame_root.visible = false
	for lmi in lantern_flames:
		lmi.visible = false
	for f in flash_pool:
		f["t"] = 1.0
		(f["light"] as OmniLight3D).light_energy = 0.0
	for s in spot_pool:
		(s["light"] as SpotLight3D).light_energy = 0.0
	wx_fade = 0.0
	if wx_mat != null:
		wx_mat.set_shader_parameter("u_fade", 0.0)
