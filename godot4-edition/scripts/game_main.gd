extends Node2D
const TEX_ALIASES: Dictionary = {
	"coin_gold": "ui_coin_hud",
	"shield_orb": "icon_shield",
	"icon_wings": "icon_wing",
	"sword_pickup": "icon_sword",
	"bullet_up": "s3_shop_bullet",
	"hud_wall_phase": "s3_shop_phase",
	"clock_item": "clock_gold"
}
var meta: Dictionary = {}
var levels_raw: Array = []
var textures: Dictionary = {}
var font_main: Font = null
var is_mobile_platform: bool = false
var save: SaveManager
var shop: ShopSystem
var engine: StageEngine
var audio: ChiptunePlayer
var ui: UIDirector
var stage_box: Control
var sky_stars: Array = []
var sky_traffic: Array = []
var prev_kb: Dictionary = {
	"down": false,
	"jump": false,
	"shoot": false,
	"slash": false,
	"bomb": false,
	"layer": false,
	"gold": false,
	"retry": false,
	"esc": false
}
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	is_mobile_platform = _detect_mobile_platform()
	_configure_platform_window()
	_init_sky_atmosphere()
	meta = _load_json_dict("res://data/game_metadata.json")
	levels_raw = _load_json_array("res://data/levels_150.json")
	font_main = _load_combined_font()
	_load_all_textures()
	var bgm_node: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if bgm_node == null:
		bgm_node = AudioStreamPlayer.new()
		bgm_node.name = "AudioStreamPlayer"
		add_child(bgm_node)
	save = SaveManager.new(is_mobile_platform)
	save.retro_sync_achievements()
	shop = ShopSystem.new(save, meta.get("shopCatalog", []))
	engine = StageEngine.new(levels_raw, save, shop)
	audio = ChiptunePlayer.new(bgm_node, meta)
	stage_box = get_node_or_null("StageLockedBox") as Control
	if stage_box == null:
		stage_box = Control.new()
		stage_box.name = "StageLockedBox"
		add_child(stage_box)
	stage_box.clip_contents = true
	stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage_box.visible = false
	if not stage_box.draw.is_connected(_draw_stage_world):
		stage_box.draw.connect(_draw_stage_world)
	_sync_stage_box_rect()
	var ui_layer: CanvasLayer = get_node_or_null("UILayer") as CanvasLayer
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10
		add_child(ui_layer)
	ui = UIDirector.new()
	ui_layer.add_child(ui)
	ui.setup(save, shop, engine, audio, textures, meta, font_main, is_mobile_platform)
	ui.sync_safe_area_and_layout()
	ui.request_start_stage.connect(_on_start_stage)
	ui.request_retry_stage.connect(_on_retry_stage)
	ui.request_fresh_restart.connect(_on_fresh_restart)
	ui.request_return_title.connect(_on_return_title)
	ui.request_quit_app.connect(func() -> void: get_tree().quit())
	ui.request_toggle_fullscreen.connect(_toggle_fullscreen)
	var cmd_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--smoke-test" in cmd_args:
		call_deferred("_StartCiSmoke")
		return
func _init_sky_atmosphere() -> void:
	sky_stars.clear()
	var cols: Array[Color] = [Color("#ffffff"), Color("#00f5ff"), Color("#67e8f9"), Color("#ff2ab4"), Color("#fde047")]
	for i in range(64):
		sky_stars.append({
			"x": float((i * 97) % 1920),
			"y": float((i * 43) % 340),
			"sz": 2.0 if (i % 3 == 0) else 1.5,
			"ph": float(i) * 0.51,
			"col": cols[i % cols.size()]
		})
	sky_traffic.clear()
	for i in range(14):
		var right_d: bool = (i % 2) == 0
		sky_traffic.append({
			"x": float((i * 137) % 1920),
			"y": 286.0 + float((i * 23) % 140),
			"spd": (72.0 + float((i % 4) * 24)) * (1.0 if right_d else -1.0),
			"col": Color("#00f5ff") if right_d else Color("#ff2ab4")
		})
func _sync_stage_box_rect() -> void:
	if stage_box == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var vw: float = maxf(960.0, vp.x)
	var vh: float = maxf(540.0, vp.y)
	var ox: float = floorf((vw - 960.0) * 0.5)
	var oy: float = floorf((vh - 540.0) * 0.5)
	stage_box.position = Vector2(ox, oy)
	stage_box.size = Vector2(960.0, 540.0)
func _detect_mobile_platform() -> bool:
	if FileAccess.file_exists("res://data/build_profile.json"):
		var bp: Dictionary = _load_json_dict("res://data/build_profile.json")
		var plat: String = str(bp.get("platform", ""))
		if plat == "android":
			return true
		if plat == "pc":
			return false
	if OS.has_feature("mobile_apk") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("pc_desktop"):
		return false
	return OS.get_name() in ["Android", "iOS"]
func _configure_platform_window() -> void:
	if is_mobile_platform:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_title("哥查德的大冒险 · GODCHARD ADVENTURE v3.5.3")
func _toggle_fullscreen() -> void:
	var cur_m: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if cur_m == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	return []
func _load_combined_font() -> Font:
	var cjk: FontFile = _try_load_font_file("res://data/cjk_font.bin")
	var lat: FontFile = _try_load_font_file("res://data/latin_font.bin")
	if lat != null and cjk != null:
		lat.fallbacks = [cjk]
		return lat
	if cjk != null:
		return cjk
	if lat != null:
		return lat
	return ThemeDB.fallback_font
func _try_load_font_file(res_path: String) -> FontFile:
	if not FileAccess.file_exists(res_path):
		return null
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if raw.is_empty():
		return null
	var ff: FontFile = FontFile.new()
	ff.data = raw
	return ff
func _load_all_textures() -> void:
	textures.clear()
	var amap: Dictionary = meta.get("assets", {})
	for k in amap.keys():
		var rel: String = "res://" + str(amap[k])
		var tex: Texture2D = _load_single_texture(rel)
		if tex != null:
			textures[str(k)] = tex
	for alias_k in TEX_ALIASES.keys():
		var target_k: String = str(TEX_ALIASES[alias_k])
		if textures.has(target_k) and not textures.has(alias_k):
			textures[alias_k] = textures[target_k]
func _load_single_texture(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var r: Resource = load(res_path)
		if r is Texture2D:
			return r as Texture2D
	if FileAccess.file_exists(res_path):
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if raw.size() > 8:
			var img: Image = Image.new()
			var err: Error = ERR_FILE_CORRUPT
			if res_path.ends_with(".png"):
				err = img.load_png_from_buffer(raw)
			elif res_path.ends_with(".jpg") or res_path.ends_with(".jpeg"):
				err = img.load_jpg_from_buffer(raw)
			if err == OK and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null
func _tex(key: String) -> Texture2D:
	if textures.has(key):
		return textures[key]
	if TEX_ALIASES.has(key) and textures.has(str(TEX_ALIASES[key])):
		return textures[str(TEX_ALIASES[key])]
	return null
func _on_start_stage(stage_id: int) -> void:
	if not save.is_stage_unlocked(stage_id):
		return
	shop.reset_for_new_stage()
	engine.start_stage(stage_id)
	stage_box.visible = true
	_sync_stage_box_rect()
	ui.enter_gameplay_hud(stage_id)
	audio.select_track(false, stage_id)
	queue_redraw()
	stage_box.queue_redraw()
func _on_retry_stage() -> void:
	if not ui.in_game:
		return
	engine.reset_attempt()
	ui.refresh_hud()
	queue_redraw()
	stage_box.queue_redraw()
func _on_fresh_restart() -> void:
	if not ui.in_game:
		return
	engine.manual_fresh_restart()
	ui.refresh_hud()
	queue_redraw()
	stage_box.queue_redraw()
func _on_return_title() -> void:
	stage_box.visible = false
	ui.show_title_screen()
	queue_redraw()
func _input(event: InputEvent) -> void:
	if ui == null:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
	if ui.handle_priority_input(event):
		get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if ui == null:
		return
	if ui.handle_unhandled_gameplay_input(event):
		get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_SIZE_CHANGED:
		if is_mobile_platform:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		_sync_stage_box_rect()
		if ui != null:
			ui.sync_safe_area_and_layout()
		queue_redraw()
		if stage_box != null:
			stage_box.queue_redraw()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
		if ui.standby_mode:
			ui.standby_mode = false
			ui.standby_veil.visible = false
		elif ui.active_modal != "":
			ui.close_all_modals(true)
		elif ui.in_game:
			ui.open_level_select_modal()
		else:
			ui.open_exit_modal()
func _gather_gameplay_input(dt: float) -> Dictionary:
	var t_edges: Dictionary = ui.consume_touch_edges()
	var kb_left: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var kb_right: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var kb_down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var kb_jump: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_K)
	var kb_shoot: bool = Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_F)
	var kb_slash: bool = Input.is_physical_key_pressed(KEY_U) or Input.is_physical_key_pressed(KEY_X)
	var kb_bomb: bool = Input.is_physical_key_pressed(KEY_B) or Input.is_physical_key_pressed(KEY_I) or Input.is_physical_key_pressed(KEY_C)
	var kb_layer: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_Q)
	var kb_gold: bool = Input.is_physical_key_pressed(KEY_G) or Input.is_physical_key_pressed(KEY_O) or Input.is_physical_key_pressed(KEY_V)
	var jump_pressed: bool = bool(t_edges["jump_pressed"]) or (kb_jump and not bool(prev_kb["jump"]))
	var jump_released: bool = bool(t_edges["jump_released"]) or ((not kb_jump) and bool(prev_kb["jump"]))
	var jump_held: bool = bool(t_edges["jump_held"]) or kb_jump
	var inp: Dictionary = {
		"left": bool(t_edges["left"]) or kb_left,
		"right": bool(t_edges["right"]) or kb_right,
		"down": bool(t_edges["down"]) or kb_down,
		"down_pressed": bool(t_edges["down_pressed"]) or (kb_down and not bool(prev_kb["down"])),
		"jump_held": jump_held,
		"jump_pressed": jump_pressed,
		"jump_released": jump_released,
		"shoot_pressed": bool(t_edges["shoot_pressed"]) or (kb_shoot and not bool(prev_kb["shoot"])),
		"slash_pressed": bool(t_edges["slash_pressed"]) or (kb_slash and not bool(prev_kb["slash"])),
		"bomb_pressed": bool(t_edges["bomb_pressed"]) or (kb_bomb and not bool(prev_kb["bomb"])),
		"layer_pressed": bool(t_edges["layer_pressed"]) or (kb_layer and not bool(prev_kb["layer"])),
		"gold_pressed": bool(t_edges["gold_pressed"]) or (kb_gold and not bool(prev_kb["gold"]))
	}
	prev_kb["down"] = kb_down
	prev_kb["jump"] = kb_jump
	prev_kb["shoot"] = kb_shoot
	prev_kb["slash"] = kb_slash
	prev_kb["bomb"] = kb_bomb
	prev_kb["layer"] = kb_layer
	prev_kb["gold"] = kb_gold
	return inp
func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.001, 0.033)
	_sync_stage_box_rect()
	var kb_r: bool = Input.is_physical_key_pressed(KEY_R)
	var kb_esc: bool = Input.is_physical_key_pressed(KEY_ESCAPE)
	if kb_r and not bool(prev_kb["retry"]) and ui.in_game:
		if ui.active_modal == "death" or ui.active_modal == "":
			audio.play_named("block", 1.06)
			ui.close_all_modals(true)
			_on_retry_stage()
	if kb_esc and not bool(prev_kb["esc"]):
		if ui.active_modal != "" and ui.active_modal != "death" and ui.active_modal != "clear":
			ui.close_all_modals(true)
		elif ui.in_game and ui.active_modal == "":
			ui.open_level_select_modal()
	prev_kb["retry"] = kb_r
	prev_kb["esc"] = kb_esc
	if ui.in_game and not ui.is_modal_open():
		var inp: Dictionary = _gather_gameplay_input(dt)
		engine.step_frame(dt, inp)
		_drain_engine_queues()
		if engine.pending_death_modal_cause != "":
			var dc: String = engine.pending_death_modal_cause
			engine.pending_death_modal_cause = ""
			if save.vibrate_on and is_mobile_platform:
				Input.vibrate_handheld(45)
			ui.open_death_modal(dc)
		elif not engine.pending_win_result.is_empty():
			var wr: Dictionary = engine.pending_win_result.duplicate()
			engine.pending_win_result.clear()
			var newly_ach: Array[String] = save.retro_sync_achievements()
			for aid in newly_ach:
				ui.push_ach_toast(aid)
			ui.open_clear_modal(wr)
		queue_redraw()
		stage_box.queue_redraw()
	else:
		_drain_engine_queues()
	ui.step_ui(dt)
	audio.sync_state(
		dt,
		save,
		(not ui.in_game) or ui.is_modal_open(),
		ui.in_game and engine.world_frozen,
		ui.in_game and engine.world_slow,
		ui.standby_mode
	)
func _drain_engine_queues() -> void:
	while not engine.sfx_queue.is_empty():
		var sname: String = engine.sfx_queue.pop_front()
		audio.play_named(sname)
	while not engine.toast_queue.is_empty():
		var td: Dictionary = engine.toast_queue.pop_front()
		var msg: String = str(td.get("en" if save.lang == "en" else "zh", ""))
		ui.push_toast(msg, str(td.get("icon", "ui_hint")), str(td.get("color", "#00f5ff")))
	while not engine.ach_queue.is_empty():
		var ach_id: String = engine.ach_queue.pop_front()
		ui.push_ach_toast(ach_id)
func _pick_stage_bg_key(stage_id: int) -> String:
	var base_k: String = "cyber_skyline_bg"
	if stage_id >= 101:
		var ch_s3: int = clampi(int(ceil(float(stage_id) / 10.0)), 11, 15)
		base_k = "s3_bg_ch%d" % ch_s3
	elif stage_id >= 91:
		base_k = "bg_s2_root"
	elif stage_id >= 81:
		base_k = "bg_s2_chrono"
	elif stage_id >= 71:
		base_k = "bg_s2_fracture"
	elif stage_id >= 61:
		base_k = "bg_s2_mecha"
	elif stage_id >= 51:
		base_k = "bg_s2_signal"
	var wide_k: String = base_k + "_wide"
	if textures.has(wide_k):
		return wide_k
	return base_k
func _is_in_zen_sanctuary(props: Dictionary) -> bool:
	if engine.player.is_empty():
		return false
	var px: float = float(engine.player.get("x", 0.0))
	if props.has("finalEmptyRoomX") and px >= GridMath.gx_to_px(float(props["finalEmptyRoomX"])):
		return true
	if props.has("whiteSanctuaryX") and px >= GridMath.gx_to_px(float(props["whiteSanctuaryX"])):
		return true
	return false
