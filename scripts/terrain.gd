class_name CWTerrain
extends Node3D

# Procedural 6x6 chunk battlefield with dramatic stepped back-cliffs, 5-band stratified slab edges,
# cascading waterfall, road puddles, palisades, roadside torches, bridge, and grand ruined gatehouse
# Ported from 31-terrain.js, 32-props.js, and 33-flora.js

var gfx: CWGfx
var layout: Dictionary = {}
var bio: Dictionary = {}
var pal: Dictionary = {}
var chunks: Array[Dictionary] = []
var beacon_pos: Vector3 = Vector3.ZERO
var waterfall_pos: Vector3 = Vector3.ZERO
var has_waterfall: bool = false
var bridge_pos: Vector2 = Vector2.ZERO
var has_bridge: bool = false
var env_lights: Array[Dictionary] = []
var keep_fires: Array[Vector3] = []
var road_path: Path3D = null
var road_lut: Dictionary = {}
var pond_centers: Array[Vector3] = []
var pad_meshes: Array[MeshInstance3D] = []
var road_smooth: Array[Vector2] = []
var water_mesh: MeshInstance3D = null
var extra_meshes: Array[MeshInstance3D] = []
var seed_val: int = 1
var mirrored: bool = false
var _mirror_active: bool = false

const GRID_N := 49
var _grid_h: PackedFloat32Array = PackedFloat32Array()
var _grid_dr: PackedFloat32Array = PackedFloat32Array()
var _grid_ds: PackedFloat32Array = PackedFloat32Array()


func build_board(p_gfx: CWGfx, p_seed: int, biome_idx: int, biome_start: int = 0) -> Dictionary:
	clear_board()
	gfx = p_gfx
	seed_val = p_seed
	mirrored = (biome_idx % 2) == 1
	_mirror_active = false
	bio = CWBiome.get_biome(biome_idx, biome_start)
	pal = CWBiome.build_palette(bio)
	gfx.apply_biome_uniforms(bio)
	layout = CWLayout.generate(p_seed)
	_bake_terrain_grids()

	var rng := CWUtil.Rng.new(p_seed + 101)
	var bh := CWLayout.BH
	var ch_sz := CWLayout.CHUNK
	var nch := CWLayout.NCH
	var step := 0.5 # 12x12 cells per chunk -> exact 31-terrain.js chiseled cliffs

	for pad in layout["pads"]:
		pad["y"] = height_at(pad["x"], pad["z"])

	var chunk_soups: Array[CWGfx.Soup] = []
	var chunk_nodes: Array[Node3D] = []
	var chunk_centers: Array[Vector3] = []

	for cz in range(nch):
		for cx in range(nch):
			var x0 := -bh + float(cx) * ch_sz
			var z0 := -bh + float(cz) * ch_sz
			var node := Node3D.new()
			var center := Vector3(x0 + ch_sz * 0.5, 0.0, z0 + ch_sz * 0.5)
			node.position = center
			add_child(node)

			var soup := CWGfx.Soup.new()
			var cells := int(ch_sz / step)
			for iz in range(cells):
				for ix in range(cells):
					var p00 := _grid_pt(x0, z0, ix, iz, step, cells, center)
					var p10 := _grid_pt(x0, z0, ix + 1, iz, step, cells, center)
					var p11 := _grid_pt(x0, z0, ix + 1, iz + 1, step, cells, center)
					var p01 := _grid_pt(x0, z0, ix, iz + 1, step, cells, center)
					# Alternating diagonal split for crisp faceted low-poly mountain cliffs (31-terrain.js:162-167)
					var tris: Array = [[p00, p10, p11], [p00, p11, p01]] if ((ix + iz) & 1) == 1 else [[p00, p10, p01], [p10, p11, p01]]
					for tri in tris:
						var ta: Vector3 = tri[0]
						var tb: Vector3 = tri[1]
						var tc: Vector3 = tri[2]
						var fn := (tc - ta).cross(tb - ta).normalized()
						var mx := center.x + (ta.x + tb.x + tc.x) / 3.0
						var mz := center.z + (ta.z + tb.z + tc.z) / 3.0
						var my := (ta.y + tb.y + tc.y) / 3.0
						var dr := _sample_grid(_grid_dr, mx, mz)
						var ds := _sample_grid(_grid_ds, mx, mz)
						var n1 := CWUtil.fbm2(mx * 0.28, mz * 0.28, 2, float(seed_val % 97))
						var n2 := CWUtil.h2(floorf(mx * 2.0 + 99.0), floorf(mz * 2.0 + 99.0), float((seed_val + 2) % 97))
						var col: Color = pal["grass"]
						var layer := CWGfx.L_DIRT
						var rough := 0.96
						if my > 1.20 or fn.y < 0.80:
							col = pal["stoneD"].lerp(pal["stone"], n1 * 0.9 + 0.1)
							if fn.y > 0.93 and n1 > 0.50:
								col = col.lerp(pal["grassD"], 0.35)
							col = col * (0.82 + 0.32 * n2)
							col.a = 1.0
							layer = CWGfx.L_ROCK
						elif ds < 1.45:
							col = pal["mud"].lerp(pal["earthD"], n1) * (0.65 + 0.25 * n2)
							col.a = 1.0
							layer = CWGfx.L_DIRT
							rough = 0.72
						else:
							col = pal["earth"].lerp(pal["grass"], smoothstep(0.40, 0.62, n1))
							var edge_w := smoothstep(2.4, 0.5, dr - CWLayout.ROAD_HALF) * 0.55
							col = col.lerp(pal["earthD"], edge_w) * (0.84 + 0.30 * n2)
							col.a = 1.0
						var bg_emis := 0.0
						if String(bio.get("key", "")) == "ember" and ds < 1.85 and my <= 1.20:
							var gw := (1.0 - smoothstep(0.85, 1.85, ds)) * (0.65 + 0.35 * n1)
							col = col.lerp(Color(0.82, 0.24, 0.04), gw * 0.55)
							bg_emis = gw * 0.14
						soup.add_tri(ta, tb, tc, col, layer, rough, 0.0, bg_emis)

			_add_chunk_skirts(soup, x0, z0, ch_sz, center, step, cx, cz, nch)
			chunk_soups.append(soup)
			chunk_nodes.append(node)
			chunk_centers.append(center)

			_add_chunk_props(node, x0, z0, ch_sz, center, rng)

			var dist_from_center := Vector2(center.x, center.z).length()
			chunks.append({
				"node": node,
				"home": center,
				"cx": cx,
				"cz": cz,
				"delay": dist_from_center * 0.032 + rng.rr(0.0, 0.18),
				"vel": Vector3(rng.rr(-1.2, 1.2), rng.rr(-2.0, -0.4), rng.rr(-1.2, 1.2)),
				"spin": Vector3(rng.rr(-0.7, 0.7), rng.rr(-0.4, 0.4), rng.rr(-0.7, 0.7)),
			})

	_add_road_ribbon_to_chunks(chunk_soups, chunk_centers, nch, ch_sz, bh)
	for ci in range(chunk_soups.size()):
		var mi := MeshInstance3D.new()
		mi.mesh = chunk_soups[ci].build()
		mi.material_override = gfx.mat_world
		chunk_nodes[ci].add_child(mi)

	CWTerrainStructures._build_water_and_waterfall(self, rng)
	CWTerrainStructures._build_bridge(self)
	CWTerrainStructures._build_pads(self)
	CWTerrainStructures._build_keep_and_cave(self)
	CWTerrainScatter._scatter_landmarks_and_biome_props(self, rng)

	if mirrored:
		_apply_mirror_xz()
	_rebuild_nav_paths()
	_build_road_lut()
	return {
		"mirrored": mirrored,
		"layout": layout,
		"bio": bio,
		"pal": pal,
		"beacon_pos": beacon_pos,
		"waterfall_pos": waterfall_pos,
		"has_waterfall": has_waterfall,
		"env_lights": env_lights,
		"keep_fires": keep_fires,
		"pond_centers": pond_centers,
	}


