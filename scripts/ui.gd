class_name CWUI
extends CanvasLayer

# Native Godot Control HUD (scenes/ui.tscn + assets/themes/pixel_theme.tres),
# lightweight WorldOverlay for 3D-projected HP bars & flying pixel coins,
# terrain-conforming 3D range/pad rings, and integer UI scaling.

const FONT_LINE := 9
const FONT_BASE := 8

const COL_BG := Color(0.0353, 0.0431, 0.0667, 0.86)
const COL_BG2 := Color(0.0941, 0.1059, 0.1490, 0.94)
const COL_BTN := Color(0.0627, 0.0706, 0.1059, 0.96)
const COL_BD := Color(0.3647, 0.2980, 0.2078, 1.0)
const COL_BD_DIM := Color(0.2275, 0.2039, 0.1725, 1.0)
const COL_BD_HI := Color(0.9098, 0.6902, 0.2902, 1.0)
const COL_BD_ON := Color(0.541, 0.416, 0.227, 1.0)
const COL_TX := Color(0.9373, 0.8941, 0.8039, 1.0)
const COL_DIM := Color(0.6549, 0.6196, 0.5412, 1.0)
const COL_DIM_BTN := Color(0.353, 0.329, 0.282, 1.0)
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
	"coin", "flame", "skull", "banner", "sound", "mute",
	"archer", "bombard", "spire", "guard", "upgrade", "sell",
	"helm", "hand", "star", "starEmpty", "pause", "play",
]

var main_ref: Node = null
var game: CWGame
var audio: CWAudio
var cam_ref: Camera3D
var sub_vp_ref: SubViewport

var pixel_font: Font
var icons: Dictionary = {}
var ui_s: int = 3

# Scene-tree HUD controls (scenes/ui.tscn)
@onready var world_overlay: Control = %WorldOverlay
@onready var hud_root: Control = %HudRoot

@onready var stats_plate: PanelContainer = %StatsPlate
@onready var flame_icon: TextureRect = %FlameIcon
@onready var lives_label: Label = %LivesLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var gold_label: Label = %GoldLabel
@onready var slain_label: Label = %SlainLabel

@onready var perf_plate: PanelContainer = %PerfPlate
@onready var perf_line1_lbl: Label = %PerfLine1
@onready var perf_line2_lbl: Label = %PerfLine2

@onready var wave_plate: PanelContainer = %WavePlate
@onready var wave_title_lbl: Label = %WaveTitle
@onready var wave_sub_lbl: Label = %WaveSub
@onready var wave_progress: ProgressBar = %WaveProgress

@onready var cmd_plate: PanelContainer = %CmdPlate
@onready var cmd_icon: TextureRect = %CmdIcon
@onready var cmd_title_lbl: Label = %CmdTitle
@onready var cmd_sub_lbl: Label = %CmdSub

@onready var pause_btn: Button = %PauseBtn
@onready var speed_btn: Button = %SpeedBtn
@onready var sound_btn: Button = %SoundBtn
@onready var biome_btn: Button = %BiomeBtn
@onready var biome_picker: HBoxContainer = %BiomePicker
@onready var follow_btn: Button = %FollowBtn
@onready var zoom_out_btn: Button = %ZoomOutBtn
@onready var zoom_in_btn: Button = %ZoomInBtn

@onready var tooltip_plate: PanelContainer = %TooltipPlate
@onready var tooltip_label: Label = %TooltipLabel
@onready var paused_plate: PanelContainer = %PausedPlate
@onready var hint_plate: PanelContainer = %HintPlate
@onready var banner_plate: PanelContainer = %BannerPlate
@onready var banner_label: Label = %BannerLabel
@onready var tip_plate: PanelContainer = %TipPlate
@onready var tip_head_lbl: Label = %TipHead
@onready var tip_body_lbl: Label = %TipBody
@onready var title_plate: PanelContainer = %TitlePlate
@onready var title_sub_lbl: Label = %TitleSub
@onready var title_best_lbl: Label = %TitleBest
@onready var armed_plate: PanelContainer = %ArmedPlate
@onready var armed_label: Label = %ArmedLabel

@onready var build_menu: PanelContainer = %BuildMenu
@onready var build_desc_title: Label = %BuildDescTitle
@onready var build_desc_l1: Label = %BuildDescLine1
@onready var build_desc_l2: Label = %BuildDescLine2

@onready var upgrade_menu: PanelContainer = %UpgradeMenu
@onready var upgrade_name_lbl: Label = %UpgradeName
@onready var upgrade_stats_lbl: Label = %UpgradeStats
@onready var upgrade_next_lbl: Label = %UpgradeNext
@onready var upgrade_btn: Button = %UpgradeBtn
@onready var sell_btn: Button = %SellBtn

