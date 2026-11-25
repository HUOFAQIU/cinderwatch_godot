class_name CWTerrain
extends Node3D

# WYSIWYG Scene-Driven Level Map Loader (scenes/maps/<biome>.tscn)
# Reads editable RoadPath (Path3D), Pads/, Chunks/, and metadata directly from the .tscn scene,
# bakes O(1) 0.2m road_lut for high-crowd performance, and supports crumble/rise transitions.

const BH := 18.0
const CHUNK := 6.0
const NCH := 6
const GRID_N := 49

var gfx: CWGfx
var layout: Dictionary = {}
var bio: Dictionary = {}
var pal: Dictionary = {}
var seed_val: int = 1
var map_root: Node3D = null
var chunks: Array[Dictionary] = []
var extra_meshes: Array[Node3D] = []
var road_smooth: Array[Vector2] = []
var beacon_pos: Vector3 = Vector3.ZERO
var waterfall_pos: Vector3 = Vector3.ZERO
var has_waterfall: bool = false
var bridge_pos: Vector2 = Vector2.ZERO
var has_bridge: bool = false
var env_lights: Array[Dictionary] = []
var keep_fires: Array[Vector3] = []
var pond_centers: Array[Vector3] = []
var road_path: Path3D = null
var road_lut: Dictionary = {}

var _grid_h: PackedFloat32Array = PackedFloat32Array()


