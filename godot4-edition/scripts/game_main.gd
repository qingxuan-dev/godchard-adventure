extends Node2D
var levels: Array = []
var meta: Dictionary = {}
var textures: Dictionary = {}
var cjk_font: FontFile = null
var is_mobile_app: bool = false
var save: SaveManager
var shop: ShopSystem
var audio: ChiptunePlayer
var engine: StageEngine
var ui: UiDirector
var input_state: Dictionary = {
	"left": false, "right": false, "jump_just_pressed": false,
	"shoot_pressed": false, "slash_pressed": false, "bomb_pressed": false,
	"layer_pressed": false, "gold_pressed": false
}
const SIMPLE_ENT_TEX: Dictionary = {
	"amanita": "mushroom_amanita", "poison_item": "mushroom_poison", "antidote_pad": "item_antidote",
	"crafting": "crafting_station", "poop": "poop", "launcher": "missile_launcher", "missile": "missile",
	"pipe": "pipe", "hourglass": "time_hourglass", "bomb_pickup": "bomb", "chain_bomb": "bomb",
	"princess": "npc_princess", "layer_term": "s2_layer_term", "root_term": "s2_root_term",
	"time_node": "s2_time_node", "beat_clock": "clock_gear", "mem_shard": "s2_mem_shard",
	"signal_battery": "s2_battery", "root_item": "s2_root_key", "trojan_heart": "s2_trojan_heart",
	"curse_totem": "s2_curse_totem", "troll_hand": "s2_troll_hand", "fake_save": "s2_fake_save",
	"peace_dove": "s2_peace_dove", "piston": "s2_piston_head", "s3_valve": "s3_valve_red",
	"s3_sundial": "s3_sundial_orb", "s3_catapult": "s3_catapult_trap", "s3_bomb_trophy": "s3_bomb_trophy",
	"s3_suction_pipe": "s3_suction_pipe", "s3_flower": "s3_pink_flower", "s3_tanuki": "s3_mon_tanuki",
	"s3_ladybug": "s3_mon_ladybug", "s3_mole": "s3_mon_mole"
}
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detect_platform()
	_load_data_and_textures()
	save = SaveManager.new()
	shop = ShopSystem.new(save, meta.get("shopCatalog", []))
	audio = ChiptunePlayer.new($AudioStreamPlayer)
	audio.select_track(true, 1)
	engine = StageEngine.new(save, shop, audio)
	ui = UiDirector.new()
	$UILayer.add_child(ui)
	ui.setup(levels, meta, textures, cjk_font, is_mobile_app, save, shop, engine)
	ui.stage_selected.connect(_enter_stage)
	ui.touch_action.connect(_on_touch_action)
func _detect_platform() -> void:
	var mode: String = "auto"
	if FileAccess.file_exists("res://data/build_profile.json"):
		var pf = FileAccess.open("res://data/build_profile.json", FileAccess.READ)
		if pf != null:
			var p: Variant = JSON.parse_string(pf.get_as_text())
			if typeof(p) == TYPE_DICTIONARY: mode = str((p as Dictionary).get("platform", "auto"))
	is_mobile_app = true if mode == "android" else (false if mode == "pc" else (OS.get_name() in ["Android", "iOS"]))
	if is_mobile_app or OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
