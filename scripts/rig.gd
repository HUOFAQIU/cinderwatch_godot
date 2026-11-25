class_name CWRig
extends Node3D

# Faithful MultiMeshInstance3D articulated character rigging & shatter debris
# Ported from 50-rig.js and 51-bestiary.js:
# 2-segment arms/legs, Bone Giant horns, Frost Jotun ice club, Necromancer hood/staff,
# War Drummer drum/banner, Buried King crown/khopesh, 8-legged Spiders, and Dire Wolves

class PartBatch:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap: int
	var count: int = 0
	var buf: PackedFloat32Array = PackedFloat32Array()

	func _init(parent: Node3D, mesh: Mesh, mat: Material, p_cap: int) -> void:
		cap = p_cap
		buf.resize(cap * 20)
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mmi)

	func begin() -> void:
		count = 0

	func put(xf: Transform3D, col: Color, flash: float = 0.0) -> void:
		if count >= cap:
			return
		var off := count * 20
		var b := xf.basis
		var o := xf.origin
		buf[off] = b.x.x; buf[off + 1] = b.y.x; buf[off + 2] = b.z.x; buf[off + 3] = o.x
		buf[off + 4] = b.x.y; buf[off + 5] = b.y.y; buf[off + 6] = b.z.y; buf[off + 7] = o.y
		buf[off + 8] = b.x.z; buf[off + 9] = b.y.z; buf[off + 10] = b.z.z; buf[off + 11] = o.z
		buf[off + 12] = col.r; buf[off + 13] = col.g; buf[off + 14] = col.b; buf[off + 15] = col.a
		buf[off + 16] = flash; buf[off + 17] = 0.0; buf[off + 18] = 0.0; buf[off + 19] = 0.0
		count += 1

	func end() -> void:
		if count > 0:
			mm.buffer = buf
		mm.visible_instance_count = count


var gfx: CWGfx
var batches: Dictionary = {}
var debris: Array[Dictionary] = []
var last_torch_pos: Vector3 = Vector3.ZERO
var capture_buf: Array[Dictionary] = []
var capturing: bool = false
var glow_mmi: MultiMeshInstance3D
var glow_mm: MultiMesh
var glow_count: int = 0
var glow_buf: PackedFloat32Array = PackedFloat32Array()
const MAX_GLOW := 1600


func init_kits(p_gfx: CWGfx) -> void:
	gfx = p_gfx
	batches["box"] = PartBatch.new(self, _make_box_mesh(), gfx.mat_inst, 9600)
	batches["cyl"] = PartBatch.new(self, _make_cyl_mesh(6), gfx.mat_inst, 3600)
	batches["cone"] = PartBatch.new(self, _make_cone_mesh(6), gfx.mat_inst, 2400)
	batches["sphere"] = PartBatch.new(self, _make_sphere_mesh(), gfx.mat_inst, 3200)

	# P0-4: Additive billboard MultiMesh for glowing monster eyes & 9x halos
	var g_mat := StandardMaterial3D.new()
	g_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	g_mat.billboard_keep_scale = true
	g_mat.vertex_color_use_as_albedo = true
	g_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	g_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gi := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for gy in range(16):
		for gx in range(16):
			var dx := (float(gx) + 0.5) / 8.0 - 1.0
			var dy := (float(gy) + 0.5) / 8.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var w := pow(clampf(1.0 - r, 0.0, 1.0), 2.4)
			gi.set_pixel(gx, gy, Color(w, w, w, w))
	g_mat.albedo_texture = ImageTexture.create_from_image(gi)
	var gq := QuadMesh.new()
	gq.size = Vector2.ONE
	glow_mm = MultiMesh.new()
	glow_mm.transform_format = MultiMesh.TRANSFORM_3D
	glow_mm.use_colors = true
	glow_mm.mesh = gq
	glow_buf.resize(MAX_GLOW * 16)
	glow_mm.instance_count = MAX_GLOW
	glow_mm.visible_instance_count = 0
	glow_mmi = MultiMeshInstance3D.new()
	glow_mmi.multimesh = glow_mm
	glow_mmi.material_override = g_mat
	glow_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow_mmi)


func _make_box_mesh() -> ArrayMesh:
	var s := CWGfx.Soup.new()
	s.add_box(Vector3.ONE, Vector3.ZERO, Color.WHITE, CWGfx.L_PLAIN, 0.85)
	return s.build()


func _make_cyl_mesh(segs: int) -> ArrayMesh:
	var s := CWGfx.Soup.new()
	s.add_cyl(0.5, 0.5, 1.0, Vector3.ZERO, Color.WHITE, segs, CWGfx.L_PLAIN, 0.85)
	return s.build()


func _make_cone_mesh(segs: int) -> ArrayMesh:
	var s := CWGfx.Soup.new()
	s.add_cone(0.5, 1.0, Vector3.ZERO, Color.WHITE, segs, CWGfx.L_PLAIN, 0.85)
	return s.build()


func _make_sphere_mesh() -> ArrayMesh:
	var s := CWGfx.Soup.new()
	s.add_rock(0.5, Vector3.ZERO, Color.WHITE, 42, CWGfx.L_PLAIN, 0.82)
	return s.build()


func begin_frame() -> void:
	for b in batches.values():
		b.begin()
	glow_count = 0


func end_frame() -> void:
	for b in batches.values():
		b.end()
	if glow_mm != null:
		if glow_count > 0:
			glow_mm.buffer = glow_buf
		glow_mm.visible_instance_count = glow_count


