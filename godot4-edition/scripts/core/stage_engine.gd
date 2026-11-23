class_name StageEngine
extends RefCounted

var levels_by_id: Dictionary = {}
var save: SaveManager
var shop: ShopSystem

var lv_id: int = 1
var lv_data: Dictionary = {}

var player: Dictionary = {}
var solids: Array = []
var entities: Array = []
var bullets: Array = []
var enemy_shots: Array = []
var bombs: Array = []
var melee_arcs: Array = []

var particles: Array = []
var shock_rings: Array = []
var afterimages: Array = []
var float_texts: Array = []
var holo_shards: Array = []
var ko_effects: Array = []

var active_checkpoint: Dictionary = {}
var revealed_invis_keys: Dictionary = {}
var broken_solid_keys: Dictionary = {}
var filled_slot_keys: Dictionary = {}
var consumed_carry_keys: Dictionary = {}
var purified_save_keys: Dictionary = {}

var active_layer: int = 0
var signal_groups: Dictionary = {}
var polarity_groups: Dictionary = {}
var seq_progress: Dictionary = {}
var echo_clones: Array = []
var carrying_item: Dictionary = {}
var portal_cooldown: float = 0.0
var layer_switch_cd: float = 0.0
var plat_freeze_timer: float = 0.0
var beat_extend_bonus: float = 0.0
var in_time_bubble: bool = false
var s2_bomb_regen: float = 0.0

var s3_valves: Dictionary = {}
var s3_sundial_phase: bool = false
var s3_boss_defeated: bool = false
var s3_trophy_respawns: Array = []

var time_elapsed: float = 0.0
var move_time: float = 0.0
var timer_left: float = -1.0
var timer_rate: float = 1.0
var world_frozen: bool = false
var world_slow: bool = false
var rule_phase_b: bool = false
var rule_timer: float = 0.0
var poop_rain_timer: float = 0.0
var empty_room_still_time: float = 0.0
var fake_phase: int = 0
var fake_timer: float = 0.0
var grave_pos: Vector2 = Vector2.ZERO
var has_grave: bool = false
var paradox_unlocked: bool = false
var light_burst_timer: float = 0.0
var princess_satisfied: bool = false
var princess_perm_order: Array = ["red", "green", "blue"]
var collected_gems: Array = []
var alchemy_regen_timer: float = 0.0
var consumed_alchemy_pool: Array = []
var history_trail: Array = []
var last_trail_record_t: float = -1.0
var shadow_clone: Dictionary = {}

var attempt_deaths: int = 0
var total_lv_deaths: int = 0
var adaptive_stacks: int = 0
var loop_progress: int = 1
var xray_level: bool = false

var cam_x: float = 0.0
var cam_y: float = 0.0
var shake_timer: float = 0.0
var shake_dur: float = 0.2
var shake_mag: float = 0.0
var hit_stop_timer: float = 0.0
var shield_flash_timer: float = 0.0

var death_modal_delay: float = -1.0
var pending_death_cause: String = ""
var pending_death_modal_cause: String = ""
var pending_win_result: Dictionary = {}
var hud_dirty: bool = true

var sfx_queue: Array[String] = []
var toast_queue: Array = []
var ach_queue: Array[String] = []

func _init(p_levels: Array, p_save: SaveManager, p_shop: ShopSystem) -> void:
	save = p_save
	shop = p_shop
	for lv_var in p_levels:
		var lv: Dictionary = lv_var
		levels_by_id[int(lv.get("id", 1))] = lv

func emit_sfx(name: String) -> void:
	sfx_queue.append(name)

func emit_toast(zh: String, en: String, icon: String = "ui_hint", color_hex: String = "#00f5ff") -> void:
	toast_queue.append({ "zh": zh, "en": en, "icon": icon, "color": color_hex })

func unlock_ach(ach_id: String) -> void:
	if save.unlock_ach(ach_id):
		ach_queue.append(ach_id)
		emit_sfx("ach_unlock")

func is_magic_sword_enabled() -> bool:
	return save.magic_sword_unlocked or save.is_stage_cleared(50) or lv_id >= 51 or bool(player.get("sword_up", false))

func is_dual_layer_active() -> bool:
	return Sector1And2Mechanics.is_dual_layer_stage(lv_data)

func is_hint_unlocked() -> bool:
	return save.get_stage_max_deaths(lv_id, attempt_deaths, total_lv_deaths) >= 5

func get_max_deaths() -> int:
	return save.get_stage_max_deaths(lv_id, attempt_deaths, total_lv_deaths)

func start_stage(stage_id: int) -> void:
	lv_id = clampi(stage_id, 1, 150)
	lv_data = levels_by_id.get(lv_id, levels_by_id.get(1, {}))
	save.last_lv = lv_id
	save.persist()
	attempt_deaths = 0
	total_lv_deaths = int(save.deaths_by_lv.get(str(lv_id), 0))
	adaptive_stacks = 0
	loop_progress = 1
	xray_level = false
	active_checkpoint = {}
	revealed_invis_keys = {}
	broken_solid_keys = {}
	filled_slot_keys = {}
	consumed_carry_keys = {}
	purified_save_keys = {}
	pending_win_result = {}
	pending_death_modal_cause = ""
	death_modal_delay = -1.0
	# Strictly reset per-stage 1-use shop allowance ONLY when newly entering a stage!
	shop.reset_for_new_stage()
	reset_attempt()

func manual_fresh_restart() -> void:
	active_checkpoint = {}
	revealed_invis_keys = {}
	broken_solid_keys = {}
	filled_slot_keys = {}
	consumed_carry_keys = {}
	purified_save_keys = {}
	loop_progress = 1
	reset_attempt()

func _shuffle_gem_order() -> Array:
	var perms: Array = [
		["red", "green", "blue"], ["red", "blue", "green"],
		["green", "red", "blue"], ["green", "blue", "red"],
		["blue", "red", "green"], ["blue", "green", "red"]
	]
	return perms[randi() % perms.size()]

func reset_attempt() -> void:
	if lv_data.is_empty():
		return
	var props: Dictionary = lv_data.get("props", {})
	princess_perm_order = _shuffle_gem_order() if bool(props.get("randomGemOrder", false)) else ["red", "green", "blue"]
	time_elapsed = 0.0
	move_time = 0.0
	hit_stop_timer = 0.0
	alchemy_regen_timer = 0.0
	consumed_alchemy_pool = []
	timer_left = float(props["timer"]) if props.has("timer") else -1.0
	timer_rate = 1.0
	world_frozen = false
	world_slow = false
	rule_phase_b = false
	rule_timer = 0.0
	poop_rain_timer = 0.0
	empty_room_still_time = 0.0
	fake_phase = 0
	fake_timer = 0.0
	has_grave = false
	paradox_unlocked = false
	light_burst_timer = 0.0
	princess_satisfied = false
	collected_gems = []
	bullets = []
	enemy_shots = []
	bombs = []
	melee_arcs = []
	particles = []
	shock_rings = []
	afterimages = []
	float_texts = []
	holo_shards = []
	ko_effects = []
	shield_flash_timer = 0.0
	history_trail = []
	last_trail_record_t = -1.0
	shadow_clone = {}
	death_modal_delay = -1.0
	pending_death_modal_cause = ""
	pending_win_result = {}

	filled_slot_keys = active_checkpoint.get("filled_slot_keys", {}).duplicate(true) if not active_checkpoint.is_empty() else {}
	consumed_carry_keys = active_checkpoint.get("consumed_carry_keys", {}).duplicate(true) if not active_checkpoint.is_empty() else {}
	broken_solid_keys = active_checkpoint.get("broken_solid_keys", {}).duplicate(true) if not active_checkpoint.is_empty() else {}

	var spawn_d: Dictionary = lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
	var sp_gx: float = float(active_checkpoint.get("x", spawn_d.get("x", 2.0))) if not active_checkpoint.is_empty() else float(spawn_d.get("x", 2.0))
	var sp_gy: float = float(active_checkpoint.get("y", spawn_d.get("y", 2.0))) if not active_checkpoint.is_empty() else float(spawn_d.get("y", 2.0))
	var spx: float = GridMath.gx_to_px(sp_gx) + 10.0
	var spy: float = GridMath.gy_to_py(sp_gy, 0.0) - 42.0

	var start_jumps: int = maxi(int(props.get("startJumps", 1)), int(active_checkpoint.get("max_jumps", 1)) if not active_checkpoint.is_empty() else 1)
	player = {
		"x": spx, "y": spy, "w": 28.0, "h": 42.0,
		"vx": 0.0, "vy": 0.0,
		"facing": 1, "grav_dir": 1.0,
		"on_ground": false, "was_on_ground": false,
		"coyote": 0.0,
		"jumps_left": start_jumps,
		"max_jumps": start_jumps,
		"has_flight": bool(active_checkpoint.get("has_flight", false)) if not active_checkpoint.is_empty() else false,
		"from_shop_flight": false,
		"has_wall_phase": false,
		"shield": bool(props.get("startShield", false)),
		"bullet_up": bool(props.get("bulletUp", false)) or (bool(active_checkpoint.get("bullet_up", false)) if not active_checkpoint.is_empty() else false),
		"from_shop_bullet": false,
		"sword_up": false,
		"bombs": 0,
		"gold_charges": 0,
		"golden_timer": 0.0,
		"poison_timer": 0.0,
		"antidote_window": 0.0,
		"invuln_timer": 0.0,
		"attack_anim": 0.0,
		"melee_cd": 0.0,
		"melee_anim": 0.0,
		"walk_cycle": 0.0,
		"step_dust_timer": 0.0,
		"turn_dust_cd": 0.0,
		"spring_trail_timer": 0.0,
		"afterimage_timer": 0.0,
		"catapult_vx": 0.0,
		"catapult_vx_timer": 0.0,
		"heat_meter": 0.0,
		"heavy_curse_timer": 0.0,
		"reverse_curse_timer": 0.0,
		"in_curse_mirror": false,
		"in_curse_jump_shot": false,
		"scale_x": 1.0, "scale_y": 1.0,
		"scale_vx": 0.0, "scale_vy": 0.0,
		"tilt_rad": 0.0,
		"dead": false
	}

	solids = []
	entities = []
	Sector1And2Mechanics.init_attempt_state(self, lv_data, props, active_checkpoint)
	Sector3Arcadia.init_attempt_state(self, active_checkpoint)
	# Apply equipped shop buffs ONLY if not yet used in this stage!
	shop.apply_stage_buffs(player)

	var objs: Array = lv_data.get("objs", [])
	for idx in range(objs.size()):
		var o: Dictionary = objs[idx]
		if lv_id >= 101 and Sector3Arcadia.spawn_obj(self, o, idx, lv_data):
			continue
		if lv_id >= 51 and Sector1And2Mechanics.spawn_obj(self, o, idx, lv_data):
			continue
		_spawn_core_obj(o, idx)

	if bool(props.get("adaptive", false)) and adaptive_stacks > 0:
		for s_i in range(mini(4, adaptive_stacks)):
			entities.append({
				"key": "adapt_" + str(s_i), "t": "poop",
				"x": GridMath.gx_to_px(8.2 + float(s_i) * 3.1),
				"y": GridMath.gy_to_py(2.0, 0.88),
				"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE,
				"falling_poop": false, "layer": -1
			})

	if bool(props.get("escalateLoop", false)) and loop_progress >= 2:
		entities.append({
			"key": "loop_imp", "t": "enemy", "kind": "follower",
			"x": GridMath.gx_to_px(8.2), "y": GridMath.gy_to_py(2.0, 1.05),
			"w": 0.92 * GridMath.TILE, "h": 1.02 * GridMath.TILE,
			"vx": 0.0, "vy": 0.0, "hp": 5, "max_hp": 5, "layer": -1
		})
		if loop_progress >= 3:
			for fx in [25.8, 30.4]:
				entities.append({
					"key": "loop_fl_" + str(fx), "t": "flower",
					"x": GridMath.gx_to_px(fx), "y": GridMath.gy_to_py(2.0, 0.88),
					"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE, "layer": -1
				})

	update_camera(1.0)
	hud_dirty = true

