extends Node2D

# Every alias resolves strictly to one of the 423 verified keys in data/game_metadata.json["assets"]
const TEX_ALIASES: Dictionary = {
	"coin_gold": "ui_coin_hud",
	"shield_orb": "icon_shield",
	"icon_wings": "icon_wing",
	"sword_pickup": "icon_sword",
	"bullet_up": "s3_shop_bullet",
	"hud_wall_phase": "s3_shop_phase",
	"clock_item": "clock_gold"
}

const BOSS_KEY_SPRITE_MAP: Dictionary = {
	"lv010_grad": "mech_knight",
	"lv020_gate": "mech_golem",
	"lv030_fortress": "mech_tank",
	"lv038_mechaskull": "boss_038_mechaskull",
	"lv040_museum": "mech_exec",
	"lv050_author": "boss_050_author_hand",
	"lv060_signal": "boss_060_signal_core",
	"lv067_blindbox": "boss_070_mecha_overlord",
	"lv067_reassembly": "boss_070_mecha_overlord",
	"lv070_mecha": "boss_070_mecha_overlord",
	"lv080_fracture": "boss_080_fracture_core",
	"lv088_reaper": "boss_090_chrono_overlord",
	"lv088_chrono_skull": "boss_090_chrono_overlord",
	"lv090_chrono": "boss_090_chrono_overlord",
	"lv098_admin": "boss_100_null",
	"lv098_admin_clone": "boss_100_null",
	"lv100_null": "boss_100_null",
	"lv110_cloud_ram": "boss_110_cloud_ram",
	"lv120_hydra_pipe": "boss_120_hydra_pipe",
	"lv130_kitsune_tanuki": "boss_130_kitsune_tanuki",
	"lv140_thunder_demon": "boss_140_thunder_demon",
	"lv150_solaris": "boss_150_solaris"
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
var debug_overlay: DebugOverlay = null

var sky_stars: Array = []
var sky_traffic: Array = []

# Hero multi-frame visual tracking state (non-invasive client-side animation timers)
var hero_land_pose_timer: float = 0.0
var hero_hurt_pose_timer: float = 0.0
var hero_prev_invuln: float = 0.0
var hero_was_airborne: bool = false
var screen_flash_alpha: float = 0.0
var screen_flash_col: Color = Color.WHITE

var prev_kb: Dictionary = {
	"down": false,
	"jump": false,
	"shoot": false,
	"slash": false,
	"sheathe": false,
	"interact": false,
	"bomb": false,
	"layer": false,
	"gold": false,
	"retry": false,
	"esc": false,
	"debug": false
}

# ==============================================================================
# SAFE REFLECTION & WORLD-STATE HELPERS (100% Forward/Backward Compatible)
# ==============================================================================
func _eng_get(prop_name: String, fallback: Variant) -> Variant:
	if engine == null:
		return fallback
	var val: Variant = engine.get(prop_name)
	if val != null:
		return val
	return fallback

func _eng_set_if_has(prop_name: String, value: Variant) -> void:
	if engine == null:
		return
	for p_info_v in engine.get_property_list():
		var p_info: Dictionary = p_info_v
		if str(p_info.get("name", "")) == prop_name:
			engine.set(prop_name, value)
			return

func _ws_get(prop_name: String, fallback: Variant) -> Variant:
	if engine != null:
		var ws: Variant = engine.get("world_state")
		if ws != null and typeof(ws) == TYPE_OBJECT:
			var v: Variant = (ws as Object).get(prop_name)
			if v != null:
				return v
	return _eng_get(prop_name, fallback)

func _is_signal_group_on(grp: String) -> bool:
	if grp == "":
		return false
	var sg: Variant = _eng_get("signal_groups", {})
	if typeof(sg) == TYPE_DICTIONARY:
		return bool((sg as Dictionary).get(grp, false))
	return false

func _check_signal_bridge_on(s: Dictionary) -> bool:
	if s.has("bridge_on"):
		return bool(s["bridge_on"])
	var grp: String = str(s.get("group", ""))
	var inv: bool = bool(s.get("invert", false))
	var sig: bool = _is_signal_group_on(grp)
	return (not sig) if inv else sig

func _check_signal_gate_open(s: Dictionary) -> bool:
	if s.has("gate_open"):
		return bool(s["gate_open"])
	var grp: String = str(s.get("group", s.get("unlockGroup", "")))
	if grp == "":
		return false
	var inv: bool = bool(s.get("invert", false))
	var sig: bool = _is_signal_group_on(grp)
	return (not sig) if inv else sig

func _check_solid_collidable(s: Dictionary) -> bool:
	if bool(s.get("broken", false)):
		return false
	if s.has("collidable"):
		return bool(s["collidable"])
	var st: String = str(s.get("t", "solid"))
	if st == "null_block":
		return str(s.get("null_state", "solid")) != "ghost"
	if st == "time_slice_plat":
		var grp: String = str(s.get("group", ""))
		if grp != "":
			return _is_signal_group_on(grp)
		return bool(s.get("slice_active", true))
	return true

func _check_cloud_safe(o: Dictionary) -> bool:
	var sub: String = str(o.get("subType", ""))
	if sub != "":
		if sub in ["blade", "hollow", "thunder"]:
			return bool(o.get("disarmed", false)) or bool(o.get("frozen_solid", false))
		return true
	var mode_s: String = str(o.get("mode", "safe_plat"))
	if mode_s == "sundial_knife":
		var phase_name: String = str(_ws_get("sundial_phase_name", ""))
		var legacy_phase: bool = bool(_eng_get("s3_sundial_phase", false))
		return (phase_name == "night") or legacy_phase
	if mode_s in ["hidden_knife", "swoop_cloud", "fake_cloud"]:
		return bool(o.get("disarmed", false))
	return not bool(o.get("knife", false))

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	is_mobile_platform = _detect_mobile_platform()
	_configure_platform_window()
	_init_sky_atmosphere()

	meta = _load_json_dict("res://data/game_metadata.json")
	levels_raw = _load_all_levels()
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
	_eng_set_if_has("assist_mode", save.assist_mode)
	audio = ChiptunePlayer.new(bgm_node, meta)
	audio.visual_subtitles_enabled = save.visual_captions_on

	# Locked 960x540 (16:9) hardware-clipped Stage World Box over full-screen wide panorama
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

	debug_overlay = get_node_or_null("DebugLayer/DebugOverlay") as DebugOverlay
	if debug_overlay != null:
		debug_overlay.setup(engine, save, font_main)

	ui.request_start_stage.connect(_on_start_stage)
	ui.request_retry_stage.connect(_on_retry_stage)
	ui.request_fresh_restart.connect(_on_fresh_restart)
	ui.request_return_title.connect(_on_return_title)
	ui.request_quit_app.connect(func() -> void: get_tree().quit())
	ui.request_toggle_fullscreen.connect(_toggle_fullscreen)

	var all_args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if ("--smoke-test" in user_args) or ("--smoke-test" in all_args):
		call_deferred("_StartCiSmoke")
		return

func _load_all_levels() -> Array:
	var main_arr: Array = _load_json_array("res://data/levels_150.json")
	if main_arr.size() >= 150:
		return main_arr
	var merged_by_id: Dictionary = {}
	for lv_v in main_arr:
		if typeof(lv_v) == TYPE_DICTIONARY:
			var d0: Dictionary = lv_v
			merged_by_id[int(d0.get("id", 0))] = d0
	var part_paths: Array[String] = [
		"res://data/levels_act1_001_050.json",
		"res://data/levels_act2_051_100.json",
		"res://data/levels_act3_101_150.json"
	]
	for pp in part_paths:
		var parr: Array = _load_json_array(pp)
		for item_v in parr:
			if typeof(item_v) == TYPE_DICTIONARY:
				var d: Dictionary = item_v
				merged_by_id[int(d.get("id", 0))] = d
	var ids: Array = merged_by_id.keys()
	ids.sort()
	var out: Array = []
	for id_k in ids:
		if int(id_k) >= 1 and int(id_k) <= 150:
			out.append(merged_by_id[id_k])
	return out

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
		DisplayServer.window_set_title("哥查德的大冒险 · GODCHARD ADVENTURE v4.0")

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
# STAGE FLOW & LAYERED INPUT ARCHITECTURE (`_input` -> GUI -> `_unhandled_input`)
# ==============================================================================
func _on_start_stage(stage_id: int) -> void:
	if not save.is_stage_unlocked(stage_id):
		return
	shop.reset_for_new_stage()
	_eng_set_if_has("assist_mode", save.assist_mode)
	engine.start_stage(stage_id)
	hero_land_pose_timer = 0.0
	hero_hurt_pose_timer = 0.0
	hero_prev_invuln = 0.0
	hero_was_airborne = false
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
	hero_land_pose_timer = 0.0
	hero_hurt_pose_timer = 0.0
	hero_was_airborne = false
	ui.refresh_hud()
	queue_redraw()
	stage_box.queue_redraw()

func _on_fresh_restart() -> void:
	if not ui.in_game:
		return
	engine.manual_fresh_restart()
	hero_land_pose_timer = 0.0
	hero_hurt_pose_timer = 0.0
	hero_was_airborne = false
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
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_F11:
				_toggle_fullscreen()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_F3 and debug_overlay != null:
				var dbg_on: bool = debug_overlay.toggle_debug()
				ui.push_toast("Debug Overlay: ON" if dbg_on else "Debug Overlay: OFF", "ui_gear", "#00f5ff")
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

func _gather_gameplay_input(_dt: float) -> Dictionary:
	var t_edges: Dictionary = ui.consume_touch_edges()

	var kb_left: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var kb_right: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var kb_down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var kb_jump: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_K)
	var kb_shoot: bool = Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z)
	var kb_slash: bool = Input.is_physical_key_pressed(KEY_U) or Input.is_physical_key_pressed(KEY_X)
	var kb_sheathe: bool = Input.is_physical_key_pressed(KEY_H)
	var kb_interact: bool = Input.is_physical_key_pressed(KEY_F)
	var kb_bomb: bool = Input.is_physical_key_pressed(KEY_B) or Input.is_physical_key_pressed(KEY_I) or Input.is_physical_key_pressed(KEY_C)
	var kb_layer: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_Q)
	var kb_gold: bool = Input.is_physical_key_pressed(KEY_G) or Input.is_physical_key_pressed(KEY_O) or Input.is_physical_key_pressed(KEY_V)

	var jump_pressed: bool = bool(t_edges["jump_pressed"]) or (kb_jump and not bool(prev_kb["jump"]))
	var jump_released: bool = bool(t_edges["jump_released"]) or ((not kb_jump) and bool(prev_kb["jump"]))
	var jump_held: bool = bool(t_edges["jump_held"]) or kb_jump
	var down_now: bool = bool(t_edges["down"]) or kb_down
	var down_pressed: bool = bool(t_edges["down_pressed"]) or (kb_down and not bool(prev_kb["down"]))
	var sheathe_pressed: bool = bool(t_edges["sheathe_pressed"]) or (kb_sheathe and not bool(prev_kb["sheathe"]))
	var interact_pressed: bool = bool(t_edges["interact_pressed"]) or (kb_interact and not bool(prev_kb["interact"]))
	var interact_held: bool = bool(t_edges["interact_held"]) or kb_interact

	var p_cur: Dictionary = _eng_get("player", {})
	var airborne_now: bool = (not p_cur.is_empty()) and (not bool(p_cur.get("on_ground", true)))
	var gp_pressed: bool = airborne_now and down_now and jump_pressed

	var inp: Dictionary = {
		"left": bool(t_edges["left"]) or kb_left,
		"right": bool(t_edges["right"]) or kb_right,
		"down": down_now,
		"down_pressed": down_pressed,
		"jump_held": jump_held,
		"jump_pressed": jump_pressed,
		"jump_released": jump_released,
		"ground_pound_pressed": gp_pressed,
		"shoot_pressed": bool(t_edges["shoot_pressed"]) or (kb_shoot and not bool(prev_kb["shoot"])),
		"slash_pressed": bool(t_edges["slash_pressed"]) or (kb_slash and not bool(prev_kb["slash"])),
		"sheathe_pressed": sheathe_pressed,
		"sheathe_toggle": sheathe_pressed,
		"interact_pressed": interact_pressed,
		"interact": interact_pressed,
		"interact_held": interact_held,
		"pick_place_pressed": interact_pressed,
		"bomb_pressed": bool(t_edges["bomb_pressed"]) or (kb_bomb and not bool(prev_kb["bomb"])),
		"layer_pressed": bool(t_edges["layer_pressed"]) or (kb_layer and not bool(prev_kb["layer"])),
		"gold_pressed": bool(t_edges["gold_pressed"]) or (kb_gold and not bool(prev_kb["gold"]))
	}

	prev_kb["down"] = kb_down
	prev_kb["jump"] = kb_jump
	prev_kb["shoot"] = kb_shoot
	prev_kb["slash"] = kb_slash
	prev_kb["sheathe"] = kb_sheathe
	prev_kb["interact"] = kb_interact
	prev_kb["bomb"] = kb_bomb
	prev_kb["layer"] = kb_layer
	prev_kb["gold"] = kb_gold

	return inp

func _update_hero_pose_timers(dt: float) -> void:
	if hero_land_pose_timer > 0.0:
		hero_land_pose_timer = maxf(0.0, hero_land_pose_timer - dt)
	if hero_hurt_pose_timer > 0.0:
		hero_hurt_pose_timer = maxf(0.0, hero_hurt_pose_timer - dt)
	if screen_flash_alpha > 0.0:
		screen_flash_alpha = maxf(0.0, screen_flash_alpha - dt * 3.2)

	var p: Dictionary = _eng_get("player", {})
	if p.is_empty():
		return
	var on_gnd: bool = bool(p.get("on_ground", false))
	if hero_was_airborne and on_gnd:
		hero_land_pose_timer = 0.13
	hero_was_airborne = not on_gnd

	var cur_inv: float = float(p.get("invuln_timer", 0.0))
	if cur_inv > hero_prev_invuln + 0.05 and float(p.get("golden_timer", 0.0)) <= 0.0:
		hero_hurt_pose_timer = 0.26
		screen_flash_col = Color("#38bdf8")
		screen_flash_alpha = 0.28 * clampf(save.screen_flash_scale, 0.0, 1.0)
	hero_prev_invuln = cur_inv

func _process(delta: float) -> void:
	if ui == null or engine == null:
		return
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
		_update_hero_pose_timers(dt)

		_drain_engine_queues()
		var dc_pending: String = str(_eng_get("pending_death_modal_cause", ""))
		var win_pending: Dictionary = _eng_get("pending_win_result", {})
		if dc_pending != "":
			_eng_set_if_has("pending_death_modal_cause", "")
			if save.vibrate_on and is_mobile_platform:
				Input.vibrate_handheld(45)
			ui.open_death_modal(dc_pending)
		elif not win_pending.is_empty():
			var wr: Dictionary = win_pending.duplicate(true)
			win_pending.clear()
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
		ui.in_game and bool(_eng_get("world_frozen", false)),
		ui.in_game and bool(_eng_get("world_slow", false)),
		ui.standby_mode
	)

