class_name CWGame
extends Node

signal banner_requested(text: String, dur: float, is_boss: bool)
signal coin_dropped(world_pos: Vector3, amount: int, is_boss: bool)

# Wave director, economy, battlefield crumble/rise transitions, and self-playing AI Commander
# Ported from 62-game.js

const ROSTER := {
	"skel": [4.0, 3, 6, 0.5, 1, 5.0],
	"rat": [1.7, 5, 9, 0.2, 2, 3.0],
	"bat": [4.2, 3, 5, 0.35, 2, 1.3],
	"ghoul": [5.5, 2, 4, 0.4, 2, 2.0],
	"slime": [9.5, 1, 3, 0.9, 3, 2.0],
	"spider": [3.0, 3, 6, 0.25, 3, 2.0],
	"scarab": [1.9, 5, 8, 0.18, 2, 0.0],
	"knight": [12.5, 1, 3, 0.5, 4, 2.0],
	"wolf": [5.5, 2, 4, 0.35, 4, 1.6],
	"bomber": [6.0, 1, 2, 0.8, 4, 1.2],
	"wraith": [9.0, 1, 3, 0.7, 5, 1.4],
	"toad": [8.0, 1, 3, 0.7, 5, 0.7],
	"wisp": [2.6, 4, 7, 0.22, 5, 0.8],
	"drummer": [13.0, 1, 1, 1.0, 6, 0.9],
	"gargoyle": [11.0, 3, 5, 0.6, 6, 0.9],
	"necro": [18.0, 1, 1, 1.2, 7, 0.9],
	"mummy": [15.0, 1, 2, 0.9, 7, 0.9],
	"brute": [32.0, 1, 1, 2.0, 8, 0.7],
	"golem": [40.0, 1, 1, 2.0, 8, 0.7],
	"brood": [30.0, 1, 1, 2.0, 9, 0.6],
}

var gold: int = 240
var lives: int = 20
var max_lives: int = 20
var level: int = 0
var k: int = 0
var slain: int = 0
var phase: String = "play" # play, clear, crumble, rise, defeat
var phase_t: float = 0.0
var slowmo: float = 0.0
var paused: bool = false
var speed: int = 1
var ignite_at: float = -1.0
var ignited: bool = false
var ai_commander: bool = true
var ai_think_cd: float = 0.35

var queue: Array[Dictionary] = []
var wave_t: float = 0.0
var next_in: float = 1.5
var spawning: bool = false
var boss_wave: bool = false
var dmg_mul: float = 1.0
var biome_start: int = 0
var seed_val: int = 4
var best_wave: int = 0
var seen_mobs: Dictionary = {}
const SAVE_PATH := "user://cinderwatch_save.cfg"

var terrain: CWTerrain
var towers_sys: CWTowers
var monsters_sys: CWMonsters
var fx: CWFx
var rig: CWRig
var audio: CWAudio
var env: Environment
func init_game(p_terrain: CWTerrain, p_towers: CWTowers, p_monsters: CWMonsters, p_fx: CWFx, p_rig: CWRig, p_audio: CWAudio, p_env: Environment) -> void:
	terrain = p_terrain
	towers_sys = p_towers
	monsters_sys = p_monsters
	fx = p_fx
	rig = p_rig
	audio = p_audio
	env = p_env
	_load_best_wave()
	biome_start = randi() % CWBiome.BIOMES.size()
	seed_val = randi_range(1, 99999)
	start_new_run()


func switch_biome(biome_idx: int) -> void:
	var n := CWBiome.BIOMES.size()
	biome_start = ((biome_idx % n) + n) % n
	seed_val = randi_range(1, 99999)
	start_new_run()


func cycle_biome() -> void:
	switch_biome(biome_start + level + 1)


func reroll_seed() -> void:
	var cur_idx := (biome_start + level) % CWBiome.BIOMES.size()
	switch_biome(cur_idx)


func start_new_run() -> void:
	level = 0
	k = 0
	slain = 0
	lives = max_lives
	gold = 240
	phase = "play"
	phase_t = 0.0
	_load_board(seed_val, level, false)
	next_in = 1.6
	spawning = false
	boss_wave = false
	queue.clear()
	_banner(terrain.bio["name"], 2.4, false)


