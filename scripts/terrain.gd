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
var stream_path: Path3D = null
var pond_centers: Array[Vector3] = []
var pad_meshes: Array[MeshInstance3D] = []
var road_smooth: Array[Vector2] = []
var water_mesh: MeshInstance3D = null
var extra_meshes: Array[MeshInstance3D] = []
var seed_val: int = 1
var mirrored: bool = false
var _mirror_active: bool = false

const Props := preload("res://scripts/props.gd")
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

	_build_water_and_waterfall(rng)
	_build_bridge()
	_build_pads()
	_build_keep_and_cave()
	_scatter_landmarks_and_biome_props(rng)

	if mirrored:
		_apply_mirror_xz()
	_rebuild_nav_paths()
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
			Props.add_palm(soup, lp, h * 1.15, pal, rng)
		"willow":
			Props.add_willow(soup, lp, h * 1.05, pal, rng)
			if rng.next_f() < 0.28:
				Props.add_web(soup, lp + Vector3(0.0, h * 0.42, 0.0), rng.rr(0.0, TAU), 0.52)
		"charred":
			Props.add_gnarled_tree(soup, lp, h, pal, rng, true)
		_:
			Props.add_gnarled_tree(soup, lp, h, pal, rng, false)
			if String(bio.get("key", "")) in ["ashen", "fen"] and rng.next_f() < 0.25:
				Props.add_web(soup, lp + Vector3(0.0, h * 0.42, 0.0), rng.rr(0.0, TAU), 0.50)


func _build_water_and_waterfall(rng: CWUtil.Rng) -> void:
	var stream: Array[Vector2] = layout["stream"]
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
		var scol: Color = pal["stoneD"].lerp(pal["stone"], rng.next_f())
		sp_soup.add_rock(srad, Vector3(sx, height_at(sx, sz) + srad * 0.22, sz), scol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.15, 0.75, 1.05))
	if sp_soup.vert_count > 0:
		var spmi := MeshInstance3D.new()
		spmi.mesh = sp_soup.build()
		spmi.material_override = gfx.mat_world
		add_child(spmi)
		extra_meshes.append(spmi)

	# 14-row parabolic waterfall sheet + stone outfall lip & flanking rocks (31-terrain.js:306-315, 381-391)
	var end_pt := stream[stream.size() - 1]
	var is_front := bool(layout.get("stream_front", true))
	has_waterfall = true
	var fx := clampf(end_pt.x, -CWLayout.BH + 1.5, CWLayout.BH - 1.5) if is_front else CWLayout.BH
	var fz := CWLayout.BH if is_front else clampf(end_pt.y, -CWLayout.BH + 1.5, CWLayout.BH - 1.5)
	var ox := 0.0 if is_front else 1.0
	var oz := 1.0 if is_front else 0.0
	var ax := -oz
	var az := ox
	var ext := 0.55
	var v0 := 1.55
	var fw := 1.15
	waterfall_pos = Vector3(fx + ox * (ext + 0.6), end_y - 3.6, fz + oz * (ext + 0.6))

	# Stone outfall lip & 4 flanking rocks framing the waterfall mouth
	var lip_sp := CWGfx.Soup.new()
	var rc: Color = pal["stoneD"].lerp(pal["stone"], 0.45)
	var lip_c := Vector3(ox * (ext * 0.35), -0.42, oz * (ext * 0.35))
	var lip_sz := Vector3(ext + 0.7, 0.48, fw * 2.0 + 0.9) if not is_front else Vector3(fw * 2.0 + 0.9, 0.48, ext + 0.7)
	lip_sp.add_box(lip_sz, lip_c, rc, CWGfx.L_ROCK, 0.92)
	lip_sp.add_rock(fw * 0.55 + 0.15, Vector3(ox * 0.12, -0.78, oz * 0.12), pal["stoneD"], 701, CWGfx.L_ROCK, 0.94, Vector3(1.1, 0.55, 1.1))
	for sd2: float in [-1.0, 1.0]:
		lip_sp.add_rock(0.46, Vector3(ox * 0.08 + ax * sd2 * (fw + 0.28), 0.12, oz * 0.08 + az * sd2 * (fw + 0.28)), rc, 710 + int(sd2 + 2.0), CWGfx.L_ROCK, 0.92, Vector3(1.0, 0.72, 1.0))
		lip_sp.add_rock(0.32, Vector3(ox * (ext * 0.62) + ax * sd2 * (fw + 0.24), 0.02, oz * (ext * 0.62) + az * sd2 * (fw + 0.24)), pal["stoneD"], 720 + int(sd2 + 2.0), CWGfx.L_ROCK, 0.92, Vector3(1.0, 0.72, 1.0))
	var lip_mi := MeshInstance3D.new()
	lip_mi.mesh = lip_sp.build()
	lip_mi.material_override = gfx.mat_world
	_attach_to_chunk(lip_mi, Vector3(fx, end_y, fz))

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
	fall_mi.material_override = gfx.mat_fall
	fall_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach_to_chunk(fall_mi, Vector3(fx, end_y, fz))

	# Reflective puddles along the cobblestone road (disabled in Emberscar/Dunes)
	var bkey_w: String = String(bio.get("key", "ashen"))
	var road: Array[Vector2] = layout["road"]
	var n_road_p := 0 if (bkey_w == "ember" or bkey_w == "dunes") else 6
	for _p in range(n_road_p):
		var idx := rng.ri(8, maxi(9, road.size() - 10))
		var rp := road[idx] + Vector2(rng.rr(-0.45, 0.45), rng.rr(-0.45, 0.45))
		var py := height_at(rp.x, rp.y) + 0.03
		var pr := rng.rr(0.42, 0.72)
		soup.add_cyl(pr, pr, 0.02, Vector3(rp.x, py, rp.y), Color.WHITE, 8, 0, 0.08, Vector3.ZERO, 0.0, 0.0)

	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = soup.build()
	water_mesh.material_override = gfx.mat_water
	add_child(water_mesh)


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