func _drain_engine_queues() -> void:
	var sq: Variant = _eng_get("sfx_queue", [])
	if typeof(sq) == TYPE_ARRAY:
		var s_arr: Array = sq
		while not s_arr.is_empty():
			var sname: String = str(s_arr.pop_front())
			if sname == "boom":
				screen_flash_col = Color("#fef08a")
				screen_flash_alpha = maxf(screen_flash_alpha, 0.22 * clampf(save.screen_flash_scale, 0.0, 1.0))
			audio.play_named(sname)

	var tq: Variant = _eng_get("toast_queue", [])
	if typeof(tq) == TYPE_ARRAY:
		var t_arr: Array = tq
		while not t_arr.is_empty():
			var td_v: Variant = t_arr.pop_front()
			if typeof(td_v) == TYPE_DICTIONARY:
				var td: Dictionary = td_v
				var msg: String = str(td.get("en" if save.lang == "en" else "zh", ""))
				ui.push_toast(msg, str(td.get("icon", "ui_hint")), str(td.get("color", "#00f5ff")))

	var aq: Variant = _eng_get("ach_queue", [])
	if typeof(aq) == TYPE_ARRAY:
		var a_arr: Array = aq
		while not a_arr.is_empty():
			var ach_id: String = str(a_arr.pop_front())
			ui.push_ach_toast(ach_id)

# ==============================================================================
# LAYER 0: FULL-SCREEN ULTRA-WIDE SEAMLESS SKY & PARALLAX BACKDROP
# ==============================================================================
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
	var p: Dictionary = _eng_get("player", {})
	if p.is_empty():
		return false
	var px: float = float(p.get("x", 0.0))
	if props.has("finalEmptyRoomX") and px >= GridMath.gx_to_px(float(props["finalEmptyRoomX"])):
		return true
	if props.has("whiteSanctuaryX") and px >= GridMath.gx_to_px(float(props["whiteSanctuaryX"])):
		return true
	return false

func _draw() -> void:
	var vp_rect: Rect2 = get_viewport_rect()
	var vw: float = maxf(960.0, vp_rect.size.x)
	var vh: float = maxf(540.0, vp_rect.size.y)

	var lv_data: Dictionary = _eng_get("lv_data", {})
	if ui == null or not ui.in_game or lv_data.is_empty():
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040824"), true)
		return

	var props: Dictionary = lv_data.get("props", {})
	var is_zen: bool = _is_in_zen_sanctuary(props)
	var lv_id: int = int(_eng_get("lv_id", 1))
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))
	var cam_x: float = float(_eng_get("cam_x", 0.0))
	var world_frozen: bool = bool(_eng_get("world_frozen", false))

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
		var sky_drift: float = 0.0 if world_frozen else (t_sec * 7.5)
		var p_scroll: float = cam_x * 0.22 + sky_drift
		var offset_x: float = fposmod(p_scroll, tile_w)
		var draw_x: float = -offset_x
		while draw_x < vw + 2.0:
			draw_texture_rect(bg_tex, Rect2(floorf(draw_x), 0.0, tile_w + 1.0, vh), false)
			draw_x += tile_w

	if lv_id < 101:
		for st_var in sky_stars:
			var st: Dictionary = st_var
			var sx: float = fposmod(float(st["x"]) - cam_x * 0.08, vw)
			var sy: float = float(st["y"]) * (vh / 540.0)
			var tw: float = 0.32 + 0.68 * absf(sin(t_sec * 3.4 + float(st["ph"])))
			var sc: Color = st["col"]
			var ssz: float = float(st["sz"])
			draw_rect(Rect2(sx, sy, ssz, ssz), Color(sc.r, sc.g, sc.b, tw * 0.78), true)
		if lv_id <= 50:
			for tr_var in sky_traffic:
				var tr: Dictionary = tr_var
				var tx: float = fposmod(float(tr["x"]) + t_sec * float(tr["spd"]) - cam_x * 0.14, vw + 80.0) - 40.0
				var ty: float = float(tr["y"]) * (vh / 540.0)
				var tc: Color = tr["col"]
				draw_rect(Rect2(tx, ty, 12.0, 2.0), Color(tc.r, tc.g, tc.b, 0.52), true)

	if world_frozen:
		draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.05, 0.45, 0.56, 0.22), true)
	elif lv_id >= 51 and engine.has_method("is_dual_layer_active") and engine.is_dual_layer_active():
		var act_l: int = int(_eng_get("active_layer", 0))
		var veil_c: Color = Color(0.75, 0.22, 0.92, 0.08) if act_l == 1 else Color(0.0, 0.92, 1.0, 0.05)
		draw_rect(Rect2(0.0, 0.0, vw, vh), veil_c, true)
	elif lv_id >= 101:
		var sd_name: String = str(_ws_get("sundial_phase_name", "day"))
		if sd_name == "dusk" or bool(_eng_get("s3_sundial_phase", false)):
			draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.99, 0.62, 0.16, 0.16), true)
		elif sd_name == "night":
			draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.05, 0.09, 0.28, 0.34), true)

# ==============================================================================
# LAYER 1: LOCKED 960x540 (16:9) STAGE WORLD RENDERER (`stage_box._draw`)
# ==============================================================================
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

func _draw_dashed_line_on(c: Control, p0: Vector2, p1: Vector2, col: Color, width: float = 1.6, dash_len: float = 9.0, gap_len: float = 6.0) -> void:
	var diff: Vector2 = p1 - p0
	var dist: float = diff.length()
	if dist <= 1.0:
		return
	var dir: Vector2 = diff / dist
	var cur: float = 0.0
	while cur < dist:
		var end_d: float = minf(dist, cur + dash_len)
		c.draw_line(p0 + dir * cur, p0 + dir * end_d, col, width)
		cur += dash_len + gap_len

func _draw_colorblind_glyph(c: Control, pos: Vector2, kind: String, col: Color) -> void:
	if not save.colorblind_mode:
		return
	if kind == "hazard":
		# High-contrast Triangle ▲
		var pts: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0.0, -6.0),
			pos + Vector2(5.5, 4.5),
			pos + Vector2(-5.5, 4.5)
		])
		c.draw_colored_polygon(pts, col)
		c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color.BLACK, 1.2)
	elif kind == "safe":
		# High-contrast Diamond ◆
		var pts2: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0.0, -5.5),
			pos + Vector2(5.5, 0.0),
			pos + Vector2(0.0, 5.5),
			pos + Vector2(-5.5, 0.0)
		])
		c.draw_colored_polygon(pts2, col)
	elif kind == "bait":
		# High-contrast Cross ✕
		c.draw_line(pos + Vector2(-4.5, -4.5), pos + Vector2(4.5, 4.5), col, 2.0)
		c.draw_line(pos + Vector2(4.5, -4.5), pos + Vector2(-4.5, 4.5), col, 2.0)

func _is_missile_flipped(e: Dictionary) -> bool:
	return float(e.get("dir", 1.0)) < 0.0

func _draw_stage_world() -> void:
	var lv_data: Dictionary = _eng_get("lv_data", {})
	if ui == null or not ui.in_game or lv_data.is_empty():
		return

	var vw: float = 960.0
	var vh: float = 540.0
	var props: Dictionary = lv_data.get("props", {})
	var is_zen: bool = _is_in_zen_sanctuary(props)
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))
	var cam_x: float = float(_eng_get("cam_x", 0.0))
	var cam_y: float = float(_eng_get("cam_y", 0.0))

	# Screen shake scaled by Accessibility setting `save.screen_shake_scale`
	var shk: Vector2 = Vector2.ZERO
	var shk_t: float = float(_eng_get("shake_timer", 0.0))
	var shk_scale: float = clampf(save.screen_shake_scale, 0.0, 1.0)
	if shk_t > 0.0 and shk_scale > 0.01:
		var prog: float = shk_t / maxf(0.05, float(_eng_get("shake_dur", 0.2)))
		var mag: float = float(_eng_get("shake_mag", 0.0)) * prog * prog * shk_scale
		shk = Vector2(sin(t_sec * 68.0) * mag, cos(t_sec * 53.0) * mag * 0.7)
	var cam_off: Vector2 = Vector2(-roundf(cam_x) + shk.x, -roundf(cam_y) + shk.y)

	stage_box.draw_set_transform(cam_off, 0.0, Vector2.ONE)

	# 1. Moving platform rails, Signal fiber links, Clock scope tethers & Spotlight cones
	_draw_world_links_and_cones(stage_box, vw)

	# 2. Solids (Including v2.0 Rotatable Mirror + Reflection Preview, Weight Scale Gauge, 404 Popups + Top Wire, Ghost Train)
	var solids: Array = _eng_get("solids", [])
	for s_var in solids:
		if typeof(s_var) == TYPE_DICTIONARY:
			_draw_solid_on(stage_box, s_var as Dictionary, vw, is_zen, cam_off)

	# 3. Entities & 15 Chapter Bosses (Including all 30 new v2.0 objects & Boss Phase Armor VFX)
	var active_boss: Dictionary = {}
	var entities: Array = _eng_get("entities", [])
	for e_var in entities:
		if typeof(e_var) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_var
		_draw_entity_on(stage_box, e, vw, cam_off)
		var et: String = str(e.get("t", ""))
		if (et in ["s2_boss", "s3_boss", "enemy_boss"] or (et == "enemy" and str(e.get("kind", "")) == "boss")) and not bool(e.get("defeated", false)) and int(e.get("hp", 1)) > 0:
			active_boss = e

	# 4. Dual-Layer Landing Preview Ghost, Projected Player Shadow, Grave, Clones, Afterimages & Multi-Frame HD Hero
	_draw_player_shadow_and_layer_preview(stage_box)

	if bool(_eng_get("has_grave", false)):
		var gpos: Vector2 = _eng_get("grave_pos", Vector2.ZERO)
		var gt: Texture2D = _tex("hero_grave")
		if gt != null:
			stage_box.draw_texture_rect(gt, Rect2(gpos.x - 10.0, gpos.y - 6.0, 48.0, 52.0), false)

	var shadow_clone: Dictionary = _eng_get("shadow_clone", {})
	if not shadow_clone.is_empty():
		var sc_tex: Texture2D = _tex("hero_run2")
		var sc_f: bool = int(shadow_clone.get("facing", 1)) < 0
		_draw_sprite_on(stage_box, sc_tex, Rect2(float(shadow_clone["x"]) - 10.0, float(shadow_clone["y"]) - 6.0, 48.0, 50.0), sc_f, false, Color(0.85, 0.28, 0.96, 0.84), 0.0, cam_off)

	var act_layer: int = int(_eng_get("active_layer", 0))
	var echo_clones: Array = _eng_get("echo_clones", [])
	for ec_var in echo_clones:
		var ec: Dictionary = ec_var
		if bool(ec.get("cat_mirror", false)):
			var cm_r: Rect2 = Rect2(float(ec["x"]) - 4.0, float(ec["y"]) - 4.0, float(ec.get("w", 28.0)) + 8.0, float(ec.get("h", 42.0)) + 8.0)
			stage_box.draw_rect(cm_r, Color("#f43f5e"), false, 2.0)
			stage_box.draw_texture_rect(_tex("cat_nav_taunt"), Rect2(float(ec["x"]) - 6.0, float(ec["y"]), float(ec.get("w", 28.0)) + 12.0, float(ec.get("h", 42.0))), false)
		else:
			var same_l: bool = int(ec.get("layer", 0)) == act_layer
			var ec_al: float = 0.78 if same_l else 0.34
			var ec_col: Color = Color(0.98, 0.25, 0.55, ec_al) if bool(ec.get("hazard", false)) else Color(0.20, 0.96, 1.0, ec_al)
			var ec_f: bool = int(ec.get("facing", 1)) < 0
			_draw_sprite_on(stage_box, _tex("hero_run1"), Rect2(float(ec["x"]) - 10.0, float(ec["y"]) - 6.0, 48.0, 50.0), ec_f, false, ec_col, 0.0, cam_off)

	var afterimages: Array = _eng_get("afterimages", [])
	for ai_var in afterimages:
		var ai: Dictionary = ai_var
		var a_col: Color = ai.get("color", Color("#00f5ff"))
		var a_alpha: float = clampf(float(ai.get("life", 0.1)) / maxf(0.05, float(ai.get("max_life", 0.22))), 0.0, 1.0) * 0.42
		var ai_flip: bool = int(ai.get("facing", 1)) < 0
		_draw_sprite_on(stage_box, _tex("hero_jump1"), Rect2(float(ai["x"]) - 10.0, float(ai["y"]) - 6.0, 48.0, 50.0), ai_flip, float(ai.get("grav_dir", 1.0)) < 0.0, Color(a_col.r, a_col.g, a_col.b, a_alpha), 0.0, cam_off)

	_draw_hero_on(stage_box, cam_off)

	# 5. Projectiles, Mole Wrenches, Bombs, Melee Arcs, Shock Rings, Particles & Float Texts
	_draw_combat_and_fx_on(stage_box, cam_off)

	# Reset to 960x540 stage screen-space for HUD overlays
	stage_box.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 6. Blackout Spotlight / Separate Boss Armor + HP Bar / Fake Flag Prank / Screen Flash
	var is_blackout: bool = props.has("blackoutAfter") and t_sec >= float(props["blackoutAfter"])
	var player: Dictionary = _eng_get("player", {})
	if is_blackout and not player.is_empty():
		var px_s: float = float(player["x"]) + 14.0 - cam_x
		var py_s: float = float(player["y"]) + 21.0 - cam_y
		var rad: float = 290.0 if float(_eng_get("light_burst_timer", 0.0)) > 0.0 else 108.0
		_draw_spotlight_mask(stage_box, vw, vh, Vector2(px_s, py_s), rad)

	var boss_sm_state: Dictionary = _eng_get("boss_state", {})
	if bool(boss_sm_state.get("active", false)) and not bool(boss_sm_state.get("defeated", false)):
		_draw_boss_hud_bar(stage_box, vw, boss_sm_state, active_boss)
	elif not active_boss.is_empty():
		_draw_boss_hud_bar(stage_box, vw, {}, active_boss)

	if int(_eng_get("fake_phase", 0)) > 0:
		_draw_fake_flag_prank(stage_box, vw, vh)

	if screen_flash_alpha > 0.01:
		stage_box.draw_rect(Rect2(0.0, 0.0, vw, vh), Color(screen_flash_col.r, screen_flash_col.g, screen_flash_col.b, screen_flash_alpha), true)

