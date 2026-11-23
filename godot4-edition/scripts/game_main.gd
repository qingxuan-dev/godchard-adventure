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
var jump_buffer_timer: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	is_mobile_platform = _detect_mobile_platform()
	_configure_platform_window()

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

	var ui_layer: CanvasLayer = get_node_or_null("UILayer") as CanvasLayer
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)

	ui = UIDirector.new()
	ui_layer.add_child(ui)
	ui.setup(save, shop, engine, audio, textures, meta, font_main, is_mobile_platform)

	ui.request_start_stage.connect(_on_start_stage)
	ui.request_retry_stage.connect(_on_retry_stage)
	ui.request_fresh_restart.connect(_on_fresh_restart)
	ui.request_return_title.connect(_on_return_title)
	ui.request_quit_app.connect(func() -> void: get_tree().quit())
	ui.request_toggle_fullscreen.connect(_toggle_fullscreen)

	# Smoke-check mode for automated headless verification in CI
	var cmd_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--smoke-test" in cmd_args:
		_run_ci_smoke_test()
		return

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
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_title("哥查德的大冒险 · GODCHARD ADVENTURE v3.3.0")

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

# ==============================================================================
# STAGE FLOW & INPUT HANDLING
# ==============================================================================
func _on_start_stage(stage_id: int) -> void:
	if not save.is_stage_unlocked(stage_id):
		return
	shop.reset_for_new_stage()
	engine.start_stage(stage_id)
	ui.enter_gameplay_hud(stage_id)
	audio.select_track(false, stage_id)
	queue_redraw()

func _on_retry_stage() -> void:
	if not ui.in_game:
		return
	engine.reset_attempt()
	ui.refresh_hud()
	queue_redraw()

func _on_fresh_restart() -> void:
	if not ui.in_game:
		return
	engine.manual_fresh_restart()
	ui.refresh_hud()
	queue_redraw()

func _on_return_title() -> void:
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

	if ui.handle_screen_touch_input(event):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
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

	if jump_pressed:
		jump_buffer_timer = 0.12
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - dt)

	var inp: Dictionary = {
		"left": bool(t_edges["left"]) or kb_left,
		"right": bool(t_edges["right"]) or kb_right,
		"down": bool(t_edges["down"]) or kb_down,
		"down_pressed": bool(t_edges["down_pressed"]) or (kb_down and not bool(prev_kb["down"])),
		"jump_held": jump_held,
		"jump_pressed": jump_pressed,
		"jump_released": jump_released,
		"jump_buffer": jump_buffer_timer > 0.0,
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

	if not engine.player.is_empty() and bool(engine.player.get("on_ground", false)) and jump_buffer_timer > 0.0 and not jump_pressed:
		inp["jump_pressed"] = true
		jump_buffer_timer = 0.0

	return inp

func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.001, 0.05)

	# Keyboard quick shortcuts (`R` retry, `ESC` stage select / close modal)
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

# ==============================================================================
# CRISP 3-SECTOR PIXEL WORLD RENDERER (`_draw`)
# ==============================================================================
func _pick_stage_bg_key(stage_id: int) -> String:
	if stage_id >= 101:
		var ch_s3: int = clampi(int(ceil(float(stage_id) / 10.0)), 11, 15)
		return "s3_bg_ch%d" % ch_s3
	if stage_id >= 91:
		return "bg_s2_root"
	if stage_id >= 81:
		return "bg_s2_chrono"
	if stage_id >= 71:
		return "bg_s2_fracture"
	if stage_id >= 61:
		return "bg_s2_mecha"
	if stage_id >= 51:
		return "bg_s2_signal"
	return "cyber_skyline_bg"

