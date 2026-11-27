class_name SaveManager
extends RefCounted

const SCHEMA_VERSION: int = 4
const PRIMARY_SAVE_PATH: String = "user://save_primary.json"
const BACKUP_SAVE_PATH: String = "user://save_backup.json"
const TEMP_SAVE_PATH: String = "user://save_primary.tmp"
const SAVE_PATH: String = "user://gotchard_save_v4.json"
const CHECKSUM_SALT: String = "GOTCHARD_V4_ATOMIC_GUARD_2026"

var schema_version: int = SCHEMA_VERSION
var lang: String = "zh"
var unlocked_max: int = 1
var cleared: Dictionary = {}
var best_iq: Dictionary = {}
var best_stars: Dictionary = {}
var best_time_by_lv: Dictionary = {}
var medals_by_lv: Dictionary = {}
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

# Accessibility & Assist settings (Master GDD 11.3 & 12)
var colorblind_mode: bool = false
var visual_captions_on: bool = true
var screen_flash_scale: float = 1.0
var screen_shake_scale: float = 1.0
var assist_mode: bool = false

var recovered_from_backup: bool = false
var last_load_status: String = "fresh_init"

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

static func _canonicalize_variant(val: Variant) -> String:
	var t: int = typeof(val)
	if t == TYPE_DICTIONARY:
		var d: Dictionary = val
		var keys: Array = d.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var parts: PackedStringArray = PackedStringArray()
		for k in keys:
			var ks: String = str(k)
			if ks == "checksum" or ks == "updated_unix":
				continue
			parts.append(JSON.stringify(ks) + ":" + _canonicalize_variant(d[k]))
		return "{" + ",".join(parts) + "}"
	if t == TYPE_ARRAY:
		var arr: Array = val
		var items: PackedStringArray = PackedStringArray()
		for item in arr:
			items.append(_canonicalize_variant(item))
		return "[" + ",".join(items) + "]"
	if t == TYPE_FLOAT:
		return "%.4f" % float(val)
	if t == TYPE_INT:
		return str(int(val))
	if t == TYPE_BOOL:
		return "true" if bool(val) else "false"
	return JSON.stringify(str(val))

static func compute_payload_checksum(payload: Dictionary) -> String:
	var canonical: String = CHECKSUM_SALT + "|" + _canonicalize_variant(payload)
	return canonical.sha256_text()

