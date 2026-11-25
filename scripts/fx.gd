class_name CWFx
extends Node3D

# Scene-backed dynamic lighting, MultiMesh FX pools (zero-GC SoA + O(1) swap-remove),
# GPU weather, GPUParticles3D, and biome atmosphere transitions.

const MAX_PARTS := 2000
const MAX_COINS := 120
const MAX_BOLTS := 480
const MAX_FLAMES := 192
const MAX_DECALS := 64
const MAX_RINGS := 24
const MAX_WX := 2600
const MIST_GAIN_ENV := 2.7

# Scene-tree nodes bound in init_fx() (scenes/fx.tscn)
var moon_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var beacon_light: OmniLight3D
var beacon_flame_root: Node3D
var beacon_flame_mats: Array[ShaderMaterial] = []
var beacon_halo_mat: ShaderMaterial
var lantern_flames: Array[MeshInstance3D] = []
var spot_pool: Array[Dictionary] = []
var tower_lights: Array[OmniLight3D] = []
var torch_lights: Array[OmniLight3D] = []
var env_lights: Array[OmniLight3D] = []
var flash_pool: Array[Dictionary] = []

var part_mmi: MultiMeshInstance3D
var part_mm: MultiMesh
var bolt_mmi: MultiMeshInstance3D
var bolt_mm: MultiMesh
var wx_mmi: MultiMeshInstance3D
var wx_mm: MultiMesh
var wx_mat: ShaderMaterial
var flame_mmi: MultiMeshInstance3D
var flame_mm: MultiMesh
var decal_mmi: MultiMeshInstance3D
var decal_mm: MultiMesh
var ring_mmi: MultiMeshInstance3D
var ring_mm: MultiMesh
var beacon_embers_gpu: GPUParticles3D
var waterfall_gpu: GPUParticles3D
var _wf_gpu_mat: ParticleProcessMaterial

# External per-frame inputs & biome state
var torch_positions: Array[Vector3] = []
var dynamic_flames: Array[Dictionary] = []
var emitters: Array[Dictionary] = []
var env_srcs: Array[Dictionary] = []
var keep_fires: Array[Vector3] = []
var pond_centers: Array[Vector3] = []
var beacon_pos: Vector3 = Vector3.ZERO
var waterfall_pos: Vector3 = Vector3.ZERO
var has_waterfall: bool = false
var biome_key: String = "ashen"
var look_cur: Dictionary = {}
var look_to: Dictionary = {}
var env_ref: Environment = null
var beacon_mul: float = 1.0
var beacon_level: float = 1.0
var beacon_on: float = 1.0
var beacon_gutter: float = 0.0
var shake_mag: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var wx_fade: float = 1.0

# MultiMesh bulk upload buffers
var part_buf: PackedFloat32Array = PackedFloat32Array()
var bolt_buf: PackedFloat32Array = PackedFloat32Array()
var flame_buf: PackedFloat32Array = PackedFloat32Array()

# Pre-allocated SoA pools (zero Dictionary allocation, O(1) swap-remove)
var _p_cnt: int = 0
var _p_pos: PackedVector3Array = PackedVector3Array()
var _p_vel: PackedVector3Array = PackedVector3Array()
var _p_col: PackedColorArray = PackedColorArray()
var _p_life: PackedFloat32Array = PackedFloat32Array()
var _p_max_life: PackedFloat32Array = PackedFloat32Array()
var _p_size: PackedFloat32Array = PackedFloat32Array()
var _p_grav: PackedFloat32Array = PackedFloat32Array()
var _p_grow: PackedFloat32Array = PackedFloat32Array()

var _c_cnt: int = 0
var _c_pos: PackedVector3Array = PackedVector3Array()
var _c_vel: PackedVector3Array = PackedVector3Array()
var _c_life: PackedFloat32Array = PackedFloat32Array()

var _b_cnt: int = 0
var _b_a: PackedVector3Array = PackedVector3Array()
var _b_b: PackedVector3Array = PackedVector3Array()
var _b_col: PackedColorArray = PackedColorArray()
var _b_life: PackedFloat32Array = PackedFloat32Array()
var _b_max_life: PackedFloat32Array = PackedFloat32Array()

var _d_cnt: int = 0
var _d_pos: PackedVector3Array = PackedVector3Array()
var _d_col: PackedColorArray = PackedColorArray()
var _d_size: PackedFloat32Array = PackedFloat32Array()
var _d_life: PackedFloat32Array = PackedFloat32Array()

var _r_cnt: int = 0
var _r_pos: PackedVector3Array = PackedVector3Array()
var _r_col: PackedColorArray = PackedColorArray()
var _r_max: PackedFloat32Array = PackedFloat32Array()
var _r_t: PackedFloat32Array = PackedFloat32Array()
var _r_dur: PackedFloat32Array = PackedFloat32Array()

# Reusable scratch buffers (zero per-frame allocations)
var _mist_pos: Array[Vector3] = []
var _mist_col: Array[Vector3] = []
var _mist_out: Dictionary = {}
var _active_emitters: Array[Dictionary] = []
var _active_d2: PackedFloat32Array = PackedFloat32Array()
var _top_torch_idx: PackedInt32Array = PackedInt32Array()
var _top_torch_d2: PackedFloat32Array = PackedFloat32Array()
var _spot_shadow_off: bool = false