var _bio_btns: Array[Button] = []
var _build_cards: Array[PanelContainer] = []
var _star_icons: Array[TextureRect] = []

# Shared reusable StyleBoxFlat presets (zero per-frame allocations)
var _sb_plate: StyleBoxFlat
var _sb_plate_hi: StyleBoxFlat
var _sb_plate_hover: StyleBoxFlat
var _sb_plate_hurt: StyleBoxFlat
var _sb_plate_ember: StyleBoxFlat
var _sb_card_normal: StyleBoxFlat
var _sb_card_dim: StyleBoxFlat
var _sb_card_lit: StyleBoxFlat
var _sb_btn_normal: StyleBoxFlat
var _sb_btn_on: StyleBoxFlat
var _sb_btn_sell_armed: StyleBoxFlat

# Interactive UI state
var show_perf: bool = false
var selected_pad = null
var hovered_pad = null
var menu_t: float = 0.0
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
var is_panning: bool = false

var _wave_hovered: bool = false
var _cmd_hovered: bool = false
var _hovered_build_kind: String = ""
var _hovered_tip_ctrl: Control = null
var _hovered_tip_text: String = ""

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
	_init_styleboxes()
	_wire_controls()
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


func _make_sb(bg: Color, bd: Color, pad_x: int = 5, pad_y: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bd
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(1)
	sb.corner_detail = 1
	sb.anti_aliasing = false
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func _init_styleboxes() -> void:
	_sb_plate = _make_sb(COL_BG, COL_BD, 5, 4)
	_sb_plate_hi = _make_sb(COL_BG, COL_BD_HI, 5, 4)
	_sb_plate_hover = _make_sb(COL_BG2, COL_BD_HI, 5, 4)
	_sb_plate_hurt = _make_sb(COL_BG, COL_RED, 5, 4)
	_sb_plate_ember = _make_sb(COL_BG, COL_EMBER, 6, 4)
	_sb_card_normal = _make_sb(COL_BTN, COL_BD, 2, 2)
	_sb_card_dim = _make_sb(COL_BTN, COL_BD_DIM, 2, 2)
	_sb_card_lit = _make_sb(COL_BG2, COL_BD_HI, 2, 2)
	_sb_btn_normal = _make_sb(COL_BG, COL_BD, 4, 3)
	_sb_btn_on = _make_sb(COL_BG, COL_BD_ON, 4, 3)
	_sb_btn_sell_armed = _make_sb(COL_BG2, COL_RED, 4, 3)


func _wire_controls() -> void:
	if not world_overlay.draw.is_connected(_draw_world_overlay):
		world_overlay.draw.connect(_draw_world_overlay)

	# Wave plate click & hover
	wave_plate.mouse_entered.connect(func(): _wave_hovered = true)
	wave_plate.mouse_exited.connect(func(): _wave_hovered = false)
	wave_plate.gui_input.connect(_on_wave_plate_input)

	# Commander plate click & hover
	cmd_plate.mouse_entered.connect(func(): _cmd_hovered = true)
	cmd_plate.mouse_exited.connect(func(): _cmd_hovered = false)
	cmd_plate.gui_input.connect(_on_cmd_plate_input)

	# Bottom-left toolbar buttons
	pause_btn.pressed.connect(func():
		if main_ref != null:
			main_ref.call("toggle_pause")
	)
	_bind_hover_tip(pause_btn, func() -> String:
		return "Resume (P)" if (game != null and game.paused) else "Pause (P)"
	)

	speed_btn.pressed.connect(func():
		if main_ref != null:
			main_ref.call("cycle_speed")
	)
	_bind_hover_tip(speed_btn, func() -> String: return "Speed (Tab)")

	sound_btn.pressed.connect(func():
		audio.set_muted(not audio.muted)
		audio.play_sfx("ui_click", 0.6)
	)
	_bind_hover_tip(sound_btn, func() -> String:
		return "Sound is off (M)" if (audio != null and audio.muted) else "Sound is on (M)"
	)

	biome_btn.pressed.connect(func():
		biome_picker_open = not biome_picker_open
		audio.play_sfx("ui_click", 0.6)
	)
	_bind_hover_tip(biome_btn, func() -> String: return "Switch biome (B / F1-F5)")

	_bio_btns.clear()
	for bi in range(CWBiome.BIOMES.size()):
		var bb := biome_picker.get_node_or_null("BioBtn_%d" % bi) as Button
		if bb != null:
			_bio_btns.append(bb)
			var idx := bi
			var bnm: String = String(CWBiome.BIOMES[bi]["name"])
			bb.text = bnm
			bb.pressed.connect(func():
				biome_picker_open = false
				select_pad(null)
				game.switch_biome(idx)
				audio.play_sfx("ui_click", 0.7)
			)
			_bind_hover_tip(bb, func() -> String: return "F%d · %s" % [idx + 1, bnm])

	# Bottom-right toolbar buttons
	follow_btn.pressed.connect(func():
		if main_ref != null:
			main_ref.call("cam_reset")
		audio.play_sfx("ui_click", 0.6)
	)
	zoom_out_btn.pressed.connect(func():
		if main_ref != null:
			main_ref.call("cam_zoom_by", 1.0 / 1.5)
	)
	_bind_hover_tip(zoom_out_btn, func() -> String: return "Zoom out (-)")

	zoom_in_btn.pressed.connect(func():
		if main_ref != null:
			main_ref.call("cam_zoom_by", 1.5)
	)
	_bind_hover_tip(zoom_in_btn, func() -> String: return "Zoom in (+)")

	# Build popup tower cards
	_build_cards.clear()
	for i in range(CWTowers.TOWER_KINDS.size()):
		var card := build_menu.find_child("BuildBtn_%d" % i, true, false) as PanelContainer
		if card != null:
			_build_cards.append(card)
			var knd: String = CWTowers.TOWER_KINDS[i]
			card.mouse_entered.connect(func(): _hovered_build_kind = knd)
			card.mouse_exited.connect(func():
				if _hovered_build_kind == knd:
					_hovered_build_kind = ""
			)
			card.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton:
					var mb := ev as InputEventMouseButton
					if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
						if selected_pad != null:
							_do_build(selected_pad, knd)
						card.accept_event()
			)

	# Upgrade popup stars & buttons
	_star_icons.clear()
	for i in range(3):
		var st := upgrade_menu.find_child("Star%d" % i, true, false) as TextureRect
		if st != null:
			_star_icons.append(st)

	upgrade_btn.pressed.connect(func():
		if selected_pad != null and selected_pad["tower"] != null:
			_do_upgrade(selected_pad["tower"])
	)
	sell_btn.pressed.connect(func():
		if selected_pad == null or selected_pad["tower"] == null:
			return
		var t: Dictionary = selected_pad["tower"]
		if not sell_armed:
			sell_armed = true
			audio.play_sfx("ui_click", 0.6)
		else:
			_do_sell(t)
	)