func _spawn_core_obj(o: Dictionary, idx: int) -> void:
	var key: String = "%d_%d" % [lv_id, idx]
	var t: String = str(o.get("t", ""))
	var ox: float = float(o.get("x", 0.0))
	var oy: float = float(o.get("y", 0.0))
	var layer_val: int = int(o["layer"]) if (o.has("layer") and o["layer"] != null) else -1

	if t in ["solid", "fake_wall", "vanish", "fake_plat", "destructible", "mirror", "paradox_gate", "timed_gate"]:
		var oh: float = float(o.get("h", 1.0))
		var sx0: float = GridMath.gx_to_px(ox)
		var sy0: float = GridMath.gy_to_py(oy, oh)
		solids.append({
			"key": key, "t": t,
			"x": sx0, "y": sy0, "base_x": sx0, "base_y": sy0,
			"w": float(o.get("w", 1.0)) * GridMath.TILE,
			"h": oh * GridMath.TILE,
			"skin": str(o.get("skin", "steel")),
			"bullet_break": bool(o.get("bulletBreak", false)),
			"mirror_break": bool(o.get("mirrorBreak", false)),
			"move_dx_px": float(o.get("moveDx", 0.0)) * GridMath.TILE,
			"move_dy_px": float(o.get("moveDy", 0.0)) * GridMath.TILE,
			"move_speed": float(o.get("moveSpeed", 0.0)),
			"open_time": float(o.get("openTime", 5.0)),
			"vanish_timer": -1.0,
			"respawn_timer": 0.0,
			"gate_open": false,
			"shattered": false,
			"shatter_anim": 0.0,
			"bump_offset": 0.0,
			"revealed": true,
			"layer": layer_val,
			"broken": bool(broken_solid_keys.get(key, false))
		})
	elif t == "invis":
		solids.append({
			"key": key, "t": "invis",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, 0.72),
			"w": float(o.get("w", 1.2)) * GridMath.TILE, "h": 0.72 * GridMath.TILE,
			"step_reveal": bool(o.get("stepReveal", false)),
			"s3_kaizo": bool(o.get("s3Kaizo", false)),
			"loot": str(o.get("loot", "")),
			"revealed": bool(revealed_invis_keys.get(key, false)),
			"looted": false,
			"bump_offset": 0.0,
			"move_dx_px": 0.0, "move_dy_px": 0.0,
			"layer": layer_val, "broken": false
		})
	elif t == "qblock":
		var is_inv: bool = bool(o.get("invis", false))
		solids.append({
			"key": key, "t": "qblock",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, 0.9),
			"w": 0.95 * GridMath.TILE, "h": 0.9 * GridMath.TILE,
			"invis": is_inv,
			"revealed": (not is_inv) or bool(revealed_invis_keys.get(key, false)),
			"used": false,
			"loot": str(o.get("loot", "random")),
			"unlock_group": str(o.get("unlockGroup", "")),
			"bump_offset": 0.0,
			"move_dx_px": 0.0, "move_dy_px": 0.0,
			"layer": layer_val, "broken": false
		})
	elif t == "cloud":
		if not bool(o.get("knife", false)):
			var cy: float = GridMath.gy_to_py(oy, 0.85)
			solids.append({
				"key": key, "t": "cloud_plat",
				"x": GridMath.gx_to_px(ox), "y": cy, "base_y": cy,
				"w": 1.7 * GridMath.TILE, "h": 0.85 * GridMath.TILE,
				"rule_swap": bool(o.get("ruleSwap", false)),
				"move_dx_px": 0.0, "move_dy_px": 0.0,
				"revealed": true, "layer": layer_val, "broken": false
			})
		else:
			var kcy: float = GridMath.gy_to_py(oy, 0.9)
			entities.append({
				"key": key, "t": "cloud_knife",
				"x": GridMath.gx_to_px(ox), "y": kcy, "base_y": kcy,
				"w": 1.65 * GridMath.TILE, "h": 0.9 * GridMath.TILE,
				"rule_swap": bool(o.get("ruleSwap", false)),
				"layer": layer_val
			})
	else:
		var ent: Dictionary = o.duplicate(true)
		ent["key"] = key
		ent["layer"] = layer_val
		if t in ["flower", "amanita", "poop", "poison_item", "bomb_pickup", "antidote_pad", "crafting", "spring", "hourglass"]:
			ent["x"] = GridMath.gx_to_px(ox) + 4.0
			ent["y"] = GridMath.gy_to_py(oy, 0.88)
			ent["spawn_x"] = float(ent["x"])
			ent["spawn_y"] = float(ent["y"])
			ent["w"] = 0.82 * GridMath.TILE
			ent["h"] = 0.88 * GridMath.TILE
			ent["ambush_target_dx"] = float(o.get("ambushDx", 0.0)) * GridMath.TILE
			ent["ambush_moved"] = 0.0
			ent["ambush_active"] = false
			ent["spring_anim"] = 0.0
			ent["cooldown"] = 0.0
			ent["rule_swap"] = bool(o.get("ruleSwap", false))
			ent["stalker"] = bool(o.get("stalker", false))
			ent["falling_poop"] = false
		elif t == "spikes":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["w"] = float(o.get("w", 1.0)) * GridMath.TILE
			ent["h"] = 0.65 * GridMath.TILE
			ent["y"] = GridMath.gy_to_py(oy, 0.65)
		elif t == "sign":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.15)
			ent["spawn_x"] = float(ent["x"])
			ent["spawn_y"] = float(ent["y"])
			ent["w"] = 1.15 * GridMath.TILE
			ent["h"] = 1.15 * GridMath.TILE
			ent["vy"] = 0.0
			ent["fall_state"] = 0
		elif t == "flag":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.6)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 1.6 * GridMath.TILE
			ent["shy_left"] = int(o.get("shySteps", 0))
			ent["fake"] = bool(o.get("fake", false))
			ent["fake_type"] = str(o.get("fakeType", ""))
			ent["has_run_away"] = false
		elif t == "clock":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.1)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 1.1 * GridMath.TILE
			ent["hp"] = int(o.get("hp", 1))
		elif t == "launcher":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 0.95)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 0.95 * GridMath.TILE
			ent["cd"] = 0.35
			ent["recoil"] = 0.0
		elif t == "pipe":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.35)
			ent["w"] = 1.35 * GridMath.TILE
			ent["h"] = 1.35 * GridMath.TILE
		elif t in ["coin", "gem", "powerup"]:
			ent["x"] = GridMath.gx_to_px(ox) + 6.0
			ent["y"] = GridMath.gy_to_py(oy, 0.8)
			ent["w"] = 0.75 * GridMath.TILE
			ent["h"] = 0.75 * GridMath.TILE
		elif t == "shop":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.6)
			ent["w"] = 2.0 * GridMath.TILE
			ent["h"] = 1.6 * GridMath.TILE
		elif t == "princess":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.65)
			ent["w"] = 1.2 * GridMath.TILE
			ent["h"] = 1.65 * GridMath.TILE
			var props_p: Dictionary = lv_data.get("props", {})
			if bool(props_p.get("randomGemOrder", false)):
				ent["req"] = princess_perm_order.duplicate()
		elif t == "enemy":
			var ekind: String = str(o.get("kind", "follower"))
			ent["armor_flash"] = 0.0
			ent["jolt_x"] = 0.0
			ent["is_phasing"] = false
			if ekind == "boss":
				ent["x"] = (float(player["x"]) - 7.5 * GridMath.TILE) if not active_checkpoint.is_empty() else GridMath.gx_to_px(ox)
				ent["y"] = GridMath.gy_to_py(oy, 2.4)
				ent["w"] = 2.2 * GridMath.TILE
				ent["h"] = 2.2 * GridMath.TILE
				ent["stun_timer"] = 0.0
			elif ekind == "flying":
				ent["x"] = GridMath.gx_to_px(ox)
				ent["spawn_x"] = float(ent["x"])
				ent["y"] = GridMath.gy_to_py(oy, 1.0)
				ent["base_y"] = float(ent["y"])
				ent["w"] = 1.1 * GridMath.TILE
				ent["h"] = 0.95 * GridMath.TILE
				ent["max_hp"] = 2
				ent["hp"] = 2
				ent["atk_cd"] = 1.8
				ent["phase_clock"] = 0.0
			else:
				ent["x"] = GridMath.gx_to_px(ox)
				ent["spawn_x"] = float(ent["x"])
				ent["y"] = GridMath.gy_to_py(oy, 1.05)
				ent["w"] = 0.92 * GridMath.TILE
				ent["h"] = 1.02 * GridMath.TILE
				ent["vx"] = 0.0
				ent["vy"] = 0.0
				ent["max_hp"] = 5
				ent["hp"] = 5
				ent["dash_cd"] = 1.4
				ent["dash_state"] = ""
				ent["dash_timer"] = 0.0
				ent["dash_dir"] = 1.0
				ent["leap_cd"] = 1.6
				ent["on_ground_enemy"] = false
		elif t == "chain_bomb":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 0.95)
			ent["w"] = 0.9 * GridMath.TILE
			ent["h"] = 0.95 * GridMath.TILE
			ent["fuse"] = -1.0
		elif t == "gravity_pad":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 0.9)
			ent["w"] = 1.2 * GridMath.TILE
			ent["h"] = 0.9 * GridMath.TILE
		elif t == "checkpoint":
			ent["x"] = GridMath.gx_to_px(ox) + 4.0
			ent["y"] = GridMath.gy_to_py(oy, 1.32)
			ent["w"] = 0.85 * GridMath.TILE
			ent["h"] = 1.32 * GridMath.TILE
			ent["gx"] = ox
			ent["gy"] = oy
			ent["s3_fake"] = bool(o.get("s3Fake", false))
			ent["ambushed"] = false
			ent["active"] = (not active_checkpoint.is_empty()) and absf(float(active_checkpoint.get("x", -999.0)) - ox) < 0.2
		entities.append(ent)

func save_checkpoint_at(gx: float, gy: float) -> void:
	active_checkpoint = {
		"x": gx, "y": gy,
		"bullet_up": bool(player.get("bullet_up", false)) and not bool(player.get("from_shop_bullet", false)),
		"max_jumps": int(player.get("max_jumps", 1)),
		"has_flight": bool(player.get("has_flight", false)) and not bool(player.get("from_shop_flight", false)),
		"layer": active_layer,
		"signal_groups": signal_groups.duplicate(true),
		"polarity_groups": polarity_groups.duplicate(true),
		"s3_valves": s3_valves.duplicate(true),
		"s3_sundial_phase": s3_sundial_phase,
		"seq_progress": seq_progress.duplicate(true),
		"filled_slot_keys": filled_slot_keys.duplicate(true),
		"consumed_carry_keys": consumed_carry_keys.duplicate(true),
		"carrying_item_key": str(carrying_item.get("key", "")) if not carrying_item.is_empty() else "",
		"broken_solid_keys": broken_solid_keys.duplicate(true),
		"purified_save_keys": purified_save_keys.duplicate(true)
	}
	emit_sfx("coin")
	emit_toast("赛博存档信标已激活！", "CHECKPOINT ACTIVATED!", "checkpoint_on", "#00f5ff")

func spring_impulse_scale(sx: float, sy: float) -> void:
	if player.is_empty():
		return
	player["scale_x"] = sx
	player["scale_y"] = sy
	player["scale_vx"] = 0.0
	player["scale_vy"] = 0.0

func trigger_shake(mag: float, dur: float = 0.2) -> void:
	shake_mag = maxf(shake_mag, mag)
	shake_dur = maxf(0.05, dur)
	shake_timer = maxf(shake_timer, dur)
	if save.vibrate_on and mag >= 5.0:
		Input.vibrate_handheld(24)

func trigger_hit_stop(sec: float = 0.024) -> void:
	hit_stop_timer = maxf(hit_stop_timer, sec)

func spawn_particles(x: float, y: float, col: Color, count: int = 12, speed_mul: float = 1.0, grav_mul: float = 1.0) -> void:
	if particles.size() > 260:
		return
	for _i in range(count):
		var ang: float = randf() * TAU
		var spd: float = (45.0 + randf() * 195.0) * speed_mul
		var life: float = 0.32 + randf() * 0.34
		particles.append({
			"x": x, "y": y,
			"vx": cos(ang) * spd,
			"vy": sin(ang) * spd - 42.0 * grav_mul,
			"grav": 380.0 * grav_mul,
			"life": life, "max_life": life,
			"color": col,
			"size": 2.5 + randf() * 4.0
		})

func add_shock_ring(x: float, y: float, col: Color, max_r: float = 38.0, dur: float = 0.28) -> void:
	shock_rings.append({
		"x": x, "y": y, "color": col, "max_r": max_r, "life": dur, "max_life": dur
	})

func add_afterimage(col: Color) -> void:
	if player.is_empty() or afterimages.size() > 28:
		return
	afterimages.append({
		"x": float(player["x"]), "y": float(player["y"]),
		"w": float(player["w"]), "h": float(player["h"]),
		"facing": int(player["facing"]),
		"grav_dir": float(player["grav_dir"]),
		"color": col, "life": 0.22, "max_life": 0.22
	})

func add_float_text(x: float, y: float, txt: String, color_hex: String = "#fde047") -> void:
	float_texts.append({
		"x": x, "y": y, "txt": txt, "color": Color(color_hex), "life": 0.72, "max_life": 0.72
	})

func shatter_fake_wall(s: Dictionary, _dir: int = 1) -> void:
	if bool(s.get("shattered", false)):
		return
	s["shattered"] = true
	s["shatter_anim"] = 1.0
	emit_sfx("fake_wall_shatter")
	trigger_shake(4.8, 0.16)
	var cx: float = float(s["x"]) + float(s["w"]) * 0.5
	var cy: float = float(s["y"]) + float(s["h"]) * 0.5
	add_shock_ring(cx, cy, Color("#c084fc"), 54.0, 0.28)
	spawn_particles(cx, cy, Color("#00f5ff"), 18)
	emit_toast("全息假墙已识破粉碎！", "HOLO FAKE WALL SHATTERED!", "qblock", "#c084fc")

func find_trail_snapshot(target_t: float) -> Dictionary:
	for h_var in history_trail:
		var h: Dictionary = h_var
		if float(h["t"]) >= target_t:
			return h
	return {}

