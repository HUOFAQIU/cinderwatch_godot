class_name CWTowers
extends Node3D

# 4 tower kinds x 3 levels: piece-by-piece scaffolding build animation,
# zero-GC SoA projectile pools (arrows, mortar shells, stuck arrows),
# chain lightning, and guard footmen.

signal tower_built(t: Dictionary)
signal tower_upgraded(t: Dictionary)
signal tower_sold(t: Dictionary)

const TOWER_SCENE := preload("res://scenes/tower_node.tscn")
const TOWER_KINDS := ["archer", "bombard", "spire", "guard"]
const MAX_PROJ := 600
const MAX_ARROWS := 320
const MAX_SHELLS := 64
const MAX_STUCK := 256

static var DEFS: Dictionary = {}
static var _scene_cache: Dictionary = {}


static func _static_init() -> void:
	for knd in TOWER_KINDS:
		var res := load("res://assets/data/towers/%s.tres" % knd) as CWTowerData
		if res != null:
			DEFS[knd] = res.to_dict()


var gfx: CWGfx
var fx: CWFx
var audio: CWAudio
var rig: CWRig
var terrain: CWTerrain

var towers: Array[Dictionary] = []
var footmen: Array[CWFootmanUnit] = []

var proj_mmi: MultiMeshInstance3D
var proj_mm: MultiMesh
var proj_buf: PackedFloat32Array = PackedFloat32Array()
var land_sfx_last: float = -1.0

# Zero-GC SoA projectile pools + O(1) swap-remove
var _a_cnt: int = 0
var _a_p0: PackedVector3Array = PackedVector3Array()
var _a_p1: PackedVector3Array = PackedVector3Array()
var _a_pos: PackedVector3Array = PackedVector3Array()
var _a_vel: PackedVector3Array = PackedVector3Array()
var _a_t: PackedFloat32Array = PackedFloat32Array()
var _a_dur: PackedFloat32Array = PackedFloat32Array()
var _a_dmg: PackedFloat32Array = PackedFloat32Array()
var _a_arc: PackedFloat32Array = PackedFloat32Array()
var _a_target: Array[CWMonsterUnit] = []
var _a_tower: Array = []

var _s_cnt: int = 0
var _s_p0: PackedVector3Array = PackedVector3Array()
var _s_p1: PackedVector3Array = PackedVector3Array()
var _s_t: PackedFloat32Array = PackedFloat32Array()
var _s_dur: PackedFloat32Array = PackedFloat32Array()
var _s_dmg: PackedFloat32Array = PackedFloat32Array()
var _s_splash: PackedFloat32Array = PackedFloat32Array()
var _s_arc: PackedFloat32Array = PackedFloat32Array()
var _s_tower: Array = []

var _k_cnt: int = 0
var _k_pos: PackedVector3Array = PackedVector3Array()
var _k_dir: PackedVector3Array = PackedVector3Array()
var _k_life: PackedFloat32Array = PackedFloat32Array()


func init_towers(p_gfx: CWGfx, p_fx: CWFx, p_audio: CWAudio, p_rig: CWRig, p_terrain: CWTerrain) -> void:
	gfx = p_gfx
	fx = p_fx
	audio = p_audio
	rig = p_rig
	terrain = p_terrain

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	proj_mm = MultiMesh.new()
	proj_mm.transform_format = MultiMesh.TRANSFORM_3D
	proj_mm.use_colors = true
	proj_mm.mesh = box
	proj_buf.resize(MAX_PROJ * 16)
	proj_mm.instance_count = MAX_PROJ
	proj_mm.visible_instance_count = 0
	proj_mmi = MultiMeshInstance3D.new()
	proj_mmi.multimesh = proj_mm
	proj_mmi.material_override = mat
	proj_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(proj_mmi)

	_a_p0.resize(MAX_ARROWS); _a_p1.resize(MAX_ARROWS); _a_pos.resize(MAX_ARROWS); _a_vel.resize(MAX_ARROWS)
	_a_t.resize(MAX_ARROWS); _a_dur.resize(MAX_ARROWS); _a_dmg.resize(MAX_ARROWS); _a_arc.resize(MAX_ARROWS)
	_a_target.resize(MAX_ARROWS); _a_tower.resize(MAX_ARROWS)

	_s_p0.resize(MAX_SHELLS); _s_p1.resize(MAX_SHELLS)
	_s_t.resize(MAX_SHELLS); _s_dur.resize(MAX_SHELLS); _s_dmg.resize(MAX_SHELLS); _s_splash.resize(MAX_SHELLS); _s_arc.resize(MAX_SHELLS)
	_s_tower.resize(MAX_SHELLS)

	_k_pos.resize(MAX_STUCK); _k_dir.resize(MAX_STUCK); _k_life.resize(MAX_STUCK)


