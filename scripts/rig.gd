class_name CWRig
extends Node3D

# Resource-driven GPU Procedural Skeletal Batcher & Shatter Debris
# Loads pre-baked 3D ArrayMesh assets from res://assets/models/units/*.res
# and animates all units on GPU via shaders/lit_unit.gdshader (1 instance = 1 unit).


class PartBatch:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap: int
	var count: int = 0
	var buf: PackedFloat32Array = PackedFloat32Array()

	func _init(parent: Node3D, mesh: Mesh, mat: Material, p_cap: int) -> void:
		cap = p_cap
		buf.resize(cap * 20)
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)

	func begin() -> void:
		count = 0

	func put(xf: Transform3D, col: Color, flash: float = 0.0) -> void:
		if count >= cap:
			return
		var off := count * 20
		var b := xf.basis
		var o := xf.origin
		buf[off] = b.x.x; buf[off + 1] = b.y.x; buf[off + 2] = b.z.x; buf[off + 3] = o.x
		buf[off + 4] = b.x.y; buf[off + 5] = b.y.y; buf[off + 6] = b.z.y; buf[off + 7] = o.y
		buf[off + 8] = b.x.z; buf[off + 9] = b.y.z; buf[off + 10] = b.z.z; buf[off + 11] = o.z
		buf[off + 12] = col.r; buf[off + 13] = col.g; buf[off + 14] = col.b; buf[off + 15] = col.a
		buf[off + 16] = flash; buf[off + 17] = 0.0; buf[off + 18] = 0.0; buf[off + 19] = 0.0
		count += 1

	func end() -> void:
		if count > 0:
			mm.buffer = buf
		mm.visible_instance_count = count


class UnitBatch:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap: int
	var count: int = 0
	var is_boss: bool = false
	var buf: PackedFloat32Array = PackedFloat32Array()

	func _init(parent: Node3D, mesh: Mesh, mat: Material, p_cap: int, p_is_boss: bool = false) -> void:
		cap = p_cap
		is_boss = p_is_boss
		buf.resize(cap * 20)
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.extra_cull_margin = 64.0
		parent.add_child(mmi)

	func begin() -> void:
		count = 0

	func _grow() -> void:
		var new_cap := mini(cap * 2, 4096)
		if new_cap <= cap:
			return
		cap = new_cap
		buf.resize(cap * 20)
		mm.instance_count = cap

	func push_cs(x: float, y: float, z: float, cy: float, sy: float, sc: float, cr: float, cg: float, cb: float, phase: float, swing: float, flash: float, mv: float) -> void:
		if count >= cap:
			_grow()
			if count >= cap:
				return
		var off := count * 20
		var c := cy * sc
		var s := sy * sc
		buf[off] = c; buf[off + 1] = 0.0; buf[off + 2] = s; buf[off + 3] = x
		buf[off + 4] = 0.0; buf[off + 5] = sc; buf[off + 6] = 0.0; buf[off + 7] = y
		buf[off + 8] = -s; buf[off + 9] = 0.0; buf[off + 10] = c; buf[off + 11] = z
		buf[off + 12] = cr; buf[off + 13] = cg; buf[off + 14] = cb; buf[off + 15] = 1.0
		buf[off + 16] = phase; buf[off + 17] = swing; buf[off + 18] = flash; buf[off + 19] = mv
		count += 1

	func end() -> void:
		if count > 0:
			mm.buffer = buf
		mm.visible_instance_count = count


var gfx: CWGfx
var debris_box: PartBatch
var debris_sph: PartBatch
var unit_batches: Dictionary = {}
var debris: Array[Dictionary] = []
var last_torch_pos: Vector3 = Vector3.ZERO
var _crowd_shadow_off: bool = false

var glow_mmi: MultiMeshInstance3D
var glow_mm: MultiMesh
var glow_count: int = 0
var glow_buf: PackedFloat32Array = PackedFloat32Array()
const MAX_GLOW := 1600


