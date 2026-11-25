class_name CWLayout
extends RefCounted

# Faithful port of 30-layout.js:
# Road enters from West cave (-17.6, zc) and winds to NE Ruined Keep (kx, -11.4)
# Stream crosses the road once and pours off the front edge as a waterfall
# Tower pads are scored by road coverage

const BH := 18.0
const CHUNK := 6.0
const NCH := 6
const ROAD_HALF := 1.25
const PATH_STEP := 0.35


static func generate(seed_val: int) -> Dictionary:
	var rng := CWUtil.Rng.new(seed_val)
	var road_data: Dictionary = {}
	var stream_data: Dictionary = {}
	# Match 30-layout.js: retry road+stream together so stream ALWAYS crosses road cleanly once
	for _retry in range(45):
		var rd := _try_road(rng)
		if rd.is_empty():
			continue
		var sd := _try_stream(rng, rd["poly"], float(rd["kx"]), float(rd["total"]))
		if not sd.is_empty():
			road_data = rd
			stream_data = sd
			break
	if road_data.is_empty():
		road_data = _fallback_road()
		stream_data = _try_stream(rng, road_data["poly"], float(road_data["kx"]), float(road_data["total"]))
		if stream_data.is_empty():
			stream_data = _fallback_stream()

	var road: Array[Vector2] = road_data["poly"]

	var pads := _choose_pads(rng, road, stream_data["pts"], float(road_data["kx"]))
	var path_len := _compute_lengths(road)
	return {
		"seed": seed_val,
		"road": road,
		"path_s": path_len["s"],
		"total_len": path_len["total"],
		"stream": stream_data["pts"],
		"stream_front": stream_data["front"],
		"pads": pads,
		"cave": road[0],
		"keep": road[road.size() - 1],
		"kx": road_data["kx"],
		"zc": road_data["zc"],
	}


