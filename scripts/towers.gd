class_name CWTowers
extends Node3D

# 4 tower kinds x 3 levels with detailed medieval/fantasy architecture ported from 60-towers.js
# Piece-by-piece scaffolding build animation, flaming arrows, mortar shells, chain lightning, and guard footmen

const TOWER_KINDS := ["archer", "bombard", "spire", "guard"]

const DEFS := {
	"archer": {
		"name": "Archer Tower", "short": "Archers",
		"cost": [70, 90, 140], "range": [6.2, 6.8, 7.4], "dmg": [9.0, 11.0, 14.0],
		"rate": [0.85, 0.78, 0.70], "n": [1, 2, 3], "air": true, "ground": true,
		"light": [10.0, 13.0, 16.0], "col": Color(1.0, 0.58, 0.22),
		"desc": "Fast flaming arrows. Hits flyers.",
	},
	"bombard": {
		"name": "Bombard", "short": "Bombard",
		"cost": [120, 130, 190], "range": [7.4, 8.0, 8.6], "min_range": 2.3,
		"dmg": [36.0, 60.0, 98.0], "splash": [1.55, 1.8, 2.1], "rate": [2.9, 2.7, 2.5],
		"air": false, "ground": true,
		"light": [8.5, 10.5, 13.0], "col": Color(1.0, 0.46, 0.16),
		"desc": "Heavy mortar shells with splash damage. Ground only.",
	},
	"spire": {
		"name": "Storm Spire", "short": "Spire",
		"cost": [110, 120, 180], "range": [5.5, 6.0, 6.5], "dmg": [17.0, 25.0, 35.0],
		"jumps": [3, 4, 6], "rate": [2.3, 2.1, 1.9], "slow": [0.36, 0.42, 0.48], "slow_t": [1.3, 1.5, 1.7],
		"air": true, "ground": true,
		"light": [7.5, 9.5, 12.0], "col": Color(0.40, 0.80, 1.0),
		"desc": "Chain lightning that slows. Hits flyers.",
	},
	"guard": {
		"name": "Guard Post", "short": "Guards",
		"cost": [80, 90, 150], "range": [3.4, 3.7, 4.0], "n": [2, 3, 3],
		"hp": [62.0, 90.0, 135.0], "dmg": [7.0, 10.0, 15.0], "rate": [7.0, 6.0, 5.0],
		"air": false, "ground": true,
		"light": [9.0, 11.5, 14.0], "col": Color(1.0, 0.64, 0.26),
		"desc": "Footmen who block and duel monsters on the road.",
	},
}

var gfx: CWGfx
var fx: CWFx
var audio: CWAudio
var rig: CWRig
var terrain: CWTerrain

var towers: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var shells: Array[Dictionary] = []
var stuck_arrows: Array[Dictionary] = []
var footmen: Array[Dictionary] = []

var proj_mmi: MultiMeshInstance3D
var proj_mm: MultiMesh
const MAX_PROJ := 220
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
	proj_mm.instance_count = MAX_PROJ
	proj_mm.visible_instance_count = 0
	proj_mmi = MultiMeshInstance3D.new()
	proj_mmi.multimesh = proj_mm
	proj_mmi.material_override = mat
	proj_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(proj_mmi)


func build_tower(pad: Dictionary, kind: String, pal: Dictionary) -> Dictionary:
	var def: Dictionary = DEFS[kind]
	var node := Node3D.new()
	var ch := terrain.get_chunk_node(float(pad["x"]), float(pad["z"]))
	node.position = Vector3(pad["x"], pad["y"], pad["z"]) - ch.position
	node.rotation.y = float(pad["rot"])
	ch.add_child(node)

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
	_rebuild_mesh(t, pal)
	audio.play_sfx("build", 0.9)
	return t


func upgrade_tower(t: Dictionary, pal: Dictionary) -> bool:
	if int(t["lvl"]) >= 2 or String(t["state"]) != "active":
		return false
	t["lvl"] = int(t["lvl"]) + 1
	var def: Dictionary = t["def"]
	t["spent"] = int(t["spent"]) + int(def["cost"][int(t["lvl"])])
	t["state"] = "build"
	t["build_t"] = 0.0
	t["emitter"]["energy"] = float(def["light"][int(t["lvl"])])
	_rebuild_mesh(t, pal)
	audio.play_sfx("upgrade", 0.95)
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
	return refund


func _find_rally_point(tx: float, tz: float) -> Vector3:
	var road: Array[Vector2] = terrain.layout["road"]
	var best_d := 1e9
	var best := Vector2(tx, tz)
	for pt in road:
		var d := Vector2(tx, tz).distance_to(pt)
		if d < best_d:
			best_d = d
			best = pt
	return Vector3(best.x, terrain.height_at(best.x, best.y), best.y)


func _add_brazier(s: CWGfx.Soup, p: Vector3, bs: float, iron: Color) -> void:
	for k in range(3):
		var a := float(k) * TAU / 3.0 + 0.5
		s.add_seg(p + Vector3(cos(a) * bs * 0.42, 0.0, sin(a) * bs * 0.42), p + Vector3(cos(a) * bs * 0.20, bs * 0.5, sin(a) * bs * 0.20), 0.03, 0.03, iron, 4, CWGfx.L_METAL, 0.55)
	s.add_cyl(bs * 0.28, bs * 0.42, bs * 0.24, p + Vector3(0, bs * 0.56, 0), iron, 8, CWGfx.L_METAL, 0.55)
	s.add_cyl(bs * 0.36, bs * 0.32, 0.08, p + Vector3(0, bs * 0.68, 0), Color(1.0, 0.48, 0.14), 8, CWGfx.L_PLAIN, 0.4, Vector3.ZERO, 0.0, 2.2)