func push_glow(pos: Vector3, col: Color, size: float, alpha: float = 1.0) -> void:
	if capturing or glow_mm == null or glow_count >= MAX_GLOW:
		return
	var off := glow_count * 16
	glow_buf[off] = size; glow_buf[off + 1] = 0.0; glow_buf[off + 2] = 0.0; glow_buf[off + 3] = pos.x
	glow_buf[off + 4] = 0.0; glow_buf[off + 5] = size; glow_buf[off + 6] = 0.0; glow_buf[off + 7] = pos.y
	glow_buf[off + 8] = 0.0; glow_buf[off + 9] = 0.0; glow_buf[off + 10] = size; glow_buf[off + 11] = pos.z
	glow_buf[off + 12] = col.r * alpha; glow_buf[off + 13] = col.g * alpha; glow_buf[off + 14] = col.b * alpha; glow_buf[off + 15] = 1.0
	glow_count += 1


func put_part(kind: String, xf: Transform3D, col: Color, flash: float = 0.0) -> void:
	if capturing:
		capture_buf.append({"kind": kind, "xf": xf, "col": col})
		return
	var b: PartBatch = batches.get(kind, batches["box"])
	b.put(xf, col, flash)


func _xf(parent: Transform3D, pos: Vector3, rot: Vector3, scl: Vector3) -> Transform3D:
	var local := Transform3D(Basis.from_euler(rot).scaled_local(scl), pos)
	return parent * local


