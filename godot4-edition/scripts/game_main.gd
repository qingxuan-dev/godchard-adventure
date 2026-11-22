extends Node2D

var levels: Array = []
var meta: Dictionary = {}
var textures: Dictionary = {}

var save: SaveManager
var shop: ShopSystem
var audio: ChiptunePlayer
var engine: StageEngine
var ui: UiDirector

var input_state: Dictionary = {
	"left": false,
	"right": false,
	"jump_just_pressed": false,
	"shoot_pressed": false,
	"slash_pressed": false,
	"bomb_pressed": false,
	"layer_pressed": false,
	"gold_pressed": false
}

func _ready() -> void:
	_load_data_and_textures()
	save = SaveManager.new()
	shop = ShopSystem.new(save, meta.get("shopCatalog", []))
	audio = ChiptunePlayer.new($AudioStreamPlayer)
	audio.select_track(true, 1)
	engine = StageEngine.new(save, shop, audio)

	ui = UiDirector.new()
	$UILayer.add_child(ui)
	ui.setup(levels, meta, textures, save, shop, engine)
	ui.stage_selected.connect(_enter_stage)
	ui.touch_action.connect(_on_touch_action)

func _load_data_and_textures() -> void:
	if FileAccess.file_exists("res://fonts/DroidSansFallbackFull.ttf"):
		var fbytes: PackedByteArray = FileAccess.get_file_as_bytes("res://fonts/DroidSansFallbackFull.ttf")
		if fbytes.size() > 0:
			var ff: FontFile = FontFile.new()
			ff.data = fbytes
			ThemeDB.fallback_font = ff

	var lf = FileAccess.open("res://data/levels_150.json", FileAccess.READ)
	if lf != null:
		levels = JSON.parse_string(lf.get_as_text())
	var mf = FileAccess.open("res://data/game_metadata.json", FileAccess.READ)
	if mf != null:
		meta = JSON.parse_string(mf.get_as_text())

	var assets_map: Dictionary = meta.get("assets", {})
	for key in assets_map.keys():
		var rel: String = "res://" + str(assets_map[key])
		if ResourceLoader.exists(rel):
			textures[key] = load(rel)
		elif FileAccess.file_exists(rel):
			var raw: PackedByteArray = FileAccess.get_file_as_bytes(rel)
			var im: Image = Image.new()
			var err: int = ERR_FILE_CORRUPT
			if rel.ends_with(".webp"):
				err = im.load_webp_from_buffer(raw)
			elif rel.ends_with(".png"):
				err = im.load_png_from_buffer(raw)
			elif rel.ends_with(".jpg") or rel.ends_with(".jpeg"):
				err = im.load_jpg_from_buffer(raw)
			if err == OK:
				textures[key] = ImageTexture.create_from_image(im)

func _enter_stage(stage_id: int) -> void:
	for lv in levels:
		if int(lv.get("id", 0)) == stage_id:
			engine.start_stage(lv)
			break

func _on_touch_action(act: String, pressed: bool) -> void:
	if act == "left":
		input_state["left"] = pressed
	elif act == "right":
		input_state["right"] = pressed
	elif pressed:
		if act == "jump":
			input_state["jump_just_pressed"] = true
		elif act == "shoot":
			input_state["shoot_pressed"] = true
		elif act == "slash":
			input_state["slash_pressed"] = true
		elif act == "bomb":
			input_state["bomb_pressed"] = true
		elif act == "gold":
			input_state["gold_pressed"] = true
		elif act == "layer":
			input_state["layer_pressed"] = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke = event as InputEventKey
		if ke.keycode in [KEY_A, KEY_LEFT]:
			input_state["left"] = ke.pressed
		elif ke.keycode in [KEY_D, KEY_RIGHT]:
			input_state["right"] = ke.pressed
		elif ke.pressed and not ke.echo:
			if ke.keycode in [KEY_SPACE, KEY_W, KEY_UP, KEY_K]:
				input_state["jump_just_pressed"] = true
			elif ke.keycode == KEY_J:
				input_state["shoot_pressed"] = true
			elif ke.keycode == KEY_U:
				input_state["slash_pressed"] = true
			elif ke.keycode in [KEY_B, KEY_I]:
				input_state["bomb_pressed"] = true
			elif ke.keycode == KEY_E:
				input_state["layer_pressed"] = true
			elif ke.keycode == KEY_G:
				input_state["gold_pressed"] = true
			elif ke.keycode == KEY_R:
				if not engine.player.is_empty() and bool(engine.player.get("dead", false)):
					engine.reset_attempt()
				else:
					engine.kill_player(true, "tactical_reset")

func _process(delta: float) -> void:
	audio.fill_buffer(save.volume)
	if not engine.current_level.is_empty():
		engine.step_frame(delta, input_state)
		ui.update_hud()
		queue_redraw()

func _pick_bg_key(lid: int, ch: int) -> String:
	if lid >= 101:
		return "s3_bg_ch%d" % clampi(ch, 11, 15)
	if lid >= 51:
		var m = { 6: "bg_s2_signal", 7: "bg_s2_foundry", 8: "bg_s2_mirror", 9: "bg_s2_biolab", 10: "bg_s2_core" }
		return str(m.get(ch, "bg_s2_signal"))
	return "cyber_skyline_bg"

