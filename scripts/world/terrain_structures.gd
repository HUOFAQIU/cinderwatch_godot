class_name CWTerrainStructures
extends RefCounted

# Water, waterfall, bridge, tower pads, keep, and cave builders (extracted from terrain.gd)

static func _build_water_and_waterfall(t: CWTerrain, rng: CWUtil.Rng) -> void:
	var stream: Array[Vector2] = t.layout["stream"]
	if stream.size() < 2:
		return
	var soup := CWGfx.Soup.new()
	var end_y := -0.30
	var sv: Array = []
	var arc_s := 0.0
	for u in range(stream.size()):
		if u > 0:
			arc_s += stream[u].distance_to(stream[u - 1])
		var pa := stream[maxi(0, u - 1)]
		var pb := stream[mini(stream.size() - 1, u + 1)]
		var dir := (pb - pa).normalized()
		var spring_w := 0.65 * smoothstep(3.0, 0.0, arc_s)
		var wu := 0.78 + 0.12 * sin(float(u) * 0.7) + spring_w
		var nrm := Vector2(-dir.y, dir.x) * wu
		var frac_u := float(u) / float(maxi(1, stream.size() - 1))
		var sy := lerpf(-0.26, -0.36, frac_u)
		end_y = sy
		sv.append({
			"l": Vector3(stream[u].x - nrm.x, sy, stream[u].y - nrm.y),
			"r": Vector3(stream[u].x + nrm.x, sy, stream[u].y + nrm.y),
			"s": arc_s * 0.52,
			"w": wu * 0.52,
		})
	for u in range(sv.size() - 1):
		var a_d: Dictionary = sv[u]
		var b_d: Dictionary = sv[u + 1]
		var p0: Vector3 = a_d["l"]
		var p1: Vector3 = a_d["r"]
		var p2: Vector3 = b_d["r"]
		var p3: Vector3 = b_d["l"]
		var u0 := -float(a_d["w"])
		var u1 := float(a_d["w"])
		var v0_s := float(a_d["s"])
		var v1_s := float(b_d["s"])
		var q_pts: Array = [
			[p0, Vector2(u0, v0_s)], [p3, Vector2(u0, v1_s)], [p2, Vector2(u1, v1_s)],
			[p0, Vector2(u0, v0_s)], [p2, Vector2(u1, v1_s)], [p1, Vector2(u1, v0_s)],
		]
		for qp in q_pts:
			var arr_q: Array = qp
			soup.add_v(arr_q[0], Vector3.UP, Color.WHITE, arr_q[1], 0, 0.12, 1.25, 0.0)

	# Natural rocky springhead basin boulders hiding stream[0] start edge
	var src_pt := stream[0]
	var src_dir := (stream[1] - stream[0]).normalized()
	var sp_soup := CWGfx.Soup.new()
	for srk in range(7):
		var sa := atan2(src_dir.y, src_dir.x) + PI + rng.rr(-1.35, 1.35)
		var sd_r := rng.rr(0.95, 1.55)
		var srad := rng.rr(0.35, 0.68)
		var sx := src_pt.x + cos(sa) * sd_r
		var sz := src_pt.y + sin(sa) * sd_r
		var scol: Color = t.pal["stoneD"].lerp(t.pal["stone"], rng.next_f())
		sp_soup.add_rock(srad, Vector3(sx, t.height_at(sx, sz) + srad * 0.22, sz), scol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.15, 0.75, 1.05))
	if sp_soup.vert_count > 0:
		var spmi := MeshInstance3D.new()
		spmi.mesh = sp_soup.build()
		spmi.material_override = t.gfx.mat_world
		t.add_child(spmi)
		t.extra_meshes.append(spmi)

	# 14-row parabolic waterfall sheet + stone outfall lip & flanking rocks (31-terrain.js:306-315, 381-391)
	var end_pt := stream[stream.size() - 1]
	var is_front := bool(t.layout.get("stream_front", true))
	t.has_waterfall = true
	var fx := clampf(end_pt.x, -CWLayout.BH + 1.5, CWLayout.BH - 1.5) if is_front else CWLayout.BH
	var fz := CWLayout.BH if is_front else clampf(end_pt.y, -CWLayout.BH + 1.5, CWLayout.BH - 1.5)
	var ox := 0.0 if is_front else 1.0
	var oz := 1.0 if is_front else 0.0
	var ax := -oz
	var az := ox
	var ext := 0.55
	var v0 := 1.55
	var fw := 1.15
	t.waterfall_pos = Vector3(fx + ox * (ext + 0.6), end_y - 3.6, fz + oz * (ext + 0.6))

	# Stone outfall lip & 4 flanking rocks framing the waterfall mouth
	var lip_sp := CWGfx.Soup.new()
	var rc: Color = t.pal["stoneD"].lerp(t.pal["stone"], 0.45)
	var lip_c := Vector3(ox * (ext * 0.35), -0.42, oz * (ext * 0.35))
	var lip_sz := Vector3(ext + 0.7, 0.48, fw * 2.0 + 0.9) if not is_front else Vector3(fw * 2.0 + 0.9, 0.48, ext + 0.7)
	lip_sp.add_box(lip_sz, lip_c, rc, CWGfx.L_ROCK, 0.92)
	lip_sp.add_rock(fw * 0.55 + 0.15, Vector3(ox * 0.12, -0.78, oz * 0.12), t.pal["stoneD"], 701, CWGfx.L_ROCK, 0.94, Vector3(1.1, 0.55, 1.1))
	for sd2: float in [-1.0, 1.0]:
		lip_sp.add_rock(0.46, Vector3(ox * 0.08 + ax * sd2 * (fw + 0.28), 0.12, oz * 0.08 + az * sd2 * (fw + 0.28)), rc, 710 + int(sd2 + 2.0), CWGfx.L_ROCK, 0.92, Vector3(1.0, 0.72, 1.0))
		lip_sp.add_rock(0.32, Vector3(ox * (ext * 0.62) + ax * sd2 * (fw + 0.24), 0.02, oz * (ext * 0.62) + az * sd2 * (fw + 0.24)), t.pal["stoneD"], 720 + int(sd2 + 2.0), CWGfx.L_ROCK, 0.92, Vector3(1.0, 0.72, 1.0))
	var lip_mi := MeshInstance3D.new()
	lip_mi.mesh = lip_sp.build()
	lip_mi.material_override = t.gfx.mat_world
	t._attach_to_chunk(lip_mi, Vector3(fx, end_y, fz))

	# Horizontal lip extension water quad bridging stream edge to waterfall start (continuous stream UV)
	var lp0 := Vector3(fx - ax * fw, end_y, fz - az * fw)
	var lp1 := Vector3(fx + ax * fw, end_y, fz + az * fw)
	var lp2 := Vector3(fx + ox * (ext + 0.06) + ax * fw, end_y, fz + oz * (ext + 0.06) + az * fw)
	var lp3 := Vector3(fx + ox * (ext + 0.06) - ax * fw, end_y, fz + oz * (ext + 0.06) - az * fw)
	var last_s := float(sv[sv.size() - 1]["s"])
	var lip_s := last_s + (ext + 0.06) * 0.52
	var lw_u := fw * 0.52
	var lip_pts: Array = [
		[lp0, Vector2(-lw_u, last_s)], [lp3, Vector2(-lw_u, lip_s)], [lp2, Vector2(lw_u, lip_s)],
		[lp0, Vector2(-lw_u, last_s)], [lp2, Vector2(lw_u, lip_s)], [lp1, Vector2(lw_u, last_s)],
	]
	for lp in lip_pts:
		var arr_l: Array = lp
		soup.add_v(arr_l[0], Vector3.UP, Color.WHITE, arr_l[1], 0, 0.12, 1.25, 0.0)

	# 14-row parabolic curved waterfall mesh (local to (fx, end_y, fz)) using dedicated MAT.fall
	var nr := 14
	var f_verts := PackedVector3Array()
	var f_uvs := PackedVector2Array()
	var f_idx := PackedInt32Array()
	for r in range(nr + 1):
		var v := float(r) / float(nr)
		var tau := 1.3 * v
		var out_d := ext + v0 * tau
		var dy := -4.5 * tau * tau
		var ww := fw * (1.0 + 0.35 * v)
		for sd: float in [-1.0, 1.0]:
			f_verts.append(Vector3(ox * out_d + ax * ww * sd, dy, oz * out_d + az * ww * sd))
			f_uvs.append(Vector2(sd * 0.5 + 0.5, v))
	for r in range(nr):
		var a_i := r * 2
		f_idx.append(a_i); f_idx.append(a_i + 1); f_idx.append(a_i + 3)
		f_idx.append(a_i); f_idx.append(a_i + 3); f_idx.append(a_i + 2)
	var f_arr := []
	f_arr.resize(Mesh.ARRAY_MAX)
	f_arr[Mesh.ARRAY_VERTEX] = f_verts
	f_arr[Mesh.ARRAY_TEX_UV] = f_uvs
	f_arr[Mesh.ARRAY_INDEX] = f_idx
	var fall_mesh := ArrayMesh.new()
	fall_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, f_arr)
	var fall_mi := MeshInstance3D.new()
	fall_mi.mesh = fall_mesh
	fall_mi.material_override = t.gfx.mat_fall
	fall_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t._attach_to_chunk(fall_mi, Vector3(fx, end_y, fz))

	# Reflective puddles along the cobblestone road (disabled in Emberscar/Dunes)
	var bkey_w: String = String(t.bio.get("key", "ashen"))
	var road: Array[Vector2] = t.layout["road"]
	var n_road_p := 0 if (bkey_w == "ember" or bkey_w == "dunes") else 6
	for _p in range(n_road_p):
		var idx := rng.ri(8, maxi(9, road.size() - 10))
		var rp := road[idx] + Vector2(rng.rr(-0.45, 0.45), rng.rr(-0.45, 0.45))
		var py := t.height_at(rp.x, rp.y) + 0.03
		var pr := rng.rr(0.42, 0.72)
		soup.add_cyl(pr, pr, 0.02, Vector3(rp.x, py, rp.y), Color.WHITE, 8, 0, 0.08, Vector3.ZERO, 0.0, 0.0)

	t.water_mesh = MeshInstance3D.new()
	t.water_mesh.mesh = soup.build()
	t.water_mesh.material_override = t.gfx.mat_water
	t.add_child(t.water_mesh)



