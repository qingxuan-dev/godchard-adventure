class_name SaveManager
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
var pad_opacity: float = 0.94
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
	pad_opacity = clampf(float(d.get("pad_opacity", 0.94)), 0.25, 1.0)
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
