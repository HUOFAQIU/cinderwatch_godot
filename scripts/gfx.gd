class_name CWGfx
extends RefCounted

# Procedural Texture2DArray generator, fast ArrayMesh Soup builder, and ShaderMaterials
# Ported from 10-gfx.js

const L_DIRT := 0
const L_ROCK := 1
const L_MASON := 2
const L_WOOD := 3
const L_COBBLE := 4
const L_METAL := 5
const L_SLATE := 6
const L_CLOTH := 7
const L_PLAIN := 8
const L_BARK := 9
const L_LEAF := 10
const TEX_LAYERS := 11
const TEX_N := 64

var tex_albedo: Texture2DArray
var tex_height: Texture2DArray
var mat_world: ShaderMaterial
var mat_inst: ShaderMaterial
var mat_unit: ShaderMaterial
var mat_water: ShaderMaterial
var mat_fall: ShaderMaterial


func init_resources() -> void:
	_make_detail_textures()
	var sh_world: Shader = load("res://shaders/lit_world.gdshader")
	var sh_water: Shader = load("res://shaders/lit_water.gdshader")

	mat_world = ShaderMaterial.new()
	mat_world.shader = sh_world
	mat_world.set_shader_parameter("u_tex_a", tex_albedo)
	mat_world.set_shader_parameter("u_tex_h", tex_height)
	mat_world.set_shader_parameter("u_bump", 0.055)
	mat_world.set_shader_parameter("u_is_instanced", false)

	mat_inst = ShaderMaterial.new()
	mat_inst.shader = sh_world
	mat_inst.set_shader_parameter("u_tex_a", tex_albedo)
	mat_inst.set_shader_parameter("u_tex_h", tex_height)
	mat_inst.set_shader_parameter("u_bump", 0.045)
	mat_inst.set_shader_parameter("u_is_instanced", true)

	var sh_unit := load("res://shaders/lit_unit.gdshader") as Shader
	mat_unit = ShaderMaterial.new()
	mat_unit.shader = sh_unit if sh_unit != null else sh_world
	mat_unit.set_shader_parameter("u_tex_a", tex_albedo)
	mat_unit.set_shader_parameter("u_tex_h", tex_height)
	mat_unit.set_shader_parameter("u_bump", 0.04)

	mat_water = ShaderMaterial.new()
	mat_water.shader = sh_water

	mat_fall = ShaderMaterial.new()
	mat_fall.shader = load("res://shaders/waterfall.gdshader")
	mat_fall.render_priority = 2


func apply_biome_uniforms(bio: Dictionary) -> void:
	mat_world.set_shader_parameter("u_wind", float(bio.get("wind", 1.0)))
	mat_world.set_shader_parameter("u_cover", bio.get("cover", Vector4(0, 0.55, 0.3, 0.5)))
	mat_world.set_shader_parameter("u_cover_col", bio.get("cover_col", Vector3.ONE))
	mat_world.set_shader_parameter("u_cover_p", bio.get("cover_p", Vector4(0.7, 0.6, 0, 0)))

	mat_water.set_shader_parameter("u_wat", bio.get("wat", Vector4(0, 1, 1, 0)))
	mat_water.set_shader_parameter("u_wat_a", bio.get("wat_a", Vector3(0.012, 0.02, 0.03)))
	mat_water.set_shader_parameter("u_wat_b", bio.get("wat_b", Vector3(0.3, 0.4, 0.5)))
	var sky_c: Color = bio.get("sky", Color(0.012, 0.022, 0.045, 1.0))
	mat_water.set_shader_parameter("u_sky", Vector3(sky_c.r, sky_c.g, sky_c.b))
	if mat_fall != null:
		var bkey: String = String(bio.get("key", "ashen"))
		if bkey == "ember":
			mat_fall.set_shader_parameter("u_fp", Vector4(2.0, 0.55, 1.0, 0.0))
			mat_fall.set_shader_parameter("u_fa", Vector3(2.35, 0.72, 0.12))
			mat_fall.set_shader_parameter("u_fb", Vector3(0.18, 0.05, 0.02))
		elif bkey == "frost":
			mat_fall.set_shader_parameter("u_fp", Vector4(1.0, 0.0, 0.92, 0.0))
			mat_fall.set_shader_parameter("u_fa", Vector3(0.32, 0.52, 0.72))
			mat_fall.set_shader_parameter("u_fb", Vector3(0.78, 0.90, 1.0))
		elif bkey == "fen":
			mat_fall.set_shader_parameter("u_fp", Vector4(0.0, 0.85, 0.92, 0.0))
			mat_fall.set_shader_parameter("u_fa", Vector3(0.03, 0.07, 0.05))
			mat_fall.set_shader_parameter("u_fb", Vector3(0.24, 0.38, 0.30))
		else:
			mat_fall.set_shader_parameter("u_fp", Vector4(0.0, 1.0, 0.95, 0.0))
			mat_fall.set_shader_parameter("u_fa", Vector3(0.022, 0.034, 0.054))
			mat_fall.set_shader_parameter("u_fb", Vector3(0.32, 0.44, 0.60))