func _draw() -> void:
	var vp_rect: Rect2 = get_viewport_rect()
	var vw: float = maxf(960.0, vp_rect.size.x)
	var vh: float = maxf(540.0, vp_rect.size.y)
	if ui == null or not ui.in_game or engine.lv_data.is_empty():
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040824"), true)
		return
	var props: Dictionary = engine.lv_data.get("props", {})
	var is_zen: bool = _is_in_zen_sanctuary(props)
	var lv_id: int = engine.lv_id
	var t_sec: float = engine.time_elapsed
	if is_zen:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#f8fafc"), true)
		return
	if lv_id >= 101:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#58a6ff"), true)
	elif lv_id >= 51:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#05091e"), true)
	else:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040a28"), true)
	var bg_key: String = _pick_stage_bg_key(lv_id)
	var bg_tex: Texture2D = _tex(bg_key)
	if bg_tex != null:
		var tsz: Vector2 = bg_tex.get_size()
		var bg_scale: float = vh / maxf(1.0, tsz.y)
		var tile_w: float = maxf(960.0, roundf(tsz.x * bg_scale))
		var sky_drift: float = 0.0 if engine.world_frozen else (t_sec * 7.5)
		var p_scroll: float = engine.cam_x * 0.22 + sky_drift
		var offset_x: float = fposmod(p_scroll, tile_w)
		var draw_x: float = -offset_x
		while draw_x < vw + 2.0:
			draw_texture_rect(bg_tex, Rect2(floorf(draw_x), 0.0, tile_w + 1.0, vh), false)
			draw_x += tile_w
	if lv_id < 101:
		for st_var in sky_stars:
			var st: Dictionary = st_var
			var sx: float = fposmod(float(st["x"]) - engine.cam_x * 0.08, vw)
			var sy: float = float(st["y"]) * (vh / 540.0)
			var tw: float = 0.32 + 0.68 * absf(sin(t_sec * 3.4 + float(st["ph"])))
			var sc: Color = st["col"]
			var ssz: float = float(st["sz"])
			draw_rect(Rect2(sx, sy, ssz, ssz), Color(sc.r, sc.g, sc.b, tw * 0.78), true)
		if lv_id <= 50:
			for tr_var in sky_traffic:
				var tr: Dictionary = tr_var
				var tx: float = fposmod(float(tr["x"]) + t_sec * float(tr["spd"]) - engine.cam_x * 0.14, vw + 80.0) - 40.0
				var ty: float = float(tr["y"]) * (vh / 540.0)
				var tc: Color = tr["col"]
				draw_rect(Rect2(tx, ty, 12.0, 2.0), Color(tc.r, tc.g, tc.b, 0.52), true)
	if engine.world_frozen:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.05, 0.45, 0.56, 0.22), true)
	elif lv_id >= 51 and engine.is_dual_layer_active():
		var veil_c: Color = Color(0.75, 0.22, 0.92, 0.08) if engine.active_layer == 1 else Color(0.0, 0.92, 1.0, 0.05)
		draw_rect(Rect2(0.0, 0.0, vw, vh), veil_c, true)
	elif lv_id >= 101 and engine.s3_sundial_phase:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.99, 0.72, 0.18, 0.12), true)
func _draw_sprite_on(
	c: Control,
	tex: Texture2D,
	r: Rect2,
	flip_x: bool = false,
	flip_y: bool = false,
	tint: Color = Color.WHITE,
	rot_rad: float = 0.0,
	base_off: Vector2 = Vector2.ZERO
) -> void:
	if tex == null or r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	if not flip_x and not flip_y and absf(rot_rad) < 0.001:
		c.draw_texture_rect(tex, r, false, tint)
		return
	var center: Vector2 = r.position + r.size * 0.5
	var sx: float = -1.0 if flip_x else 1.0
	var sy: float = -1.0 if flip_y else 1.0
	c.draw_set_transform(base_off + center, rot_rad, Vector2(sx, sy))
	c.draw_texture_rect(tex, Rect2(-r.size * 0.5, r.size), false, tint)
	c.draw_set_transform(base_off, 0.0, Vector2.ONE)
func _draw_uv_tiled_on(
	c: Control,
	tex: Texture2D,
	dst_r: Rect2,
	seg_w: float,
	seg_h: float,
	tint: Color = Color.WHITE
) -> void:
	if dst_r.size.x <= 0.5 or dst_r.size.y <= 0.5:
		return
	if tex == null:
		c.draw_rect(dst_r, tint, true)
		return
	var tsz: Vector2 = tex.get_size()
	if tsz.x <= 1.0 or tsz.y <= 1.0:
		c.draw_rect(dst_r, tint, true)
		return
	var sw: float = maxf(8.0, seg_w)
	var sh: float = maxf(8.0, seg_h)
	var yy: float = dst_r.position.y
	var end_y: float = dst_r.position.y + dst_r.size.y
	var end_x: float = dst_r.position.x + dst_r.size.x
	while yy < end_y - 0.25:
		var ch: float = minf(sh, end_y - yy)
		var src_h: float = tsz.y * (ch / sh)
		var xx: float = dst_r.position.x
		while xx < end_x - 0.25:
			var cw: float = minf(sw, end_x - xx)
			var src_w: float = tsz.x * (cw / sw)
			c.draw_texture_rect_region(tex, Rect2(xx, yy, cw, ch), Rect2(0.0, 0.0, src_w, src_h), tint, false, false)
			xx += sw
		yy += sh
func _is_missile_flipped(e: Dictionary) -> bool:
	return float(e.get("dir", 1.0)) < 0.0
func _draw_stage_world() -> void:
	if ui == null or not ui.in_game or engine.lv_data.is_empty():
		return
	var vw: float = 960.0
	var vh: float = 540.0
	var props: Dictionary = engine.lv_data.get("props", {})
	var is_zen: bool = _is_in_zen_sanctuary(props)
	var shk: Vector2 = Vector2.ZERO
	if engine.shake_timer > 0.0:
		var prog: float = engine.shake_timer / maxf(0.05, engine.shake_dur)
		var mag: float = engine.shake_mag * prog * prog
		shk = Vector2(sin(engine.time_elapsed * 68.0) * mag, cos(engine.time_elapsed * 53.0) * mag * 0.7)
	var cam_off: Vector2 = Vector2(-roundf(engine.cam_x) + shk.x, -roundf(engine.cam_y) + shk.y)
	stage_box.draw_set_transform(cam_off, 0.0, Vector2.ONE)
	_draw_world_links(stage_box, vw)
	for s_var in engine.solids:
		var s: Dictionary = s_var
		_draw_solid_on(stage_box, s, vw, is_zen, cam_off)
	var active_boss: Dictionary = {}
	for e_var in engine.entities:
		var e: Dictionary = e_var
		_draw_entity_on(stage_box, e, vw, cam_off)
		var et: String = str(e.get("t", ""))
		if (et == "s2_boss" or et == "s3_boss" or (et == "enemy" and str(e.get("kind", "")) == "boss")) and int(e.get("hp", 0)) > 0 and not bool(e.get("defeated", false)):
			active_boss = e
	if engine.has_grave:
		var gt: Texture2D = _tex("hero_grave")
		if gt != null:
			stage_box.draw_texture_rect(gt, Rect2(engine.grave_pos.x - 10.0, engine.grave_pos.y - 6.0, 48.0, 52.0), false)
	if not engine.shadow_clone.is_empty():
		var sc_tex: Texture2D = _tex("hero_run1")
		var sc_f: bool = int(engine.shadow_clone.get("facing", 1)) < 0
		_draw_sprite_on(stage_box, sc_tex, Rect2(float(engine.shadow_clone["x"]) - 10.0, float(engine.shadow_clone["y"]) - 6.0, 48.0, 50.0), sc_f, false, Color(0.85, 0.28, 0.96, 0.84), 0.0, cam_off)
	for ec_var in engine.echo_clones:
		var ec: Dictionary = ec_var
		if bool(ec.get("cat_mirror", false)):
			var cm_r: Rect2 = Rect2(float(ec["x"]) - 4.0, float(ec["y"]) - 4.0, float(ec.get("w", 28.0)) + 8.0, float(ec.get("h", 42.0)) + 8.0)
			stage_box.draw_rect(cm_r, Color("#f43f5e"), false, 2.0)
			stage_box.draw_texture_rect(_tex("cat_nav_taunt"), Rect2(float(ec["x"]) - 6.0, float(ec["y"]), float(ec.get("w", 28.0)) + 12.0, float(ec.get("h", 42.0))), false)
		else:
			var same_l: bool = int(ec.get("layer", 0)) == engine.active_layer
			var ec_al: float = 0.78 if same_l else 0.34
			var ec_col: Color = Color(0.98, 0.25, 0.55, ec_al) if bool(ec.get("hazard", false)) else Color(0.20, 0.96, 1.0, ec_al)
			var ec_f: bool = int(ec.get("facing", 1)) < 0
			_draw_sprite_on(stage_box, _tex("hero_run1"), Rect2(float(ec["x"]) - 10.0, float(ec["y"]) - 6.0, 48.0, 50.0), ec_f, false, ec_col, 0.0, cam_off)
	for ai_var in engine.afterimages:
		var ai: Dictionary = ai_var
		var a_col: Color = ai.get("color", Color("#00f5ff"))
		var a_alpha: float = clampf(float(ai.get("life", 0.1)) / maxf(0.05, float(ai.get("max_life", 0.22))), 0.0, 1.0) * 0.42
		var ai_flip: bool = int(ai.get("facing", 1)) < 0
		_draw_sprite_on(stage_box, _tex("hero_jump1"), Rect2(float(ai["x"]) - 10.0, float(ai["y"]) - 6.0, 48.0, 50.0), ai_flip, float(ai.get("grav_dir", 1.0)) < 0.0, Color(a_col.r, a_col.g, a_col.b, a_alpha), 0.0, cam_off)
	_draw_hero_on(stage_box, cam_off)
	_draw_combat_and_fx_on(stage_box, cam_off)
	stage_box.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var is_blackout: bool = props.has("blackoutAfter") and engine.time_elapsed >= float(props["blackoutAfter"])
	if is_blackout and not engine.player.is_empty():
		var px_s: float = float(engine.player["x"]) + 14.0 - engine.cam_x
		var py_s: float = float(engine.player["y"]) + 21.0 - engine.cam_y
		var rad: float = 290.0 if engine.light_burst_timer > 0.0 else 108.0
		_draw_spotlight_mask(stage_box, vw, vh, Vector2(px_s, py_s), rad)
	if not active_boss.is_empty():
		_draw_boss_hud_bar(stage_box, vw, active_boss)
	if engine.fake_phase > 0:
		_draw_fake_flag_prank(stage_box, vw, vh)
func _draw_world_links(c: Control, vw: float) -> void:
	for s_var in engine.solids:
		var s: Dictionary = s_var
		if bool(s.get("broken", false)):
			continue
		var mdx: float = float(s.get("move_dx_px", s.get("dx_px", 0.0)))
		var mdy: float = float(s.get("move_dy_px", s.get("dy_px", 0.0)))
		if absf(mdx) > 1.0 or absf(mdy) > 1.0:
			var bx: float = float(s.get("base_x", s.get("x", 0.0))) + float(s.get("w", 40.0)) * 0.5
			var by: float = float(s.get("base_y", s.get("y", 0.0))) + float(s.get("h", 40.0)) * 0.5
			c.draw_line(Vector2(bx, by), Vector2(bx + mdx, by - mdy), Color(0.0, 0.96, 1.0, 0.38), 2.0)
			c.draw_circle(Vector2(bx, by), 3.0, Color("#00f5ff"))
			c.draw_circle(Vector2(bx + mdx, by - mdy), 3.0, Color("#00f5ff"))
	var nodes_by_grp: Dictionary = {}
	for e_var in engine.entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "signal_node":
			var grp: String = str(e.get("group", ""))
			if grp != "":
				nodes_by_grp[grp] = Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
	if not nodes_by_grp.is_empty():
		for s_var in engine.solids:
			var s2: Dictionary = s_var
			var st: String = str(s2.get("t", ""))
			if st == "signal_bridge" or st == "signal_gate":
				var g: String = str(s2.get("group", ""))
				if nodes_by_grp.has(g):
					var p0: Vector2 = nodes_by_grp[g]
					if absf(p0.x - engine.cam_x) < vw + 320.0:
						var p1: Vector2 = Vector2(float(s2["x"]) + float(s2["w"]) * 0.5, float(s2["y"]) + float(s2["h"]) * 0.5)
						var on_g: bool = bool(engine.signal_groups.get(g, false))
						c.draw_line(p0, p1, Color(0.29, 0.87, 0.50, 0.55) if on_g else Color(0.0, 0.96, 1.0, 0.22), 2.0)
