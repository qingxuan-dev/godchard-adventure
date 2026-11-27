class_name StageEngine
extends RefCounted

var levels_by_id: Dictionary = {}
var save: SaveManager
var shop: ShopSystem
var event_bus: EventBus
var world_state: WorldState
var boss_sm: BossStateMachine
var boss_state: Dictionary = {}
var visual_captions: Array = []

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
var fired_logic_ids: Dictionary = {}

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
var assist_mode: bool = false
var anti_troll_disqualified: bool = false
var anti_troll_earned: bool = true
var collected_shard_this_run: bool = false
var hints_used_tier: int = 0
var used_full_hint: bool = false
var sword_sheathed: bool = false
var mirror_input_active: bool = false

var cam_x: float = 0.0
var cam_y: float = 0.0
var shake_timer: float = 0.0
var shake_dur: float = 0.2
var shake_mag: float = 0.0
var hit_stop_timer: float = 0.0
var pipe_warp_cd: float = 0.0
var jump_buffer_timer: float = 0.0
var shield_flash_timer: float = 0.0

var death_modal_delay: float = -1.0
var pending_death_cause: String = ""
var pending_death_modal_cause: String = ""
var pending_win_result: Dictionary = {}
var hud_dirty: bool = true

var sfx_queue: Array[String] = []
var toast_queue: Array = []
var ach_queue: Array[String] = []

func _init(p_levels: Array = [], p_save: SaveManager = null, p_shop: ShopSystem = null) -> void:
	save = p_save if p_save != null else SaveManager.new(false)
	shop = p_shop if p_shop != null else ShopSystem.new(save, [])
	event_bus = EventBus.new()
	world_state = WorldState.new()
	boss_sm = BossStateMachine.new()
	boss_state = boss_sm.state
	visual_captions = event_bus.visual_captions
	set_levels(p_levels)

func set_levels(p_levels: Array) -> void:
	levels_by_id.clear()
	for lv_var in p_levels:
		if typeof(lv_var) == TYPE_DICTIONARY:
			var lv: Dictionary = lv_var
			levels_by_id[int(lv.get("id", 1))] = lv

func load_stage(stage_or_dict: Variant) -> void:
	if typeof(stage_or_dict) == TYPE_DICTIONARY:
		var d: Dictionary = stage_or_dict
		var sid: int = clampi(int(d.get("id", 1)), 1, 150)
		levels_by_id[sid] = d
		start_stage(sid)
	else:
		start_stage(int(stage_or_dict))

func step(raw_dt: float, inp: Dictionary) -> void:
	step_frame(raw_dt, inp)

func restart_stage(full_reset: bool = false) -> void:
	if full_reset:
		manual_fresh_restart()
	else:
		reset_attempt()

func validate_stage_data(lv_dict: Dictionary = {}, strict_v2: bool = false) -> Dictionary:
	var target: Dictionary = lv_dict if not lv_dict.is_empty() else lv_data
	return LevelValidator.validate_level(target, strict_v2)

func record_hint_used(tier: int) -> void:
	hints_used_tier = maxi(hints_used_tier, clampi(tier, 1, 3))
	if hints_used_tier >= 3:
		used_full_hint = true

func emit_sfx(name: String) -> void:
	sfx_queue.append(name)
	if event_bus != null:
		event_bus.captions_enabled = (save == null) or bool(save.visual_captions_on)
		var ppos: Vector2 = Vector2(float(player.get("x", 0.0)), float(player.get("y", 0.0))) if not player.is_empty() else Vector2.ZERO
		event_bus.push_sfx_caption(name, ppos, false)
		event_bus.emit_event("sfx", { "name": name })

func emit_toast(zh: String, en: String, icon: String = "ui_hint", color_hex: String = "#00f5ff") -> void:
	toast_queue.append({ "zh": zh, "en": en, "icon": icon, "color": color_hex })
	if event_bus != null:
		event_bus.emit_event("toast", { "zh": zh, "en": en, "icon": icon, "color": color_hex })

func unlock_ach(ach_id: String) -> void:
	if save != null and save.unlock_ach(ach_id):
		ach_queue.append(ach_id)
		emit_sfx("ach_unlock")

func is_magic_sword_enabled() -> bool:
	var abilities: Array = []
	if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY:
		var pr: Dictionary = lv_data["props"]
		if typeof(pr.get("abilities", null)) == TYPE_ARRAY:
			abilities = pr["abilities"]
	return (
		(save != null and (save.magic_sword_unlocked or save.is_stage_cleared(50)))
		or lv_id >= 51
		or ("magic_sword" in abilities)
		or ("sword" in abilities)
		or ("melee" in abilities)
		or bool(player.get("sword_up", false))
	)

func is_dual_layer_active() -> bool:
	return Sector1And2Mechanics.is_dual_layer_stage(lv_data)

func is_hint_unlocked() -> bool:
	if save == null:
		return true
	return save.get_stage_max_deaths(lv_id, attempt_deaths, total_lv_deaths) >= 5

func get_max_deaths() -> int:
	if save == null:
		return attempt_deaths
	return save.get_stage_max_deaths(lv_id, attempt_deaths, total_lv_deaths)

func start_stage(stage_id: int) -> void:
	lv_id = clampi(stage_id, 1, 150)
	lv_data = levels_by_id.get(lv_id, levels_by_id.get(1, {}))
	if save != null:
		save.last_lv = lv_id
		save.persist()
		total_lv_deaths = int(save.deaths_by_lv.get(str(lv_id), 0))
	else:
		total_lv_deaths = 0
	attempt_deaths = 0
	adaptive_stacks = 0
	loop_progress = 1
	xray_level = false
	assist_mode = (save != null and save.assist_mode)
	anti_troll_disqualified = false
	anti_troll_earned = true
	collected_shard_this_run = false
	hints_used_tier = 0
	used_full_hint = false
	sword_sheathed = false
	mirror_input_active = false
	active_checkpoint = {}
	revealed_invis_keys = {}
	broken_solid_keys = {}
	filled_slot_keys = {}
	consumed_carry_keys = {}
	purified_save_keys = {}
	fired_logic_ids = {}
	pending_win_result = {}
	pending_death_modal_cause = ""
	death_modal_delay = -1.0
	if event_bus != null:
		event_bus.clear_transient()
	if shop != null:
		shop.reset_for_new_stage()
	reset_attempt()

func manual_fresh_restart() -> void:
	active_checkpoint = {}
	revealed_invis_keys = {}
	broken_solid_keys = {}
	filled_slot_keys = {}
	consumed_carry_keys = {}
	purified_save_keys = {}
	fired_logic_ids = {}
	loop_progress = 1
	anti_troll_disqualified = false
	anti_troll_earned = true
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
	var props: Dictionary = lv_data.get("props", {}) if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY else {}
	princess_perm_order = _shuffle_gem_order() if bool(props.get("randomGemOrder", false)) else ["red", "green", "blue"]
	time_elapsed = 0.0
	move_time = 0.0
	hit_stop_timer = 0.0
	pipe_warp_cd = 0.0
	jump_buffer_timer = 0.0
	alchemy_regen_timer = 0.0
	consumed_alchemy_pool = []
	if props.has("timer"):
		timer_left = float(props["timer"])
	elif props.has("timeLimit") and float(props["timeLimit"]) > 0.0:
		timer_left = float(props["timeLimit"])
	else:
		timer_left = -1.0
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
	fired_logic_ids = active_checkpoint.get("fired_logic_ids", {}).duplicate(true) if not active_checkpoint.is_empty() else {}

	world_state.reset_for_attempt(props, active_checkpoint)

	var spawn_d: Dictionary = lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
	var sp_gx: float = float(active_checkpoint.get("x", spawn_d.get("x", 2.0))) if not active_checkpoint.is_empty() else float(spawn_d.get("x", 2.0))
	var sp_gy: float = float(active_checkpoint.get("y", spawn_d.get("y", 2.0))) if not active_checkpoint.is_empty() else float(spawn_d.get("y", 2.0))
	var spx: float = GridMath.gx_to_px(sp_gx) + 10.0
	var spy: float = GridMath.gy_to_py(sp_gy, 0.0) - 42.0

	player = PlayerController.create_player_dict(Vector2(spx, spy), props, active_checkpoint)
	player["grav_dir"] = world_state.get_grav_dir_scalar()

	solids = []
	entities = []
	Sector1And2Mechanics.init_attempt_state(self, lv_data, props, active_checkpoint)
	Sector3Arcadia.init_attempt_state(self, active_checkpoint)
	world_state.active_layer = active_layer
	boss_sm.init_for_stage(self, lv_id, lv_data, active_checkpoint)
	boss_state = boss_sm.state

	if shop != null:
		shop.apply_stage_buffs(player)
		if shop.map_lens_active:
			xray_level = true

	var spawned_uuids: Dictionary = {}
	var objs: Array = lv_data.get("objs", [])
	for idx in range(objs.size()):
		if typeof(objs[idx]) != TYPE_DICTIONARY:
			continue
		var o: Dictionary = objs[idx]
		var o_uid: String = str(o.get("uuid", "")).strip_edges()
		if o_uid != "":
			spawned_uuids[o_uid] = true
		if Sector3Arcadia.spawn_obj(self, o, idx, lv_data):
			continue
		if Sector1And2Mechanics.spawn_obj(self, o, idx, lv_data):
			continue
		_spawn_core_obj(o, idx)

	# Also spawn top-level checkpoints & collectibles from v2.0 schema if not already in objs
	if typeof(lv_data.get("checkpoints", null)) == TYPE_ARRAY:
		var cp_arr: Array = lv_data["checkpoints"]
		for cpi in range(cp_arr.size()):
			if typeof(cp_arr[cpi]) != TYPE_DICTIONARY:
				continue
			var cpo: Dictionary = cp_arr[cpi].duplicate(true)
			var cp_uid: String = str(cpo.get("uuid", "")).strip_edges()
			if cp_uid != "" and spawned_uuids.has(cp_uid):
				continue
			cpo["t"] = str(cpo.get("t", "checkpoint"))
			_spawn_core_obj(cpo, 5000 + cpi)

	if typeof(lv_data.get("collectibles", null)) == TYPE_ARRAY:
		var col_arr: Array = lv_data["collectibles"]
		for coli in range(col_arr.size()):
			if typeof(col_arr[coli]) != TYPE_DICTIONARY:
				continue
			var colo: Dictionary = col_arr[coli].duplicate(true)
			var col_uid: String = str(colo.get("uuid", "")).strip_edges()
			if col_uid != "" and spawned_uuids.has(col_uid):
				continue
			colo["t"] = str(colo.get("t", "mem_shard"))
			if not Sector1And2Mechanics.spawn_obj(self, colo, 6000 + coli, lv_data):
				_spawn_core_obj(colo, 6000 + coli)

	if bool(props.get("adaptive", false)) and adaptive_stacks > 0:
		for s_i in range(mini(4, adaptive_stacks)):
			entities.append({
				"uuid": "adapt_" + str(s_i), "key": "adapt_" + str(s_i), "t": "poop",
				"x": GridMath.gx_to_px(8.2 + float(s_i) * 3.1),
				"y": GridMath.gy_to_py(2.0, 0.88),
				"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE,
				"falling_poop": false, "layer": -1
			})

	if bool(props.get("escalateLoop", false)) and loop_progress >= 2:
		entities.append({
			"uuid": "loop_imp", "key": "loop_imp", "t": "enemy", "kind": "follower",
			"x": GridMath.gx_to_px(8.2), "y": GridMath.gy_to_py(2.0, 1.05),
			"w": 0.92 * GridMath.TILE, "h": 1.02 * GridMath.TILE,
			"vx": 0.0, "vy": 0.0, "hp": 5, "max_hp": 5, "layer": -1
		})
		if loop_progress >= 3:
			for fx in [25.8, 30.4]:
				entities.append({
					"uuid": "loop_fl_" + str(fx), "key": "loop_fl_" + str(fx), "t": "flower",
					"x": GridMath.gx_to_px(fx), "y": GridMath.gy_to_py(2.0, 0.88),
					"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE, "layer": -1
				})

	update_camera(1.0)
	hud_dirty = true

