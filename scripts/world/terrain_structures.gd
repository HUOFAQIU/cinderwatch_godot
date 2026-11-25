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
	var dir := (road[mini(road.size() - 1, best_i + 3)] - road[maxi(0, best_i - 3)]).normalized()
	var yaw := atan2(dir.x, dir.y)
	var b_path := "res://assets/models/structures/bridge_frost.res" if String(t.bio.get("key", "")) == "frost" else "res://assets/models/structures/bridge.res"
	var mi := MeshInstance3D.new()
	mi.mesh = load(b_path) as Mesh
	mi.material_override = t.gfx.mat_world
	t.bridge_pos = p
	t.has_bridge = true
	mi.rotation.y = yaw
	t._attach_to_chunk(mi, Vector3(p.x, 0.06, p.y))


static func _build_pads(t: CWTerrain) -> void:
	t.pad_meshes.clear()
	var rng := CWUtil.Rng.new(t.seed_val + 777)
	var bkey: String = String(t.bio.get("key", "ashen"))
	var bright := (bkey == "frost" or bkey == "dunes")
	var pad_mesh := load("res://assets/models/structures/%s.res" % ("pad_bright" if bright else "pad_dark")) as Mesh
	var marker_mesh := load("res://assets/models/structures/pad_marker.res") as Mesh

	# Build smoothed road centerline for flyers
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
		var py_rot := rng.rr(0.0, TAU)
		var mi := MeshInstance3D.new()
		mi.mesh = pad_mesh
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

		var mmi := MeshInstance3D.new()
		mmi.mesh = marker_mesh
		mmi.material_override = t.gfx.mat_world
		t._attach_to_chunk(mmi, Vector3(pad["x"], float(pad["y"]) + 0.28, pad["z"]))
		pad["marker"] = mmi
		pad["marker_yaw"] = py_rot


static func _keep_world(t: CWTerrain, kp: Vector2, ky: float, yaw: float, lx: float, ly: float, lz: float) -> Vector3:
	return Vector3(kp.x + lx * cos(yaw) + lz * sin(yaw), ky + ly, kp.y - lx * sin(yaw) + lz * cos(yaw))


static func _build_keep_and_cave(t: CWTerrain) -> void:
	var kp: Vector2 = t.layout["keep"]
	var ky := t.height_at(kp.x, kp.y)
	var road: Array[Vector2] = t.layout["road"]
	var rd := (road[maxi(0, road.size() - 2)] - kp).normalized()
	var yaw := atan2(rd.x, rd.y)

	# Register 2 gatehouse wall lanterns as env_lights + keep_fires
	for sg: float in [-1.0, 1.0]:
		var lpos := _keep_world(t, kp, ky, yaw, sg * 1.32, 2.3, 0.94)
		t.keep_fires.append(lpos)
		if t.env_lights.size() < 2:
			t.env_lights.append({"pos": lpos, "col": Color(1.0, 0.55, 0.20), "energy": 1.7, "range": 9.0, "flick": true})

	# Keep & Great Beacon Tower (non-shadow-casting so beacon_light illuminates courtyard cleanly)
	var keep_mi := MeshInstance3D.new()
	keep_mi.mesh = load("res://assets/models/structures/keep.res") as Mesh
	keep_mi.material_override = t.gfx.mat_world
	keep_mi.rotation.y = yaw
	keep_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t._attach_to_chunk(keep_mi, Vector3(kp.x, ky, kp.y))

	var btop_mi := MeshInstance3D.new()
	btop_mi.mesh = load("res://assets/models/structures/beacon_top.res") as Mesh
	btop_mi.material_override = t.gfx.mat_world
	btop_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	btop_mi.rotation.y = yaw
	t._attach_to_chunk(btop_mi, Vector3(kp.x, ky, kp.y))
	t.beacon_pos = _keep_world(t, kp, ky, yaw, -2.6, 8.75, -0.35)

	if t.has_waterfall and t.env_lights.size() < 3:
		var is_em := String(t.bio.get("key", "")) == "ember"
		t.env_lights.append({"pos": t.waterfall_pos + Vector3(0, 3.8, 0), "col": Color(1.0, 0.38, 0.12) if is_em else Color(0.55, 0.78, 1.0), "energy": 1.4, "range": 9.0, "flick": is_em})

	# Monster Cave arch at road start
	var cv: Vector2 = t.layout["cave"]
	var cy := t.height_at(cv.x, cv.y)
	var c_path := "res://assets/models/structures/cave_frost.res" if String(t.bio.get("key", "")) == "frost" else "res://assets/models/structures/cave.res"
	var cave_mi := MeshInstance3D.new()
	cave_mi.mesh = load(c_path) as Mesh
	cave_mi.material_override = t.gfx.mat_world
	t._attach_to_chunk(cave_mi, Vector3(cv.x + 2.8, cy, cv.y))