func _draw_solid_on(c: Control, s: Dictionary, vw: float, is_zen: bool, _cam_off: Vector2) -> void:
	var sx: float = float(s.get("x", 0.0))
	var sw: float = float(s.get("w", 40.0))
	if sx + sw < engine.cam_x - 96.0 or sx > engine.cam_x + vw + 96.0:
		return
	var st: String = str(s.get("t", "solid"))
	if st == "sign_landed":
		return
	var t_sec: float = engine.time_elapsed
	if bool(s.get("broken", false)):
		if st == "vanish" and float(s.get("respawn_timer", 0.0)) > 0.0:
			var pct: float = clampf(1.0 - float(s["respawn_timer"]) / 2.2, 0.0, 1.0)
			var sy_b: float = float(s.get("y", 0.0))
			var sh_b: float = float(s.get("h", 40.0))
			c.draw_rect(Rect2(sx + 2.0, sy_b + 2.0, sw - 4.0, sh_b - 4.0), Color(0.0, 0.96, 1.0, 0.45), false, 1.5)
			c.draw_rect(Rect2(sx + 5.0, sy_b + sh_b * 0.5 - 2.0, (sw - 10.0) * pct, 4.0), Color("#22d3ee"), true)
		return
	var sy: float = float(s.get("y", 0.0)) + float(s.get("bump_offset", 0.0))
	var sh: float = float(s.get("h", 40.0))
	var r: Rect2 = Rect2(sx, sy, sw, sh)
	var lv_id: int = engine.lv_id
	var s_layer: int = int(s.get("layer", -1))
	var ghost_layer: bool = (lv_id >= 51 and s_layer >= 0 and s_layer != engine.active_layer)
	var alpha_mul: float = 0.28 if ghost_layer else 1.0
	var base_tint: Color = Color(0.85, 0.55, 1.0, alpha_mul) if (ghost_layer and s_layer == 1) else (Color(0.55, 0.92, 1.0, alpha_mul) if ghost_layer else Color(1.0, 1.0, 1.0, alpha_mul))
	if is_zen and st == "solid":
		c.draw_rect(r, Color("#e2e8f0"), true)
		c.draw_rect(r, Color("#94a3b8"), false, 2.0)
		return
	if st == "invis":
		if bool(s.get("revealed", false)):
			var rev_tint: Color = Color(0.62, 0.66, 0.76, alpha_mul) if bool(s.get("looted", false)) else base_tint
			c.draw_rect(r.grow(-1.0), Color(0.04, 0.08, 0.20, alpha_mul), true)
			if lv_id >= 101 or bool(s.get("s3_kaizo", false)):
				_draw_uv_tiled_on(c, _tex("s3_kaizo_block"), r, 36.0, 36.0, rev_tint)
			else:
				_draw_uv_tiled_on(c, _tex("plat_copper_destruct"), r, 96.0, 32.0, rev_tint)
			c.draw_rect(r.grow(-0.5), Color(0.0, 0.96, 1.0, 0.65 * alpha_mul), false, 1.5)
		else:
			var pulse_i: float = 0.18 + 0.14 * sin(t_sec * 4.5 + sx * 0.05)
			c.draw_rect(Rect2(sx + sw * 0.5 - 2.0, sy + sh * 0.5 - 2.0, 4.0, 4.0), Color(0.0, 0.96, 1.0, 0.52 if engine.xray_level else pulse_i * 0.55), true)
			if engine.xray_level:
				c.draw_rect(r, Color(0.0, 0.96, 1.0, 0.16), true)
				c.draw_rect(r, Color("#00f5ff"), false, 2.0)
		return
	if st == "qblock":
		if not bool(s.get("revealed", true)):
			var pulse_q: float = 0.18 + 0.14 * sin(t_sec * 4.5 + sx * 0.05)
			c.draw_rect(Rect2(sx + sw * 0.5 - 2.0, sy + sh * 0.5 - 2.0, 4.0, 4.0), Color(0.0, 0.96, 1.0, 0.52 if engine.xray_level else pulse_q * 0.55), true)
			if engine.xray_level:
				c.draw_rect(r, Color(0.98, 0.80, 0.08, 0.18), true)
				c.draw_rect(r, Color("#fde047"), false, 2.0)
			return
		var used_q: bool = bool(s.get("used", false))
		var bob_q: float = 0.0 if used_q else (sin(t_sec * 4.2 + sx * 0.04) * 2.0)
		var q_side: float = 0.95 * GridMath.TILE
		var qx: float = sx + (sw - q_side) * 0.5
		var qy: float = sy + (sh - q_side) * 0.5 + bob_q
		var qr: Rect2 = Rect2(qx, qy, q_side, q_side)
		var q_tex: Texture2D = _tex("s3_qblock" if lv_id >= 101 else "qblock")
		c.draw_rect(qr.grow(-2.0), Color(0.04, 0.08, 0.20, alpha_mul), true)
		var qtint: Color = Color(0.55, 0.58, 0.68, alpha_mul) if used_q else base_tint
		c.draw_texture_rect(q_tex, qr, false, qtint)
		if not used_q:
			var glow_q: float = 0.28 + 0.24 * sin(t_sec * 6.0 + sx)
			c.draw_rect(qr.grow(-1.5), Color(0.98, 0.80, 0.08, glow_q * alpha_mul), false, 1.5)
		return
	if st == "cloud_plat":
		var ck_p: String = "cloud_knife" if (bool(s.get("rule_swap", false)) and engine.rule_phase_b) else "cloud_safe"
		c.draw_texture_rect(_tex(ck_p), r, false, base_tint)
		return
	if st == "solid" or st == "fake_wall" or st == "fake_plat":
		if (st == "fake_wall" or st == "fake_plat") and bool(s.get("shattered", false)) and float(s.get("shatter_anim", 0.0)) <= 0.02:
			return
		var f_alpha: float = alpha_mul
		if st == "fake_wall" or st == "fake_plat":
			if float(s.get("shatter_anim", 0.0)) > 0.02:
				f_alpha *= clampf(float(s["shatter_anim"]), 0.15, 1.0)
			elif engine.xray_level:
				f_alpha *= 0.42
		var f_tint: Color = Color(base_tint.r, base_tint.g, base_tint.b, f_alpha)
		if lv_id >= 101:
			var skin3: String = str(s.get("skin", ""))
			if skin3 == "tanuki_log":
				c.draw_texture_rect(_tex("s3_mon_tanuki_log"), Rect2(sx - 2.0, sy, sw + 4.0, sh), false, f_tint)
			elif skin3 == "wood" or skin3 == "crate":
				c.draw_rect(r.grow(-1.0), Color(0.28, 0.16, 0.08, f_alpha), true)
				_draw_uv_tiled_on(c, _tex("s3_wood_crate"), r, 48.0, 48.0, f_tint)
			elif skin3 == "stone":
				c.draw_rect(r.grow(-1.0), Color(0.22, 0.25, 0.30, f_alpha), true)
				_draw_uv_tiled_on(c, _tex("s3_stone_brick"), r, 48.0, 48.0, f_tint)
			elif skin3 == "grass" or (skin3 == "" and sy + sh >= GridMath.WORLD_ORIGIN_Y - 4.0):
				c.draw_rect(Rect2(sx, sy + 8.0, sw, maxf(4.0, sh - 8.0)), Color(0.26, 0.16, 0.09, f_alpha), true)
				var top_h3: float = minf(48.0, sh)
				_draw_uv_tiled_on(c, _tex("s3_ground_top"), Rect2(sx, sy, sw, top_h3), 144.0, 48.0, f_tint)
				if sh > top_h3 + 1.0:
					_draw_uv_tiled_on(c, _tex("s3_ground_dirt"), Rect2(sx, sy + top_h3, sw, sh - top_h3), 96.0, 48.0, f_tint)
			else:
				c.draw_rect(Rect2(sx + 1.0, sy + 6.0, sw - 2.0, maxf(4.0, sh - 8.0)), Color(0.24, 0.16, 0.10, f_alpha), true)
				_draw_uv_tiled_on(c, _tex("s3_float_grass"), Rect2(sx, sy, sw, maxf(sh, 46.0)), 144.0, maxf(sh, 46.0), f_tint)
		else:
			if sh > 14.0:
				c.draw_rect(Rect2(sx, sy + 6.0, sw, sh - 6.0), Color(0.027, 0.055, 0.149, f_alpha), true)
			else:
				c.draw_rect(r, Color(0.027, 0.055, 0.149, f_alpha), true)
			var is_s2: bool = (lv_id >= 51)
			if sh > sw * 1.35 and sw <= 100.0:
				var col_tex: Texture2D = _tex("s2_plat_column" if is_s2 else "plat_column")
				_draw_uv_tiled_on(c, col_tex, r, sw, 192.0, f_tint)
			elif sh <= 50.0 and sy + sh < GridMath.WORLD_ORIGIN_Y + 8.0:
				var fl_tex: Texture2D = _tex("s2_plat_float_deck" if is_s2 else "plat_float_deck")
				_draw_uv_tiled_on(c, fl_tex, Rect2(sx, sy, sw, maxf(sh, 46.0)), 192.0, maxf(sh, 46.0), f_tint)
			else:
				var use_reactor: bool = (sw >= 120.0 and sh >= 76.0)
				var top_k: String = ("s2_plat_reactor_wall" if is_s2 else "plat_reactor_wall") if use_reactor else ("s2_plat_ground_top" if is_s2 else "plat_ground_top")
				var sub_k: String = "s2_plat_sub_block" if (is_s2 and textures.has("s2_plat_sub_block")) else "plat_copper_destruct"
				var top_w: float = 288.0 if use_reactor else 240.0
				var top_h: float = 126.0 if use_reactor else 64.0
				if sh > top_h - 8.0:
					_draw_uv_tiled_on(c, _tex(sub_k), Rect2(sx, sy + top_h - 8.0, sw, sh - (top_h - 8.0)), 192.0, 64.0, f_tint)
				_draw_uv_tiled_on(c, _tex(top_k), Rect2(sx, sy, sw, minf(sh, top_h)), top_w, top_h, f_tint)
				if use_reactor and not engine.world_frozen:
					var cg_a: float = (0.07 + 0.07 * sin(t_sec * 3.4 + sx * 0.02)) * f_alpha
					c.draw_rect(Rect2(sx + 6.0, sy + 18.0, sw - 12.0, minf(44.0, sh - 22.0)), Color(0.0, 0.96, 1.0, cg_a), true)
			if sw >= 44.0 and not engine.world_frozen:
				var span_p: float = maxf(24.0, sw - 16.0)
				var px_dot: float = sx + 8.0 + fposmod(t_sec * 64.0 + absf(sx) * 0.37, span_p)
				var dot_c: Color = Color(0.98, 0.80, 0.08, 0.85 * f_alpha) if is_s2 else Color(0.0, 0.96, 1.0, 0.82 * f_alpha)
				c.draw_rect(Rect2(px_dot, sy + 2.0, 10.0, 2.0), dot_c, true)
				c.draw_rect(Rect2(px_dot + 6.0, sy + 2.0, 3.0, 2.0), Color(1.0, 1.0, 1.0, f_alpha), true)
			c.draw_rect(Rect2(sx, sy, 2.0, minf(sh, 18.0)), Color(0.58, 0.64, 0.72, 0.45 * f_alpha), true)
			c.draw_rect(Rect2(sx + sw - 2.0, sy, 2.0, minf(sh, 18.0)), Color(0.58, 0.64, 0.72, 0.45 * f_alpha), true)
		if engine.xray_level and (st == "fake_wall" or st == "fake_plat"):
			c.draw_rect(r, Color("#c084fc"), false, 2.0)
		return
	if st == "destructible":
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.18, alpha_mul), true)
		var dk: String = "s3_stone_cracked" if lv_id >= 101 else "plat_copper_destruct"
		_draw_uv_tiled_on(c, _tex(dk), r, 144.0 if lv_id < 101 else 48.0, 48.0, base_tint)
		var wp: float = 0.55 + 0.40 * absf(sin(t_sec * 4.2))
		c.draw_rect(r.grow(-1.0), Color(0.98, 0.57, 0.24, wp * alpha_mul), false, 2.0)
	elif st == "vanish":
		var v_shaking: bool = float(s.get("vanish_timer", -1.0)) >= 0.0
		var v_off: float = sin(t_sec * 55.0) * 3.0 if v_shaking else sin(t_sec * 4.2 + sx * 0.05) * 1.5
		var vr: Rect2 = Rect2(sx + (v_off if v_shaking else 0.0), sy + (0.0 if v_shaking else v_off), sw, sh)
		c.draw_rect(vr.grow(-1.0), Color(0.04, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s3_float_grass" if lv_id >= 101 else "plat_vanish_hover"), vr, 192.0 if lv_id < 101 else 96.0, maxf(sh, 48.0), base_tint)
		c.draw_rect(vr.grow(-1.0), Color("#f43f5e") if v_shaking else Color(0.0, 0.96, 1.0, 0.62 * alpha_mul), false, 1.5)
	elif st == "mirror":
		c.draw_rect(r, Color(0.06, 0.14, 0.28, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("mirror_wall"), r, sw, 40.0, base_tint)
	elif st == "s3_tall_pipe":
		var tp_tex: Texture2D = _tex("s3_pipe_tall")
		if tp_tex != null:
			var tp_sz: Vector2 = tp_tex.get_size()
			var rim_sh: float = roundf(tp_sz.y * 0.34)
			if sh > 26.0:
				c.draw_texture_rect_region(tp_tex, Rect2(sx + 2.0, sy + 24.0, maxf(8.0, sw - 4.0), sh - 24.0), Rect2(0.0, rim_sh, tp_sz.x, maxf(4.0, tp_sz.y - rim_sh)), base_tint)
			c.draw_texture_rect_region(tp_tex, Rect2(sx - 2.0, sy, sw + 4.0, minf(26.0, sh)), Rect2(0.0, 0.0, tp_sz.x, rim_sh), base_tint)
	elif st == "s3_cloud":
		var mode_c: String = str(s.get("mode", "safe_plat"))
		var knife_out: bool = bool(s.get("blades_out", false)) or (not Sector3Arcadia.is_cloud_safe(s, engine.s3_sundial_phase) and (engine.xray_level or mode_c == "sundial_knife"))
		var ck: String = "s3_cloud_knife" if knife_out else ("s3_cloud_dark" if mode_c == "swoop_cloud" else "s3_cloud_safe")
		c.draw_texture_rect(_tex(ck), r, false, Color(1.0, 1.0, 1.0, 0.45 if (mode_c == "fake_cloud" and engine.xray_level) else alpha_mul))
	elif st == "s3_drop_block":
		var db_shk: float = roundf(sin(t_sec * 65.0) * 3.0) if str(s.get("drop_state", "")) == "shake" else 0.0
		var db_r: Rect2 = Rect2(sx + db_shk, sy, sw, sh)
		c.draw_rect(db_r.grow(-1.0), Color(0.22, 0.20, 0.18, alpha_mul), true)
		var db_sk: String = str(s.get("skin", "stone"))
		_draw_uv_tiled_on(c, _tex("s3_wood_crate" if (db_sk == "wood" or db_sk == "crate") else "s3_stone_brick"), db_r, 48.0, 48.0, base_tint)
	elif st == "s3_slide_turf":
		c.draw_rect(r.grow(-1.0), Color(0.22, 0.15, 0.09, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s3_float_grass"), r, 96.0, sh, base_tint)
	elif st == "conveyor":
		var stop_c: bool = str(s.get("stop_group", "")) != "" and bool(engine.signal_groups.get(str(s.get("stop_group", "")), false))
		var bvx_c: float = float(s.get("belt_vx", 135.0))
		var dir_c: float = 1.0 if bvx_c >= 0.0 else -1.0
		var fast_c: bool = bool(s.get("fast_trap", false))
		c.draw_rect(r, Color(0.035, 0.05, 0.12, alpha_mul), true)
		c.draw_rect(r.grow(-2.0), Color(0.30, 0.02, 0.10, alpha_mul) if fast_c else Color(0.12, 0.16, 0.23, alpha_mul), true)
		var rim_col: Color = Color("#f43f5e") if fast_c else (Color("#64748b") if stop_c else Color("#eab308"))
		rim_col.a = alpha_mul
		c.draw_rect(Rect2(sx + 2.0, sy + 2.0, maxf(4.0, sw - 4.0), 3.0), rim_col, true)
		c.draw_rect(Rect2(sx + 2.0, sy + sh - 5.0, maxf(4.0, sw - 4.0), 3.0), rim_col, true)
		var span_c: float = maxf(20.0, sw - 26.0)
		var shift_c: float = 0.0 if stop_c else fposmod(t_sec * absf(bvx_c) * 0.5, 20.0) * dir_c
		var ch_col: Color = Color("#fb7185") if fast_c else (Color("#475569") if stop_c else Color("#22d3ee"))
		ch_col.a = alpha_mul
		var xx_c: float = 14.0
		while xx_c < sw - 16.0:
			var ax_c: float = sx + 12.0 + fposmod(xx_c - 12.0 + shift_c, span_c)
			var my_c: float = sy + sh * 0.5
			c.draw_rect(Rect2(ax_c, my_c - 4.0, 3.0, 2.0), ch_col, true)
			c.draw_rect(Rect2(ax_c + dir_c * 3.0, my_c - 1.0, 3.0, 2.0), ch_col, true)
			c.draw_rect(Rect2(ax_c, my_c + 2.0, 3.0, 2.0), ch_col, true)
			xx_c += 20.0
	elif st == "rail_plat":
		c.draw_rect(r.grow(-1.0), Color(0.04, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s2_rail_plat"), r, 128.0, sh, base_tint)
	elif st == "phase_plat":
		var p_st: String = str(s.get("phase_state", "solid"))
		var p_solid: bool = p_st != "ghost"
		var p_warn: bool = p_st == "warn"
		var pk: String = "s2_phase_warn" if p_warn else ("s2_phase_solid" if p_solid else "s2_phase_ghost")
		if p_solid:
			c.draw_rect(r.grow(-1.0), Color(0.04, 0.09, 0.22, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex(pk), r, 144.0, sh, Color(1.0, 1.0, 1.0, (1.0 if p_solid else 0.32) * alpha_mul))
	elif st == "polarity_block":
		var mode_p: String = str(engine.polarity_groups.get(str(s.get("group", "m1")), "blue"))
		var is_org: bool = mode_p == "orange"
		if s.has("blue_x") and s.has("orange_x"):
			c.draw_rect(Rect2(float(s["blue_x"]) + 2.0, float(s["blue_y"]) + 2.0, sw - 4.0, sh - 4.0), Color(0.23, 0.51, 0.96, 0.28 * alpha_mul), false, 1.5)
			c.draw_rect(Rect2(float(s["orange_x"]) + 2.0, float(s["orange_y"]) + 2.0, sw - 4.0, sh - 4.0), Color(0.98, 0.57, 0.24, 0.28 * alpha_mul), false, 1.5)
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s2_mag_orange" if is_org else "s2_mag_blue"), r, 96.0, sh, base_tint)
	elif st == "signal_bridge":
		var br_on: bool = Sector1And2Mechanics.is_signal_bridge_on(s, engine.signal_groups)
		c.draw_rect(r, Color(0.0, 0.96, 1.0, 0.72 * alpha_mul) if br_on else Color(0.0, 0.96, 1.0, 0.14), true)
		c.draw_rect(r, Color("#00f5ff"), false, 1.5)
	elif st in ["signal_gate", "beat_gate", "paradox_gate", "timed_gate"]:
		var g_open: bool = false
		if st == "signal_gate":
			g_open = Sector1And2Mechanics.is_signal_gate_open(s, engine.signal_groups)
		elif st == "beat_gate":
			g_open = bool(s.get("is_open", false))
		elif st == "paradox_gate":
			g_open = engine.paradox_unlocked or bool(s.get("gate_open", false))
		elif st == "timed_gate":
			g_open = engine.time_elapsed >= float(s.get("open_time", 5.0))
		if not g_open:
			_draw_uv_tiled_on(c, _tex("s2_beat_gate" if lv_id >= 51 else "laser_gate"), r, sw, 64.0, base_tint)
	elif st == "shy_brick":
		var shy_on: bool = bool(s.get("shy_solid", true))
		if shy_on:
			c.draw_rect(r.grow(-1.0), Color(0.06, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s2_shy_brick"), r, 48.0, 48.0, Color(1.0, 1.0, 1.0, (1.0 if shy_on else 0.26) * alpha_mul))
	elif st == "piston":
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s2_piston_head"), r, sw, 48.0, base_tint)
	elif st == "ceiling_crusher":
		c.draw_rect(r.grow(-1.0), Color(0.08, 0.05, 0.16, alpha_mul), true)
		c.draw_texture_rect(_tex("s2_ceiling_crusher"), r, false, base_tint)
	elif st == "moving_pit":
		var mp_lg: String = str(s.get("lock_group", ""))
		var mp_locked: bool = mp_lg != "" and bool(engine.signal_groups.get(mp_lg, false))
		var leg_bob: float = sin(t_sec * 36.0) * 3.0 if (bool(s.get("triggered", false)) and not bool(s.get("scoot_done", false))) else 0.0
		c.draw_texture_rect(_tex("s2_moving_pit"), Rect2(sx, sy - 3.0 + leg_bob, sw, sh + 16.0), false, base_tint)
		if mp_locked:
			c.draw_rect(r.grow(-1.0), Color("#4ade80"), false, 2.0)
	elif st == "fake_error":
		var fe_flash: float = float(s.get("hit_flash", 0.0))
		var fe_tint: Color = Color(1.8, 1.8, 1.8, alpha_mul) if fe_flash > 0.0 else base_tint
		c.draw_texture_rect(_tex("s2_fake_error"), r, false, fe_tint)
		var fe_lbl: String = "BRIDGE.SYS" if str(s.get("mode", "")) == "walk_top" else str(s.get("title_text", "ERR_404"))
		c.draw_string(font_main, Vector2(sx + 10.0, sy + 16.0), fe_lbl, HORIZONTAL_ALIGNMENT_LEFT, maxf(16.0, sw - 20.0), 9, Color(1.0, 1.0, 1.0, alpha_mul))
	elif st == "glass_panel":
		var is_real_gp: bool = bool(s.get("real", true))
		var rev_fk: bool = bool(s.get("revealed_fake", false)) or (engine.xray_level and not is_real_gp)
		var tested_gp: bool = bool(s.get("tested", false))
		if rev_fk:
			c.draw_rect(r, Color(0.96, 0.25, 0.37, 0.18 * alpha_mul), true)
			c.draw_rect(r.grow(-1.0), Color(1.0, 0.16, 0.71, 0.55 * alpha_mul), false, 1.5)
		else:
			c.draw_rect(r, Color(0.13, 0.83, 0.93, (0.54 if tested_gp else 0.38) * alpha_mul), true)
			c.draw_rect(Rect2(sx, sy, sw, 3.0), Color(0.88, 0.95, 1.0, 0.90 * alpha_mul), true)
			c.draw_rect(r, Color("#fde047") if tested_gp else Color(1.0, 1.0, 1.0, 0.82 * alpha_mul), false, 1.5)
	elif st in ["time_slice_plat", "null_block"]:
		var col_on: bool = Sector1And2Mechanics.is_solid_collidable(s, engine.active_layer, engine.signal_groups)
		var base_a: float = (0.66 if st == "time_slice_plat" else 0.70) * (1.0 if col_on else 0.22) * alpha_mul
		var fill_g: Color = Color(0.99, 0.85, 0.28, base_a) if st == "time_slice_plat" else Color(0.75, 0.52, 0.99, base_a)
		c.draw_rect(r, fill_g, true)
		c.draw_rect(r, Color(1.0, 1.0, 1.0, 0.85 if col_on else 0.25), false, 1.5)
	else:
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.18, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("platform_copper"), r, 128.0, 42.0, base_tint)
func _draw_entity_on(c: Control, e: Dictionary, vw: float, cam_off: Vector2) -> void:
	if bool(e.get("dead", false)):
		return
	var ex: float = float(e.get("x", 0.0))
	var ey: float = float(e.get("y", 0.0))
	var ew: float = float(e.get("w", 36.0))
	var eh: float = float(e.get("h", 36.0))
	var et: String = str(e.get("t", ""))
	if et != "time_bubble" and (ex + ew < engine.cam_x - 120.0 or ex > engine.cam_x + vw + 120.0):
		return
	var lv_id: int = engine.lv_id
	var t_sec: float = engine.time_elapsed
	var r: Rect2 = Rect2(ex, ey, ew, eh)
	var e_layer: int = int(e.get("layer", -1))
	var ghost_e: bool = (lv_id >= 51 and e_layer >= 0 and e_layer != engine.active_layer)
	var tint: Color = Color(1.0, 1.0, 1.0, 0.30 if ghost_e else 1.0)
	if et == "spikes":
		var is_ceil: bool = bool(e.get("ceil", false))
		var sp_tex: Texture2D = _tex("s3_thorns" if lv_id >= 101 else "spikes_red")
		var xx: float = ex
		while xx < ex + ew - 1.0:
			var cw: float = minf(GridMath.TILE, ex + ew - xx)
			_draw_sprite_on(c, sp_tex, Rect2(xx, ey, cw, eh), false, is_ceil, tint, 0.0, cam_off)
			xx += GridMath.TILE
	elif et == "flower":
		var fk: String = "flower_chomp" if (not engine.world_frozen and sin(t_sec * 5.2 + ex * 0.08) > 0.2) else "flower_skull"
		var f_col: Color = Color(1.0, 1.0, 1.0, 0.48) if (bool(e.get("rule_swap", false)) and engine.rule_phase_b) else tint
		c.draw_texture_rect(_tex(fk), r, false, f_col)
	elif et == "amanita":
		c.draw_texture_rect(_tex("mushroom_amanita"), r, false, tint)
	elif et == "poison_item":
		c.draw_texture_rect(_tex("mushroom_poison"), r, false, tint)
	elif et == "antidote_pad":
		c.draw_texture_rect(_tex("item_antidote"), Rect2(ex, ey - 6.0, ew, eh + 6.0), false, tint)
	elif et == "crafting":
		c.draw_texture_rect(_tex("crafting_station"), Rect2(ex - 6.0, ey - 6.0, ew + 12.0, eh + 6.0), false, tint)
	elif et == "spring":
		var sp_anim: float = float(e.get("spring_anim", 0.0))
		if lv_id >= 101:
			var sq_s3: float = 1.25 if sp_anim > 0.05 else 1.0
			c.draw_texture_rect(_tex("s3_shroom_bounce"), Rect2(ex - 2.0, ey - 4.0 * sq_s3, ew + 4.0, (eh + 4.0) * sq_s3), false, tint)
		elif sp_anim > 0.80:
			c.draw_texture_rect(_tex("spring_compressed"), Rect2(ex - 2.0, ey + 4.0, ew + 4.0, eh - 4.0), false, tint)
		elif sp_anim > 0.05:
			c.draw_texture_rect(_tex("spring_launch"), Rect2(ex, ey - 6.0 * sp_anim, ew, eh + 6.0 * sp_anim), false, tint)
			var prog_sp: float = 1.0 - sp_anim
			var vcol_sp: Color = Color("#fde047") if prog_sp < 0.5 else Color("#00f5ff")
			vcol_sp.a = clampf(sp_anim * 0.9, 0.0, 1.0) * tint.a
			for k_v in range(2):
				var cy_v: float = ey - 6.0 - prog_sp * 38.0 - float(k_v) * 11.0
				var cx_v: float = ex + ew * 0.5
				c.draw_line(Vector2(cx_v - 12.0, cy_v + 7.0), Vector2(cx_v, cy_v), vcol_sp, 2.2)
				c.draw_line(Vector2(cx_v, cy_v), Vector2(cx_v + 12.0, cy_v + 7.0), vcol_sp, 2.2)
		else:
			c.draw_texture_rect(_tex("spring"), r, false, tint)
	elif et == "checkpoint":
		var is_on: bool = bool(e.get("active", false)) or ((not engine.active_checkpoint.is_empty()) and absf(float(engine.active_checkpoint.get("x", -999.0)) - GridMath.px_to_gx(ex)) < 0.8)
		var cpk: String = ("s3_cp_on" if is_on else "s3_cp_off") if lv_id >= 101 else ("checkpoint_on" if is_on else "checkpoint_off")
		c.draw_texture_rect(_tex(cpk), Rect2(ex - 4.0, ey - 4.0, ew + 8.0, eh + 4.0), false, tint)
		if lv_id >= 101 and bool(e.get("s3_fake", false)):
			c.draw_rect(Rect2(ex + 14.0, ey - 5.0, 4.0, 5.0), Color("#e11d48"), true)
			c.draw_rect(Rect2(ex + 24.0, ey - 5.0, 4.0, 5.0), Color("#e11d48"), true)
	elif et == "flag":
		var is_fk: bool = bool(e.get("fake", false))
		var flk: String = ("s3_flag_win" if engine.fake_phase == 1 else "s3_flag_idle") if lv_id >= 101 else ("flag_win" if engine.fake_phase == 1 else "flag_idle")
		var fl_tint: Color = Color(1.0, 1.0, 1.0, 0.48) if (engine.xray_level and is_fk) else tint
		c.draw_texture_rect(_tex(flk), Rect2(ex - 4.0, ey, ew + 14.0, eh), false, fl_tint)
		if engine.xray_level and is_fk:
			c.draw_rect(r, Color("#fb7185"), false, 2.0)
	elif et == "cloud" or et == "cloud_knife":
		var safe_now: bool = bool(e.get("rule_swap", false)) and engine.rule_phase_b
		var k_rev: bool = (et == "cloud_knife" and (engine.xray_level or fposmod(t_sec, 2.2) < 0.28)) or (engine.xray_level and bool(e.get("knife", false)))
		var shiver_c: float = sin(t_sec * 65.0) * 3.0 if (et == "cloud_knife" and not safe_now and fposmod(t_sec, 2.2) < 0.24) else 0.0
		var clk: String = "cloud_safe" if safe_now else ("cloud_knife" if k_rev else ("cloud_poison" if bool(e.get("poison", false)) else ("cloud_dark_safe" if et == "cloud_knife" else "cloud_safe")))
		c.draw_texture_rect(_tex(clk), Rect2(ex + shiver_c, ey, ew, eh), false, tint)
	elif et == "coin":
		var ck2: String = "coin_2" if int(t_sec * 5.0) % 2 == 1 else "coin_1"
		c.draw_texture_rect(_tex(ck2), Rect2(ex, ey + sin(t_sec * 4.0 + ex) * 2.5, ew, eh), false, tint)
	elif et == "gem":
		var gc: String = str(e.get("color", "red"))
		c.draw_texture_rect(_tex("gem_" + gc), Rect2(ex, ey + sin(t_sec * 4.2 + ex) * 3.5, ew, eh), false, tint)
	elif et == "powerup":
		var pk2: String = "icon_wing" if str(e.get("kind", "")) == "flight" else "icon_spring"
		c.draw_texture_rect(_tex(pk2), Rect2(ex, ey + sin(t_sec * 4.5) * 3.5, ew, eh), false, tint)
	elif et == "bomb_pickup" or et == "chain_bomb":
		var b_pl: float = sin(t_sec * 36.0) * 3.5 if float(e.get("fuse", -1.0)) >= 0.0 else sin(t_sec * 5.0) * 1.5
		c.draw_texture_rect(_tex("bomb"), Rect2(ex - b_pl * 0.5, ey - b_pl * 0.5, ew + b_pl, eh + b_pl), false, tint)
	elif et == "clock" or et == "beat_clock":
		var use_gear: bool = (et == "beat_clock") or bool(e.get("gear", false))
		var c_rot: float = fposmod(t_sec * 1.8, TAU) * 0.08 if use_gear else sin(t_sec * 9.0) * 0.09
		_draw_sprite_on(c, _tex("clock_gear" if use_gear else "clock_gold"), Rect2(ex, ey + sin(t_sec * 3.5) * 2.5, ew, eh), false, false, tint, c_rot, cam_off)
	elif et == "hourglass":
		var hg_a: float = 0.35 if float(e.get("cooldown", 0.0)) > 0.0 else tint.a
		c.draw_texture_rect(_tex("time_hourglass"), Rect2(ex - 4.0, ey - 4.0 + sin(t_sec * 4.0) * 3.0, ew + 8.0, eh + 4.0), false, Color(1.0, 1.0, 1.0, hg_a))
	elif et == "gravity_pad":
		var g_up: bool = float(e.get("dir", -1.0)) < 0.0
		var gk: String = "arrow_up_red" if g_up else "ui_pipe_down"
		var g_bob: float = sin(t_sec * 6.5) * 3.5 * (-1.0 if g_up else 1.0)
		c.draw_texture_rect(_tex(gk), Rect2(ex + 2.0, ey - 10.0 + g_bob, ew - 4.0, eh + 10.0), false, tint)
	elif et == "poop":
		c.draw_texture_rect(_tex("poop"), r, false, tint)
	elif et == "pipe":
		c.draw_rect(Rect2(ex + 6.0, ey + 4.0, ew - 12.0, eh - 4.0), Color(0.05, 0.24, 0.15, tint.a), true)
		c.draw_texture_rect(_tex("pipe"), r, false, tint)
		var rim_g: float = 0.28 + 0.24 * sin(t_sec * 4.0 + ex)
		c.draw_rect(Rect2(ex + 8.0, ey + 3.0, ew - 16.0, 3.0), Color(0.29, 0.87, 0.50, rim_g * tint.a), true)
	elif et == "launcher":
		var ldir_v: float = float(e.get("dir", 1.0))
		var rec_x: float = float(e.get("recoil", 0.0)) * (-ldir_v) * 5.0
		_draw_sprite_on(c, _tex("missile_launcher"), Rect2(ex + rec_x, ey, ew, eh), ldir_v < 0.0, false, tint, 0.0, cam_off)
	elif et == "missile":
		var m_flip: bool = _is_missile_flipped(e)
		var m_bob: float = sin(t_sec * 24.0 + ex * 0.05) * 1.2
		_draw_sprite_on(c, _tex("missile"), Rect2(ex, ey + m_bob, ew, eh), m_flip, false, tint, 0.0, cam_off)
	elif et == "sign":
		var sk: String = "s3_wood_sign" if lv_id >= 101 else ("sign_left" if str(e.get("dir", "right")) == "left" else "sign_right")
		c.draw_texture_rect(_tex(sk), r, false, tint)
		var stxt: String = str(e.get("textEn" if save.lang == "en" else "text", ""))
		if stxt != "" and font_main != null and int(e.get("fall_state", 0)) == 0:
			var bob_s: float = sin(t_sec * 3.4 + ex) * 1.5
			var pill_w: float = maxf(88.0, float(stxt.length()) * 13.0 + 18.0)
			var pill_x: float = ex + ew * 0.5 - pill_w * 0.5
			var pill_y: float = ey - 22.0 + bob_s
			var bg_s: Color = Color(0.12, 0.07, 0.03, 0.92) if lv_id >= 101 else Color(0.016, 0.039, 0.15, 0.92)
			var bd_s: Color = Color("#facc15") if lv_id >= 101 else Color("#00f5ff")
			var tx_s: Color = Color("#fef9c3") if lv_id >= 101 else Color("#00f5ff")
			c.draw_rect(Rect2(pill_x, pill_y, pill_w, 18.0), bg_s, true)
			c.draw_rect(Rect2(pill_x, pill_y, pill_w, 18.0), bd_s, false, 1.0)
			c.draw_string(font_main, Vector2(pill_x, pill_y + 13.0), stxt, HORIZONTAL_ALIGNMENT_CENTER, pill_w, 11, tx_s)
	elif et == "princess":
		var p_bob: float = -absf(sin(t_sec * 7.0)) * 5.0 if engine.princess_satisfied else sin(t_sec * 3.0) * 1.5
		c.draw_texture_rect(_tex("npc_princess"), Rect2(ex - 6.0, ey - 6.0 + p_bob, ew + 12.0, eh + 6.0), false, tint)
		if (bool(e.get("showOrderDots", false)) or engine.xray_level) and not engine.princess_satisfied:
			var req_p: Array = e.get("req", engine.princess_perm_order)
			for gi in range(req_p.size()):
				var g_col: String = str(req_p[gi])
				var done_g: bool = gi < engine.collected_gems.size() and str(engine.collected_gems[gi]) == g_col
				c.draw_texture_rect(_tex("gem_" + g_col), Rect2(ex - 8.0 + float(gi) * 18.0, ey - 22.0, 15.0, 15.0), false, Color(1.0, 1.0, 1.0, 1.0 if done_g else 0.45))
	elif et == "shop":
		c.draw_texture_rect(_tex("shop_frame"), Rect2(ex - 10.0, ey - 12.0, ew + 20.0, eh + 12.0), false, tint)
		c.draw_texture_rect(_tex("npc_merchant"), Rect2(ex + ew * 0.25, ey + 12.0 + sin(t_sec * 3.8) * 1.5, ew * 0.55, eh - 12.0), false, tint)
	elif et == "enemy":
		var ek: String = str(e.get("kind", "follower"))
		var espr: String = "enemy_boss" if ek == "boss" else ("enemy_flying" if ek == "flying" else "enemy_follower")
		var e_flip: bool = (ek == "follower" and float(e.get("vx", 0.0)) > 0.0)
		var hop_y: float = absf(sin(t_sec * 10.0 + ex * 0.05)) * 3.0 if ek == "follower" else (sin(t_sec * 4.2) * 4.0 if ek == "boss" else 0.0)
		var e_al: float = 0.50 if bool(e.get("is_phasing", false)) else (0.60 if float(e.get("stun_timer", 0.0)) > 0.0 else 1.0)
		_draw_sprite_on(c, _tex(espr), Rect2(ex, ey - hop_y, ew, eh), e_flip, false, Color(tint.r, tint.g, tint.b, tint.a * e_al), 0.0, cam_off)
	elif et == "piston":
		c.draw_rect(Rect2(ex + ew * 0.36, float(e.get("base_y", ey)) - 10.0, ew * 0.28, (ey - float(e.get("base_y", ey))) + 14.0), Color(0.20, 0.25, 0.33, tint.a), true)
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.20, tint.a), true)
		_draw_uv_tiled_on(c, _tex("s2_piston_head"), r, ew, 48.0, tint)
	elif et == "signal_node":
		var n_on: bool = bool(engine.signal_groups.get(str(e.get("group", "")), false))
		var nk: String = "s2_node_overload" if bool(e.get("fake", false)) else ("s2_node_on" if n_on else "s2_node_off")
		c.draw_texture_rect(_tex(nk), Rect2(ex, ey + sin(t_sec * 4.0 + ex) * 2.0, ew, eh), false, tint)
		var n_lbl: String = str(e.get("label", ""))
		if n_lbl == "" and str(e.get("seqGroup", "")) != "":
			n_lbl = "#%d" % int(e.get("seqStep", 1))
		if n_lbl != "" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 20.0, ey - 4.0), n_lbl, HORIZONTAL_ALIGNMENT_CENTER, ew + 40.0, 10, Color("#4ade80") if n_on else Color("#fde047"))
	elif et == "decoy_btn":
		c.draw_rect(Rect2(ex + 4.0, ey + eh - 10.0, ew - 8.0, 10.0), Color(0.20, 0.25, 0.33, tint.a), true)
		var db_pr: bool = bool(e.get("pressed", false))
		c.draw_rect(Rect2(ex + 8.0, ey + (14.0 if db_pr else 8.0), ew - 16.0, eh - (22.0 if db_pr else 16.0)), Color("#881337") if db_pr else Color("#f43f5e"), true)
		if font_main != null:
			c.draw_string(font_main, Vector2(ex - 20.0, ey + 4.0), str(e.get("label", "REBOOT")), HORIZONTAL_ALIGNMENT_CENTER, ew + 40.0, 9, Color("#fda4af"))
	elif et == "polarity_node":
		var p_org: bool = str(engine.polarity_groups.get(str(e.get("group", "m1")), "blue")) == "orange"
		c.draw_texture_rect(_tex("s2_mag_node_orange" if p_org else "s2_mag_node_blue"), Rect2(ex, ey + sin(t_sec * 4.5) * 2.0, ew, eh), false, tint)
	elif et == "portal":
		var pid_s: String = str(e.get("pairId", "A")).to_upper()
		var ptk: String = "s2_portal_c" if (pid_s == "C" or pid_s == "2") else ("s2_portal_b" if (pid_s == "B" or pid_s == "1") else "s2_portal_a")
		c.draw_texture_rect(_tex(ptk), Rect2(ex, ey + sin(t_sec * 3.5 + ex) * 2.0, ew, eh), false, tint)
		if font_main != null:
			var p_lbl: String = "OUT" if str(e.get("role", "")) == "out" else (("<-" + pid_s) if float(e.get("exitDir", 1.0)) < 0.0 else (pid_s + "->"))
			c.draw_string(font_main, Vector2(ex - 16.0, ey - 4.0), p_lbl, HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 10, Color.WHITE)
	elif et == "layer_term":
		c.draw_texture_rect(_tex("s2_layer_term"), Rect2(ex, ey + sin(t_sec * 3.8) * 2.5, ew, eh), false, tint)
	elif et in ["battery_slot", "root_slot", "echo_pad", "echo_rec_pad"]:
		var pad_on: bool = bool(e.get("filled", false)) or bool(e.get("depressed", false))
		var ry_p: float = ey + eh - 14.0
		var rim_p: Color = Color("#4ade80") if pad_on else (Color("#38bdf8") if et == "echo_rec_pad" else Color("#facc15"))
		c.draw_rect(Rect2(ex, ry_p + 6.0, ew, 8.0), Color(0.20, 0.25, 0.33, tint.a), true)
		var cap_y: float = ry_p + (4.0 if pad_on else 0.0)
		c.draw_rect(Rect2(ex + 3.0, cap_y, ew - 6.0, 6.0), Color("#15803d") if pad_on else Color("#1e1b4b"), true)
		c.draw_rect(Rect2(ex + 4.0, cap_y, ew - 8.0, 2.0), rim_p, true)
		if font_main != null:
			var sl_lbl: String = str(e.get("reqCode", ""))
			if sl_lbl == "":
				sl_lbl = "ECHO" if et == "echo_pad" else ("REC" if et == "echo_rec_pad" else "SLOT")
			c.draw_string(font_main, Vector2(ex - 16.0, ry_p - 4.0), sl_lbl, HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 9, rim_p)
	elif et == "signal_battery" or et == "root_item":
		if bool(e.get("inserted", false)) or bool(e.get("carried", false)):
			return
		var ik: String = "s2_battery" if et == "signal_battery" else "s2_root_key"
		c.draw_texture_rect(_tex(ik), Rect2(ex, ey + sin(t_sec * 4.0) * 3.0, ew, eh), false, tint)
		var bc_s: String = str(e.get("badgeCode", ""))
		if bc_s != "" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 12.0, ey - 3.0), bc_s, HORIZONTAL_ALIGNMENT_CENTER, ew + 24.0, 9, Color("#fde047"))
	elif et == "root_term":
		c.draw_texture_rect(_tex("s2_root_term"), r, false, tint)
		c.draw_rect(Rect2(ex + 10.0, ey + 8.0, maxf(6.0, ew - 20.0), 5.0), Color("#4ade80") if bool(e.get("activated", false)) else Color("#fde047"), true)
		if str(e.get("mode", "")) == "calm_touch" and not bool(e.get("activated", false)) and font_main != null:
			c.draw_string(font_main, Vector2(ex - 16.0, ey - 4.0), "CALM", HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 9, Color("#fde047"))
	elif et == "curse_totem":
		var ct_on: bool = float(e.get("disable_timer", 0.0)) <= 0.0
		if ct_on and not ghost_e:
			var ct_r: float = float(e.get("radius_px", 240.0))
			c.draw_arc(Vector2(ex + ew * 0.5, ey + eh * 0.5), ct_r, 0.0, TAU, 36, Color(0.91, 0.47, 0.98, 0.28), 2.0)
		c.draw_texture_rect(_tex("s2_curse_totem"), r, false, Color(tint.r, tint.g, tint.b, tint.a * (1.0 if ct_on else 0.42)))
	elif et == "fake_save":
		var pur: bool = bool(e.get("purified", false))
		var fs_act: bool = bool(e.get("active", false))
		c.draw_texture_rect(_tex(("checkpoint_on" if fs_act else "checkpoint_off") if pur else "s2_fake_save"), r, false, tint)
	elif et == "mimic_flag":
		var tamed: bool = bool(e.get("tamed", false))
		var rev_mf: bool = bool(e.get("revealed", false)) or engine.xray_level
		var mfk: String = "flag_win" if tamed else ("s2_mimic_flag" if rev_mf else "flag_idle")
		var mf_bob: float = sin(t_sec * 18.0) * 2.5 if (rev_mf and not tamed) else 0.0
		c.draw_texture_rect(_tex(mfk), Rect2(ex - 4.0, ey + mf_bob, ew + 8.0, eh), false, tint)
	elif et == "mimic_chest":
		var mc_aw: bool = bool(e.get("awake", false))
		var mc_sp: String = "s2_mimic_chest" if mc_aw else "chest_closed"
		var mc_flip: bool = (not engine.player.is_empty()) and float(engine.player.get("x", 0.0)) > ex
		_draw_sprite_on(c, _tex(mc_sp), r, mc_flip, false, tint, 0.0, cam_off)
		if mc_aw and str(e.get("mode", "")) == "bomb_feed" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 24.0, ey - 5.0), "FEED BOMB!", HORIZONTAL_ALIGNMENT_CENTER, ew + 48.0, 9, Color("#fb923c"))
	elif et == "betray_spring":
		var bs_cal: bool = bool(e.get("calibrated", false))
		var bs_rev: bool = bool(e.get("revealed_evil", false)) or engine.xray_level
		var bs_sp: String = "spring" if bs_cal else ("s2_betray_spring" if bs_rev else "spring")
		var bs_sq: float = (1.0 - 0.26 * sin(float(e.get("spring_anim", 0.0)) * PI)) if float(e.get("spring_anim", 0.0)) > 0.0 else 1.0
		c.draw_texture_rect(_tex(bs_sp), Rect2(ex, ey + eh * (1.0 - bs_sq), ew, eh * bs_sq), false, tint)
	elif et == "trojan_heart":
		if float(e.get("respawn_cd", 0.0)) > 0.0:
			return
		var th_bob: float = sin(t_sec * 4.5 + ex) * 3.5
		c.draw_texture_rect(_tex("s2_trojan_heart"), Rect2(ex, ey + th_bob, ew, eh), false, tint)
		if font_main != null:
			var th_lbl: String = "500KG" if str(e.get("mode", "")) == "heavy_curse" else "FREE"
			c.draw_string(font_main, Vector2(ex - 16.0, ey + th_bob - 4.0), th_lbl, HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 9, Color("#f43f5e") if str(e.get("mode", "")) == "shoot_to_buff" else Color("#a3e635"))
	elif et == "troll_hand":
		var th_off: String = str(e.get("offGroup", ""))
		if bool(e.get("parried", false)) or (th_off != "" and bool(engine.signal_groups.get(th_off, false))):
			return
		var is_pduel: bool = str(e.get("mode", "")) == "parry_duel"
		var th_t: Color = Color(1.5, 1.4, 0.9, tint.a) if str(e.get("state", "")) == "windup" else tint
		_draw_sprite_on(c, _tex("s2_troll_hand"), r, is_pduel, false, th_t, 0.0, cam_off)
		if is_pduel and str(e.get("state", "")) == "windup" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 24.0, ey - 6.0), "SLASH!", HORIZONTAL_ALIGNMENT_CENTER, ew + 48.0, 10, Color("#fde047"))
	elif et == "peace_dove":
		var pd_mad: bool = float(e.get("angry_timer", 0.0)) > 0.0
		var pd_t: Color = Color(1.35, 0.55, 0.65, tint.a) if pd_mad else tint
		_draw_sprite_on(c, _tex("s2_peace_dove"), r, float(e.get("vx", 0.0)) > 0.0, false, pd_t, 0.0, cam_off)
		if font_main != null:
			c.draw_string(font_main, Vector2(ex - 20.0, ey - 4.0), "ANGRY!" if pd_mad else "NO FIRE", HORIZONTAL_ALIGNMENT_CENTER, ew + 40.0, 9, Color("#f43f5e") if pd_mad else Color("#4ade80"))
	elif et == "saw_track":
		var off_gs: String = str(e.get("offGroup", ""))
		if off_gs != "" and bool(engine.signal_groups.get(off_gs, false)):
			return
		var sx0_w: float = float(e.get("base_x", ex)) + ew * 0.5
		var sy0_w: float = float(e.get("base_y", ey)) + eh * 0.5
		var sdx_w: float = float(e.get("dx_px", 0.0))
		var sdy_w: float = float(e.get("dy_px", 0.0))
		if absf(sdx_w) > 1.0 or absf(sdy_w) > 1.0:
			c.draw_line(Vector2(sx0_w, sy0_w), Vector2(sx0_w + sdx_w, sy0_w - sdy_w), Color(0.96, 0.25, 0.37, 0.42 * tint.a), 2.0)
		_draw_sprite_on(c, _tex("s2_saw_blade"), r, false, false, tint, t_sec * 9.0, cam_off)
	elif et == "time_node":
		c.draw_texture_rect(_tex("s2_time_node"), Rect2(ex, ey + sin(t_sec * 4.0) * 2.5, ew, eh), false, tint)
	elif et == "mem_shard":
		var ms_y: float = ey + sin(t_sec * 5.0) * 3.5
		c.draw_texture_rect(_tex("s2_mem_shard"), Rect2(ex, ms_y, ew, eh), false, tint)
	elif et == "electric_arc":
		var off_ga: String = str(e.get("offGroup", ""))
		if off_ga == "" or not bool(engine.signal_groups.get(off_ga, false)):
			var arc_c: Color = Color("#00f5ff") if (int(t_sec * 20.0) % 2 == 0) else Color("#ff2ab4")
			arc_c.a = tint.a
			var prev_pt: Vector2 = Vector2(ex, ey + eh * 0.5)
			var ax_i: float = ex + 10.0
			while ax_i <= ex + ew + 0.5:
				var cur_pt: Vector2 = Vector2(minf(ex + ew, ax_i), ey + eh * 0.5 + sin(t_sec * 45.0 + ax_i) * 8.0)
				c.draw_line(prev_pt, cur_pt, arc_c, 2.5)
				prev_pt = cur_pt
				ax_i += 10.0
	elif et == "wind_zone":
		var off_wz: String = str(e.get("offGroup", ""))
		if off_wz != "" and bool(engine.signal_groups.get(off_wz, false)):
			return
		var wvx_d: float = float(e.get("vx", 0.0))
		var wvy_d: float = float(e.get("vy", 0.0))
		var is_side_w: bool = absf(wvx_d) >= absf(wvy_d)
		var w_col: Color = Color(1.0, 0.16, 0.71, 0.52 * tint.a) if is_side_w else Color(0.0, 0.96, 1.0, 0.52 * tint.a)
		c.draw_rect(r, Color(w_col.r, w_col.g, w_col.b, 0.10 * tint.a), true)
		c.draw_rect(r, Color(w_col.r, w_col.g, w_col.b, 0.34 * tint.a), false, 1.2)
		for kw in range(7):
			if is_side_w:
				var dir_w: float = 1.0 if wvx_d >= 0.0 else -1.0
				var px_w: float = ex + fposmod(t_sec * 140.0 * dir_w + float(kw) * 37.0, maxf(16.0, ew))
				var py_w: float = ey + fposmod(float(kw) * 29.0, maxf(12.0, eh - 8.0)) + 4.0
				c.draw_line(Vector2(px_w, py_w), Vector2(clampf(px_w - dir_w * 18.0, ex, ex + ew), py_w), w_col, 1.6)
			else:
				var py_wu: float = ey + eh - fposmod(t_sec * 130.0 + float(kw) * 31.0, maxf(16.0, eh))
				var px_wu: float = ex + fposmod(float(kw) * 27.0 + 12.0, maxf(12.0, ew - 10.0))
				c.draw_line(Vector2(px_wu, py_wu), Vector2(px_wu, minf(ey + eh, py_wu + 16.0)), w_col, 1.6)
	elif et in ["time_bubble", "heat_vent", "cool_pad"]:
		if et == "heat_vent" and str(e.get("offGroup", "")) != "" and bool(engine.signal_groups.get(str(e.get("offGroup", "")), false)):
			return
		var zc: Color = Color(0.38, 0.75, 1.0, 0.18)
		if et == "heat_vent":
			var hp_st: String = str(e.get("heat_phase", "rest"))
			zc = Color(0.98, 0.25, 0.18, 0.36) if hp_st == "erupt" else (Color(0.98, 0.80, 0.08, 0.26) if hp_st == "warn" else Color(0.98, 0.38, 0.18, 0.18))
			if hp_st == "erupt":
				c.draw_rect(Rect2(ex, ey - 3.4 * GridMath.TILE, ew, 3.4 * GridMath.TILE), Color(0.98, 0.32, 0.16, 0.22 * tint.a), true)
		elif et == "time_bubble":
			var tb_r: float = float(e.get("radius_px", ew * 0.5))
			var tb_c: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.5)
			c.draw_circle(tb_c, tb_r, Color(0.0, 0.96, 1.0, 0.10 * tint.a))
			c.draw_arc(tb_c, tb_r, 0.0, TAU, 36, Color(0.40, 0.91, 0.98, 0.62 * tint.a), 2.0)
			return
		c.draw_rect(r, zc, true)
		c.draw_rect(r, Color(zc.r, zc.g, zc.b, 0.52), false, 1.5)
	elif et == "s2_enemy":
		var off_s2e: String = str(e.get("offGroup", ""))
		if off_s2e != "" and bool(engine.signal_groups.get(off_s2e, false)):
			return
		var skind: String = str(e.get("kind", "mech_spider"))
		var smap: Dictionary = {
			"forklift": "s2_forklift", "turret": "s2_turret", "drone": "s2_bot_drone",
			"shield_mech": "s2_shield_mech", "patrol": "s2_bot_patrol"
		}
		var s2k: String = str(smap.get(skind, skind))
		var dx_s2: float = ex + float(e.get("jolt_x", 0.0))
		var s2_flip: bool = false
		if skind == "forklift" or skind == "patrol":
			s2_flip = float(e.get("vx", 0.0)) < 0.0
		elif skind == "turret":
			var t_dir: float = float(e["dir"]) if e.has("dir") else (-1.0 if (not engine.player.is_empty() and float(engine.player.get("x", 0.0)) < ex) else 1.0)
			s2_flip = t_dir < 0.0
			if str(e.get("aim_phase", "")) == "lock":
				var lc: Color = Color(0.96, 0.25, 0.37, 0.80) if (int(t_sec * 18.0) % 2 == 0) else Color(0.98, 0.80, 0.08, 0.65)
				var lx_t: float = (dx_s2 + ew * 0.5) if t_dir > 0.0 else (dx_s2 + ew * 0.5 - 380.0)
				c.draw_rect(Rect2(lx_t, ey + eh * 0.4 - 1.0, 380.0, 2.0), lc, true)
		elif skind == "drone":
			s2_flip = false
		elif skind == "shield_mech":
			s2_flip = int(e.get("facing", -1)) < 0
		else:
			var f_dir_m: int = int(e["facing"]) if e.has("facing") else (-1 if float(e.get("vx", 0.0)) < 0.0 else 1)
			s2_flip = f_dir_m < 0
		var s2_al: float = 0.46 if bool(e.get("is_phasing", false)) else 1.0
		var s2_t: Color = Color(1.8, 1.7, 0.9, tint.a * s2_al) if float(e.get("armor_flash", 0.0)) > 0.0 else Color(tint.r, tint.g, tint.b, tint.a * s2_al)
		_draw_sprite_on(c, _tex(s2k), Rect2(dx_s2, ey, ew, eh), s2_flip, false, s2_t, 0.0, cam_off)
		var mhp_s2: int = int(e.get("max_hp", 0))
		if skind != "forklift" and mhp_s2 > 0:
			var bw_e: float = 54.0 if str(e.get("tier", "")) == "large" else 36.0
			var bh_e: float = 5.0
			var bx_e: float = dx_s2 + (ew - bw_e) * 0.5
			var by_e: float = ey - 10.0
			var rat_e: float = clampf(float(e.get("hp", mhp_s2)) / float(mhp_s2), 0.0, 1.0)
			c.draw_rect(Rect2(bx_e - 1.0, by_e - 1.0, bw_e + 2.0, bh_e + 2.0), Color(0.01, 0.03, 0.09, 0.88 * tint.a), true)
			c.draw_rect(Rect2(bx_e, by_e, bw_e * rat_e, bh_e), Color("#c084fc") if bool(e.get("bullet_immune", false)) else (Color("#f97316") if str(e.get("tier", "")) == "large" else Color("#22d3ee")), true)
	elif et == "s2_boss":
		if bool(e.get("defeated", false)):
			return
		var bkind: String = str(e.get("bossKind", "signal_storm"))
		var bmap: Dictionary = {
			"signal_storm": "s2_boss_signal",
			"reassembly_mech": "s2_boss_mecha",
			"mecha_sovereign": "s2_boss_mecha",
			"fracture_core": "s2_boss_fracture",
			"chrono_skull": "s2_boss_chrono",
			"chrono_regent": "s2_boss_chrono",
			"admin_arena": "s2_boss_null",
			"null_admin": "s2_boss_null"
		}
		var b_ghost: bool = (bkind == "fracture_core" and int(e.get("phase", 1)) == 1 and engine.active_layer != int(e.get("active_core_layer", 0)))
		var b_tint: Color = Color(1.8, 1.8, 1.0, 0.32 if b_ghost else 1.0) if float(e.get("armor_flash", 0.0)) > 0.0 else Color(1.0, 1.0, 1.0, 0.32 if b_ghost else 1.0)
		c.draw_texture_rect(_tex(str(bmap.get(bkind, "s2_boss_null"))), r, false, b_tint)
	elif et == "s3_valve":
		var v_spun: bool = bool(e.get("spun", false))
		var v_rot: float = float(e.get("spin_ang", 0.0)) + (t_sec * 3.2 if v_spun else 0.0)
		var v_tint: Color = Color(tint.r, tint.g, tint.b, tint.a * (0.78 if v_spun else 1.0))
		_draw_sprite_on(c, _tex("s3_valve_red"), r, false, false, v_tint, v_rot, cam_off)
	elif et == "s3_sundial":
		var sd_bob: float = sin(t_sec * 4.0 + ex) * 3.0
		var sd_rot: float = (PI * 0.25) if engine.s3_sundial_phase else 0.0
		_draw_sprite_on(c, _tex("s3_sundial_orb"), Rect2(ex, ey + sd_bob, ew, eh), false, false, tint, sd_rot, cam_off)
	elif et == "s3_catapult":
		var cat_anim: float = float(e.get("anim", 0.0))
		var cat_sy: float = (1.0 + cat_anim * 0.35) if cat_anim > 0.0 else 1.0
		var cat_flip: bool = str(e.get("mode", "")) == "back_fling"
		_draw_sprite_on(c, _tex("s3_catapult_trap"), Rect2(ex, ey - (cat_sy - 1.0) * 14.0, ew, eh * cat_sy), cat_flip, false, tint, 0.0, cam_off)
	elif et == "s3_bomb_trophy":
		var bt_shk: float = sin(t_sec * 55.0) * 4.0 if float(e.get("fuse", -1.0)) >= 0.0 else sin(t_sec * 3.5) * 1.5
		c.draw_texture_rect(_tex("s3_bomb_trophy"), Rect2(ex + bt_shk, ey, ew, eh), false, tint)
	elif et == "s3_suction_pipe":
		var pgrp_sp: String = str(e.get("pipe_group", e.get("pipeGroup", "")))
		var shut_sp: bool = pgrp_sp != "" and bool(engine.s3_valves.get(pgrp_sp, false))
		c.draw_texture_rect(_tex("s3_suction_pipe"), r, false, Color(tint.r, tint.g, tint.b, tint.a * (0.52 if shut_sp else 1.0)))
		if not shut_sp:
			c.draw_rect(Rect2(ex + 6.0, ey + eh, ew - 12.0, 3.8 * GridMath.TILE), Color(0.96, 0.25, 0.37, 0.16 * tint.a), true)
	elif et == "s3_mimic_flag":
		var tm3: bool = bool(e.get("tamed", false))
		var aw3: bool = bool(e.get("awake", false)) or engine.xray_level
		var mf3_k: String = "s3_flag_win" if tm3 else ("s3_mimic_flag" if aw3 else "s3_flag_idle")
		c.draw_texture_rect(_tex(mf3_k), Rect2(ex - 4.0, ey, ew + 10.0, eh), false, tint)
	elif et == "s3_bush":
		var b_out: bool = (bool(e.get("revealed", false)) or engine.xray_level) and str(e.get("mode", "safe")) != "safe"
		if b_out:
			c.draw_texture_rect(_tex("s3_bush_blade"), Rect2(ex, ey - 14.0, ew, eh + 14.0), false, tint)
		else:
			c.draw_texture_rect(_tex("s3_bush_safe"), r, false, tint)
	elif et == "s3_flower":
		var f_ang: bool = bool(e.get("angry", false))
		var f_sway: float = sin(t_sec * 4.5 + ex * 0.05) * 0.06
		_draw_sprite_on(c, _tex("s3_pink_flower_angry" if f_ang else "s3_pink_flower"), r, false, false, tint, f_sway, cam_off)
	elif et == "s3_tanuki":
		var t_hop: float = absf(sin(t_sec * 9.0 + ex * 0.04)) * 3.0
		var t_flip: bool = float(e.get("vx", -60.0)) > 0.0
		_draw_sprite_on(c, _tex("s3_mon_tanuki"), Rect2(ex, ey - t_hop, ew, eh), t_flip, false, tint, 0.0, cam_off)
		if not bool(e.get("is_clone", false)) and bool(e.get("cloned", false)):
			c.draw_rect(Rect2(ex + ew * 0.46, ey - t_hop - 4.0, 5.0, 5.0), Color("#fde047"), true)
	elif et == "s3_manju":
		var mj_hop: float = 0.0 if bool(e.get("waiting_drop", false)) else absf(sin(t_sec * 10.0 + ex * 0.05)) * 3.0
		var spk_m: bool = bool(e.get("spiked", false))
		var mj_flip: bool = float(e.get("vx", -85.0)) > 0.0
		_draw_sprite_on(c, _tex("s3_mon_manju_spike" if spk_m else "s3_mon_manju"), Rect2(ex, ey - mj_hop, ew, eh), mj_flip, false, tint, 0.0, cam_off)
	elif et == "s3_ladybug":
		var lb_bob: float = absf(sin(t_sec * (22.0 if bool(e.get("sprinting", false)) else 8.0))) * 2.0
		var lb_flip: bool = float(e.get("dir", -1.0)) > 0.0
		_draw_sprite_on(c, _tex("s3_mon_ladybug"), Rect2(ex, ey - lb_bob, ew, eh), lb_flip, false, tint, 0.0, cam_off)
	elif et == "s3_mole":
		c.draw_texture_rect(_tex("s3_mon_mole"), r, false, tint)
	elif et == "s3_sun":
		var sun_mad: bool = bool(e.get("swooping", false)) or bool(e.get("awake", false))
		_draw_sprite_on(c, _tex("s3_sun_angry" if sun_mad else "s3_sun_calm"), r, false, false, tint, sin(t_sec * 2.0) * 0.08, cam_off)
	elif et == "s3_boss":
		var b3_map: Dictionary = {
			"cloud_ram": "s3_boss_110",
			"pipe_kaiser": "s3_boss_120",
			"kage_tanuki": "s3_boss_130",
			"blade_archon": "s3_boss_140",
			"solaris_painter": "s3_boss_150"
		}
		var b3k: String = str(b3_map.get(str(e.get("boss_kind", "")), "s3_boss_150"))
		var b3_al: float = 0.68 if float(e.get("stun_timer", 0.0)) > 0.0 else 1.0
		var b3_t: Color = Color(1.8, 1.8, 1.1, tint.a * b3_al) if float(e.get("hit_flash", 0.0)) > 0.0 else Color(tint.r, tint.g, tint.b, tint.a * b3_al)
		c.draw_texture_rect(_tex(b3k), r, false, b3_t)
