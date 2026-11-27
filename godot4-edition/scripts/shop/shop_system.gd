class_name ShopSystem
extends RefCounted

var save: SaveManager
var catalog: Array = []
var stage_used: Dictionary = {}
var stage_stall_purchases: Array = []
var map_lens_active: bool = false
var siphoned_stage_coins: int = 0
var active_debt_tags: int = 0

func _init(p_save: SaveManager = null, p_catalog: Array = []) -> void:
	save = p_save
	catalog = p_catalog.duplicate(true)
	_ensure_map_lens_in_catalog()

func _ensure_map_lens_in_catalog() -> void:
	for it_var in catalog:
		var it: Dictionary = it_var
		if str(it.get("id", "")) == "map_lens":
			return
	catalog.append({
		"id": "map_lens",
		"price": 80,
		"icon": "ui_hint",
		"zhName": "战术透视透镜",
		"enName": "TACTICAL MAP LENS",
		"zhDesc": "【每关限用1次】透视墙后隐藏电路、配重刻度与管道回声属性（不破坏核心解谜乐趣）。",
		"enDesc": "[1 Use / Stage] Reveals hidden wires, weight scales & pipe echo cues behind walls."
	})

func is_unlocked() -> bool:
	if save == null:
		return false
	return save.is_stage_cleared(50)

func reset_for_new_stage() -> void:
	stage_used.clear()
	stage_stall_purchases.clear()
	map_lens_active = false
	siphoned_stage_coins = 0
	active_debt_tags = 0

func has_used_in_stage(item_id: String) -> bool:
	return bool(stage_used.get(item_id, false))

func mark_used_in_stage(item_id: String) -> void:
	stage_used[item_id] = true

func is_owned(item_id: String) -> bool:
	if save == null:
		return false
	return bool(save.shop_owned.get(item_id, false))

func is_equipped(item_id: String) -> bool:
	if not is_owned(item_id):
		return false
	return bool(save.shop_equipped.get(item_id, true))

func is_active(item_id: String) -> bool:
	return is_unlocked() and is_equipped(item_id)

func buy_or_toggle(item_id: String, player: Dictionary, in_game: bool) -> Dictionary:
	if save == null or not is_unlocked():
		return { "ok": false, "reason": "locked" }
	var found: Dictionary = {}
	for it_var in catalog:
		var it: Dictionary = it_var
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
			elif item_id == "map_lens":
				map_lens_active = false
				player["map_lens"] = false
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
	if is_active("map_lens") and not has_used_in_stage("map_lens"):
		map_lens_active = true
		p["map_lens"] = true
		mark_used_in_stage("map_lens")

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

# --- In-stage v2.0 Shop Stall, Map Lens, Return Slot & Debt Tag Support (Lv015, Lv020, Lv037, Lv065) ---

func buy_stage_stall_item(stall: Dictionary, player: Dictionary, world_state: RefCounted = null) -> Dictionary:
	var item_kind: String = str(stall.get("shopItem", stall.get("mode", "trap")))
	var price: int = maxi(0, int(stall.get("price", 0)))
	if save != null and price > 0 and save.coins < price:
		# Per GDD 5.3 & v2.0 Lv015: currency never permanently softlocks stage progression; allow stage credit purchase!
		price = save.coins
	if save != null and price > 0:
		save.add_coins(-price)

	var record: Dictionary = { "kind": item_kind, "price": price }
	stage_stall_purchases.append(record)

	if item_kind == "map_lens":
		map_lens_active = true
		player["map_lens"] = true
		return { "ok": true, "effect": "map_lens_activated", "reveal_wires": true }
	if item_kind == "useless_receipt":
		player["has_receipt"] = true
		return { "ok": true, "effect": "useless_receipt", "true_wall_hint": true }
	if item_kind == "free_revive_coupon":
		active_debt_tags += 1
		player["revive_debt"] = true
		if world_state != null:
			world_state.reward_debt = int(world_state.reward_debt) + 1
		return { "ok": true, "effect": "revive_debt_incurred", "debt": active_debt_tags }
	if item_kind == "magnet_shield":
		player["shield"] = false
		return { "ok": true, "effect": "shield_magnetized_away" }
	return { "ok": true, "effect": item_kind, "price_paid": price }

func return_slot_refund(player: Dictionary, submitted_kind: String = "") -> Dictionary:
	var refunded_coins: int = 0
	if not stage_stall_purchases.is_empty():
		var last_rec: Dictionary = stage_stall_purchases.pop_back()
		refunded_coins = int(last_rec.get("price", 0))
		if save != null and refunded_coins > 0:
			save.add_coins(refunded_coins)
	player["revive_debt"] = false
	if submitted_kind == "fake_coin" or bool(player.get("has_fake_coin", false)):
		player["has_fake_coin"] = false
		return { "ok": true, "unlocked_exit": true, "refunded": refunded_coins, "reason": "fake_coin_returned" }
	return { "ok": true, "unlocked_exit": refunded_coins > 0 or active_debt_tags > 0, "refunded": refunded_coins, "reason": "item_recycled" }

func siphon_coins_for_debt(amount: int) -> int:
	if save == null or amount <= 0:
		return 0
	var actual: int = mini(save.coins, amount)
	if actual > 0:
		save.add_coins(-actual)
		siphoned_stage_coins += actual
	active_debt_tags += 1
	return actual

func settle_debt_at_register(player: Dictionary, world_state: RefCounted = null) -> Dictionary:
	var recovered: int = siphoned_stage_coins
	siphoned_stage_coins = 0
	active_debt_tags = 0
	player["revive_debt"] = false
	player["has_debt_tag"] = false
	if world_state != null:
		world_state.reward_debt = 0
	if save != null and recovered > 0:
		save.add_coins(recovered)
	return {
		"ok": true,
		"shop_closed": true,
		"recovered_coins": recovered
	}