func init_kits(p_gfx: CWGfx) -> void:
	gfx = p_gfx
	var s_box := CWGfx.Soup.new()
	s_box.add_box(Vector3.ONE, Vector3.ZERO, Color.WHITE, CWGfx.L_PLAIN, 0.85)
	debris_box = PartBatch.new(self, s_box.build(), gfx.mat_inst, 512)

	var s_sph := CWGfx.Soup.new()
	s_sph.add_rock(0.5, Vector3.ZERO, Color.WHITE, 42, CWGfx.L_PLAIN, 0.82)
	debris_sph = PartBatch.new(self, s_sph.build(), gfx.mat_inst, 512)

	# Additive billboard MultiMesh for glowing monster eyes & pad halos
	var g_mat := StandardMaterial3D.new()
	g_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	g_mat.billboard_keep_scale = true
	g_mat.vertex_color_use_as_albedo = true
	g_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	g_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gi := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for gy in range(16):
		for gx in range(16):
			var dx := (float(gx) + 0.5) / 8.0 - 1.0
			var dy := (float(gy) + 0.5) / 8.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var w := pow(clampf(1.0 - r, 0.0, 1.0), 2.4)
			gi.set_pixel(gx, gy, Color(w, w, w, w))
	g_mat.albedo_texture = ImageTexture.create_from_image(gi)
	var gq := QuadMesh.new()
	gq.size = Vector2.ONE
	glow_mm = MultiMesh.new()
	glow_mm.transform_format = MultiMesh.TRANSFORM_3D
	glow_mm.use_colors = true
	glow_mm.mesh = gq
	glow_buf.resize(MAX_GLOW * 16)
	glow_mm.instance_count = MAX_GLOW
	glow_mm.visible_instance_count = 0
	glow_mmi = MultiMeshInstance3D.new()
	glow_mmi.multimesh = glow_mm
	glow_mmi.material_override = g_mat
	glow_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow_mmi)


func _get_unit_batch(key: String, cap: int = 128, p_is_boss: bool = false) -> UnitBatch:
	if unit_batches.has(key):
		return unit_batches[key] as UnitBatch
	var mesh := load("res://assets/models/units/%s.res" % key) as Mesh
	if mesh == null:
		push_warning("Missing unit model: res://assets/models/units/%s.res" % key)
		mesh = BoxMesh.new()
	var ub := UnitBatch.new(self, mesh, gfx.mat_unit, cap, p_is_boss)
	if _crowd_shadow_off and not p_is_boss:
		ub.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	unit_batches[key] = ub
	return ub


func set_crowd_shadow_lod(high_crowd: bool) -> void:
	if _crowd_shadow_off == high_crowd:
		return
	_crowd_shadow_off = high_crowd
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if high_crowd else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for ub_v in unit_batches.values():
		var ub: UnitBatch = ub_v
		if not ub.is_boss:
			ub.mmi.cast_shadow = mode


func get_gpu_unit_count() -> int:
	var tot := 0
	for ub_v in unit_batches.values():
		tot += (ub_v as UnitBatch).count
	return tot


func begin_frame() -> void:
	debris_box.begin()
	debris_sph.begin()
	for ub_v in unit_batches.values():
		(ub_v as UnitBatch).begin()
	glow_count = 0


func end_frame() -> void:
	debris_box.end()
	debris_sph.end()
	for ub_v in unit_batches.values():
		(ub_v as UnitBatch).end()
	if glow_mm != null:
		if glow_count > 0:
			glow_mm.buffer = glow_buf
		glow_mm.visible_instance_count = glow_count


func push_glow(pos: Vector3, col: Color, size: float, alpha: float = 1.0) -> void:
	push_glow_xyz(pos.x, pos.y, pos.z, col.r, col.g, col.b, size, alpha)


func push_glow_xyz(px: float, py: float, pz: float, r: float, g: float, b: float, size: float, alpha: float = 1.0) -> void:
	if glow_mm == null or glow_count >= MAX_GLOW:
		return
	var off := glow_count * 16
	glow_buf[off] = size; glow_buf[off + 1] = 0.0; glow_buf[off + 2] = 0.0; glow_buf[off + 3] = px
	glow_buf[off + 4] = 0.0; glow_buf[off + 5] = size; glow_buf[off + 6] = 0.0; glow_buf[off + 7] = py
	glow_buf[off + 8] = 0.0; glow_buf[off + 9] = 0.0; glow_buf[off + 10] = size; glow_buf[off + 11] = pz
	glow_buf[off + 12] = r * alpha; glow_buf[off + 13] = g * alpha; glow_buf[off + 14] = b * alpha; glow_buf[off + 15] = 1.0
	glow_count += 1


func bind_monster_batch(m: CWMonsterUnit) -> UnitBatch:
	var key: String = m.type + ("_t" if m.torch else "")
	m.ub = _get_unit_batch(key, 16 if m.is_boss else 128, m.is_boss)
	return m.ub


