class_name CWMonsters
extends RefCounted

# All 21 monster types + 6 biome bosses with full special abilities
# Ported from 61-monsters.js

const DEFS := {
	"skel": {"skel": true, "eye": Color(3.4, 0.9, 0.2), "name": "Skeleton", "hp": 34.0, "spd": 1.35, "bounty": 6, "lives": 1, "hit_h": 0.75, "dmg": 6.0, "atk_t": 0.95, "scale": 1.0, "rig": "human", "col": Color(0.84, 0.80, 0.72), "weapon": true},
	"rat": {"tip": "Fast and frail. Comes in packs.", "eye": Color(3.2, 0.4, 0.3), "name": "Giant Rat", "hp": 13.0, "spd": 2.65, "bounty": 3, "lives": 1, "hit_h": 0.25, "dmg": 3.0, "atk_t": 0.6, "scale": 0.9, "rig": "quad", "col": Color(0.42, 0.35, 0.30)},
	"slime": {"tip": "Splits in two when it dies.", "eye": Color(1.8, 2.8, 0.4), "name": "Slime", "hp": 95.0, "spd": 0.82, "bounty": 9, "lives": 1, "hit_h": 0.35, "dmg": 8.0, "atk_t": 1.2, "scale": 1.0, "rig": "slime", "col": Color(0.32, 0.78, 0.30), "split": ["slimelet", 2]},
	"slimelet": {"eye": Color(1.8, 2.8, 0.4), "name": "Slimelet", "hp": 30.0, "spd": 1.20, "bounty": 3, "lives": 1, "hit_h": 0.22, "dmg": 4.0, "atk_t": 1.0, "scale": 0.58, "rig": "slime", "col": Color(0.40, 0.85, 0.36)},
	"knight": {"skel": true, "armor_suit": true, "tip": "Its armor turns most arrows.", "eye": Color(0.5, 1.7, 3.4), "name": "Skeleton Knight", "hp": 118.0, "spd": 1.00, "bounty": 15, "lives": 1, "hit_h": 0.8, "dmg": 11.0, "atk_t": 1.05, "scale": 1.08, "rig": "human", "col": Color(0.55, 0.60, 0.70), "armor": 0.35, "weapon": true, "shield": true},
	"bat": {"tip": "Flies over the road. Only archers and spires reach it.", "eye": Color(3.2, 0.5, 0.3), "name": "Bat", "hp": 20.0, "spd": 2.30, "bounty": 6, "lives": 1, "hit_h": 0.0, "dmg": 0.0, "atk_t": 1.0, "scale": 1.2, "rig": "fly", "col": Color(0.28, 0.22, 0.30), "fly": true, "alt": 3.2},
	"ghoul": {"tip": "Runs faster the more it is hurt.", "eye": Color(3.2, 2.8, 0.6), "name": "Ghoul", "hp": 40.0, "spd": 1.85, "bounty": 7, "lives": 1, "hit_h": 0.55, "dmg": 9.0, "atk_t": 0.7, "scale": 0.78, "rig": "human", "col": Color(0.56, 0.48, 0.72), "frenzy": 0.55},
	"spider": {"tip": "Slips past your footmen.", "eye": Color(3.4, 0.3, 0.2), "name": "Cave Spider", "hp": 20.0, "spd": 2.25, "bounty": 3, "lives": 1, "hit_h": 0.2, "dmg": 4.0, "atk_t": 0.6, "scale": 1.0, "rig": "bug", "col": Color(0.25, 0.22, 0.26), "slip": true},
	"scarab": {"eye": Color(1.2, 3.0, 2.6), "name": "Scarab", "hp": 9.0, "spd": 2.50, "bounty": 1, "lives": 1, "hit_h": 0.14, "dmg": 2.0, "atk_t": 0.6, "scale": 0.55, "rig": "bug", "col": Color(0.85, 0.68, 0.26), "slip": true},
	"wolf": {"tip": "Fast, and it bites hard.", "eye": Color(3.4, 2.6, 0.3), "name": "Dire Wolf", "hp": 38.0, "spd": 2.70, "bounty": 7, "lives": 1, "hit_h": 0.4, "dmg": 12.0, "atk_t": 0.7, "scale": 1.25, "rig": "quad", "col": Color(0.45, 0.48, 0.56)},
	"bomber": {"skel": true, "tip": "Its powder keg blows up friend and foe.", "eye": Color(3.6, 1.4, 0.2), "name": "Sapper", "hp": 38.0, "spd": 1.55, "bounty": 8, "lives": 2, "hit_h": 0.75, "dmg": 0.0, "atk_t": 1.0, "scale": 1.0, "rig": "human", "col": Color(0.74, 0.62, 0.52), "keg": true, "explode": {"r": 1.8, "dmg": 46.0, "men": 30.0}},
	"wraith": {"tip": "Arrows and swords miss while it fades.", "eye": Color(0.8, 2.4, 3.6), "name": "Wraith", "hp": 58.0, "spd": 1.30, "bounty": 11, "lives": 1, "hit_h": 0.8, "dmg": 0.0, "atk_t": 1.0, "scale": 1.02, "rig": "human", "col": Color(0.35, 0.78, 0.95), "ghost": true, "hood": true},
	"toad": {"tip": "Covers ground in long hops.", "eye": Color(3.0, 2.4, 0.3), "name": "Bog Toad", "hp": 78.0, "spd": 1.00, "bounty": 9, "lives": 1, "hit_h": 0.35, "dmg": 9.0, "atk_t": 1.0, "scale": 1.15, "rig": "slime", "col": Color(0.36, 0.50, 0.24)},
	"wisp": {"tip": "A fast flyer. Easy to kill, hard to catch.", "eye": Color(1.2, 1.6, 2.2), "name": "Wisp", "hp": 10.0, "spd": 3.00, "bounty": 2, "lives": 1, "hit_h": 0.0, "dmg": 0.0, "atk_t": 1.0, "scale": 1.0, "rig": "wisp", "col": Color(0.75, 0.95, 1.4), "fly": true, "alt": 1.8},
	"drummer": {"skel": true, "tip": "Speeds up everything near it.", "eye": Color(3.6, 0.6, 0.2), "name": "War Drummer", "hp": 92.0, "spd": 1.15, "bounty": 14, "lives": 1, "hit_h": 0.8, "dmg": 6.0, "atk_t": 1.0, "scale": 1.08, "rig": "human", "col": Color(0.78, 0.32, 0.24), "drum": true, "aura": [3.5, 0.30]},
	"gargoyle": {"tip": "A flyer that shrugs off arrows.", "eye": Color(3.6, 1.2, 0.2), "name": "Gargoyle", "hp": 90.0, "spd": 1.60, "bounty": 13, "lives": 1, "hit_h": 0.0, "dmg": 0.0, "atk_t": 1.0, "scale": 1.35, "rig": "fly", "col": Color(0.48, 0.50, 0.54), "fly": true, "armor": 0.50, "alt": 2.8},
	"necro": {"skel": true, "tip": "Raises skeletons as it walks.", "eye": Color(0.6, 3.4, 1.0), "name": "Necromancer", "hp": 105.0, "spd": 0.85, "bounty": 18, "lives": 1, "hit_h": 0.8, "dmg": 5.0, "atk_t": 1.2, "scale": 1.08, "rig": "human", "col": Color(0.30, 0.45, 0.34), "hood": true, "staff": true, "summon": {"type": "skel", "n": 2, "every": 7.5, "max": 3, "hp": 0.6}},
	"mummy": {"skel": true, "wraps": true, "tip": "Bursts into scarabs when it falls.", "eye": Color(0.6, 3.0, 2.6), "name": "Mummy", "hp": 135.0, "spd": 0.90, "bounty": 14, "lives": 1, "hit_h": 0.8, "dmg": 12.0, "atk_t": 1.1, "scale": 1.1, "rig": "human", "col": Color(0.84, 0.76, 0.56), "split": ["scarab", 3]},
	"brute": {"tip": "Heals unless you keep hitting it.", "eye": Color(3.4, 2.4, 0.4), "name": "Troll", "hp": 360.0, "spd": 0.82, "bounty": 30, "lives": 2, "hit_h": 1.0, "dmg": 24.0, "atk_t": 1.4, "scale": 1.5, "rig": "human", "col": Color(0.44, 0.46, 0.68), "heavy": true, "weapon": true, "regen": 0.035},
	"golem": {"tip": "Shrugs off arrows and is hard to slow.", "eye": Color(3.2, 2.6, 1.6), "name": "Stone Golem", "hp": 470.0, "spd": 0.62, "bounty": 34, "lives": 2, "hit_h": 1.1, "dmg": 26.0, "atk_t": 1.5, "scale": 1.55, "rig": "human", "col": Color(0.55, 0.58, 0.62), "heavy": true, "armor": 0.35, "slow_res": 0.5},
	"brood": {"tip": "Bursts into spiders when it falls.", "eye": Color(3.4, 0.3, 0.2), "name": "Brood Mother", "hp": 230.0, "spd": 0.92, "bounty": 24, "lives": 2, "hit_h": 0.5, "dmg": 14.0, "atk_t": 1.0, "scale": 2.1, "rig": "bug", "col": Color(0.45, 0.28, 0.42), "split": ["spider", 5]},
	# Bosses (every 5th wave)
	"giant": {"skel": true, "tip": "Slow and enormous. Hit it with everything.", "eye": Color(4.5, 0.9, 0.2), "name": "Bone Giant", "hp": 1250.0, "spd": 0.88, "bounty": 200, "lives": 5, "hit_h": 2.1, "dmg": 46.0, "atk_t": 1.7, "scale": 2.5, "rig": "human", "col": Color(0.88, 0.84, 0.74), "heavy": true, "horns": true, "greatsword": true, "boss": true},
	"ogre": {"tip": "Smashes footmen aside.", "eye": Color(4.0, 2.2, 0.3), "name": "Ogre", "hp": 1400.0, "spd": 0.80, "bounty": 200, "lives": 5, "hit_h": 1.9, "dmg": 52.0, "atk_t": 1.8, "scale": 2.4, "rig": "human", "col": Color(0.56, 0.48, 0.36), "heavy": true, "weapon": true, "boss": true},
	"jotun": {"tip": "Its stomp freezes nearby towers.", "eye": Color(0.8, 2.4, 4.0), "name": "Frost Jotun", "hp": 1150.0, "spd": 0.80, "bounty": 200, "lives": 5, "hit_h": 1.9, "dmg": 52.0, "atk_t": 1.8, "scale": 2.55, "rig": "human", "col": Color(0.55, 0.75, 1.0), "heavy": true, "iceclub": true, "boss": true, "stomp": {"every": 9.5, "r": 5.5, "stun": 1.8}},
	"queen": {"tip": "Keeps hatching spiders.", "eye": Color(3.8, 0.3, 0.9), "name": "Brood Queen", "hp": 1150.0, "spd": 0.85, "bounty": 200, "lives": 5, "hit_h": 1.0, "dmg": 40.0, "atk_t": 1.5, "scale": 3.4, "rig": "bug", "col": Color(0.58, 0.32, 0.68), "boss": true, "summon": {"type": "spider", "n": 2, "every": 7.5, "max": 99, "hp": 1.0}},
	"colossus": {"tip": "Speeds up when it is nearly dead.", "eye": Color(4.0, 1.6, 0.3), "name": "Magma Colossus", "hp": 1250.0, "spd": 0.70, "bounty": 200, "lives": 5, "hit_h": 2.1, "dmg": 60.0, "atk_t": 2.0, "scale": 2.75, "rig": "human", "col": Color(0.95, 0.34, 0.14), "heavy": true, "boss": true, "armor": 0.82, "slow_res": 0.35, "enrage": 0.35},
	"king": {"skel": true, "tip": "Summons mummies to walk with him.", "eye": Color(0.6, 3.0, 2.6), "name": "The Buried King", "hp": 1250.0, "spd": 0.86, "bounty": 200, "lives": 5, "hit_h": 2.1, "dmg": 46.0, "atk_t": 1.7, "scale": 2.5, "rig": "human", "col": Color(0.86, 0.74, 0.40), "heavy": true, "weapon": true, "crown": true, "boss": true, "summon": {"type": "mummy", "n": 1, "every": 9.0, "max": 99, "hp": 0.7}},
}