func try_trigger_golden_body() -> bool:
	if shop.trigger_golden_body(player):
		emit_sfx("shield_up")
		add_shock_ring(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#fde047"), 56.0, 0.34)
		spawn_particles(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#fde047"), 22)
		emit_toast("★ 不灭金身已开启 (10s，落入深坑依然必死)！", "GOLDEN BODY ACTIVE (10S · PITS STILL KILL)!", "ui_btn_gold", "#fde047")
		hud_dirty = true
		return true
	return false

func kill_player(ignore_shield: bool = true, cause: String = "general") -> void:
	if player.is_empty() or bool(player.get("dead", false)) or fake_phase > 0:
		return
	var is_pit_or_reset: bool = (cause == "abyss" or cause == "tactical_reset")
	if not is_pit_or_reset and (float(player.get("invuln_timer", 0.0)) > 0.0 or float(player.get("golden_timer", 0.0)) > 0.0):
		return
	if is_pit_or_reset:
		player["golden_timer"] = 0.0
		player["invuln_timer"] = 0.0

	if not is_pit_or_reset and not ignore_shield and int(player.get("gold_charges", 0)) > 0 and float(player.get("golden_timer", 0.0)) <= 0.0:
		if try_trigger_golden_body():
			return

	if not is_pit_or_reset and not ignore_shield and bool(player.get("shield", false)):
		player["shield"] = false
		player["invuln_timer"] = 1.25
		player["vy"] = -250.0 * float(player["grav_dir"])
		spring_impulse_scale(1.28, 0.75)
		emit_sfx("shield_parry")
		trigger_hit_stop(0.048)
		trigger_shake(7.5, 0.24)
		shield_flash_timer = 0.28
		var scx: float = float(player["x"]) + float(player["w"]) * 0.5
		var scy: float = float(player["y"]) + float(player["h"]) * 0.5
		add_shock_ring(scx, scy, Color("#00f5ff"), 64.0, 0.34)
		spawn_particles(scx, scy, Color("#00f5ff"), 22, 1.2)
		emit_toast("能量护盾完美弹反致命伤！", "AEGIS SHIELD PARRIED LETHAL HIT!", "icon_shield", "#00f5ff")
		unlock_ach("shield_saver")
		hud_dirty = true
		return

	player["dead"] = true
	grave_pos = Vector2(float(player["x"]) - 10.0, minf(GridMath.WORLD_ORIGIN_Y - 46.0, float(player["y"]) - 6.0))
	has_grave = true
	emit_sfx("die")
	trigger_hit_stop(0.038)
	trigger_shake(9.0, 0.28)
	var dcx: float = float(player["x"]) + float(player["w"]) * 0.5
	var dcy: float = float(player["y"]) + float(player["h"]) * 0.5
	add_shock_ring(dcx, dcy, Color("#ff2a85"), 56.0, 0.32)
	spawn_particles(dcx, dcy, Color("#ff2a85"), 24, 1.2)

	attempt_deaths += 1
	total_lv_deaths += 1
	var tot_d: int = save.record_death(lv_id, total_lv_deaths)

	var props: Dictionary = lv_data.get("props", {})
	if bool(props.get("adaptive", false)) and float(player["y"]) > GridMath.WORLD_ORIGIN_Y - 3.2 * GridMath.TILE:
		adaptive_stacks += 1

	if cause == "shop":
		unlock_ach("goblin_scam")
	elif cause == "sign":
		unlock_ach("sign_betrayal")
	elif cause == "shadow":
		unlock_ach("shadow_crash")
	unlock_ach("first_blood")
	if tot_d >= 25:
		unlock_ach("deaths_25")
	if tot_d >= 60:
		unlock_ach("deaths_60")
	if tot_d >= 100:
		unlock_ach("deaths_100")
	if attempt_deaths >= 5 or total_lv_deaths >= 5:
		unlock_ach("five_deaths")

	pending_death_cause = cause if cause != "" else "general"
	death_modal_delay = 0.42
	hud_dirty = true

func trigger_fake_flag(flag_ent: Dictionary) -> void:
	if fake_phase > 0:
		return
	unlock_ach("fake_flag")
	if str(flag_ent.get("fake_type", "")) == "teleport_start":
		unlock_ach("teleport_troll")
		emit_sfx("poison")
		trigger_shake(6.0, 0.22)
		add_afterimage(Color("#c084fc"))
		var sp: Dictionary = lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
		player["x"] = GridMath.gx_to_px(float(sp.get("x", 2.0))) + 10.0
		player["y"] = GridMath.gy_to_py(float(sp.get("y", 2.0)), 0.0) - 42.0
		player["vx"] = 0.0
		player["vy"] = 0.0
		add_shock_ring(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#c084fc"), 44.0, 0.30)
		emit_toast("回城假旗陷阱！", "WARP TRAP FLAG!", "ui_skull", "#c084fc")
		return
	fake_phase = 1
	fake_timer = 0.0
	emit_sfx("fake_win")
	spawn_particles(float(flag_ent["x"]) + 20.0, float(flag_ent["y"]) + 20.0, Color("#fde047"), 28)

func trigger_level_win() -> void:
	if not pending_win_result.is_empty() or fake_phase > 0:
		return
	var props: Dictionary = lv_data.get("props", {})
	var req_loops: int = int(props.get("loopsRequired", 0))
	if req_loops > 0 and loop_progress < req_loops:
		loop_progress += 1
		active_checkpoint = {}
		emit_sfx("fake_win")
		emit_toast("轮回升级 %d/%d！" % [loop_progress, req_loops], "LOOP %d/%d!" % [loop_progress, req_loops], "ach_iceclock", "#fde047")
		reset_attempt()
		return

	emit_sfx("real_win")
	var res: Dictionary = save.mark_stage_cleared(lv_id, attempt_deaths)
	if int(res["iq"]) <= 0:
		unlock_ach("zero_iq_clear")
	if int(res["iq"]) <= -500:
		unlock_ach("neg_500_clear")
	if time_elapsed <= 15.0:
		unlock_ach("speed_clear")
	var retro: Array[String] = save.retro_sync_achievements()
	for aid in retro:
		ach_queue.append(aid)

	res["stage_id"] = lv_id
	res["attempt_deaths"] = attempt_deaths
	res["time_elapsed"] = maxf(0.1, time_elapsed)
	pending_win_result = res
	hud_dirty = true

func _record_consumed_alchemy(ent: Dictionary) -> void:
	var t: String = str(ent.get("t", ""))
	if not (t in ["poison_item", "antidote_pad", "bomb_pickup", "flower", "amanita"]):
		return
	var k: String = str(ent.get("key", ""))
	for ex_var in consumed_alchemy_pool:
		var ex: Dictionary = ex_var
		if str(ex.get("key", "")) == k:
			return
	var clone: Dictionary = ent.duplicate(true)
	clone["x"] = float(ent.get("spawn_x", ent["x"]))
	clone["y"] = float(ent.get("spawn_y", ent["y"]))
	clone["ambush_moved"] = 0.0
	clone["ambush_active"] = false
	consumed_alchemy_pool.append(clone)

func grant_loot(loot_type: String, bx: float, by: float) -> void:
	var lt: String = loot_type
	if lt == "random":
		var r: float = randf()
		lt = "coin" if r < 0.2 else ("monster" if r < 0.6 else ("hazard" if r < 0.8 else "empty"))
	if lt == "instant_win" or lt == "win":
		trigger_level_win()
		return
	if lt == "coin":
		save.add_coins(5)
		emit_sfx("coin")
		spawn_particles(bx, by, Color("#facc15"), 12)
		emit_toast("获得金币 +5", "COINS +5", "ui_coin_hud", "#facc15")
	elif lt == "mech_ambush":
		emit_sfx("poison")
		var mk: String = "mech_hound" if (lv_id % 2) == 0 else "mech_spider"
		entities.append({
			"key": "spawn_mech_" + str(Time.get_ticks_msec()),
			"t": "s2_enemy", "kind": mk, "tier": "small",
			"x": bx - 16.0, "y": by - 56.0, "spawn_x": bx - 16.0, "ground_y": by - 56.0,
			"w": 1.25 * GridMath.TILE, "h": 1.12 * GridMath.TILE,
			"min_px": bx - 3.2 * GridMath.TILE, "max_px": bx + 3.2 * GridMath.TILE,
			"vx": 118.0, "vy": 0.0, "hp": 5, "max_hp": 5, "jolt_x": 0.0, "layer": active_layer
		})
	elif lt == "bomb_supply":
		player["bombs"] = int(player.get("bombs", 0)) + 1
		emit_sfx("coin")
		emit_toast("获得高爆破甲弹 +1！", "BOMB +1!", "bomb", "#fb923c")
	elif lt == "monster":
		emit_sfx("poison")
		entities.append({
			"key": "spawn_imp_" + str(Time.get_ticks_msec()),
			"t": "enemy", "kind": "follower",
			"x": bx, "y": by - 52.0, "w": 0.92 * GridMath.TILE, "h": 1.02 * GridMath.TILE,
			"vx": 0.0, "vy": -220.0, "hp": 5, "max_hp": 5, "layer": -1
		})
	elif lt == "hazard":
		emit_sfx("poison")
		entities.append({
			"key": "drop_poop_" + str(Time.get_ticks_msec()),
			"t": "poop", "x": bx, "y": by - 64.0,
			"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE,
			"falling_poop": true, "vy": 180.0, "layer": -1
		})
	elif lt == "empty":
		emit_sfx("block")
	elif lt == "poison":
		player["poison_timer"] = 12.0
		emit_sfx("poison")
		emit_toast("剧毒缠身 · 触骷髅花炼炸弹！", "POISONED · TOUCH FLOWER FOR BOMB!", "icon_poison", "#c084fc")
	elif lt == "antidote":
		player["poison_timer"] = 0.0
		player["antidote_window"] = 8.5
		emit_sfx("coin")
		emit_toast("解毒圣体 · 触花盾/触红菇炼弹！", "ANTIDOTE AURA ACTIVE!", "item_antidote", "#4ade80")
	elif lt == "shield":
		player["shield"] = true
		emit_sfx("shield_up")
		emit_toast("能量护盾已展开！", "ENERGY SHIELD ACTIVE!", "icon_shield", "#00f5ff")
	elif lt == "bullet_up":
		player["bullet_up"] = true
		player["from_shop_bullet"] = false
		emit_sfx("coin")
		emit_toast("烈焰剑波强化 · 可破脆壁！", "FLAME WAVE UPGRADED!", "icon_sword", "#ff2a85")
	elif lt == "spring_shoe" or lt == "double_jump":
		player["max_jumps"] = maxi(int(player["max_jumps"]), 2)
		player["jumps_left"] = int(player["max_jumps"])
		emit_sfx("coin")
		unlock_ach("multi_jumper")
		emit_toast("二段跳靴已装备！", "DOUBLE JUMP UNLOCKED!", "icon_spring", "#a855f7")
	elif lt == "flight":
		player["has_flight"] = true
		player["from_shop_flight"] = false
		emit_sfx("coin")
		unlock_ach("cyber_wings")
		emit_toast("赛博飞翼 · 连按跳跃自由滑翔！", "CYBER WINGS EQUIPPED!", "icon_wing", "#00f5ff")
	elif lt == "gem_blue":
		collect_gem("blue")
	hud_dirty = true

func collect_gem(col_name: String) -> void:
	for e_var in entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "princess" and bool(e.get("strictOrder", false)):
			var req_arr: Array = e.get("req", ["red", "green", "blue"])
			var idx_g: int = collected_gems.size()
			if idx_g < req_arr.size() and str(req_arr[idx_g]) != col_name:
				collected_gems.clear()
				emit_sfx("fake_buzz")
				kill_player(true, "wrong_gem")
				return
	if not (col_name in collected_gems):
		collected_gems.append(col_name)
		emit_sfx("coin")
		hud_dirty = true

func perform_melee_slash() -> void:
	if not is_magic_sword_enabled():
		return
	if player.is_empty() or bool(player.get("dead", false)):
		return
	if float(player.get("melee_cd", 0.0)) > 0.0:
		return

	player["melee_cd"] = 0.25
	player["melee_anim"] = 0.23
	player["attack_anim"] = 0.23
	spring_impulse_scale(1.20, 0.86)

	var dir: int = 1 if int(player["facing"]) >= 0 else -1
	var sword_up: bool = bool(player.get("sword_up", false))
	var slash_w: float = 108.0 if sword_up else 70.0
	var slash_h: float = 72.0 if sword_up else 60.0
	var slash_x: float = (float(player["x"]) + float(player["w"]) * 0.35) if dir > 0 else (float(player["x"]) + float(player["w"]) * 0.65 - slash_w)
	var slash_y: float = float(player["y"]) - (16.0 if sword_up else 10.0)
	var slash_box: Rect2 = Rect2(slash_x, slash_y, slash_w, slash_h)

	if sword_up:
		bullets.append({
			"x": (float(player["x"]) + float(player["w"])) if dir > 0 else (float(player["x"]) - 34.0),
			"y": float(player["y"]) + 4.0,
			"w": 36.0, "h": 30.0,
			"vx": float(dir) * 590.0,
			"upgraded": true, "s3_wave": true, "reflected": false, "life": 0.52
		})

	melee_arcs.append({
		"x": (float(player["x"]) + float(player["w"]) - 8.0) if dir > 0 else (float(player["x"]) - 66.0),
		"y": float(player["y"]) - 16.0,
		"w": 74.0, "h": 68.0, "dir": dir, "life": 0.19, "max_life": 0.19
	})

	var hit_any: bool = false

	for si in range(enemy_shots.size() - 1, -1, -1):
		var sh: Dictionary = enemy_shots[si]
		var sh_l: int = int(sh.get("layer", -1))
		if (sh_l < 0 or sh_l == active_layer) and GridMath.aabb_overlap(slash_box, Rect2(float(sh["x"]), float(sh["y"]), float(sh["w"]), float(sh["h"]))):
			spawn_particles(float(sh["x"]) + 6.0, float(sh["y"]) + 6.0, Color("#fde047"), 8)
			add_float_text(float(sh["x"]), float(sh["y"]) - 8.0, "PARRY!", "#fde047")
			enemy_shots.remove_at(si)
			hit_any = true

	for s_var in solids:
		var s: Dictionary = s_var
		if lv_id >= 51 and not Sector1And2Mechanics.is_in_active_layer(s, active_layer):
			continue
		var st: String = str(s.get("t", ""))
		var sr: Rect2 = Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"]))
		if not GridMath.aabb_overlap(slash_box, sr):
			continue
		if st == "fake_error" and not bool(s.get("broken", false)):
			if str(s.get("mode", "")) != "walk_top":
				s["broken"] = true
				broken_solid_keys[str(s["key"])] = true
				if str(s.get("unlock_group", "")) != "":
					signal_groups[str(s["unlock_group"])] = true
				emit_sfx("fake_wall_shatter")
			else:
				s["hit_flash"] = 0.2
			hit_any = true
		elif (st == "fake_wall" or st == "fake_plat") and not bool(s.get("shattered", false)):
			shatter_fake_wall(s, dir)
			hit_any = true
		elif st == "destructible" and bool(s.get("bullet_break", false)) and not bool(s.get("mirror_break", false)) and not bool(s.get("broken", false)):
			s["broken"] = true
			emit_sfx("boom")
			hit_any = true
		elif st == "qblock" or st == "invis":
			if not bool(s.get("revealed", false)):
				s["revealed"] = true
				revealed_invis_keys[str(s["key"])] = true
			if st == "qblock" and not bool(s.get("used", false)):
				s["used"] = true
				s["bump_offset"] = -7.0
				if str(s.get("unlock_group", "")) != "":
					signal_groups[str(s["unlock_group"])] = true
				emit_sfx("block")
				grant_loot(str(s["loot"]), float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]))
				hit_any = true
			elif st == "invis" and str(s.get("loot", "")) != "" and not bool(s.get("looted", false)):
				s["looted"] = true
				s["bump_offset"] = -7.0
				emit_sfx("block")
				grant_loot(str(s["loot"]), float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]))
				hit_any = true

	if lv_id >= 101 and Sector3Arcadia.disarm_or_damage_targets(self, slash_box, 6 if sword_up else 3, true, true):
		hit_any = true

	var needs_alchemy_preserve: bool = false
	for sp_var in solids:
		var sp_d: Dictionary = sp_var
		if str(sp_d.get("t", "")) == "destructible" and not bool(sp_d.get("broken", false)) and not bool(sp_d.get("bullet_break", false)):
			needs_alchemy_preserve = true
			break

	for j in range(entities.size() - 1, -1, -1):
		if j >= entities.size():
			continue
		var e: Dictionary = entities[j]
		var et: String = str(e.get("t", ""))
		if lv_id >= 51 and et != "layer_term" and not Sector1And2Mechanics.is_in_active_layer(e, active_layer):
			continue
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x <= 0.0 or not GridMath.aabb_overlap(slash_box, er):
			continue

		if et == "flower" or et == "amanita":
			hit_any = true
			emit_sfx("enemy_kill")
			save.add_coins(2)
			hud_dirty = true
			add_float_text(float(e["x"]), float(e["y"]) - 10.0, "SLASH +2G", "#fde047")
			if str(e.get("onKillGroup", "")) != "":
				signal_groups[str(e["onKillGroup"])] = true
			if needs_alchemy_preserve:
				_record_consumed_alchemy(e)
			entities.remove_at(j)
		elif et == "enemy":
			hit_any = true
			if str(e.get("kind", "")) == "boss":
				e["stun_timer"] = 2.8
				add_float_text(float(e["x"]), float(e["y"]) - 10.0, "STUN!", "#fde047")
			else:
				emit_sfx("enemy_kill")
				entities.remove_at(j)
		elif et == "s2_enemy":
			var off_ge: String = str(e.get("offGroup", ""))
			if off_ge != "" and bool(signal_groups.get(off_ge, false)):
				continue
			hit_any = true
			if str(e.get("kind", "")) == "forklift":
				emit_sfx("armor_clang")
			else:
				var m_dmg: int = 5 if bool(e.get("is_phasing", false)) else (5 if sword_up else 3)
				e["is_phasing"] = false
				Sector1And2Mechanics.apply_monster_damage(self, e, j, m_dmg, dir, true)
		elif et == "s2_boss" and not bool(e.get("defeated", false)):
			hit_any = true
			Sector1And2Mechanics.damage_boss(self, e, false, true, false, 5 if sword_up else 3)
		elif et == "troll_hand" and not bool(e.get("parried", false)) and str(e.get("mode", "")) == "parry_duel":
			e["parried"] = true
			if str(e.get("unlockGroup", "")) != "":
				signal_groups[str(e["unlockGroup"])] = true
			emit_sfx("boss_phase_break")
			add_float_text(float(e["x"]), float(e["y"]) - 14.0, "SLAP BACK!", "#fde047")
			hit_any = true
		elif et == "mimic_flag" and not bool(e.get("tamed", false)):
			e["revealed"] = true
			if str(e.get("mode", "")) == "sword_tame":
				e["tamed"] = true
				if str(e.get("unlockGroup", "")) != "":
					signal_groups[str(e["unlockGroup"])] = true
				emit_sfx("real_win")
			else:
				if str(e.get("unlockGroup", "")) != "":
					signal_groups[str(e["unlockGroup"])] = true
				emit_sfx("enemy_kill")
				entities.remove_at(j)
			hit_any = true
		elif et == "mimic_chest":
			e["awake"] = true
			hit_any = true
			if str(e.get("mode", "")) == "bomb_feed":
				emit_sfx("armor_clang")
			else:
				Sector1And2Mechanics.apply_monster_damage(self, e, j, 3, dir, true)
		elif et in ["signal_node", "polarity_node", "time_node", "beat_clock", "layer_term", "root_term", "betray_spring", "curse_totem", "fake_save", "trojan_heart"]:
			var fb: Dictionary = { "x": float(e["x"]) + 2.0, "y": float(e["y"]) + 2.0, "w": 12.0, "h": 12.0, "vx": float(dir) * 400.0, "upgraded": true, "reflected": false, "life": 0.2 }
			Sector1And2Mechanics.handle_bullet_hit(self, fb)
			hit_any = true

	emit_sfx("melee_hit" if hit_any else "melee_slash")