func _load_board(p_seed: int, p_lvl: int, rising: bool) -> void:
	towers_sys.clear_all()
	monsters_sys.clear_all()
	rig.clear_debris()
	fx.clear_fx()
	var info := terrain.build_board(terrain.gfx, p_seed, p_lvl, biome_start)
	fx.apply_biome(info["bio"], env, info["beacon_pos"], bool(info.get("mirrored", false)))
	fx.waterfall_pos = info["waterfall_pos"]
	fx.has_waterfall = bool(info["has_waterfall"])
	fx.env_srcs = info["env_lights"]
	fx.keep_fires = info["keep_fires"]
	fx.pond_centers = info["pond_centers"]
	fx.beacon_level = float(lives) / float(max_lives)
	fx.beacon_on = 0.0 if rising else 1.0
	if rising:
		terrain.update_rise(0.0, 2.0)


func _load_best_wave() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_wave = int(cfg.get_value("progress", "best_wave", 0))


func _save_best_wave() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("progress", "best_wave", best_wave)
	cfg.save(SAVE_PATH)


func wave_number() -> int:
	return level * 5 + (1 if phase == "rise" else maxi(1, k))


func boss_type() -> String:
	var b: Array = terrain.bio["boss"]
	return String(b[int(floorf(float(level) / float(CWBiome.BIOMES.size()))) % b.size()])


func call_wave_early() -> bool:
	if phase == "play" and not spawning and not boss_wave and next_in > 0.4:
		var bonus := int(roundf(next_in * 3.0))
		gold += bonus
		next_in = 0.0
		audio.play_sfx("coin", 0.7)
		return true
	return false


func build_tower(pad: Dictionary, kind: String, by_player: bool) -> bool:
	if pad["tower"] != null or phase != "play":
		return false
	var cost: int = CWTowers.DEFS[kind]["cost"][0]
	if gold < cost:
		return false
	gold -= cost
	towers_sys.build_tower(pad, kind, terrain.pal)
	fx.spawn_ring(Vector3(pad["x"], pad["y"], pad["z"]), 2.8, Color(0.55, 0.85, 1.5, 0.9) if by_player else Color(1.5, 1.05, 0.35, 0.9), 0.55)
	if by_player:
		ai_commander = false
	return true


func upgrade_tower(t: Dictionary, by_player: bool) -> bool:
	if int(t["lvl"]) >= 2 or String(t["state"]) != "active" or phase != "play":
		return false
	var cost: int = t["def"]["cost"][int(t["lvl"]) + 1]
	if gold < cost:
		return false
	gold -= cost
	towers_sys.upgrade_tower(t, terrain.pal)
	fx.spawn_ring(Vector3(t["x"], t["y"], t["z"]), 3.0, Color(0.55, 0.85, 1.5, 0.9) if by_player else Color(1.5, 1.05, 0.35, 0.9), 0.55)
	if by_player:
		ai_commander = false
	return true


func sell_tower(t: Dictionary, by_player: bool) -> void:
	gold += towers_sys.sell_tower(t)
	if by_player:
		ai_commander = false


func on_boss_dying() -> void:
	slowmo = 1.4


func on_monster_killed(m: CWMonsterUnit) -> void:
	slain += 1
	var bty := int(m.def["bounty"])
	gold += bty
	coin_dropped.emit(Vector3(m.x, m.y + 0.8, m.z), bty, bool(m.def.get("boss", false)))
	if bool(m.def.get("boss", false)):
		audio.play_sfx("coin", 1.0)
		fx.add_shake(0.55)


func on_monster_leaked(m: CWMonsterUnit) -> void:
	lives = maxi(0, lives - int(m.def["lives"]))
	fx.beacon_level = float(lives) / float(max_lives)
	if lives <= 0 and phase != "defeat":
		phase = "defeat"
		phase_t = 0.0
		fx.beacon_on = 0.0
		fx.spawn_embers(terrain.beacon_pos, 50, 1.4)
		fx.spawn_smoke(terrain.beacon_pos + Vector3(0, 0.8, 0), 10, 0.8, 1.5, 2.8)
		_banner("The Beacon Fell · Restarting...", 3.5, true)


