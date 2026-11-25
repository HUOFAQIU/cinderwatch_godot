class_name CWInputHandler
extends RefCounted

# Keyboard, mouse drag/zoom, hotkey, and 3D physics raycast picking (extracted from main.gd)

static func poll_pan_keys(m: CWMain, dt: float) -> void:
	var kx := 0.0
	var ky := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kx += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kx -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		ky += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		ky -= 1.0
	if kx != 0.0 or ky != 0.0:
		m.cam_za.clear()
		var dh := maxf(m.get_viewport().get_visible_rect().size.y, 200.0)
		m.cam_pan(kx * dh * 0.9 * dt, ky * dh * 0.9 * dt)


static func handle_input(m: CWMain, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mpos := (event as InputEventMouseMotion).position
		m.ui.on_mouse_move(mpos)
		if m._drag_down and not m._drag_on_hud:
			if not m._drag_panning and mpos.distance_to(m._drag_start) > 6.0:
				m._drag_panning = true
				m.ui.is_panning = true
				m.ui.press_id = ""
				m.cam_za.clear()
			if m._drag_panning:
				var dp := mpos - m._drag_last
				m.cam_pan(dp.x, dp.y)
		m._drag_last = mpos
		m.ui.hovered_pad = null if (m._drag_panning or m.ui.is_point_on_hud(mpos)) else pick_pad(m, mpos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			m.cam_zoom_to(m.cam_zoom_now() * 1.26, mb.position.x, mb.position.y, 16.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			m.cam_zoom_to(m.cam_zoom_now() / 1.26, mb.position.x, mb.position.y, 16.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				m.cam_za.clear()
				m._drag_down = true
				m._drag_panning = false
				m._drag_start = mb.position
				m._drag_last = mb.position
				m._drag_on_hud = m.ui.is_point_on_hud(mb.position)
				if m._drag_on_hud:
					m.ui.on_hud_press(mb.position)
			else:
				var was_pan := m._drag_panning
				m._drag_down = false
				m._drag_panning = false
				m.ui.is_panning = false
				if not was_pan:
					var pad = pick_pad(m, mb.position)
					var handled := m.ui.on_mouse_tap(mb.position, pad)
					if not handled:
						var now_ms := Time.get_ticks_msec()
						if now_ms - m._last_tap_ms < 330 and mb.position.distance_to(m._last_tap_pos) < 40.0:
							m._last_tap_ms = -9999
							if m.cam_man and m.cam_mzoom > 1.3:
								m.cam_reset()
							else:
								m.cam_zoom_to(maxf(1.9, m.cam_zoom_now() * 1.6), mb.position.x, mb.position.y)
						else:
							m._last_tap_ms = now_ms
							m._last_tap_pos = mb.position
				m.ui.on_mouse_up()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			m.ui.select_pad(null)
			m.ui.armed_kind = ""
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_P:
			m.toggle_pause()
			return
		elif ke.keycode == KEY_TAB:
			m.cycle_speed()
			m.get_viewport().set_input_as_handled()
			return
		elif ke.keycode == KEY_F or ke.keycode == KEY_0 or ke.keycode == KEY_HOME:
			m.cam_reset()
			return
		elif ke.keycode == KEY_EQUAL or ke.keycode == KEY_PLUS or ke.keycode == KEY_KP_ADD:
			m.cam_zoom_by(1.4)
			return
		elif ke.keycode == KEY_MINUS or ke.keycode == KEY_KP_SUBTRACT:
			m.cam_zoom_by(1.0 / 1.4)
			return
		elif ke.keycode == KEY_B:
			m.ui.biome_picker_open = false
			m.ui.select_pad(null)
			m.game.cycle_biome()
			m.audio.play_sfx("ui_click", 0.7)
			return
		elif ke.keycode == KEY_R:
			m.ui.biome_picker_open = false
			m.ui.select_pad(null)
			m.game.reroll_seed()
			m.audio.play_sfx("ui_click", 0.7)
			return
		elif ke.keycode >= KEY_F1 and ke.keycode <= KEY_F5:
			m.ui.biome_picker_open = false
			m.ui.select_pad(null)
			m.game.switch_biome(ke.keycode - KEY_F1)
			m.audio.play_sfx("ui_click", 0.7)
			return
		elif ke.keycode == KEY_K:
			var stress_types := ["skel", "rat", "slime", "spider", "ghoul", "knight", "bat", "wolf"]
			for si in range(100):
				m.monsters_sys.spawn(stress_types[si % stress_types.size()], 1.0, randf_range(0.5, 16.0))
			m.audio.play_sfx("ui_click", 0.7)
			print("[StressTest] Spawned +100 units | total_mons=%d | fps=%d" % [m.monsters_sys.mons.size(), int(Engine.get_frames_per_second())])
			return
		elif ke.keycode == KEY_L:
			m.ui.toggle_perf_overlay()
			m.audio.play_sfx("ui_click", 0.7)
			return

	if event.is_action_pressed("toggle_commander"):
		m.game.ai_commander = not m.game.ai_commander
		if m.game.ai_commander:
			m.ui.select_pad(null)
			m.ui.armed_kind = ""
		m.audio.play_sfx("ui_click", 0.7)
	elif event.is_action_pressed("toggle_mute"):
		m.audio.set_muted(not m.audio.muted)
	elif event.is_action_pressed("next_wave"):
		m.ui.touch_input()
		if m.game.call_wave_early():
			m.audio.play_sfx("ui_click", 0.8)
		else:
			m.audio.play_sfx("ui_deny", 0.5)
	elif event.is_action_pressed("cancel_menu"):
		m.ui.select_pad(null)
		m.ui.armed_kind = ""
	elif event.is_action_pressed("upgrade_tower"):
		var target_pad = m.ui.selected_pad if m.ui.selected_pad != null else m.ui.hovered_pad
		if target_pad != null and target_pad["tower"] != null:
			m.ui.touch_input()
			if m.game.upgrade_tower(target_pad["tower"], true):
				m.ui.select_pad(null)
	elif event.is_action_pressed("sell_tower"):
		m.ui.press_sell_key()
	else:
		var hotkeys := ["tower_1", "tower_2", "tower_3", "tower_4"]
		for idx in range(hotkeys.size()):
			if event.is_action_pressed(hotkeys[idx]):
				m.ui.pick_kind(CWTowers.TOWER_KINDS[idx])
				break


static func pick_pad(m: CWMain, screen_pos: Vector2):
	if m.terrain.layout.is_empty() or m.game.phase != "play":
		return null
	var win_sz := m.get_viewport().get_visible_rect().size
	if win_sz.x <= 1.0 or win_sz.y <= 1.0:
		return null
	var vp_pos := Vector2(
		screen_pos.x / win_sz.x * float(m.sub_vp.size.x),
		screen_pos.y / win_sz.y * float(m.sub_vp.size.y)
	)
	var ray_orig := m.cam.project_ray_origin(vp_pos)
	var ray_dir := m.cam.project_ray_normal(vp_pos)
	if absf(ray_dir.y) < 1e-4:
		return null
	# Native Godot Physics 3D raycast against layer 16 (PadPickBody & TowerNode/PickBody)
	var w3d := m.world.get_world_3d()
	if w3d != null and w3d.direct_space_state != null:
		var rq := PhysicsRayQueryParameters3D.create(ray_orig, ray_orig + ray_dir * 200.0, 16)
		var hit := w3d.direct_space_state.intersect_ray(rq)
		if not hit.is_empty():
			var col_obj: Object = hit.get("collider", null)
			if col_obj != null and col_obj.has_meta("pad"):
				return col_obj.get_meta("pad")
	# Fallback geometric pad picking
	var best = null
	var best_d := 1e9
	for pad in m.terrain.layout["pads"]:
		var px := float(pad["x"])
		var py := float(pad["y"])
		var pz := float(pad["z"])
		var top_h := 0.1
		if pad["tower"] != null:
			top_h = minf(3.4, float(pad["tower"].get("top_y", 2.0)))
		var h := 0.0
		while h <= top_h + 0.001:
			var t := (py + h - ray_orig.y) / ray_dir.y
			if t > 0.0:
				var hx := ray_orig.x + ray_dir.x * t
				var hz := ray_orig.z + ray_dir.z * t
				var d := sqrt((hx - px) * (hx - px) + (hz - pz) * (hz - pz))
				var rad := 1.55 if h == 0.0 else 1.0
				if d < rad and d + h * 0.01 < best_d:
					best_d = d
					best = pad
			h += 0.6
	return best