func draw_humanoid(pos: Vector3, yaw: float, scale_v: float, phase: float, swing: float, body_col: Color, accent_col: Color, flash: float, opts: Dictionary = {}) -> void:
	var s := scale_v
	if opts.get("wraith", false):
		var t_w := Time.get_ticks_msec() * 0.001 + pos.x * 0.7
		var wr := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(0.16 * float(opts.get("mv", 1.0)), 0.0, sin(t_w * 1.3) * 0.06)), pos + Vector3(0.0, (0.24 + sin(t_w * 2.1) * 0.07) * s, 0.0))
		var rc := Color(0.18, 0.23, 0.31)
		var rcd := Color(0.11, 0.14, 0.20)
		put_part("cone", _xf(wr, Vector3(0, 0.50 * s, 0), Vector3.ZERO, Vector3(0.36 * s, 0.96 * s, 0.36 * s)), rc, flash)
		put_part("sphere", _xf(wr, Vector3(0, 0.90 * s, -0.02 * s), Vector3.ZERO, Vector3(0.42 * s, 0.20 * s, 0.32 * s)), rcd, flash)
		put_part("sphere", _xf(wr, Vector3(0, 1.05 * s, -0.03 * s), Vector3.ZERO, Vector3(0.36 * s, 0.34 * s, 0.36 * s)), rcd, flash)
		put_part("sphere", _xf(wr, Vector3(0, 1.03 * s, 0.05 * s), Vector3.ZERO, Vector3(0.22 * s, 0.24 * s, 0.22 * s)), Color(0.82, 0.78, 0.70), flash)
		for esg in [-1.0, 1.0]:
			put_part("box", _xf(wr, Vector3(esg * 0.045 * s, 1.04 * s, 0.15 * s), Vector3.ZERO, Vector3(0.042 * s, 0.042 * s, 0.03 * s)), Color(0.04, 0.04, 0.05), flash)
		if opts.has("eye"):
			var wec: Color = opts["eye"]
			push_glow(wr * Vector3(-0.045 * s, 1.04 * s, 0.16 * s), wec, 0.05 * s, 1.1)
			push_glow(wr * Vector3(0.045 * s, 1.04 * s, 0.16 * s), wec, 0.05 * s, 1.1)
		for asg in [-1.0, 1.0]:
			var wa := _xf(wr, Vector3(asg * 0.22 * s, 0.84 * s, 0.04 * s), Vector3(-0.25 + sin(t_w * 1.7 + asg) * 0.22, asg * -0.25, 0.0), Vector3.ONE)
			put_part("box", _xf(wa, Vector3(0, -0.06 * s, 0.14 * s), Vector3(0.35, 0, 0), Vector3(0.09 * s, 0.09 * s, 0.30 * s)), rcd, flash)
			put_part("cone", _xf(wa, Vector3(0, -0.14 * s, 0.32 * s), Vector3(1.1, 0, 0), Vector3(0.05 * s, 0.14 * s, 0.05 * s)), Color(0.80, 0.76, 0.68), flash)
		return
	var mv := float(opts.get("mv", 1.0))
	var bob := absf(sin(phase)) * 0.07 * s * mv
	# 2-phase melee attack curve (swing = 1.0 -> 0.0: raise weapon overhead, then whip down & lunge)
	var atk_u := 1.0 - clampf(swing, 0.0, 1.0)
	var has_atk := swing > 0.01
	var atk_arm := 0.0
	var atk_twist := 0.0
	var atk_lunge := 0.0
	if has_atk:
		if atk_u < 0.40:
			var w := atk_u / 0.40
			var ew := w * w * (3.0 - 2.0 * w)
			atk_arm = -2.35 * ew
			atk_twist = -0.45 * ew
			atk_lunge = -0.10 * ew
		elif atk_u < 0.65:
			var w := (atk_u - 0.40) / 0.25
			var ew := 1.0 - pow(1.0 - w, 3.0)
			atk_arm = lerpf(-2.35, 0.85, ew)
			atk_twist = lerpf(-0.45, 0.55, ew)
			atk_lunge = lerpf(-0.10, 0.26, ew)
		else:
			var w := (atk_u - 0.65) / 0.35
			atk_arm = lerpf(0.85, 0.0, w)
			atk_twist = lerpf(0.55, 0.0, w)
			atk_lunge = lerpf(0.26, 0.0, w)
	var lean := (0.14 if opts.get("heavy", false) else 0.08) + maxf(0.0, atk_lunge) * 1.4
	var root := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0.0, bob, 0.0))
	var thigh_a := sin(phase) * 0.62 * mv
	var knee_l := maxf(0.0, -sin(phase + 0.5)) * 0.55 * mv
	var knee_r := maxf(0.0, sin(phase + 0.5)) * 0.55 * mv

	var is_skel := bool(opts.get("skel", false))
	var bone_d := body_col.darkened(0.24)
	# Articulated 2-segment legs (thin bone shafts + feet for skeletons)
	var leg_w := (0.070 if is_skel else 0.12) * s
	var shin_w := (0.056 if is_skel else 0.10) * s
	var hip_off := (0.095 if is_skel else 0.12) * s
	for side in [-1, 1]:
		var ta := thigh_a if side < 0 else -thigh_a
		var ka := knee_l if side < 0 else knee_r
		var u_leg := _xf(root, Vector3(float(side) * hip_off, 0.46 * s, 0.0), Vector3(ta, 0, 0), Vector3.ONE)
		put_part("box", _xf(u_leg, Vector3(0, -0.12 * s, 0), Vector3.ZERO, Vector3(leg_w, 0.25 * s, leg_w)), body_col if is_skel else body_col.darkened(0.16), flash)
		var l_leg := _xf(u_leg, Vector3(0, -0.24 * s, 0), Vector3(ka, 0, 0), Vector3.ONE)
		put_part("box", _xf(l_leg, Vector3(0, -0.12 * s, 0), Vector3.ZERO, Vector3(shin_w, 0.24 * s, shin_w)), bone_d if is_skel else body_col.darkened(0.24), flash)
		if is_skel:
			put_part("box", _xf(l_leg, Vector3(0, -0.23 * s, 0.04 * s), Vector3.ZERO, Vector3(0.082 * s, 0.046 * s, 0.16 * s)), bone_d, flash)

	# Pelvis & Torso (exact 50-rig.js:48-55 spine + 3 rib bars + collarbone + sternum for skeletons)
	var torso_w := (0.38 if is_skel else 0.44) * s if opts.get("heavy", false) else (0.31 if is_skel else 0.32) * s
	put_part("box", _xf(root, Vector3(0, 0.50 * s, 0), Vector3.ZERO, Vector3(torso_w * (0.78 if is_skel else 0.85), (0.09 if is_skel else 0.12) * s, (0.13 if is_skel else 0.18) * s)), bone_d if is_skel else body_col.darkened(0.1), flash)
	var fz := float(opts.get("flinch", 0.0))
	var cast_u := float(opts.get("cast", 0.0))
	var torso := _xf(root, Vector3(0, 0.56 * s, atk_lunge * 0.45 * s - fz * 0.05 * s), Vector3(lean - fz * 0.28, atk_twist, 0), Vector3.ONE)
	if is_skel:
		put_part("box", _xf(torso, Vector3(0, 0.21 * s, -0.03 * s), Vector3.ZERO, Vector3(0.065 * s, 0.42 * s, 0.065 * s)), bone_d, flash)
		put_part("box", _xf(torso, Vector3(0, 0.25 * s, 0.095 * s), Vector3.ZERO, Vector3(0.055 * s, 0.24 * s, 0.03 * s)), body_col, flash)
		put_part("box", _xf(torso, Vector3(0, 0.42 * s, 0.0), Vector3.ZERO, Vector3(0.37 * s, 0.065 * s, 0.11 * s)), body_col, flash)
		for ry: float in [0.15, 0.24, 0.33]:
			var rw: float = (0.29 - (0.33 - ry) * 0.24) * s
			put_part("box", _xf(torso, Vector3(0, ry * s, 0.01 * s), Vector3.ZERO, Vector3(rw, 0.048 * s, 0.19 * s)), body_col, flash)
	else:
		put_part("box", _xf(torso, Vector3(0, 0.22 * s, 0), Vector3.ZERO, Vector3(torso_w, 0.44 * s, 0.22 * s)), body_col, flash)

	# Head + Jaw + Dark Eye Sockets + Eye Glow
	var head := _xf(torso, Vector3(0, 0.48 * s, 0.03 * s), Vector3(-lean * 0.5, 0, 0), Vector3.ONE)
	if is_skel:
		put_part("sphere", _xf(head, Vector3(0, 0.16 * s, 0), Vector3.ZERO, Vector3(0.27 * s, 0.26 * s, 0.29 * s)), accent_col, flash)
		put_part("box", _xf(head, Vector3(0, 0.04 * s, 0.035 * s), Vector3.ZERO, Vector3(0.16 * s, 0.075 * s, 0.13 * s)), bone_d, flash)
		var dark_sk := Color(0.05, 0.04, 0.04)
		for esg in [-1.0, 1.0]:
			put_part("box", _xf(head, Vector3(esg * 0.056 * s, 0.17 * s, 0.128 * s), Vector3.ZERO, Vector3(0.060 * s, 0.056 * s, 0.04 * s)), dark_sk, flash)
		put_part("box", _xf(head, Vector3(0, 0.11 * s, 0.145 * s), Vector3.ZERO, Vector3(0.028 * s, 0.036 * s, 0.035 * s)), dark_sk, flash)
	else:
		put_part("sphere", _xf(head, Vector3(0, 0.13 * s, 0), Vector3.ZERO, Vector3(0.28 * s, 0.29 * s, 0.28 * s)), accent_col, flash)
	if opts.has("eye"):
		var ec: Color = opts["eye"]
		var ey_y := 0.17 if is_skel else 0.14
		var e_l := head * Vector3(-0.056 * s, ey_y * s, 0.145 * s)
		var e_r := head * Vector3(0.056 * s, ey_y * s, 0.145 * s)
		push_glow(e_l, ec, 0.052 * s, 1.05)
		push_glow(e_r, ec, 0.052 * s, 1.05)
		push_glow((e_l + e_r) * 0.5, ec, 0.44 * s, 0.10)

	if opts.get("horns", false):
		for sg in [-1.0, 1.0]:
			put_part("cone", _xf(head, Vector3(sg * 0.16 * s, 0.28 * s, 0.02 * s), Vector3(0.2, 0, -sg * 0.45), Vector3(0.08 * s, 0.24 * s, 0.08 * s)), Color(0.75, 0.70, 0.60), flash)
	if opts.get("armor_suit", false):
		var ir := Color(0.32, 0.34, 0.38)
		var irl := Color(0.48, 0.50, 0.56)
		put_part("box", _xf(torso, Vector3(0, 0.27 * s, 0), Vector3.ZERO, Vector3(0.34 * s, 0.30 * s, 0.24 * s)), ir, flash)
		put_part("box", _xf(torso, Vector3(0, 0.29 * s, 0.01 * s), Vector3.ZERO, Vector3(0.20 * s, 0.20 * s, 0.25 * s)), irl, flash)
		for psg in [-1.0, 1.0]:
			put_part("sphere", _xf(torso, Vector3(psg * 0.21 * s, 0.42 * s, 0), Vector3.ZERO, Vector3(0.18 * s, 0.15 * s, 0.20 * s)), irl, flash)
		put_part("sphere", _xf(head, Vector3(0, 0.18 * s, 0), Vector3.ZERO, Vector3(0.33 * s, 0.26 * s, 0.35 * s)), ir, flash)
		put_part("box", _xf(head, Vector3(0, 0.16 * s, 0.175 * s), Vector3.ZERO, Vector3(0.035 * s, 0.12 * s, 0.03 * s)), irl, flash)
		put_part("cone", _xf(head, Vector3(0, 0.36 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.15 * s, 0.055 * s)), irl, flash)
	if opts.get("wraps", false):
		var wc := Color(0.76, 0.70, 0.54)
		for wk in [[0.13, 0.30, 0.10], [0.21, 0.33, -0.12], [0.29, 0.35, 0.08], [0.37, 0.36, -0.06]]:
			put_part("box", _xf(torso, Vector3(0, float(wk[0]) * s, 0), Vector3(0, 0, float(wk[2])), Vector3(float(wk[1]) * s, 0.05 * s, 0.23 * s)), wc, flash)
		put_part("cyl", _xf(head, Vector3(0, 0.24 * s, 0), Vector3.ZERO, Vector3(0.30 * s, 0.08 * s, 0.30 * s)), wc, flash)
	if opts.get("crown", false):
		var gc := Color(0.92, 0.74, 0.20)
		put_part("cyl", _xf(head, Vector3(0, 0.28 * s, 0), Vector3.ZERO, Vector3(0.30 * s, 0.08 * s, 0.30 * s)), gc, flash)
		for ca in range(6):
			var c_ang := float(ca) * 1.0472
			put_part("cone", _xf(head, Vector3(cos(c_ang) * 0.14 * s, 0.36 * s, sin(c_ang) * 0.14 * s), Vector3.ZERO, Vector3(0.05 * s, 0.12 * s, 0.05 * s)), gc, flash)
		put_part("sphere", _xf(head, Vector3(0, 0.29 * s, 0.15 * s), Vector3.ZERO, Vector3.ONE * 0.055 * s), Color(0.2, 0.9, 0.8), maxf(flash, 0.4))
	elif opts.get("hood", false):
		put_part("cone", _xf(head, Vector3(0, 0.22 * s, -0.02 * s), Vector3(-0.15, 0, 0), Vector3(0.36 * s, 0.34 * s, 0.36 * s)), Color(0.22, 0.18, 0.28), flash)

	# Articulated Arms (upper + forearm)
	var arm_a := -sin(phase) * 0.55 * mv
	var draw_amt := float(opts.get("draw", 0.0))
	var has_torch := bool(opts.get("torch", false))
	var r_sh := (atk_arm if has_atk else arm_a) - draw_amt * 1.15 + fz * 0.42
	var l_sh := ((-0.78 + sin(phase) * 0.08 * mv) if has_torch else (-arm_a * 0.7 - draw_amt * 0.85)) + fz * 0.48
	if cast_u > 0.01:
		var cu := cast_u * cast_u * (3.0 - 2.0 * cast_u)
		r_sh = lerpf(r_sh, -2.55, cu)
		l_sh = lerpf(l_sh, -2.35, cu)

	var ua_w := (0.056 if is_skel else 0.10) * s
	var la_w := (0.048 if is_skel else 0.09) * s
	var arm_off := (0.19 if is_skel else torso_w * 0.62)
	var l_uarm := _xf(torso, Vector3(-arm_off, 0.39 * s, 0), Vector3(l_sh, 0, 0.14), Vector3.ONE)
	put_part("box", _xf(l_uarm, Vector3(0, -0.11 * s, 0), Vector3.ZERO, Vector3(ua_w, 0.22 * s, ua_w)), body_col, flash)
	var l_larm := _xf(l_uarm, Vector3(0, -0.22 * s, 0), Vector3(-0.55 if has_torch else -0.45, 0, 0), Vector3.ONE)
	put_part("box", _xf(l_larm, Vector3(0, -0.10 * s, 0), Vector3.ZERO, Vector3(la_w, 0.20 * s, la_w)), bone_d if is_skel else body_col.darkened(0.08), flash)

	var r_uarm := _xf(torso, Vector3(arm_off, 0.39 * s, 0), Vector3(r_sh, 0, -0.14), Vector3.ONE)
	put_part("box", _xf(r_uarm, Vector3(0, -0.11 * s, 0), Vector3.ZERO, Vector3(ua_w, 0.22 * s, ua_w)), body_col, flash)
	var r_larm := _xf(r_uarm, Vector3(0, -0.22 * s, 0), Vector3(-0.45 + (atk_arm * 0.35 if has_atk else 0.0), 0, 0), Vector3.ONE)
	put_part("box", _xf(r_larm, Vector3(0, -0.10 * s, 0), Vector3.ZERO, Vector3(la_w, 0.20 * s, la_w)), bone_d if is_skel else body_col.darkened(0.08), flash)

	# Weapons & Special Gear
	if opts.get("bow", false):
		put_part("box", _xf(l_larm, Vector3(0, -0.18 * s, 0.14 * s), Vector3.ZERO, Vector3(0.04 * s, 0.52 * s, 0.06 * s)), Color(0.58, 0.40, 0.22), flash)
	elif opts.get("keg", false):
		put_part("cyl", _xf(torso, Vector3(0, 0.26 * s, 0.24 * s), Vector3(0, 0, PI * 0.5), Vector3(0.28 * s, 0.36 * s, 0.28 * s)), Color(0.55, 0.25, 0.12), flash)
		put_part("sphere", _xf(torso, Vector3(0.04 * s, 0.44 * s, 0.24 * s), Vector3.ZERO, Vector3.ONE * 0.08 * s), Color(1.0, 0.55, 0.15), maxf(flash, 0.75))
	elif opts.get("staff", false):
		put_part("cyl", _xf(r_larm, Vector3(0, -0.14 * s, 0.18 * s), Vector3(0.45, 0, 0), Vector3(0.05 * s, 0.95 * s, 0.05 * s)), Color(0.32, 0.22, 0.14), flash)
		put_part("sphere", _xf(r_larm, Vector3(0, 0.12 * s, 0.42 * s), Vector3.ZERO, Vector3.ONE * 0.14 * s), Color(0.35, 1.0, 0.5), maxf(flash, 0.7))
	elif opts.get("iceclub", false):
		put_part("cyl", _xf(r_larm, Vector3(0, -0.16 * s, 0.24 * s), Vector3(0.6, 0, 0), Vector3(0.09 * s, 0.72 * s, 0.09 * s)), Color(0.55, 0.85, 1.1), maxf(flash, 0.3))
	elif opts.get("greatsword", false):
		# Upstream 50-rig.js:119-126 Bone Giant notched steel greatsword
		var gs_base := _xf(r_larm, Vector3(0, -0.14 * s, 0.16 * s), Vector3(0.55, 0, 0), Vector3.ONE)
		var steel := Color(0.72, 0.68, 0.64)
		var dark_i := Color(0.24, 0.25, 0.28)
		put_part("box", _xf(gs_base, Vector3(0, -0.02 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.26 * s, 0.055 * s)), Color(0.32, 0.20, 0.12), flash)
		put_part("sphere", _xf(gs_base, Vector3(0, -0.17 * s, 0), Vector3.ZERO, Vector3.ONE * 0.08 * s), Color(0.84, 0.80, 0.72), flash)
		put_part("box", _xf(gs_base, Vector3(0, 0.12 * s, 0), Vector3.ZERO, Vector3(0.36 * s, 0.055 * s, 0.08 * s)), dark_i, flash)
		put_part("box", _xf(gs_base, Vector3(0, 0.56 * s, 0), Vector3.ZERO, Vector3(0.12 * s, 0.84 * s, 0.032 * s)), steel, flash)
		put_part("box", _xf(gs_base, Vector3(0, 0.52 * s, 0), Vector3.ZERO, Vector3(0.038 * s, 0.70 * s, 0.042 * s)), steel.darkened(0.35), flash)
		put_part("cone", _xf(gs_base, Vector3(0, 1.06 * s, 0), Vector3.ZERO, Vector3(0.12 * s, 0.20 * s, 0.034 * s)), steel, flash)
	elif opts.get("weapon", false):
		var sw_base := _xf(r_larm, Vector3(0, -0.16 * s, 0.06 * s), Vector3(1.12, 0, 0), Vector3.ONE)
		var blade_c := Color(0.56, 0.44, 0.36) if is_skel else Color(0.76, 0.80, 0.88)
		var guard_c := Color(0.28, 0.30, 0.34) if is_skel else Color(0.84, 0.68, 0.26)
		put_part("box", _xf(sw_base, Vector3.ZERO, Vector3.ZERO, Vector3(0.036 * s, 0.13 * s, 0.036 * s)), Color(0.30, 0.20, 0.12), flash)
		put_part("box", _xf(sw_base, Vector3(0, 0.075 * s, 0), Vector3.ZERO, Vector3(0.17 * s, 0.032 * s, 0.05 * s)), guard_c, flash)
		put_part("box", _xf(sw_base, Vector3(0, 0.33 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.48 * s, 0.02 * s)), blade_c, flash)
		put_part("cone", _xf(sw_base, Vector3(0, 0.61 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.09 * s, 0.022 * s)), blade_c, flash)

	if opts.get("shield", false):
		if is_skel:
			# Round iron-rimmed wooden shield (50-rig.js:78)
			put_part("cyl", _xf(l_larm, Vector3(-0.07 * s, -0.10 * s, 0.10 * s), Vector3(0, 0, PI * 0.5), Vector3(0.46 * s, 0.05 * s, 0.46 * s)), Color(0.32, 0.21, 0.12), flash)
			put_part("sphere", _xf(l_larm, Vector3(-0.10 * s, -0.10 * s, 0.10 * s), Vector3.ZERO, Vector3(0.08 * s, 0.14 * s, 0.14 * s)), Color(0.55, 0.58, 0.64), flash)
		else:
			put_part("box", _xf(l_larm, Vector3(-0.08 * s, -0.12 * s, 0.12 * s), Vector3(0, 0.3, 0), Vector3(0.06 * s, 0.38 * s, 0.32 * s)), Color(0.36, 0.46, 0.62), flash)
	elif has_torch:
		# Torch gripped directly in raised left hand (50-rig.js:202 RIGOUT.torch)
		var hand_l := _xf(l_larm, Vector3(0.0, -0.18 * s, 0.02 * s), Vector3(1.22, 0.0, -0.10), Vector3.ONE)
		put_part("cyl", _xf(hand_l, Vector3(0.0, 0.14 * s, 0.0), Vector3.ZERO, Vector3(0.045 * s, 0.44 * s, 0.045 * s)), Color(0.38, 0.24, 0.13), flash)
		var t_tip := _xf(hand_l, Vector3(0.0, 0.36 * s, 0.0), Vector3.ZERO, Vector3(0.085 * s, 0.085 * s, 0.085 * s))
		put_part("sphere", t_tip, Color(0.95, 0.38, 0.08), 0.55)
		last_torch_pos = t_tip.origin

	if opts.get("drum", false):
		put_part("cyl", _xf(torso, Vector3(0, 0.12 * s, 0.26 * s), Vector3(0.45, 0, 0), Vector3(0.32 * s, 0.22 * s, 0.32 * s)), Color(0.55, 0.20, 0.16), flash)
		put_part("cyl", _xf(torso, Vector3(0, 0.56 * s, -0.16 * s), Vector3.ZERO, Vector3(0.04 * s, 0.95 * s, 0.04 * s)), Color(0.42, 0.30, 0.20), flash)
		put_part("box", _xf(torso, Vector3(0, 0.92 * s, -0.18 * s), Vector3.ZERO, Vector3(0.36 * s, 0.44 * s, 0.04 * s)), Color(0.68, 0.22, 0.18), flash)


