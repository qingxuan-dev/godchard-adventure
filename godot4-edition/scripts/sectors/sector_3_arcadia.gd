class_name Sector3Arcadia
extends RefCounted

static func init_attempt_state(eng: RefCounted, cp: Dictionary) -> void:
	eng.s3_valves = {}
	if not cp.is_empty() and cp.has("s3_valves"):
		var cv: Dictionary = cp["s3_valves"]
		for k in cv.keys():
			eng.s3_valves[str(k)] = bool(cv[k])
	eng.s3_sundial_phase = bool(cp.get("s3_sundial_phase", false)) if not cp.is_empty() else false
	eng.s3_boss_defeated = false
	eng.s3_trophy_respawns = []

static func spawn_obj(eng: RefCounted, o: Dictionary, idx: int, lv: Dictionary) -> bool:
	var lv_id: int = int(lv.get("id", 1))
	var key: String = str(o.get("uuid", "%d_s3_%d" % [lv_id, idx]))
	var t: String = str(o.get("t", ""))
	if t == "sunglasses_sun":
		t = "s3_sun"
	var ox: float = float(o.get("x", 0.0))
	var oy: float = float(o.get("y", 0.0))
	var layer_val: int = int(o["layer"]) if (o.has("layer") and o["layer"] != null) else -1

	if t == "s3_tall_pipe":
		var full_h: float = float(o.get("h", 5.8)) * GridMath.TILE
		var target_h_px: float = float(o.get("targetH", 1.4)) * GridMath.TILE
		var pgrp: String = str(o.get("pipeGroup", "p1"))
		var already_low: bool = bool(eng.s3_valves.get(pgrp, false))
		var cur_h: float = target_h_px if already_low else full_h
		var foot_y: float = GridMath.gy_to_py(oy, 0.0)
		eng.solids.append({
			"uuid": key, "key": key, "t": "s3_tall_pipe",
			"x": GridMath.gx_to_px(ox),
			"y": foot_y - cur_h,
			"foot_y": foot_y,
			"w": float(o.get("w", 1.45)) * GridMath.TILE,
			"h": cur_h,
			"orig_h_px": full_h,
			"target_h_px": target_h_px,
			"pipe_group": pgrp,
			"mode": str(o.get("mode", "block")),
			"invert_sundial": bool(o.get("invertSundial", false)),
			"lowered": already_low,
			"rocket_cd": 0.0,
			"layer": layer_val, "broken": false
		})
		return true

	if t == "s3_cloud":
		var cw: float = float(o.get("w", 2.2)) * GridMath.TILE
		var ch: float = float(o.get("h", 1.15)) * GridMath.TILE
		var csx: float = GridMath.gx_to_px(ox)
		var csy: float = GridMath.gy_to_py(oy, float(o.get("h", 1.15)))
		var cmode: String = str(o.get("subType", o.get("mode", "hidden_knife")))
		if cmode == "solid":
			cmode = "safe_plat"
		elif cmode == "blade":
			cmode = "hidden_knife"
		elif cmode == "hollow":
			cmode = "fake_cloud"
		elif cmode == "thunder":
			cmode = "swoop_cloud"
		eng.solids.append({
			"uuid": key, "key": key, "t": "s3_cloud",
			"x": csx, "y": csy, "base_x": csx, "base_y": csy,
			"w": cw, "h": ch,
			"mode": cmode,
			"brittle_core": bool(o.get("brittleCore", false)),
			"invert_sundial": bool(o.get("invertSundial", false)),
			"disarmed": (cmode == "safe_plat" or cmode == "bounce"),
			"blades_out": false,
			"swooping": false,
			"thunder_frozen_timer": 0.0,
			"step_cue_cd": 0.0,
			"vy": 0.0,
			"respawn_timer": 0.0,
			"layer": layer_val, "broken": false
		})
		return true

	if t == "s3_drop_block":
		var dbh: float = float(o.get("h", 1.2))
		var dsx: float = GridMath.gx_to_px(ox)
		var dsy: float = GridMath.gy_to_py(oy, dbh)
		eng.solids.append({
			"uuid": key, "key": key, "t": "s3_drop_block",
			"x": dsx, "y": dsy, "base_x": dsx, "base_y": dsy,
			"w": float(o.get("w", 2.0)) * GridMath.TILE,
			"h": dbh * GridMath.TILE,
			"skin": str(o.get("skin", "stone")),
			"stay_solid": bool(o.get("staySolid", true)),
			"rise_trap": bool(o.get("riseTrap", false)),
			"anti_newton": bool(o.get("antiNewton", false)),
			"last_impulse_dir": 0,
			"drop_state": "idle",
			"timer": 0.0,
			"vy": 0.0,
			"respawn_timer": 0.0,
			"layer": layer_val, "broken": false
		})
		return true

	if t == "s3_slide_turf":
		var sth: float = float(o.get("h", 2.0))
		var stx: float = GridMath.gx_to_px(ox)
		var sty: float = GridMath.gy_to_py(oy, sth)
		eng.solids.append({
			"uuid": key, "key": key, "t": "s3_slide_turf",
			"x": stx, "y": sty, "base_x": stx, "base_y": sty,
			"w": float(o.get("w", 3.2)) * GridMath.TILE,
			"h": sth * GridMath.TILE,
			"slide_dx_px": float(o.get("slideDx", 2.4)) * GridMath.TILE,
			"slide_dy_px": float(o.get("slideDy", 0.0)) * GridMath.TILE,
			"trigger_dist_px": float(o.get("triggerDx", 2.0)) * GridMath.TILE,
			"triggered": false,
			"layer": layer_val, "broken": false
		})
		return true

	if t == "tanuki_log":
		var tlh: float = float(o.get("h", 1.0))
		var tlx: float = GridMath.gx_to_px(ox)
		var tly: float = GridMath.gy_to_py(oy, tlh)
		eng.solids.append({
			"uuid": key, "key": key, "t": "tanuki_log", "skin": "tanuki_log",
			"x": tlx, "y": tly, "base_x": tlx, "base_y": tly,
			"w": float(o.get("w", 1.0)) * GridMath.TILE, "h": tlh * GridMath.TILE,
			"pushable": true,
			"layer": layer_val, "broken": false, "revealed": true
		})
		return true

	var s3_ents: Array[String] = [
		"s3_valve", "s3_bush", "s3_flower", "s3_tanuki", "s3_manju",
		"s3_ladybug", "s3_mole", "s3_sun", "s3_boss",
		"s3_catapult", "s3_bomb_trophy", "s3_suction_pipe", "s3_sundial", "s3_mimic_flag"
	]
	if not (t in s3_ents):
		return false

	var ent: Dictionary = o.duplicate(true)
	ent["uuid"] = key
	ent["key"] = key
	ent["t"] = t
	ent["layer"] = layer_val

	if t == "s3_valve":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.0)
		ent["w"] = 1.0 * GridMath.TILE
		ent["h"] = 1.0 * GridMath.TILE
		var pgrp_v: String = str(o.get("pipeGroup", ""))
		ent["pipe_group"] = pgrp_v
		ent["fake"] = bool(o.get("fake", false))
		ent["spun"] = pgrp_v != "" and bool(eng.s3_valves.get(pgrp_v, false))
		ent["spin_ang"] = 0.0
		ent["reset_timer"] = 0.0
	elif t == "s3_bush":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.35)
		ent["w"] = float(o.get("w", 2.4)) * GridMath.TILE
		ent["h"] = 1.35 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "ambush_blade"))
		ent["revealed"] = false
	elif t == "s3_flower":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["mode"] = str(o.get("subType", o.get("mode", "lunge")))
		ent["vx"] = 0.0
		ent["vy"] = 0.0
		ent["angry"] = false
		ent["hp"] = 2
		ent["rewarded"] = false
	elif t == "s3_tanuki":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["hp"] = 3
		ent["max_hp"] = 3
		ent["clones"] = int(o.get("clones", 2))
		ent["cloned"] = false
		ent["is_clone"] = false
		ent["vx"] = -68.0
		ent["vy"] = 0.0
	elif t == "s3_manju":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.9)
		ent["spawn_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = 0.96 * GridMath.TILE
		ent["h"] = 0.9 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "spike_morph"))
		ent["vx"] = -85.0
		ent["vy"] = 0.0
		ent["spiked"] = false
		ent["hp"] = 2
		ent["waiting_drop"] = false
		if str(ent["mode"]) == "sky_drop":
			ent["y"] = GridMath.gy_to_py(oy + 5.4, 0.9)
			ent["waiting_drop"] = true
	elif t == "s3_ladybug":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.88)
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 0.88 * GridMath.TILE
		ent["min_px"] = GridMath.gx_to_px(float(o.get("minGx", ox - 3.0)))
		ent["max_px"] = GridMath.gx_to_px(float(o.get("maxGx", ox + 3.0)))
		ent["dir"] = -1.0
		ent["sprinting"] = false
		ent["hp"] = 2
	elif t == "s3_mole":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["base_y"] = GridMath.gy_to_py(oy, 1.0)
		ent["y"] = float(ent["base_y"])
		ent["w"] = 1.0 * GridMath.TILE
		ent["h"] = 1.0 * GridMath.TILE
		ent["clock"] = float(idx % 3) * 0.7
		ent["up"] = true
		ent["hp"] = 2
	elif t == "s3_sun":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.6)
		ent["home_y"] = float(ent["y"])
		ent["w"] = 1.6 * GridMath.TILE
		ent["h"] = 1.6 * GridMath.TILE
		ent["trigger_px"] = GridMath.gx_to_px(float(o.get("triggerGx", 10.0)))
		ent["tracks_shadow"] = bool(o.get("tracksShadow", false))
		ent["tracks_heat"] = bool(o.get("tracksHeat", false))
		ent["blind_timer"] = 0.0
		ent["awake"] = false
		ent["swoop_clock"] = 1.2
		ent["swooping"] = false
		ent["swoop_prog"] = 0.0
		ent["start_x"] = 0.0
	elif t == "s3_catapult":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.75)
		ent["w"] = 1.25 * GridMath.TILE
		ent["h"] = 0.75 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "forward_vault"))
		ent["cd"] = 0.0
		ent["anim"] = 0.0
	elif t == "s3_bomb_trophy":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["spawn_y"] = float(ent["y"])
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["fuse"] = -1.0
	elif t == "s3_suction_pipe":
		var sph: float = float(o.get("h", 2.2))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, sph)
		ent["w"] = float(o.get("w", 1.45)) * GridMath.TILE
		ent["h"] = sph * GridMath.TILE
		ent["pipe_group"] = str(o.get("pipeGroup", ""))
		ent["stone_plugged"] = false
	elif t == "s3_sundial":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.1)
		ent["w"] = 1.1 * GridMath.TILE
		ent["h"] = 1.1 * GridMath.TILE
		ent["hit_cd"] = 0.0
	elif t == "s3_mimic_flag":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.75)
		ent["spawn_x"] = float(ent["x"])
		ent["w"] = 1.15 * GridMath.TILE
		ent["h"] = 1.75 * GridMath.TILE
		ent["awake"] = false
		ent["tamed"] = false
		ent["hp"] = 2
		ent["mode"] = str(o.get("fakeType", o.get("mode", "decoy")))
	elif t == "s3_boss":
		var bh: float = float(o.get("h", 2.5))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, bh)
		ent["base_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = float(o.get("w", 2.5)) * GridMath.TILE
		ent["h"] = bh * GridMath.TILE
		ent["boss_kind"] = str(o.get("bossKey", o.get("bossKind", "solaris_painter")))
		ent["max_hp"] = int(o.get("hp", 34 if ("150" in str(ent["boss_kind"]) or "solaris" in str(ent["boss_kind"])) else 26))
		ent["hp"] = int(ent["max_hp"])
		ent["atk_timer"] = 1.6
		ent["phase_clock"] = 0.0
		ent["stun_timer"] = 0.0
		ent["hit_flash"] = 0.0

	eng.entities.append(ent)
	return true

static func is_cloud_safe(s: Dictionary, sundial_phase: bool) -> bool:
	var cm: String = str(s.get("mode", ""))
	if bool(s.get("disarmed", false)) or cm == "safe_plat" or cm == "bounce":
		return true
	if float(s.get("thunder_frozen_timer", 0.0)) > 0.0:
		return true
	if cm == "sundial_knife":
		var inv: bool = bool(s.get("invert_sundial", false))
		return (not sundial_phase) if inv else sundial_phase
	return false

static func is_solid_collidable(s: Dictionary, sundial_phase: bool) -> bool:
	if bool(s.get("broken", false)):
		return false
	if str(s.get("t", "")) == "s3_cloud":
		if str(s.get("mode", "")) == "fake_cloud" and float(s.get("thunder_frozen_timer", 0.0)) <= 0.0:
			return true
		return is_cloud_safe(s, sundial_phase)
	return true

static func activate_valve(eng: RefCounted, e: Dictionary) -> void:
	if e.is_empty() or bool(e.get("spun", false)):
		return
	if bool(e.get("fake", false)):
		e["spun"] = true
		eng.anti_troll_disqualified = true
		eng.emit_sfx("fake_buzz")
		eng.trigger_shake(6.0, 0.20)
		var dir_m: float = -155.0 if float(eng.player.get("x", 0.0)) < float(e["x"]) else 155.0
		eng.entities.append({
			"uuid": "trap_manju_" + str(Time.get_ticks_msec()),
			"key": "trap_manju_" + str(Time.get_ticks_msec()),
			"t": "s3_manju", "mode": "spike_morph",
			"x": float(e["x"]), "y": float(e["y"]) - 44.0,
			"spawn_x": float(e["x"]), "base_y": float(e["y"]),
			"w": 0.96 * GridMath.TILE, "h": 0.9 * GridMath.TILE,
			"vx": dir_m, "vy": -250.0, "spiked": true, "hp": 2,
			"waiting_drop": false, "layer": -1
		})
		eng.emit_toast("糟糕！拧到了诱饵假阀门，蹦出带刺白团子！", "DECOY VALVE! SPIKED MANJU AMBUSH!", "s3_mon_manju_spike", "#fb7185")
		return

	e["spun"] = true
	var pgrp: String = str(e.get("pipe_group", ""))
	if pgrp != "":
		eng.s3_valves[pgrp] = true
	eng.emit_sfx("valve_turn")
	eng.trigger_shake(5.0, 0.18)
	var cx: float = float(e["x"]) + float(e["w"]) * 0.5
	var cy: float = float(e["y"]) + float(e["h"]) * 0.5
	eng.add_shock_ring(cx, cy, Color("#4ade80"), 46.0, 0.28)
	eng.spawn_particles(cx, cy, Color("#fde047"), 16)

	# Recompute shared aqueduct water pressure pool
	var all_pipes: Array = []
	for sp_var in eng.solids:
		var sp_d: Dictionary = sp_var
		if str(sp_d.get("t", "")) == "s3_tall_pipe":
			all_pipes.append(sp_d)
	for ep_var in eng.entities:
		var ep_d: Dictionary = ep_var
		if str(ep_d.get("t", "")) == "s3_suction_pipe":
			all_pipes.append(ep_d)
	eng.world_state.recompute_water_pressure(eng.s3_valves, all_pipes)

	# Lv118: Optional water-flow gravity sync
	if bool(e.get("flipFlowGravity", false)):
		eng.world_state.water_flow_dir = -eng.world_state.water_flow_dir
		eng.player["grav_dir"] = -1.0 if eng.world_state.water_flow_dir < 0 else 1.0
		eng.world_state.set_gravity_vector(Vector2(0.0, float(eng.player["grav_dir"])))

	if eng.has_method("fire_logic_event"):
		eng.fire_logic_event(str(e.get("uuid", "")), "on_valve", { "pipe_group": pgrp })

	var hit_boss120: bool = false
	if pgrp.begins_with("boss120"):
		if eng.boss_sm != null:
			eng.boss_sm.on_puzzle_event(eng, "bottom_relief_vented", {})
		for b_var in eng.entities:
			var b_ent: Dictionary = b_var
			if str(b_ent.get("t", "")) == "s3_boss" and ("120" in str(b_ent.get("boss_kind", "")) or "pipe_kaiser" in str(b_ent.get("boss_kind", ""))):
				b_ent["stun_timer"] = 4.6
				e["reset_timer"] = 5.2
				hit_boss120 = true
	if hit_boss120:
		eng.emit_toast("红阀门泄压成功 · 巨管九头蛇破甲眩晕 4.6s！快砍！", "PRESSURE VENTED · PIPE-HYDRA STUNNED!", "s3_valve_red", "#4ade80")
	else:
		eng.emit_toast("红手轮阀门已拧开 · 关联绿管水压已切换！", "RED VALVE SPUN · PIPE PRESSURE SHIFTED!", "s3_valve_red", "#4ade80")

static func step_pre_move(eng: RefCounted, dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)):
		return

	if float(p.get("golden_timer", 0.0)) > 0.0:
		p["golden_timer"] = maxf(0.0, float(p["golden_timer"]) - dt)
		p["invuln_timer"] = maxf(float(p.get("invuln_timer", 0.0)), float(p["golden_timer"]))
		if randf() < 0.35:
			eng.spawn_particles(float(p["x"]) + randf() * float(p["w"]), float(p["y"]) + randf() * float(p["h"]), Color("#fde047"), 1)

	if float(p.get("catapult_vx_timer", 0.0)) > 0.0:
		p["catapult_vx_timer"] = maxf(0.0, float(p["catapult_vx_timer"]) - dt)
		p["vx"] = float(p.get("catapult_vx", p["vx"]))

	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))

	for s_var in eng.solids:
		var s: Dictionary = s_var
		var st: String = str(s.get("t", ""))
		if not Sector1And2Mechanics.is_in_active_layer(s, eng.active_layer):
			continue

		if st == "tanuki_log" and bool(s.get("pushable", true)):
			var tl_push: Rect2 = Rect2(float(s["x"]) - 4.0, float(s["y"]) + 4.0, float(s["w"]) + 8.0, float(s["h"]) - 8.0)
			if GridMath.aabb_overlap(p_rect, tl_push) and absf(float(p["vx"])) > 20.0:
				s["x"] = float(s["x"]) + signf(float(p["vx"])) * 130.0 * dt

		elif st == "s3_tall_pipe":
			var pgrp: String = str(s.get("pipe_group", ""))
			var want_low: bool = bool(eng.s3_valves.get(pgrp, false))
			if str(s.get("mode", "")) == "sundial_alt":
				want_low = (not eng.s3_sundial_phase) if bool(s.get("invert_sundial", false)) else eng.s3_sundial_phase
			var goal_h: float = float(s["target_h_px"]) if want_low else float(s["orig_h_px"])
			if absf(float(s["h"]) - goal_h) > 0.5:
				var prev_y: float = float(s["y"])
				var step_h: float = signf(goal_h - float(s["h"])) * minf(absf(goal_h - float(s["h"])), 280.0 * world_dt)
				s["h"] = float(s["h"]) + step_h
				s["y"] = float(s["foot_y"]) - float(s["h"])
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_y) <= 12.0:
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_y)
			s["lowered"] = float(s["h"]) <= float(s["target_h_px"]) + 4.0

			if float(s.get("rocket_cd", 0.0)) > 0.0:
				s["rocket_cd"] = maxf(0.0, float(s["rocket_cd"]) - world_dt)
			if str(s.get("mode", "")) == "rocket" and not want_low and float(s.get("rocket_cd", 0.0)) <= 0.0:
				var over_mouth: bool = (float(p["x"]) + float(p["w"]) > float(s["x"]) + 4.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) - 4.0) and (float(p["y"]) + float(p["h"]) <= float(s["y"]) + 18.0) and (float(p["y"]) + float(p["h"]) >= float(s["y"]) - 78.0)
				if over_mouth:
					s["rocket_cd"] = 0.55
					p["vy"] = -785.0
					p["on_ground"] = false
					p["coyote"] = 0.0
					p["spring_trail_timer"] = 0.46
					eng.spring_impulse_scale(0.72, 1.34)
					eng.emit_sfx("spring")
					eng.add_shock_ring(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]), Color("#38bdf8"), 42.0, 0.25)
					eng.emit_toast("高压喷泉绿管 · 冲天水柱弹射！", "PRESSURIZED WATER GEYSER!", "s3_pipe_tall", "#38bdf8")

			if str(s.get("mode", "")) == "lethal_drop" and not bool(s["lowered"]):
				if float(p["x"]) >= float(s["x"]) + float(s["w"]) - 2.0 and float(p["x"]) <= float(s["x"]) + float(s["w"]) + 36.0 and float(p["vy"]) > 510.0 and float(p["y"]) > float(s["foot_y"]) - 96.0:
					eng.kill_player(false, "tall_pipe")
					return

		elif st == "s3_cloud":
			if float(s.get("step_cue_cd", 0.0)) > 0.0:
				s["step_cue_cd"] = maxf(0.0, float(s["step_cue_cd"]) - dt)
			if float(s.get("thunder_frozen_timer", 0.0)) > 0.0:
				s["thunder_frozen_timer"] = maxf(0.0, float(s["thunder_frozen_timer"]) - world_dt)
			if bool(s.get("broken", false)):
				if float(s.get("respawn_timer", 0.0)) > 0.0:
					s["respawn_timer"] = float(s["respawn_timer"]) - world_dt
					if float(s["respawn_timer"]) <= 0.0:
						s["broken"] = false
				continue
			var safe_now: bool = is_cloud_safe(s, eng.s3_sundial_phase)
			var prev_cy: float = float(s["y"])
			var cmode: String = str(s.get("mode", ""))
			if cmode == "swoop_cloud" and not safe_now:
				var dx_c: float = absf(p_rect.get_center().x - (float(s["x"]) + float(s["w"]) * 0.5))
				if not bool(s.get("swooping", false)) and dx_c < 2.0 * GridMath.TILE and float(p["y"]) > float(s["y"]):
					s["swooping"] = true
					eng.emit_sfx("cloud_blade")
				if bool(s.get("swooping", false)):
					s["y"] = float(s["y"]) + 330.0 * world_dt
					# Lv102: Swooping thunder cloud solidifies hollow fake_clouds upon collision!
					for oth_c_var in eng.solids:
						var oth_c: Dictionary = oth_c_var
						if oth_c != s and str(oth_c.get("t", "")) == "s3_cloud" and str(oth_c.get("mode", "")) == "fake_cloud":
							if GridMath.aabb_overlap(Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])), Rect2(float(oth_c["x"]), float(oth_c["y"]), float(oth_c["w"]), float(oth_c["h"]))):
								oth_c["broken"] = false
								oth_c["thunder_frozen_timer"] = 3.8
								eng.emit_sfx("cloud_solid")
					if float(s["y"]) > GridMath.WORLD_ORIGIN_Y + 80.0:
						s["y"] = float(s["base_y"])
						s["swooping"] = false
			else:
				s["y"] = float(s["base_y"]) + sin(eng.time_elapsed * 2.6 + float(s["x"]) * 0.03) * 3.5
				if safe_now and float(p["grav_dir"]) > 0.0 and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_cy) <= 10.0:
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_cy)
					if cmode == "bounce":
						p["vy"] = -735.0
						p["on_ground"] = false
						p["spring_trail_timer"] = 0.40
						eng.emit_sfx("cloud_bounce")
					elif float(s.get("step_cue_cd", 0.0)) <= 0.0:
						s["step_cue_cd"] = 0.9
						eng.emit_sfx("cloud_solid")

			if not safe_now and (cmode == "hidden_knife" or cmode == "sundial_knife"):
				var dc: float = p_rect.get_center().distance_to(Vector2(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + float(s["h"]) * 0.5))
				if dc < 1.9 * GridMath.TILE:
					if not bool(s.get("blades_out", false)):
						eng.emit_sfx("cloud_blade")
					s["blades_out"] = true
				if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 8.0, float(s["y"]) - 2.0, float(s["w"]) - 16.0, float(s["h"]) + 4.0)):
					s["blades_out"] = true
					eng.kill_player(false, "cloud_knife")
					return
			elif not safe_now and cmode == "swoop_cloud":
				if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 8.0, float(s["y"]) + 4.0, float(s["w"]) - 16.0, float(s["h"]) - 6.0)):
					eng.kill_player(false, "cloud_knife")
					return
			elif cmode == "fake_cloud" and float(s.get("thunder_frozen_timer", 0.0)) <= 0.0:
				if float(p["vy"]) >= 0.0 and GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 4.0, float(s["y"]) - 6.0, float(s["w"]) - 8.0, 16.0)):
					s["broken"] = true
					s["respawn_timer"] = 2.5
					eng.emit_sfx("cloud_hollow")
					eng.spawn_particles(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + 12.0, Color("#ffffff"), 14)
					eng.emit_toast("虚胖棉花假云 · 一踩就散！", "POOF! FAKE COTTON CLOUD!", "s3_cloud_safe", "#93c5fd")

		elif st == "s3_drop_block":
			if bool(s.get("broken", false)):
				s["respawn_timer"] = float(s.get("respawn_timer", 0.0)) - world_dt
				if float(s["respawn_timer"]) <= 0.0 and not GridMath.aabb_overlap(p_rect, Rect2(float(s["base_x"]), float(s["base_y"]), float(s["w"]), float(s["h"]))):
					s["broken"] = false
					s["x"] = float(s["base_x"])
					s["y"] = float(s["base_y"])
					s["drop_state"] = "idle"
					s["vy"] = 0.0
				continue
			var dst: String = str(s.get("drop_state", "idle"))
			if dst == "idle":
				if bool(s.get("stay_solid", true)):
					var near_x: bool = (float(p["x"]) + float(p["w"]) > float(s["x"]) - 24.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) + 24.0)
					var trig: bool = (near_x and float(p["y"]) <= float(s["y"])) if bool(s.get("rise_trap", false)) else (near_x and float(p["y"]) > float(s["y"]))
					if trig:
						s["drop_state"] = "shake"
						s["timer"] = 0.18
						eng.emit_sfx("block")
				else:
					var stood: bool = bool(p["on_ground"]) and (float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0) and (float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0) and absf((float(p["y"]) + float(p["h"])) - float(s["y"])) <= 9.0
					if stood:
						s["drop_state"] = "shake"
						s["timer"] = 0.28
						eng.emit_sfx("block")
			elif dst == "shake":
				s["timer"] = float(s["timer"]) - world_dt
				if float(s["timer"]) <= 0.0:
					s["drop_state"] = "fall"
					s["vy"] = -460.0 if bool(s.get("rise_trap", false)) else 60.0
			elif dst == "fall":
				var prev_dy: float = float(s["y"])
				if bool(s.get("rise_trap", false)) or float(s["vy"]) < -10.0:
					s["y"] = prev_dy + float(s["vy"]) * world_dt
					var ceil_y: float = GridMath.gy_to_py(6.2, 0.0)
					if float(s["y"]) <= ceil_y:
						s["y"] = ceil_y
						s["drop_state"] = "landed"
				else:
					s["vy"] = minf(720.0, float(s["vy"]) + 1500.0 * world_dt)
					s["y"] = prev_dy + float(s["vy"]) * world_dt
					if bool(s.get("stay_solid", true)):
						var floor_y: float = GridMath.gy_to_py(2.0, 0.0) - float(s["h"])
						if GridMath.aabb_overlap(p_rect, Rect2(float(s["x"]) + 6.0, float(s["y"]) + float(s["h"]) - 14.0, float(s["w"]) - 12.0, 16.0)) and float(p["y"]) > prev_dy:
							eng.kill_player(false, "crush")
							return
						if float(s["y"]) >= floor_y:
							s["y"] = floor_y
							s["drop_state"] = "landed"
							eng.emit_sfx("boom")
							eng.trigger_shake(4.5, 0.14)
					elif float(s["y"]) > GridMath.WORLD_ORIGIN_Y + 110.0:
						s["broken"] = true
						s["respawn_timer"] = 2.6

		elif st == "s3_slide_turf":
			var dist_st: float = absf(p_rect.get_center().x - (float(s["x"]) + float(s["w"]) * 0.5))
			if not bool(s.get("triggered", false)) and dist_st < float(s["trigger_dist_px"]) + float(s["w"]) * 0.5:
				s["triggered"] = true
				eng.emit_sfx("spring")
			if bool(s.get("triggered", false)):
				var target_stx: float = float(s["base_x"]) + float(s["slide_dx_px"])
				var target_sty: float = float(s["base_y"]) - float(s["slide_dy_px"])
				var prev_stx: float = float(s["x"])
				var prev_sty: float = float(s["y"])
				var diff_stx: float = target_stx - prev_stx
				var diff_sty: float = target_sty - prev_sty
				if absf(diff_stx) > 0.5:
					s["x"] = prev_stx + signf(diff_stx) * minf(absf(diff_stx), 295.0 * world_dt)
				if absf(diff_sty) > 0.5:
					s["y"] = prev_sty + signf(diff_sty) * minf(absf(diff_sty), 240.0 * world_dt)
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > prev_stx + 2.0 and float(p["x"]) < prev_stx + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - prev_sty) <= 10.0:
					p["x"] = float(p["x"]) + (float(s["x"]) - prev_stx)
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_sty)
					p_rect.position = Vector2(float(p["x"]), float(p["y"]))