func init_fx() -> void:
	moon_light = %MoonLight
	fill_light = %FillLight
	beacon_light = %BeaconLight
	beacon_flame_root = %BeaconFlameRoot
	beacon_embers_gpu = %BeaconEmbersGPU
	waterfall_gpu = %WaterfallParticlesGPU
	_wf_gpu_mat = waterfall_gpu.process_material as ParticleProcessMaterial

	beacon_flame_mats.clear()
	for ch in beacon_flame_root.get_children():
		if ch.name == "BeaconHalo":
			beacon_halo_mat = (ch as MeshInstance3D).material_override as ShaderMaterial
		elif ch is MeshInstance3D:
			var sm := (ch as MeshInstance3D).material_override as ShaderMaterial
			if sm != null:
				beacon_flame_mats.append(sm)

	lantern_flames.clear()
	for ch in %LanternFlames.get_children():
		if ch is MeshInstance3D:
			lantern_flames.append(ch as MeshInstance3D)

	spot_pool.clear()
	for ch in %SpotPool.get_children():
		if ch is SpotLight3D:
			spot_pool.append({"light": ch, "owner": null, "fade": 0.0})

	tower_lights.clear()
	for ch in %TowerLights.get_children():
		if ch is OmniLight3D:
			tower_lights.append(ch as OmniLight3D)

	torch_lights.clear()
	for ch in %TorchLights.get_children():
		if ch is OmniLight3D:
			torch_lights.append(ch as OmniLight3D)

	env_lights.clear()
	for ch in %EnvLights.get_children():
		if ch is OmniLight3D:
			env_lights.append(ch as OmniLight3D)

	flash_pool.clear()
	for ch in %FlashPool.get_children():
		if ch is OmniLight3D:
			flash_pool.append({"light": ch, "t": 1.0, "dur": 1.0, "energy": 0.0})

	part_mmi = %ParticlesMMI
	part_mm = part_mmi.multimesh
	part_buf.resize(MAX_PARTS * 16)
	part_mm.instance_count = MAX_PARTS
	part_mm.visible_instance_count = 0

	bolt_mmi = %BoltsMMI
	bolt_mm = bolt_mmi.multimesh
	bolt_buf.resize(MAX_BOLTS * 16)
	bolt_mm.instance_count = MAX_BOLTS
	bolt_mm.visible_instance_count = 0

	wx_mmi = %WeatherMMI
	wx_mm = wx_mmi.multimesh
	wx_mat = wx_mmi.material_override as ShaderMaterial
	wx_mm.instance_count = MAX_WX
	var wx_rng := CWUtil.Rng.new(4242)
	for wi in range(MAX_WX):
		wx_mm.set_instance_transform(wi, Transform3D.IDENTITY)
		wx_mm.set_instance_custom_data(wi, Color(wx_rng.next_f(), wx_rng.next_f(), wx_rng.next_f(), (float(wi) + 0.5) / float(MAX_WX)))

	flame_mmi = %FlamesMMI
	flame_mm = flame_mmi.multimesh
	flame_buf.resize(MAX_FLAMES * 16)
	flame_mm.instance_count = MAX_FLAMES
	flame_mm.visible_instance_count = 0

	decal_mmi = %DecalsMMI
	decal_mm = decal_mmi.multimesh
	decal_mm.instance_count = MAX_DECALS
	decal_mm.visible_instance_count = 0

	ring_mmi = %RingsMMI
	ring_mm = ring_mmi.multimesh
	ring_mm.instance_count = MAX_RINGS
	ring_mm.visible_instance_count = 0

	_alloc_pools()


func _alloc_pools() -> void:
	_p_pos.resize(MAX_PARTS); _p_vel.resize(MAX_PARTS); _p_col.resize(MAX_PARTS)
	_p_life.resize(MAX_PARTS); _p_max_life.resize(MAX_PARTS); _p_size.resize(MAX_PARTS)
	_p_grav.resize(MAX_PARTS); _p_grow.resize(MAX_PARTS)

	_c_pos.resize(MAX_COINS); _c_vel.resize(MAX_COINS); _c_life.resize(MAX_COINS)

	_b_a.resize(MAX_BOLTS); _b_b.resize(MAX_BOLTS); _b_col.resize(MAX_BOLTS)
	_b_life.resize(MAX_BOLTS); _b_max_life.resize(MAX_BOLTS)

	_d_pos.resize(MAX_DECALS); _d_col.resize(MAX_DECALS)
	_d_size.resize(MAX_DECALS); _d_life.resize(MAX_DECALS)

	_r_pos.resize(MAX_RINGS); _r_col.resize(MAX_RINGS)
	_r_max.resize(MAX_RINGS); _r_t.resize(MAX_RINGS); _r_dur.resize(MAX_RINGS)

	_mist_pos.resize(16); _mist_col.resize(16)
	_mist_out = {"pos": _mist_pos, "col": _mist_col, "count": 0}
	_top_torch_idx.resize(maxi(1, torch_lights.size()))
	_top_torch_d2.resize(maxi(1, torch_lights.size()))


