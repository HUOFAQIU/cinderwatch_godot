class_name CWTerrainScatter
extends RefCounted


# Biome landmarks, flora, boulders, ponds, and ruins placement (extracted from terrain.gd)

static func _scatter_landmarks_and_biome_props(t: CWTerrain, rng: CWUtil.Rng) -> void:
	var placed: Array[Vector3] = []
	var bh := CWLayout.BH - 1.8
	var cave: Vector2 = t.layout["cave"]
	var keep: Vector2 = t.layout["keep"]
	var total_len: float = float(t.layout["total_len"])
	var bkey: String = String(t.bio.get("key", "ashen"))

	var is_free := func(wx: float, wz: float, rad: float, road_min: float = 2.0, water_min: float = 1.6, allow_steep: bool = false) -> bool:
		var lim := (CWLayout.BH - 0.7 - rad * 0.4) if allow_steep else bh
		if absf(wx) > lim or absf(wz) > lim:
			return false
		if not allow_steep:
			if t.height_at(wx, wz) > 1.05:
				return false
			var sr := minf(rad * 0.65, 1.4)
			if sr > 0.35:
				if t.height_at(wx + sr, wz) > 1.20 or t.height_at(wx - sr, wz) > 1.20 or t.height_at(wx, wz + sr) > 1.20 or t.height_at(wx, wz - sr) > 1.20:
					return false
		if t._sample_grid(t._grid_dr, wx, wz) < road_min + rad * 0.45:
			return false
		if t._sample_grid(t._grid_ds, wx, wz) < water_min + rad * 0.45:
			return false
		var p2 := Vector2(wx, wz)
		if p2.distance_to(cave) < 3.6 + rad or p2.distance_to(keep) < 5.6 + rad:
			return false
		if t.has_bridge and p2.distance_to(t.bridge_pos) < 3.0 + rad:
			return false
		for pad in t.layout["pads"]:
			if p2.distance_to(Vector2(pad["x"], pad["z"])) < 2.25 + rad:
				return false
		for ex in placed:
			var dx := wx - ex.x
			var dz := wz - ex.y
			var rr := rad + ex.z
			if dx * dx + dz * dz < rr * rr:
				return false
		return true

	# Batch all scattered props into per-chunk Soup buckets (1 ArrayMesh per chunk instead of 160+ separate meshes!)
	var nch_p := CWLayout.NCH
	var prop_soups: Array[CWGfx.Soup] = []
	for _ci in range(nch_p * nch_p):
		prop_soups.append(CWGfx.Soup.new())

	var place_at := func(wx: float, wz: float, yaw: float, build_fn: Callable) -> void:
		var ci := clampi(int(floorf((wx + CWLayout.BH) / CWLayout.CHUNK)), 0, nch_p - 1)
		var cj := clampi(int(floorf((wz + CWLayout.BH) / CWLayout.CHUNK)), 0, nch_p - 1)
		var idx := cj * nch_p + ci
		if idx < t.chunks.size():
			var home: Vector3 = t.chunks[idx]["home"]
			var lp := Vector3(wx - home.x, t.height_at(wx, wz) - home.y, wz - home.z)
			build_fn.call(prop_soups[idx], lp, yaw)

	var drop := func(build_fn: Callable, rad: float, road_min: float = 2.0, water_min: float = 1.6, tries: int = 36, allow_steep: bool = false) -> Vector2:
		var lim := (CWLayout.BH - 0.8) if allow_steep else bh
		for _t in range(tries):
			var wx := rng.rr(-lim, lim)
			var wz := rng.rr(-lim, lim)
			if is_free.call(wx, wz, rad, road_min, water_min, allow_steep):
				placed.append(Vector3(wx, wz, rad))
				place_at.call(wx, wz, rng.rr(0.0, TAU), build_fn)
				return Vector2(wx, wz)
		return Vector2(999.0, 999.0)

	var beside_road := func(s_min: float, s_max: float, off_min: float, rad: float) -> Dictionary:
		for _t in range(36):
			var s_pos := rng.rr(s_min, maxf(s_min + 1.0, s_max))
			var smp := CWLayout.sample_path(t.layout, s_pos)
			var p: Vector2 = smp["pos"]
			var d: Vector2 = smp["dir"]
			var side := -1.0 if rng.next_f() < 0.5 else 1.0
			var off := CWLayout.ROAD_HALF + off_min + rng.rr(0.15, 0.75)
			var wx := p.x + (-d.y) * side * off
			var wz := p.y + d.x * side * off
			if is_free.call(wx, wz, rad, 1.45, 1.4):
				placed.append(Vector3(wx, wz, rad))
				return {"x": wx, "z": wz, "yaw": atan2(d.x, d.y), "side": side}
		return {}

	# 1. Iconic Landmarks (32-props.js:354-365)
	drop.call(func(s, p, y): CWPropLib.stamp(s, "tower_ruin", p, y), 2.7, 2.8, 1.8)
	drop.call(func(s, p, y): CWPropLib.stamp(s, "ribcage", p, y), 2.3, 2.4, 1.6)
	drop.call(func(s, p, y): CWPropLib.stamp(s, "graveyard", p, y), 3.0, 2.6, 1.8)
	drop.call(func(s, p, y): CWPropLib.stamp(s, "well", p, y), 1.3, 1.9, 1.5)
	drop.call(func(s, p, y): CWPropLib.stamp(s, "statue", p, y), 1.2, 2.0, 1.5)
	for _w in range(3):
		var wlen := rng.rr(3.8, 6.4)
		var wh := rng.rr(1.8, 3.0)
		drop.call(func(s, p, y): CWPropLib.stamp(s, "wall_run", p, y, wlen / 4.0), wlen * 0.48, 2.0, 1.5)
	for _c in range(3):
		drop.call(func(s, p, _y): CWPropLib.stamp(s, "cairn", p, rng.rr(0.0, TAU)), 0.55, 1.8, 1.3)

	# 2. Road-Aligned Narrative Dressing (32-props.js:366-378)
	for k in range(2):
		var br: Dictionary = beside_road.call(8.0, total_len - 7.0, 0.9, 1.05)
		if not br.is_empty():
			var is_brk := (k == 1)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + rng.rr(-0.25, 0.25), func(s, p, y): CWPropLib.stamp(s, "cart_broken" if is_brk else "cart", p, y))
	for _k in range(4):
		var br: Dictionary = beside_road.call(6.0, total_len - 6.0, 0.45, 0.95)
		if not br.is_empty():
			var plen := rng.rr(2.6, 4.1)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5, func(s, p, y): CWPropLib.stamp(s, "palisade", p, y, plen / 3.0))
	for _k in range(4):
		var br: Dictionary = beside_road.call(6.0, total_len - 6.0, 0.65, 1.05)
		if not br.is_empty():
			var flen := rng.rr(2.5, 4.3)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5 + rng.rr(-0.12, 0.12), func(s, p, y): CWPropLib.stamp(s, "fence", p, y, flen / 3.2))
	for k in range(4):
		var br: Dictionary = beside_road.call(7.0, total_len - 5.0, 0.55, 0.35)
		if not br.is_empty():
			var bcol: Color = t.pal["clothR"] if (k & 1) == 0 else t.pal["clothB"]
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5 * float(br["side"]), func(s, p, y): CWPropLib.stamp(s, "banner_r" if bcol == t.pal["clothR"] else "banner_b", p, y))
	var br_sign: Dictionary = beside_road.call(total_len * 0.28, total_len * 0.72, 0.55, 0.4)
	if not br_sign.is_empty():
		place_at.call(float(br_sign["x"]), float(br_sign["z"]), float(br_sign["yaw"]), func(s, p, y): CWPropLib.stamp(s, "signpost", p, y))
	var br_gib: Dictionary = beside_road.call(10.0, total_len * 0.62, 1.0, 0.65)
	if not br_gib.is_empty():
		place_at.call(float(br_gib["x"]), float(br_gib["z"]), float(br_gib["yaw"]) + PI * 0.5, func(s, p, y): CWPropLib.stamp(s, "gibbet", p, y))
	for _k in range(5):
		var br: Dictionary = beside_road.call(6.0, total_len - 5.0, 0.75, 0.7)
		if not br.is_empty():
			place_at.call(float(br["x"]), float(br["z"]), rng.rr(0.0, TAU), func(s, p, y): CWPropLib.stamp(s, "supply_cluster", p, y))

	# 3. Cave Skull Stakes & Bone Piles (32-props.js:310-311, 379-380)
	for sg: float in [-1.0, 1.0]:
		var sx := cave.x + 1.85
		var sz := cave.y + sg * 2.35
		place_at.call(sx, sz, 0.0, func(s, p, _y): CWPropLib.stamp(s, "skull_stake", p, rng.rr(0.0, TAU)))
	for _k in range(6):
		var bx := cave.x + rng.rr(1.8, 6.8)
		var bz := cave.y + (-1.0 if rng.next_f() < 0.5 else 1.0) * rng.rr(1.8, 4.8)
		if absf(bx) < bh and absf(bz) < bh and t.height_at(bx, bz) < 1.35:
			place_at.call(bx, bz, 0.0, func(s, p, _y): CWPropLib.stamp(s, "bone_pile", p, rng.rr(0.0, TAU), rng.rr(0.85, 1.2)))
	for _k in range(5):
		drop.call(func(s, p, _y): CWPropLib.stamp(s, "bone_pile", p, rng.rr(0.0, TAU), rng.rr(0.75, 1.05)), 0.45, 1.6, 1.3)

	# 4. Road Puddles & Biome Ponds (exact counts & wet mud halos from 29-biome.js & 31-terrain.js:244-270)
	var puddle_soup := CWGfx.Soup.new()
	var mud_soup := CWGfx.Soup.new()
	var n_puddles := 11 if bkey == "ashen" else (8 if bkey == "frost" else (15 if bkey == "fen" else 0))
	var mud_col: Color = t.pal["mud"] * 0.55
	mud_col.a = 1.0
	for _q in range(n_puddles):
		var s_p := rng.rr(4.5, maxf(5.5, total_len - 5.0))
		var smp := CWLayout.sample_path(t.layout, s_p)
		var rp: Vector2 = smp["pos"] + Vector2(rng.rr(-0.82, 0.82), rng.rr(-0.82, 0.82))
		if t.has_bridge and rp.distance_to(t.bridge_pos) < 3.6:
			continue
		var py := t.height_at(rp.x, rp.y) + 0.048
		var rx := rng.rr(0.38, 0.76)
		var rz := rng.rr(0.30, 0.65)
		var segs := 11
		var center_v := Vector3(rp.x, py, rp.y)
		var mud_c := Vector3(rp.x, py - 0.008, rp.y)
		for si in range(segs):
			var a0 := TAU * float(si) / float(segs)
			var a1 := TAU * float(si + 1) / float(segs)
			var r0 := 0.78 + 0.34 * sin(a0 * 3.0 + float(_q) * 2.1)
			var r1 := 0.78 + 0.34 * sin(a1 * 3.0 + float(_q) * 2.1)
			var v0 := Vector3(rp.x + cos(a0) * rx * r0, py, rp.y + sin(a0) * rz * r0)
			var v1 := Vector3(rp.x + cos(a1) * rx * r1, py, rp.y + sin(a1) * rz * r1)
			puddle_soup.add_v(center_v, Vector3.UP, Color.WHITE, Vector2(center_v.x, center_v.z), 0, 0.14, 0.0, 0.0)
			puddle_soup.add_v(v1, Vector3.UP, Color.WHITE, Vector2(v1.x, v1.z), 0, 0.14, 0.0, 0.0)
			puddle_soup.add_v(v0, Vector3.UP, Color.WHITE, Vector2(v0.x, v0.z), 0, 0.14, 0.0, 0.0)
			# Dark wet cobblestone mud halo around puddle (31-terrain.js:250-252)
			var m0 := Vector3(rp.x + cos(a0) * rx * r0 * 1.28, py - 0.008, rp.y + sin(a0) * rz * r0 * 1.28)
			var m1 := Vector3(rp.x + cos(a1) * rx * r1 * 1.28, py - 0.008, rp.y + sin(a1) * rz * r1 * 1.28)
			mud_soup.add_v(mud_c, Vector3.UP, mud_col, Vector2(mud_c.x * 0.25, mud_c.z * 0.25), CWGfx.L_COBBLE, 0.28, 0.0, 0.0)
			mud_soup.add_v(m1, Vector3.UP, mud_col, Vector2(m1.x * 0.25, m1.z * 0.25), CWGfx.L_COBBLE, 0.28, 0.0, 0.0)
			mud_soup.add_v(m0, Vector3.UP, mud_col, Vector2(m0.x * 0.25, m0.z * 0.25), CWGfx.L_COBBLE, 0.28, 0.0, 0.0)
	if mud_soup.vert_count > 0:
		var mmi := MeshInstance3D.new()
		mmi.mesh = mud_soup.build()
		mmi.material_override = t.gfx.mat_world
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(mmi)
		t.extra_meshes.append(mmi)

	t.pond_centers.clear()
	var want_ponds := 4 if bkey == "fen" else (1 if bkey == "ashen" else 2)
	for _pq in range(want_ponds):
		for _t in range(60):
			var wx := rng.rr(-bh + 2.4, bh - 2.4)
			var wz := rng.rr(-bh + 2.4, bh - 2.4)
			var pr := rng.rr(1.5, 2.3)
			if is_free.call(wx, wz, pr + 0.6, 2.4, 2.2):
				placed.append(Vector3(wx, wz, pr + 0.6))
				var py := t.height_at(wx, wz) + 0.05
				t.pond_centers.append(Vector3(wx, py, wz))
				var segs := 14
				var cv := Vector3(wx, py, wz)
				for si in range(segs):
					var a0 := TAU * float(si) / float(segs)
					var a1 := TAU * float(si + 1) / float(segs)
					var w0 := 0.86 + 0.18 * sin(a0 * 3.0 + wx)
					var w1 := 0.86 + 0.18 * sin(a1 * 3.0 + wx)
					var v0 := Vector3(wx + cos(a0) * pr * w0, py, wz + sin(a0) * pr * w0)
					var v1 := Vector3(wx + cos(a1) * pr * w1, py, wz + sin(a1) * pr * w1)
					puddle_soup.add_v(cv, Vector3.UP, Color.WHITE, Vector2(cv.x * 0.8, cv.z * 0.8), 0, 0.12, 0.02, 0.0)
					puddle_soup.add_v(v1, Vector3.UP, Color.WHITE, Vector2(v1.x * 0.8, v1.z * 0.8), 0, 0.12, 0.02, 0.0)
					puddle_soup.add_v(v0, Vector3.UP, Color.WHITE, Vector2(v0.x * 0.8, v0.z * 0.8), 0, 0.12, 0.02, 0.0)
				# Rim rocks & biome pond dressing
				var rim_sp := CWGfx.Soup.new()
				for rk in range(8):
					var ra := float(rk) * TAU / 8.0 + rng.rr(-0.2, 0.2)
					var rr_p := pr * rng.rr(0.92, 1.12)
					rim_sp.add_rock(rng.rr(0.22, 0.42), Vector3(cos(ra) * rr_p, 0.08, sin(ra) * rr_p), t.pal["stoneD"], rng.ri(1, 9999), CWGfx.L_ROCK, 0.92, Vector3(1.1, 0.65, 1.0))
					if bkey == "fen" or bkey == "dunes":
						CWPropLib.stamp(rim_sp, "reeds", Vector3(cos(ra + 0.2) * (pr * 0.98), 0.0, sin(ra + 0.2) * (pr * 0.98)), rng.rr(0.0, TAU))
					elif bkey == "frost" and rk < 3:
						CWPropLib.stamp(rim_sp, "crystal", Vector3(cos(ra) * (pr + 0.35), 0.0, sin(ra) * (pr + 0.35)), rng.rr(0.0, TAU))
				if bkey == "fen":
					for _lk in range(4):
						var la := rng.rr(0.0, TAU)
						var ld := pr * rng.rr(0.08, 0.55)
						CWPropLib.stamp(rim_sp, "lily", Vector3(cos(la) * ld, 0.05, sin(la) * ld), rng.rr(0.0, TAU))
				var rim_mi := MeshInstance3D.new()
				rim_mi.mesh = rim_sp.build()
				rim_mi.material_override = t.gfx.mat_world
				t._attach_to_chunk(rim_mi, Vector3(wx, py - 0.04, wz))
				if t.env_lights.size() < 3 and (bkey == "ember" or bkey == "frost"):
					t.env_lights.append({
						"pos": Vector3(wx, py + 0.8, wz),
						"col": Color(1.0, 0.38, 0.12) if bkey == "ember" else Color(0.50, 0.78, 1.0),
						"energy": 1.6 if bkey == "ember" else 0.65,
						"range": 9.0 if bkey == "ember" else 7.0,
						"flick": bkey == "ember",
					})
				break

	if puddle_soup.vert_count > 0:
		var pmi := MeshInstance3D.new()
		pmi.mesh = puddle_soup.build()
		pmi.material_override = t.gfx.mat_water
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if t.water_mesh != null:
			t.water_mesh.add_child(pmi)
		else:
			t.add_child(pmi)

	# 5. Biome-Specific Flora & Landforms (33-flora.js:129-170)
	for _s in range(7):
		drop.call(func(s, p, _y): CWPropLib.stamp(s, "stump", p, rng.rr(0.0, TAU)), 0.45, 1.8, 1.3)

	# Subtle cobblestone road cracks (31-terrain.js:238-248)
	var cr_soup := CWGfx.Soup.new()
	for _q in range(14):
		var s_c := rng.rr(4.5, maxf(5.5, total_len - 5.0))
		var smp := CWLayout.sample_path(t.layout, s_c)
		var cp: Vector2 = smp["pos"]
		if t.has_bridge and cp.distance_to(t.bridge_pos) < 3.5:
			continue
		var cx := cp.x + rng.rr(-0.85, 0.85)
		var cz := cp.y + rng.rr(-0.85, 0.85)
		var ca := rng.rr(0.0, TAU)
		for _sgm in range(rng.ri(3, 5)):
			ca += rng.rr(-0.85, 0.85)
			var cl := rng.rr(0.18, 0.38)
			var x2 := cx + cos(ca) * cl
			var z2 := cz + sin(ca) * cl
			var wx_c := -sin(ca) * 0.028
			var wz_c := cos(ca) * 0.028
			var cy1 := t.height_at(cx, cz) + 0.065
			var cy2 := t.height_at(x2, z2) + 0.065
			cr_soup.add_quad(Vector3(cx - wx_c, cy1, cz - wz_c), Vector3(cx + wx_c, cy1, cz + wz_c), Vector3(x2 + wx_c, cy2, z2 + wz_c), Vector3(x2 - wx_c, cy2, z2 - wz_c), Color(0.09, 0.08, 0.09), CWGfx.L_PLAIN, 0.98)
			cx = x2; cz = z2
	if cr_soup.vert_count > 0:
		var crmi := MeshInstance3D.new()
		crmi.mesh = cr_soup.build()
		crmi.material_override = t.gfx.mat_world
		crmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(crmi)
		t.extra_meshes.append(crmi)

	match bkey:
		"ashen":
			for _k in range(4):
				drop.call(func(s, p, y): CWPropLib.stamp(s, "log", p, y), 1.0, 1.9, 1.4)
		"frost":
			for _k in range(6):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "crystal", p, rng.rr(0.0, TAU)), 0.55, 1.8, 1.2)
			for _k in range(32):
				var dr_r := rng.rr(0.50, 1.25)
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "drift", p, rng.rr(0.0, TAU), dr_r / 1.6), dr_r * 0.38, 1.2, 1.0, 55, true)
			for _k in range(2):
				drop.call(func(s, p, y): CWPropLib.stamp(s, "log", p, y), 1.0, 1.9, 1.4)
		"fen":
			for _k in range(16):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "shroom_cluster", p, rng.rr(0.0, TAU)), 0.40, 1.6, 1.1)
			for _k in range(5):
				drop.call(func(s, p, y): CWPropLib.stamp(s, "log", p, y), 1.0, 1.9, 1.4)
			if t.env_lights.size() < 3 and not t.pond_centers.is_empty():
				var pc0 := t.pond_centers[0]
				t.env_lights.append({"pos": pc0 + Vector3(0, 0.8, 0), "col": Color(0.27, 0.88, 0.72), "energy": 1.1, "range": 7.5, "flick": false})
			# 52 stream-bank reeds (33-flora.js:124-127)
			var st_pts: Array[Vector2] = t.layout["stream"]
			if st_pts.size() > 4:
				for _rk in range(52):
					var su := rng.ri(1, st_pts.size() - 2)
					var sdir := (st_pts[su + 1] - st_pts[su - 1]).normalized()
					var sside := -1.0 if rng.next_f() < 0.5 else 1.0
					var soff := rng.rr(1.05, 1.95)
					var rx := st_pts[su].x - sdir.y * sside * soff
					var rz := st_pts[su].y + sdir.x * sside * soff
					if absf(rx) < bh - 0.8 and absf(rz) < bh - 0.8 and t._sample_grid(t._grid_dr, rx, rz) > CWLayout.ROAD_HALF + 0.9:
						place_at.call(rx, rz, rng.rr(0.0, TAU), func(s, p, _y): CWPropLib.stamp(s, "reeds", p, rng.rr(0.0, TAU)))
		"ember":
			for _k in range(9):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "basalt", p, rng.rr(0.0, TAU)), 1.0, 1.9, 1.4)
			for _k in range(6):
				var sh := rng.rr(2.0, 4.0)
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "spire_dunes" if bkey == "dunes" else "spire", p, rng.rr(0.0, TAU), sh / 3.2), sh * 0.28, 2.0, 1.4, 50, true)
			for _k in range(4):
				var vp: Vector2 = drop.call(func(s, p, _y): CWPropLib.stamp(s, "vent", p, rng.rr(0.0, TAU)), 0.85, 2.1, 1.5)
				if vp.x < 500.0:
					t.keep_fires.append(Vector3(vp.x, t.height_at(vp.x, vp.y) + 0.18, vp.y))
			# Glowing volcanic ground lava cracks (31-terrain.js:271-284)
			var lv_soup := CWGfx.Soup.new()
			for _q in range(36):
				var lx := rng.rr(-bh + 1.8, bh - 1.8)
				var lz := rng.rr(-bh + 1.8, bh - 1.8)
				if t._sample_grid(t._grid_dr, lx, lz) < CWLayout.ROAD_HALF + 0.8 or t._sample_grid(t._grid_ds, lx, lz) < 1.5 or t._sample_grid(t._grid_ds, lx, lz) > 9.0:
					continue
				var la := rng.rr(0.0, TAU)
				var em := rng.rr(0.16, 0.34)
				for _sgm in range(rng.ri(4, 7)):
					la += rng.rr(-0.8, 0.8)
					var ll := rng.rr(0.25, 0.58)
					var x2 := lx + cos(la) * ll
					var z2 := lz + sin(la) * ll
					if absf(x2) > bh - 0.8 or absf(z2) > bh - 0.8:
						break
					var wd_l := rng.rr(0.025, 0.05)
					var wx_l := -sin(la) * wd_l
					var wz_l := cos(la) * wd_l
					var y1 := t.height_at(lx, lz) + 0.04
					var y2 := t.height_at(x2, z2) + 0.04
					lv_soup.add_quad(Vector3(lx - wx_l, y1, lz - wz_l), Vector3(lx + wx_l, y1, lz + wz_l), Vector3(x2 + wx_l, y2, z2 + wz_l), Vector3(x2 - wx_l, y2, z2 - wz_l), Color(0.95, 0.32, 0.05), CWGfx.L_PLAIN, 0.9, 0.0, em)
					lx = x2; lz = z2
			if lv_soup.vert_count > 0:
				var lvmi := MeshInstance3D.new()
				lvmi.mesh = lv_soup.build()
				lvmi.material_override = t.gfx.mat_world
				lvmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				t.add_child(lvmi)
				t.extra_meshes.append(lvmi)
			if t.has_bridge and t.env_lights.size() < 3:
				t.env_lights.append({"pos": Vector3(t.bridge_pos.x, t.height_at(t.bridge_pos.x, t.bridge_pos.y) + 0.5, t.bridge_pos.y), "col": Color(1.0, 0.35, 0.12), "energy": 2.2, "range": 9.5, "flick": true})
		"dunes":
			for _k in range(11):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "cactus", p, rng.rr(0.0, TAU)), 0.45, 1.7, 1.3)
			for _k in range(6):
				var sh := rng.rr(2.2, 4.4)
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "spire_dunes" if bkey == "dunes" else "spire", p, rng.rr(0.0, TAU), sh / 3.2), sh * 0.28, 2.0, 1.4, 50, true)
			# Terracotta amphora jar clusters beside Duskmesa pads (33-flora.js:171-176)
			var d_pads: Array = t.layout["pads"]
			for pd in d_pads:
				if rng.next_f() < 0.5:
					continue
				var ja := rng.rr(0.0, TAU)
				var jx := float(pd["x"]) + cos(ja) * 2.25
				var jz := float(pd["z"]) + sin(ja) * 2.25
				if absf(jx) < bh - 1.0 and absf(jz) < bh - 1.0 and t._sample_grid(t._grid_dr, jx, jz) > CWLayout.ROAD_HALF + 0.5:
					place_at.call(jx, jz, 0.0, func(s, p, _y): CWPropLib.stamp(s, "jar_cluster", p, rng.rr(0.0, TAU)))

	# Duskmesa oasis palms ringing each desert pond (33-flora.js:146-149)
	if bkey == "dunes":
		for pc in t.pond_centers:
			for _pk in range(4):
				var pa := rng.rr(0.0, TAU)
				var pd := rng.rr(2.4, 3.3)
				var px_p := pc.x + cos(pa) * pd
				var pz_p := pc.z + sin(pa) * pd
				if absf(px_p) < bh - 1.2 and absf(pz_p) < bh - 1.2 and t._sample_grid(t._grid_dr, px_p, pz_p) > CWLayout.ROAD_HALF + 1.0:
					place_at.call(px_p, pz_p, rng.rr(0.0, TAU), func(s, p, _y): CWPropLib.stamp(s, "palm", p, rng.rr(0.0, TAU), rng.rr(0.84, 1.22)))

	# Full biome forest density & secondary bare gnarled trees (exact 29-biome.js bio.trees)
	match bkey:
		"frost":
			for _tk in range(11):
				drop.call(func(s, p, _y): t._build_tree(s, p, "pine", rng), 0.78, 1.4, 1.5, 45, false)
			for _tk in range(4):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "gnarled_tree", p, rng.rr(0.0, TAU), rng.rr(0.76, 1.24)), 0.58, 1.4, 1.5, 45, false)
		"fen":
			for _tk in range(5):
				drop.call(func(s, p, _y): t._build_tree(s, p, "willow", rng), 0.80, 1.4, 1.5, 45, false)
			for _tk in range(5):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "gnarled_tree", p, rng.rr(0.0, TAU), rng.rr(0.76, 1.28)), 0.58, 1.4, 1.5, 45, false)
		"dunes":
			for _tk in range(4):
				drop.call(func(s, p, _y): t._build_tree(s, p, "palm", rng), 0.72, 1.4, 1.5, 45, false)
			for _tk in range(2):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "gnarled_tree", p, rng.rr(0.0, TAU), rng.rr(0.70, 1.00)), 0.55, 1.4, 1.5, 45, false)
		"ashen":
			for _tk in range(7):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "gnarled_tree", p, rng.rr(0.0, TAU), rng.rr(0.76, 1.35)), 0.58, 1.4, 1.5, 45, false)
		"ember":
			for _tk in range(6):
				drop.call(func(s, p, _y): CWPropLib.stamp(s, "gnarled_ember", p, rng.rr(0.0, TAU), rng.rr(0.76, 1.28)), 0.58, 1.4, 1.5, 45, false)

	# Cliff-perched & hillside boulders across ALL biomes (32-props.js:394: steep=true, 20% large 0.6-1.25m + 80% 0.16-0.5m)
	var rock_cnt := int(t.bio.get("rock_count", 52))
	for _bk in range(rock_cnt):
		var br := rng.rr(0.58, 1.22) if rng.next_f() < 0.22 else rng.rr(0.18, 0.48)
		var bcol: Color = t.pal["stoneD"].lerp(t.pal["stone"], rng.next_f())
		drop.call(func(s, p, _y): s.add_rock(br, p + Vector3(0.0, br * 0.24, 0.0), bcol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.12, 0.78, 1.04)), br * 0.72, 1.15, 1.55, 45, true)

	# 60 small roadside cobble pebbles lining road shoulders (32-props.js:401-405)
	var peb_soup := CWGfx.Soup.new()
	for _pk2 in range(60):
		var sp_p := rng.rr(3.5, maxf(4.5, total_len - 3.5))
		var smp_p := CWLayout.sample_path(t.layout, sp_p)
		var pp: Vector2 = smp_p["pos"]
		var pd_v: Vector2 = smp_p["dir"]
		var pside := -1.0 if rng.next_f() < 0.5 else 1.0
		var poff := CWLayout.ROAD_HALF + rng.rr(0.10, 0.48)
		var px2 := pp.x - pd_v.y * pside * poff
		var pz2 := pp.y + pd_v.x * pside * poff
		if absf(px2) > bh - 0.6 or absf(pz2) > bh - 0.6 or t._sample_grid(t._grid_ds, px2, pz2) < 2.2:
			continue
		var pr2 := rng.rr(0.08, 0.17)
		var pcol: Color = t.pal["roadD"].lerp(t.pal["stone"], rng.next_f())
		peb_soup.add_rock(pr2, Vector3(px2, t.height_at(px2, pz2) + pr2 * 0.25, pz2), pcol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.92)
	if peb_soup.vert_count > 0:
		var pebmi := MeshInstance3D.new()
		pebmi.mesh = peb_soup.build()
		pebmi.material_override = t.gfx.mat_world
		pebmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(pebmi)
		t.extra_meshes.append(pebmi)

	# Flush batched per-chunk prop meshes (36 combined meshes instead of 160+ individual MeshInstance3Ds)
	for ci in range(mini(prop_soups.size(), t.chunks.size())):
		if prop_soups[ci].vert_count > 0:
			var p_mi := MeshInstance3D.new()
			p_mi.mesh = prop_soups[ci].build()
			p_mi.material_override = t.gfx.mat_world
			(t.chunks[ci]["node"] as Node3D).add_child(p_mi)
