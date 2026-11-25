class_name CWUtil
extends RefCounted

# Deterministic PRNG, noise, and math utilities ported from 00-util.js

class Rng:
	var state: int = 1

	func _init(seed_val: int = 1) -> void:
		state = seed_val & 0xFFFFFFFF
		if state == 0:
			state = 1

	func next_f() -> float:
		state = (state + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = state
		t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
		t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF
		var out: int = (t ^ (t >> 14)) & 0xFFFFFFFF
		return float(out) / 4294967296.0

	func rr(a: float, b: float) -> float:
		return a + (b - a) * next_f()

	func ri(a: int, b: int) -> int:
		return a + int(floorf(next_f() * float(b - a + 1)))

	func pick(arr: Array):
		if arr.is_empty():
			return null
		return arr[int(floorf(next_f() * float(arr.size()))) % arr.size()]


static func damp(a: float, b: float, lam: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-lam * dt))


static func dist2(ax: float, az: float, bx: float, bz: float) -> float:
	var dx := ax - bx
	var dz := az - bz
	return dx * dx + dz * dz


static func hex_color(hex: int) -> Color:
	return Color(
		float((hex >> 16) & 0xFF) / 255.0,
		float((hex >> 8) & 0xFF) / 255.0,
		float(hex & 0xFF) / 255.0,
		1.0
	)


static func h1(n: float, s: float = 0.0) -> float:
	var x := sin(n * 127.1 + s * 311.7) * 43758.5453
	return x - floorf(x)


static func n1(x: float, s: float = 0.0) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(h1(i, s), h1(i + 1.0, s), f) * 2.0 - 1.0


static func h2(x: float, y: float, s: float = 0.0) -> float:
	var v := sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453123
	return v - floorf(v)


static func n2(x: float, y: float, s: float = 0.0) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := h2(ix, iy, s)
	var b := h2(ix + 1.0, iy, s)
	var c := h2(ix, iy + 1.0, s)
	var d := h2(ix + 1.0, iy + 1.0, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func fbm2(x: float, y: float, octs: int = 3, s: float = 0.0) -> float:
	var val := 0.0
	var amp := 0.5
	var freq := 1.0
	var norm := 0.0
	for _i in range(octs):
		val += n2(x * freq, y * freq, s + float(_i) * 19.3) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	return val / maxf(norm, 0.001)


static func pnoise2(x: float, y: float, per_x: int, per_y: int, s: float = 0.0) -> float:
	var ix := int(floorf(x))
	var iy := int(floorf(y))
	var fx := x - float(ix)
	var fy := y - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := ((ix % per_x) + per_x) % per_x
	var x1 := (x0 + 1) % per_x
	var y0 := ((iy % per_y) + per_y) % per_y
	var y1 := (y0 + 1) % per_y
	var a := h2(float(x0), float(y0), s)
	var b := h2(float(x1), float(y0), s)
	var c := h2(float(x0), float(y1), s)
	var d := h2(float(x1), float(y1), s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func seg_dist(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var dx := bx - ax
	var dz := bz - az
	var l2 := dx * dx + dz * dz
	var t := 0.0 if l2 < 1e-8 else clampf(((px - ax) * dx + (pz - az) * dz) / l2, 0.0, 1.0)
	var cx := ax + dx * t
	var cz := az + dz * t
	return sqrt(dist2(px, pz, cx, cz))


static func catmull_rom(pts: Array[Vector2], step: float = 0.3) -> Array[Vector2]:
	var raw: Array[Vector2] = []
	var n := pts.size()
	if n < 2:
		return pts.duplicate()
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(n - 1, i + 2)]
		var seg_len := p1.distance_to(p2)
		var sub := maxi(4, int(ceilf(seg_len / maxf(step * 0.5, 0.05))))
		for j in range(sub):
			var t := float(j) / float(sub)
			var t2 := t * t
			var t3 := t2 * t
			var v := 0.5 * (
				(2.0 * p1)
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			raw.append(v)
	raw.append(pts[n - 1])
	return resample_polyline(raw, step)


static func resample_polyline(raw: Array[Vector2], step: float) -> Array[Vector2]:
	if raw.size() < 2:
		return raw.duplicate()
	var out: Array[Vector2] = [raw[0]]
	var acc := 0.0
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var b := raw[i]
		var d := a.distance_to(b)
		if d < 1e-6:
			continue
		var cur := step - acc
		while cur <= d:
			out.append(a.lerp(b, cur / d))
			cur += step
		acc = d - (cur - step)
	if out.back().distance_to(raw.back()) > step * 0.25:
		out.append(raw.back())
	return out

static func ang_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)

static func ang_damp(a: float, b: float, lam: float, dt: float) -> float:
	return a + wrapf(b - a, -PI, PI) * (1.0 - exp(-lam * dt))