func apply_biome(bio: Dictionary, env: Environment, p_beacon_pos: Vector3) -> void:
	beacon_pos = p_beacon_pos
	biome_key = String(bio.get("key", "ashen"))
	beacon_mul = float(bio.get("beacon", 1.0))
	env_ref = env

	var moon_cfg: Array = bio["moon"]
	moon_light.look_at_from_position(bio["moon_pos"], Vector3.ZERO, Vector3.UP)
	var fill_cfg: Array = bio["fill"]
	fill_light.look_at_from_position(Vector3(30, 14, 34), Vector3.ZERO, Vector3.UP)
	var hemi_cfg: Array = bio["hemi"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = false

	look_to = {
		"moon_c": CWUtil.hex_color(moon_cfg[0]),
		"moon_e": float(moon_cfg[1]) * 0.96,
		"fill_c": CWUtil.hex_color(fill_cfg[0]),
		"fill_e": float(fill_cfg[1]) * 0.45,
		"amb_c": CWUtil.hex_color(hemi_cfg[0]).lerp(CWUtil.hex_color(hemi_cfg[1]), 0.30),
		"amb_e": float(hemi_cfg[2]) * 0.24,
		"clear": bio["clear"],
		"mist_amb": bio.get("mist_amb", Vector3(0.05, 0.08, 0.14)),
		"mist": bio.get("mist", Vector4(-0.3, 0.42, 0.75, 0.10)),
		"lift": bio.get("lift", Vector3(0.01, 0.016, 0.03)),
		"sat": float(bio.get("sat", 0.92)),
		"expo": float(bio.get("expo", 1.0)),
	}
	if look_cur.is_empty():
		look_cur = look_to.duplicate()
		_apply_look_now()

	if _wf_gpu_mat != null:
		if biome_key == "ember":
			_wf_gpu_mat.color = Color(2.4, 0.85, 0.16, 0.95)
			_wf_gpu_mat.gravity = Vector3(0.0, 0.6, 0.0)
			_wf_gpu_mat.scale_min = 0.10
			_wf_gpu_mat.scale_max = 0.22
		else:
			_wf_gpu_mat.color = Color(0.48, 0.68, 0.56, 0.45) if biome_key == "fen" else Color(0.75, 0.85, 0.95, 0.52)
			_wf_gpu_mat.gravity = Vector3(0.0, -0.5, 0.0)
			_wf_gpu_mat.scale_min = 0.28
			_wf_gpu_mat.scale_max = 0.50

	if wx_mat != null and bio.has("wx"):
		var wx: Dictionary = bio["wx"]
		wx_mat.set_shader_parameter("u_n", wx["n"])
		wx_mat.set_shader_parameter("u_vel_a", wx["vel_a"])
		wx_mat.set_shader_parameter("u_vel_b", wx["vel_b"])
		wx_mat.set_shader_parameter("u_sway_a", wx["sway_a"])
		wx_mat.set_shader_parameter("u_sway_b", wx["sway_b"])
		wx_mat.set_shader_parameter("u_size_a", wx["size_a"])
		wx_mat.set_shader_parameter("u_size_b", wx["size_b"])
		wx_mat.set_shader_parameter("u_col_a", wx["col_a"])
		wx_mat.set_shader_parameter("u_col_b", wx["col_b"])
		wx_mat.set_shader_parameter("u_al_a", wx["al_a"])
		wx_mat.set_shader_parameter("u_al_b", wx["al_b"])
		wx_mat.set_shader_parameter("u_ya", wx["ya"])
		wx_mat.set_shader_parameter("u_yb", wx["yb"])
		wx_mat.set_shader_parameter("u_amb", wx["amb"])
		wx_fade = 0.0
		wx_mat.set_shader_parameter("u_fade", 0.0)


func _apply_look_now() -> void:
	if look_cur.is_empty():
		return
	moon_light.light_color = look_cur["moon_c"]
	moon_light.light_energy = float(look_cur["moon_e"])
	fill_light.light_color = look_cur["fill_c"]
	fill_light.light_energy = float(look_cur["fill_e"])
	if env_ref != null:
		env_ref.ambient_light_color = look_cur["amb_c"]
		env_ref.ambient_light_energy = float(look_cur["amb_e"])
		env_ref.background_color = look_cur["clear"]


func update_biome_look(dt: float) -> void:
	if look_cur.is_empty() or look_to.is_empty():
		return
	var k := 1.0 - exp(-dt * 1.6)
	look_cur["moon_c"] = (look_cur["moon_c"] as Color).lerp(look_to["moon_c"], k)
	look_cur["moon_e"] = lerpf(float(look_cur["moon_e"]), float(look_to["moon_e"]), k)
	look_cur["fill_c"] = (look_cur["fill_c"] as Color).lerp(look_to["fill_c"], k)
	look_cur["fill_e"] = lerpf(float(look_cur["fill_e"]), float(look_to["fill_e"]), k)
	look_cur["amb_c"] = (look_cur["amb_c"] as Color).lerp(look_to["amb_c"], k)
	look_cur["amb_e"] = lerpf(float(look_cur["amb_e"]), float(look_to["amb_e"]), k)
	look_cur["clear"] = (look_cur["clear"] as Color).lerp(look_to["clear"], k)
	look_cur["mist_amb"] = (look_cur["mist_amb"] as Vector3).lerp(look_to["mist_amb"], k)
	look_cur["mist"] = (look_cur["mist"] as Vector4).lerp(look_to["mist"], k)
	look_cur["lift"] = (look_cur["lift"] as Vector3).lerp(look_to["lift"], k)
	look_cur["sat"] = lerpf(float(look_cur["sat"]), float(look_to["sat"]), k)
	look_cur["expo"] = lerpf(float(look_cur["expo"]), float(look_to["expo"]), k)
	_apply_look_now()


func add_emitter(pos: Vector3, col: Color, energy: float, rng: float) -> Dictionary:
	var e := {"pos": pos, "col": col, "energy": energy, "range": rng, "alive": true, "seed": randf_range(0.0, 100.0)}
	emitters.append(e)
	return e


func remove_emitter(e: Dictionary) -> void:
	e["alive"] = false
	emitters.erase(e)


func flash(pos: Vector3, col: Color, energy: float, dur: float = 0.25, rng: float = 18.0) -> void:
	var best: Dictionary = flash_pool[0]
	for f in flash_pool:
		if float(f["t"]) >= 1.0:
			best = f
			break
		if float(f["t"]) > float(best["t"]):
			best = f
	var l: OmniLight3D = best["light"]
	l.position = pos
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	best["energy"] = energy
	best["dur"] = maxf(dur, 0.05)
	best["t"] = 0.0


func add_shake(amount: float) -> void:
	shake_mag = minf(1.2, shake_mag + amount)


func get_mist_lights() -> Dictionary:
	var n := 0
	var bc := beacon_light.light_color
	_mist_pos[0] = beacon_light.position
	_mist_col[0] = Vector3(bc.r, bc.g, bc.b) * (beacon_light.light_energy * 0.10)
	n = 1
	for f in flash_pool:
		var fl: OmniLight3D = f["light"]
		if fl.light_energy > 0.2:
			var fc := fl.light_color
			_mist_pos[n] = fl.position
			_mist_col[n] = Vector3(fc.r, fc.g, fc.b) * fl.light_energy
			n += 1
			break
	for el in env_lights:
		if el.light_energy > 0.05 and n < 12:
			var ec := el.light_color
			_mist_pos[n] = el.position
			_mist_col[n] = Vector3(ec.r, ec.g, ec.b) * (el.light_energy * MIST_GAIN_ENV)
			n += 1
	for e in emitters:
		if n >= 12:
			break
		if bool(e["alive"]):
			var tc: Color = e["col"]
			_mist_pos[n] = e["pos"]
			_mist_col[n] = Vector3(tc.r, tc.g, tc.b) * float(e["energy"])
			n += 1
	for i in range(n, 16):
		_mist_pos[i] = Vector3.ZERO
		_mist_col[i] = Vector3.ZERO
	_mist_out["count"] = n
	return _mist_out


# --- Zero-allocation FX spawners ---
func _add_part(pos: Vector3, vel: Vector3, col: Color, sz: float, life: float, max_life: float, grav: float, grow: float = 0.0) -> void:
	if _p_cnt >= MAX_PARTS:
		return
	var i := _p_cnt
	_p_cnt += 1
	_p_pos[i] = pos
	_p_vel[i] = vel
	_p_col[i] = col
	_p_size[i] = sz
	_p_life[i] = life
	_p_max_life[i] = max_life
	_p_grav[i] = grav
	_p_grow[i] = grow


func spawn_coins(pos: Vector3, count: int) -> void:
	for _i in range(count):
		if _c_cnt >= MAX_COINS:
			break
		var i := _c_cnt
		_c_cnt += 1
		_c_pos[i] = pos + Vector3(randf_range(-0.25, 0.25), 0.35, randf_range(-0.25, 0.25))
		_c_vel[i] = Vector3(randf_range(-2.2, 2.2), randf_range(3.2, 5.6), randf_range(-2.2, 2.2))
		_c_life[i] = randf_range(0.85, 1.35)


func spawn_dust(pos: Vector3, count: int, spd: float = 2.0, life: float = 1.4, size: float = 0.45) -> void:
	for _i in range(count):
		if _p_cnt >= MAX_PARTS:
			break
		_add_part(
			pos + Vector3(randf_range(-0.25, 0.25), 0.1, randf_range(-0.25, 0.25)),
			Vector3(randf_range(-spd, spd), randf_range(0.2, spd * 0.4), randf_range(-spd, spd)),
			Color(0.62, 0.55, 0.46, 0.55), randf_range(size * 0.5, size),
			randf_range(life * 0.6, life), life, 2.0, 0.5
		)


func spawn_smoke(pos: Vector3, count: int, spd: float = 2.0, up: float = 1.6, life: float = 1.8) -> void:
	for _i in range(count):
		if _p_cnt >= MAX_PARTS:
			break
		_add_part(
			pos + Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2)),
			Vector3(randf_range(-spd * 0.6, spd * 0.6), randf_range(up * 0.5, up), randf_range(-spd * 0.6, spd * 0.6)),
			Color(0.28, 0.26, 0.24, 0.50), randf_range(0.50, 0.85),
			randf_range(life * 0.65, life), life, -0.6, 1.6
		)


