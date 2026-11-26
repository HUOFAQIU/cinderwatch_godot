class_name AroundMeGame
extends Node3D

## Self-contained Morning Forest Clearing survival simulation under res://aroundme/
## High-capacity spatial-hash crowd simulation supporting 2000 monsters;
## delegates audio to AroundMeSfxPool and sparks/debris to AroundMeFxPool.

const SPAWN_RADIUS_MIN := 23.0
const SPAWN_RADIUS_MAX := 30.5
const MAX_MONS := 2000
const BATCH_CAP := 512
const GRID_CELL := 1.25
const SWING_IMPACT_U := 0.52

const MOB_TYPES: Array[Dictionary] = [
	{"id": "rat",    "hp": 22.0,  "spd": 3.45, "dmg": 4.0,  "cd": 0.90, "reach": 1.15, "scale": 0.92, "hit_h": 0.42, "col": Color(0.50, 0.42, 0.34), "min_w": 1},
	{"id": "skel",   "hp": 36.0,  "spd": 2.45, "dmg": 6.0,  "cd": 1.10, "reach": 1.28, "scale": 1.00, "hit_h": 0.95, "col": Color(0.86, 0.82, 0.72), "min_w": 1},
	{"id": "slime",  "hp": 44.0,  "spd": 1.95, "dmg": 5.5,  "cd": 1.18, "reach": 1.22, "scale": 0.98, "hit_h": 0.52, "col": Color(0.45, 0.78, 0.32), "min_w": 1},
	{"id": "spider", "hp": 30.0,  "spd": 3.25, "dmg": 5.5,  "cd": 0.95, "reach": 1.18, "scale": 0.96, "hit_h": 0.48, "col": Color(0.32, 0.28, 0.38), "min_w": 1},
	{"id": "ghoul",  "hp": 52.0,  "spd": 2.65, "dmg": 8.0,  "cd": 1.05, "reach": 1.26, "scale": 1.04, "hit_h": 0.92, "col": Color(0.48, 0.62, 0.44), "min_w": 2},
	{"id": "wolf",   "hp": 40.0,  "spd": 3.85, "dmg": 7.5,  "cd": 0.88, "reach": 1.22, "scale": 1.05, "hit_h": 0.62, "col": Color(0.46, 0.44, 0.48), "min_w": 2},
	{"id": "knight", "hp": 85.0,  "spd": 1.85, "dmg": 11.0, "cd": 1.28, "reach": 1.38, "scale": 1.10, "hit_h": 1.05, "col": Color(0.55, 0.58, 0.64), "min_w": 3},
	{"id": "brute",  "hp": 135.0, "spd": 1.55, "dmg": 15.0, "cd": 1.48, "reach": 1.52, "scale": 1.22, "hit_h": 1.18, "col": Color(0.54, 0.36, 0.30), "min_w": 4},
]

@export_group("Soldier")
@export var soldier_max_hp: float = 360.0
@export var soldier_range: float = 2.65
@export var soldier_dmg: float = 30.0
@export var soldier_atk_period: float = 0.56

var soldier_pos := Vector3.ZERO
var soldier_yaw: float = 0.0
var soldier_hp: float = 360.0
var soldier_cd: float = 0.0
var soldier_swing: float = 0.0
var soldier_hit_pending: bool = false
var soldier_flash: float = 0.0
var soldier_dead: bool = false
var soldier_respawn_t: float = 0.0

var wave: int = 1
var kills: int = 0
var elapsed: float = 0.0
var _spawn_cd: float = 0.45
var shake_mag: float = 0.0
var shake_offset := Vector2.ZERO

var muted: bool:
	get: return _sfx.muted

var perf_sim_ms: float = 0.0
var perf_batch_ms: float = 0.0

var mons: Array[Dictionary] = []
var _grid: Dictionary = {}
var _mat_unit: ShaderMaterial
var _batches: Dictionary = {}

var _sfx := AroundMeSfxPool.new()
var _fx := AroundMeFxPool.new()


func init_game(mat_unit: ShaderMaterial) -> void:
	_mat_unit = mat_unit
	_sfx.init(self, ["sword", "clash", "hit", "kill", "horn", "ui_click"], 10)
	_init_unit_batches()
	_fx.init(self)
	reset_run()


func toggle_mute() -> void:
	_sfx.toggle_mute()


func play_ui_click() -> void:
	_sfx.play("ui_click", 0.65)


