class_name CWTowers
extends Node3D

# 4 tower kinds x 3 levels with detailed medieval/fantasy architecture ported from 60-towers.js
# Piece-by-piece scaffolding build animation, flaming arrows, mortar shells, chain lightning, and guard footmen

signal tower_built(t: Dictionary)
signal tower_upgraded(t: Dictionary)
signal tower_sold(t: Dictionary)

const TOWER_SCENE := preload("res://scenes/tower_node.tscn")
const TOWER_KINDS := ["archer", "bombard", "spire", "guard"]

static var DEFS: Dictionary = {}


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
var arrows: Array[Dictionary] = []
var shells: Array[Dictionary] = []
var stuck_arrows: Array[Dictionary] = []
var footmen: Array[CWFootmanUnit] = []

var proj_mmi: MultiMeshInstance3D
var proj_mm: MultiMesh
const MAX_PROJ := 600
var proj_buf: PackedFloat32Array = PackedFloat32Array()
var land_sfx_last: float = -1.0


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


func build_tower(pad: Dictionary, kind: String, pal: Dictionary) -> Dictionary:
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
		"draw": 0.0,
		"charge": 0.0,
		"spin": 0.0,
		"flame_local": Vector3(0, 2.8, 0),
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


func upgrade_tower(t: Dictionary, pal: Dictionary) -> bool:
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

	var path := "res://assets/models/towers/%s_%d.tscn" % [String(t["kind"]), int(t["lvl"])]
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("Missing tower scene: " + path)
		return
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