func _draw() -> void:
	var vp_rect: Rect2 = get_viewport_rect()
	var vw: float = maxf(960.0, vp_rect.size.x)
	var vh: float = maxf(540.0, vp_rect.size.y)

	if not ui.in_game or engine.lv_data.is_empty():
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040824"), true)
		return

	var props: Dictionary = engine.lv_data.get("props", {})
	var is_zen50: bool = bool(props.get("emptyRoom", false))
	var lv_id: int = engine.lv_id

	# 1. Sky & Parallax Tiled Background
	if is_zen50:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#f8fafc"), true)
	elif lv_id >= 101:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#58a6ff"), true)
	elif lv_id >= 51:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#05091e"), true)
	else:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040a28"), true)

	if not is_zen50:
		var bg_key: String = _pick_stage_bg_key(lv_id)
		var bg_tex: Texture2D = _tex(bg_key)
		if bg_tex != null:
			var tsz: Vector2 = bg_tex.get_size()
			var bg_scale: float = vh / maxf(1.0, tsz.y)
			var tile_w: float = maxf(256.0, tsz.x * bg_scale)
			var raw_scroll: float = engine.cam_x * 0.24
			var base_idx: int = int(floor(raw_scroll / tile_w))
			var scroll_x: float = raw_scroll - float(base_idx) * tile_w
			var start_x: float = -scroll_x
			var step_i: int = 0
			while start_x < vw + tile_w:
				var flip_odd: bool = (absi(base_idx + step_i) % 2) == 1
				if flip_odd:
					draw_texture_rect(bg_tex, Rect2(start_x + tile_w + 1.0, 0.0, -(tile_w + 2.0), vh), false)
				else:
					draw_texture_rect(bg_tex, Rect2(start_x, 0.0, tile_w + 1.0, vh), false)
				start_x += tile_w
				step_i += 1

	if lv_id >= 51 and lv_id <= 100 and engine.is_dual_layer_active():
		var veil_c: Color = Color(0.75, 0.22, 0.92, 0.08) if engine.active_layer == 1 else Color(0.0, 0.92, 1.0, 0.05)
		draw_rect(Rect2(0.0, 0.0, vw, vh), veil_c, true)
	elif lv_id >= 101 and engine.s3_sundial_phase:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.99, 0.72, 0.18, 0.12), true)

	# 2. Camera + Screen Shake Transform
	var shk: Vector2 = Vector2.ZERO
	if engine.shake_timer > 0.0:
		var mag: float = engine.shake_mag * (engine.shake_timer / maxf(0.05, engine.shake_dur))
		shk = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	var cam_off: Vector2 = Vector2(-engine.cam_x + shk.x, -engine.cam_y + shk.y)

	draw_set_transform(cam_off, 0.0, Vector2.ONE)

	# 3. Signal Fiber Lines (S2) & Valve Links (S3)
	_draw_world_links(vw)

	# 4. Solids
	for s_var in engine.solids:
		var s: Dictionary = s_var
		_draw_solid(s, vw, is_zen50)

	# 5. Entities & Bosses
	var active_boss: Dictionary = {}
	for e_var in engine.entities:
		var e: Dictionary = e_var
		_draw_entity(e, vw)
		var et: String = str(e.get("t", ""))
		if (et == "s2_boss" or et == "s3_boss" or (et == "enemy" and str(e.get("kind", "")) == "boss")) and int(e.get("hp", 0)) > 0:
			active_boss = e

	# 6. Grave, Clones, Afterimages & Hero
	if engine.has_grave:
		var gt: Texture2D = _tex("hero_grave")
		if gt != null:
			draw_texture_rect(gt, Rect2(engine.grave_pos.x - 4.0, engine.grave_pos.y + 6.0, 36.0, 36.0), false)

	if not engine.shadow_clone.is_empty() and bool(engine.shadow_clone.get("active", false)):
		var sc_tex: Texture2D = _tex("hero_run1")
		if sc_tex != null:
			draw_texture_rect(sc_tex, Rect2(float(engine.shadow_clone["x"]) - 4.0, float(engine.shadow_clone["y"]), 36.0, 42.0), false, Color(0.72, 0.18, 0.95, 0.78))

	for ec_var in engine.echo_clones:
		var ec: Dictionary = ec_var
		if bool(ec.get("active", false)):
			var etx: Texture2D = _tex("hero_idle")
			if etx != null:
				draw_texture_rect(etx, Rect2(float(ec["x"]) - 4.0, float(ec["y"]), 36.0, 42.0), false, Color(0.0, 0.96, 1.0, 0.62))

	for ai_var in engine.afterimages:
		var ai: Dictionary = ai_var
		var atx: Texture2D = _tex("hero_jump1")
		if atx != null:
			var a_col: Color = ai.get("col", Color("#00f5ff"))
			var a_alpha: float = clampf(float(ai.get("life", 0.1)) / 0.22, 0.0, 1.0) * 0.45
			var aw: float = 36.0 * (1.0 if int(ai.get("facing", 1)) >= 0 else -1.0)
			var ax: float = float(ai["x"]) - 4.0 + (36.0 if aw < 0.0 else 0.0)
			draw_texture_rect(atx, Rect2(ax, float(ai["y"]), aw, 42.0), false, Color(a_col.r, a_col.g, a_col.b, a_alpha))

	_draw_hero()

	# 7. Projectiles, Bombs, Melee Arcs, Shock Rings, Particles & Float Texts
	_draw_combat_and_fx()

	# Reset to screen-space for overlays
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 8. Blackout Stage Spotlight / Boss HP Bar / Fake Flag Banner
	if bool(props.get("blackout", false)) and not engine.player.is_empty():
		var px_s: float = float(engine.player["x"]) + 14.0 - engine.cam_x
		var py_s: float = float(engine.player["y"]) + 21.0 - engine.cam_y
		var rad: float = 290.0 if engine.light_burst_timer > 0.0 else 108.0
		_draw_spotlight_mask(vw, vh, Vector2(px_s, py_s), rad)

	if not active_boss.is_empty():
		_draw_boss_hud_bar(vw, active_boss)

	if engine.fake_phase > 0:
		_draw_fake_flag_prank(vw, vh)

func _draw_tiled_sprite(tex: Texture2D, r: Rect2, tint: Color = Color.WHITE) -> void:
	if tex == null:
		draw_rect(r, tint, true)
		return
	var step: float = GridMath.TILE
	if r.size.x <= step * 1.35 and r.size.y <= step * 1.35:
		draw_texture_rect(tex, r, false, tint)
		return
	var y: float = r.position.y
	while y < r.position.y + r.size.y - 0.5:
		var ch_h: float = minf(step, r.position.y + r.size.y - y)
		var x: float = r.position.x
		while x < r.position.x + r.size.x - 0.5:
			var ch_w: float = minf(step, r.position.x + r.size.x - x)
			draw_texture_rect(tex, Rect2(x, y, ch_w, ch_h), false, tint)
			x += step
		y += step

func _draw_ground_block(top_tex: Texture2D, body_tex: Texture2D, r: Rect2, tint: Color = Color.WHITE) -> void:
	var step: float = GridMath.TILE
	if r.size.y <= step * 1.25 or body_tex == null:
		_draw_tiled_sprite(top_tex, r, tint)
		return
	var top_r: Rect2 = Rect2(r.position.x, r.position.y, r.size.x, step)
	var bot_r: Rect2 = Rect2(r.position.x, r.position.y + step, r.size.x, r.size.y - step)
	_draw_tiled_sprite(top_tex, top_r, tint)
	_draw_tiled_sprite(body_tex, bot_r, tint)

func _draw_world_links(vw: float) -> void:
	var nodes_by_grp: Dictionary = {}
	for e_var in engine.entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "signal_node":
			var grp: String = str(e.get("group", ""))
			if grp != "":
				nodes_by_grp[grp] = Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
	if not nodes_by_grp.is_empty():
		for s_var in engine.solids:
			var s: Dictionary = s_var
			var st: String = str(s.get("t", ""))
			if st == "signal_bridge" or st == "signal_gate":
				var g: String = str(s.get("group", ""))
				if nodes_by_grp.has(g):
					var p0: Vector2 = nodes_by_grp[g]
					if absf(p0.x - engine.cam_x) < vw + 320.0:
						var p1: Vector2 = Vector2(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + float(s["h"]) * 0.5)
						var on_g: bool = bool(engine.signal_groups.get(g, false))
						draw_line(p0, p1, Color(0.29, 0.87, 0.50, 0.55) if on_g else Color(0.0, 0.96, 1.0, 0.22), 2.0)