func _create_batch(key: String, mesh_path: String, cap: int) -> void:
	if not ResourceLoader.exists(mesh_path):
		return
	var m := load(mesh_path) as Mesh
	if m == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = m
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_unit
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)
	var buf := PackedFloat32Array()
	buf.resize(cap * 20)
	_batches[key] = {"mm": mm, "buf": buf, "cap": cap, "cnt": 0}


func _init_unit_batches() -> void:
	_create_batch("soldier", "res://aroundme/assets/models/footman_s.res", 2)
	for md in MOB_TYPES:
		var mid: String = md["id"]
		_create_batch(mid, "res://aroundme/assets/models/units/%s.res" % mid, BATCH_CAP)


func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var center_flat := clampf((r - 3.2) / 4.2, 0.0, 1.0)
	var roll := (sin(x * 0.16) * cos(z * 0.14) * 0.34 + sin((x + z) * 0.085) * 0.22) * center_flat
	var rim_rise := clampf((r - 17.0) / 14.0, 0.0, 1.0) * 0.55
	return 0.08 * (1.0 - center_flat) + roll + rim_rise


func reset_run() -> void:
	mons.clear()
	_fx.clear()
	soldier_pos = Vector3(0.0, height_at(0.0, 0.0), 0.0)
	soldier_yaw = 0.0
	soldier_hp = soldier_max_hp
	soldier_cd = 0.0
	soldier_swing = 0.0
	soldier_hit_pending = false
	soldier_flash = 0.0
	soldier_dead = false
	soldier_respawn_t = 0.0
	wave = 1
	kills = 0
	elapsed = 0.0
	_spawn_cd = 0.4
	shake_mag = 0.0
	shake_offset = Vector2.ZERO
	_sfx.play("horn", 0.45)

	for i in range(12):
		_spawn_outer_monster(TAU * float(i) / 12.0 + randf_range(-0.18, 0.18), false)


func spawn_stress_wave(count: int = 100) -> void:
	for i in range(count):
		if mons.size() >= MAX_MONS:
			break
		var a := TAU * (float(i) + randf()) / float(maxi(count, 1))
		_spawn_outer_monster(a, true)


func _spawn_outer_monster(angle: float = -1.0, all_types: bool = false) -> void:
	if mons.size() >= MAX_MONS:
		return
	var def: Dictionary
	if all_types:
		def = MOB_TYPES[randi() % MOB_TYPES.size()]
	else:
		var eligible: Array[Dictionary] = []
		for md in MOB_TYPES:
			if int(md["min_w"]) <= wave:
				eligible.append(md)
		def = eligible[randi() % eligible.size()]
	var a := randf() * TAU if angle < 0.0 else angle
	var rad := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var mx := cos(a) * rad
	var mz := sin(a) * rad
	var hp_mul := 1.0 + float(wave - 1) * 0.14
	var max_hp := float(def["hp"]) * hp_mul
	mons.append({
		"def": def,
		"id": String(def["id"]),
		"x": mx,
		"y": height_at(mx, mz),
		"z": mz,
		"yaw": atan2(-mx, -mz),
		"hp": max_hp,
		"max_hp": max_hp,
		"phase": randf() * TAU,
		"swing": 0.0,
		"hit_pending": false,
		"flash": 0.0,
		"cd": randf_range(0.15, 0.55),
		"mv": 1.0,
	})


func get_gpu_unit_count() -> int:
	var total := 0
	for k in _batches.keys():
		total += int(_batches[k]["cnt"])
	return total


func _push_unit(key: String, x: float, y: float, z: float, yaw: float, sc: float, ph: float, sw: float, fl: float, mv: float) -> void:
	if not _batches.has(key):
		return
	var b: Dictionary = _batches[key]
	var cnt: int = b["cnt"]
	if cnt >= int(b["cap"]):
		return
	var buf: PackedFloat32Array = b["buf"]
	var cy := cos(yaw) * sc
	var sy := sin(yaw) * sc
	var off := cnt * 20
	buf[off] = cy; buf[off + 1] = 0.0; buf[off + 2] = sy; buf[off + 3] = x
	buf[off + 4] = 0.0; buf[off + 5] = sc; buf[off + 6] = 0.0; buf[off + 7] = y
	buf[off + 8] = -sy; buf[off + 9] = 0.0; buf[off + 10] = cy; buf[off + 11] = z
	buf[off + 12] = 1.0; buf[off + 13] = 1.0; buf[off + 14] = 1.0; buf[off + 15] = 1.0
	buf[off + 16] = ph; buf[off + 17] = sw; buf[off + 18] = fl; buf[off + 19] = mv
	b["cnt"] = cnt + 1