func draw_quadruped(pos: Vector3, yaw: float, scale_v: float, phase: float, body_col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0) -> void:
	var s := scale_v
	var lng := sin(clampf(swing, 0.0, 1.0) * PI)
	var root := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lng * 0.35), pos + Vector3(0.0, (0.26 + lng * 0.16) * s, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, lng * 0.28 * s))
	put_part("box", _xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.24 * s, 0.20 * s, 0.56 * s)), body_col, flash)
	put_part("cone", _xf(root, Vector3(0.0, 0.10 * s, 0.34 * s), Vector3(PI * 0.45, 0, 0), Vector3(0.20 * s, 0.28 * s, 0.20 * s)), body_col.lightened(0.12), flash)
	for sg in [-1.0, 1.0]:
		put_part("cone", _xf(root, Vector3(sg * 0.07 * s, 0.22 * s, 0.28 * s), Vector3.ZERO, Vector3(0.06 * s, 0.12 * s, 0.06 * s)), body_col.darkened(0.15), flash)
	put_part("box", _xf(root, Vector3(0.0, 0.04 * s, -0.34 * s), Vector3(-0.35, 0, 0), Vector3(0.07 * s, 0.07 * s, 0.26 * s)), body_col.darkened(0.2), flash)
	var l := sin(phase) * 0.72
	for sx in [-0.11, 0.11]:
		for sz in [-0.18, 0.18]:
			var a := l if (sx * sz > 0) else -l
			put_part("box", _xf(root, Vector3(sx * s, -0.14 * s, sz * s), Vector3(a, 0, 0), Vector3(0.07 * s, 0.24 * s, 0.07 * s)), body_col.darkened(0.2), flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.055 * s, 0.14 * s, 0.42 * s)
		var er := root * Vector3(0.055 * s, 0.14 * s, 0.42 * s)
		push_glow(el, eye_col, 0.055 * s, 1.2)
		push_glow(er, eye_col, 0.055 * s, 1.2)
		push_glow((el + er) * 0.5, eye_col, 0.45 * s, 0.14)