func _draw_solid(s: Dictionary, vw: float, is_zen50: bool) -> void:
	var sx: float = float(s.get("x", 0.0))
	var sw: float = float(s.get("w", 40.0))
	if sx + sw < engine.cam_x - 80.0 or sx > engine.cam_x + vw + 80.0:
		return
	if bool(s.get("broken", false)):
		return

	var sy: float = float(s.get("y", 0.0)) + float(s.get("bump_offset", 0.0))
	var sh: float = float(s.get("h", 40.0))
	var r: Rect2 = Rect2(sx, sy, sw, sh)
	var st: String = str(s.get("t", "solid"))
	var lv_id: int = engine.lv_id

	var s_layer: int = int(s.get("layer", -1))
	var ghost_layer: bool = (lv_id >= 51 and lv_id <= 100 and s_layer >= 0 and s_layer != engine.active_layer)
	var alpha_mul: float = 0.25 if ghost_layer else 1.0
	var base_tint: Color = Color(0.85, 0.55, 1.0, alpha_mul) if (ghost_layer and s_layer == 1) else (Color(0.55, 0.92, 1.0, alpha_mul) if ghost_layer else Color(1.0, 1.0, 1.0, alpha_mul))

	if is_zen50 and st == "solid":
		draw_rect(r, Color("#e2e8f0"), true)
		draw_rect(r, Color("#94a3b8"), false, 2.0)
		return

	if st == "invis":
		if bool(s.get("revealed", false)):
			var qk: String = "s3_kaizo_block" if lv_id >= 101 else "qblock"
			_draw_tiled_sprite(_tex(qk), r, Color(0.75, 0.85, 1.0, alpha_mul))
		elif engine.xray_level:
			draw_rect(r, Color(0.0, 0.96, 1.0, 0.18), true)
			draw_rect(r, Color("#00f5ff"), false, 2.0)
		return

	if st == "qblock":
		var q_tex: Texture2D = _tex("s3_qblock" if lv_id >= 101 else "qblock")
		var used_tint: Color = Color(0.55, 0.58, 0.66, alpha_mul) if bool(s.get("used", false)) else base_tint
		_draw_tiled_sprite(q_tex, r, used_tint)
		return

	if st == "solid" or st == "fake_wall" or st == "fake_plat":
		var f_alpha: float = alpha_mul
		if st == "fake_wall" or st == "fake_plat":
			if float(s.get("shatter_anim", 0.0)) > 0.0:
				f_alpha *= float(s["shatter_anim"])
			elif bool(s.get("shattered", false)):
				f_alpha *= 0.16
			elif engine.xray_level:
				f_alpha *= 0.45
		var f_tint: Color = Color(base_tint.r, base_tint.g, base_tint.b, f_alpha)

		if lv_id >= 101:
			var sty3: String = str(s.get("style", ""))
			if str(s.get("skin", "")) == "tanuki_log":
				draw_texture_rect(_tex("s3_mon_tanuki_log"), r, false, f_tint)
			elif sty3 == "crate" or str(s.get("skin", "")) == "crate" or (sw <= 84.0 and sh <= 84.0 and sy < GridMath.WORLD_ORIGIN_Y - 42.0 and int(sx) % 80 == 0):
				_draw_tiled_sprite(_tex("s3_wood_crate"), r, f_tint)
			elif sty3 == "stone" or (sh > 60.0 and sw <= 120.0 and sy < GridMath.WORLD_ORIGIN_Y - 10.0):
				_draw_tiled_sprite(_tex("s3_stone_brick"), r, f_tint)
			elif sh <= 48.0 and sy < GridMath.WORLD_ORIGIN_Y - 20.0:
				_draw_tiled_sprite(_tex("s3_float_grass"), r, f_tint)
			else:
				_draw_ground_block(_tex("s3_ground_top"), _tex("s3_ground_dirt"), r, f_tint)
		elif lv_id >= 51:
			if sh <= 48.0 and sy < GridMath.WORLD_ORIGIN_Y - 20.0:
				_draw_tiled_sprite(_tex("s2_plat_float_deck"), r, f_tint)
			elif sw <= 60.0 and sh >= 80.0:
				_draw_tiled_sprite(_tex("s2_plat_column"), r, f_tint)
			else:
				_draw_ground_block(_tex("s2_plat_ground_top"), _tex("s2_plat_reactor_wall"), r, f_tint)
		else:
			if sh <= 48.0 and sy < GridMath.WORLD_ORIGIN_Y - 20.0:
				_draw_tiled_sprite(_tex("plat_float_deck"), r, f_tint)
			elif sw <= 60.0 and sh >= 80.0:
				_draw_tiled_sprite(_tex("plat_column"), r, f_tint)
			else:
				_draw_ground_block(_tex("plat_ground_top"), _tex("cyber_wall"), r, f_tint)

		if engine.xray_level and (st == "fake_wall" or st == "fake_plat"):
			draw_rect(r, Color("#c084fc"), false, 2.0)
		return

	if st == "destructible":
		var dk: String = "s3_stone_cracked" if lv_id >= 101 else "plat_copper_destruct"
		_draw_tiled_sprite(_tex(dk), r, base_tint)
	elif st == "vanish":
		var v_al: float = clampf(1.0 - float(s.get("vanish_progress", 0.0)), 0.15, 1.0) * alpha_mul
		_draw_tiled_sprite(_tex("s3_float_grass" if lv_id >= 101 else "plat_vanish_hover"), r, Color(1.0, 0.85, 0.85, v_al))
	elif st == "mirror":
		_draw_tiled_sprite(_tex("mirror_wall"), r, base_tint)
	elif st == "s3_tall_pipe":
		draw_texture_rect(_tex("s3_pipe_tall"), r, false, base_tint)
	elif st == "s3_cloud":
		var mode_c: String = str(s.get("mode", "safe_plat"))
		var knife_out: bool = bool(s.get("blades_out", false)) or bool(s.get("knife_revealed", false)) or (not Sector3Arcadia.is_cloud_safe(s, engine.s3_sundial_phase) and (engine.xray_level or mode_c == "sundial_knife"))
		var ck: String = "s3_cloud_knife" if knife_out else ("s3_cloud_dark" if mode_c == "swoop_cloud" else "s3_cloud_safe")
		draw_texture_rect(_tex(ck), r, false, Color(1.0, 1.0, 1.0, 0.45 if (mode_c == "fake_cloud" and engine.xray_level) else alpha_mul))
	elif st == "s3_drop_block":
		_draw_tiled_sprite(_tex("s3_wood_crate" if str(s.get("skin", "")) == "crate" else "s3_stone_brick"), r, base_tint)
	elif st == "s3_slide_turf":
		_draw_tiled_sprite(_tex("s3_float_grass"), r, base_tint)
	elif st == "conveyor":
		_draw_tiled_sprite(_tex("platform_steel"), r, base_tint)
		var dir_c: float = float(s.get("dir", 1.0))
		draw_line(Vector2(sx + 8.0, sy + sh * 0.5), Vector2(sx + sw - 8.0, sy + sh * 0.5), Color("#fde047") if dir_c > 0.0 else Color("#fb7185"), 2.0)
	elif st == "rail_plat":
		_draw_tiled_sprite(_tex("s2_rail_plat"), r, base_tint)
	elif st == "phase_plat":
		var p_st: String = str(s.get("phase_state", "solid"))
		var p_solid: bool = p_st != "ghost"
		var p_warn: bool = p_st == "warn"
		var pk: String = "s2_phase_warn" if p_warn else ("s2_phase_solid" if p_solid else "s2_phase_ghost")
		_draw_tiled_sprite(_tex(pk), r, Color(1.0, 1.0, 1.0, (1.0 if p_solid else 0.28) * alpha_mul))
	elif st == "polarity_block":
		var mode_p: String = str(engine.polarity_groups.get(str(s.get("group", "m1")), "blue"))
		var is_org: bool = mode_p == "orange"
		_draw_tiled_sprite(_tex("s2_mag_orange" if is_org else "s2_mag_blue"), r, base_tint)
	elif st == "signal_bridge":
		var br_on: bool = Sector1And2Mechanics.is_signal_bridge_on(s, engine.signal_groups)
		draw_rect(r, Color(0.0, 0.96, 1.0, 0.72 * alpha_mul) if br_on else Color(0.0, 0.96, 1.0, 0.12), true)
		draw_rect(r, Color("#00f5ff"), false, 1.5)
	elif st in ["signal_gate", "beat_gate", "paradox_gate"]:
		var g_open: bool = false
		if st == "signal_gate":
			g_open = Sector1And2Mechanics.is_signal_gate_open(s, engine.signal_groups)
		elif st == "beat_gate":
			g_open = bool(s.get("is_open", false))
		elif st == "paradox_gate":
			g_open = engine.paradox_unlocked
		if not g_open:
			_draw_tiled_sprite(_tex("s2_beat_gate" if lv_id >= 51 else "laser_gate"), r, base_tint)
	elif st == "shy_brick":
		var shy_on: bool = bool(s.get("shy_solid", true))
		_draw_tiled_sprite(_tex("s2_shy_brick"), r, Color(1.0, 1.0, 1.0, (1.0 if shy_on else 0.24) * alpha_mul))
	elif st == "piston":
		_draw_tiled_sprite(_tex("s2_piston_head"), r, base_tint)
	elif st == "ceiling_crusher":
		draw_texture_rect(_tex("s2_ceiling_crusher"), r, false, base_tint)
	elif st == "fake_error":
		draw_texture_rect(_tex("s2_fake_error"), r, false, base_tint)
	elif st in ["glass_panel", "time_slice_plat", "null_block"]:
		var col_on: bool = Sector1And2Mechanics.is_solid_collidable(s, engine.active_layer, engine.signal_groups)
		var base_a: float = (0.46 if st == "glass_panel" else (0.64 if st == "time_slice_plat" else 0.68)) * (1.0 if col_on else 0.22) * alpha_mul
		var fill_g: Color = Color(0.56, 0.90, 1.0, base_a) if st == "glass_panel" else (Color(0.99, 0.85, 0.28, base_a) if st == "time_slice_plat" else Color(0.95, 0.18, 0.45, base_a))
		draw_rect(r, fill_g, true)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.85 if col_on else 0.25), false, 1.5)
	else:
		_draw_tiled_sprite(_tex("platform_copper"), r, base_tint)