func step_frame(raw_dt: float, inp: Dictionary) -> void:
	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - raw_dt)
	if shield_flash_timer > 0.0:
		shield_flash_timer = maxf(0.0, shield_flash_timer - raw_dt)

	_step_visual_fx(raw_dt)

	if death_modal_delay >= 0.0:
		death_modal_delay -= raw_dt
		if death_modal_delay < 0.0 and not player.is_empty() and bool(player.get("dead", false)):
			pending_death_modal_cause = pending_death_cause
		return

	if fake_phase > 0:
		fake_timer += raw_dt
		if fake_phase == 1 and fake_timer >= 0.72:
			fake_phase = 2
			fake_timer = 0.0
			emit_sfx("fake_buzz")
		elif fake_phase == 2 and fake_timer >= 0.68:
			fake_phase = 0
			kill_player(true, "fake_flag")
		return

	if hit_stop_timer > 0.0:
		hit_stop_timer = maxf(0.0, hit_stop_timer - raw_dt)
		return

	var sub_steps: int = clampi(int(ceil(raw_dt / (1.0 / 120.0))), 1, 4)
	var sub_dt: float = raw_dt / float(sub_steps)
	for step_i in range(sub_steps):
		var step_inp: Dictionary = inp.duplicate()
		if step_i > 0:
			step_inp["jump_pressed"] = false
			step_inp["jump_released"] = false
			step_inp["shoot_pressed"] = false
			step_inp["slash_pressed"] = false
			step_inp["bomb_pressed"] = false
			step_inp["down_pressed"] = false
			step_inp["layer_pressed"] = false
			step_inp["gold_pressed"] = false
		_step_physics(sub_dt, step_inp)
		if player.is_empty() or bool(player.get("dead", false)) or not pending_win_result.is_empty():
			break

