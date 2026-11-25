class_name CWProps
extends RefCounted

# Procedural landmarks, roadside narrative dressing, and biome-specific flora/landforms
# Ported from 32-props.js and 33-flora.js using CWGfx.Soup


static func _xf_pt(p: Vector3, yaw: float) -> Vector3:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)


static func _box(soup: CWGfx.Soup, origin: Vector3, yaw: float, sz: Vector3, lp: Vector3, col: Color, layer: int, rough: float = 0.9, rot: Vector3 = Vector3.ZERO, sway: float = 0.0, emis: float = 0.0) -> void:
	soup.add_box(sz, origin + _xf_pt(lp, yaw), col, layer, rough, Vector3(rot.x, rot.y + yaw, rot.z), sway, emis)


static func _cyl(soup: CWGfx.Soup, origin: Vector3, yaw: float, r0: float, r1: float, h: float, lp: Vector3, col: Color, segs: int, layer: int, rough: float = 0.9, rot: Vector3 = Vector3.ZERO, sway: float = 0.0, emis: float = 0.0) -> void:
	soup.add_cyl(r0, r1, h, origin + _xf_pt(lp, yaw), col, segs, layer, rough, Vector3(rot.x, rot.y + yaw, rot.z), sway, emis)


static func _seg(soup: CWGfx.Soup, origin: Vector3, yaw: float, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs: int, layer: int, rough: float = 0.9, emis: float = 0.0) -> void:
	soup.add_seg(origin + _xf_pt(a, yaw), origin + _xf_pt(b, yaw), r0, r1, col, segs, layer, rough, emis)


static func _rock(soup: CWGfx.Soup, origin: Vector3, yaw: float, rad: float, lp: Vector3, col: Color, seed_i: int, layer: int = CWGfx.L_ROCK, rough: float = 0.93, sq: Vector3 = Vector3.ONE) -> void:
	soup.add_rock(rad, origin + _xf_pt(lp, yaw), col, seed_i, layer, rough, sq)


# --- Iconic Landmarks (32-props.js) ---

static func add_ribcage(soup: CWGfx.Soup, pos: Vector3, yaw: float, _pal: Dictionary, rng: CWUtil.Rng) -> void:
	var bone := Color(0.84, 0.80, 0.72)
	var bone_d := Color(0.68, 0.64, 0.56)
	# Exact 1:1 port of 32-props.js:93-106 giant beast ribcage (spine + 6 outward-arching rib pairs + horned skull & snout)
	_seg(soup, pos, yaw, Vector3(-1.6, 0.50, 0.0), Vector3(1.6, 0.70, 0.0), 0.10, 0.08, bone, 5, CWGfx.L_PLAIN, 0.88)
	for k in range(6):
		var rx := -1.3 + float(k) * 0.50
		var rs := 1.0 - absf(float(k) - 2.5) * 0.12
		for side: float in [-1.0, 1.0]:
			if rng.next_f() < 0.15:
				continue
			var p := Vector3(rx, 0.55, 0.0)
			var pts: Array[Vector3] = [
				Vector3(rx, 0.95 * rs, side * 0.55 * rs),
				Vector3(rx + 0.05, 1.25 * rs, side * 0.95 * rs),
				Vector3(rx + 0.10, 0.85 * rs, side * 1.15 * rs),
				Vector3(rx + 0.12, 0.10, side * 1.05 * rs),
			]
			for q in pts:
				var bc := bone * rng.rr(0.82, 1.02)
				bc.a = 1.0
				_seg(soup, pos, yaw, p, q, 0.06, 0.05, bc, 5, CWGfx.L_PLAIN, 0.88)
				p = q
	# Horned beast cranium + snout + eye sockets
	_rock(soup, pos, yaw, 0.50, Vector3(2.15, 0.55, 0.0), bone, rng.ri(1, 9999), CWGfx.L_PLAIN, 0.86, Vector3(1.35, 0.80, 0.85))
	_rock(soup, pos, yaw, 0.30, Vector3(2.85, 0.40, 0.0), bone_d, rng.ri(1, 9999), CWGfx.L_PLAIN, 0.88, Vector3(1.30, 0.60, 0.70))
	for side: float in [-1.0, 1.0]:
		_seg(soup, pos, yaw, Vector3(2.0, 0.80, side * 0.30), Vector3(1.7, 1.40, side * 0.75), 0.10, 0.02, bone, 5, CWGfx.L_PLAIN, 0.86)
		_box(soup, pos, yaw, Vector3(0.20, 0.16, 0.08), Vector3(2.30, 0.62, side * 0.40), Color(0.05, 0.05, 0.06), CWGfx.L_PLAIN, 0.96)