var mons: Array[Dictionary] = []
var terrain: CWTerrain
var rig: CWRig
var fx: CWFx
var audio: CWAudio
var towers_sys: CWTowers
var on_kill_cb: Callable
var on_leak_cb: Callable
var on_boss_dying_cb: Callable
var on_new_mob_cb: Callable


func init_monsters(p_terrain: CWTerrain, p_rig: CWRig, p_fx: CWFx, p_audio: CWAudio, p_towers: CWTowers, p_kill: Callable, p_leak: Callable, p_boss_dying: Callable = Callable()) -> void:
	on_boss_dying_cb = p_boss_dying
	terrain = p_terrain
	rig = p_rig
	fx = p_fx
	audio = p_audio
	towers_sys = p_towers
	on_kill_cb = p_kill
	on_leak_cb = p_leak


func spawn(type: String, hp_mul: float = 1.0, s_pos: float = -1.0, lat_ofs: float = 999.0) -> Dictionary:
	var def: Dictionary = DEFS[type]
	var s := randf_range(0.5, 1.2) if s_pos < 0.0 else s_pos
	var lat := randf_range(-0.8, 0.8) if lat_ofs > 100.0 else lat_ofs
	var sample := CWLayout.sample_path(terrain.layout, s)
	var p: Vector2 = sample["pos"]
	var d: Vector2 = sample["dir"]
	var perp := Vector2(-d.y, d.x)
	var wx := p.x + perp.x * lat
	var wz := p.y + perp.y * lat
	var wy := terrain.height_at(wx, wz) + (float(def.get("alt", 0.0)) if bool(def.get("fly", false)) else 0.0)

	var col: Color = def["col"]
	var tints: Dictionary = terrain.bio.get("tints", {})
	if tints.has(type):
		col = col * Color(tints[type])

	var m := {
		"type": type,
		"def": def,
		"hp": float(def["hp"]) * hp_mul,
		"max_hp": float(def["hp"]) * hp_mul,
		"s": s,
		"lat": lat,
		"prog": float(sample["prog"]),
		"x": wx,
		"y": wy,
		"z": wz,
		"yaw": atan2(d.x, d.y),
		"phase": randf_range(0.0, TAU),
		"flash": 0.0,
		"slow_f": 0.0,
		"slow_t": 0.0,
		"haste": 0.0,
		"dead": false,
		"dying": 0.0,
		"blocker": null,
		"atk_cd": 0.4,
		"swing": 0.0,
		"ghost_t": randf_range(0.0, 4.0),
		"faded": false,
		"ability_cd": randf_range(2.5, 5.0),
		"summons": 0,
		"torch": (type == "skel" or type == "mummy") and randf() < 0.45,
		"col": col,
	}
	mons.append(m)
	if on_new_mob_cb.is_valid():
		on_new_mob_cb.call(type)
	return m