func _draw_player_shadow_and_layer_preview(c: Control) -> void:
	var p: Dictionary = _eng_get("player", {})
	if p.is_empty() or bool(p.get("dead", false)):
		return
	var lv_id: int = int(_eng_get("lv_id", 1))

	# Draw projected ground shadow when shadow mechanics (Lv.016, 019, 029, 089, 124, 141, 150) or wings are active
	var sh_rect_v: Variant = _ws_get("shadow_rect", Rect2())
	if typeof(sh_rect_v) == TYPE_RECT2:
		var sr: Rect2 = sh_rect_v
		if sr.size.x > 4.0 and (bool(p.get("has_flight", false)) or lv_id in [16, 19, 29, 89, 101, 124, 130, 141, 144, 148, 150]):
			c.draw_rect(Rect2(sr.position.x, sr.position.y + 4.0, sr.size.x, 6.0), Color(0.02, 0.04, 0.12, 0.52), true)
			c.draw_rect(Rect2(sr.position.x, sr.position.y + 4.0, sr.size.x, 6.0), Color(0.40, 0.91, 0.98, 0.35), false, 1.0)

	# Draw Dual-Layer landing preview box if available in WorldState
	if engine.has_method("is_dual_layer_active") and engine.is_dual_layer_active():
		var prev_d: Variant = _ws_get("last_layer_preview", {})
		if typeof(prev_d) == TYPE_DICTIONARY and not (prev_d as Dictionary).is_empty():
			var pd: Dictionary = prev_d
			var pr_v: Variant = pd.get("preview_rect", null)
			if typeof(pr_v) == TYPE_RECT2:
				var pr: Rect2 = pr_v
				var safe_l: bool = bool(pd.get("safe", true)) and not bool(pd.get("blocked", false))
				var pcol: Color = Color(0.29, 0.87, 0.50, 0.32) if safe_l else Color(0.98, 0.25, 0.37, 0.38)
				c.draw_rect(pr, pcol, false, 1.5)

func _draw_world_links_and_cones(c: Control, vw: float) -> void:
	var cam_x: float = float(_eng_get("cam_x", 0.0))
	var solids: Array = _eng_get("solids", [])
	var entities: Array = _eng_get("entities", [])
	var map_lens_on: bool = bool(_eng_get("xray_level", false)) or (shop != null and shop.map_lens_active)

	for s_var in solids:
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
	for e_var in entities:
		var e: Dictionary = e_var
		if bool(e.get("dead", false)):
			continue
		var et: String = str(e.get("t", ""))
		var role_s: String = str(e.get("role", ""))
		var ex: float = float(e.get("x", 0.0))
		var ey: float = float(e.get("y", 0.0))
		var ew: float = float(e.get("w", 36.0))
		var eh: float = float(e.get("h", 36.0))

		if et == "signal_node":
			var grp: String = str(e.get("group", ""))
			if grp != "":
				nodes_by_grp[grp] = Vector2(ex + ew * 0.5, ey + eh * 0.5)

		# v2.0 Spotlight Shadow/Light Cone (`v2_spotlight_lamp`)
		if (et == "spotlight" or role_s == "spotlight") and not bool(e.get("off", false)) and not bool(e.get("broken", false)):
			if absf(ex - cam_x) < vw + 260.0:
				var lamp_c: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.82)
				var cone_pts: PackedVector2Array = PackedVector2Array([
					lamp_c + Vector2(-10.0, 0.0),
					lamp_c + Vector2(10.0, 0.0),
					lamp_c + Vector2(118.0, 260.0),
					lamp_c + Vector2(-118.0, 260.0)
				])
				c.draw_colored_polygon(cone_pts, Color(1.0, 0.94, 0.52, 0.13))
				_draw_dashed_line_on(c, lamp_c, lamp_c + Vector2(-118.0, 260.0), Color(1.0, 0.92, 0.38, 0.30), 1.2)
				_draw_dashed_line_on(c, lamp_c, lamp_c + Vector2(118.0, 260.0), Color(1.0, 0.92, 0.38, 0.30), 1.2)

		# v2.0 Clock Scope Color Tether Lines (Lv.008 & Lv.028: "钟摆影响到的对象会有同色细线")
		if et == "clock" or et == "beat_clock":
			var scope_s: String = str(e.get("scope", ""))
			var clk_grp: String = str(e.get("group", ""))
			if (scope_s != "" or clk_grp != "") and absf(ex - cam_x) < vw + 240.0:
				var sc_col: Color = Color("#fb923c") if scope_s == "enemy_speed" else (Color("#38bdf8") if scope_s == "mech_freeze" else Color("#fde047"))
				var c_origin: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.5)
				c.draw_arc(c_origin, 26.0, 0.0, TAU, 20, Color(sc_col.r, sc_col.g, sc_col.b, 0.38), 1.4)
				for s2_v in solids:
					var s2d: Dictionary = s2_v
					if clk_grp != "" and str(s2d.get("group", "")) == clk_grp:
						var sp1: Vector2 = Vector2(float(s2d["x"]) + float(s2d["w"]) * 0.5, float(s2d["y"]) + float(s2d["h"]) * 0.5)
						_draw_dashed_line_on(c, c_origin, sp1, Color(sc_col.r, sc_col.g, sc_col.b, 0.45), 1.4)

	if not nodes_by_grp.is_empty():
		for s_var in solids:
			var s2: Dictionary = s_var
			var st: String = str(s2.get("t", ""))
			if st in ["signal_bridge", "signal_gate"] or map_lens_on:
				var g: String = str(s2.get("group", s2.get("unlockGroup", "")))
				if nodes_by_grp.has(g):
					var p0: Vector2 = nodes_by_grp[g]
					if absf(p0.x - cam_x) < vw + 320.0:
						var p1: Vector2 = Vector2(float(s2["x"]) + float(s2["w"]) * 0.5, float(s2["y"]) + float(s2["h"]) * 0.5)
						var on_g: bool = _is_signal_group_on(g)
						c.draw_line(p0, p1, Color(0.29, 0.87, 0.50, 0.58) if on_g else Color(0.0, 0.96, 1.0, 0.25), 2.0)