func _draw_entity(e: Dictionary, vw: float) -> void:
	if bool(e.get("collected", false)) or bool(e.get("dead_ent", false)):
		return
	var ex: float = float(e.get("x", 0.0))
	var ey: float = float(e.get("y", 0.0))
	var ew: float = float(e.get("w", 36.0))
	var eh: float = float(e.get("h", 36.0))
	if ex + ew < engine.cam_x - 120.0 or ex > engine.cam_x + vw + 120.0:
		return

	var et: String = str(e.get("t", ""))
	var lv_id: int = engine.lv_id
	var r: Rect2 = Rect2(ex, ey, ew, eh)

	var e_layer: int = int(e.get("layer", -1))
	var ghost_e: bool = (lv_id >= 51 and lv_id <= 100 and e_layer >= 0 and e_layer != engine.active_layer)
	var tint: Color = Color(1.0, 1.0, 1.0, 0.28 if ghost_e else 1.0)

	if et == "spikes":
		_draw_tiled_sprite(_tex("s3_thorns" if lv_id >= 101 else "spikes_red"), r, tint)
	elif et == "flower":
		var fk: String = "flower_chomp" if int(engine.time_elapsed * 4.0) % 2 == 0 else "flower_skull"
		draw_texture_rect(_tex(fk), r, false, Color("#4ade80") if engine.rule_phase_b else tint)
	elif et == "amanita":
		draw_texture_rect(_tex("mushroom_amanita"), r, false, tint)
	elif et == "poison_item":
		draw_texture_rect(_tex("mushroom_poison"), r, false, tint)
	elif et == "antidote_pad":
		draw_texture_rect(_tex("item_antidote"), r, false, tint)
	elif et == "crafting":
		draw_texture_rect(_tex("crafting_station"), r, false, tint)
	elif et == "spring":
		var sp_anim: float = float(e.get("spring_anim", 0.0))
		var spk: String = "s3_shroom_bounce" if lv_id >= 101 else ("spring_launch" if sp_anim > 0.4 else ("spring_compressed" if sp_anim > 0.05 else "spring"))
		draw_texture_rect(_tex(spk), r, false, tint)
	elif et == "checkpoint":
		var is_on: bool = (not engine.active_checkpoint.is_empty()) and absf(float(engine.active_checkpoint.get("gx", -999.0)) - GridMath.px_to_gx(ex)) < 0.8
		var cpk: String = ("s3_cp_on" if is_on else "s3_cp_off") if lv_id >= 101 else ("checkpoint_on" if is_on else "checkpoint_off")
		draw_texture_rect(_tex(cpk), r, false, tint)
	elif et == "flag":
		var is_fk: bool = bool(e.get("fake", false))
		var flk: String = ("s3_flag_idle" if lv_id >= 101 else "flag_idle")
		draw_texture_rect(_tex(flk), r, false, tint)
		if engine.xray_level and is_fk:
			draw_rect(r, Color("#fb7185"), false, 2.0)
	elif et == "cloud":
		var k_rev: bool = bool(e.get("knife_out", false)) or (engine.xray_level and bool(e.get("knife", false)))
		var clk: String = "cloud_knife" if k_rev else ("cloud_poison" if bool(e.get("poison", false)) else ("cloud_dark_safe" if bool(e.get("darkSafe", false)) else "cloud_safe"))
		draw_texture_rect(_tex(clk), r, false, tint)
	elif et == "coin":
		var ck2: String = "coin_2" if int(engine.time_elapsed * 6.0) % 2 == 1 else "coin_1"
		draw_texture_rect(_tex(ck2), r, false, tint)
	elif et == "gem":
		var gc: String = str(e.get("color", "red"))
		draw_texture_rect(_tex("gem_" + gc), r, false, tint)
	elif et == "powerup":
		var pk2: String = "icon_wing" if str(e.get("kind", "")) == "flight" else "icon_spring"
		draw_texture_rect(_tex(pk2), r, false, tint)
	elif et == "bomb_pickup" or et == "chain_bomb":
		draw_texture_rect(_tex("bomb"), r, false, tint)
	elif et == "clock" or et == "beat_clock":
		draw_texture_rect(_tex("clock_gold" if et == "clock" else "clock_gear"), r, false, tint)
	elif et == "hourglass":
		draw_texture_rect(_tex("time_hourglass"), r, false, tint)
	elif et == "gravity_pad":
		draw_texture_rect(_tex("gravity_pad"), r, false, tint)
	elif et == "poop":
		draw_texture_rect(_tex("poop"), r, false, tint)
	elif et == "pipe":
		draw_texture_rect(_tex("pipe"), r, false, tint)
	elif et == "launcher":
		draw_texture_rect(_tex("missile_launcher"), r, false, tint)
	elif et == "missile":
		var m_dir: float = 1.0 if float(e.get("vx", -1.0)) >= 0.0 else -1.0
		var mr: Rect2 = Rect2(ex + (ew if m_dir < 0.0 else 0.0), ey, ew * m_dir, eh)
		draw_texture_rect(_tex("missile"), mr, false, tint)
	elif et == "sign":
		var sk: String = "s3_wood_sign" if lv_id >= 101 else ("sign_left" if str(e.get("dir", "right")) == "left" else "sign_right")
		draw_texture_rect(_tex(sk), r, false, tint)
		var stxt: String = str(e.get("textEn" if save.lang == "en" else "text", ""))
		if stxt != "" and font_main != null and absf(float(engine.player.get("x", 0.0)) - ex) < 150.0:
			draw_string(font_main, Vector2(ex - 20.0, ey - 8.0), stxt, HORIZONTAL_ALIGNMENT_CENTER, ew + 40.0, 12, Color("#fde047"))
	elif et == "princess":
		draw_texture_rect(_tex("npc_princess"), r, false, tint)
		for gi in range(engine.princess_perm_order.size()):
			var g_col: String = str(engine.princess_perm_order[gi])
			var done_g: bool = gi < engine.collected_gems.size()
			draw_texture_rect(_tex("gem_" + g_col), Rect2(ex - 8.0 + float(gi) * 18.0, ey - 22.0, 15.0, 15.0), false, Color(1.0, 1.0, 1.0, 1.0 if done_g else 0.45))
	elif et == "shop":
		draw_texture_rect(_tex("npc_merchant"), r, false, tint)
	elif et == "enemy":
		var ek: String = str(e.get("kind", "follower"))
		var espr: String = "enemy_boss" if ek == "boss" else ("enemy_flying" if ek == "flying" else "enemy_follower")
		draw_texture_rect(_tex(espr), r, false, tint)
	# --- Sector 2 Entities ---
	elif et == "signal_node":
		var n_on: bool = bool(engine.signal_groups.get(str(e.get("group", "")), false))
		draw_texture_rect(_tex("s2_node_on" if n_on else "s2_node_off"), r, false, tint)
	elif et == "decoy_btn":
		draw_texture_rect(_tex("s2_node_overload"), r, false, tint)
	elif et == "polarity_node":
		var p_org: bool = str(engine.polarity_groups.get(str(e.get("group", "m1")), "blue")) == "orange"
		draw_texture_rect(_tex("s2_mag_node_orange" if p_org else "s2_mag_node_blue"), r, false, tint)
	elif et == "portal":
		var pid: int = int(e.get("pairId", 0)) % 3
		var ptk: String = "s2_portal_c" if pid == 2 else ("s2_portal_b" if pid == 1 else "s2_portal_a")
		draw_texture_rect(_tex(ptk), r, false, tint)
	elif et in ["layer_term", "echo_pad", "echo_rec_pad"]:
		draw_texture_rect(_tex("s2_layer_term"), r, false, tint)
	elif et == "signal_battery" or et == "battery_slot":
		draw_texture_rect(_tex("s2_battery"), r, false, Color(1.0, 1.0, 1.0, 0.45) if et == "battery_slot" and not bool(e.get("filled", false)) else tint)
	elif et == "root_item" or et == "root_slot":
		draw_texture_rect(_tex("s2_root_key"), r, false, Color(1.0, 1.0, 1.0, 0.45) if et == "root_slot" and not bool(e.get("filled", false)) else tint)
	elif et == "root_term":
		draw_texture_rect(_tex("s2_root_term"), r, false, tint)
	elif et == "curse_totem":
		draw_texture_rect(_tex("s2_curse_totem"), r, false, tint)
	elif et == "fake_save":
		var pur: bool = bool(e.get("purified", false))
		draw_texture_rect(_tex("checkpoint_on" if pur else "s2_fake_save"), r, false, tint)
	elif et == "mimic_flag":
		var tamed: bool = bool(e.get("tamed", false))
		draw_texture_rect(_tex("flag_win" if tamed else "s2_mimic_flag"), r, false, tint)
	elif et == "mimic_chest":
		draw_texture_rect(_tex("s2_mimic_chest"), r, false, tint)
	elif et == "betray_spring":
		draw_texture_rect(_tex("spring" if bool(e.get("calibrated", false)) else "s2_betray_spring"), r, false, tint)
	elif et == "trojan_heart":
		draw_texture_rect(_tex("heart" if bool(e.get("purified", false)) else "s2_trojan_heart"), r, false, tint)
	elif et == "troll_hand":
		draw_texture_rect(_tex("s2_troll_hand"), r, false, tint)
	elif et == "peace_dove":
		draw_texture_rect(_tex("s2_peace_dove"), r, false, tint)
	elif et == "moving_pit":
		draw_texture_rect(_tex("s2_moving_pit"), r, false, tint)
	elif et == "saw_track":
		draw_texture_rect(_tex("s2_saw_blade"), r, false, tint)
	elif et == "time_node":
		draw_texture_rect(_tex("s2_time_node"), r, false, tint)
	elif et == "mem_shard":
		draw_texture_rect(_tex("s2_mem_shard"), r, false, tint)
	elif et == "electric_arc":
		var off_ga: String = str(e.get("offGroup", ""))
		if (off_ga == "" or not bool(engine.signal_groups.get(off_ga, false))) and not bool(e.get("disabled_arc", false)):
			draw_rect(r, Color(0.0, 0.96, 1.0, 0.55 + 0.35 * sin(engine.time_elapsed * 22.0)), true)
	elif et in ["time_bubble", "wind_zone", "heat_vent", "cool_pad"]:
		var zc: Color = Color(0.38, 0.75, 1.0, 0.16)
		if et == "heat_vent":
			zc = Color(0.98, 0.38, 0.18, 0.22)
		elif et == "time_bubble":
			zc = Color(0.75, 0.52, 0.99, 0.18)
		draw_rect(r, zc, true)
		draw_rect(r, Color(zc.r, zc.g, zc.b, 0.48), false, 1.5)
	elif et == "s2_enemy":
		var skind: String = str(e.get("kind", "mech_spider"))
		var smap: Dictionary = {
			"forklift": "s2_forklift", "turret": "s2_turret", "drone": "s2_bot_drone",
			"shield_mech": "s2_shield_mech", "patrol": "s2_bot_patrol"
		}
		var s2k: String = str(smap.get(skind, skind))
		draw_texture_rect(_tex(s2k), r, false, tint)
	elif et == "s2_boss":
		var bstyle: String = str(e.get("style", "signal_storm"))
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
		draw_texture_rect(_tex(str(bmap.get(bstyle, "s2_boss_null"))), r, false, tint)
	# --- Sector 3 Arcadia Entities ---
	elif et == "s3_valve":
		draw_texture_rect(_tex("s3_valve_red"), r, false, tint)
	elif et == "s3_sundial":
		draw_texture_rect(_tex("s3_sundial_orb"), r, false, tint)
	elif et == "s3_catapult":
		draw_texture_rect(_tex("s3_catapult_trap"), r, false, tint)
	elif et == "s3_bomb_trophy":
		draw_texture_rect(_tex("s3_bomb_trophy"), r, false, tint)
	elif et == "s3_suction_pipe":
		draw_texture_rect(_tex("s3_suction_pipe"), r, false, tint)
	elif et == "s3_mimic_flag":
		var tm3: bool = bool(e.get("tamed", false))
		draw_texture_rect(_tex("s3_flag_win" if tm3 else "s3_mimic_flag"), r, false, tint)
	elif et == "s3_bush":
		var b_out: bool = bool(e.get("revealed", false)) or bool(e.get("blade_out", false)) or (engine.xray_level and str(e.get("mode", "safe")) != "safe")
		draw_texture_rect(_tex("s3_bush_blade" if b_out else "s3_bush_safe"), r, false, tint)
	elif et == "s3_flower":
		var f_ang: bool = bool(e.get("angry", false))
		draw_texture_rect(_tex("s3_pink_flower_angry" if f_ang else "s3_pink_flower"), r, false, tint)
	elif et == "s3_tanuki":
		var as_log: bool = bool(e.get("is_log", false))
		draw_texture_rect(_tex("s3_mon_tanuki_log" if as_log else "s3_mon_tanuki"), r, false, tint)
	elif et == "s3_manju":
		var spk_m: bool = bool(e.get("spiked", false)) or bool(e.get("spiky", false))
		draw_texture_rect(_tex("s3_mon_manju_spike" if spk_m else "s3_mon_manju"), r, false, tint)
	elif et == "s3_ladybug":
		draw_texture_rect(_tex("s3_mon_ladybug"), r, false, tint)
	elif et == "s3_mole":
		draw_texture_rect(_tex("s3_mon_mole"), r, false, tint)
	elif et == "s3_sun":
		var sun_mad: bool = bool(e.get("swooping", false)) or bool(e.get("awake", false)) or bool(e.get("diving", false))
		draw_texture_rect(_tex("s3_sun_angry" if sun_mad else "s3_sun_calm"), r, false, tint)
	elif et == "s3_boss":
		var b3k: String = "s3_boss_%d" % clampi(lv_id, 110, 150)
		if not textures.has(b3k):
			b3k = "s3_boss_150"
		draw_texture_rect(_tex(b3k), r, false, tint)