func _load_data_and_textures() -> void:
	var lff: FontFile = null
	var cff: FontFile = null
	if FileAccess.file_exists("res://data/latin_font.bin"):
		var lb: PackedByteArray = FileAccess.get_file_as_bytes("res://data/latin_font.bin")
		if lb.size() > 0: lff = FontFile.new(); lff.data = lb
	if FileAccess.file_exists("res://data/cjk_font.bin"):
		var cb: PackedByteArray = FileAccess.get_file_as_bytes("res://data/cjk_font.bin")
		if cb.size() > 0: cff = FontFile.new(); cff.data = cb
	if lff != null and cff != null:
		lff.fallbacks = [cff]
		cjk_font = lff
		ThemeDB.fallback_font = cff
		var dth: Theme = ThemeDB.get_default_theme()
		if dth != null: dth.default_font = lff
	elif cff != null:
		cjk_font = cff; ThemeDB.fallback_font = cff
	var lf = FileAccess.open("res://data/levels_150.json", FileAccess.READ)
	if lf != null: levels = JSON.parse_string(lf.get_as_text())
	var mf = FileAccess.open("res://data/game_metadata.json", FileAccess.READ)
	if mf != null: meta = JSON.parse_string(mf.get_as_text())
	var amap: Dictionary = meta.get("assets", {})
	for k in amap.keys():
		var rel: String = "res://" + str(amap[k])
		var tex: Texture2D = null
		if ResourceLoader.exists(rel):
			var r: Resource = load(rel)
			if r is Texture2D: tex = r as Texture2D
		if tex == null and FileAccess.file_exists(rel):
			var raw: PackedByteArray = FileAccess.get_file_as_bytes(rel)
			var im: Image = Image.new()
			var err: int = im.load_png_from_buffer(raw) if rel.ends_with(".png") else im.load_jpg_from_buffer(raw)
			if err == OK: tex = ImageTexture.create_from_image(im)
		if tex != null: textures[str(k)] = tex
func _enter_stage(stage_id: int) -> void:
	for lv in levels:
		if int(lv.get("id", 0)) == stage_id:
			engine.start_stage(lv)
			break
func _on_touch_action(act: String, pressed: bool) -> void:
	if act == "left": input_state["left"] = pressed
	elif act == "right": input_state["right"] = pressed
	elif pressed:
		if is_mobile_app: Input.vibrate_handheld(15)
		if act == "jump": input_state["jump_just_pressed"] = true
		elif act == "shoot": input_state["shoot_pressed"] = true
		elif act == "slash": input_state["slash_pressed"] = true
		elif act == "bomb": input_state["bomb_pressed"] = true
		elif act == "gold": input_state["gold_pressed"] = true
		elif act == "layer": input_state["layer_pressed"] = true
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode in [KEY_A, KEY_LEFT]: input_state["left"] = ke.pressed
		elif ke.keycode in [KEY_D, KEY_RIGHT]: input_state["right"] = ke.pressed
		elif ke.pressed and not ke.echo:
			if ke.keycode == KEY_F11 and not is_mobile_app: ui.toggle_pc_fullscreen()
			elif ke.keycode == KEY_ESCAPE: ui.toggle_settings_modal()
			elif ke.keycode == KEY_H: ui.open_hint_modal()
			elif ke.keycode in [KEY_SPACE, KEY_W, KEY_UP, KEY_K]: input_state["jump_just_pressed"] = true
			elif ke.keycode == KEY_J: input_state["shoot_pressed"] = true
			elif ke.keycode == KEY_U: input_state["slash_pressed"] = true
			elif ke.keycode in [KEY_B, KEY_I]: input_state["bomb_pressed"] = true
			elif ke.keycode == KEY_E: input_state["layer_pressed"] = true
			elif ke.keycode == KEY_G: input_state["gold_pressed"] = true
			elif ke.keycode == KEY_R and not engine.current_level.is_empty():
				if not engine.player.is_empty() and bool(engine.player.get("dead", false)):
					ui.hide_death_modal(); engine.reset_attempt()
				else: engine.kill_player(true, "tactical_reset")
func _process(delta: float) -> void:
	audio.fill_buffer(save.volume)
	if not engine.current_level.is_empty():
		engine.viewport_w = maxf(960.0, get_viewport_rect().size.x)
		engine.step_frame(delta, input_state)
		ui.update_hud()
		queue_redraw()
func _sp(key: String, x: float, y: float, w: float, h: float, fx: bool = false, fy: bool = false, col: Color = Color.WHITE) -> bool:
	if not textures.has(key) or w <= 0.5 or h <= 0.5: return false
	var tex: Texture2D = textures[key]
	var dw: float = -w if fx else w
	var dx: float = (x + w) if fx else x
	var dh: float = -h if fy else h
	var dy: float = (y + h) if fy else y
	draw_texture_rect(tex, Rect2(dx, dy, dw, dh), false, col)
	return true
