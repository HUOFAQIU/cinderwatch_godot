class_name CWFxInit
extends RefCounted

# Lighting pools, MultiMesh FX pools, and GPUParticles3D setup (extracted from fx.gd)

static func init_fx(f: CWFx) -> void:
	# Moon & Fill directional lights
	f.moon_light = DirectionalLight3D.new()
	f.moon_light.shadow_enabled = true
	f.moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	f.moon_light.directional_shadow_max_distance = 72.0
	f.moon_light.shadow_bias = 0.06
	f.moon_light.shadow_normal_bias = 0.85
	f.moon_light.shadow_blur = 0.25
	f.add_child(f.moon_light)

	f.fill_light = DirectionalLight3D.new()
	f.fill_light.shadow_enabled = false
	f.add_child(f.fill_light)

	# Shadow-casting Beacon OmniLight3D
	f.beacon_light = OmniLight3D.new()
	f.beacon_light.light_color = Color(1.0, 0.54, 0.22)
	f.beacon_light.omni_range = 75.0
	f.beacon_light.omni_attenuation = 1.42
	f.beacon_light.shadow_enabled = true
	f.beacon_light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	f.beacon_light.shadow_bias = 0.06
	f.beacon_light.shadow_normal_bias = 0.75
	f.beacon_light.shadow_blur = 0.35
	f.add_child(f.beacon_light)

	# 3-layer volumetric Great Beacon flame column + warm golden bloom halo (40-fx.js:338-346)
	var fl_sh := load("res://shaders/flame.gdshader") as Shader
	f.beacon_flame_root = Node3D.new()
	f.add_child(f.beacon_flame_root)
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
			f.beacon_flame_mats.append(fmat)
			var fmi := MeshInstance3D.new()
			fmi.mesh = qm
			fmi.material_override = fmat
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fw := 3.25 * (1.0 - kk * 0.20)
			var fh := 4.45 * (1.0 - kk * 0.14)
			fmi.scale = Vector3(fw, fh, 1.0)
			fmi.position = Vector3(sin(float(k) * 2.1) * 0.28 if k > 0 else 0.0, fh * 0.43, cos(float(k) * 1.7) * 0.28 if k > 0 else 0.0)
			f.beacon_flame_root.add_child(fmi)
		f.beacon_halo_mat = ShaderMaterial.new()
		f.beacon_halo_mat.shader = fl_sh
		f.beacon_halo_mat.render_priority = 7
		f.beacon_halo_mat.set_shader_parameter("u_is_halo", 1.0)
		f.beacon_halo_mat.set_shader_parameter("u_col", Vector3(1.25, 0.56, 0.16))
		f.beacon_halo_mat.set_shader_parameter("u_intensity", 0.36)
		var hmi := MeshInstance3D.new()
		hmi.mesh = qm
		hmi.material_override = f.beacon_halo_mat
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hmi.scale = Vector3(13.5, 13.5, 1.0)
		hmi.position = Vector3(0.0, 1.65, 0.0)
		f.beacon_flame_root.add_child(hmi)
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
			f.add_child(lmi)
			f.lantern_flames.append(lmi)

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
		f.add_child(sp)
		f.spot_pool.append({"light": sp, "owner": null, "fade": 0.0})

	# 12 non-shadow tower OmniLight3D
	for _i in range(12):
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.58, 0.26)
		ol.omni_range = 15.0
		ol.omni_attenuation = 1.8
		ol.shadow_enabled = false
		ol.light_energy = 0.0
		f.add_child(ol)
		f.tower_lights.append(ol)

	# 8 moving torch OmniLight3D following footmen & torch-bearing skeletons
	for _i in range(8):
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.65, 0.28)
		tl.omni_range = 7.5
		tl.omni_attenuation = 1.9
		tl.shadow_enabled = false
		tl.light_energy = 0.0
		f.add_child(tl)
		f.torch_lights.append(tl)

	# 3 environment OmniLight3D (keep lanterns / bridge / waterfall glow)
	for _i in range(3):
		var el := OmniLight3D.new()
		el.shadow_enabled = false
		el.light_energy = 0.0
		f.add_child(el)
		f.env_lights.append(el)

	# 4 flash OmniLight3D for explosions/lightning
	for _i in range(4):
		var fl := OmniLight3D.new()
		fl.omni_range = 18.0
		fl.shadow_enabled = false
		fl.light_energy = 0.0
		f.add_child(fl)
		f.flash_pool.append({"light": fl, "t": 1.0, "dur": 1.0, "energy": 0.0})

	_init_particle_meshes(f)