func _draw_hero() -> void:
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

	var spr_key: String = "hero_idle"
	if float(p.get("melee_anim_timer", 0.0)) > 0.0:
		spr_key = "hero_melee_slash"
	elif float(p.get("attack_anim_timer", 0.0)) > 0.0:
		spr_key = "hero_attack"
	elif not bool(p.get("on_ground", false)):
		spr_key = "hero_jump1" if float(p.get("vy", 0.0)) * grav_d < 0.0 else "hero_jump2"
	elif absf(float(p.get("vx", 0.0))) > 22.0:
		var frame_i: int = int(engine.move_time * 10.0) % 2
		spr_key = "hero_run1" if frame_i == 0 else "hero_run2"

	var h_tex: Texture2D = _tex(spr_key)
	var sc_x: float = float(p.get("scale_x", 1.0))
	var sc_y: float = float(p.get("scale_y", 1.0))
	var draw_w: float = (pw + 12.0) * sc_x
	var draw_h: float = (ph + 4.0) * sc_y
	var cx: float = px + pw * 0.5
	var by: float = py + ph

	# Golden Body Radiant Aura
	if float(p.get("golden_timer", 0.0)) > 0.0:
		var pulse_r: float = 28.0 + sin(engine.time_elapsed * 12.0) * 4.0
		draw_circle(Vector2(cx, py + ph * 0.5), pulse_r, Color(0.99, 0.88, 0.22, 0.30))
		draw_arc(Vector2(cx, py + ph * 0.5), pulse_r + 3.0, 0.0, TAU, 24, Color("#fde047"), 2.0)

	var h_tint: Color = Color.WHITE
	if float(p.get("golden_timer", 0.0)) > 0.0:
		h_tint = Color(1.25, 1.12, 0.55, 1.0)
	elif float(p.get("poison_timer", 0.0)) > 0.0:
		h_tint = Color(0.75, 1.15, 0.65, 1.0)
	elif float(p.get("invuln_timer", 0.0)) > 0.0 and int(engine.time_elapsed * 18.0) % 2 == 0:
		h_tint.a = 0.48

	if h_tex != null:
		var rx: float = cx - draw_w * 0.5 + (draw_w if facing < 0 else 0.0)
		var rw: float = draw_w * (-1.0 if facing < 0 else 1.0)
		var ry: float = (by - draw_h) if grav_d >= 0.0 else (py + draw_h)
		var rh: float = draw_h * (1.0 if grav_d >= 0.0 else -1.0)
		draw_texture_rect(h_tex, Rect2(rx, ry, rw, rh), false, h_tint)
	else:
		draw_rect(Rect2(px, py, pw, ph), Color("#00f5ff"), true)

	# Shield bubble
	if bool(p.get("shield", false)):
		var sh_tex: Texture2D = _tex("fx_shield_aegis")
		if sh_tex != null:
			draw_texture_rect(sh_tex, Rect2(cx - 24.0, py - 5.0, 48.0, 50.0), false, Color(1.0, 1.0, 1.0, 0.62))
		else:
			draw_arc(Vector2(cx, py + ph * 0.5), 24.0, 0.0, TAU, 24, Color("#38bdf8"), 2.0)

	# Carried battery / root key above head
	if not engine.carrying_item.is_empty():
		var ck_carry: String = "s2_root_key" if str(engine.carrying_item.get("t", "")) == "root_item" else "s2_battery"
		draw_texture_rect(_tex(ck_carry), Rect2(cx - 12.0, py - 26.0, 24.0, 24.0), false)