func _step_visual_fx(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var pt: Dictionary = particles[i]
		pt["vy"] = float(pt["vy"]) + float(pt["grav"]) * dt
		pt["x"] = float(pt["x"]) + float(pt["vx"]) * dt
		pt["y"] = float(pt["y"]) + float(pt["vy"]) * dt
		pt["life"] = float(pt["life"]) - dt
		if float(pt["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(shock_rings.size() - 1, -1, -1):
		var sr: Dictionary = shock_rings[i]
		sr["life"] = float(sr["life"]) - dt
		if float(sr["life"]) <= 0.0:
			shock_rings.remove_at(i)
	for i in range(afterimages.size() - 1, -1, -1):
		var ai: Dictionary = afterimages[i]
		ai["life"] = float(ai["life"]) - dt
		if float(ai["life"]) <= 0.0:
			afterimages.remove_at(i)
	for i in range(float_texts.size() - 1, -1, -1):
		var ft: Dictionary = float_texts[i]
		ft["y"] = float(ft["y"]) - 28.0 * dt
		ft["life"] = float(ft["life"]) - dt
		if float(ft["life"]) <= 0.0:
			float_texts.remove_at(i)
	for i in range(melee_arcs.size() - 1, -1, -1):
		var ma: Dictionary = melee_arcs[i]
		ma["life"] = float(ma["life"]) - dt
		if float(ma["life"]) <= 0.0:
			melee_arcs.remove_at(i)

func _step_physics(dt: float, inp: Dictionary) -> void:
	if player.is_empty() or bool(player.get("dead", false)):
		return
	var props: Dictionary = lv_data.get("props", {})
	var loop_mul: float = (1.0 + float(loop_progress - 1) * 0.14) if int(props.get("loopsRequired", 0)) > 0 else 1.0
	var world_dt: float = 0.0 if world_frozen else (dt * 0.38 if world_slow else dt * loop_mul)

	time_elapsed += dt

	if bool(inp.get("layer_pressed", false)):
		Sector1And2Mechanics.try_shift_dual_layer(self, false)
	if bool(inp.get("gold_pressed", false)):
		try_trigger_golden_body()

	# Spring-damper squash & stretch
	player["scale_vx"] = (float(player["scale_vx"]) + (1.0 - float(player["scale_x"])) * 230.0 * dt) * maxf(0.0, 1.0 - 17.0 * dt)
	player["scale_vy"] = (float(player["scale_vy"]) + (1.0 - float(player["scale_y"])) * 230.0 * dt) * maxf(0.0, 1.0 - 17.0 * dt)
	player["scale_x"] = clampf(float(player["scale_x"]) + float(player["scale_vx"]) * dt, 0.68, 1.36)
	player["scale_y"] = clampf(float(player["scale_y"]) + float(player["scale_vy"]) * dt, 0.68, 1.38)
	var target_tilt: float = clampf((float(player["vx"]) / 250.0) * 0.065, -0.11, 0.11) * float(player["grav_dir"])
	player["tilt_rad"] = lerpf(float(player["tilt_rad"]), target_tilt, minf(1.0, dt * 18.0))

	for s_var in solids:
		var s: Dictionary = s_var
		if absf(float(s.get("bump_offset", 0.0))) > 0.01:
			s["bump_offset"] = float(s["bump_offset"]) * maxf(0.0, 1.0 - dt * 16.0)
		if float(s.get("shatter_anim", 0.0)) > 0.0:
			s["shatter_anim"] = maxf(0.0, float(s["shatter_anim"]) - dt * 2.4)

	for e_var in entities:
		var e: Dictionary = e_var
		if float(e.get("spring_anim", 0.0)) > 0.0:
			e["spring_anim"] = maxf(0.0, float(e["spring_anim"]) - dt * 2.4)
		if float(e.get("recoil", 0.0)) > 0.0:
			e["recoil"] = maxf(0.0, float(e["recoil"]) - dt * 5.0)
		if float(e.get("cooldown", 0.0)) > 0.0:
			e["cooldown"] = maxf(0.0, float(e["cooldown"]) - dt)

	if bool(props.get("ruleShuffle", false)):
		rule_timer += dt
		if rule_timer >= 5.0:
			rule_timer = 0.0
			rule_phase_b = not rule_phase_b
			emit_sfx("block")
			emit_toast(
				"法则切换：红花无害 / 蓝云带刀！" if rule_phase_b else "法则切换：蓝云安全 / 红花致命！",
				"RULE B: FLOWER SAFE / CLOUD LETHAL!" if rule_phase_b else "RULE A: CLOUD SAFE / FLOWER LETHAL!",
				"flower_skull" if rule_phase_b else "cloud_safe",
				"#4ade80" if rule_phase_b else "#00f5ff"
			)

	if (bool(props.get("poopRain", false)) or bool(props.get("authorDuel", false))) and not world_frozen:
		poop_rain_timer += dt
		var rain_iv: float = 2.4 if bool(props.get("authorDuel", false)) else 3.2
		if poop_rain_timer >= rain_iv:
			poop_rain_timer = 0.0
			var drop_x: float = float(player["x"]) if bool(props.get("authorDuel", false)) else GridMath.gx_to_px(4.0 + randf() * 18.0)
			entities.append({
				"key": "rain_poop_" + str(Time.get_ticks_msec()),
				"t": "poop", "x": drop_x, "y": float(player["y"]) - 280.0,
				"w": 0.78 * GridMath.TILE, "h": 0.82 * GridMath.TILE,
				"falling_poop": true, "vy": 230.0, "layer": -1
			})

	if timer_left >= 0.0 and not world_frozen:
		timer_left -= dt * timer_rate * (0.4 if world_slow else 1.0)
		if timer_left <= 0.0:
			timer_left = 0.0
			kill_player(true, "timer")
			return

	if float(player["invuln_timer"]) > 0.0:
		player["invuln_timer"] = maxf(0.0, float(player["invuln_timer"]) - dt)
	if float(player["antidote_window"]) > 0.0:
		player["antidote_window"] = maxf(0.0, float(player["antidote_window"]) - dt)
	if float(player["attack_anim"]) > 0.0:
		player["attack_anim"] = maxf(0.0, float(player["attack_anim"]) - dt)
	if float(player["melee_cd"]) > 0.0:
		player["melee_cd"] = maxf(0.0, float(player["melee_cd"]) - dt)
	if float(player["melee_anim"]) > 0.0:
		player["melee_anim"] = maxf(0.0, float(player["melee_anim"]) - dt)
	if float(player["poison_timer"]) > 0.0:
		player["poison_timer"] = float(player["poison_timer"]) - dt
		if float(player["poison_timer"]) <= 0.0:
			kill_player(true, "poison")
			return

	# Anti-softlock alchemy supply auto-regen
	var needs_bomb_wall: bool = false
	for s_bw_var in solids:
		var s_bw: Dictionary = s_bw_var
		if str(s_bw.get("t", "")) == "destructible" and not bool(s_bw.get("broken", false)) and not bool(s_bw.get("bullet_break", false)):
			needs_bomb_wall = true
			break
	var chain_fusing: bool = false
	for e_cf_var in entities:
		var e_cf: Dictionary = e_cf_var
		if str(e_cf.get("t", "")) == "chain_bomb" and float(e_cf.get("fuse", -1.0)) >= 0.0:
			chain_fusing = true
			break
	if needs_bomb_wall and int(player["bombs"]) <= 0 and bombs.is_empty() and float(player["poison_timer"]) <= 0.0 and float(player["antidote_window"]) <= 0.0 and not chain_fusing:
		if consumed_alchemy_pool.size() > 0:
			alchemy_regen_timer += dt
			if alchemy_regen_timer >= 1.45:
				alchemy_regen_timer = 0.0
				while consumed_alchemy_pool.size() > 0:
					var item_r: Dictionary = consumed_alchemy_pool.pop_back()
					entities.append(item_r)
				for sq_var in solids:
					var sq: Dictionary = sq_var
					if str(sq.get("t", "")) == "qblock" and bool(sq.get("used", false)) and str(sq.get("loot", "")) in ["poison", "antidote"]:
						sq["used"] = false
				emit_sfx("coin")
				emit_toast("炼金补给已自动重聚！", "ALCHEMY SUPPLIES REFILLED!", "ach_alchemy", "#c084fc")
	else:
		alchemy_regen_timer = 0.0

	var sens: float = clampf(save.sensitivity, 0.5, 1.5)
	var resp_mul: float = 0.68 + 0.56 * sens

	if float(player.get("heavy_curse_timer", 0.0)) > 0.0:
		player["heavy_curse_timer"] = maxf(0.0, float(player["heavy_curse_timer"]) - dt)
	if float(player.get("reverse_curse_timer", 0.0)) > 0.0:
		player["reverse_curse_timer"] = maxf(0.0, float(player["reverse_curse_timer"]) - dt)
	player["in_curse_mirror"] = false
	player["in_curse_jump_shot"] = false
	if lv_id >= 51:
		var p_center: Vector2 = Vector2(float(player["x"]) + 14.0, float(player["y"]) + 21.0)
		for ct_var in entities:
			var ct: Dictionary = ct_var
			if str(ct.get("t", "")) == "curse_totem" and float(ct.get("disable_timer", 0.0)) <= 0.0 and Sector1And2Mechanics.is_in_active_layer(ct, active_layer):
				var ctc: Vector2 = Vector2(float(ct["x"]) + float(ct["w"]) * 0.5, float(ct["y"]) + float(ct["h"]) * 0.5)
				if p_center.distance_to(ctc) <= float(ct.get("radius_px", 250.0)):
					if str(ct.get("curse_type", "mirror_lr")) == "anti_jump_shoot":
						player["in_curse_jump_shot"] = true
					else:
						player["in_curse_mirror"] = true

	var move_dir: int = (1 if bool(inp.get("right", false)) else 0) - (1 if bool(inp.get("left", false)) else 0)
	if bool(props.get("mirrorInput", false)):
		move_dir = -move_dir
	if bool(player["in_curse_mirror"]) or float(player["reverse_curse_timer"]) > 0.0:
		move_dir = -move_dir

	var max_run_spd: float = (242.0 + (sens - 1.0) * 22.0) * loop_mul
	var is_turning: bool = move_dir != 0 and absf(float(player["vx"])) > 20.0 and int(signf(float(player["vx"]))) != move_dir
	var is_braking: bool = move_dir == 0

	if move_dir != 0 and absf(float(player["vx"])) < 36.0 * sens:
		player["vx"] = float(move_dir) * 36.0 * sens

	var accel: float = 0.0
	if is_turning:
		accel = (5800.0 if bool(player["on_ground"]) else 4200.0) * resp_mul
	elif is_braking:
		accel = (4700.0 if bool(player["on_ground"]) else 2850.0) * resp_mul
	else:
		accel = (3450.0 if bool(player["on_ground"]) else 2600.0) * resp_mul

	var jump_held: bool = bool(inp.get("jump_held", false))
	var near_apex: bool = (not bool(player["on_ground"])) and (not bool(player["has_flight"])) and absf(float(player["vy"])) < 85.0 and jump_held
	var target_vx: float = float(move_dir) * max_run_spd * (1.07 if near_apex else 1.0)
	if float(player["vx"]) < target_vx:
		player["vx"] = minf(target_vx, float(player["vx"]) + accel * dt)
	elif float(player["vx"]) > target_vx:
		player["vx"] = maxf(target_vx, float(player["vx"]) - accel * dt)

	if move_dir != 0:
		player["facing"] = move_dir
		player["walk_cycle"] = float(player["walk_cycle"]) + dt * (11.6 + sens * 1.4)
	else:
		player["walk_cycle"] = 0.0

	var coyote_win: float = 0.115 + 0.030 * sens
	if bool(player["on_ground"]):
		player["coyote"] = coyote_win
		player["jumps_left"] = int(player["max_jumps"])
	else:
		player["coyote"] = maxf(0.0, float(player["coyote"]) - dt)

	var shoot_triggered: bool = bool(inp.get("shoot_pressed", false))
	if bool(inp.get("jump_pressed", false)) or float(inp.get("jump_buffer", 0.0)) > 0.0:
		if bool(player["has_flight"]):
			player["vy"] = -410.0 * float(player["grav_dir"])
			spring_impulse_scale(0.82, 1.20)
			emit_sfx("jump_air")
			add_shock_ring(float(player["x"]) + 14.0, float(player["y"]) + 42.0, Color("#00f5ff"), 26.0, 0.22)
		elif float(player["coyote"]) > 0.0 or int(player["jumps_left"]) > 0:
			var is_air: bool = float(player["coyote"]) <= 0.0
			if is_air:
				player["jumps_left"] = int(player["jumps_left"]) - 1
				unlock_ach("multi_jumper")
				add_afterimage(Color("#a855f7"))
			else:
				player["jumps_left"] = maxi(0, int(player["max_jumps"]) - 1)
			player["coyote"] = 0.0
			player["on_ground"] = false
			var jvy: float = -425.0 if float(player["heavy_curse_timer"]) > 0.0 else -592.0
			player["vy"] = jvy * float(player["grav_dir"])
			if bool(player["in_curse_jump_shot"]):
				shoot_triggered = true
			spring_impulse_scale(0.77, 1.27)
			emit_sfx("jump_air" if is_air else "jump")

	if bool(inp.get("jump_released", false)):
		if not bool(player["has_flight"]) and float(player["vy"]) * float(player["grav_dir"]) < -165.0:
			var cut_f: float = clampf(0.54 - (sens - 0.5) * 0.10, 0.42, 0.56)
			player["vy"] = float(player["vy"]) * cut_f

	if bool(inp.get("slash_pressed", false)):
		Sector1And2Mechanics.notify_peace_doves(self, float(player["x"]) + 14.0, float(player["y"]) + 21.0)
		perform_melee_slash()

	if shoot_triggered:
		Sector1And2Mechanics.notify_peace_doves(self, float(player["x"]) + 14.0, float(player["y"]) + 21.0)
		player["attack_anim"] = 0.22
		spring_impulse_scale(1.15, 0.90)
		emit_sfx("shoot")
		var bup: bool = bool(player["bullet_up"])
		var bspd: float = 545.0 if bup else 455.0
		bullets.append({
			"x": (float(player["x"]) + float(player["w"]) + 2.0) if int(player["facing"]) > 0 else (float(player["x"]) - 24.0),
			"y": float(player["y"]) + 10.0,
			"w": 28.0 if bup else 24.0,
			"h": 18.0 if bup else 20.0,
			"vx": float(player["facing"]) * bspd,
			"upgraded": bup, "s3_wave": false, "reflected": false, "life": 2.2
		})

	if bool(inp.get("bomb_pressed", false)):
		if not carrying_item.is_empty() and str(carrying_item.get("t", "")) == "signal_battery":
			emit_sfx("block")
			emit_toast("携带信号电池期间无法投弹！", "CANNOT USE BOMBS WHILE CARRYING BATTERY!", "s2_battery", "#fde047")
		elif int(player["bombs"]) > 0:
			player["bombs"] = int(player["bombs"]) - 1
			spring_impulse_scale(1.12, 0.92)
			emit_sfx("shoot")
			bombs.append({
				"x": float(player["x"]) + 14.0, "y": float(player["y"]) + 8.0,
				"vx": float(player["facing"]) * 275.0, "vy": -280.0 * float(player["grav_dir"]), "fuse": 0.92
			})
			hud_dirty = true

	var grav_scale: float = 1.0
	if not bool(player["on_ground"]) and not bool(player["has_flight"]):
		if jump_held and absf(float(player["vy"])) < 82.0:
			grav_scale = 0.74
		elif float(player["vy"]) * float(player["grav_dir"]) > 45.0:
			grav_scale = 1.07
	player["vy"] = clampf(float(player["vy"]) + 1320.0 * grav_scale * float(player["grav_dir"]) * dt, -765.0, 765.0)

	if light_burst_timer > 0.0:
		light_burst_timer = maxf(0.0, light_burst_timer - dt)

	# Moving solids & breathing cloud platforms
	move_time += world_dt
	for s_m_var in solids:
		var s_m: Dictionary = s_m_var
		if bool(s_m.get("broken", false)):
			continue
		if str(s_m.get("t", "")) == "cloud_plat":
			var prev_cy: float = float(s_m["y"])
			s_m["y"] = float(s_m["base_y"]) + sin(time_elapsed * 2.4 + float(s_m["x"]) * 0.03) * 3.5
			if float(player["grav_dir"]) > 0.0 and bool(player["on_ground"]) and float(player["x"]) + float(player["w"]) > float(s_m["x"]) + 2.0 and float(player["x"]) < float(s_m["x"]) + float(s_m["w"]) - 2.0 and absf((float(player["y"]) + float(player["h"])) - prev_cy) <= 9.0:
				player["y"] = float(player["y"]) + (float(s_m["y"]) - prev_cy)
			continue
		var mdx: float = float(s_m.get("move_dx_px", 0.0))
		var mdy: float = float(s_m.get("move_dy_px", 0.0))
		if absf(mdx) > 0.01 or absf(mdy) > 0.01:
			var prev_sx: float = float(s_m["x"])
			var prev_sy: float = float(s_m["y"])
			var mspd: float = float(s_m.get("move_speed", 1.7))
			if mspd <= 0.0:
				mspd = 1.7
			var ph: float = 0.5 - 0.5 * cos(move_time * mspd)
			s_m["x"] = float(s_m["base_x"]) + ph * mdx
			s_m["y"] = float(s_m["base_y"]) - ph * mdy
			if float(player["grav_dir"]) > 0.0 and bool(player["on_ground"]) and float(player["x"]) + float(player["w"]) > prev_sx + 2.0 and float(player["x"]) < prev_sx + float(s_m["w"]) - 2.0 and absf((float(player["y"]) + float(player["h"])) - prev_sy) <= 9.0:
				player["x"] = float(player["x"]) + (float(s_m["x"]) - prev_sx)
				player["y"] = float(player["y"]) + (float(s_m["y"]) - prev_sy)
				unlock_ach("shuttle_rider")

	Sector1And2Mechanics.step_pre_move(self, dt, world_dt)
	Sector3Arcadia.step_pre_move(self, dt, world_dt)
	if bool(player.get("dead", false)):
		return

	var active_solids: Array = _collect_active_solids()

	var bounds_d: Dictionary = lv_data.get("bounds", { "minX": -2.0, "maxX": 60.0 })
	var min_bx: float = GridMath.gx_to_px(float(bounds_d.get("minX", -2.0)))
	var max_bx: float = GridMath.gx_to_px(float(bounds_d.get("maxX", 60.0)))

	player["x"] = clampf(float(player["x"]) + float(player["vx"]) * dt, min_bx, max_bx - float(player["w"]))
	var p_rect_x: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))

	for s_x_var in active_solids:
		var s_x: Dictionary = s_x_var
		var st_x: String = str(s_x.get("t", ""))
		if (st_x == "invis" or st_x == "qblock") and not bool(s_x.get("revealed", false)):
			continue
		var sr_x: Rect2 = Rect2(float(s_x["x"]), float(s_x["y"]), float(s_x["w"]), float(s_x["h"]))
		if GridMath.aabb_overlap(p_rect_x, sr_x):
			if bool(player.get("has_wall_phase", false)) and (float(player["y"]) + float(player["h"]) > float(s_x["y"]) + 10.0) and float(s_x["w"]) <= GridMath.TILE * 3.4:
				continue
			if float(player["vx"]) > 0.0:
				player["x"] = float(s_x["x"]) - float(player["w"])
			elif float(player["vx"]) < 0.0:
				player["x"] = float(s_x["x"]) + float(s_x["w"])
			player["vx"] = 0.0
			p_rect_x.position.x = float(player["x"])

	player["was_on_ground"] = bool(player["on_ground"])
	var prev_y: float = float(player["y"])
	var pre_land_vy: float = float(player["vy"])
	player["y"] = prev_y + float(player["vy"]) * dt
	player["on_ground"] = false
	var p_rect_y: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))

	for s_y_var in active_solids:
		var s_y: Dictionary = s_y_var
		var sr_y: Rect2 = Rect2(float(s_y["x"]), float(s_y["y"]), float(s_y["w"]), float(s_y["h"]))
		if not GridMath.aabb_overlap(p_rect_y, sr_y):
			continue
		var st_y: String = str(s_y.get("t", ""))

		if (st_y == "invis" or st_y == "qblock") and not bool(s_y.get("revealed", false)):
			var hit_below: bool = float(player["grav_dir"]) > 0.0 and float(player["vy"]) < 0.0 and prev_y >= float(s_y["y"]) + float(s_y["h"]) - 12.0
			var step_top: bool = float(player["grav_dir"]) > 0.0 and bool(s_y.get("step_reveal", false)) and float(player["vy"]) >= 0.0 and prev_y + float(player["h"]) <= float(s_y["y"]) + 15.0
			if hit_below:
				s_y["revealed"] = true
				s_y["bump_offset"] = -7.0
				revealed_invis_keys[str(s_y["key"])] = true
				player["y"] = float(s_y["y"]) + float(s_y["h"])
				player["vy"] = 40.0
				p_rect_y.position.y = float(player["y"])
				emit_sfx("block")
				if st_y == "qblock" and not bool(s_y.get("used", false)):
					s_y["used"] = true
					if str(s_y.get("unlock_group", "")) != "":
						signal_groups[str(s_y["unlock_group"])] = true
					grant_loot(str(s_y["loot"]), float(s_y["x"]) + float(s_y["w"]) * 0.5, float(s_y["y"]))
				elif st_y == "invis" and str(s_y.get("loot", "")) != "" and not bool(s_y.get("looted", false)):
					s_y["looted"] = true
					grant_loot(str(s_y["loot"]), float(s_y["x"]) + float(s_y["w"]) * 0.5, float(s_y["y"]))
			elif step_top:
				s_y["revealed"] = true
				s_y["bump_offset"] = 4.0
				revealed_invis_keys[str(s_y["key"])] = true
				player["y"] = float(s_y["y"]) - float(player["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
				p_rect_y.position.y = float(player["y"])
				emit_sfx("block")
			continue

		if float(player["grav_dir"]) > 0.0:
			if float(player["vy"]) >= 0.0 and prev_y + float(player["h"]) <= float(s_y["y"]) + 16.0:
				player["y"] = float(s_y["y"]) - float(player["h"])
				if not bool(player["was_on_ground"]) and pre_land_vy > 210.0:
					spring_impulse_scale(1.22, 0.80)
				player["vy"] = 0.0
				player["on_ground"] = true
				p_rect_y.position.y = float(player["y"])
				if st_y == "vanish" and float(s_y.get("vanish_timer", -1.0)) < 0.0:
					s_y["vanish_timer"] = 0.48
			elif float(player["vy"]) < 0.0 and prev_y >= float(s_y["y"]) + float(s_y["h"]) - 16.0:
				var corner_ok: bool = false
				if st_y == "solid":
					var over_r: float = (float(s_y["x"]) + float(s_y["w"])) - float(player["x"])
					var over_l: float = (float(player["x"]) + float(player["w"])) - float(s_y["x"])
					if over_r > 0.0 and over_r <= 7.5:
						player["x"] = float(s_y["x"]) + float(s_y["w"]) + 0.5
						p_rect_y.position.x = float(player["x"])
						corner_ok = true
					elif over_l > 0.0 and over_l <= 7.5:
						player["x"] = float(s_y["x"]) - float(player["w"]) - 0.5
						p_rect_y.position.x = float(player["x"])
						corner_ok = true
				if not corner_ok:
					player["y"] = float(s_y["y"]) + float(s_y["h"])
					player["vy"] = 30.0
					p_rect_y.position.y = float(player["y"])
					if st_y == "qblock" and not bool(s_y.get("used", false)):
						s_y["used"] = true
						s_y["bump_offset"] = -7.0
						if str(s_y.get("unlock_group", "")) != "":
							signal_groups[str(s_y["unlock_group"])] = true
						emit_sfx("block")
						grant_loot(str(s_y["loot"]), float(s_y["x"]) + float(s_y["w"]) * 0.5, float(s_y["y"]))
					elif st_y == "invis" and str(s_y.get("loot", "")) != "" and not bool(s_y.get("looted", false)):
						s_y["looted"] = true
						s_y["bump_offset"] = -7.0
						emit_sfx("block")
						grant_loot(str(s_y["loot"]), float(s_y["x"]) + float(s_y["w"]) * 0.5, float(s_y["y"]))
		else:
			if float(player["vy"]) <= 0.0 and prev_y >= float(s_y["y"]) + float(s_y["h"]) - 16.0:
				player["y"] = float(s_y["y"]) + float(s_y["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
				p_rect_y.position.y = float(player["y"])
			elif float(player["vy"]) > 0.0 and prev_y + float(player["h"]) <= float(s_y["y"]) + 16.0:
				player["y"] = float(s_y["y"]) - float(player["h"])
				player["vy"] = -30.0
				p_rect_y.position.y = float(player["y"])

	var p_rect: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))

	for s_v_var in solids:
		var s_v: Dictionary = s_v_var
		var st_v: String = str(s_v.get("t", ""))
		var sr_v: Rect2 = Rect2(float(s_v["x"]), float(s_v["y"]), float(s_v["w"]), float(s_v["h"]))
		if st_v == "vanish":
			if not bool(s_v["broken"]) and float(s_v.get("vanish_timer", -1.0)) >= 0.0:
				s_v["vanish_timer"] = float(s_v["vanish_timer"]) - dt
				if float(s_v["vanish_timer"]) <= 0.0:
					s_v["broken"] = true
					s_v["respawn_timer"] = 2.2
					emit_sfx("block")
			elif bool(s_v["broken"]) and float(s_v.get("respawn_timer", 0.0)) > 0.0:
				s_v["respawn_timer"] = float(s_v["respawn_timer"]) - dt
				if float(s_v["respawn_timer"]) <= 0.0 and not GridMath.aabb_overlap(p_rect, sr_v):
					s_v["broken"] = false
					s_v["vanish_timer"] = -1.0
		if (st_v == "fake_wall" or st_v == "fake_plat") and not bool(s_v.get("shattered", false)) and GridMath.aabb_overlap(p_rect, sr_v):
			shatter_fake_wall(s_v, int(player["facing"]))
		if st_v == "cloud_plat" and bool(s_v.get("rule_swap", false)) and rule_phase_b and GridMath.aabb_overlap(p_rect, sr_v):
			kill_player(true, "cloud_knife")
			return

	# Pit / Abyss Check (Golden Body STILL dies immediately!)
	if float(player["y"]) > GridMath.WORLD_ORIGIN_Y + 95.0:
		kill_player(true, "abyss")
		return
	if float(player["grav_dir"]) < 0.0 and float(player["y"]) < GridMath.WORLD_ORIGIN_Y - 13.0 * GridMath.TILE:
		kill_player(true, "abyss")
		return

	if time_elapsed - last_trail_record_t >= (1.0 / 90.0):
		last_trail_record_t = time_elapsed
		history_trail.append({
			"x": float(player["x"]), "y": float(player["y"]),
			"facing": int(player["facing"]), "on_ground": bool(player["on_ground"]),
			"layer": active_layer, "t": time_elapsed
		})
		while history_trail.size() > 2 and float(history_trail[0]["t"]) < time_elapsed - 9.5:
			history_trail.pop_front()

	if (bool(props.get("shadowClone", false)) or bool(props.get("shadowChaser", false))) and time_elapsed >= 1.8:
		var snap_sc: Dictionary = find_trail_snapshot(time_elapsed - 1.8)
		if not snap_sc.is_empty():
			shadow_clone = { "x": float(snap_sc["x"]), "y": float(snap_sc["y"]), "w": float(player["w"]), "h": float(player["h"]), "facing": int(snap_sc["facing"]) }
			if GridMath.aabb_overlap(p_rect, Rect2(float(shadow_clone["x"]) + 4.0, float(shadow_clone["y"]) + 4.0, float(shadow_clone["w"]) - 8.0, float(shadow_clone["h"]) - 8.0)):
				kill_player(true, "shadow")
				return

	if props.has("finalEmptyRoomX") and float(player["x"]) >= GridMath.gx_to_px(float(props["finalEmptyRoomX"])):
		if absf(float(player["vx"])) < 5.0 and bool(player["on_ground"]):
			empty_room_still_time += dt
			if empty_room_still_time >= 1.35:
				trigger_level_win()
				return
		else:
			empty_room_still_time = 0.0

	_step_bullets(dt, active_solids, p_rect)
	if bool(player.get("dead", false)):
		return

	_step_bombs(dt, active_solids)
	if bool(player.get("dead", false)):
		return

	_step_core_entities(dt, world_dt, prev_y, active_solids, inp)
	if bool(player.get("dead", false)) or not pending_win_result.is_empty():
		return

	Sector1And2Mechanics.step_post_move(self, dt, world_dt)
	Sector3Arcadia.step_post_move(self, dt, world_dt)
	if bool(player.get("dead", false)) or not pending_win_result.is_empty():
		return

	_step_enemy_shots(dt, world_dt, active_solids)
	if bool(player.get("dead", false)):
		return

	update_camera(dt)

func _collect_active_solids() -> Array:
	var out: Array = []
	for s_var in solids:
		var s: Dictionary = s_var
		if lv_id >= 101 and not Sector3Arcadia.is_solid_collidable(s, s3_sundial_phase):
			continue
		if lv_id >= 51 and not Sector1And2Mechanics.is_solid_collidable(s, active_layer, signal_groups):
			continue
		if bool(s.get("broken", false)):
			continue
		var st: String = str(s.get("t", ""))
		if st == "fake_wall" or st == "fake_plat":
			continue
		if st == "paradox_gate" and (bool(s.get("gate_open", false)) or paradox_unlocked):
			continue
		if st == "timed_gate" and time_elapsed >= float(s.get("open_time", 5.0)):
			continue
		if st == "cloud_plat" and bool(s.get("rule_swap", false)) and rule_phase_b:
			continue
		out.append(s)

	for e_var in entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "sign" and int(e.get("fall_state", 0)) == 2:
			out.append({
				"key": str(e["key"]), "t": "sign_landed",
				"x": float(e["x"]), "y": float(e["y"]) + 8.0,
				"w": float(e["w"]), "h": float(e["h"]) - 8.0,
				"revealed": true
			})
	return out

func _step_bullets(dt: float, active_solids: Array, p_rect: Rect2) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["x"] = float(b["x"]) + float(b["vx"]) * dt
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			bullets.remove_at(i)
			continue
		var b_rect: Rect2 = Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]))
		if bool(b.get("reflected", false)) and GridMath.aabb_overlap(b_rect, p_rect):
			bullets.remove_at(i)
			kill_player(false, "mirror_shot")
			return
		for fw_var in solids:
			var fw: Dictionary = fw_var
			if (str(fw.get("t", "")) == "fake_wall" or str(fw.get("t", "")) == "fake_plat") and not bool(fw.get("shattered", false)):
				if GridMath.aabb_overlap(b_rect, Rect2(float(fw["x"]), float(fw["y"]), float(fw["w"]), float(fw["h"]))):
					shatter_fake_wall(fw, int(signf(float(b["vx"]))))

		var hit_flora: bool = false
		for fl_var in entities:
			var fl: Dictionary = fl_var
			if (str(fl.get("t", "")) == "flower" or str(fl.get("t", "")) == "amanita") and (lv_id < 51 or Sector1And2Mechanics.is_in_active_layer(fl, active_layer)):
				if GridMath.aabb_overlap(b_rect, Rect2(float(fl["x"]), float(fl["y"]), float(fl["w"]), float(fl["h"]))):
					emit_sfx("armor_clang")
					add_float_text(float(fl["x"]), float(fl["y"]) - 8.0, "IMMUNE", "#fb7185")
					hit_flora = true
					break
		if hit_flora:
			bullets.remove_at(i)
			continue

		var is_wave: bool = bool(b.get("s3_wave", false))
		var b_dmg: int = 4 if is_wave else (2 if bool(b.get("upgraded", false)) else 1)
		if lv_id >= 101 and Sector3Arcadia.disarm_or_damage_targets(self, b_rect, b_dmg, is_wave, bool(b.get("upgraded", false)) or is_wave):
			if not is_wave:
				bullets.remove_at(i)
				continue

		if lv_id >= 51 and Sector1And2Mechanics.handle_bullet_hit(self, b):
			bullets.remove_at(i)
			continue
		if float(b.get("hold_timer", 0.0)) > 0.0:
			continue

		var removed: bool = false
		for s_var in active_solids:
			var s: Dictionary = s_var
			var st: String = str(s.get("t", ""))
			if (st == "invis" or st == "qblock") and not bool(s.get("revealed", false)):
				continue
			if GridMath.aabb_overlap(b_rect, Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"]))):
				if st == "mirror":
					b["vx"] = -float(b["vx"]) * 1.18
					b["reflected"] = true
					b["x"] = float(b["x"]) + (10.0 if float(b["vx"]) > 0.0 else -10.0)
					emit_sfx("spring")
					unlock_ach("mirror_bounce")
				elif st == "destructible" and bool(s.get("bullet_break", false)):
					if bool(s.get("mirror_break", false)):
						if bool(b.get("reflected", false)):
							s["broken"] = true
							emit_sfx("boom")
							unlock_ach("mirror_bankshot")
						else:
							emit_sfx("block")
						removed = true
					elif bool(b.get("upgraded", false)) or bool(b.get("reflected", false)):
						s["broken"] = true
						emit_sfx("boom")
						removed = true
					else:
						emit_sfx("block")
						removed = true
				else:
					removed = true
				break
		if removed:
			bullets.remove_at(i)
			continue

		for j in range(entities.size() - 1, -1, -1):
			var e: Dictionary = entities[j]
			var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
			if er.size.x <= 0.0 or not GridMath.aabb_overlap(b_rect, er):
				continue
			var et: String = str(e.get("t", ""))
			if et == "clock":
				e["hp"] = int(e.get("hp", 1)) - 1
				removed = true
				if int(e["hp"]) <= 0:
					emit_sfx("boom")
					var eff: String = str(e.get("effect", ""))
					if e.has("s3AddSec") and timer_left >= 0.0:
						timer_left += float(e["s3AddSec"])
					elif eff == "stop_timer":
						timer_left = -1.0
						unlock_ach("clock_stopper")
					elif eff == "freeze_world":
						world_frozen = true
						timer_left = -1.0
						unlock_ach("clock_stopper")
					elif eff == "slow_world":
						world_slow = true
						unlock_ach("clock_stopper")
					elif eff == "speedup":
						timer_rate = 4.5
						emit_sfx("fake_buzz")
					elif eff == "stun_boss":
						for m_var in entities:
							var m: Dictionary = m_var
							if str(m.get("t", "")) == "enemy" and str(m.get("kind", "")) == "boss":
								m["stun_timer"] = 2.8
						unlock_ach("clock_stopper")
					elif eff == "light_burst":
						light_burst_timer = 4.8
						unlock_ach("light_keeper")
					entities.remove_at(j)
				break
			elif et == "enemy":
				if bool(e.get("is_phasing", false)):
					continue
				removed = true
				var ek: String = str(e.get("kind", "follower"))
				if ek == "flying":
					e["hp"] = int(e.get("hp", 2)) - (2 if bool(b.get("upgraded", false)) else 1)
					if int(e["hp"]) <= 0:
						emit_sfx("enemy_kill")
						entities.remove_at(j)
					else:
						emit_sfx("block")
				elif ek != "boss" and lv_id < 50:
					e["hp"] = int(e.get("hp", 5)) - (2 if bool(b.get("upgraded", false)) else 1)
					if int(e["hp"]) <= 0:
						emit_sfx("enemy_kill")
						entities.remove_at(j)
					else:
						emit_sfx("block")
				else:
					emit_sfx("armor_clang")
				break
		if removed:
			bullets.remove_at(i)

func explode_at(cx: float, cy: float, radius: float, trap_self: bool) -> void:
	if lv_id >= 101:
		Sector3Arcadia.disarm_or_damage_targets(self, Rect2(cx - radius, cy - radius, radius * 2.0, radius * 2.0), 6, true, true)
	emit_sfx("boom")
	trigger_shake(8.5, 0.26)
	add_shock_ring(cx, cy, Color("#fb923c"), radius * 0.85, 0.32)
	spawn_particles(cx, cy, Color("#fb923c"), 26, 1.2)
	if trap_self:
		kill_player(true, "trap_bomb")
		return
	for s_var in solids:
		var s: Dictionary = s_var
		if str(s.get("t", "")) == "destructible" and not bool(s.get("broken", false)):
			var sc: Vector2 = Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])).get_center()
			if sc.distance_to(Vector2(cx, cy)) <= radius + maxf(float(s["w"]), float(s["h"])) * 0.55:
				s["broken"] = true
				broken_solid_keys[str(s["key"])] = true
				spawn_particles(sc.x, sc.y, Color("#ff2a85"), 20)
	for mi in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[mi]
		var et: String = str(e.get("t", ""))
		var ec: Vector2 = Vector2(float(e.get("x", 0.0)) + float(e.get("w", 32.0)) * 0.5, float(e.get("y", 0.0)) + float(e.get("h", 32.0)) * 0.5)
		if et == "s2_boss" and not bool(e.get("defeated", false)) and ec.distance_to(Vector2(cx, cy)) <= radius + 68.0:
			Sector1And2Mechanics.damage_boss(self, e, false, false, true, 5)
		elif et == "mimic_chest" and ec.distance_to(Vector2(cx, cy)) <= radius + 64.0:
			if str(e.get("unlockGroup", "")) != "":
				signal_groups[str(e["unlockGroup"])] = true
			if str(e.get("loot", "")) != "":
				grant_loot(str(e["loot"]), float(e["x"]) + 24.0, float(e["y"]))
			emit_sfx("enemy_kill")
			entities.remove_at(mi)
	for cb_var in entities:
		var cb: Dictionary = cb_var
		if str(cb.get("t", "")) == "chain_bomb" and float(cb.get("fuse", -1.0)) < 0.0:
			if Vector2(float(cb["x"]) + 20.0 - cx, float(cb["y"]) + 20.0 - cy).length() <= radius + 95.0:
				cb["fuse"] = 0.24
				unlock_ach("domino_bomber")