func slow_monster(m: Dictionary, f: float, dur: float) -> void:
	var def: Dictionary = m["def"]
	if bool(def.get("boss", false)):
		f *= 0.4
		dur *= 0.6
	var res := float(def.get("slow_res", 0.0))
	f *= (1.0 - res)
	m["slow_f"] = maxf(float(m["slow_f"]), f)
	m["slow_t"] = maxf(float(m["slow_t"]), dur)


func hit_monster(m: Dictionary, dmg: float, kind: String, dir: Vector3, tower = null) -> void:
	if bool(m["dead"]) or float(m.get("dying", 0.0)) > 0.0:
		return
	var def: Dictionary = m["def"]
	# Wraith fades through arrows & melee
	if bool(m["faded"]) and (kind == "arrow" or kind == "melee"):
		return
	var armor := float(def.get("armor", 0.0))
	if kind == "arrow" and armor > 0.0:
		# Upstream 61-monsters.js:59: armor is the remaining arrow damage multiplier (e.g. 0.35 = 35% dmg)
		dmg *= armor
		if randf() < 0.6:
			fx.spawn_sparks(Vector3(float(m["x"]), float(m["y"]) + float(def.get("hit_h", 0.6)), float(m["z"])), 3, 3.0, Color(2.4, 2.2, 1.6))
	m["hp"] = float(m["hp"]) - dmg
	m["flash"] = 1.0
	m["flinch"] = 1.0
	if float(m["hp"]) <= 0.0:
		_kill(m, dir, tower)
	else:
		audio.play_sfx("hit", 0.35)