func _build_bridge() -> void:
	# 1:1 port of buildBridge() in 32-props.js:200-225 (6.2m arched masonry bridge + 9-stone arch + spandrels + 4 corner finial piers + Frost icicles)
	var road: Array[Vector2] = layout["road"]
	var stream: Array[Vector2] = layout["stream"]
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
	var rng := CWUtil.Rng.new(seed_val + 409)
	var soup := CWGfx.Soup.new()

	var y0 := 0.06
	var bed := -0.78 - y0
	var spring := -0.22 - y0
	var w_half := CWLayout.ROAD_HALF + 0.22
	var arch_a := 1.25
	var crown := 0.18 - 0.32
	var sd_col: Color = pal["stoneD"]
	var sl_col: Color = pal["stoneL"]

	# 8-segment 4.64m arched span fits cleanly over the river without overshooting road bends
	for k in range(-4, 4):
		var u := (float(k) + 0.5) * 0.58
		var top := 0.18 * cos(clampf(u / 2.55, -1.0, 1.0) * PI * 0.5)
		if absf(u) < 1.85:
			soup.add_box(Vector3(w_half * 2.0 - 0.14, 0.16, 0.60), Vector3(0.0, top - 0.08, u), pal["road"], CWGfx.L_COBBLE, 0.86)
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
	if String(bio.get("key", "")) == "frost":
		for side: float in [-1.0, 1.0]:
			var u_ic := -1.15
			while u_ic <= 1.16:
				var h_ic := rng.rr(0.14, 0.52)
				var y_ic := spring + (crown - spring) * sqrt(maxf(0.0, 1.0 - (u_ic / arch_a) * (u_ic / arch_a)))
				soup.add_cone(rng.rr(0.04, 0.07), h_ic, Vector3(side * (w_half + 0.03), y_ic - h_ic * 0.5 - 0.04, u_ic), Color(0.68, 0.88, 1.0), 5, CWGfx.L_PLAIN, 0.16, Vector3(PI, 0.0, 0.0), 0.0, 0.45)
				u_ic += 0.21

	var mi := MeshInstance3D.new()
	mi.mesh = soup.build()
	mi.material_override = gfx.mat_world
	bridge_pos = p
	has_bridge = true
	mi.rotation.y = yaw
	_attach_to_chunk(mi, Vector3(p.x, y0, p.y))


func _build_pads() -> void:
	# Upstream 32-props.js:227-238 + 90-main.js:152-158: bright brass-inlaid octagonal pads & golden pennant markers
	pad_meshes.clear()
	var rng := CWUtil.Rng.new(seed_val + 777)
	var bkey: String = String(bio.get("key", "ashen"))
	var bright := (bkey == "frost" or bkey == "dunes")
	var top_col := Color(0.353, 0.376, 0.439) if bright else Color(0.557, 0.573, 0.620)
	var rim_col := Color(0.212, 0.227, 0.275) if bright else Color(0.337, 0.353, 0.400)
	var brass_col := Color(0.95, 0.72, 0.24) if bright else Color(0.84, 0.63, 0.22)
	var gold_col := Color(0.92, 0.70, 0.22)
	var amber_col := Color(0.79, 0.41, 0.16)

	# Build smoothed road centerline for flyers (31-terrain.js:403)
	var road: Array[Vector2] = layout["road"]
	road_smooth.clear()
	var rn := road.size()
	for ri in range(rn):
		var w := mini(5, mini(ri, rn - 1 - ri))
		var acc := Vector2.ZERO
		for dk in range(-w, w + 1):
			acc += road[ri + dk]
		road_smooth.append(acc / float(2 * w + 1))

	var pad_pick_shape := CylinderShape3D.new()
	pad_pick_shape.radius = 1.55
	pad_pick_shape.height = 0.55

	for pad in layout["pads"]:
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
		mi.material_override = gfx.mat_world
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
		_attach_to_chunk(mi, Vector3(pad["x"], pad["y"], pad["z"]))
		pad_meshes.append(mi)

		# Golden-tipped empty-pad pennant marker (hidden when a tower is built)
		var msp := CWGfx.Soup.new()
		msp.add_box(Vector3(0.08, 1.15, 0.08), Vector3(0, 0.57, 0), pal["woodD"], CWGfx.L_WOOD, 0.90, Vector3(0, 0, 0.05))
		msp.add_cone(0.07, 0.14, Vector3(0.03, 1.20, 0), brass_col, 4, CWGfx.L_METAL, 0.45, Vector3.ZERO, 0.0, 0.25)
		msp.add_box(Vector3(0.46, 0.34, 0.04), Vector3(0.28, 0.88, 0), gold_col.lerp(amber_col, 0.4), CWGfx.L_CLOTH, 0.85, Vector3.ZERO, 0.45, 0.22)
		msp.add_box(Vector3(0.22, 0.18, 0.04), Vector3(0.56, 0.88, 0), gold_col, CWGfx.L_CLOTH, 0.85, Vector3.ZERO, 0.65, 0.26)
		var mmi := MeshInstance3D.new()
		mmi.mesh = msp.build()
		mmi.material_override = gfx.mat_world
		_attach_to_chunk(mmi, Vector3(pad["x"], float(pad["y"]) + 0.28, pad["z"]))
		pad["marker"] = mmi
		pad["marker_yaw"] = py_rot


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