func _resolve_soldier_strike() -> void:
	var hit_n := 0
	var max_cleave := 4
	var r2 := (soldier_range + 0.45) * (soldier_range + 0.45)
	var killed_any := false
	for i in range(mons.size() - 1, -1, -1):
		var m := mons[i]
		var mx := float(m["x"])
		var mz := float(m["z"])
		var d2 := mx * mx + mz * mz
		if d2 <= r2:
			var ang_to := atan2(mx, mz)
			if absf(wrapf(ang_to - soldier_yaw, -PI, PI)) < 1.45 or d2 < 2.25:
				m["hp"] = float(m["hp"]) - soldier_dmg
				m["flash"] = 0.85
				var dn := Vector3(mx, 0.0, mz).normalized()
				m["x"] = mx + dn.x * 0.28
				m["z"] = mz + dn.z * 0.28
				_fx.spawn_sparks(Vector3(mx, float(m["y"]) + float(m["def"]["hit_h"]), mz), 4, Color(2.4, 1.7, 0.6), 4.0)
				if float(m["hp"]) <= 0.0:
					kills += 1
					killed_any = true
					_fx.spawn_shatter(Vector3(mx, float(m["y"]), mz), float(m["def"]["scale"]), m["def"]["col"], dn * 2.8)
					shake_mag = minf(0.40, shake_mag + 0.07)
					mons.remove_at(i)
				hit_n += 1
				if hit_n >= max_cleave:
					break
	if hit_n > 0:
		_sfx.play("sword", 0.48)
		if killed_any:
			_sfx.play("kill", 0.42)
	else:
		_sfx.play("sword", 0.25)


