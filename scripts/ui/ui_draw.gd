class_name CWUIDraw
extends RefCounted

# Pixel-art HUD, HP bars, toolbars, build/upgrade popups, banners & tips (extracted from ui.gd)

static func draw_hud(u: CWUI) -> void:
	if u.cam_ref == null or u.sub_vp_ref == null or u.game == null:
		return
	var win_sz := u.get_viewport().get_visible_rect().size
	var W := win_sz.x
	var H := win_sz.y
	var vp_sz := Vector2(u.sub_vp_ref.size)
	if W < 10.0 or H < 10.0 or vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return

	var s := u.ui_s
	var sf := float(s)
	var pad := 5.0 * sf
	var lh := float(u.FONT_LINE) * sf
	var pix := maxf(1.0, roundf(H / vp_sz.y))

	u.btns.clear()
	var next_hot: Dictionary = {}

	# 1. Monster & footman health bars
	var col_man := Color(0.498, 0.714, 0.918, 1.0)
	var col_hi := Color(0.851, 0.631, 0.235, 1.0)
	var col_mid := Color(0.878, 0.463, 0.173, 1.0)
	var col_lo := Color(0.878, 0.290, 0.196, 1.0)

	for m: CWMonsterUnit in u.game.monsters_sys.mons:
		if m.dead or m.dying > 0.0:
			continue
		var is_boss := bool(m.def.get("boss", false))
		if not is_boss and m.hp >= m.max_hp * 0.999:
			continue
		var f := clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0)
		var wpos := Vector3(m.x, m.y + float(m.def["hit_h"]) * 1.65 + (0.65 if is_boss else 0.35), m.z)
		var sp := u._proj_world(wpos)
		var bw := (34.0 if is_boss else 9.0) * pix
		var bh := (2.0 if is_boss else 1.0) * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		if bx < -bw or bx > W or by < 0.0 or by > H:
			continue
		var alpha := 0.40 if f >= 0.999 else 0.95
		var fill_c := col_hi if f > 0.5 else (col_mid if f > 0.25 else col_lo)
		u.hud_canvas.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(u.COL_DARK.r, u.COL_DARK.g, u.COL_DARK.b, alpha))
		u.hud_canvas.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(fill_c.r, fill_c.g, fill_c.b, alpha))
		if is_boss:
			u._draw_px_text(String(m.def["name"]), sp.x, by - lh - 2.0 * pix, u.COL_TX, s, "c", 1.0, u.COL_DARK)

	for fm: CWFootmanUnit in u.game.towers_sys.footmen:
		var fhp := fm.hp
		var fmhp := maxf(fm.max_hp, 1.0)
		if fhp >= fmhp * 0.999:
			continue
		var f := clampf(fhp / fmhp, 0.0, 1.0)
		var sp := u._proj_world(Vector3(fm.x, fm.y + 1.38, fm.z))
		var bw := 8.0 * pix
		var bh := 1.0 * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		u.hud_canvas.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(u.COL_DARK.r, u.COL_DARK.g, u.COL_DARK.b, 0.95))
		u.hud_canvas.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(col_man.r, col_man.g, col_man.b, 0.95))

	# 2. Top-left stats plate (flame / coin / skull)
	var stats := [
		["flame", str(u.game.lives), u.COL_RED if u.hurt_t > 0.0 else u.COL_TX],
		["coin", str(int(floorf(u.gold_shown))), u.COL_RED if u.deny_t > 0.0 else (u.COL_GOLD_HI if u.gold_bump > 0.0 else u.COL_TX)],
		["skull", str(u.game.slain), Color.WHITE if u.slain_bump > 0.5 else u.COL_TX],
	]
	var w_s := pad
	for st in stats:
		var isz := u._icon_size(String(st[0]))
		w_s += isz.x * sf + 2.0 * sf + maxf(u._tw(String(st[1])), u._tw("000")) + 6.0 * sf
	w_s += pad - 6.0 * sf
	var h_s := 10.0 * sf + pad * 2.0 - 2.0 * sf
	var x0 := 5.0 * sf
	var y0 := 5.0 * sf
	u.PixelPanel.draw_plate(u.hud_canvas, x0, y0, w_s, h_s, s, u.COL_BG, u.COL_RED if u.hurt_t > 0.0 else u.COL_BD)
	var cur_x := x0 + pad
	for st in stats:
		var nm: String = st[0]
		var val: String = st[1]
		var col: Color = st[2]
		var isz := u._icon_size(nm)
		var iy := y0 + roundf((h_s - isz.y * sf) * 0.5)
		var ia := (0.55 + 0.45 * (float(u.game.lives) / float(maxi(1, u.game.max_lives)))) if nm == "flame" else 1.0
		u._draw_px_icon(nm, cur_x, iy, s, ia)
		if nm == "coin":
			u.gold_icon_pos = Vector2(cur_x + isz.x * sf * 0.5, iy + isz.y * sf * 0.5)
		cur_x += isz.x * sf + 2.0 * sf
		u._draw_px_text(val, cur_x, y0 + roundf((h_s - lh) * 0.5) + sf, col, s)
		cur_x += maxf(u._tw(val), u._tw("000")) + 6.0 * sf

	# 3. Top-center Wave plate & Top-right Commander plate (responsive anti-overlap)
	var wn := "Wave %d" % maxi(1, u.game.wave_number())
	var sub := ""
	var frac := -1.0
	var can_call := u.game.phase == "play" and not u.game.spawning and not u.game.boss_wave and u.game.next_in > 0.4
	var pre_wave_hot := can_call and u.mouse_inside and u.wave_rect.size.x > 0.0 and u.wave_rect.has_point(u.mouse_pos)
	if u.game.phase == "play":
		if not u.game.spawning and not u.game.boss_wave and u.game.next_in > 0.0:
			if pre_wave_hot:
				sub = "Call now · +%d" % int(roundf(u.game.next_in * 3.0))
			else:
				sub = "Next wave in %d" % maxi(1, int(ceilf(u.game.next_in)))
			frac = 1.0 - u.game.next_in / 6.5
		else:
			sub = "%d on the road" % (u.game.monsters_sys.mons.size() + u.game.queue.size())
	elif u.game.phase == "defeat":
		sub = "The fire has died"
	elif u.game.phase == "clear":
		sub = "Boss defeated"
	else:
		sub = "A new pass awaits"

	var bw_ic := u._icon_size("banner").x * sf
	var w_w := maxf(maxf(bw_ic + 3.0 * sf + u._tw(wn), u._tw(sub)), u._tw("Call now · +18")) + pad * 2.0 + 4.0 * sf
	var h_w := lh * 2.0 + pad * 2.0 + sf

	var you := not u.game.ai_commander
	var ct := "You command" if you else "AI commander"
	var cs := "Click here for the AI" if you else "Click a pad to take over"
	var ic_cmd := "hand" if you else "helm"
	var icw := u._icon_size(ic_cmd).x * sf
	var c_w := maxf(icw + 3.0 * sf + u._tw(ct), u._tw(cs)) + pad * 2.0 + 2.0 * sf
	if u.show_perf and not u.perf_line1.is_empty():
		var pw := maxf(u._tw(u.perf_line1), u._tw(u.perf_line2)) + pad * 2.0
		var ph := lh * 2.0 + pad * 2.0 + sf
		var py: float = 5.0 * sf + h_s + 4.0 * sf
		u.PixelPanel.draw_plate(u.hud_canvas, 5.0 * sf, py, pw, ph, s, u.COL_BG, u.COL_BD)
		u._draw_px_text(u.perf_line1, 5.0 * sf + pad, py + pad, u.COL_AMBER, s)
		u._draw_px_text(u.perf_line2, 5.0 * sf + pad, py + pad + lh + sf, u.COL_TX, s)

	var xc := W - c_w - 5.0 * sf
	var g3 := 3.0 * sf
	var xw := roundf(W * 0.5 - w_w * 0.5)
	var yc := y0
	var yw := y0
	if xc < x0 + w_s + g3:
		yc = y0 + h_s + g3
	if xw < x0 + w_s + g3 or (yc == y0 and xw + w_w > xc - g3) or yc != y0:
		yw = maxf(y0 + h_s, yc + (h_w if (yc == y0 or xw + w_w > xc - g3) else 0.0)) + g3
	var top_h := maxf(y0 + h_s, maxf(yc + h_w, yw + h_w)) - y0

	u.wave_rect = Rect2(xw, yw, w_w, h_w)
	u.wave_hot = can_call and u.mouse_inside and u.wave_rect.has_point(u.mouse_pos)
	u.PixelPanel.draw_plate(u.hud_canvas, xw, yw, w_w, h_w, s, u.COL_BG2 if u.wave_hot else u.COL_BG, u.COL_BD_HI if u.wave_hot else u.COL_BD)
	var tx0 := roundf(W * 0.5 - (bw_ic + 3.0 * sf + u._tw(wn)) * 0.5)
	u._draw_px_icon("banner", tx0, yw + pad - sf, s)
	u._draw_px_text(wn, tx0 + bw_ic + 3.0 * sf, yw + pad, u.COL_AMBER, s)
	u._draw_px_text(sub, W * 0.5, yw + pad + lh + sf, u.COL_DIM, s, "c")
	if frac >= 0.0:
		u.hud_canvas.draw_rect(Rect2(xw + 3.0 * sf, yw + h_w - 3.0 * sf, w_w - 6.0 * sf, sf), Color(0.165, 0.149, 0.125, 1.0))
		u.hud_canvas.draw_rect(Rect2(xw + 3.0 * sf, yw + h_w - 3.0 * sf, roundf((w_w - 6.0 * sf) * clampf(frac, 0.0, 1.0)), sf), u.COL_AMBER)

	u.cmd_rect = Rect2(xc, yc, c_w, h_w)
	u.cmd_hot = u.mouse_inside and u.cmd_rect.has_point(u.mouse_pos)
	u.PixelPanel.draw_plate(u.hud_canvas, xc, yc, c_w, h_w, s, u.COL_BG2 if u.cmd_hot else u.COL_BG, u.COL_BD_HI if (u.cmd_hot or you) else u.COL_BD)
	u._draw_px_icon(ic_cmd, xc + pad, yc + pad - sf, s)
	u._draw_px_text(ct, xc + pad + icw + 3.0 * sf, yc + pad, u.COL_AMBER if you else u.COL_TX, s)
	u._draw_px_text(cs, xc + pad, yc + pad + lh + sf, u.COL_DIM, s)

	# 4. Bottom Pixel Toolbar: Pause (P), Speed (Tab), Sound (M) on left; Zoom (- / +) & Follow on right (72-ui.js:280-325)
	u.hud_btns.clear()
	u.hud_hot = false
	u.menu_rect = Rect2()
	var h_b := lh + pad * 2.0 - sf
	var zb := h_b
	var y_b := H - zb - 5.0 * sf
	var tip_state := {"text": "", "x": 0.0}
	var col_bd_on := Color(0.541, 0.416, 0.227, 1.0)
	var col_dim_btn := Color(0.353, 0.329, 0.282, 1.0)

	var draw_sq := func(id: String, bx: float, bw: float, fn: Callable, tip: String, on: bool) -> Dictionary:
		var r := Rect2(bx, y_b, bw, zb)
		var is_h := u.mouse_inside and not u.is_panning and r.has_point(u.mouse_pos)
		var is_d := u.press_id == id
		var dy := sf if is_d else 0.0
		u.hud_btns.append({"id": id, "rect": r, "fn": fn})
		if is_h:
			u.hud_hot = true
			tip_state["text"] = tip
			tip_state["x"] = bx + bw * 0.5
		u.PixelPanel.draw_plate(u.hud_canvas, bx, y_b + dy, bw, zb, s, u.COL_BG2 if (is_h or is_d) else u.COL_BG, u.COL_BD_HI if (is_h or is_d) else (col_bd_on if on else u.COL_BD))
		return {"dy": dy}

	var xl := 5.0 * sf
	# Pause button
	var bp_r: Dictionary = draw_sq.call("pause", xl, zb, func():
		if u.main_ref != null:
			u.main_ref.call("toggle_pause")
	, "Resume (P)" if u.game.paused else "Pause (P)", u.game.paused)
	var u_p := zb / 18.0
	var py_b := y_b + float(bp_r["dy"])
	if u.game.paused:
		for pi in range(4):
			u.hud_canvas.draw_rect(Rect2(roundf(xl + (6.5 + float(pi) * 1.5) * u_p), roundf(py_b + (5.0 + float(pi)) * u_p), ceilf(1.5 * u_p), roundf((8.0 - 2.0 * float(pi)) * u_p)), u.COL_TX)
	else:
		u.hud_canvas.draw_rect(Rect2(roundf(xl + 6.0 * u_p), roundf(py_b + 5.0 * u_p), roundf(2.2 * u_p), roundf(8.0 * u_p)), u.COL_TX)
		u.hud_canvas.draw_rect(Rect2(roundf(xl + 9.8 * u_p), roundf(py_b + 5.0 * u_p), roundf(2.2 * u_p), roundf(8.0 * u_p)), u.COL_TX)
	xl += zb + g3

	# Speed button (1x / 2x / 3x)
	var bs_r: Dictionary = draw_sq.call("speed", xl, zb, func():
		if u.main_ref != null:
			u.main_ref.call("cycle_speed")
	, "Speed (Tab)", u.game.speed > 1)
	var sp_lbl := "%dx" % u.game.speed
	u._draw_px_text(sp_lbl, xl + zb * 0.5, y_b + float(bs_r["dy"]) + roundf((zb - lh) * 0.5) + sf, u.COL_AMBER if u.game.speed > 1 else u.COL_TX, s, "c")
	xl += zb + g3

	# Sound icon button
	var snd_ic := "mute" if u.audio.muted else "sound"
	var bsnd_r: Dictionary = draw_sq.call("sound", xl, zb, func():
		u.audio.set_muted(not u.audio.muted)
		u.audio.play_sfx("ui_click", 0.6)
	, "Sound is off (M)" if u.audio.muted else "Sound is on (M)", false)
	var s_isz := u._icon_size(snd_ic)
	u._draw_px_icon(snd_ic, xl + roundf((zb - s_isz.x * sf) * 0.5), y_b + float(bsnd_r["dy"]) + roundf((zb - s_isz.y * sf) * 0.5), s)
	u.sound_rect = Rect2(xl, y_b, zb, zb)
	u.sound_hot = u.mouse_inside and not u.is_panning and u.sound_rect.has_point(u.mouse_pos)
	xl += zb + g3

	# Biome selector button (click to open 5-biome picker; B cycles, F1-F5 direct, R new seed)
	var cur_bname: String = String(u.game.terrain.bio.get("name", "Ashen Pass"))
	var bw_bio := u._tw(cur_bname) + pad * 2.0 + 4.0 * sf
	var bbio_r: Dictionary = draw_sq.call("biome_btn", xl, bw_bio, func():
		u.biome_picker_open = not u.biome_picker_open
		u.audio.play_sfx("ui_click", 0.6)
	, "Switch biome (B / F1-F5, R reroll)", u.biome_picker_open)
	u._draw_px_text(cur_bname, xl + bw_bio * 0.5, y_b + float(bbio_r["dy"]) + roundf((zb - lh) * 0.5) + sf, u.COL_AMBER if u.biome_picker_open else u.COL_TX, s, "c")

	if u.biome_picker_open:
		var py_bio := y_b - zb - g3
		var px_bio := xl
		var cur_key: String = String(u.game.terrain.bio.get("key", ""))
		for bi in range(CWBiome.BIOMES.size()):
			var bdict: Dictionary = CWBiome.BIOMES[bi]
			var bnm: String = String(bdict["name"])
			var is_cur := String(bdict["key"]) == cur_key
			var b_idx := bi
			var bw_opt := u._tw(bnm) + pad * 2.0
			var r_opt := Rect2(px_bio, py_bio, bw_opt, zb)
			var h_opt := u.mouse_inside and not u.is_panning and r_opt.has_point(u.mouse_pos)
			var d_opt := u.press_id == ("bio_%d" % b_idx)
			var dy_o := sf if d_opt else 0.0
			u.hud_btns.append({"id": "bio_%d" % b_idx, "rect": r_opt, "fn": func():
				u.biome_picker_open = false
				u.select_pad(null)
				u.game.switch_biome(b_idx)
				u.audio.play_sfx("ui_click", 0.7)
			})
			if h_opt:
				u.hud_hot = true
				tip_state["text"] = "F%d · %s" % [b_idx + 1, bnm]
				tip_state["x"] = px_bio + bw_opt * 0.5
			u.PixelPanel.draw_plate(u.hud_canvas, px_bio, py_bio + dy_o, bw_opt, zb, s, u.COL_BG2 if (h_opt or d_opt or is_cur) else u.COL_BG, u.COL_BD_HI if (h_opt or is_cur) else u.COL_BD)
			u._draw_px_text(bnm, px_bio + bw_opt * 0.5, py_bio + dy_o + roundf((zb - lh) * 0.5) + sf, u.COL_AMBER if is_cur else u.COL_TX, s, "c")
			px_bio += bw_opt + g3
	xl += bw_bio + g3

	# Bottom-right Zoom (+) and (-) buttons
	var cur_z := float(u.main_ref.call("cam_zoom_now")) if u.main_ref != null else 1.0
	var min_z := float(u.main_ref.call("cam_zoom_min")) if u.main_ref != null else 0.5
	var xr := W - 5.0 * sf - zb
	var bzi_r: Dictionary = draw_sq.call("zin", xr, zb, func():
		if u.main_ref != null:
			u.main_ref.call("cam_zoom_by", 1.5)
	, "Zoom in (+)", false)
	u._draw_px_text("+", xr + zb * 0.5, y_b + float(bzi_r["dy"]) + roundf((zb - lh) * 0.5) + sf, u.COL_TX if cur_z < 2.99 else col_dim_btn, s, "c")
	xr -= zb + g3

	var bzo_r: Dictionary = draw_sq.call("zout", xr, zb, func():
		if u.main_ref != null:
			u.main_ref.call("cam_zoom_by", 1.0 / 1.5)
	, "Zoom out (-)", false)
	u._draw_px_text("-", xr + zb * 0.5, y_b + float(bzo_r["dy"]) + roundf((zb - lh) * 0.5) + sf, u.COL_TX if cur_z > min_z + 0.01 else col_dim_btn, s, "c")

	# "Center view" button when manually panned/zoomed
	var y_up := y_b - g3
	var is_man := bool(u.main_ref.get("cam_man")) if u.main_ref != null else false
	if is_man and (u.game.phase == "play" or u.game.phase == "defeat"):
		var flbl := "Follow the fight"
		var fw_b := u._tw(flbl) + pad * 2.0
		var fits := xr - g3 - fw_b >= xl
		var xf2 := (xr - g3 - fw_b) if fits else (W - fw_b - 5.0 * sf)
		var yf := (y_b + roundf((zb - h_b) * 0.5)) if fits else (y_b - g3 - h_b)
		var fr := Rect2(xf2, yf, fw_b, h_b)
		var hot_f := u.mouse_inside and not u.is_panning and fr.has_point(u.mouse_pos)
		u.hud_btns.append({"id": "follow", "rect": fr, "fn": func():
			if u.main_ref != null:
				u.main_ref.call("cam_reset")
			u.audio.play_sfx("ui_click", 0.6)
		})
		if hot_f:
			u.hud_hot = true
		u.PixelPanel.draw_plate(u.hud_canvas, xf2, yf, fw_b, h_b, s, u.COL_BG2 if hot_f else u.COL_BG, u.COL_BD_HI if hot_f else col_bd_on)
		u._draw_px_text(flbl, xf2 + pad, yf + pad - sf, u.COL_TX, s)
		if not fits:
			y_up = yf - g3

	# Hover shortcut tooltip above toolbar button
	var tip_text: String = String(tip_state["text"])
	if tip_text != "":
		var tw_t := u._tw(tip_text) + pad * 2.0
		var tx_t := clampf(roundf(float(tip_state["x"]) - tw_t * 0.5), 4.0 * sf, W - tw_t - 4.0 * sf)
		var ty_t := y_b - g3 - h_b
		u.PixelPanel.draw_plate(u.hud_canvas, tx_t, ty_t, tw_t, h_b, s, u.COL_BG, u.COL_BD_HI)
		u._draw_px_text(tip_text, tx_t + pad, ty_t + pad - sf, u.COL_TX, s)
		y_up = minf(y_up, ty_t - g3)

	# Paused banner
	if u.game.paused:
		var psc := s + 1
		var pt1 := "Paused"
		var pw_b := u._tw(pt1, psc) + pad * 4.0
		var ph_b := float(u.FONT_LINE * psc) + pad * 2.0
		u.PixelPanel.draw_plate(u.hud_canvas, roundf(W * 0.5 - pw_b * 0.5), y_up - ph_b, pw_b, ph_b, s, u.COL_BG, u.COL_BD_HI)
		u._draw_px_text(pt1, W * 0.5, y_up - ph_b + pad, u.COL_AMBER, psc, "c")
		y_up -= ph_b + g3

	# 5. Bottom centered controls hint plate (hidden when paused or menu open)
	var hint_a := clampf(minf(u.title_t - 7.2, 3.0 - (u.moved_t if u.idle_t > 20.0 else 0.0) + (8.0 if u.title_t < 18.0 else 0.0)), 0.0, 1.0)
	if hint_a > 0.02 and u.selected_pad == null and not u.game.paused:
		var hl := "Click a pad to build · 1-4 pick a tower · Space calls the next wave · Wheel zooms, drag moves the view"
		var hw := u._tw(hl) + pad * 2.0
		var hh := lh + pad * 2.0 - sf
		if hw < W - 10.0 * sf:
			var hx := roundf((W - hw) * 0.5)
			var hy := y_up - hh
			u.PixelPanel.draw_plate(u.hud_canvas, hx, hy, hw, hh, s, u.COL_BG, u.COL_BD, Color(0, 0, 0, 0), hint_a)
			u._draw_px_text(hl, hx + pad, hy + pad - sf, u.COL_DIM, s, "l", hint_a)

	# 6. Flying pixel coins
	var coin_s := maxi(2, s - 1)
	for qc in u.hud_coins:
		var cu := clampf(float(qc["t"]) / float(qc["dur"]), 0.0, 1.0)
		var e := cu * cu * (3.0 - 2.0 * cu)
		var a := 1.0 - e
		var qx := a * a * float(qc["sx"]) + 2.0 * a * e * float(qc["cx"]) + e * e * u.gold_icon_pos.x
		var qy := a * a * float(qc["sy"]) + 2.0 * a * e * float(qc["cy"]) + e * e * u.gold_icon_pos.y
		u._draw_px_icon("coin", qx - 4.0 * sf * 0.75, qy - 4.0 * sf * 0.75, coin_s)

	# 7. Wave / Boss Banner
	if u.banner_dur > 0.0 and not u.banner_text.is_empty():
		var ba := clampf(minf(u.banner_t * 3.0, (u.banner_dur - u.banner_t) * 2.0), 0.0, 1.0)
		if ba > 0.01:
			var bsc := s + (2 if u.banner_big else 1)
			var bw_b := u._tw(u.banner_text, bsc) + pad * 4.0
			var bh_b := float(u.FONT_LINE * bsc) + pad * 2.0
			var yb := maxf(roundf(H * 0.2), y0 + top_h + 4.0 * sf)
			u.PixelPanel.draw_plate(u.hud_canvas, roundf(W * 0.5 - bw_b * 0.5), yb, bw_b, bh_b, s, u.COL_BG, u.COL_EMBER if u.banner_big else u.COL_BD_HI, Color(0, 0, 0, 0), ba)
			u._draw_px_text(u.banner_text, W * 0.5, yb + pad, u.COL_BANNER_BIG if u.banner_big else u.COL_TX, bsc, "c", ba)

	# 8. Build / Upgrade Popup Menu (exact match to 72-ui.js:204-248 & image_e65201.png)
	if u.selected_pad != null and u.game.phase == "play":
		var tower = u.selected_pad["tower"]
		var top_off := minf(3.6, float(tower.get("top_y", 2.0))) if tower != null else 1.2
		var p := u._proj_world(Vector3(u.selected_pad["x"], float(u.selected_pad["y"]) + top_off, u.selected_pad["z"]))
		var ma := clampf(u.menu_t * 8.0, 0.0, 1.0)
		var mp := 6.0 * sf

		if tower == null:
			var bwid := 31.0 * sf
			var bh := 35.0 * sf
			var gapb := 3.0 * sf
			var row_w := 4.0 * bwid + 3.0 * gapb
			var text_w := 0.0
			for l in ["Choose a tower", "Hover or press 1 to 4", "to see what each does."]:
				text_w = maxf(text_w, u._tw(l))
			for knd in CWTowers.TOWER_KINDS:
				text_w = maxf(text_w, u._tw(String(CWTowers.DEFS[knd]["name"])))
				for dl in u.TOWER_DESC_LINES[knd]:
					text_w = maxf(text_w, u._tw(String(dl)))
			var wp := maxf(row_w, text_w) + mp * 2.0
			var hp := mp * 2.0 + lh + 3.0 * sf + bh + 4.0 * sf + lh * 3.0 + 2.0 * sf
			var px := clampf(roundf(p.x - wp * 0.5), 4.0 * sf, W - wp - 4.0 * sf)
			var py := clampf(roundf(p.y - hp - 7.0 * sf), minf(y0 + top_h + 4.0 * sf, H - hp - 4.0 * sf), H - hp - 4.0 * sf)
			u.menu_rect = Rect2(px, py, wp, hp)
			u.PixelPanel.draw_plate(u.hud_canvas, px, py, wp, hp, s, u.COL_BG, u.COL_BD, Color(0, 0, 0, 0), ma)
			u._draw_px_text("Build here", px + mp, py + mp - sf, u.COL_AMBER, s, "l", ma)

			var bx0 := px + roundf((wp - row_w) * 0.5)
			var by := py + mp + lh + 3.0 * sf
			var lit_kind := ""
			var fk: String = String(CWTowers.TOWER_KINDS[u.menu_focus % 4]) if u.gp_active else ""
			for i in range(CWTowers.TOWER_KINDS.size()):
				var knd: String = CWTowers.TOWER_KINDS[i]
				var d: Dictionary = CWTowers.DEFS[knd]
				var cost := int(d["cost"][0])
				var can := u.game.gold >= cost
				var bx := bx0 + float(i) * (bwid + gapb)
				var bid := "b_" + knd
				var rect := Rect2(bx, by, bwid, bh)
				var over := u.mouse_inside and not u.gp_active and rect.has_point(u.mouse_pos)
				var focused := u.gp_active and u.btns.size() == u.menu_focus
				var b_entry := {"id": bid, "kind": knd, "fn": func(): u._do_build(u.selected_pad, knd)}
				u.btns.append(b_entry)
				if over:
					next_hot = b_entry
				var down := u.press_id == bid
				var lit := over or focused
				var dy := sf if down else 0.0
				u.PixelPanel.draw_plate(
					u.hud_canvas, bx, by + dy, bwid, bh, s,
					u.COL_BG2 if lit else u.COL_BTN,
					u.COL_BD_HI if lit else (u.COL_BD if can else u.COL_BD_DIM),
					u.COL_HI if lit else Color(0, 0, 0, 0),
					ma
				)
				var isz := u._icon_size(knd)
				u._draw_px_icon(knd, bx + roundf((bwid - isz.x * sf) * 0.5), by + 6.0 * sf + dy, s, (1.0 if can else 0.45) * ma)
				u._draw_px_text(str(i + 1), bx + 3.0 * sf, by + 2.0 * sf + dy, u.COL_DIM, s, "l", ma)
				var cost_s := str(cost)
				var cw2 := 8.0 * sf + 2.0 * sf + u._tw(cost_s)
				var cx0 := bx + roundf((bwid - cw2) * 0.5)
				u._draw_px_icon("coin", cx0, by + bh - lh - 3.0 * sf + dy, s, (1.0 if can else 0.5) * ma)
				u._draw_px_text(cost_s, cx0 + 10.0 * sf, by + bh - lh - 3.0 * sf + dy, u.COL_AMBER if can else u.COL_RED, s, "l", ma)
				if lit:
					lit_kind = knd

			var show_k: String = lit_kind if lit_kind != "" else fk
			var ty := by + bh + 4.0 * sf
			if show_k != "":
				var dl: Array = u.TOWER_DESC_LINES[show_k]
				u._draw_px_text(String(CWTowers.DEFS[show_k]["name"]), px + mp, ty, u.COL_TX, s, "l", ma)
				u._draw_px_text(String(dl[0]), px + mp, ty + lh + sf, u.COL_DIM, s, "l", ma)
				u._draw_px_text(String(dl[1]), px + mp, ty + lh * 2.0 + sf, u.COL_DIM, s, "l", ma)
			else:
				u._draw_px_text("Choose a tower", px + mp, ty, u.COL_DIM, s, "l", ma)
				u._draw_px_text("Hover or press 1 to 4", px + mp, ty + lh + sf, u.COL_DIM, s, "l", ma)
				u._draw_px_text("to see what each does.", px + mp, ty + lh * 2.0 + sf, u.COL_DIM, s, "l", ma)
		else:
			var d: Dictionary = tower["def"]
			var lvl := int(tower["lvl"])
			var maxed := lvl >= 2
			var upc := 0 if maxed else int(d["cost"][lvl + 1])
			var can_up := (not maxed) and u.game.gold >= upc and String(tower["state"]) == "active"
			var refund := int(roundf(float(tower["spent"]) * 0.7))
			var ul := "Max level" if maxed else ("Upgrade %d" % upc)
			var sl := ("Confirm +%d" % refund) if u.sell_armed else ("Sell +%d" % refund)
			var iw9 := 9.0 * sf
			var bw3 := maxf(maxf(u._tw(ul), u._tw(sl)), u._tw("Confirm +%d" % refund)) + iw9 + 11.0 * sf
			var bh := 15.0 * sf
			var kills_n := int(tower.get("kills", 0))
			var st_txt := ("%d footmen · %d health" % [int(d["n"][lvl]), int(d["hp"][lvl])]) if String(tower["kind"]) == "guard" else ("Range %.1f · Damage %d" % [float(d["range"][lvl]), int(d["dmg"][lvl])])
			var nx_txt := ""
			if maxed:
				nx_txt = "%d kills" % kills_n
			elif String(tower["kind"]) == "guard":
				nx_txt = "Next: %d footmen · %d health" % [int(d["n"][lvl + 1]), int(d["hp"][lvl + 1])]
			else:
				nx_txt = "Next: range %.1f · damage %d" % [float(d["range"][lvl + 1]), int(d["dmg"][lvl + 1])]
			var wp := maxf(maxf(bw3 * 2.0 + 3.0 * sf, u._tw(String(d["name"])) + 26.0 * sf), maxf(u._tw(st_txt), u._tw(nx_txt))) + mp * 2.0
			var hp := mp * 2.0 + lh * 3.0 + 7.0 * sf + bh
			var px := clampf(roundf(p.x - wp * 0.5), 4.0 * sf, W - wp - 4.0 * sf)
			var py := clampf(roundf(p.y - hp - 7.0 * sf), minf(y0 + top_h + 4.0 * sf, H - hp - 4.0 * sf), H - hp - 4.0 * sf)
			u.menu_rect = Rect2(px, py, wp, hp)
			u.PixelPanel.draw_plate(u.hud_canvas, px, py, wp, hp, s, u.COL_BG, u.COL_BD, Color(0, 0, 0, 0), ma)
			u._draw_px_text(String(d["name"]), px + mp, py + mp - sf, u.COL_AMBER, s, "l", ma)
			for i in range(3):
				u._draw_px_icon("star" if i <= lvl else "starEmpty", px + wp - mp - float(3 - i) * 6.0 * sf, py + mp, s, ma)
			u._draw_px_text(st_txt, px + mp, py + mp + lh + sf, u.COL_DIM, s, "l", ma)
			u._draw_px_text(nx_txt, px + mp, py + mp + lh * 2.0 + 2.0 * sf, u.COL_DIM if maxed else u.COL_AMBER, s, "l", ma)

			var by := py + mp + lh * 3.0 + 7.0 * sf
			var bwf := floorf((wp - mp * 2.0 - 3.0 * sf) * 0.5)
			# Upgrade button
			var r_up := Rect2(px + mp, by, bwf, bh)
			var over_up := u.mouse_inside and not u.gp_active and r_up.has_point(u.mouse_pos)
			var foc_up := u.gp_active and u.btns.size() == u.menu_focus
			var b_up := {"id": "up", "kind": "", "fn": func(): u._do_upgrade(tower)}
			u.btns.append(b_up)
			if over_up:
				next_hot = b_up
			var lit_up := over_up or foc_up
			var dy_up := sf if u.press_id == "up" else 0.0
			u.PixelPanel.draw_plate(u.hud_canvas, px + mp, by + dy_up, bwf, bh, s, u.COL_BG2 if lit_up else u.COL_BTN, u.COL_BD_HI if lit_up else (u.COL_BD if can_up else u.COL_BD_DIM), u.COL_HI if lit_up else Color(0, 0, 0, 0), ma)
			u._draw_px_icon("upgrade", px + mp + 4.0 * sf, by + 3.0 * sf + dy_up, s, (1.0 if can_up else 0.4) * ma)
			u._draw_px_text(ul, px + mp + 4.0 * sf + iw9 + 3.0 * sf, by + 3.0 * sf + dy_up, u.COL_TX if can_up else (u.COL_DIM if maxed else u.COL_RED), s, "l", ma)

			# Sell button (two-step confirmation matching 72-ui.js:379)
			var sx_btn := px + mp + bwf + 3.0 * sf
			var r_sl := Rect2(sx_btn, by, bwf, bh)
			var over_sl := u.mouse_inside and not u.gp_active and r_sl.has_point(u.mouse_pos)
			var foc_sl := u.gp_active and u.btns.size() == u.menu_focus
			var b_sl := {"id": "sell", "kind": "", "fn": func():
				if not u.sell_armed:
					u.sell_armed = true
					u.audio.play_sfx("ui_click", 0.6)
				else:
					u._do_sell(tower)
			}
			u.btns.append(b_sl)
			if over_sl:
				next_hot = b_sl
			var lit_sl := over_sl or foc_sl or u.sell_armed
			var dy_sl := sf if u.press_id == "sell" else 0.0
			u.PixelPanel.draw_plate(u.hud_canvas, sx_btn, by + dy_sl, bwf, bh, s, u.COL_BG2 if lit_sl else u.COL_BTN, u.COL_RED if u.sell_armed else (u.COL_BD_HI if lit_sl else u.COL_BD), u.COL_HI if lit_sl else Color(0, 0, 0, 0), ma)
			u._draw_px_icon("sell", sx_btn + 4.0 * sf, by + 3.0 * sf + dy_sl, s, ma)
			u._draw_px_text(sl, sx_btn + 4.0 * sf + iw9 + 3.0 * sf, by + 3.0 * sf + dy_sl, u.COL_RED if u.sell_armed else u.COL_TX, s, "l", ma)

	u.hot_btn = next_hot

	# 9. Armed tower cursor tooltip
	if u.armed_kind != "" and u.mouse_inside and u.game.phase == "play":
		var al := "%s: click a pad" % String(CWTowers.DEFS[u.armed_kind]["name"])
		var aw := u._tw(al) + pad * 2.0
		var ah := lh + pad * 2.0 - sf
		var ax := clampf(u.mouse_pos.x + 10.0 * sf, 2.0 * sf, W - aw - 2.0 * sf)
		var ay := clampf(u.mouse_pos.y + 10.0 * sf, 2.0 * sf, H - ah - 2.0 * sf)
		u.PixelPanel.draw_plate(u.hud_canvas, ax, ay, aw, ah, s, u.COL_BG, u.COL_BD_HI)
		u._draw_px_text(al, ax + pad, ay + pad - sf, u.COL_TX, s)

	# 9b. New Monster / Boss 5.2s Tip Card (72-ui.js:311-318)
	if not u.active_tip.is_empty() and u.selected_pad == null:
		var mtype: String = String(u.active_tip["type"])
		var tt: float = float(u.active_tip["t"])
		var tip_a := clampf(minf(tt * 4.0, (5.2 - tt) * 2.0), 0.0, 1.0)
		if tip_a > 0.01 and CWMonsters.DEFS.has(mtype):
			var md: Dictionary = CWMonsters.DEFS[mtype]
			var head := ("%s: %s" % ["Boss" if bool(md.get("boss", false)) else "New", String(md.get("name", mtype))])
			var body := String(md.get("tip", ""))
			var tip_w := maxf(u._tw(head), u._tw(body)) + pad * 3.0
			var tip_h := lh * 2.0 + pad * 2.0 + 2.0 * sf
			var tip_y := H - tip_h - zb - 10.0 * sf
			u.PixelPanel.draw_plate(u.hud_canvas, roundf(W * 0.5 - tip_w * 0.5), tip_y, tip_w, tip_h, s, u.COL_BG, u.COL_BD_HI if bool(md.get("boss", false)) else u.COL_BD, Color(0, 0, 0, 0), tip_a)
			u._draw_px_text(head, W * 0.5, tip_y + pad, u.COL_AMBER, s, "c", tip_a)
			u._draw_px_text(body, W * 0.5, tip_y + pad + lh + sf, u.COL_TX, s, "c", tip_a)

	# 10. Opening title card (first 7s)
	if u.title_t < 7.0 and u.selected_pad == null:
		var ta := clampf(minf((u.title_t - 0.4) * 1.5, (6.6 - u.title_t) * 1.2), 0.0, 1.0)
		if ta > 0.01:
			var sc2 := s * 2
			var t1 := "Cinderwatch"
			var t2 := "%s · The commander plays until you take over." % String(u.game.terrain.bio.get("name", "Ashen Pass"))
			var t3 := ("Best run: wave %d" % u.game.best_wave) if u.game.best_wave > 5 else ""
			var tw_box := maxf(maxf(u._tw(t1, sc2), u._tw(t2)), u._tw(t3)) + pad * 4.0
			var extra_h := (lh + sf) if t3 != "" else 0.0
			var th_box := float(u.FONT_LINE * sc2) + lh + extra_h + pad * 2.0 + 2.0 * sf
			var yy := H - th_box - 22.0 * sf
			u.PixelPanel.draw_plate(u.hud_canvas, roundf(W * 0.5 - tw_box * 0.5), yy, tw_box, th_box, s, u.COL_BG, u.COL_BD, Color(0, 0, 0, 0), ta)
			u._draw_px_text(t1, W * 0.5, yy + pad, u.COL_BANNER_BIG, sc2, "c", ta)
			u._draw_px_text(t2, W * 0.5, yy + pad + float(u.FONT_LINE * sc2) + sf, u.COL_DIM, s, "c", ta)
			if t3 != "":
				u._draw_px_text(t3, W * 0.5, yy + pad + float(u.FONT_LINE * sc2) + lh + 2.0 * sf, u.COL_AMBER, s, "c", ta)