func spawn_embers(pos: Vector3, count: int, life: float = 1.6) -> void:
	for _i in range(count):
		if _p_cnt >= MAX_PARTS:
			break
		_add_part(
			pos + Vector3(randf_range(-0.5, 0.5), randf_range(-0.1, 0.4), randf_range(-0.5, 0.5)),
			Vector3(randf_range(-1.2, 1.2), randf_range(1.4, 3.6), randf_range(-1.2, 1.2)),
			Color(2.2, 0.9, 0.3, 0.92), randf_range(0.06, 0.14),
			randf_range(life * 0.5, life), life, -0.4, 0.0
		)


func spawn_flame_puff(pos: Vector3, sc: float = 0.3) -> void:
	_add_part(
		pos + Vector3(randf_range(-0.12, 0.12), 0.04, randf_range(-0.12, 0.12)),
		Vector3(randf_range(-0.25, 0.25), randf_range(1.1, 2.2), randf_range(-0.25, 0.25)),
		Color(2.4, randf_range(0.85, 1.45), 0.28, 0.95), randf_range(0.14, 0.28) * sc / 0.25,
		randf_range(0.22, 0.45), 0.45, -1.5, 0.0
	)


func spawn_sparks(pos: Vector3, count: int, speed: float, col: Color) -> void:
	for _i in range(count):
		if _p_cnt >= MAX_PARTS:
			break
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.4), randf_range(-1.0, 1.0)).normalized()
		_add_part(pos, dir * randf_range(speed * 0.4, speed), col, randf_range(0.07, 0.16), randf_range(0.25, 0.65), 0.65, 9.8, 0.0)


func spawn_decal(pos: Vector3, size: float, col: Color, life: float = 18.0) -> void:
	var idx := _d_cnt
	if idx >= MAX_DECALS:
		idx = 0
		var min_l := _d_life[0]
		for k in range(1, MAX_DECALS):
			if _d_life[k] < min_l:
				min_l = _d_life[k]
				idx = k
	else:
		_d_cnt += 1
	_d_pos[idx] = Vector3(pos.x, pos.y + 0.05, pos.z)
	_d_size[idx] = size
	_d_col[idx] = col
	_d_life[idx] = life