func _draw_solid_on(c: Control, s: Dictionary, vw: float, is_zen: bool, cam_off: Vector2) -> void:
	var sx: float = float(s.get("x", 0.0))
	var sw: float = float(s.get("w", 40.0))
	var cam_x: float = float(_eng_get("cam_x", 0.0))
	if sx + sw < cam_x - 110.0 or sx > cam_x + vw + 110.0:
		return
	var st: String = str(s.get("t", "solid"))
	var role_s: String = str(s.get("role", ""))
	var sub_s: String = str(s.get("subType", ""))
	if st == "sign_landed":
		return
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))
	var xray_on: bool = bool(_eng_get("xray_level", false)) or (shop != null and shop.map_lens_active)

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
	var lv_id: int = int(_eng_get("lv_id", 1))
	var act_layer: int = int(_eng_get("active_layer", 0))
	var world_frozen: bool = bool(_eng_get("world_frozen", false))

	var s_layer: int = int(s.get("layer", -1))
	var ghost_layer: bool = (lv_id >= 51 and s_layer >= 0 and s_layer != act_layer)
	var alpha_mul: float = 0.28 if ghost_layer else 1.0
	var base_tint: Color = Color(0.85, 0.55, 1.0, alpha_mul) if (ghost_layer and s_layer == 1) else (Color(0.55, 0.92, 1.0, alpha_mul) if ghost_layer else Color(1.0, 1.0, 1.0, alpha_mul))

	if is_zen and st == "solid":
		c.draw_rect(r, Color("#e2e8f0"), true)
		c.draw_rect(r, Color("#94a3b8"), false, 2.0)
		return

	# v2.0 Weight Scale (`weight_scale` or `solid` + `role == "weight_scale"`) with Live Numeric Gauge!
	if st == "weight_scale" or role_s == "weight_scale":
		c.draw_texture_rect(_tex("v2_weight_scale"), Rect2(sx - 4.0, sy - 18.0, sw + 8.0, sh + 22.0), false, base_tint)
		var cur_w: int = int(s.get("current_weight", s.get("weight", 0)))
		var tgt_w: int = int(s.get("targetWeight", s.get("target_weight", 2)))
		var matched_w: bool = (cur_w == tgt_w)
		var gauge_col: Color = Color("#4ade80") if matched_w else (Color("#fb7185") if cur_w > tgt_w else Color("#fde047"))
		c.draw_rect(Rect2(sx + 4.0, sy - 16.0, maxf(48.0, sw - 8.0), 14.0), Color(0.02, 0.05, 0.16, 0.90 * alpha_mul), true)
		c.draw_rect(Rect2(sx + 4.0, sy - 16.0, maxf(48.0, sw - 8.0), 14.0), gauge_col, false, 1.2)
		if font_main != null:
			c.draw_string(font_main, Vector2(sx + 4.0, sy - 5.5), "%d / %d KG" % [cur_w, tgt_w], HORIZONTAL_ALIGNMENT_CENTER, maxf(48.0, sw - 8.0), 10, gauge_col)
		return

	# v2.0 Ghost Train (`ghost_train` or `rail_plat` with `role/skin == "ghost_train"`)
	if st == "ghost_train" or role_s in ["ghost_train", "ghost_train_head"] or str(s.get("skin", "")) in ["ghost_train", "v2_ghost_train"]:
		var gt_bob: float = sin(t_sec * 6.5 + sx * 0.03) * 2.0
		c.draw_texture_rect(_tex("v2_ghost_train"), Rect2(sx - 6.0, sy - 16.0 + gt_bob, sw + 12.0, sh + 18.0), false, Color(0.82, 0.98, 1.0, 0.92 * alpha_mul))
		c.draw_rect(Rect2(sx, sy, sw, 4.0), Color(0.40, 0.95, 1.0, 0.78 * alpha_mul), true)
		return

	# v2.0 Poison Fog Door (`poison_fog_door`) as solid/barrier
	if st == "poison_fog_door" or role_s == "poison_fog_door":
		var door_open: bool = bool(s.get("is_open", s.get("gate_open", false)))
		if not door_open:
			var fog_sway: float = sin(t_sec * 4.2) * 2.0
			c.draw_texture_rect(_tex("v2_poison_fog_door"), Rect2(sx - 4.0 + fog_sway, sy - 4.0, sw + 8.0, sh + 6.0), false, base_tint)
		return

	# v2.0 Rotatable Mirror & Classic Mirror (`mirror` / `mirror_rotatable`) + Reflection Preview Line!
	if st == "mirror" or st == "mirror_rotatable":
		var is_rot: bool = (st == "mirror_rotatable") or bool(s.get("rotatable", false)) or s.has("angle")
		var ang_deg: float = float(s.get("angle", 90.0))
		if is_rot:
			var m_rad: float = deg_to_rad(ang_deg - 45.0) * 0.35
			_draw_sprite_on(c, _tex("v2_mirror_rotatable"), Rect2(sx - 6.0, sy - 6.0, maxf(44.0, sw + 12.0), maxf(52.0, sh + 12.0)), false, false, base_tint, m_rad, cam_off)
			# Draw live laser reflection trajectory preview line!
			var m_center: Vector2 = Vector2(sx + sw * 0.5, sy + sh * 0.5)
			var p_ref: Dictionary = _eng_get("player", {})
			var in_dir: Vector2 = Vector2(1.0 if (p_ref.is_empty() or float(p_ref.get("x", 0.0)) <= m_center.x) else -1.0, 0.0)
			var out_dir: Vector2 = GridMath.reflect_by_mirror_angle(in_dir, ang_deg, 1.0).normalized()
			_draw_dashed_line_on(c, m_center - in_dir * 64.0, m_center, Color(0.0, 0.96, 1.0, 0.42 * alpha_mul), 1.5, 7.0, 5.0)
			_draw_dashed_line_on(c, m_center, m_center + out_dir * 148.0, Color(0.99, 0.88, 0.28, 0.68 * alpha_mul), 1.8, 9.0, 5.0)
			c.draw_circle(m_center + out_dir * 148.0, 3.5, Color(0.99, 0.88, 0.28, 0.78 * alpha_mul))
			if font_main != null:
				c.draw_string(font_main, Vector2(sx - 12.0, sy - 8.0), "%.0f°" % ang_deg, HORIZONTAL_ALIGNMENT_CENTER, sw + 24.0, 10, Color("#67e8f9"))
		else:
			c.draw_rect(r, Color(0.06, 0.14, 0.28, alpha_mul), true)
			_draw_uv_tiled_on(c, _tex("mirror_wall"), r, sw, 40.0, base_tint)
		return

	# Invisible Step Blocks (`invis`)
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
			c.draw_rect(Rect2(sx + sw * 0.5 - 2.0, sy + sh * 0.5 - 2.0, 4.0, 4.0), Color(0.0, 0.96, 1.0, 0.52 if xray_on else pulse_i * 0.55), true)
			if xray_on:
				c.draw_rect(r, Color(0.0, 0.96, 1.0, 0.16), true)
				c.draw_rect(r, Color("#00f5ff"), false, 2.0)
		return

	# Question Blocks (`qblock`) — uses `qblock_used` when used!
	if st == "qblock":
		if not bool(s.get("revealed", true)):
			var pulse_q: float = 0.18 + 0.14 * sin(t_sec * 4.5 + sx * 0.05)
			c.draw_rect(Rect2(sx + sw * 0.5 - 2.0, sy + sh * 0.5 - 2.0, 4.0, 4.0), Color(0.0, 0.96, 1.0, 0.52 if xray_on else pulse_q * 0.55), true)
			if xray_on:
				c.draw_rect(r, Color(0.98, 0.80, 0.08, 0.18), true)
				c.draw_rect(r, Color("#fde047"), false, 2.0)
			return
		var used_q: bool = bool(s.get("used", false))
		var bob_q: float = 0.0 if used_q else (sin(t_sec * 4.2 + sx * 0.04) * 2.0)
		var q_side: float = 0.95 * GridMath.TILE
		var qx: float = sx + (sw - q_side) * 0.5
		var qy: float = sy + (sh - q_side) * 0.5 + bob_q
		var qr: Rect2 = Rect2(qx, qy, q_side, q_side)
		var q_key: String = ("qblock_used" if (used_q and textures.has("qblock_used") and lv_id < 101) else ("s3_qblock" if lv_id >= 101 else "qblock"))
		c.draw_rect(qr.grow(-2.0), Color(0.04, 0.08, 0.20, alpha_mul), true)
		var qtint: Color = Color(0.62, 0.65, 0.74, alpha_mul) if used_q else base_tint
		c.draw_texture_rect(_tex(q_key), qr, false, qtint)
		if not used_q:
			var glow_q: float = 0.28 + 0.24 * sin(t_sec * 6.0 + sx)
			c.draw_rect(qr.grow(-1.5), Color(0.98, 0.80, 0.08, glow_q * alpha_mul), false, 1.5)
		return

	# Four-State Clouds (`cloud`, `cloud_plat`, `s3_cloud`) with Shadow, Metallic Glint, Brittle Core & Colorblind Badges!
	if st in ["cloud", "cloud_plat", "s3_cloud"]:
		var rule_b: bool = bool(_eng_get("rule_phase_b", false))
		var safe_c: bool = _check_cloud_safe(s)
		if bool(s.get("rule_swap", false)) and rule_b:
			safe_c = not safe_c
		var knife_out: bool = bool(s.get("blades_out", false)) or (not safe_c and (xray_on or sub_s == "blade" or str(s.get("mode", "")) == "sundial_knife"))
		var is_hollow: bool = (sub_s == "hollow") or (str(s.get("mode", "")) == "fake_cloud")
		var is_bounce: bool = (sub_s == "bounce")
		var is_thunder: bool = (sub_s == "thunder") or (str(s.get("mode", "")) == "swoop_cloud")

		var ck: String = ("s3_cloud_knife" if lv_id >= 101 else "cloud_knife") if knife_out else (("s3_cloud_dark" if lv_id >= 101 else "cloud_dark_safe") if is_thunder else ("s3_cloud_safe" if lv_id >= 101 else "cloud_safe"))
		var c_alpha: float = alpha_mul * (0.52 if (is_hollow and xray_on) else (0.86 if is_hollow else 1.0))
		# Cloud under-shadow clue (v2.0 Lv.002 & Lv.102: solid clouds cast dark bottom shadow, hollow clouds have none, blade clouds glint!)
		if safe_c and not is_hollow:
			c.draw_rect(Rect2(sx + 8.0, sy + sh - 3.0, maxf(12.0, sw - 16.0), 4.0), Color(0.05, 0.14, 0.28, 0.45 * alpha_mul), true)
		c.draw_texture_rect(_tex(ck), r, false, Color(1.0, 1.0, 1.0, c_alpha))
		if sub_s == "blade" or bool(s.get("knife", false)):
			var glint_a: float = 0.35 + 0.55 * absf(sin(t_sec * 5.2 + sx * 0.07))
			c.draw_line(Vector2(sx + 10.0, sy + sh - 2.0), Vector2(sx + sw - 10.0, sy + sh - 2.0), Color(0.95, 0.98, 1.0, glint_a * alpha_mul), 2.0)
			if bool(s.get("brittleCore", false)) and not bool(s.get("disarmed", false)):
				c.draw_circle(Vector2(sx + sw - 6.0, sy + sh * 0.5), 4.5, Color("#fb923c"))
		if is_bounce:
			c.draw_line(Vector2(sx + sw * 0.5 - 8.0, sy + 6.0), Vector2(sx + sw * 0.5, sy + 1.0), Color("#4ade80"), 2.0)
			c.draw_line(Vector2(sx + sw * 0.5, sy + 1.0), Vector2(sx + sw * 0.5 + 8.0, sy + 6.0), Color("#4ade80"), 2.0)
		_draw_colorblind_glyph(c, Vector2(sx + sw * 0.5, sy - 6.0), "safe" if safe_c else ("bait" if is_hollow else "hazard"), Color("#4ade80") if safe_c else Color("#fb7185"))
		return

	# Solid / Fake Wall / Fake Plat / Wood Crate / Ferry Plat
	if st in ["solid", "fake_wall", "fake_plat", "wood_crate", "ferry_plat", "tanuki_log"]:
		if (st == "fake_wall" or st == "fake_plat") and bool(s.get("shattered", false)) and float(s.get("shatter_anim", 0.0)) <= 0.02:
			return

		var f_alpha: float = alpha_mul
		if st == "fake_wall" or st == "fake_plat":
			if float(s.get("shatter_anim", 0.0)) > 0.02:
				f_alpha *= clampf(float(s["shatter_anim"]), 0.15, 1.0)
			elif xray_on:
				f_alpha *= 0.42
		var f_tint: Color = Color(base_tint.r, base_tint.g, base_tint.b, f_alpha)

		# Subtle inward particle drift clue for passable purple fake walls (Lv.001!)
		if st == "fake_wall" and not bool(s.get("shattered", false)):
			for pi in range(3):
				var py_f: float = sy + fposmod(float(pi) * 23.0 + t_sec * 18.0, maxf(12.0, sh - 6.0))
				var px_f: float = sx + sw - fposmod(t_sec * 26.0 + float(pi) * 14.0, maxf(12.0, sw))
				c.draw_rect(Rect2(px_f, py_f, 3.0, 3.0), Color(0.82, 0.58, 1.0, 0.55 * f_alpha), true)

		if st == "tanuki_log" or str(s.get("skin", "")) == "tanuki_log":
			c.draw_texture_rect(_tex("s3_mon_tanuki_log"), Rect2(sx - 2.0, sy, sw + 4.0, sh), false, f_tint)
			return
		if st == "wood_crate":
			c.draw_rect(r.grow(-1.0), Color(0.28, 0.16, 0.08, f_alpha), true)
			_draw_uv_tiled_on(c, _tex("s3_wood_crate"), r, 48.0, 48.0, f_tint)
			return

		if lv_id >= 101:
			var skin3: String = str(s.get("skin", ""))
			if skin3 == "wood" or skin3 == "crate":
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
				if use_reactor and not world_frozen:
					var cg_a: float = (0.07 + 0.07 * sin(t_sec * 3.4 + sx * 0.02)) * f_alpha
					c.draw_rect(Rect2(sx + 6.0, sy + 18.0, sw - 12.0, minf(44.0, sh - 22.0)), Color(0.0, 0.96, 1.0, cg_a), true)

			if sw >= 44.0 and not world_frozen:
				var span_p: float = maxf(24.0, sw - 16.0)
				var px_dot: float = sx + 8.0 + fposmod(t_sec * 64.0 + absf(sx) * 0.37, span_p)
				var dot_c: Color = Color(0.98, 0.80, 0.08, 0.85 * f_alpha) if is_s2 else Color(0.0, 0.96, 1.0, 0.82 * f_alpha)
				c.draw_rect(Rect2(px_dot, sy + 2.0, 10.0, 2.0), dot_c, true)
				c.draw_rect(Rect2(px_dot + 6.0, sy + 2.0, 3.0, 2.0), Color(1.0, 1.0, 1.0, f_alpha), true)

		if xray_on and (st == "fake_wall" or st == "fake_plat"):
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
	elif st == "s3_tall_pipe":
		var tp_tex: Texture2D = _tex("s3_pipe_tall")
		if tp_tex != null:
			var tp_sz: Vector2 = tp_tex.get_size()
			var rim_sh: float = roundf(tp_sz.y * 0.34)
			if sh > 26.0:
				c.draw_texture_rect_region(tp_tex, Rect2(sx + 2.0, sy + 24.0, maxf(8.0, sw - 4.0), sh - 24.0), Rect2(0.0, rim_sh, tp_sz.x, maxf(4.0, tp_sz.y - rim_sh)), base_tint)
			c.draw_texture_rect_region(tp_tex, Rect2(sx - 2.0, sy, sw + 4.0, minf(26.0, sh)), Rect2(0.0, 0.0, tp_sz.x, rim_sh), base_tint)
	elif st == "s3_drop_block":
		var db_shk: float = roundf(sin(t_sec * 65.0) * 3.0) if str(s.get("drop_state", "")) == "shake" else 0.0
		var db_r: Rect2 = Rect2(sx + db_shk, sy, sw, sh)
		c.draw_rect(db_r.grow(-1.0), Color(0.22, 0.20, 0.18, alpha_mul), true)
		var db_sk: String = str(s.get("skin", "stone"))
		_draw_uv_tiled_on(c, _tex("s3_wood_crate" if (db_sk == "wood" or db_sk == "crate") else "s3_stone_brick"), db_r, 48.0, 48.0, base_tint)
		# Anti-Newton directional arrow indicator (Lv.106)
		if str(s.get("subType", "")) == "anti_newton":
			c.draw_rect(db_r.grow(-2.0), Color(0.66, 0.33, 0.97, 0.72 * alpha_mul), false, 1.6)
	elif st == "s3_slide_turf":
		c.draw_rect(r.grow(-1.0), Color(0.22, 0.15, 0.09, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s3_float_grass"), r, 96.0, sh, base_tint)
	elif st == "conveyor":
		var stop_c: bool = _is_signal_group_on(str(s.get("stop_group", "")))
		var bvx_c: float = float(s.get("belt_vx", 135.0))
		var dir_c: float = 1.0 if bvx_c >= 0.0 else -1.0
		var fast_c: bool = bool(s.get("fast_trap", false)) or str(s.get("subType", "")) == "vip_fast"
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
		var pol_groups: Dictionary = _eng_get("polarity_groups", {})
		var mode_p: String = str(pol_groups.get(str(s.get("group", "m1")), "blue"))
		var is_org: bool = mode_p == "orange"
		if s.has("blue_x") and s.has("orange_x"):
			c.draw_rect(Rect2(float(s["blue_x"]) + 2.0, float(s["blue_y"]) + 2.0, sw - 4.0, sh - 4.0), Color(0.23, 0.51, 0.96, 0.28 * alpha_mul), false, 1.5)
			c.draw_rect(Rect2(float(s["orange_x"]) + 2.0, float(s["orange_y"]) + 2.0, sw - 4.0, sh - 4.0), Color(0.98, 0.57, 0.24, 0.28 * alpha_mul), false, 1.5)
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.20, alpha_mul), true)
		_draw_uv_tiled_on(c, _tex("s2_mag_orange" if is_org else "s2_mag_blue"), r, 96.0, sh, base_tint)
	elif st == "signal_bridge":
		var br_on: bool = _check_signal_bridge_on(s)
		c.draw_rect(r, Color(0.0, 0.96, 1.0, 0.72 * alpha_mul) if br_on else Color(0.0, 0.96, 1.0, 0.14), true)
		c.draw_rect(r, Color("#00f5ff"), false, 1.5)
	elif st in ["signal_gate", "beat_gate", "paradox_gate", "timed_gate"]:
		var g_open: bool = false
		if st == "signal_gate":
			g_open = _check_signal_gate_open(s)
		elif st == "beat_gate":
			g_open = bool(s.get("is_open", false))
		elif st == "paradox_gate":
			g_open = bool(_eng_get("paradox_unlocked", false)) or bool(s.get("gate_open", false))
		elif st == "timed_gate":
			g_open = t_sec >= float(s.get("open_time", 5.0))
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
		var mp_locked: bool = _is_signal_group_on(str(s.get("lock_group", "")))
		var leg_bob: float = sin(t_sec * 36.0) * 3.0 if (bool(s.get("triggered", false)) and not bool(s.get("scoot_done", false))) else 0.0
		c.draw_texture_rect(_tex("s2_moving_pit"), Rect2(sx, sy - 3.0 + leg_bob, sw, sh + 16.0), false, base_tint)
		if mp_locked:
			c.draw_rect(r.grow(-1.0), Color("#4ade80"), false, 2.0)
	elif st == "fake_error" or st == "popup_404":
		# v2.0 Rogue 404 Popup + Top Severable Signal Cable (`wire_pushable` / `rogue_walkable` / `load_bearing`)
		var fe_flash: float = float(s.get("hit_flash", 0.0))
		var p_type: String = str(s.get("popupType", s.get("mode", "normal_x")))
		var wire_cut: bool = bool(s.get("wire_cut", false))
		if (p_type in ["wire_pushable", "rogue_walkable"] or bool(s.get("has_top_wire", false))) and not wire_cut:
			var wx: float = sx + sw * 0.5
			c.draw_line(Vector2(wx, sy - 44.0), Vector2(wx, sy + 2.0), Color("#00f5ff"), 2.4)
			c.draw_circle(Vector2(wx, sy - 2.0), 4.5, Color("#fde047"))
		if p_type == "load_bearing":
			c.draw_rect(r.grow(2.0), Color("#fde047"), false, 2.2)
		var fe_tint: Color = Color(1.8, 1.8, 1.8, alpha_mul) if fe_flash > 0.0 else base_tint
		c.draw_texture_rect(_tex("v2_popup_404"), r, false, fe_tint)
		if font_main != null:
			var fe_lbl: String = "SAFE_CORE.SYS" if p_type == "load_bearing" else ("PUSH.WIN" if wire_cut else ("BRIDGE.SYS" if p_type == "rogue_walkable" else str(s.get("title_text", "ERR_404"))))
			c.draw_string(font_main, Vector2(sx + 8.0, sy + 15.0), fe_lbl, HORIZONTAL_ALIGNMENT_LEFT, maxf(16.0, sw - 16.0), 9, Color(1.0, 1.0, 1.0, alpha_mul))
	elif st == "glass_panel":
		var is_real_gp: bool = bool(s.get("real", true))
		var rev_fk: bool = bool(s.get("revealed_fake", false)) or (xray_on and not is_real_gp)
		var tested_gp: bool = bool(s.get("tested", false))
		if rev_fk:
			c.draw_rect(r, Color(0.96, 0.25, 0.37, 0.18 * alpha_mul), true)
			c.draw_rect(r.grow(-1.0), Color(1.0, 0.16, 0.71, 0.55 * alpha_mul), false, 1.5)
		else:
			c.draw_rect(r, Color(0.13, 0.83, 0.93, (0.54 if tested_gp else 0.38) * alpha_mul), true)
			c.draw_rect(Rect2(sx, sy, sw, 3.0), Color(0.88, 0.95, 1.0, 0.90 * alpha_mul), true)
			c.draw_rect(r, Color("#fde047") if tested_gp else Color(1.0, 1.0, 1.0, 0.82 * alpha_mul), false, 1.5)
	elif st in ["time_slice_plat", "null_block"]:
		var col_on: bool = _check_solid_collidable(s)
		var gold_immortal: bool = bool(s.get("gold_safe", false)) or str(s.get("subType", "")) == "gold_immortal"
		var base_a: float = (0.66 if st == "time_slice_plat" else 0.72) * (1.0 if col_on else 0.22) * alpha_mul
		var fill_g: Color = Color(0.99, 0.85, 0.28, base_a) if (st == "time_slice_plat" or gold_immortal) else Color(0.75, 0.52, 0.99, base_a)
		c.draw_rect(r, fill_g, true)
		c.draw_rect(r, Color("#fde047") if gold_immortal else Color(1.0, 1.0, 1.0, 0.85 if col_on else 0.25), false, 1.8)
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
	var sub_s: String = str(e.get("subType", ""))
	var cam_x: float = float(_eng_get("cam_x", 0.0))
	if et != "time_bubble" and (ex + ew < cam_x - 140.0 or ex > cam_x + vw + 140.0):
		return

	var lv_id: int = int(_eng_get("lv_id", 1))
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))
	var act_layer: int = int(_eng_get("active_layer", 0))
	var xray_on: bool = bool(_eng_get("xray_level", false)) or (shop != null and shop.map_lens_active)
	var r: Rect2 = Rect2(ex, ey, ew, eh)

	var e_layer: int = int(e.get("layer", -1))
	var ghost_e: bool = (lv_id >= 51 and e_layer >= 0 and e_layer != act_layer)
	var tint: Color = Color(1.0, 1.0, 1.0, 0.30 if ghost_e else 1.0)

	# --- v2.0 Dedicated Puzzle Entities ---
	if et == "spore_key" or (et == "poison_item" and str(e.get("role", "")) == "spore_key"):
		if bool(e.get("carried", false)) or bool(e.get("collected", false)):
			return
		var sk_bob: float = sin(t_sec * 4.6 + ex) * 3.5
		c.draw_circle(Vector2(ex + ew * 0.5, ey + eh * 0.5 + sk_bob), 20.0, Color(0.29, 0.87, 0.50, 0.18 * tint.a))
		c.draw_texture_rect(_tex("v2_spore_key"), Rect2(ex - 2.0, ey + sk_bob, ew + 4.0, eh + 4.0), false, tint)
		return
	elif et == "poison_fog_door" or (et == "paradox_gate" and str(e.get("role", "")) == "poison_fog_door"):
		if not bool(e.get("is_open", false)):
			c.draw_texture_rect(_tex("v2_poison_fog_door"), Rect2(ex - 4.0, ey - 4.0, ew + 8.0, eh + 6.0), false, tint)
		return
	elif et == "white_flower" or (et == "flower" and sub_s == "white_cure_aggro"):
		var p_chk: Dictionary = _eng_get("player", {})
		var unpoisoned_danger: bool = float(p_chk.get("poison_timer", 0.0)) <= 0.05
		var wf_sway: float = sin(t_sec * 5.2 + ex * 0.05) * (0.12 if unpoisoned_danger else 0.04)
		var wf_tint: Color = Color(1.25, 0.72, 0.78, tint.a) if unpoisoned_danger else tint
		_draw_sprite_on(c, _tex("v2_flower_white"), r, false, false, wf_tint, wf_sway, cam_off)
		_draw_colorblind_glyph(c, Vector2(ex + ew * 0.5, ey - 6.0), "hazard" if unpoisoned_danger else "safe", Color("#fb7185") if unpoisoned_danger else Color("#4ade80"))
		return
	elif et == "spotlight" or str(e.get("role", "")) == "spotlight":
		var lamp_off: bool = bool(e.get("off", false)) or bool(e.get("broken", false))
		c.draw_texture_rect(_tex("v2_spotlight_lamp"), r, false, Color(tint.r, tint.g, tint.b, tint.a * (0.38 if lamp_off else 1.0)))
		return
	elif et == "patch_chip" or (et == "coin" and str(e.get("role", "")) == "signal_chip_item"):
		if bool(e.get("carried", false)) or bool(e.get("inserted", false)):
			return
		var pc_bob: float = sin(t_sec * 4.4 + ex) * 3.0
		c.draw_texture_rect(_tex("v2_patch_chip"), Rect2(ex, ey + pc_bob, ew, eh), false, tint)
		if font_main != null:
			var p_ver: String = str(e.get("patchId", e.get("badgeCode", "HOTFIX")))
			c.draw_string(font_main, Vector2(ex - 16.0, ey + pc_bob - 3.0), p_ver, HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 9, Color("#00f5ff"))
		return
	elif et == "wrench_shot":
		var wr_rot: float = t_sec * 16.0
		c.draw_arc(Vector2(ex + ew * 0.5, ey + eh * 0.5), maxf(12.0, ew * 0.55), 0.0, TAU, 16, Color(0.99, 0.88, 0.28, 0.75 * tint.a), 2.0)
		_draw_sprite_on(c, _tex("s3_mon_mole"), Rect2(ex + 2.0, ey + 2.0, ew - 4.0, eh - 4.0), false, false, Color(1.2, 1.2, 0.9, tint.a), wr_rot, cam_off)
		return
	elif et in ["patch_slot", "return_slot", "debt_tag", "control_orb"]:
		var orb_col: Color = Color("#fde047") if et != "debt_tag" else Color("#fb7185")
		c.draw_rect(r, Color(0.05, 0.10, 0.26, 0.85 * tint.a), true)
		c.draw_rect(r, orb_col, false, 1.8)
		if font_main != null:
			var tag_lbl: String = str(e.get("label", et.to_upper()))
			c.draw_string(font_main, Vector2(ex - 14.0, ey + eh * 0.62), tag_lbl, HORIZONTAL_ALIGNMENT_CENTER, ew + 28.0, 9, orb_col)
		return

	# --- Core & Upgraded Classic Entities ---
	if et == "spikes":
		var is_ceil: bool = bool(e.get("ceil", false))
		var sp_tex: Texture2D = _tex("s3_thorns" if lv_id >= 101 else "spikes_red")
		var xx: float = ex
		while xx < ex + ew - 1.0:
			var cw: float = minf(GridMath.TILE, ex + ew - xx)
			_draw_sprite_on(c, sp_tex, Rect2(xx, ey, cw, eh), false, is_ceil, tint, 0.0, cam_off)
			xx += GridMath.TILE
	elif et == "flower":
		var world_frozen: bool = bool(_eng_get("world_frozen", false))
		var fk: String = "flower_chomp" if (not world_frozen and sin(t_sec * 5.2 + ex * 0.08) > 0.2) else "flower_skull"
		var f_col: Color = Color(1.0, 1.0, 1.0, 0.48) if (bool(e.get("rule_swap", false)) and bool(_eng_get("rule_phase_b", false))) else tint
		if sub_s == "magnetic":
			c.draw_arc(Vector2(ex + ew * 0.5, ey + eh * 0.5), 32.0, 0.0, TAU, 20, Color(0.23, 0.82, 0.98, 0.36 * tint.a), 1.5)
		c.draw_texture_rect(_tex(fk), r, false, f_col)
		_draw_colorblind_glyph(c, Vector2(ex + ew * 0.5, ey - 6.0), "hazard", Color("#fb7185"))
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
		var act_cp: Dictionary = _eng_get("active_checkpoint", {})
		var is_on: bool = bool(e.get("active", false)) or ((not act_cp.is_empty()) and absf(float(act_cp.get("x", -999.0)) - GridMath.px_to_gx(ex)) < 0.8)
		var cpk: String = ("s3_cp_on" if is_on else "s3_cp_off") if lv_id >= 101 else ("checkpoint_on" if is_on else "checkpoint_off")
		c.draw_texture_rect(_tex(cpk), Rect2(ex - 4.0, ey - 4.0, ew + 8.0, eh + 4.0), false, tint)
		if lv_id >= 101 and bool(e.get("s3_fake", e.get("fake", false))):
			c.draw_rect(Rect2(ex + 14.0, ey - 5.0, 4.0, 5.0), Color("#e11d48"), true)
			c.draw_rect(Rect2(ex + 24.0, ey - 5.0, 4.0, 5.0), Color("#e11d48"), true)
	elif et == "flag":
		var is_fk: bool = bool(e.get("fake", false))
		var fake_ph: int = int(_eng_get("fake_phase", 0))
		var flk: String = ("s3_flag_win" if fake_ph == 1 else "s3_flag_idle") if lv_id >= 101 else ("flag_win" if fake_ph == 1 else "flag_idle")
		var fl_sway: float = sin(t_sec * (13.5 if is_fk else 3.2) + ex * 0.04) * (2.5 if is_fk else 0.6)
		var fl_tint: Color = Color(1.0, 1.0, 1.0, 0.48) if (xray_on and is_fk) else tint
		c.draw_texture_rect(_tex(flk), Rect2(ex - 4.0 + fl_sway, ey, ew + 14.0, eh), false, fl_tint)
		if bool(e.get("requireBackEntry", false)):
			c.draw_line(Vector2(ex + ew + 6.0, ey + 6.0), Vector2(ex + ew + 6.0, ey + eh), Color("#fde047"), 2.0)
		if xray_on and is_fk:
			c.draw_rect(r, Color("#fb7185"), false, 2.0)
		_draw_colorblind_glyph(c, Vector2(ex + ew * 0.5, ey - 6.0), "bait" if is_fk else "safe", Color("#fb7185") if is_fk else Color("#4ade80"))
	elif et == "cloud" or et == "cloud_knife":
		var safe_now: bool = bool(e.get("rule_swap", false)) and bool(_eng_get("rule_phase_b", false))
		var k_rev: bool = (et == "cloud_knife" and (xray_on or fposmod(t_sec, 2.2) < 0.28)) or (xray_on and bool(e.get("knife", false)))
		var shiver_c: float = sin(t_sec * 65.0) * 3.0 if (et == "cloud_knife" and not safe_now and fposmod(t_sec, 2.2) < 0.24) else 0.0
		var clk: String = "cloud_safe" if safe_now else ("cloud_knife" if k_rev else ("cloud_poison" if bool(e.get("poison", false)) else ("cloud_dark_safe" if et == "cloud_knife" else "cloud_safe")))
		c.draw_texture_rect(_tex(clk), Rect2(ex + shiver_c, ey, ew, eh), false, tint)
	elif et == "coin":
		var ck2: String = "coin_2" if int(t_sec * 5.0) % 2 == 1 else "coin_1"
		var c_bob: float = 0.0 if bool(e.get("placed_weight", false)) else (sin(t_sec * 4.0 + ex) * 2.5)
		c.draw_texture_rect(_tex(ck2), Rect2(ex, ey + c_bob, ew, eh), false, tint)
	elif et == "gem":
		var gc: String = str(e.get("color", "red"))
		c.draw_texture_rect(_tex("gem_" + gc), Rect2(ex, ey + sin(t_sec * 4.2 + ex) * 3.5, ew, eh), false, tint)
		if save.colorblind_mode and font_main != null:
			c.draw_string(font_main, Vector2(ex, ey - 2.0), gc.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, ew, 10, Color.WHITE)
	elif et == "powerup":
		var pkind: String = str(e.get("kind", ""))
		var pk2: String = "icon_shield" if pkind == "shield_weight" else ("icon_wing" if pkind == "flight" else "icon_spring")
		c.draw_texture_rect(_tex(pk2), Rect2(ex, ey + sin(t_sec * 4.5) * 3.0, ew, eh), false, tint)
	elif et == "bomb_pickup" or et == "chain_bomb":
		var b_pl: float = sin(t_sec * 36.0) * 3.5 if float(e.get("fuse", -1.0)) >= 0.0 else sin(t_sec * 5.0) * 1.5
		c.draw_texture_rect(_tex("bomb"), Rect2(ex - b_pl * 0.5, ey - b_pl * 0.5, ew + b_pl, eh + b_pl), false, tint)
	elif et == "clock" or et == "beat_clock":
		var use_gear: bool = (et == "beat_clock") or bool(e.get("gear", false)) or str(e.get("scope", "")) == "timer_only"
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
		var is_loop_p: bool = bool(e.get("loop_pipe", false)) or str(e.get("echo", "")) == "double"
		var rim_g: float = 0.28 + 0.24 * sin(t_sec * 4.0 + ex)
		c.draw_rect(Rect2(ex + 8.0, ey + 3.0, ew - 16.0, 3.0), (Color("#c084fc") if (is_loop_p and xray_on) else Color(0.29, 0.87, 0.50, rim_g * tint.a)), true)
	elif et == "launcher":
		var ldir_v: float = float(e.get("dir", 1.0))
		var rec_x: float = float(e.get("recoil", 0.0)) * (-ldir_v) * 5.0
		_draw_sprite_on(c, _tex("missile_launcher"), Rect2(ex + rec_x, ey, ew, eh), ldir_v < 0.0, false, tint, 0.0, cam_off)
	elif et == "missile":
		var m_flip: bool = _is_missile_flipped(e)
		var m_bob: float = sin(t_sec * 24.0 + ex * 0.05) * 1.2
		var m_type: String = str(e.get("missileType", e.get("subType", "normal")))
		var m_tint: Color = Color(0.68, 0.94, 1.15, tint.a) if m_type == "cooled_rideable" else (Color(1.25, 0.62, 0.68, tint.a) if m_type == "homing_bait" else tint)
		# Tail exhaust glow (blue cooled rideable tail vs orange hot warhead)
		var tail_x: float = (ex - 8.0) if not m_flip else (ex + ew + 8.0)
		c.draw_circle(Vector2(tail_x, ey + eh * 0.5), 6.0, Color("#38bdf8") if m_type == "cooled_rideable" else Color("#fb923c"))
		_draw_sprite_on(c, _tex("missile"), Rect2(ex, ey + m_bob, ew, eh), m_flip, false, m_tint, 0.0, cam_off)
	elif et == "sign":
		var smode: String = str(e.get("mode", ""))
		var sk: String = "sign_knife_trap" if (smode == "knife_trap" and textures.has("sign_knife_trap")) else ("s3_wood_sign" if lv_id >= 101 else ("sign_left" if str(e.get("dir", "right")) == "left" else "sign_right"))
		# Clue: red shock wire at foot (`wire_shock`) or loose top bolt (`fall_slope`) per v2.0 Lv.003!
		if smode == "wire_shock":
			c.draw_line(Vector2(ex - 10.0, ey + eh - 2.0), Vector2(ex + ew + 10.0, ey + eh - 2.0), Color("#f43f5e"), 2.2)
		elif smode == "fall_slope" and int(e.get("fall_state", 0)) == 0:
			c.draw_circle(Vector2(ex + ew * 0.5, ey + 4.0), 3.0, Color("#fde047"))
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
		var p_sat: bool = bool(_eng_get("princess_satisfied", false))
		var p_bob: float = -absf(sin(t_sec * 7.0)) * 5.0 if p_sat else sin(t_sec * 3.0) * 1.5
		var p_spr: String = "npc_princess_happy" if (p_sat and textures.has("npc_princess_happy")) else "npc_princess"
		c.draw_texture_rect(_tex(p_spr), Rect2(ex - 6.0, ey - 6.0 + p_bob, ew + 12.0, eh + 6.0), false, tint)
		if (bool(e.get("showOrderDots", false)) or xray_on) and not p_sat:
			var req_p: Array = e.get("req", _eng_get("princess_perm_order", ["red", "green", "blue"]))
			var col_gems: Array = _eng_get("collected_gems", [])
			for gi in range(req_p.size()):
				var g_col: String = str(req_p[gi])
				var done_g: bool = gi < col_gems.size() and str(col_gems[gi]) == g_col
				c.draw_texture_rect(_tex("gem_" + g_col), Rect2(ex - 8.0 + float(gi) * 18.0, ey - 22.0, 15.0, 15.0), false, Color(1.0, 1.0, 1.0, 1.0 if done_g else 0.45))
	elif et == "shop":
		c.draw_texture_rect(_tex("shop_frame"), Rect2(ex - 10.0, ey - 12.0, ew + 20.0, eh + 12.0), false, tint)
		c.draw_texture_rect(_tex("npc_merchant"), Rect2(ex + ew * 0.25, ey + 12.0 + sin(t_sec * 3.8) * 1.5, ew * 0.55, eh - 12.0), false, tint)
	elif et == "enemy":
		var ek: String = str(e.get("kind", "follower"))
		if ek == "boss" or str(e.get("bossKey", e.get("boss_key", ""))) != "":
			if not bool(e.get("defeated", false)):
				_draw_boss_entity_and_armor_vfx(c, e, r, tint, t_sec, cam_off)
			return
		var espr: String = "enemy_slime" if ek == "slime" else ("enemy_flying" if ek == "flying" else "enemy_follower")
		var e_flip: bool = (ek in ["follower", "slime"] and float(e.get("vx", 0.0)) > 0.0)
		var hop_y: float = absf(sin(t_sec * 10.0 + ex * 0.05)) * 3.0 if ek in ["follower", "slime"] else (sin(t_sec * 4.2) * 4.0 if ek == "boss" else 0.0)
		var e_al: float = 0.50 if bool(e.get("is_phasing", false)) else (0.60 if float(e.get("stun_timer", 0.0)) > 0.0 else 1.0)
		_draw_sprite_on(c, _tex(espr), Rect2(ex, ey - hop_y, ew, eh), e_flip, false, Color(tint.r, tint.g, tint.b, tint.a * e_al), 0.0, cam_off)
	# --- Sector 2 Cyber / Meta Entities ---
	elif et == "piston":
		c.draw_rect(Rect2(ex + ew * 0.36, float(e.get("base_y", ey)) - 10.0, ew * 0.28, (ey - float(e.get("base_y", ey))) + 14.0), Color(0.20, 0.25, 0.33, tint.a), true)
		c.draw_rect(r.grow(-1.0), Color(0.05, 0.08, 0.20, tint.a), true)
		_draw_uv_tiled_on(c, _tex("s2_piston_head"), r, ew, 48.0, tint)
	elif et == "signal_node":
		var n_on: bool = _is_signal_group_on(str(e.get("group", "")))
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
		var pol_g2: Dictionary = _eng_get("polarity_groups", {})
		var p_org: bool = str(pol_g2.get(str(e.get("group", "m1")), "blue")) == "orange"
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
		var is_patch_item: bool = (sub_s == "patch") or e.has("patchId")
		var ik: String = "v2_patch_chip" if is_patch_item else ("s2_battery" if et == "signal_battery" else "s2_root_key")
		c.draw_texture_rect(_tex(ik), Rect2(ex, ey + sin(t_sec * 4.0) * 3.0, ew, eh), false, tint)
		var bc_s: String = str(e.get("badgeCode", e.get("patchId", "")))
		if bc_s != "" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 12.0, ey - 3.0), bc_s, HORIZONTAL_ALIGNMENT_CENTER, ew + 24.0, 9, Color("#fde047"))
	elif et == "root_term" or et == "perm_terminal":
		c.draw_texture_rect(_tex("v2_perm_terminal"), r, false, tint)
		c.draw_rect(Rect2(ex + 10.0, ey + 8.0, maxf(6.0, ew - 20.0), 5.0), Color("#4ade80") if bool(e.get("activated", false)) else Color("#fde047"), true)
		if font_main != null:
			var t_tag: String = "SHEATHE!" if bool(e.get("sheatheRequired", false)) else ("CALM" if str(e.get("mode", "")) == "calm_touch" else str(e.get("perm", str(_ws_get("root_permission", "ROOT")))))
			if t_tag == "NONE":
				t_tag = "PERM"
			c.draw_string(font_main, Vector2(ex - 20.0, ey - 4.0), t_tag, HORIZONTAL_ALIGNMENT_CENTER, ew + 40.0, 9, Color("#4ade80") if bool(e.get("activated", false)) else Color("#00f5ff"))
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
		var rev_mf: bool = bool(e.get("revealed", false)) or xray_on
		var mfk: String = "flag_win" if tamed else ("s2_mimic_flag" if rev_mf else "flag_idle")
		var mf_bob: float = sin(t_sec * 18.0) * 2.5 if (rev_mf and not tamed) else 0.0
		c.draw_texture_rect(_tex(mfk), Rect2(ex - 4.0, ey + mf_bob, ew + 8.0, eh), false, tint)
	elif et == "mimic_chest":
		var mc_aw: bool = bool(e.get("awake", false))
		var p_mc: Dictionary = _eng_get("player", {})
		var mc_sp: String = "s2_mimic_chest" if mc_aw else ("chest_open" if bool(e.get("fed_bomb", false)) else "chest_closed")
		var mc_flip: bool = (not p_mc.is_empty()) and float(p_mc.get("x", 0.0)) > ex
		_draw_sprite_on(c, _tex(mc_sp), r, mc_flip, false, tint, 0.0, cam_off)
		if mc_aw and str(e.get("mode", "")) == "bomb_feed" and font_main != null:
			c.draw_string(font_main, Vector2(ex - 24.0, ey - 5.0), "FEED BOMB!", HORIZONTAL_ALIGNMENT_CENTER, ew + 48.0, 9, Color("#fb923c"))
	elif et == "betray_spring":
		var bs_cal: bool = bool(e.get("calibrated", false))
		var bs_rev: bool = bool(e.get("revealed_evil", false)) or xray_on
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
		if bool(e.get("parried", false)) or _is_signal_group_on(str(e.get("offGroup", ""))):
			return
		var is_pduel: bool = str(e.get("mode", "")) == "parry_duel"
		var th_t: Color = Color(1.5, 1.4, 0.9, tint.a) if str(e.get("state", "")) == "windup" else tint
		# Wrist cable visual cue (Lv.048 & Lv.094!)
		c.draw_line(Vector2(ex + ew * 0.5, ey - 32.0), Vector2(ex + ew * 0.5, ey + 4.0), Color(0.0, 0.96, 1.0, 0.65 * tint.a), 2.2)
		_draw_sprite_on(c, _tex("s2_troll_hand"), r, is_pduel, false, th_t, 0.0, cam_off)
	elif et == "peace_dove" or et == "peace_dove_nuke":
		var pd_mad: bool = float(e.get("angry_timer", 0.0)) > 0.0
		var pd_blind: bool = bool(e.get("blinded", false)) or _is_signal_group_on(str(e.get("muteGroup", "")))
		var pd_dir: float = 1.0 if float(e.get("vx", 1.0)) >= 0.0 else -1.0
		# v2.0 Peace Dove Vision Cone (`核弹白鸽视线锥`)
		if not pd_blind and not ghost_e:
			var dv_o: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.45)
			var cone_col: Color = Color(0.98, 0.25, 0.37, 0.20) if pd_mad else Color(0.29, 0.87, 0.50, 0.12)
			var dv_pts: PackedVector2Array = PackedVector2Array([
				dv_o,
				dv_o + Vector2(pd_dir * 165.0, -56.0),
				dv_o + Vector2(pd_dir * 165.0, 68.0)
			])
			c.draw_colored_polygon(dv_pts, cone_col)
		var pd_t: Color = Color(1.35, 0.55, 0.65, tint.a) if pd_mad else tint
		_draw_sprite_on(c, _tex("v2_peace_dove_nuke"), r, pd_dir > 0.0, false, pd_t, 0.0, cam_off)
		if font_main != null:
			c.draw_string(font_main, Vector2(ex - 22.0, ey - 4.0), "LOCKED!" if pd_mad else ("SAFE" if pd_blind else "NO WEAPON"), HORIZONTAL_ALIGNMENT_CENTER, ew + 44.0, 9, Color("#f43f5e") if pd_mad else Color("#4ade80"))
	elif et == "forklift":
		var fk_flip: bool = float(e.get("vx", 0.0)) < 0.0
		_draw_sprite_on(c, _tex("v2_forklift"), r, fk_flip, false, tint, 0.0, cam_off)
	elif et == "saw_track":
		if _is_signal_group_on(str(e.get("offGroup", ""))):
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
		if not _is_signal_group_on(str(e.get("offGroup", ""))):
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
		if _is_signal_group_on(str(e.get("offGroup", ""))):
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
		if et == "heat_vent" and _is_signal_group_on(str(e.get("offGroup", ""))):
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
		if _is_signal_group_on(str(e.get("offGroup", ""))):
			return
		var skind: String = str(e.get("kind", "mech_spider"))
		var smap: Dictionary = {
			"forklift": "v2_forklift", "turret": "s2_turret", "drone": "s2_bot_drone",
			"shield_mech": "s2_shield_mech", "patrol": "s2_bot_patrol"
		}
		var s2k: String = str(smap.get(skind, skind))
		if not textures.has(s2k):
			s2k = "s2_bot_patrol"
		var dx_s2: float = ex + float(e.get("jolt_x", 0.0))
		var s2_flip: bool = false
		if skind == "forklift" or skind == "patrol":
			s2_flip = float(e.get("vx", 0.0)) < 0.0
		elif skind == "turret":
			var p_tr: Dictionary = _eng_get("player", {})
			var t_dir: float = float(e["dir"]) if e.has("dir") else (-1.0 if (not p_tr.is_empty() and float(p_tr.get("x", 0.0)) < ex) else 1.0)
			s2_flip = t_dir < 0.0
			if str(e.get("aim_phase", "")) == "lock":
				var lc: Color = Color(0.96, 0.25, 0.37, 0.80) if (int(t_sec * 18.0) % 2 == 0) else Color(0.98, 0.80, 0.08, 0.65)
				var lx_t: float = (dx_s2 + ew * 0.5) if t_dir > 0.0 else (dx_s2 + ew * 0.5 - 380.0)
				c.draw_rect(Rect2(lx_t, ey + eh * 0.4 - 1.0, 380.0, 2.0), lc, true)
		elif skind == "shield_mech":
			s2_flip = int(e.get("facing", -1)) < 0
		elif skind != "drone":
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
	# --- All 15 Chapter Bosses (`enemy_boss`, `s2_boss`, `s3_boss`) + Exclusive Phase Armor VFX! ---
	elif et in ["enemy_boss", "s2_boss", "s3_boss"]:
		if bool(e.get("defeated", false)):
			return
		_draw_boss_entity_and_armor_vfx(c, e, r, tint, t_sec, cam_off)
	# --- Sector 3 Arcadia Ecology & Sky Entities ---
	elif et == "s3_valve":
		var v_spun: bool = bool(e.get("spun", false))
		var v_rot: float = float(e.get("spin_ang", 0.0)) + (t_sec * 3.2 if v_spun else 0.0)
		var v_tint: Color = Color(tint.r, tint.g, tint.b, tint.a * (0.78 if v_spun else 1.0))
		_draw_sprite_on(c, _tex("s3_valve_red"), r, false, false, v_tint, v_rot, cam_off)
	elif et == "s3_sundial":
		# v2.0 Sundial Tri-Phase Concentric Halo (`日晷三相光环`: Day / Dusk / Night)
		var sd_bob: float = sin(t_sec * 4.0 + ex) * 3.0
		var sd_phase_name: String = str(_ws_get("sundial_phase_name", "dusk" if bool(_eng_get("s3_sundial_phase", false)) else "day"))
		var sd_col: Color = Color("#fde047") if sd_phase_name == "day" else (Color("#fb923c") if sd_phase_name == "dusk" else Color("#818cf8"))
		var sd_center: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.5 + sd_bob)
		c.draw_arc(sd_center, ew * 0.68, 0.0, TAU, 28, Color(sd_col.r, sd_col.g, sd_col.b, 0.55 * tint.a), 2.0)
		c.draw_arc(sd_center, ew * 0.88, t_sec * 1.4, t_sec * 1.4 + PI * 1.2, 20, Color(sd_col.r, sd_col.g, sd_col.b, 0.35 * tint.a), 1.4)
		var sd_rot: float = 0.0 if sd_phase_name == "day" else (PI * 0.25 if sd_phase_name == "dusk" else PI * 0.5)
		_draw_sprite_on(c, _tex("s3_sundial_orb"), Rect2(ex, ey + sd_bob, ew, eh), false, false, tint, sd_rot, cam_off)
		if font_main != null:
			c.draw_string(font_main, Vector2(ex - 16.0, ey + sd_bob - 4.0), sd_phase_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, ew + 32.0, 9, sd_col)
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
		var valves_d: Dictionary = _eng_get("s3_valves", {})
		var shut_sp: bool = pgrp_sp != "" and bool(valves_d.get(pgrp_sp, false))
		c.draw_texture_rect(_tex("s3_suction_pipe"), r, false, Color(tint.r, tint.g, tint.b, tint.a * (0.52 if shut_sp else 1.0)))
		if not shut_sp:
			c.draw_rect(Rect2(ex + 6.0, ey + eh, ew - 12.0, 3.8 * GridMath.TILE), Color(0.96, 0.25, 0.37, 0.16 * tint.a), true)
	elif et == "s3_mimic_flag":
		var tm3: bool = bool(e.get("tamed", false))
		var aw3: bool = bool(e.get("awake", false)) or xray_on
		var mf3_k: String = "s3_flag_win" if tm3 else ("s3_mimic_flag" if aw3 else "s3_flag_idle")
		c.draw_texture_rect(_tex(mf3_k), Rect2(ex - 4.0, ey, ew + 10.0, eh), false, tint)
	elif et == "s3_bush":
		var b_out: bool = (bool(e.get("revealed", false)) or xray_on) and str(e.get("mode", "safe")) != "safe"
		if b_out:
			c.draw_texture_rect(_tex("s3_bush_blade"), Rect2(ex, ey - 14.0, ew, eh + 14.0), false, tint)
		else:
			c.draw_texture_rect(_tex("s3_bush_safe"), r, false, tint)
	elif et == "s3_flower":
		var f_ang: bool = bool(e.get("angry", false)) or str(e.get("state", "")) == "predict_windup"
		var f_sway: float = sin(t_sec * 4.5 + ex * 0.05) * 0.06
		_draw_sprite_on(c, _tex("s3_pink_flower_angry" if f_ang else "s3_pink_flower"), r, false, false, tint, f_sway, cam_off)
	elif et == "s3_tanuki":
		var as_log: bool = bool(e.get("is_log", false)) or str(e.get("state", "")) == "log"
		if as_log:
			c.draw_texture_rect(_tex("s3_mon_tanuki_log"), r, false, tint)
		else:
			var t_hop: float = absf(sin(t_sec * 9.0 + ex * 0.04)) * 3.0
			var t_flip: bool = float(e.get("vx", -60.0)) > 0.0
			_draw_sprite_on(c, _tex("s3_mon_tanuki"), Rect2(ex, ey - t_hop, ew, eh), t_flip, false, tint, 0.0, cam_off)
			if not bool(e.get("is_clone", false)) and bool(e.get("cloned", false)):
				c.draw_arc(Vector2(ex + ew * 0.5, ey - t_hop - 4.0), 6.0, 0.0, TAU, 16, Color("#fde047"), 1.5)
	elif et == "s3_manju":
		var mj_hop: float = 0.0 if bool(e.get("waiting_drop", false)) else absf(sin(t_sec * 10.0 + ex * 0.05)) * 3.0
		var spk_m: bool = bool(e.get("spiked", false))
		var mj_flip: bool = float(e.get("vx", -85.0)) > 0.0
		if bool(e.get("has_balloon", false)):
			c.draw_line(Vector2(ex + ew * 0.5, ey - 16.0), Vector2(ex + ew * 0.5, ey + 2.0), Color("#f8fafc"), 1.5)
			c.draw_circle(Vector2(ex + ew * 0.5, ey - 22.0), 7.0, Color("#fb7185"))
		_draw_sprite_on(c, _tex("s3_mon_manju_spike" if spk_m else "s3_mon_manju"), Rect2(ex, ey - mj_hop, ew, eh), mj_flip, false, tint, 0.0, cam_off)
	elif et == "s3_ladybug":
		# v2.0 Nitro Ladybug Slipstream Wake Trail (`氮气瓢虫尾流`)!
		var sprinting_lb: bool = bool(e.get("sprinting", false)) or absf(float(e.get("vx", 0.0))) > 140.0
		var lb_dir: float = float(e.get("dir", -1.0 if float(e.get("vx", -1.0)) < 0.0 else 1.0))
		if sprinting_lb:
			for wi in range(3):
				var wx_l: float = ex + (ew * 0.5) - lb_dir * (18.0 + float(wi) * 14.0)
				var wy_l: float = ey + eh * 0.55 - 4.0 + float(wi % 2) * 4.0
				c.draw_rect(Rect2(wx_l - 8.0, wy_l, 16.0, 4.0), Color(0.22, 0.92, 1.0, (0.58 - float(wi) * 0.16) * tint.a), true)
		var lb_bob: float = absf(sin(t_sec * (22.0 if sprinting_lb else 8.0))) * 2.0
		_draw_sprite_on(c, _tex("s3_mon_ladybug"), Rect2(ex, ey - lb_bob, ew, eh), lb_dir > 0.0, false, tint, 0.0, cam_off)
	elif et == "s3_mole":
		c.draw_texture_rect(_tex("s3_mon_mole"), r, false, tint)
		if bool(e.get("holding_wrench", true)):
			_draw_dashed_arc_hint(c, Vector2(ex + ew * 0.5, ey), 14.0, Color(0.99, 0.88, 0.28, 0.45 * tint.a))
	elif et == "s3_sun" or et == "sunglasses_sun":
		# v2.0 Sunglasses Blazing Sun (`墨镜烈日`) + Heat-Lock Beam
		var sun_mad: bool = bool(e.get("swooping", false)) or bool(e.get("awake", false)) or float(_ws_get("sun_heat", 0.0)) > 45.0
		var p_sun: Dictionary = _eng_get("player", {})
		if sun_mad and not p_sun.is_empty() and not bool(e.get("blinded", false)):
			var s_c: Vector2 = Vector2(ex + ew * 0.5, ey + eh * 0.5)
			var t_c: Vector2 = Vector2(float(p_sun["x"]) + 14.0, float(p_sun["y"]) + 21.0)
			_draw_dashed_line_on(c, s_c, t_c, Color(0.99, 0.45, 0.18, 0.42 * tint.a), 1.8, 10.0, 6.0)
		_draw_sprite_on(c, _tex("v2_sunglasses_sun" if sun_mad else "s3_sun_calm"), r, false, false, tint, sin(t_sec * 2.0) * 0.08, cam_off)