func update_game(dt: float) -> void:
	match phase:
		"play":
			_update_waves(dt)
			if ai_commander:
				_ai_think(dt)
		"clear":
			phase_t += dt
			if phase_t >= 2.6:
				_start_crumble()
		"crumble":
			phase_t += dt
			var fell_all := terrain.update_crumble(phase_t, fx)
			if fell_all or phase_t >= 5.2:
				if lives <= 0:
					level = 0
					slain = 0
					lives = max_lives
					gold = 240
					seed_val += 1
				else:
					level += 1
					gold = maxi(gold, 240 + level * 45)
					lives = mini(max_lives, lives + 4)
				k = 0
				_load_board(seed_val + level * 37, level, true)
				phase = "rise"
				phase_t = 0.0
				ignite_at = -1.0
				ignited = false
				_banner(terrain.bio["name"], 2.8, false)
		"rise":
			phase_t += dt
			var risen := terrain.update_rise(phase_t, 1.15)
			if risen and ignite_at < 0.0:
				ignite_at = phase_t + 0.25
			if ignite_at > 0.0 and phase_t >= ignite_at and not ignited:
				ignited = true
				fx.beacon_on = 1.0
				fx.flash(terrain.beacon_pos, Color(1.0, 0.63, 0.31), 90.0, 0.7, 60.0)
				fx.spawn_embers(terrain.beacon_pos, 50, 1.6)
				fx.add_shake(0.5)
				audio.play_sfx("explode", 0.65)
			if ignited and phase_t >= ignite_at + 0.7:
				phase = "play"
				phase_t = 0.0
				next_in = 0.9 if level == 0 else 1.6
				spawning = false
				boss_wave = false
		"defeat":
			phase_t += dt
			if phase_t >= 4.4:
				_start_crumble()


func _start_crumble() -> void:
	# Exact 62-game.js:155-169: clear all entities, tower flames/lights, board flames, waterfall spray, decals & floating water/cracks
	phase = "crumble"
	phase_t = 0.0
	monsters_sys.clear_all()
	towers_sys.clear_all()
	rig.clear_debris()
	fx.clear_fx()
	terrain.hide_crumble_extras()
	fx.add_shake(0.95)
	audio.play_sfx("crumble", 1.0)


func _update_waves(dt: float) -> void:
	if spawning:
		wave_t += dt
		while not queue.is_empty() and float(queue[0]["t"]) <= wave_t:
			var item: Dictionary = queue.pop_front()
			monsters_sys.spawn(String(item["type"]), float(item["hp_mul"]))
		if queue.is_empty():
			spawning = false
	elif monsters_sys.mons.is_empty():
		if boss_wave:
			boss_wave = false
			phase = "clear"
			phase_t = 0.0
			_banner("The pass holds", 2.2, false)
			return
		next_in -= dt
		if next_in <= 0.0:
			_start_wave()


func _start_wave() -> void:
	var wn_now := wave_number()
	if wn_now > best_wave:
		best_wave = wn_now
		_save_best_wave()
	k = (k % 5) + 1
	boss_wave = (k == 5)
	queue = _build_wave(k, level)
	wave_t = 0.0
	spawning = true
	next_in = 6.5
	audio.play_sfx("horn_boss" if boss_wave else "horn", 0.95)
	var title := "Wave %d · %s" % [wave_number(), CWMonsters.DEFS[boss_type()]["name"]] if boss_wave else "Wave %d" % wave_number()
	_banner(title, 3.2 if boss_wave else 2.0, boss_wave)