func _pick_solid_tex(lid: int, s: Dictionary) -> String:
	var st = str(s.get("t", "solid"))
	var skin = str(s.get("skin", ""))
	if lid >= 101:
		if st == "s3_tall_pipe":
			return "s3_pipe_green"
		if st == "s3_cloud":
			return "s3_cloud_safe" if Sector3Arcadia.is_cloud_safe(s, bool(engine.state_bag["sundial_phase"])) else "s3_cloud_knife"
		if st == "qblock":
			return "s3_qblock"
		if skin == "wood":
			return "s3_wood_crate"
		if skin == "stone":
			return "s3_stone_brick"
		return "s3_ground_top"
	if st == "qblock":
		return "qblock"
	if st == "mirror":
		return "mirror_wall"
	return "s2_plat_ground_top" if lid >= 51 else "plat_cyber_top"

func _pick_entity_tex(lid: int, e: Dictionary) -> String:
	var et = str(e.get("t", ""))
	if et == "s3_valve": return "s3_valve_red"
	if et == "s3_bush": return "s3_bush_safe" if str(e.get("mode", "")) == "safe" else "s3_bush_blade"
	if et == "s3_flower": return "s3_pink_flower"
	if et == "s3_tanuki": return "s3_mon_tanuki"
	if et == "s3_manju": return "s3_mon_manju_cute"
	if et == "s3_ladybug": return "s3_mon_ladybug"
	if et == "s3_mole": return "s3_mon_mole"
	if et == "s3_sun": return "s3_sun_angry"
	if et == "s3_catapult": return "s3_catapult"
	if et == "s3_bomb_trophy": return "s3_bomb_trophy"
	if et == "s3_suction_pipe": return "s3_suction_pipe"
	if et == "s3_sundial": return "s3_sundial"
	if et == "s3_mimic_flag": return "s3_flag_idle" if bool(e.get("tamed", false)) else "s3_flag_mimic"
	if et == "s3_boss":
		var bk = str(e.get("boss_kind", ""))
		if bk == "pipe_kaiser": return "s3_boss_120"
		if bk == "kage_tanuki": return "s3_boss_130"
		if bk == "blade_archon": return "s3_boss_140"
		if bk == "solaris_painter": return "s3_boss_150"
		return "s3_boss_110"
	if et == "flag": return "s3_flag_idle" if lid >= 101 else "flag_idle"
	if et == "checkpoint": return "s3_checkpoint" if lid >= 101 else "checkpoint_off"
	if et == "spring": return "s3_mushroom_bounce" if lid >= 101 else "spring_idle"
	if et == "spike": return "s3_thorns" if lid >= 101 else "spike_neon"
	return "coin"

func _draw() -> void:
	if engine == null or engine.current_level.is_empty():
		return
	var lid = int(engine.current_level.get("id", 1))
	var ch = int(engine.current_level.get("chapter", 1))
	var bg_col = Color("#5cb8ff") if lid >= 101 else Color("#06091e")
	draw_rect(Rect2(0, 0, GridMath.VIEWPORT_W, GridMath.VIEWPORT_H), bg_col)

	var bg_key = _pick_bg_key(lid, ch)
	if textures.has(bg_key) and textures[bg_key] != null:
		draw_texture_rect(textures[bg_key], Rect2(0, 0, GridMath.VIEWPORT_W, GridMath.VIEWPORT_H), false)

	var cx = engine.cam_x
	for s in engine.solids:
		if bool(s.get("broken", false)):
			continue
		if (str(s["t"]) == "invis" or str(s["t"]) == "qblock") and not bool(s.get("revealed", true)):
			continue
		var r = Rect2(float(s["x"]) - cx, float(s["y"]), float(s["w"]), float(s["h"]))
		if r.end.x < -64 or r.position.x > 1024:
			continue
		var sk = _pick_solid_tex(lid, s)
		if textures.has(sk) and textures[sk] != null:
			draw_texture_rect(textures[sk], r, false)
		else:
			draw_rect(r, Color("#4ade80") if lid >= 101 else Color("#1e3a8a"))

	for e in engine.entities:
		var r = Rect2(float(e["x"]) - cx, float(e["y"]), float(e["w"]), float(e["h"]))
		if r.end.x < -64 or r.position.x > 1024:
			continue
		var ek = _pick_entity_tex(lid, e)
		if textures.has(ek) and textures[ek] != null:
			draw_texture_rect(textures[ek], r, false)
		else:
			draw_rect(r, Color("#fde047"))

	for b in engine.bullets:
		var br = Rect2(float(b["x"]) - cx, float(b["y"]), float(b["w"]), float(b["h"]))
		draw_rect(br, Color("#fde047") if bool(b.get("s3_wave", false)) else Color("#00f5ff"))

	for sh in engine.enemy_shots:
		var sr = Rect2(float(sh["x"]) - cx, float(sh["y"]), float(sh["w"]), float(sh["h"]))
		draw_rect(sr, Color("#fb7185"))

	if not engine.player.is_empty() and not bool(engine.player.get("dead", false)):
		var p = engine.player
		var pr = Rect2(float(p["x"]) - cx - 10.0, float(p["y"]) - 6.0, 48.0, 48.0)
		var modulate_col = Color(1.3, 1.15, 0.45, 1.0) if float(p.get("golden_timer", 0.0)) > 0.0 else Color.WHITE
		var hk = "hero_jump" if not bool(p.get("on_ground", false)) else ("hero_run1" if absf(float(p.get("vx", 0.0))) > 25.0 else "hero_idle")
		if textures.has(hk) and textures[hk] != null:
			var draw_w = -48.0 if int(p.get("facing", 1)) < 0 else 48.0
			var draw_x = pr.position.x + 48.0 if int(p.get("facing", 1)) < 0 else pr.position.x
			draw_texture_rect(textures[hk], Rect2(draw_x, pr.position.y, draw_w, 48.0), false, modulate_col)
		else:
			draw_rect(Rect2(float(p["x"]) - cx, float(p["y"]), float(p["w"]), float(p["h"])), modulate_col)