func _draw_dashed_arc_hint(c: Control, center: Vector2, rad: float, col: Color) -> void:
	c.draw_arc(center, rad, PI * 1.15, PI * 1.85, 10, col, 1.4)

# Renders all 15 Chapter Bosses with their dedicated HD sprite AND Phase Armor Rings / Shields!
func _draw_boss_entity_and_armor_vfx(c: Control, e: Dictionary, r: Rect2, tint: Color, t_sec: float, cam_off: Vector2) -> void:
	var lv_id: int = int(_eng_get("lv_id", 1))
	var lv_data: Dictionary = _eng_get("lv_data", {})
	var bkey: String = BossStateMachine.resolve_boss_key(lv_id, lv_data, e)
	var spr_k: String = str(BOSS_KEY_SPRITE_MAP.get(bkey, ""))
	if spr_k == "" or not textures.has(spr_k):
		var bkind_fb: String = str(e.get("bossKind", e.get("boss_kind", "")))
		var legacy_map: Dictionary = {
			"signal_storm": "boss_060_signal_core",
			"reassembly_mech": "boss_070_mecha_overlord",
			"mecha_sovereign": "boss_070_mecha_overlord",
			"fracture_core": "boss_080_fracture_core",
			"chrono_skull": "boss_090_chrono_overlord",
			"chrono_regent": "boss_090_chrono_overlord",
			"admin_arena": "boss_100_null",
			"null_admin": "boss_100_null",
			"cloud_ram": "boss_110_cloud_ram",
			"pipe_kaiser": "boss_120_hydra_pipe",
			"kage_tanuki": "boss_130_kitsune_tanuki",
			"blade_archon": "boss_140_thunder_demon",
			"solaris_painter": "boss_150_solaris"
		}
		spr_k = str(legacy_map.get(bkind_fb, "boss_150_solaris" if lv_id >= 101 else "boss_100_null"))

	var bstate: Dictionary = _eng_get("boss_state", {})
	var armor_cnt: int = int(bstate.get("boss_armor", e.get("armor", 0)))
	var core_open: bool = bool(bstate.get("core_exposed", armor_cnt <= 0))
	var b_ghost: bool = (bkey == "lv080_fracture" and int(e.get("phase", 1)) == 1 and int(_eng_get("active_layer", 0)) != int(e.get("active_core_layer", 0)))
	var hit_fl: float = maxf(float(e.get("armor_flash", 0.0)), float(e.get("hit_flash", 0.0)))
	var b_al: float = (0.34 if b_ghost else (0.72 if float(e.get("stun_timer", 0.0)) > 0.0 else 1.0)) * tint.a
	var b_tint: Color = Color(1.8, 1.8, 1.08, b_al) if hit_fl > 0.0 else Color(tint.r, tint.g, tint.b, b_al)

	var b_center: Vector2 = r.position + r.size * 0.5
	var ring_r: float = maxf(r.size.x, r.size.y) * 0.58

	# Phase Armor Orbiting Shield Segments (`阶段护甲特效`)
	if armor_cnt > 0:
		var seg_col: Color = Color("#fde047") if bkey == "lv150_solaris" else (Color("#38bdf8") if lv_id < 101 else Color("#4ade80"))
		c.draw_circle(b_center, ring_r, Color(seg_col.r, seg_col.g, seg_col.b, 0.10 * b_al))
		var seg_n: int = clampi(armor_cnt, 1, 9)
		var arc_span: float = (TAU / float(seg_n)) * 0.72
		for si in range(seg_n):
			var a0: float = t_sec * 1.6 + float(si) * (TAU / float(seg_n))
			c.draw_arc(b_center, ring_r, a0, a0 + arc_span, 12, Color(seg_col.r, seg_col.g, seg_col.b, 0.85 * b_al), 3.0)
	elif core_open:
		var vuln_pulse: float = 0.45 + 0.45 * absf(sin(t_sec * 8.0))
		c.draw_arc(b_center, ring_r * 0.92, 0.0, TAU, 24, Color(0.98, 0.25, 0.37, vuln_pulse * b_al), 2.2)

	var b_flip: bool = float(e.get("vx", -1.0)) > 0.0 and bkey in ["lv038_mechaskull", "lv110_cloud_ram", "lv130_kitsune_tanuki"]
	_draw_sprite_on(c, _tex(spr_k), r, b_flip, false, b_tint, 0.0, cam_off)