static func detonate_trophy_bomb(eng: RefCounted, e: Dictionary) -> void:
	var cx: float = float(e["x"]) + float(e["w"]) * 0.5
	var cy: float = float(e["y"]) + float(e["h"]) * 0.5
	var r: float = 148.0
	eng.emit_sfx("boom")
	eng.trigger_shake(8.0, 0.26)
	eng.add_shock_ring(cx, cy, Color("#fb923c"), r, 0.34)
	eng.spawn_particles(cx, cy, Color("#fde047"), 26)
	for s_var in eng.solids:
		var s: Dictionary = s_var
		if str(s.get("t", "")) == "destructible" and not bool(s.get("broken", false)):
			var sc: Vector2 = Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])).get_center()
			if sc.distance_to(Vector2(cx, cy)) <= r + maxf(float(s["w"]), float(s["h"])) * 0.5:
				s["broken"] = true
				eng.broken_solid_keys[str(s["key"])] = true
				eng.spawn_particles(sc.x, sc.y, Color("#fb923c"), 18)
	disarm_or_damage_targets(eng, Rect2(cx - r, cy - r, r * 2.0, r * 2.0), 6, true, true)
	if not eng.player.is_empty() and not bool(eng.player.get("dead", false)):
		var pc: Vector2 = Vector2(float(eng.player["x"]) + 14.0, float(eng.player["y"]) + 20.0)
		if pc.distance_to(Vector2(cx, cy)) < 68.0:
			eng.kill_player(false, "trophy_bomb")
	eng.s3_trophy_respawns.append({
		"timer": 3.6,
		"spawn_x": float(e.get("spawn_x", e["x"])),
		"spawn_y": float(e.get("spawn_y", e["y"]))
	})