func draw_slime(pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0, is_toad: bool = false) -> void:
	if is_toad:
		var hop_t := maxf(absf(sin(phase)), sin(clampf(swing, 0.0, 1.0) * PI) * 1.2)
		var sq_t := lerpf(0.84, 1.12, hop_t)
		var tr_xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -hop_t * 0.28), pos + Vector3(0.0, (0.14 + hop_t * 0.46) * scale_v, 0.0))
		var tc := col
		var tcd := col.darkened(0.28)
		var pale := Color(0.46, 0.46, 0.28)
		put_part("sphere", _xf(tr_xf, Vector3(0, 0.12 * scale_v, -0.02 * scale_v), Vector3.ZERO, Vector3(0.56 * scale_v, 0.36 * scale_v * sq_t, 0.62 * scale_v)), tc, flash)
		put_part("sphere", _xf(tr_xf, Vector3(0, 0.05 * scale_v, 0.18 * scale_v), Vector3.ZERO, Vector3(0.30 * scale_v, 0.18 * scale_v, 0.24 * scale_v)), pale, flash)
		for bsg in [-1.0, 1.0]:
			put_part("sphere", _xf(tr_xf, Vector3(bsg * 0.12 * scale_v, 0.31 * scale_v, 0.20 * scale_v), Vector3.ZERO, Vector3.ONE * 0.14 * scale_v), tcd, flash)
			put_part("box", _xf(tr_xf, Vector3(bsg * 0.20 * scale_v, 0.04 * scale_v, -0.14 * scale_v), Vector3(-hop_t * 0.65, 0, 0), Vector3(0.12 * scale_v, 0.16 * scale_v, 0.26 * scale_v)), tcd, flash)
			put_part("box", _xf(tr_xf, Vector3(bsg * 0.24 * scale_v, -0.03 * scale_v, 0.26 * scale_v), Vector3.ZERO, Vector3(0.08 * scale_v, 0.05 * scale_v, 0.11 * scale_v)), tcd, flash)
		if eye_col.r + eye_col.g + eye_col.b > 0.01:
			push_glow(tr_xf * Vector3(-0.12 * scale_v, 0.33 * scale_v, 0.27 * scale_v), eye_col, 0.055 * scale_v, 1.15)
			push_glow(tr_xf * Vector3(0.12 * scale_v, 0.33 * scale_v, 0.27 * scale_v), eye_col, 0.055 * scale_v, 1.15)
		return
	var hop := maxf(absf(sin(phase)), sin(clampf(swing, 0.0, 1.0) * PI) * 1.25)
	var sq_y := lerpf(0.72, 1.28, hop)
	var sq_xz := 1.0 / sqrt(sq_y)
	var root := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0.0, hop * 0.35 * scale_v + 0.26 * scale_v * sq_y, 0.0))
	put_part("sphere", _xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.70 * scale_v * sq_xz, 0.56 * scale_v * sq_y, 0.70 * scale_v * sq_xz)), col, flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.11 * scale_v, 0.08 * scale_v, 0.30 * scale_v)
		var er := root * Vector3(0.11 * scale_v, 0.08 * scale_v, 0.30 * scale_v)
		push_glow(el, eye_col, 0.06 * scale_v, 1.2)
		push_glow(er, eye_col, 0.06 * scale_v, 1.2)
		push_glow((el + er) * 0.5, eye_col, 0.50 * scale_v, 0.14)