func _draw_hero_on(c: Control, cam_off: Vector2) -> void:
	if engine.player.is_empty():
		return
	var p: Dictionary = engine.player
	if bool(p.get("dead", false)):
		return
	var px: float = float(p["x"])
	var py: float = float(p["y"])
	var pw: float = float(p["w"])
	var ph: float = float(p["h"])
	var facing: int = int(p.get("facing", 1))
	var grav_d: float = float(p.get("grav_dir", 1.0))
	var t_sec: float = engine.time_elapsed
	var is_melee: bool = float(p.get("melee_anim", 0.0)) > 0.0
	var is_atk: bool = float(p.get("attack_anim", 0.0)) > 0.0
	var spr_key: String = "hero_idle"
	if is_melee:
		spr_key = "hero_melee_slash"
	elif is_atk:
		spr_key = "hero_attack"
	elif not bool(p.get("on_ground", false)):
		spr_key = "hero_jump1" if float(p.get("vy", 0.0)) * grav_d < -40.0 else "hero_jump2"
	elif absf(float(p.get("vx", 0.0))) > 14.0:
		var walk_frames: Array[String] = ["hero_walk1", "hero_run1", "hero_walk2", "hero_run2"]
		var cyc_idx: int = absi(int(floorf(float(p.get("walk_cycle", 0.0))))) % 4
		spr_key = walk_frames[cyc_idx]
	var h_tex: Texture2D = _tex(spr_key)
	var on_gnd: bool = bool(p.get("on_ground", false))
	var vx_abs: float = absf(float(p.get("vx", 0.0)))
	var stride_lift: float = -absf(sin(float(p.get("walk_cycle", 0.0)) * PI)) * 2.5 if (on_gnd and vx_abs > 20.0) else 0.0
	var idle_breath: float = sin(t_sec * 4.2) * 0.025 if (on_gnd and vx_abs <= 20.0) else 0.0
	var sc_x: float = float(p.get("scale_x", 1.0)) * (1.0 - idle_breath * 0.5)
	var sc_y: float = float(p.get("scale_y", 1.0)) * (1.0 + idle_breath)
	var base_w: float = (pw + 42.0) if is_melee else (pw + 22.0)
	var base_h: float = (ph + 10.0) if is_melee else (ph + 8.0)
	var draw_w: float = base_w * sc_x
	var draw_h: float = base_h * sc_y
	var cx: float = px + pw * 0.5 + (6.0 * float(facing) if is_melee else 0.0)
	var by: float = py + ph + stride_lift
	if float(p.get("golden_timer", 0.0)) > 0.0:
		var pulse_r: float = 28.0 + sin(t_sec * 12.0) * 4.0
		c.draw_circle(Vector2(cx, py + ph * 0.5), pulse_r, Color(0.99, 0.88, 0.22, 0.30))
		c.draw_arc(Vector2(cx, py + ph * 0.5), pulse_r + 3.0, 0.0, TAU, 24, Color("#fde047"), 2.0)
	var h_tint: Color = Color.WHITE
	if float(p.get("golden_timer", 0.0)) > 0.0:
		h_tint = Color(1.25, 1.14, 0.58, 1.0)
	elif float(p.get("poison_timer", 0.0)) > 0.0:
		h_tint = Color(0.75, 1.15, 0.65, 1.0)
	elif float(p.get("invuln_timer", 0.0)) > 0.0 and int(t_sec * 20.0) % 2 == 0:
		h_tint.a = 0.55
	if h_tex != null:
		var hero_rect: Rect2 = Rect2(cx - draw_w * 0.5, (by - draw_h) if grav_d >= 0.0 else py, draw_w, draw_h)
		_draw_sprite_on(c, h_tex, hero_rect, facing < 0, grav_d < 0.0, h_tint, float(p.get("tilt_rad", 0.0)), cam_off)
	else:
		c.draw_rect(Rect2(px, py, pw, ph), Color("#00f5ff"), true)
	if bool(p.get("shield", false)):
		var sh_tex: Texture2D = _tex("fx_shield_aegis")
		var sh_sz: float = 62.0 * (1.0 + sin(t_sec * 6.5) * 0.05)
		if sh_tex != null:
			_draw_sprite_on(c, sh_tex, Rect2(cx - sh_sz * 0.5, py + ph * 0.5 - sh_sz * 0.5, sh_sz, sh_sz), false, false, Color(1.0, 1.0, 1.0, 0.82), t_sec * 1.35, cam_off)
		else:
			c.draw_arc(Vector2(cx, py + ph * 0.5), 26.0, 0.0, TAU, 24, Color("#38bdf8"), 2.0)
	if float(p.get("poison_timer", 0.0)) > 0.0:
		c.draw_texture_rect(_tex("icon_poison"), Rect2(cx - 12.0, py - 28.0 + sin(t_sec * 7.0) * 2.0, 24.0, 24.0), false)
	if not engine.carrying_item.is_empty():
		var ck_carry: String = "s2_root_key" if str(engine.carrying_item.get("t", "")) == "root_item" else "s2_battery"
		c.draw_texture_rect(_tex(ck_carry), Rect2(cx - 12.0, py - 28.0, 24.0, 24.0), false)