static func disarm_or_damage_targets(eng: RefCounted, hit_box: Rect2, dmg: int, is_sword: bool, is_upgraded_proj: bool) -> bool:
	var hit_any: bool = false

	if is_sword or is_upgraded_proj or true:
		for s_var in eng.solids:
			var s: Dictionary = s_var
			if str(s.get("t", "")) == "s3_cloud" and not bool(s.get("broken", false)) and not bool(s.get("disarmed", false)):
				var cm: String = str(s.get("mode", ""))
				var allow_disarm: bool = is_sword or is_upgraded_proj or bool(s.get("brittle_core", false))
				if allow_disarm and cm in ["hidden_knife", "swoop_cloud", "sundial_knife"]:
					if GridMath.aabb_overlap(hit_box, Rect2(float(s["x"]) - 4.0, float(s["y"]) - 8.0, float(s["w"]) + 8.0, float(s["h"]) + 16.0)):
						s["disarmed"] = true
						s["blades_out"] = false
						s["swooping"] = false
						s["y"] = float(s["base_y"])
						eng.emit_sfx("enemy_kill")
						if eng.boss_sm != null and str(eng.boss_sm.state.get("boss_key", "")) == "lv140_thunder_demon":
							eng.boss_sm.on_puzzle_event(eng, "cloud_shaved", {})
						if eng.save != null:
							eng.save.add_coins(2)
						eng.add_float_text(float(s["x"]) + 12.0, float(s["y"]) - 10.0, "卸刀 +2G", "#4ade80")
						eng.hud_dirty = true
						hit_any = true

	for i in range(eng.entities.size() - 1, -1, -1):
		if i >= eng.entities.size():
			continue
		var e: Dictionary = eng.entities[i]
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x <= 0.0 or not GridMath.aabb_overlap(hit_box, er):
			continue
		var et: String = str(e.get("t", ""))

		if et == "s3_valve":
			e["spin_ang"] = float(e.get("spin_ang", 0.0)) + 1.8
			activate_valve(eng, e)
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_sundial":
			if float(e.get("hit_cd", 0.0)) <= 0.0:
				e["hit_cd"] = 0.32
				var next_phase_name: String = eng.world_state.advance_sundial_phase(1)
				eng.s3_sundial_phase = (next_phase_name != WorldState.PHASE_DAY)
				eng.emit_sfx("sundial_shift")
				eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#fde047"), 52.0, 0.28)
				var zh_phase: String = "【白昼】" if next_phase_name == "day" else ("【黄昏/日落】" if next_phase_name == "dusk" else "【暗夜】")
				eng.emit_toast(
					"☀ 日晷流转至" + zh_phase + " · 阴阳云管与影长已切换！",
					"SUNDIAL PHASE: " + next_phase_name.to_upper() + "!",
					"s3_sundial_orb", "#fde047"
				)
				if eng.has_method("fire_logic_event"):
					eng.fire_logic_event(str(e.get("uuid", "")), "on_activate", { "phase": next_phase_name })
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_bomb_trophy":
			if float(e.get("fuse", -1.0)) < 0.0:
				e["fuse"] = 0.75
				eng.emit_sfx("fake_win")
				eng.emit_toast("● 伪奖杯引信已点燃 · 快退后等它炸墙！", "TROPHY BOMB LIT · STEP BACK!", "s3_bomb_trophy", "#fb923c")
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_mimic_flag":
			if is_sword and not bool(e.get("tamed", false)):
				e["hp"] = int(e.get("hp", 2)) - 1
				e["awake"] = true
				eng.emit_sfx("block")
				if int(e["hp"]) <= 0:
					if str(e.get("mode", "")) == "tame_goal":
						e["tamed"] = true
						eng.emit_sfx("real_win")
						eng.emit_toast("★ 噬人伪旗已被破魔剑驯服为真终点旗！", "MIMIC FLAG TAMED INTO REAL GOAL!", "s3_flag_win", "#4ade80")
					else:
						if eng.save != null:
							eng.save.add_coins(4)
						eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "斩伪旗 +4G", "#fde047")
						eng.entities.remove_at(i)
						eng.hud_dirty = true
				hit_any = true
		elif et == "s3_bush" and str(e.get("mode", "")) != "safe":
			if is_sword:
				if str(e.get("mode", "")) == "reflect_clip":
					eng.enemy_shots.append({
						"x": float(e["x"]) + float(e["w"]) * 0.5,
						"y": float(e["y"]) + 10.0,
						"w": 16.0, "h": 12.0,
						"vx": (-1.0 if float(eng.player.get("x", 0.0)) > float(e["x"]) else 1.0) * -230.0,
						"vy": -60.0, "color": "#fb7185", "layer": -1, "life": 1.8
					})
					eng.emit_sfx("cloud_blade")
				else:
					eng.emit_sfx("enemy_kill")
					if eng.save != null:
						eng.save.add_coins(2)
					eng.add_float_text(float(e["x"]) + 16.0, float(e["y"]) - 8.0, "除草 +2G", "#fde047")
					eng.entities.remove_at(i)
					eng.hud_dirty = true
				hit_any = true
		elif et == "s3_flower":
			var fmode_d: String = str(e.get("mode", ""))
			if fmode_d == "polite" or fmode_d == "polite_reflect":
				e["mode"] = "lunge"
				e["angry"] = true
				eng.emit_sfx("poison")
				eng.emit_toast("糟糕！你激怒了讲礼貌的守卫粉花！", "PROVOKED THE POLITE FLOWER!", "s3_pink_flower_angry", "#fb7185")
				hit_any = true
			else:
				e["hp"] = int(e.get("hp", 2)) - dmg
				if int(e["hp"]) <= 0:
					eng.emit_sfx("enemy_kill")
					if eng.save != null:
						eng.save.add_coins(3)
					eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "KO +3G", "#fde047")
					eng.entities.remove_at(i)
					eng.hud_dirty = true
				else:
					eng.emit_sfx("block")
				hit_any = true
				if not is_sword:
					break
		elif et == "s3_tanuki":
			if bool(e.get("is_clone", false)):
				eng.emit_sfx("block")
				var crouched: bool = bool(eng.player.get("crouching", false))
				var log_w: float = 68.0 if crouched else 46.0
				var log_h: float = 30.0 if crouched else 48.0
				eng.solids.append({
					"uuid": "tanuki_log_" + str(Time.get_ticks_msec()) + "_" + str(i),
					"key": "tanuki_log_" + str(Time.get_ticks_msec()) + "_" + str(i),
					"t": "tanuki_log", "skin": "tanuki_log",
					"x": float(e["x"]) + 2.0,
					"y": float(e["base_y"]) + float(e["h"]) - log_h,
					"base_x": float(e["x"]) + 2.0,
					"base_y": float(e["base_y"]) + float(e["h"]) - log_h,
					"w": log_w, "h": log_h,
					"pushable": true,
					"move_dx_px": 0.0, "move_dy_px": 0.0, "move_speed": 0.0,
					"layer": -1, "broken": false, "revealed": true
				})
				eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "横替身木桩!" if crouched else "替身木桩!", "#fde047")
				eng.entities.remove_at(i)
			else:
				e["hp"] = int(e.get("hp", 3)) - dmg
				if int(e["hp"]) <= 0:
					eng.emit_sfx("enemy_kill")
					if eng.save != null:
						eng.save.add_coins(4)
					eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "真身破 +4G", "#4ade80")
					eng.entities.remove_at(i)
					eng.hud_dirty = true
				else:
					eng.emit_sfx("block")
			hit_any = true
			if not is_sword:
				break
		elif et in ["s3_manju", "s3_ladybug", "s3_mole"]:
			e["hp"] = int(e.get("hp", 2)) - dmg
			if int(e["hp"]) <= 0:
				eng.emit_sfx("enemy_kill")
				if eng.save != null:
					eng.save.add_coins(3)
				eng.add_float_text(float(e["x"]), float(e["y"]) - 10.0, "KO +3G", "#4ade80")
				eng.entities.remove_at(i)
				eng.hud_dirty = true
			else:
				eng.emit_sfx("block")
			hit_any = true
			if not is_sword:
				break
		elif et == "s3_boss":
			if eng.boss_sm != null and bool(eng.boss_sm.state.get("active", false)):
				var blocked_by_sm: bool = eng.boss_sm.on_boss_hit(eng, e, dmg, {
					"is_melee": is_sword,
					"reflected": false
				})
				if blocked_by_sm:
					hit_any = true
					break
			var eff_dmg: int = dmg
			if ("pipe_kaiser" in str(e.get("boss_kind", "")) or "120" in str(e.get("boss_kind", ""))) and float(e.get("stun_timer", 0.0)) <= 0.0:
				eff_dmg = maxi(1, int(floor(float(dmg) * 0.35)))
				eng.emit_toast("巨管九头蛇护甲减伤中 · 打两侧红阀门泄压破防！", "SPIN RED VALVES TO STUN!", "s3_valve_red", "#fde047")
			e["hp"] = int(e.get("hp", 26)) - eff_dmg
			if eng.boss_sm != null and bool(eng.boss_sm.state.get("active", false)):
				eng.boss_sm.state["boss_hp"] = maxi(0, int(e["hp"]))
			e["hit_flash"] = 0.16
			eng.emit_sfx("block")
			eng.add_float_text(float(e["x"]) + float(e["w"]) * 0.4, float(e["y"]) - 10.0, "-%d" % eff_dmg, "#fde047")
			if int(e["hp"]) <= 0:
				eng.s3_boss_defeated = true
				if eng.boss_sm != null and bool(eng.boss_sm.state.get("active", false)):
					eng.boss_sm.state["defeated"] = true
				eng.emit_sfx("real_win")
				eng.trigger_shake(9.0, 0.32)
				if eng.save != null:
					eng.save.add_coins(30)
				eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#fde047"), 96.0, 0.45)
				eng.spawn_particles(er.get_center().x, er.get_center().y, Color("#fde047"), 34)
				eng.add_float_text(float(e["x"]) + 12.0, float(e["y"]) - 20.0, "BOSS CLEAR +30G!", "#fde047")
				eng.emit_toast("守关巨兽已击溃 · 右侧凯旋终点旗已解封！", "BOSS DEFEATED · FLAG UNLOCKED!", "s3_flag_win", "#4ade80")
				eng.entities.remove_at(i)
				eng.hud_dirty = true
			hit_any = true
			if not is_sword:
				break
	return hit_any

