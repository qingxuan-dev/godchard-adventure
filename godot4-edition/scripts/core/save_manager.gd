class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://gotchard_adventure_save_v4.json"

var lang: String = "zh"
var volume: float = 0.8
var sensitivity: float = 1.0
var unlocked_max: int = 1
var last_lv: int = 1
var coins: int = 0
var magic_sword_unlocked: bool = false
var cleared: Dictionary = {}
var best_stars: Dictionary = {}
var shop_owned: Dictionary = {}
var shop_equipped: Dictionary = {}

func _init() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		lang = str(d.get("lang", "zh"))
		volume = float(d.get("volume", 0.8))
		sensitivity = float(d.get("sensitivity", 1.0))
		unlocked_max = int(d.get("unlocked_max", 1))
		last_lv = int(d.get("last_lv", 1))
		coins = int(d.get("coins", 0))
		magic_sword_unlocked = bool(d.get("magic_sword_unlocked", false))
		cleared = d.get("cleared", {})
		best_stars = d.get("best_stars", {})
		shop_owned = d.get("shop_owned", {})
		shop_equipped = d.get("shop_equipped", {})

func persist() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var payload = {
		"lang": lang,
		"volume": volume,
		"sensitivity": sensitivity,
		"unlocked_max": unlocked_max,
		"last_lv": last_lv,
		"coins": coins,
		"magic_sword_unlocked": magic_sword_unlocked,
		"cleared": cleared,
		"best_stars": best_stars,
		"shop_owned": shop_owned,
		"shop_equipped": shop_equipped
	}
	f.store_string(JSON.stringify(payload))

## Strict sequential stage progression: ONLY Stage 1 unlocked on a fresh save.
func is_stage_unlocked(stage_id: int) -> bool:
	if stage_id == 1:
		return true
	return (
		bool(cleared.get(str(stage_id), false))
		or bool(cleared.get(str(stage_id - 1), false))
		or stage_id <= unlocked_max
	)

func add_coins(delta: int) -> void:
	if delta == 0:
		return
	coins = maxi(0, coins + delta)
	persist()

func record_stage_clear(stage_id: int, attempt_deaths: int) -> int:
	var stars: int = 5 if attempt_deaths == 0 else (4 if attempt_deaths <= 2 else (3 if attempt_deaths <= 5 else (2 if attempt_deaths <= 10 else 1)))
	var key = str(stage_id)
	var first_clear = not bool(cleared.get(key, false))
	cleared[key] = true
	if stage_id == 50:
		magic_sword_unlocked = true
	if stage_id >= unlocked_max and stage_id < 150:
		unlocked_max = stage_id + 1
	best_stars[key] = maxi(int(best_stars.get(key, 0)), stars)
	var reward: int = (15 + stars * 5) if first_clear else (5 + stars * 2)
	add_coins(reward)
	persist()
	return reward