func _keep_world(kp: Vector2, ky: float, yaw: float, lx: float, ly: float, lz: float) -> Vector3:
	return Vector3(kp.x + lx * cos(yaw) + lz * sin(yaw), ky + ly, kp.y - lx * sin(yaw) + lz * cos(yaw))


func _build_keep_and_cave() -> void:
	# A1: Full 5-tier Ruined Keep & 7.3m Independent Beacon Tower (32-props.js:237-295)
	var kp: Vector2 = layout["keep"]
	var ky := height_at(kp.x, kp.y)
	var road: Array[Vector2] = layout["road"]
	var rd := (road[maxi(0, road.size() - 2)] - kp).normalized()
	var yaw := atan2(rd.x, rd.y)
	var st: Color = pal["stone"]
	var sdk: Color = pal["stoneD"]
	var sl: Color = pal["stoneL"]
	var iron: Color = pal["iron"]
	var wd: Color = pal["woodD"]
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
	keep_soup.add_box(Vector3(0.9, 1.55, 0.05), Vector3(2.3, 2.45, 0.85), pal["clothR"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 0.5)

	# 2 Gatehouse Wall Lanterns (also registered as env_lights + keep_fires)
	for sg: float in [-1.0, 1.0]:
		keep_soup.add_seg(Vector3(sg * 1.32, 1.9, 0.52), Vector3(sg * 1.32, 2.1, 0.92), 0.035, 0.03, iron, 4, CWGfx.L_METAL, 0.5)
		keep_soup.add_cyl(0.09, 0.14, 0.16, Vector3(sg * 1.32, 2.14, 0.94), Color(1.0, 0.56, 0.18), 6, CWGfx.L_PLAIN, 0.35, Vector3.ZERO, 0.0, 1.6)
		var lpos := _keep_world(kp, ky, yaw, sg * 1.32, 2.3, 0.94)
		keep_fires.append(lpos)
		if env_lights.size() < 2:
			env_lights.append({"pos": lpos, "col": Color(1.0, 0.55, 0.20), "energy": 1.7, "range": 9.0, "flick": true})

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
		btop_soup.add_seg(Vector3(bx + cos(a) * 0.65, bh_t + 1.28, bz + sin(a) * 0.65), Vector3(bx - cos(a) * 0.2, bh_t + 1.48, bz - sin(a) * 0.2), 0.1, 0.09, pal["bark"], 5, CWGfx.L_BARK, 0.92)
	btop_soup.add_cyl(0.9, 0.85, 0.12, Vector3(bx, bh_t + 1.24, bz), Color(1.0, 0.48, 0.12), 10, CWGfx.L_PLAIN, 0.35, Vector3.ZERO, 0.0, 0.42)
	btop_soup.add_box(Vector3(0.9, 2.2, 0.05), Vector3(bx, 4.1, bz + 1.52), pal["clothR"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 0.55)

	var keep_mi := MeshInstance3D.new()
	keep_mi.mesh = keep_soup.build()
	keep_mi.material_override = gfx.mat_world
	keep_mi.rotation.y = yaw
	keep_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach_to_chunk(keep_mi, Vector3(kp.x, ky, kp.y))

	var btop_mi := MeshInstance3D.new()
	btop_mi.mesh = btop_soup.build()
	btop_mi.material_override = gfx.mat_world
	btop_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	btop_mi.rotation.y = yaw
	_attach_to_chunk(btop_mi, Vector3(kp.x, ky, kp.y))
	beacon_pos = _keep_world(kp, ky, yaw, bx, bh_t + 1.45, bz)

	# Add 3rd env light at waterfall/bridge for atmospheric mist glow
	if has_waterfall and env_lights.size() < 3:
		env_lights.append({"pos": waterfall_pos + Vector3(0, 3.8, 0), "col": Color(0.55, 0.78, 1.0) if String(bio.get("key", "")) != "ember" else Color(1.0, 0.38, 0.12), "energy": 1.4, "range": 9.0, "flick": String(bio.get("key", "")) == "ember"})

	# Monster Cave arch at road start
	var cv: Vector2 = layout["cave"]
	var cy := height_at(cv.x, cv.y)
	# Exact 32-props.js:301-318 monumental 21-boulder mountain cave + hanging stalactites & Frostfall icicles
	var cave_soup := CWGfx.Soup.new()
	var crng := CWUtil.Rng.new(seed_val + 613)
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
	if String(bio.get("key", "")) == "frost":
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
	cave_mi.material_override = gfx.mat_world
	_attach_to_chunk(cave_mi, Vector3(cv.x + 2.8, cy, cv.y))



	# Giant ribcage skeleton landmark
	var rx := clampf(kp.x + 1.2, -CWLayout.BH + 3.0, CWLayout.BH - 2.5)
	var rz := clampf(kp.y - 5.2, -CWLayout.BH + 3.0, CWLayout.BH - 3.0)
	var ry := height_at(rx, rz)
	var rib_soup := CWGfx.Soup.new()
	var bone_col: Color = pal["bone"]
	rib_soup.add_seg(Vector3(-1.3, 0.22, 0), Vector3(1.3, 0.16, 0.1), 0.11, 0.08, bone_col, 5, CWGfx.L_PLAIN, 0.85)
	for r_i in range(5):
		var xo := -0.95 + float(r_i) * 0.45
		var rad := 0.72 - absf(float(r_i - 2)) * 0.12
		for sg: float in [-1.0, 1.0]:
			rib_soup.add_seg(Vector3(xo, 0.2, 0), Vector3(xo - 0.1, 0.75 * rad, sg * 0.55 * rad), 0.06, 0.04, bone_col, 4, CWGfx.L_PLAIN, 0.85)
			rib_soup.add_seg(Vector3(xo - 0.1, 0.75 * rad, sg * 0.55 * rad), Vector3(xo - 0.15, 0.18, sg * 0.78 * rad), 0.04, 0.025, bone_col, 4, CWGfx.L_PLAIN, 0.85)
	var rib_mi := MeshInstance3D.new()
	rib_mi.mesh = rib_soup.build()
	rib_mi.material_override = gfx.mat_world
	rib_mi.rotation.y = 0.55
	_attach_to_chunk(rib_mi, Vector3(rx, ry, rz))


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


func _scatter_landmarks_and_biome_props(rng: CWUtil.Rng) -> void:
	var placed: Array[Vector3] = []
	var bh := CWLayout.BH - 1.8
	var cave: Vector2 = layout["cave"]
	var keep: Vector2 = layout["keep"]
	var total_len: float = float(layout["total_len"])
	var bkey: String = String(bio.get("key", "ashen"))

	var is_free := func(wx: float, wz: float, rad: float, road_min: float = 2.0, water_min: float = 1.6, allow_steep: bool = false) -> bool:
		var lim := (CWLayout.BH - 0.7 - rad * 0.4) if allow_steep else bh
		if absf(wx) > lim or absf(wz) > lim:
			return false
		if not allow_steep:
			if height_at(wx, wz) > 1.05:
				return false
			var sr := minf(rad * 0.65, 1.4)
			if sr > 0.35:
				if height_at(wx + sr, wz) > 1.20 or height_at(wx - sr, wz) > 1.20 or height_at(wx, wz + sr) > 1.20 or height_at(wx, wz - sr) > 1.20:
					return false
		if _sample_grid(_grid_dr, wx, wz) < road_min + rad * 0.45:
			return false
		if _sample_grid(_grid_ds, wx, wz) < water_min + rad * 0.45:
			return false
		var p2 := Vector2(wx, wz)
		if p2.distance_to(cave) < 3.6 + rad or p2.distance_to(keep) < 5.6 + rad:
			return false
		if has_bridge and p2.distance_to(bridge_pos) < 3.0 + rad:
			return false
		for pad in layout["pads"]:
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
		if idx < chunks.size():
			var home: Vector3 = chunks[idx]["home"]
			var lp := Vector3(wx - home.x, height_at(wx, wz) - home.y, wz - home.z)
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
			var smp := CWLayout.sample_path(layout, s_pos)
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
	drop.call(func(s, p, y): Props.add_tower_ruin(s, p, y, pal, rng), 2.7, 2.8, 1.8)
	drop.call(func(s, p, y): Props.add_ribcage(s, p, y, pal, rng), 2.3, 2.4, 1.6)
	drop.call(func(s, p, y): Props.add_graveyard(s, p, y, pal, rng), 3.0, 2.6, 1.8)
	drop.call(func(s, p, y): Props.add_well(s, p, y, pal, rng), 1.3, 1.9, 1.5)
	drop.call(func(s, p, y): Props.add_statue(s, p, y, pal, rng), 1.2, 2.0, 1.5)
	for _w in range(3):
		var wlen := rng.rr(3.8, 6.4)
		var wh := rng.rr(1.8, 3.0)
		drop.call(func(s, p, y): Props.add_wall_run(s, p, y, wlen, wh, pal, rng), wlen * 0.48, 2.0, 1.5)
	for _c in range(3):
		drop.call(func(s, p, _y): Props.add_cairn(s, p, pal, rng), 0.55, 1.8, 1.3)

	# 2. Road-Aligned Narrative Dressing (32-props.js:366-378)
	for k in range(2):
		var br: Dictionary = beside_road.call(8.0, total_len - 7.0, 0.9, 1.05)
		if not br.is_empty():
			var is_brk := (k == 1)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + rng.rr(-0.25, 0.25), func(s, p, y): Props.add_cart(s, p, y, is_brk, pal, rng))
	for _k in range(4):
		var br: Dictionary = beside_road.call(6.0, total_len - 6.0, 0.45, 0.95)
		if not br.is_empty():
			var plen := rng.rr(2.6, 4.1)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5, func(s, p, y): Props.add_palisade(s, p, y, plen, pal, rng))
	for _k in range(4):
		var br: Dictionary = beside_road.call(6.0, total_len - 6.0, 0.65, 1.05)
		if not br.is_empty():
			var flen := rng.rr(2.5, 4.3)
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5 + rng.rr(-0.12, 0.12), func(s, p, y): Props.add_fence(s, p, y, flen, pal, rng))
	for k in range(4):
		var br: Dictionary = beside_road.call(7.0, total_len - 5.0, 0.55, 0.35)
		if not br.is_empty():
			var bcol: Color = pal["clothR"] if (k & 1) == 0 else pal["clothB"]
			place_at.call(float(br["x"]), float(br["z"]), float(br["yaw"]) + PI * 0.5 * float(br["side"]), func(s, p, y): Props.add_banner(s, p, y, bcol, pal))
	var br_sign: Dictionary = beside_road.call(total_len * 0.28, total_len * 0.72, 0.55, 0.4)
	if not br_sign.is_empty():
		place_at.call(float(br_sign["x"]), float(br_sign["z"]), float(br_sign["yaw"]), func(s, p, y): Props.add_signpost(s, p, y, pal, rng))
	var br_gib: Dictionary = beside_road.call(10.0, total_len * 0.62, 1.0, 0.65)
	if not br_gib.is_empty():
		place_at.call(float(br_gib["x"]), float(br_gib["z"]), float(br_gib["yaw"]) + PI * 0.5, func(s, p, y): Props.add_gibbet(s, p, y, pal, rng))
	for _k in range(5):
		var br: Dictionary = beside_road.call(6.0, total_len - 5.0, 0.75, 0.7)
		if not br.is_empty():
			place_at.call(float(br["x"]), float(br["z"]), rng.rr(0.0, TAU), func(s, p, y): Props.add_supply_cluster(s, p, y, pal, rng))

	# 3. Cave Skull Stakes & Bone Piles (32-props.js:310-311, 379-380)
	for sg: float in [-1.0, 1.0]:
		var sx := cave.x + 1.85
		var sz := cave.y + sg * 2.35
		place_at.call(sx, sz, 0.0, func(s, p, _y): Props.add_skull_stake(s, p, pal, rng))
	for _k in range(6):
		var bx := cave.x + rng.rr(1.8, 6.8)
		var bz := cave.y + (-1.0 if rng.next_f() < 0.5 else 1.0) * rng.rr(1.8, 4.8)
		if absf(bx) < bh and absf(bz) < bh and height_at(bx, bz) < 1.35:
			place_at.call(bx, bz, 0.0, func(s, p, _y): Props.add_bone_pile(s, p, pal, rng, rng.ri(4, 7)))
	for _k in range(5):
		drop.call(func(s, p, _y): Props.add_bone_pile(s, p, pal, rng, rng.ri(3, 5)), 0.45, 1.6, 1.3)

	# 4. Road Puddles & Biome Ponds (exact counts & wet mud halos from 29-biome.js & 31-terrain.js:244-270)
	var puddle_soup := CWGfx.Soup.new()
	var mud_soup := CWGfx.Soup.new()
	var n_puddles := 11 if bkey == "ashen" else (8 if bkey == "frost" else (15 if bkey == "fen" else 0))
	var mud_col: Color = pal["mud"] * 0.55
	mud_col.a = 1.0
	for _q in range(n_puddles):
		var s_p := rng.rr(4.5, maxf(5.5, total_len - 5.0))
		var smp := CWLayout.sample_path(layout, s_p)
		var rp: Vector2 = smp["pos"] + Vector2(rng.rr(-0.82, 0.82), rng.rr(-0.82, 0.82))
		if has_bridge and rp.distance_to(bridge_pos) < 3.6:
			continue
		var py := height_at(rp.x, rp.y) + 0.048
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
		mmi.material_override = gfx.mat_world
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		extra_meshes.append(mmi)

	pond_centers.clear()
	var want_ponds := 4 if bkey == "fen" else (1 if bkey == "ashen" else 2)
	for _pq in range(want_ponds):
		for _t in range(60):
			var wx := rng.rr(-bh + 2.4, bh - 2.4)
			var wz := rng.rr(-bh + 2.4, bh - 2.4)
			var pr := rng.rr(1.5, 2.3)
			if is_free.call(wx, wz, pr + 0.6, 2.4, 2.2):
				placed.append(Vector3(wx, wz, pr + 0.6))
				var py := height_at(wx, wz) + 0.05
				pond_centers.append(Vector3(wx, py, wz))
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
					rim_sp.add_rock(rng.rr(0.22, 0.42), Vector3(cos(ra) * rr_p, 0.08, sin(ra) * rr_p), pal["stoneD"], rng.ri(1, 9999), CWGfx.L_ROCK, 0.92, Vector3(1.1, 0.65, 1.0))
					if bkey == "fen" or bkey == "dunes":
						Props.add_reeds(rim_sp, Vector3(cos(ra + 0.2) * (pr * 0.98), 0.0, sin(ra + 0.2) * (pr * 0.98)), pal, rng)
					elif bkey == "frost" and rk < 3:
						Props.add_crystal(rim_sp, Vector3(cos(ra) * (pr + 0.35), 0.0, sin(ra) * (pr + 0.35)), Color(0.52, 0.84, 1.0), rng)
				if bkey == "fen":
					for _lk in range(4):
						var la := rng.rr(0.0, TAU)
						var ld := pr * rng.rr(0.08, 0.55)
						Props.add_lily(rim_sp, Vector3(cos(la) * ld, 0.05, sin(la) * ld), pal, rng)
				var rim_mi := MeshInstance3D.new()
				rim_mi.mesh = rim_sp.build()
				rim_mi.material_override = gfx.mat_world
				_attach_to_chunk(rim_mi, Vector3(wx, py - 0.04, wz))
				if env_lights.size() < 3 and (bkey == "ember" or bkey == "frost"):
					env_lights.append({
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
		pmi.material_override = gfx.mat_water
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if water_mesh != null:
			water_mesh.add_child(pmi)
		else:
			add_child(pmi)

	# 5. Biome-Specific Flora & Landforms (33-flora.js:129-170)
	for _s in range(7):
		drop.call(func(s, p, _y): Props.add_stump(s, p, pal, rng), 0.45, 1.8, 1.3)

	# Subtle cobblestone road cracks (31-terrain.js:238-248)
	var cr_soup := CWGfx.Soup.new()
	for _q in range(14):
		var s_c := rng.rr(4.5, maxf(5.5, total_len - 5.0))
		var smp := CWLayout.sample_path(layout, s_c)
		var cp: Vector2 = smp["pos"]
		if has_bridge and cp.distance_to(bridge_pos) < 3.5:
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
			var cy1 := height_at(cx, cz) + 0.065
			var cy2 := height_at(x2, z2) + 0.065
			cr_soup.add_quad(Vector3(cx - wx_c, cy1, cz - wz_c), Vector3(cx + wx_c, cy1, cz + wz_c), Vector3(x2 + wx_c, cy2, z2 + wz_c), Vector3(x2 - wx_c, cy2, z2 - wz_c), Color(0.09, 0.08, 0.09), CWGfx.L_PLAIN, 0.98)
			cx = x2; cz = z2
	if cr_soup.vert_count > 0:
		var crmi := MeshInstance3D.new()
		crmi.mesh = cr_soup.build()
		crmi.material_override = gfx.mat_world
		crmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crmi)
		extra_meshes.append(crmi)

	match bkey:
		"ashen":
			for _k in range(4):
				drop.call(func(s, p, y): Props.add_log(s, p, y, pal, rng), 1.0, 1.9, 1.4)
		"frost":
			for _k in range(6):
				drop.call(func(s, p, _y): Props.add_crystal(s, p, Color(0.54, 0.86, 1.0), rng), 0.55, 1.8, 1.2)
			for _k in range(32):
				var dr_r := rng.rr(0.50, 1.25)
				drop.call(func(s, p, _y): Props.add_drift(s, p, dr_r, Color(0.76, 0.83, 0.92), rng), dr_r * 0.38, 1.2, 1.0, 55, true)
			for _k in range(2):
				drop.call(func(s, p, y): Props.add_log(s, p, y, pal, rng), 1.0, 1.9, 1.4)
		"fen":
			for _k in range(16):
				drop.call(func(s, p, _y): Props.add_shroom_cluster(s, p, rng), 0.40, 1.6, 1.1)
			for _k in range(5):
				drop.call(func(s, p, y): Props.add_log(s, p, y, pal, rng), 1.0, 1.9, 1.4)
			if env_lights.size() < 3 and not pond_centers.is_empty():
				var pc0 := pond_centers[0]
				env_lights.append({"pos": pc0 + Vector3(0, 0.8, 0), "col": Color(0.27, 0.88, 0.72), "energy": 1.1, "range": 7.5, "flick": false})
			# 52 stream-bank reeds (33-flora.js:124-127)
			var st_pts: Array[Vector2] = layout["stream"]
			if st_pts.size() > 4:
				for _rk in range(52):
					var su := rng.ri(1, st_pts.size() - 2)
					var sdir := (st_pts[su + 1] - st_pts[su - 1]).normalized()
					var sside := -1.0 if rng.next_f() < 0.5 else 1.0
					var soff := rng.rr(1.05, 1.95)
					var rx := st_pts[su].x - sdir.y * sside * soff
					var rz := st_pts[su].y + sdir.x * sside * soff
					if absf(rx) < bh - 0.8 and absf(rz) < bh - 0.8 and _sample_grid(_grid_dr, rx, rz) > CWLayout.ROAD_HALF + 0.9:
						place_at.call(rx, rz, rng.rr(0.0, TAU), func(s, p, _y): Props.add_reeds(s, p, pal, rng))
		"ember":
			for _k in range(9):
				drop.call(func(s, p, _y): Props.add_basalt(s, p, pal, rng), 1.0, 1.9, 1.4)
			for _k in range(6):
				var sh := rng.rr(2.0, 4.0)
				drop.call(func(s, p, _y): Props.add_spire(s, p, sh, pal, rng), sh * 0.28, 2.0, 1.4, 50, true)
			for _k in range(4):
				var vp: Vector2 = drop.call(func(s, p, _y): Props.add_vent(s, p, pal, rng), 0.85, 2.1, 1.5)
				if vp.x < 500.0:
					keep_fires.append(Vector3(vp.x, height_at(vp.x, vp.y) + 0.18, vp.y))
			# Glowing volcanic ground lava cracks (31-terrain.js:271-284)
			var lv_soup := CWGfx.Soup.new()
			for _q in range(36):
				var lx := rng.rr(-bh + 1.8, bh - 1.8)
				var lz := rng.rr(-bh + 1.8, bh - 1.8)
				if _sample_grid(_grid_dr, lx, lz) < CWLayout.ROAD_HALF + 0.8 or _sample_grid(_grid_ds, lx, lz) < 1.5 or _sample_grid(_grid_ds, lx, lz) > 9.0:
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
					var y1 := height_at(lx, lz) + 0.04
					var y2 := height_at(x2, z2) + 0.04
					lv_soup.add_quad(Vector3(lx - wx_l, y1, lz - wz_l), Vector3(lx + wx_l, y1, lz + wz_l), Vector3(x2 + wx_l, y2, z2 + wz_l), Vector3(x2 - wx_l, y2, z2 - wz_l), Color(0.95, 0.32, 0.05), CWGfx.L_PLAIN, 0.9, 0.0, em)
					lx = x2; lz = z2
			if lv_soup.vert_count > 0:
				var lvmi := MeshInstance3D.new()
				lvmi.mesh = lv_soup.build()
				lvmi.material_override = gfx.mat_world
				lvmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(lvmi)
				extra_meshes.append(lvmi)
			if has_bridge and env_lights.size() < 3:
				env_lights.append({"pos": Vector3(bridge_pos.x, height_at(bridge_pos.x, bridge_pos.y) + 0.5, bridge_pos.y), "col": Color(1.0, 0.35, 0.12), "energy": 2.2, "range": 9.5, "flick": true})
		"dunes":
			for _k in range(11):
				drop.call(func(s, p, _y): Props.add_cactus(s, p, rng), 0.45, 1.7, 1.3)
			for _k in range(6):
				var sh := rng.rr(2.2, 4.4)
				drop.call(func(s, p, _y): Props.add_spire(s, p, sh, pal, rng), sh * 0.28, 2.0, 1.4, 50, true)
			# Terracotta amphora jar clusters beside Duskmesa pads (33-flora.js:171-176)
			var d_pads: Array = layout["pads"]
			for pd in d_pads:
				if rng.next_f() < 0.5:
					continue
				var ja := rng.rr(0.0, TAU)
				var jx := float(pd["x"]) + cos(ja) * 2.25
				var jz := float(pd["z"]) + sin(ja) * 2.25
				if absf(jx) < bh - 1.0 and absf(jz) < bh - 1.0 and _sample_grid(_grid_dr, jx, jz) > CWLayout.ROAD_HALF + 0.5:
					place_at.call(jx, jz, 0.0, func(s, p, _y): Props.add_jar_cluster(s, p, rng))

	# Duskmesa oasis palms ringing each desert pond (33-flora.js:146-149)
	if bkey == "dunes":
		for pc in pond_centers:
			for _pk in range(4):
				var pa := rng.rr(0.0, TAU)
				var pd := rng.rr(2.4, 3.3)
				var px_p := pc.x + cos(pa) * pd
				var pz_p := pc.z + sin(pa) * pd
				if absf(px_p) < bh - 1.2 and absf(pz_p) < bh - 1.2 and _sample_grid(_grid_dr, px_p, pz_p) > CWLayout.ROAD_HALF + 1.0:
					place_at.call(px_p, pz_p, rng.rr(0.0, TAU), func(s, p, _y): Props.add_palm(s, p, rng.rr(3.0, 4.4), pal, rng))

	# Full biome forest density & secondary bare gnarled trees (exact 29-biome.js bio.trees)
	match bkey:
		"frost":
			for _tk in range(11):
				drop.call(func(s, p, _y): _build_tree(s, p, "pine", rng), 0.78, 1.4, 1.5, 45, false)
			for _tk in range(4):
				drop.call(func(s, p, _y): Props.add_gnarled_tree(s, p, rng.rr(2.6, 4.2), pal, rng, false), 0.58, 1.4, 1.5, 45, false)
		"fen":
			for _tk in range(5):
				drop.call(func(s, p, _y): _build_tree(s, p, "willow", rng), 0.80, 1.4, 1.5, 45, false)
			for _tk in range(5):
				drop.call(func(s, p, _y): Props.add_gnarled_tree(s, p, rng.rr(2.6, 4.4), pal, rng, false), 0.58, 1.4, 1.5, 45, false)
		"dunes":
			for _tk in range(4):
				drop.call(func(s, p, _y): _build_tree(s, p, "palm", rng), 0.72, 1.4, 1.5, 45, false)
			for _tk in range(2):
				drop.call(func(s, p, _y): Props.add_gnarled_tree(s, p, rng.rr(2.4, 3.4), pal, rng, false), 0.55, 1.4, 1.5, 45, false)
		"ashen":
			for _tk in range(7):
				drop.call(func(s, p, _y): Props.add_gnarled_tree(s, p, rng.rr(2.6, 4.6), pal, rng, false), 0.58, 1.4, 1.5, 45, false)
		"ember":
			for _tk in range(6):
				drop.call(func(s, p, _y): Props.add_gnarled_tree(s, p, rng.rr(2.6, 4.4), pal, rng, true), 0.58, 1.4, 1.5, 45, false)

	# Cliff-perched & hillside boulders across ALL biomes (32-props.js:394: steep=true, 20% large 0.6-1.25m + 80% 0.16-0.5m)
	var rock_cnt := int(bio.get("rock_count", 52))
	for _bk in range(rock_cnt):
		var br := rng.rr(0.58, 1.22) if rng.next_f() < 0.22 else rng.rr(0.18, 0.48)
		var bcol: Color = pal["stoneD"].lerp(pal["stone"], rng.next_f())
		drop.call(func(s, p, _y): s.add_rock(br, p + Vector3(0.0, br * 0.24, 0.0), bcol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.12, 0.78, 1.04)), br * 0.72, 1.15, 1.55, 45, true)

	# 60 small roadside cobble pebbles lining road shoulders (32-props.js:401-405)
	var peb_soup := CWGfx.Soup.new()
	for _pk2 in range(60):
		var sp_p := rng.rr(3.5, maxf(4.5, total_len - 3.5))
		var smp_p := CWLayout.sample_path(layout, sp_p)
		var pp: Vector2 = smp_p["pos"]
		var pd_v: Vector2 = smp_p["dir"]
		var pside := -1.0 if rng.next_f() < 0.5 else 1.0
		var poff := CWLayout.ROAD_HALF + rng.rr(0.10, 0.48)
		var px2 := pp.x - pd_v.y * pside * poff
		var pz2 := pp.y + pd_v.x * pside * poff
		if absf(px2) > bh - 0.6 or absf(pz2) > bh - 0.6 or _sample_grid(_grid_ds, px2, pz2) < 2.2:
			continue
		var pr2 := rng.rr(0.08, 0.17)
		var pcol: Color = pal["roadD"].lerp(pal["stone"], rng.next_f())
		peb_soup.add_rock(pr2, Vector3(px2, height_at(px2, pz2) + pr2 * 0.25, pz2), pcol, rng.ri(1, 9999), CWGfx.L_ROCK, 0.92)
	if peb_soup.vert_count > 0:
		var pebmi := MeshInstance3D.new()
		pebmi.mesh = peb_soup.build()
		pebmi.material_override = gfx.mat_world
		pebmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pebmi)
		extra_meshes.append(pebmi)

	# Flush batched per-chunk prop meshes (36 combined meshes instead of 160+ individual MeshInstance3Ds)
	for ci in range(mini(prop_soups.size(), chunks.size())):
		if prop_soups[ci].vert_count > 0:
			var p_mi := MeshInstance3D.new()
			p_mi.mesh = prop_soups[ci].build()
			p_mi.material_override = gfx.mat_world
			(chunks[ci]["node"] as Node3D).add_child(p_mi)


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
	if stream_path != null and is_instance_valid(stream_path):
		stream_path.queue_free()
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

	stream_path = Path3D.new()
	stream_path.name = "StreamPath"
	var s_curve := Curve3D.new()
	var s_pts: Array = layout.get("stream", [])
	for pt_v in s_pts:
		var pt: Vector2 = pt_v
		var sx: float = pt.y if mirrored else pt.x
		var sz: float = pt.x if mirrored else pt.y
		s_curve.add_point(Vector3(sx, height_at(sx, sz), sz))
	stream_path.curve = s_curve
	add_child(stream_path)