func spawn_ring(pos: Vector3, r_max: float, col: Color, dur: float = 0.45) -> void:
	var idx := _r_cnt
	if idx >= MAX_RINGS:
		idx = 0
		var max_t := _r_t[0]
		for k in range(1, MAX_RINGS):
			if _r_t[k] > max_t:
				max_t = _r_t[k]
				idx = k
	else:
		_r_cnt += 1
	_r_pos[idx] = Vector3(pos.x, pos.y + 0.14, pos.z)
	_r_max[idx] = r_max
	_r_col[idx] = col
	_r_t[idx] = 0.0
	_r_dur[idx] = maxf(dur, 0.01)


func spawn_explosion(pos: Vector3, sc: float = 1.0) -> void:
	flash(pos + Vector3(0, 1.0, 0), Color(1.0, 0.65, 0.25), 9.0 * sc, 0.32, 18.0 * sc)
	add_shake(0.35 * sc)
	spawn_decal(pos, 1.4 * sc, Color(0.05, 0.04, 0.04, 0.62), 20.0)
	spawn_ring(pos, 2.2 * sc, Color(1.6, 0.78, 0.25, 0.85), 0.36)
	spawn_sparks(pos + Vector3(0, 0.4, 0), int(18 * sc), 7.5 * sc, Color(1.0, 0.68, 0.22))
	for _i in range(int(10 * sc)):
		if _p_cnt >= MAX_PARTS:
			break
		_add_part(
			pos + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)),
			Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.2), randf_range(-1.5, 1.5)),
			Color(0.22, 0.2, 0.22, 0.75), randf_range(0.35, 0.75) * sc,
			randf_range(0.45, 0.95), 0.95, -1.2, 0.0
		)


func spawn_bolt(a: Vector3, b: Vector3, col: Color = Color(0.55, 0.85, 1.8), life: float = 0.22) -> void:
	const SEGS := 6
	var prev := a
	for i in range(1, SEGS + 1):
		var cur := b if i == SEGS else (a.lerp(b, float(i) / float(SEGS)) + Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.35), randf_range(-0.35, 0.35)))
		if _b_cnt < MAX_BOLTS:
			var idx := _b_cnt
			_b_cnt += 1
			_b_a[idx] = prev
			_b_b[idx] = cur
			_b_col[idx] = col
			_b_life[idx] = life
			_b_max_life[idx] = life
		prev = cur


# --- MultiMesh buffer writers ---
func _put_part(idx: int, sz: float, pos: Vector3, r: float, g: float, b: float, a: float) -> void:
	var off := idx * 16
	part_buf[off] = sz; part_buf[off + 1] = 0.0; part_buf[off + 2] = 0.0; part_buf[off + 3] = pos.x
	part_buf[off + 4] = 0.0; part_buf[off + 5] = sz; part_buf[off + 6] = 0.0; part_buf[off + 7] = pos.y
	part_buf[off + 8] = 0.0; part_buf[off + 9] = 0.0; part_buf[off + 10] = sz; part_buf[off + 11] = pos.z
	part_buf[off + 12] = r; part_buf[off + 13] = g; part_buf[off + 14] = b; part_buf[off + 15] = a


func _put_bolt(idx: int, basis: Basis, pos: Vector3, col: Color) -> void:
	var off := idx * 16
	bolt_buf[off] = basis.x.x; bolt_buf[off + 1] = basis.y.x; bolt_buf[off + 2] = basis.z.x; bolt_buf[off + 3] = pos.x
	bolt_buf[off + 4] = basis.x.y; bolt_buf[off + 5] = basis.y.y; bolt_buf[off + 6] = basis.z.y; bolt_buf[off + 7] = pos.y
	bolt_buf[off + 8] = basis.x.z; bolt_buf[off + 9] = basis.y.z; bolt_buf[off + 10] = basis.z.z; bolt_buf[off + 11] = pos.z
	bolt_buf[off + 12] = col.r; bolt_buf[off + 13] = col.g; bolt_buf[off + 14] = col.b; bolt_buf[off + 15] = col.a


func _put_flame(idx: int, sx: float, sy: float, pos: Vector3, cd0: float, cd1: float) -> void:
	var off := idx * 16
	flame_buf[off] = sx; flame_buf[off + 1] = 0.0; flame_buf[off + 2] = 0.0; flame_buf[off + 3] = pos.x
	flame_buf[off + 4] = 0.0; flame_buf[off + 5] = sy; flame_buf[off + 6] = 0.0; flame_buf[off + 7] = pos.y
	flame_buf[off + 8] = 0.0; flame_buf[off + 9] = 0.0; flame_buf[off + 10] = 1.0; flame_buf[off + 11] = pos.z
	flame_buf[off + 12] = cd0; flame_buf[off + 13] = cd1; flame_buf[off + 14] = 0.0; flame_buf[off + 15] = 1.0


# --- Per-frame update ---
func update_fx(dt: float, t: float, focus: Vector3) -> void:
	_update_beacon_and_env(dt, t)
	_update_lights(dt, t, focus)
	_update_particles_and_coins(dt)
	_update_bolts(dt)
	_update_flames(t)
	_update_decals_and_rings(dt)


