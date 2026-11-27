class_name PlayerController
extends RefCounted

const COYOTE_TIME_BASE: float = 0.130
const COYOTE_TIME_ASSIST: float = 0.175
const JUMP_BUFFER_BASE: float = 0.145
const JUMP_BUFFER_ASSIST: float = 0.185

const GRAVITY_ACCEL: float = 1320.0
const TERMINAL_FALL_VY: float = 765.0
const JUMP_VY_NORMAL: float = -592.0
const JUMP_VY_HEAVY: float = -425.0
const FLIGHT_FLAP_VY: float = -410.0
const GROUND_POUND_VY: float = 820.0

static func create_player_dict(spawn_px: Vector2, props: Dictionary, cp: Dictionary) -> Dictionary:
	var abilities: Array = props.get("abilities", []) if typeof(props.get("abilities", null)) == TYPE_ARRAY else []
	var default_jumps: int = int(props.get("startJumps", 1))
	if "triple_jump" in abilities or "ground_pound" in abilities:
		default_jumps = maxi(default_jumps, 3)
	elif "double_jump" in abilities:
		default_jumps = maxi(default_jumps, 2)
	var cp_jumps: int = int(cp.get("max_jumps", 1)) if not cp.is_empty() else 1
	var start_jumps: int = maxi(default_jumps, cp_jumps)
	var start_flight: bool = (
		bool(props.get("startFlight", false))
		or ("flight" in abilities)
		or ("wings" in abilities)
		or (bool(cp.get("has_flight", false)) if not cp.is_empty() else false)
	)
	var init_grav: float = float(props.get("gravity", 1.0))
	if absf(init_grav) < 0.05:
		init_grav = 1.0

	return {
		"x": spawn_px.x,
		"y": spawn_px.y,
		"w": 28.0,
		"h": 42.0,
		"vx": 0.0,
		"vy": 0.0,
		"facing": 1,
		"grav_dir": -1.0 if init_grav < 0.0 else 1.0,
		"on_ground": false,
		"was_on_ground": false,
		"couching": false,
		"crouching": false,
		"coyote": 0.0,
		"jumps_left": start_jumps,
		"max_jumps": start_jumps,
		"air_jumps_used": 0,
		"ground_pounding": false,
		"sheathed": bool(props.get("startSheathed", false)),
		"sword_sheathed": bool(props.get("startSheathed", false)),
		"sheathe_cd": 0.0,
		"feint_slash_count": 0,
		"attack_count_stage": 0,
		"has_flight": start_flight,
		"wings_folded": false,
		"wing_fuel": 100.0,
		"flight_energy": 100.0,
		"max_wing_fuel": 100.0,
		"from_shop_flight": false,
		"has_wall_phase": false,
		"shield": bool(props.get("startShield", false)) or ("shield" in abilities),
		"shield_cache": "",
		"shield_tag": "",
		"from_shop_shield": false,
		"bullet_up": bool(props.get("bulletUp", false)) or ("bullet_up" in abilities) or (bool(cp.get("bullet_up", false)) if not cp.is_empty() else false),
		"from_shop_bullet": false,
		"sword_up": false,
		"map_lens": false,
		"bombs": int(props.get("startBombs", 0)),
		"carried_coins": 0,
		"coin_weight": 0,
		"has_spore_key": false,
		"has_fake_coin": false,
		"has_receipt": false,
		"has_debt_tag": false,
		"revive_debt": false,
		"immortal_charm": false,
		"gold_charges": 0,
		"golden_timer": 0.0,
		"poison_timer": 0.0,
		"poison_max": 3.0,
		"antidote_window": 0.0,
		"antidote_max": 6.0,
		"plant_cure_window": 0.0,
		"antidote_short_window": 0.0,
		"invuln_timer": 0.0,
		"celebrate_freeze_timer": 0.0,
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
		"scale_x": 1.0,
		"scale_y": 1.0,
		"scale_vx": 0.0,
		"scale_vy": 0.0,
		"tilt_rad": 0.0,
		"last_action_tag": "idle",
		"dead": false
	}