func _add_road_ribbon_to_chunks(chunk_soups: Array[CWGfx.Soup], chunk_centers: Array[Vector3], nch: int, ch_sz: float, bh: float) -> void:
	# Smooth curved 9-column cobblestone road ribbon ported 1:1 from 31-terrain.js:215-237
	var road: Array[Vector2] = layout["road"]
	var n := road.size()
	if n < 4:
		return
	var tx_arr := PackedFloat32Array()
	var tz_arr := PackedFloat32Array()
	var py_arr := PackedFloat32Array()
	tx_arr.resize(n)
	tz_arr.resize(n)
	py_arr.resize(n)
	for i in range(n):
		var ia := maxi(0, i - 1)
		var ib := mini(n - 1, i + 1)
		var dx := road[ib].x - road[ia].x
		var dz := road[ib].y - road[ia].y
		var l := maxf(sqrt(dx * dx + dz * dz), 1e-4)
		tx_arr[i] = dx / l
		tz_arr[i] = dz / l
		py_arr[i] = height_at(road[i].x, road[i].y)
	var stream: Array[Vector2] = layout["stream"]
	var cross_pt := Vector2(1e6, 1e6)
	var best_cd := 1e9
	for i in range(1, n - 1):
		var cd := CWLayout.poly_min_dist(stream, road[i].x, road[i].y)
		if cd < best_cd:
			best_cd = cd
			cross_pt = road[i]
	var sd_f := float(seed_val % 997)
	var offs: Array[float] = [-1.62, -1.25, -0.85, -0.45, 0.0, 0.45, 0.85, 1.25, 1.62]
	var rows: Array[int] = []
	var ri := 0
	while ri < n:
		rows.append(ri)
		ri += 2
	if rows[rows.size() - 1] != n - 1:
		rows.append(n - 1)

	var make_vert := func(idx: int, k: int, ext: float) -> Dictionary:
		var off: float = offs[k]
		var s_dist := float(idx) * CWLayout.PATH_STEP
		var wj := (1.0 + (CWUtil.fbm2(s_dist * 0.5, float(k), 2, sd_f + 20.0) - 0.5) * 0.28) if absf(off) > 1.3 else 1.0
		var ii := clampi(idx, 0, n - 1)
		var vx := road[ii].x + tx_arr[ii] * ext - tz_arr[ii] * off * wj
		var vz := road[ii].y + tz_arr[ii] * ext + tx_arr[ii] * off * wj
		var on_bridge := Vector2(road[ii].x, road[ii].y).distance_to(cross_pt) < 2.25
		var vy := maxf(py_arr[ii], height_at(vx, vz)) + 0.045 * (1.0 - (off / 1.25) * (off / 1.25)) + 0.025
		var nz := CWUtil.fbm2(vx * 0.45, vz * 0.45, 2, sd_f + 21.0)
		var c: Color = pal["road"] * (0.78 + 0.42 * nz)
		var rough := 0.62
		var rut := smoothstep(0.38, 0.62, CWUtil.fbm2(s_dist * 0.22, 3.0 if off > 0.0 else 9.0, 2, sd_f + 23.0)) if absf(absf(off) - 0.62) < 0.3 else 0.0
		c = c.lerp(pal["roadD"], rut * 0.72)
		vy -= rut * 0.022
		var mud := 0.0 if on_bridge else smoothstep(0.57, 0.70, CWUtil.fbm2(vx * 0.3 + 7.0, vz * 0.3, 2, sd_f + 25.0))
		c = c.lerp(pal["mud"], mud * 0.85)
		rough = lerpf(rough, 0.30, mud) - rut * 0.12
		var lyr := CWGfx.L_COBBLE
		if absf(off) > 1.3:
			c = c.lerp(pal["earth"], 0.82)
			rough = 0.95
			vy = (py_arr[ii] - 0.04) if on_bridge else (height_at(vx, vz) + 0.012)
			lyr = CWGfx.L_DIRT
		if on_bridge:
			vy -= 0.18
		c.a = 1.0
		return {"p": Vector3(vx, vy, vz), "c": c, "r": clampf(rough, 0.18, 0.98), "l": lyr}

	var rv: Array = []
	for row_i in rows:
		var line: Array = []
		for k in range(offs.size()):
			line.append(make_vert.call(row_i, k, 0.0))
		rv.append(line)
	var ext_line: Array = []
	for k in range(offs.size()):
		ext_line.append(make_vert.call(n - 1, k, 1.3))
	rv.append(ext_line)

	for r in range(rv.size() - 1):
		for k in range(offs.size() - 1):
			var a: Dictionary = rv[r][k]
			var b: Dictionary = rv[r][k + 1]
			var c: Dictionary = rv[r + 1][k + 1]
			var d: Dictionary = rv[r + 1][k]
			var pa: Vector3 = a["p"]
			var pc: Vector3 = c["p"]
			var mx := (pa.x + pc.x) * 0.5
			var mz := (pa.z + pc.z) * 0.5
			var cx := clampi(int(floorf((mx + bh) / ch_sz)), 0, nch - 1)
			var cz := clampi(int(floorf((mz + bh) / ch_sz)), 0, nch - 1)
			var ci := cz * nch + cx
			var soup: CWGfx.Soup = chunk_soups[ci]
			var ctr: Vector3 = chunk_centers[ci]
			var pb: Vector3 = b["p"]
			var up_n := (pc - pa).cross(pb - pa)
			var quad_v: Array = [a, b, c, a, c, d] if up_n.y >= 0.0 else [a, d, c, a, c, b]
			var quad_lyr: int = CWGfx.L_DIRT if (int(a["l"]) == CWGfx.L_DIRT or int(b["l"]) == CWGfx.L_DIRT) else CWGfx.L_COBBLE
			for vv in quad_v:
				var vd: Dictionary = vv
				var wp: Vector3 = vd["p"]
				soup.add_v(wp - ctr, Vector3.UP, vd["c"], Vector2(wp.x * 0.28, wp.z * 0.28), quad_lyr, float(vd["r"]))