func _bind_hover_tip(ctrl: Control, tip_fn: Callable) -> void:
	ctrl.mouse_entered.connect(func():
		_hovered_tip_ctrl = ctrl
		_hovered_tip_text = String(tip_fn.call())
	)
	ctrl.mouse_exited.connect(func():
		if _hovered_tip_ctrl == ctrl:
			_hovered_tip_ctrl = null
			_hovered_tip_text = ""
	)


func _on_wave_plate_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			touch_input()
			if game.call_wave_early():
				audio.play_sfx("ui_click", 0.8)
			else:
				_deny()
			wave_plate.accept_event()


func _on_cmd_plate_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			game.ai_commander = not game.ai_commander
			if game.ai_commander:
				select_pad(null)
				armed_kind = ""
			idle_t = 0.0
			audio.play_sfx("ui_click", 0.8)
			cmd_plate.accept_event()


func toggle_perf_overlay() -> void:
	show_perf = not show_perf
	perf_plate.visible = show_perf


func update_perf_overlay(fps: int, mons_n: int, foot_n: int, gpu_units: int, mon_ms: float, rig_ms: float, tow_ms: float) -> void:
	if not show_perf:
		return
	perf_line1_lbl.text = "FPS %d · Mons %d · Guards %d · Units %d" % [fps, mons_n, foot_n, gpu_units]
	perf_line2_lbl.text = "CPU Mon %.1fms · Rig %.1fms · Tow %.1fms" % [mon_ms, rig_ms, tow_ms]


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


func _proj_world(world_pos: Vector3) -> Vector2:
	if cam_ref == null or sub_vp_ref == null:
		return Vector2(-1000.0, -1000.0)
	var win_sz := get_viewport().get_visible_rect().size
	var vp_sz := Vector2(sub_vp_ref.size)
	if vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return Vector2(-1000.0, -1000.0)
	var sp := cam_ref.unproject_position(world_pos)
	return Vector2(sp.x * (win_sz.x / vp_sz.x), sp.y * (win_sz.y / vp_sz.y))


# --- Public interaction hooks called from main.gd / input_handler.gd ---
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
	armed_kind = "" if armed_kind == kind else kind
	selected_pad = null
	audio.play_sfx("ui_click", 0.5)