func _spawn_core_obj(o: Dictionary, idx: int) -> void:
	var key: String = str(o.get("uuid", "%d_%d" % [lv_id, idx]))
	var t: String = str(o.get("t", ""))
	if t == "mirror_rotatable":
		t = "mirror"
	elif t == "enemy_boss":
		t = "enemy"
	var ox: float = float(o.get("x", 0.0))
	var oy: float = float(o.get("y", 0.0))
	var layer_val: int = int(o["layer"]) if (o.has("layer") and o["layer"] != null) else -1

	if t in ["solid", "fake_wall", "vanish", "fake_plat", "destructible", "mirror", "paradox_gate", "timed_gate"]:
		var oh: float = float(o.get("h", 1.0))
		var sx0: float = GridMath.gx_to_px(ox)
		var sy0: float = GridMath.gy_to_py(oy, oh)
		solids.append({
			"uuid": key, "key": key, "t": t,
			"x": sx0, "y": sy0, "base_x": sx0, "base_y": sy0,
			"w": float(o.get("w", 1.0)) * GridMath.TILE,
			"h": oh * GridMath.TILE,
			"skin": str(o.get("skin", "")),
			"rotatable": bool(o.get("rotatable", false)),
			"angle": float(o.get("angle", 90.0)),
			"reflects_bomb": bool(o.get("reflectsBomb", false)),
			"pound_break": bool(o.get("poundBreak", false)),
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
			"uuid": key, "key": key, "t": "invis",
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
			"uuid": key, "key": key, "t": "qblock",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, 0.95),
			"w": 0.95 * GridMath.TILE, "h": 0.95 * GridMath.TILE,
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
		var csub: String = str(o.get("subType", "blade" if bool(o.get("knife", false)) else "solid"))
		if csub != "blade":
			var cy: float = GridMath.gy_to_py(oy, 0.85)
			solids.append({
				"uuid": key, "key": key, "t": "cloud_plat",
				"sub_type": csub,
				"x": GridMath.gx_to_px(ox), "y": cy, "base_y": cy,
				"w": float(o.get("w", 1.7)) * GridMath.TILE, "h": 0.85 * GridMath.TILE,
				"rule_swap": bool(o.get("ruleSwap", false)),
				"step_cue_cd": 0.0,
				"move_dx_px": 0.0, "move_dy_px": 0.0,
				"revealed": true, "layer": layer_val, "broken": false
			})
		else:
			var kcy: float = GridMath.gy_to_py(oy, 0.9)
			entities.append({
				"uuid": key, "key": key, "t": "cloud_knife",
				"x": GridMath.gx_to_px(ox), "y": kcy, "base_y": kcy,
				"w": float(o.get("w", 1.65)) * GridMath.TILE, "h": 0.9 * GridMath.TILE,
				"brittle_core": bool(o.get("brittleCore", true)),
				"rule_swap": bool(o.get("ruleSwap", false)),
				"layer": layer_val
			})
	else:
		var ent: Dictionary = o.duplicate(true)
		ent["uuid"] = key
		ent["key"] = key
		ent["t"] = t
		ent["layer"] = layer_val
		if str(o.get("t", "")) == "enemy_boss":
			ent["kind"] = "boss"
		if t in ["flower", "amanita", "poop", "poison_item", "bomb_pickup", "antidote_pad", "crafting", "spring", "hourglass"]:
			ent["x"] = GridMath.gx_to_px(ox) + 4.0
			ent["y"] = GridMath.gy_to_py(oy, 0.88)
			ent["spawn_x"] = float(ent["x"])
			ent["spawn_y"] = float(ent["y"])
			ent["w"] = 0.82 * GridMath.TILE
			ent["h"] = 0.88 * GridMath.TILE
			ent["sub_type"] = str(o.get("subType", ""))
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
			ent["wire_timer"] = 0.0
		elif t == "flag":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.6)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 1.6 * GridMath.TILE
			ent["shy_left"] = int(o.get("shySteps", 0))
			ent["fake"] = bool(o.get("fake", false))
			ent["fake_type"] = str(o.get("fakeType", ""))
			ent["require_back_entry"] = bool(o.get("requireBackEntry", false))
			ent["tentacle_disarmed"] = false
			ent["has_run_away"] = false
		elif t == "clock":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.1)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 1.1 * GridMath.TILE
			ent["hp"] = int(o.get("hp", 1))
			ent["scope"] = str(o.get("scope", ""))
		elif t == "launcher":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 0.95)
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 0.95 * GridMath.TILE
			ent["cd"] = 0.35
			ent["recoil"] = 0.0
			ent["shot_idx"] = 0
		elif t == "pipe":
			ent["x"] = GridMath.gx_to_px(ox)
			ent["y"] = GridMath.gy_to_py(oy, 1.35)
			ent["w"] = 1.35 * GridMath.TILE
			ent["h"] = 1.35 * GridMath.TILE
			ent["echo_cd"] = 0.0
		elif t in ["coin", "gem", "powerup"]:
			ent["x"] = GridMath.gx_to_px(ox) + 6.0
			ent["y"] = GridMath.gy_to_py(oy, 0.8)
			ent["w"] = 0.75 * GridMath.TILE
			ent["h"] = 0.75 * GridMath.TILE
			ent["weighted"] = bool(o.get("weighted", false))
			ent["pickup_cd"] = 0.0
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
			var ekind: String = str(ent.get("kind", "follower"))
			ent["armor_flash"] = 0.0
			ent["jolt_x"] = 0.0
			ent["is_phasing"] = false
			ent["tracks_shadow"] = bool(o.get("tracksShadow", false)) or (ekind == "shadow_follower")
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

func find_obj_by_uuid(target_uuid: String) -> Dictionary:
	if target_uuid == "":
		return {}
	for s_var in solids:
		var s: Dictionary = s_var
		if str(s.get("uuid", s.get("key", ""))) == target_uuid:
			return s
	for e_var in entities:
		var e: Dictionary = e_var
		if str(e.get("uuid", e.get("key", ""))) == target_uuid:
			return e
	return {}

func _does_logic_event_match(edge_evt: String, runtime_evt: String) -> bool:
	if edge_evt == "" or edge_evt == runtime_evt:
		return true
	if runtime_evt == "on_activate" and (edge_evt in ["on_activated", "on_triggered", "on_trigger", "on_opened", "on_weight_satisfied", "on_all_3_ring_lit", "on_ring", "on_pressure_rise"]):
		return true
	if runtime_evt == "on_step" and (edge_evt in ["on_touch", "on_board", "on_enter", "on_slot_enter", "on_walk_flat", "on_back_facing_walk", "on_sprint_pass", "on_pass_through", "on_stand_beneath", "on_stand_behind", "on_idle_beneath"]):
		return true
	if runtime_evt == "on_interact" and (edge_evt.begins_with("on_interact") or edge_evt in ["on_inspect", "on_click_or_hit_x", "on_bullet_hit_or_interact", "on_interact_or_shot", "on_safe_mode", "on_sheathe_retreat", "on_sheathe_backturn_wait", "on_half_swing_sheathe"]):
		return true
	if runtime_evt == "on_pickup" and (edge_evt.begins_with("on_pickup") or edge_evt.begins_with("on_poisoned") or edge_evt.ends_with("_used")):
		return true
	if runtime_evt == "on_bullet_hit" and (edge_evt.begins_with("on_bullet") or edge_evt in ["on_hit", "on_shot", "on_slash_or_shot", "on_side_bullet_hit", "on_struck", "on_normal_bullet_hit", "on_single_shot", "on_shoot", "on_remote_shoot", "on_interact_or_shot", "on_bullet_hit_or_interact", "on_sword_or_bullet_hit", "on_sword_or_hit", "on_click_or_hit_x"]):
		return true
	if runtime_evt == "on_sword_slash" and (edge_evt.begins_with("on_sword") or edge_evt.begins_with("on_slash") or edge_evt in ["on_underside_slash", "on_crouch_slash", "on_hit", "on_struck", "on_player_attack", "on_click_or_hit_x", "on_wrench_parry_up", "on_wrench_parry_forward", "on_sword_parry"]):
		return true
	if runtime_evt == "on_ground_pound" and (edge_evt in ["on_third_jump_ground_pound", "on_slam_and_hop", "on_drop_stomp", "on_slam_valve"]):
		return true
	if runtime_evt == "on_bump" and (edge_evt in ["on_hit", "on_upward_hit", "on_side_bump", "on_bump_and_push", "on_wind_bump"]):
		return true
	if runtime_evt == "on_shatter" and (edge_evt in ["on_broken", "on_break", "on_destroy", "on_detonate", "on_alchemy_bomb", "on_fall_impact"]):
		return true
	if runtime_evt == "on_slot_filled" and (edge_evt.ends_with("_inserted") or edge_evt.ends_with("_placed") or edge_evt.ends_with("_slotted") or edge_evt in ["on_coin_place", "on_drop_to_pan", "on_push_into_core"]):
		return true
	if runtime_evt == "on_bullet_reflect" and ("reflect" in edge_evt or "ricochet" in edge_evt or "bounce" in edge_evt):
		return true
	return false