func build_tower(pad: Dictionary, kind: String, _pal: Dictionary) -> Dictionary:
	var def: Dictionary = DEFS[kind]
	var node := TOWER_SCENE.instantiate() as CWTowerNode
	node.tower_kind = kind
	node.tower_level = 0
	var ch := terrain.get_chunk_node(float(pad["x"]), float(pad["z"]))
	node.position = Vector3(pad["x"], pad["y"], pad["z"]) - ch.position
	node.rotation.y = float(pad["rot"])
	ch.add_child(node)
	if node.pick_body != null:
		node.pick_body.set_meta("pad", pad)

	var t := {
		"pad": pad,
		"kind": kind,
		"def": def,
		"lvl": 0,
		"spent": int(def["cost"][0]),
		"kills": 0,
		"x": float(pad["x"]),
		"y": float(pad["y"]),
		"z": float(pad["z"]),
		"node": node,
		"visuals": node.visuals,
		"pieces": [],
		"scaffold": null,
		"crystal": null,
		"shards": [],
		"turret": null,
		"recoil": 0.0,
		"charge": 0.0,
		"spin": 0.0,
		"flame_local": Vector3(0, 2.8, 0),
		"flame_desc": {},
		"state": "build",
		"build_t": 0.0,
		"cd": 0.35,
		"stun": 0.0,
		"recent": 0.0,
		"emitter": fx.add_emitter(Vector3(pad["x"], float(pad["y"]) + 3.0, pad["z"]), def["col"], float(def["light"][0]), 15.0),
		"men": [],
		"rally": _find_rally_point(float(pad["x"]), float(pad["z"])),
	}
	pad["tower"] = t
	towers.append(t)
	_load_tower_visuals(t)
	audio.play_sfx("build", 0.9)
	tower_built.emit(t)
	return t


func upgrade_tower(t: Dictionary, _pal: Dictionary) -> bool:
	if int(t["lvl"]) >= 2 or String(t["state"]) != "active":
		return false
	t["lvl"] = int(t["lvl"]) + 1
	if t["node"] is CWTowerNode:
		(t["node"] as CWTowerNode).tower_level = int(t["lvl"])
	var def: Dictionary = t["def"]
	t["spent"] = int(t["spent"]) + int(def["cost"][int(t["lvl"])])
	t["state"] = "build"
	t["build_t"] = 0.0
	t["emitter"]["energy"] = float(def["light"][int(t["lvl"])])
	_load_tower_visuals(t)
	audio.play_sfx("upgrade", 0.95)
	tower_upgraded.emit(t)
	return true


func sell_tower(t: Dictionary) -> int:
	var refund := int(roundf(float(t["spent"]) * 0.7))
	fx.remove_emitter(t["emitter"])
	for m in t["men"]:
		footmen.erase(m)
	t["men"].clear()
	(t["node"] as Node3D).queue_free()
	t["pad"]["tower"] = null
	towers.erase(t)
	audio.play_sfx("sell", 0.85)
	tower_sold.emit(t)
	return refund


func _find_rally_point(tx: float, tz: float) -> Vector3:
	if terrain.road_path != null and terrain.road_path.curve != null and terrain.road_path.curve.point_count > 1:
		var cp: Vector3 = terrain.road_path.curve.get_closest_point(Vector3(tx, terrain.height_at(tx, tz), tz))
		return Vector3(cp.x, terrain.height_at(cp.x, cp.z), cp.z)
	var road: Array[Vector2] = terrain.layout["road"]
	var best_d := 1e9
	var best := Vector2(tx, tz)
	for pt in road:
		var d := Vector2(tx, tz).distance_to(pt)
		if d < best_d:
			best_d = d
			best = pt
	return Vector3(best.x, terrain.height_at(best.x, best.y), best.y)