func draw_flyer(pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, is_wisp: bool = false, eye_col: Color = Color.BLACK, is_garg: bool = false) -> void:
	if is_wisp:
		var wroot := Transform3D(Basis(Vector3.UP, yaw), pos)
		put_part("sphere", _xf(wroot, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.28 * scale_v), col, maxf(flash, 0.75))
		push_glow(pos, col, 0.75 * scale_v, 0.22)
		return
	# Matches 50-rig.js:231-238: body bob/pitch/bank + shoulder-pivoted wing flap
	var s := scale_v
	var body_pos := pos + Vector3(0.0, sin(phase * 0.5) * 0.08 * s, 0.0)
	var body_rot := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(-0.25, 0.0, sin(phase * 0.25) * 0.15))
	var root := Transform3D(body_rot, body_pos)
	var flap := sin(phase) * 0.85 + 0.15
	put_part("sphere", _xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.24 * s, 0.18 * s, 0.32 * s)), col, flash)
	var l_sh := _xf(root, Vector3(-0.08 * s, 0.02 * s, 0.0), Vector3(0.0, 0.0, -flap), Vector3.ONE)
	var r_sh := _xf(root, Vector3(0.08 * s, 0.02 * s, 0.0), Vector3(0.0, 0.0, flap), Vector3.ONE)
	put_part("box", _xf(l_sh, Vector3(-0.25 * s, 0.0, 0.0), Vector3.ZERO, Vector3(0.50 * s, 0.04 * s, 0.24 * s)), col.darkened(0.15), flash)
	put_part("box", _xf(r_sh, Vector3(0.25 * s, 0.0, 0.0), Vector3.ZERO, Vector3(0.50 * s, 0.04 * s, 0.24 * s)), col.darkened(0.15), flash)
	if is_garg:
		# Sculpted stone horns, snout & barbed tail on Gargoyle (51-bestiary.js:108-115)
		var gd := col.darkened(0.25)
		put_part("box", _xf(root, Vector3(0, 0.05 * s, 0.22 * s), Vector3.ZERO, Vector3(0.12 * s, 0.09 * s, 0.16 * s)), gd, flash)
		put_part("box", _xf(root, Vector3(0, -0.08 * s, -0.26 * s), Vector3(-0.35, 0, 0), Vector3(0.05 * s, 0.05 * s, 0.28 * s)), gd, flash)
		for gsg in [-1.0, 1.0]:
			put_part("cone", _xf(root, Vector3(gsg * 0.09 * s, 0.18 * s, 0.06 * s), Vector3(-0.35, 0, -gsg * 0.35), Vector3(0.05 * s, 0.16 * s, 0.05 * s)), gd, flash)
			put_part("box", _xf(root, Vector3(gsg * 0.12 * s, -0.12 * s, 0.10 * s), Vector3(0.4, 0, 0), Vector3(0.05 * s, 0.18 * s, 0.05 * s)), gd, flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.05 * scale_v, 0.03 * scale_v, 0.16 * scale_v)
		var er := root * Vector3(0.05 * scale_v, 0.03 * scale_v, 0.16 * scale_v)
		push_glow(el, eye_col, 0.055 * scale_v, 1.2)
		push_glow(er, eye_col, 0.055 * scale_v, 1.2)
		push_glow(pos, eye_col, 0.48 * scale_v, 0.13)