static func toggle_sheathe(eng: RefCounted, p: Dictionary) -> bool:
	if p.is_empty() or bool(p.get("dead", false)):
		return false
	if float(p.get("sheathe_cd", 0.0)) > 0.0:
		return bool(p.get("sheathed", false))
	p["sheathe_cd"] = 0.18

	# If toggled mid-melee windup/animation, record a half-stopped feint slash (Lv130!)
	if float(p.get("melee_anim", 0.0)) > 0.04:
		p["feint_slash_count"] = int(p.get("feint_slash_count", 0)) + 1
		p["melee_anim"] = 0.0
		p["attack_anim"] = 0.0
		p["last_action_tag"] = "feint_slash"
		eng.add_float_text(float(p["x"]), float(p["y"]) - 14.0, "FEINT!", "#fde047")

	var next_sh: bool = not bool(p.get("sheathed", false))
	p["sheathed"] = next_sh
	if next_sh:
		p["last_action_tag"] = "sheathe"
		eng.emit_sfx("sword_sheathe")
		eng.emit_toast("破魔剑已归鞘 · 解除攻击敌意姿态！", "SWORD SHEATHED · CALM STANCE!", "icon_sword", "#4ade80")
		if eng.has_method("fire_logic_event"):
			eng.fire_logic_event("player", "on_sheathe", {})
	else:
		p["last_action_tag"] = "unsheathe"
		eng.emit_sfx("melee_slash")
		eng.emit_toast("破魔剑已出鞘 · 恢复战斗姿态！", "SWORD DRAWN · COMBAT READY!", "icon_sword", "#00f5ff")
	eng.hud_dirty = true
	return next_sh

static func trigger_ground_pound(eng: RefCounted, p: Dictionary) -> bool:
	if p.is_empty() or bool(p.get("dead", false)) or bool(p.get("on_ground", false)):
		return false
	if bool(p.get("ground_pounding", false)):
		return false
	p["ground_pounding"] = true
	p["spring_trail_timer"] = 0.0
	p["vx"] = float(p["vx"]) * 0.22
	p["vy"] = GROUND_POUND_VY * float(p["grav_dir"])
	p["last_action_tag"] = "ground_pound"
	eng.spring_impulse_scale(0.74, 1.34)
	eng.emit_sfx("ground_pound")
	eng.add_shock_ring(float(p["x"]) + 14.0, float(p["y"]) + 21.0, Color("#a855f7"), 36.0, 0.24)
	return true

static func on_ground_pound_land(eng: RefCounted, p: Dictionary, landed_solid: Dictionary) -> void:
	if not bool(p.get("ground_pounding", false)):
		return
	p["ground_pounding"] = false
	var foot_x: float = float(p["x"]) + float(p["w"]) * 0.5
	var foot_y: float = (float(p["y"]) + float(p["h"])) if float(p["grav_dir"]) > 0.0 else float(p["y"])
	eng.spring_impulse_scale(1.34, 0.70)
	eng.trigger_shake(6.2, 0.18)
	eng.emit_sfx("ground_pound")
	eng.add_shock_ring(foot_x, foot_y, Color("#a855f7"), 52.0, 0.28)
	eng.spawn_particles(foot_x, foot_y, Color("#c084fc"), 14, 1.05)

	if not landed_solid.is_empty():
		var st: String = str(landed_solid.get("t", ""))
		if st == "s3_drop_block":
			landed_solid["drop_state"] = "fall"
			landed_solid["vy"] = 480.0
		elif st == "destructible" and bool(landed_solid.get("pound_break", false)):
			landed_solid["broken"] = true
			eng.broken_solid_keys[str(landed_solid.get("key", ""))] = true
		var suid: String = str(landed_solid.get("uuid", landed_solid.get("key", "")))
		if suid != "" and eng.has_method("fire_logic_event"):
			eng.fire_logic_event(suid, "on_ground_pound", {})

	# Depress any nearby heavy floor switches / echo pads
	var pound_box: Rect2 = Rect2(foot_x - 36.0, foot_y - 24.0, 72.0, 44.0)
	for e_var in eng.entities:
		var e: Dictionary = e_var
		var et: String = str(e.get("t", ""))
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x > 0.0 and GridMath.aabb_overlap(pound_box, er):
			if et in ["echo_pad", "signal_node", "decoy_btn"]:
				var grp: String = str(e.get("group", e.get("padGroup", "")))
				if grp != "":
					eng.signal_groups[grp] = true
				var euid: String = str(e.get("uuid", e.get("key", "")))
				if euid != "" and eng.has_method("fire_logic_event"):
					eng.fire_logic_event(euid, "on_ground_pound", {})