func on_mouse_move(pos: Vector2) -> void:
	mouse_pos = pos
	mouse_inside = true
	moved_t = 0.0


func is_point_on_hud(pos: Vector2) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.is_visible_in_tree():
		return true
	if build_menu.visible and build_menu.get_global_rect().has_point(pos):
		return true
	if upgrade_menu.visible and upgrade_menu.get_global_rect().has_point(pos):
		return true
	return false



func on_mouse_tap(pos: Vector2, picked_pad) -> bool:
	mouse_pos = pos
	mouse_inside = true
	if is_point_on_hud(pos):
		return true
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



func select_pad(pad) -> void:
	selected_pad = pad
	menu_t = 0.0
	sell_armed = false
	_hovered_build_kind = ""
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


func update_ui(dt: float) -> void:
	var win_sz := get_viewport().get_visible_rect().size
	ui_s = maxi(2, int(roundf(win_sz.y / 430.0)))
	var lw := win_sz.x / float(ui_s)
	var lh := win_sz.y / float(ui_s)
	hud_root.scale = Vector2(ui_s, ui_s)
	hud_root.size = Vector2(lw, lh)

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

	_sync_hud_controls(lw, lh)
	_update_3d_rings(dt)

	if is_panning:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)
	elif get_viewport().gui_get_hovered_control() == null:
		var pointer := hovered_pad != null and game.phase == "play"
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if pointer else DisplayServer.CURSOR_ARROW)

	world_overlay.queue_redraw()