static func _init_particle_meshes(f: CWFx) -> void:
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

	f.part_mm = MultiMesh.new()
	f.part_mm.transform_format = MultiMesh.TRANSFORM_3D
	f.part_mm.use_colors = true
	f.part_mm.mesh = quad_m
	f.part_buf.resize(f.MAX_PARTS * 16)
	f.part_mm.instance_count = f.MAX_PARTS
	f.part_mm.visible_instance_count = 0
	f.part_mmi = MultiMeshInstance3D.new()
	f.part_mmi.multimesh = f.part_mm
	f.part_mmi.material_override = p_mat
	f.part_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.part_mmi)

	# Chain lightning segments
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.vertex_color_use_as_albedo = true
	f.bolt_mm = MultiMesh.new()
	f.bolt_mm.transform_format = MultiMesh.TRANSFORM_3D
	f.bolt_mm.use_colors = true
	f.bolt_mm.mesh = box_m
	f.bolt_buf.resize(f.MAX_BOLTS * 16)
	f.bolt_mm.instance_count = f.MAX_BOLTS
	f.bolt_mm.visible_instance_count = 0
	f.bolt_mmi = MultiMeshInstance3D.new()
	f.bolt_mmi.multimesh = f.bolt_mm
	f.bolt_mmi.material_override = b_mat
	f.bolt_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.bolt_mmi)

	# 2600-instance GPU dual-layer point-lit weather (exact 41-weather.js port)
	f.wx_mm = MultiMesh.new()
	f.wx_mm.transform_format = MultiMesh.TRANSFORM_3D
	f.wx_mm.use_custom_data = true
	f.wx_mm.mesh = quad_m
	f.wx_mm.instance_count = f.MAX_WX
	var wx_rng := CWUtil.Rng.new(4242)
	for wi in range(f.MAX_WX):
		f.wx_mm.set_instance_transform(wi, Transform3D.IDENTITY)
		f.wx_mm.set_instance_custom_data(wi, Color(wx_rng.next_f(), wx_rng.next_f(), wx_rng.next_f(), (float(wi) + 0.5) / float(f.MAX_WX)))
	f.wx_mmi = MultiMeshInstance3D.new()
	f.wx_mmi.multimesh = f.wx_mm
	f.wx_mmi.extra_cull_margin = 16384.0
	var wx_sh := load("res://shaders/weather.gdshader") as Shader
	if wx_sh != null:
		f.wx_mat = ShaderMaterial.new()
		f.wx_mat.shader = wx_sh
		f.wx_mat.render_priority = 4
		f.wx_mmi.material_override = f.wx_mat
	else:
		f.wx_mmi.material_override = p_mat
	f.wx_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.wx_mmi)

	# 96-instance animated dancing billboard flame pool for all tower braziers, torches & handheld fires
	var fl_inst_sh := load("res://shaders/flame.gdshader") as Shader
	if fl_inst_sh != null:
		var fl_mat := ShaderMaterial.new()
		fl_mat.shader = fl_inst_sh
		fl_mat.render_priority = 8
		fl_mat.set_shader_parameter("u_is_instanced", true)
		fl_mat.set_shader_parameter("u_is_halo", 0.0)
		fl_mat.set_shader_parameter("u_col", Vector3(1.0, 0.58, 0.22))
		f.flame_mm = MultiMesh.new()
		f.flame_mm.transform_format = MultiMesh.TRANSFORM_3D
		f.flame_mm.use_custom_data = true
		f.flame_mm.mesh = quad_m
		f.flame_buf.resize(f.MAX_FLAMES * 16)
		f.flame_mm.instance_count = f.MAX_FLAMES
		f.flame_mm.visible_instance_count = 0
		f.flame_mmi = MultiMeshInstance3D.new()
		f.flame_mmi.multimesh = f.flame_mm
		f.flame_mmi.material_override = fl_mat
		f.flame_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(f.flame_mmi)

	# Native GPUParticles3D emitters for Great Beacon rising embers & Waterfall spray
	f.beacon_embers_gpu = GPUParticles3D.new()
	f.beacon_embers_gpu.name = "BeaconEmbersGPU"
	f.beacon_embers_gpu.amount = 36
	f.beacon_embers_gpu.lifetime = 1.8
	f.beacon_embers_gpu.preprocess = 0.5
	f.beacon_embers_gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.beacon_embers_gpu.draw_pass_1 = quad_m
	f.beacon_embers_gpu.material_override = p_mat
	var be_mat := ParticleProcessMaterial.new()
	be_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	be_mat.emission_box_extents = Vector3(0.45, 0.25, 0.45)
	be_mat.direction = Vector3(0.0, 1.0, 0.0)
	be_mat.spread = 28.0
	be_mat.initial_velocity_min = 1.2
	be_mat.initial_velocity_max = 2.6
	be_mat.gravity = Vector3(0.0, 0.4, 0.0)
	be_mat.scale_min = 0.08
	be_mat.scale_max = 0.18
	be_mat.color = Color(1.9, 0.82, 0.22, 0.92)
	f.beacon_embers_gpu.process_material = be_mat
	f.add_child(f.beacon_embers_gpu)

	f.waterfall_gpu = GPUParticles3D.new()
	f.waterfall_gpu.name = "WaterfallParticlesGPU"
	f.waterfall_gpu.amount = 42
	f.waterfall_gpu.lifetime = 0.85
	f.waterfall_gpu.emitting = false
	f.waterfall_gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.waterfall_gpu.draw_pass_1 = quad_m
	f.waterfall_gpu.material_override = p_mat
	f._wf_gpu_mat = ParticleProcessMaterial.new()
	f._wf_gpu_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	f._wf_gpu_mat.emission_box_extents = Vector3(0.85, 0.28, 0.25)
	f._wf_gpu_mat.direction = Vector3(0.0, 0.85, 0.45)
	f._wf_gpu_mat.spread = 35.0
	f._wf_gpu_mat.initial_velocity_min = 0.8
	f._wf_gpu_mat.initial_velocity_max = 1.8
	f._wf_gpu_mat.gravity = Vector3(0.0, -0.5, 0.0)
	f._wf_gpu_mat.scale_min = 0.26
	f._wf_gpu_mat.scale_max = 0.50
	f._wf_gpu_mat.color = Color(0.75, 0.85, 0.95, 0.52)
	f.waterfall_gpu.process_material = f._wf_gpu_mat
	f.add_child(f.waterfall_gpu)

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
	f.decal_mm = MultiMesh.new()
	f.decal_mm.transform_format = MultiMesh.TRANSFORM_3D
	f.decal_mm.use_colors = true
	f.decal_mm.mesh = dq
	f.decal_mm.instance_count = 64
	f.decal_mm.visible_instance_count = 0
	f.decal_mmi = MultiMeshInstance3D.new()
	f.decal_mmi.multimesh = f.decal_mm
	f.decal_mmi.material_override = d_mat
	f.decal_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.decal_mmi)

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
	f.ring_mm = MultiMesh.new()
	f.ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	f.ring_mm.use_colors = true
	f.ring_mm.mesh = ring_st.commit()
	f.ring_mm.instance_count = 24
	f.ring_mm.visible_instance_count = 0
	f.ring_mmi = MultiMeshInstance3D.new()
	f.ring_mmi.multimesh = f.ring_mm
	f.ring_mmi.material_override = r_mat
	f.ring_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.ring_mmi)