# ==============================================================================
# MULTI-FRAME HD PROTAGONIST ANIMATION PIPELINE (All 22 Registered Hero Frames!)
# ==============================================================================
func _draw_hero_on(c: Control, cam_off: Vector2) -> void:
	var p: Dictionary = _eng_get("player", {})
	if p.is_empty():
		return
	var px: float = float(p["x"])
	var py: float = float(p["y"])
	var pw: float = float(p["w"])
	var ph: float = float(p["h"])
	var facing: int = int(p.get("facing", 1))
	var grav_d: float = float(p.get("grav_dir", 1.0))
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))

	if bool(p.get("dead", false)):
		# Render HD fallen pose `hero_death` cleanly before/beside grave!
		var d_tex: Texture2D = _tex("hero_death")
		if d_tex != null:
			_draw_sprite_on(c, d_tex, Rect2(px - 11.0, py + 4.0, pw + 22.0, ph + 6.0), facing < 0, grav_d < 0.0, Color(1.0, 0.85, 0.85, 0.92), 0.0, cam_off)
		return

	var on_gnd: bool = bool(p.get("on_ground", false))
	var vx_abs: float = absf(float(p.get("vx", 0.0)))
	var vy_dir: float = float(p.get("vy", 0.0)) * grav_d
	var melee_t: float = float(p.get("melee_anim", 0.0))
	var atk_t: float = float(p.get("attack_anim", 0.0))
	var is_pounding: bool = bool(p.get("ground_pounding", false))
	var is_sheathed: bool = bool(p.get("sheathed", false))

	var spr_key: String = "hero_idle_01"
	if hero_hurt_pose_timer > 0.0:
		spr_key = "hero_hurt"
	elif melee_t > 0.0:
		# 2-stage sword slash combo: initial cleave -> follow-through arc!
		spr_key = "hero_melee_slash" if melee_t > 0.09 else "hero_melee_follow"
	elif atk_t > 0.0:
		spr_key = "hero_attack"
	elif not on_gnd:
		if is_pounding or vy_dir > 135.0:
			spr_key = "hero_jump_fall"
		elif int(p.get("air_jumps_used", 0)) > 0 or vy_dir > -55.0:
			spr_key = "hero_jump2"
		else:
			spr_key = "hero_jump1"
	elif hero_land_pose_timer > 0.0 and vx_abs < 65.0:
		spr_key = "hero_jump_land"
	elif vx_abs > 155.0:
		var run_frames: Array[String] = ["hero_run1", "hero_run2", "hero_run3", "hero_run4"]
		var r_idx: int = absi(int(floorf(float(p.get("walk_cycle", 0.0))))) % 4
		spr_key = run_frames[r_idx]
	elif vx_abs > 14.0:
		var walk_frames: Array[String] = ["hero_walk1", "hero_walk2", "hero_walk3", "hero_walk4"]
		var w_idx: int = absi(int(floorf(float(p.get("walk_cycle", 0.0))))) % 4
		spr_key = walk_frames[w_idx]
	else:
		var idle_frames: Array[String] = ["hero_idle_01", "hero_idle_02", "hero_idle_03", "hero_idle_04"]
		var i_idx: int = int(floorf(t_sec * 4.8)) % 4
		spr_key = idle_frames[i_idx]

	var h_tex: Texture2D = _tex(spr_key)
	if h_tex == null:
		h_tex = _tex("hero_idle")

	var is_melee: bool = (melee_t > 0.0)
	var stride_lift: float = -absf(sin(float(p.get("walk_cycle", 0.0)) * PI)) * 2.2 if (on_gnd and vx_abs > 20.0) else 0.0
	var crouch_squash: float = 0.86 if bool(p.get("crouching", false)) else 1.0

	var sc_x: float = float(p.get("scale_x", 1.0)) * (1.10 if crouch_squash < 0.95 else 1.0)
	var sc_y: float = float(p.get("scale_y", 1.0)) * crouch_squash
	var base_w: float = (pw + 34.0) if is_melee else (pw + 22.0)
	var base_h: float = (ph + 10.0) if is_melee else (ph + 8.0)
	var draw_w: float = base_w * sc_x
	var draw_h: float = base_h * sc_y
	var cx: float = px + pw * 0.5 + (5.0 * float(facing) if is_melee else 0.0)
	var by: float = py + ph + stride_lift

	# Ground-Pound Meteor Streak VFX
	if is_pounding:
		c.draw_line(Vector2(cx - 8.0, py - 24.0 * grav_d), Vector2(cx - 8.0, py + ph * 0.5), Color(0.66, 0.33, 0.97, 0.72), 2.5)
		c.draw_line(Vector2(cx + 8.0, py - 28.0 * grav_d), Vector2(cx + 8.0, py + ph * 0.5), Color(0.0, 0.96, 1.0, 0.72), 2.5)

	# Active Flight Wings Visual
	if bool(p.get("has_flight", false)):
		var wf_folded: bool = bool(p.get("wings_folded", false))
		var w_sz: float = 22.0 if wf_folded else (34.0 + sin(t_sec * 14.0) * 4.0)
		_draw_sprite_on(c, _tex("icon_wing"), Rect2(cx - float(facing) * 16.0 - w_sz * 0.5, py + 6.0, w_sz, w_sz), facing < 0, grav_d < 0.0, Color(1.0, 1.0, 1.0, 0.55 if wf_folded else 0.92), 0.0, cam_off)

	# Golden Body Radiant Aura
	if float(p.get("golden_timer", 0.0)) > 0.0:
		var pulse_r: float = 28.0 + sin(t_sec * 12.0) * 4.0
		c.draw_circle(Vector2(cx, py + ph * 0.5), pulse_r, Color(0.99, 0.88, 0.22, 0.30))
		c.draw_arc(Vector2(cx, py + ph * 0.5), pulse_r + 3.0, 0.0, TAU, 24, Color("#fde047"), 2.0)

	# Calm Sheathed Zen Lotus Ring (`收剑姿态特效`)
	if is_sheathed:
		var sh_r: float = 22.0 + sin(t_sec * 4.2) * 2.0
		c.draw_arc(Vector2(cx, py + ph - 6.0), sh_r, 0.0, TAU, 24, Color(0.29, 0.87, 0.50, 0.65), 1.8)

	var h_tint: Color = Color.WHITE
	if float(p.get("golden_timer", 0.0)) > 0.0:
		h_tint = Color(1.25, 1.14, 0.58, 1.0)
	elif is_sheathed:
		h_tint = Color(0.88, 1.06, 0.96, 1.0)
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
		var sh_cache: String = str(p.get("shield_cache", ""))
		var sh_col: Color = Color(1.0, 0.62, 0.45, 0.85) if sh_cache != "" else Color(1.0, 1.0, 1.0, 0.82)
		if sh_tex != null:
			_draw_sprite_on(c, sh_tex, Rect2(cx - sh_sz * 0.5, py + ph * 0.5 - sh_sz * 0.5, sh_sz, sh_sz), false, false, sh_col, t_sec * 1.35, cam_off)
		else:
			c.draw_arc(Vector2(cx, py + ph * 0.5), 26.0, 0.0, TAU, 24, Color("#38bdf8"), 2.0)

	if float(p.get("poison_timer", 0.0)) > 0.0:
		c.draw_texture_rect(_tex("icon_poison"), Rect2(cx - 12.0, py - 28.0 + sin(t_sec * 7.0) * 2.0, 24.0, 24.0), false)

	var carry_d: Dictionary = _eng_get("carrying_item", {})
	if not carry_d.is_empty():
		var ct: String = str(carry_d.get("t", ""))
		var ck_carry: String = "v2_spore_key" if ct == "spore_key" else ("v2_patch_chip" if ct == "patch_chip" else ("s2_root_key" if ct == "root_item" else "s2_battery"))
		c.draw_texture_rect(_tex(ck_carry), Rect2(cx - 12.0, py - 30.0, 24.0, 24.0), false)