func _step_bombs(dt: float, active_solids: Array) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var bm: Dictionary = bombs[i]
		bm["vy"] = float(bm["vy"]) + 980.0 * dt
		bm["x"] = float(bm["x"]) + float(bm["vx"]) * dt
		bm["y"] = float(bm["y"]) + float(bm["vy"]) * dt
		bm["fuse"] = float(bm["fuse"]) - dt
		var bmr: Rect2 = Rect2(float(bm["x"]) - 10.0, float(bm["y"]) - 10.0, 20.0, 20.0)
		for s_var in active_solids:
			var s: Dictionary = s_var
			var st: String = str(s.get("t", ""))
			if (st == "invis" or st == "qblock") and not bool(s.get("revealed", false)):
				continue
			if GridMath.aabb_overlap(bmr, Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"]))):
				bm["vx"] = float(bm["vx"]) * 0.4
				bm["vy"] = -absf(float(bm["vy"])) * 0.3
				bm["fuse"] = minf(float(bm["fuse"]), 0.12)
		if float(bm["fuse"]) <= 0.0:
			var bx: float = float(bm["x"])
			var by: float = float(bm["y"])
			bombs.remove_at(i)
			explode_at(bx, by, 118.0, false)

func _step_core_entities(dt: float, world_dt: float, prev_y: float, active_solids: Array, inp: Dictionary) -> void:
	var p_rect: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))
	var props: Dictionary = lv_data.get("props", {})
	var bounds_d: Dictionary = lv_data.get("bounds", { "minX": -2.0, "maxX": 60.0 })

	for i in range(entities.size() - 1, -1, -1):
		if i >= entities.size():
			continue
		var e: Dictionary = entities[i]
		var et: String = str(e.get("t", ""))

		if et == "chain_bomb" and float(e.get("fuse", -1.0)) >= 0.0:
			e["fuse"] = float(e["fuse"]) - dt
			if float(e["fuse"]) <= 0.0:
				var tx: float = float(e["x"]) + 20.0
				var ty: float = float(e["y"]) + 20.0
				var ts: bool = bool(e.get("trapSelf", false))
				entities.remove_at(i)
				explode_at(tx, ty, 132.0, ts)
				if bool(player.get("dead", false)):
					return
				continue

		if et == "launcher":
			if not world_frozen:
				e["cd"] = float(e.get("cd", 0.35)) - world_dt
				if float(e["cd"]) <= 0.0:
					e["cd"] = float(e.get("interval", 2.5))
					e["recoil"] = 1.0
					var ldir: float = float(e.get("dir", 1.0))
					var mx: float = float(e["x"]) + (38.0 if ldir > 0.0 else -58.0)
					entities.append({
						"key": "msl_" + str(Time.get_ticks_msec()) + "_" + str(i),
						"t": "missile",
						"x": mx, "spawn_x": mx, "y": float(e["y"]) + 8.0,
						"w": 68.0, "h": 26.0, "dir": ldir,
						"speed": float(e.get("speed", 3.6)) * GridMath.TILE,
						"layer": -1
					})
			continue

		if et == "missile":
			var mdx: float = float(e["dir"]) * float(e["speed"]) * world_dt
			e["x"] = float(e["x"]) + mdx
			if float(e["x"]) < GridMath.gx_to_px(float(bounds_d.get("minX", -2.0))) - 180.0 or float(e["x"]) > GridMath.gx_to_px(float(bounds_d.get("maxX", 60.0))) + 180.0:
				entities.remove_at(i)
				continue
			if absf(float(e["x"]) - float(e.get("spawn_x", e["x"]))) > 76.0:
				var nose_wall: Rect2 = Rect2((float(e["x"]) + float(e["w"]) - 8.0) if float(e["dir"]) > 0.0 else float(e["x"]), float(e["y"]) + 5.0, 8.0, float(e["h"]) - 10.0)
				var hit_cliff: bool = false
				for sw_var in active_solids:
					var sw: Dictionary = sw_var
					if str(sw.get("t", "")) == "solid" and float(sw["h"]) >= GridMath.TILE * 1.1 and GridMath.aabb_overlap(nose_wall, Rect2(float(sw["x"]), float(sw["y"]), float(sw["w"]), float(sw["h"]))):
						hit_cliff = true
						break
				if hit_cliff:
					entities.remove_at(i)
					continue
			var rider_box: Rect2 = Rect2(float(e["x"]) + 4.0, float(e["y"]) - 8.0, float(e["w"]) - 10.0, 16.0)
			var nose_box: Rect2 = Rect2((float(e["x"]) + float(e["w"]) - 13.0) if float(e["dir"]) > 0.0 else float(e["x"]), float(e["y"]) + 5.0, 13.0, float(e["h"]) - 10.0)
			var foot_box: Rect2 = Rect2(float(player["x"]), float(player["y"]) + float(player["h"]) - 7.0, float(player["w"]), 12.0)
			if float(player["grav_dir"]) > 0.0 and float(player["vy"]) >= -25.0 and prev_y + float(player["h"]) <= float(e["y"]) + 15.0 and GridMath.aabb_overlap(foot_box, rider_box):
				player["y"] = float(e["y"]) - float(player["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
				player["x"] = float(player["x"]) + mdx
				p_rect.position = Vector2(float(player["x"]), float(player["y"]))
				unlock_ach("missile_rider")
			elif not world_frozen and GridMath.aabb_overlap(p_rect, nose_box):
				kill_player(false, "missile")
				return
			continue

		if et == "cloud_knife" and e.has("base_y") and not world_frozen:
			e["y"] = float(e["base_y"]) + sin(time_elapsed * 2.8 + float(e["x"]) * 0.03) * 4.0

		if bool(e.get("falling_poop", false)):
			e["vy"] = float(e.get("vy", 0.0)) + 520.0 * world_dt
			e["y"] = float(e["y"]) + float(e["vy"]) * world_dt
			for sp_s_var in active_solids:
				var sp_s: Dictionary = sp_s_var
				if str(sp_s.get("t", "")) != "invis" and GridMath.aabb_overlap(Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"])), Rect2(float(sp_s["x"]), float(sp_s["y"]), float(sp_s["w"]), float(sp_s["h"]))):
					e["y"] = float(sp_s["y"]) - float(e["h"])
					e["falling_poop"] = false
					break

		if et == "flower" and not world_frozen:
			if bool(e.get("stalker", false)):
				e["x"] = float(e["x"]) + (1.0 if float(player["x"]) > float(e["x"]) else -1.0) * 34.0 * world_dt
			var atd: float = float(e.get("ambush_target_dx", 0.0))
			if absf(atd) > 0.5:
				if not bool(e.get("ambush_active", false)) and absf((float(player["x"]) + 14.0) - (float(e["x"]) + 18.0)) < 3.1 * GridMath.TILE and absf((float(player["y"]) + 42.0) - (float(e["y"]) + float(e["h"]))) < 2.2 * GridMath.TILE:
					e["ambush_active"] = true
					emit_sfx("shoot")
				if bool(e.get("ambush_active", false)) and absf(float(e["ambush_moved"])) < absf(atd):
					var rem_a: float = atd - float(e["ambush_moved"])
					var step_a: float = signf(rem_a) * minf(absf(rem_a), 340.0 * world_dt)
					e["x"] = float(e["x"]) + step_a
					e["ambush_moved"] = float(e["ambush_moved"]) + step_a

		if et == "flag" and not bool(e.get("fake", false)) and int(e.get("shy_left", 0)) > 0:
			if p_rect.get_center().distance_to(Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)) < 76.0:
				e["shy_left"] = int(e["shy_left"]) - 1
				var hdir: float = -1.0 if bool(props.get("mirrorInput", false)) else 1.0
				e["x"] = float(e["x"]) + hdir * 3.2 * GridMath.TILE
				emit_sfx("spring")
				unlock_ach("shy_flag_chase")

		if et == "sign":
			var smode: String = str(e.get("mode", ""))
			var fs: int = int(e.get("fall_state", 0))
			if smode == "fall" and fs == 0:
				if absf((float(player["x"]) + 14.0) - (float(e["x"]) + float(e["w"]) * 0.5)) < 46.0 and float(player["y"]) > float(e["y"]):
					e["fall_state"] = 1
					e["vy"] = 60.0
					emit_sfx("shoot")
			elif fs == 1:
				e["vy"] = float(e["vy"]) + 1150.0 * world_dt
				e["y"] = float(e["y"]) + float(e["vy"]) * world_dt
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))):
					kill_player(false, "sign")
					return
				for ss_var in active_solids:
					var ss: Dictionary = ss_var
					if str(ss.get("key", "")) != str(e["key"]) and str(ss.get("t", "")) != "invis":
						if GridMath.aabb_overlap(Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"])), Rect2(float(ss["x"]), float(ss["y"]), float(ss["w"]), float(ss["h"]))):
							e["y"] = float(ss["y"]) - float(e["h"])
							e["fall_state"] = 2
							emit_sfx("block")
							break
				if float(e["y"]) > GridMath.WORLD_ORIGIN_Y + 80.0:
					e["x"] = float(e["spawn_x"])
					e["y"] = float(e["spawn_y"])
					e["vy"] = 0.0
					e["fall_state"] = 0
			elif smode == "knife" and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + 8.0, float(e["w"]) - 16.0, float(e["h"]) - 10.0)):
				kill_player(true, "sign")
				return
			continue

		if et == "enemy":
			_step_s1_enemy(e, i, dt, world_dt, active_solids)
			if i < entities.size() and entities[i] == e:
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 6.0, float(e["y"]) + 6.0, float(e["w"]) - 12.0, float(e["h"]) - 12.0)):
					kill_player(false, "enemy")
					return
			continue

		if lv_id >= 51 and not Sector1And2Mechanics.is_in_active_layer(e, active_layer) and et != "checkpoint":
			continue
		if et == "hourglass" and float(e.get("cooldown", 0.0)) > 0.0:
			continue

		var ew: float = float(e.get("w", 0.0))
		var eh: float = float(e.get("h", 0.0))
		if ew <= 0.0:
			continue
		var is_lethal_prop: bool = et in ["flower", "amanita", "poop", "spikes", "cloud_knife"]
		var hit_box: Rect2 = (
			Rect2(float(e["x"]) + 6.0, float(e["y"]) + 6.0, maxf(8.0, ew - 12.0), maxf(8.0, eh - 8.0))
			if is_lethal_prop
			else Rect2(float(e["x"]), float(e["y"]), ew, eh)
		)
		if not GridMath.aabb_overlap(p_rect, hit_box):
			continue

		if et == "flower":
			if (bool(e.get("rule_swap", false)) and rule_phase_b) or world_frozen:
				continue
			if float(player["antidote_window"]) > 0.0:
				player["shield"] = true
				emit_sfx("shield_up")
				_record_consumed_alchemy(e)
				entities.remove_at(i)
				hud_dirty = true
			elif float(player["poison_timer"]) > 0.0:
				player["poison_timer"] = 0.0
				player["bombs"] = int(player["bombs"]) + 1
				emit_sfx("coin")
				_record_consumed_alchemy(e)
				unlock_ach("toxic_alchemist")
				entities.remove_at(i)
				hud_dirty = true
			else:
				kill_player(true, "flower")
				return
		elif et == "amanita":
			if world_frozen:
				continue
			if float(player["antidote_window"]) > 0.0:
				player["bombs"] = int(player["bombs"]) + 1
				emit_sfx("coin")
				_record_consumed_alchemy(e)
				unlock_ach("toxic_alchemist")
				entities.remove_at(i)
				hud_dirty = true
			else:
				kill_player(true, "amanita")
				return
		elif et == "poop":
			kill_player(true, "poop")
			return
		elif et == "cloud_knife":
			if not (bool(e.get("rule_swap", false)) and rule_phase_b):
				kill_player(true, "cloud_knife")
				return
		elif et == "spikes":
			kill_player(false, "spike")
			return
		elif et == "poison_item":
			player["poison_timer"] = 12.0
			emit_sfx("poison")
			_record_consumed_alchemy(e)
			entities.remove_at(i)
			hud_dirty = true
		elif et == "antidote_pad":
			if float(player["poison_timer"]) > 0.0:
				player["poison_timer"] = 0.0
				player["invuln_timer"] = 4.2
				if lv_id >= 101:
					player["bombs"] = int(player["bombs"]) + 2
				_record_consumed_alchemy(e)
				unlock_ach("antidote_gold")
				unlock_ach("toxic_alchemist")
				emit_sfx("real_win")
				entities.remove_at(i)
				hud_dirty = true
		elif et == "bomb_pickup":
			player["bombs"] = int(player["bombs"]) + 1
			emit_sfx("coin")
			_record_consumed_alchemy(e)
			entities.remove_at(i)
			hud_dirty = true
		elif et == "spring":
			if float(player["grav_dir"]) > 0.0 and float(player["vy"]) >= -20.0:
				player["vy"] = -815.0
				player["on_ground"] = false
				player["spring_trail_timer"] = 0.42
				e["spring_anim"] = 1.0
				spring_impulse_scale(0.68, 1.38)
				add_afterimage(Color("#facc15"))
				emit_sfx("spring")
		elif et == "gravity_pad":
			var gdir: float = float(e.get("dir", -1.0))
			if absf(float(player["grav_dir"]) - gdir) > 0.1:
				player["grav_dir"] = gdir
				player["vy"] = gdir * 90.0
				spring_impulse_scale(0.80, 1.24)
				if gdir < 0.0:
					unlock_ach("grav_walker")
				emit_sfx("spring")
		elif et == "checkpoint":
			if bool(e.get("s3_fake", false)):
				if not bool(e.get("ambushed", false)):
					e["ambushed"] = true
					emit_sfx("fake_buzz")
					entities.append({
						"key": "cp_tanuki_" + str(Time.get_ticks_msec()),
						"t": "s3_tanuki",
						"x": float(e["x"]) + 28.0, "y": float(e["y"]),
						"spawn_x": float(e["x"]) + 28.0, "base_y": float(e["y"]),
						"w": 48.0, "h": 52.0, "hp": 2, "max_hp": 2,
						"cloned": true, "is_clone": false, "vx": -95.0, "vy": -220.0, "layer": -1
					})
			elif not bool(e.get("active", false)):
				for oth_cp_var in entities:
					var oth_cp: Dictionary = oth_cp_var
					if str(oth_cp.get("t", "")) == "checkpoint":
						oth_cp["active"] = false
				e["active"] = true
				save_checkpoint_at(float(e["gx"]), float(e["gy"]))
		elif et == "hourglass":
			emit_sfx("hint_popup")
			unlock_ach("time_rewinder")
			add_afterimage(Color("#00f5ff"))
			var snap_hg: Dictionary = find_trail_snapshot(maxf(0.0, time_elapsed - 2.4))
			if snap_hg.is_empty() or float(snap_hg["y"]) > float(e["y"]) - 16.0:
				for hi in range(history_trail.size() - 1, -1, -1):
					var cand: Dictionary = history_trail[hi]
					if float(cand["y"]) <= float(e["y"]) - 24.0 and bool(cand["on_ground"]):
						snap_hg = cand
						break
			var nearest_gate: Dictionary = {}
			var best_gd: float = 999999.0
			for sg_var in solids:
				var sg: Dictionary = sg_var
				if str(sg.get("t", "")) == "paradox_gate" and not bool(sg.get("gate_open", false)):
					var gd: float = absf(float(sg["x"]) - float(e["x"]))
					if gd < best_gd:
						best_gd = gd
						nearest_gate = sg
			if not nearest_gate.is_empty():
				nearest_gate["gate_open"] = true
				if snap_hg.is_empty() or float(snap_hg["y"]) > float(e["y"]) - 16.0:
					snap_hg = { "x": float(nearest_gate["x"]) - 42.0, "y": float(nearest_gate["y"]) + float(nearest_gate["h"]) - float(player["h"]) }
			else:
				paradox_unlocked = true
			if not snap_hg.is_empty():
				player["x"] = float(snap_hg["x"])
				player["y"] = float(snap_hg["y"])
				player["vx"] = 0.0
				player["vy"] = 0.0
				p_rect.position = Vector2(float(player["x"]), float(player["y"]))
			e["cooldown"] = 3.0
		elif et == "clock" and e.has("s3AddSec") and timer_left >= 0.0:
			timer_left += float(e["s3AddSec"])
			emit_sfx("coin")
			entities.remove_at(i)
		elif et == "coin":
			save.add_coins(1)
			emit_sfx("coin")
			entities.remove_at(i)
			hud_dirty = true
		elif et == "gem":
			var gc: String = str(e.get("color", "red"))
			entities.remove_at(i)
			collect_gem(gc)
		elif et == "powerup":
			emit_sfx("coin")
			var pk: String = str(e.get("kind", ""))
			if pk == "double_jump":
				player["max_jumps"] = 2
				player["jumps_left"] = 2
				unlock_ach("multi_jumper")
			elif pk == "flight":
				player["has_flight"] = true
				unlock_ach("cyber_wings")
			entities.remove_at(i)
			hud_dirty = true
		elif et == "pipe":
			if bool(inp.get("down_pressed", false)) or bool(inp.get("down", false)):
				emit_sfx("spring")
				unlock_ach("pipe_traveler")
				add_afterimage(Color("#4ade80"))
				player["x"] = GridMath.gx_to_px(float(e.get("destX", 2.0)))
				player["y"] = GridMath.gy_to_py(float(e.get("destY", 2.0)), 0.0) - float(player["h"])
				player["vx"] = 0.0
				player["vy"] = 0.0
				p_rect.position = Vector2(float(player["x"]), float(player["y"]))
		elif et == "shop":
			if bool(inp.get("down_pressed", false)):
				var pr: int = int(e.get("price", 3))
				if save.coins >= pr:
					save.add_coins(-pr)
					emit_sfx("fake_buzz")
					kill_player(true, "shop")
					return
				else:
					emit_sfx("block")
		elif et == "princess":
			var req_p: Array = e.get("req", ["red", "green", "blue"])
			if not princess_satisfied and collected_gems.size() >= req_p.size():
				princess_satisfied = true
				unlock_ach("gem_knight")
				emit_sfx("real_win")
		elif et == "flag":
			if bool(e.get("fake", false)):
				trigger_fake_flag(e)
				return
			var has_s3_boss: bool = false
			for sb_check_var in entities:
				var sb_check: Dictionary = sb_check_var
				if str(sb_check.get("t", "")) == "s3_boss":
					has_s3_boss = true
					break
			if lv_id >= 101 and bool(props.get("s3BossLockGoal", false)) and not s3_boss_defeated and has_s3_boss:
				emit_sfx("block")
				emit_toast("需先击败守关巨兽才能解封终点旗！", "DEFEAT THE STAGE BOSS FIRST!", "s3_flag_idle", "#fde047")
			elif bool(e.get("s3Runaway", false)) and not bool(e.get("has_run_away", false)):
				e["has_run_away"] = true
				e["x"] = GridMath.gx_to_px(35.0)
				emit_sfx("spring")
			elif bool(e.get("lockedByPrincess", false)) and not princess_satisfied:
				emit_sfx("block")
				emit_toast("需先集齐宝石献给公主解封！", "DELIVER GEMS TO PRINCESS FIRST!", "npc_princess", "#f472b6")
			else:
				trigger_level_win()
				return