func draw_bug(pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0) -> void:
	var s := scale_v
	var lng := sin(clampf(swing, 0.0, 1.0) * PI)
	var root := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lng * 0.32), pos + Vector3(0.0, (0.18 + lng * 0.12) * s, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, lng * 0.24 * s))
	put_part("sphere", _xf(root, Vector3(0, 0.04 * s, -0.17 * s), Vector3.ZERO, Vector3(0.38 * s, 0.30 * s, 0.48 * s)), col, flash)
	put_part("box", _xf(root, Vector3(0, 0.19 * s, -0.17 * s), Vector3.ZERO, Vector3(0.08 * s, 0.025 * s, 0.14 * s)), Color(0.95, 0.22, 0.10), flash)
	put_part("sphere", _xf(root, Vector3(0, -0.01 * s, 0.14 * s), Vector3.ZERO, Vector3(0.24 * s, 0.18 * s, 0.24 * s)), col.darkened(0.15), flash)
	for msg in [-1.0, 1.0]:
		put_part("cone", _xf(root, Vector3(msg * 0.05 * s, -0.04 * s, 0.25 * s), Vector3(1.1, 0, 0), Vector3(0.04 * s, 0.10 * s, 0.04 * s)), Color(0.12, 0.09, 0.09), flash)
	for i in range(4):
		var a := sin(phase * 1.6 + float(i) * 1.3) * 0.38
		var z := (-0.14 + float(i) * 0.10) * s
		for sd in [-1.0, 1.0]:
			var l_hip := _xf(root, Vector3(sd * 0.10 * s, 0.0, z), Vector3(0, -sd * a, sd * 0.55), Vector3.ONE)
			put_part("box", _xf(l_hip, Vector3(sd * 0.12 * s, 0.05 * s, 0), Vector3(0, 0, -sd * 0.42), Vector3(0.24 * s, 0.042 * s, 0.042 * s)), col.darkened(0.22), flash)
			put_part("box", _xf(l_hip, Vector3(sd * 0.28 * s, -0.08 * s, 0), Vector3(0, 0, sd * 0.85), Vector3(0.24 * s, 0.036 * s, 0.036 * s)), col.darkened(0.30), flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.05 * s, 0.04 * s, 0.24 * s)
		var er := root * Vector3(0.05 * s, 0.04 * s, 0.24 * s)
		push_glow(el, eye_col, 0.05 * s, 1.2)
		push_glow(er, eye_col, 0.05 * s, 1.2)
		push_glow((el + er) * 0.5, eye_col, 0.42 * s, 0.14)