func _grid_pt(x0: float, z0: float, ix: int, iz: int, step: float, cells: int, center: Vector3) -> Vector3:
	var wx := x0 + float(ix) * step
	var wz := z0 + float(iz) * step
	if ix > 0 and ix < cells:
		wx += (CWUtil.h2(wx * 2.0, wz * 2.0, float(seed_val % 53)) - 0.5) * 0.26
	if iz > 0 and iz < cells:
		wz += (CWUtil.h2(wx * 2.0, wz * 2.0, float((seed_val + 17) % 53)) - 0.5) * 0.26
	var wy := height_at(wx, wz)
	return Vector3(wx - center.x, wy, wz - center.z)


func _add_chunk_skirts(soup: CWGfx.Soup, x0: float, z0: float, ch_sz: float, center: Vector3, step: float, cx: int, cz: int, nch: int) -> void:
	# Exact 31-terrain.js:173-198 horizontal stepped geological strata cutaway walls + Emberscar glowing magma veins
	var strata: Array = bio.get("strata", [0x555555])
	var is_ember := (String(bio.get("key", "")) == "ember")
	var sd_f := float(seed_val % 997)
	var lv: Array[float] = []
	var y_lv := 12.0
	var li := 0
	while y_lv > -8.5:
		lv.append(y_lv)
		y_lv -= 0.52 + 0.90 * CWUtil.h2(float(li), 9.0, sd_f + 47.0)
		li += 1
	lv.append(-99.0)

	var emit_col := func(ax: float, az: float, ay: float, bx: float, bz: float, by: float, ox: float, oz: float, t0_s: float, t1_s: float) -> void:
		var bot_a := -4.8 - 1.8 * CWUtil.fbm2(t0_s * 0.45, 1.7, 2, sd_f + 43.0)
		var bot_b := -4.8 - 1.8 * CWUtil.fbm2(t1_s * 0.45, 1.7, 2, sd_f + 43.0)
		var y_a := ay
		var y_b := by
		var in_a := 0.0
		var in_b := 0.0
		var lvl := minf(ay, by) - 0.32
		var j := 0
		while j < lv.size() - 1 and lv[j] > lvl - 0.25:
			j += 1
		for stp in range(22):
			var wob := 0.16 if stp > 0 else 0.0
			var lo_a := maxf(lvl + wob * (CWUtil.n2(t0_s * 1.3, float(j), sd_f + 46.0) - 0.5), bot_a)
			var lo_b := maxf(lvl + wob * (CWUtil.n2(t1_s * 1.3, float(j), sd_f + 46.0) - 0.5), bot_b)
			var vk := smoothstep(0.45, 0.68, CWUtil.n2(t0_s * 0.35, float(j) * 1.7, sd_f + 48.0)) if (is_ember and stp > 0 and (j % 5) == 2) else 0.0
			var base_c: Color = pal["earthD"] * 1.1 if stp == 0 else CWUtil.hex_color(strata[(j * 3 + int(floorf(CWUtil.h2(float(j), 7.0, sd_f + 40.0) * 3.0))) % strata.size()]) * (0.82 + 0.32 * CWUtil.h2(float(j), 3.0, sd_f + 41.0))
			var col: Color = base_c.lerp(Color(0.95, 0.28, 0.04), vk) if vk > 0.01 else base_c
			col.a = 1.0
			var em := (0.08 + 0.45 * vk) if vk > 0.01 else 0.0
			var a1 := Vector3(ax - ox * in_a - center.x, y_a, az - oz * in_a - center.z)
			var a2 := Vector3(ax - ox * in_a - center.x, lo_a, az - oz * in_a - center.z)
			var b2 := Vector3(bx - ox * in_b - center.x, lo_b, bz - oz * in_b - center.z)
			var b1 := Vector3(bx - ox * in_b - center.x, y_b, bz - oz * in_b - center.z)
			if y_a - lo_a > 0.01 or y_b - lo_b > 0.01:
				var fn_w := (b2 - a1).cross(a2 - a1)
				var lyr := CWGfx.L_DIRT if stp == 0 else CWGfx.L_ROCK
				if fn_w.x * ox + fn_w.z * oz >= 0.0:
					soup.add_quad(a1, a2, b2, b1, col, lyr, 0.96, 0.0, em)
				else:
					soup.add_quad(a1, b1, b2, a2, col, lyr, 0.96, 0.0, em)
			if lvl <= bot_a and lvl <= bot_b:
				break
			var nl: float = lv[j]
			j = mini(j + 1, lv.size() - 1)
			var ib := -(float(j & 1) * 0.12) if (nl + 0.4) > -0.5 else -(minf(0.85, (-0.5 - (nl + 0.4)) * 0.18) + float(j & 1) * 0.18)
			var n_a := ib + (CWUtil.n2(t0_s * 0.8, float(j) * 3.1, sd_f + 45.0) - 0.5) * 0.12
			var n_b := ib + (CWUtil.n2(t1_s * 0.8, float(j) * 3.1, sd_f + 45.0) - 0.5) * 0.12
			var l1 := Vector3(ax - ox * n_a - center.x, lo_a, az - oz * n_a - center.z)
			var l2 := Vector3(bx - ox * n_b - center.x, lo_b, bz - oz * n_b - center.z)
			var top_c := col * 1.25
			top_c.a = 1.0
			soup.add_quad(a2, l1, l2, b2, top_c, CWGfx.L_ROCK, 0.96, 0.0, em)
			soup.add_quad(a2, b2, l2, l1, col.darkened(0.50), CWGfx.L_ROCK, 0.96)
			y_a = lo_a; y_b = lo_b; in_a = n_a; in_b = n_b; lvl = nl

	var cells := int(ch_sz / step)
	for i in range(cells):
		var t0 := float(i) * step
		var t1 := t0 + step
		if cz == nch - 1:
			var sx0 := x0 + t0; var sx1 := x0 + t1; var sz := z0 + ch_sz
			emit_col.call(sx0, sz, height_at(sx0, sz), sx1, sz, height_at(sx1, sz), 0.0, 1.0, sx0 + 50.0, sx1 + 50.0)
		if cx == nch - 1:
			var ex := x0 + ch_sz; var ez0 := z0 + t0; var ez1 := z0 + t1
			emit_col.call(ex, ez0, height_at(ex, ez0), ex, ez1, height_at(ex, ez1), 1.0, 0.0, ez0 + 150.0, ez1 + 150.0)
		if cz == 0:
			var nx0 := x0 + t0; var nx1 := x0 + t1; var nz := z0
			emit_col.call(nx0, nz, height_at(nx0, nz), nx1, nz, height_at(nx1, nz), 0.0, -1.0, nx0, nx1)
		if cx == 0:
			var wx_e := x0; var wz0 := z0 + t0; var wz1 := z0 + t1
			emit_col.call(wx_e, wz0, height_at(wx_e, wz0), wx_e, wz1, height_at(wx_e, wz1), -1.0, 0.0, wz0 + 100.0, wz1 + 100.0)