func _step_s1_enemy(e: Dictionary, idx: int, dt: float, world_dt: float, active_solids: Array) -> void:
	if world_frozen:
		return
	var ek: String = str(e.get("kind", "follower"))
	if ek == "follower":
		var dir: float = 1.0 if float(player["x"]) > float(e["x"]) + 4.0 else (-1.0 if float(player["x"]) < float(e["x"]) - 4.0 else 0.0)
		var abs_dx: float = absf(float(player["x"]) - float(e["x"]))
		var spd: float = 152.0
		var astyle: String = str(e.get("atkStyle", ""))
		if astyle == "dasher":
			e["dash_cd"] = float(e.get("dash_cd", 1.4)) - world_dt
			var ds: String = str(e.get("dash_state", ""))
			if ds == "" and float(e["dash_cd"]) <= 0.0 and abs_dx < 240.0 and absf(float(player["y"]) - float(e["y"])) < 76.0:
				e["dash_state"] = "windup"
				e["dash_timer"] = 0.32
				e["dash_dir"] = dir if dir != 0.0 else 1.0
			elif ds == "windup":
				e["dash_timer"] = float(e["dash_timer"]) - world_dt
				spd = 20.0
				if float(e["dash_timer"]) <= 0.0:
					e["dash_state"] = "dash"
					e["dash_timer"] = 0.42
			elif ds == "dash":
				e["dash_timer"] = float(e["dash_timer"]) - world_dt
				spd = 295.0
				if float(e["dash_timer"]) <= 0.0:
					e["dash_state"] = ""
					e["dash_cd"] = 2.0
		elif astyle == "jumper" and bool(e.get("on_ground_enemy", false)):
			e["leap_cd"] = float(e.get("leap_cd", 1.5)) - world_dt
			if float(e["leap_cd"]) <= 0.0 and abs_dx < 250.0:
				e["vy"] = -430.0
				e["leap_cd"] = 1.95
				e["on_ground_enemy"] = false

		var eff_dir: float = float(e["dash_dir"]) if str(e.get("dash_state", "")) == "dash" else dir
		e["vx"] = eff_dir * spd
		e["vy"] = float(e.get("vy", 0.0)) + 1200.0 * world_dt
		e["x"] = float(e["x"]) + float(e["vx"]) * world_dt
		var er_x: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		for sx_var in active_solids:
			var sx: Dictionary = sx_var
			var stx: String = str(sx.get("t", ""))
			if (stx == "invis" or stx == "qblock") and not bool(sx.get("revealed", false)):
				continue
			if GridMath.aabb_overlap(er_x, Rect2(float(sx["x"]), float(sx["y"]), float(sx["w"]), float(sx["h"]))):
				e["x"] = (float(sx["x"]) - float(e["w"])) if float(e["vx"]) > 0.0 else (float(sx["x"]) + float(sx["w"]))
				er_x.position.x = float(e["x"])
				if bool(e.get("on_ground_enemy", false)) and float(sx["h"]) <= 1.6 * GridMath.TILE:
					e["vy"] = -410.0
					e["on_ground_enemy"] = false
		e["y"] = float(e["y"]) + float(e["vy"]) * world_dt
		e["on_ground_enemy"] = false
		var er_y: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		for sy_var in active_solids:
			var sy: Dictionary = sy_var
			var sty: String = str(sy.get("t", ""))
			if (sty == "invis" or sty == "qblock") and not bool(sy.get("revealed", false)):
				continue
			if float(e["vy"]) >= 0.0 and GridMath.aabb_overlap(er_y, Rect2(float(sy["x"]), float(sy["y"]), float(sy["w"]), float(sy["h"]))):
				e["y"] = float(sy["y"]) - float(e["h"])
				e["vy"] = 0.0
				e["on_ground_enemy"] = true
				er_y.position.y = float(e["y"])
		if float(e["y"]) > GridMath.WORLD_ORIGIN_Y + 90.0:
			emit_sfx("coin")
			entities.remove_at(idx)
	elif ek == "flying":
		e["phase_clock"] = float(e.get("phase_clock", 0.0)) + world_dt
		var phasing: bool = str(e.get("atkStyle", "")) == "phaser" and fposmod(float(e["phase_clock"]), 4.4) > 2.4
		e["is_phasing"] = phasing
		if phasing and Vector2(float(player["x"]) - float(e["x"]), float(player["y"]) - float(e["y"])).length() < 340.0:
			var dv: Vector2 = Vector2(float(player["x"]) - float(e["x"]), (float(player["y"]) - 16.0) - float(e["y"])).normalized()
			e["x"] = float(e["x"]) + dv.x * 95.0 * world_dt
			e["y"] = float(e["y"]) + dv.y * 80.0 * world_dt
		else:
			e["y"] = float(e["base_y"]) + sin(time_elapsed * 3.4 + float(e["x"]) * 0.02) * 34.0
			e["x"] = float(e["x"]) + cos(time_elapsed * 1.8) * 52.0 * world_dt
		if absf(float(player["x"]) - float(e["x"])) < 420.0:
			e["atk_cd"] = float(e.get("atk_cd", 2.2)) - world_dt
			if float(e["atk_cd"]) <= 0.0:
				e["atk_cd"] = 2.85
				var dv2: Vector2 = (Vector2(float(player["x"]) + 14.0, float(player["y"]) + 21.0) - Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)).normalized()
				enemy_shots.append({
					"x": float(e["x"]) + float(e["w"]) * 0.5 - 5.0, "y": float(e["y"]) + float(e["h"]) * 0.5,
					"w": 11.0, "h": 11.0, "vx": dv2.x * 185.0, "vy": dv2.y * 185.0,
					"pierce_walls": phasing, "kind": "phase_orb" if phasing else "aimed",
					"layer": -1, "life": 2.6
				})
				emit_sfx("shoot")
	elif ek == "boss":
		if float(e.get("stun_timer", 0.0)) > 0.0:
			e["stun_timer"] = maxf(0.0, float(e["stun_timer"]) - dt)
		else:
			e["x"] = float(e["x"]) + float(e.get("speed", 3.6)) * GridMath.TILE * world_dt
			e["y"] = float(e["y"]) + ((float(player["y"]) - 24.0) - float(e["y"])) * 1.8 * world_dt