func explode_at(cx: float, cz: float, dmg: float, splash: float, tower = null) -> void:
	var r2 := splash * splash
	for m in mons.duplicate():
		if bool(m["dead"]) or float(m["hp"]) <= 0.0 or bool(m["def"].get("fly", false)):
			continue
		var d2 := CWUtil.dist2(m["x"], m["z"], cx, cz)
		if d2 <= r2:
			var falloff := 1.0 - 0.45 * sqrt(d2) / maxf(splash, 0.1)
			hit_monster(m, dmg * falloff, "blast", Vector3(m["x"] - cx, 1.5, m["z"] - cz), tower)


func _finish_boss(m: Dictionary) -> void:
	if bool(m["dead"]):
		return
	m["dead"] = true
	var pos := Vector3(m["x"], m["y"], m["z"])
	rig.shatter_from_call(func(): _draw_one(m), Vector3(0, 3.8, 0))
	fx.spawn_dust(pos + Vector3(0, 0.5, 0), 26, 4.5, 1.6, 0.75)
	fx.spawn_explosion(pos, 1.25)
	fx.spawn_decal(pos, 2.6, Color(0.04, 0.03, 0.03, 0.72), 24.0)
	fx.spawn_coins(pos, 26)
	fx.add_shake(1.2)
	audio.play_sfx("kill", 1.0, 0.04)
	audio.play_sfx("explode", 0.85, 0.04)
	if on_kill_cb.is_valid():
		on_kill_cb.call(m)