func _update_beacon_and_env(dt: float, t: float) -> void:
	beacon_gutter = maxf(0.0, beacon_gutter - dt * 1.6)
	var flick := 0.86 + 0.10 * CWUtil.n1(t * 6.3, 1.0) + 0.06 * CWUtil.n1(t * 17.0, 2.0)
	var lvl := beacon_level * beacon_on * (1.0 - 0.5 * beacon_gutter)
	beacon_light.position = beacon_pos + Vector3(CWUtil.n1(t * 5.0, 3.0) * 0.12, 1.65 + CWUtil.n1(t * 4.0, 4.0) * 0.10, CWUtil.n1(t * 5.0, 5.0) * 0.12)
	beacon_light.light_energy = 175.0 * beacon_mul * beacon_on * (0.35 + 0.65 * lvl) * flick

	beacon_flame_root.position = beacon_pos + Vector3(0.0, 0.05, 0.0)
	var f_sc := clampf(beacon_on * (0.45 + 0.55 * lvl), 0.0, 1.12) * (0.94 + 0.08 * flick)
	beacon_flame_root.visible = f_sc > 0.02
	beacon_flame_root.scale = Vector3(f_sc, f_sc, f_sc)
	for fm in beacon_flame_mats:
		fm.set_shader_parameter("u_intensity", 1.05 * beacon_on * flick)
	if beacon_halo_mat != null:
		beacon_halo_mat.set_shader_parameter("u_intensity", 0.36 * beacon_on * (0.45 + 0.55 * lvl) * flick)

	for li in range(lantern_flames.size()):
		if li < keep_fires.size():
			lantern_flames[li].visible = true
			lantern_flames[li].position = keep_fires[li] + Vector3(0.0, 0.16, 0.0)
		else:
			lantern_flames[li].visible = false

	if beacon_on > 0.2:
		if randf() < dt * 22.0 * beacon_on:
			spawn_flame_puff(beacon_pos + Vector3(randf_range(-0.35, 0.35), randf_range(0.2, 1.4), randf_range(-0.35, 0.35)), 0.60 * beacon_on)
		if randf() < dt * 5.0 * beacon_on:
			_add_part(
				beacon_pos + Vector3(randf_range(-0.45, 0.45), randf_range(2.2, 2.8), randf_range(-0.45, 0.45)),
				Vector3(randf_range(-0.35, 0.35), randf_range(1.0, 1.7), randf_range(-0.35, 0.35)),
				Color(0.95, 0.58, 0.24, 0.34), randf_range(0.75, 1.25), randf_range(2.2, 3.6), 3.6, -0.35, 1.6
			)

	beacon_embers_gpu.position = beacon_pos + Vector3(0.0, 0.25, 0.0)
	beacon_embers_gpu.emitting = beacon_on > 0.2
	waterfall_gpu.position = waterfall_pos + Vector3(0.0, 0.15, 0.05)
	waterfall_gpu.emitting = has_waterfall and biome_key != "frost"

	if not pond_centers.is_empty() and beacon_on > 0.2 and _p_cnt < MAX_PARTS:
		if biome_key == "ember" and randf() < dt * 10.0:
			var pc: Vector3 = pond_centers[randi() % pond_centers.size()]
			_add_part(
				pc + Vector3(randf_range(-1.2, 1.2), 0.12, randf_range(-1.2, 1.2)),
				Vector3(randf_range(-0.3, 0.3), randf_range(0.8, 1.9), randf_range(-0.3, 0.3)),
				Color(2.5, 0.82, 0.14, 0.92), randf_range(0.08, 0.16), randf_range(0.9, 1.8), 1.8, -0.35, 0.0
			)
		elif biome_key == "fen" and randf() < dt * 5.0:
			var pc: Vector3 = pond_centers[randi() % pond_centers.size()]
			_add_part(
				pc + Vector3(randf_range(-1.3, 1.3), 0.18, randf_range(-1.3, 1.3)),
				Vector3(randf_range(-0.2, 0.2), randf_range(0.25, 0.55), randf_range(-0.2, 0.2)),
				Color(0.28, 0.62, 0.42, 0.26), randf_range(0.45, 0.85), randf_range(1.6, 2.8), 2.8, -0.05, 0.9
			)

	if beacon_on > 0.3:
		for kf in keep_fires:
			if randf() < dt * 6.0:
				spawn_flame_puff(kf, 0.18)

	if wx_mat != null:
		var want_wx := 1.0 if (beacon_on > 0.05 or has_waterfall) else 0.0
		wx_fade = CWUtil.damp(wx_fade, want_wx, 2.5 if want_wx < 0.5 else 0.9, dt)
		wx_mat.set_shader_parameter("u_fade", wx_fade)

	shake_mag = maxf(0.0, shake_mag - dt * 2.6)
	var sh := shake_mag * shake_mag * 0.22
	shake_offset = Vector2(CWUtil.n1(t * 31.0, 7.0), CWUtil.n1(t * 37.0, 9.0)) * sh if sh > 1e-5 else Vector2.ZERO