static func interact_place_throw(eng: RefCounted, p: Dictionary, inp: Dictionary) -> bool:
	if p.is_empty() or bool(p.get("dead", false)):
		return false
	var down_held: bool = bool(inp.get("down", false)) or bool(inp.get("down_pressed", false))
	var px_front: float = (float(p["x"]) + float(p["w"]) + 8.0) if int(p["facing"]) >= 0 else (float(p["x"]) - 34.0)
	var py_foot: float = float(p["y"]) + float(p["h"]) - 32.0

	# 1. If currently carrying a portable entity, place or throw it!
	if not eng.carrying_item.is_empty():
		var item: Dictionary = eng.carrying_item
		item["carried"] = false
		item["x"] = (float(p["x"]) + 2.0) if down_held else px_front
		item["y"] = py_foot
		item["thrown_vx"] = 0.0 if down_held else (float(p["facing"]) * 285.0)
		item["thrown_vy"] = 0.0 if down_held else (-195.0 * float(p["grav_dir"]))
		eng.carrying_item = {}
		eng.emit_sfx("block")
		eng.hud_dirty = true
		var iuid: String = str(item.get("uuid", item.get("key", "")))
		if iuid != "" and eng.has_method("fire_logic_event"):
			eng.fire_logic_event(iuid, "on_place", { "thrown": not down_held })
		return true

	# 2. Check nearby pickable objects (patch_chip, spore_key, debt_tag, control_orb, signal_battery, root_item, trojan_heart)
	var reach_box: Rect2 = Rect2(float(p["x"]) - 18.0, float(p["y"]) - 12.0, float(p["w"]) + 36.0, float(p["h"]) + 24.0)
	for e_var in eng.entities:
		var e: Dictionary = e_var
		var et: String = str(e.get("t", ""))
		if et in ["signal_battery", "root_item", "patch_chip", "spore_key", "debt_tag", "control_orb"]:
			if not bool(e.get("carried", false)) and not bool(e.get("inserted", false)):
				var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 32.0)), float(e.get("h", 32.0)))
				if GridMath.aabb_overlap(reach_box, er):
					e["carried"] = true
					eng.carrying_item = e
					eng.emit_sfx("coin")
					eng.hud_dirty = true
					return true

	# 3. Unequip / throw active shield as counterweight or magnetic core tool (Lv011, Lv020, Lv053)
	if bool(p.get("shield", false)) and down_held:
		p["shield"] = false
		p["shield_cache"] = ""
		var dropped_shield: Dictionary = {
			"uuid": "dropped_shield_" + str(Time.get_ticks_msec()),
			"key": "dropped_shield_" + str(Time.get_ticks_msec()),
			"t": "powerup",
			"kind": "shield_weight",
			"weight": 2,
			"magnetic": true,
			"x": px_front,
			"y": py_foot,
			"w": 32.0,
			"h": 32.0,
			"vx": float(p["facing"]) * 190.0,
			"vy": -120.0,
			"layer": eng.active_layer
		}
		eng.entities.append(dropped_shield)
		eng.emit_sfx("shield_parry")
		eng.emit_toast("已主动卸下能量护盾作为配重/磁吸工具！", "SHIELD DROPPED AS TOOL / WEIGHT!", "icon_shield", "#38bdf8")
		eng.hud_dirty = true
		return true

	# 4. Place a carried stage coin onto weight scale / coin slot (Lv013, Lv020, Lv041, Lv138)
	if int(p.get("carried_coins", 0)) > 0:
		p["carried_coins"] = int(p["carried_coins"]) - 1
		eng.entities.append({
			"uuid": "placed_coin_" + str(Time.get_ticks_msec()),
			"key": "placed_coin_" + str(Time.get_ticks_msec()),
			"t": "coin",
			"placed_weight": true,
			"weight": 1,
			"pickup_cd": 0.65,
			"x": px_front,
			"y": py_foot + 4.0,
			"w": 28.0,
			"h": 28.0,
			"layer": eng.active_layer
		})
		eng.emit_sfx("coin")
		eng.hud_dirty = true
		return true

	return false