static func _build_bridge(t: CWTerrain) -> void:
	# 1:1 port of buildBridge() in 32-props.js:200-225 (6.2m arched masonry bridge + 9-stone arch + spandrels + 4 corner finial piers + Frost icicles)
	var road: Array[Vector2] = t.layout["road"]
	var stream: Array[Vector2] = t.layout["stream"]
	var best_d := 1e9
	var best_i := 0
	for i in range(1, road.size() - 1):
		var d := CWLayout.poly_min_dist(stream, road[i].x, road[i].y)
		if d < best_d:
			best_d = d
			best_i = i
	if best_d > 1.6:
		return
	var p := road[best_i]
	# Average road direction across the bridge span (+/-3 samples) so curved crossings align cleanly
	var dir := (road[mini(road.size() - 1, best_i + 3)] - road[maxi(0, best_i - 3)]).normalized()
	var yaw := atan2(dir.x, dir.y)
	var rng := CWUtil.Rng.new(t.seed_val + 409)
	var soup := CWGfx.Soup.new()

	var y0 := 0.06
	var bed := -0.78 - y0
	var spring := -0.22 - y0
	var w_half := CWLayout.ROAD_HALF + 0.22
	var arch_a := 1.25
	var crown := 0.18 - 0.32
	var sd_col: Color = t.pal["stoneD"]
	var sl_col: Color = t.pal["stoneL"]

	# 8-segment 4.64m arched span fits cleanly over the river without overshooting road bends
	for k in range(-4, 4):
		var u := (float(k) + 0.5) * 0.58
		var top := 0.18 * cos(clampf(u / 2.55, -1.0, 1.0) * PI * 0.5)
		if absf(u) < 1.85:
			soup.add_box(Vector3(w_half * 2.0 - 0.14, 0.16, 0.60), Vector3(0.0, top - 0.08, u), t.pal["road"], CWGfx.L_COBBLE, 0.86)
		soup.add_box(Vector3(w_half * 2.0 - 0.10, 0.24, 0.59), Vector3(0.0, top - 0.24, u), sd_col, CWGfx.L_MASON, 0.90)
		for side: float in [-1.0, 1.0]:
			var xx := side * w_half
			var mc := sd_col.lerp(sl_col, rng.next_f())
			# Crenellated parapet wall + alternating coping merlons
			soup.add_box(Vector3(0.28, 0.48, 0.59), Vector3(xx, top + 0.20, u), mc, CWGfx.L_MASON, 0.90)
			if (k & 1) == 0:
				soup.add_box(Vector3(0.34, 0.14, 0.28), Vector3(xx, top + 0.51, u), sd_col.lerp(sl_col, rng.next_f()), CWGfx.L_MASON, 0.88)
			# Masonry spandrel wall down to elliptical arch or riverbed
			var bot := (spring + (crown - spring) * sqrt(maxf(0.0, 1.0 - (u / arch_a) * (u / arch_a)))) if absf(u) < arch_a else (bed - 0.3)
			if top - 0.05 - bot > 0.04:
				soup.add_box(Vector3(0.28, top - 0.05 - bot, 0.59), Vector3(xx, (top - 0.05 + bot) * 0.5, u), sd_col.lerp(sl_col, rng.next_f()), CWGfx.L_MASON, 0.91)

	for side: float in [-1.0, 1.0]:
		var xx := side * w_half
		# 9-stone elliptical arch voussoirs
		for k in range(9):
			var th := PI * float(k) / 8.0
			var u := cos(th) * arch_a
			var ay := spring + (crown - spring) * sin(th) - 0.05
			soup.add_box(Vector3(0.36, 0.20, 0.40), Vector3(xx, ay, u), sl_col, CWGfx.L_MASON, 0.88, Vector3(th - PI * 0.5, 0.0, 0.0))
		# 4 tall corner piers with cap slabs & pyramid finials
		for u_end: float in [-2.45, 2.45]:
			var t_end := 0.18 * cos(clampf(u_end / 2.55, -1.0, 1.0) * PI * 0.5)
			soup.add_box(Vector3(0.48, 1.18, 0.48), Vector3(xx, t_end + 0.26, u_end), sd_col.lerp(sl_col, rng.next_f()), CWGfx.L_MASON, 0.90)
			soup.add_box(Vector3(0.60, 0.13, 0.60), Vector3(xx, t_end + 0.92, u_end), sl_col, CWGfx.L_MASON, 0.86)
			soup.add_cone(0.19, 0.24, Vector3(xx, t_end + 1.09, u_end), sd_col, 4, CWGfx.L_ROCK, 0.90)

	# Frostfall icicles hanging under both arches
	if String(t.bio.get("key", "")) == "frost":
		for side: float in [-1.0, 1.0]:
			var u_ic := -1.15
			while u_ic <= 1.16:
				var h_ic := rng.rr(0.14, 0.52)
				var y_ic := spring + (crown - spring) * sqrt(maxf(0.0, 1.0 - (u_ic / arch_a) * (u_ic / arch_a)))
				soup.add_cone(rng.rr(0.04, 0.07), h_ic, Vector3(side * (w_half + 0.03), y_ic - h_ic * 0.5 - 0.04, u_ic), Color(0.68, 0.88, 1.0), 5, CWGfx.L_PLAIN, 0.16, Vector3(PI, 0.0, 0.0), 0.0, 0.45)
				u_ic += 0.21

	var mi := MeshInstance3D.new()
	mi.mesh = soup.build()
	mi.material_override = t.gfx.mat_world
	t.bridge_pos = p
	t.has_bridge = true
	mi.rotation.y = yaw
	t._attach_to_chunk(mi, Vector3(p.x, y0, p.y))