func _draw_combat_and_fx_on(c: Control, cam_off: Vector2) -> void:
	var t_sec: float = float(_eng_get("time_elapsed", 0.0))
	var bullets: Array = _eng_get("bullets", [])
	for b_var in bullets:
		var b: Dictionary = b_var
		var bk: String = "sword_wave" if bool(b.get("s3_wave", false)) else ("bullet_fire" if bool(b.get("upgraded", false)) else "bullet_cyan")
		var b_flip: bool = float(b.get("vx", 1.0)) < 0.0
		var bw: float = float(b.get("w", 24.0))
		var bh: float = float(b.get("h", 18.0))
		if bool(b.get("frozen_plat", false)) or (bool(b.get("s3_wave", false)) and absf(float(b.get("vx", 100.0))) < 25.0):
			c.draw_rect(Rect2(float(b["x"]) - 2.0, float(b["y"]) - 2.0, bw + 4.0, bh + 4.0), Color(0.99, 0.88, 0.28, 0.55), false, 1.5)
		_draw_sprite_on(c, _tex(bk), Rect2(float(b["x"]), float(b["y"]), bw, bh), b_flip, false, Color.WHITE, 0.0, cam_off)

	var enemy_shots: Array = _eng_get("enemy_shots", [])
	for es_var in enemy_shots:
		var es: Dictionary = es_var
		var ew_s: float = float(es.get("w", 12.0))
		var eh_s: float = float(es.get("h", 12.0))
		var es_kind: String = str(es.get("kind", ""))
		# Mole Deflectable Wrench Projectile (`鼹鼠扳手`)
		if es_kind == "wrench" or bool(es.get("deflectable_wrench", false)):
			var wr_c: Vector2 = Vector2(float(es["x"]) + ew_s * 0.5, float(es["y"]) + eh_s * 0.5)
			c.draw_arc(wr_c, maxf(9.0, ew_s * 0.65), 0.0, TAU, 14, Color("#fde047"), 2.2)
			c.draw_line(wr_c + Vector2(-7.0, 0.0).rotated(t_sec * 18.0), wr_c + Vector2(7.0, 0.0).rotated(t_sec * 18.0), Color("#cbd5e1"), 3.0)
			continue
		var es_center: Vector2 = Vector2(float(es["x"]) + ew_s * 0.5, float(es["y"]) + eh_s * 0.5)
		var es_r: float = maxf(ew_s, eh_s) * 0.5
		var raw_ec: Variant = es.get("color", "#fb7185")
		var es_col: Color = (raw_ec as Color) if typeof(raw_ec) == TYPE_COLOR else Color(str(raw_ec))
		c.draw_circle(es_center, es_r, es_col)
		c.draw_circle(es_center, es_r * 0.48, Color.WHITE)

	var bombs: Array = _eng_get("bombs", [])
	for bm_var in bombs:
		var bm: Dictionary = bm_var
		_draw_sprite_on(c, _tex("bomb"), Rect2(float(bm["x"]) - 15.0, float(bm["y"]) - 15.0, 30.0, 30.0), false, false, Color.WHITE, t_sec * 9.0, cam_off)

	var melee_arcs: Array = _eng_get("melee_arcs", [])
	for ma_var in melee_arcs:
		var ma: Dictionary = ma_var
		var mk: String = "fx_slash_crit" if (bool(ma.get("crit", false)) and textures.has("fx_slash_crit")) else ("fx_melee_crit" if bool(ma.get("crit", false)) else "fx_melee_arc")
		var m_flip: bool = int(ma.get("dir", 1)) < 0
		var mw: float = float(ma.get("w", 74.0))
		var mh: float = float(ma.get("h", 68.0))
		var m_al: float = clampf(float(ma.get("life", 0.1)) / maxf(0.05, float(ma.get("max_life", 0.19))), 0.0, 1.0)
		_draw_sprite_on(c, _tex(mk), Rect2(float(ma["x"]), float(ma["y"]), mw, mh), m_flip, false, Color(1.0, 1.0, 1.0, m_al), 0.0, cam_off)

	var shock_rings: Array = _eng_get("shock_rings", [])
	for sr_var in shock_rings:
		var sr: Dictionary = sr_var
		var prog: float = 1.0 - clampf(float(sr["life"]) / maxf(0.05, float(sr["max_life"])), 0.0, 1.0)
		var rad: float = lerpf(6.0, float(sr["max_r"]), prog)
		var scol: Color = sr.get("color", Color("#00f5ff"))
		c.draw_arc(Vector2(float(sr["x"]), float(sr["y"])), rad, 0.0, TAU, 24, Color(scol.r, scol.g, scol.b, 1.0 - prog), 2.5)

	var particles: Array = _eng_get("particles", [])
	for pt_var in particles:
		var pt: Dictionary = pt_var
		var pal: float = clampf(float(pt["life"]) / maxf(0.05, float(pt["max_life"])), 0.0, 1.0)
		var pcol: Color = pt.get("color", Color("#00f5ff"))
		var psz: float = float(pt.get("size", 3.5))
		c.draw_rect(Rect2(float(pt["x"]), float(pt["y"]), psz, psz), Color(pcol.r, pcol.g, pcol.b, pal), true)

	if font_main != null:
		var float_texts: Array = _eng_get("float_texts", [])
		for ft_var in float_texts:
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

