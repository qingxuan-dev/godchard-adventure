class_name LevelValidator
extends RefCounted

const SYSTEM_UUID_TARGETS: Array[String] = [
	"player", "world", "boss", "stage_exit", "camera", "timer", "sundial", "shop"
]

static func validate_level(lv: Dictionary, strict_v2: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if lv.is_empty():
		errors.append("Level dictionary is empty.")
		return { "valid": false, "level_id": -1, "errors": errors, "warnings": warnings, "stats": {} }

	var lv_id: int = int(lv.get("id", 0))
	if lv_id < 1 or lv_id > 150:
		errors.append("Invalid or missing level 'id': %d (expected 1..150)." % lv_id)

	if str(lv.get("name", "")).strip_edges() == "":
		errors.append("Missing level 'name'.")

	if typeof(lv.get("spawn", null)) != TYPE_DICTIONARY:
		errors.append("Missing or invalid 'spawn' dictionary.")
	if typeof(lv.get("bounds", null)) != TYPE_DICTIONARY:
		errors.append("Missing or invalid 'bounds' dictionary.")
	if typeof(lv.get("objs", null)) != TYPE_ARRAY:
		errors.append("Missing or invalid 'objs' array.")

	if not errors.is_empty():
		return { "valid": false, "level_id": lv_id, "errors": errors, "warnings": warnings, "stats": {} }

	var spawn: Dictionary = lv["spawn"]
	var bounds: Dictionary = lv["bounds"]
	var objs: Array = lv["objs"]
	var props: Dictionary = lv.get("props", {}) if typeof(lv.get("props", null)) == TYPE_DICTIONARY else {}

	if objs.is_empty():
		errors.append("Level 'objs' array cannot be empty.")

	var min_x: float = float(bounds.get("minX", -2.0))
	var max_x: float = float(bounds.get("maxX", 60.0))
	if max_x <= min_x + 4.0:
		errors.append("Invalid 'bounds': maxX (%.2f) must exceed minX (%.2f) by > 4 tiles." % [max_x, min_x])

	var sp_x: float = float(spawn.get("x", 0.0))
	var sp_y: float = float(spawn.get("y", 2.0))
	if sp_x < min_x - 2.0 or sp_x > max_x + 2.0:
		errors.append("Spawn x (%.2f) lies outside level bounds [%.2f, %.2f]." % [sp_x, min_x, max_x])

	# 1. Scan UUID uniqueness & TrapRegistry membership
	var uuid_set: Dictionary = {}
	var missing_uuid_count: int = 0
	var has_goal_candidate: bool = false
	var has_princess_lock: bool = false
	var has_princess_npc: bool = false
	var gem_count: int = 0
	var has_bomb_wall: bool = false
	var has_bomb_source: bool = false
	var spawn_has_support: bool = bool(props.get("startFlight", false))
	var spawn_rect: Rect2 = Rect2(
		GridMath.gx_to_px(sp_x) + 10.0,
		GridMath.gy_to_py(sp_y, 0.0) - 42.0,
		28.0,
		42.0
	)

	for idx in range(objs.size()):
		if typeof(objs[idx]) != TYPE_DICTIONARY:
			errors.append("objs[%d] is not a Dictionary." % idx)
			continue
		var o: Dictionary = objs[idx]
		var t: String = str(o.get("t", ""))
		if t == "":
			errors.append("objs[%d] missing object type 't'." % idx)
			continue
		if not TrapRegistry.has_type(t):
			errors.append("objs[%d] uses unregistered object type '%s'." % [idx, t])

		var uid: String = str(o.get("uuid", "")).strip_edges()
		if uid == "":
			missing_uuid_count += 1
		else:
			if uuid_set.has(uid):
				errors.append("Duplicate object uuid '%s' at objs[%d]." % [uid, idx])
			uuid_set[uid] = t

		var ox: float = float(o.get("x", 0.0))
		var oy: float = float(o.get("y", 0.0))
		var ow: float = float(o.get("w", 1.0))
		var oh: float = float(o.get("h", 1.0))

		if ox + ow < min_x - 16.0 or ox > max_x + 16.0:
			warnings.append("Object '%s' (objs[%d]) at x=%.1f is far outside horizontal bounds." % [t, idx, ox])

		# Check immediate spawn-kill overlap
		if t in ["spikes", "poop", "electric_arc"]:
			var hz_r: Rect2 = GridMath.grid_to_world_rect(ox, oy, maxf(0.6, ow), maxf(0.6, oh))
			var shrink_hz: Rect2 = Rect2(hz_r.position.x + 8.0, hz_r.position.y + 8.0, maxf(4.0, hz_r.size.x - 16.0), maxf(4.0, hz_r.size.y - 16.0))
			if GridMath.aabb_overlap(spawn_rect, shrink_hz):
				errors.append("Spawn overlaps immediate lethal hazard '%s' at objs[%d] (%.1f, %.1f)." % [t, idx, ox, oy])

		# Check floor support beneath spawn (within 5 tiles below spawn)
		if t in ["solid", "cloud", "s3_cloud", "vanish", "rail_plat", "phase_plat", "null_block", "conveyor", "shy_brick", "glass_panel", "s3_slide_turf", "s3_tall_pipe", "weight_scale", "fake_error"]:
			if sp_x + 0.8 >= ox - 0.5 and sp_x <= ox + ow + 0.5 and oy + oh <= sp_y + 1.5 and oy + oh >= sp_y - 6.0:
				spawn_has_support = true

		# Goal / Completion candidates
		if t == "flag" and not bool(o.get("fake", false)):
			has_goal_candidate = true
			if bool(o.get("lockedByPrincess", false)):
				has_princess_lock = true
		elif (t == "mimic_flag" and str(o.get("mode", "")) == "sword_tame") or (t == "s3_mimic_flag" and str(o.get("mode", "")) == "tame_goal"):
			has_goal_candidate = true
		elif (t == "qblock" or t == "invis") and str(o.get("loot", "")) in ["instant_win", "win"]:
			has_goal_candidate = true
			if str(o.get("loot", "")) == "gem_blue":
				gem_count += 1
		elif t == "root_term" and bool(o.get("winOnCalm", false)):
			has_goal_candidate = true
		elif t in ["s2_boss", "s3_boss", "enemy_boss"] and (bool(o.get("autoWinOnDefeat", false)) or str(o.get("bossKey", "")) != ""):
			has_goal_candidate = true

		if (t == "qblock" or t == "invis") and str(o.get("loot", "")) == "gem_blue":
			gem_count += 1
		if (t == "qblock" or t == "invis") and str(o.get("loot", "")) in ["bomb_supply", "poison", "antidote"]:
			has_bomb_source = true
		if t == "princess":
			has_princess_npc = true
		if t == "gem":
			gem_count += 1
		if t == "destructible" and not bool(o.get("bulletBreak", false)) and not bool(o.get("mirrorBreak", false)):
			has_bomb_wall = true
		if t in ["bomb_pickup", "chain_bomb", "s3_bomb_trophy", "poison_item", "amanita", "antidote_pad", "crafting"]:
			has_bomb_source = true

	# Also register checkpoints & collectibles top-level arrays into uuid_set
	if typeof(lv.get("checkpoints", null)) == TYPE_ARRAY:
		var cps: Array = lv["checkpoints"]
		for cp_idx in range(cps.size()):
			if typeof(cps[cp_idx]) == TYPE_DICTIONARY:
				var cp_d: Dictionary = cps[cp_idx]
				var cp_uid: String = str(cp_d.get("uuid", "")).strip_edges()
				if cp_uid != "":
					if uuid_set.has(cp_uid):
						errors.append("Duplicate checkpoint uuid '%s'." % cp_uid)
					uuid_set[cp_uid] = "checkpoint"

	if typeof(lv.get("collectibles", null)) == TYPE_ARRAY:
		var cols: Array = lv["collectibles"]
		for c_idx in range(cols.size()):
			if typeof(cols[c_idx]) == TYPE_DICTIONARY:
				var c_d: Dictionary = cols[c_idx]
				var c_t: String = str(c_d.get("t", "mem_shard"))
				if not TrapRegistry.has_type(c_t):
					errors.append("collectibles[%d] uses unregistered type '%s'." % [c_idx, c_t])
				var c_uid: String = str(c_d.get("uuid", "")).strip_edges()
				if c_uid != "":
					if uuid_set.has(c_uid):
						errors.append("Duplicate collectible uuid '%s'." % c_uid)
					uuid_set[c_uid] = c_t

	if strict_v2 and missing_uuid_count > 0:
		errors.append("%d object(s) in 'objs' are missing mandatory v2.0 'uuid' field." % missing_uuid_count)
	elif missing_uuid_count > 0:
		warnings.append("%d object(s) omit 'uuid' (fallback key will be generated at runtime)." % missing_uuid_count)

	# 2. Check completion_rule & exit existence
	if props.has("finalEmptyRoomX") or str(props.get("bossId", "")) != "":
		has_goal_candidate = true

	if typeof(lv.get("completion_rule", null)) == TYPE_DICTIONARY:
		var cr: Dictionary = lv["completion_rule"]
		var cr_type: String = str(cr.get("type", ""))
		if cr_type != "":
			has_goal_candidate = true
		var cr_target: String = str(cr.get("target_uuid", "")).strip_edges()
		if cr_target != "" and not (cr_target in SYSTEM_UUID_TARGETS) and not uuid_set.has(cr_target):
			errors.append("completion_rule.target_uuid '%s' does not match any object uuid in level." % cr_target)

	if not has_goal_candidate:
		errors.append("Level %03d has no reachable true exit / completion_rule / Boss win condition." % lv_id)

	# 3. Check logic_graph reference closure
	if typeof(lv.get("logic_graph", null)) == TYPE_ARRAY:
		var lg_arr: Array = lv["logic_graph"]
		var lg_ids: Dictionary = {}
		for lg_i in range(lg_arr.size()):
			if typeof(lg_arr[lg_i]) != TYPE_DICTIONARY:
				errors.append("logic_graph[%d] must be a Dictionary." % lg_i)
				continue
			var edge: Dictionary = lg_arr[lg_i]
			var eid: String = str(edge.get("id", "")).strip_edges()
			if eid != "":
				if lg_ids.has(eid):
					errors.append("Duplicate logic_graph edge id '%s'." % eid)
				lg_ids[eid] = true
			var trig_u: String = str(edge.get("trigger_uuid", "")).strip_edges()
			var targ_u: String = str(edge.get("target_uuid", "")).strip_edges()
			if trig_u == "" or targ_u == "":
				errors.append("logic_graph[%d] has empty trigger_uuid or target_uuid." % lg_i)
				continue
			if not (trig_u in SYSTEM_UUID_TARGETS) and not uuid_set.has(trig_u):
				errors.append("logic_graph[%d] trigger_uuid '%s' not found in level UUIDs." % [lg_i, trig_u])
			if not (targ_u in SYSTEM_UUID_TARGETS) and not uuid_set.has(targ_u):
				errors.append("logic_graph[%d] target_uuid '%s' not found in level UUIDs." % [lg_i, targ_u])

	# 4. Basic Anti-Softlock Checks
	if not spawn_has_support:
		warnings.append("No immediate floor detected within 6 tiles below spawn (%.1f, %.1f); verify carrier/gravity." % [sp_x, sp_y])

	if has_princess_lock and not has_princess_npc:
		errors.append("Flag has lockedByPrincess=true, but no 'princess' NPC exists in level.")
	if has_princess_lock and gem_count < 1:
		warnings.append("Flag is locked by princess, check that required gems are obtainable.")
	if has_bomb_wall and not has_bomb_source:
		warnings.append("Level contains bomb-only destructible wall without an obvious bomb/alchemy object.")

	return {
		"valid": errors.is_empty(),
		"level_id": lv_id,
		"errors": errors,
		"warnings": warnings,
		"stats": {
			"obj_count": objs.size(),
			"unique_uuids": uuid_set.size(),
			"has_goal": has_goal_candidate
		}
	}

static func validate_all_levels(levels: Array, strict_v2: bool = false) -> Dictionary:
	var reports: Array = []
	var failed_ids: Array[int] = []
	var seen_ids: Dictionary = {}
	var passed: int = 0

	for i in range(levels.size()):
		if typeof(levels[i]) != TYPE_DICTIONARY:
			failed_ids.append(-i - 1)
			reports.append({ "valid": false, "level_id": -i - 1, "errors": ["Entry is not a Dictionary."], "warnings": [] })
			continue
		var lv: Dictionary = levels[i]
		var rep: Dictionary = validate_level(lv, strict_v2)
		var lid: int = int(rep.get("level_id", 0))
		if seen_ids.has(lid):
			var errs: Array[String] = rep["errors"]
			errs.append("Duplicate level id %d across level pack." % lid)
			rep["valid"] = false
		seen_ids[lid] = true
		if bool(rep["valid"]):
			passed += 1
		else:
			failed_ids.append(lid)
		reports.append(rep)

	return {
		"valid": failed_ids.is_empty() and levels.size() > 0,
		"total": levels.size(),
		"passed": passed,
		"failed_ids": failed_ids,
		"reports": reports
	}