const LAYER_NAMES := [
	"00_dirt", "01_rock", "02_mason", "03_wood", "04_cobble",
	"05_metal", "06_slate", "07_cloth", "08_plain", "09_bark", "10_leaf"
]


func _load_layer_img(path: String) -> Image:
	var tex := load(path) as Texture2D
	var img: Image = tex.get_image() if tex != null else Image.create_empty(TEX_N, TEX_N, false, Image.FORMAT_RGBA8)
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return img


func _make_detail_textures() -> void:
	var imgs_a: Array[Image] = []
	var imgs_h: Array[Image] = []
	for nm: String in LAYER_NAMES:
		imgs_a.append(_load_layer_img("res://assets/textures/albedo_%s.png" % nm))
		imgs_h.append(_load_layer_img("res://assets/textures/height_%s.png" % nm))
	tex_albedo = Texture2DArray.new()
	tex_albedo.create_from_images(imgs_a)
	tex_height = Texture2DArray.new()
	tex_height.create_from_images(imgs_h)


class Soup:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var custom0: PackedFloat32Array = PackedFloat32Array()
	var vert_count: int = 0

	func add_v(pos: Vector3, nrm: Vector3, col: Color, uv: Vector2, layer: int = 8, rough: float = 0.85, sway: float = 0.0, emis: float = 0.0) -> void:
		verts.append(pos)
		norms.append(nrm)
		cols.append(col)
		uvs.append(uv)
		custom0.append(float(layer)); custom0.append(rough); custom0.append(sway); custom0.append(emis)
		vert_count += 1

	func add_tri(a: Vector3, b: Vector3, c: Vector3, col: Color, layer: int = 8, rough: float = 0.85, sway: float = 0.0, emis: float = 0.0, uv_scale: float = 0.5) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-10:
			return
		n = n.normalized()
		var fl := float(layer)
		var mode := 0 if absf(n.y) > 0.65 else (1 if absf(n.x) > 0.65 else 2)

		verts.append(a); verts.append(b); verts.append(c)
		norms.append(n); norms.append(n); norms.append(n)
		cols.append(col); cols.append(col); cols.append(col)

		if mode == 0:
			uvs.append(Vector2(a.x * uv_scale, a.z * uv_scale))
			uvs.append(Vector2(b.x * uv_scale, b.z * uv_scale))
			uvs.append(Vector2(c.x * uv_scale, c.z * uv_scale))
		elif mode == 1:
			uvs.append(Vector2(a.z * uv_scale, a.y * uv_scale))
			uvs.append(Vector2(b.z * uv_scale, b.y * uv_scale))
			uvs.append(Vector2(c.z * uv_scale, c.y * uv_scale))
		else:
			uvs.append(Vector2(a.x * uv_scale, a.y * uv_scale))
			uvs.append(Vector2(b.x * uv_scale, b.y * uv_scale))
			uvs.append(Vector2(c.x * uv_scale, c.y * uv_scale))

		for _k in range(3):
			custom0.append(fl); custom0.append(rough); custom0.append(sway); custom0.append(emis)
		vert_count += 3

	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, layer: int = 8, rough: float = 0.85, sway: float = 0.0, emis: float = 0.0, uv_scale: float = 0.5) -> void:
		add_tri(a, b, c, col, layer, rough, sway, emis, uv_scale)
		add_tri(a, c, d, col, layer, rough, sway, emis, uv_scale)

	func add_box(size: Vector3, pos: Vector3, col: Color, layer: int = 8, rough: float = 0.85, rot: Vector3 = Vector3.ZERO, sway: float = 0.0, emis: float = 0.0) -> void:
		var hx := size.x * 0.5
		var hy := size.y * 0.5
		var hz := size.z * 0.5
		var basis := Basis.from_euler(rot)
		var c0 := pos + basis * Vector3(-hx, -hy, -hz)
		var c1 := pos + basis * Vector3(hx, -hy, -hz)
		var c2 := pos + basis * Vector3(hx, hy, -hz)
		var c3 := pos + basis * Vector3(-hx, hy, -hz)
		var c4 := pos + basis * Vector3(-hx, -hy, hz)
		var c5 := pos + basis * Vector3(hx, -hy, hz)
		var c6 := pos + basis * Vector3(hx, hy, hz)
		var c7 := pos + basis * Vector3(-hx, hy, hz)
		add_quad(c7, c6, c5, c4, col, layer, rough, sway, emis) # +Z
		add_quad(c2, c3, c0, c1, col, layer, rough, sway, emis) # -Z
		add_quad(c6, c2, c1, c5, col, layer, rough, sway, emis) # +X
		add_quad(c3, c7, c4, c0, col, layer, rough, sway, emis) # -X
		add_quad(c3, c2, c6, c7, col, layer, rough, sway, emis) # +Y
		add_quad(c4, c5, c1, c0, col, layer, rough, sway, emis) # -Y

	func add_cyl(r_bot: float, r_top: float, h: float, pos: Vector3, col: Color, segs: int = 6, layer: int = 8, rough: float = 0.85, rot: Vector3 = Vector3.ZERO, sway: float = 0.0, emis: float = 0.0) -> void:
		var basis := Basis.from_euler(rot)
		var hy := h * 0.5
		var bot_c := pos + basis * Vector3(0, -hy, 0)
		var top_c := pos + basis * Vector3(0, hy, 0)
		for i in range(segs):
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var b0 := pos + basis * Vector3(cos(a0) * r_bot, -hy, sin(a0) * r_bot)
			var b1 := pos + basis * Vector3(cos(a1) * r_bot, -hy, sin(a1) * r_bot)
			var t0 := pos + basis * Vector3(cos(a0) * r_top, hy, sin(a0) * r_top)
			var t1 := pos + basis * Vector3(cos(a1) * r_top, hy, sin(a1) * r_top)
			if r_top > 0.001:
				add_quad(b0, b1, t1, t0, col, layer, rough, sway, emis)
				add_tri(top_c, t0, t1, col, layer, rough, sway, emis)
			else:
				add_tri(b0, b1, top_c, col, layer, rough, sway, emis)
			if r_bot > 0.001:
				add_tri(bot_c, b1, b0, col, layer, rough, sway, emis)

	func add_seg(p0: Vector3, p1: Vector3, r0: float, r1: float, col: Color, segs: int = 5, layer: int = 3, rough: float = 0.88, emis: float = 0.0) -> void:
		var d := p1 - p0
		var h := d.length()
		if h < 1e-4:
			return
		var up := d / h
		var ref := Vector3.RIGHT if absf(up.y) > 0.95 else Vector3.UP
		var right := up.cross(ref).normalized()
		var fwd := right.cross(up).normalized()
		var basis := Basis(right, up, fwd)
		var mid := (p0 + p1) * 0.5
		var hy := h * 0.5
		for i in range(segs):
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var b0 := mid + basis * Vector3(cos(a0) * r0, -hy, sin(a0) * r0)
			var b1 := mid + basis * Vector3(cos(a1) * r0, -hy, sin(a1) * r0)
			var t0 := mid + basis * Vector3(cos(a0) * r1, hy, sin(a0) * r1)
			var t1 := mid + basis * Vector3(cos(a1) * r1, hy, sin(a1) * r1)
			add_quad(b0, b1, t1, t0, col, layer, rough, 0.0, emis)

	func add_cone(r: float, h: float, pos: Vector3, col: Color, segs: int = 6, layer: int = 8, rough: float = 0.85, rot: Vector3 = Vector3.ZERO, sway: float = 0.0, emis: float = 0.0) -> void:
		add_cyl(r, 0.0, h, pos, col, segs, layer, rough, rot, sway, emis)

	func add_rock(r: float, pos: Vector3, col: Color, seed_val: int, layer: int = 1, rough: float = 0.92, scale_v: Vector3 = Vector3.ONE) -> void:
		# Closed, sculpted low-poly boulder (shared poles so top never rips into sharp spikes)
		var rng := CWUtil.Rng.new(seed_val)
		var stacks := 5
		var slices := 8
		var top_p := pos + Vector3(0.0, r * rng.rr(0.88, 1.10) * scale_v.y, 0.0)
		var bot_p := pos + Vector3(0.0, -r * rng.rr(0.88, 1.10) * scale_v.y, 0.0)
		var ring_pts: Array = []
		for st_i in range(1, stacks):
			var phi := PI * float(st_i) / float(stacks)
			var row: Array[Vector3] = []
			for sl_i in range(slices):
				var theta := TAU * float(sl_i) / float(slices)
				var jitter := rng.rr(0.86, 1.14)
				var p := Vector3(
					sin(phi) * cos(theta) * r * jitter * scale_v.x,
					cos(phi) * r * jitter * scale_v.y,
					sin(phi) * sin(theta) * r * jitter * scale_v.z
				) + pos
				row.append(p)
			ring_pts.append(row)
		# Top & bottom caps
		for sl_i in range(slices):
			var nsl := (sl_i + 1) % slices
			add_tri(top_p, ring_pts[0][sl_i], ring_pts[0][nsl], col, layer, rough)
			add_tri(bot_p, ring_pts[ring_pts.size() - 1][nsl], ring_pts[ring_pts.size() - 1][sl_i], col, layer, rough)
		# Middle bands
		for st_i in range(ring_pts.size() - 1):
			for sl_i in range(slices):
				var nsl := (sl_i + 1) % slices
				add_quad(ring_pts[st_i][sl_i], ring_pts[st_i + 1][sl_i], ring_pts[st_i + 1][nsl], ring_pts[st_i][nsl], col, layer, rough)

	func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if vert_count == 0:
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_CUSTOM0] = custom0
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		return mesh