func update_towers(dt: float, monsters_sys: CWMonsters, dmg_mul: float) -> void:
	var now_s := float(Time.get_ticks_msec()) * 0.001
	for t in towers:
		t["recent"] = maxf(0.0, float(t["recent"]) - dt * 6.0)
		if t["turret"] != null:
			t["recoil"] = maxf(0.0, float(t["recoil"]) - dt * 1.6)
			var tn: Node3D = t["turret"]
			var rk := float(t["recoil"])
			tn.scale = Vector3(1.0 + rk * 0.12, 1.0, 1.0 - rk * 0.18)

		if String(t["state"]) == "build":
			t["build_t"] = float(t["build_t"]) + dt
			var bt: float = t["build_t"]
			var t_end := 1.02
			if t["scaffold"] != null:
				var sc_mi: MeshInstance3D = t["scaffold"]
				if bt < t_end - 0.25:
					var ku := clampf(bt / 0.3, 0.0, 1.0) - 1.0
					var eob := 1.0 + 2.70158 * ku * ku * ku + 1.70158 * ku * ku
					sc_mi.scale.y = maxf(0.01, eob)
				else:
					sc_mi.scale.y = maxf(0.01, 1.0 - (bt - (t_end - 0.25)) / 0.25)
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
			if bt >= t_end:
				t["state"] = "active"
				if t["scaffold"] != null:
					(t["scaffold"] as MeshInstance3D).queue_free()
					t["scaffold"] = null
				fx.spawn_dust(Vector3(t["x"], float(t["y"]) + 0.2, t["z"]), 8, 2.0, 1.1, 0.6)
				fx.spawn_sparks(Vector3(t["x"], float(t["y"]) + 1.2, t["z"]), 8, 3.0, Color(1.0, 0.78, 0.35))
			continue

		# Living animated billboard flames & rising ember puffs from every active brazier/torch
		var t_kind := String(t["kind"])
		var t_lvl := int(t["lvl"])
		if t_kind != "spire":
			var fpos := Vector3(t["flame_world"])
			var fw := 0.72 if t_kind == "archer" else (0.34 if t_kind == "bombard" else (0.38 if t_lvl == 0 else 0.56))
			var fh := 1.08 if t_kind == "archer" else (0.52 if t_kind == "bombard" else (0.62 if t_lvl == 0 else 0.86))
			fx.dynamic_flames.append({
				"pos": fpos,
				"w": fw,
				"h": fh,
				"seed": float(t["pad"]["idx"]) * 3.7 + 1.1,
				"intensity": 1.22 if t_kind == "archer" else 1.12,
			})
			if randf() < dt * 8.0:
				fx.spawn_flame_puff(fpos, 0.24)

		var base_e: float = float(t["def"]["light"][int(t["lvl"])])
		if float(t["stun"]) > 0.0:
			t["stun"] = maxf(0.0, float(t["stun"]) - dt)
			t["emitter"]["energy"] = base_e * 0.12
			if randf() < dt * 5.0:
				fx.spawn_sparks(Vector3(float(t["x"]) + randf_range(-0.6, 0.6), float(t["y"]) + randf_range(0.6, 2.6), float(t["z"]) + randf_range(-0.6, 0.6)), 2, 2.0, Color(0.55, 0.9, 1.8))
			continue
		if String(t["kind"]) != "spire":
			t["emitter"]["energy"] = base_e

		var lvl: int = t["lvl"]
		var def: Dictionary = t["def"]
		if String(t["kind"]) != "guard":
			t["cd"] = float(t["cd"]) - dt
		match String(t["kind"]):
			"archer":
				var n_arch := int(def["n"][lvl])
				var base_yaw := float(t["node"].rotation.y)
				if not t.has("archers") or (t["archers"] as Array).size() != n_arch:
					var alist: Array[Dictionary] = []
					for a_i in range(n_arch):
						alist.append({
							"cd": float(a_i) * float(def["rate"][lvl]) / float(maxi(1, n_arch)),
							"draw": 0.0,
							"yaw": base_yaw + float(a_i) * 2.1,
						})
					t["archers"] = alist
				var a_tgts: Array[CWMonsterUnit] = monsters_sys.find_targets(float(t["x"]), float(t["z"]), float(def["range"][lvl]), true, true, 0.0, 1)
				var deck_y := float(t["y"]) + float(t["top_y"]) - 0.56
				var archers_arr: Array = t["archers"]
				for a_i in range(n_arch):
					var ar: Dictionary = archers_arr[a_i]
					var a_ang := float(a_i) * 2.1 + base_yaw
					var ax := float(t["x"]) + cos(a_ang) * 0.34
					var az := float(t["z"]) + sin(a_ang) * 0.34
					ar["cd"] = float(ar["cd"]) - dt
					var ayaw := float(ar["yaw"])
					var adraw := float(ar["draw"])
					if not a_tgts.is_empty():
						var tg: CWMonsterUnit = a_tgts[0]
						var want_a := atan2(tg.x - ax, tg.z - az)
						ayaw = CWUtil.ang_damp(ayaw, want_a, 12.0, dt)
						adraw = minf(1.0, adraw + dt * 3.6) if float(ar["cd"]) < 0.34 else maxf(0.0, adraw - dt * 6.0)
						if float(ar["cd"]) <= 0.0 and adraw > 0.95:
							ar["cd"] = float(def["rate"][lvl]) * randf_range(0.90, 1.12)
							adraw = 0.0
							t["recent"] = float(t["recent"]) + 4.0
							var origin := Vector3(ax + sin(ayaw) * 0.3, deck_y + 0.85, az + cos(ayaw) * 0.3)
							_shoot_arrow(origin, tg, float(def["dmg"][lvl]) * dmg_mul, t)
							audio.play_sfx("arrow", 0.55, 0.08, float(t["x"]))
					else:
						adraw = maxf(0.0, adraw - dt * 3.0)
						ayaw = CWUtil.ang_damp(ayaw, base_yaw + sin(now_s * 0.5 + float(a_i) * 2.1) * 0.5, 2.0, dt)
						if float(ar["cd"]) < 0.3:
							ar["cd"] = 0.3
					ar["yaw"] = ayaw
					ar["draw"] = adraw
					rig.push_archer_gpu(Vector3(ax, deck_y, az), ayaw, adraw)
			"bombard":
				var targets := monsters_sys.find_targets(float(t["x"]), float(t["z"]), float(def["range"][lvl]), false, true, float(def["min_range"]), 1)
				var base_yaw := float(t["node"].rotation.y)
				var gun_yaw := float(t.get("gun_yaw", base_yaw))
				var aligned := false
				if not targets.is_empty():
					var m: CWMonsterUnit = targets[0]
					var want := atan2(m.x - float(t["x"]), m.z - float(t["z"]))
					gun_yaw = CWUtil.ang_damp(gun_yaw, want, 5.0, dt)
					aligned = absf(CWUtil.ang_diff(gun_yaw, want)) < 0.12
					if aligned and float(t["cd"]) <= 0.0:
						t["cd"] = float(def["rate"][lvl]) * randf_range(0.95, 1.08)
						t["recent"] = float(t["recent"]) + 12.0
						t["recoil"] = 1.0
						var origin := Vector3(t["x"], float(t["y"]) + float(t["top_y"]), t["z"])
						_shoot_shell(origin, Vector3(m.x, m.y, m.z), float(def["dmg"][lvl]) * dmg_mul, float(def["splash"][lvl]), t)
						fx.flash(origin, Color(1.0, 0.65, 0.2), 12.0, 0.18, 15.0)
						fx.spawn_smoke(origin, 6, 2.2, 1.4, 1.8)
						fx.spawn_sparks(origin, 8, 5.0, Color(1.0, 0.68, 0.22))
						fx.add_shake(0.12)
						audio.play_sfx("cannon", 0.85, 0.08, float(t["x"]))
				else:
					var idle_yaw := base_yaw + sin(now_s * 0.3 + float(t["pad"]["idx"])) * 0.7
					gun_yaw = CWUtil.ang_damp(gun_yaw, idle_yaw, 1.2, dt)
				t["gun_yaw"] = gun_yaw
				if t["turret"] != null:
					(t["turret"] as Node3D).rotation.y = gun_yaw - base_yaw
				if float(t["cd"]) > 0.0 and float(t["cd"]) < 1.2 and randf() < dt * 5.0:
					fx.spawn_smoke(Vector3(t["x"], float(t["y"]) + float(t["top_y"]), t["z"]), 1, 0.4, 0.8, 1.0)
			"spire":
				var s_tgts := monsters_sys.find_targets(float(t["x"]), float(t["z"]), float(def["range"][lvl]), true, true, 0.0, 1)
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
					for si in range(shs.size()):
						var sa := spin * 0.7 + float(si) * TAU / maxf(float(shs.size()), 1.0)
						var smi: MeshInstance3D = shs[si]
						smi.position = Vector3(cos(sa) * 0.58, sin(sa * 1.3) * 0.14 - 0.05, sin(sa) * 0.58)
						smi.rotation.y = -sa * 2.0
				var origin := Vector3(t["flame_world"])
				if chg > 0.5 and randf() < dt * 14.0 * chg:
					var ba := randf() * TAU
					fx.spawn_bolt(origin, origin + Vector3(cos(ba) * 0.7, randf_range(-0.5, 0.5), sin(ba) * 0.7), Color(0.45, 0.75, 1.8), 0.10)
				if chg >= 1.0 and not s_tgts.is_empty():
					t["charge"] = 0.0
					t["recent"] = float(t["recent"]) + 8.0
					var tgt0: CWMonsterUnit = s_tgts[0]
					_fire_chain(origin, tgt0, int(def["jumps"][lvl]), float(def["dmg"][lvl]) * dmg_mul, float(def["slow"][lvl]), float(def["slow_t"][lvl]), monsters_sys, t)
					fx.flash(Vector3(tgt0["x"], float(tgt0["y"]) + 1.2, tgt0["z"]), Color(0.62, 0.82, 1.0), 14.0, 0.22, 16.0)
					fx.flash(origin, Color(0.62, 0.82, 1.0), 10.0, 0.18, 12.0)
					fx.add_shake(0.08)
					audio.play_sfx("zap", 0.75, 0.08, float(t["x"]))
			"guard":
				var max_men: int = def["n"][lvl]
				if t["men"].size() < max_men:
					t["cd"] = float(t["cd"]) - dt
					if float(t["cd"]) <= 0.0:
						t["cd"] = 0.5 if t["men"].is_empty() else float(def["rate"][lvl])
						_spawn_footman(t)

	_update_projectiles(dt, monsters_sys)
	_update_footmen(dt, monsters_sys)