func _kill(m: Dictionary, dir: Vector3, tower = null) -> void:
	if bool(m["dead"]) or float(m.get("dying", 0.0)) > 0.0:
		return
	if tower is Dictionary:
		tower["kills"] = int(tower.get("kills", 0)) + 1
	var def: Dictionary = m["def"]
	if bool(def.get("boss", false)):
		m["dying"] = 1.9
		m["hp"] = 0.0
		if m["blocker"] != null:
			m["blocker"]["foe"] = null
			m["blocker"] = null
		audio.play_sfx("horn_boss", 1.0, 0.05)
		if on_boss_dying_cb.is_valid():
			on_boss_dying_cb.call()
		return
	m["dead"] = true
	if m["blocker"] != null:
		m["blocker"]["foe"] = null
		m["blocker"] = null

	var pos := Vector3(m["x"], m["y"], m["z"])
	var impulse := dir.normalized() * 3.5 if dir.length_squared() > 0.01 else Vector3(0, 2.5, 0)
	rig.shatter_from_call(func(): _draw_one(m), impulse)
	fx.spawn_sparks(pos + Vector3(0, 0.5, 0), 12 if bool(def.get("boss", false)) else 5, 4.5, m["col"])
	fx.spawn_coins(pos, 18 if bool(def.get("boss", false)) else clampi(int(floorf(float(def["bounty"]) / 3.0)), 1, 5))

	# Sapper explosion damages nearby monsters & footmen
	if def.has("explode"):
		var ex: Dictionary = def["explode"]
		fx.spawn_explosion(pos, 1.15)
		audio.play_sfx("explode", 0.9)
		explode_at(m["x"], m["z"], float(ex["dmg"]), float(ex["r"]))
		for f in towers_sys.footmen:
			if CWUtil.dist2(f["x"], f["z"], m["x"], m["z"]) <= float(ex["r"]) * float(ex["r"]):
				f["hp"] = float(f["hp"]) - float(ex["men"])
				f["flash"] = 1.0

	# Splitters (Slime -> Slimelets, Mummy -> Scarabs, Brood Mother -> Spiders)
	if def.has("split"):
		var sp: Array = def["split"]
		for _i in range(int(sp[1])):
			spawn(String(sp[0]), 1.0, float(m["s"]) + randf_range(-0.4, 0.4), float(m["lat"]) + randf_range(-0.35, 0.35))

	var mty: String = String(m["type"])
	var d_sfx := "kill"
	if mty in ["skel", "knight", "mummy"]:
		d_sfx = "bone_rattle"
	elif mty in ["rat", "wolf"]:
		d_sfx = "rat_squeal"
	elif mty == "bat":
		d_sfx = "bat_screech"
	elif mty in ["slime", "slimelet", "ghoul", "toad", "brute", "spider", "scarab", "brood"]:
		d_sfx = "squelch"
	elif mty in ["gargoyle", "golem"]:
		d_sfx = "rock_break"
	elif mty == "wraith":
		d_sfx = "ghost_fade"
	elif mty == "wisp":
		d_sfx = "wisp_pop"
	audio.play_sfx(d_sfx, 0.7 if bool(def.get("boss", false)) else 0.55, 0.10, float(m["x"]))
	if on_kill_cb.is_valid():
		on_kill_cb.call(m)


func find_targets(cx: float, cz: float, rng: float, can_air: bool, can_ground: bool, min_rng: float, count: int) -> Array[Dictionary]:
	var r2 := rng * rng
	var min2 := min_rng * min_rng
	var cands: Array[Dictionary] = []
	for m in mons:
		if bool(m["dead"]) or float(m["hp"]) <= 0.0:
			continue
		var is_fly := bool(m["def"].get("fly", false))
		if is_fly and not can_air:
			continue
		if not is_fly and not can_ground:
			continue
		var d2 := CWUtil.dist2(m["x"], m["z"], cx, cz)
		if d2 <= r2 and d2 >= min2:
			cands.append(m)
	cands.sort_custom(func(a, b): return float(a["prog"]) > float(b["prog"]))
	if cands.size() > count:
		cands.resize(count)
	return cands


func find_chain_next(cx: float, cz: float, rng: float, exclude: Array[Dictionary]) -> Dictionary:
	var best_d := rng * rng
	var best := {}
	for m in mons:
		if bool(m["dead"]) or float(m["hp"]) <= 0.0 or exclude.has(m):
			continue
		var d2 := CWUtil.dist2(m["x"], m["z"], cx, cz)
		if d2 < best_d:
			best_d = d2
			best = m
	return best


func find_duel_target(cx: float, cz: float, rng: float):
	var best_d := rng * rng
	var best = null
	for m in mons:
		if bool(m["dead"]) or float(m["hp"]) <= 0.0 or bool(m["def"].get("fly", false)) or bool(m["def"].get("slip", false)) or bool(m["def"].get("ghost", false)):
			continue
		if m["blocker"] != null:
			continue
		var d2 := CWUtil.dist2(m["x"], m["z"], cx, cz)
		if d2 < best_d:
			best_d = d2
			best = m
	return best


