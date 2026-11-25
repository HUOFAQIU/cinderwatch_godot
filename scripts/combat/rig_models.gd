class_name CWRigModels
extends RefCounted

# Procedural archetype geometry builders (humanoid, quadruped, slime, flyer, bug)

static func draw_humanoid(rig: CWRig, pos: Vector3, yaw: float, scale_v: float, phase: float, swing: float, body_col: Color, accent_col: Color, flash: float, opts: Dictionary = {}) -> void:
	var s := scale_v
	if opts.get("wraith", false):
		rig._cur_pid = 6.0; rig._cur_piv = Vector3.ZERO
		var t_w := Time.get_ticks_msec() * 0.001 + pos.x * 0.7
		var wr := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(0.16 * float(opts.get("mv", 1.0)), 0.0, sin(t_w * 1.3) * 0.06)), pos + Vector3(0.0, (0.24 + sin(t_w * 2.1) * 0.07) * s, 0.0))
		var rc := Color(0.18, 0.23, 0.31)
		var rcd := Color(0.11, 0.14, 0.20)
		rig.put_part("cone", rig._xf(wr, Vector3(0, 0.50 * s, 0), Vector3.ZERO, Vector3(0.36 * s, 0.96 * s, 0.36 * s)), rc, flash)
		rig.put_part("sphere", rig._xf(wr, Vector3(0, 0.90 * s, -0.02 * s), Vector3.ZERO, Vector3(0.42 * s, 0.20 * s, 0.32 * s)), rcd, flash)
		rig.put_part("sphere", rig._xf(wr, Vector3(0, 1.05 * s, -0.03 * s), Vector3.ZERO, Vector3(0.36 * s, 0.34 * s, 0.36 * s)), rcd, flash)
		rig.put_part("sphere", rig._xf(wr, Vector3(0, 1.03 * s, 0.05 * s), Vector3.ZERO, Vector3(0.22 * s, 0.24 * s, 0.22 * s)), Color(0.82, 0.78, 0.70), flash)
		for esg in [-1.0, 1.0]:
			rig.put_part("box", rig._xf(wr, Vector3(esg * 0.045 * s, 1.04 * s, 0.15 * s), Vector3.ZERO, Vector3(0.042 * s, 0.042 * s, 0.03 * s)), Color(0.04, 0.04, 0.05), flash)
		if opts.has("eye"):
			var wec: Color = opts["eye"]
			rig.push_glow(wr * Vector3(-0.045 * s, 1.04 * s, 0.16 * s), wec, 0.05 * s, 1.1)
			rig.push_glow(wr * Vector3(0.045 * s, 1.04 * s, 0.16 * s), wec, 0.05 * s, 1.1)
		for asg in [-1.0, 1.0]:
			var wa := rig._xf(wr, Vector3(asg * 0.22 * s, 0.84 * s, 0.04 * s), Vector3(-0.25 + sin(t_w * 1.7 + asg) * 0.22, asg * -0.25, 0.0), Vector3.ONE)
			rig.put_part("box", rig._xf(wa, Vector3(0, -0.06 * s, 0.14 * s), Vector3(0.35, 0, 0), Vector3(0.09 * s, 0.09 * s, 0.30 * s)), rcd, flash)
			rig.put_part("cone", rig._xf(wa, Vector3(0, -0.14 * s, 0.32 * s), Vector3(1.1, 0, 0), Vector3(0.05 * s, 0.14 * s, 0.05 * s)), Color(0.80, 0.76, 0.68), flash)
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
		rig._cur_pid = 1.0 if side < 0 else 2.0
		rig._cur_piv = Vector3(float(side) * hip_off, 0.46 * s, 0.0)
		var ta := thigh_a if side < 0 else -thigh_a
		var ka := knee_l if side < 0 else knee_r
		var u_leg := rig._xf(root, Vector3(float(side) * hip_off, 0.46 * s, 0.0), Vector3(ta, 0, 0), Vector3.ONE)
		rig.put_part("box", rig._xf(u_leg, Vector3(0, -0.12 * s, 0), Vector3.ZERO, Vector3(leg_w, 0.25 * s, leg_w)), body_col if is_skel else body_col.darkened(0.16), flash)
		var l_leg := rig._xf(u_leg, Vector3(0, -0.24 * s, 0), Vector3(ka, 0, 0), Vector3.ONE)
		rig.put_part("box", rig._xf(l_leg, Vector3(0, -0.12 * s, 0), Vector3.ZERO, Vector3(shin_w, 0.24 * s, shin_w)), bone_d if is_skel else body_col.darkened(0.24), flash)
		if is_skel:
			rig.put_part("box", rig._xf(l_leg, Vector3(0, -0.23 * s, 0.04 * s), Vector3.ZERO, Vector3(0.082 * s, 0.046 * s, 0.16 * s)), bone_d, flash)

	# Pelvis & Torso (exact 50-rig.js:48-55 spine + 3 rib bars + collarbone + sternum for skeletons)
	rig._cur_pid = 3.0; rig._cur_piv = Vector3(0.0, 0.56 * s, 0.0)
	var torso_w := (0.38 if is_skel else 0.44) * s if opts.get("heavy", false) else (0.31 if is_skel else 0.32) * s
	rig.put_part("box", rig._xf(root, Vector3(0, 0.50 * s, 0), Vector3.ZERO, Vector3(torso_w * (0.78 if is_skel else 0.85), (0.09 if is_skel else 0.12) * s, (0.13 if is_skel else 0.18) * s)), bone_d if is_skel else body_col.darkened(0.1), flash)
	var fz := float(opts.get("flinch", 0.0))
	var cast_u := float(opts.get("cast", 0.0))
	var torso := rig._xf(root, Vector3(0, 0.56 * s, atk_lunge * 0.45 * s - fz * 0.05 * s), Vector3(lean - fz * 0.28, atk_twist, 0), Vector3.ONE)
	if is_skel:
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.21 * s, -0.03 * s), Vector3.ZERO, Vector3(0.065 * s, 0.42 * s, 0.065 * s)), bone_d, flash)
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.25 * s, 0.095 * s), Vector3.ZERO, Vector3(0.055 * s, 0.24 * s, 0.03 * s)), body_col, flash)
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.42 * s, 0.0), Vector3.ZERO, Vector3(0.37 * s, 0.065 * s, 0.11 * s)), body_col, flash)
		for ry: float in [0.15, 0.24, 0.33]:
			var rw: float = (0.29 - (0.33 - ry) * 0.24) * s
			rig.put_part("box", rig._xf(torso, Vector3(0, ry * s, 0.01 * s), Vector3.ZERO, Vector3(rw, 0.048 * s, 0.19 * s)), body_col, flash)
	else:
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.22 * s, 0), Vector3.ZERO, Vector3(torso_w, 0.44 * s, 0.22 * s)), body_col, flash)

	# Head + Jaw + Dark Eye Sockets + Eye Glow
	var head := rig._xf(torso, Vector3(0, 0.48 * s, 0.03 * s), Vector3(-lean * 0.5, 0, 0), Vector3.ONE)
	if is_skel:
		rig.put_part("sphere", rig._xf(head, Vector3(0, 0.16 * s, 0), Vector3.ZERO, Vector3(0.27 * s, 0.26 * s, 0.29 * s)), accent_col, flash)
		rig.put_part("box", rig._xf(head, Vector3(0, 0.04 * s, 0.035 * s), Vector3.ZERO, Vector3(0.16 * s, 0.075 * s, 0.13 * s)), bone_d, flash)
		var dark_sk := Color(0.05, 0.04, 0.04)
		for esg in [-1.0, 1.0]:
			rig.put_part("box", rig._xf(head, Vector3(esg * 0.056 * s, 0.17 * s, 0.128 * s), Vector3.ZERO, Vector3(0.060 * s, 0.056 * s, 0.04 * s)), dark_sk, flash)
		rig.put_part("box", rig._xf(head, Vector3(0, 0.11 * s, 0.145 * s), Vector3.ZERO, Vector3(0.028 * s, 0.036 * s, 0.035 * s)), dark_sk, flash)
	else:
		rig.put_part("sphere", rig._xf(head, Vector3(0, 0.13 * s, 0), Vector3.ZERO, Vector3(0.28 * s, 0.29 * s, 0.28 * s)), accent_col, flash)
	if opts.has("eye"):
		var ec: Color = opts["eye"]
		var ey_y := 0.17 if is_skel else 0.14
		var e_l := head * Vector3(-0.056 * s, ey_y * s, 0.145 * s)
		var e_r := head * Vector3(0.056 * s, ey_y * s, 0.145 * s)
		rig.push_glow(e_l, ec, 0.052 * s, 1.05)
		rig.push_glow(e_r, ec, 0.052 * s, 1.05)
		rig.push_glow((e_l + e_r) * 0.5, ec, 0.44 * s, 0.10)

	if opts.get("horns", false):
		for sg in [-1.0, 1.0]:
			rig.put_part("cone", rig._xf(head, Vector3(sg * 0.16 * s, 0.28 * s, 0.02 * s), Vector3(0.2, 0, -sg * 0.45), Vector3(0.08 * s, 0.24 * s, 0.08 * s)), Color(0.75, 0.70, 0.60), flash)
	if opts.get("armor_suit", false):
		var ir := Color(0.32, 0.34, 0.38)
		var irl := Color(0.48, 0.50, 0.56)
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.27 * s, 0), Vector3.ZERO, Vector3(0.34 * s, 0.30 * s, 0.24 * s)), ir, flash)
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.29 * s, 0.01 * s), Vector3.ZERO, Vector3(0.20 * s, 0.20 * s, 0.25 * s)), irl, flash)
		for psg in [-1.0, 1.0]:
			rig.put_part("sphere", rig._xf(torso, Vector3(psg * 0.21 * s, 0.42 * s, 0), Vector3.ZERO, Vector3(0.18 * s, 0.15 * s, 0.20 * s)), irl, flash)
		rig.put_part("sphere", rig._xf(head, Vector3(0, 0.18 * s, 0), Vector3.ZERO, Vector3(0.33 * s, 0.26 * s, 0.35 * s)), ir, flash)
		rig.put_part("box", rig._xf(head, Vector3(0, 0.16 * s, 0.175 * s), Vector3.ZERO, Vector3(0.035 * s, 0.12 * s, 0.03 * s)), irl, flash)
		rig.put_part("cone", rig._xf(head, Vector3(0, 0.36 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.15 * s, 0.055 * s)), irl, flash)
	if opts.get("wraps", false):
		var wc := Color(0.76, 0.70, 0.54)
		for wk in [[0.13, 0.30, 0.10], [0.21, 0.33, -0.12], [0.29, 0.35, 0.08], [0.37, 0.36, -0.06]]:
			rig.put_part("box", rig._xf(torso, Vector3(0, float(wk[0]) * s, 0), Vector3(0, 0, float(wk[2])), Vector3(float(wk[1]) * s, 0.05 * s, 0.23 * s)), wc, flash)
		rig.put_part("cyl", rig._xf(head, Vector3(0, 0.24 * s, 0), Vector3.ZERO, Vector3(0.30 * s, 0.08 * s, 0.30 * s)), wc, flash)
	if opts.get("crown", false):
		var gc := Color(0.92, 0.74, 0.20)
		rig.put_part("cyl", rig._xf(head, Vector3(0, 0.28 * s, 0), Vector3.ZERO, Vector3(0.30 * s, 0.08 * s, 0.30 * s)), gc, flash)
		for ca in range(6):
			var c_ang := float(ca) * 1.0472
			rig.put_part("cone", rig._xf(head, Vector3(cos(c_ang) * 0.14 * s, 0.36 * s, sin(c_ang) * 0.14 * s), Vector3.ZERO, Vector3(0.05 * s, 0.12 * s, 0.05 * s)), gc, flash)
		rig.put_part("sphere", rig._xf(head, Vector3(0, 0.29 * s, 0.15 * s), Vector3.ZERO, Vector3.ONE * 0.055 * s), Color(0.2, 0.9, 0.8), maxf(flash, 0.4))
	elif opts.get("hood", false):
		rig.put_part("cone", rig._xf(head, Vector3(0, 0.22 * s, -0.02 * s), Vector3(-0.15, 0, 0), Vector3(0.36 * s, 0.34 * s, 0.36 * s)), Color(0.22, 0.18, 0.28), flash)

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
	rig._cur_pid = 4.0; rig._cur_piv = Vector3(-arm_off, 0.95 * s, 0.0)
	var l_uarm := rig._xf(torso, Vector3(-arm_off, 0.39 * s, 0), Vector3(l_sh, 0, 0.14), Vector3.ONE)
	rig.put_part("box", rig._xf(l_uarm, Vector3(0, -0.11 * s, 0), Vector3.ZERO, Vector3(ua_w, 0.22 * s, ua_w)), body_col, flash)
	var l_larm := rig._xf(l_uarm, Vector3(0, -0.22 * s, 0), Vector3(-0.55 if has_torch else -0.45, 0, 0), Vector3.ONE)
	rig.put_part("box", rig._xf(l_larm, Vector3(0, -0.10 * s, 0), Vector3.ZERO, Vector3(la_w, 0.20 * s, la_w)), bone_d if is_skel else body_col.darkened(0.08), flash)

	rig._cur_pid = 5.0; rig._cur_piv = Vector3(arm_off, 0.95 * s, 0.0)
	var r_uarm := rig._xf(torso, Vector3(arm_off, 0.39 * s, 0), Vector3(r_sh, 0, -0.14), Vector3.ONE)
	rig.put_part("box", rig._xf(r_uarm, Vector3(0, -0.11 * s, 0), Vector3.ZERO, Vector3(ua_w, 0.22 * s, ua_w)), body_col, flash)
	var r_larm := rig._xf(r_uarm, Vector3(0, -0.22 * s, 0), Vector3(-0.45 + (atk_arm * 0.35 if has_atk else 0.0), 0, 0), Vector3.ONE)
	rig.put_part("box", rig._xf(r_larm, Vector3(0, -0.10 * s, 0), Vector3.ZERO, Vector3(la_w, 0.20 * s, la_w)), bone_d if is_skel else body_col.darkened(0.08), flash)

	# Weapons & Special Gear
	if opts.get("bow", false):
		rig._cur_pid = 4.0; rig._cur_piv = Vector3(-arm_off, 0.95 * s, 0.0)
		rig.put_part("box", rig._xf(l_larm, Vector3(0, -0.18 * s, 0.14 * s), Vector3.ZERO, Vector3(0.04 * s, 0.52 * s, 0.06 * s)), Color(0.58, 0.40, 0.22), flash)
	elif opts.get("keg", false):
		rig._cur_pid = 3.0; rig._cur_piv = Vector3(0.0, 0.56 * s, 0.0)
		rig.put_part("cyl", rig._xf(torso, Vector3(0, 0.26 * s, 0.24 * s), Vector3(0, 0, PI * 0.5), Vector3(0.28 * s, 0.36 * s, 0.28 * s)), Color(0.55, 0.25, 0.12), flash)
		rig.put_part("sphere", rig._xf(torso, Vector3(0.04 * s, 0.44 * s, 0.24 * s), Vector3.ZERO, Vector3.ONE * 0.08 * s), Color(1.0, 0.55, 0.15), maxf(flash, 0.75))
	elif opts.get("staff", false):
		rig.put_part("cyl", rig._xf(r_larm, Vector3(0, -0.14 * s, 0.18 * s), Vector3(0.45, 0, 0), Vector3(0.05 * s, 0.95 * s, 0.05 * s)), Color(0.32, 0.22, 0.14), flash)
		rig.put_part("sphere", rig._xf(r_larm, Vector3(0, 0.12 * s, 0.42 * s), Vector3.ZERO, Vector3.ONE * 0.14 * s), Color(0.35, 1.0, 0.5), maxf(flash, 0.7))
	elif opts.get("iceclub", false):
		rig.put_part("cyl", rig._xf(r_larm, Vector3(0, -0.16 * s, 0.24 * s), Vector3(0.6, 0, 0), Vector3(0.09 * s, 0.72 * s, 0.09 * s)), Color(0.55, 0.85, 1.1), maxf(flash, 0.3))
	elif opts.get("greatsword", false):
		# Upstream 50-rig.js:119-126 Bone Giant notched steel greatsword
		var gs_base := rig._xf(r_larm, Vector3(0, -0.14 * s, 0.16 * s), Vector3(0.55, 0, 0), Vector3.ONE)
		var steel := Color(0.72, 0.68, 0.64)
		var dark_i := Color(0.24, 0.25, 0.28)
		rig.put_part("box", rig._xf(gs_base, Vector3(0, -0.02 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.26 * s, 0.055 * s)), Color(0.32, 0.20, 0.12), flash)
		rig.put_part("sphere", rig._xf(gs_base, Vector3(0, -0.17 * s, 0), Vector3.ZERO, Vector3.ONE * 0.08 * s), Color(0.84, 0.80, 0.72), flash)
		rig.put_part("box", rig._xf(gs_base, Vector3(0, 0.12 * s, 0), Vector3.ZERO, Vector3(0.36 * s, 0.055 * s, 0.08 * s)), dark_i, flash)
		rig.put_part("box", rig._xf(gs_base, Vector3(0, 0.56 * s, 0), Vector3.ZERO, Vector3(0.12 * s, 0.84 * s, 0.032 * s)), steel, flash)
		rig.put_part("box", rig._xf(gs_base, Vector3(0, 0.52 * s, 0), Vector3.ZERO, Vector3(0.038 * s, 0.70 * s, 0.042 * s)), steel.darkened(0.35), flash)
		rig.put_part("cone", rig._xf(gs_base, Vector3(0, 1.06 * s, 0), Vector3.ZERO, Vector3(0.12 * s, 0.20 * s, 0.034 * s)), steel, flash)
	elif opts.get("weapon", false):
		var sw_base := rig._xf(r_larm, Vector3(0, -0.16 * s, 0.06 * s), Vector3(1.12, 0, 0), Vector3.ONE)
		var blade_c := Color(0.56, 0.44, 0.36) if is_skel else Color(0.76, 0.80, 0.88)
		var guard_c := Color(0.28, 0.30, 0.34) if is_skel else Color(0.84, 0.68, 0.26)
		rig.put_part("box", rig._xf(sw_base, Vector3.ZERO, Vector3.ZERO, Vector3(0.036 * s, 0.13 * s, 0.036 * s)), Color(0.30, 0.20, 0.12), flash)
		rig.put_part("box", rig._xf(sw_base, Vector3(0, 0.075 * s, 0), Vector3.ZERO, Vector3(0.17 * s, 0.032 * s, 0.05 * s)), guard_c, flash)
		rig.put_part("box", rig._xf(sw_base, Vector3(0, 0.33 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.48 * s, 0.02 * s)), blade_c, flash)
		rig.put_part("cone", rig._xf(sw_base, Vector3(0, 0.61 * s, 0), Vector3.ZERO, Vector3(0.055 * s, 0.09 * s, 0.022 * s)), blade_c, flash)

	rig._cur_pid = 4.0; rig._cur_piv = Vector3(-arm_off, 0.95 * s, 0.0)
	if opts.get("shield", false):
		if is_skel:
			# Round iron-rimmed wooden shield (50-rig.js:78)
			rig.put_part("cyl", rig._xf(l_larm, Vector3(-0.07 * s, -0.10 * s, 0.10 * s), Vector3(0, 0, PI * 0.5), Vector3(0.46 * s, 0.05 * s, 0.46 * s)), Color(0.32, 0.21, 0.12), flash)
			rig.put_part("sphere", rig._xf(l_larm, Vector3(-0.10 * s, -0.10 * s, 0.10 * s), Vector3.ZERO, Vector3(0.08 * s, 0.14 * s, 0.14 * s)), Color(0.55, 0.58, 0.64), flash)
		else:
			rig.put_part("box", rig._xf(l_larm, Vector3(-0.08 * s, -0.12 * s, 0.12 * s), Vector3(0, 0.3, 0), Vector3(0.06 * s, 0.38 * s, 0.32 * s)), Color(0.36, 0.46, 0.62), flash)
	elif has_torch:
		# Torch gripped directly in raised left hand (50-rig.js:202 RIGOUT.torch)
		var hand_l := rig._xf(l_larm, Vector3(0.0, -0.18 * s, 0.02 * s), Vector3(1.22, 0.0, -0.10), Vector3.ONE)
		rig.put_part("cyl", rig._xf(hand_l, Vector3(0.0, 0.14 * s, 0.0), Vector3.ZERO, Vector3(0.045 * s, 0.44 * s, 0.045 * s)), Color(0.38, 0.24, 0.13), flash)
		var t_tip := rig._xf(hand_l, Vector3(0.0, 0.36 * s, 0.0), Vector3.ZERO, Vector3(0.085 * s, 0.085 * s, 0.085 * s))
		rig.put_part("sphere", t_tip, Color(0.95, 0.38, 0.08), 0.55)
		rig.last_torch_pos = t_tip.origin

	rig._cur_pid = 3.0; rig._cur_piv = Vector3(0.0, 0.56 * s, 0.0)
	if opts.get("drum", false):
		rig.put_part("cyl", rig._xf(torso, Vector3(0, 0.12 * s, 0.26 * s), Vector3(0.45, 0, 0), Vector3(0.32 * s, 0.22 * s, 0.32 * s)), Color(0.55, 0.20, 0.16), flash)
		rig.put_part("cyl", rig._xf(torso, Vector3(0, 0.56 * s, -0.16 * s), Vector3.ZERO, Vector3(0.04 * s, 0.95 * s, 0.04 * s)), Color(0.42, 0.30, 0.20), flash)
		rig.put_part("box", rig._xf(torso, Vector3(0, 0.92 * s, -0.18 * s), Vector3.ZERO, Vector3(0.36 * s, 0.44 * s, 0.04 * s)), Color(0.68, 0.22, 0.18), flash)