static func _build_pads(t: CWTerrain) -> void:
	# Upstream 32-props.js:227-238 + 90-main.js:152-158: bright brass-inlaid octagonal pads & golden pennant markers
	t.pad_meshes.clear()
	var rng := CWUtil.Rng.new(t.seed_val + 777)
	var bkey: String = String(t.bio.get("key", "ashen"))
	var bright := (bkey == "frost" or bkey == "dunes")
	var top_col := Color(0.353, 0.376, 0.439) if bright else Color(0.557, 0.573, 0.620)
	var rim_col := Color(0.212, 0.227, 0.275) if bright else Color(0.337, 0.353, 0.400)
	var brass_col := Color(0.95, 0.72, 0.24) if bright else Color(0.84, 0.63, 0.22)
	var gold_col := Color(0.92, 0.70, 0.22)
	var amber_col := Color(0.79, 0.41, 0.16)

	# Build smoothed road centerline for flyers (31-terrain.js:403)
	var road: Array[Vector2] = t.layout["road"]
	t.road_smooth.clear()
	var rn := road.size()
	for ri in range(rn):
		var w := mini(5, mini(ri, rn - 1 - ri))
		var acc := Vector2.ZERO
		for dk in range(-w, w + 1):
			acc += road[ri + dk]
		t.road_smooth.append(acc / float(2 * w + 1))

	var pad_pick_shape := CylinderShape3D.new()
	pad_pick_shape.radius = 1.55
	pad_pick_shape.height = 0.55

	for pad in t.layout["pads"]:
		var soup := CWGfx.Soup.new()
		var py_rot := rng.rr(0.0, TAU)
		# Octagonal rim & faintly glowing top stone
		soup.add_cyl(1.36, 1.30, 0.30, Vector3(0, 0.12, 0), rim_col.darkened(0.18), 8, CWGfx.L_MASON, 0.90, Vector3(0, PI / 8.0, 0))
		soup.add_cyl(1.20, 1.20, 0.06, Vector3(0, 0.28, 0), top_col, 8, CWGfx.L_MASON, 0.86, Vector3(0, PI / 8.0, 0), 0.0, 0.14)
		# 8 perimeter curb stones
		for k in range(8):
			var a := float(k) / 8.0 * TAU
			soup.add_box(Vector3(0.46, 0.20, 0.28), Vector3(cos(a) * 1.34, 0.10 + rng.rr(0.0, 0.06), sin(a) * 1.34), rim_col.lerp(top_col, rng.rr(0.0, 0.5)), CWGfx.L_ROCK, 0.90, Vector3(rng.rr(-0.1, 0.1), -a + PI * 0.5, 0), 0.0, 0.08)
		# 8-segment brass octagonal inlay ring + brass center crosshair
		for k in range(8):
			var a := (float(k) + 0.5) / 8.0 * TAU
			soup.add_box(Vector3(0.62, 0.035, 0.09), Vector3(cos(a) * 0.80, 0.325, sin(a) * 0.80), brass_col, CWGfx.L_METAL, 0.40, Vector3(0, -a + PI * 0.5, 0), 0.0, 0.36)
		soup.add_box(Vector3(0.50, 0.035, 0.09), Vector3(0, 0.325, 0), brass_col, CWGfx.L_METAL, 0.40, Vector3.ZERO, 0.0, 0.36)
		soup.add_box(Vector3(0.50, 0.035, 0.09), Vector3(0, 0.325, 0), brass_col, CWGfx.L_METAL, 0.40, Vector3(0, PI * 0.5, 0), 0.0, 0.36)

		var mi := MeshInstance3D.new()
		mi.mesh = soup.build()
		mi.material_override = t.gfx.mat_world
		mi.rotation.y = py_rot
		var pad_body := StaticBody3D.new()
		pad_body.name = "PadPickBody"
		pad_body.collision_layer = 16
		pad_body.collision_mask = 0
		pad_body.set_meta("pad", pad)
		var pad_col := CollisionShape3D.new()
		pad_col.shape = pad_pick_shape
		pad_col.position = Vector3(0.0, 0.2, 0.0)
		pad_body.add_child(pad_col)
		mi.add_child(pad_body)
		t._attach_to_chunk(mi, Vector3(pad["x"], pad["y"], pad["z"]))
		t.pad_meshes.append(mi)

		# Golden-tipped empty-pad pennant marker (hidden when a tower is built)
		var msp := CWGfx.Soup.new()
		msp.add_box(Vector3(0.08, 1.15, 0.08), Vector3(0, 0.57, 0), t.pal["woodD"], CWGfx.L_WOOD, 0.90, Vector3(0, 0, 0.05))
		msp.add_cone(0.07, 0.14, Vector3(0.03, 1.20, 0), brass_col, 4, CWGfx.L_METAL, 0.45, Vector3.ZERO, 0.0, 0.25)
		msp.add_box(Vector3(0.46, 0.34, 0.04), Vector3(0.28, 0.88, 0), gold_col.lerp(amber_col, 0.4), CWGfx.L_CLOTH, 0.85, Vector3.ZERO, 0.45, 0.22)
		msp.add_box(Vector3(0.22, 0.18, 0.04), Vector3(0.56, 0.88, 0), gold_col, CWGfx.L_CLOTH, 0.85, Vector3.ZERO, 0.65, 0.26)
		var mmi := MeshInstance3D.new()
		mmi.mesh = msp.build()
		mmi.material_override = t.gfx.mat_world
		t._attach_to_chunk(mmi, Vector3(pad["x"], float(pad["y"]) + 0.28, pad["z"]))
		pad["marker"] = mmi
		pad["marker_yaw"] = py_rot