static func step_movement_and_actions(
	eng: RefCounted,
	p: Dictionary,
	dt: float,
	inp: Dictionary,
	props: Dictionary,
	loop_mul: float
) -> void:
	if p.is_empty() or bool(p.get("dead", false)):
		return

	if float(p.get("sheathe_cd", 0.0)) > 0.0:
		p["sheathe_cd"] = maxf(0.0, float(p["sheathe_cd"]) - dt)
	if float(p.get("antidote_short_window", 0.0)) > 0.0:
		p["antidote_short_window"] = maxf(0.0, float(p["antidote_short_window"]) - dt)

	# Brief celebration freeze (Lv006 non-lethal 0.9s max, direction reversal breaks out early!)
	if float(p.get("celebrate_freeze_timer", 0.0)) > 0.0:
		p["celebrate_freeze_timer"] = maxf(0.0, float(p["celebrate_freeze_timer"]) - dt)
		var rev_break: bool = (int(p["facing"]) > 0 and bool(inp.get("left", false))) or (int(p["facing"]) < 0 and bool(inp.get("right", false)))
		if rev_break:
			p["celebrate_freeze_timer"] = 0.0
		else:
			p["vx"] = 0.0
			return

	var assist_on: bool = eng.save != null and bool(eng.save.assist_mode)
	var sens: float = clampf(eng.save.sensitivity if eng.save != null else 1.0, 0.5, 1.5)
	var resp_mul: float = 0.68 + 0.56 * sens

	if bool(inp.get("sheathe_pressed", false)):
		toggle_sheathe(eng, p)

	if bool(inp.get("interact_pressed", false)):
		if not interact_place_throw(eng, p, inp):
			# Secondary convenience: pressing interact when empty-handed in calm stages toggles sheathe if requested
			if bool(props.get("sheatheStage", false)):
				toggle_sheathe(eng, p)

	var down_held: bool = bool(inp.get("down", false))
	p["crouching"] = down_held and bool(p["on_ground"])

	# Cancel mid-slash into feint on sudden crouch (Lv130!)
	if down_held and float(p.get("melee_anim", 0.0)) > 0.06:
		p["feint_slash_count"] = int(p.get("feint_slash_count", 0)) + 1
		p["melee_anim"] = 0.0
		p["last_action_tag"] = "feint_slash"

	# Fold/unfold wings in mid-air via down key (Lv133, Lv137, Lv140)
	if bool(p.get("has_flight", false)) and not bool(p["on_ground"]):
		p["wings_folded"] = down_held
	else:
		p["wings_folded"] = false

	var move_dir: int = (1 if bool(inp.get("right", false)) else 0) - (1 if bool(inp.get("left", false)) else 0)
	if bool(props.get("mirrorInput", false)):
		move_dir = -move_dir
	if bool(p.get("in_curse_mirror", false)) or float(p.get("reverse_curse_timer", 0.0)) > 0.0:
		move_dir = -move_dir

	var weight_penalty: float = clampf(1.0 - float(int(p.get("carried_coins", 0))) * 0.035, 0.78, 1.0)
	var crouch_mul: float = 0.58 if bool(p["crouching"]) else 1.0
	var max_run_spd: float = (242.0 + (sens - 1.0) * 22.0) * loop_mul * weight_penalty * crouch_mul
	var is_turning: bool = move_dir != 0 and absf(float(p["vx"])) > 20.0 and int(signf(float(p["vx"]))) != move_dir
	var is_braking: bool = move_dir == 0

	if move_dir != 0 and absf(float(p["vx"])) < 36.0 * sens:
		p["vx"] = float(move_dir) * 36.0 * sens

	var accel: float = 0.0
	if is_turning:
		accel = (5800.0 if bool(p["on_ground"]) else 4200.0) * resp_mul
	elif is_braking:
		accel = (4700.0 if bool(p["on_ground"]) else 2850.0) * resp_mul
	else:
		accel = (3450.0 if bool(p["on_ground"]) else 2600.0) * resp_mul

	var jump_held: bool = bool(inp.get("jump_held", false))
	var near_apex: bool = (not bool(p["on_ground"])) and (not bool(p["has_flight"])) and absf(float(p["vy"])) < 85.0 and jump_held
	var target_vx: float = float(move_dir) * max_run_spd * (1.07 if near_apex else 1.0)
	if float(p["vx"]) < target_vx:
		p["vx"] = minf(target_vx, float(p["vx"]) + accel * dt)
	elif float(p["vx"]) > target_vx:
		p["vx"] = maxf(target_vx, float(p["vx"]) - accel * dt)

	if move_dir != 0:
		var backwalk_lock: bool = bool(inp.get("lock_facing", false))
		if not backwalk_lock:
			p["facing"] = move_dir
		p["walk_cycle"] = float(p["walk_cycle"]) + dt * (11.6 + sens * 1.4)
		p["last_action_tag"] = "crouch" if bool(p["crouching"]) else "move"
	else:
		p["walk_cycle"] = 0.0
		if bool(p["crouching"]):
			p["last_action_tag"] = "crouch"

	var coyote_win: float = (COYOTE_TIME_ASSIST if assist_on else COYOTE_TIME_BASE) + (sens - 1.0) * 0.02
	if bool(p["on_ground"]):
		p["coyote"] = coyote_win
		p["jumps_left"] = int(p["max_jumps"])
		p["air_jumps_used"] = 0
		p["ground_pounding"] = false
		p["wing_fuel"] = minf(float(p.get("max_wing_fuel", 100.0)), float(p.get("wing_fuel", 100.0)) + 65.0 * dt)
	else:
		p["coyote"] = maxf(0.0, float(p["coyote"]) - dt)

	# Mid-air manual ground pound (down_pressed while airborne in 3-jump or pound-enabled stages)
	if not bool(p["on_ground"]) and bool(inp.get("ground_pound_pressed", false)):
		trigger_ground_pound(eng, p)

	var shoot_triggered: bool = bool(inp.get("shoot_pressed", false))
	var buf_win: float = JUMP_BUFFER_ASSIST if assist_on else JUMP_BUFFER_BASE
	if bool(inp.get("jump_pressed", false)):
		eng.jump_buffer_timer = buf_win
	elif eng.jump_buffer_timer > 0.0:
		eng.jump_buffer_timer = maxf(0.0, eng.jump_buffer_timer - dt)

	if eng.jump_buffer_timer > 0.0:
		if bool(p["has_flight"]) and not bool(p.get("wings_folded", false)) and float(p.get("wing_fuel", 100.0)) > 0.5:
			eng.jump_buffer_timer = 0.0
			p["spring_trail_timer"] = 0.0
			p["vy"] = FLIGHT_FLAP_VY * float(p["grav_dir"])
			if bool(props.get("wingShadowFuel", false)) or bool(props.get("limitedWingFuel", false)):
				var drain: float = clampf(960.0 / maxf(24.0, eng.world_state.shadow_length_px), 6.0, 28.0)
				p["wing_fuel"] = maxf(0.0, float(p["wing_fuel"]) - drain)
			p["last_action_tag"] = "fly_flap"
			eng.spring_impulse_scale(0.82, 1.20)
			eng.emit_sfx("jump_air")
			eng.add_shock_ring(float(p["x"]) + 14.0, float(p["y"]) + 42.0, Color("#00f5ff"), 26.0, 0.22)
			eng.spawn_particles(float(p["x"]) + 14.0, float(p["y"]) + 42.0, Color("#00f5ff"), 6, 0.85)
		elif float(p["coyote"]) > 0.0 or int(p["jumps_left"]) > 0:
			var is_air: bool = float(p["coyote"]) <= 0.0
			eng.jump_buffer_timer = 0.0
			p["spring_trail_timer"] = 0.0
			var foot_py: float = (float(p["y"]) + float(p["h"])) if float(p["grav_dir"]) > 0.0 else float(p["y"])
			if is_air:
				p["jumps_left"] = int(p["jumps_left"]) - 1
				p["air_jumps_used"] = int(p.get("air_jumps_used", 0)) + 1
				eng.unlock_ach("multi_jumper")

				# Lv031: 3rd jump acts as downward ground pound when down is held or tripleJumpDown prop is active!
				if (int(p["air_jumps_used"]) >= 2 and (down_held or bool(props.get("tripleJumpDown", false)))):
					p["coyote"] = 0.0
					p["on_ground"] = false
					trigger_ground_pound(eng, p)
					return

				# Lv014: Double jump horizontal inertia reversal
				if bool(props.get("doubleJumpInvertVx", false)):
					var rev_vx: float = -float(p["vx"]) * 1.12
					if absf(rev_vx) < 220.0 and move_dir != 0:
						rev_vx = float(move_dir) * 265.0
					p["vx"] = clampf(rev_vx, -320.0, 320.0)
				elif move_dir != 0 and signf(float(p["vx"])) != float(move_dir):
					p["vx"] = float(move_dir) * max_run_spd * 1.08

				eng.add_shock_ring(float(p["x"]) + 14.0, foot_py, Color("#a855f7"), 34.0, 0.25)
				eng.add_afterimage(Color("#a855f7"))
				p["last_action_tag"] = "air_jump"
			else:
				p["jumps_left"] = maxi(0, int(p["max_jumps"]) - 1)
				eng.add_shock_ring(float(p["x"]) + 14.0, foot_py, Color("#00f5ff"), 24.0, 0.20)
				p["last_action_tag"] = "jump_long" if absf(float(p["vx"])) > 160.0 else "jump_short"

			p["coyote"] = 0.0
			p["on_ground"] = false
			var jvy: float = JUMP_VY_HEAVY if (float(p["heavy_curse_timer"]) > 0.0 or int(p.get("carried_coins", 0)) >= 4) else JUMP_VY_NORMAL
			p["vy"] = jvy * float(p["grav_dir"])
			if bool(p["in_curse_jump_shot"]):
				shoot_triggered = true
			eng.spring_impulse_scale(0.77, 1.27)
			eng.emit_sfx("jump_air" if is_air else "jump")
			eng.spawn_particles(float(p["x"]) + 14.0, foot_py, Color("#c084fc") if is_air else Color("#00f5ff"), 8, 0.9)

	if bool(inp.get("jump_released", false)):
		if not bool(p["has_flight"]) and not bool(p.get("ground_pounding", false)) and float(p.get("spring_trail_timer", 0.0)) <= 0.0 and float(p["vy"]) * float(p["grav_dir"]) < -165.0:
			var cut_f: float = clampf(0.54 - (sens - 0.5) * 0.10, 0.42, 0.56)
			p["vy"] = float(p["vy"]) * cut_f

	# Combat gating when sword is actively sheathed
	if bool(inp.get("slash_pressed", false)):
		if bool(p.get("sheathed", false)):
			eng.emit_sfx("sword_sheathe")
			eng.add_float_text(float(p["x"]), float(p["y"]) - 10.0, "SHEATHED", "#4ade80")
		else:
			p["attack_count_stage"] = int(p.get("attack_count_stage", 0)) + 1
			p["last_action_tag"] = "slash"
			eng.world_state.step_sun_heat(0.0, false, true)
			Sector1And2Mechanics.notify_peace_doves(eng, float(p["x"]) + 14.0, float(p["y"]) + 21.0)
			eng.perform_melee_slash()

	if shoot_triggered:
		if bool(p.get("sheathed", false)):
			eng.emit_sfx("sword_sheathe")
			eng.add_float_text(float(p["x"]), float(p["y"]) - 10.0, "SHEATHED", "#4ade80")
		else:
			p["attack_count_stage"] = int(p.get("attack_count_stage", 0)) + 1
			p["last_action_tag"] = "shoot"
			eng.world_state.step_sun_heat(0.0, false, true)
			Sector1And2Mechanics.notify_peace_doves(eng, float(p["x"]) + 14.0, float(p["y"]) + 21.0)
			fire_energy_shot(eng, p, props)

	if bool(inp.get("bomb_pressed", false)):
		if not eng.carrying_item.is_empty() and str(eng.carrying_item.get("t", "")) == "signal_battery":
			eng.emit_sfx("block")
			eng.emit_toast("携带信号电池期间无法投弹！", "CANNOT USE BOMBS WHILE CARRYING BATTERY!", "s2_battery", "#fde047")
		elif int(p["bombs"]) > 0:
			p["bombs"] = int(p["bombs"]) - 1
			if bool(p.get("shop_bomb_pending", false)) and eng.shop != null:
				p["shop_bomb_pending"] = false
				eng.shop.mark_used_in_stage("bomb_pack")
			p["last_action_tag"] = "throw_bomb"
			eng.spring_impulse_scale(1.12, 0.92)
			eng.emit_sfx("shoot")
			eng.bombs.append({
				"x": float(p["x"]) + 14.0,
				"y": float(p["y"]) + 8.0,
				"vx": float(p["facing"]) * 275.0,
				"vy": -280.0 * float(p["grav_dir"]),
				"fuse": 0.92
			})
			eng.hud_dirty = true

	var grav_scale: float = 1.0
	if bool(p.get("ground_pounding", false)):
		grav_scale = 1.85
	elif not bool(p["on_ground"]) and not bool(p["has_flight"]):
		if jump_held and absf(float(p["vy"])) < 82.0:
			grav_scale = 0.74
		elif float(p["vy"]) * float(p["grav_dir"]) > 45.0:
			grav_scale = 1.07
	elif bool(p["has_flight"]) and not bool(p.get("wings_folded", false)) and jump_held and float(p["vy"]) * float(p["grav_dir"]) > 110.0:
		grav_scale = 0.42

	p["vy"] = float(p["vy"]) + GRAVITY_ACCEL * grav_scale * float(p["grav_dir"]) * dt
	var max_fall: float = 920.0 if bool(p.get("ground_pounding", false)) else TERMINAL_FALL_VY
	if float(p["grav_dir"]) > 0.0 and float(p["vy"]) > max_fall:
		p["vy"] = max_fall
	elif float(p["grav_dir"]) < 0.0 and float(p["vy"]) < -max_fall:
		p["vy"] = -max_fall