static func step_post_move(eng: RefCounted, _dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)) or eng.world_frozen:
		return

	for ri in range(eng.s3_trophy_respawns.size() - 1, -1, -1):
		var tr: Dictionary = eng.s3_trophy_respawns[ri]
		tr["timer"] = float(tr["timer"]) - world_dt
		if float(tr["timer"]) <= 0.0:
			var sx0: float = float(tr["spawn_x"])
			var sy0: float = float(tr["spawn_y"])
			var still_blocked: bool = false
			for s_check_var in eng.solids:
				var s_check: Dictionary = s_check_var
				if str(s_check.get("t", "")) == "destructible" and not bool(s_check.get("broken", false)) and absf(float(s_check["x"]) - sx0) < 260.0:
					still_blocked = true
					break
			if still_blocked:
				eng.entities.append({
					"uuid": "respawn_trophy_" + str(Time.get_ticks_msec()),
					"key": "respawn_trophy_" + str(Time.get_ticks_msec()),
					"t": "s3_bomb_trophy",
					"x": sx0, "y": sy0, "spawn_x": sx0, "spawn_y": sy0,
					"w": 1.05 * GridMath.TILE, "h": 1.15 * GridMath.TILE,
					"fuse": -1.0, "layer": -1
				})
			eng.s3_trophy_respawns.remove_at(ri)

	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))

	for i in range(eng.entities.size() - 1, -1, -1):
		if i >= eng.entities.size():
			continue
		var e: Dictionary = eng.entities[i]
		if not Sector1And2Mechanics.is_in_active_layer(e, eng.active_layer):
			continue
		var et: String = str(e.get("t", ""))
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))

		if et == "s3_valve":
			if float(e.get("reset_timer", 0.0)) > 0.0:
				e["reset_timer"] = float(e["reset_timer"]) - world_dt
				if float(e["reset_timer"]) <= 0.0:
					e["spun"] = false
			if GridMath.aabb_overlap(p_rect, er):
				activate_valve(eng, e)
		elif et == "s3_sundial":
			if float(e.get("hit_cd", 0.0)) > 0.0:
				e["hit_cd"] = maxf(0.0, float(e["hit_cd"]) - world_dt)
		elif et == "s3_catapult":
			if float(e.get("cd", 0.0)) > 0.0:
				e["cd"] = maxf(0.0, float(e["cd"]) - world_dt)
			if float(e.get("anim", 0.0)) > 0.0:
				e["anim"] = maxf(0.0, float(e["anim"]) - world_dt * 3.0)
			if float(e.get("cd", 0.0)) <= 0.0 and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 4.0, float(e["y"]) - 6.0, float(e["w"]) - 8.0, float(e["h"]) + 8.0)):
				e["cd"] = 0.45
				e["anim"] = 1.0
				eng.emit_sfx("spring")
				eng.trigger_shake(5.0, 0.16)
				eng.add_shock_ring(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]), Color("#fde047"), 42.0, 0.25)
				eng.spring_impulse_scale(0.70, 1.36)
				p["y"] = minf(float(p["y"]), float(e["y"]) - float(p["h"]) + 8.0)
				p["on_ground"] = false
				p["coyote"] = 0.0
				p["spring_trail_timer"] = 0.48
				var cm: String = str(e.get("mode", "forward_vault"))
				if cm == "back_fling":
					p["vy"] = -835.0
					p["catapult_vx"] = -455.0
					p["catapult_vx_timer"] = 0.48
					p["spring_trail_timer"] = 0.54
					eng.emit_toast("反向木夹弹射 · 嗖地把你往后高抛！", "REVERSE CATAPULT FLING!", "s3_catapult_trap", "#fb923c")
				elif cm == "high_secret":
					p["vy"] = -935.0
					p["spring_trail_timer"] = 0.56
					eng.emit_toast("强力木夹冲天弹射！", "SKYWARD CATAPULT LAUNCH!", "s3_catapult_trap", "#4ade80")
				else:
					p["vy"] = -845.0
					p["catapult_vx"] = 515.0
					p["catapult_vx_timer"] = 0.88
					p["spring_trail_timer"] = 0.56
					eng.emit_toast("飞跃木夹助推 · 横跨大峡谷！", "LONG-JUMP CATAPULT BOOST!", "s3_catapult_trap", "#38bdf8")
		elif et == "s3_bomb_trophy":
			var fuse: float = float(e.get("fuse", -1.0))
			if fuse < 0.0 and GridMath.aabb_overlap(p_rect, er):
				e["fuse"] = 0.90
				eng.emit_sfx("fake_win")
				eng.emit_toast("● 假奖杯炸弹已引燃 · 0.9秒后爆炸，快闪开！", "TROPHY BOMB LIT · RUN BACK!", "s3_bomb_trophy", "#fb923c")
			elif fuse >= 0.0:
				fuse -= world_dt
				e["fuse"] = fuse
				if fuse <= 0.0:
					var dead_e: Dictionary = e.duplicate(true)
					eng.entities.remove_at(i)
					detonate_trophy_bomb(eng, dead_e)
					if bool(p.get("dead", false)):
						return
		elif et == "s3_suction_pipe":
			var pgrp_s: String = str(e.get("pipe_group", ""))
			var shut_off: bool = (pgrp_s != "" and bool(eng.s3_valves.get(pgrp_s, false))) or bool(e.get("stone_plugged", false))
			if not shut_off:
				# Lv111: Check if a wood_crate / drop_block plugs the suction mouth!
				var mouth_r: Rect2 = Rect2(float(e["x"]) + 4.0, float(e["y"]) + float(e["h"]) - 28.0, float(e["w"]) - 8.0, 34.0)
				for sc_var in eng.solids:
					var sc_d: Dictionary = sc_var
					if str(sc_d.get("t", "")) in ["wood_crate", "s3_drop_block", "tanuki_log"] and GridMath.aabb_overlap(mouth_r, Rect2(float(sc_d["x"]), float(sc_d["y"]), float(sc_d["w"]), float(sc_d["h"]))):
						e["stone_plugged"] = true
						eng.emit_sfx("valve_turn")
						break
				if not bool(e["stone_plugged"]):
					var in_beam: bool = (float(p["x"]) + float(p["w"]) > float(e["x"]) - 10.0) and (float(p["x"]) < float(e["x"]) + float(e["w"]) + 10.0) and (float(p["y"]) > float(e["y"])) and (float(p["y"]) < float(e["y"]) + float(e["h"]) + 4.2 * GridMath.TILE)
					if in_beam:
						var pull_mul: float = 0.35 if bool(p.get("wings_folded", false)) else 1.0
						p["vy"] = float(p["vy"]) - 2150.0 * pull_mul * world_dt
						p["on_ground"] = false
						if not bool(p.get("wings_folded", false)) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + float(e["h"]) - 22.0, float(e["w"]) - 16.0, 26.0)):
							eng.kill_player(false, "suction_pipe")
							return
		elif et == "s3_mimic_flag":
			if bool(e.get("tamed", false)):
				if GridMath.aabb_overlap(p_rect, er):
					eng.trigger_level_win()
					return
				continue
			var dx_mf: float = p_rect.get_center().x - er.get_center().x
			if absf(dx_mf) < 2.6 * GridMath.TILE:
				if not bool(e.get("awake", false)):
					e["awake"] = true
					eng.emit_sfx("poison")
				var f_dir: float = -signf(dx_mf) if str(e.get("mode", "")) == "fleeing" else signf(dx_mf)
				e["x"] = float(e["x"]) + f_dir * 95.0 * world_dt
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 10.0, float(e["y"]) + 10.0, float(e["w"]) - 20.0, float(e["h"]) - 14.0)):
				eng.kill_player(false, "mimic_flag")
				return
		elif et == "s3_bush":
			var dx_b: float = p_rect.get_center().x - er.get_center().x
			var dist_b: float = p_rect.get_center().distance_to(er.get_center())
			var bmode: String = str(e.get("mode", "ambush_blade"))
			if bmode == "ambush_blade" or bmode == "reflect_clip":
				if dist_b < 1.6 * GridMath.TILE:
					e["revealed"] = true
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 10.0, float(e["w"]) - 28.0, float(e["h"]) - 12.0)):
					e["revealed"] = true
					eng.kill_player(false, "bush_blade")
					return
			elif bmode == "stalk_bush":
				var looking_at: bool = GridMath.is_player_looking_at(p_rect.get_center(), int(p["facing"]), er, 340.0)
				if not looking_at and absf(dx_b) < 6.8 * GridMath.TILE:
					e["x"] = float(e["x"]) + signf(dx_b) * 140.0 * world_dt
					e["revealed"] = true
				else:
					e["revealed"] = false
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 16.0, float(e["y"]) + 12.0, float(e["w"]) - 32.0, float(e["h"]) - 14.0)):
					e["revealed"] = true
					eng.kill_player(false, "bush_blade")
					return
		elif et == "s3_flower":
			var dx_f: float = p_rect.get_center().x - er.get_center().x
			var abs_dxf: float = absf(dx_f)
			var fmode: String = str(e.get("mode", "lunge"))
			if fmode == "lunge":
				if abs_dxf < 3.9 * GridMath.TILE and absf(float(p["y"]) - float(e["y"])) < 92.0:
					e["angry"] = true
					e["x"] = float(e["x"]) + signf(dx_f) * 255.0 * world_dt
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 8.0, float(e["w"]) - 18.0, float(e["h"]) - 10.0)):
					eng.kill_player(false, "flower")
					return
			elif fmode == "jump_block" or fmode == "predictive":
				if not bool(p["on_ground"]) and float(p["vy"]) < -120.0 and abs_dxf < 4.3 * GridMath.TILE and absf(float(e["y"]) - float(e["base_y"])) < 5.0:
					e["angry"] = true
					e["vy"] = -565.0
					if fmode == "predictive":
						e["x"] = float(e["x"]) + clampf(float(p["vx"]) * 0.22, -64.0, 64.0)
				e["vy"] = float(e.get("vy", 0.0)) + 1300.0 * world_dt
				e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
				if float(e["y"]) >= float(e["base_y"]):
					e["vy"] = 0.0
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 8.0, float(e["w"]) - 18.0, float(e["h"]) - 10.0)):
					eng.kill_player(false, "flower")
					return
			elif fmode == "polite" or fmode == "polite_reflect":
				if not bool(e.get("rewarded", false)) and float(p["x"]) > float(e["x"]) + float(e["w"]) + 24.0:
					e["rewarded"] = true
					if eng.save != null:
						eng.save.add_coins(5)
					eng.emit_sfx("coin")
					eng.add_float_text(float(e["x"]), float(e["y"]) - 12.0, "礼貌奖励 +5G!", "#4ade80")
					eng.hud_dirty = true
		elif et == "s3_tanuki":
			var dx_t: float = p_rect.get_center().x - er.get_center().x
			if not bool(e.get("cloned", false)) and not bool(e.get("is_clone", false)) and absf(dx_t) < 5.6 * GridMath.TILE:
				e["cloned"] = true
				eng.emit_sfx("spring")
				var cnt_cl: int = int(e.get("clones", 2))
				for c_i in range(1, cnt_cl + 1):
					var off_dir: float = 54.0 if (c_i % 2) == 0 else -54.0
					var mult_i: float = ceil(float(c_i) * 0.5)
					eng.entities.append({
						"uuid": str(e["key"]) + "_clone_" + str(c_i),
						"key": str(e["key"]) + "_clone_" + str(c_i),
						"t": "s3_tanuki",
						"x": float(e["x"]) + off_dir * mult_i,
						"y": float(e["y"]),
						"spawn_x": float(e["x"]), "base_y": float(e["base_y"]),
						"w": float(e["w"]), "h": float(e["h"]),
						"hp": 1, "max_hp": 1,
						"cloned": true, "is_clone": true,
						"vx": 75.0 if (c_i % 2) == 0 else -75.0,
						"vy": -180.0, "layer": -1
					})
			e["vy"] = float(e.get("vy", 0.0)) + 1200.0 * world_dt
			e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
			if float(e["y"]) >= float(e["base_y"]):
				e["vy"] = 0.0
			e["x"] = float(e["x"]) + float(e.get("vx", -60.0)) * world_dt
			if absf(float(e["x"]) - float(e["spawn_x"])) > 2.6 * GridMath.TILE:
				e["vx"] = -float(e.get("vx", -60.0))
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 9.0, float(e["y"]) + 9.0, float(e["w"]) - 18.0, float(e["h"]) - 11.0)):
				eng.kill_player(false, "tanuki")
				return
		elif et == "s3_manju":
			var dx_mj: float = p_rect.get_center().x - er.get_center().x
			if bool(e.get("waiting_drop", false)):
				if absf(dx_mj) < 2.2 * GridMath.TILE:
					e["waiting_drop"] = false
				else:
					continue
			if str(e.get("mode", "")) == "spike_morph" and not bool(p["on_ground"]) and absf(dx_mj) < 3.5 * GridMath.TILE and absf(float(e["y"]) - float(e["base_y"])) < 5.0:
				e["spiked"] = true
				e["vy"] = -490.0
			e["vy"] = float(e.get("vy", 0.0)) + 1280.0 * world_dt
			e["y"] = minf(float(e["base_y"]), float(e["y"]) + float(e["vy"]) * world_dt)
			if float(e["y"]) >= float(e["base_y"]):
				e["vy"] = 0.0
			e["x"] = float(e["x"]) + float(e.get("vx", -85.0)) * world_dt
			if absf(float(e["x"]) - float(e["spawn_x"])) > 3.2 * GridMath.TILE:
				e["vx"] = -float(e.get("vx", -85.0))
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 7.0, float(e["w"]) - 14.0, float(e["h"]) - 9.0)):
				eng.kill_player(false, "manju")
				return
		elif et == "s3_ladybug":
			var dx_lb: float = p_rect.get_center().x - er.get_center().x
			var spr: bool = absf(dx_lb) < 4.2 * GridMath.TILE and absf(float(p["y"]) - float(e["y"])) < 72.0
			e["sprinting"] = spr
			if spr and absf(dx_lb) > 1.0:
				e["dir"] = signf(dx_lb)
			var spd_lb: float = 298.0 if spr else 78.0
			e["x"] = float(e["x"]) + float(e["dir"]) * spd_lb * world_dt
			if float(e["x"]) < float(e["min_px"]):
				e["x"] = float(e["min_px"])
				e["dir"] = 1.0
			elif float(e["x"]) > float(e["max_px"]):
				e["x"] = float(e["max_px"])
				e["dir"] = -1.0
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 7.0, float(e["w"]) - 14.0, float(e["h"]) - 9.0)):
				eng.kill_player(false, "ladybug")
				return
		elif et == "s3_mole":
			e["clock"] = float(e.get("clock", 0.0)) + world_dt
			var cyc_ml: float = fposmod(float(e["clock"]), 2.8)
			var was_up: bool = bool(e.get("up", true))
			var now_up: bool = cyc_ml < 1.85
			e["up"] = now_up
			e["y"] = float(e["base_y"]) if now_up else (float(e["base_y"]) + 28.0)
			if not was_up and now_up and absf(float(p["x"]) - float(e["x"])) < 7.8 * GridMath.TILE:
				var d_ml: float = -1.0 if float(p["x"]) < float(e["x"]) else 1.0
				eng.enemy_shots.append({
					"x": float(e["x"]) + 16.0, "y": float(e["y"]) + 4.0,
					"w": 16.0, "h": 16.0, "vx": d_ml * 198.0, "vy": -340.0,
					"grav": 780.0, "kind": "mole_wrench", "parry_wrench": true,
					"color": "#facc15", "layer": -1, "life": 2.6
				})
			if now_up and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 7.0, float(e["y"]) + 8.0, float(e["w"]) - 14.0, float(e["h"]) - 10.0)):
				eng.kill_player(false, "mole")
				return
		elif et == "s3_sun":
			if float(e.get("blind_timer", 0.0)) > 0.0:
				e["blind_timer"] = maxf(0.0, float(e["blind_timer"]) - world_dt)
				continue
			if not bool(e.get("awake", false)) and float(p["x"]) >= float(e["trigger_px"]):
				e["awake"] = true
				eng.emit_toast("☀ 警告：天上的墨镜太阳睡醒俯冲啦！", "WATCH OUT: SUNGLASSES SUN SWOOPING!", "s3_sun_angry", "#fb923c")
			if not bool(e.get("awake", false)):
				e["x"] = eng.cam_x + 805.0
				e["y"] = 42.0 + sin(eng.time_elapsed * 2.5) * 6.0
			else:
				# Lv132: If sun tracks heat and sun_heat is cooled down near 0, pause swoop countdown!
				var heat_calm: bool = bool(e.get("tracks_heat", false)) and eng.world_state.sun_heat < 8.0
				if not heat_calm:
					e["swoop_clock"] = float(e.get("swoop_clock", 1.2)) - world_dt
				if not bool(e.get("swooping", false)):
					var target_sun_x: float = eng.world_state.shadow_rect.position.x if bool(e.get("tracks_shadow", false)) else (eng.cam_x + 795.0)
					e["x"] = lerpf(float(e["x"]), target_sun_x + cos(eng.time_elapsed * 3.0) * 18.0, minf(1.0, world_dt * 4.0))
					e["y"] = 44.0 + sin(eng.time_elapsed * 4.0) * 8.0
					if float(e["swoop_clock"]) <= 0.0:
						e["swooping"] = true
						e["swoop_prog"] = 0.0
						e["start_x"] = eng.cam_x + 860.0
						eng.emit_sfx("shoot")
				else:
					e["swoop_prog"] = float(e["swoop_prog"]) + world_dt * 0.68
					e["x"] = float(e["start_x"]) - float(e["swoop_prog"]) * 920.0
					e["y"] = 52.0 + sin(float(e["swoop_prog"]) * PI) * 340.0
					# Blind sun if it swoops into a mirror!
					for sm_var in eng.solids:
						var sm_d: Dictionary = sm_var
						if str(sm_d.get("t", "")) == "mirror" and GridMath.aabb_overlap(er, Rect2(float(sm_d["x"]), float(sm_d["y"]), float(sm_d["w"]), float(sm_d["h"]))):
							e["swooping"] = false
							e["blind_timer"] = 4.5
							eng.emit_sfx("mirror_ping")
							break
					if float(e["swoop_prog"]) >= 1.0:
						e["swooping"] = false
						e["swoop_clock"] = 2.9
					if bool(e["swooping"]) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 14.0, float(e["w"]) - 28.0, float(e["h"]) - 28.0)):
						eng.kill_player(false, "troll_sun")
						return
		elif et == "s3_boss":
			if float(e.get("hit_flash", 0.0)) > 0.0:
				e["hit_flash"] = maxf(0.0, float(e["hit_flash"]) - world_dt)
			if float(e.get("stun_timer", 0.0)) > 0.0:
				e["stun_timer"] = maxf(0.0, float(e["stun_timer"]) - world_dt)
				continue
			e["phase_clock"] = float(e.get("phase_clock", 0.0)) + world_dt
			e["atk_timer"] = float(e.get("atk_timer", 1.6)) - world_dt
			var bkind: String = str(e.get("boss_kind", ""))
			var pc_b: float = float(e["phase_clock"])
			if "cloud_ram" in bkind or "110" in bkind or "blade_archon" in bkind or "140" in bkind or "solaris" in bkind or "150" in bkind:
				var span_b: float = 220.0 if ("solaris" in bkind or "150" in bkind) else 185.0
				e["x"] = float(e["base_x"]) + sin(pc_b * 1.45) * span_b
				e["y"] = float(e["base_y"]) + sin(pc_b * 2.7) * 48.0
			elif "pipe" in bkind or "120" in bkind:
				e["x"] = float(e["base_x"]) + sin(pc_b * 1.1) * 110.0
			elif "tanuki" in bkind or "130" in bkind:
				e["x"] = float(e["base_x"]) + cos(pc_b * 1.7) * 165.0
				e["y"] = float(e["base_y"]) - absf(sin(pc_b * 3.1)) * 55.0

			var solaris_pacified: bool = (
				eng.boss_sm != null
				and str(eng.boss_sm.state.get("boss_key", "")) == "lv150_solaris"
				and bool(eng.boss_sm.state["puzzle_flags"].get("throne_core_open", false))
			)
			if float(e["atk_timer"]) <= 0.0 and not solaris_pacified:
				e["atk_timer"] = 1.50 if ("solaris" in bkind or "150" in bkind) else 2.00
				var bc: Vector2 = Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
				var dvb: Vector2 = (p_rect.get_center() - bc).normalized()
				eng.enemy_shots.append({
					"x": bc.x, "y": bc.y, "w": 15.0, "h": 15.0,
					"vx": dvb.x * 260.0, "vy": dvb.y * 260.0,
					"color": "#fb923c", "layer": -1, "life": 3.0
				})
				if "solaris" in bkind or "150" in bkind or "blade_archon" in bkind or "140" in bkind:
					var dir_s3b: float = -1.0 if float(p["x"]) < float(e["x"]) else 1.0
					eng.enemy_shots.append({
						"x": bc.x, "y": bc.y, "w": 14.0, "h": 14.0,
						"vx": dir_s3b * 215.0, "vy": 145.0,
						"kind": "boss_lightning" if ("140" in bkind or "blade_archon" in bkind) else "solar_beam",
						"color": "#fde047", "layer": -1, "life": 2.8
					})
			if not solaris_pacified and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 14.0, float(e["y"]) + 14.0, float(e["w"]) - 28.0, float(e["h"]) - 28.0)):
				eng.kill_player(false, "boss")
				return