func _add_chunk_props(parent: Node3D, x0: float, z0: float, ch_sz: float, center: Vector3, rng: CWUtil.Rng) -> void:
	var soup := CWGfx.Soup.new()
	var style: String = bio.get("tree_style", "dead")
	var trees_here := 1 if rng.next_f() < 0.6 else 0
	var rocks_here := rng.ri(2, 4)
	var tufts_here := rng.ri(5, 10)

	for _t in range(trees_here):
		var wx := rng.rr(x0 + 0.8, x0 + ch_sz - 0.8)
		var wz := rng.rr(z0 + 0.8, z0 + ch_sz - 0.8)
		if _is_blocked_for_prop(wx, wz):
			continue
		var wy := height_at(wx, wz)
		_build_tree(soup, Vector3(wx - center.x, wy, wz - center.z), style, rng)

	for _r in range(rocks_here):
		var wx := rng.rr(x0 + 0.5, x0 + ch_sz - 0.5)
		var wz := rng.rr(z0 + 0.5, z0 + ch_sz - 0.5)
		if _is_blocked_for_prop(wx, wz):
			continue
		var wy := height_at(wx, wz)
		var rad := rng.rr(0.24, 0.68)
		soup.add_rock(rad, Vector3(wx - center.x, wy + rad * 0.22, wz - center.z), pal["stone"].lerp(pal["stoneD"], rng.rr(0.0, 0.65)), rng.ri(1, 99999), CWGfx.L_ROCK, 0.93, Vector3(1.15, 0.68, 1.0))

	# Roadside wooden palisade fences & supply barrels/crates
	if rng.next_f() < 0.42:
		var wx := rng.rr(x0 + 0.8, x0 + ch_sz - 0.8)
		var wz := rng.rr(z0 + 0.8, z0 + ch_sz - 0.8)
		var dr := _sample_grid(_grid_dr, wx, wz)
		if dr > 1.55 and dr < 2.25 and _sample_grid(_grid_ds, wx, wz) > 1.8:
			var wy := height_at(wx, wz)
			var lp := Vector3(wx - center.x, wy, wz - center.z)
			if rng.next_f() < 0.5:
				# Wooden palisade posts
				for p_i in range(3):
					soup.add_box(Vector3(0.11, 0.62, 0.11), lp + Vector3(float(p_i - 1) * 0.26, 0.31, 0), pal["woodD"], CWGfx.L_WOOD, 0.9)
				soup.add_box(Vector3(0.75, 0.08, 0.08), lp + Vector3(0, 0.42, 0), pal["wood"], CWGfx.L_WOOD, 0.88)
			elif rng.next_f() < 0.45:
				# Broken wooden supply cart
				soup.add_box(Vector3(1.1, 0.10, 0.65), lp + Vector3(0, 0.38, 0), pal["wood"], CWGfx.L_WOOD, 0.88)
				soup.add_box(Vector3(1.1, 0.24, 0.06), lp + Vector3(0, 0.54, 0.32), pal["woodD"], CWGfx.L_WOOD, 0.88)
				soup.add_box(Vector3(1.1, 0.24, 0.06), lp + Vector3(0, 0.54, -0.32), pal["woodD"], CWGfx.L_WOOD, 0.88)
				soup.add_cyl(0.28, 0.28, 0.08, lp + Vector3(-0.1, 0.28, 0.38), pal["woodD"], 8, CWGfx.L_WOOD, 0.9, Vector3(PI * 0.5, 0, 0))
				soup.add_cyl(0.28, 0.28, 0.08, lp + Vector3(-0.1, 0.28, -0.38), pal["woodD"], 8, CWGfx.L_WOOD, 0.9, Vector3(PI * 0.5, 0, 0))
			elif rng.next_f() < 0.5:
				# Stone well with pitched slate roof
				soup.add_cyl(0.46, 0.44, 0.48, lp + Vector3(0, 0.24, 0), pal["stone"], 8, CWGfx.L_MASON, 0.9)
				soup.add_box(Vector3(0.08, 1.25, 0.08), lp + Vector3(-0.46, 0.62, 0), pal["woodD"], CWGfx.L_WOOD, 0.9)
				soup.add_box(Vector3(0.08, 1.25, 0.08), lp + Vector3(0.46, 0.62, 0), pal["woodD"], CWGfx.L_WOOD, 0.9)
				soup.add_box(Vector3(1.15, 0.06, 0.45), lp + Vector3(0, 1.32, 0.18), Color(0.26, 0.29, 0.36), CWGfx.L_SLATE, 0.86, Vector3(0.55, 0, 0))
				soup.add_box(Vector3(1.15, 0.06, 0.45), lp + Vector3(0, 1.32, -0.18), Color(0.26, 0.29, 0.36), CWGfx.L_SLATE, 0.86, Vector3(-0.55, 0, 0))
			else:
				# Barrel + gravestone + glowing roadside torch
				soup.add_cyl(0.18, 0.16, 0.38, lp + Vector3(0.22, 0.19, 0), pal["wood"], 6, CWGfx.L_WOOD, 0.86)
				soup.add_box(Vector3(0.36, 0.58, 0.12), lp + Vector3(0.55, 0.29, 0.25), pal["stoneD"], CWGfx.L_ROCK, 0.92, Vector3(0.1, 0.2, -0.1))
				soup.add_seg(lp + Vector3(-0.2, 0, 0), lp + Vector3(-0.2, 0.95, 0), 0.035, 0.03, pal["woodD"], 4, CWGfx.L_WOOD, 0.9)
				soup.add_cyl(0.06, 0.09, 0.10, lp + Vector3(-0.2, 0.99, 0), pal["iron"], 6, CWGfx.L_METAL, 0.55)
				keep_fires.append(center + lp + Vector3(-0.2, 1.04, 0))

	for _g in range(tufts_here):
		var wx := rng.rr(x0 + 0.3, x0 + ch_sz - 0.3)
		var wz := rng.rr(z0 + 0.3, z0 + ch_sz - 0.3)
		if _sample_grid(_grid_dr, wx, wz) < 1.55 or _sample_grid(_grid_ds, wx, wz) < 1.35:
			continue
		var wy := height_at(wx, wz)
		if wy > 1.3:
			continue
		var lp := Vector3(wx - center.x, wy, wz - center.z)
		if String(bio.get("key", "")) == "fen" and rng.next_f() < 0.16:
			soup.add_cyl(0.04, 0.03, 0.22, lp + Vector3(0, 0.11, 0), Color(0.6, 0.65, 0.55), 5, CWGfx.L_PLAIN, 0.8)
			soup.add_cone(0.15, 0.10, lp + Vector3(0, 0.24, 0), Color(0.35, 1.0, 0.55), 6, CWGfx.L_PLAIN, 0.4, Vector3.ZERO, 0.0, 1.8)
		else:
			var tc: Color = pal["tuftA"].lerp(pal["tuftB"], rng.next_f())
			var th := rng.rr(0.22, 0.42)
			soup.add_cone(0.08, th, lp + Vector3(0, th * 0.5, 0), tc, 4, CWGfx.L_LEAF, 0.9, Vector3(rng.rr(-0.2, 0.2), rng.rr(0, TAU), rng.rr(-0.2, 0.2)), 0.7)

	if soup.vert_count > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = soup.build()
		mi.material_override = gfx.mat_world
		parent.add_child(mi)


