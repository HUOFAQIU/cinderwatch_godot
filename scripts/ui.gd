class_name CWUI
extends CanvasLayer

# Complete 1:1 pixel-art HUD, build/upgrade popups, flying coins, banners,
# terrain-conforming 3D rings, integer UI scaling (C1-C4), and gamepad navigation (D3).
# Ported from 70-pixelfont.js and 72-ui.js.

const PixelPanel := preload("res://scripts/ui_pixel_panel.gd")

const FONT_LINE := 9
const FONT_BASE := 8

const COL_BG := Color(0.0353, 0.0431, 0.0667, 0.86)
const COL_BG2 := Color(0.0941, 0.1059, 0.1490, 0.94)
const COL_BTN := Color(0.0627, 0.0706, 0.1059, 0.96)
const COL_BD := Color(0.3647, 0.2980, 0.2078, 1.0)
const COL_BD_DIM := Color(0.2275, 0.2039, 0.1725, 1.0)
const COL_BD_HI := Color(0.9098, 0.6902, 0.2902, 1.0)
const COL_HI := Color(0.9098, 0.6902, 0.2902, 0.18)
const COL_TX := Color(0.9373, 0.8941, 0.8039, 1.0)
const COL_DIM := Color(0.6549, 0.6196, 0.5412, 1.0)
const COL_AMBER := Color(0.9098, 0.6902, 0.2902, 1.0)
const COL_EMBER := Color(1.0, 0.5412, 0.2353, 1.0)
const COL_RED := Color(0.8980, 0.3333, 0.2353, 1.0)
const COL_DARK := Color(0.0431, 0.0510, 0.0784, 1.0)
const COL_GOLD_HI := Color(1.0, 0.8863, 0.6275, 1.0)
const COL_BANNER_BIG := Color(1.0, 0.8510, 0.6588, 1.0)

const TOWER_DESC_LINES := {
	"archer": ["Fast flaming arrows.", "Can hit flyers."],
	"bombard": ["Slow shells that burst.", "Ground targets only."],
	"spire": ["Chain lightning that slows.", "Can hit flyers."],
	"guard": ["Footmen who block", "and duel on the road."],
}

const ICON_NAMES := [
	"coin", "flame", "skull", "banner", "hourglass", "sound", "mute",
	"archer", "bombard", "spire", "guard", "upgrade", "sell",
	"helm", "hand", "star", "starEmpty",
]

var main_ref: Node = null
var game: CWGame
var audio: CWAudio
var cam_ref: Camera3D
var sub_vp_ref: SubViewport

# Pixel font & 17 icons (C1 & C3)
var pixel_font: Font
var icons: Dictionary = {}

# Unified pixel HUD canvas (C2 & C4)
@onready var hud_canvas: Control = %HudCanvas
var show_perf: bool = false
var perf_line1: String = ""
var perf_line2: String = "" 
var ui_s: int = 3

# Interactive UI state
var selected_pad = null
var hovered_pad = null
var menu_t: float = 0.0
var menu_focus: int = 0
var sell_armed: bool = false
var biome_picker_open: bool = false
var tip_queue: Array[String] = []
var active_tip: Dictionary = {}
var armed_kind: String = ""
var mouse_pos: Vector2 = Vector2(-1000.0, -1000.0)
var mouse_inside: bool = false
var moved_t: float = 99.0
var idle_t: float = 99.0
var title_t: float = 0.0

var btns: Array[Dictionary] = []
var hud_btns: Array[Dictionary] = []
var hot_btn: Dictionary = {}
var hud_hot: bool = false
var is_panning: bool = false
var press_id: String = ""
var menu_rect: Rect2 = Rect2()
var sound_rect: Rect2 = Rect2()
var cmd_rect: Rect2 = Rect2()
var wave_rect: Rect2 = Rect2()
var sound_hot: bool = false
var cmd_hot: bool = false
var wave_hot: bool = false

# HUD feedback animations
var gold_shown: float = 240.0
var gold_bump: float = 0.0
var gold_icon_pos: Vector2 = Vector2(92.0, 28.0)
var hurt_t: float = 0.0
var deny_t: float = 0.0
var slain_bump: float = 0.0
var last_slain: int = 0
var last_lives: int = 20
var hud_coins: Array[Dictionary] = []

# Banner
var banner_text: String = ""
var banner_t: float = 0.0
var banner_dur: float = 0.0
var banner_big: bool = false

# Gamepad state (D3)
var gp_sel: int = -1
var gp_active: bool = false
var gp_repeat: float = 0.0

# 3D terrain-conforming range & hover rings
var ring_range: MeshInstance3D
var ring_pad: MeshInstance3D
var ring_range_mat: StandardMaterial3D
var ring_pad_mat: StandardMaterial3D
var _ring_pad_key: String = ""
var _ring_range_key: String = ""
var _ring_time: float = 0.0


func init_ui(p_game: CWGame, p_audio: CWAudio, world_root: Node3D, p_cam: Camera3D, p_sub_vp: SubViewport) -> void:
	cam_ref = p_cam
	sub_vp_ref = p_sub_vp
	game = p_game
	audio = p_audio
	layer = 10
	gold_shown = float(game.gold)
	last_lives = game.lives
	last_slain = game.slain

	_load_pixel_assets()
	_build_hud_canvas()
	_build_3d_rings(world_root)


func _load_pixel_assets() -> void:
	var fnt = load("res://assets/fonts/pixel9.fnt")
	if fnt is FontFile:
		var ff := fnt as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		pixel_font = ff
	elif fnt is Font:
		pixel_font = fnt
	else:
		pixel_font = ThemeDB.fallback_font

	for nm in ICON_NAMES:
		var tex = load("res://assets/icons/%s.png" % nm)
		if tex is Texture2D:
			icons[nm] = tex


func _build_hud_canvas() -> void:
	if hud_canvas == null:
		hud_canvas = Control.new()
		hud_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(hud_canvas)
	if not hud_canvas.draw.is_connected(_draw_hud):
		hud_canvas.draw.connect(_draw_hud)


func toggle_perf_overlay() -> void:
	show_perf = not show_perf


func update_perf_overlay(fps: int, mons_n: int, foot_n: int, gpu_units: int, debris_n: int, glow_n: int, glow_cap: int) -> void:
	if not show_perf:
		return
	perf_line1 = "FPS %d · Mons %d · Guards %d" % [fps, mons_n, foot_n]
	perf_line2 = "GPU Units %d · Debris %d · Glow %d/%d" % [gpu_units, debris_n, glow_n, glow_cap]


func _build_3d_rings(world_root: Node3D) -> void:
	ring_range_mat = StandardMaterial3D.new()
	ring_range_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_range_mat.albedo_color = Color(1.5, 1.15, 0.6, 0.34)
	ring_range_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_range_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_range_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_range_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	ring_range_mat.render_priority = 6

	ring_range = MeshInstance3D.new()
	ring_range.material_override = ring_range_mat
	ring_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_range.visible = false
	world_root.add_child(ring_range)

	ring_pad_mat = StandardMaterial3D.new()
	ring_pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_pad_mat.albedo_color = Color(2.2, 1.7, 0.9, 0.55)
	ring_pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_pad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_pad_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_pad_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	ring_pad_mat.render_priority = 6

	ring_pad = MeshInstance3D.new()
	ring_pad.material_override = ring_pad_mat
	ring_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_pad.visible = false
	world_root.add_child(ring_pad)