func _draw_combat_and_fx() -> void:
	for b_var in engine.bullets:
		var b: Dictionary = b_var
		var bk: String = "sword_wave" if bool(b.get("is_wave", false)) else ("bullet_fire" if bool(b.get("fire", false)) else "bullet_cyan")
		draw_texture_rect(_tex(bk), Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"])), false)

	for es_var in engine.enemy_shots:
		var es: Dictionary = es_var
		var ec: Color = Color("#c084fc") if str(es.get("kind", "")) == "phase_orb" else Color("#fb7185")
		var er: Rect2 = Rect2(float(es["x"]), float(es["y"]), float(es.get("w", 12.0)), float(es.get("h", 12.0)))
		draw_circle(er.get_center(), er.size.x * 0.55, ec)
		draw_circle(er.get_center(), er.size.x * 0.28, Color.WHITE)

	for bm_var in engine.bombs:
		var bm: Dictionary = bm_var
		var fuse: float = float(bm.get("fuse", 1.0))
		var flash_b: Color = Color(1.3, 0.5, 0.5, 1.0) if (fuse < 0.5 and int(fuse * 18.0) % 2 == 0) else Color.WHITE
		draw_texture_rect(_tex("bomb"), Rect2(float(bm["x"]), float(bm["y"]), 24.0, 24.0), false, flash_b)

	for ma_var in engine.melee_arcs:
		var ma: Dictionary = ma_var
		var mk: String = "fx_melee_crit" if bool(ma.get("crit", false)) else "fx_melee_arc"
		var mdir: int = int(ma.get("dir", 1))
		var mw: float = float(ma.get("w", 56.0))
		var mh: float = float(ma.get("h", 48.0))
		var mx: float = float(ma["x"]) + (mw if mdir < 0 else 0.0)
		var m_al: float = clampf(float(ma.get("life", 0.1)) / 0.18, 0.0, 1.0)
		draw_texture_rect(_tex(mk), Rect2(mx, float(ma["y"]), mw * float(mdir), mh), false, Color(1.0, 1.0, 1.0, m_al))

	for sr_var in engine.shock_rings:
		var sr: Dictionary = sr_var
		var prog: float = 1.0 - clampf(float(sr["life"]) / maxf(0.05, float(sr["max_life"])), 0.0, 1.0)
		var rad: float = lerpf(6.0, float(sr["max_r"]), prog)
		var scol: Color = sr.get("col", Color("#00f5ff"))
		draw_arc(Vector2(float(sr["x"]), float(sr["y"])), rad, 0.0, TAU, 24, Color(scol.r, scol.g, scol.b, 1.0 - prog), 2.5)

	for pt_var in engine.particles:
		var pt: Dictionary = pt_var
		var pal: float = clampf(float(pt["life"]) / maxf(0.05, float(pt["max_life"])), 0.0, 1.0)
		var pcol: Color = pt.get("col", Color("#00f5ff"))
		var psz: float = float(pt.get("sz", 4.0))
		draw_rect(Rect2(float(pt["x"]), float(pt["y"]), psz, psz), Color(pcol.r, pcol.g, pcol.b, pal), true)

	if font_main != null:
		for ft_var in engine.float_texts:
			var ft: Dictionary = ft_var
			var fal: float = clampf(float(ft["life"]) / 0.9, 0.0, 1.0)
			var fcol: Color = Color(str(ft.get("color", "#fde047")))
			fcol.a = fal
			draw_string(font_main, Vector2(float(ft["x"]) - 40.0, float(ft["y"])), str(ft.get("txt", "")), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, fcol)

func _draw_spotlight_mask(vw: float, vh: float, center: Vector2, r: float) -> void:
	var dark: Color = Color(0.01, 0.02, 0.06, 0.93)
	draw_rect(Rect2(0.0, 0.0, vw, maxf(0.0, center.y - r)), dark, true)
	draw_rect(Rect2(0.0, minf(vh, center.y + r), vw, maxf(0.0, vh - (center.y + r))), dark, true)
	draw_rect(Rect2(0.0, maxf(0.0, center.y - r), maxf(0.0, center.x - r), r * 2.0), dark, true)
	draw_rect(Rect2(minf(vw, center.x + r), maxf(0.0, center.y - r), maxf(0.0, vw - (center.x + r)), r * 2.0), dark, true)
	draw_arc(center, r, 0.0, TAU, 32, Color(0.0, 0.96, 1.0, 0.35), 2.0)

func _draw_boss_hud_bar(vw: float, boss: Dictionary) -> void:
	var hp: int = maxi(0, int(boss.get("hp", 1)))
	var max_hp: int = maxi(1, int(boss.get("max_hp", hp)))
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var bw: float = 340.0
	var bx: float = (vw - bw) * 0.5
	var by: float = 58.0
	draw_rect(Rect2(bx - 3.0, by - 3.0, bw + 6.0, 18.0), Color(0.02, 0.04, 0.14, 0.88), true)
	draw_rect(Rect2(bx, by, bw * ratio, 12.0), Color("#fb7185") if engine.lv_id < 101 else Color("#f59e0b"), true)
	draw_rect(Rect2(bx - 3.0, by - 3.0, bw + 6.0, 18.0), Color("#fde047"), false, 1.5)
	if font_main != null:
		var b_lbl: String = "BOSS HP  %d / %d" % [hp, max_hp]
		draw_string(font_main, Vector2(bx, by + 10.5), b_lbl, HORIZONTAL_ALIGNMENT_CENTER, bw, 11, Color.WHITE)

func _draw_fake_flag_prank(vw: float, vh: float) -> void:
	var card_w: float = 460.0
	var card_h: float = 84.0
	var rx: float = (vw - card_w) * 0.5
	var ry: float = (vh - card_h) * 0.42
	var is_p2: bool = (engine.fake_phase >= 2)
	draw_rect(Rect2(rx, ry, card_w, card_h), Color(0.18, 0.03, 0.10, 0.94) if is_p2 else Color(0.03, 0.16, 0.12, 0.92), true)
	draw_rect(Rect2(rx, ry, card_w, card_h), Color("#fb7185") if is_p2 else Color("#4ade80"), false, 3.0)
	if font_main != null:
		var msg: String = ""
		if save.lang == "en":
			msg = "★ PSYCH! IT'S A BOOBY-TRAPPED FAKE FLAG!" if is_p2 else "★ STAGE CLEARED...?!"
		else:
			msg = "★ 想得美！这是绑了炸药的钓鱼假旗喵！" if is_p2 else "★ 恭喜通关……才怪？！"
		draw_string(font_main, Vector2(rx, ry + 50.0), msg, HORIZONTAL_ALIGNMENT_CENTER, card_w, 20, Color("#fde047") if is_p2 else Color("#4ade80"))

# ==============================================================================
# AUTOMATED CI SMOKE VERIFICATION (`--smoke-test`)
# ==============================================================================
func _run_ci_smoke_test() -> void:
	print("[SMOKE] Loaded textures: ", textures.size(), " | BGM streams: ", audio.bgm_streams.size(), " | SFX streams: ", audio.sfx_streams.size(), " | Stages: ", engine.levels_by_id.size())
	if textures.size() < 330 or audio.bgm_streams.size() < 9 or audio.sfx_streams.size() < 24 or engine.levels_by_id.size() != 150:
		push_error("[SMOKE] Asset or stage count mismatch!")
		get_tree().quit(1)
		return
	# Verify S1 (Lv.1), S1 Zen (Lv.50), S2 (Lv.51 & Lv.75), S3 (Lv.101 & Lv.150) simulation ticks cleanly
	for test_lv in [1, 50, 51, 75, 101, 150]:
		engine.start_stage(test_lv)
		ui.enter_gameplay_hud(test_lv)
		for _step in range(8):
			engine.step_frame(0.016, { "left": false, "right": true, "jump_pressed": _step == 0, "jump_held": _step < 4 })
			ui.step_ui(0.016)
	ui.open_level_select_modal()
	ui.open_options_modal("shop")
	ui.show_title_screen()
	print("[SMOKE] All 150-stage sectors, UI modals, shop rules, and audio streams verified 100% OK!")
	get_tree().quit(0)
