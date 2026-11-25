class_name CWPropLib
extends RefCounted

# Resource-driven 3D prop library: loads pre-baked res://assets/models/props/*.res
# and stamps vertices into chunk CWGfx.Soup meshes for batched rendering.

static var _cache: Dictionary = {}


static func _get_arrays(prop_name: String) -> Dictionary:
	if _cache.has(prop_name):
		return _cache[prop_name] as Dictionary
	var mesh := load("res://assets/models/props/%s.res" % prop_name) as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		push_warning("Missing prop model: res://assets/models/props/%s.res" % prop_name)
		_cache[prop_name] = {}
		return {}
	var arr := mesh.surface_get_arrays(0)
	var data := {
		"v": arr[Mesh.ARRAY_VERTEX] as PackedVector3Array,
		"n": arr[Mesh.ARRAY_NORMAL] as PackedVector3Array,
		"uv": arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array,
		"c": arr[Mesh.ARRAY_COLOR] as PackedColorArray,
		"c0": arr[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array,
	}
	_cache[prop_name] = data
	return data


static func stamp(soup: CWGfx.Soup, prop_name: String, pos: Vector3, yaw: float = 0.0, scale_v: float = 1.0) -> void:
	var data := _get_arrays(prop_name)
	if data.is_empty():
		return
	var pv: PackedVector3Array = data["v"]
	var pn: PackedVector3Array = data["n"]
	var puv: PackedVector2Array = data["uv"]
	var pc: PackedColorArray = data["c"]
	var pc0: PackedFloat32Array = data["c0"]
	var cy := cos(yaw)
	var sy := sin(yaw)
	var n := pv.size()
	for i in range(n):
		var v := pv[i] * scale_v
		var rv := Vector3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy) + pos
		var nm := pn[i]
		var rn := Vector3(nm.x * cy + nm.z * sy, nm.y, -nm.x * sy + nm.z * cy)
		soup.verts.append(rv)
		soup.norms.append(rn)
		soup.uvs.append(puv[i])
		soup.cols.append(pc[i])
		var ci := i * 4
		soup.custom0.append(pc0[ci])
		soup.custom0.append(pc0[ci + 1])
		soup.custom0.append(pc0[ci + 2])
		soup.custom0.append(pc0[ci + 3])