func push_monster_gpu(m: CWMonsterUnit, cy: float = 2.0, sy: float = 0.0) -> void:
	var ub: UnitBatch = m.ub
	if ub == null:
		ub = bind_monster_batch(m)
	var cr := 1.0
	var cg := 1.0
	var cb := 1.0
	if m.faded:
		cr = 0.45; cg = 1.0; cb = 1.18
	elif m.slow_t > 0.0:
		cr = 0.62; cg = 0.92; cb = 1.15
	var sc: float = m.unit_scale
	var ph: float = m.phase * 2.0 if m.rig_is_fly else m.phase
	var mv_enc: float = (2.0 + m.cast) if m.cast > 0.01 else m.mv
	if cy > 1.5:
		cy = cos(m.yaw)
		sy = sin(m.yaw)
	ub.push_cs(m.x, m.y, m.z, cy, sy, sc, cr, cg, cb, ph, m.swing, m.flash, mv_enc)

	if m.torch:
		var lx := -0.22 * sc
		var lz := 0.30 * sc
		last_torch_pos = Vector3(m.x + cy * lx + sy * lz, m.y + 1.05 * sc, m.z - sy * lx + cy * lz)
	if m.has_eye and glow_count < MAX_GLOW:
		var ec := m.eye_col
		push_glow_xyz(m.x + sy * m.eye_z, m.y + m.eye_y, m.z + cy * m.eye_z, ec.r, ec.g, ec.b, 0.34 * sc, 0.24)


func push_footman_gpu(f: CWFootmanUnit) -> void:
	var key := "footman_t" if f.torch else "footman_s"
	var ub := _get_unit_batch(key, 64, false)
	var sc := 0.90 + float(f.tower["lvl"]) * 0.05
	var cy := cos(f.yaw)
	var sy := sin(f.yaw)
	ub.push_cs(f.x, f.y, f.z, cy, sy, sc, 1.0, 1.0, 1.0, f.phase, f.swing, f.flash, f.mv)
	if f.torch:
		var lx := -0.22 * sc
		var lz := 0.30 * sc
		last_torch_pos = Vector3(f.x + cy * lx + sy * lz, f.y + 1.05 * sc, f.z - sy * lx + cy * lz)


func push_archer_gpu(pos: Vector3, yaw: float, draw_amt: float) -> void:
	var ub := _get_unit_batch("archer", 64, false)
	ub.push_cs(pos.x, pos.y, pos.z, cos(yaw), sin(yaw), 0.72, 1.0, 1.0, 1.0, 0.0, draw_amt * 0.35, 0.0, 0.0)


func shatter_unit(pos: Vector3, scale_v: float, col: Color, impulse: Vector3, is_boss: bool = false) -> void:
	var n := 22 if is_boss else 9
	for i in range(n):
		if debris.size() > 260:
			break
		var sz := randf_range(0.08, 0.24) * scale_v
		var p := pos + Vector3(randf_range(-0.22, 0.22) * scale_v, randf_range(0.15, 0.95) * scale_v, randf_range(-0.22, 0.22) * scale_v)
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3(sz, sz * randf_range(0.6, 1.6), sz))
		var c := col.darkened(randf_range(0.0, 0.28)) if (i & 1) == 0 else col.lightened(randf_range(0.0, 0.14))
		debris.append({
			"sph": (i % 3) == 0,
			"xf": Transform3D(b, p),
			"col": c,
			"vel": impulse + Vector3(randf_range(-2.2, 2.2), randf_range(2.2, 5.2), randf_range(-2.2, 2.2)),
			"spin": Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"life": randf_range(0.8, 1.6),
		})


func update_debris(dt: float, terrain: CWTerrain) -> void:
	var i := debris.size() - 1
	while i >= 0:
		var d: Dictionary = debris[i]
		d["life"] = float(d["life"]) - dt
		if float(d["life"]) <= 0.0:
			debris.remove_at(i)
			i -= 1
			continue
		var vel: Vector3 = d["vel"]
		vel.y -= 15.0 * dt
		var xf: Transform3D = d["xf"]
		xf.origin += vel * dt
		var gy := terrain.height_at(xf.origin.x, xf.origin.z) + 0.06
		if xf.origin.y < gy:
			xf.origin.y = gy
			vel.y = absf(vel.y) * 0.38
			vel.x *= 0.65
			vel.z *= 0.65
		var sp: Vector3 = d["spin"]
		xf.basis = xf.basis.rotated(Vector3.RIGHT, sp.x * dt).rotated(Vector3.UP, sp.y * dt)
		d["vel"] = vel
		d["xf"] = xf
		var shrink := clampf(float(d["life"]) * 2.5, 0.0, 1.0)
		var draw_xf := Transform3D(xf.basis.scaled(Vector3.ONE * shrink), xf.origin)
		if bool(d["sph"]):
			debris_sph.put(draw_xf, d["col"], 0.0)
		else:
			debris_box.put(draw_xf, d["col"], 0.0)
		i -= 1


func clear_debris() -> void:
	debris.clear()