static func fire_energy_shot(eng: RefCounted, p: Dictionary, props: Dictionary) -> void:
	p["attack_anim"] = 0.22
	eng.spring_impulse_scale(1.15, 0.90)
	eng.emit_sfx("shoot")
	var bup: bool = bool(p.get("bullet_up", false))
	var bspd: float = 545.0 if bup else 455.0
	var down_shot: bool = bool(props.get("airDownRecoilShot", false)) and not bool(p.get("on_ground", false))
	var vx_b: float = float(p["facing"]) * bspd
	var vy_b: float = 0.0
	if down_shot:
		vx_b = float(p["facing"]) * 180.0
		vy_b = 520.0
		p["vy"] = minf(float(p["vy"]), -330.0)
		p["vx"] = float(p["vx"]) - float(p["facing"]) * 145.0
	eng.bullets.append({
		"x": (float(p["x"]) + float(p["w"]) + 2.0) if int(p["facing"]) > 0 else (float(p["x"]) - 24.0),
		"y": float(p["y"]) + 10.0,
		"w": 28.0 if bup else 24.0,
		"h": 18.0 if bup else 20.0,
		"vx": vx_b,
		"vy": vy_b,
		"upgraded": bup,
		"pierce_left": 1 if bup else 0,
		"vengeful": bup and bool(props.get("vengefulBullet", false)),
		"origin_x": float(p["x"]) + 14.0,
		"origin_y": float(p["y"]) + 20.0,
		"s3_wave": false,
		"reflected": false,
		"bounce_count": 0,
		"life": 2.35
	})