func _shoot_arrow(origin: Vector3, target: CWMonsterUnit, dmg: float, tower = null) -> void:
	var dest := Vector3(target.x, target.y + float(target.def["hit_h"]), target.z)
	var dist := origin.distance_to(dest)
	var dur := clampf(dist / 16.0, 0.18, 0.65)
	arrows.append({
		"p0": origin,
		"target": target,
		"p1": dest,
		"t": 0.0,
		"dur": dur,
		"dmg": dmg,
		"tower": tower,
		"arc": clampf(dist * 0.18, 0.6, 2.2),
		"pos": origin,
		"vel": Vector3.FORWARD,
	})


func _shoot_shell(origin: Vector3, dest: Vector3, dmg: float, splash: float, tower = null) -> void:
	var dist := origin.distance_to(dest)
	var dur := clampf(dist / 9.5, 0.45, 1.15)
	shells.append({
		"p0": origin,
		"p1": dest,
		"t": 0.0,
		"dur": dur,
		"dmg": dmg,
		"splash": splash,
		"tower": tower,
		"arc": clampf(dist * 0.42, 2.2, 4.8),
		"pos": origin,
	})


func _fire_chain(origin: Vector3, first: CWMonsterUnit, jumps: int, dmg: float, slow_f: float, slow_t: float, monsters_sys: CWMonsters, tower = null) -> void:
	var hit_list: Array[CWMonsterUnit] = [first]
	var prev_pos := origin
	var cur: CWMonsterUnit = first
	var cur_dmg := dmg
	for _j in range(jumps):
		var cpos := Vector3(cur.x, float(cur.y) + float(cur.def["hit_h"]), cur.z)
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
	var used: Array[int] = []
	for fm: CWFootmanUnit in t["men"]:
		used.append(fm.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	var max_n: int = def["n"][lvl]
	var lats: Array = [-0.48, 0.48] if max_n <= 2 else [-0.66, 0.0, 0.66]
	var lat: float = float(lats[slot % lats.size()])
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
		var ia := maxi(0, best_i - 1)
		var ib := mini(road.size() - 1, best_i + 1)
		rdir = (road[ib] - road[ia]).normalized()
	var home := Vector3(rally.x - rdir.y * lat, 0.0, rally.z + rdir.x * lat)
	home.y = terrain.height_at(home.x, home.z)
	var door_l: Vector3 = t.get("door_local", Vector3(0.0, 0.0, 1.1))
	var door_w: Vector3 = Vector3(t["x"], t["y"], t["z"]) + Basis(Vector3.UP, float(t["node"].rotation.y)) * door_l
	var guard_yaw := atan2(-rdir.x, -rdir.y)
	var f := CWFootmanUnit.new()
	f.tower = t
	f.slot = slot
	f.torch = (slot == 0)
	f.x = door_w.x
	f.y = terrain.height_at(door_w.x, door_w.z)
	f.z = door_w.z
	f.home = home
	f.guard_yaw = guard_yaw
	f.hp = float(def["hp"][lvl])
	f.max_hp = f.hp
	f.dmg = float(def["dmg"][lvl])
	f.yaw = float(t["node"].rotation.y)
	f.phase = randf_range(0.0, TAU)
	t["men"].append(f)
	footmen.append(f)


func _put_proj(idx: int, basis: Basis, pos: Vector3, col: Color) -> void:
	var off := idx * 16
	proj_buf[off] = basis.x.x; proj_buf[off + 1] = basis.y.x; proj_buf[off + 2] = basis.z.x; proj_buf[off + 3] = pos.x
	proj_buf[off + 4] = basis.x.y; proj_buf[off + 5] = basis.y.y; proj_buf[off + 6] = basis.z.y; proj_buf[off + 7] = pos.y
	proj_buf[off + 8] = basis.x.z; proj_buf[off + 9] = basis.y.z; proj_buf[off + 10] = basis.z.z; proj_buf[off + 11] = pos.z
	proj_buf[off + 12] = col.r; proj_buf[off + 13] = col.g; proj_buf[off + 14] = col.b; proj_buf[off + 15] = col.a


func _update_projectiles(dt: float, monsters_sys: CWMonsters) -> void:
	var vis := 0
	var i := arrows.size() - 1
	while i >= 0:
		var a := arrows[i]
		a["t"] = float(a["t"]) + dt / float(a["dur"])
		var m: CWMonsterUnit = a["target"]
		if m != null and not m.dead:
			a["p1"] = Vector3(m.x, m.y + float(m.def["hit_h"]), m.z)
		var u := clampf(float(a["t"]), 0.0, 1.0)
		var pos: Vector3 = Vector3(a["p0"]).lerp(a["p1"], u)
		pos.y += sin(u * PI) * float(a["arc"])
		var prev: Vector3 = a["pos"]
		a["vel"] = (pos - prev)
		a["pos"] = pos
		if u >= 1.0:
			if m != null and not m.dead:
				monsters_sys.hit_monster(m, float(a["dmg"]), "arrow", a["vel"], a.get("tower", null))
			else:
				# Upstream 60-towers.js:382: missed arrows stick in the ground for 3.2s
				var gy := terrain.height_at(pos.x, pos.z)
				var d_st := (a["vel"] as Vector3).normalized()
				if d_st.length_squared() < 0.01:
					d_st = Vector3(0.0, -1.0, 0.2).normalized()
				d_st.y = minf(d_st.y, -0.45)
				stuck_arrows.append({
					"pos": Vector3(pos.x, gy + 0.14, pos.z),
					"dir": d_st.normalized(),
					"life": 3.2,
				})
			arrows.remove_at(i)
		elif vis < MAX_PROJ:
			var dir := (a["vel"] as Vector3).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector3.FORWARD
			var up_v := Vector3.FORWARD if absf(dir.y) > 0.98 else Vector3.UP
			var a_basis := Basis.looking_at(dir, up_v)
			_put_proj(vis, a_basis.scaled_local(Vector3(0.055, 0.055, 0.58)), pos, Color(2.0, 0.9, 0.25))
			if randf() < dt * 16.0:
				fx.spawn_flame_puff(pos, 0.12)
			vis += 1
		i -= 1

	i = shells.size() - 1
	while i >= 0:
		var s := shells[i]
		s["t"] = float(s["t"]) + dt / float(s["dur"])
		var u := clampf(float(s["t"]), 0.0, 1.0)
		var pos: Vector3 = Vector3(s["p0"]).lerp(s["p1"], u)
		pos.y += sin(u * PI) * float(s["arc"])
		s["pos"] = pos
		if u >= 1.0:
			fx.spawn_explosion(pos, 1.1)
			audio.play_sfx("explode", 0.9)
			monsters_sys.explode_at(pos.x, pos.z, float(s["dmg"]), float(s["splash"]), s.get("tower", null))
			shells.remove_at(i)
		elif vis < MAX_PROJ:
			_put_proj(vis, Basis.IDENTITY.scaled(Vector3.ONE * 0.30), pos, Color(1.6, 0.55, 0.15))
			vis += 1
		i -= 1

	i = stuck_arrows.size() - 1
	while i >= 0:
		var sa := stuck_arrows[i]
		sa["life"] = float(sa["life"]) - dt
		if float(sa["life"]) <= 0.0:
			stuck_arrows.remove_at(i)
		elif vis < MAX_PROJ:
			var sdir: Vector3 = sa["dir"]
			var sup := Vector3.FORWARD if absf(sdir.y) > 0.98 else Vector3.UP
			var sbas := Basis.looking_at(sdir, sup)
			var fade := clampf(float(sa["life"]) / 0.8, 0.0, 1.0)
			_put_proj(vis, sbas.scaled_local(Vector3(0.048, 0.048, 0.48 * fade)), sa["pos"], Color(0.55, 0.42, 0.26))
			vis += 1
		i -= 1

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
			footmen.remove_at(i)
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

		var target_pos: Vector3 = f.home
		if foe != null:
			target_pos = Vector3(foe.x, foe.y, foe.z)
		var dx := target_pos.x - f.x
		var dz := target_pos.z - f.z
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
			var spd := 2.2
			var step_d := minf(d, spd * dt)
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

		var has_torch := f.torch
		rig.push_footman_gpu(f)
		if has_torch:
			var tpos: Vector3 = rig.last_torch_pos
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
	arrows.clear()
	shells.clear()
	stuck_arrows.clear()
	footmen.clear()
	proj_mm.visible_instance_count = 0