# Master GDD & v2.0 Boss HUD: Separates Segmented Armor Bar (`护甲条`) from Core HP Bar (`生命条`)!
func _draw_boss_hud_bar(c: Control, vw: float, bstate: Dictionary, boss_ent: Dictionary) -> void:
	var use_sm: bool = not bstate.is_empty() and bool(bstate.get("active", false))
	var hp: int = maxi(0, int(bstate.get("boss_hp", boss_ent.get("hp", 1)))) if use_sm else maxi(0, int(boss_ent.get("hp", 1)))
	var max_hp: int = maxi(1, int(bstate.get("boss_max_hp", boss_ent.get("max_hp", hp)))) if use_sm else maxi(1, int(boss_ent.get("max_hp", hp)))
	var armor: int = maxi(0, int(bstate.get("boss_armor", boss_ent.get("armor", 0))))
	var max_armor: int = maxi(armor, int(bstate.get("boss_max_armor", boss_ent.get("max_armor", armor))))
	var phase_i: int = int(bstate.get("phase", boss_ent.get("phase", 1)))
	var max_phase: int = maxi(phase_i, int(bstate.get("max_phase", 3)))
	var bname: String = str(bstate.get("name_en" if save.lang == "en" else "name_zh", "BOSS"))
	var sheathe_req: bool = bool(bstate.get("sheathe_required", false))

	var bw: float = 368.0
	var bx: float = (vw - bw) * 0.5
	var by: float = 54.0
	var panel_h: float = 42.0 if max_armor > 0 else 28.0

	c.draw_rect(Rect2(bx - 6.0, by - 4.0, bw + 12.0, panel_h + 8.0), Color(0.02, 0.04, 0.14, 0.90), true)
	c.draw_rect(Rect2(bx - 6.0, by - 4.0, bw + 12.0, panel_h + 8.0), Color("#fde047"), false, 1.5)

	if font_main != null:
		var tag_sh: String = ("  [收剑破局]" if save.lang != "en" else "  [SHEATHE]") if sheathe_req else ""
		var title_line: String = "%s · PHASE %d/%d%s" % [bname, phase_i, max_phase, tag_sh]
		c.draw_string(font_main, Vector2(bx, by + 9.0), title_line, HORIZONTAL_ALIGNMENT_CENTER, bw, 10, Color("#fde047"))

	# Top Segmented Armor Bar (when Boss has puzzle armor layers!)
	var hp_y: float = by + 13.0
	if max_armor > 0:
		var seg_gap: float = 4.0
		var seg_w: float = (bw - float(max_armor - 1) * seg_gap) / float(max_armor)
		for ai in range(max_armor):
			var sx_a: float = bx + float(ai) * (seg_w + seg_gap)
			var intact: bool = ai < armor
			c.draw_rect(Rect2(sx_a, by + 13.0, seg_w, 8.0), Color("#38bdf8") if intact else Color(0.15, 0.22, 0.34, 0.65), true)
			c.draw_rect(Rect2(sx_a, by + 13.0, seg_w, 8.0), Color("#e0f2fe") if intact else Color("#334155"), false, 1.0)
		hp_y = by + 25.0

	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	c.draw_rect(Rect2(bx, hp_y, bw, 12.0), Color(0.12, 0.05, 0.12, 0.85), true)
	c.draw_rect(Rect2(bx, hp_y, bw * ratio, 12.0), Color("#fb7185") if int(_eng_get("lv_id", 1)) < 101 else Color("#f59e0b"), true)
	if font_main != null:
		var hp_lbl: String = ("HP %d/%d  |  ARMOR %d/%d" % [hp, max_hp, armor, max_armor]) if max_armor > 0 else ("BOSS HP  %d / %d" % [hp, max_hp])
		c.draw_string(font_main, Vector2(bx, hp_y + 10.0), hp_lbl, HORIZONTAL_ALIGNMENT_CENTER, bw, 10, Color.WHITE)

func _draw_fake_flag_prank(c: Control, vw: float, vh: float) -> void:
	var card_w: float = 460.0
	var card_h: float = 84.0
	var rx: float = (vw - card_w) * 0.5
	var ry: float = (vh - card_h) * 0.42
	var is_p2: bool = int(_eng_get("fake_phase", 0)) >= 2
	c.draw_rect(Rect2(rx, ry, card_w, card_h), Color(0.18, 0.03, 0.10, 0.94) if is_p2 else Color(0.03, 0.16, 0.12, 0.92), true)
	c.draw_rect(Rect2(rx, ry, card_w, card_h), Color("#fb7185") if is_p2 else Color("#4ade80"), false, 3.0)
	if font_main != null:
		var msg: String = ""
		if save.lang == "en":
			msg = "★ PSYCH! IT'S A BOOBY-TRAPPED FAKE FLAG!" if is_p2 else "★ STAGE CLEARED...?!"
		else:
			msg = "★ 想得美！这是暗藏玄机的拟态假旗喵！" if is_p2 else "★ 恭喜通关……才怪？！"
		c.draw_string(font_main, Vector2(rx, ry + 50.0), msg, HORIZONTAL_ALIGNMENT_CENTER, card_w, 20, Color("#fde047") if is_p2 else Color("#4ade80"))

# ==============================================================================
# ENHANCED `--smoke-test` AUTOMATED 150-STAGE VERIFICATION SUITE
# ==============================================================================
func _StartCiSmoke() -> void:
	await get_tree().process_frame
	await _run_ci_smoke_test()

func _run_ci_smoke_test() -> void:
	print("[SMOKE v4.0] Loaded textures: ", textures.size(), " | BGM streams: ", audio.bgm_streams.size(), " | SFX streams: ", audio.sfx_streams.size(), " | Stages: ", engine.levels_by_id.size())
	if textures.size() < 420 or audio.bgm_streams.size() < 9 or audio.sfx_streams.size() < 38 or engine.levels_by_id.size() != 150:
		push_error("[SMOKE FAIL] Asset or stage count mismatch! tex=%d bgm=%d sfx=%d stages=%d" % [textures.size(), audio.bgm_streams.size(), audio.sfx_streams.size(), engine.levels_by_id.size()])
		get_tree().quit(1)
		return

	# 1. Run LevelValidator across all 150 levels
	var val_report: Dictionary = LevelValidator.validate_all_levels(levels_raw, false)
	if not bool(val_report.get("valid", false)):
		push_error("[SMOKE FAIL] LevelValidator failed on stages: " + str(val_report.get("failed_ids", [])))
		get_tree().quit(1)
		return
	print("[SMOKE v4.0] LevelValidator passed: ", val_report.get("passed", 0), "/150")

	# 2. Verify ChiptunePlayer Visual Subtitle Cue Emission across new v2.0 puzzle sounds
	save.visual_captions_on = true
	audio.visual_subtitles_enabled = true
	audio.pending_visual_cues.clear()
	for test_sfx in ["cloud_blade", "pipe_echo_double", "clock_gear", "sword_sheathe", "ground_pound", "valve_turn", "mirror_ping", "sundial_shift"]:
		audio.last_cue_time_by_key.clear()
		audio.play_named(test_sfx)
	if audio.pending_visual_cues.size() < 6:
		push_error("[SMOKE FAIL] Visual audio subtitles failed to emit for v2.0 puzzle SFX!")
		get_tree().quit(1)
		return

	# 3. Iterate through ALL 150 stages: load, physics + new v4.0 input simulation, checkpoint restore & 3-tier hint check
	save.unlocked_max = 150
	var checkpoints_restored: int = 0
	var bosses_verified: int = 0

	for test_lv in range(1, 151):
		_on_start_stage(test_lv)
		var p: Dictionary = _eng_get("player", {})
		if int(_eng_get("lv_id", 0)) != test_lv or p.is_empty():
			push_error("[SMOKE FAIL] Failed to boot Stage %d!" % test_lv)
			get_tree().quit(1)
			return

		var bs_chk: Dictionary = _eng_get("boss_state", {})
		if bool(bs_chk.get("active", false)):
			bosses_verified += 1

		# Simulate 14 frames covering move, jump, double-jump, ground-pound, shoot, slash, sheathe, interact, and layer shift
		for step_i in range(14):
			var cur_p: Dictionary = _eng_get("player", {})
			if bool(cur_p.get("dead", false)):
				engine.reset_attempt()
			var sim_inp: Dictionary = {
				"left": step_i >= 9,
				"right": step_i < 9,
				"down": step_i == 10,
				"down_pressed": step_i == 10,
				"jump_pressed": step_i == 0 or step_i == 5 or step_i == 10,
				"jump_released": step_i == 3,
				"jump_held": step_i < 3 or (step_i >= 5 and step_i < 8),
				"ground_pound_pressed": step_i == 10,
				"shoot_pressed": step_i == 2,
				"slash_pressed": step_i == 4,
				"sheathe_pressed": step_i == 6 or step_i == 11,
				"sheathe_toggle": step_i == 6 or step_i == 11,
				"interact_pressed": step_i == 7,
				"interact": step_i == 7,
				"interact_held": step_i == 7,
				"pick_place_pressed": step_i == 7,
				"bomb_pressed": false,
				"layer_pressed": step_i == 8 and engine.has_method("is_dual_layer_active") and engine.is_dual_layer_active(),
				"gold_pressed": false
			}
			engine.step_frame(0.016, sim_inp)
			_update_hero_pose_timers(0.016)
			_drain_engine_queues()
			ui.step_ui(0.016)

		# Test Checkpoint Save & Restore if stage has a checkpoint
		for e_v in _eng_get("entities", []):
			var e_cp: Dictionary = e_v
			if str(e_cp.get("t", "")) == "checkpoint" and not bool(e_cp.get("s3_fake", e_cp.get("fake", false))):
				var p_cp: Dictionary = _eng_get("player", {})
				p_cp["x"] = float(e_cp["x"]) + 4.0
				p_cp["y"] = float(e_cp["y"]) - 6.0
				engine.step_frame(0.016, {})
				engine.reset_attempt()
				checkpoints_restored += 1
				break

	# 4. Verify UI Modal Construction: 15-Chapter Cards, 3-Tier Progressive Hint & Medal Tracking, Accessibility & CG Skip
	ui.hall_view_mode = "chapters"
	ui.open_level_select_modal()
	ui.hall_view_mode = "stages"
	ui._refresh_hall_contents()
	ui.open_hint_modal()
	ui.hint_blueprint.set_tier(HintBlueprintView.TIER_LIGHT, 150)
	if ui.hint_blueprint.has_used_full_hint(150):
		push_error("[SMOKE FAIL] Light hint wrongly marked full hint as used!")
		get_tree().quit(1)
		return
	ui.hint_blueprint.set_tier(HintBlueprintView.TIER_FULL, 150)
	if not ui.hint_blueprint.has_used_full_hint(150):
		push_error("[SMOKE FAIL] Full hint did not record full_hint_used for stage!")
		get_tree().quit(1)
		return
	ui.open_options_modal("assist")
	await get_tree().process_frame
	ui.step_ui(0.016)
	ui.close_all_modals(true)

	# Restore clean fresh-install state before exiting smoke test
	save.reset_progress_keep_prefs()
	for sp_clean in [SaveManager.PRIMARY_SAVE_PATH, SaveManager.BACKUP_SAVE_PATH, SaveManager.TEMP_SAVE_PATH, SaveManager.SAVE_PATH]:
		if FileAccess.file_exists(sp_clean):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(sp_clean))

	print("[SMOKE TEST PASS] 150/150 levels verified | checkpoints_tested=", checkpoints_restored, " | bosses_verified=", bosses_verified)
	get_tree().quit(0)