func _is_blocked_for_prop(wx: float, wz: float) -> bool:
	if _sample_grid(_grid_dr, wx, wz) < 2.2:
		return true
	if _sample_grid(_grid_ds, wx, wz) < 1.8:
		return true
	for pad in layout["pads"]:
		if Vector2(wx, wz).distance_to(Vector2(pad["x"], pad["z"])) < 2.2:
			return true
	var cave: Vector2 = layout["cave"]
	var keep: Vector2 = layout["keep"]
	if Vector2(wx, wz).distance_to(cave) < 3.5 or Vector2(wx, wz).distance_to(keep) < 4.5:
		return true
	return false


func _build_tree(soup: CWGfx.Soup, lp: Vector3, style: String, rng: CWUtil.Rng) -> void:
	var h := rng.rr(2.5, 4.4)
	var bark: Color = pal["bark"]
	var leaf: Color = pal["leaf"]
	var leaf_l: Color = pal["leafL"]
	match style:
		"pine":
			var lx := rng.rr(-0.04, 0.04)
			var lz := rng.rr(-0.04, 0.04)
			soup.add_seg(lp + Vector3(0.0, -0.1, 0.0), lp + Vector3(lx * h, h * 0.92, lz * h), h * 0.052, h * 0.014, bark, 6, CWGfx.L_BARK, 0.92)
			var tiers := clampi(roundi(4.0 + h * 0.55), 5, 7)
			for tier in range(tiers):
				var u := float(tier) / float(maxi(1, tiers - 1))
				var ty := h * (0.22 + 0.66 * u)
				var tier_r := h * (0.30 - 0.20 * u) * rng.rr(0.88, 1.10)
				var thh := h * (0.32 - 0.11 * u)
				var tcol := leaf.lerp(leaf_l, rng.next_f() * 0.55 + u * 0.28) * rng.rr(0.84, 1.14)
				tcol.a = 1.0
				var trot := Vector3(rng.rr(-0.08, 0.08), rng.rr(0.0, TAU), rng.rr(-0.08, 0.08))
				soup.add_cone(tier_r, thh, lp + Vector3(lx * ty + rng.rr(-0.03, 0.03), ty + thh * 0.38, lz * ty + rng.rr(-0.03, 0.03)), tcol, 9, CWGfx.L_LEAF, 0.88, trot, 0.22 + u * 0.25)
		"palm":
			CWPropLib.stamp(soup, "palm", lp, rng.rr(0.0, TAU), (h * 1.15) / 3.6)
		"willow":
			CWPropLib.stamp(soup, "willow", lp, rng.rr(0.0, TAU), (h * 1.05) / 3.4)
			if rng.next_f() < 0.28:
				CWPropLib.stamp(soup, "web", lp + Vector3(0.0, h * 0.42, 0.0), rng.rr(0.0, TAU), 1.0)
		"charred":
			CWPropLib.stamp(soup, "gnarled_ember", lp, rng.rr(0.0, TAU), h / 3.4)
		_:
			CWPropLib.stamp(soup, "gnarled_tree", lp, rng.rr(0.0, TAU), h / 3.4)
			if String(bio.get("key", "")) in ["ashen", "fen"] and rng.next_f() < 0.25:
				CWPropLib.stamp(soup, "web", lp + Vector3(0.0, h * 0.42, 0.0), rng.rr(0.0, TAU), 0.96)