static func draw_quadruped(rig: CWRig, pos: Vector3, yaw: float, scale_v: float, phase: float, body_col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0) -> void:
	var s := scale_v
	var lng := sin(clampf(swing, 0.0, 1.0) * PI)
	rig._cur_pid = 13.0; rig._cur_piv = Vector3.ZERO
	var root := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lng * 0.35), pos + Vector3(0.0, (0.26 + lng * 0.16) * s, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, lng * 0.28 * s))
	rig.put_part("box", rig._xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.24 * s, 0.20 * s, 0.56 * s)), body_col, flash)
	rig.put_part("cone", rig._xf(root, Vector3(0.0, 0.10 * s, 0.34 * s), Vector3(PI * 0.45, 0, 0), Vector3(0.20 * s, 0.28 * s, 0.20 * s)), body_col.lightened(0.12), flash)
	for sg in [-1.0, 1.0]:
		rig.put_part("cone", rig._xf(root, Vector3(sg * 0.07 * s, 0.22 * s, 0.28 * s), Vector3.ZERO, Vector3(0.06 * s, 0.12 * s, 0.06 * s)), body_col.darkened(0.15), flash)
	rig.put_part("box", rig._xf(root, Vector3(0.0, 0.04 * s, -0.34 * s), Vector3(-0.35, 0, 0), Vector3(0.07 * s, 0.07 * s, 0.26 * s)), body_col.darkened(0.2), flash)
	var l := sin(phase) * 0.72
	for sx in [-0.11, 0.11]:
		for sz in [-0.18, 0.18]:
			rig._cur_pid = 11.0 if (sx * sz > 0) else 12.0
			rig._cur_piv = Vector3(sx * s, 0.24 * s, sz * s)
			var a := l if (sx * sz > 0) else -l
			rig.put_part("box", rig._xf(root, Vector3(sx * s, -0.14 * s, sz * s), Vector3(a, 0, 0), Vector3(0.07 * s, 0.24 * s, 0.07 * s)), body_col.darkened(0.2), flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.055 * s, 0.14 * s, 0.42 * s)
		var er := root * Vector3(0.055 * s, 0.14 * s, 0.42 * s)
		rig.push_glow(el, eye_col, 0.055 * s, 1.2)
		rig.push_glow(er, eye_col, 0.055 * s, 1.2)
		rig.push_glow((el + er) * 0.5, eye_col, 0.45 * s, 0.14)