func build_board(p_gfx: CWGfx, p_seed: int, biome_idx: int, biome_start: int = 0) -> Dictionary:
	gfx = p_gfx
	seed_val = p_seed
	clear_board()

	bio = CWBiome.get_biome(biome_idx, biome_start)
	pal = CWBiome.build_palette(bio)
	gfx.apply_biome_uniforms(bio)

	var bkey: String = String(bio.get("key", "ashen"))
	var map_path := "res://scenes/maps/%s.tscn" % bkey
	var ps := load(map_path) as PackedScene
	if ps == null:
		push_error("Missing level map scene: " + map_path)
		return {}

	map_root = ps.instantiate() as Node3D
	add_child(map_root)
	_apply_materials_rec(map_root)

	# 1. Read baked map metadata
	_grid_h = map_root.get_meta("height_grid", PackedFloat32Array())
	beacon_pos = map_root.get_meta("beacon_pos", Vector3.ZERO)
	has_waterfall = bool(map_root.get_meta("has_waterfall", false))
	waterfall_pos = map_root.get_meta("waterfall_pos", Vector3.ZERO)
	has_bridge = bool(map_root.get_meta("has_bridge", false))
	bridge_pos = map_root.get_meta("bridge_pos", Vector2.ZERO)

	env_lights.clear()
	for el_v in map_root.get_meta("env_lights", []):
		env_lights.append((el_v as Dictionary).duplicate())
	keep_fires.clear()
	for kf_v in map_root.get_meta("keep_fires", []):
		keep_fires.append(kf_v as Vector3)
	pond_centers.clear()
	for pc_v in map_root.get_meta("pond_centers", []):
		pond_centers.append(pc_v as Vector3)

	# 2. Collect Chunks (for crumble/rise transition animations)
	var rng := CWUtil.Rng.new(p_seed)
	var chunks_node := map_root.get_node_or_null("Chunks")
	if chunks_node != null:
		for ch_n in chunks_node.get_children():
			if ch_n is Node3D:
				var cn := ch_n as Node3D
				var center := cn.position
				var dist_c := Vector2(center.x, center.z).length()
				chunks.append({
					"node": cn,
					"home": center,
					"cx": int(cn.get_meta("cx", 0)),
					"cz": int(cn.get_meta("cz", 0)),
					"delay": dist_c * 0.032 + rng.rr(0.0, 0.18),
					"vel": Vector3(rng.rr(-1.2, 1.2), rng.rr(-2.0, -0.4), rng.rr(-1.2, 1.2)),
					"spin": Vector3(rng.rr(-0.7, 0.7), rng.rr(-0.4, 0.4), rng.rr(-0.7, 0.7)),
				})

	var extras_node := map_root.get_node_or_null("Extras")
	if extras_node != null:
		for ex_n in extras_node.get_children():
			if ex_n is Node3D:
				extra_meshes.append(ex_n as Node3D)

	# 3. Read editable RoadPath (Path3D) -> road polyline, path_s, road_smooth
	road_path = map_root.get_node_or_null("RoadPath") as Path3D
	var road: Array[Vector2] = []
	var path_s: Array[float] = [0.0]
	var total_len := 0.0
	if road_path != null and road_path.curve != null:
		var baked := road_path.curve.get_baked_points()
		for pt in baked:
			var v2 := Vector2(pt.x, pt.z)
			if not road.is_empty():
				total_len += road[road.size() - 1].distance_to(v2)
				path_s.append(total_len)
			road.append(v2)
	if road.size() < 2:
		road = [Vector2(-16.0, 0.0), Vector2(8.0, -10.0)]
		path_s = [0.0, road[0].distance_to(road[1])]
		total_len = path_s[1]

	# 4. Read editable Pads/ nodes
	var pads: Array[Dictionary] = []
	var pads_node := map_root.get_node_or_null("Pads")
	if pads_node != null:
		for pn_v in pads_node.get_children():
			if pn_v is Node3D:
				var pn := pn_v as Node3D
				var ppos := pn.position
				var pad_dict := {
					"idx": pads.size(),
					"x": ppos.x,
					"y": ppos.y,
					"z": ppos.z,
					"rot": pn.rotation.y,
					"tower": null,
					"node": pn,
					"marker": pn.get_node_or_null("Marker"),
					"marker_yaw": float(pn.get_meta("marker_yaw", pn.rotation.y)),
				}
				var pmesh := pn.get_node_or_null("PadMesh")
				if pmesh != null:
					var pb := pmesh.get_node_or_null("PadPickBody")
					if pb != null:
						pb.set_meta("pad", pad_dict)
				pads.append(pad_dict)

	layout = {
		"seed": p_seed,
		"road": road,
		"path_s": path_s,
		"total_len": total_len,
		"pads": pads,
		"cave": road[0],
		"keep": road[road.size() - 1],
	}

	_build_road_smooth()
	_build_road_lut()

	return {
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


func _apply_materials_rec(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var tag := String(mi.get_meta("mat_tag", "world"))
		if tag == "water":
			mi.material_override = gfx.mat_water
		elif tag == "fall":
			mi.material_override = gfx.mat_fall
		else:
			mi.material_override = gfx.mat_world
	for c in n.get_children():
		_apply_materials_rec(c)


func _build_road_smooth() -> void:
	var road: Array[Vector2] = layout["road"]
	road_smooth.clear()
	var rn := road.size()
	for ri in range(rn):
		var w := mini(5, mini(ri, rn - 1 - ri))
		var acc := Vector2.ZERO
		for dk in range(-w, w + 1):
			acc += road[ri + dk]
		road_smooth.append(acc / float(2 * w + 1))


func sample_path(s_pos: float) -> Dictionary:
	var road: Array[Vector2] = layout["road"]
	var s_arr: Array[float] = layout["path_s"]
	var total: float = layout["total_len"]
	var cs := clampf(s_pos, 0.0, total)
	var lo := 0
	var hi := s_arr.size() - 1
	while lo + 1 < hi:
		var mid := (lo + hi) >> 1
		if s_arr[mid] <= cs:
			lo = mid
		else:
			hi = mid
	var seg := maxf(s_arr[hi] - s_arr[lo], 1e-5)
	var t := clampf((cs - s_arr[lo]) / seg, 0.0, 1.0)
	var p: Vector2 = road[lo].lerp(road[hi], t)
	var dir: Vector2 = (road[hi] - road[lo]).normalized()
	return {"pos": p, "dir": dir, "prog": cs / maxf(total, 1.0)}


func sample_smooth_road(s_pos: float) -> Dictionary:
	if road_smooth.size() < 2:
		return sample_path(s_pos)
	var s_arr: Array[float] = layout["path_s"]
	var total: float = layout["total_len"]
	var cs := clampf(s_pos, 0.0, total)
	var lo := 0
	var hi := s_arr.size() - 1
	while lo + 1 < hi:
		var mid := (lo + hi) >> 1
		if s_arr[mid] <= cs:
			lo = mid
		else:
			hi = mid
	var seg := maxf(s_arr[hi] - s_arr[lo], 1e-5)
	var t := clampf((cs - s_arr[lo]) / seg, 0.0, 1.0)
	var p: Vector2 = road_smooth[lo].lerp(road_smooth[hi], t)
	var dir: Vector2 = (road_smooth[hi] - road_smooth[lo]).normalized()
	return {"pos": p, "dir": dir, "prog": cs / maxf(total, 1.0)}


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
		var smp := sample_path(s_val)
		var p: Vector2 = smp["pos"]
		var d: Vector2 = smp["dir"]
		var yw := atan2(d.x, d.y)
		rx[k] = p.x
		ry[k] = height_at(p.x, p.y)
		rz[k] = p.y
		px[k] = -d.y
		pz[k] = d.x
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


func get_chunk_node(wx: float, wz: float) -> Node3D:
	var cx := clampi(int(floorf((wx + BH) / CHUNK)), 0, NCH - 1)
	var cz := clampi(int(floorf((wz + BH) / CHUNK)), 0, NCH - 1)
	for ch in chunks:
		if int(ch["cx"]) == cx and int(ch["cz"]) == cz:
			return ch["node"] as Node3D
	return chunks[0]["node"] as Node3D if not chunks.is_empty() else self


func height_at(wx: float, wz: float) -> float:
	if _grid_h.is_empty():
		return 0.0
	var u := clampf((wx + BH) / (BH * 2.0) * float(GRID_N - 1), 0.0, float(GRID_N - 1) - 0.001)
	var v := clampf((wz + BH) / (BH * 2.0) * float(GRID_N - 1), 0.0, float(GRID_N - 1) - 0.001)
	var ix := int(floorf(u))
	var iz := int(floorf(v))
	var fx := u - float(ix)
	var fz := v - float(iz)
	var i00 := iz * GRID_N + ix
	var h0 := lerpf(_grid_h[i00], _grid_h[i00 + 1], fx)
	var h1 := lerpf(_grid_h[i00 + GRID_N], _grid_h[i00 + GRID_N + 1], fx)
	var h := lerpf(h0, h1, fz)
	if has_bridge:
		var db := Vector2(wx, wz).distance_to(bridge_pos)
		if db < 2.25:
			var w := smoothstep(2.25, 1.35, db)
			h = maxf(h, lerpf(h, 0.56, w))
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
		node.position = home + vel * t + Vector3(0.0, -0.5 * 19.0 * t * t, 0.0)
		node.rotation = spin * t
		if node.position.y > -32.0:
			all_done = false
	return all_done


func update_rise(phase_t: float, dur: float = 1.15) -> bool:
	var all_done := true
	for ch in chunks:
		var u := clampf((phase_t - float(ch["delay"]) * 0.45) / dur, 0.0, 1.0)
		if u < 1.0:
			all_done = false
		var ease_out := 1.0 - pow(1.0 - u, 3.0)
		var node: Node3D = ch["node"]
		var home: Vector3 = ch["home"]
		node.position = home + Vector3(0.0, lerpf(-22.0, 0.0, ease_out), 0.0)
		node.rotation = Vector3.ZERO
	return all_done


func hide_crumble_extras() -> void:
	for m in extra_meshes:
		if is_instance_valid(m):
			m.visible = false
	if map_root != null and is_instance_valid(map_root):
		var pn := map_root.get_node_or_null("Pads")
		if pn != null:
			(pn as Node3D).visible = false


func clear_board() -> void:
	if map_root != null and is_instance_valid(map_root):
		map_root.queue_free()
	map_root = null
	chunks.clear()
	extra_meshes.clear()
	env_lights.clear()
	keep_fires.clear()
	pond_centers.clear()
	road_smooth.clear()
	road_path = null
	has_waterfall = false
	has_bridge = false