func fire_logic_event(trigger_uuid: String, event_name: String, context: Dictionary = {}) -> void:
	if trigger_uuid == "":
		return
	if event_bus != null:
		event_bus.emit_event("logic_trigger", { "uuid": trigger_uuid, "event": event_name, "context": context })

	if typeof(lv_data.get("logic_graph", null)) != TYPE_ARRAY:
		return
	var graph: Array = lv_data["logic_graph"]
	for edge_var in graph:
		if typeof(edge_var) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_var
		var e_trig: String = str(edge.get("trigger_uuid", ""))
		var e_evt: String = str(edge.get("event", ""))
		if e_trig != trigger_uuid or not _does_logic_event_match(e_evt, event_name):
			continue
		var eid: String = str(edge.get("id", ""))
		if bool(edge.get("once", false)) and eid != "" and bool(fired_logic_ids.get(eid, false)):
			continue
		if eid != "":
			fired_logic_ids[eid] = true

		var targ_uid: String = str(edge.get("target_uuid", ""))
		var action: String = str(edge.get("action", "reveal"))
		if targ_uid == "stage_exit" or action == "win" or action == "teleport_to_goal_sanctuary":
			trigger_level_win()
			return
		if targ_uid == "boss" and boss_sm != null:
			boss_sm.on_puzzle_event(self, str(edge.get("bossEvent", action)), context)
			continue
		if targ_uid == "world" or targ_uid == "sundial" or targ_uid == "timer":
			if action == "shift_sundial":
				var np: String = world_state.advance_sundial_phase(1)
				s3_sundial_phase = (np != WorldState.PHASE_DAY)
			elif action == "grant_perm" or action == "unlock_admin_privilege":
				world_state.set_permission(str(edge.get("perm", "ADMIN")))
			elif "pause" in action or "freeze" in action:
				world_frozen = true
			continue

		var target_obj: Dictionary = find_obj_by_uuid(targ_uid)
		if not target_obj.is_empty():
			var tt: String = str(target_obj.get("t", ""))
			if boss_sm != null and (tt in ["s2_boss", "s3_boss", "enemy_boss"] or str(target_obj.get("bossKey", target_obj.get("bossKind", ""))) != ""):
				boss_sm.on_puzzle_event(self, str(edge.get("bossEvent", action)), context)
				if action in ["sever_main_cable_defeat", "self_reflect_cannon_shatter_core", "trap_barrage_self_destruct_core"]:
					target_obj["hp"] = 0
					boss_sm.state["boss_armor"] = 0
					boss_sm.state["boss_hp"] = 0
					boss_sm.state["defeated"] = true
					fire_logic_event(targ_uid, "on_defeat", context)
		if target_obj.is_empty():
			if action == "set_signal" or "open" in action or "unlock" in action:
				signal_groups[targ_uid] = true
			continue

		if action == "reveal" or action.begins_with("reveal_") or action.begins_with("expose_") or action.begins_with("materialize_"):
			target_obj["revealed"] = true
			target_obj["active"] = true
			revealed_invis_keys[str(target_obj.get("key", targ_uid))] = true
		elif action in ["open", "unlock", "open_gate", "root_override_complete"] or "open_" in action or action.begins_with("unlock_"):
			target_obj["gate_open"] = true
			target_obj["unlocked"] = true
			target_obj["is_open"] = true
			target_obj["fake"] = false
			if str(target_obj.get("group", "")) != "":
				signal_groups[str(target_obj["group"])] = true
		elif action == "close" or action == "drop_lock_trap_boss":
			target_obj["gate_open"] = false
			target_obj["is_open"] = false
			if str(target_obj.get("group", "")) != "":
				signal_groups[str(target_obj["group"])] = false
		elif action in ["break", "shatter"] or action.begins_with("shatter_") or "shatters_" in action or action.begins_with("smash_"):
			target_obj["broken"] = true
			broken_solid_keys[str(target_obj.get("key", targ_uid))] = true
			if "wings" in action and not player.is_empty():
				player["has_flight"] = true
				player["wing_fuel"] = 100.0
			fire_logic_event(targ_uid, "on_shatter", context)
		elif action in ["drop_as_slope", "tilt_tower_form_slope", "drop_lever_ramp"]:
			target_obj["revealed"] = true
			target_obj["fallen_slope"] = true
		elif action in ["drop_as_bridge", "enable_platform", "bridge_pit_reach_key1", "enter_safe_mode_solidify_mesh"] or action.begins_with("stabilize_") or action.begins_with("solidify_"):
			target_obj["revealed"] = true
			target_obj["bridge_on"] = true
			target_obj["collidable"] = true
		elif action == "convert_to_pushable_block" or action.begins_with("slide_popup"):
			target_obj["pushable_block"] = true
			target_obj["collidable"] = true
		elif action == "invert_gravity_to_ceiling" or action == "invert_gravity_up":
			world_state.set_gravity_vector(Vector2(0.0, -1.0))
			if not player.is_empty():
				player["grav_dir"] = -1.0
		elif action.begins_with("restore_down"):
			world_state.set_gravity_vector(Vector2(0.0, 1.0))
			if not player.is_empty():
				player["grav_dir"] = 1.0
		elif action == "rotate_gravity_90_sidewall":
			world_state.set_gravity_vector(Vector2(1.0, 0.0))
		elif action == "spawn_spore_key" and not player.is_empty():
			player["has_spore_key"] = true
			target_obj["revealed"] = true
		elif action == "dispense_magic_sword" and not player.is_empty():
			player["sword_up"] = true
			if save != null:
				save.magic_sword_unlocked = true
		elif action == "grant_alchemy_bomb" and not player.is_empty():
			player["bombs"] = int(player.get("bombs", 0)) + 1
		elif action == "disarm_cloud" or action.begins_with("drop_blades"):
			target_obj["disarmed"] = true
		elif action == "tame_flag" or action.begins_with("pacify"):
			target_obj["tamed"] = true
			target_obj["pacified"] = true
			target_obj["fake"] = false
		elif action == "set_signal":
			var sg_n: String = str(edge.get("group", target_obj.get("group", targ_uid)))
			signal_groups[sg_n] = true
		elif action == "toggle_signal":
			var sg_t: String = str(edge.get("group", target_obj.get("group", targ_uid)))
			signal_groups[sg_t] = not bool(signal_groups.get(sg_t, false))
		elif action.begins_with("lower_") or action == "shift_carrier_height":
			target_obj["lowered"] = true
			var pg_l: String = str(target_obj.get("pipe_group", target_obj.get("pipeGroup", "")))
			if pg_l != "":
				s3_valves[pg_l] = true
			if target_obj.has("target_h_px") and target_obj.has("foot_y"):
				target_obj["h"] = float(target_obj["target_h_px"])
				target_obj["y"] = float(target_obj["foot_y"]) - float(target_obj["h"])
		elif action == "activate_valve":
			target_obj["spun"] = true
			target_obj["fake"] = false
			var pg_v: String = str(target_obj.get("pipe_group", target_obj.get("pipeGroup", "")))
			if pg_v != "":
				s3_valves[pg_v] = true
			fire_logic_event(targ_uid, "on_activate", context)
		elif action.begins_with("disarm_"):
			target_obj["disarmed"] = true
			target_obj["blades_out"] = false
		elif action.begins_with("shut_suction") or action == "block_suction_divert_side":
			target_obj["shut"] = true
			target_obj["disabled"] = true
			target_obj["suction_off"] = true
		elif action == "freeze_solid_window":
			target_obj["thunder_frozen_timer"] = 6.5
			target_obj["collidable"] = true
		elif action == "spawn_low_log" or action == "solidify_clone_into_log":
			target_obj["revealed"] = true
			target_obj["collidable"] = true
			target_obj["pushable"] = true
		else:
			target_obj["logic_state"] = action
			target_obj["activated_by_logic"] = true