static func draw_slime(rig: CWRig, pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0, is_toad: bool = false) -> void:
	rig._cur_pid = 20.0; rig._cur_piv = Vector3.ZERO
	if is_toad:
		var hop_t := maxf(absf(sin(phase)), sin(clampf(swing, 0.0, 1.0) * PI) * 1.2)
		var sq_t := lerpf(0.84, 1.12, hop_t)
		var tr_xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -hop_t * 0.28), pos + Vector3(0.0, (0.14 + hop_t * 0.46) * scale_v, 0.0))
		var tc := col
		var tcd := col.darkened(0.28)
		var pale := Color(0.46, 0.46, 0.28)
		rig.put_part("sphere", rig._xf(tr_xf, Vector3(0, 0.12 * scale_v, -0.02 * scale_v), Vector3.ZERO, Vector3(0.56 * scale_v, 0.36 * scale_v * sq_t, 0.62 * scale_v)), tc, flash)
		rig.put_part("sphere", rig._xf(tr_xf, Vector3(0, 0.05 * scale_v, 0.18 * scale_v), Vector3.ZERO, Vector3(0.30 * scale_v, 0.18 * scale_v, 0.24 * scale_v)), pale, flash)
		for bsg in [-1.0, 1.0]:
			rig.put_part("sphere", rig._xf(tr_xf, Vector3(bsg * 0.12 * scale_v, 0.31 * scale_v, 0.20 * scale_v), Vector3.ZERO, Vector3.ONE * 0.14 * scale_v), tcd, flash)
			rig.put_part("box", rig._xf(tr_xf, Vector3(bsg * 0.20 * scale_v, 0.04 * scale_v, -0.14 * scale_v), Vector3(-hop_t * 0.65, 0, 0), Vector3(0.12 * scale_v, 0.16 * scale_v, 0.26 * scale_v)), tcd, flash)
			rig.put_part("box", rig._xf(tr_xf, Vector3(bsg * 0.24 * scale_v, -0.03 * scale_v, 0.26 * scale_v), Vector3.ZERO, Vector3(0.08 * scale_v, 0.05 * scale_v, 0.11 * scale_v)), tcd, flash)
		if eye_col.r + eye_col.g + eye_col.b > 0.01:
			rig.push_glow(tr_xf * Vector3(-0.12 * scale_v, 0.33 * scale_v, 0.27 * scale_v), eye_col, 0.055 * scale_v, 1.15)
			rig.push_glow(tr_xf * Vector3(0.12 * scale_v, 0.33 * scale_v, 0.27 * scale_v), eye_col, 0.055 * scale_v, 1.15)
		return
	var hop := maxf(absf(sin(phase)), sin(clampf(swing, 0.0, 1.0) * PI) * 1.25)
	var sq_y := lerpf(0.72, 1.28, hop)
	var sq_xz := 1.0 / sqrt(sq_y)
	var root := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0.0, hop * 0.35 * scale_v + 0.26 * scale_v * sq_y, 0.0))
	rig.put_part("sphere", rig._xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.70 * scale_v * sq_xz, 0.56 * scale_v * sq_y, 0.70 * scale_v * sq_xz)), col, flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.11 * scale_v, 0.08 * scale_v, 0.30 * scale_v)
		var er := root * Vector3(0.11 * scale_v, 0.08 * scale_v, 0.30 * scale_v)
		rig.push_glow(el, eye_col, 0.06 * scale_v, 1.2)
		rig.push_glow(er, eye_col, 0.06 * scale_v, 1.2)
		rig.push_glow((el + er) * 0.5, eye_col, 0.50 * scale_v, 0.14)