func _build_terrain_ring_mesh(cx: float, cz: float, radius: float, width: float, segs: int, min_y: float = -1e9) -> ArrayMesh:
	var verts := PackedVector3Array()
	verts.resize(segs * 6)
	var vi := 0
	var r0 := maxf(0.05, radius)
	var r1 := radius + width
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var x00 := cx + c0 * r0
		var z00 := cz + s0 * r0
		var x01 := cx + c0 * r1
		var z01 := cz + s0 * r1
		var x10 := cx + c1 * r0
		var z10 := cz + s1 * r0
		var x11 := cx + c1 * r1
		var z11 := cz + s1 * r1
		var y00 := maxf(game.terrain.height_at(x00, z00), min_y) + 0.12
		var y01 := maxf(game.terrain.height_at(x01, z01), min_y) + 0.12
		var y10 := maxf(game.terrain.height_at(x10, z10), min_y) + 0.12
		var y11 := maxf(game.terrain.height_at(x11, z11), min_y) + 0.12
		var p0 := Vector3(x00, y00, z00)
		var p1 := Vector3(x01, y01, z01)
		var p2 := Vector3(x11, y11, z11)
		var p3 := Vector3(x10, y10, z10)
		verts[vi] = p0; verts[vi + 1] = p1; verts[vi + 2] = p2
		verts[vi + 3] = p0; verts[vi + 4] = p2; verts[vi + 5] = p3
		vi += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# --- Pixel text & icon helpers (always integer-scaled & nearest-filtered) ---
func _measure_px(txt: String) -> float:
	if txt.is_empty():
		return 0.0
	return maxf(0.0, pixel_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE).x - 1.0)


func _tw(txt: String, sc: int = -1) -> float:
	var s := ui_s if sc <= 0 else sc
	return _measure_px(txt) * float(s)


func _icon_size(nm: String) -> Vector2:
	if icons.has(nm):
		var t: Texture2D = icons[nm]
		return Vector2(t.get_width(), t.get_height())
	return Vector2.ZERO


func _draw_px_icon(nm: String, x: float, y: float, sc: int = -1, alpha: float = 1.0) -> void:
	if not icons.has(nm) or alpha <= 0.001:
		return
	var s := float(ui_s if sc <= 0 else sc)
	var t: Texture2D = icons[nm]
	hud_canvas.draw_texture_rect(t, Rect2(roundf(x), roundf(y), float(t.get_width()) * s, float(t.get_height()) * s), false, Color(1.0, 1.0, 1.0, alpha))