func save_checkpoint_at(gx: float, gy: float) -> void:
	active_checkpoint = {
		"x": gx, "y": gy,
		"bullet_up": bool(player.get("bullet_up", false)) and not bool(player.get("from_shop_bullet", false)),
		"max_jumps": 1 if bool(player.get("from_shop_jump", false)) else int(player.get("max_jumps", 1)),
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
		"purified_save_keys": purified_save_keys.duplicate(true),
		"fired_logic_ids": fired_logic_ids.duplicate(true),
		"world_state": world_state.export_checkpoint_snapshot(),
		"boss_sm": boss_sm.export_checkpoint_snapshot()
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
	var scale_s: float = clampf(save.screen_shake_scale, 0.0, 1.0) if save != null else 1.0
	var scaled_mag: float = mag * scale_s
	shake_mag = maxf(shake_mag, scaled_mag)
	shake_dur = maxf(0.05, dur)
	shake_timer = maxf(shake_timer, dur)
	if save != null and save.vibrate_on and scaled_mag >= 5.0:
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
	fire_logic_event(str(s.get("uuid", "")), "on_break", {})

func find_trail_snapshot(target_t: float) -> Dictionary:
	for h_var in history_trail:
		var h: Dictionary = h_var
		if float(h["t"]) >= target_t:
			return h
	return {}

func try_trigger_golden_body(auto_saved: bool = false) -> bool:
	if shop != null and shop.trigger_golden_body(player):
		emit_sfx("shield_up")
		add_shock_ring(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#fde047"), 56.0, 0.34)
		spawn_particles(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#fde047"), 22)
		emit_toast(
			"★ 不灭金身自动护主 · 10秒无视陷阱怪物（落坑必死）！" if auto_saved else "★ 不灭金身已开启 (10s，落入深坑依然必死)！",
			"GOLDEN BODY AUTO-GUARD (10S · PITS KILL)!" if auto_saved else "GOLDEN BODY ACTIVE (10S · PITS STILL KILL)!",
			"ui_btn_gold", "#fde047"
		)
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

	if not is_pit_or_reset and bool(player.get("immortal_charm", false)):
		player["immortal_charm"] = false
		player["invuln_timer"] = 1.4
		emit_sfx("shield_parry")
		emit_toast("免死金牌已抵消致命事件！", "IMMORTAL CHARM CONSUMED!", "ui_btn_gold", "#fde047")
		hud_dirty = true
		return

	if not is_pit_or_reset and cause != "timer" and cause != "fake_flag" and cause != "shop" and int(player.get("gold_charges", 0)) > 0 and float(player.get("golden_timer", 0.0)) <= 0.0:
		if try_trigger_golden_body(true):
			return

	var shield_allowed: bool = (not ignore_shield) and TrapRegistry.can_shield_block(cause, "", str(player.get("shield_cache", "")))
	if not is_pit_or_reset and shield_allowed and bool(player.get("shield", false)):
		player["shield"] = false
		player["shield_cache"] = cause
		if bool(player.get("from_shop_shield", false)) and shop != null:
			player["from_shop_shield"] = false
			shop.mark_used_in_stage("aegis_shield")
		var assist_extra: float = 0.35 if (save != null and bool(save.assist_mode)) else 0.0
		player["invuln_timer"] = 1.25 + assist_extra
		player["vy"] = -250.0 * float(player["grav_dir"])
		spring_impulse_scale(1.28, 0.75)
		emit_sfx("shield_parry")
		trigger_hit_stop(0.048)
		trigger_shake(7.5, 0.24)
		shield_flash_timer = 0.28 * (save.screen_flash_scale if save != null else 1.0)
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
	var tot_d: int = save.record_death(lv_id, total_lv_deaths) if save != null else total_lv_deaths

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
	if event_bus != null:
		event_bus.emit_event("player_died", { "stage_id": lv_id, "cause": pending_death_cause, "attempt_deaths": attempt_deaths })
	hud_dirty = true

func trigger_fake_flag(flag_ent: Dictionary) -> void:
	if fake_phase > 0:
		return
	anti_troll_disqualified = true
	unlock_ach("fake_flag")
	var ftype: String = str(flag_ent.get("fake_type", ""))
	if ftype == "teleport_start" or ftype == "loop_back":
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
		emit_toast("回城假旗陷阱！已获得进度保留，快观察左侧线索！", "WARP TRAP FLAG! PROGRESS KEPT!", "ui_skull", "#c084fc")
		fire_logic_event(str(flag_ent.get("uuid", "")), "on_loop", {})
		return
	if ftype == "freeze_taunt":
		# Lv006: Non-lethal 0.9s celebration lock, drops flagpole as walkable lever!
		emit_sfx("fake_win")
		player["celebrate_freeze_timer"] = 0.90
		flag_ent["fake"] = false
		flag_ent["fallen_lever"] = true
		solids.append({
			"uuid": str(flag_ent.get("uuid", "")) + "_lever",
			"key": str(flag_ent.get("key", "")) + "_lever",
			"t": "sign_landed",
			"slope_ramp": true,
			"x": float(flag_ent["x"]) - 48.0,
			"y": float(flag_ent["y"]) + float(flag_ent["h"]) - 28.0,
			"w": 96.0, "h": 28.0,
			"x0": float(flag_ent["x"]) + 36.0, "y0": float(flag_ent["y"]) + float(flag_ent["h"]) - 4.0,
			"x1": float(flag_ent["x"]) - 48.0, "y1": float(flag_ent["y"]) + float(flag_ent["h"]) - 28.0,
			"revealed": true, "broken": false, "layer": active_layer
		})
		emit_toast("假庆祝锁定 · 快反向移动借倒下旗杆起跳！", "FAKE FANFARE · USE FALLEN POLE AS LEVER!", "flag_idle", "#fde047")
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
	if used_full_hint and hints_used_tier < 3:
		hints_used_tier = 3
	var anti_troll_ok: bool = not anti_troll_disqualified
	anti_troll_earned = anti_troll_ok
	var extra_meta: Dictionary = {
		"time_elapsed": maxf(0.1, time_elapsed),
		"hints_used_tier": hints_used_tier,
		"collected_shard": collected_shard_this_run,
		"anti_troll_earned": anti_troll_ok,
		"level_stars": int(lv_data.get("stars", 3))
	}
	var res: Dictionary = (
		save.mark_stage_cleared(lv_id, attempt_deaths, extra_meta)
		if save != null
		else { "stars": 5, "reward": 40, "first_time": true, "iq": 250, "medals": { "copper": true, "silver": true, "gold": true, "anti_troll": anti_troll_ok } }
	)
	if int(res["iq"]) <= 0:
		unlock_ach("zero_iq_clear")
	if int(res["iq"]) <= -500:
		unlock_ach("neg_500_clear")
	if time_elapsed <= 15.0:
		unlock_ach("speed_clear")
	if save != null:
		var retro: Array[String] = save.retro_sync_achievements()
		for aid in retro:
			ach_queue.append(aid)

	res["stage_id"] = lv_id
	res["attempt_deaths"] = attempt_deaths
	res["time_elapsed"] = maxf(0.1, time_elapsed)
	pending_win_result = res
	if event_bus != null:
		event_bus.emit_event("stage_cleared", res)
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
		if save != null:
			save.add_coins(5)
		emit_sfx("coin")
		spawn_particles(bx, by, Color("#facc15"), 12)
		emit_toast("获得金币 +5", "COINS +5", "ui_coin_hud", "#facc15")
	elif lt == "mech_ambush":
		emit_sfx("poison")
		var mk: String = "mech_hound" if (lv_id % 2) == 0 else "mech_spider"
		entities.append({
			"uuid": "spawn_mech_" + str(Time.get_ticks_msec()),
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
			"uuid": "spawn_imp_" + str(Time.get_ticks_msec()),
			"key": "spawn_imp_" + str(Time.get_ticks_msec()),
			"t": "enemy", "kind": "follower",
			"x": bx, "y": by - 52.0, "w": 0.92 * GridMath.TILE, "h": 1.02 * GridMath.TILE,
			"vx": 0.0, "vy": -220.0, "hp": 5, "max_hp": 5, "layer": -1
		})
	elif lt == "hazard":
		emit_sfx("poison")
		entities.append({
			"uuid": "drop_poop_" + str(Time.get_ticks_msec()),
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
		player["antidote_short_window"] = 4.2
		emit_sfx("coin")
		emit_toast("解毒圣体 · 触花盾/触红菇炼弹！", "ANTIDOTE AURA ACTIVE!", "item_antidote", "#4ade80")
	elif lt == "shield":
		player["shield"] = true
		player["shield_cache"] = ""
		emit_sfx("shield_up")
		emit_toast("能量护盾已展开！", "ENERGY SHIELD ACTIVE!", "icon_shield", "#00f5ff")
	elif lt == "bullet_up":
		player["bullet_up"] = true
		player["from_shop_bullet"] = false
		emit_sfx("coin")
		emit_toast("烈焰剑波强化 · 可破脆壁与折射追击！", "FLAME WAVE UPGRADED!", "icon_sword", "#ff2a85")
	elif lt == "spring_shoe" or lt == "double_jump":
		player["max_jumps"] = maxi(int(player["max_jumps"]), 2)
		player["jumps_left"] = int(player["max_jumps"])
		emit_sfx("coin")
		unlock_ach("multi_jumper")
		emit_toast("二段跳靴已装备！", "DOUBLE JUMP UNLOCKED!", "icon_spring", "#a855f7")
	elif lt == "triple_jump":
		player["max_jumps"] = maxi(int(player["max_jumps"]), 3)
		player["jumps_left"] = int(player["max_jumps"])
		emit_sfx("coin")
		unlock_ach("multi_jumper")
		emit_toast("三段跳已解锁 · 第3跳可下砸破砖！", "TRIPLE JUMP + GROUND POUND!", "icon_spring", "#a855f7")
	elif lt == "flight":
		player["has_flight"] = true
		player["wing_fuel"] = 100.0
		player["from_shop_flight"] = false
		emit_sfx("coin")
		unlock_ach("cyber_wings")
		emit_toast("赛博飞翼 · 连按跳跃滑翔 / 下键收翼！", "CYBER WINGS EQUIPPED!", "icon_wing", "#00f5ff")
	elif lt == "immortal_charm":
		player["immortal_charm"] = true
		emit_sfx("shield_up")
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
	if player.is_empty() or bool(player.get("dead", false)) or bool(player.get("sheathed", false)):
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
			"vx": float(dir) * 590.0, "vy": 0.0,
			"upgraded": true, "s3_wave": true, "reflected": false, "life": 0.52
		})

	melee_arcs.append({
		"x": (float(player["x"]) + float(player["w"]) - 8.0) if dir > 0 else (float(player["x"]) - 66.0),
		"y": float(player["y"]) - 16.0,
		"w": 74.0, "h": 68.0, "dir": dir, "crit": sword_up, "life": 0.19, "max_life": 0.19
	})

	var hit_any: bool = false

	# Parry enemy shots & convert Mole wrenches into valve-spinning friendly projectiles (Lv117!)
	for si in range(enemy_shots.size() - 1, -1, -1):
		var sh: Dictionary = enemy_shots[si]
		var sh_l: int = int(sh.get("layer", -1))
		if (sh_l < 0 or sh_l == active_layer) and GridMath.aabb_overlap(slash_box, Rect2(float(sh["x"]), float(sh["y"]), float(sh["w"]), float(sh["h"]))):
			spawn_particles(float(sh["x"]) + 6.0, float(sh["y"]) + 6.0, Color("#fde047"), 8)
			add_float_text(float(sh["x"]), float(sh["y"]) - 8.0, "PARRY!", "#fde047")
			if bool(sh.get("parry_wrench", false)):
				var up_parry: bool = not bool(player["on_ground"])
				bullets.append({
					"x": float(sh["x"]), "y": float(sh["y"]),
					"w": 20.0, "h": 20.0,
					"vx": float(dir) * (220.0 if up_parry else 440.0),
					"vy": -460.0 if up_parry else 40.0,
					"upgraded": true, "s3_wave": false, "reflected": true, "wrench_parried": true, "life": 2.2
				})
				emit_sfx("mirror_ping")
			enemy_shots.remove_at(si)
			hit_any = true

	# Lv150 Phase 3 & Throne Core slash checks
	if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv150_solaris":
		if GridMath.aabb_overlap(slash_box, world_state.shadow_rect):
			boss_sm.on_boss_hit(self, {}, 3, { "is_melee": true, "target_part": "shadow" })
			hit_any = true
		if bool(boss_sm.state["puzzle_flags"].get("throne_core_open", false)):
			boss_sm.on_boss_hit(self, {}, 34, { "is_melee": true, "target_part": "throne_core" })
			hit_any = true

	for s_var in solids:
		var s: Dictionary = s_var
		if not Sector1And2Mechanics.is_in_active_layer(s, active_layer):
			continue
		var st: String = str(s.get("t", ""))
		var sr: Rect2 = Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"]))
		if not GridMath.aabb_overlap(slash_box, sr):
			continue
		if st == "mirror" and bool(s.get("rotatable", false)):
			s["angle"] = fposmod(float(s.get("angle", 90.0)) + 45.0, 180.0)
			emit_sfx("mirror_ping")
			if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv080_fracture":
				boss_sm.on_puzzle_event(self, "mirror_inward", {})
			fire_logic_event(str(s.get("uuid", "")), "on_hit", { "angle": float(s["angle"]) })
			hit_any = true
		elif st == "fake_error" and not bool(s.get("broken", false)):
			var fem_s: String = str(s.get("mode", ""))
			if fem_s == "wire_pushable":
				s["pushable_block"] = true
				emit_sfx("node_on")
			elif fem_s != "walk_top" and fem_s != "rogue_walkable" and fem_s != "load_bearing":
				s["broken"] = true
				broken_solid_keys[str(s["key"])] = true
				if str(s.get("unlock_group", "")) != "":
					signal_groups[str(s["unlock_group"])] = true
				emit_sfx("fake_wall_shatter")
				fire_logic_event(str(s.get("uuid", "")), "on_break", {})
			else:
				s["hit_flash"] = 0.2
			hit_any = true
		elif (st == "fake_wall" or st == "fake_plat") and not bool(s.get("shattered", false)):
			shatter_fake_wall(s, dir)
			hit_any = true
		elif st == "destructible" and bool(s.get("bullet_break", false)) and not bool(s.get("mirror_break", false)) and not bool(s.get("broken", false)):
			s["broken"] = true
			broken_solid_keys[str(s["key"])] = true
			emit_sfx("boom")
			fire_logic_event(str(s.get("uuid", "")), "on_break", {})
			hit_any = true
		elif st == "qblock" or st == "invis":
			if not bool(s.get("revealed", false)):
				s["revealed"] = true
				revealed_invis_keys[str(s["key"])] = true
			fire_logic_event(str(s.get("uuid", "")), "on_hit", {})
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

	if Sector3Arcadia.disarm_or_damage_targets(self, slash_box, 6 if sword_up else 3, true, true):
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
		if et != "layer_term" and not Sector1And2Mechanics.is_in_active_layer(e, active_layer):
			continue
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x <= 0.0 or not GridMath.aabb_overlap(slash_box, er):
			continue

		if et == "cloud_knife" and bool(e.get("brittle_core", true)):
			hit_any = true
			emit_sfx("cloud_solid")
			solids.append({
				"uuid": str(e.get("uuid", "")), "key": str(e["key"]), "t": "cloud_plat", "sub_type": "solid",
				"x": float(e["x"]), "y": float(e["y"]), "base_y": float(e.get("base_y", e["y"])),
				"w": float(e["w"]), "h": float(e["h"]), "rule_swap": false, "step_cue_cd": 0.5,
				"move_dx_px": 0.0, "move_dy_px": 0.0, "revealed": true, "layer": int(e.get("layer", -1)), "broken": false
			})
			entities.remove_at(j)
		elif et == "flag" and bool(e.get("fake", false)):
			hit_any = true
			if str(e.get("fake_type", "")) == "tentacle_back":
				e["tentacle_disarmed"] = true
				e["fake"] = false
				emit_sfx("real_win")
				emit_toast("旗底拟态触手已斩除 · 从背面碰旗通关！", "TENTACLE DISARMED · TOUCH FLAG BASE!", "flag_win", "#4ade80")
			else:
				e["fake"] = false
				e["broken_pole"] = true
				if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv010_grad":
					boss_sm.on_puzzle_event(self, "fake_flag_knocked", {})
				fire_logic_event(str(e.get("uuid", "")), "on_hit", {})
				entities.remove_at(j)
		elif et == "flower" or et == "amanita":
			hit_any = true
			emit_sfx("enemy_kill")
			if save != null:
				save.add_coins(2)
			hud_dirty = true
			add_float_text(float(e["x"]), float(e["y"]) - 10.0, "SLASH +2G", "#fde047")
			if str(e.get("onKillGroup", "")) != "":
				signal_groups[str(e["onKillGroup"])] = true
			fire_logic_event(str(e.get("uuid", "")), "on_kill", {})
			if needs_alchemy_preserve:
				_record_consumed_alchemy(e)
			entities.remove_at(j)
		elif et == "enemy":
			hit_any = true
			if str(e.get("kind", "")) == "boss":
				if boss_sm != null and bool(boss_sm.state.get("active", false)):
					boss_sm.on_boss_hit(self, e, 3, { "is_melee": true })
				else:
					e["stun_timer"] = 2.8
					add_float_text(float(e["x"]), float(e["y"]) - 10.0, "STUN!", "#fde047")
			elif bool(e.get("tracks_shadow", false)):
				# Lv016: Direct hit splits/jolts shadow follower rather than killing it!
				emit_sfx("armor_clang")
				add_float_text(float(e["x"]), float(e["y"]) - 10.0, "IMMORTAL · LURE SHADOW!", "#c084fc")
			else:
				emit_sfx("enemy_kill")
				fire_logic_event(str(e.get("uuid", "")), "on_kill", {})
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
			fire_logic_event(str(e.get("uuid", "")), "on_hit", {})
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
		elif et in ["signal_node", "polarity_node", "time_node", "beat_clock", "layer_term", "root_term", "betray_spring", "curse_totem", "fake_save", "trojan_heart", "spotlight"]:
			var fb: Dictionary = { "x": float(e["x"]) + 2.0, "y": float(e["y"]) + 2.0, "w": 12.0, "h": 12.0, "vx": float(dir) * 400.0, "upgraded": true, "reflected": false, "life": 0.2 }
			Sector1And2Mechanics.handle_bullet_hit(self, fb)
			hit_any = true

	emit_sfx("melee_hit" if hit_any else "melee_slash")

func step_frame(raw_dt: float, inp: Dictionary) -> void:
	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - raw_dt)
	if shield_flash_timer > 0.0:
		shield_flash_timer = maxf(0.0, shield_flash_timer - raw_dt)

	if event_bus != null:
		event_bus.step_captions(raw_dt)
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
			step_inp["sheathe_pressed"] = false
			step_inp["sheathe_toggle"] = false
			step_inp["interact_pressed"] = false
			step_inp["pick_place_pressed"] = false
			step_inp["ground_pound_pressed"] = false
		_step_physics(sub_dt, step_inp)
		if player.is_empty() or bool(player.get("dead", false)) or not pending_win_result.is_empty():
			break
	anti_troll_earned = not anti_troll_disqualified
	if not player.is_empty():
		sword_sheathed = bool(player.get("sheathed", false))
		player["sword_sheathed"] = sword_sheathed
		player["flight_energy"] = float(player.get("wing_fuel", 100.0))
		player["coin_weight"] = int(player.get("carried_coins", 0))
		player["plant_cure_window"] = float(player.get("antidote_short_window", 0.0))
		var props_m: Dictionary = lv_data.get("props", {}) if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY else {}
		mirror_input_active = bool(props_m.get("mirrorInput", false)) or bool(player.get("in_curse_mirror", false)) or float(player.get("reverse_curse_timer", 0.0)) > 0.0

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
	var props: Dictionary = lv_data.get("props", {}) if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY else {}
	var loop_mul: float = (1.0 + float(loop_progress - 1) * 0.14) if int(props.get("loopsRequired", 0)) > 0 else 1.0
	world_state.global_frozen = world_frozen
	world_state.global_slow = world_slow
	var world_dt: float = 0.0 if world_frozen else (dt * 0.38 if world_slow else dt * loop_mul)
	var mech_dt: float = world_dt * absf(world_state.mech_time_scale)
	var enemy_dt: float = world_dt * world_state.enemy_time_scale

	time_elapsed += dt
	if pipe_warp_cd > 0.0:
		pipe_warp_cd = maxf(0.0, pipe_warp_cd - dt)

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
		if float(s.get("step_cue_cd", 0.0)) > 0.0:
			s["step_cue_cd"] = maxf(0.0, float(s["step_cue_cd"]) - dt)

	for e_var in entities:
		var e: Dictionary = e_var
		if float(e.get("spring_anim", 0.0)) > 0.0:
			e["spring_anim"] = maxf(0.0, float(e["spring_anim"]) - dt * 2.4)
		if float(e.get("recoil", 0.0)) > 0.0:
			e["recoil"] = maxf(0.0, float(e["recoil"]) - dt * 5.0)
		if float(e.get("cooldown", 0.0)) > 0.0:
			e["cooldown"] = maxf(0.0, float(e["cooldown"]) - dt)
		if float(e.get("pickup_cd", 0.0)) > 0.0:
			e["pickup_cd"] = maxf(0.0, float(e["pickup_cd"]) - dt)
		if float(e.get("echo_cd", 0.0)) > 0.0:
			e["echo_cd"] = maxf(0.0, float(e["echo_cd"]) - dt)

	if bool(props.get("ruleShuffle", false)):
		rule_timer += dt
		if rule_timer >= 5.0:
			rule_timer = 0.0
			rule_phase_b = not rule_phase_b
			emit_sfx("clock_high" if rule_phase_b else "clock_low")
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
				"uuid": "rain_poop_" + str(Time.get_ticks_msec()),
				"key": "rain_poop_" + str(Time.get_ticks_msec()),
				"t": "poop", "x": drop_x, "y": float(player["y"]) - 280.0,
				"w": 0.78 * GridMath.TILE, "h": 0.82 * GridMath.TILE,
				"falling_poop": true, "vy": 230.0, "layer": -1
			})

	if timer_left >= 0.0 and not world_frozen:
		timer_left -= dt * timer_rate * world_state.timer_rate * (0.4 if world_slow else 1.0)
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
	if float(player.get("spring_trail_timer", 0.0)) > 0.0:
		player["spring_trail_timer"] = maxf(0.0, float(player["spring_trail_timer"]) - dt)
	player["afterimage_timer"] = float(player.get("afterimage_timer", 0.0)) - dt
	if float(player["afterimage_timer"]) <= 0.0 and (float(player.get("spring_trail_timer", 0.0)) > 0.0 or bool(player.get("has_flight", false)) or absf(float(player["vy"])) > 430.0 or float(player["invuln_timer"]) > 0.4 or float(player["grav_dir"]) < 0.0):
		player["afterimage_timer"] = 0.038 if float(player.get("spring_trail_timer", 0.0)) > 0.0 else 0.055
		var tr_c: Color = Color("#facc15") if float(player.get("spring_trail_timer", 0.0)) > 0.0 else (Color("#c084fc") if float(player["grav_dir"]) < 0.0 else (Color("#4ade80") if float(player["invuln_timer"]) > 0.0 else Color("#00f5ff")))
		add_afterimage(tr_c)
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

	if float(player.get("heavy_curse_timer", 0.0)) > 0.0:
		player["heavy_curse_timer"] = maxf(0.0, float(player["heavy_curse_timer"]) - dt)
	if float(player.get("reverse_curse_timer", 0.0)) > 0.0:
		player["reverse_curse_timer"] = maxf(0.0, float(player["reverse_curse_timer"]) - dt)
	player["in_curse_mirror"] = false
	player["in_curse_jump_shot"] = false
	var p_center: Vector2 = Vector2(float(player["x"]) + 14.0, float(player["y"]) + 21.0)
	for ct_var in entities:
		var ct: Dictionary = ct_var
		if str(ct.get("t", "")) == "curse_totem" and float(ct.get("disable_timer", 0.0)) <= 0.0 and Sector1And2Mechanics.is_in_active_layer(ct, active_layer):
			var ctc: Vector2 = Vector2(float(ct["x"]) + float(ct["w"]) * 0.5, float(ct["y"]) + float(ct["h"]) * 0.5)
			if p_center.distance_to(ctc) <= float(ct.get("radius_px", 250.0)):
				if str(ct.get("curse_type", "mirror_lr")) == "anti_jump_shoot":
					player["in_curse_jump_shot"] = true
				elif str(ct.get("curse_type", "")) != "auto_fire":
					player["in_curse_mirror"] = true

	# Delegate player movement, coyote/buffer, double-jump inertia reversal, 3rd-jump ground pound, sheathe, item place/throw, and shooting to PlayerController!
	PlayerController.step_movement_and_actions(self, player, dt, inp, props, loop_mul)
	if bool(player.get("dead", false)):
		return

	if light_burst_timer > 0.0:
		light_burst_timer = maxf(0.0, light_burst_timer - dt)

	# Moving solids & 4-state cloud platforms
	move_time += mech_dt * (1.0 if world_state.mech_time_scale >= 0.0 else -1.0)
	for s_m_var in solids:
		var s_m: Dictionary = s_m_var
		if bool(s_m.get("broken", false)):
			if float(s_m.get("respawn_timer", 0.0)) > 0.0 and str(s_m.get("t", "")) == "cloud_plat":
				s_m["respawn_timer"] = float(s_m["respawn_timer"]) - world_dt
				if float(s_m["respawn_timer"]) <= 0.0:
					s_m["broken"] = false
			continue
		if str(s_m.get("t", "")) == "cloud_plat":
			var prev_cy: float = float(s_m["y"])
			s_m["y"] = float(s_m["base_y"]) + sin(time_elapsed * 2.4 + float(s_m["x"]) * 0.03) * 3.5
			var on_cloud: bool = float(player["grav_dir"]) > 0.0 and bool(player["on_ground"]) and float(player["x"]) + float(player["w"]) > float(s_m["x"]) + 2.0 and float(player["x"]) < float(s_m["x"]) + float(s_m["w"]) - 2.0 and absf((float(player["y"]) + float(player["h"])) - prev_cy) <= 9.0
			if on_cloud:
				var csub: String = str(s_m.get("sub_type", "solid"))
				if csub == "hollow":
					s_m["broken"] = true
					s_m["respawn_timer"] = 2.4
					emit_sfx("cloud_hollow")
					continue
				if csub == "bounce":
					player["vy"] = -720.0
					player["on_ground"] = false
					player["spring_trail_timer"] = 0.42
					emit_sfx("cloud_bounce")
					continue
				player["y"] = float(player["y"]) + (float(s_m["y"]) - prev_cy)
				if float(s_m.get("step_cue_cd", 0.0)) <= 0.0:
					s_m["step_cue_cd"] = 0.9
					emit_sfx("cloud_solid")
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

	Sector1And2Mechanics.step_pre_move(self, dt, mech_dt)
	Sector3Arcadia.step_pre_move(self, dt, mech_dt)
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
		if bool(s_x.get("slope_ramp", false)):
			continue
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
	var landed_solid_ref: Dictionary = {}

	for s_y_var in active_solids:
		var s_y: Dictionary = s_y_var
		if bool(s_y.get("slope_ramp", false)) and float(player["grav_dir"]) > 0.0 and float(player["vy"]) >= -20.0:
			var sl_res: Dictionary = GridMath.collide_aabb_with_slope(
				p_rect_y,
				float(s_y.get("x0", s_y["x"])),
				float(s_y.get("y0", float(s_y["y"]) + float(s_y["h"]))),
				float(s_y.get("x1", float(s_y["x"]) + float(s_y["w"]))),
				float(s_y.get("y1", s_y["y"])),
				16.0
			)
			if bool(sl_res.get("hit", false)):
				player["y"] = float(sl_res["surface_y"]) - float(player["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
				p_rect_y.position.y = float(player["y"])
				landed_solid_ref = s_y
			continue

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
				fire_logic_event(str(s_y.get("uuid", "")), "on_hit", {})
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
				landed_solid_ref = s_y
				emit_sfx("block")
				fire_logic_event(str(s_y.get("uuid", "")), "on_step", {})
			continue

		if float(player["grav_dir"]) > 0.0:
			if float(player["vy"]) >= 0.0 and prev_y + float(player["h"]) <= float(s_y["y"]) + 16.0:
				player["y"] = float(s_y["y"]) - float(player["h"])
				if not bool(player["was_on_ground"]) and pre_land_vy > 210.0:
					spring_impulse_scale(1.22, 0.80)
				player["vy"] = 0.0
				player["on_ground"] = true
				p_rect_y.position.y = float(player["y"])
				landed_solid_ref = s_y
				world_state.record_surface_material(str(s_y.get("skin", st_y)))
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
					fire_logic_event(str(s_y.get("uuid", "")), "on_hit", {})
					if st_y == "s3_drop_block" and bool(s_y.get("anti_newton", false)):
						s_y["drop_state"] = "fall"
						s_y["vy"] = -480.0
						emit_sfx("spring")
					elif st_y == "qblock" and not bool(s_y.get("used", false)):
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
				landed_solid_ref = s_y
				world_state.record_surface_material(str(s_y.get("skin", st_y)))
			elif float(player["vy"]) > 0.0 and prev_y + float(player["h"]) <= float(s_y["y"]) + 16.0:
				player["y"] = float(s_y["y"]) - float(player["h"])
				player["vy"] = -30.0
				p_rect_y.position.y = float(player["y"])

	if bool(player["on_ground"]) and bool(player.get("ground_pounding", false)):
		PlayerController.on_ground_pound_land(self, player, landed_solid_ref)

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
	var min_by: float = float(bounds_d.get("minY", -2.0))
	var max_by: float = float(bounds_d.get("maxY", 15.0))
	var abyss_bottom_py: float = maxf(GridMath.WORLD_ORIGIN_Y + 95.0, GridMath.gy_to_py(min_by, 0.0) + 95.0)
	var abyss_top_py: float = minf(GridMath.WORLD_ORIGIN_Y - 13.0 * GridMath.TILE, GridMath.gy_to_py(max_by, 0.0) - 96.0)
	if float(player["y"]) > abyss_bottom_py:
		kill_player(true, "abyss")
		return
	if float(player["grav_dir"]) < 0.0 and float(player["y"]) < abyss_top_py:
		kill_player(true, "abyss")
		return

	if time_elapsed - last_trail_record_t >= (1.0 / 90.0):
		last_trail_record_t = time_elapsed
		history_trail.append({
			"x": float(player["x"]), "y": float(player["y"]),
			"facing": int(player["facing"]), "on_ground": bool(player["on_ground"]),
			"sheathed": bool(player.get("sheathed", false)),
			"action": str(player.get("last_action_tag", "idle")),
			"layer": active_layer, "t": time_elapsed
		})
		while history_trail.size() > 2 and float(history_trail[0]["t"]) < time_elapsed - 9.5:
			history_trail.pop_front()

	shadow_clone = {}
	if (bool(props.get("shadowClone", false)) or bool(props.get("shadowChaser", false))) and time_elapsed >= 1.8:
		var snap_sc: Dictionary = find_trail_snapshot(time_elapsed - 1.8)
		if not snap_sc.is_empty():
			shadow_clone = {
				"active": true,
				"x": float(snap_sc["x"]), "y": float(snap_sc["y"]),
				"w": float(player["w"]), "h": float(player["h"]),
				"facing": int(snap_sc["facing"]),
				"sheathed": bool(snap_sc.get("sheathed", false))
			}
			# Lv129: If player sheathes sword, passing through shadow queue is non-hostile!
			if not bool(player.get("sheathed", false)) and GridMath.aabb_overlap(p_rect, Rect2(float(shadow_clone["x"]) + 4.0, float(shadow_clone["y"]) + 4.0, float(shadow_clone["w"]) - 8.0, float(shadow_clone["h"]) - 8.0)):
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

	_step_core_entities(dt, enemy_dt, prev_y, active_solids, inp)
	if bool(player.get("dead", false)) or not pending_win_result.is_empty():
		return

	Sector1And2Mechanics.step_post_move(self, dt, enemy_dt)
	Sector3Arcadia.step_post_move(self, dt, enemy_dt)
	boss_sm.step_boss(self, dt, enemy_dt)
	if bool(player.get("dead", false)) or not pending_win_result.is_empty():
		return

	_step_enemy_shots(dt, world_dt * world_state.proj_time_scale, active_solids)
	if bool(player.get("dead", false)):
		return

	update_camera(dt)

func _collect_active_solids() -> Array:
	var out: Array = []
	for s_var in solids:
		var s: Dictionary = s_var
		if not Sector3Arcadia.is_solid_collidable(s, s3_sundial_phase):
			continue
		if not Sector1And2Mechanics.is_solid_collidable(s, active_layer, signal_groups):
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
			var is_slope: bool = str(e.get("mode", "")) == "fall_slope"
			out.append({
				"uuid": str(e.get("uuid", e["key"])),
				"key": str(e["key"]),
				"t": "sign_landed",
				"slope_ramp": is_slope,
				"x": float(e["x"]),
				"y": float(e["y"]) + 8.0,
				"w": float(e["w"]),
				"h": float(e["h"]) - 8.0,
				"x0": float(e["x"]),
				"y0": float(e["y"]) + float(e["h"]),
				"x1": float(e["x"]) + float(e["w"]),
				"y1": float(e["y"]) + 10.0,
				"revealed": true
			})
	return out

func _step_bullets(dt: float, active_solids: Array, p_rect: Rect2) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["x"] = float(b["x"]) + float(b.get("vx", 0.0)) * dt
		b["y"] = float(b["y"]) + float(b.get("vy", 0.0)) * dt
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			bullets.remove_at(i)
			continue
		var b_rect: Rect2 = Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]))
		if bool(b.get("reflected", false)) and not bool(b.get("wrench_parried", false)) and GridMath.aabb_overlap(b_rect, p_rect):
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
			if (str(fl.get("t", "")) == "flower" or str(fl.get("t", "")) == "amanita") and Sector1And2Mechanics.is_in_active_layer(fl, active_layer):
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
		if Sector3Arcadia.disarm_or_damage_targets(self, b_rect, b_dmg, is_wave, bool(b.get("upgraded", false)) or is_wave):
			if not is_wave:
				bullets.remove_at(i)
				continue

		if Sector1And2Mechanics.handle_bullet_hit(self, b):
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
					if bool(s.get("rotatable", false)):
						var new_vel: Vector2 = GridMath.reflect_by_mirror_angle(Vector2(float(b.get("vx", 0.0)), float(b.get("vy", 0.0))), float(s.get("angle", 45.0)), 1.12)
						b["vx"] = new_vel.x
						b["vy"] = new_vel.y
					else:
						b["vx"] = -float(b["vx"]) * 1.18
					b["reflected"] = true
					b["bounce_count"] = int(b.get("bounce_count", 0)) + 1
					if bool(b.get("vengeful", false)):
						var dy_orig: float = float(b.get("origin_y", b["y"])) - float(b["y"])
						b["vy"] = clampf(dy_orig * 1.4, -180.0, 180.0)
					b["x"] = float(b["x"]) + (12.0 if float(b["vx"]) >= 0.0 else -12.0)
					b["y"] = float(b["y"]) + (8.0 if float(b.get("vy", 0.0)) > 20.0 else (-8.0 if float(b.get("vy", 0.0)) < -20.0 else 0.0))
					emit_sfx("mirror_ping")
					unlock_ach("mirror_bounce")
				elif bool(b.get("wrench_parried", false)) and int(b.get("bounce_count", 0)) < 2:
					b["vy"] = -absf(float(b.get("vy", -280.0))) * 0.85
					b["bounce_count"] = int(b.get("bounce_count", 0)) + 1
					emit_sfx("mirror_ping")
				elif st == "destructible" and bool(s.get("bullet_break", false)):
					if bool(s.get("mirror_break", false)):
						if bool(b.get("reflected", false)):
							s["broken"] = true
							broken_solid_keys[str(s["key"])] = true
							emit_sfx("boom")
							unlock_ach("mirror_bankshot")
							fire_logic_event(str(s.get("uuid", "")), "on_break", {})
						else:
							emit_sfx("block")
						removed = true
					elif bool(b.get("upgraded", false)) or bool(b.get("reflected", false)):
						s["broken"] = true
						broken_solid_keys[str(s["key"])] = true
						emit_sfx("boom")
						fire_logic_event(str(s.get("uuid", "")), "on_break", {})
						if int(b.get("pierce_left", 0)) > 0:
							b["pierce_left"] = int(b["pierce_left"]) - 1
						else:
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
			if et == "cloud_knife" and bool(e.get("brittle_core", true)):
				removed = true
				emit_sfx("cloud_solid")
				solids.append({
					"uuid": str(e.get("uuid", "")), "key": str(e["key"]), "t": "cloud_plat", "sub_type": "solid",
					"x": float(e["x"]), "y": float(e["y"]), "base_y": float(e.get("base_y", e["y"])),
					"w": float(e["w"]), "h": float(e["h"]), "rule_swap": false, "step_cue_cd": 0.5,
					"move_dx_px": 0.0, "move_dy_px": 0.0, "revealed": true, "layer": int(e.get("layer", -1)), "broken": false
				})
				entities.remove_at(j)
				break
			elif et == "clock":
				e["hp"] = int(e.get("hp", 1)) - 1
				removed = true
				if int(e["hp"]) <= 0:
					var c_scope: String = str(e.get("scope", ""))
					var eff: String = str(e.get("effect", ""))
					if c_scope != "":
						world_state.apply_clock_scope(c_scope, true, float(e.get("factor", 1.8)), str(e.get("group", "")))
						emit_sfx("clock_low" if c_scope in ["mech_freeze", "rewind_plat"] else ("clock_high" if c_scope in ["enemy_speed", "time_loan"] else "clock_gear"))
						if c_scope == "mech_freeze":
							plat_freeze_timer = 5.5
						elif c_scope == "timer_only":
							timer_rate = 0.0
					elif e.has("s3AddSec") and timer_left >= 0.0:
						timer_left += float(e["s3AddSec"])
						emit_sfx("clock_high")
					elif eff == "stop_timer":
						timer_left = -1.0
						emit_sfx("clock_gear")
						unlock_ach("clock_stopper")
					elif eff == "freeze_world":
						world_frozen = true
						timer_left = -1.0
						emit_sfx("clock_low")
						unlock_ach("clock_stopper")
					elif eff == "slow_world":
						world_slow = true
						emit_sfx("clock_low")
						unlock_ach("clock_stopper")
					elif eff == "speedup":
						timer_rate = 4.5
						emit_sfx("clock_high")
					elif eff == "stun_boss":
						for m_var in entities:
							var m: Dictionary = m_var
							if str(m.get("t", "")) == "enemy" and str(m.get("kind", "")) == "boss":
								m["stun_timer"] = 2.8
						emit_sfx("clock_gear")
						unlock_ach("clock_stopper")
					elif eff == "light_burst":
						light_burst_timer = 4.8
						emit_sfx("clock_high")
						unlock_ach("light_keeper")
					else:
						emit_sfx("boom")
					fire_logic_event(str(e.get("uuid", "")), "on_hit", {})
					entities.remove_at(j)
				break
			elif et == "enemy":
				if bool(e.get("is_phasing", false)):
					continue
				removed = true
				var ek: String = str(e.get("kind", "follower"))
				if bool(e.get("tracks_shadow", false)):
					emit_sfx("armor_clang")
				elif ek == "flying":
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
					if ek == "boss" and boss_sm != null and bool(boss_sm.state.get("active", false)):
						boss_sm.on_boss_hit(self, e, 1, { "reflected": bool(b.get("reflected", false)) })
					emit_sfx("armor_clang")
				break
		if removed:
			bullets.remove_at(i)