func _sync_hud_controls(lw: float, lh: float) -> void:
	# 1. Top-left Stats Plate
	lives_label.text = str(game.lives)
	lives_label.add_theme_color_override("font_color", COL_RED if hurt_t > 0.0 else COL_TX)
	flame_icon.modulate.a = 0.55 + 0.45 * (float(game.lives) / float(maxi(1, game.max_lives)))
	gold_label.text = str(int(floorf(gold_shown)))
	gold_label.add_theme_color_override("font_color", COL_RED if deny_t > 0.0 else (COL_GOLD_HI if gold_bump > 0.0 else COL_TX))
	slain_label.text = str(game.slain)
	slain_label.add_theme_color_override("font_color", Color.WHITE if slain_bump > 0.5 else COL_TX)
	stats_plate.add_theme_stylebox_override("panel", _sb_plate_hurt if hurt_t > 0.0 else _sb_plate)
	gold_icon_pos = coin_icon.get_global_rect().get_center()

	if show_perf:
		perf_plate.position = Vector2(5.0, stats_plate.position.y + stats_plate.size.y + 4.0)

	# 2. Top-center Wave Plate
	wave_title_lbl.text = "Wave %d" % maxi(1, game.wave_number())
	var can_call := game.phase == "play" and not game.spawning and not game.boss_wave and game.next_in > 0.4
	var wave_hot := can_call and _wave_hovered
	var frac := -1.0
	if game.phase == "play":
		if not game.spawning and not game.boss_wave and game.next_in > 0.0:
			if wave_hot:
				wave_sub_lbl.text = "Call now · +%d" % int(roundf(game.next_in * 3.0))
			else:
				wave_sub_lbl.text = "Next wave in %d" % maxi(1, int(ceilf(game.next_in)))
			frac = 1.0 - game.next_in / 6.5
		else:
			wave_sub_lbl.text = "%d on the road" % (game.monsters_sys.mons.size() + game.queue.size())
	elif game.phase == "defeat":
		wave_sub_lbl.text = "The fire has died"
	elif game.phase == "clear":
		wave_sub_lbl.text = "Boss defeated"
	else:
		wave_sub_lbl.text = "A new pass awaits"
	wave_progress.visible = frac >= 0.0
	if frac >= 0.0:
		wave_progress.value = clampf(frac, 0.0, 1.0)
	wave_plate.add_theme_stylebox_override("panel", _sb_plate_hover if wave_hot else _sb_plate)
	wave_plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_call else Control.CURSOR_ARROW

	# 3. Top-right Commander Plate
	var you := not game.ai_commander
	cmd_icon.texture = icons.get("hand" if you else "helm", null)
	cmd_title_lbl.text = "You command" if you else "AI commander"
	cmd_title_lbl.add_theme_color_override("font_color", COL_AMBER if you else COL_TX)
	cmd_sub_lbl.text = "Click here for the AI" if you else "Click a pad to take over"
	cmd_plate.add_theme_stylebox_override("panel", _sb_plate_hover if _cmd_hovered else (_sb_plate_hi if you else _sb_plate))

	# Anti-overlap positioning for top plates
	var stats_r := stats_plate.position.x + stats_plate.size.x
	var cmd_x := lw - cmd_plate.size.x - 5.0
	var cmd_y := 5.0
	if cmd_x < stats_r + 3.0:
		cmd_y = 5.0 + stats_plate.size.y + 3.0
	cmd_plate.position = Vector2(cmd_x, cmd_y)
	var wave_x := roundf((lw - wave_plate.size.x) * 0.5)
	var wave_y := 5.0
	if wave_x < stats_r + 3.0 or (cmd_y == 5.0 and wave_x + wave_plate.size.x > cmd_x - 3.0) or cmd_y != 5.0:
		wave_y = maxf(5.0 + stats_plate.size.y, cmd_y + (cmd_plate.size.y if (cmd_y == 5.0 or wave_x + wave_plate.size.x > cmd_x - 3.0) else 0.0)) + 3.0
	wave_plate.position = Vector2(wave_x, wave_y)
	var top_bottom := maxf(5.0 + stats_plate.size.y, maxf(cmd_y + cmd_plate.size.y, wave_y + wave_plate.size.y))

	# 4. Bottom toolbar state
	pause_btn.icon = icons.get("play" if game.paused else "pause", null)
	pause_btn.add_theme_stylebox_override("normal", _sb_btn_on if game.paused else _sb_btn_normal)
	speed_btn.text = "%dx" % game.speed
	speed_btn.add_theme_color_override("font_color", COL_AMBER if game.speed > 1 else COL_TX)
	speed_btn.add_theme_stylebox_override("normal", _sb_btn_on if game.speed > 1 else _sb_btn_normal)
	sound_btn.icon = icons.get("mute" if audio.muted else "sound", null)

	var cur_bname: String = String(game.terrain.bio.get("name", "Ashen Pass"))
	biome_btn.text = cur_bname
	biome_btn.add_theme_color_override("font_color", COL_AMBER if biome_picker_open else COL_TX)
	biome_btn.add_theme_stylebox_override("normal", _sb_btn_on if biome_picker_open else _sb_btn_normal)
	biome_picker.visible = biome_picker_open
	if biome_picker_open:
		var cur_key: String = String(game.terrain.bio.get("key", ""))
		for bi in range(_bio_btns.size()):
			var is_cur := String(CWBiome.BIOMES[bi]["key"]) == cur_key
			_bio_btns[bi].add_theme_color_override("font_color", COL_AMBER if is_cur else COL_TX)
			_bio_btns[bi].add_theme_stylebox_override("normal", _sb_plate_hover if is_cur else _sb_btn_normal)
		var b_pos := biome_btn.get_global_rect().position / float(ui_s)
		biome_picker.position = Vector2(b_pos.x, b_pos.y - biome_picker.size.y - 3.0)

	var cur_z := float(main_ref.call("cam_zoom_now")) if main_ref != null else 1.0
	var min_z := float(main_ref.call("cam_zoom_min")) if main_ref != null else 0.5
	zoom_in_btn.add_theme_color_override("font_color", COL_TX if cur_z < 2.99 else COL_DIM_BTN)
	zoom_out_btn.add_theme_color_override("font_color", COL_TX if cur_z > min_z + 0.01 else COL_DIM_BTN)
	var is_man := bool(main_ref.get("cam_man")) if main_ref != null else false
	follow_btn.visible = is_man and (game.phase == "play" or game.phase == "defeat")

	# Toolbar hover tooltip
	var y_up := lh - 5.0 - pause_btn.size.y - 3.0
	if _hovered_tip_ctrl != null and _hovered_tip_ctrl.is_visible_in_tree() and not is_panning and _hovered_tip_text != "":
		tooltip_label.text = _hovered_tip_text
		tooltip_plate.visible = true
		var cr := _hovered_tip_ctrl.get_global_rect()
		var cx := (cr.position.x + cr.size.x * 0.5) / float(ui_s)
		var tx := clampf(roundf(cx - tooltip_plate.size.x * 0.5), 4.0, lw - tooltip_plate.size.x - 4.0)
		var ty := y_up - tooltip_plate.size.y
		tooltip_plate.position = Vector2(tx, ty)
		y_up = minf(y_up, ty - 3.0)
	else:
		tooltip_plate.visible = false

	# Paused banner
	paused_plate.visible = game.paused
	if game.paused:
		paused_plate.position = Vector2(roundf((lw - paused_plate.size.x) * 0.5), y_up - paused_plate.size.y)
		y_up -= paused_plate.size.y + 3.0

	# Bottom controls hint
	var hint_a := clampf(minf(title_t - 7.2, 3.0 - (moved_t if idle_t > 20.0 else 0.0) + (8.0 if title_t < 18.0 else 0.0)), 0.0, 1.0)
	var show_hint := hint_a > 0.02 and selected_pad == null and not game.paused and hint_plate.size.x < lw - 10.0
	hint_plate.visible = show_hint
	if show_hint:
		hint_plate.modulate.a = hint_a
		hint_plate.position = Vector2(roundf((lw - hint_plate.size.x) * 0.5), y_up - hint_plate.size.y)

	# Wave / Boss banner
	var show_banner_now := false
	if banner_dur > 0.0 and not banner_text.is_empty():
		var ba := clampf(minf(banner_t * 3.0, (banner_dur - banner_t) * 2.0), 0.0, 1.0)
		if ba > 0.01:
			show_banner_now = true
			banner_label.text = banner_text
			banner_label.add_theme_font_size_override("font_size", 27 if banner_big else 18)
			banner_label.add_theme_color_override("font_color", COL_BANNER_BIG if banner_big else COL_TX)
			banner_plate.add_theme_stylebox_override("panel", _sb_plate_ember if banner_big else _sb_plate_hi)
			banner_plate.modulate.a = ba
			var yb := maxf(roundf(lh * 0.2), top_bottom + 4.0)
			banner_plate.position = Vector2(roundf((lw - banner_plate.size.x) * 0.5), yb)
	banner_plate.visible = show_banner_now

	# Build / Upgrade popup menus
	if selected_pad != null and game.phase == "play":
		var tower = selected_pad["tower"]
		var top_off := minf(3.6, float(tower.get("top_y", 2.0))) if tower != null else 1.2
		var p := _proj_world(Vector3(selected_pad["x"], float(selected_pad["y"]) + top_off, selected_pad["z"])) / float(ui_s)
		var ma := clampf(menu_t * 8.0, 0.0, 1.0)
		if tower == null:
			upgrade_menu.visible = false
			build_menu.visible = true
			build_menu.modulate.a = ma
			var show_k := _hovered_build_kind
			for i in range(_build_cards.size()):
				var knd: String = CWTowers.TOWER_KINDS[i]
				var cost := int(CWTowers.DEFS[knd]["cost"][0])
				var can := game.gold >= cost
				var lit := (_hovered_build_kind == knd)
				var card := _build_cards[i]
				card.add_theme_stylebox_override("panel", _sb_card_lit if lit else (_sb_card_normal if can else _sb_card_dim))
				var t_ic := card.find_child("TowerIcon", true, false) as TextureRect
				var c_ic := card.find_child("CostIcon", true, false) as TextureRect
				var c_lb := card.find_child("CostLabel", true, false) as Label
				if t_ic != null:
					t_ic.modulate.a = 1.0 if can else 0.45
				if c_ic != null:
					c_ic.modulate.a = 1.0 if can else 0.5
				if c_lb != null:
					c_lb.text = str(cost)
					c_lb.add_theme_color_override("font_color", COL_AMBER if can else COL_RED)
			if show_k != "":
				var dl: Array = TOWER_DESC_LINES[show_k]
				build_desc_title.text = String(CWTowers.DEFS[show_k]["name"])
				build_desc_title.add_theme_color_override("font_color", COL_TX)
				build_desc_l1.text = String(dl[0])
				build_desc_l2.text = String(dl[1])
			else:
				build_desc_title.text = "Choose a tower"
				build_desc_title.add_theme_color_override("font_color", COL_DIM)
				build_desc_l1.text = "Hover or press 1 to 4"
				build_desc_l2.text = "to see what each does."
			var bx := clampf(roundf(p.x - build_menu.size.x * 0.5), 4.0, lw - build_menu.size.x - 4.0)
			var by := clampf(roundf(p.y - build_menu.size.y - 7.0), minf(top_bottom + 4.0, lh - build_menu.size.y - 4.0), lh - build_menu.size.y - 4.0)
			build_menu.position = Vector2(bx, by)
		else:
			build_menu.visible = false
			upgrade_menu.visible = true
			upgrade_menu.modulate.a = ma
			var d: Dictionary = tower["def"]
			var lvl := int(tower["lvl"])
			var maxed := lvl >= 2
			var upc := 0 if maxed else int(d["cost"][lvl + 1])
			var can_up := (not maxed) and game.gold >= upc and String(tower["state"]) == "active"
			var refund := int(roundf(float(tower["spent"]) * 0.7))
			upgrade_name_lbl.text = String(d["name"])
			for si in range(_star_icons.size()):
				_star_icons[si].texture = icons.get("star" if si <= lvl else "starEmpty", null)
			var kills_n := int(tower.get("kills", 0))
			upgrade_stats_lbl.text = ("%d footmen · %d health" % [int(d["n"][lvl]), int(d["hp"][lvl])]) if String(tower["kind"]) == "guard" else ("Range %.1f · Damage %d" % [float(d["range"][lvl]), int(d["dmg"][lvl])])
			if maxed:
				upgrade_next_lbl.text = "%d kills" % kills_n
			elif String(tower["kind"]) == "guard":
				upgrade_next_lbl.text = "Next: %d footmen · %d health" % [int(d["n"][lvl + 1]), int(d["hp"][lvl + 1])]
			else:
				upgrade_next_lbl.text = "Next: range %.1f · damage %d" % [float(d["range"][lvl + 1]), int(d["dmg"][lvl + 1])]
			upgrade_next_lbl.add_theme_color_override("font_color", COL_DIM if maxed else COL_AMBER)

			upgrade_btn.text = "Max level" if maxed else ("Upgrade %d" % upc)
			upgrade_btn.add_theme_color_override("font_color", COL_TX if can_up else (COL_DIM if maxed else COL_RED))
			upgrade_btn.add_theme_stylebox_override("normal", _sb_card_normal if can_up else _sb_card_dim)
			sell_btn.text = ("Confirm +%d" % refund) if sell_armed else ("Sell +%d" % refund)
			sell_btn.add_theme_color_override("font_color", COL_RED if sell_armed else COL_TX)
			sell_btn.add_theme_stylebox_override("normal", _sb_btn_sell_armed if sell_armed else _sb_card_normal)

			var ux := clampf(roundf(p.x - upgrade_menu.size.x * 0.5), 4.0, lw - upgrade_menu.size.x - 4.0)
			var uy := clampf(roundf(p.y - upgrade_menu.size.y - 7.0), minf(top_bottom + 4.0, lh - upgrade_menu.size.y - 4.0), lh - upgrade_menu.size.y - 4.0)
			upgrade_menu.position = Vector2(ux, uy)
	else:
		build_menu.visible = false
		upgrade_menu.visible = false

	# Armed tower cursor tooltip
	if armed_kind != "" and mouse_inside and game.phase == "play":
		armed_label.text = "%s: click a pad" % String(CWTowers.DEFS[armed_kind]["name"])
		armed_plate.visible = true
		var mp := mouse_pos / float(ui_s)
		armed_plate.position = Vector2(
			clampf(mp.x + 10.0, 2.0, lw - armed_plate.size.x - 2.0),
			clampf(mp.y + 10.0, 2.0, lh - armed_plate.size.y - 2.0)
		)
	else:
		armed_plate.visible = false

	# New Monster / Boss 5.2s tip card
	var show_tip := false
	if not active_tip.is_empty() and selected_pad == null:
		var mtype: String = String(active_tip["type"])
		var tt: float = float(active_tip["t"])
		var tip_a := clampf(minf(tt * 4.0, (5.2 - tt) * 2.0), 0.0, 1.0)
		if tip_a > 0.01 and CWMonsters.DEFS.has(mtype):
			show_tip = true
			var md: Dictionary = CWMonsters.DEFS[mtype]
			tip_head_lbl.text = "%s: %s" % ["Boss" if bool(md.get("boss", false)) else "New", String(md.get("name", mtype))]
			tip_body_lbl.text = String(md.get("tip", ""))
			tip_plate.add_theme_stylebox_override("panel", _sb_plate_hi if bool(md.get("boss", false)) else _sb_plate)
			tip_plate.modulate.a = tip_a
			tip_plate.position = Vector2(roundf((lw - tip_plate.size.x) * 0.5), lh - tip_plate.size.y - pause_btn.size.y - 10.0)
	tip_plate.visible = show_tip

	# Opening title card (first 7s)
	var show_title := false
	if title_t < 7.0 and selected_pad == null:
		var ta := clampf(minf((title_t - 0.4) * 1.5, (6.6 - title_t) * 1.2), 0.0, 1.0)
		if ta > 0.01:
			show_title = true
			title_sub_lbl.text = "%s · The commander plays until you take over." % cur_bname
			var has_best := game.best_wave > 5
			title_best_lbl.visible = has_best
			if has_best:
				title_best_lbl.text = "Best run: wave %d" % game.best_wave
			title_plate.modulate.a = ta
			title_plate.position = Vector2(roundf((lw - title_plate.size.x) * 0.5), lh - title_plate.size.y - 22.0)
	title_plate.visible = show_title