func step_sim(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	elapsed += dt
	wave = 1 + int(elapsed / 20.0)

	shake_mag = maxf(0.0, shake_mag - dt * 3.2)
	var sh := shake_mag * shake_mag * 0.22
	shake_offset = Vector2(sin(elapsed * 47.0), cos(elapsed * 53.0)) * sh if sh > 1e-5 else Vector2.ZERO

	if not soldier_dead:
		_spawn_cd -= dt
		if _spawn_cd <= 0.0:
			var pack := 2 + mini(4, int(float(wave) / 2.0))
			var base_a := randf() * TAU
			for _pi in range(pack):
				_spawn_outer_monster(base_a + randf_range(-0.35, 0.35), false)
			_spawn_cd = maxf(0.24, 1.05 - float(wave - 1) * 0.10) * randf_range(0.75, 1.25)

	soldier_flash = maxf(0.0, soldier_flash - dt * 5.0)
	soldier_swing = maxf(0.0, soldier_swing - dt * 2.15)
	if soldier_dead:
		soldier_respawn_t -= dt
		if soldier_respawn_t <= 0.0:
			reset_run()
			return
	else:
		soldier_cd = maxf(0.0, soldier_cd - dt)
		var best_idx := -1
		var best_d2 := 999999.0
		for i in range(mons.size()):
			var m := mons[i]
			var mx := float(m["x"])
			var mz := float(m["z"])
			var d2 := mx * mx + mz * mz
			if d2 < best_d2:
				best_d2 = d2
				best_idx = i

		if best_idx >= 0:
			var tm := mons[best_idx]
			var tgt_yaw := atan2(float(tm["x"]), float(tm["z"]))
			var diff := wrapf(tgt_yaw - soldier_yaw, -PI, PI)
			soldier_yaw += clampf(diff, -dt * 12.0, dt * 12.0)

			if best_d2 <= soldier_range * soldier_range and soldier_cd <= 0.0 and not soldier_hit_pending:
				soldier_cd = soldier_atk_period
				soldier_swing = 1.0
				soldier_hit_pending = true
		else:
			soldier_hp = minf(soldier_max_hp, soldier_hp + dt * 8.0)

		if soldier_hit_pending and (1.0 - soldier_swing) >= SWING_IMPACT_U:
			soldier_hit_pending = false
			_resolve_soldier_strike()

	# Build O(N) spatial hash grid for fast crowd separation
	_grid.clear()
	var n_mons := mons.size()
	var inv_cell := 1.0 / GRID_CELL
	for i in range(n_mons):
		var m := mons[i]
		var gx := int(floorf(float(m["x"]) * inv_cell))
		var gz := int(floorf(float(m["z"]) * inv_cell))
		var key := (gx + 4096) * 8192 + (gz + 4096)
		if _grid.has(key):
			(_grid[key] as Array).append(i)
		else:
			_grid[key] = [i]

	# Update monsters walking inward toward center soldier
	for i in range(n_mons):
		var m := mons[i]
		var def: Dictionary = m["def"]
		m["flash"] = maxf(0.0, float(m["flash"]) - dt * 5.0)
		m["swing"] = maxf(0.0, float(m["swing"]) - dt * 1.95)
		m["cd"] = maxf(0.0, float(m["cd"]) - dt)
		var mx := float(m["x"])
		var mz := float(m["z"])
		var dist := sqrt(mx * mx + mz * mz)
		var reach := float(def["reach"])
		if dist > reach:
			m["hit_pending"] = false
			var step_d := minf(dist - reach * 0.9, float(def["spd"]) * dt)
			mx -= (mx / dist) * step_d
			mz -= (mz / dist) * step_d
			var gx := int(floorf(mx * inv_cell))
			var gz := int(floorf(mz * inv_cell))
			var sep_x := 0.0
			var sep_z := 0.0
			var checks := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var k := (gx + dx + 4096) * 8192 + (gz + dz + 4096)
					if not _grid.has(k):
						continue
					var bucket: Array = _grid[k]
					for bi in range(bucket.size()):
						var j: int = bucket[bi]
						if j == i:
							continue
						var o := mons[j]
						var ox := mx - float(o["x"])
						var oz := mz - float(o["z"])
						var od2 := ox * ox + oz * oz
						if od2 > 0.0001 and od2 < 0.72:
							var od := sqrt(od2)
							var push := (0.85 - od) * 1.45
							sep_x += (ox / od) * push
							sep_z += (oz / od) * push
						checks += 1
						if checks >= 10:
							break
					if checks >= 10:
						break
			mx += sep_x * dt
			mz += sep_z * dt
			m["x"] = mx
			m["z"] = mz
			m["y"] = height_at(mx, mz)
			m["yaw"] = atan2(-mx, -mz)
			m["phase"] = float(m["phase"]) + dt * float(def["spd"]) * 3.8
			m["mv"] = 1.0
		else:
			m["mv"] = 0.0
			m["yaw"] = atan2(-mx, -mz)
			if not soldier_dead:
				if float(m["cd"]) <= 0.0 and not bool(m["hit_pending"]):
					m["cd"] = float(def["cd"])
					m["swing"] = 1.0
					m["hit_pending"] = true
				if bool(m["hit_pending"]) and (1.0 - float(m["swing"])) >= SWING_IMPACT_U:
					m["hit_pending"] = false
					soldier_hp = maxf(0.0, soldier_hp - float(def["dmg"]))
					soldier_flash = 0.50
					_sfx.play("clash", 0.30)
					_fx.spawn_sparks(soldier_pos + Vector3(0.0, 0.9, 0.0), 3, Color(2.0, 0.65, 0.45), 3.0)
					if soldier_hp <= 0.0:
						soldier_dead = true
						soldier_respawn_t = 2.6
						_fx.spawn_shatter(soldier_pos, 1.2, Color(0.55, 0.68, 0.92), Vector3(0.0, 2.5, 0.0))
						_sfx.play("kill", 0.65)
						shake_mag = 0.55

	var t1 := Time.get_ticks_usec()
	perf_sim_ms = float(t1 - t0) * 0.001

	for k in _batches.keys():
		_batches[k]["cnt"] = 0
	if not soldier_dead:
		_push_unit("soldier", soldier_pos.x, soldier_pos.y, soldier_pos.z, soldier_yaw, 1.18, 0.0, soldier_swing, soldier_flash, 0.0)
	for i in range(mons.size()):
		var m := mons[i]
		_push_unit(String(m["id"]), float(m["x"]), float(m["y"]), float(m["z"]), float(m["yaw"]),
			float(m["def"]["scale"]), float(m["phase"]), float(m["swing"]), float(m["flash"]), float(m["mv"]))

	for k in _batches.keys():
		var b: Dictionary = _batches[k]
		var mm: MultiMesh = b["mm"]
		var cnt: int = b["cnt"]
		mm.visible_instance_count = cnt
		if cnt > 0:
			mm.buffer = b["buf"]

	_fx.step(dt, height_at)
	perf_batch_ms = float(Time.get_ticks_usec() - t1) * 0.001