func _draw_px_text(txt: String, x: float, y: float, col: Color, sc: int = -1, align: String = "l", alpha: float = 1.0, outline: Color = Color(0, 0, 0, 0)) -> void:
	if txt.is_empty() or alpha <= 0.001:
		return
	var s := float(ui_s if sc <= 0 else sc)
	var w := _measure_px(txt) * s
	var dx := x
	if align == "c":
		dx = x - w * 0.5
	elif align == "r":
		dx = x - w
	dx = roundf(dx)
	var dy := roundf(y)
	var tc := Color(col.r, col.g, col.b, col.a * alpha)
	if outline.a > 0.001:
		var oc := Color(outline.r, outline.g, outline.b, outline.a * alpha)
		for ox in [-1.0, 0.0, 1.0]:
			for oy in [-1.0, 0.0, 1.0]:
				if ox == 0.0 and oy == 0.0:
					continue
				hud_canvas.draw_set_transform(Vector2(dx + ox * s, dy + oy * s), 0.0, Vector2(s, s))
				hud_canvas.draw_string(pixel_font, Vector2(0.0, float(FONT_BASE)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE, oc)
	hud_canvas.draw_set_transform(Vector2(dx, dy), 0.0, Vector2(s, s))
	hud_canvas.draw_string(pixel_font, Vector2(0.0, float(FONT_BASE)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE, tc)
	hud_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _proj_world(world_pos: Vector3) -> Vector2:
	if cam_ref == null or sub_vp_ref == null:
		return Vector2(-1000.0, -1000.0)
	var win_sz := get_viewport().get_visible_rect().size
	var vp_sz := Vector2(sub_vp_ref.size)
	if vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return Vector2(-1000.0, -1000.0)
	var sp := cam_ref.unproject_position(world_pos)
	return Vector2(sp.x * (win_sz.x / vp_sz.x), sp.y * (win_sz.y / vp_sz.y))


# --- Public interaction hooks called from main.gd ---
func touch_input() -> void:
	idle_t = 0.0
	game.ai_commander = false


func _deny() -> void:
	deny_t = 1.0
	audio.play_sfx("ui_deny", 0.6)


func _do_build(pad: Dictionary, kind: String) -> bool:
	touch_input()
	if game.build_tower(pad, kind, true):
		audio.play_sfx("ui_click", 0.8)
		select_pad(null)
		armed_kind = ""
		return true
	_deny()
	return false


func _do_upgrade(t: Dictionary) -> bool:
	touch_input()
	if game.upgrade_tower(t, true):
		audio.play_sfx("ui_click", 0.8)
		select_pad(null)
		return true
	_deny()
	return false


func _do_sell(t: Dictionary) -> bool:
	touch_input()
	game.sell_tower(t, true)
	select_pad(null)
	return true


func pick_kind(kind: String) -> void:
	touch_input()
	if selected_pad != null and selected_pad["tower"] == null:
		_do_build(selected_pad, kind)
		return
	if hovered_pad != null and hovered_pad["tower"] == null:
		_do_build(hovered_pad, kind)
		return
	if gp_active and gp_sel >= 0 and not game.terrain.layout.is_empty():
		var pads: Array = game.terrain.layout["pads"]
		if gp_sel < pads.size() and pads[gp_sel]["tower"] == null:
			_do_build(pads[gp_sel], kind)
			return
	armed_kind = "" if armed_kind == kind else kind
	selected_pad = null
	audio.play_sfx("ui_click", 0.5)


func on_mouse_move(pos: Vector2) -> void:
	mouse_pos = pos
	mouse_inside = true
	moved_t = 0.0
	gp_active = false


func is_point_on_hud(pos: Vector2) -> bool:
	if menu_rect.size.x > 0.0 and menu_rect.has_point(pos):
		return true
	for hb in hud_btns:
		if (hb["rect"] as Rect2).has_point(pos):
			return true
	if sound_rect.has_point(pos) or cmd_rect.has_point(pos) or wave_rect.has_point(pos):
		return true
	return false


func on_hud_press(pos: Vector2) -> void:
	for hb in hud_btns:
		if (hb["rect"] as Rect2).has_point(pos):
			press_id = String(hb["id"])
			return
	if not hot_btn.is_empty():
		press_id = String(hot_btn["id"])


func on_mouse_tap(pos: Vector2, picked_pad) -> bool:
	mouse_pos = pos
	mouse_inside = true
	gp_active = false
	# 1. Toolbar / HUD buttons (Pause, Speed, Sound, Zoom, Follow)
	for hb in hud_btns:
		if (hb["rect"] as Rect2).has_point(pos):
			var fn: Callable = hb["fn"]
			if fn.is_valid():
				fn.call()
			return true
	# 2. Commander toggle plate
	if cmd_rect.has_point(pos):
		game.ai_commander = not game.ai_commander
		if game.ai_commander:
			select_pad(null)
			armed_kind = ""
		idle_t = 0.0
		audio.play_sfx("ui_click", 0.8)
		return true
	# 3. Wave plate (call next wave early)
	if wave_rect.has_point(pos):
		touch_input()
		if game.call_wave_early():
			audio.play_sfx("ui_click", 0.8)
		else:
			_deny()
		return true
	# 4. Active menu button
	if not hot_btn.is_empty():
		touch_input()
		var fn: Callable = hot_btn["fn"]
		if fn.is_valid():
			fn.call()
		return true
	if menu_rect.size.x > 0.0 and menu_rect.has_point(pos):
		return true
	# 5. Pad click
	if picked_pad != null:
		touch_input()
		if picked_pad["tower"] == null and armed_kind != "":
			_do_build(picked_pad, armed_kind)
			return true
		if selected_pad != null and selected_pad == picked_pad:
			select_pad(null)
			return true
		select_pad(picked_pad)
		armed_kind = ""
		return true
	elif selected_pad != null or armed_kind != "":
		select_pad(null)
		armed_kind = ""
		return true
	return false


func on_mouse_up() -> void:
	press_id = ""


func select_pad(pad) -> void:
	selected_pad = pad
	menu_t = 0.0
	menu_focus = 0
	sell_armed = false
	if pad != null:
		audio.play_sfx("ui_click", 0.55)


func saw_monster(mtype: String) -> void:
	if game == null or game.seen_mobs.has(mtype):
		return
	game.seen_mobs[mtype] = true
	if CWMonsters.DEFS.has(mtype) and CWMonsters.DEFS[mtype].has("tip") and tip_queue.size() < 4:
		tip_queue.append(mtype)


func press_sell_key() -> void:
	if selected_pad == null or selected_pad["tower"] == null:
		return
	touch_input()
	var t: Dictionary = selected_pad["tower"]
	if sell_armed:
		_do_sell(t)
	else:
		sell_armed = true
		audio.play_sfx("ui_click", 0.6)


func spawn_hud_coins(world_pos: Vector3, bounty: int, is_boss: bool) -> void:
	if cam_ref == null or sub_vp_ref == null:
		return
	if hud_coins.size() >= 70:
		gold_shown = minf(float(game.gold), gold_shown + float(bounty))
		return
	var sp := _proj_world(world_pos)
	var n := 18 if is_boss else clampi(int(floorf(float(bounty) / 3.0)), 1, 5)
	var val_each := float(bounty) / float(maxi(1, n))
	for _i in range(n):
		if hud_coins.size() >= 70:
			break
		hud_coins.append({
			"sx": sp.x + randf_range(-10.0, 10.0),
			"sy": sp.y + randf_range(-8.0, 8.0),
			"cx": sp.x + randf_range(-60.0, 60.0) * float(ui_s),
			"cy": sp.y - randf_range(30.0, 70.0) * float(ui_s),
			"t": 0.0,
			"dur": randf_range(0.55, 0.8),
			"val": val_each,
		})


func show_banner(text: String, dur: float, is_boss: bool) -> void:
	banner_text = text
	banner_t = 0.0
	banner_dur = dur
	banner_big = is_boss


# --- D3: Gamepad polling (72-ui.js:102-123) ---
func _poll_gamepad(dt: float) -> void:
	if game.terrain.layout.is_empty() or game.phase != "play":
		return
	var ax := 0.0
	var ay := 0.0
	if Input.is_action_pressed("cw_right"):
		ax += 1.0
	if Input.is_action_pressed("cw_left"):
		ax -= 1.0
	if Input.is_action_pressed("cw_down"):
		ay += 1.0
	if Input.is_action_pressed("cw_up"):
		ay -= 1.0
	if ax == 0.0 and ay == 0.0:
		var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		if absf(joy_x) > 0.5:
			ax = signf(joy_x)
		if absf(joy_y) > 0.5:
			ay = signf(joy_y)

	gp_repeat -= dt
	if (ax != 0.0 or ay != 0.0) and gp_repeat <= 0.0:
		gp_repeat = 0.22
		gp_active = true
		touch_input()
		if selected_pad != null:
			var n := maxi(1, btns.size())
			var step := int(ax if ax != 0.0 else ay)
			menu_focus = posmod(menu_focus + step, n)
			audio.play_sfx("ui_click", 0.45)
		else:
			var pads: Array = game.terrain.layout["pads"]
			if pads.is_empty():
				return
			if gp_sel < 0 or gp_sel >= pads.size():
				gp_sel = 0
			var cp: Dictionary = pads[gp_sel]
			var cur := _proj_world(Vector3(cp["x"], cp["y"], cp["z"]))
			var best := -1
			var best_sc := 1e9
			for i in range(pads.size()):
				if i == gp_sel:
					continue
				var p: Dictionary = pads[i]
				var q := _proj_world(Vector3(p["x"], p["y"], p["z"]))
				var dx := q.x - cur.x
				var dy := q.y - cur.y
				var along := dx * ax + dy * ay
				if along <= 4.0:
					continue
				var off := absf(-dx * ay + dy * ax)
				var sc := along + off * 2.2
				if sc < best_sc:
					best_sc = sc
					best = i
			if best >= 0:
				gp_sel = best
				audio.play_sfx("ui_click", 0.45)
	if ax == 0.0 and ay == 0.0:
		gp_repeat = 0.0

	if Input.is_action_just_pressed("cw_confirm"):
		touch_input()
		gp_active = true
		var pads: Array = game.terrain.layout["pads"]
		if gp_sel < 0 or gp_sel >= pads.size():
			gp_sel = 0
		if selected_pad != null:
			if menu_focus >= 0 and menu_focus < btns.size():
				var fn: Callable = btns[menu_focus]["fn"]
				if fn.is_valid():
					fn.call()
		elif not pads.is_empty():
			select_pad(pads[gp_sel])
	if Input.is_action_just_pressed("cw_cancel"):
		select_pad(null)
		armed_kind = ""
		touch_input()
	if Input.is_action_just_pressed("cw_upgrade"):
		var pads: Array = game.terrain.layout["pads"]
		if gp_sel >= 0 and gp_sel < pads.size() and pads[gp_sel]["tower"] != null:
			_do_upgrade(pads[gp_sel]["tower"])
	if Input.is_action_just_pressed("cw_call_wave"):
		touch_input()
		if game.call_wave_early():
			audio.play_sfx("ui_click", 0.8)
		else:
			_deny()


func update_ui(dt: float) -> void:
	var win_sz := get_viewport().get_visible_rect().size
	ui_s = maxi(2, int(roundf(win_sz.y / 430.0)))

	idle_t += dt
	moved_t += dt
	title_t += dt
	hurt_t = maxf(0.0, hurt_t - dt * 1.6)
	gold_bump = maxf(0.0, gold_bump - dt * 5.0)
	deny_t = maxf(0.0, deny_t - dt * 3.0)
	slain_bump = maxf(0.0, slain_bump - dt * 4.0)

	if game.lives < last_lives:
		hurt_t = 1.0
	last_lives = game.lives
	if game.slain != last_slain:
		last_slain = game.slain
		slain_bump = 1.0

	_poll_gamepad(dt)

	if selected_pad != null:
		menu_t += dt
		if game.phase != "play":
			select_pad(null)
	if game.phase != "play":
		armed_kind = ""
		hovered_pad = null

	# Smooth coin-driven gold readout
	if gold_shown > float(game.gold):
		gold_shown = float(game.gold)
	if hud_coins.is_empty() and gold_shown < float(game.gold):
		gold_shown = minf(float(game.gold), gold_shown + maxf(1.0, (float(game.gold) - gold_shown) * 6.0 * dt))

	var hci := hud_coins.size() - 1
	while hci >= 0:
		hud_coins[hci]["t"] = float(hud_coins[hci]["t"]) + dt
		if float(hud_coins[hci]["t"]) >= float(hud_coins[hci]["dur"]):
			gold_shown = minf(float(game.gold), gold_shown + float(hud_coins[hci]["val"]))
			hud_coins.remove_at(hci)
			gold_bump = 1.0
			audio.play_sfx("coin", 0.30)
		hci -= 1

	if banner_dur > 0.0:
		banner_t += dt
		if banner_t >= banner_dur:
			banner_dur = 0.0
			banner_text = ""

	if not active_tip.is_empty():
		active_tip["t"] = float(active_tip["t"]) + dt
		if float(active_tip["t"]) > 5.2:
			active_tip.clear()
	elif not tip_queue.is_empty() and title_t > 7.5:
		active_tip = {"type": tip_queue.pop_front(), "t": 0.0}

	# Update 3D terrain-conforming pad & range ring indicators (72-ui.js:135-142)
	_ring_time += dt
	var gp_pad = null
	if gp_active and gp_sel >= 0 and game.phase == "play" and not game.terrain.layout.is_empty():
		var pads: Array = game.terrain.layout["pads"]
		if gp_sel < pads.size():
			gp_pad = pads[gp_sel]
	var focus_pad = selected_pad if selected_pad != null else (gp_pad if gp_pad != null else (null if not hot_btn.is_empty() else hovered_pad))
	if focus_pad != null and game.phase == "play":
		var px := float(focus_pad["x"])
		var pz := float(focus_pad["z"])
		var py := float(focus_pad["y"])
		var pad_key := "%d_%d" % [game.level, int(focus_pad["idx"])]
		if pad_key != _ring_pad_key:
			_ring_pad_key = pad_key
			ring_pad.mesh = _build_terrain_ring_mesh(px, pz, 1.5, 0.10, 40, py + 0.02)
		var pulse := 0.5 + 0.5 * sin(_ring_time * 5.0)
		ring_pad_mat.albedo_color.a = 0.45 + 0.25 * pulse
		ring_pad.visible = true

		var t = focus_pad["tower"]
		var r: float = 0.0
		if t != null:
			r = float(t["def"]["range"][int(t["lvl"])])
		else:
			var pk := ""
			if selected_pad != null and not hot_btn.is_empty() and String(hot_btn.get("kind", "")) != "":
				pk = String(hot_btn["kind"])
			elif armed_kind != "":
				pk = armed_kind
			elif selected_pad != null and gp_active and menu_focus >= 0 and menu_focus < btns.size() and String(btns[menu_focus].get("kind", "")) != "":
				pk = String(btns[menu_focus]["kind"])
			else:
				pk = "archer"
			r = float(CWTowers.DEFS[pk]["range"][0])
		var rng_key := "%s_%.2f" % [pad_key, r]
		if rng_key != _ring_range_key:
			_ring_range_key = rng_key
			ring_range.mesh = _build_terrain_ring_mesh(px, pz, r, 0.07, 96)
		ring_range.visible = true
	else:
		ring_pad.visible = false
		ring_range.visible = false

	if is_panning:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)
	else:
		var pointer := (not hot_btn.is_empty()) or (hovered_pad != null and game.phase == "play") or sound_hot or cmd_hot or wave_hot or hud_hot
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if pointer else DisplayServer.CURSOR_ARROW)

	if hud_canvas != null:
		hud_canvas.queue_redraw()