func _update_3d_rings(dt: float) -> void:
	_ring_time += dt
	var focus_pad = selected_pad if selected_pad != null else hovered_pad
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
			var pk := "archer"
			if selected_pad != null and _hovered_build_kind != "":
				pk = _hovered_build_kind
			elif armed_kind != "":
				pk = armed_kind
			r = float(CWTowers.DEFS[pk]["range"][0])
		var rng_key := "%s_%.2f" % [pad_key, r]
		if rng_key != _ring_range_key:
			_ring_range_key = rng_key
			ring_range.mesh = _build_terrain_ring_mesh(px, pz, r, 0.07, 96)
		ring_range.visible = true
	else:
		ring_pad.visible = false
		ring_range.visible = false


# --- Dynamic 3D-projected HP bars & flying pixel coins only ---
func _draw_world_overlay() -> void:
	if cam_ref == null or sub_vp_ref == null or game == null:
		return
	var win_sz := get_viewport().get_visible_rect().size
	var W := win_sz.x
	var H := win_sz.y
	var vp_sz := Vector2(sub_vp_ref.size)
	if W < 10.0 or H < 10.0 or vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return

	var sf := float(ui_s)
	var pix := maxf(1.0, roundf(H / vp_sz.y))
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
		var sp := _proj_world(Vector3(m.x, m.y + float(m.def["hit_h"]) * 1.65 + (0.65 if is_boss else 0.35), m.z))
		var bw := (34.0 if is_boss else 9.0) * pix
		var bh := (2.0 if is_boss else 1.0) * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		if bx < -bw or bx > W or by < 0.0 or by > H:
			continue
		var alpha := 0.40 if f >= 0.999 else 0.95
		var fill_c := col_hi if f > 0.5 else (col_mid if f > 0.25 else col_lo)
		world_overlay.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(COL_DARK.r, COL_DARK.g, COL_DARK.b, alpha))
		world_overlay.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(fill_c.r, fill_c.g, fill_c.b, alpha))
		if is_boss:
			var bname := String(m.def["name"])
			var tw := maxf(0.0, pixel_font.get_string_size(bname, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE).x - 1.0) * sf
			var dx := roundf(sp.x - tw * 0.5)
			var dy := roundf(by - float(FONT_LINE) * sf - 2.0 * pix)
			for ox in [-1.0, 0.0, 1.0]:
				for oy in [-1.0, 0.0, 1.0]:
					if ox == 0.0 and oy == 0.0:
						continue
					world_overlay.draw_set_transform(Vector2(dx + ox * sf, dy + oy * sf), 0.0, Vector2(sf, sf))
					world_overlay.draw_string(pixel_font, Vector2(0.0, float(FONT_BASE)), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE, COL_DARK)
			world_overlay.draw_set_transform(Vector2(dx, dy), 0.0, Vector2(sf, sf))
			world_overlay.draw_string(pixel_font, Vector2(0.0, float(FONT_BASE)), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LINE, COL_TX)
			world_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for fm: CWFootmanUnit in game.towers_sys.footmen:
		var fmhp := maxf(fm.max_hp, 1.0)
		if fm.hp >= fmhp * 0.999:
			continue
		var f := clampf(fm.hp / fmhp, 0.0, 1.0)
		var sp := _proj_world(Vector3(fm.x, fm.y + 1.38, fm.z))
		var bw := 8.0 * pix
		var bh := 1.0 * pix
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		world_overlay.draw_rect(Rect2(bx - pix, by - pix, bw + 2.0 * pix, bh + 2.0 * pix), Color(COL_DARK.r, COL_DARK.g, COL_DARK.b, 0.95))
		world_overlay.draw_rect(Rect2(bx, by, maxf(pix, roundf(bw * f)), bh), Color(col_man.r, col_man.g, col_man.b, 0.95))

	if icons.has("coin"):
		var coin_tex: Texture2D = icons["coin"]
		var cs := float(maxi(2, ui_s - 1))
		var cw := float(coin_tex.get_width()) * cs
		var ch := float(coin_tex.get_height()) * cs
		for qc in hud_coins:
			var cu := clampf(float(qc["t"]) / float(qc["dur"]), 0.0, 1.0)
			var e := cu * cu * (3.0 - 2.0 * cu)
			var a := 1.0 - e
			var qx := a * a * float(qc["sx"]) + 2.0 * a * e * float(qc["cx"]) + e * e * gold_icon_pos.x
			var qy := a * a * float(qc["sy"]) + 2.0 * a * e * float(qc["cy"]) + e * e * gold_icon_pos.y
			world_overlay.draw_texture_rect(coin_tex, Rect2(roundf(qx - cw * 0.5), roundf(qy - ch * 0.5), cw, ch), false)