static func draw_flyer(rig: CWRig, pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, is_wisp: bool = false, eye_col: Color = Color.BLACK, is_garg: bool = false) -> void:
	rig._cur_pid = 33.0; rig._cur_piv = Vector3.ZERO
	if is_wisp:
		var wroot := Transform3D(Basis(Vector3.UP, yaw), pos)
		rig.put_part("sphere", rig._xf(wroot, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.28 * scale_v), col, maxf(flash, 0.75))
		rig.push_glow(pos, col, 0.75 * scale_v, 0.22)
		return
	# Matches 50-rig.js:231-238: body bob/pitch/bank + shoulder-pivoted wing flap
	var s := scale_v
	var body_pos := pos + Vector3(0.0, sin(phase * 0.5) * 0.08 * s, 0.0)
	var body_rot := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(-0.25, 0.0, sin(phase * 0.25) * 0.15))
	var root := Transform3D(body_rot, body_pos)
	var flap := sin(phase) * 0.85 + 0.15
	rig.put_part("sphere", rig._xf(root, Vector3.ZERO, Vector3.ZERO, Vector3(0.24 * s, 0.18 * s, 0.32 * s)), col, flash)
	var l_sh := rig._xf(root, Vector3(-0.08 * s, 0.02 * s, 0.0), Vector3(0.0, 0.0, -flap), Vector3.ONE)
	var r_sh := rig._xf(root, Vector3(0.08 * s, 0.02 * s, 0.0), Vector3(0.0, 0.0, flap), Vector3.ONE)
	rig._cur_pid = 31.0; rig._cur_piv = Vector3(-0.08 * s, 0.02 * s, 0.0)
	rig.put_part("box", rig._xf(l_sh, Vector3(-0.25 * s, 0.0, 0.0), Vector3.ZERO, Vector3(0.50 * s, 0.04 * s, 0.24 * s)), col.darkened(0.15), flash)
	rig._cur_pid = 32.0; rig._cur_piv = Vector3(0.08 * s, 0.02 * s, 0.0)
	rig.put_part("box", rig._xf(r_sh, Vector3(0.25 * s, 0.0, 0.0), Vector3.ZERO, Vector3(0.50 * s, 0.04 * s, 0.24 * s)), col.darkened(0.15), flash)
	rig._cur_pid = 33.0; rig._cur_piv = Vector3.ZERO
	if is_garg:
		# Sculpted stone horns, snout & barbed tail on Gargoyle (51-bestiary.js:108-115)
		var gd := col.darkened(0.25)
		rig.put_part("box", rig._xf(root, Vector3(0, 0.05 * s, 0.22 * s), Vector3.ZERO, Vector3(0.12 * s, 0.09 * s, 0.16 * s)), gd, flash)
		rig.put_part("box", rig._xf(root, Vector3(0, -0.08 * s, -0.26 * s), Vector3(-0.35, 0, 0), Vector3(0.05 * s, 0.05 * s, 0.28 * s)), gd, flash)
		for gsg in [-1.0, 1.0]:
			rig.put_part("cone", rig._xf(root, Vector3(gsg * 0.09 * s, 0.18 * s, 0.06 * s), Vector3(-0.35, 0, -gsg * 0.35), Vector3(0.05 * s, 0.16 * s, 0.05 * s)), gd, flash)
			rig.put_part("box", rig._xf(root, Vector3(gsg * 0.12 * s, -0.12 * s, 0.10 * s), Vector3(0.4, 0, 0), Vector3(0.05 * s, 0.18 * s, 0.05 * s)), gd, flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.05 * scale_v, 0.03 * scale_v, 0.16 * scale_v)
		var er := root * Vector3(0.05 * scale_v, 0.03 * scale_v, 0.16 * scale_v)
		rig.push_glow(el, eye_col, 0.055 * scale_v, 1.2)
		rig.push_glow(er, eye_col, 0.055 * scale_v, 1.2)
		rig.push_glow(pos, eye_col, 0.48 * scale_v, 0.13)