func shatter_from_call(draw_fn: Callable, impulse: Vector3) -> void:
	capture_buf.clear()
	capturing = true
	draw_fn.call()
	capturing = false
	for item in capture_buf:
		if debris.size() > 260:
			break
		debris.append({
			"kind": item["kind"],
			"xf": item["xf"],
			"col": item["col"],
			"vel": impulse + Vector3(randf_range(-2.2, 2.2), randf_range(2.2, 5.2), randf_range(-2.2, 2.2)),
			"spin": Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"life": randf_range(0.9, 1.8),
			"max_life": 1.8,
		})
	capture_buf.clear()


func update_debris(dt: float, terrain: CWTerrain) -> void:
	var i := debris.size() - 1
	while i >= 0:
		var d: Dictionary = debris[i]
		d["life"] = float(d["life"]) - dt
		if float(d["life"]) <= 0.0:
			debris.remove_at(i)
			i -= 1
			continue
		var vel: Vector3 = d["vel"]
		vel.y -= 15.0 * dt
		var xf: Transform3D = d["xf"]
		xf.origin += vel * dt
		var gy := terrain.height_at(xf.origin.x, xf.origin.z) + 0.06
		if xf.origin.y < gy:
			xf.origin.y = gy
			vel.y = absf(vel.y) * 0.38
			vel.x *= 0.65
			vel.z *= 0.65
		var sp: Vector3 = d["spin"]
		xf.basis = xf.basis.rotated(Vector3.RIGHT, sp.x * dt).rotated(Vector3.UP, sp.y * dt)
		d["vel"] = vel
		d["xf"] = xf
		var shrink := clampf(float(d["life"]) * 2.5, 0.0, 1.0)
		var draw_xf := Transform3D(xf.basis.scaled(Vector3.ONE * shrink), xf.origin)
		put_part(d["kind"], draw_xf, d["col"], 0.0)
		i -= 1


func clear_debris() -> void:
	debris.clear()