func _draw_combat_and_fx_on(c: Control, cam_off: Vector2) -> void:
	for b_var in engine.bullets:
		var b: Dictionary = b_var
		var bk: String = "sword_wave" if bool(b.get("s3_wave", false)) else ("bullet_fire" if bool(b.get("upgraded", false)) else "bullet_cyan")
		var b_flip: bool = float(b.get("vx", 1.0)) < 0.0
		_draw_sprite_on(c, _tex(bk), Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"])), b_flip, false, Color.WHITE, 0.0, cam_off)
	for es_var in engine.enemy_shots:
		var es: Dictionary = es_var
		var ew_s: float = float(es.get("w", 12.0))
		var eh_s: float = float(es.get("h", 12.0))
		var es_center: Vector2 = Vector2(float(es["x"]) + ew_s * 0.5, float(es["y"]) + eh_s * 0.5)
		var es_r: float = maxf(ew_s, eh_s) * 0.5
		var raw_ec: Variant = es.get("color", "#fb7185")
		var es_col: Color = (raw_ec as Color) if typeof(raw_ec) == TYPE_COLOR else Color(str(raw_ec))
		c.draw_circle(es_center, es_r, es_col)
		c.draw_circle(es_center, es_r * 0.48, Color.WHITE)
	for bm_var in engine.bombs:
		var bm: Dictionary = bm_var
		_draw_sprite_on(c, _tex("bomb"), Rect2(float(bm["x"]) - 15.0, float(bm["y"]) - 15.0, 30.0, 30.0), false, false, Color.WHITE, engine.time_elapsed * 9.0, cam_off)
	for ma_var in engine.melee_arcs:
		var ma: Dictionary = ma_var
		var mk: String = "fx_melee_crit" if bool(ma.get("crit", false)) else "fx_melee_arc"
		var m_flip: bool = int(ma.get("dir", 1)) < 0
		var mw: float = float(ma.get("w", 74.0))
		var mh: float = float(ma.get("h", 68.0))
		var m_al: float = clampf(float(ma.get("life", 0.1)) / maxf(0.05, float(ma.get("max_life", 0.19))), 0.0, 1.0)
		_draw_sprite_on(c, _tex(mk), Rect2(float(ma["x"]), float(ma["y"]), mw, mh), m_flip, false, Color(1.0, 1.0, 1.0, m_al), 0.0, cam_off)
	for sr_var in engine.shock_rings:
		var sr: Dictionary = sr_var
		var prog: float = 1.0 - clampf(float(sr["life"]) / maxf(0.05, float(sr["max_life"])), 0.0, 1.0)
		var rad: float = lerpf(6.0, float(sr["max_r"]), prog)
		var scol: Color = sr.get("color", Color("#00f5ff"))
		c.draw_arc(Vector2(float(sr["x"]), float(sr["y"])), rad, 0.0, TAU, 24, Color(scol.r, scol.g, scol.b, 1.0 - prog), 2.5)
	for pt_var in engine.particles:
		var pt: Dictionary = pt_var
		var pal: float = clampf(float(pt["life"]) / maxf(0.05, float(pt["max_life"])), 0.0, 1.0)
		var pcol: Color = pt.get("color", Color("#00f5ff"))
		var psz: float = float(pt.get("size", 3.5))
		c.draw_rect(Rect2(float(pt["x"]), float(pt["y"]), psz, psz), Color(pcol.r, pcol.g, pcol.b, pal), true)
	if font_main != null:
		for ft_var in engine.float_texts:
			var ft: Dictionary = ft_var
			var fal: float = clampf(float(ft["life"]) / maxf(0.1, float(ft.get("max_life", 0.72))), 0.0, 1.0)
			var raw_fc: Variant = ft.get("color", Color("#fde047"))
			var fcol: Color = (raw_fc as Color) if typeof(raw_fc) == TYPE_COLOR else Color(str(raw_fc))
			fcol.a = fal
			c.draw_string(font_main, Vector2(float(ft["x"]) - 40.0, float(ft["y"])), str(ft.get("txt", "")), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, fcol)
func _draw_spotlight_mask(c: Control, vw: float, vh: float, center: Vector2, r: float) -> void:
	var dark: Color = Color(0.01, 0.02, 0.06, 0.93)
	c.draw_rect(Rect2(0.0, 0.0, vw, maxf(0.0, center.y - r)), dark, true)
	c.draw_rect(Rect2(0.0, minf(vh, center.y + r), vw, maxf(0.0, vh - (center.y + r))), dark, true)
	c.draw_rect(Rect2(0.0, maxf(0.0, center.y - r), maxf(0.0, center.x - r), r * 2.0), dark, true)
	c.draw_rect(Rect2(minf(vw, center.x + r), maxf(0.0, center.y - r), maxf(0.0, vw - (center.x + r)), r * 2.0), dark, true)
	c.draw_arc(center, r, 0.0, TAU, 32, Color(0.0, 0.96, 1.0, 0.35), 2.0)
func _draw_boss_hud_bar(c: Control, vw: float, boss: Dictionary) -> void:
	var hp: int = maxi(0, int(boss.get("hp", 1)))
	var max_hp: int = maxi(1, int(boss.get("max_hp", hp)))
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var bw: float = 340.0
	var bx: float = (vw - bw) * 0.5
	var by: float = 64.0
	c.draw_rect(Rect2(bx - 3.0, by - 3.0, bw + 6.0, 18.0), Color(0.02, 0.04, 0.14, 0.88), true)
	c.draw_rect(Rect2(bx, by, bw * ratio, 12.0), Color("#fb7185") if engine.lv_id < 101 else Color("#f59e0b"), true)
	c.draw_rect(Rect2(bx - 3.0, by - 3.0, bw + 6.0, 18.0), Color("#fde047"), false, 1.5)
	if font_main != null:
		var b_lbl: String = "BOSS HP  %d / %d" % [hp, max_hp]
		c.draw_string(font_main, Vector2(bx, by + 10.5), b_lbl, HORIZONTAL_ALIGNMENT_CENTER, bw, 11, Color.WHITE)
func _draw_fake_flag_prank(c: Control, vw: float, vh: float) -> void:
	var card_w: float = 460.0
	var card_h: float = 84.0
	var rx: float = (vw - card_w) * 0.5
	var ry: float = (vh - card_h) * 0.42
	var is_p2: bool = (engine.fake_phase >= 2)
	c.draw_rect(Rect2(rx, ry, card_w, card_h), Color(0.18, 0.03, 0.10, 0.94) if is_p2 else Color(0.03, 0.16, 0.12, 0.92), true)
	c.draw_rect(Rect2(rx, ry, card_w, card_h), Color("#fb7185") if is_p2 else Color("#4ade80"), false, 3.0)
	if font_main != null:
		var msg: String = ""
		if save.lang == "en":
			msg = "★ PSYCH! IT'S A BOOBY-TRAPPED FAKE FLAG!" if is_p2 else "★ STAGE CLEARED...?!"
		else:
			msg = "★ 想得美！这是绑了炸药的钓鱼假旗喵！" if is_p2 else "★ 恭喜通关……才怪？！"
		c.draw_string(font_main, Vector2(rx, ry + 50.0), msg, HORIZONTAL_ALIGNMENT_CENTER, card_w, 20, Color("#fde047") if is_p2 else Color("#4ade80"))
func _StartCiSmoke() -> void:
	await get_tree().process_frame
	await _run_ci_smoke_test()
func _run_ci_smoke_test() -> void:
	print("[SMOKE v3.5.3] Loaded textures: ", textures.size(), " | BGM streams: ", audio.bgm_streams.size(), " | SFX streams: ", audio.sfx_streams.size(), " | Stages: ", engine.levels_by_id.size())
	if textures.size() < 345 or audio.bgm_streams.size() < 9 or audio.sfx_streams.size() < 24 or engine.levels_by_id.size() != 150:
		push_error("[SMOKE] Asset or stage count mismatch!")
		get_tree().quit(1)
		return
	save.unlocked_max = 150
	var invis_tested: int = 0
	var qblock_tested: int = 0
	var moving_pits_seen: int = 0
	var fake_errors_closed: int = 0
	for test_lv in range(1, 151):
		_on_start_stage(test_lv)
		if engine.lv_id != test_lv or engine.player.is_empty():
			push_error("[SMOKE] Failed to boot Stage %d!" % test_lv)
			get_tree().quit(1)
			return
		for s_chk_v in engine.solids:
			var s_chk: Dictionary = s_chk_v
			var st_c: String = str(s_chk.get("t", ""))
			if st_c == "qblock" and absf(float(s_chk["w"]) - float(s_chk["h"])) > 0.05:
				push_error("[SMOKE] Non-square qblock in Stage %d!" % test_lv)
				get_tree().quit(1)
				return
			if st_c == "moving_pit":
				moving_pits_seen += 1
		for step_i in range(12):
			if bool(engine.player.get("dead", false)):
				engine.reset_attempt()
			var sim_inp: Dictionary = {
				"left": step_i >= 8,
				"right": step_i < 8,
				"down": false,
				"down_pressed": false,
				"jump_pressed": step_i == 0 or step_i == 6,
				"jump_released": step_i == 4,
				"jump_held": step_i < 4 or (step_i >= 6 and step_i < 9),
				"jump_buffer": step_i == 0,
				"shoot_pressed": step_i == 2,
				"slash_pressed": step_i == 5,
				"bomb_pressed": false,
				"layer_pressed": step_i == 7 and engine.is_dual_layer_active(),
				"gold_pressed": false
			}
			engine.step_frame(0.016, sim_inp)
			_drain_engine_queues()
			ui.step_ui(0.016)
		engine.reset_attempt()
		for s_iv in engine.solids:
			var s_i: Dictionary = s_iv
			if str(s_i.get("t", "")) == "invis" and bool(s_i.get("step_reveal", false)) and not bool(s_i.get("revealed", false)):
				engine.player["x"] = float(s_i["x"]) + 4.0
				engine.player["y"] = float(s_i["y"]) - float(engine.player["h"]) - 2.0
				engine.player["vy"] = 120.0
				for _k in range(4):
					engine.step_frame(0.016, {})
				if bool(s_i.get("revealed", false)):
					invis_tested += 1
				break
		engine.reset_attempt()
		for s_qv in engine.solids:
			var s_q: Dictionary = s_qv
			if str(s_q.get("t", "")) == "qblock" and not bool(s_q.get("used", false)):
				engine.player["x"] = float(s_q["x"]) + 4.0
				engine.player["y"] = float(s_q["y"]) + float(s_q["h"]) + 2.0
				engine.player["vy"] = -360.0
				for _k in range(4):
					engine.step_frame(0.016, {})
				if bool(s_q.get("used", false)):
					qblock_tested += 1
				break
		engine.reset_attempt()
		for s_fev in engine.solids:
			var s_fe: Dictionary = s_fev
			if str(s_fe.get("t", "")) == "fake_error" and str(s_fe.get("mode", "close_x")) == "close_x" and not bool(s_fe.get("broken", false)):
				engine.active_layer = maxi(0, int(s_fe.get("layer", 0)))
				engine.bullets.append({ "x": float(s_fe["x"]) + 8.0, "y": float(s_fe["y"]) + 6.0, "w": 14.0, "h": 10.0, "vx": 420.0, "vy": 0.0, "life": 1.0, "upgraded": false, "s3_wave": false, "bounces": 0 })
				for _k in range(3):
					engine.step_frame(0.016, {})
				if bool(s_fe.get("broken", false)):
					fake_errors_closed += 1
				break
	_on_start_stage(5)
	var found_msl_r: bool = false
	for _f5 in range(40):
		engine.step_frame(0.016, {})
		for em5_v in engine.entities:
			var em5: Dictionary = em5_v
			if str(em5.get("t", "")) == "missile":
				found_msl_r = true
				if _is_missile_flipped(em5) or float(em5.get("dir", 0.0)) <= 0.0:
					push_error("[SMOKE] Stage 5 right-flying missile rendered backwards!")
					get_tree().quit(1)
					return
				break
		if found_msl_r:
			break
	if not found_msl_r:
		push_error("[SMOKE] Stage 5 launcher did not spawn missile!")
		get_tree().quit(1)
		return
	_on_start_stage(36)
	var found_msl_l: bool = false
	for _f36 in range(40):
		engine.step_frame(0.016, {})
		for em36_v in engine.entities:
			var em36: Dictionary = em36_v
			if str(em36.get("t", "")) == "missile":
				found_msl_l = true
				if (not _is_missile_flipped(em36)) or float(em36.get("dir", 0.0)) >= 0.0:
					push_error("[SMOKE] Stage 36 left-flying missile rendered backwards!")
					get_tree().quit(1)
					return
				break
		if found_msl_l:
			break
	if not found_msl_l:
		push_error("[SMOKE] Stage 36 launcher did not spawn missile!")
		get_tree().quit(1)
		return
	_on_start_stage(14)
	ui.is_mobile_platform = true
	save.pad_mode = "auto"
	ui.sync_safe_area_and_layout()
	ui._ensure_pad_geometry()
	var jump_btn_center: Vector2 = Vector2(880.0, 460.0)
	for jb_v in ui.pad_buttons:
		var jb_d: Dictionary = jb_v
		if str(jb_d.get("action", "")) == "jump":
			jump_btn_center = (jb_d["rect"] as Rect2).get_center()
			break
	engine.player["x"] = GridMath.gx_to_px(4.8)
	for _f14_prep in range(18):
		engine.step_frame(0.016, { "right": true })
	if int(engine.player.get("max_jumps", 1)) != 2:
		push_error("[SMOKE] Stage 14 failed to pick up double_jump powerup!")
		get_tree().quit(1)
		return
	engine.player["x"] = GridMath.gx_to_px(9.15)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	engine.player["vx"] = 240.0
	engine.player["vy"] = 0.0
	engine.player["on_ground"] = true
	var tp1_down: InputEventScreenTouch = InputEventScreenTouch.new()
	tp1_down.index = 1
	tp1_down.pressed = true
	tp1_down.position = jump_btn_center
	ui.handle_priority_input(tp1_down)
	var inp14_f0: Dictionary = _gather_gameplay_input(0.016)
	inp14_f0["right"] = true
	engine.step_frame(0.016, inp14_f0)
	if int(engine.player.get("jumps_left", 0)) != 1:
		push_error("[SMOKE] Stage 14 ground jump burned double-jump charge! jumps_left=%d" % int(engine.player.get("jumps_left", -1)))
		get_tree().quit(1)
		return
	for f14 in range(1, 19):
		if f14 == 2:
			var tp1_up: InputEventScreenTouch = InputEventScreenTouch.new()
			tp1_up.index = 1
			tp1_up.pressed = false
			tp1_up.position = jump_btn_center
			ui.handle_priority_input(tp1_up)
		var step_i14: Dictionary = _gather_gameplay_input(0.016)
		step_i14["right"] = true
		engine.step_frame(0.016, step_i14)
	if int(engine.player.get("jumps_left", 0)) != 1:
		push_error("[SMOKE] Stage 14 lost double-jump charge while gliding! jumps_left=%d" % int(engine.player.get("jumps_left", -1)))
		get_tree().quit(1)
		return
	var tp2_down: InputEventScreenTouch = InputEventScreenTouch.new()
	tp2_down.index = 1
	tp2_down.pressed = true
	tp2_down.position = jump_btn_center
	ui.handle_priority_input(tp2_down)
	var inp14_air: Dictionary = _gather_gameplay_input(0.016)
	inp14_air["right"] = true
	engine.step_frame(0.016, inp14_air)
	if int(engine.player.get("jumps_left", -1)) != 0 or float(engine.player.get("vy", 0.0)) > -520.0:
		push_error("[SMOKE] Stage 14 midair double-jump failed to fire! jumps_left=%d vy=%f" % [int(engine.player.get("jumps_left", -1)), float(engine.player.get("vy", 0.0))])
		get_tree().quit(1)
		return
	var tp2_up: InputEventScreenTouch = InputEventScreenTouch.new()
	tp2_up.index = 1
	tp2_up.pressed = false
	tp2_up.position = jump_btn_center
	ui.handle_priority_input(tp2_up)
	var landed_14: bool = false
	for _f14_land in range(75):
		var st_l14: Dictionary = _gather_gameplay_input(0.016)
		st_l14["right"] = true
		engine.step_frame(0.016, st_l14)
		if bool(engine.player.get("dead", false)):
			push_error("[SMOKE] Stage 14 died during double-jump chasm crossing!")
			get_tree().quit(1)
			return
		if bool(engine.player.get("on_ground", false)) and float(engine.player["x"]) >= GridMath.gx_to_px(13.9):
			landed_14 = true
			break
	if not landed_14:
		push_error("[SMOKE] Stage 14 did not reach island x>=13.9! final gx=%f" % GridMath.px_to_gx(float(engine.player["x"])))
		get_tree().quit(1)
		return
	ui.clear_touch_inputs()
	_on_start_stage(15)
	engine.player["x"] = GridMath.gx_to_px(18.5)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	engine.player["vy"] = 20.0
	engine.step_frame(0.016, { "jump_released": true })
	var min_feet_py15: float = 9999.0
	for f15 in range(45):
		engine.step_frame(0.016, { "jump_released": f15 == 0 })
		var feet_py: float = float(engine.player["y"]) + float(engine.player["h"])
		if feet_py < min_feet_py15:
			min_feet_py15 = feet_py
	if min_feet_py15 > 108.0:
		push_error("[SMOKE] Stage 15 spring bounce too low! min_feet_py=%f (need <=108.0)" % min_feet_py15)
		get_tree().quit(1)
		return
	_on_start_stage(101)
	engine.player["x"] = GridMath.gx_to_px(82.6)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	var min_feet_101: float = 9999.0
	for f101 in range(45):
		engine.step_frame(0.016, { "jump_released": f101 == 1 })
		min_feet_101 = minf(min_feet_101, float(engine.player["y"]) + float(engine.player["h"]))
	if min_feet_101 > GridMath.gy_to_py(6.55, 0.0):
		push_error("[SMOKE] Stage 101 back_fling catapult too low for gy=6.4 terrace! min_feet=%f" % min_feet_101)
		get_tree().quit(1)
		return
	_on_start_stage(128)
	engine.player["x"] = GridMath.gx_to_px(82.6)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	var min_feet_128: float = 9999.0
	for f128 in range(50):
		engine.step_frame(0.016, { "jump_released": f128 == 1 })
		min_feet_128 = minf(min_feet_128, float(engine.player["y"]) + float(engine.player["h"]))
	if min_feet_128 > GridMath.gy_to_py(8.4, 0.0):
		push_error("[SMOKE] Stage 128 high_secret catapult too low for gy=8.2 shrine! min_feet=%f" % min_feet_128)
		get_tree().quit(1)
		return
	_on_start_stage(135)
	engine.player["x"] = GridMath.gx_to_px(87.6)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	var landed_135: bool = false
	for f135 in range(95):
		engine.step_frame(0.016, { "right": true, "jump_released": f135 == 1 })
		if bool(engine.player.get("on_ground", false)) and float(engine.player["x"]) >= GridMath.gx_to_px(94.5) and float(engine.player["y"]) + float(engine.player["h"]) <= GridMath.gy_to_py(5.5, 0.0):
			landed_135 = true
			break
	if not landed_135:
		push_error("[SMOKE] Stage 135 forward_vault failed to land on gy=5.6 terrace!")
		get_tree().quit(1)
		return
	_on_start_stage(137)
	engine.player["x"] = GridMath.gx_to_px(85.6)
	engine.player["y"] = GridMath.gy_to_py(2.0, 0.0) - float(engine.player["h"])
	var landed_137: bool = false
	for f137 in range(95):
		engine.step_frame(0.016, { "right": true, "jump_released": f137 == 1 })
		if bool(engine.player.get("on_ground", false)) and float(engine.player["x"]) >= GridMath.gx_to_px(93.5):
			landed_137 = true
			break
	if not landed_137:
		push_error("[SMOKE] Stage 137 forward_vault failed to clear headwind chasm!")
		get_tree().quit(1)
		return
	_on_start_stage(12)
	for e_pv in engine.entities:
		var e_p: Dictionary = e_pv
		if str(e_p.get("t", "")) == "pipe" and absf(float(e_p["x"]) - GridMath.gx_to_px(6.0)) < 12.0:
			engine.player["x"] = float(e_p["x"]) + 8.0
			engine.player["y"] = float(e_p["y"]) - float(engine.player["h"]) + 10.0
			for f_p in range(12):
				engine.step_frame(0.016, { "down": true, "down_pressed": f_p == 0 })
			if absf(float(engine.player["x"]) - GridMath.gx_to_px(12.0)) > 48.0:
				push_error("[SMOKE] Stage 12 bidirectional pipe ping-ponged!")
				get_tree().quit(1)
				return
			break
	for s_cl in range(1, 51):
		save.cleared[str(s_cl)] = true
	save.coins = 5000
	save.shop_owned = { "golden_body": true }
	save.shop_equipped = { "golden_body": true }
	_on_start_stage(6)
	engine.kill_player(true, "abyss")
	if not bool(engine.player.get("dead", false)):
		push_error("[SMOKE] Pit did not kill before Golden Body!")
		get_tree().quit(1)
		return
	_on_retry_stage()
	if int(engine.player.get("gold_charges", 0)) != 1:
		push_error("[SMOKE] Unused Golden Body charge was lost after pit death!")
		get_tree().quit(1)
		return
	engine.kill_player(true, "flower")
	if bool(engine.player.get("dead", false)) or float(engine.player.get("golden_timer", 0.0)) < 9.0:
		push_error("[SMOKE] Golden Body failed to auto-guard against flower!")
		get_tree().quit(1)
		return
	engine.kill_player(true, "abyss")
	if not bool(engine.player.get("dead", false)):
		push_error("[SMOKE] Active Golden Body did NOT die in pit!")
		get_tree().quit(1)
		return
	_on_retry_stage()
	if int(engine.player.get("gold_charges", 0)) != 0 or float(engine.player.get("golden_timer", 0.0)) > 0.0:
		push_error("[SMOKE] Golden Body refilled on retry within same stage!")
		get_tree().quit(1)
		return
	ui.is_mobile_platform = true
	save.pad_mode = "auto"
	ui.sync_safe_area_and_layout()
	ui._on_hud_gear_pressed()
	if ui.active_modal != "options":
		push_error("[SMOKE] Settings modal failed to open!")
		get_tree().quit(1)
		return
	ui.open_options_modal("shop")
	await get_tree().process_frame
	ui.step_ui(0.016)
	var m_down: InputEventMouseButton = InputEventMouseButton.new()
	m_down.button_index = MOUSE_BUTTON_LEFT
	m_down.pressed = true
	m_down.position = Vector2(480.0, 360.0)
	ui.handle_priority_input(m_down)
	var m_drag: InputEventMouseMotion = InputEventMouseMotion.new()
	m_drag.position = Vector2(480.0, 210.0)
	m_drag.relative = Vector2(0.0, -150.0)
	var drag_consumed: bool = ui.handle_priority_input(m_drag)
	var m_up: InputEventMouseButton = InputEventMouseButton.new()
	m_up.button_index = MOUSE_BUTTON_LEFT
	m_up.pressed = false
	m_up.position = Vector2(480.0, 210.0)
	var up_consumed: bool = ui.handle_priority_input(m_up)
	if not drag_consumed or up_consumed or m_up.position.x > -9000.0 or ui.opt_scroll_y < 80.0:
		push_error("[SMOKE] SmoothScrollBox scroll or clean mouse_focus release failed!")
		get_tree().quit(1)
		return
	ui.close_all_modals(true)
	var t_press: InputEventScreenTouch = InputEventScreenTouch.new()
	t_press.index = 0
	t_press.pressed = true
	t_press.position = Vector2(80.0, 470.0)
	ui.handle_unhandled_gameplay_input(t_press)
	var t_drag: InputEventScreenDrag = InputEventScreenDrag.new()
	t_drag.index = 0
	t_drag.position = Vector2(82.0, 496.0)
	t_drag.relative = Vector2(2.0, 26.0)
	ui.handle_unhandled_gameplay_input(t_drag)
	var edges: Dictionary = ui.consume_touch_edges()
	if not bool(edges["down"]) or not bool(edges["down_pressed"]):
		push_error("[SMOKE] Swipe-down failed to trigger down_pressed!")
		get_tree().quit(1)
		return
	save.reset_progress_keep_prefs()
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	print("[SMOKE v3.5.3] ALL 150 STAGES VERIFIED 100% OK! invis=", invis_tested, " qblocks=", qblock_tested, " moving_pits=", moving_pits_seen, " fake_errors=", fake_errors_closed)
	get_tree().quit(0)