func _tiled(key: String, dst: Rect2, tw: float, th: float, col: Color = Color.WHITE) -> void:
	if not textures.has(key) or dst.size.x <= 0.5 or dst.size.y <= 0.5: return
	var tex: Texture2D = textures[key]
	var sw0: float = float(tex.get_width())
	var sh0: float = float(tex.get_height())
	var yy: float = dst.position.y
	while yy < dst.end.y - 0.1:
		var dh: float = minf(th, dst.end.y - yy)
		var xx: float = dst.position.x
		while xx < dst.end.x - 0.1:
			var dw: float = minf(tw, dst.end.x - xx)
			draw_texture_rect_region(tex, Rect2(xx, yy, dw, dh), Rect2(0.0, 0.0, sw0 * (dw / tw), sh0 * (dh / th)), col)
			xx += tw
		yy += th
func _pick_bg(lid: int, ch: int) -> String:
	if lid >= 101: return "s3_bg_ch%d" % clampi(ch, 11, 15)
	if lid >= 51:
		var m: Dictionary = { 6: "bg_s2_signal", 7: "bg_s2_mecha", 8: "bg_s2_fracture", 9: "bg_s2_chrono", 10: "bg_s2_root" }
		return str(m.get(ch, "bg_s2_signal"))
	return "cyber_skyline_bg"
