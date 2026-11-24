class_name ShopSystem
extends RefCounted

var save: SaveManager
var catalog: Array = []
var stage_used: Dictionary = {}

func _init(p_save: SaveManager, p_catalog: Array) -> void:
	save = p_save
	catalog = p_catalog

func is_unlocked() -> bool:
	return save.is_stage_cleared(50)

func reset_for_new_stage() -> void:
	stage_used.clear()

func has_used_in_stage(item_id: String) -> bool:
	return bool(stage_used.get(item_id, false))

func mark_used_in_stage(item_id: String) -> void:
	stage_used[item_id] = true

func is_owned(item_id: String) -> bool:
	return bool(save.shop_owned.get(item_id, false))

func is_equipped(item_id: String) -> bool:
	if not is_owned(item_id):
		return false
	return bool(save.shop_equipped.get(item_id, true))

func is_active(item_id: String) -> bool:
	return is_unlocked() and is_equipped(item_id)

func buy_or_toggle(item_id: String, player: Dictionary, in_game: bool) -> Dictionary:
	if not is_unlocked():
		return { "ok": false, "reason": "locked" }
	var found: Dictionary = {}
	for it in catalog:
		if str(it.get("id", "")) == item_id:
			found = it
			break
	if found.is_empty():
		return { "ok": false, "reason": "missing" }

	var price: int = int(found.get("price", 100))
	if not is_owned(item_id):
		if save.coins < price:
			return { "ok": false, "reason": "no_coins", "price": price }
		save.coins -= price
		save.shop_owned[item_id] = true
		save.shop_equipped[item_id] = true
		save.persist()
		if in_game and not player.is_empty() and not bool(player.get("dead", false)):
			apply_stage_buffs(player)
		return { "ok": true, "action": "bought", "item": found }
	else:
		var next_eq: bool = not is_equipped(item_id)
		save.shop_equipped[item_id] = next_eq
		save.persist()
		if in_game and not player.is_empty() and not bool(player.get("dead", false)):
			if next_eq:
				if has_used_in_stage(item_id):
					return { "ok": true, "action": "already_used_this_stage", "item": found }
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
				elif item_id == "aegis_shield" and bool(player.get("from_shop_shield", false)):
					player["shield"] = false
					player["from_shop_shield"] = false
				elif item_id == "bomb_pack" and bool(player.get("shop_bomb_pending", false)):
					player["bombs"] = maxi(0, int(player.get("bombs", 0)) - 1)
					player["shop_bomb_pending"] = false
				elif item_id == "golden_body":
					player["gold_charges"] = 0
					player["golden_timer"] = 0.0
		return { "ok": true, "action": "toggled", "equipped": next_eq, "item": found }

func apply_stage_buffs(p: Dictionary) -> void:
	if p.is_empty() or not is_unlocked():
		return
	if is_active("bomb_pack") and not has_used_in_stage("bomb_pack") and not bool(p.get("shop_bomb_pending", false)):
		p["bombs"] = int(p.get("bombs", 0)) + 1
		p["shop_bomb_pending"] = true
	if is_active("aegis_shield") and not has_used_in_stage("aegis_shield") and not bool(p.get("shield", false)):
		p["shield"] = true
		p["from_shop_shield"] = true
	if is_active("bullet_plus") and not has_used_in_stage("bullet_plus"):
		if not bool(p.get("bullet_up", false)):
			p["from_shop_bullet"] = true
		p["bullet_up"] = true
		mark_used_in_stage("bullet_plus")
	if is_active("sword_plus") and not has_used_in_stage("sword_plus"):
		p["sword_up"] = true
		mark_used_in_stage("sword_plus")
	if is_active("golden_body") and not has_used_in_stage("golden_body") and int(p.get("gold_charges", 0)) <= 0 and float(p.get("golden_timer", 0.0)) <= 0.0:
		p["gold_charges"] = 1
		p["golden_timer"] = 0.0
	if is_active("wall_phase") and not has_used_in_stage("wall_phase"):
		p["has_wall_phase"] = true
		mark_used_in_stage("wall_phase")
	if is_active("sky_wings") and not has_used_in_stage("sky_wings"):
		if not bool(p.get("has_flight", false)):
			p["from_shop_flight"] = true
		p["has_flight"] = true
		mark_used_in_stage("sky_wings")

func trigger_golden_body(p: Dictionary) -> bool:
	if p.is_empty() or bool(p.get("dead", false)):
		return false
	if int(p.get("gold_charges", 0)) <= 0 or float(p.get("golden_timer", 0.0)) > 0.0:
		return false
	p["gold_charges"] = int(p["gold_charges"]) - 1
	mark_used_in_stage("golden_body")
	p["golden_timer"] = 10.0
	p["invuln_timer"] = maxf(float(p.get("invuln_timer", 0.0)), 10.0)
	return true