func update_monsters(dt: float) -> void:
	# Reset haste auras first
	for m in mons:
		m["haste"] = 0.0
	for m in mons:
		if bool(m["dead"]) or float(m["hp"]) <= 0.0:
			continue
		var def: Dictionary = m["def"]
		if def.has("aura"):
			var ar: float = def["aura"][0]
			var boost: float = def["aura"][1]
			var r2 := ar * ar
			for other in mons:
				if not bool(other["dead"]) and CWUtil.dist2(m["x"], m["z"], other["x"], other["z"]) <= r2:
					other["haste"] = maxf(float(other["haste"]), boost)

	var total_len: float = terrain.layout["total_len"]
	var i := mons.size() - 1
	while i >= 0:
		var m := mons[i]
		if bool(m["dead"]):
			mons.remove_at(i)
			i -= 1
			continue
		if float(m.get("dying", 0.0)) > 0.0:
			m["dying"] = float(m["dying"]) - dt
			m["y"] = float(m["y"]) - dt * 0.14
			m["flash"] = 0.5 + 0.5 * sin(float(m["dying"]) * 22.0)
			if randf() < dt * 14.0:
				fx.spawn_dust(Vector3(m["x"], float(m["y"]) + 0.4, m["z"]), 2, 1.8, 1.0, 0.6)
			if float(m["dying"]) <= 0.0:
				_finish_boss(m)
				mons.remove_at(i)
			else:
				_draw_one(m)
			i -= 1
			continue

		var def: Dictionary = m["def"]
		m["flash"] = maxf(0.0, float(m["flash"]) - dt * 5.0)
		m["flinch"] = maxf(0.0, float(m.get("flinch", 0.0)) - dt * 5.2)
		m["cast"] = maxf(0.0, float(m.get("cast", 0.0)) - dt * 1.4)
		m["swing"] = maxf(0.0, float(m["swing"]) - dt * 1.75)
		if float(m["slow_t"]) > 0.0:
			m["slow_t"] = maxf(0.0, float(m["slow_t"]) - dt)
			if float(m["slow_t"]) <= 0.0:
				m["slow_f"] = 0.0

		# Troll regeneration
		if def.has("regen"):
			m["hp"] = minf(float(m["max_hp"]), float(m["hp"]) + float(m["max_hp"]) * float(def["regen"]) * dt)

		# Wraith periodic phase fade
		if bool(def.get("ghost", false)):
			m["ghost_t"] = float(m["ghost_t"]) + dt
			m["faded"] = fmod(float(m["ghost_t"]), 4.7) > 3.0

		# Special active abilities (Summon / Frost Jotun Stomp)
		m["ability_cd"] = float(m["ability_cd"]) - dt
		if float(m["ability_cd"]) <= 0.0:
			if def.has("summon"):
				var sm: Dictionary = def["summon"]
				if int(m["summons"]) < int(sm["max"]):
					m["ability_cd"] = float(sm["every"])
					m["summons"] = int(m["summons"]) + 1
					m["cast"] = 1.0
					for _k in range(int(sm["n"])):
						spawn(String(sm["type"]), float(sm["hp"]), float(m["s"]) + randf_range(-0.6, 0.6), float(m["lat"]) + randf_range(-0.4, 0.4))
					fx.spawn_sparks(Vector3(m["x"], float(m["y"]) + 1.0, m["z"]), 8, 3.0, Color(0.4, 1.0, 0.5))
			elif def.has("stomp"):
				var st: Dictionary = def["stomp"]
				m["ability_cd"] = float(st["every"])
				towers_sys.stun_towers_in_radius(m["x"], m["z"], float(st["r"]), float(st["stun"]))
				fx.add_shake(0.35)
				fx.flash(Vector3(m["x"], float(m["y"]) + 1.2, m["z"]), Color(0.5, 0.85, 1.0), 8.0, 0.35, 16.0)
				audio.play_sfx("crumble", 0.7)

		# Movement or Melee Duel
		var blocker = m["blocker"]
		if blocker != null and float(blocker["hp"]) > 0.0:
			var bdx := float(blocker["x"]) - float(m["x"])
			var bdz := float(blocker["z"]) - float(m["z"])
			m["yaw"] = lerp_angle(float(m["yaw"]), atan2(bdx, bdz), 1.0 - exp(-12.0 * dt))
			m["mv"] = CWUtil.damp(float(m.get("mv", 1.0)), 0.0, 10.0, dt)
			m["atk_cd"] = float(m["atk_cd"]) - dt
			if float(m["atk_cd"]) <= 0.0:
				m["atk_cd"] = maxf(0.65, float(def["atk_t"]))
				m["swing"] = 1.0
				m["struck"] = false
			if float(m["swing"]) > 0.0 and float(m["swing"]) <= 0.52 and not bool(m.get("struck", true)):
				m["struck"] = true
				blocker["hp"] = float(blocker["hp"]) - float(def["dmg"])
				blocker["flash"] = 1.0
				blocker["flinch"] = 1.0
				var hit_p := Vector3((float(m["x"]) + float(blocker["x"])) * 0.5, float(m["y"]) + 0.85, (float(m["z"]) + float(blocker["z"])) * 0.5)
				fx.spawn_sparks(hit_p, 6, 3.2, Color(1.0, 0.82, 0.42))
				audio.play_sfx("hit", 0.45)
		else:
			m["blocker"] = null
			var spd := float(def["spd"]) * (1.0 - float(m["slow_f"])) * (1.0 + float(m["haste"]))
			# Ghoul frenzy when hurt
			if def.has("frenzy"):
				var hurt := 1.0 - clampf(float(m["hp"]) / maxf(float(m["max_hp"]), 1.0), 0.0, 1.0)
				spd *= (1.0 + hurt * float(def["frenzy"]))
			# Magma Colossus enrage below 35% HP (61-monsters.js:286)
			if def.has("enrage") and float(m["hp"]) < float(m["max_hp"]) * float(def["enrage"]):
				spd *= 1.35
				if not bool(m.get("raged", false)):
					m["raged"] = true
					fx.spawn_sparks(Vector3(m["x"], float(m["y"]) + 1.8, m["z"]), 22, 4.5, Color(2.6, 0.85, 0.14))
					fx.add_shake(0.55)
					audio.play_sfx("horn_boss", 0.85)

			m["s"] = float(m["s"]) + spd * dt
			var is_fly := bool(def.get("fly", false))
			var sample := terrain.sample_smooth_road(float(m["s"])) if is_fly else CWLayout.sample_path(terrain.layout, float(m["s"]))
			var p: Vector2 = sample["pos"]
			var d: Vector2 = sample["dir"]
			var perp := Vector2(-d.y, d.x)
			if is_fly:
				var weave := sin(float(m["phase"]) * 0.22) * (0.70 if String(m["type"]) == "wisp" else 0.45)
				var lat_f := float(m["lat"]) * 1.25 + weave
				var e_end := clampf((float(m["s"]) - (total_len - 6.0)) / 6.0, 0.0, 1.0)
				var e2 := e_end * e_end * (3.0 - 2.0 * e_end)
				var tx := lerpf(p.x + perp.x * lat_f, terrain.beacon_pos.x, e2)
				var tz := lerpf(p.y + perp.y * lat_f, terrain.beacon_pos.z, e2)
				m["x"] = CWUtil.damp(float(m["x"]), tx, 4.0, dt)
				m["z"] = CWUtil.damp(float(m["z"]), tz, 4.0, dt)
				var base_y := terrain.height_at(m["x"], m["z"])
				var want_y := lerpf(base_y + float(def.get("alt", 2.8)), terrain.beacon_pos.y - 0.2, e2)
				m["y"] = CWUtil.damp(float(m["y"]), want_y + sin(float(m["phase"]) * 0.4) * 0.25, 3.0, dt)
			else:
				m["x"] = p.x + perp.x * float(m["lat"])
				m["z"] = p.y + perp.y * float(m["lat"])
				m["y"] = terrain.height_at(m["x"], m["z"])
			m["yaw"] = atan2(d.x, d.y)
			m["prog"] = float(sample["prog"])
			m["phase"] = float(m["phase"]) + dt * spd * 6.2
			m["mv"] = CWUtil.damp(float(m.get("mv", 1.0)), 1.0, 10.0, dt)
			# Boss heavy footstep dust, footprint decal & subtle camera shake (61-monsters.js:322)
			if bool(def.get("boss", false)) and not is_fly:
				var st_idx := int(floorf(float(m["phase"]) / PI))
				if st_idx != int(m.get("step", -1)):
					m["step"] = st_idx
					var fsd := 1.0 if (st_idx & 1) == 1 else -1.0
					var fp := Vector3(float(m["x"]) + perp.x * fsd * 0.5, float(m["y"]) + 0.06, float(m["z"]) + perp.y * fsd * 0.5)
					fx.spawn_dust(fp, 6, 2.2, 0.9, 0.55)
					fx.spawn_decal(fp, 0.65, Color(0.03, 0.025, 0.022, 0.48), 8.5)
					fx.add_shake(0.28)

			if float(m["s"]) >= total_len - 0.4:
				m["dead"] = true
				fx.beacon_gutter = 1.0
				audio.play_sfx("leak", 0.9)
				if on_leak_cb.is_valid():
					on_leak_cb.call(m)
				mons.remove_at(i)
				i -= 1
				continue

		_draw_one(m)
		var m_ty: String = String(m["type"])
		var m_sc: float = float(def["scale"])
		var m_pos := Vector3(m["x"], m["y"], m["z"])
		var hit_h: float = float(def.get("hit_h", 0.6))
		# Slowed monster crackling blue lightning arcs (61-monsters.js:157)
		if float(m["slow_t"]) > 0.0 and randf() < dt * 8.0:
			var ba := randf() * TAU
			var b0 := m_pos + Vector3(0.0, hit_h, 0.0)
			var b1 := b0 + Vector3(cos(ba) * 0.45 * m_sc, randf_range(-0.28, 0.36), sin(ba) * 0.45 * m_sc)
			fx.spawn_bolt(b0, b1, Color(0.45, 0.72, 1.6), 0.10)
		# Wisp glowing aura & sparkling trail (61-monsters.js:152)
		if m_ty == "wisp":
			var wc: Color = m["col"]
			rig.push_glow(m_pos, wc * 1.4, 0.85, 0.48)
			if randf() < dt * 14.0:
				fx.spawn_sparks(m_pos, 1, 1.4, wc * 1.8)
		# Wraith ethereal blue aura & drifting wisps (61-monsters.js:153)
		elif m_ty == "wraith":
			var wa := 0.46 if bool(m["faded"]) else 0.18
			rig.push_glow(m_pos + Vector3(0.0, 0.75 * m_sc, 0.0), Color(0.30, 0.65, 1.5), 1.45 * m_sc, wa)
			if bool(m["faded"]) and randf() < dt * 12.0:
				fx.spawn_sparks(m_pos + Vector3(randf_range(-0.22, 0.22), randf_range(0.2, 1.2), randf_range(-0.22, 0.22)), 1, 1.2, Color(0.55, 1.0, 2.0))
		# Necromancer / Brood Queen / Buried King summon cast aura (61-monsters.js:154)
		elif (m_ty == "necro" or m_ty == "queen" or m_ty == "king") and float(m.get("cast", 0.0)) > 0.02:
			var cc := Color(0.4, 1.6, 0.6) if m_ty == "necro" else (Color(1.2, 0.5, 1.6) if m_ty == "queen" else Color(0.4, 1.5, 1.3))
			var cu := float(m["cast"])
			rig.push_glow(m_pos + Vector3(0.0, hit_h * 1.5, 0.0), cc, 2.2 * cu * m_sc, 0.34 * cu)
		# Magma Colossus rising volcanic ember trail (61-monsters.js:155)
		elif m_ty == "colossus":
			var erate := 24.0 if bool(m.get("raged", false)) else 7.0
			if randf() < dt * erate:
				fx.spawn_sparks(m_pos + Vector3(randf_range(-0.65, 0.65), randf_range(0.6, 2.6), randf_range(-0.65, 0.65)), 1, 2.0, Color(2.6, 0.9, 0.15))
		if bool(m.get("torch", false)):
			var tp: Vector3 = rig.last_torch_pos
			fx.torch_positions.append(tp)
			if randf() < dt * 4.5:
				fx.spawn_flame_puff(tp, 0.16)
		i -= 1