static func _ang_diff(a: float, b: float) -> float:
	var d := fmod(b - a + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI


static func _seg_inter(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var rx := b.x - a.x
	var rz := b.y - a.y
	var sx := d.x - c.x
	var sz := d.y - c.y
	var den := rx * sz - rz * sx
	if absf(den) < 1e-6:
		return -1.0
	var qpx := c.x - a.x
	var qpz := c.y - a.y
	var t := (qpx * sz - qpz * sx) / den
	var u := (qpx * rz - qpz * rx) / den
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return t
	return -1.0


static func _try_road(rng: CWUtil.Rng) -> Dictionary:
	var zc := rng.rr(-6.5, 9.0)
	var kx := rng.rr(0.5, 10.5)
	var way: Array[Vector2] = [Vector2(-17.6, zc), Vector2(-12.0, zc)]
	var end_a := Vector2(kx, -6.2)
	var end_b := Vector2(kx, -11.4)
	var cur := way[1]
	var dir := 0.0
	var n_mid := rng.ri(4, 6)

	for _k in range(n_mid):
		var ok := false
		for _t in range(32):
			var a := dir + rng.rr(-2.2, 2.2)
			var length := rng.rr(5.5, 11.0)
			var p := Vector2(cur.x + cos(a) * length, cur.y + sin(a) * length)
			if p.x < -10.5 or p.x > 14.2 or p.y < -6.5 or p.y > 14.2:
				continue
			if p.x + p.y > 24.0:
				continue
			if absf(p.x - kx) < 6.5 and p.y < -4.0:
				continue
			var bad := false
			for i in range(way.size() - 2):
				if CWUtil.seg_dist(p.x, p.y, way[i].x, way[i].y, way[i + 1].x, way[i + 1].y) < 5.8:
					bad = true
					break
				if _seg_inter(cur, p, way[i], way[i + 1]) >= 0.0:
					bad = true
					break
			if bad:
				continue
			way.append(p)
			dir = atan2(p.y - cur.y, p.x - cur.x)
			cur = p
			ok = true
			break
		if not ok:
			return {}

	way.append(end_a)
	way.append(end_b)
	var poly := CWUtil.catmull_rom(way, PATH_STEP)
	poly[poly.size() - 1] = end_b
	var total := float(poly.size() - 1) * PATH_STEP
	if total < 52.0 or total > 95.0:
		return {}

	var gap := int(roundf(10.0 / PATH_STEP))
	for i in range(poly.size()):
		var p := poly[i]
		var s := float(i) * PATH_STEP
		if p.x > 15.3 or p.y > 15.3 or p.y < -11.8 or p.x + p.y > 26.0:
			return {}
		if s > 7.0 and p.x < -12.2:
			return {}
		if s < total - 5.5 and absf(p.x - kx) < 5.2 and p.y < -8.6:
			return {}
		for j in range(i + gap, poly.size(), 2):
			if p.distance_to(poly[j]) < 5.6:
				return {}
	return {"poly": poly, "total": total, "zc": zc, "kx": kx}


static func _fallback_road() -> Dictionary:
	var way: Array[Vector2] = [
		Vector2(-17.6, 2.0),
		Vector2(-11.0, 2.0),
		Vector2(-4.0, 9.0),
		Vector2(5.5, 7.5),
		Vector2(10.0, 0.5),
		Vector2(5.0, -5.5),
		Vector2(6.0, -11.4),
	]
	var poly := CWUtil.catmull_rom(way, PATH_STEP)
	return {"poly": poly, "total": float(poly.size() - 1) * PATH_STEP, "zc": 2.0, "kx": 6.0}


static func _try_stream(rng: CWUtil.Rng, poly: Array[Vector2], kx: float, total_len: float) -> Dictionary:
	for _t in range(60):
		var sx := rng.rr(-10.0, 12.0)
		var sz := rng.rr(-12.5, 2.0)
		if absf(sx - kx) < 7.0 and sz < -7.0:
			continue
		if poly_min_dist(poly, sx, sz) < 3.4:
			continue
		var front := rng.next_f() < 0.65
		var ex := rng.rr(-13.0, 13.0) if front else BH + 0.6
		var ez := BH + 0.6 if front else rng.rr(-7.0, 13.0)
		var mx := (sx + ex) * 0.5 + rng.rr(-5.0, 5.0)
		var mz := (sz + ez) * 0.5 + rng.rr(-5.0, 5.0)
		var raw: Array[Vector2] = []
		for k in range(41):
			var u := float(k) / 40.0
			var a := (1.0 - u) * (1.0 - u)
			var b := 2.0 * u * (1.0 - u)
			var c := u * u
			raw.append(Vector2(a * sx + b * mx + c * ex, a * sz + b * mz + c * ez))
		var sp := CWUtil.resample_polyline(raw, 0.55)
		if sp.size() < 18:
			continue
		var cross_count := 0
		var cross_s := 0.0
		var cross_pt := Vector2.ZERO
		var cross_rel := 0.0
		var bad := false
		for i in range(sp.size() - 1):
			if bad:
				break
			for j in range(poly.size() - 1):
				var tt := _seg_inter(sp[i], sp[i + 1], poly[j], poly[j + 1])
				if tt >= 0.0:
					cross_count += 1
					if cross_count > 1:
						bad = true
						break
					cross_s = float(j) * PATH_STEP
					cross_pt = sp[i].lerp(sp[i + 1], tt)
					var sa := atan2(sp[i + 1].y - sp[i].y, sp[i + 1].x - sp[i].x)
					var ra := atan2(poly[j + 1].y - poly[j].y, poly[j + 1].x - poly[j].x)
					cross_rel = absf(_ang_diff(sa, ra))
					if cross_rel > PI * 0.5:
						cross_rel = PI - cross_rel
		if bad or cross_count != 1:
			continue
		if cross_rel < 1.0 or cross_s < 9.0 or cross_s > total_len - 9.0:
			continue
		for p in sp:
			if p.distance_to(cross_pt) > 3.4 and poly_min_dist(poly, p.x, p.y) < 3.6:
				bad = true
				break
			if absf(p.x - kx) < 6.0 and p.y < -9.0:
				bad = true
				break
			if p.x < -12.8:
				bad = true
				break
		if bad:
			continue
		return {"pts": sp, "front": front}
	return {}


static func _fallback_stream() -> Dictionary:
	var raw: Array[Vector2] = [Vector2(-6.5, -12.0), Vector2(-3.0, -2.0), Vector2(-4.5, 9.0), Vector2(-5.5, BH + 0.6)]
	return {"pts": CWUtil.catmull_rom(raw, 0.55), "front": true}


static func poly_min_dist(poly: Array[Vector2], px: float, pz: float) -> float:
	var best := 1e9
	for i in range(poly.size() - 1):
		var d := CWUtil.seg_dist(px, pz, poly[i].x, poly[i].y, poly[i + 1].x, poly[i + 1].y)
		if d < best:
			best = d
	return best


static func _choose_pads(rng: CWUtil.Rng, road: Array[Vector2], stream: Array[Vector2], kx: float) -> Array[Dictionary]:
	var pads: Array[Dictionary] = []
	var cave := road[0]
	var keep := road[road.size() - 1]
	for _attempt in range(900):
		if pads.size() >= 11:
			break
		var px := rng.rr(-11.4, BH - 3.2)
		var pz := rng.rr(-11.4, BH - 3.2)
		if px < -11.5 and pz < -6.0:
			continue
		if absf(px - kx) < 5.5 and pz < -7.5:
			continue
		var dr := poly_min_dist(road, px, pz)
		if dr < 2.25 or dr > 4.5:
			continue
		if poly_min_dist(stream, px, pz) < 2.2:
			continue
		if Vector2(px, pz).distance_to(cave) < 4.5 or Vector2(px, pz).distance_to(keep) < 5.0:
			continue
		var too_close := false
		for p in pads:
			if Vector2(px, pz).distance_to(Vector2(p["x"], p["z"])) < 4.2:
				too_close = true
				break
		if too_close:
			continue
		var best_d := 1e9
		var best_pt := road[0]
		for pt in road:
			var d := Vector2(px, pz).distance_to(pt)
			if d < best_d:
				best_d = d
				best_pt = pt
		var ang := atan2(best_pt.x - px, best_pt.y - pz)
		pads.append({
			"idx": pads.size(),
			"x": px,
			"z": pz,
			"y": 0.0,
			"rot": ang,
			"tower": null,
		})
	return pads


static func _compute_lengths(road: Array[Vector2]) -> Dictionary:
	var s_arr: Array[float] = [0.0]
	var total := 0.0
	for i in range(1, road.size()):
		total += road[i - 1].distance_to(road[i])
		s_arr.append(total)
	return {"s": s_arr, "total": total}


static func sample_path(layout: Dictionary, s: float) -> Dictionary:
	var road: Array[Vector2] = layout["road"]
	var s_arr: Array[float] = layout["path_s"]
	var total: float = layout["total_len"]
	var cs := clampf(s, 0.0, total)
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
