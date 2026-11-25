class_name CWTowerMeshBuilder
extends RefCounted

# Procedural 3-tier medieval/fantasy tower geometry builder (extracted from towers.gd)

static func rebuild_mesh(t: Dictionary, pal: Dictionary, gfx: CWGfx) -> void:
	var node: Node3D = t["visuals"]
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
			_add_piece(t, node, s0, 0.0, gfx)

			# Piece 1: 4 timber posts + X cross-bracing
			var s1 := CWGfx.Soup.new()
			for c in corners:
				s1.add_seg(Vector3(c.x * 0.62, b_h, c.y * 0.62), Vector3(c.x * (hw - 0.1), h, c.y * (hw - 0.1)), 0.085, 0.075, wd, 5, CWGfx.L_WOOD, 0.9)
			for k in range(4):
				var c0: Vector2 = corners[k]
				var c1: Vector2 = corners[(k + 1) % 4]
				s1.add_seg(Vector3(c0.x * 0.62, b_h + 0.1, c0.y * 0.62), Vector3(c1.x * (hw - 0.12), h - 0.12, c1.y * (hw - 0.12)), 0.04, 0.04, w, 4, CWGfx.L_WOOD, 0.88)
				s1.add_seg(Vector3(c1.x * 0.62, b_h + 0.1, c1.y * 0.62), Vector3(c0.x * (hw - 0.12), h - 0.12, c0.y * (hw - 0.12)), 0.04, 0.04, wl, 4, CWGfx.L_WOOD, 0.88)
			_add_piece(t, node, s1, 0.22, gfx)

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
			_add_piece(t, node, s2, 0.48, gfx)
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
			_add_piece(t, node, s0, 0.0, gfx)

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
			_add_piece(t, node, s1, 0.28, gfx)

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
			_add_piece(t, node, s2, 0.50, gfx)
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
			_add_piece(t, node, s0, 0.0, gfx)

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
			_add_piece(t, node, s1, 0.25, gfx)

			# Piece 2: 4 angled basalt/copper claws
			var s2 := CWGfx.Soup.new()
			for k in range(4):
				var a := float(k) * PI * 0.5 + PI * 0.25
				var cs := cos(a)
				var sn := sin(a)
				s2.add_seg(Vector3(cs * 0.22, h - 0.12, sn * 0.22), Vector3(cs * 0.48, h + 0.28, sn * 0.48), 0.065, 0.045, bas_l, 4, CWGfx.L_ROCK, 0.86)
				s2.add_seg(Vector3(cs * 0.48, h + 0.28, sn * 0.48), Vector3(cs * 0.26, h + 0.78, sn * 0.26), 0.045, 0.015, cu if lvl >= 1 else bas_l, 4, CWGfx.L_METAL if lvl >= 1 else CWGfx.L_ROCK, 0.55)
			_add_piece(t, node, s2, 0.48, gfx)

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
			_add_piece(t, node, s0, 0.0, gfx)

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
			_add_piece(t, node, s1, 0.20, gfx)

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
			_add_piece(t, node, s2, 0.42, gfx)

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


static func _add_piece(t: Dictionary, parent: Node3D, soup: CWGfx.Soup, delay: float, gfx: CWGfx) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = soup.build()
	mi.material_override = gfx.mat_world
	mi.scale = Vector3(1.0, 0.01, 1.0)
	parent.add_child(mi)
	mi.visible = false
	mi.scale = Vector3.ONE
	t["pieces"].append({"mi": mi, "delay": delay, "landed": false})



static func _add_brazier(s: CWGfx.Soup, p: Vector3, bs: float, iron: Color) -> void:
	for k in range(3):
		var a := float(k) * TAU / 3.0 + 0.5
		s.add_seg(p + Vector3(cos(a) * bs * 0.42, 0.0, sin(a) * bs * 0.42), p + Vector3(cos(a) * bs * 0.20, bs * 0.5, sin(a) * bs * 0.20), 0.03, 0.03, iron, 4, CWGfx.L_METAL, 0.55)
	s.add_cyl(bs * 0.28, bs * 0.42, bs * 0.24, p + Vector3(0, bs * 0.56, 0), iron, 8, CWGfx.L_METAL, 0.55)
	s.add_cyl(bs * 0.36, bs * 0.32, 0.08, p + Vector3(0, bs * 0.68, 0), Color(1.0, 0.48, 0.14), 8, CWGfx.L_PLAIN, 0.4, Vector3.ZERO, 0.0, 2.2)


