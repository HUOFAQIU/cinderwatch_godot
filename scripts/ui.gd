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


func update_perf_overlay(fps: int, mons_n: int, foot_n: int, gpu_units: int, mon_ms: float, rig_ms: float, tow_ms: float) -> void:
	if not show_perf:
		return
	perf_line1 = "FPS %d · Mons %d · Guards %d · Units %d" % [fps, mons_n, foot_n, gpu_units]
	perf_line2 = "CPU Mon %.1fms · Rig %.1fms · Tow %.1fms" % [mon_ms, rig_ms, tow_ms]


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
	CWUIDraw.draw_hud(self)