func get_chunk_node(wx: float, wz: float) -> Node3D:
	var bh := CWLayout.BH
	var cx := clampi(int(floorf((wx + bh) / CWLayout.CHUNK)), 0, CWLayout.NCH - 1)
	var cz := clampi(int(floorf((wz + bh) / CWLayout.CHUNK)), 0, CWLayout.NCH - 1)
	var idx := cz * CWLayout.NCH + cx
	if idx >= 0 and idx < chunks.size():
		return chunks[idx]["node"]
	return self


func _attach_to_chunk(mi: Node3D, world_pos: Vector3) -> void:
	var ch := get_chunk_node(world_pos.x, world_pos.z)
	mi.position = world_pos - ch.position
	ch.add_child(mi)


func sample_smooth_road(s_pos: float) -> Dictionary:
	if road_smooth.size() < 2:
		return CWLayout.sample_path(layout, s_pos)
	var total: float = maxf(float(layout.get("total_len", 1.0)), 1.0)
	var prog := clampf(s_pos / total, 0.0, 1.0)
	var f := prog * float(road_smooth.size() - 1)
	var i := mini(int(floorf(f)), road_smooth.size() - 2)
	var u := f - float(i)
	var a := road_smooth[i]
	var b := road_smooth[i + 1]
	return {
		"pos": a.lerp(b, u),
		"dir": (b - a).normalized(),
		"prog": prog,
	}


func _bake_terrain_grids() -> void:
	var sz := GRID_N * GRID_N
	_grid_h.resize(sz)
	_grid_dr.resize(sz)
	_grid_ds.resize(sz)
	var bh := CWLayout.BH
	var inv := (2.0 * bh) / float(GRID_N - 1)
	var road: Array[Vector2] = layout["road"]
	var stream: Array[Vector2] = layout["stream"]
	var pads: Array = layout["pads"]
	var cave: Vector2 = layout["cave"]
	var keep: Vector2 = layout["keep"]
	var r_step := maxi(1, int(floorf(float(road.size()) / 40.0)))
	var s_step := maxi(1, int(floorf(float(stream.size()) / 28.0)))
	var sd_f := float(seed_val % 131)
	var rx_arr := PackedFloat32Array()
	var rz_arr := PackedFloat32Array()
	var rk := 0
	while rk < road.size():
		rx_arr.append(road[rk].x)
		rz_arr.append(road[rk].y)
		rk += r_step
	var sx_arr := PackedFloat32Array()
	var sz_arr := PackedFloat32Array()
	var sk := 0
	while sk < stream.size():
		sx_arr.append(stream[sk].x)
		sz_arr.append(stream[sk].y)
		sk += s_step
	var px_arr := PackedFloat32Array()
	var pz_arr := PackedFloat32Array()
	for pad in pads:
		px_arr.append(float(pad["x"]))
		pz_arr.append(float(pad["z"]))
	var r_cnt := rx_arr.size()
	var s_cnt := sx_arr.size()
	var p_cnt := px_arr.size()
	var bkey_g: String = String(bio.get("key", ""))
	var rl_c := 1.15 if bkey_g in ["frost", "ember"] else (0.75 if bkey_g == "fen" else 1.0)

	for j in range(GRID_N):
		var wz := -bh + float(j) * inv
		var row_o := j * GRID_N
		for i in range(GRID_N):
			var wx := -bh + float(i) * inv
			var best_r := 1e9
			for k in range(r_cnt):
				var dx := rx_arr[k] - wx
				var dz := rz_arr[k] - wz
				var d2 := dx * dx + dz * dz
				if d2 < best_r:
					best_r = d2
			var dr := sqrt(best_r)
			var best_s := 1e9
			for k in range(s_cnt):
				var dx := sx_arr[k] - wx
				var dz := sz_arr[k] - wz
				var d2 := dx * dx + dz * dz
				if d2 < best_s:
					best_s = d2
			var ds := sqrt(best_s)
			_grid_dr[row_o + i] = dr
			_grid_ds[row_o + i] = ds

			var base := (CWUtil.fbm2(wx * 0.085, wz * 0.085, 2, sd_f) - 0.5) * 2.1
			var h := base * smoothstep(CWLayout.ROAD_HALF * 0.8, CWLayout.ROAD_HALF * 2.6, dr)
			for pi in range(p_cnt):
				var dxp := wx - px_arr[pi]
				var dzp := wz - pz_arr[pi]
				var dp2 := dxp * dxp + dzp * dzp
				if dp2 < 5.76:
					h *= smoothstep(1.2, 2.4, sqrt(dp2))
			# Exact 31-terrain.js:99-101: subtle raised riverbank berm + organic steep-banked channel + springhead basin
			if ds < 3.4:
				var berm := smoothstep(3.4, 2.0, ds) * smoothstep(0.8, 1.5, ds)
				h = maxf(h, lerpf(h, 0.24, berm))
			if ds < 2.15:
				var bed_w := 1.0 - smoothstep(0.55, 2.15, ds)
				h = lerpf(h, -0.72, bed_w)
			if not stream.is_empty():
				var dsrc := Vector2(wx, wz).distance_to(stream[0])
				if dsrc < 2.5:
					h = lerpf(h, -0.72, 1.0 - smoothstep(1.0, 2.5, dsrc))
			# Exact 31-terrain.js:116-123 rugged jagged cliffs + towering NW corner mountain peak (only compute near W/N edges)
			var cliff := 0.0
			if wx < -bh + 8.5 or wz < -bh + 8.5:
				var c_w := 0.0
				if wx < -bh + 7.2:
					var dcl := wx + bh + (CWUtil.fbm2(wz * 0.23 + 1.7, wx * 0.11, 2, sd_f + 9.0) - 0.5) * 2.6
					c_w = smoothstep(5.2, 1.2, dcl) * (3.6 + 2.8 * CWUtil.fbm2(wx * 0.21, wz * 0.21, 2, sd_f + 11.0) + 1.6 * smoothstep(4.0, -15.0, wz)) * rl_c
				var c_n := 0.0
				if wz < -bh + 6.8:
					var dbr := wz + bh + (CWUtil.fbm2(wx * 0.23 + 5.1, wz * 0.11, 2, sd_f + 13.0) - 0.5) * 2.4
					c_n = smoothstep(4.6, 1.0, dbr) * (2.2 + 2.4 * CWUtil.fbm2(wx * 0.20 + 9.0, wz * 0.20, 2, sd_f + 15.0)) * smoothstep(5.4, 7.6, absf(wx - keep.x)) * rl_c
				var nw_d := sqrt((wx + bh) * (wx + bh) + (wz + bh) * (wz + bh))
				cliff = maxf(c_w, c_n) + 2.2 * smoothstep(11.5, 1.0, nw_d) * smoothstep(7.2, 2.4, minf(wx + bh, wz + bh)) * rl_c
			if cliff > 0.02:
				var step_v := cliff / 1.20
				var fl := floorf(step_v)
				cliff = (fl + smoothstep(0.45, 0.90, step_v - fl)) * 1.20
			if wx < -12.2:
				cliff *= 1.0 - smoothstep(2.6, 1.6, absf(wz - cave.y)) * smoothstep(-12.2, -13.2, wx)
			for pad in pads:
				var dp_c := sqrt((wx - float(pad["x"])) * (wx - float(pad["x"])) + (wz - float(pad["z"])) * (wz - float(pad["z"])))
				cliff *= smoothstep(2.1, 3.8, dp_c)
			cliff *= smoothstep(1.4, 2.8, dr)
			h += cliff
			_grid_h[row_o + i] = h