func _draw() -> void:
	if engine == null or engine.current_level.is_empty(): return
	var vw: float = maxf(960.0, get_viewport_rect().size.x)
	var lid: int = int(engine.current_level.get("id", 1))
	var ch: int = int(engine.current_level.get("chapter", 1))
	var t_sec: float = engine.time_elapsed
	var cx: float = engine.cam_x
	draw_rect(Rect2(0.0, 0.0, vw, 540.0), Color("#5cb8ff") if lid >= 101 else Color("#06091e"))
	_sp(_pick_bg(lid, ch), 0.0, 0.0, vw, 540.0)
	for s in engine.solids:
		if bool(s.get("broken", false)): continue
		var st: String = str(s.get("t", "solid"))
		var sx: float = float(s["x"]) - cx
		var sy: float = float(s["y"])
		var sw: float = float(s["w"])
		var sh: float = float(s["h"])
		if sx + sw < -96.0 or sx > vw + 96.0: continue
		var in_l: bool = Sector1And2Mechanics.is_in_layer(s, engine.active_layer)
		var mc: Color = Color(1.0, 1.0, 1.0, 1.0 if in_l else 0.25)
		if (st == "invis" or st == "qblock") and not bool(s.get("revealed", true)):
			draw_rect(Rect2(sx + sw * 0.5 - 2.0, sy + sh * 0.5 - 2.0, 4.0, 4.0), Color(0.0, 0.96, 1.0, 0.28))
			continue
		if st == "qblock":
			_sp("s3_qblock" if lid >= 101 else "qblock", sx, sy, sw, sh, false, false, Color(1.0, 1.0, 1.0, 0.55 if bool(s.get("used", false)) else 1.0))
			continue
		if st == "invis":
			_sp("s3_kaizo_block" if lid >= 101 else "plat_copper_destruct", sx, sy, sw, sh)
			continue
		if st == "mirror":
			_tiled("mirror_wall", Rect2(sx, sy, sw, sh), sw, 48.0, mc)
			continue
		if st in ["signal_gate", "paradox_gate", "timed_gate"]:
			if not Sector1And2Mechanics.is_solid_collidable(s, engine.active_layer, engine.signal_groups): continue
			_sp("laser_gate", sx - 3.0, sy, sw + 6.0, sh)
			continue
		if st == "cloud_plat":
			_sp("cloud_safe", sx, sy, sw, sh); continue
		if lid >= 101:
			var sk3: String = str(s.get("skin", ""))
			if st == "s3_tall_pipe" and textures.has("s3_pipe_tall"):
				var pt: Texture2D = textures["s3_pipe_tall"]
				var pw0: float = float(pt.get_width()); var ph0: float = float(pt.get_height())
				draw_texture_rect_region(pt, Rect2(sx + 2.0, sy + 24.0, sw - 4.0, maxf(8.0, sh - 24.0)), Rect2(0.0, ph0 * 0.34, pw0, ph0 * 0.66))
				draw_texture_rect_region(pt, Rect2(sx - 2.0, sy, sw + 4.0, 26.0), Rect2(0.0, 0.0, pw0, ph0 * 0.34))
			elif st == "s3_cloud":
				var safe3: bool = Sector3Arcadia.is_cloud_safe(s, bool(engine.state_bag["sundial_phase"]))
				_sp("s3_cloud_safe" if safe3 else "s3_cloud_knife", sx, sy - (0.0 if safe3 else 10.0), sw, sh + (6.0 if safe3 else 20.0))
			elif st == "destructible":
				_tiled("s3_stone_cracked", Rect2(sx, sy, sw, sh), 48.0, 48.0, mc)
			elif st == "s3_slide_turf" or sk3 == "grass":
				if sh > 54.0: _tiled("s3_ground_dirt", Rect2(sx, sy + 44.0, sw, sh - 44.0), 192.0, 96.0, mc)
				_tiled("s3_ground_top", Rect2(sx, sy, sw, minf(sh, 96.0)), 288.0, 96.0, mc)
			elif sk3 == "wood":
				if sw <= 98.0 and sh <= 98.0: _sp("s3_wood_crate", sx, sy, sw, sh, false, false, mc)
				else: _tiled("s3_wood_crate", Rect2(sx, sy, sw, sh), 48.0, minf(48.0, sh), mc)
			elif sk3 == "stone" or st == "s3_drop_block":
				if sw <= 122.0 and sh <= 102.0: _sp("s3_stone_brick", sx, sy, sw, sh, false, false, mc)
				else: _tiled("s3_stone_brick", Rect2(sx, sy, sw, sh), 48.0, minf(48.0, sh), mc)
			else:
				_tiled("s3_float_grass", Rect2(sx, sy, sw, maxf(sh, 54.0)), 192.0, 64.0, mc)
			continue
		if st == "polarity_block":
			_sp("s2_mag_orange" if bool(engine.polarity_groups.get(str(s.get("group", "")), false)) else "s2_mag_blue", sx, sy, sw, sh, false, false, mc); continue
		if st in ["phase_plat", "signal_bridge"]:
			_tiled("s2_phase_ghost" if str(s.get("phase_state", "solid")) == "ghost" else "s2_phase_solid", Rect2(sx, sy - 2.0, sw, sh + 4.0), 96.0, sh + 4.0, mc); continue
		if st == "rail_plat": _sp("s2_rail_plat", sx, sy - 2.0, sw, sh + 4.0, false, false, mc); continue
		if st == "shy_brick": _tiled("s2_shy_brick", Rect2(sx, sy, sw, sh), sh, sh, Color(1, 1, 1, 1.0 if bool(s.get("shy_solid", true)) else 0.3)); continue
		if st == "moving_pit": _sp("s2_moving_pit", sx, sy, sw, sh + 12.0, false, false, mc); continue
		if st == "ceiling_crusher": _sp("s2_ceiling_crusher", sx, sy, sw, sh + 6.0, false, false, mc); continue
		if st == "fake_error": _sp("s2_fake_error", sx, sy, sw, sh, false, false, mc); continue
		if st == "beat_gate":
			if not bool(s.get("is_open", false)): _sp("s2_beat_gate", sx, sy, sw, sh, false, false, mc)
			continue
		if st in ["conveyor", "glass_panel", "null_block"]:
			draw_rect(Rect2(sx, sy, sw, sh), Color(0.12, 0.22, 0.38, 0.78 if st != "glass_panel" else 0.42))
			draw_rect(Rect2(sx, sy, sw, 3.0), Color("#22d3ee") if st == "glass_panel" else Color("#eab308"))
			continue
		draw_rect(Rect2(sx, sy + 8.0, sw, maxf(0.0, sh - 8.0)), Color(0.03, 0.06, 0.15, mc.a))
		if st == "destructible": _tiled("plat_copper_destruct", Rect2(sx, sy, sw, sh), 144.0, 48.0, mc)
		elif st == "vanish": _tiled("plat_vanish_hover", Rect2(sx, sy, sw, maxf(sh + 12.0, 56.0)), 192.0, 62.0, mc)
		elif sh > sw * 1.35 and sw <= 120.0: _tiled("s2_plat_column" if lid >= 51 else "plat_column", Rect2(sx, sy, sw, sh), sw, 192.0, mc)
		elif sh <= 60.0 and sy + sh < 488.0: _tiled("s2_plat_float_deck" if lid >= 51 else "plat_float_deck", Rect2(sx, sy, sw, maxf(sh + 6.0, 52.0)), 192.0, 54.0, mc)
		else:
			var s2: bool = lid >= 51
			var reac: bool = sw >= 144.0 and sh >= 90.0
			if sh > 56.0: _tiled("s2_plat_sub_block" if s2 else "plat_copper_destruct", Rect2(sx, sy + 54.0, sw, sh - 54.0), 192.0, 64.0, mc)
			_tiled(("s2_plat_reactor_wall" if s2 else "plat_reactor_wall") if reac else ("s2_plat_ground_top" if s2 else "plat_ground_top"), Rect2(sx, sy, sw, minf(sh, 126.0 if reac else 64.0)), 288.0 if reac else 240.0, 126.0 if reac else 64.0, mc)
	for e in engine.entities:
		var et: String = str(e.get("t", ""))
		var ex: float = float(e["x"]) - cx
		var ey: float = float(e["y"])
		var ew: float = float(e["w"])
		var eh: float = float(e["h"])
		if ex + ew < -110.0 or ex > vw + 110.0: continue
		var flip_e: bool = float(e.get("vx", 0.0)) > 0.0 if et in ["enemy", "s3_tanuki", "s3_manju"] else (float(e.get("vx", -1.0)) < 0.0)
		if SIMPLE_ENT_TEX.has(et):
			_sp(str(SIMPLE_ENT_TEX[et]), ex, ey, ew, eh, flip_e); continue
		if et == "flower": _sp("flower_chomp" if sin(t_sec * 5.0 + ex) > 0.25 else "flower_skull", ex, ey, ew, eh)
		elif et in ["spikes", "spike"]:
			if lid >= 101: _tiled("s3_thorns", Rect2(ex, ey - 4.0, ew, eh + 6.0), 48.0, 36.0)
			else: _tiled("spikes_red", Rect2(ex, ey, ew, eh), 48.0, eh)
		elif et == "coin": _sp("coin_1" if (int(floor(t_sec * 5.0)) % 2 == 0) else "coin_2", ex, ey + sin(t_sec * 4.0 + ex) * 2.5, ew, eh)
		elif et == "gem": _sp("gem_" + str(e.get("color", "red")), ex, ey, ew, eh)
		elif et == "powerup": _sp("icon_wing" if str(e.get("kind", "")) == "flight" else "icon_spring", ex, ey, ew, eh)
		elif et == "spring": _sp("s3_shroom_bounce" if lid >= 101 else "spring", ex, ey, ew, eh)
		elif et == "betray_spring": _sp("s2_betray_spring" if not bool(e.get("calibrated", false)) else "spring", ex, ey, ew, eh)
		elif et == "gravity_pad": _sp("arrow_up_red" if int(e.get("dir", -1)) < 0 else "ui_pipe_down", ex, ey - 10.0, ew, eh + 10.0)
		elif et == "checkpoint":
			var cp_on: bool = bool(e.get("active", false))
			_sp(("s3_cp_on" if cp_on else "s3_cp_off") if lid >= 101 else ("checkpoint_on" if cp_on else "checkpoint_off"), ex - 4.0, ey - 4.0, ew + 8.0, eh + 4.0)
		elif et == "flag": _sp("s3_flag_idle" if lid >= 101 else "flag_idle", ex - 4.0, ey, ew + 12.0, eh)
		elif et == "mimic_flag": _sp("flag_win" if bool(e.get("tamed", false)) else "s2_mimic_flag", ex, ey, ew, eh)
		elif et == "s3_mimic_flag": _sp("s3_flag_win" if bool(e.get("tamed", false)) else "s3_mimic_flag", ex, ey, ew, eh)
		elif et == "mimic_chest": _sp("s2_mimic_chest" if bool(e.get("awake", false)) else "chest_closed", ex, ey, ew, eh)
		elif et == "sign":
			_sp("s3_wood_sign" if lid >= 101 else ("sign_left" if str(e.get("dir_str", "")) == "left" else "sign_right"), ex, ey, ew, eh)
		elif et == "clock": _sp("clock_gear" if bool(e.get("gear", false)) else "clock_gold", ex, ey, ew, eh)
		elif et == "cloud_knife": _sp("cloud_knife" if fposmod(t_sec, 2.2) < 0.35 else "cloud_dark_safe", ex, ey, ew, eh)
		elif et == "shop": _sp("shop_frame", ex - 8.0, ey - 10.0, ew + 16.0, eh + 10.0); _sp("npc_merchant", ex + ew * 0.25, ey + 10.0, ew * 0.55, eh - 10.0)
		elif et == "signal_node":
			var son: bool = str(e.get("group", "")) != "" and bool(engine.signal_groups.get(str(e["group"]), false))
			_sp("s2_node_overload" if bool(e.get("fake", false)) else ("s2_node_on" if son else "s2_node_off"), ex, ey, ew, eh)
		elif et == "polarity_node": _sp("s2_mag_node_orange" if bool(engine.polarity_groups.get(str(e.get("group", "")), false)) else "s2_mag_node_blue", ex, ey, ew, eh)
		elif et == "portal": _sp("s2_portal_b" if str(e.get("pair_id", "A")) == "B" else ("s2_portal_c" if str(e.get("pair_id", "A")) == "C" else "s2_portal_a"), ex, ey, ew, eh)
		elif et == "saw_track": _sp("s2_saw_blade", ex, ey, ew, eh)
		elif et == "enemy":
			var ek: String = str(e.get("kind", ""))
			_sp("enemy_boss" if ek == "boss" else ("enemy_flying" if ek == "flying" else "enemy_follower"), ex, ey, ew, eh, flip_e)
		elif et == "s2_enemy":
			var sk: String = str(e.get("kind", "patrol"))
			var mk: String = sk if textures.has(sk) else ("s2_forklift" if sk == "forklift" else ("s2_turret" if sk == "turret" else ("s2_bot_drone" if sk == "drone" else ("s2_shield_mech" if sk == "shield_mech" else "s2_bot_patrol"))))
			_sp(mk, ex, ey, ew, eh, flip_e)
		elif et == "s2_boss" and not bool(e.get("defeated", false)):
			var bk: String = str(e.get("boss_kind", ""))
			var bm: Dictionary = { "signal_storm": "s2_boss_signal", "reassembly_mech": "s2_boss_mecha", "mecha_sovereign": "s2_boss_mecha", "fracture_core": "s2_boss_fracture", "chrono_skull": "s2_boss_chrono", "chrono_regent": "s2_boss_chrono" }
			_sp(str(bm.get(bk, "s2_boss_null")), ex, ey, ew, eh)
		elif et == "s3_bush":
			var safe_b: bool = str(e.get("mode", "")) == "safe"
			_sp("s3_bush_safe" if safe_b else "s3_bush_blade", ex, ey - (0.0 if safe_b else 14.0), ew, eh + (0.0 if safe_b else 14.0))
		elif et == "s3_manju": _sp("s3_mon_manju" if str(e.get("mode", "")) == "polite" else "s3_mon_manju_spike", ex, ey, ew, eh, flip_e)
		elif et == "s3_sun": _sp("s3_sun_angry" if bool(e.get("awake", false)) else "s3_sun_calm", ex, ey, ew, eh)
		elif et == "s3_boss":
			var b3m: Dictionary = { "cloud_ram": "s3_boss_110", "pipe_kaiser": "s3_boss_120", "kage_tanuki": "s3_boss_130", "blade_archon": "s3_boss_140", "solaris_painter": "s3_boss_150" }
			_sp(str(b3m.get(str(e.get("boss_kind", "")), "s3_boss_150")), ex, ey, ew, eh)
			var rat: float = clampf(float(e.get("hp", 26)) / maxf(1.0, float(e.get("max_hp", 26))), 0.0, 1.0)
			draw_rect(Rect2(ex + ew * 0.5 - 50.0, ey - 14.0, 100.0 * rat, 6.0), Color("#ef4444"))
	for b in engine.bullets:
		var bkey: String = "sword_wave" if bool(b.get("s3_wave", false)) else ("bullet_fire" if bool(b.get("upgraded", false)) else "bullet_cyan")
		_sp(bkey, float(b["x"]) - cx, float(b["y"]), float(b["w"]), float(b["h"]), float(b.get("vx", 1.0)) < 0.0)
	for sh_p in engine.enemy_shots:
		if not _sp("bullet_fire", float(sh_p["x"]) - cx, float(sh_p["y"]), float(sh_p["w"]), float(sh_p["h"])):
			draw_circle(Vector2(float(sh_p["x"]) - cx + 8.0, float(sh_p["y"]) + 8.0), 7.0, Color("#fb7185"))
	if not engine.player.is_empty() and not bool(engine.player.get("dead", false)):
		var p: Dictionary = engine.player
		var px: float = float(p["x"]) - cx
		var py: float = float(p["y"])
		var pw: float = float(p["w"])
		var ph: float = float(p["h"])
		var melee: bool = float(p.get("melee_anim", 0.0)) > 0.0
		var hk: String = "hero_melee_slash" if melee else ("hero_attack" if float(p.get("attack_anim", 0.0)) > 0.0 else (("hero_jump1" if float(p["vy"]) < 0.0 else "hero_jump2") if not bool(p["on_ground"]) else (str(["hero_walk1", "hero_run1", "hero_walk2", "hero_run2"][int(floor(float(p.get("walk_cycle", 0.0)))) % 4]) if absf(float(p["vx"])) > 14.0 else "hero_idle")))
		var gold_on: bool = float(p.get("golden_timer", 0.0)) > 0.0
		if gold_on: draw_arc(Vector2(px + pw * 0.5, py + ph * 0.5), 30.0, 0.0, TAU, 24, Color("#facc15"), 3.0)
		var pcol: Color = Color(1.3, 1.18, 0.42, 1.0) if gold_on else Color.WHITE
		var fh: bool = int(p.get("facing", 1)) < 0
		var fv: bool = int(p.get("grav_dir", 1)) < 0
		if melee:
			_sp(hk, px - (28.0 if fh else 16.0), py - 8.0, pw + 44.0, ph + 10.0, fh, fv, pcol)
			_sp("fx_melee_arc", px + (-64.0 if fh else 14.0), py - 10.0, 74.0, 60.0, fh, false)
		else:
			_sp(hk, px - 12.0, py - 6.0, pw + 24.0, ph + 8.0, fh, fv, pcol)
		if bool(p.get("shield", false)):
			_sp("fx_shield_aegis", px + pw * 0.5 - 32.0, py + ph * 0.5 - 32.0, 64.0, 64.0, false, false, Color(1, 1, 1, 0.85))