func _update_lights(dt: float, t: float, focus: Vector3) -> void:
	for f in flash_pool:
		var l: OmniLight3D = f["light"]
		if float(f["t"]) < 1.0:
			f["t"] = float(f["t"]) + dt / float(f["dur"])
			var k := maxf(0.0, 1.0 - float(f["t"]))
			l.light_energy = float(f["energy"]) * k * k
		else:
			l.light_energy = 0.0

	# Insertion-sort active tower emitters by distance to focus (zero lambda/array alloc)
	_active_emitters.clear()
	var an := 0
	for e in emitters:
		if e["alive"]:
			var d2 := (e["pos"] as Vector3).distance_squared_to(focus)
			_active_emitters.append(e)
			if _active_d2.size() <= an:
				_active_d2.resize(an + 8)
			_active_d2[an] = d2
			var j := an
			while j > 0 and _active_d2[j - 1] > d2:
				_active_d2[j] = _active_d2[j - 1]
				_active_emitters[j] = _active_emitters[j - 1]
				j -= 1
			_active_d2[j] = d2
			_active_emitters[j] = e
			an += 1

	var spot_n := spot_pool.size()
	for i in range(tower_lights.size()):
		var ol := tower_lights[i]
		if i < an:
			var e := _active_emitters[i]
			var fl := 0.88 + 0.12 * CWUtil.n1(t * 7.5 + float(e["seed"]), float(e["seed"]))
			ol.position = e["pos"]
			ol.light_color = e["col"]
			ol.omni_range = float(e["range"]) * 0.95
			ol.light_energy = float(e["energy"]) * 0.68 * fl * (0.42 if i < spot_n else 1.0)
		else:
			ol.light_energy = 0.0

	for i in range(spot_n):
		var sp: SpotLight3D = spot_pool[i]["light"]
		if i < an:
			var e := _active_emitters[i]
			sp.position = (e["pos"] as Vector3) + Vector3(0, 0.35, 0)
			sp.look_at((e["pos"] as Vector3) + Vector3(0.2, -3.5, 0.2), Vector3.UP)
			sp.light_color = e["col"]
			sp.light_energy = float(e["energy"]) * 0.72
		else:
			sp.light_energy = 0.0

	# O(N) top-K selection for closest handheld torches (zero sort, zero lambda)
	var k_lim := torch_lights.size()
	var k_got := 0
	for ti in range(torch_positions.size()):
		var d2 := torch_positions[ti].distance_squared_to(focus)
		if k_got < k_lim:
			var j := k_got
			while j > 0 and _top_torch_d2[j - 1] > d2:
				_top_torch_d2[j] = _top_torch_d2[j - 1]
				_top_torch_idx[j] = _top_torch_idx[j - 1]
				j -= 1
			_top_torch_d2[j] = d2
			_top_torch_idx[j] = ti
			k_got += 1
		elif d2 < _top_torch_d2[k_lim - 1]:
			var j := k_lim - 1
			while j > 0 and _top_torch_d2[j - 1] > d2:
				_top_torch_d2[j] = _top_torch_d2[j - 1]
				_top_torch_idx[j] = _top_torch_idx[j - 1]
				j -= 1
			_top_torch_d2[j] = d2
			_top_torch_idx[j] = ti

	for i in range(k_lim):
		var tl := torch_lights[i]
		if i < k_got:
			tl.position = torch_positions[_top_torch_idx[i]] + Vector3(0.0, 0.36, 0.0)
			tl.omni_range = 8.2
			tl.omni_attenuation = 1.15
			tl.light_energy = 3.15 * (0.86 + 0.14 * CWUtil.n1(t * 11.0 + float(i) * 3.1, float(i)))
		else:
			tl.light_energy = 0.0

	for i in range(env_lights.size()):
		var el := env_lights[i]
		if i < env_srcs.size():
			var src := env_srcs[i]
			el.position = src["pos"]
			el.light_color = src["col"]
			el.omni_range = float(src["range"])
			var flk := (0.82 + 0.18 * CWUtil.n1(t * 1.7 + float(i) * 5.0, float(i) + 11.0)) if bool(src.get("flick", false)) else 1.0
			el.light_energy = float(src["energy"]) * flk * beacon_on
		else:
			el.light_energy = 0.0


func _update_particles_and_coins(dt: float) -> void:
	var i := 0
	while i < _p_cnt:
		var life := _p_life[i] - dt
		if life <= 0.0:
			_p_cnt -= 1
			if i < _p_cnt:
				_p_pos[i] = _p_pos[_p_cnt]
				_p_vel[i] = _p_vel[_p_cnt]
				_p_col[i] = _p_col[_p_cnt]
				_p_life[i] = _p_life[_p_cnt]
				_p_max_life[i] = _p_max_life[_p_cnt]
				_p_size[i] = _p_size[_p_cnt]
				_p_grav[i] = _p_grav[_p_cnt]
				_p_grow[i] = _p_grow[_p_cnt]
		else:
			_p_life[i] = life
			var v := _p_vel[i]
			v.y -= _p_grav[i] * dt
			_p_vel[i] = v
			var p := _p_pos[i] + v * dt
			_p_pos[i] = p
			var a := clampf(life / _p_max_life[i], 0.0, 1.0)
			var sz := _p_size[i] * (0.4 + 0.6 * a) * (1.0 + _p_grow[i] * (1.0 - a))
			var c := _p_col[i]
			_put_part(i, sz, p, c.r, c.g, c.b, c.a * a)
			i += 1

	var p_vis := _p_cnt
	var ci := 0
	while ci < _c_cnt:
		var life := _c_life[ci] - dt
		if life <= 0.0:
			_c_cnt -= 1
			if ci < _c_cnt:
				_c_pos[ci] = _c_pos[_c_cnt]
				_c_vel[ci] = _c_vel[_c_cnt]
				_c_life[ci] = _c_life[_c_cnt]
		else:
			_c_life[ci] = life
			var cv := _c_vel[ci]
			cv.y -= 14.0 * dt
			var cp := _c_pos[ci] + cv * dt
			if cp.y < 0.12:
				cp.y = 0.12
				cv.y = absf(cv.y) * 0.45
			_c_vel[ci] = cv
			_c_pos[ci] = cp
			if p_vis < MAX_PARTS:
				_put_part(p_vis, 0.18, cp, 1.6, 1.25, 0.25, clampf(life * 2.0, 0.0, 1.0))
				p_vis += 1
			ci += 1

	if p_vis > 0:
		part_mm.buffer = part_buf
	part_mm.visible_instance_count = p_vis


func _update_bolts(dt: float) -> void:
	var i := 0
	while i < _b_cnt:
		var life := _b_life[i] - dt
		if life <= 0.0:
			_b_cnt -= 1
			if i < _b_cnt:
				_b_a[i] = _b_a[_b_cnt]
				_b_b[i] = _b_b[_b_cnt]
				_b_col[i] = _b_col[_b_cnt]
				_b_life[i] = _b_life[_b_cnt]
				_b_max_life[i] = _b_max_life[_b_cnt]
		else:
			_b_life[i] = life
			var pa := _b_a[i]
			var pb := _b_b[i]
			var d := pb - pa
			var length := maxf(d.length(), 0.01)
			var dn := d / length
			var up_v := Vector3.FORWARD if absf(dn.y) > 0.98 else Vector3.UP
			var w := 0.09 * clampf(life / _b_max_life[i], 0.2, 1.0)
			_put_bolt(i, Basis.looking_at(dn, up_v).scaled_local(Vector3(w, w, length)), (pa + pb) * 0.5, _b_col[i])
			i += 1
	if _b_cnt > 0:
		bolt_mm.buffer = bolt_buf
	bolt_mm.visible_instance_count = _b_cnt