static func draw_bug(rig: CWRig, pos: Vector3, yaw: float, scale_v: float, phase: float, col: Color, flash: float, eye_col: Color = Color.BLACK, swing: float = 0.0) -> void:
	rig._cur_pid = 43.0; rig._cur_piv = Vector3.ZERO
	var s := scale_v
	var lng := sin(clampf(swing, 0.0, 1.0) * PI)
	var root := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lng * 0.32), pos + Vector3(0.0, (0.18 + lng * 0.12) * s, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, lng * 0.24 * s))
	rig.put_part("sphere", rig._xf(root, Vector3(0, 0.04 * s, -0.17 * s), Vector3.ZERO, Vector3(0.38 * s, 0.30 * s, 0.48 * s)), col, flash)
	rig.put_part("box", rig._xf(root, Vector3(0, 0.19 * s, -0.17 * s), Vector3.ZERO, Vector3(0.08 * s, 0.025 * s, 0.14 * s)), Color(0.95, 0.22, 0.10), flash)
	rig.put_part("sphere", rig._xf(root, Vector3(0, -0.01 * s, 0.14 * s), Vector3.ZERO, Vector3(0.24 * s, 0.18 * s, 0.24 * s)), col.darkened(0.15), flash)
	for msg in [-1.0, 1.0]:
		rig.put_part("cone", rig._xf(root, Vector3(msg * 0.05 * s, -0.04 * s, 0.25 * s), Vector3(1.1, 0, 0), Vector3(0.04 * s, 0.10 * s, 0.04 * s)), Color(0.12, 0.09, 0.09), flash)
	for i in range(4):
		var a := sin(phase * 1.6 + float(i) * 1.3) * 0.38
		var z := (-0.14 + float(i) * 0.10) * s
		for sd in [-1.0, 1.0]:
			rig._cur_pid = 41.0 if ((i + (0 if sd < 0.0 else 1)) % 2 == 0) else 42.0
			rig._cur_piv = Vector3(sd * 0.10 * s, 0.18 * s, z)
			var l_hip := rig._xf(root, Vector3(sd * 0.10 * s, 0.0, z), Vector3(0, -sd * a, sd * 0.55), Vector3.ONE)
			rig.put_part("box", rig._xf(l_hip, Vector3(sd * 0.12 * s, 0.05 * s, 0), Vector3(0, 0, -sd * 0.42), Vector3(0.24 * s, 0.042 * s, 0.042 * s)), col.darkened(0.22), flash)
			rig.put_part("box", rig._xf(l_hip, Vector3(sd * 0.28 * s, -0.08 * s, 0), Vector3(0, 0, sd * 0.85), Vector3(0.24 * s, 0.036 * s, 0.036 * s)), col.darkened(0.30), flash)
	if eye_col.r + eye_col.g + eye_col.b > 0.01:
		var el := root * Vector3(-0.05 * s, 0.04 * s, 0.24 * s)
		var er := root * Vector3(0.05 * s, 0.04 * s, 0.24 * s)
		rig.push_glow(el, eye_col, 0.05 * s, 1.2)
		rig.push_glow(er, eye_col, 0.05 * s, 1.2)
		rig.push_glow((el + er) * 0.5, eye_col, 0.42 * s, 0.14)