static func add_tower_ruin(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var st: Color = pal["stone"]
	var sdk: Color = pal["stoneD"]
	var sl: Color = pal["stoneL"]
	var r_rad := 1.65
	var n := 10
	for k in range(n):
		var a := float(k) / float(n) * TAU
		var h := clampf(4.2 - float(k) * 0.38 + rng.rr(-0.4, 0.4), 0.65, 4.4)
		var lp := Vector3(cos(a) * r_rad, h * 0.5, sin(a) * r_rad)
		var c := sdk.lerp(sl, rng.rr(0.1, 0.75))
		_box(soup, pos, yaw, Vector3(1.08, h, 0.48), lp, c, CWGfx.L_MASON, 0.90, Vector3(0, -a + PI * 0.5, 0))
		if h > 1.8 and rng.next_f() < 0.7:
			_box(soup, pos, yaw, Vector3(0.42, rng.rr(0.22, 0.48), 0.44), Vector3(cos(a + 0.1) * r_rad, h + 0.22, sin(a + 0.1) * r_rad), st.lerp(sl, 0.5), CWGfx.L_MASON, 0.88, Vector3(0, -a + PI * 0.5, 0))
	# Fallen rubble blocks around base
	for _r in range(7):
		var a := rng.rr(0.0, TAU)
		var d := rng.rr(1.8, 2.9)
		_box(soup, pos, yaw, Vector3(rng.rr(0.32, 0.62), rng.rr(0.20, 0.38), rng.rr(0.30, 0.52)), Vector3(cos(a) * d, 0.14, sin(a) * d), sdk.lerp(st, rng.next_f()), CWGfx.L_MASON, 0.92, Vector3(rng.rr(-0.4, 0.4), rng.rr(0, 3.0), rng.rr(-0.4, 0.4)))


static func add_wall_run(soup: CWGfx.Soup, pos: Vector3, yaw: float, length: float, h_max: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var st: Color = pal["stone"]
	var sdk: Color = pal["stoneD"]
	var sl: Color = pal["stoneL"]
	var x := -length * 0.5
	var h := h_max * rng.rr(0.55, 1.0)
	while x < length * 0.5:
		var w := rng.rr(0.95, 1.35)
		h = clampf(h + rng.rr(-1.0, 0.65), 0.48, h_max)
		var cx := x + w * 0.5
		_box(soup, pos, yaw, Vector3(w, h, 0.64), Vector3(cx, h * 0.5, 0.0), sdk.lerp(st, rng.rr(0.2, 0.9)), CWGfx.L_MASON, 0.91)
		if rng.next_f() < 0.6:
			_box(soup, pos, yaw, Vector3(w * rng.rr(0.35, 0.65), rng.rr(0.18, 0.42), 0.66), Vector3(cx + rng.rr(-0.15, 0.15), h + 0.14, 0.0), sl, CWGfx.L_MASON, 0.88)
		if rng.next_f() < 0.5:
			var sg := -1.0 if rng.next_f() < 0.5 else 1.0
			_rock(soup, pos, yaw, rng.rr(0.20, 0.38), Vector3(cx, 0.14, sg * rng.rr(0.5, 0.95)), sdk.lerp(st, rng.next_f()), rng.ri(1, 9999))
		x += w


static func add_grave(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var c: Color = pal["stoneD"].lerp(pal["stoneL"], rng.next_f())
	var w := rng.rr(0.42, 0.58)
	var h := rng.rr(0.62, 0.98)
	var lean := Vector3(rng.rr(-0.18, 0.18), rng.rr(-0.25, 0.25), rng.rr(-0.15, 0.15))
	if rng.next_f() < 0.35:
		# Stone cross
		_box(soup, pos, yaw, Vector3(0.16, h, 0.14), Vector3(0, h * 0.5, 0), c, CWGfx.L_MASON, 0.92, lean)
		_box(soup, pos, yaw, Vector3(0.48, 0.14, 0.14), Vector3(0, h * 0.68, 0), c, CWGfx.L_MASON, 0.92, lean)
	else:
		_box(soup, pos, yaw, Vector3(w, h, 0.14), Vector3(0, h * 0.5, 0), c, CWGfx.L_MASON, 0.92, lean)


static func add_graveyard(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	for r in range(3):
		for c in range(4):
			if rng.next_f() < 0.22:
				continue
			var lx := (float(c) - 1.5) * 1.12 + rng.rr(-0.15, 0.15)
			var lz := (float(r) - 1.0) * 1.45 + rng.rr(-0.15, 0.15)
			add_grave(soup, pos + _xf_pt(Vector3(lx, 0, lz), yaw), yaw + rng.rr(-0.2, 0.2), pal, rng)
	add_fence(soup, pos + _xf_pt(Vector3(0, 0, -2.4), yaw), yaw, 4.4, pal, rng)
	add_fence(soup, pos + _xf_pt(Vector3(-2.7, 0, -0.2), yaw), yaw + PI * 0.5, 4.0, pal, rng)
	add_fence(soup, pos + _xf_pt(Vector3(2.7, 0, 0.4), yaw), yaw + PI * 0.5, 2.8, pal, rng)
	add_gnarled_tree(soup, pos + _xf_pt(Vector3(2.2, 0, -1.9), yaw), 3.5, pal, rng, false)


static func add_statue(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var st: Color = pal["stone"]
	var sdk: Color = pal["stoneD"]
	var sl: Color = pal["stoneL"]
	_box(soup, pos, yaw, Vector3(1.2, 0.36, 1.2), Vector3(0, 0.18, 0), sdk, CWGfx.L_MASON, 0.92)
	_box(soup, pos, yaw, Vector3(0.86, 0.72, 0.86), Vector3(0, 0.72, 0), st, CWGfx.L_MASON, 0.90)
	_cyl(soup, pos, yaw, 0.34, 0.22, 1.35, Vector3(0, 1.72, 0), sl, 6, CWGfx.L_MASON, 0.88)
	_rock(soup, pos, yaw, 0.22, Vector3(0, 2.52, 0.04), sl, rng.ri(1, 9999), CWGfx.L_MASON, 0.88)
	_box(soup, pos, yaw, Vector3(0.08, 1.15, 0.08), Vector3(0.28, 1.65, 0.26), pal["iron"], CWGfx.L_METAL, 0.65, Vector3(0.15, 0, -0.18))


static func add_well(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, _rng: CWUtil.Rng) -> void:
	_cyl(soup, pos, yaw, 0.58, 0.54, 0.58, Vector3(0, 0.29, 0), pal["stone"], 8, CWGfx.L_MASON, 0.90)
	_cyl(soup, pos, yaw, 0.42, 0.42, 0.12, Vector3(0, 0.54, 0), Color(0.04, 0.06, 0.08), 8, CWGfx.L_PLAIN, 0.96)
	_box(soup, pos, yaw, Vector3(0.09, 1.45, 0.09), Vector3(-0.54, 0.72, 0), pal["woodD"], CWGfx.L_WOOD, 0.90)
	_box(soup, pos, yaw, Vector3(0.09, 1.45, 0.09), Vector3(0.54, 0.72, 0), pal["woodD"], CWGfx.L_WOOD, 0.90)
	_box(soup, pos, yaw, Vector3(1.36, 0.07, 0.58), Vector3(0, 1.54, 0.22), Color(0.26, 0.29, 0.36), CWGfx.L_SLATE, 0.86, Vector3(0.55, 0, 0))
	_box(soup, pos, yaw, Vector3(1.36, 0.07, 0.58), Vector3(0, 1.54, -0.22), Color(0.26, 0.29, 0.36), CWGfx.L_SLATE, 0.86, Vector3(-0.55, 0, 0))


static func add_cairn(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var y := 0.0
	var r := rng.rr(0.28, 0.40)
	for _k in range(4):
		_rock(soup, pos, 0.0, r, Vector3(rng.rr(-0.04, 0.04), y + r * 0.42, rng.rr(-0.04, 0.04)), pal["stoneD"].lerp(pal["stoneL"], rng.next_f()), rng.ri(1, 9999), CWGfx.L_ROCK, 0.92, Vector3(1.1, 0.62, 1.0))
		y += r * 0.68
		r *= 0.74


# --- Roadside Narrative Dressing (32-props.js) ---

static func add_fence(soup: CWGfx.Soup, pos: Vector3, yaw: float, length: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var n_p := maxi(3, int(roundf(length / 0.85)) + 1)
	var step := length / float(n_p - 1)
	for k in range(n_p):
		var x := -length * 0.5 + float(k) * step
		var hh := rng.rr(0.72, 0.95)
		var lean := Vector3(rng.rr(-0.12, 0.12), 0, rng.rr(-0.10, 0.10))
		_box(soup, pos, yaw, Vector3(0.10, hh, 0.10), Vector3(x, hh * 0.5, 0), pal["wood"].darkened(rng.rr(0.0, 0.25)), CWGfx.L_WOOD, 0.90, lean)
		if k < n_p - 1:
			for ry: float in [0.36, 0.66]:
				if rng.next_f() < 0.22:
					continue
				var drop := -0.26 if rng.next_f() < 0.15 else 0.0
				_seg(soup, pos, yaw, Vector3(x, ry, 0), Vector3(x + step, ry + drop, 0), 0.036, 0.036, pal["wood"], 4, CWGfx.L_WOOD, 0.88)


static func add_palisade(soup: CWGfx.Soup, pos: Vector3, yaw: float, length: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var n_p := maxi(5, int(roundf(length / 0.34)))
	for k in range(n_p):
		var x := -length * 0.5 + (float(k) + 0.5) * (length / float(n_p))
		var hh := rng.rr(1.22, 1.72)
		var c: Color = pal["wood"].darkened(rng.rr(0.0, 0.3))
		_cyl(soup, pos, yaw, 0.09, 0.04, hh, Vector3(x, hh * 0.5, rng.rr(-0.04, 0.04)), c, 5, CWGfx.L_WOOD, 0.92, Vector3(rng.rr(-0.10, 0.10), 0, rng.rr(-0.10, 0.10)))
	_seg(soup, pos, yaw, Vector3(-length * 0.5, 0.68, 0.08), Vector3(length * 0.5, 0.68, 0.08), 0.055, 0.055, pal["woodD"], 4, CWGfx.L_WOOD, 0.90)


static func add_banner(soup: CWGfx.Soup, pos: Vector3, yaw: float, cloth_col: Color, pal: Dictionary) -> void:
	_seg(soup, pos, yaw, Vector3(0, 0, 0), Vector3(0, 2.55, 0), 0.045, 0.032, pal["woodD"], 5, CWGfx.L_WOOD, 0.90)
	_seg(soup, pos, yaw, Vector3(-0.36, 2.32, 0.05), Vector3(0.36, 2.32, 0.05), 0.028, 0.028, pal["iron"], 4, CWGfx.L_METAL, 0.55)
	_box(soup, pos, yaw, Vector3(0.62, 1.15, 0.04), Vector3(0, 1.72, 0.06), cloth_col, CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 0.60)
	_box(soup, pos, yaw, Vector3(0.62, 0.10, 0.05), Vector3(0, 2.26, 0.06), Color(0.86, 0.68, 0.24), CWGfx.L_METAL, 0.55, Vector3.ZERO, 0.25)


static func add_signpost(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, _rng: CWUtil.Rng) -> void:
	_box(soup, pos, yaw, Vector3(0.11, 1.65, 0.11), Vector3(0, 0.82, 0), pal["woodD"], CWGfx.L_WOOD, 0.92, Vector3(0.05, 0, -0.06))
	_box(soup, pos, yaw, Vector3(0.76, 0.18, 0.05), Vector3(0.18, 1.42, 0.06), pal["wood"], CWGfx.L_WOOD, 0.88, Vector3(0, 0.28, 0.06))
	_box(soup, pos, yaw, Vector3(0.68, 0.16, 0.05), Vector3(-0.16, 1.15, -0.05), pal["wood"], CWGfx.L_WOOD, 0.88, Vector3(0, -0.35, -0.05))


static func add_gibbet(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, _rng: CWUtil.Rng) -> void:
	_box(soup, pos, yaw, Vector3(0.14, 2.75, 0.14), Vector3(0, 1.37, 0), pal["woodD"], CWGfx.L_WOOD, 0.92)
	_box(soup, pos, yaw, Vector3(1.15, 0.12, 0.12), Vector3(0.50, 2.65, 0), pal["woodD"], CWGfx.L_WOOD, 0.92)
	_seg(soup, pos, yaw, Vector3(0.08, 2.05, 0), Vector3(0.58, 2.62, 0), 0.05, 0.05, pal["woodD"], 4, CWGfx.L_WOOD, 0.92)
	# Hanging iron cage
	_seg(soup, pos, yaw, Vector3(0.95, 2.60, 0), Vector3(0.95, 2.15, 0), 0.02, 0.02, pal["iron"], 4, CWGfx.L_METAL, 0.55)
	_cyl(soup, pos, yaw, 0.26, 0.26, 0.06, Vector3(0.95, 2.12, 0), pal["iron"], 6, CWGfx.L_METAL, 0.55)
	_cyl(soup, pos, yaw, 0.26, 0.26, 0.06, Vector3(0.95, 1.48, 0), pal["iron"], 6, CWGfx.L_METAL, 0.55)
	for k in range(4):
		var a := float(k) * PI * 0.5
		_seg(soup, pos, yaw, Vector3(0.95 + cos(a) * 0.24, 1.48, sin(a) * 0.24), Vector3(0.95 + cos(a) * 0.24, 2.12, sin(a) * 0.24), 0.018, 0.018, pal["iron"], 4, CWGfx.L_METAL, 0.55)


static func add_cart(soup: CWGfx.Soup, pos: Vector3, yaw: float, broken: bool, pal: Dictionary, _rng: CWUtil.Rng) -> void:
	var tilt := Vector3(0.0, 0.0, 0.22 if broken else 0.0)
	_box(soup, pos, yaw, Vector3(1.35, 0.10, 0.78), Vector3(0, 0.42, 0), pal["wood"], CWGfx.L_WOOD, 0.88, tilt)
	_box(soup, pos, yaw, Vector3(1.35, 0.28, 0.06), Vector3(0, 0.58, 0.37), pal["woodD"], CWGfx.L_WOOD, 0.88, tilt)
	_box(soup, pos, yaw, Vector3(1.35, 0.28, 0.06), Vector3(0, 0.58, -0.37), pal["woodD"], CWGfx.L_WOOD, 0.88, tilt)
	_box(soup, pos, yaw, Vector3(0.06, 0.28, 0.76), Vector3(-0.65, 0.58, 0), pal["woodD"], CWGfx.L_WOOD, 0.88, tilt)
	# Shafts
	_seg(soup, pos, yaw, Vector3(0.65, 0.42, 0.24), Vector3(1.45, 0.14, 0.24), 0.035, 0.03, pal["woodD"], 4, CWGfx.L_WOOD, 0.90)
	_seg(soup, pos, yaw, Vector3(0.65, 0.42, -0.24), Vector3(1.45, 0.14, -0.24), 0.035, 0.03, pal["woodD"], 4, CWGfx.L_WOOD, 0.90)
	# Wheels
	_cyl(soup, pos, yaw, 0.34, 0.34, 0.08, Vector3(-0.10, 0.34, 0.45), pal["woodD"], 8, CWGfx.L_WOOD, 0.90, Vector3(PI * 0.5, 0, 0))
	if not broken:
		_cyl(soup, pos, yaw, 0.34, 0.34, 0.08, Vector3(-0.10, 0.34, -0.45), pal["woodD"], 8, CWGfx.L_WOOD, 0.90, Vector3(PI * 0.5, 0, 0))
	else:
		_cyl(soup, pos, yaw, 0.34, 0.34, 0.08, Vector3(-0.35, 0.06, -0.78), pal["woodD"], 8, CWGfx.L_WOOD, 0.90, Vector3(0.18, 0.4, 0.12))
	# Cargo barrel
	_cyl(soup, pos, yaw, 0.20, 0.18, 0.42, Vector3(-0.25, 0.66, 0.05), pal["wood"], 6, CWGfx.L_WOOD, 0.86)


static func add_supply_cluster(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	_cyl(soup, pos, yaw, 0.22, 0.20, 0.48, Vector3(0, 0.24, 0), pal["wood"], 6, CWGfx.L_WOOD, 0.86)
	if rng.next_f() < 0.65:
		_cyl(soup, pos, yaw, 0.20, 0.18, 0.44, Vector3(0.46, 0.22, 0.14), pal["woodD"], 6, CWGfx.L_WOOD, 0.88)
	if rng.next_f() < 0.75:
		_box(soup, pos, yaw, Vector3(0.48, 0.44, 0.48), Vector3(-0.12, 0.22, 0.52), pal["wood"], CWGfx.L_WOOD, 0.88, Vector3(0, rng.rr(0, 1.5), 0))


static func add_bone_pile(soup: CWGfx.Soup, pos: Vector3, _pal: Dictionary, rng: CWUtil.Rng, n: int = 5) -> void:
	var bone := Color(0.84, 0.80, 0.72)
	for _k in range(n):
		var a := rng.rr(0.0, TAU)
		var l := rng.rr(0.22, 0.46)
		var x := rng.rr(-0.38, 0.38)
		var z := rng.rr(-0.38, 0.38)
		soup.add_seg(pos + Vector3(x, 0.04, z), pos + Vector3(x + cos(a) * l, 0.05 + rng.rr(0.0, 0.07), z + sin(a) * l), 0.032, 0.03, bone.darkened(rng.rr(0.0, 0.22)), 4, CWGfx.L_PLAIN, 0.88)
	if rng.next_f() < 0.72:
		soup.add_rock(0.14, pos + Vector3(rng.rr(-0.18, 0.18), 0.12, rng.rr(-0.18, 0.18)), bone, rng.ri(1, 9999), CWGfx.L_PLAIN, 0.86)


static func add_skull_stake(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	soup.add_seg(pos, pos + Vector3(rng.rr(-0.08, 0.08), 1.62, rng.rr(-0.08, 0.08)), 0.055, 0.035, pal["woodD"], 4, CWGfx.L_WOOD, 0.92)
	soup.add_rock(0.17, pos + Vector3(0, 1.72, 0), Color(0.86, 0.82, 0.74), rng.ri(1, 9999), CWGfx.L_PLAIN, 0.86)


# --- Biome Flora & Landforms (33-flora.js) ---

static func add_gnarled_tree(soup: CWGfx.Soup, pos: Vector3, h: float, pal: Dictionary, rng: CWUtil.Rng, ember_tips: bool = false) -> void:
	var bark: Color = pal["bark"].darkened(rng.rr(0.0, 0.25))
	var tip_col := Color(1.0, 0.36, 0.08) if ember_tips else bark
	var tip_emis := 0.12 if ember_tips else 0.0
	_gnarled_branch(soup, pos + Vector3(0, 0.02, 0), Vector3(rng.rr(-0.14, 0.14), 1.0, rng.rr(-0.14, 0.14)).normalized(), h * 0.42, h * 0.075, 0, bark, tip_col, tip_emis, rng)


static func _gnarled_branch(soup: CWGfx.Soup, a: Vector3, dir: Vector3, length: float, rad: float, depth: int, bark: Color, tip_col: Color, tip_emis: float, rng: CWUtil.Rng) -> void:
	var b := a + dir * length
	var is_tip := depth >= 2
	var col := tip_col if is_tip else bark
	var em := tip_emis if is_tip else 0.0
	soup.add_seg(a, b, rad, rad * 0.62, col, 4 if depth > 0 else 5, CWGfx.L_BARK, 0.94, em)
	if depth >= 2:
		return
	var n_sub := 2 if depth == 0 else rng.ri(2, 3)
	for _k in range(n_sub):
		var nd := Vector3(dir.x + rng.rr(-0.85, 0.85), maxf(0.18, dir.y * 0.65 + rng.rr(0.05, 0.55)), dir.z + rng.rr(-0.85, 0.85)).normalized()
		_gnarled_branch(soup, b, nd, length * rng.rr(0.58, 0.78), rad * 0.60, depth + 1, bark, tip_col, tip_emis, rng)


static func add_shroom_cluster(soup: CWGfx.Soup, pos: Vector3, rng: CWUtil.Rng) -> void:
	# Exact 33-flora.js:84-90 soft glowing teal/cyan mushroom cluster (emis=0.075, no blinding bloom)
	var base_c := CWUtil.hex_color(0x4fe0c0) if rng.next_f() < 0.5 else CWUtil.hex_color(0x7fd0ff)
	var cap_c := Color(base_c.r * 0.58, base_c.g * 0.58, base_c.b * 0.58, 1.0)
	var stem_c := CWUtil.hex_color(0xb8c8b8)
	var n := rng.ri(3, 6)
	for _k in range(n):
		var ox := rng.rr(-0.30, 0.30)
		var oz := rng.rr(-0.30, 0.30)
		var hh := rng.rr(0.14, 0.44)
		var r := hh * rng.rr(0.45, 0.70)
		soup.add_cyl(r * 0.22, r * 0.18, hh, pos + Vector3(ox, hh * 0.5, oz), stem_c, 5, CWGfx.L_PLAIN, 0.82, Vector3.ZERO, 0.0, 0.02)
		soup.add_cone(r, r * 0.58, pos + Vector3(ox, hh + r * 0.14, oz), cap_c, 7, CWGfx.L_PLAIN, 0.45, Vector3.ZERO, 0.0, 0.075)


static func add_log(soup: CWGfx.Soup, pos: Vector3, yaw: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var length := rng.rr(1.5, 2.5)
	var r := rng.rr(0.14, 0.21)
	_seg(soup, pos, yaw, Vector3(-length * 0.5, r, 0), Vector3(length * 0.5, r, 0), r, r * 0.85, pal["bark"], 6, CWGfx.L_BARK, 0.94)
	for _k in range(2):
		var sx := rng.rr(-length * 0.3, length * 0.3)
		_seg(soup, pos, yaw, Vector3(sx, r, 0), Vector3(sx + rng.rr(-0.15, 0.15), r + 0.34, rng.rr(-0.25, 0.25)), r * 0.34, r * 0.18, pal["bark"], 4, CWGfx.L_BARK, 0.94)


static func add_stump(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var r := rng.rr(0.18, 0.28)
	var h := rng.rr(0.24, 0.42)
	soup.add_cyl(r * 1.18, r, h, pos + Vector3(0, h * 0.5, 0), pal["bark"], 6, CWGfx.L_BARK, 0.94)


static func add_basalt(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var offsets := [Vector2(0, 0), Vector2(0.45, 0.15), Vector2(-0.42, 0.22), Vector2(0.15, -0.45), Vector2(-0.35, -0.35), Vector2(0.55, -0.32)]
	for k in range(offsets.size()):
		var q: Vector2 = offsets[k]
		var hh := rng.rr(0.4, 2.1) * (1.2 if k < 3 else 0.78)
		var c: Color = pal["stoneD"].lerp(pal["stone"], rng.rr(0.0, 0.5))
		soup.add_cyl(0.24, 0.22, hh, pos + Vector3(q.x, hh * 0.5, q.y), c, 6, CWGfx.L_ROCK, 0.92)


static func add_spire(soup: CWGfx.Soup, pos: Vector3, hh: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	var y := 0.0
	var r := hh * rng.rr(0.20, 0.26)
	var ox := 0.0
	var oz := 0.0
	while y < hh and r > 0.12:
		soup.add_rock(r, pos + Vector3(ox, y + r * 0.4, oz), pal["stoneD"].lerp(pal["stoneL"], rng.rr(0.1, 0.75)), rng.ri(1, 9999), CWGfx.L_ROCK, 0.92, Vector3(1.0, 0.65, 1.0))
		y += r * 0.78
		r *= rng.rr(0.78, 0.92)
		ox += rng.rr(-0.07, 0.07)
		oz += rng.rr(-0.07, 0.07)


static func add_vent(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	for k in range(7):
		var a := float(k) / 7.0 * TAU + rng.rr(0, 0.3)
		var r := rng.rr(0.20, 0.32)
		soup.add_rock(r, pos + Vector3(cos(a) * 0.50, r * 0.3, sin(a) * 0.50), pal["stoneD"], rng.ri(1, 9999), CWGfx.L_ROCK, 0.94, Vector3(1.0, 0.8, 1.0))
	soup.add_cyl(0.42, 0.38, 0.10, pos + Vector3(0, 0.08, 0), Color(1.0, 0.42, 0.10), 7, CWGfx.L_PLAIN, 0.3, Vector3.ZERO, 0.0, 2.2)


static func add_crystal(soup: CWGfx.Soup, pos: Vector3, col: Color, rng: CWUtil.Rng) -> void:
	var n := rng.ri(3, 5)
	for k in range(n):
		var hh := rng.rr(0.35, 0.92) * (1.25 if k == 0 else 0.72)
		var a := rng.rr(0.0, TAU)
		var d := 0.0 if k == 0 else rng.rr(0.12, 0.30)
		soup.add_cone(hh * 0.24, hh, pos + Vector3(cos(a) * d, hh * 0.5, sin(a) * d), col, 5, CWGfx.L_PLAIN, 0.18, Vector3(rng.rr(-0.35, 0.35), rng.rr(0, TAU), rng.rr(-0.35, 0.35)), 0.0, 0.08)


static func add_cactus(soup: CWGfx.Soup, pos: Vector3, rng: CWUtil.Rng) -> void:
	var c := Color(0.31, 0.42, 0.24).darkened(rng.rr(0.0, 0.18))
	var hh := rng.rr(1.05, 1.85)
	soup.add_cyl(0.17, 0.15, hh, pos + Vector3(0, hh * 0.5, 0), c, 6, CWGfx.L_LEAF, 0.88)
	for _k in range(rng.ri(1, 2)):
		var a := rng.rr(0.0, TAU)
		var ay := hh * rng.rr(0.38, 0.62)
		var arm_l := rng.rr(0.28, 0.42)
		var up := rng.rr(0.32, 0.65)
		var p1 := pos + Vector3(cos(a) * arm_l, ay, sin(a) * arm_l)
		soup.add_seg(pos + Vector3(0, ay, 0), p1, 0.11, 0.10, c, 5, CWGfx.L_LEAF, 0.88)
		soup.add_seg(p1, p1 + Vector3(0, up, 0), 0.10, 0.09, c, 5, CWGfx.L_LEAF, 0.88)


static func add_reeds(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	for _k in range(5):
		var ox := rng.rr(-0.28, 0.28)
		var oz := rng.rr(-0.28, 0.28)
		var hh := rng.rr(0.55, 1.15)
		var c: Color = pal["tuftA"].lerp(pal["tuftB"], rng.next_f())
		soup.add_cone(0.045, hh, pos + Vector3(ox, hh * 0.5, oz), c, 4, CWGfx.L_LEAF, 0.90, Vector3(rng.rr(-0.18, 0.18), 0, rng.rr(-0.18, 0.18)), 0.75)


static func _add_ribbon(soup: CWGfx.Soup, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, sway_v: float) -> void:
	soup.add_quad(a, b, c, d, col, CWGfx.L_LEAF, 0.82, sway_v)
	soup.add_quad(a, d, c, b, col.darkened(0.08), CWGfx.L_LEAF, 0.82, sway_v)


static func add_palm(soup: CWGfx.Soup, pos: Vector3, h: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	# Exact 33-flora.js:43-59 curved ringed palm trunk + 8-10 parabolic drooping fronds + 3 coconuts
	var bark := CWUtil.hex_color(0x6a5238) * rng.rr(0.85, 1.15)
	bark.a = 1.0
	var a0 := rng.rr(0.0, TAU)
	var bend := rng.rr(0.12, 0.30)
	var p := pos + Vector3(0.0, -0.08, 0.0)
	for k in range(7):
		var u := float(k + 1) / 7.0
		var off := bend * h * u * u
		var q := pos + Vector3(cos(a0) * off, h * u, sin(a0) * off)
		var r := h * (0.052 - 0.020 * u)
		var col := bark * (0.84 if (k & 1) == 1 else 1.06)
		col.a = 1.0
		soup.add_seg(p, q, r * (1.12 if (k & 1) == 1 else 1.0), r * 0.90, col, 6, CWGfx.L_WOOD, 0.92)
		p = q
	var top := p
	var nf := rng.ri(8, 10)
	var leaf: Color = pal["leaf"]
	var leaf_l: Color = pal["leafL"]
	for f in range(nf):
		var fa := float(f) / float(nf) * TAU + rng.rr(-0.24, 0.24)
		var flen := h * rng.rr(0.36, 0.48)
		var fup := rng.rr(0.22, 0.60)
		var fc := leaf.lerp(leaf_l, rng.next_f()) * rng.rr(0.85, 1.20)
		fc.a = 1.0
		var prev_c := Vector3.ZERO
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for m in range(6):
			var u := float(m) / 5.0
			var out := flen * u
			var fy := top.y + flen * (fup * u - 0.95 * u * u)
			var cx := top.x + cos(fa) * out
			var cz := top.z + sin(fa) * out
			var w := flen * 0.20 * sin(minf(1.0, u * 1.1 + 0.1) * PI) + 0.015
			var sx := -sin(fa) * w
			var sz := cos(fa) * w
			var cur_c := Vector3(cx, fy, cz)
			var cur_l := Vector3(cx + sx, fy - w * 0.58, cz + sz)
			var cur_r := Vector3(cx - sx, fy - w * 0.58, cz - sz)
			if m > 0:
				var sw := 0.25 + 0.75 * u
				_add_ribbon(soup, prev_c, cur_c, cur_l, prev_l, fc, sw)
				_add_ribbon(soup, prev_c, prev_r, cur_r, cur_c, fc.darkened(0.16), sw)
			prev_c = cur_c; prev_l = cur_l; prev_r = cur_r
	for _ck in range(3):
		soup.add_rock(h * 0.036, top + Vector3(rng.rr(-0.12, 0.12), -0.10, rng.rr(-0.12, 0.12)), CWUtil.hex_color(0x3a2a1c), rng.ri(1, 9999), CWGfx.L_BARK, 0.9)


static func add_willow(soup: CWGfx.Soup, pos: Vector3, h: float, pal: Dictionary, rng: CWUtil.Rng) -> void:
	# Exact 33-flora.js:23-41 gnarled willow trunk + buttress roots + drooping swaying vine ribbons
	var bark: Color = pal["bark"] * rng.rr(0.85, 1.12)
	bark.a = 1.0
	var p := pos + Vector3(0.0, -0.08, 0.0)
	var d := Vector3(rng.rr(-0.22, 0.22), 1.0, rng.rr(-0.22, 0.22)).normalized()
	var r := h * 0.082
	for _k in range(4):
		var seg_l := h * rng.rr(0.15, 0.20)
		var q := p + d * seg_l
		soup.add_seg(p, q, r, r * 0.80, bark, 6, CWGfx.L_BARK, 0.94)
		p = q; r *= 0.80
		d = (d + Vector3(rng.rr(-0.38, 0.38), 0.3, rng.rr(-0.38, 0.38))).normalized()
	var tips: Array[Vector3] = [p + Vector3(0.0, h * 0.08, 0.0)]
	for k in range(4):
		var a := rng.rr(0.0, TAU) + float(k) * 1.57
		var blen := h * rng.rr(0.28, 0.42)
		var q := p + Vector3(cos(a) * blen * 0.8, blen * rng.rr(0.12, 0.42), sin(a) * blen * 0.8)
		soup.add_seg(p, q, r, r * 0.45, bark, 5, CWGfx.L_BARK, 0.94)
		tips.append(q)
	var leaf: Color = pal["leaf"]
	var leaf_l: Color = pal["leafL"]
	for tip in tips:
		for _j in range(2):
			var rb := h * rng.rr(0.18, 0.27)
			var c := leaf.lerp(leaf_l, rng.next_f()) * rng.rr(0.78, 1.15)
			c.a = 1.0
			var cp := tip + Vector3(rng.rr(-0.24, 0.24), rng.rr(-0.04, 0.26), rng.rr(-0.24, 0.24))
			soup.add_rock(rb, cp, c, rng.ri(1, 9999), CWGfx.L_LEAF, 0.88, Vector3(1.18, 0.48, 1.18))
			for _s in range(6):
				var va := rng.rr(0.0, TAU)
				var vrad := rb * rng.rr(0.48, 1.02)
				var vx := cp.x + cos(va) * vrad
				var vz := cp.z + sin(va) * vrad
				var vlen := rng.rr(0.55, 1.45)
				var vy0 := cp.y - rb * 0.08
				var wa := rng.rr(0.0, TAU)
				var wx := cos(wa) * 0.048
				var wz := sin(wa) * 0.048
				var vc := leaf.lerp(leaf_l, rng.next_f()) * rng.rr(0.65, 0.95)
				vc.a = 1.0
				_add_ribbon(soup, Vector3(vx - wx, vy0, vz - wz), Vector3(vx + wx, vy0, vz + wz), Vector3(vx + wx * 0.4, vy0 - vlen, vz + wz * 0.4), Vector3(vx - wx * 0.4, vy0 - vlen, vz - wz * 0.4), vc, 0.85)
	for k in range(4):
		var ra := float(k) * 1.57 + rng.rr(0.0, 0.6)
		soup.add_seg(pos + Vector3(cos(ra) * h * 0.04, h * 0.17, sin(ra) * h * 0.04), pos + Vector3(cos(ra) * h * 0.22, -0.08, sin(ra) * h * 0.22), h * 0.032, h * 0.018, bark, 5, CWGfx.L_BARK, 0.94)


static func add_lily(soup: CWGfx.Soup, pos: Vector3, pal: Dictionary, rng: CWUtil.Rng) -> void:
	# Exact 33-flora.js:77-82 floating lily pads + occasional pale pink lotus flower
	var n := rng.ri(2, 4)
	for _k in range(n):
		var ox := rng.rr(-0.38, 0.38)
		var oz := rng.rr(-0.38, 0.38)
		var r := rng.rr(0.14, 0.26)
		var c: Color = pal["leaf"].lerp(pal["leafL"], rng.next_f()) * rng.rr(1.05, 1.35)
		c.a = 1.0
		soup.add_cyl(r, r, 0.016, pos + Vector3(ox, 0.014, oz), c, 7, CWGfx.L_LEAF, 0.72)
		if rng.next_f() < 0.35:
			soup.add_rock(0.06, pos + Vector3(ox + r * 0.28, 0.055, oz), CWUtil.hex_color(0xe8c8d8), rng.ri(1, 9999), CWGfx.L_PLAIN, 0.65, Vector3(1.0, 0.7, 1.0))


static func add_jar_cluster(soup: CWGfx.Soup, pos: Vector3, rng: CWUtil.Rng) -> void:
	# Exact 33-flora.js:114-118, 174-175 terracotta amphora jars beside Duskmesa tower pads
	var cnt := rng.ri(1, 3)
	for j in range(cnt):
		var base_c := CWUtil.hex_color(0x9a5a3c) * rng.rr(0.82, 1.15)
		base_c.a = 1.0
		var sc := rng.rr(0.82, 1.22)
		var jp := pos + (Vector3.ZERO if j == 0 else Vector3(rng.rr(-0.42, 0.42), 0.0, rng.rr(-0.42, 0.42)))
		var tilt := Vector3(1.25, rng.rr(0.0, TAU), 0.0) if (j == 2 and rng.next_f() < 0.5) else Vector3.ZERO
		soup.add_cyl(0.13 * sc, 0.20 * sc, 0.22 * sc, jp + Vector3(0, 0.11 * sc, 0), base_c, 8, CWGfx.L_PLAIN, 0.85, tilt)
		soup.add_cyl(0.20 * sc, 0.18 * sc, 0.20 * sc, jp + Vector3(0, 0.32 * sc, 0), base_c, 8, CWGfx.L_PLAIN, 0.85, tilt)
		soup.add_cyl(0.18 * sc, 0.09 * sc, 0.14 * sc, jp + Vector3(0, 0.49 * sc, 0), base_c, 8, CWGfx.L_PLAIN, 0.85, tilt)
		soup.add_cyl(0.09 * sc, 0.11 * sc, 0.11 * sc, jp + Vector3(0, 0.60 * sc, 0), base_c.darkened(0.10), 8, CWGfx.L_PLAIN, 0.85, tilt)
		soup.add_cyl(0.10 * sc, 0.10 * sc, 0.02 * sc, jp + Vector3(0, 0.66 * sc, 0), Color(0.08, 0.07, 0.08), 8, CWGfx.L_PLAIN, 0.95, tilt)


static func add_web(soup: CWGfx.Soup, pos: Vector3, yaw: float, sz: float) -> void:
	# Cobweb radial & concentric silk strands (32-props.js web)
	var col := Color(0.76, 0.78, 0.82)
	for k in range(6):
		var a := float(k) * TAU / 6.0
		_seg(soup, pos, yaw, Vector3.ZERO, Vector3(cos(a) * sz, sin(a) * sz, 0.0), 0.012, 0.008, col, 3, CWGfx.L_PLAIN, 0.92)
	for r_f: float in [0.42, 0.76]:
		for k in range(6):
			var a0 := float(k) * TAU / 6.0
			var a1 := float(k + 1) * TAU / 6.0
			_seg(soup, pos, yaw, Vector3(cos(a0) * sz * r_f, sin(a0) * sz * r_f, 0.0), Vector3(cos(a1) * sz * r_f, sin(a1) * sz * r_f, 0.0), 0.009, 0.009, col, 3, CWGfx.L_PLAIN, 0.92)


static func add_drift(soup: CWGfx.Soup, pos: Vector3, r: float, col: Color, rng: CWUtil.Rng) -> void:
	# Smooth rounded Frostfall snow drift mound (33-flora.js:122)
	soup.add_rock(r, pos + Vector3(0.0, r * 0.05, 0.0), col, rng.ri(1, 9999), CWGfx.L_PLAIN, 0.75, Vector3(1.25, 0.28, 0.85))
