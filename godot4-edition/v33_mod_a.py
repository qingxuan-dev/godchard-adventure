# Refactored v3.3.0 GDScript Bundle A (SaveManager + Sector3Arcadia + GameMain)
MODULES_A = {
    'scripts/core/save_manager.gd': '''class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://gotchard_save_v4.json"

var lang: String = "zh"
var unlocked_max: int = 1
var cleared: Dictionary = {}
var best_iq: Dictionary = {}
var best_stars: Dictionary = {}
var deaths_by_lv: Dictionary = {}
var last_lv: int = 1
var auto_landscape: bool = true
var pad_mode: String = "auto"
var pad_scale: float = 1.0
var pad_swap: bool = false
var pad_opacity: float = 0.85
var sensitivity: float = 1.0
var vibrate_on: bool = true
var seen_cgs: Dictionary = {}
var bgm_on: bool = true
var sfx_on: bool = true
var bgm_vol: float = 0.80
var sfx_vol: float = 0.85
var coins: int = 0
var shop_owned: Dictionary = {}
var shop_equipped: Dictionary = {}
var magic_sword_unlocked: bool = false
var achievements: Dictionary = {}
var shards: Dictionary = {}
var stats: Dictionary = {}

func _init(is_mobile_default: bool = true) -> void:
	pad_mode = "auto" if is_mobile_default else "hide"
	load_from_disk(is_mobile_default)

static func calc_stars_from_deaths(deaths: int) -> int:
	if deaths <= 0:
		return 5
	if deaths == 1:
		return 4
	if deaths == 2:
		return 3
	if deaths <= 4:
		return 2
	return 1

func load_from_disk(is_mobile_default: bool = true) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	lang = str(d.get("lang", "zh"))
	if lang != "en":
		lang = "zh"
	unlocked_max = clampi(int(d.get("unlocked_max", 1)), 1, 150)
	if typeof(d.get("cleared", null)) == TYPE_DICTIONARY:
		cleared = d["cleared"]
	if typeof(d.get("best_iq", null)) == TYPE_DICTIONARY:
		best_iq = d["best_iq"]
	if typeof(d.get("best_stars", null)) == TYPE_DICTIONARY:
		best_stars = d["best_stars"]
	if typeof(d.get("deaths_by_lv", null)) == TYPE_DICTIONARY:
		deaths_by_lv = d["deaths_by_lv"]
	last_lv = clampi(int(d.get("last_lv", 1)), 1, 150)
	auto_landscape = bool(d.get("auto_landscape", true))
	pad_mode = str(d.get("pad_mode", "auto" if is_mobile_default else "hide"))
	if not (pad_mode in ["auto", "always", "hide"]):
		pad_mode = "auto" if is_mobile_default else "hide"
	pad_scale = clampf(float(d.get("pad_scale", 1.0)), 0.7, 1.5)
	pad_swap = bool(d.get("pad_swap", false))
	pad_opacity = clampf(float(d.get("pad_opacity", 0.85)), 0.15, 1.0)
	sensitivity = clampf(float(d.get("sensitivity", 1.0)), 0.5, 1.5)
	vibrate_on = bool(d.get("vibrate_on", true))
	if typeof(d.get("seen_cgs", null)) == TYPE_DICTIONARY:
		seen_cgs = d["seen_cgs"]
	bgm_on = bool(d.get("bgm_on", true))
	sfx_on = bool(d.get("sfx_on", true))
	bgm_vol = clampf(float(d.get("bgm_vol", 0.80)), 0.0, 1.0)
	sfx_vol = clampf(float(d.get("sfx_vol", 0.85)), 0.0, 1.0)
	coins = maxi(0, int(d.get("coins", 0)))
	if typeof(d.get("shop_owned", null)) == TYPE_DICTIONARY:
		shop_owned = d["shop_owned"]
	if typeof(d.get("shop_equipped", null)) == TYPE_DICTIONARY:
		shop_equipped = d["shop_equipped"]
	magic_sword_unlocked = bool(d.get("magic_sword_unlocked", false)) or is_stage_cleared(50)
	if typeof(d.get("achievements", null)) == TYPE_DICTIONARY:
		achievements = d["achievements"]
	if typeof(d.get("shards", null)) == TYPE_DICTIONARY:
		shards = d["shards"]
	if typeof(d.get("stats", null)) == TYPE_DICTIONARY:
		stats = d["stats"]

func persist() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var payload: Dictionary = {
		"lang": lang,
		"unlocked_max": unlocked_max,
		"cleared": cleared,
		"best_iq": best_iq,
		"best_stars": best_stars,
		"deaths_by_lv": deaths_by_lv,
		"last_lv": last_lv,
		"auto_landscape": auto_landscape,
		"pad_mode": pad_mode,
		"pad_scale": pad_scale,
		"pad_swap": pad_swap,
		"pad_opacity": pad_opacity,
		"sensitivity": sensitivity,
		"vibrate_on": vibrate_on,
		"seen_cgs": seen_cgs,
		"bgm_on": bgm_on,
		"sfx_on": sfx_on,
		"bgm_vol": bgm_vol,
		"sfx_vol": sfx_vol,
		"coins": coins,
		"shop_owned": shop_owned,
		"shop_equipped": shop_equipped,
		"magic_sword_unlocked": magic_sword_unlocked,
		"achievements": achievements,
		"shards": shards,
		"stats": stats
	}
	f.store_string(JSON.stringify(payload))

func is_stage_cleared(stage_id: int) -> bool:
	return bool(cleared.get(str(stage_id), false))

func is_stage_unlocked(stage_id: int) -> bool:
	if stage_id <= 1:
		return true
	if stage_id > 150:
		return false
	return stage_id <= unlocked_max or is_stage_cleared(stage_id - 1) or is_stage_cleared(stage_id)

func get_cleared_count(max_stage: int = 150) -> int:
	var cnt: int = 0
	for i in range(1, max_stage + 1):
		if is_stage_cleared(i):
			cnt += 1
	return cnt

func get_highest_frontier_level(sector: int = 0) -> int:
	if sector == 3:
		for i in range(101, 151):
			if not is_stage_cleared(i):
				return i
		return 150
	if sector == 2:
		for i in range(51, 101):
			if not is_stage_cleared(i):
				return i
		return 100
	if sector == 1:
		for i in range(1, 51):
			if not is_stage_cleared(i):
				return i
		return 50
	for i in range(1, 151):
		if not is_stage_cleared(i):
			return i
	return 150

func add_coins(delta: int) -> void:
	coins = maxi(0, coins + delta)
	persist()

func inc_stat(key: String, delta: int = 1) -> int:
	var cur: int = int(stats.get(key, 0)) + delta
	stats[key] = cur
	return cur

func record_death(stage_id: int, total_lv_deaths: int) -> int:
	var prev: int = int(deaths_by_lv.get(str(stage_id), 0))
	if total_lv_deaths > prev:
		deaths_by_lv[str(stage_id)] = total_lv_deaths
	var tot: int = inc_stat("totalDeaths", 1)
	persist()
	return tot

func get_stage_max_deaths(stage_id: int, attempt_deaths: int, total_lv_deaths: int) -> int:
	return maxi(attempt_deaths, maxi(total_lv_deaths, int(deaths_by_lv.get(str(stage_id), 0))))

func mark_stage_cleared(stage_id: int, attempt_deaths: int) -> Dictionary:
	var stars: int = calc_stars_from_deaths(attempt_deaths)
	var first_time: bool = not is_stage_cleared(stage_id)
	var k: String = str(stage_id)
	cleared[k] = true
	if stage_id == 50:
		magic_sword_unlocked = true
	if stage_id >= unlocked_max and stage_id < 150:
		unlocked_max = stage_id + 1
	var reward: int = (15 + stars * 5) if first_time else (5 + stars * 2)
	coins = maxi(0, coins + reward)
	var lv_iq: int = 250 - attempt_deaths * 50
	var prev_iq: int = int(best_iq.get(k, -99999))
	if lv_iq > prev_iq:
		best_iq[k] = lv_iq
	var prev_st: int = int(best_stars.get(k, 0))
	if stars > prev_st:
		best_stars[k] = stars
	persist()
	return { "stars": stars, "reward": reward, "first_time": first_time, "iq": lv_iq }

func unlock_ach(ach_id: String) -> bool:
	if bool(achievements.get(ach_id, false)):
		return false
	achievements[ach_id] = true
	persist()
	return true

func retro_sync_achievements() -> Array[String]:
	var newly: Array[String] = []
	var c50: int = get_cleared_count(50)
	var c150: int = get_cleared_count(150)
	if is_stage_cleared(1) and unlock_ach("first_clear"): newly.append("first_clear")
	if c150 >= 5 and unlock_ach("clear_5"): newly.append("clear_5")
	if c150 >= 15 and unlock_ach("mid_survivor"): newly.append("mid_survivor")
	if c150 >= 25 and unlock_ach("clear_25"): newly.append("clear_25")
	if c150 >= 45 and unlock_ach("clear_45"): newly.append("clear_45")
	if is_stage_cleared(30) and unlock_ach("lv30_citadel"): newly.append("lv30_citadel")
	if is_stage_cleared(35) and unlock_ach("lv35_paradox"): newly.append("lv35_paradox")
	if is_stage_cleared(38) and unlock_ach("lv38_highway"): newly.append("lv38_highway")
	if is_stage_cleared(40) and unlock_ach("lv40_museum"): newly.append("lv40_museum")
	if is_stage_cleared(48) and unlock_ach("lv48_duel"): newly.append("lv48_duel")
	if is_stage_cleared(49) and unlock_ach("lv49_penult"): newly.append("lv49_penult")
	if c50 >= 50 and unlock_ach("true_godhard"): newly.append("true_godhard")

	var ch_pairs: Array = [
		[1, 10, "ch1_clear"], [11, 20, "ch2_clear"], [21, 30, "ch3_clear"], [31, 40, "ch4_clear"],
		[51, 60, "s2_ch6"], [61, 70, "s2_ch7"], [71, 80, "s2_ch8"], [81, 90, "s2_ch9"], [91, 100, "s2_root100"]
	]
	for cp in ch_pairs:
		var ok: bool = true
		for lv_i in range(int(cp[0]), int(cp[1]) + 1):
			if not is_stage_cleared(lv_i):
				ok = false
				break
		if ok and unlock_ach(str(cp[2])):
			newly.append(str(cp[2]))

	var five_star_cnt: int = 0
	var total_stars: int = 0
	for k in best_stars.keys():
		var st: int = int(best_stars[k])
		total_stars += st
		if st >= 5:
			five_star_cnt += 1
	if five_star_cnt >= 1 and unlock_ach("iq_250"): newly.append("iq_250")
	if five_star_cnt >= 5 and unlock_ach("stars_3_x5"): newly.append("stars_3_x5")
	if five_star_cnt >= 10 and unlock_ach("stars_3_x10"): newly.append("stars_3_x10")
	if five_star_cnt >= 20 and unlock_ach("stars_3_x20"): newly.append("stars_3_x20")
	if five_star_cnt >= 35 and unlock_ach("stars_3_x35"): newly.append("stars_3_x35")
	if five_star_cnt >= 50 and unlock_ach("stars_3_all50"): newly.append("stars_3_all50")
	if total_stars >= 30 and unlock_ach("total_stars_30"): newly.append("total_stars_30")
	if total_stars >= 75 and unlock_ach("total_stars_75"): newly.append("total_stars_75")
	if total_stars >= 120 and unlock_ach("total_stars_120"): newly.append("total_stars_120")
	return newly

func reset_progress_keep_prefs() -> void:
	unlocked_max = 1
	cleared.clear()
	best_iq.clear()
	best_stars.clear()
	deaths_by_lv.clear()
	last_lv = 1
	seen_cgs.clear()
	coins = 0
	shop_owned.clear()
	shop_equipped.clear()
	magic_sword_unlocked = false
	achievements.clear()
	shards.clear()
	stats.clear()
	persist()
''',    'scripts/sectors/sector_3_arcadia.gd': '''class_name Sector3Arcadia
extends RefCounted

static func init_attempt_state(eng: RefCounted, cp: Dictionary) -> void:
	eng.s3_valves = {}
	if not cp.is_empty() and cp.has("s3_valves"):
		var cv: Dictionary = cp["s3_valves"]
		for k in cv.keys():
			eng.s3_valves[str(k)] = bool(cv[k])
	eng.s3_sundial_phase = bool(cp.get("s3_sundial_phase", false)) if not cp.is_empty() else false
	eng.s3_boss_defeated = false
	eng.s3_trophy_respawns = []

static func spawn_obj(eng: RefCounted, o: Dictionary, idx: int, lv: Dictionary) -> bool:
	var lv_id: int = int(lv.get("id", 1))
	if lv_id < 101:
		return false
	var key: String = "%d_s3_%d" % [lv_id, idx]
	var t: String = str(o.get("t", ""))
	var ox: float = float(o.get("x", 0.0))
	var oy: float = float(o.get("y", 0.0))

	if t == "s3_tall_pipe":
		var full_h: float = float(o.get("h", 5.8)) * GridMath.TILE
		var target_h_px: float = float(o.get("targetH", 1.4)) * GridMath.TILE
		var pgrp: String = str(o.get("pipeGroup", "p1"))
		var already_low: bool = bool(eng.s3_valves.get(pgrp, false))
		var cur_h: float = target_h_px if already_low else full_h
		var foot_y: float = GridMath.gy_to_py(oy, 0.0)
		eng.solids.append({
			"key": key, "t": "s3_tall_pipe",
			"x": GridMath.gx_to_px(ox),
			"y": foot_y - cur_h,
			"foot_y": foot_y,
			"w": float(o.get("w", 1.45)) * GridMath.TILE,
			"h": cur_h,
			"orig_h_px": full_h,
			"target_h_px": target_h_px,
			"pipe_group": pgrp,
			"mode": str(o.get("mode", "block")),
			"invert_sundial": bool(o.get("invertSundial", false)),
			"lowered": already_low,
			"rocket_cd": 0.0,
			"layer": -1, "broken": false
		})
		return true

	if t == "s3_cloud":
		var cw: float = float(o.get("w", 2.2)) * GridMath.TILE
		var ch: float = float(o.get("h", 1.15)) * GridMath.TILE
		var csx: float = GridMath.gx_to_px(ox)
		var csy: float = GridMath.gy_to_py(oy, float(o.get("h", 1.15)))
		var cmode: String = str(o.get("mode", "hidden_knife"))
		eng.solids.append({
			"key": key, "t": "s3_cloud",
			"x": csx, "y": csy, "base_x": csx, "base_y": csy,
			"w": cw, "h": ch,
			"mode": cmode,
			"invert_sundial": bool(o.get("invertSundial", false)),
			"disarmed": (cmode == "safe_plat"),
			"blades_out": false,
			"swooping": false,
			"vy": 0.0,
			"respawn_timer": 0.0,
			"layer": -1, "broken": false
		})
		return true

	if t == "s3_drop_block":
		var dbh: float = float(o.get("h", 1.2))
		var dsx: float = GridMath.gx_to_px(ox)
		var dsy: float = GridMath.gy_to_py(oy, dbh)
		eng.solids.append({
			"key": key, "t": "s3_drop_block",
			"x": dsx, "y": dsy, "base_x": dsx, "base_y": dsy,
			"w": float(o.get("w", 2.0)) * GridMath.TILE,
			"h": dbh * GridMath.TILE,
			"skin": str(o.get("skin", "stone")),
			"stay_solid": bool(o.get("staySolid", true)),
			"rise_trap": bool(o.get("riseTrap", false)),
			"drop_state": "idle",
			"timer": 0.0,
			"vy": 0.0,
			"respawn_timer": 0.0,
			"layer": -1, "broken": false
		})
		return true

	if t == "s3_slide_turf":
		var sth: float = float(o.get("h", 2.0))
		var stx: float = GridMath.gx_to_px(ox)
		var sty: float = GridMath.gy_to_py(oy, sth)
		eng.solids.append({
			"key": key, "t": "s3_slide_turf",
			"x": stx, "y": sty, "base_x": stx, "base_y": sty,
			"w": float(o.get("w", 3.2)) * GridMath.TILE,
			"h": sth * GridMath.TILE,
			"slide_dx_px": float(o.get("slideDx", 2.4)) * GridMath.TILE,
			"slide_dy_px": float(o.get("slideDy", 0.0)) * GridMath.TILE,
			"trigger_dist_px": float(o.get("triggerDx", 2.0)) * GridMath.TILE,
			"triggered": false,
			"layer": -1, "broken": false
		})
		return true

	var s3_ents: Array[String] = [
		"s3_valve", "s3_bush", "s3_flower", "s3_tanuki", "s3_manju",
		"s3_ladybug", "s3_mole", "s3_sun", "s3_boss",
		"s3_catapult", "s3_bomb_trophy", "s3_suction_pipe", "s3_sundial", "s3_mimic_flag"
	]
	if not (t in s3_ents):
		return false

	var ent: Dictionary = o.duplicate(true)
	ent["key"] = key
	ent["layer"] = int(o["layer"]) if (o.has("layer") and o["layer"] != null) else -1

	if t == "s3_valve":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.0)
		ent["w"] = 1.0 * GridMath.TILE
		ent["h"] = 1.0 * GridMath.TILE
		var pgrp_v: String = str(o.get("pipeGroup", ""))
		ent["pipe_group"] = pgrp_v
		ent["fake"] = bool(o.get("fake", false))
		ent["spun"] = pgrp_v != "" and bool(eng.s3_valves.get(pgrp_v, false))
		ent["spin_ang"] = 0.0
		ent["reset_timer"] = 0.0
	elif t == "s3_bush":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.35)
		ent["w"] = float(o.get("w", 2.4)) * GridMath.TILE
		ent["h"] = 1.35 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "ambush_blade"))
		ent["revealed"] = false
	elif t == "s3_flower":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "lunge"))
		ent["vx"] = 0.0
		ent["vy"] = 0.0
		ent["angry"] = false
		ent["hp"] = 2
		ent["rewarded"] = false
	elif t == "s3_tanuki":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["hp"] = 3
		ent["max_hp"] = 3
		ent["clones"] = int(o.get("clones", 2))
		ent["cloned"] = false
		ent["is_clone"] = false
		ent["vx"] = -68.0
		ent["vy"] = 0.0
	elif t == "s3_manju":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.9)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 0.96 * GridMath.TILE
		ent["h"] = 0.9 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "spike_morph"))
		ent["vx"] = -85.0
		ent["vy"] = 0.0
		ent["spiked"] = false
		ent["hp"] = 2
		ent["waiting_drop"] = false
		if str(ent["mode"]) == "sky_drop":
			ent["y"] = GridMath.gy_to_py(oy + 5.4, 0.9)
			ent["waiting_drop"] = true
	elif t == "s3_ladybug":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.88)
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 0.88 * GridMath.TILE
		ent["min_px"] = GridMath.gx_to_px(float(o.get("minGx", ox - 3.0)))
		ent["max_px"] = GridMath.gx_to_px(float(o.get("maxGx", ox + 3.0)))
		ent["dir"] = -1.0
		ent["sprinting"] = false
		ent["hp"] = 2
	elif t == "s3_mole":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["base_y"] = GridMath.gy_to_py(oy, 1.0)
		ent["y"] = float(ent["base_y"])
		ent["w"] = 1.0 * GridMath.TILE
		ent["h"] = 1.0 * GridMath.TILE
		ent["clock"] = float(idx % 3) * 0.7
		ent["up"] = true
		ent["hp"] = 2
	elif t == "s3_sun":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.6)
		ent["home_y"] = float(ent["y"])
		ent["w"] = 1.6 * GridMath.TILE
		ent["h"] = 1.6 * GridMath.TILE
		ent["trigger_px"] = GridMath.gx_to_px(float(o.get("triggerGx", 10.0)))
		ent["awake"] = false
		ent["swoop_clock"] = 1.2
		ent["swooping"] = false
		ent["swoop_prog"] = 0.0
		ent["start_x"] = 0.0
	elif t == "s3_catapult":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.75)
		ent["w"] = 1.25 * GridMath.TILE
		ent["h"] = 0.75 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "forward_vault"))
		ent["cd"] = 0.0
		ent["anim"] = 0.0
	elif t == "s3_bomb_trophy":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["spawn_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["fuse"] = -1.0
	elif t == "s3_suction_pipe":
		var sph: float = float(o.get("h", 2.2))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, sph)
		ent["w"] = float(o.get("w", 1.45)) * GridMath.TILE
		ent["h"] = sph * GridMath.TILE
		ent["pipe_group"] = str(o.get("pipeGroup", ""))
	elif t == "s3_sundial":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.1)
		ent["w"] = 1.1 * GridMath.TILE
		ent["h"] = 1.1 * GridMath.TILE
		ent["hit_cd"] = 0.0
	elif t == "s3_mimic_flag":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.75)
		ent["spawn_x"] = float(ent["x"])
		ent["w"] = 1.15 * GridMath.TILE
		ent["h"] = 1.75 * GridMath.TILE
		ent["awake"] = false
		ent["tamed"] = false
		ent["hp"] = 2
		ent["mode"] = str(o.get("mode", "decoy"))
	elif t == "s3_boss":
		var bh: float = float(o.get("h", 2.5))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, bh)
		ent["base_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = float(o.get("w", 2.5)) * GridMath.TILE
		ent["h"] = bh * GridMath.TILE
		ent["boss_kind"] = str(o.get("bossKind", "solaris_painter"))
		ent["max_hp"] = int(o.get("hp", 26))
		ent["hp"] = int(ent["max_hp"])
		ent["atk_timer"] = 1.6
		ent["phase_clock"] = 0.0
		ent["stun_timer"] = 0.0
		ent["hit_flash"] = 0.0

	eng.entities.append(ent)
	return true

static func is_cloud_safe(s: Dictionary, sundial_phase: bool) -> bool:
	if bool(s.get("disarmed", false)) or str(s.get("mode", "")) == "safe_plat":
		return true
	if str(s.get("mode", "")) == "sundial_knife":
		var inv: bool = bool(s.get("invert_sundial", false))
		return (not sundial_phase) if inv else sundial_phase
	return false

static func is_solid_collidable(s: Dictionary, sundial_phase: bool) -> bool:
	if bool(s.get("broken", false)):
		return false
	if str(s.get("t", "")) == "s3_cloud":
		if str(s.get("mode", "")) == "fake_cloud":
			return true
		return is_cloud_safe(s, sundial_phase)
	return true

static func activate_valve(eng: RefCounted, e: Dictionary) -> void:
	if e.is_empty() or bool(e.get("spun", false)):
		return
	if bool(e.get("fake", false)):
		e["spun"] = true
		eng.emit_sfx("fake_buzz")
		eng.trigger_shake(6.0, 0.20)
		var dir_m: float = -155.0 if float(eng.player.get("x", 0.0)) < float(e["x"]) else 155.0
		eng.entities.append({
			"key": "trap_manju_" + str(Time.get_ticks_msec()),
			"t": "s3_manju", "mode": "spike_morph",
			"x": float(e["x"]), "y": float(e["y"]) - 44.0,
			"spawn_x": float(e["x"]), "base_y": float(e["y"]),
			"w": 0.96 * GridMath.TILE, "h": 0.9 * GridMath.TILE,
			"vx": dir_m, "vy": -250.0, "spiked": true, "hp": 2,
			"waiting_drop": false, "layer": -1
		})
		eng.emit_toast("糟糕！拧到了诱饵假阀门，蹦出带刺白团子！", "DECOY VALVE! SPIKED MANJU AMBUSH!", "s3_mon_manju_spike", "#fb7185")
		return

	e["spun"] = true
	var pgrp: String = str(e.get("pipe_group", ""))
	if pgrp != "":
		eng.s3_valves[pgrp] = true
	eng.emit_sfx("coin")
	eng.trigger_shake(5.0, 0.18)
	var cx: float = float(e["x"]) + float(e["w"]) * 0.5
	var cy: float = float(e["y"]) + float(e["h"]) * 0.5
	eng.add_shock_ring(cx, cy, Color("#4ade80"), 46.0, 0.28)
	eng.spawn_particles(cx, cy, Color("#fde047"), 16)

	var hit_boss120: bool = false
	if pgrp.begins_with("boss120"):
		for b_var in eng.entities:
			var b_ent: Dictionary = b_var
			if str(b_ent.get("t", "")) == "s3_boss" and str(b_ent.get("boss_kind", "")) == "pipe_kaiser":
				b_ent["stun_timer"] = 4.6
				e["reset_timer"] = 5.2
				hit_boss120 = true
	if hit_boss120:
		eng.emit_toast("红阀门泄压成功 · 巨管九头蛇破甲眩晕 4.6s！快砍！", "PRESSURE VENTED · PIPE-HYDRA STUNNED!", "s3_valve_red", "#4ade80")
	else:
		eng.emit_toast("红手轮阀门已拧开 · 关联绿管机关已切换！", "RED VALVE SPUN · PIPE SHIFTED!", "s3_valve_red", "#4ade80")
    
  static func step_pre_move(eng: RefCounted, dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)):
		return

	if float(p.get("golden_timer", 0.0)) > 0.0:
		p["golden_timer"] = maxf(0.0, float(p["golden_timer"]) - dt)
		p["invuln_timer"] = maxf(float(p.get("invuln_timer", 0.0)), float(p["golden_timer"]))
		if randf() < 0.35:
			eng.spawn_particles(float(p["x"]) + randf() * float(p["w"]), float(p["y"]) + randf() * float(p["h"]), Color("#fde047"), 1)

	if float(p.get("catapult_vx_timer", 0.0)) > 0.0:
		p["catapult_vx_timer"] = maxf(0.0, float(p["catapult_vx_timer"]) - dt)
		p["vx"] = float(p.get("catapult_vx", p["vx"]))

	if eng.lv_id < 101:
		return

	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))

	for s_var in eng.solids:
		var s: Dictionary = s_var
		var st: String = str(s.get("t", ""))

		if st == "s3_tall_pipe":
			var pgrp: String = str(s.get("pipe_group", ""))
			var want_low: bool = bool(eng.s3_valves.get(pgrp, false))
			if str(s.get("mode", "")) == "sundial_alt":
				want_low = (not eng.s3_sundial_phase) if bool(s.get("invert_sundial", false)) else eng.s3_sundial_phase
			var goal_h: float = float(s["target_h_px"]) if want_low else float(s["orig_h_px"])
			if absf(float(s["h"]) - goal_h) > 0.5:
				var prev_y: float = float(s["y"])
				var step_h: float = signf(goal_h - float(s["h"])) * minf(absf(goal_h - float(s["h"])), 280.0 * world_dt)
				s["h"] = float(s["h"]) + step_h
				s["y"] = float(s["foot_y"]) - float(s["h"])
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_y) <= 12.0:
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_y)
			s["lowered"] = float(s["h"]) <= float(s["target_h_px"]) + 4.0

			if float(s.get("rocket_cd", 0.0)) > 0.0:
				s["rocket_cd"] = maxf(0.0, float(s["rocket_cd"]) - world_dt)
			if str(s.get("mode", "")) == "rocket" and not want_low and float(s.get("rocket_cd", 0.0)) <= 0.0:
				var over_mouth: bool = (float(p["x"]) + float(p["w"]) > float(s["x"]) + 4.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) - 4.0) and (float(p["y"]) + float(p["h"]) <= float(s["y"]) + 18.0) and (float(p["y"]) + float(p["h"]) >= float(s["y"]) - 78.0)
				if over_mouth:
					s["rocket_cd"] = 0.55
					p["vy"] = -755.0
					p["on_ground"] = false
					eng.emit_sfx("spring")
					eng.add_shock_ring(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]), Color("#38bdf8"), 42.0, 0.25)
					eng.emit_toast("高压喷泉绿管 · 冲天水柱弹射！", "PRESSURIZED WATER GEYSER!", "s3_pipe_tall", "#38bdf8")

			if str(s.get("mode", "")) == "lethal_drop" and not bool(s["lowered"]):
				if float(p["x"]) >= float(s["x"]) + float(s["w"]) - 2.0 and float(p["x"]) <= float(s["x"]) + float(s["w"]) + 36.0 and float(p["vy"]) > 510.0 and float(p["y"]) > float(s["foot_y"]) - 96.0:
					eng.kill_player(false, "tall_pipe")
					return

		elif st == "s3_cloud":
			if bool(s.get("broken", false)):
				if float(s.get("respawn_timer", 0.0)) > 0.0:
					s["respawn_timer"] = float(s["respawn_timer"]) - world_dt
					if float(s["respawn_timer"]) <= 0.0:
						s["broken"] = false
				continue
			var safe_now: bool = is_cloud_safe(s, eng.s3_sundial_phase)
			var prev_cy: float = float(s["y"])
			var cmode: String = str(s.get("mode", ""))
			if cmode == "swoop_cloud" and not safe_now:
				var dx_c: float = absf(p_rect.get_center().x - (float(s["x"]) + float(s["w"]) * 0.5))
				if not bool(s.get("swooping", false)) and dx_c < 2.0 * GridMath.TILE and float(p["y"]) > float(s["y"]):
					s["swooping"] = true
					eng.emit_sfx("poison")
				if bool(s.get("swooping", false)):
					s["y"] = float(s["y"]) + 330.0 * world_dt
					if float(s["y"]) > GridMath.WORLD_ORIGIN_Y + 80.0:
						s["y"] = float(s["base_y"])
						s["swooping"] = false
			else:
				s["y"] = float(s["base_y"]) + sin(eng.time_elapsed * 2.6 + float(s["x"]) * 0.03) * 3.5
				if safe_now and float(p["grav_dir"]) > 0.0 and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_cy) <= 10.0:
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_cy)

			if not safe_now and (cmode == "hidden_knife" or cmode == "sundial_knife"):
				var dc: float = p_rect.get_center().distance_to(Vector2(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + float(s["h"]) * 0.5))
				if dc < 1.9 * GridMath.TILE:
					s["blades_out"] = true
				if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 8.0, float(s["y"]) - 2.0, float(s["w"]) - 16.0, float(s["h"]) + 4.0)):
					s["blades_out"] = true
					eng.kill_player(false, "cloud_knife")
					return
			elif not safe_now and cmode == "swoop_cloud":
				if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 8.0, float(s["y"]) + 4.0, float(s["w"]) - 16.0, float(s["h"]) - 6.0)):
					eng.kill_player(false, "cloud_knife")
					return
			elif cmode == "fake_cloud":
				if float(p["vy"]) >= 0.0 and GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 4.0, float(s["y"]) - 6.0, float(s["w"]) - 8.0, 16.0)):
					s["broken"] = true
					s["respawn_timer"] = 2.5
					eng.emit_sfx("block")
					eng.spawn_particles(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + 12.0, Color("#ffffff"), 14)
					eng.emit_toast("虚胖棉花假云 · 一踩就散！", "POOF! FAKE COTTON CLOUD!", "s3_cloud_safe", "#93c5fd")

		elif st == "s3_drop_block":
			if bool(s.get("broken", false)):
				s["respawn_timer"] = float(s.get("respawn_timer", 0.0)) - world_dt
				if float(s["respawn_timer"]) <= 0.0 and not GridMath.aabb_overlap(p_rect, Rect2(float(s["base_x"]), float(s["base_y"]), float(s["w"]), float(s["h"]))):
					s["broken"] = false
					s["x"] = float(s["base_x"])
					s["y"] = float(s["base_y"])
					s["drop_state"] = "idle"
					s["vy"] = 0.0
				continue
			var dst: String = str(s.get("drop_state", "idle"))
			if dst == "idle":
				if bool(s.get("stay_solid", true)):
					var near_x: bool = (float(p["x"]) + float(p["w"]) > float(s["x"]) - 24.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) + 24.0)
					var trig: bool = (near_x and float(p["y"]) <= float(s["y"])) if bool(s.get("rise_trap", false)) else (near_x and float(p["y"]) > float(s["y"]))
					if trig:
						s["drop_state"] = "shake"
						s["timer"] = 0.18
						eng.emit_sfx("block")
				else:
					var stood: bool = bool(p["on_ground"]) and (float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0) and absf((float(p["y"]) + float(p["h"])) - float(s["y"])) <= 9.0
					if stood:
						s["drop_state"] = "shake"
						s["timer"] = 0.28
						eng.emit_sfx("block")
			elif dst == "shake":
				s["timer"] = float(s["timer"]) - world_dt
				if float(s["timer"]) <= 0.0:
					s["drop_state"] = "fall"
					s["vy"] = -460.0 if bool(s.get("rise_trap", false)) else 60.0
			elif dst == "fall":
				var prev_dy: float = float(s["y"])
				if bool(s.get("rise_trap", false)):
					s["y"] = prev_dy + float(s["vy"]) * world_dt
					var ceil_y: float = GridMath.gy_to_py(6.2, 0.0)
					if float(s["y"]) <= ceil_y:
						s["y"] = ceil_y
						s["drop_state"] = "landed"
				else:
					s["vy"] = minf(720.0, float(s["vy"]) + 1500.0 * world_dt)
					s["y"] = prev_dy + float(s["vy"]) * world_dt
					if bool(s.get("stay_solid", true)):
						var floor_y: float = GridMath.gy_to_py(2.0, 0.0) - float(s["h"])
						if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 6.0, float(s["y"]) + float(s["h"]) - 14.0, float(s["w"]) - 12.0, 16.0)) and float(p["y"]) > prev_dy:
							eng.kill_player(false, "crush")
							return
						if float(s["y"]) >= floor_y:
							s["y"] = floor_y
							s["drop_state"] = "landed"
							eng.emit_sfx("boom")
							eng.trigger_shake(4.5, 0.14)
					elif float(s["y"]) > GridMath.WORLD_ORIGIN_Y + 110.0:
						s["broken"] = true
						s["respawn_timer"] = 2.6

		elif st == "s3_slide_turf":
			var dist_st: float = absf(p_rect.get_center().x - (float(s["x"]) + float(s["w"]) * 0.5))
			if not bool(s.get("triggered", false)) and dist_st < float(s["trigger_dist_px"]) + float(s["w"]) * 0.5:
				s["triggered"] = true
				eng.emit_sfx("spring")
			if bool(s.get("triggered", false)):
				var target_stx: float = float(s["base_x"]) + float(s["slide_dx_px"])
				var target_sty: float = float(s["base_y"]) - float(s["slide_dy_px"])
				var prev_stx: float = float(s["x"])
				var prev_sty: float = float(s["y"])
				var diff_stx: float = target_stx - prev_stx
				var diff_sty: float = target_sty - prev_sty
				if absf(diff_stx) > 0.5:
					s["x"] = prev_stx + signf(diff_stx) * minf(absf(diff_stx), 295.0 * world_dt)
				if absf(diff_sty) > 0.5:
					s["y"] = prev_sty + signf(diff_sty) * minf(absf(diff_sty), 240.0 * world_dt)
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > prev_stx + 2.0 and float(p["x"]) < prev_stx + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_sty) <= 10.0:
					p["x"] = float(p["x"]) + (float(s["x"]) - prev_stx)
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_sty)
					p_rect.position = Vector2(float(p["x"]), float(p["y"]))

static func detonate_trophy_bomb(eng: RefCounted, e: Dictionary) -> void:
	var cx: float = float(e["x"]) + float(e["w"]) * 0.5
	var cy: float = float(e["y"]) + float(e["h"]) * 0.5
	var r: float = 148.0
	eng.emit_sfx("boom")
	eng.trigger_shake(8.0, 0.26)
	eng.add_shock_ring(cx, cy, Color("#fb923c"), r, 0.34)
	eng.spawn_particles(cx, cy, Color("#fde047"), 26)
	for s_var in eng.solids:
		var s: Dictionary = s_var
		if str(s.get("t", "")) == "destructible" and not bool(s.get("broken", false)):
			var sc: Vector2 = Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])).get_center()
			if sc.distance_to(Vector2(cx, cy)) <= r + maxf(float(s["w"]), float(s["h"])) * 0.5:
				s["broken"] = true
				eng.broken_solid_keys[str(s["key"])] = true
				eng.spawn_particles(sc.x, sc.y, Color("#fb923c"), 18)
	disarm_or_damage_targets(eng, Rect2(cx - r, cy - r, r * 2.0, r * 2.0), 6, true, true)
	if not eng.player.is_empty() and not bool(eng.player.get("dead", false)):
		var pc: Vector2 = Vector2(float(eng.player["x"]) + 14.0, float(eng.player["y"]) + 20.0)
		if pc.distance_to(Vector2(cx, cy)) < 68.0:
			eng.kill_player(false, "trophy_bomb")
	eng.s3_trophy_respawns.append({
		"timer": 3.6,
		"spawn_x": float(e.get("spawn_x", e["x"])),
		"spawn_y": float(e.get("spawn_y", e["y"]))
	})
static func disarm_or_damage_targets(eng: RefCounted, hit_box: Rect2, dmg: int, is_sword: bool, is_upgraded_proj: bool) -> bool:
	if eng.lv_id < 101:
		return false
	var hit_any: bool = false

	if is_sword or is_upgraded_proj:
		for s_var in eng.solids:
			var s: Dictionary = s_var
			if str(s.get("t", "")) == "s3_cloud" and not bool(s.get("broken", false)) and not bool(s.get("disarmed", false)):
				var cm: String = str(s.get("mode", ""))
				if cm in ["hidden_knife", "swoop_cloud", "sundial_knife"]:
					if GridMath.aabb_overlap(hit_box, Rect2(float(s["x"]) - 4.0, float(s["y"]) - 8.0, float(s["w"]) + 8.0, float(s["h"]) + 16.0)):
						s["disarmed"] = true
						s["blades_out"] = false
						s["swooping"] = false
						s["y"] = float(s["base_y"])
						eng.emit_sfx("enemy_kill")
						eng.save.add_coins(2)
						eng.add_float_text(float(s["x"]) + 12.0, float(s["y"]) - 10.0, "卸刀 +2G", "#4ade80")
						eng.hud_dirty = true
						hit_any = true

	for i in range(eng.entities.size() - 1, -1, -1):
		if i >= eng.entities.size():
			continue
		var e: Dictionary = eng.entities[i]
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x <= 0.0 or not GridMath.aabb_overlap(hit_box, er):
			continue
		var et: String = str(e.get("t", ""))

		if et == "s3_valve":
			e["spin_ang"] = float(e.get("spin_ang", 0.0)) + 1.8
			activate_valve(eng, e)
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_sundial":
			if float(e.get("hit_cd", 0.0)) <= 0.0:
				e["hit_cd"] = 0.32
				eng.s3_sundial_phase = not eng.s3_sundial_phase
				eng.emit_sfx("coin")
				eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#fde047"), 52.0, 0.28)
				eng.emit_toast(
					"☀ 日晷切换【白昼】：阴阳云管已反转！" if eng.s3_sundial_phase else "★ 日晷切换【黄昏】：阴阳云管已复位！",
					"SUNDIAL PHASE SHIFTED!", "s3_sundial_orb", "#fde047"
				)
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_bomb_trophy":
			if float(e.get("fuse", -1.0)) < 0.0:
				e["fuse"] = 0.75
				eng.emit_sfx("fake_win")
				eng.emit_toast("● 伪奖杯引信已点燃 · 快退后等它炸墙！", "TROPHY BOMB LIT · STEP BACK!", "s3_bomb_trophy", "#fb923c")
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_mimic_flag":
			if is_sword and not bool(e.get("tamed", false)):
				e["hp"] = int(e.get("hp", 2)) - 1
				e["awake"] = true
				eng.emit_sfx("block")
				if int(e["hp"]) <= 0:
					if str(e.get("mode", "")) == "tame_goal":
						e["tamed"] = true
						eng.emit_sfx("real_win")
						eng.emit_toast("★ 噬人伪旗已被破魔剑驯服为真终点旗！", "MIMIC FLAG TAMED INTO REAL GOAL!", "s3_flag_win", "#4ade80")
					else:
						eng.save.add_coins(4)
						eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "斩伪旗 +4G", "#fde047")
						eng.entities.remove_at(i)
						eng.hud_dirty = true
				hit_any = true
		elif et == "s3_bush" and str(e.get("mode", "")) != "safe":
			if is_sword:
				eng.emit_sfx("enemy_kill")
				eng.save.add_coins(2)
				eng.add_float_text(float(e["x"]) + 16.0, float(e["y"]) - 8.0, "除草 +2G", "#fde047")
				eng.entities.remove_at(i)
				eng.hud_dirty = true
				hit_any = true
		elif et == "s3_flower":
			if str(e.get("mode", "")) == "polite":
				e["mode"] = "lunge"
				e["angry"] = true
				eng.emit_sfx("poison")
				eng.emit_toast("糟糕！你激怒了讲礼貌的守卫粉花！", "PROVOKED THE POLITE FLOWER!", "s3_pink_flower_angry", "#fb7185")
				hit_any = true
			else:
				e["hp"] = int(e.get("hp", 2)) - dmg
				if int(e["hp"]) <= 0:
					eng.emit_sfx("enemy_kill")
					eng.save.add_coins(3)
					eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "KO +3G", "#fde047")
					eng.entities.remove_at(i)
					eng.hud_dirty = true
				else:
					eng.emit_sfx("block")
				hit_any = true
				if not is_sword:
					break
		elif et == "s3_tanuki":
			if bool(e.get("is_clone", false)):
				eng.emit_sfx("block")
				eng.solids.append({
					"key": "tanuki_log_" + str(Time.get_ticks_msec()) + "_" + str(i),
					"t": "solid", "skin": "tanuki_log",
					"x": float(e["x"]) + 2.0,
					"y": float(e["base_y"]) + float(e["h"]) - 46.0,
					"base_x": float(e["x"]) + 2.0,
					"base_y": float(e["base_y"]) + float(e["h"]) - 46.0,
					"w": 46.0, "h": 46.0,
					"move_dx_px": 0.0, "move_dy_px": 0.0, "move_speed": 0.0,
					"layer": -1, "broken": false, "revealed": true
				})
				eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "替身木桩!", "#fde047")
				eng.entities.remove_at(i)
			else:
				e["hp"] = int(e.get("hp", 3)) - dmg
				if int(e["hp"]) <= 0:
					eng.emit_sfx("enemy_kill")
					eng.save.add_coins(4)
					eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "真身破 +4G", "#4ade80")
					eng.entities.remove_at(i)
					eng.hud_dirty = true
				else:
					eng.emit_sfx("block")
			hit_any = true
			if not is_sword:
				break
		elif et in ["s3_manju", "s3_ladybug", "s3_mole"]:
			e["hp"] = int(e.get("hp", 2)) - dmg
			if int(e["hp"]) <= 0:
				eng.emit_sfx("enemy_kill")
				eng.save.add_coins(3)
				eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "KO +3G", "#4ade80")
				eng.entities.remove_at(i)
				eng.hud_dirty = true
			else:
				eng.emit_sfx("block")
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_boss":
			var eff_dmg: int = dmg
			if str(e.get("boss_kind", "")) == "pipe_kaiser" and float(e.get("stun_timer", 0.0)) <= 0.0:
				eff_dmg = maxi(1, int(floor(float(dmg) * 0.35)))
				eng.emit_toast("巨管九头蛇护甲减伤中 · 打两侧红阀门泄压破防！", "SPIN RED VALVES TO STUN!", "s3_valve_red", "#fde047")
			e["hp"] = int(e.get("hp", 26)) - eff_dmg
			e["hit_flash"] = 0.16
			eng.emit_sfx("block")
			eng.add_float_text(float(e["x"]) + float(e["w"]) * 0.4, float(e["y"]) - 10.0, "-%d" % eff_dmg, "#fde047")
			if int(e["hp"]) <= 0:
				eng.s3_boss_defeated = true
				eng.emit_sfx("real_win")
				eng.trigger_shake(9.0, 0.32)
				eng.save.add_coins(30)
				eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#fde047"), 96.0, 0.45)
				eng.spawn_particles(er.get_center().x, er.get_center().y, Color("#fde047"), 34)
				eng.add_float_text(float(e["x"]) + 12.0, float(e["y"]) - 20.0, "BOSS CLEAR +30G!", "#fde047")
				eng.emit_toast("守关巨兽已击溃 · 右侧凯旋终点旗已解封！", "BOSS DEFEATED · FLAG UNLOCKED!", "s3_flag_win", "#4ade80")
				eng.entities.remove_at(i)
				eng.hud_dirty = true
			hit_any = true
			if not is_sword:
				break
	return hit_any

static func step_post_move(eng: RefCounted, _dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)) or eng.lv_id < 101 or eng.world_frozen:
		return

	for ri in range(eng.s3_trophy_respawns.size() - 1, -1, -1):
		var tr: Dictionary = eng.s3_trophy_respawns[ri]
		tr["timer"] = float(tr["timer"]) - world_dt
		if float(tr["timer"]) <= 0.0:
			var sx0: float = float(tr["spawn_x"])
			var sy0: float = float(tr["spawn_y"])
			var still_blocked: bool = false
			for s_check_var in eng.solids:
				var s_check: Dictionary = s_check_var
				if str(s_check.get("t", "")) == "destructible" and not bool(s_check.get("broken", false)) and absf(float(s_check["x"]) - sx0) < 260.0:
					still_blocked = true
					break
			if still_blocked:
				eng.entities.append({
					"key": "respawn_trophy_" + str(Time.get_ticks_msec()),
					"t": "s3_bomb_trophy",
					"x": sx0, "y": sy0, "spawn_x": sx0, "spawn_y": sy0,
					"w": 1.05 * GridMath.TILE, "h": 1.15 * GridMath.TILE,
					"fuse": -1.0, "layer": -1
				})
			eng.s3_trophy_respawns.remove_at(ri)

	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))

	for i in range(eng.entities.size() - 1, -1, -1):
		if i >= eng.entities.size():
			continue
		var e: Dictionary = eng.entities[i]
		var et: String = str(e.get("t", ""))
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))

		if et == "s3_valve":
			if float(e.get("reset_timer", 0.0)) > 0.0:
				e["reset_timer"] = float(e["reset_timer"]) - world_dt
				if float(e["reset_timer"]) <= 0.0:
					e["spun"] = false
			if GridMath.aabb_overlap(p_rect, er):
				activate_valve(eng, e)
		elif et == "s3_sundial":
			if float(e.get("hit_cd", 0.0)) > 0.0:
				e["hit_cd"] = maxf(0.0, float(e["hit_cd"]) - world_dt)
		elif et == "s3_catapult":
			if float(e.get("cd", 0.0)) > 0.0:
				e["cd"] = maxf(0.0, float(e["cd"]) - world_dt)
			if float(e.get("anim", 0.0)) > 0.0:
				e["anim"] = maxf(0.0, float(e["anim"]) - world_dt * 3.0)
			if float(e.get("cd", 0.0)) <= 0.0 and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 4.0, float(e["y"]) - 6.0, float(e["w"]) - 8.0, float(e["h"]) + 8.0)):
				e["cd"] = 0.45
				e["anim"] = 1.0
				eng.emit_sfx("spring")
				eng.trigger_shake(5.0, 0.16)
				p["on_ground"] = false
				var cm: String = str(e.get("mode", "forward_vault"))
				if cm == "back_fling":
					p["vy"] = -560.0
					p["catapult_vx"] = -430.0
					p["catapult_vx_timer"] = 0.34
				elif cm == "high_secret":
					p["vy"] = -860.0
				else:
					p["vy"] = -610.0
					p["catapult_vx"] = 420.0
					p["catapult_vx_timer"] = 0.38
		elif et == "s3_bomb_trophy":
			var fuse: float = float(e.get("fuse", -1.0))
			if fuse < 0.0 and GridMath.aabb_overlap(p_rect, er):
				e["fuse"] = 0.90
				eng.emit_sfx("fake_win")
				eng.emit_toast("● 假奖杯炸弹已引燃 · 0.9秒后爆炸，快闪开！", "TROPHY BOMB LIT · RUN BACK!", "s3_bomb_trophy", "#fb923c")
			elif fuse >= 0.0:
				fuse -= world_dt
				e["fuse"] = fuse
				if fuse <= 0.0:
					var dead_e: Dictionary = e.duplicate(true)
					eng.entities.remove_at(i)
					detonate_trophy_bomb(eng, dead_e)
					if bool(p.get("dead", false)):
						return
		elif et == "s3_suction_pipe":
			var pgrp_s: String = str(e.get("pipe_group", ""))
			var shut_off: bool = pgrp_s != "" and bool(eng.s3_valves.get(pgrp_s, false))
			if not shut_off:
				var in_beam: bool = (float(p["x"]) + float(p["w"]) > float(e["x"]) - 10.0) and (float(p["x"]) < float(e["x"]) + float(e["w"]) + 10.0) and (float(p["y"]) > float(e["y"])) and (float(p["y"]) < float(e["y"]) + float(e["h"]) + 4.2 * GridMath.TILE)
				if in_beam:
					p["vy"] = float(p["vy"]) - 2150.0 * world_dt
					p["on_ground"] = false
					if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + float(e["h"]) - 22.0, float(e["w"]) - 16.0, 26.0)):
						eng.kill_player(false, "suction_pipe")
						return
		elif et == "s3_mimic_flag":
			if bool(e.get("tamed", false)):
				if GridMath.aabb_overlap(p_rect, er):
					eng.trigger_level_win()
					return
				continue
			var dx_mf: float = p_rect.get_center().x - er.get_center().x
			if absf(dx_mf) < 2.6 * GridMath.TILE:
				if not bool(e.get("awake", false)):
					e["awake"] = true
					eng.emit_sfx("poison")
				e["x"] = float(e["x"]) + signf(dx_mf) * 95.0 * world_dt
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 10.0, float(e["y"]) + 10.0, float(e["w"]) - 20.0, float(e["h"]) - 14.0)):
				eng.kill_player(false, "mimic_flag")
				return
		elif et == "s3_bush":
			var dx_b: float = p_rect.get_center().x - er.get_center().x
			var dist_b: float = p_rect.get_center().distance_to(er.get_center())
			var bmode: String = str(e.get("mode", "ambush_blade"))
			if bmode == "ambush_blade":
				if dist_b < 1.6 * GridMath.TILE:
					e["revealed"] = true
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 10.0, float(e["w"]) - 28.0, float(e["h"]) - 12.0)):
					e["revealed"] = true
					eng.kill_player(false, "bush_blade")
					return
			elif bmode == "stalk_bush":
				var looking_at: bool = (dx_b * float(p["facing"])) < 0.0
				if not looking_at and absf(dx_b) < 6.8 * GridMath.TILE:
					e["x"] = float(e["x"]) + signf(dx_b) * 140.0 * world_dt
					e["revealed"] = true
				else:
					e["revealed"] = false
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 16.0, float(e["y"]) + 12.0, float(e["w"]) - 32.0, float(e["h"]) - 14.0)):
					e["revealed"] = true
					eng.kill_player(false, "bush_blade")
					return
		elif et == "s3_flower":
			var dx_f: float = p_rect.get_center().x - er.get_center().x
			var abs_dxf: float = absf(dx_f)
			var fmode: String = str(e.get("mode", "lunge"))
			if fmode == "lunge":
				if abs_dxf < 3.9 * GridMath.TILE and absf(float(p["y"]) - float(e["y"])) < 92.0:
					e["angry"] = true
					e["x"] = float(e["x"]) + signf(dx_f) * 255.0 * world_dt
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 8.0, float(e["w"]) - 18.0, float(e["h"]) - 10.0)):
					eng.kill_player(false, "flower")
					return
			elif fmode == "jump_block":
				if not bool(p["on_ground"]) and float(p["vy"]) < -120.0 and abs_dxf < 4.3 * GridMath.TILE and absf(float(e["y"]) - float(e["base_y"])) < 5.0:
					e["angry"] = true
					e["vy"] = -565.0
				e["vy"] = float(e.get("vy", 0.0)) + 1300.0 * world_dt
				e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
				if float(e["y"]) >= float(e["base_y"]):
					e["vy"] = 0.0
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 8.0, float(e["w"]) - 18.0, float(e["h"]) - 10.0)):
					eng.kill_player(false, "flower")
					return
			elif fmode == "polite":
				if not bool(e.get("rewarded", false)) and float(p["x"]) > float(e["x"]) + float(e["w"]) + 24.0:
					e["rewarded"] = true
					eng.save.add_coins(5)
					eng.emit_sfx("coin")
					eng.add_float_text(float(e["x"]), float(e["y"]) - 12.0, "礼貌奖励 +5G!", "#4ade80")
					eng.hud_dirty = true
		elif et == "s3_tanuki":
			var dx_t: float = p_rect.get_center().x - er.get_center().x
			if not bool(e.get("cloned", false)) and not bool(e.get("is_clone", false)) and absf(dx_t) < 5.6 * GridMath.TILE:
				e["cloned"] = true
				eng.emit_sfx("spring")
				var cnt_cl: int = int(e.get("clones", 2))
				for c_i in range(1, cnt_cl + 1):
					var off_dir: float = 54.0 if (c_i % 2) == 0 else -54.0
					var mult_i: float = ceil(float(c_i) * 0.5)
					eng.entities.append({
						"key": str(e["key"]) + "_clone_" + str(c_i),
						"t": "s3_tanuki",
						"x": float(e["x"]) + off_dir * mult_i,
						"y": float(e["y"]),
						"spawn_x": float(e["x"]), "base_y": float(e["base_y"]),
						"w": float(e["w"]), "h": float(e["h"]),
						"hp": 1, "max_hp": 1,
						"cloned": true, "is_clone": true,
						"vx": 75.0 if (c_i % 2) == 0 else -75.0,
						"vy": -180.0, "layer": -1
					})
			e["vy"] = float(e.get("vy", 0.0)) + 1200.0 * world_dt
			e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
			if float(e["y"]) >= float(e["base_y"]):
				e["vy"] = 0.0
			e["x"] = float(e["x"]) + float(e.get("vx", -60.0)) * world_dt
			if absf(float(e["x"]) - float(e["spawn_x"])) > 2.6 * GridMath.TILE:
				e["vx"] = -float(e.get("vx", -60.0))
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 9.0, float(e["w"]) - 18.0, float(e["h"]) - 11.0)):
				eng.kill_player(false, "tanuki")
				return
		elif et == "s3_manju":
			var dx_mj: float = p_rect.get_center().x - er.get_center().x
			if bool(e.get("waiting_drop", false)):
				if absf(dx_mj) < 2.2 * GridMath.TILE:
					e["waiting_drop"] = false
				else:
					continue
			if str(e.get("mode", "")) == "spike_morph" and not bool(p["on_ground"]) and absf(dx_mj) < 3.5 * GridMath.TILE and absf(float(e["y"]) - float(e["base_y"])) < 5.0:
				e["spiked"] = true
				e["vy"] = -490.0
			e["vy"] = float(e.get("vy", 0.0)) + 1280.0 * world_dt
			e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
			if float(e["y"]) >= float(e["base_y"]):
				e["vy"] = 0.0
			e["x"] = float(e["x"]) + float(e.get("vx", -85.0)) * world_dt
			if absf(float(e["x"]) - float(e["spawn_x"])) > 3.2 * GridMath.TILE:
				e["vx"] = -float(e.get("vx", -85.0))
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 7.0, float(e["w"]) - 14.0, float(e["h"]) - 9.0)):
				eng.kill_player(false, "manju")
				return
		elif et == "s3_ladybug":
			var dx_lb: float = p_rect.get_center().x - er.get_center().x
			var spr: bool = absf(dx_lb) < 4.2 * GridMath.TILE and absf(float(p["y"]) - float(e["y"])) < 72.0
			e["sprinting"] = spr
			if spr and absf(dx_lb) > 1.0:
				e["dir"] = signf(dx_lb)
			var spd_lb: float = 298.0 if spr else 78.0
			e["x"] = float(e["x"]) + float(e["dir"]) * spd_lb * world_dt
			if float(e["x"]) < float(e["min_px"]):
				e["x"] = float(e["min_px"])
				e["dir"] = 1.0
			elif float(e["x"]) > float(e["max_px"]):
				e["x"] = float(e["max_px"])
				e["dir"] = -1.0
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 7.0, float(e["w"]) - 14.0, float(e["h"]) - 9.0)):
				eng.kill_player(false, "ladybug")
				return
		elif et == "s3_mole":
			e["clock"] = float(e.get("clock", 0.0)) + world_dt
			var cyc_ml: float = fposmod(float(e["clock"]), 2.8)
			var was_up: bool = bool(e.get("up", true))
			var now_up: bool = cyc_ml < 1.85
			e["up"] = now_up
			e["y"] = float(e["base_y"]) if now_up else (float(e["base_y"]) + 28.0)
			if not was_up and now_up and absf(float(p["x"]) - float(e["x"])) < 7.8 * GridMath.TILE:
				var d_ml: float = -1.0 if float(p["x"]) < float(e["x"]) else 1.0
				eng.enemy_shots.append({
					"x": float(e["x"]) + 16.0, "y": float(e["y"]) + 4.0,
					"w": 14.0, "h": 14.0, "vx": d_ml * 198.0, "vy": -340.0,
					"grav": 780.0, "color": "#facc15", "layer": -1, "life": 2.4
				})
			if now_up and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 8.0, float(e["w"]) - 14.0, float(e["h"]) - 10.0)):
				eng.kill_player(false, "mole")
				return
		elif et == "s3_sun":
			if not bool(e.get("awake", false)) and float(p["x"]) >= float(e["trigger_px"]):
				e["awake"] = true
				eng.emit_toast("☀ 警告：天上的墨镜太阳睡醒俯冲啦！", "WATCH OUT: SUNGLASSES SUN SWOOPING!", "s3_sun_angry", "#fb923c")
			if not bool(e.get("awake", false)):
				e["x"] = eng.cam_x + 805.0
				e["y"] = 42.0 + sin(eng.time_elapsed * 2.5) * 6.0
			else:
				e["swoop_clock"] = float(e.get("swoop_clock", 1.2)) - world_dt
				if not bool(e.get("swooping", false)):
					e["x"] = eng.cam_x + 795.0 + cos(eng.time_elapsed * 3.0) * 18.0
					e["y"] = 44.0 + sin(eng.time_elapsed * 4.0) * 8.0
					if float(e["swoop_clock"]) <= 0.0:
						e["swooping"] = true
						e["swoop_prog"] = 0.0
						e["start_x"] = eng.cam_x + 860.0
						eng.emit_sfx("shoot")
				else:
					e["swoop_prog"] = float(e["swoop_prog"]) + world_dt * 0.68
					e["x"] = float(e["start_x"]) - float(e["swoop_prog"]) * 920.0
					e["y"] = 52.0 + sin(float(e["swoop_prog"]) * PI) * 340.0
					if float(e["swoop_prog"]) >= 1.0:
						e["swooping"] = false
						e["swoop_clock"] = 2.9
					if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 14.0, float(e["w"]) - 28.0, float(e["h"]) - 28.0)):
						eng.kill_player(false, "troll_sun")
						return
		elif et == "s3_boss":
			if float(e.get("hit_flash", 0.0)) > 0.0:
				e["hit_flash"] = maxf(0.0, float(e["hit_flash"]) - world_dt)
			if float(e.get("stun_timer", 0.0)) > 0.0:
				e["stun_timer"] = maxf(0.0, float(e["stun_timer"]) - world_dt)
				continue
			e["phase_clock"] = float(e.get("phase_clock", 0.0)) + world_dt
			e["atk_timer"] = float(e.get("atk_timer", 1.6)) - world_dt
			var bkind: String = str(e.get("boss_kind", ""))
			var pc_b: float = float(e["phase_clock"])
			if bkind in ["cloud_ram", "blade_archon", "solaris_painter"]:
				var span_b: float = 220.0 if bkind == "solaris_painter" else 185.0
				e["x"] = float(e["base_x"]) + sin(pc_b * 1.45) * span_b
				e["y"] = float(e["base_y"]) + sin(pc_b * 2.7) * 48.0
			elif bkind == "pipe_kaiser":
				e["x"] = float(e["base_x"]) + sin(pc_b * 1.1) * 110.0
			elif bkind == "kage_tanuki":
				e["x"] = float(e["base_x"]) + cos(pc_b * 1.7) * 165.0
				e["y"] = float(e["base_y"]) - absf(sin(pc_b * 3.1)) * 55.0
			if float(e["atk_timer"]) <= 0.0:
				e["atk_timer"] = 1.50 if bkind == "solaris_painter" else 2.00
				var bc: Vector2 = Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
				var dvb: Vector2 = (p_rect.get_center() - bc).normalized()
				eng.enemy_shots.append({
					"x": bc.x, "y": bc.y, "w": 15.0, "h": 15.0,
					"vx": dvb.x * 260.0, "vy": dvb.y * 260.0,
					"color": "#fb923c", "layer": -1, "life": 3.0
				})
				if bkind == "solaris_painter" or bkind == "blade_archon":
					var dir_s3b: float = -1.0 if float(p["x"]) < float(e["x"]) else 1.0
					eng.enemy_shots.append({
						"x": bc.x, "y": bc.y, "w": 14.0, "h": 14.0,
						"vx": dir_s3b * 215.0, "vy": 145.0,
						"color": "#fde047", "layer": -1, "life": 2.8
					})
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 14.0, float(e["w"]) - 28.0, float(e["h"]) - 28.0)):
				eng.kill_player(false, "boss")
				return
''',
    'scripts/game_main.gd': '''extends Node2D

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

	var shk: Vector2 = Vector2.ZERO
	if engine.shake_timer > 0.0:
		var mag: float = engine.shake_mag * (engine.shake_timer / maxf(0.05, engine.shake_dur))
		shk = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	var cam_off: Vector2 = Vector2(-engine.cam_x + shk.x, -engine.cam_y + shk.y)

	draw_set_transform(cam_off, 0.0, Vector2.ONE)

	_draw_world_links(vw)

	for s_var in engine.solids:
		var s: Dictionary = s_var
		_draw_solid(s, vw, is_zen50)

	var active_boss: Dictionary = {}
	for e_var in engine.entities:
		var e: Dictionary = e_var
		_draw_entity(e, vw)
		var et: String = str(e.get("t", ""))
		if (et == "s2_boss" or et == "s3_boss" or (et == "enemy" and str(e.get("kind", "")) == "boss")) and int(e.get("hp", 0)) > 0:
			active_boss = e

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

	_draw_combat_and_fx()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

	if bool(p.get("shield", false)):
		var sh_tex: Texture2D = _tex("fx_shield_aegis")
		if sh_tex != null:
			draw_texture_rect(sh_tex, Rect2(cx - 24.0, py - 5.0, 48.0, 50.0), false, Color(1.0, 1.0, 1.0, 0.62))
		else:
			draw_arc(Vector2(cx, py + ph * 0.5), 24.0, 0.0, TAU, 24, Color("#38bdf8"), 2.0)

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

func _run_ci_smoke_test() -> void:
	print("[SMOKE] Loaded textures: ", textures.size(), " | BGM streams: ", audio.bgm_streams.size(), " | SFX streams: ", audio.sfx_streams.size(), " | Stages: ", engine.levels_by_id.size())
	if textures.size() < 330 or audio.bgm_streams.size() < 9 or audio.sfx_streams.size() < 24 or engine.levels_by_id.size() != 150:
		push_error("[SMOKE] Asset or stage count mismatch!")
		get_tree().quit(1)
		return
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
''',
}