# --- Unified pixel HUD draw pass (72-ui.js:145-254) ---
func _draw_hud() -> void:
	if cam_ref == null or sub_vp_ref == null or game == null:
		return
	var win_sz := get_viewport().get_visible_rect().size
	var W := win_sz.x
	var H := win_sz.y
	var vp_sz := Vector2(sub_vp_ref.size)
	if W < 10.0 or H < 10.0 or vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return

	var s := ui_s
	var sf := float(s)
	var pad := 5.0 * sf
	var lh := float(FONT_LINE) * sf
	var pix := maxf(1.0, roundf(H / vp_sz.y))

	btns.clear()
	var next_hot: Dictionary = {}

	# 1. Monster & footman health bars
	var col_man := Color(0.498, 0.714, 0.918, 1.0)
	var col_hi := Color(0.851, 0.631, 0.235, 1.0)
	var col_mid := Color(0.878, 0.463, 0.173, 1.0)
	var col_lo := Color(0.878, 0.290, 0.196, 1.0)

	for m: CWMonsterUnit in game.monsters_sys.mons:
		if m.dead or m.dying > 0.0:
			continue
		var is_boss := bool(m.def.get("boss", false))
		if not is_boss and m.hp >= m.max_hp * 0.999:
			continue
		var f := clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0)
		var wpos := Vector3(m.x, m.y + float(m.def["hit_h"]) * 1.65 + (0.65 if is_boss else 0.35), m.z)
		var sp := _proj_world(wpos)
		var bw := (34.0 if is_boss else 9.0) * pix
		var bh := (2.0 if is_boss else 1.0) * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		if bx < -bw or bx > W or by < 0.0 or by > H:
			continue
		var alpha := 0.40 if f >= 0.999 else 0.95
		var fill_c := col_hi if f > 0.5 else (col_mid if f > 0.25 else col_lo)
		hud_canvas.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(COL_DARK.r, COL_DARK.g, COL_DARK.b, alpha))
		hud_canvas.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(fill_c.r, fill_c.g, fill_c.b, alpha))
		if is_boss:
			_draw_px_text(String(m.def["name"]), sp.x, by - lh - 2.0 * pix, COL_TX, s, "c", 1.0, COL_DARK)

	for fm: CWFootmanUnit in game.towers_sys.footmen:
		var fhp := fm.hp
		var fmhp := maxf(fm.max_hp, 1.0)
		if fhp >= fmhp * 0.999:
			continue
		var f := clampf(fhp / fmhp, 0.0, 1.0)
		var sp := _proj_world(Vector3(fm.x, fm.y + 1.38, fm.z))
		var bw := 8.0 * pix
		var bh := 1.0 * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		hud_canvas.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(COL_DARK.r, COL_DARK.g, COL_DARK.b, 0.95))
		hud_canvas.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(col_man.r, col_man.g, col_man.b, 0.95))

	# 2. Top-left stats plate (flame / coin / skull)
	var stats := [
		["flame", str(game.lives), COL_RED if hurt_t > 0.0 else COL_TX],
		["coin", str(int(floorf(gold_shown))), COL_RED if deny_t > 0.0 else (COL_GOLD_HI if gold_bump > 0.0 else COL_TX)],
		["skull", str(game.slain), Color.WHITE if slain_bump > 0.5 else COL_TX],
	]
	var w_s := pad
	for st in stats:
		var isz := _icon_size(String(st[0]))
		w_s += isz.x * sf + 2.0 * sf + maxf(_tw(String(st[1])), _tw("000")) + 6.0 * sf
	w_s += pad - 6.0 * sf
	var h_s := 10.0 * sf + pad * 2.0 - 2.0 * sf
	var x0 := 5.0 * sf
	var y0 := 5.0 * sf
	PixelPanel.draw_plate(hud_canvas, x0, y0, w_s, h_s, s, COL_BG, COL_RED if hurt_t > 0.0 else COL_BD)
	var cur_x := x0 + pad
	for st in stats:
		var nm: String = st[0]
		var val: String = st[1]
		var col: Color = st[2]
		var isz := _icon_size(nm)
		var iy := y0 + roundf((h_s - isz.y * sf) * 0.5)
		var ia := (0.55 + 0.45 * (float(game.lives) / float(maxi(1, game.max_lives)))) if nm == "flame" else 1.0
		_draw_px_icon(nm, cur_x, iy, s, ia)
		if nm == "coin":
			gold_icon_pos = Vector2(cur_x + isz.x * sf * 0.5, iy + isz.y * sf * 0.5)
		cur_x += isz.x * sf + 2.0 * sf
		_draw_px_text(val, cur_x, y0 + roundf((h_s - lh) * 0.5) + sf, col, s)
		cur_x += maxf(_tw(val), _tw("000")) + 6.0 * sf

	# 3. Top-center Wave plate & Top-right Commander plate (responsive anti-overlap)
	var wn := "Wave %d" % maxi(1, game.wave_number())
	var sub := ""
	var frac := -1.0
	var can_call := game.phase == "play" and not game.spawning and not game.boss_wave and game.next_in > 0.4
	var pre_wave_hot := can_call and mouse_inside and wave_rect.size.x > 0.0 and wave_rect.has_point(mouse_pos)
	if game.phase == "play":
		if not game.spawning and not game.boss_wave and game.next_in > 0.0:
			if pre_wave_hot:
				sub = "Call now · +%d" % int(roundf(game.next_in * 3.0))
			else:
				sub = "Next wave in %d" % maxi(1, int(ceilf(game.next_in)))
			frac = 1.0 - game.next_in / 6.5
		else:
			sub = "%d on the road" % (game.monsters_sys.mons.size() + game.queue.size())
	elif game.phase == "defeat":
		sub = "The fire has died"
	elif game.phase == "clear":
		sub = "Boss defeated"
	else:
		sub = "A new pass awaits"

	var bw_ic := _icon_size("banner").x * sf
	var w_w := maxf(maxf(bw_ic + 3.0 * sf + _tw(wn), _tw(sub)), _tw("Call now · +18")) + pad * 2.0 + 4.0 * sf
	var h_w := lh * 2.0 + pad * 2.0 + sf

	var you := not game.ai_commander
	var ct := "You command" if you else "AI commander"
	var cs := "Click here for the AI" if you else "Click a pad to take over"
	var ic_cmd := "hand" if you else "helm"
	var icw := _icon_size(ic_cmd).x * sf
	var c_w := maxf(icw + 3.0 * sf + _tw(ct), _tw(cs)) + pad * 2.0 + 2.0 * sf
	if show_perf and not perf_line1.is_empty():
		var pw := maxf(_tw(perf_line1), _tw(perf_line2)) + pad * 2.0
		var ph := lh * 2.0 + pad * 2.0 + sf
		var py: float = 5.0 * sf + h_s + 4.0 * sf
		PixelPanel.draw_plate(hud_canvas, 5.0 * sf, py, pw, ph, s, COL_BG, COL_BD)
		_draw_px_text(perf_line1, 5.0 * sf + pad, py + pad, COL_AMBER, s)
		_draw_px_text(perf_line2, 5.0 * sf + pad, py + pad + lh + sf, COL_TX, s)

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

	wave_rect = Rect2(xw, yw, w_w, h_w)
	wave_hot = can_call and mouse_inside and wave_rect.has_point(mouse_pos)
	PixelPanel.draw_plate(hud_canvas, xw, yw, w_w, h_w, s, COL_BG2 if wave_hot else COL_BG, COL_BD_HI if wave_hot else COL_BD)
	var tx0 := roundf(W * 0.5 - (bw_ic + 3.0 * sf + _tw(wn)) * 0.5)
	_draw_px_icon("banner", tx0, yw + pad - sf, s)
	_draw_px_text(wn, tx0 + bw_ic + 3.0 * sf, yw + pad, COL_AMBER, s)
	_draw_px_text(sub, W * 0.5, yw + pad + lh + sf, COL_DIM, s, "c")
	if frac >= 0.0:
		hud_canvas.draw_rect(Rect2(xw + 3.0 * sf, yw + h_w - 3.0 * sf, w_w - 6.0 * sf, sf), Color(0.165, 0.149, 0.125, 1.0))
		hud_canvas.draw_rect(Rect2(xw + 3.0 * sf, yw + h_w - 3.0 * sf, roundf((w_w - 6.0 * sf) * clampf(frac, 0.0, 1.0)), sf), COL_AMBER)

	cmd_rect = Rect2(xc, yc, c_w, h_w)
	cmd_hot = mouse_inside and cmd_rect.has_point(mouse_pos)
	PixelPanel.draw_plate(hud_canvas, xc, yc, c_w, h_w, s, COL_BG2 if cmd_hot else COL_BG, COL_BD_HI if (cmd_hot or you) else COL_BD)
	_draw_px_icon(ic_cmd, xc + pad, yc + pad - sf, s)
	_draw_px_text(ct, xc + pad + icw + 3.0 * sf, yc + pad, COL_AMBER if you else COL_TX, s)
	_draw_px_text(cs, xc + pad, yc + pad + lh + sf, COL_DIM, s)

	# 4. Bottom Pixel Toolbar: Pause (P), Speed (Tab), Sound (M) on left; Zoom (- / +) & Follow on right (72-ui.js:280-325)
	hud_btns.clear()
	hud_hot = false
	menu_rect = Rect2()
	var h_b := lh + pad * 2.0 - sf
	var zb := h_b
	var y_b := H - zb - 5.0 * sf
	var tip_state := {"text": "", "x": 0.0}
	var col_bd_on := Color(0.541, 0.416, 0.227, 1.0)
	var col_dim_btn := Color(0.353, 0.329, 0.282, 1.0)

	var draw_sq := func(id: String, bx: float, bw: float, fn: Callable, tip: String, on: bool) -> Dictionary:
		var r := Rect2(bx, y_b, bw, zb)
		var is_h := mouse_inside and not is_panning and r.has_point(mouse_pos)
		var is_d := press_id == id
		var dy := sf if is_d else 0.0
		hud_btns.append({"id": id, "rect": r, "fn": fn})
		if is_h:
			hud_hot = true
			tip_state["text"] = tip
			tip_state["x"] = bx + bw * 0.5
		PixelPanel.draw_plate(hud_canvas, bx, y_b + dy, bw, zb, s, COL_BG2 if (is_h or is_d) else COL_BG, COL_BD_HI if (is_h or is_d) else (col_bd_on if on else COL_BD))
		return {"dy": dy}

	var xl := 5.0 * sf
	# Pause button
	var bp_r: Dictionary = draw_sq.call("pause", xl, zb, func():
		if main_ref != null:
			main_ref.call("toggle_pause")
	, "Resume (P)" if game.paused else "Pause (P)", game.paused)
	var u_p := zb / 18.0
	var py_b := y_b + float(bp_r["dy"])
	if game.paused:
		for pi in range(4):
			hud_canvas.draw_rect(Rect2(roundf(xl + (6.5 + float(pi) * 1.5) * u_p), roundf(py_b + (5.0 + float(pi)) * u_p), ceilf(1.5 * u_p), roundf((8.0 - 2.0 * float(pi)) * u_p)), COL_TX)
	else:
		hud_canvas.draw_rect(Rect2(roundf(xl + 6.0 * u_p), roundf(py_b + 5.0 * u_p), roundf(2.2 * u_p), roundf(8.0 * u_p)), COL_TX)
		hud_canvas.draw_rect(Rect2(roundf(xl + 9.8 * u_p), roundf(py_b + 5.0 * u_p), roundf(2.2 * u_p), roundf(8.0 * u_p)), COL_TX)
	xl += zb + g3

	# Speed button (1x / 2x / 3x)
	var bs_r: Dictionary = draw_sq.call("speed", xl, zb, func():
		if main_ref != null:
			main_ref.call("cycle_speed")
	, "Speed (Tab)", game.speed > 1)
	var sp_lbl := "%dx" % game.speed
	_draw_px_text(sp_lbl, xl + zb * 0.5, y_b + float(bs_r["dy"]) + roundf((zb - lh) * 0.5) + sf, COL_AMBER if game.speed > 1 else COL_TX, s, "c")
	xl += zb + g3

	# Sound icon button
	var snd_ic := "mute" if audio.muted else "sound"
	var bsnd_r: Dictionary = draw_sq.call("sound", xl, zb, func():
		audio.set_muted(not audio.muted)
		audio.play_sfx("ui_click", 0.6)
	, "Sound is off (M)" if audio.muted else "Sound is on (M)", false)
	var s_isz := _icon_size(snd_ic)
	_draw_px_icon(snd_ic, xl + roundf((zb - s_isz.x * sf) * 0.5), y_b + float(bsnd_r["dy"]) + roundf((zb - s_isz.y * sf) * 0.5), s)
	sound_rect = Rect2(xl, y_b, zb, zb)
	sound_hot = mouse_inside and not is_panning and sound_rect.has_point(mouse_pos)
	xl += zb + g3

	# Biome selector button (click to open 5-biome picker; B cycles, F1-F5 direct, R new seed)
	var cur_bname: String = String(game.terrain.bio.get("name", "Ashen Pass"))
	var bw_bio := _tw(cur_bname) + pad * 2.0 + 4.0 * sf
	var bbio_r: Dictionary = draw_sq.call("biome_btn", xl, bw_bio, func():
		biome_picker_open = not biome_picker_open
		audio.play_sfx("ui_click", 0.6)
	, "Switch biome (B / F1-F5, R reroll)", biome_picker_open)
	_draw_px_text(cur_bname, xl + bw_bio * 0.5, y_b + float(bbio_r["dy"]) + roundf((zb - lh) * 0.5) + sf, COL_AMBER if biome_picker_open else COL_TX, s, "c")

	if biome_picker_open:
		var py_bio := y_b - zb - g3
		var px_bio := xl
		var cur_key: String = String(game.terrain.bio.get("key", ""))
		for bi in range(CWBiome.BIOMES.size()):
			var bdict: Dictionary = CWBiome.BIOMES[bi]
			var bnm: String = String(bdict["name"])
			var is_cur := String(bdict["key"]) == cur_key
			var b_idx := bi
			var bw_opt := _tw(bnm) + pad * 2.0
			var r_opt := Rect2(px_bio, py_bio, bw_opt, zb)
			var h_opt := mouse_inside and not is_panning and r_opt.has_point(mouse_pos)
			var d_opt := press_id == ("bio_%d" % b_idx)
			var dy_o := sf if d_opt else 0.0
			hud_btns.append({"id": "bio_%d" % b_idx, "rect": r_opt, "fn": func():
				biome_picker_open = false
				select_pad(null)
				game.switch_biome(b_idx)
				audio.play_sfx("ui_click", 0.7)
			})
			if h_opt:
				hud_hot = true
				tip_state["text"] = "F%d · %s" % [b_idx + 1, bnm]
				tip_state["x"] = px_bio + bw_opt * 0.5
			PixelPanel.draw_plate(hud_canvas, px_bio, py_bio + dy_o, bw_opt, zb, s, COL_BG2 if (h_opt or d_opt or is_cur) else COL_BG, COL_BD_HI if (h_opt or is_cur) else COL_BD)
			_draw_px_text(bnm, px_bio + bw_opt * 0.5, py_bio + dy_o + roundf((zb - lh) * 0.5) + sf, COL_AMBER if is_cur else COL_TX, s, "c")
			px_bio += bw_opt + g3
	xl += bw_bio + g3

	# Bottom-right Zoom (+) and (-) buttons
	var cur_z := float(main_ref.call("cam_zoom_now")) if main_ref != null else 1.0
	var min_z := float(main_ref.call("cam_zoom_min")) if main_ref != null else 0.5
	var xr := W - 5.0 * sf - zb
	var bzi_r: Dictionary = draw_sq.call("zin", xr, zb, func():
		if main_ref != null:
			main_ref.call("cam_zoom_by", 1.5)
	, "Zoom in (+)", false)
	_draw_px_text("+", xr + zb * 0.5, y_b + float(bzi_r["dy"]) + roundf((zb - lh) * 0.5) + sf, COL_TX if cur_z < 2.99 else col_dim_btn, s, "c")
	xr -= zb + g3

	var bzo_r: Dictionary = draw_sq.call("zout", xr, zb, func():
		if main_ref != null:
			main_ref.call("cam_zoom_by", 1.0 / 1.5)
	, "Zoom out (-)", false)
	_draw_px_text("-", xr + zb * 0.5, y_b + float(bzo_r["dy"]) + roundf((zb - lh) * 0.5) + sf, COL_TX if cur_z > min_z + 0.01 else col_dim_btn, s, "c")

	# "Center view" button when manually panned/zoomed
	var y_up := y_b - g3
	var is_man := bool(main_ref.get("cam_man")) if main_ref != null else false
	if is_man and (game.phase == "play" or game.phase == "defeat"):
		var flbl := "Follow the fight"
		var fw_b := _tw(flbl) + pad * 2.0
		var fits := xr - g3 - fw_b >= xl
		var xf2 := (xr - g3 - fw_b) if fits else (W - fw_b - 5.0 * sf)
		var yf := (y_b + roundf((zb - h_b) * 0.5)) if fits else (y_b - g3 - h_b)
		var fr := Rect2(xf2, yf, fw_b, h_b)
		var hot_f := mouse_inside and not is_panning and fr.has_point(mouse_pos)
		hud_btns.append({"id": "follow", "rect": fr, "fn": func():
			if main_ref != null:
				main_ref.call("cam_reset")
			audio.play_sfx("ui_click", 0.6)
		})
		if hot_f:
			hud_hot = true
		PixelPanel.draw_plate(hud_canvas, xf2, yf, fw_b, h_b, s, COL_BG2 if hot_f else COL_BG, COL_BD_HI if hot_f else col_bd_on)
		_draw_px_text(flbl, xf2 + pad, yf + pad - sf, COL_TX, s)
		if not fits:
			y_up = yf - g3

	# Hover shortcut tooltip above toolbar button
	var tip_text: String = String(tip_state["text"])
	if tip_text != "":
		var tw_t := _tw(tip_text) + pad * 2.0
		var tx_t := clampf(roundf(float(tip_state["x"]) - tw_t * 0.5), 4.0 * sf, W - tw_t - 4.0 * sf)
		var ty_t := y_b - g3 - h_b
		PixelPanel.draw_plate(hud_canvas, tx_t, ty_t, tw_t, h_b, s, COL_BG, COL_BD_HI)
		_draw_px_text(tip_text, tx_t + pad, ty_t + pad - sf, COL_TX, s)
		y_up = minf(y_up, ty_t - g3)

	# Paused banner
	if game.paused:
		var psc := s + 1
		var pt1 := "Paused"
		var pw_b := _tw(pt1, psc) + pad * 4.0
		var ph_b := float(FONT_LINE * psc) + pad * 2.0
		PixelPanel.draw_plate(hud_canvas, roundf(W * 0.5 - pw_b * 0.5), y_up - ph_b, pw_b, ph_b, s, COL_BG, COL_BD_HI)
		_draw_px_text(pt1, W * 0.5, y_up - ph_b + pad, COL_AMBER, psc, "c")
		y_up -= ph_b + g3

	# 5. Bottom centered controls hint plate (hidden when paused or menu open)
	var hint_a := clampf(minf(title_t - 7.2, 3.0 - (moved_t if idle_t > 20.0 else 0.0) + (8.0 if title_t < 18.0 else 0.0)), 0.0, 1.0)
	if hint_a > 0.02 and selected_pad == null and not game.paused:
		var hl := "Click a pad to build · 1-4 pick a tower · Space calls the next wave · Wheel zooms, drag moves the view"
		var hw := _tw(hl) + pad * 2.0
		var hh := lh + pad * 2.0 - sf
		if hw < W - 10.0 * sf:
			var hx := roundf((W - hw) * 0.5)
			var hy := y_up - hh
			PixelPanel.draw_plate(hud_canvas, hx, hy, hw, hh, s, COL_BG, COL_BD, Color(0, 0, 0, 0), hint_a)
			_draw_px_text(hl, hx + pad, hy + pad - sf, COL_DIM, s, "l", hint_a)

	# 6. Flying pixel coins
	var coin_s := maxi(2, s - 1)
	for qc in hud_coins:
		var u := clampf(float(qc["t"]) / float(qc["dur"]), 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var a := 1.0 - e
		var qx := a * a * float(qc["sx"]) + 2.0 * a * e * float(qc["cx"]) + e * e * gold_icon_pos.x
		var qy := a * a * float(qc["sy"]) + 2.0 * a * e * float(qc["cy"]) + e * e * gold_icon_pos.y
		_draw_px_icon("coin", qx - 4.0 * sf * 0.75, qy - 4.0 * sf * 0.75, coin_s)

	# 7. Wave / Boss Banner
	if banner_dur > 0.0 and not banner_text.is_empty():
		var ba := clampf(minf(banner_t * 3.0, (banner_dur - banner_t) * 2.0), 0.0, 1.0)
		if ba > 0.01:
			var bsc := s + (2 if banner_big else 1)
			var bw_b := _tw(banner_text, bsc) + pad * 4.0
			var bh_b := float(FONT_LINE * bsc) + pad * 2.0
			var yb := maxf(roundf(H * 0.2), y0 + top_h + 4.0 * sf)
			PixelPanel.draw_plate(hud_canvas, roundf(W * 0.5 - bw_b * 0.5), yb, bw_b, bh_b, s, COL_BG, COL_EMBER if banner_big else COL_BD_HI, Color(0, 0, 0, 0), ba)
			_draw_px_text(banner_text, W * 0.5, yb + pad, COL_BANNER_BIG if banner_big else COL_TX, bsc, "c", ba)

	# 8. Build / Upgrade Popup Menu (exact match to 72-ui.js:204-248 & image_e65201.png)
	if selected_pad != null and game.phase == "play":
		var tower = selected_pad["tower"]
		var top_off := minf(3.6, float(tower.get("top_y", 2.0))) if tower != null else 1.2
		var p := _proj_world(Vector3(selected_pad["x"], float(selected_pad["y"]) + top_off, selected_pad["z"]))
		var ma := clampf(menu_t * 8.0, 0.0, 1.0)
		var mp := 6.0 * sf

		if tower == null:
			var bwid := 31.0 * sf
			var bh := 35.0 * sf
			var gapb := 3.0 * sf
			var row_w := 4.0 * bwid + 3.0 * gapb
			var text_w := 0.0
			for l in ["Choose a tower", "Hover or press 1 to 4", "to see what each does."]:
				text_w = maxf(text_w, _tw(l))
			for knd in CWTowers.TOWER_KINDS:
				text_w = maxf(text_w, _tw(String(CWTowers.DEFS[knd]["name"])))
				for dl in TOWER_DESC_LINES[knd]:
					text_w = maxf(text_w, _tw(String(dl)))
			var wp := maxf(row_w, text_w) + mp * 2.0
			var hp := mp * 2.0 + lh + 3.0 * sf + bh + 4.0 * sf + lh * 3.0 + 2.0 * sf
			var px := clampf(roundf(p.x - wp * 0.5), 4.0 * sf, W - wp - 4.0 * sf)
			var py := clampf(roundf(p.y - hp - 7.0 * sf), minf(y0 + top_h + 4.0 * sf, H - hp - 4.0 * sf), H - hp - 4.0 * sf)
			menu_rect = Rect2(px, py, wp, hp)
			PixelPanel.draw_plate(hud_canvas, px, py, wp, hp, s, COL_BG, COL_BD, Color(0, 0, 0, 0), ma)
			_draw_px_text("Build here", px + mp, py + mp - sf, COL_AMBER, s, "l", ma)

			var bx0 := px + roundf((wp - row_w) * 0.5)
			var by := py + mp + lh + 3.0 * sf
			var lit_kind := ""
			var fk: String = String(CWTowers.TOWER_KINDS[menu_focus % 4]) if gp_active else ""
			for i in range(CWTowers.TOWER_KINDS.size()):
				var knd: String = CWTowers.TOWER_KINDS[i]
				var d: Dictionary = CWTowers.DEFS[knd]
				var cost := int(d["cost"][0])
				var can := game.gold >= cost
				var bx := bx0 + float(i) * (bwid + gapb)
				var bid := "b_" + knd
				var rect := Rect2(bx, by, bwid, bh)
				var over := mouse_inside and not gp_active and rect.has_point(mouse_pos)
				var focused := gp_active and btns.size() == menu_focus
				var b_entry := {"id": bid, "kind": knd, "fn": func(): _do_build(selected_pad, knd)}
				btns.append(b_entry)
				if over:
					next_hot = b_entry
				var down := press_id == bid
				var lit := over or focused
				var dy := sf if down else 0.0
				PixelPanel.draw_plate(
					hud_canvas, bx, by + dy, bwid, bh, s,
					COL_BG2 if lit else COL_BTN,
					COL_BD_HI if lit else (COL_BD if can else COL_BD_DIM),
					COL_HI if lit else Color(0, 0, 0, 0),
					ma
				)
				var isz := _icon_size(knd)
				_draw_px_icon(knd, bx + roundf((bwid - isz.x * sf) * 0.5), by + 6.0 * sf + dy, s, (1.0 if can else 0.45) * ma)
				_draw_px_text(str(i + 1), bx + 3.0 * sf, by + 2.0 * sf + dy, COL_DIM, s, "l", ma)
				var cost_s := str(cost)
				var cw2 := 8.0 * sf + 2.0 * sf + _tw(cost_s)
				var cx0 := bx + roundf((bwid - cw2) * 0.5)
				_draw_px_icon("coin", cx0, by + bh - lh - 3.0 * sf + dy, s, (1.0 if can else 0.5) * ma)
				_draw_px_text(cost_s, cx0 + 10.0 * sf, by + bh - lh - 3.0 * sf + dy, COL_AMBER if can else COL_RED, s, "l", ma)
				if lit:
					lit_kind = knd

			var show_k: String = lit_kind if lit_kind != "" else fk
			var ty := by + bh + 4.0 * sf
			if show_k != "":
				var dl: Array = TOWER_DESC_LINES[show_k]
				_draw_px_text(String(CWTowers.DEFS[show_k]["name"]), px + mp, ty, COL_TX, s, "l", ma)
				_draw_px_text(String(dl[0]), px + mp, ty + lh + sf, COL_DIM, s, "l", ma)
				_draw_px_text(String(dl[1]), px + mp, ty + lh * 2.0 + sf, COL_DIM, s, "l", ma)
			else:
				_draw_px_text("Choose a tower", px + mp, ty, COL_DIM, s, "l", ma)
				_draw_px_text("Hover or press 1 to 4", px + mp, ty + lh + sf, COL_DIM, s, "l", ma)
				_draw_px_text("to see what each does.", px + mp, ty + lh * 2.0 + sf, COL_DIM, s, "l", ma)
		else:
			var d: Dictionary = tower["def"]
			var lvl := int(tower["lvl"])
			var maxed := lvl >= 2
			var upc := 0 if maxed else int(d["cost"][lvl + 1])
			var can_up := (not maxed) and game.gold >= upc and String(tower["state"]) == "active"
			var refund := int(roundf(float(tower["spent"]) * 0.7))
			var ul := "Max level" if maxed else ("Upgrade %d" % upc)
			var sl := ("Confirm +%d" % refund) if sell_armed else ("Sell +%d" % refund)
			var iw9 := 9.0 * sf
			var bw3 := maxf(maxf(_tw(ul), _tw(sl)), _tw("Confirm +%d" % refund)) + iw9 + 11.0 * sf
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
			var wp := maxf(maxf(bw3 * 2.0 + 3.0 * sf, _tw(String(d["name"])) + 26.0 * sf), maxf(_tw(st_txt), _tw(nx_txt))) + mp * 2.0
			var hp := mp * 2.0 + lh * 3.0 + 7.0 * sf + bh
			var px := clampf(roundf(p.x - wp * 0.5), 4.0 * sf, W - wp - 4.0 * sf)
			var py := clampf(roundf(p.y - hp - 7.0 * sf), minf(y0 + top_h + 4.0 * sf, H - hp - 4.0 * sf), H - hp - 4.0 * sf)
			menu_rect = Rect2(px, py, wp, hp)
			PixelPanel.draw_plate(hud_canvas, px, py, wp, hp, s, COL_BG, COL_BD, Color(0, 0, 0, 0), ma)
			_draw_px_text(String(d["name"]), px + mp, py + mp - sf, COL_AMBER, s, "l", ma)
			for i in range(3):
				_draw_px_icon("star" if i <= lvl else "starEmpty", px + wp - mp - float(3 - i) * 6.0 * sf, py + mp, s, ma)
			_draw_px_text(st_txt, px + mp, py + mp + lh + sf, COL_DIM, s, "l", ma)
			_draw_px_text(nx_txt, px + mp, py + mp + lh * 2.0 + 2.0 * sf, COL_DIM if maxed else COL_AMBER, s, "l", ma)

			var by := py + mp + lh * 3.0 + 7.0 * sf
			var bwf := floorf((wp - mp * 2.0 - 3.0 * sf) * 0.5)
			# Upgrade button
			var r_up := Rect2(px + mp, by, bwf, bh)
			var over_up := mouse_inside and not gp_active and r_up.has_point(mouse_pos)
			var foc_up := gp_active and btns.size() == menu_focus
			var b_up := {"id": "up", "kind": "", "fn": func(): _do_upgrade(tower)}
			btns.append(b_up)
			if over_up:
				next_hot = b_up
			var lit_up := over_up or foc_up
			var dy_up := sf if press_id == "up" else 0.0
			PixelPanel.draw_plate(hud_canvas, px + mp, by + dy_up, bwf, bh, s, COL_BG2 if lit_up else COL_BTN, COL_BD_HI if lit_up else (COL_BD if can_up else COL_BD_DIM), COL_HI if lit_up else Color(0, 0, 0, 0), ma)
			_draw_px_icon("upgrade", px + mp + 4.0 * sf, by + 3.0 * sf + dy_up, s, (1.0 if can_up else 0.4) * ma)
			_draw_px_text(ul, px + mp + 4.0 * sf + iw9 + 3.0 * sf, by + 3.0 * sf + dy_up, COL_TX if can_up else (COL_DIM if maxed else COL_RED), s, "l", ma)

			# Sell button (two-step confirmation matching 72-ui.js:379)
			var sx_btn := px + mp + bwf + 3.0 * sf
			var r_sl := Rect2(sx_btn, by, bwf, bh)
			var over_sl := mouse_inside and not gp_active and r_sl.has_point(mouse_pos)
			var foc_sl := gp_active and btns.size() == menu_focus
			var b_sl := {"id": "sell", "kind": "", "fn": func():
				if not sell_armed:
					sell_armed = true
					audio.play_sfx("ui_click", 0.6)
				else:
					_do_sell(tower)
			}
			btns.append(b_sl)
			if over_sl:
				next_hot = b_sl
			var lit_sl := over_sl or foc_sl or sell_armed
			var dy_sl := sf if press_id == "sell" else 0.0
			PixelPanel.draw_plate(hud_canvas, sx_btn, by + dy_sl, bwf, bh, s, COL_BG2 if lit_sl else COL_BTN, COL_RED if sell_armed else (COL_BD_HI if lit_sl else COL_BD), COL_HI if lit_sl else Color(0, 0, 0, 0), ma)
			_draw_px_icon("sell", sx_btn + 4.0 * sf, by + 3.0 * sf + dy_sl, s, ma)
			_draw_px_text(sl, sx_btn + 4.0 * sf + iw9 + 3.0 * sf, by + 3.0 * sf + dy_sl, COL_RED if sell_armed else COL_TX, s, "l", ma)

	hot_btn = next_hot

	# 9. Armed tower cursor tooltip
	if armed_kind != "" and mouse_inside and game.phase == "play":
		var al := "%s: click a pad" % String(CWTowers.DEFS[armed_kind]["name"])
		var aw := _tw(al) + pad * 2.0
		var ah := lh + pad * 2.0 - sf
		var ax := clampf(mouse_pos.x + 10.0 * sf, 2.0 * sf, W - aw - 2.0 * sf)
		var ay := clampf(mouse_pos.y + 10.0 * sf, 2.0 * sf, H - ah - 2.0 * sf)
		PixelPanel.draw_plate(hud_canvas, ax, ay, aw, ah, s, COL_BG, COL_BD_HI)
		_draw_px_text(al, ax + pad, ay + pad - sf, COL_TX, s)

	# 9b. New Monster / Boss 5.2s Tip Card (72-ui.js:311-318)
	if not active_tip.is_empty() and selected_pad == null:
		var mtype: String = String(active_tip["type"])
		var tt: float = float(active_tip["t"])
		var tip_a := clampf(minf(tt * 4.0, (5.2 - tt) * 2.0), 0.0, 1.0)
		if tip_a > 0.01 and CWMonsters.DEFS.has(mtype):
			var md: Dictionary = CWMonsters.DEFS[mtype]
			var head := ("%s: %s" % ["Boss" if bool(md.get("boss", false)) else "New", String(md.get("name", mtype))])
			var body := String(md.get("tip", ""))
			var tip_w := maxf(_tw(head), _tw(body)) + pad * 3.0
			var tip_h := lh * 2.0 + pad * 2.0 + 2.0 * sf
			var tip_y := H - tip_h - zb - 10.0 * sf
			PixelPanel.draw_plate(hud_canvas, roundf(W * 0.5 - tip_w * 0.5), tip_y, tip_w, tip_h, s, COL_BG, COL_BD_HI if bool(md.get("boss", false)) else COL_BD, Color(0, 0, 0, 0), tip_a)
			_draw_px_text(head, W * 0.5, tip_y + pad, COL_AMBER, s, "c", tip_a)
			_draw_px_text(body, W * 0.5, tip_y + pad + lh + sf, COL_TX, s, "c", tip_a)

	# 10. Opening title card (first 7s)
	if title_t < 7.0 and selected_pad == null:
		var ta := clampf(minf((title_t - 0.4) * 1.5, (6.6 - title_t) * 1.2), 0.0, 1.0)
		if ta > 0.01:
			var sc2 := s * 2
			var t1 := "Cinderwatch"
			var t2 := "%s · The commander plays until you take over." % String(game.terrain.bio.get("name", "Ashen Pass"))
			var t3 := ("Best run: wave %d" % game.best_wave) if game.best_wave > 5 else ""
			var tw_box := maxf(maxf(_tw(t1, sc2), _tw(t2)), _tw(t3)) + pad * 4.0
			var extra_h := (lh + sf) if t3 != "" else 0.0
			var th_box := float(FONT_LINE * sc2) + lh + extra_h + pad * 2.0 + 2.0 * sf
			var yy := H - th_box - 22.0 * sf
			PixelPanel.draw_plate(hud_canvas, roundf(W * 0.5 - tw_box * 0.5), yy, tw_box, th_box, s, COL_BG, COL_BD, Color(0, 0, 0, 0), ta)
			_draw_px_text(t1, W * 0.5, yy + pad, COL_BANNER_BIG, sc2, "c", ta)
			_draw_px_text(t2, W * 0.5, yy + pad + float(FONT_LINE * sc2) + sf, COL_DIM, s, "c", ta)
			if t3 != "":
				_draw_px_text(t3, W * 0.5, yy + pad + float(FONT_LINE * sc2) + lh + 2.0 * sf, COL_AMBER, s, "c", ta)