func explode_at(cx: float, cy: float, radius: float, trap_self: bool) -> void:
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
				fire_logic_event(str(s.get("uuid", "")), "on_break", {})
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
				if st == "mirror" and bool(s.get("reflects_bomb", false)):
					var r_vel: Vector2 = GridMath.reflect_by_mirror_angle(Vector2(float(bm["vx"]), float(bm["vy"])), float(s.get("angle", 45.0)), 1.15)
					bm["vx"] = r_vel.x
					bm["vy"] = minf(-180.0, r_vel.y)
					bm["fuse"] = maxf(float(bm["fuse"]), 0.45)
					emit_sfx("mirror_ping")
				else:
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
	var props: Dictionary = lv_data.get("props", {}) if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY else {}
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
					e["cd"] = float(e.get("period", e.get("interval", 2.5)))
					e["recoil"] = 1.0
					var ldir: float = float(e.get("dir", 1.0))
					var mx: float = float(e["x"]) + (38.0 if ldir > 0.0 else -58.0)
					var mtypes: Array = e.get("missileTypes", []) if typeof(e.get("missileTypes", null)) == TYPE_ARRAY else []
					var mtype: String = "cooled_rideable"
					if not mtypes.is_empty():
						var sidx: int = int(e.get("shot_idx", 0))
						mtype = str(mtypes[sidx % mtypes.size()])
						e["shot_idx"] = sidx + 1
					entities.append({
						"uuid": "msl_" + str(Time.get_ticks_msec()) + "_" + str(i),
						"key": "msl_" + str(Time.get_ticks_msec()) + "_" + str(i),
						"t": "missile",
						"missile_type": mtype,
						"ride_timer": 0.0,
						"x": mx, "spawn_x": mx, "y": float(e["y"]) + 8.0,
						"w": 68.0, "h": 26.0, "dir": ldir,
						"speed": float(e.get("speed", 3.6)) * GridMath.TILE,
						"layer": -1
					})
			continue

		if et == "missile":
			var mdir: float = float(e.get("dir", 1.0))
			var mtype_m: String = str(e.get("missile_type", "cooled_rideable"))
			var mdx: float = mdir * float(e["speed"]) * world_dt
			e["x"] = float(e["x"]) + mdx
			e["vx"] = mdir * float(e["speed"])
			if mtype_m == "homing_bait" and not world_frozen:
				var dy_hm: float = (float(player["y"]) + 10.0) - float(e["y"])
				e["y"] = float(e["y"]) + clampf(dy_hm, -95.0 * world_dt, 95.0 * world_dt)
			if not world_frozen and particles.size() < 240:
				e["exhaust_timer"] = float(e.get("exhaust_timer", 0.0)) - world_dt
				if float(e["exhaust_timer"]) <= 0.0:
					e["exhaust_timer"] = 0.045
					var tail_col: Color = Color("#38bdf8") if mtype_m == "cooled_rideable" else (Color("#fb7185") if mtype_m == "homing_bait" else Color("#fb923c"))
					particles.append({
						"x": (float(e["x"]) - 2.0) if mdir > 0.0 else (float(e["x"]) + float(e["w"]) + 2.0),
						"y": float(e["y"]) + float(e["h"]) * 0.5 + (randf() - 0.5) * 6.0,
						"vx": -mdir * (45.0 + randf() * 45.0),
						"vy": (randf() - 0.5) * 18.0,
						"grav": -20.0,
						"life": 0.20, "max_life": 0.20,
						"color": tail_col,
						"size": 3.2
					})
			if float(e["x"]) < GridMath.gx_to_px(float(bounds_d.get("minX", -2.0))) - 180.0 or float(e["x"]) > GridMath.gx_to_px(float(bounds_d.get("maxX", 60.0))) + 180.0:
				entities.remove_at(i)
				continue
			if absf(float(e["x"]) - float(e.get("spawn_x", e["x"]))) > 76.0:
				var nose_wall: Rect2 = Rect2((float(e["x"]) + float(e["w"]) - 8.0) if mdir > 0.0 else float(e["x"]), float(e["y"]) + 5.0, 8.0, float(e["h"]) - 10.0)
				var hit_cliff: bool = false
				for sw_var in active_solids:
					var sw: Dictionary = sw_var
					var sw_t: String = str(sw.get("t", ""))
					if (sw_t == "solid" or sw_t == "destructible" or sw_t == "glass_panel") and float(sw["h"]) >= GridMath.TILE * 0.8 and GridMath.aabb_overlap(nose_wall, Rect2(float(sw["x"]), float(sw["y"]), float(sw["w"]), float(sw["h"]))):
						hit_cliff = true
						if sw_t == "destructible" or sw_t == "glass_panel":
							sw["broken"] = true
							broken_solid_keys[str(sw["key"])] = true
							if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv010_grad":
								boss_sm.on_puzzle_event(self, "glass_shattered", {})
							fire_logic_event(str(sw.get("uuid", "")), "on_break", {})
						break
				if hit_cliff:
					spawn_particles((float(e["x"]) + float(e["w"])) if mdir > 0.0 else float(e["x"]), float(e["y"]) + float(e["h"]) * 0.5, Color("#fb923c"), 10, 0.75)
					entities.remove_at(i)
					continue
			var rider_box: Rect2 = Rect2(float(e["x"]) + 4.0, float(e["y"]) - 8.0, float(e["w"]) - 10.0, 16.0)
			var nose_box: Rect2 = Rect2((float(e["x"]) + float(e["w"]) - 13.0) if float(e["dir"]) > 0.0 else float(e["x"]), float(e["y"]) + 5.0, 13.0, float(e["h"]) - 10.0)
			var foot_box: Rect2 = Rect2(float(player["x"]), float(player["y"]) + float(player["h"]) - 7.0, float(player["w"]), 12.0)
			var can_ride: bool = (mtype_m != "cracked") or (float(e.get("ride_timer", 0.0)) < 0.55)
			if can_ride and float(player["grav_dir"]) > 0.0 and float(player["vy"]) >= -25.0 and prev_y + float(player["h"]) <= float(e["y"]) + 15.0 and GridMath.aabb_overlap(foot_box, rider_box):
				e["ride_timer"] = float(e.get("ride_timer", 0.0)) + dt
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
			var fsub: String = str(e.get("sub_type", ""))
			if fsub == "magnetic" and bool(player.get("shield", false)):
				# Lv011: Magnetic flower pulls shielded player unless shield is unequipped!
				var fdx: float = (float(e["x"]) + 18.0) - (float(player["x"]) + 14.0)
				if absf(fdx) < 190.0:
					player["x"] = float(player["x"]) + signf(fdx) * 95.0 * world_dt
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
			if (smode == "fall" or smode == "fall_slope") and fs == 0:
				if absf((float(player["x"]) + 14.0) - (float(e["x"]) + float(e["w"]) * 0.5)) < 54.0 and float(player["y"]) >= float(e["y"]) - 24.0:
					e["fall_state"] = 1
					e["vy"] = 60.0
					emit_sfx("shoot")
			elif fs == 1:
				e["vy"] = float(e["vy"]) + 1150.0 * world_dt
				e["y"] = float(e["y"]) + float(e["vy"]) * world_dt
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 6.0, float(e["y"]) + 6.0, float(e["w"]) - 12.0, float(e["h"]) - 12.0)):
					kill_player(false, "sign")
					return
				for ss_var in active_solids:
					var ss: Dictionary = ss_var
					if str(ss.get("key", "")) != str(e["key"]) and str(ss.get("t", "")) != "invis":
						if GridMath.aabb_overlap(Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"])), Rect2(float(ss["x"]), float(ss["y"]), float(ss["w"]), float(ss["h"]))):
							e["y"] = float(ss["y"]) - float(e["h"])
							e["fall_state"] = 2
							emit_sfx("block")
							fire_logic_event(str(e.get("uuid", "")), "on_land", {})
							break
				if float(e["y"]) > GridMath.WORLD_ORIGIN_Y + 80.0:
					e["x"] = float(e["spawn_x"])
					e["y"] = float(e["spawn_y"])
					e["vy"] = 0.0
					e["fall_state"] = 0
			elif smode == "wire_shock":
				if bool(player["on_ground"]) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) - 6.0, float(e["y"]) + float(e["h"]) - 18.0, float(e["w"]) + 12.0, 22.0)):
					e["wire_timer"] = float(e.get("wire_timer", 0.0)) + dt
					if float(e["wire_timer"]) >= 0.35:
						kill_player(false, "arc")
						return
				else:
					e["wire_timer"] = 0.0
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

		if not Sector1And2Mechanics.is_in_active_layer(e, active_layer) and et != "checkpoint":
			continue
		if et == "hourglass" and float(e.get("cooldown", 0.0)) > 0.0:
			continue

		var ew: float = float(e.get("w", 0.0))
		var eh: float = float(e.get("h", 0.0))
		if ew <= 0.0:
			continue

		# Pipe proximity echo cue (Lv012: single vs double echo before entering!)
		if et == "pipe" and float(e.get("echo_cd", 0.0)) <= 0.0:
			if p_rect.get_center().distance_to(Vector2(float(e["x"]) + ew * 0.5, float(e["y"]) + eh * 0.5)) < 78.0:
				e["echo_cd"] = 2.4
				var is_loop_p: bool = bool(e.get("loopPipe", false)) and not bool(signal_groups.get(str(e.get("rerouteGroup", "")), false))
				emit_sfx("pipe_echo_double" if is_loop_p else "pipe_echo_single")

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
			var fl_sub: String = str(e.get("sub_type", ""))
			if fl_sub == "white_cure_aggro" and float(player["poison_timer"]) > 0.0:
				continue
			if float(player["antidote_window"]) > 0.0:
				player["shield"] = true
				player["shield_cache"] = ""
				emit_sfx("shield_up")
				_record_consumed_alchemy(e)
				entities.remove_at(i)
				hud_dirty = true
			elif float(player["poison_timer"]) > 0.0:
				if fl_sub == "spore_giver":
					player["has_spore_key"] = true
					emit_sfx("coin")
					emit_toast("毒态共鸣骷髅花 · 吐出【孢子通行钥匙】！", "TOXIN RESONANCE · SPORE KEY OBTAINED!", "v2_spore_key", "#4ade80")
					_record_consumed_alchemy(e)
					entities.remove_at(i)
				else:
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
			var pmode: String = str(e.get("sub_type", e.get("mode", "lethal")))
			if pmode == "slip_boost":
				player["vx"] = float(player["facing"]) * 340.0
				emit_sfx("spring")
			elif pmode == "spring_shell":
				player["vy"] = -520.0
				player["on_ground"] = false
				solids.append({
					"uuid": str(e["key"]) + "_shell", "key": str(e["key"]) + "_shell",
					"t": "solid", "x": float(e["x"]), "y": float(e["y"]),
					"base_x": float(e["x"]), "base_y": float(e["y"]),
					"w": 42.0, "h": 38.0, "revealed": true, "broken": false, "layer": active_layer
				})
				entities.remove_at(i)
				emit_sfx("spring")
			elif pmode == "sticky_push":
				e["x"] = float(e["x"]) + signf(float(player["vx"])) * 95.0 * dt
			else:
				kill_player(true, "poop")
				return
		elif et == "cloud_knife":
			if not (bool(e.get("rule_swap", false)) and rule_phase_b):
				emit_sfx("cloud_blade")
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
				player["antidote_window"] = 6.5
				player["antidote_short_window"] = 3.2
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
			if float(player["grav_dir"]) > 0.0 and float(player["vy"]) >= -25.0 and float(e.get("spring_anim", 0.0)) < 0.86:
				player["y"] = minf(float(player["y"]), float(e["y"]) - float(player["h"]) + 10.0)
				player["vy"] = -865.0
				player["on_ground"] = false
				player["coyote"] = 0.0
				player["jumps_left"] = int(player["max_jumps"])
				player["spring_trail_timer"] = 0.48
				e["spring_anim"] = 1.0
				spring_impulse_scale(0.68, 1.38)
				add_shock_ring(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + 6.0, Color("#fde047"), 42.0, 0.26)
				spawn_particles(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + 6.0, Color("#fde047"), 14, 1.05)
				add_afterimage(Color("#facc15"))
				emit_sfx("spring")
		elif et == "gravity_pad":
			var new_gvec: Vector2 = world_state.apply_gravity_pad(e)
			var gdir: float = -1.0 if new_gvec.y < 0.0 else float(e.get("dir", -1.0))
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
					anti_troll_disqualified = true
					emit_sfx("fake_buzz")
					entities.append({
						"uuid": "cp_tanuki_" + str(Time.get_ticks_msec()),
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
			emit_sfx("clock_high")
			entities.remove_at(i)
		elif et == "coin":
			if float(e.get("pickup_cd", 0.0)) > 0.0:
				continue
			if save != null:
				save.add_coins(1)
			if bool(e.get("weighted", false)) or bool(props.get("weightedCoins", false)):
				player["carried_coins"] = int(player.get("carried_coins", 0)) + 1
			emit_sfx("coin")
			entities.remove_at(i)
			hud_dirty = true
		elif et == "gem":
			var gc: String = str(e.get("color", "red"))
			entities.remove_at(i)
			collect_gem(gc)
		elif et == "powerup":
			var pk: String = str(e.get("kind", ""))
			if pk == "shield_weight":
				continue
			emit_sfx("coin")
			if pk == "double_jump":
				player["max_jumps"] = maxi(int(player.get("max_jumps", 1)), 2)
				player["jumps_left"] = int(player["max_jumps"])
				unlock_ach("multi_jumper")
				add_shock_ring(float(e["x"]) + 18.0, float(e["y"]) + 18.0, Color("#4ade80"), 42.0, 0.25)
				emit_toast("★ 二段跳已解锁 · 空中再点跳跃可二段升空！", "DOUBLE JUMP UNLOCKED!", "icon_spring", "#4ade80")
			elif pk == "triple_jump":
				player["max_jumps"] = maxi(int(player.get("max_jumps", 1)), 3)
				player["jumps_left"] = int(player["max_jumps"])
				unlock_ach("multi_jumper")
				emit_toast("★ 三段跳已解锁 · 第三跳可下砸破砖！", "TRIPLE JUMP UNLOCKED!", "icon_spring", "#a855f7")
			elif pk == "flight":
				player["has_flight"] = true
				player["wing_fuel"] = 100.0
				unlock_ach("cyber_wings")
				add_shock_ring(float(e["x"]) + 18.0, float(e["y"]) + 18.0, Color("#67e8f9"), 42.0, 0.25)
				emit_toast("★ 赛博飞翼已激活 · 连按跳跃升空！", "CYBER WINGS ACTIVE!", "icon_wing", "#67e8f9")
			elif pk == "wing_ring":
				player["wing_fuel"] = 100.0
				emit_toast("影环充能成功 · 飞翼续航回满！", "SHADOW RING RECHARGED WINGS!", "icon_wing", "#38bdf8")
			entities.remove_at(i)
			hud_dirty = true
		elif et == "pipe":
			if pipe_warp_cd <= 0.0 and (bool(inp.get("down_pressed", false)) or bool(inp.get("down", false))):
				pipe_warp_cd = 0.45
				inp["down_pressed"] = false
				var rg_pipe: String = str(e.get("rerouteGroup", ""))
				var dest_x_val: float = float(e.get("altDestX", e.get("destX", 2.0))) if (rg_pipe != "" and bool(signal_groups.get(rg_pipe, false))) else float(e.get("destX", 2.0))
				var dest_y_val: float = float(e.get("altDestY", e.get("destY", 2.0))) if (rg_pipe != "" and bool(signal_groups.get(rg_pipe, false))) else float(e.get("destY", 2.0))
				var is_loop: bool = bool(e.get("loopPipe", false)) and not (rg_pipe != "" and bool(signal_groups.get(rg_pipe, false)))
				emit_sfx("pipe_echo_double" if is_loop else "pipe_echo_single")
				unlock_ach("pipe_traveler")
				add_afterimage(Color("#4ade80"))
				player["x"] = GridMath.gx_to_px(dest_x_val)
				player["y"] = GridMath.gy_to_py(dest_y_val, 0.0) - float(player["h"])
				player["vx"] = 0.0
				player["vy"] = 0.0
				p_rect.position = Vector2(float(player["x"]), float(player["y"]))
				add_shock_ring(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#4ade80"), 40.0, 0.26)
				spawn_particles(float(player["x"]) + 14.0, float(player["y"]) + 20.0, Color("#4ade80"), 16)
				emit_toast("管道空间跃迁！", "PIPE WARP!", "pipe", "#4ade80")
				break
		elif et == "shop":
			if bool(inp.get("down_pressed", false)) or bool(inp.get("interact_pressed", false)):
				if bool(player.get("has_debt_tag", false)) and shop != null:
					var set_res: Dictionary = shop.settle_debt_at_register(player, world_state)
					if str(e.get("unlockGroup", "")) != "":
						signal_groups[str(e["unlockGroup"])] = true
					emit_sfx("real_win")
					emit_toast("债务标签塞入收银机 · 黑店倒闭吐回 %d 金币！" % int(set_res.get("recovered_coins", 0)), "BLACK SHOP CLOSED · COINS RECOVERED!", "shop_frame", "#4ade80")
					entities.remove_at(i)
					return
				var shop_mode: String = str(e.get("shopItem", e.get("mode", "trap")))
				if shop_mode in ["map_lens", "useless_receipt", "free_revive_coupon", "magnet_shield"] and shop != null:
					var st_res: Dictionary = shop.buy_stage_stall_item(e, player, world_state)
					if str(st_res.get("effect", "")) == "map_lens_activated":
						xray_level = true
						emit_sfx("coin")
						emit_toast("已购入【地图透镜】 · 墙后隐藏电线与机关已显形！", "MAP LENS ACTIVE · WIRES REVEALED!", "ui_hint", "#00f5ff")
					elif str(st_res.get("effect", "")) == "useless_receipt":
						emit_sfx("coin")
						emit_toast("购入【无用收据】 · 背面印有真墙坐标，可压住暗钮！", "RECEIPT ACQUIRED · CHECK BACK COORDS!", "ui_hint", "#fde047")
					else:
						emit_sfx("fake_buzz")
						player["has_fake_coin"] = true
						emit_toast("误购黑店陷阱品 · 快投进退货槽回收！", "TRAP ITEM · USE RETURN SLOT!", "shop_frame", "#fb7185")
					return
				var pr: int = int(e.get("price", 3))
				if save != null and save.coins >= pr:
					save.add_coins(-pr)
					emit_sfx("fake_buzz")
					kill_player(true, "shop")
					return
				else:
					player["has_fake_coin"] = true
					emit_sfx("block")
		elif et == "princess":
			var req_p: Array = e.get("req", ["red", "green", "blue"])
			if not princess_satisfied and collected_gems.size() >= req_p.size():
				princess_satisfied = true
				unlock_ach("gem_knight")
				emit_sfx("real_win")
				fire_logic_event(str(e.get("uuid", "")), "on_activate", {})
		elif et == "flag":
			if bool(e.get("fake", false)):
				trigger_fake_flag(e)
				return
			if bool(e.get("require_back_entry", false)) and float(player["x"]) < float(e["x"]) + float(e["w"]) * 0.25:
				emit_sfx("block")
				emit_toast("正面有透明屏障 · 绕到真旗背面落脚通关！", "APPROACH REAL FLAG FROM BEHIND!", "flag_idle", "#fde047")
				continue
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
				e["x"] = GridMath.gx_to_px(float(e.get("runDestGx", 35.0)))
				emit_sfx("spring")
				fire_logic_event(str(e.get("uuid", "")), "on_flee", {})
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
	if ek == "follower" or ek == "shadow_follower":
		var target_x_e: float = world_state.shadow_rect.position.x if bool(e.get("tracks_shadow", false)) else float(player["x"])
		var dir: float = 1.0 if target_x_e > float(e["x"]) + 4.0 else (-1.0 if target_x_e < float(e["x"]) - 4.0 else 0.0)
		var abs_dx: float = absf(target_x_e - float(e["x"]))
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
			if bool(sx.get("slope_ramp", false)):
				continue
			var stx: String = str(sx.get("t", ""))
			if (stx == "invis" or stx == "qblock") and not bool(sx.get("revealed", false)):
				continue
			if GridMath.aabb_overlap(er_x, Rect2(float(sx["x"]), float(sx["y"]), float(sx["w"]), float(sx["h"]))):
				if stx == "glass_panel" and world_state.enemy_time_scale > 1.2:
					# Lv008: Accelerated patrol enemy shatters glass wall!
					sx["broken"] = true
					broken_solid_keys[str(sx["key"])] = true
					emit_sfx("fake_wall_shatter")
					continue
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
			if bool(sy.get("slope_ramp", false)):
				continue
			var sty: String = str(sy.get("t", ""))
			if (sty == "invis" or sty == "qblock") and not bool(sy.get("revealed", false)):
				continue
			if float(e["vy"]) >= 0.0 and GridMath.aabb_overlap(er_y, Rect2(float(sy["x"]), float(sy["y"]), float(sy["w"]), float(sy["h"]))):
				e["y"] = float(sy["y"]) - float(e["h"])
				e["vy"] = 0.0
				e["on_ground_enemy"] = true
				er_y.position.y = float(e["y"])
		if float(e["y"]) > GridMath.WORLD_ORIGIN_Y + 60.0:
			if bool(e.get("tracks_shadow", false)):
				# Lv016: Shadow-follower falling into pit leaves a walkable shell platform!
				solids.append({
					"uuid": str(e["key"]) + "_pit_shell", "key": str(e["key"]) + "_pit_shell",
					"t": "solid", "skin": "stone",
					"x": float(e["x"]) - 6.0, "y": GridMath.WORLD_ORIGIN_Y - 2.1 * GridMath.TILE,
					"base_x": float(e["x"]) - 6.0, "base_y": GridMath.WORLD_ORIGIN_Y - 2.1 * GridMath.TILE,
					"w": 56.0, "h": 44.0, "revealed": true, "broken": false, "layer": active_layer
				})
				emit_toast("追影怪落坑化作垫脚石壳！", "SHADOW FOLLOWER SHELL PLATFORM!", "enemy_follower", "#4ade80")
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
			# Lv038: If Gate-Chaser Mechaskull reaches exit gate after gate lock reflected, trap it!
			if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv038_mechaskull":
				for fg_var in entities:
					var fg: Dictionary = fg_var
					if str(fg.get("t", "")) == "flag" and float(e["x"]) + float(e["w"]) >= float(fg["x"]) - 48.0 and float(player["x"]) > float(fg["x"]) - 96.0:
						boss_sm.on_puzzle_event(self, "boss_charged_gate", {})
						e["stun_timer"] = 999.0
						break

func _step_enemy_shots(dt: float, world_dt: float, active_solids: Array) -> void:
	if enemy_shots.is_empty():
		return
	var p_rect: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))
	for k in range(enemy_shots.size() - 1, -1, -1):
		var sh: Dictionary = enemy_shots[k]
		var mul: float = Sector1And2Mechanics.get_local_time_scale(float(sh["x"]) + 6.0, float(sh["y"]) + 6.0, entities)
		var eff_dt: float = 0.0 if world_frozen else (world_dt * mul)
		if eff_dt <= 0.0001 and float(player["vy"]) >= -15.0:
			# Lv049 & Lv089: Frozen enemy projectiles in mid-air can be used as stepping stones!
			var sh_step: Rect2 = Rect2(float(sh["x"]) - 6.0, float(sh["y"]) - 8.0, float(sh.get("w", 12.0)) + 12.0, 14.0)
			var p_foot: Rect2 = Rect2(float(player["x"]), float(player["y"]) + float(player["h"]) - 7.0, float(player["w"]), 12.0)
			if GridMath.aabb_overlap(p_foot, sh_step):
				player["y"] = float(sh["y"]) - float(player["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
			continue

		if absf(float(sh.get("grav", 0.0))) > 0.01:
			sh["vy"] = float(sh.get("vy", 0.0)) + float(sh["grav"]) * eff_dt
		sh["x"] = float(sh["x"]) + float(sh.get("vx", 0.0)) * eff_dt
		sh["y"] = float(sh["y"]) + float(sh.get("vy", 0.0)) * eff_dt
		sh["life"] = float(sh["life"]) - dt
		if float(sh["life"]) <= 0.0:
			enemy_shots.remove_at(k)
			continue
		var shr: Rect2 = Rect2(float(sh["x"]), float(sh["y"]), float(sh.get("w", 12.0)), float(sh.get("h", 12.0)))
		var sh_l: int = int(sh.get("layer", -1))
		var same_layer: bool = (sh_l < 0) or (sh_l == active_layer)
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
					if wt == "mirror":
						var rv: Vector2 = GridMath.reflect_by_mirror_angle(Vector2(float(sh.get("vx", 0.0)), float(sh.get("vy", 0.0))), float(w_d.get("angle", 90.0)), 1.15)
						bullets.append({
							"x": float(sh["x"]), "y": float(sh["y"]),
							"w": 18.0, "h": 14.0,
							"vx": rv.x, "vy": rv.y,
							"upgraded": true, "s3_wave": false, "reflected": true, "life": 2.0
						})
						emit_sfx("mirror_ping")
						if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv038_mechaskull":
							boss_sm.on_puzzle_event(self, "gate_lock_reflected", {})
					elif wt == "s3_cloud" and str(sh.get("kind", "")) == "boss_lightning":
						if boss_sm != null and str(boss_sm.state.get("boss_key", "")) == "lv140_thunder_demon":
							boss_sm.on_puzzle_event(self, "lightning_reflected", {})
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