static func verify_payload_integrity(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	if not d.has("checksum"):
		# Legacy v3.5.3 save has no checksum field; accept if core keys are valid types
		return d.has("unlocked_max") and typeof(d.get("cleared", null)) == TYPE_DICTIONARY
	var expected: String = str(d.get("checksum", ""))
	if expected == "":
		return false
	return compute_payload_checksum(d) == expected

func _read_verified_slot(path: String, require_checksum: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw_txt: String = f.get_as_text()
	f.close()
	if raw_txt.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw_txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if require_checksum and not d.has("checksum"):
		return {}
	if not verify_payload_integrity(d):
		return {}
	return d

func load_from_disk(is_mobile_default: bool = true) -> void:
	recovered_from_backup = false
	var d: Dictionary = _read_verified_slot(PRIMARY_SAVE_PATH, true)
	if not d.is_empty():
		last_load_status = "primary_ok"
	else:
		d = _read_verified_slot(BACKUP_SAVE_PATH, true)
		if not d.is_empty():
			recovered_from_backup = true
			last_load_status = "backup_recovered"
		else:
			d = _read_verified_slot(SAVE_PATH, false)
			if not d.is_empty():
				last_load_status = "legacy_migrated"
			else:
				last_load_status = "fresh_init"
				return

	_apply_loaded_dictionary(d, is_mobile_default)
	if recovered_from_backup or last_load_status == "legacy_migrated":
		persist()

func _apply_loaded_dictionary(d: Dictionary, is_mobile_default: bool) -> void:
	schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	lang = str(d.get("lang", "zh"))
	if lang != "en":
		lang = "zh"
	unlocked_max = clampi(int(d.get("unlocked_max", 1)), 1, 150)
	if typeof(d.get("cleared", null)) == TYPE_DICTIONARY:
		cleared = d["cleared"].duplicate(true)
	if typeof(d.get("best_iq", null)) == TYPE_DICTIONARY:
		best_iq = d["best_iq"].duplicate(true)
	if typeof(d.get("best_stars", null)) == TYPE_DICTIONARY:
		best_stars = d["best_stars"].duplicate(true)
	if typeof(d.get("best_time_by_lv", null)) == TYPE_DICTIONARY:
		best_time_by_lv = d["best_time_by_lv"].duplicate(true)
	if typeof(d.get("medals_by_lv", null)) == TYPE_DICTIONARY:
		medals_by_lv = d["medals_by_lv"].duplicate(true)
	if typeof(d.get("deaths_by_lv", null)) == TYPE_DICTIONARY:
		deaths_by_lv = d["deaths_by_lv"].duplicate(true)
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
		seen_cgs = d["seen_cgs"].duplicate(true)
	bgm_on = bool(d.get("bgm_on", true))
	sfx_on = bool(d.get("sfx_on", true))
	bgm_vol = clampf(float(d.get("bgm_vol", 0.80)), 0.0, 1.0)
	sfx_vol = clampf(float(d.get("sfx_vol", 0.85)), 0.0, 1.0)
	coins = maxi(0, int(d.get("coins", 0)))
	if typeof(d.get("shop_owned", null)) == TYPE_DICTIONARY:
		shop_owned = d["shop_owned"].duplicate(true)
	if typeof(d.get("shop_equipped", null)) == TYPE_DICTIONARY:
		shop_equipped = d["shop_equipped"].duplicate(true)
	magic_sword_unlocked = bool(d.get("magic_sword_unlocked", false)) or is_stage_cleared(50)
	if typeof(d.get("achievements", null)) == TYPE_DICTIONARY:
		achievements = d["achievements"].duplicate(true)
	if typeof(d.get("shards", null)) == TYPE_DICTIONARY:
		shards = d["shards"].duplicate(true)
	if typeof(d.get("stats", null)) == TYPE_DICTIONARY:
		stats = d["stats"].duplicate(true)

	colorblind_mode = bool(d.get("colorblind_mode", false))
	visual_captions_on = bool(d.get("visual_captions_on", true))
	screen_flash_scale = clampf(float(d.get("screen_flash_scale", 1.0)), 0.0, 1.0)
	screen_shake_scale = clampf(float(d.get("screen_shake_scale", 1.0)), 0.0, 1.0)
	assist_mode = bool(d.get("assist_mode", false))

	# Backfill copper medal for any legacy cleared stages
	for ck in cleared.keys():
		if bool(cleared[ck]) and not medals_by_lv.has(str(ck)):
			var st_prev: int = int(best_stars.get(str(ck), 1))
			medals_by_lv[str(ck)] = {
				"copper": true,
				"silver": st_prev >= 3,
				"gold": st_prev >= 5,
				"anti_troll": false
			}

func build_save_payload() -> Dictionary:
	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"lang": lang,
		"unlocked_max": unlocked_max,
		"cleared": cleared,
		"best_iq": best_iq,
		"best_stars": best_stars,
		"best_time_by_lv": best_time_by_lv,
		"medals_by_lv": medals_by_lv,
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
		"stats": stats,
		"colorblind_mode": colorblind_mode,
		"visual_captions_on": visual_captions_on,
		"screen_flash_scale": screen_flash_scale,
		"screen_shake_scale": screen_shake_scale,
		"assist_mode": assist_mode,
		"updated_unix": int(Time.get_unix_time_from_system())
	}
	payload["checksum"] = compute_payload_checksum(payload)
	return payload

func _write_text_file(path: String, content: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(content)
	f.flush()
	f.close()
	return true

func persist() -> void:
	var payload: Dictionary = build_save_payload()
	var json_text: String = JSON.stringify(payload)

	# 1. Rotate verified primary to backup slot before replacing primary
	var existing_primary: Dictionary = _read_verified_slot(PRIMARY_SAVE_PATH, true)
	if not existing_primary.is_empty():
		_write_text_file(BACKUP_SAVE_PATH, JSON.stringify(existing_primary))

	# 2. Write to temporary staging file first and verify readback
	if _write_text_file(TEMP_SAVE_PATH, json_text):
		var verified_tmp: Dictionary = _read_verified_slot(TEMP_SAVE_PATH, true)
		if not verified_tmp.is_empty():
			var abs_tmp: String = ProjectSettings.globalize_path(TEMP_SAVE_PATH)
			var abs_pri: String = ProjectSettings.globalize_path(PRIMARY_SAVE_PATH)
			var err: Error = DirAccess.rename_absolute(abs_tmp, abs_pri)
			if err != OK:
				_write_text_file(PRIMARY_SAVE_PATH, json_text)
	else:
		_write_text_file(PRIMARY_SAVE_PATH, json_text)

	# 3. Ensure backup exists on first creation and mirror legacy path for full compatibility
	if not FileAccess.file_exists(BACKUP_SAVE_PATH):
		_write_text_file(BACKUP_SAVE_PATH, json_text)
	_write_text_file(SAVE_PATH, json_text)

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

func get_stage_medals(stage_id: int) -> Dictionary:
	var k: String = str(stage_id)
	if medals_by_lv.has(k) and typeof(medals_by_lv[k]) == TYPE_DICTIONARY:
		var m: Dictionary = medals_by_lv[k]
		return {
			"copper": bool(m.get("copper", false)),
			"silver": bool(m.get("silver", false)),
			"gold": bool(m.get("gold", false)),
			"anti_troll": bool(m.get("anti_troll", false))
		}
	var is_clr: bool = is_stage_cleared(stage_id)
	return {
		"copper": is_clr,
		"silver": false,
		"gold": false,
		"anti_troll": false
	}

func get_medal_counts() -> Dictionary:
	var c_cnt: int = 0
	var s_cnt: int = 0
	var g_cnt: int = 0
	var a_cnt: int = 0
	for i in range(1, 151):
		var m: Dictionary = get_stage_medals(i)
		if bool(m["copper"]):
			c_cnt += 1
		if bool(m["silver"]):
			s_cnt += 1
		if bool(m["gold"]):
			g_cnt += 1
		if bool(m["anti_troll"]):
			a_cnt += 1
	return {
		"copper": c_cnt,
		"silver": s_cnt,
		"gold": g_cnt,
		"anti_troll": a_cnt
	}

func evaluate_stage_medals(
	stage_id: int,
	attempt_deaths: int,
	clear_time: float = 60.0,
	hints_used_tier: int = 0,
	collected_shard: bool = false,
	anti_troll_earned: bool = false,
	level_stars: int = 3
) -> Dictionary:
	var prev: Dictionary = get_stage_medals(stage_id)
	var silver_death_cap: int = clampi(1 + level_stars, 2, 6)
	var earned_copper: bool = true
	var earned_silver: bool = (attempt_deaths <= silver_death_cap) and (hints_used_tier <= 1)
	var earned_gold: bool = (
		(attempt_deaths == 0 and hints_used_tier == 0)
		or (collected_shard and attempt_deaths <= 2 and hints_used_tier == 0)
	)
	var earned_anti_troll: bool = anti_troll_earned
	var merged: Dictionary = {
		"copper": bool(prev["copper"]) or earned_copper,
		"silver": bool(prev["silver"]) or earned_silver,
		"gold": bool(prev["gold"]) or earned_gold,
		"anti_troll": bool(prev["anti_troll"]) or earned_anti_troll
	}
	medals_by_lv[str(stage_id)] = merged
	if clear_time > 0.0:
		var k_t: String = str(stage_id)
		var old_t: float = float(best_time_by_lv.get(k_t, 999999.0))
		if clear_time < old_t:
			best_time_by_lv[k_t] = snappedf(clear_time, 0.01)
	return merged

func mark_stage_cleared(stage_id: int, attempt_deaths: int, extra: Dictionary = {}) -> Dictionary:
	var stars: int = calc_stars_from_deaths(attempt_deaths)
	var first_time: bool = not is_stage_cleared(stage_id)
	var k: String = str(stage_id)
	cleared[k] = true
	if stage_id == 50:
		magic_sword_unlocked = true
	if stage_id >= unlocked_max and stage_id < 150:
		unlocked_max = stage_id + 1

	var clear_time: float = float(extra.get("time_elapsed", 60.0))
	var hints_tier: int = int(extra.get("hints_used_tier", 0))
	var got_shard: bool = bool(extra.get("collected_shard", false))
	var got_anti_troll: bool = bool(extra.get("anti_troll_earned", false))
	var lv_stars_cfg: int = int(extra.get("level_stars", 3))
	var medals: Dictionary = evaluate_stage_medals(
		stage_id, attempt_deaths, clear_time, hints_tier, got_shard, got_anti_troll, lv_stars_cfg
	)

	var medal_bonus: int = (6 if bool(medals["gold"]) else 0) + (8 if got_anti_troll else 0)
	var reward: int = ((15 + stars * 5) if first_time else (5 + stars * 2)) + medal_bonus
	coins = maxi(0, coins + reward)
	var lv_iq: int = 250 - attempt_deaths * 50
	var prev_iq: int = int(best_iq.get(k, -99999))
	if lv_iq > prev_iq:
		best_iq[k] = lv_iq
	var prev_st: int = int(best_stars.get(k, 0))
	if stars > prev_st:
		best_stars[k] = stars
	persist()
	return {
		"stars": stars,
		"reward": reward,
		"first_time": first_time,
		"iq": lv_iq,
		"medals": medals,
		"highest_medal": (
			"anti_troll" if bool(medals["anti_troll"])
			else ("gold" if bool(medals["gold"]) else ("silver" if bool(medals["silver"]) else "copper"))
		)
	}

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
	if is_stage_cleared(1) and unlock_ach("first_clear"):
		newly.append("first_clear")
	if c150 >= 5 and unlock_ach("clear_5"):
		newly.append("clear_5")
	if c150 >= 15 and unlock_ach("mid_survivor"):
		newly.append("mid_survivor")
	if c150 >= 25 and unlock_ach("clear_25"):
		newly.append("clear_25")
	if c150 >= 45 and unlock_ach("clear_45"):
		newly.append("clear_45")
	if is_stage_cleared(30) and unlock_ach("lv30_citadel"):
		newly.append("lv30_citadel")
	if is_stage_cleared(35) and unlock_ach("lv35_paradox"):
		newly.append("lv35_paradox")
	if is_stage_cleared(38) and unlock_ach("lv38_highway"):
		newly.append("lv38_highway")
	if is_stage_cleared(40) and unlock_ach("lv40_museum"):
		newly.append("lv40_museum")
	if is_stage_cleared(48) and unlock_ach("lv48_duel"):
		newly.append("lv48_duel")
	if is_stage_cleared(49) and unlock_ach("lv49_penult"):
		newly.append("lv49_penult")
	if c50 >= 50 and unlock_ach("true_godhard"):
		newly.append("true_godhard")

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
	if five_star_cnt >= 1 and unlock_ach("iq_250"):
		newly.append("iq_250")
	if five_star_cnt >= 5 and unlock_ach("stars_3_x5"):
		newly.append("stars_3_x5")
	if five_star_cnt >= 10 and unlock_ach("stars_3_x10"):
		newly.append("stars_3_x10")
	if five_star_cnt >= 20 and unlock_ach("stars_3_x20"):
		newly.append("stars_3_x20")
	if five_star_cnt >= 35 and unlock_ach("stars_3_x35"):
		newly.append("stars_3_x35")
	if five_star_cnt >= 50 and unlock_ach("stars_3_all50"):
		newly.append("stars_3_all50")
	if total_stars >= 30 and unlock_ach("total_stars_30"):
		newly.append("total_stars_30")
	if total_stars >= 75 and unlock_ach("total_stars_75"):
		newly.append("total_stars_75")
	if total_stars >= 120 and unlock_ach("total_stars_120"):
		newly.append("total_stars_120")
	return newly

func reset_progress_keep_prefs() -> void:
	unlocked_max = 1
	cleared.clear()
	best_iq.clear()
	best_stars.clear()
	best_time_by_lv.clear()
	medals_by_lv.clear()
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
