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


static func ang_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)

static func ang_damp(a: float, b: float, lam: float, dt: float) -> float:
	return a + wrapf(b - a, -PI, PI) * (1.0 - exp(-lam * dt))