func _sample_grid(grid: PackedFloat32Array, wx: float, wz: float) -> float:
	if grid.is_empty():
		return 0.0
	var bh := CWLayout.BH
	var u := clampf((wx + bh) / (2.0 * bh) * float(GRID_N - 1), 0.0, float(GRID_N - 1) - 0.001)
	var v := clampf((wz + bh) / (2.0 * bh) * float(GRID_N - 1), 0.0, float(GRID_N - 1) - 0.001)
	var ix := int(floorf(u))
	var iz := int(floorf(v))
	var fx := u - float(ix)
	var fz := v - float(iz)
	var o := iz * GRID_N + ix
	var a := lerpf(grid[o], grid[o + 1], fx)
	var b := lerpf(grid[o + GRID_N], grid[o + GRID_N + 1], fx)
	return lerpf(a, b, fz)


func height_at(wx: float, wz: float) -> float:
	var gx := wz if _mirror_active else wx
	var gz := wx if _mirror_active else wz
	var h := _sample_grid(_grid_h, gx, gz)
	if has_bridge:
		var db := Vector2(wx, wz).distance_to(bridge_pos)
		if db < 2.25:
			var w := smoothstep(2.25, 1.35, db)
			h = maxf(h, lerpf(h, 0.20, w))
	return h


func update_crumble(phase_t: float, fx: CWFx = null) -> bool:
	var all_done := true
	for ch in chunks:
		var t := maxf(0.0, phase_t - float(ch["delay"]))
		if t <= 0.0:
			all_done = false
			continue
		if fx != null and not bool(ch.get("fell", false)):
			ch["fell"] = true
			var hp: Vector3 = ch["home"]
			fx.spawn_dust(hp + Vector3(0, 0.3, 0), 4, 2.0, 1.8, 1.1)
			fx.add_shake(0.08)
		var node: Node3D = ch["node"]
		var home: Vector3 = ch["home"]
		var vel: Vector3 = ch["vel"]
		var spin: Vector3 = ch["spin"]
		var dy := -(9.0 * t * t + 1.2 * t)
		if dy > -34.0:
			all_done = false
		node.position = home + vel * t + Vector3(0.0, dy, 0.0)
		node.rotation = spin * t
	if water_mesh != null:
		water_mesh.visible = phase_t < 0.45
	return all_done


func update_rise(phase_t: float, dur: float = 1.15) -> bool:
	var all_done := true
	for ch in chunks:
		var u := clampf((phase_t - float(ch["delay"]) * 0.65) / maxf(dur, 0.1), 0.0, 1.0)
		if u < 1.0:
			all_done = false
		var k := pow(1.0 - u, 3.0)
		var node: Node3D = ch["node"]
		var home: Vector3 = ch["home"]
		node.position = home + Vector3(0.0, -30.0 * k, 0.0)
		node.rotation = Vector3.ZERO
	if water_mesh != null:
		water_mesh.visible = all_done or phase_t > dur * 0.85
	return all_done


func clear_board() -> void:
	for child in get_children():
		child.queue_free()
	chunks.clear()
	extra_meshes.clear()
	pad_meshes.clear()
	water_mesh = null
	has_bridge = false
	env_lights.clear()
	keep_fires.clear()
	pond_centers.clear()


func hide_crumble_extras() -> void:
	if water_mesh != null and is_instance_valid(water_mesh):
		water_mesh.visible = false
	for em in extra_meshes:
		if is_instance_valid(em):
			em.visible = false