func _apply_world_mat(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = gfx.mat_world
	for c in n.get_children():
		_apply_world_mat(c)


func _load_tower_visuals(t: Dictionary) -> void:
	var node: Node3D = t["visuals"]
	for ch in node.get_children():
		ch.queue_free()
	t["pieces"].clear()
	t["crystal"] = null
	t["shards"].clear()
	t["turret"] = null
	t["scaffold"] = null

	var key := "%s_%d" % [String(t["kind"]), int(t["lvl"])]
	var ps: PackedScene = _scene_cache.get(key, null)
	if ps == null:
		var path := "res://assets/models/towers/%s.tscn" % key
		ps = load(path) as PackedScene
		if ps == null:
			push_error("Missing tower scene: " + path)
			return
		_scene_cache[key] = ps
	var inst := ps.instantiate() as Node3D
	_apply_world_mat(inst)
	node.add_child(inst)

	for ch in inst.get_children():
		var role := String(ch.get_meta("role", ""))
		if role == "piece" and ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
			t["pieces"].append({"mi": ch, "delay": float(ch.get_meta("delay", 0.0)), "landed": false})
		elif role == "scaffold" and ch is MeshInstance3D:
			t["scaffold"] = ch
		elif role == "turret" and ch is Node3D:
			t["turret"] = ch
		elif role == "crystal" and ch is MeshInstance3D:
			t["crystal"] = ch
			t["crystal_base_y"] = float(ch.get_meta("base_y", 3.2))
		elif role == "shard" and ch is MeshInstance3D:
			t["shards"].append(ch)

	t["flame_local"] = inst.get_meta("flame_local", Vector3(0, 2.8, 0))
	t["top_y"] = float(inst.get_meta("top_y", 2.8))
	if inst.has_meta("door_local"):
		t["door_local"] = inst.get_meta("door_local")

	var fl_world: Vector3 = Vector3(t["x"], t["y"], t["z"]) + Basis(Vector3.UP, (t["node"] as Node3D).rotation.y) * Vector3(t["flame_local"])
	t["emitter"]["pos"] = fl_world + Vector3(0, 0.35, 0)
	t["flame_world"] = fl_world
	var knd := String(t["kind"])
	var lvl := int(t["lvl"])
	t["flame_desc"] = {
		"pos": fl_world,
		"w": 0.72 if knd == "archer" else (0.34 if knd == "bombard" else (0.38 if lvl == 0 else 0.56)),
		"h": 1.08 if knd == "archer" else (0.52 if knd == "bombard" else (0.62 if lvl == 0 else 0.86)),
		"seed": float(t["pad"]["idx"]) * 3.7 + 1.1,
		"intensity": 1.22 if knd == "archer" else 1.12,
	}


# --- Per-frame tower, projectile & footman simulation ---
func update_towers(dt: float, monsters_sys: CWMonsters, dmg_mul: float) -> void:
	var now_s := float(Time.get_ticks_msec()) * 0.001
	for t in towers:
		t["recent"] = maxf(0.0, float(t["recent"]) - dt * 6.0)
		if t["turret"] != null:
			var rk := maxf(0.0, float(t["recoil"]) - dt * 1.6)
			t["recoil"] = rk
			(t["turret"] as Node3D).scale = Vector3(1.0 + rk * 0.12, 1.0, 1.0 - rk * 0.18)

		if String(t["state"]) == "build":
			_update_build_anim(t, dt, now_s)
			continue

		var knd := String(t["kind"])
		var lvl := int(t["lvl"])
		var def: Dictionary = t["def"]
		if knd != "spire":
			fx.dynamic_flames.append(t["flame_desc"])
			if randf() < dt * 8.0:
				fx.spawn_flame_puff(t["flame_world"], 0.24)

		var base_e := float(def["light"][lvl])
		if float(t["stun"]) > 0.0:
			t["stun"] = maxf(0.0, float(t["stun"]) - dt)
			t["emitter"]["energy"] = base_e * 0.12
			if randf() < dt * 5.0:
				fx.spawn_sparks(Vector3(float(t["x"]) + randf_range(-0.6, 0.6), float(t["y"]) + randf_range(0.6, 2.6), float(t["z"]) + randf_range(-0.6, 0.6)), 2, 2.0, Color(0.55, 0.9, 1.8))
			continue

		if knd != "spire":
			t["emitter"]["energy"] = base_e
		if knd != "guard":
			t["cd"] = float(t["cd"]) - dt

		match knd:
			"archer": _update_archer(t, def, lvl, dt, now_s, monsters_sys, dmg_mul)
			"bombard": _update_bombard(t, def, lvl, dt, now_s, monsters_sys, dmg_mul)
			"spire": _update_spire(t, def, lvl, base_e, dt, now_s, monsters_sys, dmg_mul)
			"guard": _update_guard(t, def, lvl, dt)

	_update_projectiles(dt, monsters_sys)
	_update_footmen(dt, monsters_sys)


func _update_build_anim(t: Dictionary, dt: float, now_s: float) -> void:
	var bt := float(t["build_t"]) + dt
	t["build_t"] = bt
	const T_END := 1.02
	if t["scaffold"] != null:
		var sc_mi: MeshInstance3D = t["scaffold"]
		if bt < T_END - 0.25:
			var ku := clampf(bt / 0.3, 0.0, 1.0) - 1.0
			sc_mi.scale.y = maxf(0.01, 1.0 + 2.70158 * ku * ku * ku + 1.70158 * ku * ku)
		else:
			sc_mi.scale.y = maxf(0.01, 1.0 - (bt - (T_END - 0.25)) / 0.25)
	for p in t["pieces"]:
		var u := (bt - float(p["delay"])) / 0.24
		var mi: MeshInstance3D = p["mi"]
		if u <= 0.0:
			mi.visible = false
			continue
		mi.visible = true
		if u < 1.0:
			mi.position.y = (1.0 - u * u) * 2.2
			mi.scale = Vector3.ONE
		else:
			mi.position.y = 0.0
			var sq := clampf((u - 1.0) / 0.5, 0.0, 1.0)
			mi.scale = Vector3(1.0, 1.0 - 0.1 * sin(sq * PI) * (1.0 - sq), 1.0)
			if not bool(p["landed"]):
				p["landed"] = true
				fx.spawn_dust(Vector3(float(t["x"]) + randf_range(-0.5, 0.5), float(t["y"]) + 0.1, float(t["z"]) + randf_range(-0.5, 0.5)), 4, 1.2, 0.8, 0.5)
				if now_s - land_sfx_last > 0.06:
					land_sfx_last = now_s
					audio.play_sfx("build", 0.55)
	if bt >= T_END:
		t["state"] = "active"
		if t["scaffold"] != null:
			(t["scaffold"] as MeshInstance3D).queue_free()
			t["scaffold"] = null
		fx.spawn_dust(Vector3(t["x"], float(t["y"]) + 0.2, t["z"]), 8, 2.0, 1.1, 0.6)
		fx.spawn_sparks(Vector3(t["x"], float(t["y"]) + 1.2, t["z"]), 8, 3.0, Color(1.0, 0.78, 0.35))


func _update_archer(t: Dictionary, def: Dictionary, lvl: int, dt: float, now_s: float, monsters_sys: CWMonsters, dmg_mul: float) -> void:
	var n_arch := int(def["n"][lvl])
	var base_yaw := float((t["node"] as Node3D).rotation.y)
	if not t.has("archers") or (t["archers"] as Array).size() != n_arch:
		var alist: Array[Dictionary] = []
		for a_i in range(n_arch):
			alist.append({
				"cd": float(a_i) * float(def["rate"][lvl]) / float(maxi(1, n_arch)),
				"draw": 0.0,
				"yaw": base_yaw + float(a_i) * 2.1,
			})
		t["archers"] = alist
	var tx := float(t["x"])
	var tz := float(t["z"])
	var a_tgts := monsters_sys.find_targets(tx, tz, float(def["range"][lvl]), true, true, 0.0, 1)
	var deck_y := float(t["y"]) + float(t["top_y"]) - 0.56
	var archers_arr: Array = t["archers"]
	for a_i in range(n_arch):
		var ar: Dictionary = archers_arr[a_i]
		var a_ang := float(a_i) * 2.1 + base_yaw
		var ax := tx + cos(a_ang) * 0.34
		var az := tz + sin(a_ang) * 0.34
		var acd := float(ar["cd"]) - dt
		var ayaw := float(ar["yaw"])
		var adraw := float(ar["draw"])
		if not a_tgts.is_empty():
			var tg: CWMonsterUnit = a_tgts[0]
			ayaw = CWUtil.ang_damp(ayaw, atan2(tg.x - ax, tg.z - az), 12.0, dt)
			adraw = minf(1.0, adraw + dt * 3.6) if acd < 0.34 else maxf(0.0, adraw - dt * 6.0)
			if acd <= 0.0 and adraw > 0.95:
				acd = float(def["rate"][lvl]) * randf_range(0.90, 1.12)
				adraw = 0.0
				t["recent"] = float(t["recent"]) + 4.0
				_shoot_arrow(Vector3(ax + sin(ayaw) * 0.3, deck_y + 0.85, az + cos(ayaw) * 0.3), tg, float(def["dmg"][lvl]) * dmg_mul, t)
				audio.play_sfx("arrow", 0.55, 0.08, tx)
		else:
			adraw = maxf(0.0, adraw - dt * 3.0)
			ayaw = CWUtil.ang_damp(ayaw, base_yaw + sin(now_s * 0.5 + float(a_i) * 2.1) * 0.5, 2.0, dt)
			if acd < 0.3:
				acd = 0.3
		ar["cd"] = acd
		ar["yaw"] = ayaw
		ar["draw"] = adraw
		rig.push_archer_gpu(Vector3(ax, deck_y, az), ayaw, adraw)


func _update_bombard(t: Dictionary, def: Dictionary, lvl: int, dt: float, now_s: float, monsters_sys: CWMonsters, dmg_mul: float) -> void:
	var tx := float(t["x"])
	var tz := float(t["z"])
	var targets := monsters_sys.find_targets(tx, tz, float(def["range"][lvl]), false, true, float(def["min_range"]), 1)
	var base_yaw := float((t["node"] as Node3D).rotation.y)
	var gun_yaw := float(t.get("gun_yaw", base_yaw))
	if not targets.is_empty():
		var m: CWMonsterUnit = targets[0]
		var want := atan2(m.x - tx, m.z - tz)
		gun_yaw = CWUtil.ang_damp(gun_yaw, want, 5.0, dt)
		if absf(CWUtil.ang_diff(gun_yaw, want)) < 0.12 and float(t["cd"]) <= 0.0:
			t["cd"] = float(def["rate"][lvl]) * randf_range(0.95, 1.08)
			t["recent"] = float(t["recent"]) + 12.0
			t["recoil"] = 1.0
			var origin := Vector3(tx, float(t["y"]) + float(t["top_y"]), tz)
			_shoot_shell(origin, Vector3(m.x, m.y, m.z), float(def["dmg"][lvl]) * dmg_mul, float(def["splash"][lvl]), t)
			fx.flash(origin, Color(1.0, 0.65, 0.2), 12.0, 0.18, 15.0)
			fx.spawn_smoke(origin, 6, 2.2, 1.4, 1.8)
			fx.spawn_sparks(origin, 8, 5.0, Color(1.0, 0.68, 0.22))
			fx.add_shake(0.12)
			audio.play_sfx("cannon", 0.85, 0.08, tx)
	else:
		gun_yaw = CWUtil.ang_damp(gun_yaw, base_yaw + sin(now_s * 0.3 + float(t["pad"]["idx"])) * 0.7, 1.2, dt)
	t["gun_yaw"] = gun_yaw
	if t["turret"] != null:
		(t["turret"] as Node3D).rotation.y = gun_yaw - base_yaw
	if float(t["cd"]) > 0.0 and float(t["cd"]) < 1.2 and randf() < dt * 5.0:
		fx.spawn_smoke(Vector3(tx, float(t["y"]) + float(t["top_y"]), tz), 1, 0.4, 0.8, 1.0)


func _update_spire(t: Dictionary, def: Dictionary, lvl: int, base_e: float, dt: float, now_s: float, monsters_sys: CWMonsters, dmg_mul: float) -> void:
	var tx := float(t["x"])
	var tz := float(t["z"])
	var s_tgts := monsters_sys.find_targets(tx, tz, float(def["range"][lvl]), true, true, 0.0, 1)
	var prev_chg := float(t["charge"])
	var chg := minf(1.0, prev_chg + dt / float(def["rate"][lvl])) if not s_tgts.is_empty() else maxf(0.0, prev_chg - dt * 0.25)
	if prev_chg < 0.68 and chg >= 0.68 and not s_tgts.is_empty():
		audio.play_sfx("zap", 0.22)
	t["charge"] = chg
	var pulse := 0.85 + 0.15 * sin(now_s * (6.0 + 20.0 * chg))
	t["emitter"]["energy"] = (base_e + 22.0 * chg * chg) * pulse
	var spin := float(t.get("spin", 0.0)) + dt * (0.8 + 5.0 * chg)
	t["spin"] = spin
	if t["crystal"] != null:
		var cmi: MeshInstance3D = t["crystal"]
		cmi.rotation.y = spin
		cmi.position.y = float(t["crystal_base_y"]) + sin(now_s * 1.6 + float(t["pad"]["idx"])) * 0.06
		var shs: Array = t["shards"]
		var sh_n := maxf(float(shs.size()), 1.0)
		for si in range(shs.size()):
			var sa := spin * 0.7 + float(si) * TAU / sh_n
			var smi: MeshInstance3D = shs[si]
			smi.position = Vector3(cos(sa) * 0.58, sin(sa * 1.3) * 0.14 - 0.05, sin(sa) * 0.58)
			smi.rotation.y = -sa * 2.0
	var origin: Vector3 = t["flame_world"]
	if chg > 0.5 and randf() < dt * 14.0 * chg:
		var ba := randf() * TAU
		fx.spawn_bolt(origin, origin + Vector3(cos(ba) * 0.7, randf_range(-0.5, 0.5), sin(ba) * 0.7), Color(0.45, 0.75, 1.8), 0.10)
	if chg >= 1.0 and not s_tgts.is_empty():
		t["charge"] = 0.0
		t["recent"] = float(t["recent"]) + 8.0
		var tgt0: CWMonsterUnit = s_tgts[0]
		_fire_chain(origin, tgt0, int(def["jumps"][lvl]), float(def["dmg"][lvl]) * dmg_mul, float(def["slow"][lvl]), float(def["slow_t"][lvl]), monsters_sys, t)
		fx.flash(Vector3(tgt0.x, tgt0.y + 1.2, tgt0.z), Color(0.62, 0.82, 1.0), 14.0, 0.22, 16.0)
		fx.flash(origin, Color(0.62, 0.82, 1.0), 10.0, 0.18, 12.0)
		fx.add_shake(0.08)
		audio.play_sfx("zap", 0.75, 0.08, tx)


func _update_guard(t: Dictionary, def: Dictionary, lvl: int, dt: float) -> void:
	if (t["men"] as Array).size() < int(def["n"][lvl]):
		var cd := float(t["cd"]) - dt
		if cd <= 0.0:
			t["cd"] = 0.5 if (t["men"] as Array).is_empty() else float(def["rate"][lvl])
			_spawn_footman(t)
		else:
			t["cd"] = cd


# --- Zero-allocation projectile spawners ---
func _shoot_arrow(origin: Vector3, target: CWMonsterUnit, dmg: float, tower = null) -> void:
	if _a_cnt >= MAX_ARROWS:
		return
	var dest := Vector3(target.x, target.y + float(target.def["hit_h"]), target.z)
	var dist := origin.distance_to(dest)
	var i := _a_cnt
	_a_cnt += 1
	_a_p0[i] = origin
	_a_p1[i] = dest
	_a_pos[i] = origin
	_a_vel[i] = Vector3.FORWARD
	_a_t[i] = 0.0
	_a_dur[i] = clampf(dist / 16.0, 0.18, 0.65)
	_a_dmg[i] = dmg
	_a_arc[i] = clampf(dist * 0.18, 0.6, 2.2)
	_a_target[i] = target
	_a_tower[i] = tower


func _shoot_shell(origin: Vector3, dest: Vector3, dmg: float, splash: float, tower = null) -> void:
	if _s_cnt >= MAX_SHELLS:
		return
	var dist := origin.distance_to(dest)
	var i := _s_cnt
	_s_cnt += 1
	_s_p0[i] = origin
	_s_p1[i] = dest
	_s_t[i] = 0.0
	_s_dur[i] = clampf(dist / 9.5, 0.45, 1.15)
	_s_dmg[i] = dmg
	_s_splash[i] = splash
	_s_arc[i] = clampf(dist * 0.42, 2.2, 4.8)
	_s_tower[i] = tower


func _add_stuck_arrow(pos: Vector3, dir: Vector3) -> void:
	var idx := _k_cnt
	if idx >= MAX_STUCK:
		idx = 0
		var min_l := _k_life[0]
		for k in range(1, MAX_STUCK):
			if _k_life[k] < min_l:
				min_l = _k_life[k]
				idx = k
	else:
		_k_cnt += 1
	_k_pos[idx] = pos
	_k_dir[idx] = dir
	_k_life[idx] = 3.2


func _fire_chain(origin: Vector3, first: CWMonsterUnit, jumps: int, dmg: float, slow_f: float, slow_t: float, monsters_sys: CWMonsters, tower = null) -> void:
	var hit_list: Array[CWMonsterUnit] = [first]
	var prev_pos := origin
	var cur: CWMonsterUnit = first
	var cur_dmg := dmg
	for _j in range(jumps):
		var cpos := Vector3(cur.x, cur.y + float(cur.def["hit_h"]), cur.z)
		fx.spawn_bolt(prev_pos, cpos, Color(0.55, 0.90, 2.2), 0.22)
		monsters_sys.slow_monster(cur, slow_f, slow_t)
		monsters_sys.hit_monster(cur, cur_dmg, "magic", cpos - prev_pos, tower)
		prev_pos = cpos
		cur_dmg *= 0.86
		var nxt := monsters_sys.find_chain_next(cur.x, cur.z, 3.0, hit_list)
		if nxt == null:
			break
		hit_list.append(nxt)
		cur = nxt


func _spawn_footman(t: Dictionary) -> void:
	var lvl: int = t["lvl"]
	var def: Dictionary = t["def"]
	var used_mask := 0
	for fm: CWFootmanUnit in t["men"]:
		used_mask |= (1 << fm.slot)
	var slot := 0
	while (used_mask & (1 << slot)) != 0:
		slot += 1
	var max_n: int = def["n"][lvl]
	var lats: Array = [-0.48, 0.48] if max_n <= 2 else [-0.66, 0.0, 0.66]
	var lat := float(lats[slot % lats.size()])
	var road: Array[Vector2] = terrain.layout.get("road", [])
	var rally: Vector3 = t["rally"]
	var rdir := Vector2(1.0, 0.0)
	if road.size() > 2:
		var best_i := 0
		var best_d := 1e9
		for ri in range(road.size()):
			var d2 := CWUtil.dist2(road[ri].x, road[ri].y, rally.x, rally.z)
			if d2 < best_d:
				best_d = d2
				best_i = ri
		rdir = (road[mini(road.size() - 1, best_i + 1)] - road[maxi(0, best_i - 1)]).normalized()
	var home := Vector3(rally.x - rdir.y * lat, 0.0, rally.z + rdir.x * lat)
	home.y = terrain.height_at(home.x, home.z)
	var door_l: Vector3 = t.get("door_local", Vector3(0.0, 0.0, 1.1))
	var yaw0 := float((t["node"] as Node3D).rotation.y)
	var door_w := Vector3(t["x"], t["y"], t["z"]) + Basis(Vector3.UP, yaw0) * door_l
	var f := CWFootmanUnit.new()
	f.tower = t
	f.slot = slot
	f.torch = (slot == 0)
	f.x = door_w.x
	f.y = terrain.height_at(door_w.x, door_w.z)
	f.z = door_w.z
	f.home = home
	f.guard_yaw = atan2(-rdir.x, -rdir.y)
	f.hp = float(def["hp"][lvl])
	f.max_hp = f.hp
	f.dmg = float(def["dmg"][lvl])
	f.yaw = yaw0
	f.phase = randf_range(0.0, TAU)
	t["men"].append(f)
	footmen.append(f)


func _put_proj(idx: int, basis: Basis, pos: Vector3, r: float, g: float, b: float) -> void:
	var off := idx * 16
	proj_buf[off] = basis.x.x; proj_buf[off + 1] = basis.y.x; proj_buf[off + 2] = basis.z.x; proj_buf[off + 3] = pos.x
	proj_buf[off + 4] = basis.x.y; proj_buf[off + 5] = basis.y.y; proj_buf[off + 6] = basis.z.y; proj_buf[off + 7] = pos.y
	proj_buf[off + 8] = basis.x.z; proj_buf[off + 9] = basis.y.z; proj_buf[off + 10] = basis.z.z; proj_buf[off + 11] = pos.z
	proj_buf[off + 12] = r; proj_buf[off + 13] = g; proj_buf[off + 14] = b; proj_buf[off + 15] = 1.0


func _update_projectiles(dt: float, monsters_sys: CWMonsters) -> void:
	var vis := 0
	# 1. Arrows (O(1) swap-remove)
	var i := 0
	while i < _a_cnt:
		var u := _a_t[i] + dt / _a_dur[i]
		_a_t[i] = u
		var m := _a_target[i]
		if m != null and not m.dead:
			_a_p1[i] = Vector3(m.x, m.y + float(m.def["hit_h"]), m.z)
		var uc := clampf(u, 0.0, 1.0)
		var pos := _a_p0[i].lerp(_a_p1[i], uc)
		pos.y += sin(uc * PI) * _a_arc[i]
		var vel := pos - _a_pos[i]
		_a_vel[i] = vel
		_a_pos[i] = pos
		if uc >= 1.0:
			if m != null and not m.dead:
				monsters_sys.hit_monster(m, _a_dmg[i], "arrow", vel, _a_tower[i])
			else:
				var gy := terrain.height_at(pos.x, pos.z)
				var d_st := vel.normalized()
				if d_st.length_squared() < 0.01:
					d_st = Vector3(0.0, -1.0, 0.2).normalized()
				d_st.y = minf(d_st.y, -0.45)
				_add_stuck_arrow(Vector3(pos.x, gy + 0.14, pos.z), d_st.normalized())
			_a_cnt -= 1
			if i < _a_cnt:
				_a_p0[i] = _a_p0[_a_cnt]; _a_p1[i] = _a_p1[_a_cnt]
				_a_pos[i] = _a_pos[_a_cnt]; _a_vel[i] = _a_vel[_a_cnt]
				_a_t[i] = _a_t[_a_cnt]; _a_dur[i] = _a_dur[_a_cnt]
				_a_dmg[i] = _a_dmg[_a_cnt]; _a_arc[i] = _a_arc[_a_cnt]
				_a_target[i] = _a_target[_a_cnt]; _a_tower[i] = _a_tower[_a_cnt]
			_a_target[_a_cnt] = null
			_a_tower[_a_cnt] = null
		else:
			if vis < MAX_PROJ:
				var dir := vel.normalized()
				if dir.length_squared() < 0.01:
					dir = Vector3.FORWARD
				var up_v := Vector3.FORWARD if absf(dir.y) > 0.98 else Vector3.UP
				_put_proj(vis, Basis.looking_at(dir, up_v).scaled_local(Vector3(0.055, 0.055, 0.58)), pos, 2.0, 0.9, 0.25)
				if randf() < dt * 16.0:
					fx.spawn_flame_puff(pos, 0.12)
				vis += 1
			i += 1

	# 2. Mortar shells (O(1) swap-remove)
	i = 0
	var shell_basis := Basis.IDENTITY.scaled(Vector3.ONE * 0.30)
	while i < _s_cnt:
		var u := _s_t[i] + dt / _s_dur[i]
		_s_t[i] = u
		var uc := clampf(u, 0.0, 1.0)
		var pos := _s_p0[i].lerp(_s_p1[i], uc)
		pos.y += sin(uc * PI) * _s_arc[i]
		if uc >= 1.0:
			fx.spawn_explosion(pos, 1.1)
			audio.play_sfx("explode", 0.9)
			monsters_sys.explode_at(pos.x, pos.z, _s_dmg[i], _s_splash[i], _s_tower[i])
			_s_cnt -= 1
			if i < _s_cnt:
				_s_p0[i] = _s_p0[_s_cnt]; _s_p1[i] = _s_p1[_s_cnt]
				_s_t[i] = _s_t[_s_cnt]; _s_dur[i] = _s_dur[_s_cnt]
				_s_dmg[i] = _s_dmg[_s_cnt]; _s_splash[i] = _s_splash[_s_cnt]; _s_arc[i] = _s_arc[_s_cnt]
				_s_tower[i] = _s_tower[_s_cnt]
			_s_tower[_s_cnt] = null
		else:
			if vis < MAX_PROJ:
				_put_proj(vis, shell_basis, pos, 1.6, 0.55, 0.15)
				vis += 1
			i += 1

	# 3. Stuck ground arrows (O(1) swap-remove)
	i = 0
	while i < _k_cnt:
		var life := _k_life[i] - dt
		if life <= 0.0:
			_k_cnt -= 1
			if i < _k_cnt:
				_k_pos[i] = _k_pos[_k_cnt]
				_k_dir[i] = _k_dir[_k_cnt]
				_k_life[i] = _k_life[_k_cnt]
		else:
			_k_life[i] = life
			if vis < MAX_PROJ:
				var sdir := _k_dir[i]
				var sup := Vector3.FORWARD if absf(sdir.y) > 0.98 else Vector3.UP
				var fade := clampf(life / 0.8, 0.0, 1.0)
				_put_proj(vis, Basis.looking_at(sdir, sup).scaled_local(Vector3(0.048, 0.048, 0.48 * fade)), _k_pos[i], 0.55, 0.42, 0.26)
				vis += 1
			i += 1

	if vis > 0:
		proj_mm.buffer = proj_buf
	proj_mm.visible_instance_count = vis


func _update_footmen(dt: float, monsters_sys: CWMonsters) -> void:
	var i := footmen.size() - 1
	while i >= 0:
		var f: CWFootmanUnit = footmen[i]
		f.flash = maxf(0.0, f.flash - dt * 5.0)
		f.flinch = maxf(0.0, f.flinch - dt * 5.2)
		f.swing = maxf(0.0, f.swing - dt * 1.75)
		f.cd = maxf(0.0, f.cd - dt)
		if f.hp <= 0.0:
			(f.tower["men"] as Array).erase(f)
			var last := footmen.size() - 1
			if i < last:
				footmen[i] = footmen[last]
			footmen.pop_back()
			i -= 1
			continue

		var foe: CWMonsterUnit = f.foe
		if foe != null and (foe.dead or CWUtil.dist2(f.x, f.z, foe.x, foe.z) > 16.0):
			foe.blocker = null
			f.foe = null
			foe = null

		if foe == null:
			foe = monsters_sys.find_duel_target(f.home.x, f.home.z, 3.6)
			if foe != null:
				f.foe = foe
				foe.blocker = f

		var tx := foe.x if foe != null else f.home.x
		var tz := foe.z if foe != null else f.home.z
		var dx := tx - f.x
		var dz := tz - f.z
		var d := sqrt(dx * dx + dz * dz)
		if foe != null and d < 0.72:
			f.yaw = lerp_angle(f.yaw, atan2(dx, dz), 1.0 - exp(-12.0 * dt))
			f.mv = CWUtil.damp(f.mv, 0.0, 10.0, dt)
			if f.cd <= 0.0:
				f.cd = 0.85
				f.swing = 1.0
				monsters_sys.hit_monster(foe, f.dmg, "melee", Vector3(dx, 0, dz), f.tower)
				fx.spawn_sparks(Vector3((f.x + foe.x) * 0.5, f.y + 0.85, (f.z + foe.z) * 0.5), 6, 3.4, Color(1.0, 0.86, 0.48))
				audio.play_sfx("clash" if float(foe.def.get("armor", 0.0)) > 0.0 else "sword", 0.52, 0.10, foe.x)
		elif d > 0.12:
			var step_d := minf(d, 2.2 * dt)
			f.x += (dx / d) * step_d
			f.z += (dz / d) * step_d
			f.y = terrain.height_at(f.x, f.z)
			f.yaw = lerp_angle(f.yaw, atan2(dx, dz), 1.0 - exp(-12.0 * dt))
			f.phase += step_d * 6.2
			f.mv = CWUtil.damp(f.mv, 1.0, 12.0, dt)
		else:
			f.mv = CWUtil.damp(f.mv, 0.0, 10.0, dt)
			f.yaw = lerp_angle(f.yaw, f.guard_yaw, 1.0 - exp(-8.0 * dt))
			f.hp = minf(f.max_hp, f.hp + dt * 4.0)

		rig.push_footman_gpu(f)
		if f.torch:
			var tpos := rig.last_torch_pos
			fx.torch_positions.append(tpos)
			if randf() < dt * 6.0:
				fx.spawn_flame_puff(tpos, 0.16)
		i -= 1


func stun_towers_in_radius(cx: float, cz: float, radius: float, dur: float) -> void:
	var r2 := radius * radius
	for t in towers:
		if CWUtil.dist2(t["x"], t["z"], cx, cz) <= r2:
			t["stun"] = maxf(float(t["stun"]), dur)
			fx.spawn_sparks(Vector3(t["x"], float(t["y"]) + 1.8, t["z"]), 10, 3.0, Color(0.5, 0.85, 1.0))


func clear_all() -> void:
	for t in towers:
		fx.remove_emitter(t["emitter"])
		(t["node"] as Node3D).queue_free()
	towers.clear()
	_a_cnt = 0
	_s_cnt = 0
	_k_cnt = 0
	_a_target.fill(null)
	_a_tower.fill(null)
	_s_tower.fill(null)
	footmen.clear()
	proj_mm.visible_instance_count = 0