static func _keep_world(t: CWTerrain, kp: Vector2, ky: float, yaw: float, lx: float, ly: float, lz: float) -> Vector3:
	return Vector3(kp.x + lx * cos(yaw) + lz * sin(yaw), ky + ly, kp.y - lx * sin(yaw) + lz * cos(yaw))


static func _build_keep_and_cave(t: CWTerrain) -> void:
	# A1: Full 5-tier Ruined Keep & 7.3m Independent Beacon Tower (32-props.js:237-295)
	var kp: Vector2 = t.layout["keep"]
	var ky := t.height_at(kp.x, kp.y)
	var road: Array[Vector2] = t.layout["road"]
	var rd := (road[maxi(0, road.size() - 2)] - kp).normalized()
	var yaw := atan2(rd.x, rd.y)
	var st: Color = t.pal["stone"]
	var sdk: Color = t.pal["stoneD"]
	var sl: Color = t.pal["stoneL"]
	var iron: Color = t.pal["iron"]
	var wd: Color = t.pal["woodD"]
	var blk := Color(0.03, 0.035, 0.05)
	var keep_soup := CWGfx.Soup.new()

	# Plinth (10.6 x 0.5 x 6.0) + 9 front steps
	keep_soup.add_box(Vector3(10.6, 0.5, 6.0), Vector3(0, -0.2, -2.3), sdk, CWGfx.L_MASON, 0.9)
	for k in range(9):
		keep_soup.add_box(Vector3(1.1, 0.16, 0.55), Vector3(-4.4 + float(k) * 1.1, 0.1, 0.85), st.lerp(sl, float(k % 2) * 0.35), CWGfx.L_MASON, 0.88)

	# Broken Right Bastion Tower (2.3, -0.15, w=1.95, h=3.9)
	var tx := 2.3
	var tz := -0.15
	var tw := 1.95
	var th := 3.9
	keep_soup.add_box(Vector3(tw + 0.34, 0.6, tw + 0.34), Vector3(tx, 0.3, tz), sdk, CWGfx.L_MASON, 0.9)
	keep_soup.add_box(Vector3(tw, th, tw), Vector3(tx, th * 0.5, tz), st, CWGfx.L_MASON, 0.88)
	for c in range(4):
		keep_soup.add_box(Vector3(tw + 0.04, 0.22, tw + 0.04), Vector3(tx, 0.9 + float(c) * (th - 1.2) / 3.2, tz), sl, CWGfx.L_MASON, 0.88)
	keep_soup.add_box(Vector3(tw + 0.36, 0.3, tw + 0.36), Vector3(tx, th + 0.12, tz), sl, CWGfx.L_MASON, 0.86)
	keep_soup.add_box(Vector3(0.14, 0.8, 0.1), Vector3(tx, th * 0.62, tz + tw * 0.5 + 0.02), blk, CWGfx.L_PLAIN, 0.95)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			keep_soup.add_box(Vector3(0.42, 0.44, 0.42), Vector3(tx + sx * (tw * 0.5 - 0.05), th + 0.48, tz + sz * (tw * 0.5 - 0.05)), st, CWGfx.L_MASON, 0.88)

	# Gatehouse + 9-stone Arch + 5-bar Iron Portcullis + 4 Battlements
	keep_soup.add_box(Vector3(2.7, 1.25, 1.3), Vector3(0, 3.2, -0.15), st, CWGfx.L_MASON, 0.88)
	for k in range(9):
		var ang := PI * float(k) / 8.0
		keep_soup.add_box(Vector3(0.4, 0.3, 1.4), Vector3(cos(ang) * 1.12, 1.5 + sin(ang) * 1.12, -0.15), sl, CWGfx.L_MASON, 0.86, Vector3(0, 0, ang - PI * 0.5))
	for sg: float in [-1.0, 1.0]:
		keep_soup.add_box(Vector3(0.5, 0.9, 1.3), Vector3(sg * 1.12, 2.3, -0.15), st, CWGfx.L_MASON, 0.88)
		keep_soup.add_box(Vector3(0.3, 1.5, 1.34), Vector3(sg * 1.2, 0.75, -0.15), sl, CWGfx.L_MASON, 0.88)
	keep_soup.add_box(Vector3(2.2, 2.7, 0.2), Vector3(0, 1.35, -0.7), blk, CWGfx.L_PLAIN, 0.96)
	keep_soup.add_box(Vector3(2.2, 0.2, 1.2), Vector3(0, 2.75, -0.2), blk, CWGfx.L_PLAIN, 0.96)
	for p_i in range(5):
		var px := -0.8 + float(p_i) * 0.4
		keep_soup.add_box(Vector3(0.07, 0.95, 0.07), Vector3(px, 2.15, 0.3), iron, CWGfx.L_METAL, 0.5)
		keep_soup.add_cone(0.06, 0.16, Vector3(px, 1.6, 0.3), iron, 4, CWGfx.L_METAL, 0.5, Vector3(PI, 0, 0))
	keep_soup.add_box(Vector3(2.0, 0.07, 0.07), Vector3(0, 1.95, 0.3), iron, CWGfx.L_METAL, 0.5)
	keep_soup.add_box(Vector3(2.0, 0.07, 0.07), Vector3(0, 2.40, 0.3), iron, CWGfx.L_METAL, 0.5)
	keep_soup.add_box(Vector3(2.9, 0.2, 1.5), Vector3(0, 3.9, -0.15), sl, CWGfx.L_MASON, 0.86)
	for bx_c in [-1.02, -0.34, 0.34, 1.02]:
		keep_soup.add_box(Vector3(0.42, 0.44, 0.42), Vector3(bx_c, 4.12, 0.3), sl, CWGfx.L_MASON, 0.88)

	# Stepped Left & Right Curtain Walls + Rear Wall
	var left_h := [3.1, 3.1, 2.3, 1.3, 0.6]
	for k in range(left_h.size()):
		var wh: float = left_h[k]
		var wx_l := -3.3 - (float(k) + 0.5) * 1.35
		keep_soup.add_box(Vector3(1.35, wh, 0.95), Vector3(wx_l, wh * 0.5, -0.35), st, CWGfx.L_MASON, 0.9)
		if wh > 2.4:
			keep_soup.add_box(Vector3(1.45, 0.2, 1.1), Vector3(wx_l, wh + 0.1, -0.35), sl, CWGfx.L_MASON, 0.88)
			keep_soup.add_box(Vector3(0.4, 0.42, 0.3), Vector3(wx_l - 0.4, wh + 0.4, 0.05), sl, CWGfx.L_MASON, 0.88)
			keep_soup.add_box(Vector3(0.4, 0.42, 0.3), Vector3(wx_l + 0.4, wh + 0.4, 0.05), sl, CWGfx.L_MASON, 0.88)
	var right_h := [3.0, 2.0, 1.1]
	for k in range(right_h.size()):
		var wh: float = right_h[k]
		var wx_r := 3.3 + (float(k) + 0.5) * 1.35
		keep_soup.add_box(Vector3(1.35, wh, 0.95), Vector3(wx_r, wh * 0.5, -0.35), st, CWGfx.L_MASON, 0.9)
		if wh > 2.4:
			keep_soup.add_box(Vector3(1.45, 0.2, 1.1), Vector3(wx_r, wh + 0.1, -0.35), sl, CWGfx.L_MASON, 0.88)
	var rear_h := [3.4, 2.4, 3.6, 1.6, 2.8]
	for k in range(rear_h.size()):
		var wh: float = rear_h[k]
		var wx_b := -4.7 + float(k) * 1.3
		keep_soup.add_box(Vector3(1.3, wh, 0.7), Vector3(wx_b, wh * 0.5, -4.7), sdk, CWGfx.L_MASON, 0.92)
		if wh > 3.0:
			keep_soup.add_box(Vector3(0.36, 1.0, 0.74), Vector3(wx_b, wh * 0.62, -4.7), blk, CWGfx.L_PLAIN, 0.95)
	keep_soup.add_box(Vector3(0.7, 2.6, 3.4), Vector3(-5.0, 1.3, -2.8), sdk, CWGfx.L_MASON, 0.9)
	keep_soup.add_cyl(1.5, 1.4, 2.4, Vector3(2.4, 1.2, -3.6), sdk, 8, CWGfx.L_MASON, 0.9)
	# Timber beams & red keep banner
	for k in range(4):
		keep_soup.add_seg(Vector3(-4.6, 2.5 - float(k) * 0.12, -4.3 + float(k) * 0.7), Vector3(-1.6, 1.2, -4.0 + float(k) * 0.7), 0.08, 0.07, wd, 4, CWGfx.L_WOOD, 0.9)
	keep_soup.add_box(Vector3(0.9, 1.55, 0.05), Vector3(2.3, 2.45, 0.85), t.pal["clothR"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 0.5)

	# 2 Gatehouse Wall Lanterns (also registered as env_lights + keep_fires)
	for sg: float in [-1.0, 1.0]:
		keep_soup.add_seg(Vector3(sg * 1.32, 1.9, 0.52), Vector3(sg * 1.32, 2.1, 0.92), 0.035, 0.03, iron, 4, CWGfx.L_METAL, 0.5)
		keep_soup.add_cyl(0.09, 0.14, 0.16, Vector3(sg * 1.32, 2.14, 0.94), Color(1.0, 0.56, 0.18), 6, CWGfx.L_PLAIN, 0.35, Vector3.ZERO, 0.0, 1.6)
		var lpos := _keep_world(t, kp, ky, yaw, sg * 1.32, 2.3, 0.94)
		t.keep_fires.append(lpos)
		if t.env_lights.size() < 2:
			t.env_lights.append({"pos": lpos, "col": Color(1.0, 0.55, 0.20), "energy": 1.7, "range": 9.0, "flick": true})

	# Independent 7.3m Great Beacon Tower (bx = -2.6, bz = -0.35, bh = 7.3)
	# Put beacon tower into its own non-shadow-casting mesh (matching 31-terrain.js:369 where beaconTower is not in B.caster)
	# so its wide 1.82m cap & brazier never cast a giant circular umbrella shadow blocking beacon_light from the Keep & road!
	var bx := -2.6
	var bz := -0.35
	var bh_t := 7.3
	var btop_soup := CWGfx.Soup.new()
	btop_soup.add_cyl(1.9, 1.6, 1.3, Vector3(bx, 0.65, bz), sdk, 10, CWGfx.L_MASON, 0.9)
	btop_soup.add_cyl(1.52, 1.37, bh_t, Vector3(bx, bh_t * 0.5, bz), st, 10, CWGfx.L_MASON, 0.88)
	for c in range(6):
		var cr := 1.54 - float(c) * 0.027
		btop_soup.add_cyl(cr, cr, 0.2, Vector3(bx, 1.7 + float(c) * 1.0, bz), sl, 10, CWGfx.L_MASON, 0.86)
	btop_soup.add_cyl(1.42, 1.79, 0.55, Vector3(bx, bh_t - 0.15, bz), sl, 10, CWGfx.L_MASON, 0.86)
	btop_soup.add_cyl(1.82, 1.82, 0.22, Vector3(bx, bh_t + 0.22, bz), st, 10, CWGfx.L_MASON, 0.88)
	for k in range(7):
		if k == 1:
			continue
		var a := float(k) * TAU / 7.0
		btop_soup.add_box(Vector3(0.6, 0.5, 0.32), Vector3(bx + cos(a) * 1.6, bh_t + 0.58, bz + sin(a) * 1.6), sl, CWGfx.L_MASON, 0.88, Vector3(0, -a + PI * 0.5, 0))
	for k in range(4):
		var a := float(k) * PI * 0.5 + 0.4
		btop_soup.add_box(Vector3(0.14, 0.9, 0.14), Vector3(bx + cos(a) * 1.44, bh_t * (0.4 + float(k & 1) * 0.22), bz + sin(a) * 1.44), blk, CWGfx.L_PLAIN, 0.95)
	for k in range(5):
		var a := float(k) * TAU / 5.0
		btop_soup.add_seg(Vector3(bx + cos(a) * 1.4, bh_t - 0.9, bz + sin(a) * 1.4), Vector3(bx + cos(a) * 2.1, bh_t - 0.1, bz + sin(a) * 2.1), 0.07, 0.06, wd, 4, CWGfx.L_WOOD, 0.9)
	# Great Beacon Brazier + 4 Burning Logs (structure top ~8.56, flame anchor ky + 8.75)
	btop_soup.add_cyl(0.6, 0.6, 0.55, Vector3(bx, bh_t + 0.6, bz), sdk, 8, CWGfx.L_MASON, 0.9)
	btop_soup.add_cyl(0.72, 1.01, 0.42, Vector3(bx, bh_t + 1.06, bz), iron, 10, CWGfx.L_METAL, 0.5)
	for k in range(4):
		var a := float(k) * PI * 0.5 + 0.3
		btop_soup.add_seg(Vector3(bx + cos(a) * 0.72, bh_t + 0.35, bz + sin(a) * 0.72), Vector3(bx + cos(a) * 0.96, bh_t + 1.22, bz + sin(a) * 0.96), 0.04, 0.04, iron, 4, CWGfx.L_METAL, 0.5)
		btop_soup.add_seg(Vector3(bx + cos(a) * 0.65, bh_t + 1.28, bz + sin(a) * 0.65), Vector3(bx - cos(a) * 0.2, bh_t + 1.48, bz - sin(a) * 0.2), 0.1, 0.09, t.pal["bark"], 5, CWGfx.L_BARK, 0.92)
	btop_soup.add_cyl(0.9, 0.85, 0.12, Vector3(bx, bh_t + 1.24, bz), Color(1.0, 0.48, 0.12), 10, CWGfx.L_PLAIN, 0.35, Vector3.ZERO, 0.0, 0.42)
	btop_soup.add_box(Vector3(0.9, 2.2, 0.05), Vector3(bx, 4.1, bz + 1.52), t.pal["clothR"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 0.55)

	var keep_mi := MeshInstance3D.new()
	keep_mi.mesh = keep_soup.build()
	keep_mi.material_override = t.gfx.mat_world
	keep_mi.rotation.y = yaw
	keep_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t._attach_to_chunk(keep_mi, Vector3(kp.x, ky, kp.y))

	var btop_mi := MeshInstance3D.new()
	btop_mi.mesh = btop_soup.build()
	btop_mi.material_override = t.gfx.mat_world
	btop_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	btop_mi.rotation.y = yaw
	t._attach_to_chunk(btop_mi, Vector3(kp.x, ky, kp.y))
	t.beacon_pos = _keep_world(t, kp, ky, yaw, bx, bh_t + 1.45, bz)

	# Add 3rd env light at waterfall/bridge for atmospheric mist glow
	if t.has_waterfall and t.env_lights.size() < 3:
		t.env_lights.append({"pos": t.waterfall_pos + Vector3(0, 3.8, 0), "col": Color(0.55, 0.78, 1.0) if String(t.bio.get("key", "")) != "ember" else Color(1.0, 0.38, 0.12), "energy": 1.4, "range": 9.0, "flick": String(t.bio.get("key", "")) == "ember"})

	# Monster Cave arch at road start
	var cv: Vector2 = t.layout["cave"]
	var cy := t.height_at(cv.x, cv.y)
	# Exact 32-props.js:301-318 monumental 21-boulder mountain cave + hanging stalactites & Frostfall icicles
	var cave_soup := CWGfx.Soup.new()
	var crng := CWUtil.Rng.new(t.seed_val + 613)
	var rk_c := func(rad: float, lp: Vector3, sq: float = 1.0) -> void:
		var col_r: Color = sdk.lerp(st, crng.rr(0.0, 0.7))
		cave_soup.add_rock(rad, lp, col_r, crng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.0, sq, 1.0))
	for sg: float in [-1.0, 1.0]:
		rk_c.call(1.35, Vector3(0.10, 0.65, sg * 2.45), 1.0)
		rk_c.call(1.15, Vector3(0.20, 1.90, sg * 2.30), 1.0)
		rk_c.call(0.98, Vector3(0.20, 2.95, sg * 1.95), 0.95)
		rk_c.call(0.65, Vector3(1.00, 0.30, sg * 2.15), 0.85)
		rk_c.call(0.46, Vector3(1.50, 0.20, sg * 1.95), 0.80)
	rk_c.call(1.45, Vector3(0.15, 3.65, 0.0), 0.58)
	rk_c.call(1.15, Vector3(0.25, 3.55, -1.05), 0.62)
	rk_c.call(1.15, Vector3(0.25, 3.55, 1.05), 0.62)
	for k in range(4):
		rk_c.call(1.80, Vector3(-0.9 - float(k) * 0.75, 4.10 + float(k) * 0.30, crng.rr(-0.55, 0.55)), 0.68)
	for zz_s: float in [-1.25, -0.75, -0.20, 0.35, 0.90, 1.30]:
		cave_soup.add_cone(0.15 + crng.rr(0.0, 0.06), 0.45 + crng.rr(0.0, 0.50), Vector3(0.30 + crng.rr(0.0, 0.20), 2.85, zz_s), sl * 0.9, 5, CWGfx.L_ROCK, 0.92, Vector3(PI, 0.0, 0.0))
	if String(t.bio.get("key", "")) == "frost":
		for zi in range(13):
			var zz_i := -1.35 + float(zi) * 0.22
			var ih := crng.rr(0.22, 0.75)
			cave_soup.add_cone(0.05 + crng.rr(0.0, 0.03), ih, Vector3(0.62 + crng.rr(0.0, 0.10), 2.90 - ih * 0.5, zz_i), Color(0.54, 0.86, 1.0), 5, CWGfx.L_PLAIN, 0.14, Vector3(PI, 0.0, 0.0), 0.0, 0.02)
	cave_soup.add_box(Vector3(3.8, 0.22, 3.7), Vector3(-1.9, 3.05, 0.0), blk, CWGfx.L_PLAIN, 0.98)
	cave_soup.add_box(Vector3(0.24, 3.4, 3.7), Vector3(-3.45, 1.50, 0.0), blk, CWGfx.L_PLAIN, 0.98)
	for sg: float in [-1.0, 1.0]:
		cave_soup.add_box(Vector3(3.8, 3.2, 0.22), Vector3(-1.9, 1.50, sg * 1.82), sdk.darkened(0.65), CWGfx.L_ROCK, 0.96)
	var cave_mi := MeshInstance3D.new()
	cave_mi.mesh = cave_soup.build()
	cave_mi.material_override = t.gfx.mat_world
	t._attach_to_chunk(cave_mi, Vector3(cv.x + 2.8, cy, cv.y))



	# Giant ribcage skeleton landmark
	var rx := clampf(kp.x + 1.2, -CWLayout.BH + 3.0, CWLayout.BH - 2.5)
	var rz := clampf(kp.y - 5.2, -CWLayout.BH + 3.0, CWLayout.BH - 3.0)
	var ry := t.height_at(rx, rz)
	var rib_soup := CWGfx.Soup.new()
	var bone_col: Color = t.pal["bone"]
	rib_soup.add_seg(Vector3(-1.3, 0.22, 0), Vector3(1.3, 0.16, 0.1), 0.11, 0.08, bone_col, 5, CWGfx.L_PLAIN, 0.85)
	for r_i in range(5):
		var xo := -0.95 + float(r_i) * 0.45
		var rad := 0.72 - absf(float(r_i - 2)) * 0.12
		for sg: float in [-1.0, 1.0]:
			rib_soup.add_seg(Vector3(xo, 0.2, 0), Vector3(xo - 0.1, 0.75 * rad, sg * 0.55 * rad), 0.06, 0.04, bone_col, 4, CWGfx.L_PLAIN, 0.85)
			rib_soup.add_seg(Vector3(xo - 0.1, 0.75 * rad, sg * 0.55 * rad), Vector3(xo - 0.15, 0.18, sg * 0.78 * rad), 0.04, 0.025, bone_col, 4, CWGfx.L_PLAIN, 0.85)
	var rib_mi := MeshInstance3D.new()
	rib_mi.mesh = rib_soup.build()
	rib_mi.material_override = t.gfx.mat_world
	rib_mi.rotation.y = 0.55
	t._attach_to_chunk(rib_mi, Vector3(rx, ry, rz))