func _mirror_mesh_xz(mesh: Mesh) -> ArrayMesh:
	if not (mesh is ArrayMesh):
		return null
	var am := mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s_i in range(am.get_surface_count()):
		var arr := am.surface_get_arrays(s_i)
		if arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var cust: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0] if arr[Mesh.ARRAY_CUSTOM0] != null else PackedFloat32Array()
		var idxs: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nv := verts.size()
		if idxs.size() > 0:
			for vi in range(nv):
				verts[vi] = Vector3(verts[vi].z, verts[vi].y, verts[vi].x)
			if norms.size() == nv:
				for ni in range(nv):
					norms[ni] = Vector3(norms[ni].z, norms[ni].y, norms[ni].x)
			var ii := 0
			while ii + 2 < idxs.size():
				var tmp_i := idxs[ii + 1]
				idxs[ii + 1] = idxs[ii + 2]
				idxs[ii + 2] = tmp_i
				ii += 3
			arr[Mesh.ARRAY_INDEX] = idxs
		else:
			var i := 0
			while i + 2 < nv:
				var v0 := Vector3(verts[i].z, verts[i].y, verts[i].x)
				var v1 := Vector3(verts[i + 2].z, verts[i + 2].y, verts[i + 2].x)
				var v2 := Vector3(verts[i + 1].z, verts[i + 1].y, verts[i + 1].x)
				verts[i] = v0; verts[i + 1] = v1; verts[i + 2] = v2
				if norms.size() == nv:
					var n0 := Vector3(norms[i].z, norms[i].y, norms[i].x)
					var n1 := Vector3(norms[i + 2].z, norms[i + 2].y, norms[i + 2].x)
					var n2 := Vector3(norms[i + 1].z, norms[i + 1].y, norms[i + 1].x)
					norms[i] = n0; norms[i + 1] = n1; norms[i + 2] = n2
				if cols.size() == nv:
					var c1 := cols[i + 1]; cols[i + 1] = cols[i + 2]; cols[i + 2] = c1
				if uvs.size() == nv:
					var u1 := uvs[i + 1]; uvs[i + 1] = uvs[i + 2]; uvs[i + 2] = u1
				if cust.size() == (nv * 4):
					for ci in range(4):
						var t1 := cust[(i + 1) * 4 + ci]
						cust[(i + 1) * 4 + ci] = cust[(i + 2) * 4 + ci]
						cust[(i + 2) * 4 + ci] = t1
				i += 3
		arr[Mesh.ARRAY_VERTEX] = verts
		if norms.size() == nv: arr[Mesh.ARRAY_NORMAL] = norms
		if cols.size() == nv: arr[Mesh.ARRAY_COLOR] = cols
		if uvs.size() == nv: arr[Mesh.ARRAY_TEX_UV] = uvs
		if cust.size() == (nv * 4): arr[Mesh.ARRAY_CUSTOM0] = cust
		var fmt_flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) if cust.size() == (nv * 4) else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt_flags)
	return out

func _mirror_subtree_xz(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.position = Vector3(mi.position.z, mi.position.y, mi.position.x)
		if mi.mesh != null:
			var mm := _mirror_mesh_xz(mi.mesh)
			if mm != null:
				mi.mesh = mm
	elif node is Node3D and node != self:
		var n3 := node as Node3D
		n3.position = Vector3(n3.position.z, n3.position.y, n3.position.x)
	for ch in node.get_children():
		_mirror_subtree_xz(ch)


func _apply_mirror_xz() -> void:
	_mirror_subtree_xz(self)
	for ch in chunks:
		var h: Vector3 = ch["home"]
		ch["home"] = Vector3(h.z, h.y, h.x)
	beacon_pos = Vector3(beacon_pos.z, beacon_pos.y, beacon_pos.x)
	waterfall_pos = Vector3(waterfall_pos.z, waterfall_pos.y, waterfall_pos.x)
	bridge_pos = Vector2(bridge_pos.y, bridge_pos.x)
	for i in range(keep_fires.size()):
		var kf := keep_fires[i]
		keep_fires[i] = Vector3(kf.z, kf.y, kf.x)
	for i in range(pond_centers.size()):
		var pc := pond_centers[i]
		pond_centers[i] = Vector3(pc.z, pc.y, pc.x)
	for el in env_lights:
		var ep: Vector3 = el["pos"]
		el["pos"] = Vector3(ep.z, ep.y, ep.x)
	for i in range(road_smooth.size()):
		var rs := road_smooth[i]
		road_smooth[i] = Vector2(rs.y, rs.x)
	if not layout.is_empty():
		var rd: Array = layout["road"]
		for i in range(rd.size()):
			var v: Vector2 = rd[i]
			rd[i] = Vector2(v.y, v.x)
		var st: Array = layout["stream"]
		for i in range(st.size()):
			var v: Vector2 = st[i]
			st[i] = Vector2(v.y, v.x)
		for pd in layout["pads"]:
			var px := float(pd["x"])
			pd["x"] = float(pd["z"])
			pd["z"] = px
		var cv: Vector2 = layout["cave"]
		layout["cave"] = Vector2(cv.y, cv.x)
		var kp: Vector2 = layout["keep"]
		layout["keep"] = Vector2(kp.y, kp.x)
		var cp: Vector2 = layout["cross_pt"]
		layout["cross_pt"] = Vector2(cp.y, cp.x)
		layout["stream_front"] = not bool(layout.get("stream_front", true))
	_mirror_active = true


func _rebuild_nav_paths() -> void:
	if road_path != null and is_instance_valid(road_path):
		road_path.queue_free()
	road_path = Path3D.new()
	road_path.name = "RoadPath"
	var r_curve := Curve3D.new()
	var r_pts: Array = layout.get("road", [])
	for pt_v in r_pts:
		var pt: Vector2 = pt_v
		var rx: float = pt.y if mirrored else pt.x
		var rz: float = pt.x if mirrored else pt.y
		r_curve.add_point(Vector3(rx, height_at(rx, rz), rz))
	road_path.curve = r_curve
	add_child(road_path)


func _build_road_lut() -> void:
	var total_len: float = float(layout.get("total_len", 1.0))
	var step := 0.2
	var n := maxi(2, int(ceilf(total_len / step)) + 2)
	var rx := PackedFloat32Array(); rx.resize(n)
	var ry := PackedFloat32Array(); ry.resize(n)
	var rz := PackedFloat32Array(); rz.resize(n)
	var px := PackedFloat32Array(); px.resize(n)
	var pz := PackedFloat32Array(); pz.resize(n)
	var ryaw := PackedFloat32Array(); ryaw.resize(n)
	var rcy := PackedFloat32Array(); rcy.resize(n)
	var rsy := PackedFloat32Array(); rsy.resize(n)
	for k in range(n):
		var s_val := minf(float(k) * step, total_len)
		var smp := CWLayout.sample_path(layout, s_val)
		var p: Vector2 = smp["pos"]
		var d: Vector2 = smp["dir"]
		var wx: float = p.y if _mirror_active else p.x
		var wz: float = p.x if _mirror_active else p.y
		var dx: float = d.y if _mirror_active else d.x
		var dz: float = d.x if _mirror_active else d.y
		var yw := atan2(dx, dz)
		rx[k] = wx
		ry[k] = height_at(wx, wz)
		rz[k] = wz
		px[k] = -dz
		pz[k] = dx
		ryaw[k] = yw
		rcy[k] = cos(yw)
		rsy[k] = sin(yw)
	road_lut = {
		"step_inv": 1.0 / step,
		"last": n - 1,
		"rx": rx, "ry": ry, "rz": rz,
		"px": px, "pz": pz,
		"yaw": ryaw, "cy": rcy, "sy": rsy,
	}