func _step_enemy_shots(dt: float, world_dt: float, active_solids: Array) -> void:
	if enemy_shots.is_empty() or world_frozen:
		return
	var p_rect: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))
	for k in range(enemy_shots.size() - 1, -1, -1):
		var sh: Dictionary = enemy_shots[k]
		var mul: float = Sector1And2Mechanics.get_local_time_scale(float(sh["x"]) + 6.0, float(sh["y"]) + 6.0, entities) if lv_id >= 51 else 1.0
		if absf(float(sh.get("grav", 0.0))) > 0.01:
			sh["vy"] = float(sh.get("vy", 0.0)) + float(sh["grav"]) * world_dt * mul
		sh["x"] = float(sh["x"]) + float(sh.get("vx", 0.0)) * world_dt * mul
		sh["y"] = float(sh["y"]) + float(sh.get("vy", 0.0)) * world_dt * mul
		sh["life"] = float(sh["life"]) - dt
		if float(sh["life"]) <= 0.0:
			enemy_shots.remove_at(k)
			continue
		var shr: Rect2 = Rect2(float(sh["x"]), float(sh["y"]), float(sh.get("w", 12.0)), float(sh.get("h", 12.0)))
		var sh_l: int = int(sh.get("layer", -1))
		var same_layer: bool = (lv_id < 51) or (sh_l < 0) or (sh_l == active_layer)
		if str(sh.get("kind", "")) == "lob":
			var hit_pb: bool = false
			for pb_var in bullets:
				var pb: Dictionary = pb_var
				if GridMath.aabb_overlap(Rect2(float(pb["x"]), float(pb["y"]), float(pb["w"]), float(pb["h"])), shr):
					hit_pb = true
					break
			if hit_pb:
				enemy_shots.remove_at(k)
				continue
		if same_layer and not bool(sh.get("pierce_walls", false)):
			var hit_w: bool = false
			for w_var in active_solids:
				var w_d: Dictionary = w_var
				var wt: String = str(w_d.get("t", ""))
				if (wt == "invis" or wt == "qblock") and not bool(w_d.get("revealed", false)):
					continue
				if GridMath.aabb_overlap(shr, Rect2(float(w_d["x"]), float(w_d["y"]), float(w_d["w"]), float(w_d["h"]))):
					hit_w = true
					break
			if hit_w:
				enemy_shots.remove_at(k)
				continue
		if same_layer and GridMath.aabb_overlap(p_rect, shr):
			enemy_shots.remove_at(k)
			kill_player(false, "turret" if lv_id >= 51 else "enemy")
			return

func update_camera(dt: float) -> void:
	if player.is_empty() or lv_data.is_empty():
		return
	var bounds_d: Dictionary = lv_data.get("bounds", { "minX": -2.0, "maxX": 60.0 })
	var min_x: float = GridMath.gx_to_px(float(bounds_d.get("minX", -2.0)))
	var max_x: float = maxf(min_x + GridMath.VIEWPORT_W, GridMath.gx_to_px(float(bounds_d.get("maxX", 60.0))))
	var look_ahead: float = float(player["facing"]) * 48.0
	var target_x: float = clampf(float(player["x"]) + float(player["w"]) * 0.5 + look_ahead - 460.0, min_x, max_x - GridMath.VIEWPORT_W)
	var target_y: float = minf(0.0, float(player["y"]) - 190.0) if float(player["y"]) < 140.0 else 0.0
	var k: float = 1.0 if dt >= 1.0 else (1.0 - exp(-dt * 9.5))
	cam_x = lerpf(cam_x, target_x, k)
	cam_y = lerpf(cam_y, target_y, k)