func _draw_one(m: Dictionary) -> void:
	var def: Dictionary = m["def"]
	var pos := Vector3(m["x"], m["y"], m["z"])
	var col: Color = m["col"]
	if bool(m["faded"]):
		col = col.lerp(Color(0.2, 0.9, 1.0), 0.55)
	elif float(m["slow_t"]) > 0.0:
		col = col.lerp(Color(0.45, 0.85, 1.0), 0.4)

	var rig_kind: String = def["rig"]
	match rig_kind:
		"human":
			rig.draw_humanoid(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]), float(m["swing"]), col, col.lightened(0.15), float(m["flash"]), {
				"heavy": bool(def.get("heavy", false)),
				"weapon": bool(def.get("weapon", false)),
				"greatsword": bool(def.get("greatsword", false)),
				"shield": bool(def.get("shield", false)),
				"keg": bool(def.get("keg", false)),
				"crown": bool(def.get("crown", false)),
				"hood": bool(def.get("hood", false)),
				"horns": bool(def.get("horns", false)),
				"staff": bool(def.get("staff", false)),
				"drum": bool(def.get("drum", false)),
				"iceclub": bool(def.get("iceclub", false)),
				"torch": bool(m.get("torch", false)),
				"mv": float(m.get("mv", 1.0)),
				"flinch": float(m.get("flinch", 0.0)),
				"cast": float(m.get("cast", 0.0)),
				"skel": bool(def.get("skel", false)),
				"wraith": String(m["type"]) == "wraith",
				"armor_suit": bool(def.get("armor_suit", false)),
				"wraps": bool(def.get("wraps", false)),
				"eye": def.get("eye", Color(2.8, 1.2, 0.3)),
			})
		"quad":
			rig.draw_quadruped(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]), col, float(m["flash"]), def.get("eye", Color.BLACK), float(m["swing"]))
		"slime":
			rig.draw_slime(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]), col, float(m["flash"]), def.get("eye", Color.BLACK), float(m["swing"]), String(m["type"]) == "toad")
		"fly":
			rig.draw_flyer(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]) * 2.0, col, float(m["flash"]), false, def.get("eye", Color.BLACK))
		"wisp":
			rig.draw_flyer(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]), col, float(m["flash"]), true, def.get("eye", Color.BLACK))
		"bug":
			rig.draw_bug(pos, float(m["yaw"]), float(def["scale"]), float(m["phase"]), col, float(m["flash"]), def.get("eye", Color.BLACK), float(m["swing"]))


func clear_all() -> void:
	mons.clear()