func _build_wave(p_k: int, p_lvl: int) -> Array[Dictionary]:
	var q: Array[Dictionary] = []
	var is_boss := (p_k == 5)
	var lv := 1.0 + 0.25 * float(p_lvl)
	var budget := (34.0 + 25.0 * float(p_k - 1)) * lv * (0.7 if is_boss else 1.0)
	var hp_mul := (1.0 + 0.13 * float(p_k - 1)) * (1.0 + 0.27 * float(p_lvl))
	var w_num := p_lvl * 5 + p_k
	var bio: Dictionary = terrain.bio
	var mobs_w: Dictionary = bio.get("mobs", {})
	var early: Dictionary = bio.get("early", {})

	var menu: Array[Dictionary] = []
	var tot := 0.0
	for ty in ROSTER.keys():
		var r: Array = ROSTER[ty]
		var mul := float(mobs_w.get(ty, 1.0))
		var unlock := mini(int(r[4]), int(early.get(ty, 99)))
		var wt := float(r[5]) * mul if float(r[5]) > 0.0 else float(mobs_w.get(ty, 0.0))
		if w_num >= unlock and wt > 0.0:
			menu.append({"type": ty, "wt": wt})
			tot += wt

	var t := 0.5
	if is_boss:
		q.append({"t": 2.0, "type": boss_type(), "hp_mul": 1.0 + 0.4 * float(p_lvl)})

	var guard_loop := 0
	while budget > 0.0 and guard_loop < 80:
		guard_loop += 1
		var roll := randf() * maxf(tot, 0.01)
		var picked := "skel"
		for entry in menu:
			roll -= float(entry["wt"])
			if roll <= 0.0:
				picked = String(entry["type"])
				break
		var r: Array = ROSTER[picked]
		if float(r[0]) > budget + 5.0:
			picked = "skel"
			r = ROSTER["skel"]
		var count := randi_range(int(r[1]), int(r[2]))
		var gap := float(r[3])
		for _i in range(count):
			if budget <= 0.0:
				break
			q.append({"t": t, "type": picked, "hp_mul": hp_mul})
			t += gap * randf_range(0.8, 1.25)
			budget -= float(r[0])
		t += randf_range(1.0, 2.1)

	q.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return q


func _pad_coverage(pad: Dictionary, rng: float) -> int:
	var road: Array[Vector2] = terrain.layout["road"]
	var r2 := rng * rng
	var hits := 0
	for pt in road:
		if CWUtil.dist2(pad["x"], pad["z"], pt.x, pt.y) <= r2:
			hits += 1
	return hits


func _ai_think(dt: float) -> void:
	ai_think_cd -= dt
	if ai_think_cd > 0.0:
		return
	ai_think_cd = 0.65

	var pads: Array = terrain.layout["pads"]
	var empty_pads: Array[Dictionary] = []
	var counts := {"archer": 0, "bombard": 0, "spire": 0, "guard": 0}
	for p in pads:
		if p["tower"] == null:
			empty_pads.append(p)
		else:
			var knd: String = p["tower"]["kind"]
			counts[knd] = int(counts[knd]) + 1

	# Decide whether to build a new tower or upgrade an existing one
	if not empty_pads.is_empty() and (towers_sys.towers.size() < 6 or randf() < 0.65):
		var want := "archer"
		if counts["archer"] < 2:
			want = "archer"
		elif counts["guard"] < 1:
			want = "guard"
		elif counts["spire"] < 1:
			want = "spire"
		elif counts["bombard"] < 2:
			want = "bombard"
		else:
			want = CWTowers.TOWER_KINDS[randi() % CWTowers.TOWER_KINDS.size()]
		var cost: int = CWTowers.DEFS[want]["cost"][0]
		if gold >= cost:
			var rng: float = CWTowers.DEFS[want]["range"][0]
			var best_pad: Dictionary = empty_pads[0]
			var best_score := -1
			for p in empty_pads:
				var sc := _pad_coverage(p, rng)
				if sc > best_score:
					best_score = sc
					best_pad = p
			build_tower(best_pad, want, false)
			return

	# Upgrade highest-impact affordable tower
	var best_t = null
	var best_u_cost := 999999
	for t in towers_sys.towers:
		if int(t["lvl"]) < 2 and String(t["state"]) == "active":
			var c: int = t["def"]["cost"][int(t["lvl"]) + 1]
			if gold >= c and c < best_u_cost:
				best_u_cost = c
				best_t = t
	if best_t != null:
		upgrade_tower(best_t, false)


func _banner(text: String, dur: float, is_boss: bool) -> void:
	banner_requested.emit(text, dur, is_boss)