func _update_flames(t: float) -> void:
	var f_idx := 0
	for df in dynamic_flames:
		if f_idx >= MAX_FLAMES:
			break
		var fp: Vector3 = df["pos"]
		var fw := float(df["w"])
		var fh := float(df["h"])
		var fseed := float(df["seed"])
		var flk := 0.88 + 0.16 * CWUtil.n1(t * 9.5 + fseed * 3.1, fseed)
		var f_int := float(df.get("intensity", 0.95)) * 0.88 * flk * beacon_on
		_put_flame(f_idx, fw, fh * flk, fp + Vector3(0.0, fh * 0.38, 0.0), fseed, f_int)
		f_idx += 1
	for ti in range(torch_positions.size()):
		if f_idx >= MAX_FLAMES:
			break
		var tseed := 17.0 + float(ti) * 2.7
		var tflk := 0.86 + 0.18 * CWUtil.n1(t * 11.0 + tseed * 2.3, tseed)
		_put_flame(f_idx, 0.42, 0.62 * tflk, torch_positions[ti] + Vector3(0.0, 0.18, 0.0), tseed, 1.12 * tflk * beacon_on)
		f_idx += 1
	for ki in range(2, keep_fires.size()):
		if f_idx >= MAX_FLAMES:
			break
		var kseed := 31.0 + float(ki) * 3.3
		var kflk := 0.88 + 0.16 * CWUtil.n1(t * 9.0 + kseed * 1.9, kseed)
		_put_flame(f_idx, 0.36, 0.58 * kflk, keep_fires[ki] + Vector3(0.0, 0.20, 0.0), kseed, 0.94 * kflk * beacon_on)
		f_idx += 1
	if f_idx > 0:
		flame_mm.buffer = flame_buf
	flame_mm.visible_instance_count = f_idx


func _update_decals_and_rings(dt: float) -> void:
	var di := 0
	while di < _d_cnt:
		var life := _d_life[di] - dt
		if life <= 0.0:
			_d_cnt -= 1
			if di < _d_cnt:
				_d_pos[di] = _d_pos[_d_cnt]
				_d_col[di] = _d_col[_d_cnt]
				_d_size[di] = _d_size[_d_cnt]
				_d_life[di] = _d_life[_d_cnt]
		else:
			_d_life[di] = life
			var a := clampf(life / 3.0, 0.0, 1.0)
			var c := _d_col[di]
			var sz := _d_size[di]
			decal_mm.set_instance_transform(di, Transform3D(Basis.IDENTITY.scaled(Vector3(sz, 1.0, sz)), _d_pos[di]))
			decal_mm.set_instance_color(di, Color(c.r, c.g, c.b, c.a * a))
			di += 1
	decal_mm.visible_instance_count = _d_cnt

	var ri := 0
	while ri < _r_cnt:
		var u := _r_t[ri] + dt / _r_dur[ri]
		if u >= 1.0:
			_r_cnt -= 1
			if ri < _r_cnt:
				_r_pos[ri] = _r_pos[_r_cnt]
				_r_col[ri] = _r_col[_r_cnt]
				_r_max[ri] = _r_max[_r_cnt]
				_r_t[ri] = _r_t[_r_cnt]
				_r_dur[ri] = _r_dur[_r_cnt]
		else:
			_r_t[ri] = u
			var rad := lerpf(0.35, _r_max[ri], 1.0 - (1.0 - u) * (1.0 - u))
			var c := _r_col[ri]
			ring_mm.set_instance_transform(ri, Transform3D(Basis.IDENTITY.scaled(Vector3(rad, 1.0, rad)), _r_pos[ri]))
			ring_mm.set_instance_color(ri, Color(c.r, c.g, c.b, c.a * (1.0 - u)))
			ri += 1
	ring_mm.visible_instance_count = _r_cnt


func clear_fx() -> void:
	_p_cnt = 0
	_c_cnt = 0
	_b_cnt = 0
	_d_cnt = 0
	_r_cnt = 0
	if part_mm != null: part_mm.visible_instance_count = 0
	if bolt_mm != null: bolt_mm.visible_instance_count = 0
	dynamic_flames.clear()
	if flame_mm != null: flame_mm.visible_instance_count = 0
	if decal_mm != null: decal_mm.visible_instance_count = 0
	if ring_mm != null: ring_mm.visible_instance_count = 0
	for e in emitters:
		e["alive"] = false
	emitters.clear()
	for ol in tower_lights:
		ol.light_energy = 0.0
	for tl in torch_lights:
		tl.light_energy = 0.0
	torch_positions.clear()
	for el in env_lights:
		el.light_energy = 0.0
	env_srcs.clear()
	keep_fires.clear()
	pond_centers.clear()
	has_waterfall = false
	beacon_on = 0.0
	if beacon_light != null:
		beacon_light.light_energy = 0.0
	if beacon_flame_root != null:
		beacon_flame_root.visible = false
	for lmi in lantern_flames:
		lmi.visible = false
	for f in flash_pool:
		f["t"] = 1.0
		(f["light"] as OmniLight3D).light_energy = 0.0
	for s in spot_pool:
		(s["light"] as SpotLight3D).light_energy = 0.0
	wx_fade = 0.0
	if wx_mat != null:
		wx_mat.set_shader_parameter("u_fade", 0.0)


func set_crowd_shadow_lod(high_crowd: bool) -> void:
	if _spot_shadow_off == high_crowd:
		return
	_spot_shadow_off = high_crowd
	for s: Dictionary in spot_pool:
		(s["light"] as SpotLight3D).shadow_enabled = not high_crowd