func _rebuild_mesh(t: Dictionary, pal: Dictionary) -> void:
	var node: Node3D = t["node"]
	for ch in node.get_children():
		ch.queue_free()
	t["pieces"].clear()
	t["crystal"] = null
	t["shards"].clear()
	t["turret"] = null

	var kind: String = t["kind"]
	var lvl: int = t["lvl"]
	var st: Color = pal["stone"]
	var std: Color = pal["stoneD"]
	var stl: Color = pal["stoneL"]
	var w: Color = pal["wood"]
	var wd: Color = pal["woodD"]
	var wl: Color = pal["woodL"]
	var iron: Color = pal["iron"]
	var blk := Color(0.04, 0.045, 0.06)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var top_y := 2.8

	match kind:
		"archer":
			var b_h: float = [0.28, 1.0, 1.85][lvl]
			var h: float = [2.05, 2.75, 3.4][lvl]
			var hw: float = [0.76, 0.85, 0.94][lvl]
			var bs: float = [0.48, 0.60, 0.74][lvl]
			top_y = h + 0.7

			# Piece 0: Stone base & corner quoins
			var s0 := CWGfx.Soup.new()
			s0.add_box(Vector3(1.65, 0.28, 1.65), Vector3(0, 0.14, 0), std, CWGfx.L_MASON, 0.9)
			if lvl == 0:
				for c in corners:
					s0.add_box(Vector3(0.32, 0.34, 0.32), Vector3(c.x * 0.66, 0.17, c.y * 0.66), stl, CWGfx.L_MASON, 0.88)
			else:
				s0.add_box(Vector3(1.42, b_h - 0.28, 1.42), Vector3(0, 0.28 + (b_h - 0.28) * 0.5, 0), st, CWGfx.L_MASON, 0.9)
				s0.add_box(Vector3(1.52, 0.14, 1.52), Vector3(0, b_h - 0.04, 0), stl, CWGfx.L_MASON, 0.86)
				s0.add_box(Vector3(0.32, 0.54, 0.08), Vector3(0, 0.55, 0.71), blk, CWGfx.L_PLAIN, 0.95)
			_add_piece(t, node, s0, 0.0)

			# Piece 1: 4 timber posts + X cross-bracing
			var s1 := CWGfx.Soup.new()
			for c in corners:
				s1.add_seg(Vector3(c.x * 0.62, b_h, c.y * 0.62), Vector3(c.x * (hw - 0.1), h, c.y * (hw - 0.1)), 0.085, 0.075, wd, 5, CWGfx.L_WOOD, 0.9)
			for k in range(4):
				var c0: Vector2 = corners[k]
				var c1: Vector2 = corners[(k + 1) % 4]
				s1.add_seg(Vector3(c0.x * 0.62, b_h + 0.1, c0.y * 0.62), Vector3(c1.x * (hw - 0.12), h - 0.12, c1.y * (hw - 0.12)), 0.04, 0.04, w, 4, CWGfx.L_WOOD, 0.88)
				s1.add_seg(Vector3(c1.x * 0.62, b_h + 0.1, c1.y * 0.62), Vector3(c0.x * (hw - 0.12), h - 0.12, c0.y * (hw - 0.12)), 0.04, 0.04, wl, 4, CWGfx.L_WOOD, 0.88)
			_add_piece(t, node, s1, 0.22)

			# Piece 2: Overhanging deck + notched battlements + ladder + brazier + banner
			var s2 := CWGfx.Soup.new()
			s2.add_box(Vector3(hw * 2.0 + 0.20, 0.12, hw * 2.0 + 0.20), Vector3(0, h + 0.06, 0), w, CWGfx.L_WOOD, 0.86)
			for c in corners:
				s2.add_box(Vector3(0.11, 0.64, 0.11), Vector3(c.x * (hw + 0.02), h + 0.40, c.y * (hw + 0.02)), wd, CWGfx.L_WOOD, 0.9)
			for k in range(4):
				var ang := float(k) * PI * 0.5
				var cs := cos(ang)
				var sn := sin(ang)
				for j in range(5):
					var u := (float(j) - 2.0) * hw * 0.42
					var ph := 0.36 if (j & 1) == 1 else 0.52
					var rx := u * cs + (hw + 0.02) * sn
					var rz := -u * sn + (hw + 0.02) * cs
					s2.add_box(Vector3(hw * 0.40, ph, 0.07), Vector3(rx, h + 0.12 + ph * 0.5, rz), w if (j & 1) == 1 else wl, CWGfx.L_WOOD, 0.86, Vector3(0, ang, 0))
			# Ladder on back
			for sg in [-1.0, 1.0]:
				s2.add_seg(Vector3(sg * 0.17, 0.0, -hw - 0.48), Vector3(sg * 0.17, h + 0.15, -hw - 0.05), 0.035, 0.035, wd, 4, CWGfx.L_WOOD, 0.9)
			var bx := -hw + 0.34
			var bz := -hw + 0.34
			_add_brazier(s2, Vector3(bx, h + 0.12, bz), bs, iron)
			# Back wooden ladder (60-towers.js:66-69)
			for sg: float in [-1.0, 1.0]:
				s2.add_seg(Vector3(sg * 0.17, 0.0, -hw - 0.48), Vector3(sg * 0.17, h + 0.15, -hw - 0.06), 0.035, 0.035, wd, 4, CWGfx.L_WOOD, 0.9)
			var ly := 0.30
			while ly < h:
				var lu := ly / (h + 0.15)
				s2.add_box(Vector3(0.36, 0.04, 0.05), Vector3(0.0, ly, lerpf(-hw - 0.48, -hw - 0.06, lu)), wl, CWGfx.L_WOOD, 0.9)
				ly += 0.34
			# Mounted rail shields & lvl 1+ red pennant (60-towers.js:63-64, 72)
			if lvl >= 1:
				var sh_xs: Array = [-0.50, 0.0, 0.50] if lvl == 2 else [-0.35, 0.35]
				var sh_col: Color = Color(0.62, 0.66, 0.72) if lvl == 2 else pal["clothB"]
				for sx_v in sh_xs:
					s2.add_cyl(0.20, 0.20, 0.04, Vector3(float(sx_v), h + 0.34, hw + 0.08), sh_col, 8, CWGfx.L_METAL if lvl == 2 else CWGfx.L_WOOD, 0.55, Vector3(PI * 0.5, 0.0, 0.0))
				if lvl == 2:
					for sg: float in [-1.0, 1.0]:
						s2.add_cyl(0.20, 0.20, 0.04, Vector3(sg * (hw + 0.08), h + 0.34, 0.10), pal["clothR"], 8, CWGfx.L_WOOD, 0.75, Vector3(0.0, 0.0, PI * 0.5))
				s2.add_seg(Vector3(hw - 0.08, h + 0.12, -hw + 0.08), Vector3(hw - 0.08, h + 1.75, -hw + 0.08), 0.035, 0.025, wd, 4, CWGfx.L_WOOD, 0.9)
				s2.add_box(Vector3(0.60, 0.36, 0.04), Vector3(hw + 0.22, h + 1.50, -hw + 0.08), pal["clothR"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 1.1)
			_add_piece(t, node, s2, 0.48)
			t["flame_local"] = Vector3(bx, h + 0.12 + bs * 0.72, bz)

		"bombard":
			var rr: float = [1.0, 1.08, 1.16][lvl]
			var h: float = [1.15, 1.55, 1.95][lvl]
			top_y = h + 0.75

			# Piece 0: Stone plinth & 10-sided drum + buttresses
			var s0 := CWGfx.Soup.new()
			s0.add_cyl(rr + 0.22, rr + 0.18, 0.28, Vector3(0, 0.14, 0), std, 10, CWGfx.L_MASON, 0.9)
			s0.add_cyl(rr, rr * 0.93, h, Vector3(0, h * 0.5, 0), st, 10, CWGfx.L_MASON, 0.88)
			s0.add_box(Vector3(0.34, 0.54, 0.12), Vector3(0, 0.32, rr * 0.94), blk, CWGfx.L_PLAIN, 0.95)
			if lvl >= 1:
				for k in range(4):
					var a := float(k) * PI * 0.5 + PI * 0.25
					s0.add_box(Vector3(0.36, h * 0.8, 0.48), Vector3(cos(a) * (rr + 0.06), h * 0.4, sin(a) * (rr + 0.06)), std, CWGfx.L_MASON, 0.9, Vector3(0, -a + PI * 0.5, 0))
				s0.add_cyl(rr * 0.98 + 0.02, rr * 0.98 + 0.02, 0.08, Vector3(0, h * 0.65, 0), iron, 10, CWGfx.L_METAL, 0.5)
			_add_piece(t, node, s0, 0.0)

			# Piece 1: Deck + crenelated rim + cannon carriage & barrel
			var s1 := CWGfx.Soup.new()
			s1.add_cyl(rr * 0.93 + 0.14, rr * 0.93 + 0.14, 0.16, Vector3(0, h + 0.04, 0), stl, 10, CWGfx.L_MASON, 0.86)
			s1.add_cyl(rr * 0.82, rr * 0.82, 0.07, Vector3(0, h + 0.14, 0), w, 10, CWGfx.L_WOOD, 0.88)
			for k in range(10):
				if k % 5 == 0:
					continue
				var a := (float(k) + 0.5) / 10.0 * TAU
				s1.add_box(Vector3(0.42, 0.32, 0.20), Vector3(cos(a) * rr * 0.96, h + 0.28, sin(a) * rr * 0.96), iron if (lvl == 2 and (k & 1) == 1) else std, CWGfx.L_MASON, 0.88, Vector3(0, -a + PI * 0.5, 0))
			var tur_node := Node3D.new()
			tur_node.position = Vector3(0, h + 0.22, 0)
			var ts := CWGfx.Soup.new()
			ts.add_box(Vector3(0.62, 0.28, 0.72), Vector3(0, 0.08, 0.0), wd, CWGfx.L_WOOD, 0.88)
			ts.add_cyl(0.22 + float(lvl) * 0.03, 0.17 + float(lvl) * 0.02, 1.18 + float(lvl) * 0.15, Vector3(0, 0.34, 0.24), iron, 8, CWGfx.L_METAL, 0.42, Vector3(0.65, 0, 0))
			var tmi := MeshInstance3D.new()
			tmi.mesh = ts.build()
			tmi.material_override = gfx.mat_world
			tur_node.add_child(tmi)
			node.add_child(tur_node)
			t["turret"] = tur_node
			_add_piece(t, node, s1, 0.28)

			# Piece 2: Stacked cannonballs + gunpowder barrel + iron crane lantern(s) (60-towers.js:87-96)
			var s2 := CWGfx.Soup.new()
			for cb in [Vector3(-0.42, h + 0.23, -0.50), Vector3(-0.24, h + 0.23, -0.52), Vector3(-0.33, h + 0.23, -0.36), Vector3(-0.33, h + 0.37, -0.46)]:
				s2.add_rock(0.095, cb, iron.darkened(0.20), 77, CWGfx.L_METAL, 0.45)
			s2.add_cyl(0.16, 0.15, 0.34, Vector3(0.44, h + 0.30, -0.48), wd, 7, CWGfx.L_WOOD, 0.88)
			s2.add_cyl(0.165, 0.165, 0.04, Vector3(0.44, h + 0.22, -0.48), iron, 7, CWGfx.L_METAL, 0.55)
			s2.add_cyl(0.165, 0.165, 0.04, Vector3(0.44, h + 0.38, -0.48), iron, 7, CWGfx.L_METAL, 0.55)
			var lx := -rr * 0.78
			var lz := 0.20
			var lh := h + 1.25 + float(lvl) * 0.12
			var lsides: Array = [-1.0, 1.0] if lvl == 2 else [1.0]
			for sg_l in lsides:
				var x_l := lx * float(sg_l)
				s2.add_seg(Vector3(x_l, h + 0.12, lz), Vector3(x_l, lh, lz), 0.04, 0.035, iron, 4, CWGfx.L_METAL, 0.5)
				s2.add_seg(Vector3(x_l, lh, lz), Vector3(x_l, lh, lz + 0.32), 0.03, 0.03, iron, 4, CWGfx.L_METAL, 0.5)
				s2.add_box(Vector3(0.20, 0.05, 0.20), Vector3(x_l, lh - 0.08, lz + 0.32), iron, CWGfx.L_METAL, 0.5)
				s2.add_box(Vector3(0.16, 0.20, 0.16), Vector3(x_l, lh - 0.22, lz + 0.32), Color(1.0, 0.52, 0.16), CWGfx.L_PLAIN, 0.4, Vector3.ZERO, 0.0, 0.85)
				s2.add_box(Vector3(0.20, 0.04, 0.20), Vector3(x_l, lh - 0.34, lz + 0.32), iron, CWGfx.L_METAL, 0.5)
			_add_piece(t, node, s2, 0.50)
			t["flame_local"] = Vector3(lx, lh - 0.22, lz + 0.32)

		"spire":
			var h: float = [2.65, 3.35, 4.05][lvl]
			var bas := Color(0.19, 0.20, 0.24)
			var bas_l := Color(0.28, 0.30, 0.35)
			var cu := Color(0.54, 0.36, 0.23)
			top_y = h + 0.85

			# Piece 0: Stepped dark basalt plinth
			var s0 := CWGfx.Soup.new()
			s0.add_box(Vector3(1.56, 0.22, 1.56), Vector3(0, 0.11, 0), bas_l, CWGfx.L_ROCK, 0.9)
			s0.add_box(Vector3(1.18, 0.22, 1.18), Vector3(0, 0.33, 0), bas, CWGfx.L_ROCK, 0.9)
			if lvl >= 1:
				for c in corners:
					s0.add_cone(0.18, 0.55, Vector3(c.x * 0.62, 0.48, c.y * 0.62), bas_l, 4, CWGfx.L_ROCK, 0.88)
			_add_piece(t, node, s0, 0.0)

			# Piece 1: Tapered basalt obelisk + glowing cyan rune strips + copper bands
			var s1 := CWGfx.Soup.new()
			s1.add_cyl(0.62, 0.32, h - 0.42, Vector3(0, 0.42 + (h - 0.42) * 0.5, 0), bas, 4, CWGfx.L_ROCK, 0.88, Vector3(0, PI * 0.25, 0))
			for k in range(4):
				var a := float(k) * PI * 0.5
				var n_runes := 3 + lvl
				for j in range(n_runes):
					var u := (float(j) + 0.7) / (float(n_runes) + 0.6)
					var ry := 0.42 + u * (h - 0.42)
					var r_off := lerpf(0.62, 0.32, u) * 0.72 + 0.02
					s1.add_box(Vector3(0.08, 0.20, 0.03), Vector3(sin(a) * r_off, ry, cos(a) * r_off), pal["crystal"], CWGfx.L_PLAIN, 0.25, Vector3(0, a, 0), 0.0, 2.0)
			if lvl >= 1:
				for u in ([0.3, 0.58, 0.82] if lvl == 2 else [0.4, 0.75]):
					var r_b := lerpf(0.62, 0.32, u) + 0.04
					s1.add_cyl(r_b, r_b, 0.09, Vector3(0, 0.42 + u * (h - 0.42), 0), cu, 4, CWGfx.L_METAL, 0.45, Vector3(0, PI * 0.25, 0))
			_add_piece(t, node, s1, 0.25)

			# Piece 2: 4 angled basalt/copper claws
			var s2 := CWGfx.Soup.new()
			for k in range(4):
				var a := float(k) * PI * 0.5 + PI * 0.25
				var cs := cos(a)
				var sn := sin(a)
				s2.add_seg(Vector3(cs * 0.22, h - 0.12, sn * 0.22), Vector3(cs * 0.48, h + 0.28, sn * 0.48), 0.065, 0.045, bas_l, 4, CWGfx.L_ROCK, 0.86)
				s2.add_seg(Vector3(cs * 0.48, h + 0.28, sn * 0.48), Vector3(cs * 0.26, h + 0.78, sn * 0.26), 0.045, 0.015, cu if lvl >= 1 else bas_l, 4, CWGfx.L_METAL if lvl >= 1 else CWGfx.L_ROCK, 0.55)
			_add_piece(t, node, s2, 0.48)

			# Floating animated crystal mesh
			var scry := CWGfx.Soup.new()
			var cs_sz: float = [0.22, 0.26, 0.32][lvl]
			scry.add_cone(cs_sz, cs_sz * 1.9, Vector3(0, cs_sz * 0.95, 0), pal["crystal"], 6, CWGfx.L_PLAIN, 0.15, Vector3.ZERO, 0.0, 2.8)
			scry.add_cone(cs_sz, cs_sz * 1.3, Vector3(0, -cs_sz * 0.65, 0), pal["crystal"], 6, CWGfx.L_PLAIN, 0.15, Vector3(PI, 0, 0), 0.0, 2.4)
			var cmi := MeshInstance3D.new()
			cmi.mesh = scry.build()
			cmi.material_override = gfx.mat_world
			cmi.position = Vector3(0, h + 0.48, 0)
			node.add_child(cmi)
			t["crystal"] = cmi
			t["crystal_base_y"] = h + 0.48
			var n_sh := lvl * 2
			for sh_i in range(n_sh):
				var shs := CWGfx.Soup.new()
				shs.add_cone(0.08, 0.22, Vector3.ZERO, pal["crystal"], 4, CWGfx.L_PLAIN, 0.2, Vector3.ZERO, 0.0, 2.4)
				var shmi := MeshInstance3D.new()
				shmi.mesh = shs.build()
				shmi.material_override = gfx.mat_world
				cmi.add_child(shmi)
				t["shards"].append(shmi)
			if lvl == 2:
				# Dual rotating copper rings around lvl-2 spire crystal (60-towers.js:108)
				for rk in range(2):
					var rs := CWGfx.Soup.new()
					var r_rad := 0.46 + float(rk) * 0.12
					for si in range(12):
						var a0 := float(si) * TAU / 12.0
						var a1 := float(si + 1) * TAU / 12.0
						rs.add_seg(Vector3(cos(a0) * r_rad, 0.0, sin(a0) * r_rad), Vector3(cos(a1) * r_rad, 0.0, sin(a1) * r_rad), 0.025, 0.025, cu, 4, CWGfx.L_METAL, 0.45)
					var rmi := MeshInstance3D.new()
					rmi.mesh = rs.build()
					rmi.material_override = gfx.mat_world
					rmi.rotation = Vector3(0.65 if rk == 0 else -0.65, 0.0, 0.45 if rk == 0 else -0.45)
					cmi.add_child(rmi)
					t["shards"].append(rmi)
			t["flame_local"] = Vector3(0, h + 0.48, 0)

		"guard":
			var bw: float = [1.5, 1.7, 1.9][lvl]
			var bd: float = [1.3, 1.4, 1.5][lvl]
			var wh: float = [1.05, 1.25, 1.48][lvl]
			top_y = 3.4 if lvl == 2 else 2.2
			t["door_local"] = Vector3(0.0, 0.0, bd * 0.5 + 0.48)

			# Piece 0: Stone floor + entry step (60-towers.js:112)
			var s0 := CWGfx.Soup.new()
			s0.add_box(Vector3(bw + 0.48, 0.16, bd + 0.65), Vector3(0, 0.08, 0.08), std, CWGfx.L_MASON, 0.9)
			s0.add_box(Vector3(0.72, 0.10, 0.38), Vector3(0, 0.05, bd * 0.5 + 0.52), st, CWGfx.L_MASON, 0.88)
			_add_piece(t, node, s0, 0.0)

			# Piece 1: Half-timbered walls + cross-beams + diagonal braces + doorway + windows (60-towers.js:115-119)
			var s1 := CWGfx.Soup.new()
			var stone_walls := (lvl == 2)
			var wc := st if stone_walls else Color(0.56, 0.52, 0.41)
			var wlay := CWGfx.L_MASON if stone_walls else CWGfx.L_PLAIN
			if lvl == 1:
				s1.add_box(Vector3(bw + 0.04, 0.50, bd + 0.04), Vector3(0, 0.41, 0), st, CWGfx.L_MASON, 0.9)
			s1.add_box(Vector3(bw, wh, bd), Vector3(0, 0.16 + wh * 0.5, 0), wc, wlay, 0.9)
			if not stone_walls:
				for c in corners:
					s1.add_box(Vector3(0.12, wh + 0.04, 0.12), Vector3(c.x * bw * 0.5, 0.16 + wh * 0.5, c.y * bd * 0.5), wd, CWGfx.L_WOOD, 0.9)
				for sg: float in [-1.0, 1.0]:
					s1.add_box(Vector3(bw, 0.10, 0.08), Vector3(0, 0.16 + wh * 0.55, sg * bd * 0.5), wd, CWGfx.L_WOOD, 0.9)
					s1.add_seg(Vector3(sg * bw * 0.5, 0.20, bd * 0.5 + 0.01), Vector3(sg * bw * 0.22, 0.16 + wh, bd * 0.5 + 0.01), 0.04, 0.04, wd, 4, CWGfx.L_WOOD, 0.9)
				s1.add_box(Vector3(0.08, 0.10, bd), Vector3(bw * 0.5, 0.16 + wh * 0.55, 0), wd, CWGfx.L_WOOD, 0.9)
				s1.add_box(Vector3(0.08, 0.10, bd), Vector3(-bw * 0.5, 0.16 + wh * 0.55, 0), wd, CWGfx.L_WOOD, 0.9)
			s1.add_box(Vector3(0.50, 0.82, 0.12), Vector3(0, 0.57, bd * 0.5), blk, CWGfx.L_PLAIN, 0.95)
			s1.add_box(Vector3(0.66, 0.10, 0.16), Vector3(0, 1.02, bd * 0.5 + 0.02), wd, CWGfx.L_WOOD, 0.88)
			for sg: float in [-1.0, 1.0]:
				s1.add_box(Vector3(0.09, 0.86, 0.16), Vector3(sg * 0.29, 0.59, bd * 0.5 + 0.02), wd, CWGfx.L_WOOD, 0.88)
			s1.add_box(Vector3(0.24, 0.24, 0.08), Vector3(bw * 0.32, 0.16 + wh * 0.62, bd * 0.5 + 0.01), blk, CWGfx.L_PLAIN, 0.95)
			s1.add_box(Vector3(0.08, 0.30, 0.30), Vector3(bw * 0.5 + 0.01, 0.16 + wh * 0.60, 0), blk, CWGfx.L_PLAIN, 0.95)
			_add_piece(t, node, s1, 0.20)

			# Piece 2: Pitched roof + closed gable triangles + chimney + spear rack + shield + lvl2 turret + fire + banner (60-towers.js:120-132)
			var s2 := CWGfx.Soup.new()
			var y0 := 0.16 + wh
			var rh: float = [0.75, 0.85, 0.90][lvl]
			var slp := atan2(rh, bd * 0.5 + 0.2)
			var rlen := sqrt(rh * rh + pow(bd * 0.5 + 0.2, 2.0)) + 0.12
			var rc := Color(0.54, 0.46, 0.27) if lvl == 0 else Color(0.26, 0.29, 0.36)
			var gc := st if stone_walls else Color(0.56, 0.52, 0.41)
			var glay := CWGfx.L_MASON if stone_walls else CWGfx.L_PLAIN
			for sg: float in [-1.0, 1.0]:
				s2.add_box(Vector3(bw + 0.36, 0.09, rlen), Vector3(0, y0 + rh * 0.5 - 0.02, sg * (bd * 0.25 + 0.10)), rc, CWGfx.L_SLATE, 0.86, Vector3(sg * slp, 0, 0))
				var g0 := Vector3(sg * bw * 0.5, y0, -bd * 0.5)
				var g1 := Vector3(sg * bw * 0.5, y0, bd * 0.5)
				var g2 := Vector3(sg * bw * 0.5, y0 + rh, 0.0)
				if sg > 0.0:
					s2.add_tri(g0, g1, g2, gc, glay, 0.95)
				else:
					s2.add_tri(g0, g2, g1, gc, glay, 0.95)
			s2.add_box(Vector3(bw + 0.44, 0.10, 0.14), Vector3(0, y0 + rh + 0.02, 0), wd, CWGfx.L_WOOD, 0.88)
			s2.add_box(Vector3(0.26, 0.50, 0.26), Vector3(-bw * 0.3, y0 + rh * 0.70 + 0.10, -bd * 0.2), std, CWGfx.L_MASON, 0.9)
			# Weapon rack with 3 steel-tipped spears on left wall + shield on right wall (lvl 1+)
			var rx_w := -bw * 0.5 - 0.28
			s2.add_box(Vector3(0.06, 0.70, 0.06), Vector3(rx_w, 0.50, -0.30), wd, CWGfx.L_WOOD, 0.9)
			s2.add_box(Vector3(0.06, 0.70, 0.06), Vector3(rx_w, 0.50, 0.30), wd, CWGfx.L_WOOD, 0.9)
			s2.add_box(Vector3(0.05, 0.05, 0.70), Vector3(rx_w, 0.78, 0.0), w, CWGfx.L_WOOD, 0.9)
			for sz_s: float in [-0.20, 0.0, 0.20]:
				s2.add_seg(Vector3(rx_w + 0.06, 0.12, sz_s), Vector3(rx_w - 0.04, 1.50, sz_s), 0.018, 0.018, wl, 4, CWGfx.L_WOOD, 0.9)
				s2.add_cone(0.035, 0.14, Vector3(rx_w - 0.045, 1.56, sz_s), Color(0.76, 0.80, 0.86), 4, CWGfx.L_METAL, 0.45)
			if lvl >= 1:
				s2.add_cyl(0.20, 0.20, 0.04, Vector3(bw * 0.5 + 0.03, 0.75, -0.25), pal["clothB"], 8, CWGfx.L_WOOD, 0.75, Vector3(0, 0, PI * 0.5))
			if lvl == 2:
				var tx_g := bw * 0.5 - 0.20
				var tz_g := -bd * 0.5 + 0.20
				var th_g := 2.7
				s2.add_box(Vector3(0.80, th_g, 0.80), Vector3(tx_g, th_g * 0.5 + 0.16, tz_g), st, CWGfx.L_MASON, 0.9)
				s2.add_box(Vector3(0.94, 0.16, 0.94), Vector3(tx_g, th_g + 0.20, tz_g), stl, CWGfx.L_MASON, 0.88)
				for c in corners:
					s2.add_box(Vector3(0.24, 0.26, 0.24), Vector3(tx_g + c.x * 0.35, th_g + 0.40, tz_g + c.y * 0.35), stl, CWGfx.L_MASON, 0.88)
				s2.add_box(Vector3(0.10, 0.40, 0.06), Vector3(tx_g, th_g * 0.70, tz_g + 0.41), blk, CWGfx.L_PLAIN, 0.95)
			# Front torch post (lvl 0) or iron brazier (lvl 1+) + tall blue-gold banner flagpole
			var fx_g := bw * 0.5 + 0.12
			var fz_g := bd * 0.5 + 0.50
			if lvl == 0:
				s2.add_seg(Vector3(fx_g, 0.0, fz_g), Vector3(fx_g, 1.05, fz_g), 0.04, 0.035, wd, 4, CWGfx.L_WOOD, 0.9)
				s2.add_cyl(0.07, 0.11, 0.12, Vector3(fx_g, 1.10, fz_g), iron, 6, CWGfx.L_METAL, 0.55)
				s2.add_cyl(0.08, 0.06, 0.06, Vector3(fx_g, 1.17, fz_g), Color(0.95, 0.38, 0.08), 6, CWGfx.L_PLAIN, 0.55, Vector3.ZERO, 0.0, 0.28)
				t["flame_local"] = Vector3(fx_g, 1.24, fz_g)
			else:
				s2.add_cyl(0.18, 0.26, 0.34, Vector3(fx_g, 0.25, fz_g), iron, 8, CWGfx.L_METAL, 0.55)
				s2.add_cyl(0.22, 0.18, 0.08, Vector3(fx_g, 0.43, fz_g), Color(0.95, 0.38, 0.08), 8, CWGfx.L_PLAIN, 0.55, Vector3.ZERO, 0.0, 0.30)
				t["flame_local"] = Vector3(fx_g, 0.52, fz_g)
			var bpx := (bw * 0.5 - 0.20) if lvl == 2 else (-bw * 0.5 + 0.10)
			var bpz := -bd * 0.5 + 0.15
			var bpy0 := 3.1 if lvl == 2 else 0.2
			var bpy1 := 4.5 if lvl == 2 else 2.9
			s2.add_seg(Vector3(bpx, bpy0, bpz), Vector3(bpx, bpy1, bpz), 0.04, 0.028, wd, 4, CWGfx.L_WOOD, 0.9)
			s2.add_box(Vector3(0.68, 0.42, 0.04), Vector3(bpx + 0.36, bpy1 - 0.24, bpz), pal["clothB"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 1.05)
			s2.add_box(Vector3(0.68, 0.08, 0.05), Vector3(bpx + 0.36, bpy1 - 0.24, bpz), pal["gold"], CWGfx.L_CLOTH, 0.86, Vector3.ZERO, 1.05)
			_add_piece(t, node, s2, 0.42)

	# Scaffolding shown during build animation
	var sc := CWGfx.Soup.new()
	for c in corners:
		sc.add_box(Vector3(0.09, top_y + 0.6, 0.09), Vector3(c.x * 0.92, (top_y + 0.6) * 0.5, c.y * 0.92), wl, CWGfx.L_WOOD, 0.9)
	var sc_mi := MeshInstance3D.new()
	sc_mi.mesh = sc.build()
	sc_mi.material_override = gfx.mat_world
	node.add_child(sc_mi)
	t["scaffold"] = sc_mi
	t["top_y"] = top_y

	# Update emitter world position to match exact brazier/crystal mount
	var fl_world: Vector3 = Vector3(t["x"], t["y"], t["z"]) + Basis(Vector3.UP, node.rotation.y) * Vector3(t["flame_local"])
	t["emitter"]["pos"] = fl_world + Vector3(0, 0.35, 0)
	t["flame_world"] = fl_world


func _add_piece(t: Dictionary, parent: Node3D, soup: CWGfx.Soup, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = soup.build()
	mi.material_override = gfx.mat_world
	mi.scale = Vector3(1.0, 0.01, 1.0)
	parent.add_child(mi)
	mi.visible = false
	mi.scale = Vector3.ONE
	t["pieces"].append({"mi": mi, "delay": delay, "landed": false})


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
				var a_tgts := monsters_sys.find_targets(float(t["x"]), float(t["z"]), float(def["range"][lvl]), true, true, 0.0, 1)
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
						var tg: Dictionary = a_tgts[0]
						var want_a := atan2(float(tg["x"]) - ax, float(tg["z"]) - az)
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
					rig.draw_humanoid(Vector3(ax, deck_y, az), ayaw, 0.72, 0.0, 0.0, Color(0.24, 0.42, 0.72), Color(0.86, 0.78, 0.68), 0.0, {"bow": true, "draw": adraw})
			"bombard":
				var targets := monsters_sys.find_targets(float(t["x"]), float(t["z"]), float(def["range"][lvl]), false, true, float(def["min_range"]), 1)
				var base_yaw := float(t["node"].rotation.y)
				var gun_yaw := float(t.get("gun_yaw", base_yaw))
				var aligned := false
				if not targets.is_empty():
					var m: Dictionary = targets[0]
					var want := atan2(float(m["x"]) - float(t["x"]), float(m["z"]) - float(t["z"]))
					gun_yaw = CWUtil.ang_damp(gun_yaw, want, 5.0, dt)
					aligned = absf(CWUtil.ang_diff(gun_yaw, want)) < 0.12
					if aligned and float(t["cd"]) <= 0.0:
						t["cd"] = float(def["rate"][lvl]) * randf_range(0.95, 1.08)
						t["recent"] = float(t["recent"]) + 12.0
						t["recoil"] = 1.0
						var origin := Vector3(t["x"], float(t["y"]) + float(t["top_y"]), t["z"])
						_shoot_shell(origin, Vector3(m["x"], m["y"], m["z"]), float(def["dmg"][lvl]) * dmg_mul, float(def["splash"][lvl]), t)
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
					var tgt0: Dictionary = s_tgts[0]
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


func _shoot_arrow(origin: Vector3, target: Dictionary, dmg: float, tower = null) -> void:
	var dest := Vector3(target["x"], float(target["y"]) + float(target["def"]["hit_h"]), target["z"])
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


func _fire_chain(origin: Vector3, first: Dictionary, jumps: int, dmg: float, slow_f: float, slow_t: float, monsters_sys: CWMonsters, tower = null) -> void:
	var hit_list: Array[Dictionary] = [first]
	var prev_pos := origin
	var cur := first
	var cur_dmg := dmg
	for _j in range(jumps):
		var cpos := Vector3(cur["x"], float(cur["y"]) + float(cur["def"]["hit_h"]), cur["z"])
		fx.spawn_bolt(prev_pos, cpos, Color(0.55, 0.90, 2.2), 0.22)
		monsters_sys.slow_monster(cur, slow_f, slow_t)
		monsters_sys.hit_monster(cur, cur_dmg, "magic", cpos - prev_pos, tower)
		prev_pos = cpos
		cur_dmg *= 0.86
		var nxt := monsters_sys.find_chain_next(cur["x"], cur["z"], 3.0, hit_list)
		if nxt.is_empty():
			break
		hit_list.append(nxt)
		cur = nxt


func _spawn_footman(t: Dictionary) -> void:
	var lvl: int = t["lvl"]
	var def: Dictionary = t["def"]
	var used: Array[int] = []
	for m in t["men"]:
		used.append(int(m.get("slot", 0)))
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
	var f := {
		"tower": t,
		"slot": slot,
		"torch": (slot == 0),
		"x": door_w.x,
		"y": terrain.height_at(door_w.x, door_w.z),
		"z": door_w.z,
		"home": home,
		"guard_yaw": guard_yaw,
		"hp": float(def["hp"][lvl]),
		"max_hp": float(def["hp"][lvl]),
		"dmg": float(def["dmg"][lvl]),
		"cd": 0.0,
		"yaw": float(t["node"].rotation.y),
		"phase": randf_range(0.0, TAU),
		"mv": 0.0,
		"swing": 0.0,
		"flash": 0.0,
		"foe": null,
	}
	t["men"].append(f)
	footmen.append(f)


func _update_projectiles(dt: float, monsters_sys: CWMonsters) -> void:
	var vis := 0
	var i := arrows.size() - 1
	while i >= 0:
		var a := arrows[i]
		a["t"] = float(a["t"]) + dt / float(a["dur"])
		var m: Dictionary = a["target"]
		if not bool(m.get("dead", true)):
			a["p1"] = Vector3(m["x"], float(m["y"]) + float(m["def"]["hit_h"]), m["z"])
		var u := clampf(float(a["t"]), 0.0, 1.0)
		var pos: Vector3 = Vector3(a["p0"]).lerp(a["p1"], u)
		pos.y += sin(u * PI) * float(a["arc"])
		var prev: Vector3 = a["pos"]
		a["vel"] = (pos - prev)
		a["pos"] = pos
		if u >= 1.0:
			if not bool(m.get("dead", true)):
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
			proj_mm.set_instance_transform(vis, Transform3D(a_basis.scaled_local(Vector3(0.055, 0.055, 0.58)), pos))
			proj_mm.set_instance_color(vis, Color(2.0, 0.9, 0.25))
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
			proj_mm.set_instance_transform(vis, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.30), pos))
			proj_mm.set_instance_color(vis, Color(1.6, 0.55, 0.15))
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
			proj_mm.set_instance_transform(vis, Transform3D(sbas.scaled_local(Vector3(0.048, 0.048, 0.48 * fade)), sa["pos"]))
			proj_mm.set_instance_color(vis, Color(0.55, 0.42, 0.26))
			vis += 1
		i -= 1

	proj_mm.visible_instance_count = vis


func _update_footmen(dt: float, monsters_sys: CWMonsters) -> void:
	var i := footmen.size() - 1
	while i >= 0:
		var f := footmen[i]
		f["flash"] = maxf(0.0, float(f["flash"]) - dt * 5.0)
		f["flinch"] = maxf(0.0, float(f.get("flinch", 0.0)) - dt * 5.2)
		f["swing"] = maxf(0.0, float(f["swing"]) - dt * 1.75)
		f["cd"] = maxf(0.0, float(f["cd"]) - dt)
		if float(f["hp"]) <= 0.0:
			(f["tower"]["men"] as Array).erase(f)
			footmen.remove_at(i)
			i -= 1
			continue

		var foe = f["foe"]
		if foe != null and (bool(foe.get("dead", true)) or CWUtil.dist2(f["x"], f["z"], foe["x"], foe["z"]) > 16.0):
			foe["blocker"] = null
			f["foe"] = null
			foe = null

		if foe == null:
			foe = monsters_sys.find_duel_target(f["home"].x, f["home"].z, 3.6)
			if foe != null:
				f["foe"] = foe
				foe["blocker"] = f

		var target_pos: Vector3 = f["home"]
		if foe != null:
			target_pos = Vector3(foe["x"], foe["y"], foe["z"])
		var dx := target_pos.x - float(f["x"])
		var dz := target_pos.z - float(f["z"])
		var d := sqrt(dx * dx + dz * dz)
		if foe != null and d < 0.72:
			f["yaw"] = lerp_angle(float(f["yaw"]), atan2(dx, dz), 1.0 - exp(-12.0 * dt))
			f["mv"] = CWUtil.damp(float(f.get("mv", 0.0)), 0.0, 10.0, dt)
			if float(f["cd"]) <= 0.0:
				f["cd"] = 0.85
				f["swing"] = 1.0
				monsters_sys.hit_monster(foe, float(f["dmg"]), "melee", Vector3(dx, 0, dz), f.get("tower", null))
				fx.spawn_sparks(Vector3((float(f["x"]) + float(foe["x"])) * 0.5, float(f["y"]) + 0.85, (float(f["z"]) + float(foe["z"])) * 0.5), 6, 3.4, Color(1.0, 0.86, 0.48))
				audio.play_sfx("clash" if float(foe["def"].get("armor", 0.0)) > 0.0 else "sword", 0.52, 0.10, float(foe["x"]))
		elif d > 0.12:
			var spd := 2.2
			var step_d := minf(d, spd * dt)
			f["x"] = float(f["x"]) + (dx / d) * step_d
			f["z"] = float(f["z"]) + (dz / d) * step_d
			f["y"] = terrain.height_at(f["x"], f["z"])
			f["yaw"] = lerp_angle(float(f["yaw"]), atan2(dx, dz), 1.0 - exp(-12.0 * dt))
			f["phase"] = float(f["phase"]) + step_d * 6.2
			f["mv"] = CWUtil.damp(float(f.get("mv", 0.0)), 1.0, 12.0, dt)
		else:
			f["mv"] = CWUtil.damp(float(f.get("mv", 0.0)), 0.0, 10.0, dt)
			f["yaw"] = lerp_angle(float(f["yaw"]), float(f.get("guard_yaw", 0.0)), 1.0 - exp(-8.0 * dt))
			f["hp"] = minf(float(f["max_hp"]), float(f["hp"]) + dt * 4.0)

		var has_torch := bool(f.get("torch", false))
		var f_opts := {"weapon": true, "mv": float(f.get("mv", 0.0)), "flinch": float(f.get("flinch", 0.0))}
		if has_torch:
			f_opts["torch"] = true
		else:
			f_opts["shield"] = true
		rig.draw_humanoid(
			Vector3(f["x"], f["y"], f["z"]),
			float(f["yaw"]),
			0.90 + float(f["tower"]["lvl"]) * 0.05,
			float(f["phase"]),
			float(f["swing"]),
			Color(0.24, 0.42, 0.76),
			Color(0.86, 0.78, 0.68),
			float(f["flash"]),
			f_opts
		)
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
