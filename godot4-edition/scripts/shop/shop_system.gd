class_name ShopSystem
extends RefCounted

## Settings-embedded Coin Armory (unlocked strictly after clearing Stage 50).
## Enforces the strict rule: EVERY item can only be used AT MOST ONCE per stage (`_used_in_stage`).
## Respawning at checkpoints, retrying after death, or toggling in Settings NEVER refills a spent item in the same stage.

var save: SaveManager
var catalog: Array = []
var _used_in_stage: Dictionary = {}

func _init(p_save: SaveManager, p_catalog: Array) -> void:
	save = p_save
	catalog = p_catalog

func is_unlocked() -> bool:
	return bool(save.cleared.get("50", false))

## Called ONLY when entering a stage via `start_stage(stage_id)` (never on retry/checkpoint respawn).
func reset_for_new_stage() -> void:
	_used_in_stage.clear()

func has_used_in_stage(item_id: String) -> bool:
	return bool(_used_in_stage.get(item_id, false))

func mark_used_in_stage(item_id: String) -> void:
	_used_in_stage[item_id] = true

func is_item_equipped(item_id: String) -> bool:
	if not is_unlocked():
		return false
	return bool(save.shop_owned.get(item_id, false)) and (save.shop_equipped.get(item_id, true) != false)

func apply_stage_buffs(player: Dictionary) -> void:
	if not is_unlocked() or bool(player.get("dead", false)):
		return

	if is_item_equipped("bomb_pack") and not has_used_in_stage("bomb_pack"):
		player["bombs"] = int(player.get("bombs", 0)) + 1
		mark_used_in_stage("bomb_pack")

	if is_item_equipped("aegis_shield") and not has_used_in_stage("aegis_shield"):
		player["shield"] = true
		mark_used_in_stage("aegis_shield")

	if is_item_equipped("bullet_plus") and not has_used_in_stage("bullet_plus"):
		if not bool(player.get("bullet_up", false)):
			player["from_shop_bullet"] = true
		player["bullet_up"] = true
		mark_used_in_stage("bullet_plus")

	if is_item_equipped("sword_plus") and not has_used_in_stage("sword_plus"):
		player["sword_up"] = true
		mark_used_in_stage("sword_plus")

	if is_item_equipped("golden_body") and not has_used_in_stage("golden_body"):
		player["gold_charges"] = 1
		player["golden_timer"] = 0.0
		mark_used_in_stage("golden_body")

	if is_item_equipped("wall_phase") and not has_used_in_stage("wall_phase"):
		player["has_wall_phase"] = true
		mark_used_in_stage("wall_phase")

	if is_item_equipped("sky_wings") and not has_used_in_stage("sky_wings"):
		if not bool(player.get("has_flight", false)):
			player["from_shop_flight"] = true
		player["has_flight"] = true
		mark_used_in_stage("sky_wings")

func trigger_golden_body(player: Dictionary) -> bool:
	if bool(player.get("dead", false)):
		return false
	if int(player.get("gold_charges", 0)) <= 0 or float(player.get("golden_timer", 0.0)) > 0.0:
		return false
	player["gold_charges"] = int(player.get("gold_charges", 0)) - 1
	mark_used_in_stage("golden_body")
	player["golden_timer"] = 10.0
	player["invuln_timer"] = maxf(float(player.get("invuln_timer", 0.0)), 10.0)
	return true

func purchase_or_toggle(item_id: String, in_active_stage: bool, player: Dictionary) -> String:
	var spec: Dictionary = {}
	for entry in catalog:
		if str(entry.get("id", "")) == item_id:
			spec = entry
			break
	if spec.is_empty() or not is_unlocked():
		return "需先通关第 50 关解锁设置内商城！"

	var price = int(spec.get("price", 100))
	var zh_name = str(spec.get("zhName", item_id))

	if not bool(save.shop_owned.get(item_id, false)):
		if save.coins < price:
			return "金币不足！需要 %d 金币" % price
		save.coins -= price
		save.shop_owned[item_id] = true
		save.shop_equipped[item_id] = true
		save.persist()
		if in_active_stage and not player.is_empty() and not bool(player.get("dead", false)):
			apply_stage_buffs(player)
		return "购买成功：已装备【%s】（每关限用1次）！" % zh_name

	var next_on = (save.shop_equipped.get(item_id, true) == false)
	save.shop_equipped[item_id] = next_on
	save.persist()

	if in_active_stage and not player.is_empty() and not bool(player.get("dead", false)):
		if next_on:
			if has_used_in_stage(item_id):
				return "【%s】在本关已使用过 1 次，下一关自动生效！" % zh_name
			apply_stage_buffs(player)
		else:
			if item_id == "sky_wings" and bool(player.get("from_shop_flight", false)):
				player["has_flight"] = false
				player["from_shop_flight"] = false
			elif item_id == "wall_phase":
				player["has_wall_phase"] = false
			elif item_id == "sword_plus":
				player["sword_up"] = false
			elif item_id == "bullet_plus" and bool(player.get("from_shop_bullet", false)):
				player["bullet_up"] = false
				player["from_shop_bullet"] = false
			elif item_id == "golden_body":
				player["gold_charges"] = 0
				player["golden_timer"] = 0.0

	return ("已开启【%s】" if next_on else "已关闭【%s】") % zh_name
