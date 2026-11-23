class_name Sector1And2Mechanics
extends RefCounted

const LARGE_MECH_KINDS: Array[String] = [
	"mech_golem", "mech_crab", "mech_tank", "mech_knight", "mech_exec", "shield_mech", "turret"
]

static func is_in_active_layer(obj: Dictionary, active_layer: int) -> bool:
	if not obj.has("layer") or obj["layer"] == null:
		return true
	var lyr: int = int(obj["layer"])
	if lyr < 0:
		return true
	return lyr == active_layer

static func is_dual_layer_stage(lv: Dictionary) -> bool:
	if lv.is_empty():
		return false
	var props: Dictionary = lv.get("props", {})
	if bool(props.get("dualLayer", false)):
		return true
	var objs: Array = lv.get("objs", [])
	for o_var in objs:
		var o: Dictionary = o_var
		if str(o.get("t", "")) == "layer_term":
			return true
		if o.has("layer") and o["layer"] != null:
			return true
	return false

static func is_signal_gate_open(s: Dictionary, signal_groups: Dictionary) -> bool:
	var grp: String = str(s.get("group", ""))
	var raw_val: Variant = signal_groups.get(grp, false) if grp != "" else false
	var active: bool = false
	if typeof(raw_val) == TYPE_INT or typeof(raw_val) == TYPE_FLOAT:
		active = int(raw_val) >= int(s.get("req_count", 1))
	else:
		active = bool(raw_val)
	return (not active) if bool(s.get("invert", false)) else active

static func is_signal_bridge_on(s: Dictionary, signal_groups: Dictionary) -> bool:
	var grp: String = str(s.get("group", ""))
	var raw_val: Variant = signal_groups.get(grp, false) if grp != "" else false
	var active: bool = false
	if typeof(raw_val) == TYPE_INT or typeof(raw_val) == TYPE_FLOAT:
		active = int(raw_val) >= 1
	else:
		active = bool(raw_val)
	return (not active) if bool(s.get("invert", false)) else active

static func is_solid_collidable(s: Dictionary, active_layer: int, signal_groups: Dictionary) -> bool:
	if bool(s.get("broken", false)):
		return false
	if not is_in_active_layer(s, active_layer):
		return false
	var t: String = str(s.get("t", ""))
	if t == "signal_gate":
		return not is_signal_gate_open(s, signal_groups)
	if t == "signal_bridge":
		return is_signal_bridge_on(s, signal_groups)
	if t == "phase_plat" or t == "null_block":
		return str(s.get("phase_state", "solid")) != "ghost"
	if t == "glass_panel":
		return bool(s.get("real", true))
	if t == "time_slice_plat":
		return float(s.get("solid_timer", 0.0)) > 0.0
	if t == "beat_gate":
		return not bool(s.get("is_open", false))
	if t == "shy_brick":
		return bool(s.get("shy_solid", true))
	return true

static func get_local_time_scale(px: float, py: float, entities: Array) -> float:
	var mul: float = 1.0
	for e_var in entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "time_bubble":
			var cx: float = float(e["x"]) + float(e["w"]) * 0.5
			var cy: float = float(e["y"]) + float(e["h"]) * 0.5
			var r_px: float = float(e.get("radius_px", 120.0))
			if Vector2(px - cx, py - cy).length() <= r_px:
				var factor: float = float(e.get("slow_factor", 0.28))
				if factor < mul:
					mul = factor
	return mul

static func init_attempt_state(eng: RefCounted, lv: Dictionary, props: Dictionary, cp: Dictionary) -> void:
	eng.active_layer = int(cp.get("layer", int(props.get("startLayer", 0)))) if not cp.is_empty() else int(props.get("startLayer", 0))
	eng.signal_groups = {}
	var init_sig: Dictionary = props.get("initSignals", {})
	for k in init_sig.keys():
		eng.signal_groups[str(k)] = init_sig[k]
	if not cp.is_empty() and cp.has("signal_groups"):
		var cp_sig: Dictionary = cp["signal_groups"]
		for k2 in cp_sig.keys():
			eng.signal_groups[str(k2)] = cp_sig[k2]

	eng.polarity_groups = {}
	var init_pol: Dictionary = props.get("initPolarity", {})
	for kp in init_pol.keys():
		eng.polarity_groups[str(kp)] = str(init_pol[kp])
	if not cp.is_empty() and cp.has("polarity_groups"):
		var cp_pol: Dictionary = cp["polarity_groups"]
		for kp2 in cp_pol.keys():
			eng.polarity_groups[str(kp2)] = str(cp_pol[kp2])

	eng.seq_progress = {}
	if not cp.is_empty() and cp.has("seq_progress"):
		var cp_seq: Dictionary = cp["seq_progress"]
		for ks in cp_seq.keys():
			eng.seq_progress[str(ks)] = int(cp_seq[ks])

	eng.purified_save_keys = {}
	if not cp.is_empty() and cp.has("purified_save_keys"):
		var cp_ps: Dictionary = cp["purified_save_keys"]
		for kps in cp_ps.keys():
			eng.purified_save_keys[str(kps)] = bool(cp_ps[kps])

	eng.portal_cooldown = 0.0
	eng.layer_switch_cd = 0.0
	eng.plat_freeze_timer = 0.0
	eng.beat_extend_bonus = 0.0
	eng.echo_clones = []
	eng.carrying_item = {}
	eng.in_time_bubble = false
	eng.s2_bomb_regen = 0.0
	if not eng.player.is_empty():
		eng.player["heat_meter"] = 0.0
		eng.player["heavy_curse_timer"] = 0.0
		eng.player["reverse_curse_timer"] = 0.0
		eng.player["in_curse_mirror"] = false
		eng.player["in_curse_jump_shot"] = false

static func spawn_obj(eng: RefCounted, o: Dictionary, idx: int, lv: Dictionary) -> bool:
	var lv_id: int = int(lv.get("id", 1))
	var key: String = "%d_s2_%d" % [lv_id, idx]
	var layer_val: int = int(o["layer"]) if (o.has("layer") and o["layer"] != null) else -1
	var t: String = str(o.get("t", ""))
	var ox: float = float(o.get("x", 0.0))
	var oy: float = float(o.get("y", 0.0))

	if t == "signal_gate":
		var gh: float = float(o.get("h", 2.0))
		eng.solids.append({
			"key": key, "t": "signal_gate",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, gh),
			"w": float(o.get("w", 0.65)) * GridMath.TILE, "h": gh * GridMath.TILE,
			"group": str(o.get("group", "g1")),
			"invert": bool(o.get("invert", false)),
			"req_count": int(o.get("reqCount", 1)),
			"layer": layer_val, "broken": false
		})
		return true
	if t == "signal_bridge":
		var bh: float = float(o.get("h", 0.65))
		eng.solids.append({
			"key": key, "t": "signal_bridge",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, bh),
			"w": float(o.get("w", 3.0)) * GridMath.TILE, "h": bh * GridMath.TILE,
			"group": str(o.get("group", "g1")),
			"invert": bool(o.get("invert", false)),
			"layer": layer_val, "broken": false
		})
		return true
	if t == "phase_plat":
		var ph: float = float(o.get("h", 0.68))
		eng.solids.append({
			"key": key, "t": "phase_plat",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, ph),
			"w": float(o.get("w", 2.4)) * GridMath.TILE, "h": ph * GridMath.TILE,
			"period": float(o.get("period", 3.4)),
			"duty": float(o.get("duty", 0.56)),
			"offset": float(o.get("offset", 0.0)),
			"lock_group": str(o.get("lockGroup", "")),
			"local_clock": 0.0,
			"phase_state": "solid",
			"foot_hold_protected": false,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "polarity_block":
		var pbh: float = float(o.get("h", 1.2))
		var bx: float = GridMath.gx_to_px(ox)
		var by: float = GridMath.gy_to_py(oy, pbh)
		var blue_gx: float = float(o.get("blueX", ox))
		var blue_gy: float = float(o.get("blueY", oy))
		var orange_gx: float = float(o.get("orangeX", ox + 3.0))
		var orange_gy: float = float(o.get("orangeY", oy))
		eng.solids.append({
			"key": key, "t": "polarity_block",
			"x": bx, "y": by,
			"blue_x": GridMath.gx_to_px(blue_gx), "blue_y": GridMath.gy_to_py(blue_gy, pbh),
			"orange_x": GridMath.gx_to_px(orange_gx), "orange_y": GridMath.gy_to_py(orange_gy, pbh),
			"w": float(o.get("w", 1.4)) * GridMath.TILE, "h": pbh * GridMath.TILE,
			"group": str(o.get("group", "m1")),
			"layer": layer_val, "broken": false
		})
		return true
	if t == "rail_plat":
		var rh: float = float(o.get("h", 0.68))
		var sx: float = GridMath.gx_to_px(ox)
		var sy: float = GridMath.gy_to_py(oy, rh)
		eng.solids.append({
			"key": key, "t": "rail_plat",
			"x": sx, "y": sy, "base_x": sx, "base_y": sy,
			"dx_px": float(o.get("dx", 0.0)) * GridMath.TILE,
			"dy_px": float(o.get("dy", 0.0)) * GridMath.TILE,
			"w": float(o.get("w", 2.5)) * GridMath.TILE, "h": rh * GridMath.TILE,
			"speed": float(o.get("speed", 1.45)),
			"dwell": float(o.get("dwell", 0.45)),
			"prog": float(o.get("startProg", 0.0)),
			"dir": 1.0, "wait_timer": 0.0,
			"req_group": str(o.get("reqGroup", "")),
			"anchor_group": str(o.get("anchorGroup", "")),
			"layer": layer_val, "broken": false
		})
		return true
	if t == "conveyor":
		var ch: float = float(o.get("h", 0.85))
		eng.solids.append({
			"key": key, "t": "conveyor",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, ch),
			"w": float(o.get("w", 4.0)) * GridMath.TILE, "h": ch * GridMath.TILE,
			"belt_vx": float(o.get("beltVx", 135.0)),
			"stop_group": str(o.get("stopGroup", "")),
			"fast_trap": bool(o.get("fastTrap", false)),
			"layer": layer_val, "broken": false
		})
		return true
	if t == "glass_panel":
		var gph: float = float(o.get("h", 0.68))
		eng.solids.append({
			"key": key, "t": "glass_panel",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, gph),
			"w": float(o.get("w", 2.0)) * GridMath.TILE, "h": gph * GridMath.TILE,
			"real": bool(o.get("real", true)),
			"tested": false, "revealed_fake": false,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "time_slice_plat":
		var tsh: float = float(o.get("h", 0.68))
		var tsx: float = GridMath.gx_to_px(ox)
		var tsy: float = GridMath.gy_to_py(oy, tsh)
		eng.solids.append({
			"key": key, "t": "time_slice_plat",
			"x": tsx, "y": tsy, "base_x": tsx, "base_y": tsy,
			"dx_px": float(o.get("dx", 0.0)) * GridMath.TILE,
			"dy_px": float(o.get("dy", 0.0)) * GridMath.TILE,
			"w": float(o.get("w", 2.4)) * GridMath.TILE, "h": tsh * GridMath.TILE,
			"speed": float(o.get("speed", 1.35)),
			"offset": float(o.get("offset", 0.0)),
			"group": str(o.get("group", "ts1")),
			"solid_timer": 0.0, "local_clock": 0.0,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "beat_gate":
		var bgh: float = float(o.get("h", 2.6))
		eng.solids.append({
			"key": key, "t": "beat_gate",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, bgh),
			"w": float(o.get("w", 0.72)) * GridMath.TILE, "h": bgh * GridMath.TILE,
			"period": float(o.get("period", 5.5)),
			"open_dur": maxf(1.5, float(o.get("openDur", 2.1))),
			"offset": float(o.get("offset", 0.0)),
			"local_clock": 0.0, "is_open": false, "warn": false,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "null_block":
		var nbh: float = float(o.get("h", 1.0))
		eng.solids.append({
			"key": key, "t": "null_block",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, nbh),
			"w": float(o.get("w", 2.5)) * GridMath.TILE, "h": nbh * GridMath.TILE,
			"period": float(o.get("period", 4.4)),
			"blank_dur": minf(2.2, float(o.get("blankDur", 1.7))),
			"offset": float(o.get("offset", 0.0)),
			"stabilize_group": str(o.get("stabilizeGroup", "")),
			"gold_safe": bool(o.get("goldSafe", false)),
			"local_clock": 0.0, "phase_state": "solid", "foot_hold_protected": false,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "shy_brick":
		var sbh: float = float(o.get("h", 0.82))
		eng.solids.append({
			"key": key, "t": "shy_brick",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, sbh),
			"w": float(o.get("w", 2.1)) * GridMath.TILE, "h": sbh * GridMath.TILE,
			"mode": str(o.get("mode", "shy")),
			"shy_solid": true, "grace_timer": 0.0,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "moving_pit":
		var mph: float = float(o.get("h", 0.85))
		var mpx: float = GridMath.gx_to_px(ox)
		var mpy: float = GridMath.gy_to_py(oy, mph)
		eng.solids.append({
			"key": key, "t": "moving_pit",
			"x": mpx, "y": mpy, "base_x": mpx, "base_y": mpy,
			"w": float(o.get("w", 2.5)) * GridMath.TILE, "h": mph * GridMath.TILE,
			"scoot_dx_px": float(o.get("scootDx", 2.8)) * GridMath.TILE,
			"trigger_dist_px": float(o.get("triggerDist", 3.1)) * GridMath.TILE,
			"mode": str(o.get("mode", "flee")),
			"lock_group": str(o.get("lockGroup", "")),
			"triggered": false, "scoot_done": false, "return_timer": 0.0,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "ceiling_crusher":
		var cch: float = float(o.get("h", 1.5))
		var ccx: float = GridMath.gx_to_px(ox)
		var ccy: float = GridMath.gy_to_py(oy, cch)
		eng.solids.append({
			"key": key, "t": "ceiling_crusher",
			"x": ccx, "y": ccy, "base_x": ccx, "base_y": ccy,
			"w": float(o.get("w", 1.7)) * GridMath.TILE, "h": cch * GridMath.TILE,
			"max_drop_px": float(o.get("dropTiles", 3.0)) * GridMath.TILE,
			"trigger_pad_px": float(o.get("triggerPad", 1.05)) * GridMath.TILE,
			"rise_back": bool(o.get("riseBack", false)),
			"unlock_group": str(o.get("unlockGroup", "")),
			"state": "idle", "timer": 0.0,
			"layer": layer_val, "broken": false
		})
		return true
	if t == "fake_error":
		var feh: float = float(o.get("h", 2.1))
		var already_broken: bool = bool(eng.broken_solid_keys.get(key, false))
		eng.solids.append({
			"key": key, "t": "fake_error",
			"x": GridMath.gx_to_px(ox), "y": GridMath.gy_to_py(oy, feh),
			"w": float(o.get("w", 2.7)) * GridMath.TILE, "h": feh * GridMath.TILE,
			"mode": str(o.get("mode", "close_x")),
			"unlock_group": str(o.get("unlockGroup", "")),
			"title_text": str(o.get("titleText", "ERR_404")),
			"hit_flash": 0.0,
			"layer": layer_val, "broken": already_broken
		})
		return true

	var s2_ent_types: Array[String] = [
		"signal_node", "decoy_btn", "electric_arc", "polarity_node",
		"wind_zone", "heat_vent", "cool_pad", "piston", "saw_track",
		"signal_battery", "battery_slot", "echo_pad", "echo_rec_pad",
		"layer_term", "portal", "time_bubble", "time_node", "beat_clock",
		"root_term", "root_item", "root_slot", "mem_shard",
		"mimic_chest", "mimic_flag", "betray_spring", "trojan_heart",
		"curse_totem", "troll_hand", "fake_save", "peace_dove",
		"s2_enemy", "s2_boss"
	]
	if not (t in s2_ent_types):
		return false

	var ent: Dictionary = o.duplicate(true)
	ent["key"] = key
	ent["layer"] = layer_val
	ent["hit_cd"] = 0.0

	if t in ["signal_node", "polarity_node", "time_node", "beat_clock"]:
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.1)
		ent["w"] = 1.1 * GridMath.TILE
		ent["h"] = 1.1 * GridMath.TILE
		ent["activated_once"] = false
	elif t == "decoy_btn":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.85)
		ent["w"] = 1.0 * GridMath.TILE
		ent["h"] = 0.85 * GridMath.TILE
		ent["pressed"] = false
	elif t == "electric_arc":
		var eah: float = float(o.get("h", 0.7))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, eah)
		ent["w"] = float(o.get("w", 2.0)) * GridMath.TILE
		ent["h"] = eah * GridMath.TILE
	elif t == "wind_zone":
		var wzh: float = float(o.get("h", 3.5))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, wzh)
		ent["w"] = float(o.get("w", 3.0)) * GridMath.TILE
		ent["h"] = wzh * GridMath.TILE
	elif t == "heat_vent" or t == "cool_pad":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.65)
		ent["w"] = float(o.get("w", 2.2)) * GridMath.TILE
		ent["h"] = 0.65 * GridMath.TILE
		ent["heat_phase"] = "rest"
	elif t == "piston":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["max_drop_px"] = float(o.get("dropH", 2.4)) * GridMath.TILE
		ent["base_y"] = GridMath.gy_to_py(oy, 1.2)
		ent["y"] = float(ent["base_y"])
		ent["w"] = float(o.get("w", 1.5)) * GridMath.TILE
		ent["h"] = 1.2 * GridMath.TILE
		ent["period"] = float(o.get("period", 3.1))
		ent["offset"] = float(o.get("offset", 0.0))
		ent["local_clock"] = 0.0
		ent["state"] = "idle"
	elif t == "saw_track":
		ent["base_x"] = GridMath.gx_to_px(ox)
		ent["base_y"] = GridMath.gy_to_py(oy, 1.25)
		ent["x"] = float(ent["base_x"])
		ent["y"] = float(ent["base_y"])
		ent["dx_px"] = float(o.get("dx", 0.0)) * GridMath.TILE
		ent["dy_px"] = float(o.get("dy", 0.0)) * GridMath.TILE
		ent["w"] = 1.25 * GridMath.TILE
		ent["h"] = 1.25 * GridMath.TILE
		ent["speed"] = float(o.get("speed", 2.0))
		ent["phase"] = float(o.get("offset", 0.0))
	elif t in ["signal_battery", "root_item", "mem_shard"]:
		ent["x"] = GridMath.gx_to_px(ox) + 4.0
		ent["y"] = GridMath.gy_to_py(oy, 0.95)
		ent["spawn_x"] = float(ent["x"])
		ent["spawn_y"] = float(ent["y"])
		ent["w"] = 0.9 * GridMath.TILE
		ent["h"] = 0.95 * GridMath.TILE
		ent["carried"] = false
		ent["inserted"] = false
		if t == "mem_shard":
			var sid: String = str(o.get("shardId", key))
			ent["already_collected"] = bool(eng.save.shards.get(sid, false))
		elif bool(eng.consumed_carry_keys.get(key, false)):
			return true
		elif not eng.active_checkpoint.is_empty() and str(eng.active_checkpoint.get("carrying_item_key", "")) == key:
			ent["carried"] = true
			eng.carrying_item = ent
	elif t in ["battery_slot", "root_slot", "echo_pad", "echo_rec_pad"]:
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 0.85)
		ent["w"] = float(o.get("w", 1.2)) * GridMath.TILE
		ent["h"] = 0.85 * GridMath.TILE
		var grp_s: String = str(o.get("group", ""))
		ent["filled"] = (grp_s != "" and bool(eng.signal_groups.get(grp_s, false))) or bool(eng.filled_slot_keys.get(key, false))
		ent["depressed"] = false
		ent["latched"] = false
	elif t == "layer_term" or t == "root_term":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.45)
		ent["w"] = 1.15 * GridMath.TILE
		ent["h"] = 1.45 * GridMath.TILE
		var grp_t: String = str(o.get("group", ""))
		ent["activated"] = grp_t != "" and bool(eng.signal_groups.get(grp_t, false))
	elif t == "portal":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.75)
		ent["w"] = 1.25 * GridMath.TILE
		ent["h"] = 1.75 * GridMath.TILE
	elif t == "time_bubble":
		var r_px: float = float(o.get("r", 2.6)) * GridMath.TILE
		ent["radius_px"] = r_px
		ent["x"] = GridMath.gx_to_px(ox) - r_px
		ent["y"] = GridMath.gy_to_py(oy, 0.0) - r_px
		ent["w"] = r_px * 2.0
		ent["h"] = r_px * 2.0
		ent["slow_factor"] = float(o.get("slowFactor", 0.28))
	elif t == "s2_enemy":
		var kind: String = str(o.get("kind", "patrol"))
		var is_large: bool = kind in LARGE_MECH_KINDS
		ent["x"] = GridMath.gx_to_px(ox)
		ent["spawn_x"] = float(ent["x"])
		ent["tier"] = "hazard" if kind == "forklift" else ("large" if is_large else "small")
		ent["max_hp"] = int(o.get("hp", 15 if is_large else 5))
		ent["hp"] = int(ent["max_hp"])
		ent["jolt_x"] = 0.0
		ent["armor_flash"] = 0.0
		ent["atk_cd"] = float(o.get("offset", 0.0)) + 1.2
		ent["dash_cd"] = 1.2
		ent["dash_state"] = ""
		ent["dash_timer"] = 0.0
		ent["dash_dir"] = -1.0
		ent["telegraph"] = 0
		ent["is_phasing"] = false
		ent["phase_clock"] = 0.0
		ent["bullet_immune"] = (kind == "mech_shroom")
		var d_init: float = float(o.get("dir", -1.0))
		if kind in ["drone", "mech_wasp", "mech_wisp"]:
			ent["y"] = GridMath.gy_to_py(oy, 1.15)
			ent["base_y"] = float(ent["y"])
			ent["w"] = 1.25 * GridMath.TILE
			ent["h"] = 1.15 * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 3.0)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 3.0)))
			ent["vx"] = float(o.get("speed", 95.0)) * d_init
			ent["facing"] = -1 if d_init < 0.0 else 1
		elif kind == "turret":
			ent["y"] = GridMath.gy_to_py(oy, 1.1)
			ent["w"] = 1.25 * GridMath.TILE
			ent["h"] = 1.1 * GridMath.TILE
			ent["cycle"] = float(o.get("offset", 0.0))
			ent["period"] = float(o.get("period", 2.8))
			ent["aim_phase"] = "cool"
			ent["fired_this_beat"] = false
		elif kind == "forklift":
			ent["y"] = GridMath.gy_to_py(oy, 1.25)
			ent["w"] = 1.65 * GridMath.TILE
			ent["h"] = 1.25 * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 3.0)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 4.0)))
			ent["vx"] = float(o.get("speed", 135.0)) * float(o.get("dir", 1.0))
		elif kind == "mech_hopper":
			ent["y"] = GridMath.gy_to_py(oy, 1.15)
			ent["ground_y"] = float(ent["y"])
			ent["w"] = 1.1 * GridMath.TILE
			ent["h"] = 1.15 * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 3.0)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 3.0)))
			ent["vx"] = float(o.get("speed", 95.0)) * d_init
			ent["vy"] = 0.0
			ent["leap_cd"] = 0.9
			ent["leap_windup"] = 0.0
			ent["facing"] = -1
		elif kind == "mech_shroom":
			ent["y"] = GridMath.gy_to_py(oy, 1.2)
			ent["w"] = 1.18 * GridMath.TILE
			ent["h"] = 1.2 * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 2.5)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 2.5)))
			ent["vx"] = float(o.get("speed", 82.0)) * d_init
			ent["facing"] = -1
		elif is_large:
			var ht: float = 1.55 if kind == "mech_crab" else (1.6 if kind == "mech_tank" else 1.85)
			var wt: float = 1.85 if kind == "mech_crab" else (1.75 if kind == "mech_tank" else 1.48)
			ent["y"] = GridMath.gy_to_py(oy, ht)
			ent["ground_y"] = float(ent["y"])
			ent["w"] = wt * GridMath.TILE
			ent["h"] = ht * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 3.2)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 3.2)))
			var def_spd: float = 0.0 if kind == "shield_mech" else 78.0
			ent["vx"] = float(o.get("speed", def_spd)) * d_init
			ent["vy"] = 0.0
			ent["facing"] = int(o.get("facing", -1))
		else:
			ent["y"] = GridMath.gy_to_py(oy, 1.12)
			ent["ground_y"] = float(ent["y"])
			ent["w"] = 1.25 * GridMath.TILE
			ent["h"] = 1.12 * GridMath.TILE
			ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 2.8)))
			ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 2.8)))
			var def_spd2: float = 148.0 if kind == "mech_hound" else 112.0
			ent["vx"] = float(o.get("speed", def_spd2)) * d_init
			ent["vy"] = 0.0
			ent["facing"] = -1 if float(ent["vx"]) < 0.0 else 1
	elif t == "s2_boss":
		var boss_h: float = float(o.get("h", 2.8))
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, boss_h)
		ent["base_x"] = float(ent["x"])
		ent["base_y"] = float(ent["y"])
		ent["w"] = float(o.get("w", 2.8)) * GridMath.TILE
		ent["h"] = boss_h * GridMath.TILE
		var saved_phase: int = int(eng.active_checkpoint.get("boss_phase", 1)) if not eng.active_checkpoint.is_empty() else 1
		var max_hp_b: int = int(o.get("hp", 25))
		var saved_hp: int = int(eng.active_checkpoint.get("boss_hp", max_hp_b)) if not eng.active_checkpoint.is_empty() else max_hp_b
		ent["phase"] = saved_phase
		ent["max_phase"] = int(o.get("maxPhase", 3))
		ent["max_hp"] = max_hp_b
		ent["hp"] = mini(max_hp_b, saved_hp)
		ent["vuln_timer"] = 0.0
		ent["atk_timer"] = 1.6
		ent["mode_idx"] = 0
		ent["defeated"] = false
		ent["stun_timer"] = 0.0
		ent["armor_flash"] = 0.0
		ent["armor_cracked"] = false
		ent["active_core_layer"] = 0
	elif t == "mimic_chest":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["spawn_x"] = float(ent["x"])
		ent["ground_y"] = float(ent["y"])
		ent["w"] = 1.3 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "ambush"))
		ent["awake"] = bool(o.get("startAwake", false))
		ent["max_hp"] = int(o.get("hp", 6))
		ent["hp"] = int(ent["max_hp"])
		ent["vx"] = 0.0
		ent["vy"] = 0.0
		ent["hop_cd"] = 0.6
	elif t == "mimic_flag":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.7)
		ent["spawn_x"] = float(ent["x"])
		ent["w"] = 1.2 * GridMath.TILE
		ent["h"] = 1.7 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "bite"))
		ent["revealed"] = false
		var ug: String = str(o.get("unlockGroup", ""))
		ent["tamed"] = (ug != "" and bool(eng.signal_groups.get(ug, false)) and str(ent["mode"]) == "sword_tame")
		ent["fleeing"] = false
	elif t == "betray_spring":
		ent["x"] = GridMath.gx_to_px(ox) + 2.0
		ent["y"] = GridMath.gy_to_py(oy, 0.92)
		ent["w"] = 1.05 * GridMath.TILE
		ent["h"] = 0.92 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "calibrate"))
		ent["launch_vx"] = float(o.get("launchVx", -455.0))
		ent["launch_vy"] = float(o.get("launchVy", -510.0))
		var cg: String = str(o.get("calibGroup", ""))
		ent["calibrated"] = cg != "" and bool(eng.signal_groups.get(cg, false))
		var disg: bool = bool(o.get("disguised", true))
		ent["revealed_evil"] = not disg
		ent["spring_anim"] = 0.0
	elif t == "trojan_heart":
		ent["x"] = GridMath.gx_to_px(ox) + 4.0
		ent["y"] = GridMath.gy_to_py(oy, 0.95)
		ent["w"] = 0.95 * GridMath.TILE
		ent["h"] = 0.95 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "heavy_curse"))
		ent["respawn_cd"] = 0.0
	elif t == "curse_totem":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.65)
		ent["w"] = 1.15 * GridMath.TILE
		ent["h"] = 1.65 * GridMath.TILE
		ent["radius_px"] = float(o.get("radius", 5.2)) * GridMath.TILE
		ent["curse_type"] = str(o.get("curseType", "mirror_lr"))
		ent["can_disable"] = bool(o.get("canDisable", true))
		ent["disable_timer"] = 0.0
	elif t == "troll_hand":
		ent["base_x"] = GridMath.gx_to_px(ox)
		ent["base_y"] = GridMath.gy_to_py(oy, 1.65)
		ent["x"] = float(ent["base_x"])
		ent["y"] = float(ent["base_y"])
		ent["w"] = 1.65 * GridMath.TILE
		ent["h"] = 1.65 * GridMath.TILE
		ent["mode"] = str(o.get("mode", "parry_duel"))
		ent["reach_px"] = float(o.get("reachTiles", 2.4)) * GridMath.TILE
		ent["period"] = float(o.get("period", 2.9))
		ent["offset"] = float(o.get("offset", 0.0))
		ent["local_clock"] = 0.0
		ent["state"] = "idle"
		var ug_h: String = str(o.get("unlockGroup", ""))
		ent["parried"] = (ug_h != "" and bool(eng.signal_groups.get(ug_h, false)) and str(ent["mode"]) == "parry_duel")
	elif t == "fake_save":
		ent["x"] = GridMath.gx_to_px(ox) + 3.0
		ent["y"] = GridMath.gy_to_py(oy, 1.45)
		ent["gx"] = ox
		ent["gy"] = oy
		ent["w"] = 0.98 * GridMath.TILE
		ent["h"] = 1.45 * GridMath.TILE
		ent["purified"] = bool(eng.purified_save_keys.get(key, false))
		ent["active"] = (not eng.active_checkpoint.is_empty()) and absf(float(eng.active_checkpoint.get("x", -999.0)) - ox) < 0.25
		if bool(ent["active"]):
			ent["purified"] = true
	elif t == "peace_dove":
		ent["x"] = GridMath.gx_to_px(ox)
		ent["y"] = GridMath.gy_to_py(oy, 1.15)
		ent["base_y"] = float(ent["y"])
		ent["w"] = 1.35 * GridMath.TILE
		ent["h"] = 1.15 * GridMath.TILE
		ent["min_px"] = GridMath.gx_to_px(float(o.get("minX", ox - 4.0)))
		ent["max_px"] = GridMath.gx_to_px(float(o.get("maxX", ox + 4.0)))
		ent["vx"] = float(o.get("speed", 88.0)) * float(o.get("dir", 1.0))
		ent["watch_radius_px"] = float(o.get("watchRadius", 6.5)) * GridMath.TILE
		ent["angry_timer"] = 0.0
		ent["bomb_cd"] = 0.0
		ent["gifted_shield"] = false
		var pgg: String = str(o.get("peaceGateGroup", ""))
		if pgg != "" and not eng.signal_groups.has(pgg):
			eng.signal_groups[pgg] = true

	eng.entities.append(ent)
	return true

static func try_shift_dual_layer(eng: RefCounted, from_terminal: bool = false) -> bool:
	if not is_dual_layer_stage(eng.lv_data):
		return false
	if eng.layer_switch_cd > 0.0:
		return false
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)):
		return false
	var lv_props: Dictionary = eng.lv_data.get("props", {})
	var next_layer: int = 1 if eng.active_layer == 0 else 0

	var p_box: Rect2 = Rect2(float(p["x"]) + 3.0, float(p["y"]) + 3.0, float(p["w"]) - 6.0, float(p["h"]) - 6.0)
	var target_solids: Array = []
	for s_var in eng.solids:
		var s: Dictionary = s_var
		if bool(s.get("broken", false)):
			continue
		var st: String = str(s.get("t", ""))
		if st == "fake_wall" or st == "fake_plat":
			continue
		if (st == "invis" or st == "qblock") and not bool(s.get("revealed", false)):
			continue
		if not is_solid_collidable(s, next_layer, eng.signal_groups):
			continue
		if eng.lv_id >= 101 and not Sector3Arcadia.is_solid_collidable(s, eng.s3_sundial_phase):
			continue
		target_solids.append(s)

	var hit_solids: Array = []
	for ts_var in target_solids:
		var ts: Dictionary = ts_var
		if GridMath.aabb_overlap(p_box, Rect2(float(ts["x"]), float(ts["y"]), float(ts["w"]), float(ts["h"]))):
			hit_solids.append(ts)

	if hit_solids.size() > 0:
		var hs0: Dictionary = hit_solids[0]
		var only_lip: bool = hit_solids.size() == 1 and (float(p["y"]) + float(p["h"]) - float(hs0["y"])) <= 14.0 and (float(p["y"]) > float(hs0["y"]) - float(p["h"]) - 2.0)
		var nudged_ok: bool = false
		if only_lip:
			var nudged_box: Rect2 = Rect2(float(p["x"]) + 3.0, float(hs0["y"]) - float(p["h"]) + 2.0, float(p["w"]) - 6.0, float(p["h"]) - 6.0)
			nudged_ok = true
			for ts2_var in target_solids:
				var ts2: Dictionary = ts2_var
				if ts2 != hs0 and GridMath.aabb_overlap(nudged_box, Rect2(float(ts2["x"]), float(ts2["y"]), float(ts2["w"]), float(ts2["h"]))):
					nudged_ok = false
					break
		if nudged_ok:
			p["y"] = float(hs0["y"]) - float(p["h"])
		else:
			eng.emit_sfx("layer_deny")
			eng.layer_switch_cd = 0.25
			eng.add_shock_ring(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) + float(p["h"]) * 0.5, Color("#f43f5e"), 40.0, 0.25)
			eng.emit_toast("目标层有墙体阻挡 · 禁止切层！", "TARGET LAYER BLOCKED!", "cat_nav_nervous", "#f43f5e")
			return false

	var target_grav: float = float(p.get("grav_dir", 1.0))
	if bool(lv_props.get("layerInvertGrav", false)):
		target_grav = -1.0 if next_layer == 1 else 1.0
	var probe_h: float = GridMath.TILE * 4.0
	var foot_probe: Rect2 = (
		Rect2(float(p["x"]) - 10.0, float(p["y"]) + float(p["h"]) - 8.0, float(p["w"]) + 20.0, probe_h)
		if target_grav > 0.0
		else Rect2(float(p["x"]) - 10.0, float(p["y"]) - probe_h + 8.0, float(p["w"]) + 20.0, probe_h)
	)
	var has_safe: bool = bool(lv_props.get("allowFreeLayerShift", false)) or from_terminal
	if not has_safe:
		for ts3_var in target_solids:
			var ts3: Dictionary = ts3_var
			if GridMath.aabb_overlap(foot_probe, Rect2(float(ts3["x"]), float(ts3["y"]), float(ts3["w"]), float(ts3["h"]))):
				has_safe = true
				break
	if not has_safe:
		eng.emit_sfx("layer_deny")
		eng.layer_switch_cd = 0.25
		eng.add_shock_ring(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) + float(p["h"]) * 0.5, Color("#f43f5e"), 40.0, 0.25)
		eng.emit_toast("目标层下方无安全落点 · 请站安全台切层！", "NO SAFE FLOOR IN TARGET LAYER!", "cat_nav_shock", "#f43f5e")
		return false

	eng.active_layer = next_layer
	eng.layer_switch_cd = 0.28
	if bool(lv_props.get("layerInvertGrav", false)):
		p["grav_dir"] = -1.0 if next_layer == 1 else 1.0
		p["vy"] = float(p["grav_dir"]) * 60.0
		eng.unlock_ach("grav_walker")
	eng.emit_sfx("layer_switch")
	eng.unlock_ach("layer_walker")
	var col_s: String = "#c084fc" if next_layer == 1 else "#00f5ff"
	eng.add_afterimage(Color(col_s))
	eng.add_shock_ring(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) + float(p["h"]) * 0.5, Color(col_s), 48.0, 0.28)
	eng.spawn_particles(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) + float(p["h"]) * 0.5, Color(col_s), 14)
	eng.emit_toast(
		"已切入【背景裂界层】！" if next_layer == 1 else "已切回【前景现实层】！",
		"SHIFTED TO BACKGROUND LAYER!" if next_layer == 1 else "SHIFTED TO FOREGROUND LAYER!",
		"s2_ui_layer_btn", col_s
	)
	eng.hud_dirty = true
	return true

static func notify_peace_doves(eng: RefCounted, px: float, py: float) -> void:
	if eng.lv_id < 51:
		return
	for e_var in eng.entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) == "peace_dove" and is_in_active_layer(e, eng.active_layer):
			var d: float = Vector2(px - (float(e["x"]) + float(e["w"]) * 0.5), py - (float(e["y"]) + float(e["h"]) * 0.5)).length()
			if d <= float(e.get("watch_radius_px", 312.0)):
				e["angry_timer"] = 3.4
				var pgg: String = str(e.get("peaceGateGroup", ""))
				if pgg != "":
					eng.signal_groups[pgg] = false
				eng.emit_sfx("fake_buzz")
				eng.emit_toast("违背停战协议！白鸽暴怒封门（收手3.4秒平息）！", "CEASEFIRE BROKEN! HOLD FIRE 3.4S!", "s2_peace_dove", "#f43f5e")

static func step_pre_move(eng: RefCounted, dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)) or eng.lv_id < 51:
		return

	if eng.portal_cooldown > 0.0:
		eng.portal_cooldown = maxf(0.0, eng.portal_cooldown - dt)
	if eng.layer_switch_cd > 0.0:
		eng.layer_switch_cd = maxf(0.0, eng.layer_switch_cd - dt)
	if eng.plat_freeze_timer > 0.0:
		eng.plat_freeze_timer = maxf(0.0, eng.plat_freeze_timer - dt)

	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))
	var p_scale: float = get_local_time_scale(p_rect.get_center().x, p_rect.get_center().y, eng.entities)
	var now_bubble: bool = p_scale < 0.8
	if now_bubble and not eng.in_time_bubble:
		eng.emit_sfx("time_bubble_in")
		eng.unlock_ach("chrono_drifter")
	eng.in_time_bubble = now_bubble

	for e_var in eng.entities:
		var e: Dictionary = e_var
		if not is_in_active_layer(e, eng.active_layer):
			continue
		var et: String = str(e.get("t", ""))
		if et == "wind_zone":
			var off_g: String = str(e.get("offGroup", ""))
			if off_g != "" and bool(eng.signal_groups.get(off_g, false)):
				continue
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))):
				var heavy_mul: float = 0.16 if float(p.get("heavy_curse_timer", 0.0)) > 0.0 else 1.0
				p["vx"] = float(p["vx"]) + float(e.get("vx", 0.0)) * heavy_mul * dt
				var wvy: float = float(e.get("vy", 0.0))
				if absf(wvy) > 0.01:
					p["vy"] = float(p["vy"]) + wvy * heavy_mul * dt
					if float(p["vy"]) < -430.0:
						p["vy"] = -430.0
		elif et == "heat_vent":
			var fan_off: bool = str(e.get("offGroup", "")) != "" and bool(eng.signal_groups.get(str(e.get("offGroup", "")), false))
			var cyc: float = fposmod(eng.time_elapsed + float(e.get("offset", 0.0)), 4.0)
			var hphase: String = "off" if fan_off else ("warn" if cyc < 1.0 else ("erupt" if cyc < 2.7 else "rest"))
			e["heat_phase"] = hphase
			if hphase == "erupt":
				var plume: Rect2 = Rect2(float(e["x"]), float(e["y"]) - 3.4 * GridMath.TILE, float(e["w"]), 3.6 * GridMath.TILE)
				if GridMath.aabb_overlap(p_rect, plume):
					p["vy"] = maxf(-440.0, float(p["vy"]) - 980.0 * dt)
					p["heat_meter"] = minf(100.0, float(p.get("heat_meter", 0.0)) + 46.0 * dt)
					if float(p["heat_meter"]) >= 100.0:
						eng.kill_player(false, "heat")
						return
		elif et == "cool_pad":
			if float(p.get("heat_meter", 0.0)) > 0.0:
				var cbox: Rect2 = Rect2(float(e["x"]) - 4.0, float(e["y"]) - 16.0, float(e["w"]) + 8.0, float(e["h"]) + 20.0)
				if GridMath.aabb_overlap(p_rect, cbox):
					p["heat_meter"] = 0.0
					eng.emit_sfx("coin")
					eng.emit_toast("冷却成功 · 过热清零！", "COOLED DOWN!", "ach_iceclock", "#67e8f9")

	if float(p.get("heat_meter", 0.0)) > 0.0:
		p["heat_meter"] = maxf(0.0, float(p["heat_meter"]) - 8.0 * dt)

	for s_var in eng.solids:
		var s: Dictionary = s_var
		if bool(s.get("broken", false)):
			continue
		var st: String = str(s.get("t", ""))
		var local_mul: float = 0.0 if eng.plat_freeze_timer > 0.0 else get_local_time_scale(float(s["x"]) + float(s["w"]) * 0.5, float(s["y"]) + float(s["h"]) * 0.5, eng.entities)
		var s_dt: float = world_dt * local_mul

		if st == "phase_plat":
			var lg: String = str(s.get("lock_group", ""))
			if lg != "" and bool(eng.signal_groups.get(lg, false)):
				s["phase_state"] = "solid"
				s["foot_hold_protected"] = false
				continue
			s["local_clock"] = float(s.get("local_clock", 0.0)) + s_dt
			var per: float = maxf(0.8, float(s.get("period", 3.4)))
			var duty: float = float(s.get("duty", 0.56))
			var cyc_p: float = fposmod(float(s["local_clock"]) + float(s.get("offset", 0.0)), per) / per
			var warn_start: float = maxf(0.15, duty - (0.75 / per))
			var desired: String = "solid" if cyc_p < warn_start else ("warn" if cyc_p < duty else "ghost")
			var standing: bool = is_in_active_layer(s, eng.active_layer) and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"]) - float(s["y"])) if float(p["grav_dir"]) > 0.0 else (float(p["y"]) - (float(s["y"]) + float(s["h"])))) <= 10.0
			if desired == "ghost" and standing:
				s["phase_state"] = "warn"
				s["foot_hold_protected"] = true
			else:
				s["phase_state"] = desired
				s["foot_hold_protected"] = false
		elif st == "null_block":
			var sg: String = str(s.get("stabilize_group", ""))
			if bool(s.get("gold_safe", false)) or (sg != "" and bool(eng.signal_groups.get(sg, false))):
				s["phase_state"] = "solid"
				continue
			s["local_clock"] = float(s.get("local_clock", 0.0)) + s_dt
			var per_n: float = maxf(1.0, float(s.get("period", 4.4)))
			var cyc_n: float = fposmod(float(s["local_clock"]) + float(s.get("offset", 0.0)), per_n)
			var solid_end: float = per_n - float(s.get("blank_dur", 1.7))
			var des_n: String = "solid" if cyc_n < (solid_end - 0.85) else ("warn" if cyc_n < solid_end else "ghost")
			var stand_n: bool = is_in_active_layer(s, eng.active_layer) and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - float(s["y"])) <= 10.0
			s["phase_state"] = "warn" if (des_n == "ghost" and stand_n) else des_n
		elif st == "polarity_block":
			var mode_p: String = str(eng.polarity_groups.get(str(s.get("group", "m1")), "blue"))
			var tx: float = float(s["orange_x"]) if mode_p == "orange" else float(s["blue_x"])
			var ty: float = float(s["orange_y"]) if mode_p == "orange" else float(s["blue_y"])
			var prev_x: float = float(s["x"])
			var prev_y: float = float(s["y"])
			var dist_p: float = Vector2(tx - prev_x, ty - prev_y).length()
			var step_px: float = 210.0 * s_dt
			if dist_p > 0.5 and step_px > 0.0:
				var r: float = minf(1.0, step_px / dist_p)
				s["x"] = prev_x + (tx - prev_x) * r
				s["y"] = prev_y + (ty - prev_y) * r
				if is_in_active_layer(s, eng.active_layer) and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > prev_x + 2.0 and float(p["x"]) < prev_x + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - prev_y) <= 10.0:
					p["x"] = float(p["x"]) + (float(s["x"]) - prev_x)
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_y)
		elif st == "rail_plat":
			var rg: String = str(s.get("req_group", ""))
			var ag: String = str(s.get("anchor_group", ""))
			if (rg != "" and not bool(eng.signal_groups.get(rg, false))) or (ag != "" and bool(eng.signal_groups.get(ag, false))):
				continue
			if float(s.get("wait_timer", 0.0)) > 0.0:
				s["wait_timer"] = maxf(0.0, float(s["wait_timer"]) - s_dt)
				continue
			var rpx: float = float(s["x"])
			var rpy: float = float(s["y"])
			var span_r: float = maxf(1.0, Vector2(float(s["dx_px"]), float(s["dy_px"])).length())
			var rate_r: float = (float(s["speed"]) * GridMath.TILE) / span_r
			var prog_r: float = float(s["prog"]) + float(s["dir"]) * rate_r * s_dt
			if prog_r >= 1.0:
				prog_r = 1.0
				s["dir"] = -1.0
				s["wait_timer"] = float(s["dwell"])
			elif prog_r <= 0.0:
				prog_r = 0.0
				s["dir"] = 1.0
				s["wait_timer"] = float(s["dwell"])
			s["prog"] = prog_r
			s["x"] = float(s["base_x"]) + float(s["dx_px"]) * prog_r
			s["y"] = float(s["base_y"]) - float(s["dy_px"]) * prog_r
			if is_in_active_layer(s, eng.active_layer) and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > rpx + 2.0 and float(p["x"]) < rpx + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - rpy) <= 10.0:
				p["x"] = float(p["x"]) + (float(s["x"]) - rpx)
				p["y"] = float(p["y"]) + (float(s["y"]) - rpy)
		elif st == "time_slice_plat":
			if float(s.get("solid_timer", 0.0)) > 0.0:
				s["solid_timer"] = maxf(0.0, float(s["solid_timer"]) - dt)
			var tspx: float = float(s["x"])
			var tspy: float = float(s["y"])
			s["local_clock"] = float(s.get("local_clock", 0.0)) + s_dt
			var ph_ts: float = 0.5 - 0.5 * cos((float(s["local_clock"]) + float(s["offset"])) * float(s["speed"]))
			s["x"] = float(s["base_x"]) + float(s["dx_px"]) * ph_ts
			s["y"] = float(s["base_y"]) - float(s["dy_px"]) * ph_ts
			if float(s.get("solid_timer", 0.0)) > 0.0 and is_in_active_layer(s, eng.active_layer) and bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > tspx + 2.0 and float(p["x"]) < tspx + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - tspy) <= 10.0:
				p["x"] = float(p["x"]) + (float(s["x"]) - tspx)
				p["y"] = float(p["y"]) + (float(s["y"]) - tspy)
		elif st == "beat_gate":
			s["local_clock"] = float(s.get("local_clock", 0.0)) + s_dt
			var per_b: float = maxf(1.5, float(s["period"]))
			var eff_open: float = minf(per_b - 0.5, float(s["open_dur"]) + eng.beat_extend_bonus)
			var cyc_b: float = fposmod(float(s["local_clock"]) + float(s["offset"]), per_b)
			var was_open: bool = bool(s.get("is_open", false))
			s["is_open"] = cyc_b < eff_open
			s["warn"] = (not bool(s["is_open"])) and (cyc_b >= per_b - 0.85)
			if bool(s["is_open"]) and not was_open and absf(float(s["x"]) - float(p["x"])) < 420.0:
				eng.emit_sfx("beat_open")
		elif st == "shy_brick":
			if not is_in_active_layer(s, eng.active_layer):
				continue
			var dx_sb: float = (float(s["x"]) + float(s["w"]) * 0.5) - (float(p["x"]) + float(p["w"]) * 0.5)
			var looking: bool = (dx_sb * float(p["facing"])) > 0.0 if absf(dx_sb) > 6.0 else false
			var want_s: bool = looking if str(s.get("mode", "shy")) == "stare" else (not looking)
			if want_s:
				s["shy_solid"] = true
				s["grace_timer"] = 0.13
			elif float(s.get("grace_timer", 0.0)) > 0.0:
				s["grace_timer"] = maxf(0.0, float(s["grace_timer"]) - dt)
				s["shy_solid"] = true
			else:
				s["shy_solid"] = false
		elif st == "moving_pit":
			if not is_in_active_layer(s, eng.active_layer):
				continue
			var lg_mp: String = str(s.get("lock_group", ""))
			if lg_mp != "" and bool(eng.signal_groups.get(lg_mp, false)):
				s["triggered"] = false
				continue
			var p_cx: float = float(p["x"]) + float(p["w"]) * 0.5
			var b_cx: float = float(s["x"]) + float(s["w"]) * 0.5
			if not bool(s["triggered"]) and not bool(s["scoot_done"]) and absf(p_cx - b_cx) <= float(s["trigger_dist_px"]) and absf((float(p["y"]) + float(p["h"])) - float(s["y"])) <= 3.3 * GridMath.TILE:
				s["triggered"] = true
				eng.emit_sfx("spring")
				eng.emit_toast("地板长脚溜走啦 · 假跳骗它站定再踩！", "RUNAWAY FLOOR! BAIT IT FIRST!", "s2_moving_pit", "#fde047")
			var target_mp_x: float = (float(s["base_x"]) + float(s["scoot_dx_px"])) if bool(s["triggered"]) else float(s["base_x"])
			var prev_mp_x: float = float(s["x"])
			var diff_mp: float = target_mp_x - prev_mp_x
			if absf(diff_mp) > 0.6:
				s["x"] = prev_mp_x + signf(diff_mp) * minf(absf(diff_mp), 360.0 * s_dt)
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > prev_mp_x + 2.0 and float(p["x"]) < prev_mp_x + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - float(s["y"])) <= 10.0:
					p["x"] = float(p["x"]) + (float(s["x"]) - prev_mp_x)
			elif bool(s["triggered"]) and not bool(s["scoot_done"]):
				s["x"] = target_mp_x
				s["scoot_done"] = true
				if str(s.get("mode", "flee")) == "return":
					s["return_timer"] = 2.0
			elif bool(s["scoot_done"]) and str(s.get("mode", "flee")) == "return":
				s["return_timer"] = float(s["return_timer"]) - s_dt
				if float(s["return_timer"]) <= 0.0:
					s["triggered"] = false
					s["scoot_done"] = false
		elif st == "ceiling_crusher":
			if not is_in_active_layer(s, eng.active_layer):
				continue
			var cst: String = str(s.get("state", "idle"))
			if cst == "idle":
				var in_x: bool = (float(p["x"]) + float(p["w"]) > float(s["x"]) - float(s["trigger_pad_px"])) and (float(p["x"]) < float(s["x"]) + float(s["w"]) + float(s["trigger_pad_px"]))
				var below: bool = (float(p["y"]) >= float(s["y"]) + float(s["h"]) - 10.0) and (float(p["y"]) <= float(s["y"]) + float(s["h"]) + float(s["max_drop_px"]) + 1.8 * GridMath.TILE)
				if in_x and below:
					s["state"] = "warn"
					s["timer"] = 0.24
					eng.emit_sfx("fake_buzz")
			elif cst == "warn":
				s["timer"] = float(s["timer"]) - s_dt
				if float(s["timer"]) <= 0.0:
					s["state"] = "falling"
			elif cst == "falling":
				var prev_cy: float = float(s["y"])
				var target_cy: float = float(s["base_y"]) + float(s["max_drop_px"])
				s["y"] = minf(target_cy, prev_cy + 700.0 * s_dt)
				var crush_box: Rect2 = Rect2(float(s["x"]) + 5.0, float(s["y"]) + float(s["h"]) - 16.0, float(s["w"]) - 10.0, 20.0)
				if GridMath.aabb_overlap(p_rect, crush_box) and float(p["y"]) + 8.0 >= prev_cy + float(s["h"]) - 18.0:
					eng.kill_player(false, "crusher")
					return
				if float(s["y"]) >= target_cy - 0.5:
					s["y"] = target_cy
					s["state"] = "landed"
					s["timer"] = 0.95
					eng.emit_sfx("block")
					eng.trigger_shake(5.0, 0.16)
					var ug_c: String = str(s.get("unlock_group", ""))
					if ug_c != "":
						eng.signal_groups[ug_c] = true
			elif cst == "landed" and bool(s.get("rise_back", false)):
				s["timer"] = float(s["timer"]) - s_dt
				if float(s["timer"]) <= 0.0:
					s["state"] = "rising"
			elif cst == "rising":
				var prev_ry: float = float(s["y"])
				s["y"] = maxf(float(s["base_y"]), prev_ry - 170.0 * s_dt)
				if bool(p["on_ground"]) and float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf(float(p["y"]) + float(p["h"]) - prev_ry) <= 10.0:
					p["y"] = float(p["y"]) + (float(s["y"]) - prev_ry)
				if float(s["y"]) <= float(s["base_y"]) + 0.5:
					s["y"] = float(s["base_y"])
					s["state"] = "idle"
		elif st == "fake_error":
			if float(s.get("hit_flash", 0.0)) > 0.0:
				s["hit_flash"] = maxf(0.0, float(s["hit_flash"]) - dt)

static func handle_bullet_hit(eng: RefCounted, b: Dictionary) -> bool:
	var b_rect: Rect2 = Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]))
	var b_vx: float = float(b.get("vx", 400.0))

	for fe_var in eng.solids:
		var fe: Dictionary = fe_var
		if str(fe.get("t", "")) == "fake_error" and not bool(fe.get("broken", false)) and is_in_active_layer(fe, eng.active_layer):
			var fe_rect: Rect2 = Rect2(float(fe["x"]), float(fe["y"]), float(fe["w"]), float(fe["h"]))
			if GridMath.aabb_overlap(b_rect, fe_rect):
				var hit_top: bool = float(b["y"]) <= float(fe["y"]) + float(fe["h"]) * 0.44
				var hit_back: bool = str(fe.get("mode", "")) == "back_slash" and b_vx < 0.0
				if (str(fe.get("mode", "close_x")) == "close_x" and hit_top) or hit_back:
					fe["broken"] = true
					eng.broken_solid_keys[str(fe["key"])] = true
					var ug_fe: String = str(fe.get("unlock_group", ""))
					if ug_fe != "":
						eng.signal_groups[ug_fe] = true
					eng.emit_sfx("fake_wall_shatter")
					eng.spawn_particles(fe_rect.get_center().x, fe_rect.get_center().y, Color("#4ade80"), 18)
					eng.emit_toast("已点中右上角 [X] · 伪报错弹窗关闭！", "CLICKED [X] · FAKE ERROR CLOSED!", "s2_fake_error", "#4ade80")
				else:
					fe["hit_flash"] = 0.2
					eng.emit_sfx("fake_buzz")
					eng.emit_toast(
						"关不掉的弹窗 · 直接跳上红标题栏当桥踩！" if str(fe.get("mode", "")) == "walk_top" else "跳起来瞄准弹窗顶部红栏 [X] 关闭它！",
						"AIM AT THE TOP RED BAR [X]!", "s2_fake_error", "#fde047"
					)
				return true

	for gs_var in eng.solids:
		var gs: Dictionary = gs_var
		if str(gs.get("t", "")) == "glass_panel" and is_in_active_layer(gs, eng.active_layer):
			var probe_rect: Rect2 = Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]) + 26.0)
			if GridMath.aabb_overlap(probe_rect, Rect2(float(gs["x"]), float(gs["y"]), float(gs["w"]), float(gs["h"]))):
				if bool(gs.get("real", true)):
					gs["tested"] = true
					eng.emit_sfx("block")
				else:
					gs["revealed_fake"] = true
					eng.emit_sfx("fake_wall_shatter")

	var props: Dictionary = eng.lv_data.get("props", {})
	if bool(props.get("bulletDelayBubble", false)) and not bool(b.get("delayed_once", false)):
		for tb_var in eng.entities:
			var tb: Dictionary = tb_var
			if str(tb.get("t", "")) == "time_bubble":
				var tbc: Vector2 = Rect2(float(tb["x"]), float(tb["y"]), float(tb["w"]), float(tb["h"])).get_center()
				if b_rect.get_center().distance_to(tbc) <= float(tb.get("radius_px", 120.0)):
					b["delayed_once"] = true
					b["hold_timer"] = 0.62
					b["saved_vx"] = b_vx
					b["vx"] = 0.0
					b["life"] = float(b["life"]) + 1.2
					eng.emit_sfx("time_bubble_in")
					break

	for j in range(eng.entities.size() - 1, -1, -1):
		var e: Dictionary = eng.entities[j]
		var et: String = str(e.get("t", ""))
		if et != "layer_term" and not is_in_active_layer(e, eng.active_layer):
			continue
		var er: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er.size.x <= 0.0 or not GridMath.aabb_overlap(b_rect, er):
			continue

		if et == "signal_node":
			if float(e.get("hit_cd", 0.0)) > 0.0:
				return true
			e["hit_cd"] = 0.22
			if bool(e.get("fake", false)):
				eng.emit_sfx("fake_buzz")
				eng.emit_toast("伪信号节点 · 无光纤连接！", "DECOY NODE!", "cat_nav_taunt", "#ff2ab4")
				return true
			if str(e.get("mode", "")) == "reset":
				var rgs: Array = e.get("resetGroups", [])
				for rg_v in rgs:
					eng.signal_groups[str(rg_v)] = false
				eng.emit_sfx("node_off")
				return true
			var seq_g: String = str(e.get("seqGroup", ""))
			if seq_g != "":
				var cur_step: int = int(eng.seq_progress.get(seq_g, 0))
				var seq_step: int = int(e.get("seqStep", 1))
				var seq_tot: int = int(e.get("seqTotal", 3))
				if seq_step == cur_step + 1:
					eng.seq_progress[seq_g] = cur_step + 1
					eng.signal_groups[str(e.get("group", ""))] = true
					eng.emit_sfx("node_on")
					eng.unlock_ach("signal_hacker")
					if cur_step + 1 >= seq_tot and str(e.get("masterGroup", "")) != "":
						eng.signal_groups[str(e["masterGroup"])] = true
						eng.emit_toast("序列指令匹配 · 闸门开启！", "SEQUENCE MATCHED!", "s2_node_on", "#4ade80")
					else:
						eng.emit_toast("序列节点 (%d/%d) 已锁定！" % [cur_step + 1, seq_tot], "NODE LOCKED!", "s2_node_on", "#00f5ff")
				elif seq_step > cur_step + 1:
					if not bool(e.get("preservePrevSteps", false)):
						eng.seq_progress[seq_g] = 0
						for n_var in eng.entities:
							var n: Dictionary = n_var
							if str(n.get("t", "")) == "signal_node" and str(n.get("seqGroup", "")) == seq_g:
								eng.signal_groups[str(n.get("group", ""))] = false
					eng.emit_sfx("fake_buzz")
					eng.emit_toast("节点顺序错误 · 本组已重置！", "WRONG SEQUENCE!", "cat_nav_doubt", "#f43f5e")
				return true

			var cnt_g: String = str(e.get("countGroup", ""))
			var grp_n: String = str(e.get("group", ""))
			if cnt_g != "":
				if not bool(e.get("activated_once", false)):
					e["activated_once"] = true
					eng.signal_groups[cnt_g] = int(eng.signal_groups.get(cnt_g, 0)) + 1
				if grp_n != "":
					eng.signal_groups[grp_n] = true
			elif str(e.get("mode", "")) == "on":
				eng.signal_groups[grp_n] = true
			else:
				eng.signal_groups[grp_n] = not bool(eng.signal_groups.get(grp_n, false))
			var is_on: bool = bool(eng.signal_groups.get(grp_n, true)) if grp_n != "" else true
			eng.emit_sfx("node_on" if is_on else "node_off")
			eng.unlock_ach("signal_hacker")
			eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#00f5ff"), 40.0, 0.26)
			eng.emit_toast("信号链路已接通！" if is_on else "信号节点已切换！", "SIGNAL NODE TOGGLED!", "s2_node_on", "#4ade80" if is_on else "#00f5ff")
			return true

		if et == "polarity_node":
			if float(e.get("hit_cd", 0.0)) > 0.0:
				return true
			e["hit_cd"] = 0.22
			var p_grp: String = str(e.get("group", "m1"))
			var cur_p: String = str(eng.polarity_groups.get(p_grp, "blue"))
			var force_p: String = str(e.get("forcePole", ""))
			var next_p: String = force_p if force_p != "" else ("orange" if cur_p == "blue" else "blue")
			eng.polarity_groups[p_grp] = next_p
			eng.emit_sfx("magnet_pulse")
			eng.unlock_ach("polarity_pro")
			eng.add_shock_ring(er.get_center().x, er.get_center().y, Color("#fb923c" if next_p == "orange" else "#3b82f6"), 42.0, 0.26)
			return true

		if et == "layer_term":
			if float(e.get("hit_cd", 0.0)) <= 0.0:
				e["hit_cd"] = 0.28
				try_shift_dual_layer(eng, true)
			return true

		if et == "time_node":
			if float(e.get("hit_cd", 0.0)) > 0.0:
				return true
			e["hit_cd"] = 0.25
			var sl_g: String = str(e.get("sliceGroup", ""))
			if sl_g != "":
				for s_ts_var in eng.solids:
					var s_ts: Dictionary = s_ts_var
					if str(s_ts.get("t", "")) == "time_slice_plat" and str(s_ts.get("group", "")) == sl_g:
						s_ts["solid_timer"] = 4.6
				eng.emit_sfx("node_on")
				eng.emit_toast("时间残像电梯已实体化 (4.6s)！", "TIME-SLICE SOLIDIFIED!", "s2_time_node", "#00f5ff")
			else:
				eng.plat_freeze_timer = 0.0 if eng.plat_freeze_timer > 0.0 else 4.2
				eng.emit_sfx("node_on" if eng.plat_freeze_timer > 0.0 else "node_off")
			return true

		if et == "beat_clock":
			eng.beat_extend_bonus = 3.2
			eng.emit_sfx("boom")
			eng.emit_toast("节拍闸开启窗口已延长 +3.2s！", "BEAT GATE +3.2S!", "clock_gear", "#fde047")
			eng.entities.remove_at(j)
			return true

		if et == "root_term" and str(e.get("mode", "")) == "shoot":
			if not bool(e.get("activated", false)):
				e["activated"] = true
				var rt_g: String = str(e.get("group", ""))
				var rt_cg: String = str(e.get("countGroup", ""))
				if rt_g != "":
					eng.signal_groups[rt_g] = true
				if rt_cg != "":
					eng.signal_groups[rt_cg] = int(eng.signal_groups.get(rt_cg, 0)) + 1
				eng.emit_sfx("node_on")
				eng.emit_toast("根源权限终端已激活！", "ROOT TERMINAL ACTIVATED!", "s2_root_term", "#fde047")
			return true

		if et == "s2_enemy":
			var off_ge: String = str(e.get("offGroup", ""))
			if off_ge != "" and bool(eng.signal_groups.get(off_ge, false)):
				continue
			var ek: String = str(e.get("kind", ""))
			if ek == "forklift":
				eng.emit_sfx("armor_clang")
				e["armor_flash"] = 0.14
				return true
			if bool(e.get("is_phasing", false)):
				eng.add_float_text(float(e["x"]), float(e["y"]) - 8.0, "PHASE!", "#a855f7")
				continue
			if bool(e.get("bullet_immune", false)) or ek == "mech_shroom":
				eng.emit_sfx("armor_clang")
				e["armor_flash"] = 0.16
				eng.add_float_text(float(e["x"]), float(e["y"]) - 8.0, "IMMUNE", "#c084fc")
				return true
			if ek == "shield_mech" or ek == "mech_knight":
				var p_cut: bool = str(e.get("powerGroup", "")) != "" and bool(eng.signal_groups.get(str(e.get("powerGroup", "")), false))
				var f_sign: float = float(e.get("facing", -1))
				var behind: bool = (signf(b_vx) == signf(f_sign)) or bool(b.get("reflected", false)) or p_cut
				if not behind:
					eng.emit_sfx("armor_clang")
					e["armor_flash"] = 0.16
					eng.add_float_text(float(e["x"]), float(e["y"]) - 8.0, "GUARD", "#38bdf8")
					return true
			apply_monster_damage(eng, e, j, 2 if bool(b.get("upgraded", false)) else 1, int(signf(b_vx)), false)
			return true

		if et == "betray_spring" and str(e.get("mode", "")) == "calibrate":
			if float(e.get("hit_cd", 0.0)) <= 0.0:
				e["hit_cd"] = 0.25
				var next_cal: bool = not bool(e.get("calibrated", false))
				e["calibrated"] = next_cal
				e["revealed_evil"] = true
				if str(e.get("calibGroup", "")) != "":
					eng.signal_groups[str(e["calibGroup"])] = next_cal
				eng.emit_sfx("node_on" if next_cal else "node_off")
			return true

		if et == "trojan_heart" and float(e.get("respawn_cd", 0.0)) <= 0.0 and str(e.get("mode", "")) == "shoot_to_buff":
			e["respawn_cd"] = 999.0
			eng.player["shield"] = true
			if str(e.get("unlockGroup", "")) != "":
				eng.signal_groups[str(e["unlockGroup"])] = true
			eng.emit_sfx("shield_up")
			eng.hud_dirty = true
			return true

		if et == "curse_totem" and bool(e.get("can_disable", true)) and float(e.get("disable_timer", 0.0)) <= 0.0:
			e["disable_timer"] = 9999.0 if bool(e.get("permanentOff", false)) else 5.5
			if str(e.get("offGroup", "")) != "":
				eng.signal_groups[str(e["offGroup"])] = true
			eng.emit_sfx("node_off")
			return true

		if et == "fake_save" and not bool(e.get("purified", false)):
			e["purified"] = true
			eng.purified_save_keys[str(e["key"])] = true
			if str(e.get("unlockGroup", "")) != "":
				eng.signal_groups[str(e["unlockGroup"])] = true
			eng.emit_sfx("node_on")
			eng.emit_toast("恶魔病毒已格式化 · 化作安全存档点！", "SAFE CHECKPOINT READY!", "checkpoint_on", "#4ade80")
			return true

		if et == "mimic_chest":
			e["awake"] = true
			if str(e.get("mode", "")) == "bomb_feed":
				eng.emit_sfx("armor_clang")
				eng.emit_toast("宝箱怪免疫刀枪 · 往它嘴里投颗炸弹！", "FEED IT A BOMB!", "bomb", "#fde047")
			else:
				apply_monster_damage(eng, e, j, 1, int(signf(b_vx)), false)
			return true

		if et == "s2_boss" and not bool(e.get("defeated", false)):
			return damage_boss(eng, e, bool(b.get("reflected", false)), false, false, 1)

	return false

static func apply_monster_damage(eng: RefCounted, e: Dictionary, idx: int, dmg: int, hit_dir: int, is_melee: bool) -> void:
	e["hp"] = maxi(0, int(e.get("hp", 5)) - dmg)
	e["armor_flash"] = 0.20 if is_melee else 0.12
	e["jolt_x"] = float(hit_dir * (9 if is_melee else 4))
	var ecx: float = float(e["x"]) + float(e["w"]) * 0.5
	var ecy: float = float(e["y"]) + float(e["h"]) * 0.5
	eng.add_float_text(float(e["x"]) + 8.0, float(e["y"]) - 10.0, "-%d" % dmg, "#fde047" if is_melee else "#67e8f9")
	if is_melee:
		eng.add_shock_ring(ecx, ecy, Color("#fde047"), 42.0, 0.20)
	else:
		eng.emit_sfx("block")

	if int(e["hp"]) <= 0:
		eng.emit_sfx("enemy_kill")
		eng.trigger_shake(6.0, 0.20)
		var is_lg: bool = str(e.get("tier", "small")) == "large"
		var gain: int = 5 if is_lg else 2
		eng.save.add_coins(gain)
		eng.hud_dirty = true
		eng.add_float_text(float(e["x"]), float(e["y"]) - 22.0, "KO +%dG" % gain, "#4ade80")
		eng.spawn_particles(ecx, ecy, Color("#fb923c" if is_lg else "#00f5ff"), 20)
		var okg: String = str(e.get("onKillGroup", ""))
		if okg != "":
			eng.signal_groups[okg] = true
		if idx >= 0 and idx < eng.entities.size() and eng.entities[idx] == e:
			eng.entities.remove_at(idx)
		else:
			eng.entities.erase(e)

static func damage_boss(eng: RefCounted, boss: Dictionary, reflected: bool, is_melee: bool, is_bomb: bool, explicit_dmg: int) -> bool:
	var dmg: int = explicit_dmg if explicit_dmg > 0 else (5 if is_bomb else (3 if is_melee else 1))
	var bk: String = str(boss.get("bossKind", ""))
	var phase: int = int(boss.get("phase", 1))
	var can_dmg: bool = float(boss.get("vuln_timer", 0.0)) > 0.0

	if bk == "signal_storm":
		if phase == 1:
			can_dmg = bool(eng.signal_groups.get("b60_n1", false)) and bool(eng.signal_groups.get("b60_n2", false)) and bool(eng.signal_groups.get("b60_n3", false))
		elif phase == 2:
			can_dmg = float(boss.get("vuln_timer", 0.0)) > 0.0 or is_melee
		else:
			can_dmg = bool(eng.signal_groups.get("b60_cable", false))
	elif bk == "reassembly_mech":
		if phase == 1:
			can_dmg = bool(eng.signal_groups.get("b67_wire", false))
		elif phase == 2:
			can_dmg = true
		else:
			if (is_bomb or is_melee) and not bool(boss.get("armor_cracked", false)):
				boss["armor_cracked"] = true
			can_dmg = is_bomb or is_melee or bool(boss.get("armor_cracked", false))
	elif bk == "mecha_sovereign":
		if phase == 1:
			can_dmg = bool(eng.signal_groups.get("b70_p1", false)) and bool(eng.signal_groups.get("b70_p2", false))
		elif phase == 2:
			can_dmg = float(eng.player.get("x", 0.0)) > float(boss["x"]) + float(boss["w"]) * 0.45 or float(boss.get("vuln_timer", 0.0)) > 0.0 or is_melee
		else:
			can_dmg = reflected or is_melee or bool(eng.signal_groups.get("b70_side", false))
	elif bk == "fracture_core":
		if phase == 1:
			can_dmg = eng.active_layer == int(boss.get("active_core_layer", 0))
		elif phase == 2:
			can_dmg = float(boss.get("vuln_timer", 0.0)) > 0.0 or is_melee
		else:
			can_dmg = bool(eng.signal_groups.get("b80_echo_lock", false)) and eng.active_layer == 1
	elif bk == "chrono_skull":
		boss["stun_timer"] = 3.2 if is_melee else 1.8
		boss["hp"] = maxi(1, int(boss.get("hp", 25)) - dmg)
		eng.emit_sfx("node_on")
		eng.add_float_text(float(boss["x"]) + 12.0, float(boss["y"]) - 12.0, "-%d STUN!" % dmg, "#fde047")
		return true
	elif bk == "chrono_regent":
		if phase == 1:
			can_dmg = true
		elif phase == 2:
			can_dmg = bool(eng.signal_groups.get("b90_past_sw", false)) and eng.active_layer == 1
		else:
			can_dmg = float(boss.get("vuln_timer", 0.0)) > 0.0 or is_melee or bool(eng.signal_groups.get("b90_final_sw", false))
	elif bk == "admin_arena":
		can_dmg = int(eng.signal_groups.get("b98_count", 0)) >= 3
	elif bk == "null_admin":
		if phase == 1:
			can_dmg = bool(eng.signal_groups.get("b100_p1", false))
		elif phase == 2:
			can_dmg = bool(eng.signal_groups.get("b100_p2", false))
		else:
			can_dmg = int(eng.signal_groups.get("b100_calm_count", 0)) >= 3

	if not can_dmg:
		eng.emit_sfx("armor_clang")
		boss["armor_flash"] = 0.16
		eng.add_float_text(float(boss["x"]) + 20.0, float(boss["y"]) - 12.0, "SHIELDED", "#94a3b8")
		return true

	boss["hp"] = maxi(0, int(boss.get("hp", 25)) - dmg)
	boss["armor_flash"] = 0.22
	eng.emit_sfx("boss_phase_break")
	eng.trigger_shake(6.5, 0.20)
	var bcx: float = float(boss["x"]) + float(boss["w"]) * 0.5
	var bcy: float = float(boss["y"]) + float(boss["h"]) * 0.5
	eng.add_shock_ring(bcx, bcy, Color("#fde047" if is_melee else "#00f5ff"), 58.0, 0.28)
	eng.add_float_text(bcx - 10.0, float(boss["y"]) - 16.0, "-%d" % dmg, "#fde047")

	var max_p: int = int(boss.get("max_phase", 3))
	var p2_th: int = 12 if max_p == 2 else 17
	var p3_th: int = 0 if max_p == 2 else 9

	if int(boss["hp"]) <= 0:
		boss["defeated"] = true
		boss["phase"] = max_p
		var dgg: String = str(boss.get("defeatGateGroup", ""))
		if dgg != "":
			eng.signal_groups[dgg] = true
		eng.enemy_shots.clear()
		eng.spawn_particles(bcx, bcy, Color("#00f5ff"), 36)
		eng.emit_toast("统御核心已被彻底击溃 · 通路开启！", "BOSS DEFEATED · EXIT UNLOCKED!", "cat_nav_cheer", "#4ade80")
		if bool(boss.get("autoWinOnDefeat", false)):
			eng.trigger_level_win()
		return true

	var hp_now: int = int(boss["hp"])
	var target_phase: int = 3 if (max_p >= 3 and hp_now <= p3_th) else (2 if hp_now <= p2_th else 1)
	if target_phase > phase:
		boss["phase"] = target_phase
		boss["vuln_timer"] = 2.6
		var spawn_d: Dictionary = eng.lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
		eng.active_checkpoint = {
			"x": float(boss.get("safeRespawnGx", spawn_d.get("x", 2.0))),
			"y": float(boss.get("safeRespawnGy", spawn_d.get("y", 2.0))),
			"bullet_up": bool(eng.player.get("bullet_up", false)),
			"max_jumps": int(eng.player.get("max_jumps", 1)),
			"has_flight": bool(eng.player.get("has_flight", false)),
			"layer": eng.active_layer,
			"boss_phase": target_phase,
			"boss_hp": hp_now,
			"signal_groups": eng.signal_groups.duplicate(true),
			"polarity_groups": eng.polarity_groups.duplicate(true),
			"seq_progress": eng.seq_progress.duplicate(true),
			"filled_slot_keys": eng.filled_slot_keys.duplicate(true),
			"consumed_carry_keys": eng.consumed_carry_keys.duplicate(true),
			"carrying_item_key": str(eng.carrying_item.get("key", "")) if not eng.carrying_item.is_empty() else "",
			"broken_solid_keys": eng.broken_solid_keys.duplicate(true),
			"purified_save_keys": eng.purified_save_keys.duplicate(true)
		}
		eng.emit_toast("BOSS 阶段突破 (%d/%d)！" % [target_phase, max_p], "BOSS PHASE %d/%d!" % [target_phase, max_p], "cat_nav_cheer", "#fde047")
	return true

static func step_post_move(eng: RefCounted, dt: float, world_dt: float) -> void:
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)) or eng.lv_id < 51:
		return
	var props: Dictionary = eng.lv_data.get("props", {})
	var p_rect: Rect2 = Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))

	if bool(p["on_ground"]):
		for s_var in eng.solids:
			var s: Dictionary = s_var
			if str(s.get("t", "")) == "conveyor" and is_in_active_layer(s, eng.active_layer):
				var stop_g: String = str(s.get("stop_group", ""))
				if stop_g != "" and bool(eng.signal_groups.get(stop_g, false)):
					continue
				if float(p["x"]) + float(p["w"]) > float(s["x"]) + 2.0 and float(p["x"]) < float(s["x"]) + float(s["w"]) - 2.0 and absf((float(p["y"]) + float(p["h"])) - float(s["y"])) <= 10.0:
					p["x"] = float(p["x"]) + float(s.get("belt_vx", 135.0)) * dt
					p_rect.position.x = float(p["x"])

	for b_var in eng.bullets:
		var b: Dictionary = b_var
		if float(b.get("hold_timer", 0.0)) > 0.0:
			b["hold_timer"] = float(b["hold_timer"]) - dt
			if float(b["hold_timer"]) <= 0.0:
				b["vx"] = float(b.get("saved_vx", 480.0))
				eng.emit_sfx("shoot")

	eng.echo_clones = []
	var echo_mode: String = str(props.get("echoMode", ""))
	if echo_mode != "":
		var delays: Array[float] = [1.7, 3.4] if echo_mode == "dual_coop" else [float(props.get("echoDelay", 1.75))]
		for d_idx in range(delays.size()):
			var d_sec: float = delays[d_idx]
			if eng.time_elapsed >= d_sec:
				var snap: Dictionary = eng.find_trail_snapshot(eng.time_elapsed - d_sec)
				if not snap.is_empty():
					var cat_m: bool = bool(props.get("catMirror", false))
					if cat_m and bool(eng.signal_groups.get("cat_mirror_trapped", false)):
						continue
					var cl: Dictionary = {
						"x": float(snap["x"]), "y": float(snap["y"]),
						"w": float(p["w"]), "h": float(p["h"]),
						"facing": int(snap["facing"]),
						"layer": int(snap.get("layer", 0)),
						"hazard": (echo_mode == "hazard"),
						"cat_mirror": cat_m
					}
					eng.echo_clones.append(cl)
					if bool(cl["hazard"]) and int(cl["layer"]) == eng.active_layer:
						var hz_rect: Rect2 = Rect2(float(cl["x"]) + 4.0, float(cl["y"]) + 4.0, float(cl["w"]) - 8.0, float(cl["h"]) - 8.0)
						if GridMath.aabb_overlap(p_rect, hz_rect):
							eng.kill_player(false, "shadow")
							return

	var pad_counts: Dictionary = {}
	var pad_totals: Dictionary = {}
	for ep_var in eng.entities:
		var ep: Dictionary = ep_var
		if str(ep.get("t", "")) == "echo_pad":
			var pg: String = str(ep.get("padGroup", "ep1"))
			pad_totals[pg] = int(pad_totals.get(pg, 0)) + 1
			if bool(ep.get("latched", false)):
				ep["depressed"] = true
				pad_counts[pg] = int(pad_counts.get(pg, 0)) + 1
				continue
			var pad_box: Rect2 = Rect2(float(ep["x"]) - 4.0, float(ep["y"]) - 18.0, float(ep["w"]) + 8.0, float(ep["h"]) + 22.0)
			var pressed: bool = is_in_active_layer(ep, eng.active_layer) and GridMath.aabb_overlap(p_rect, pad_box)
			if not pressed:
				for cl_var in eng.echo_clones:
					var cl2: Dictionary = cl_var
					var ep_l: int = int(ep.get("layer", -1))
					if (ep_l < 0 or ep_l == int(cl2["layer"])) and GridMath.aabb_overlap(Rect2(float(cl2["x"]), float(cl2["y"]), float(cl2["w"]), float(cl2["h"])), pad_box):
						pressed = true
						break
			if not pressed:
				for sb_var in eng.solids:
					var sb: Dictionary = sb_var
					if str(sb.get("t", "")) == "polarity_block" and GridMath.aabb_overlap(Rect2(float(sb["x"]), float(sb["y"]), float(sb["w"]), float(sb["h"])), pad_box):
						pressed = true
						break
			ep["depressed"] = pressed
			if pressed:
				pad_counts[pg] = int(pad_counts.get(pg, 0)) + 1

	for pg_k in pad_totals.keys():
		var pg_str: String = str(pg_k)
		if int(pad_counts.get(pg_str, 0)) >= int(pad_totals[pg_str]) and not bool(eng.signal_groups.get(pg_str, false)):
			eng.signal_groups[pg_str] = true
			for ep2_var in eng.entities:
				var ep2: Dictionary = ep2_var
				if str(ep2.get("t", "")) == "echo_pad" and str(ep2.get("padGroup", "ep1")) == pg_str:
					ep2["latched"] = true
			eng.emit_sfx("node_on")
			eng.emit_toast("回声踏板同步激活 · 通路开启！", "ECHO SWITCHES SYNCHRONIZED!", "cat_nav_cheer", "#4ade80")

	if not eng.carrying_item.is_empty():
		eng.carrying_item["x"] = float(p["x"]) + (-14.0 if int(p["facing"]) > 0 else 18.0)
		eng.carrying_item["y"] = float(p["y"]) - 18.0

	var s2_needs_bomb: bool = false
	for s_nb_var in eng.solids:
		var s_nb: Dictionary = s_nb_var
		if str(s_nb.get("t", "")) == "destructible" and not bool(s_nb.get("broken", false)) and not bool(s_nb.get("bullet_break", false)):
			s2_needs_bomb = true
			break
	if not s2_needs_bomb:
		for e_nb_var in eng.entities:
			var e_nb: Dictionary = e_nb_var
			if str(e_nb.get("t", "")) == "mimic_chest" and str(e_nb.get("mode", "")) == "bomb_feed":
				s2_needs_bomb = true
				break
	var has_bp: bool = false
	for e_bp_var in eng.entities:
		var e_bp: Dictionary = e_bp_var
		if str(e_bp.get("t", "")) == "bomb_pickup":
			has_bp = true
			break
	if s2_needs_bomb and int(p.get("bombs", 0)) <= 0 and eng.bombs.is_empty() and not has_bp:
		eng.s2_bomb_regen += dt
		if eng.s2_bomb_regen >= 1.5:
			eng.s2_bomb_regen = 0.0
			var objs_raw: Array = eng.lv_data.get("objs", [])
			for o_bp_var in objs_raw:
				var o_bp: Dictionary = o_bp_var
				if str(o_bp.get("t", "")) == "bomb_pickup":
					eng.entities.append({
						"key": "s2_regen_bomb_" + str(Time.get_ticks_msec()),
						"t": "bomb_pickup",
						"x": GridMath.gx_to_px(float(o_bp.get("x", 2.0))) + 4.0,
						"y": GridMath.gy_to_py(float(o_bp.get("y", 2.0)), 0.88),
						"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE,
						"layer": -1
					})
					break
	else:
		eng.s2_bomb_regen = 0.0

	for i in range(eng.entities.size() - 1, -1, -1):
		if i >= eng.entities.size():
			continue
		var e: Dictionary = eng.entities[i]
		if float(e.get("hit_cd", 0.0)) > 0.0:
			e["hit_cd"] = maxf(0.0, float(e["hit_cd"]) - dt)
		var et: String = str(e.get("t", ""))
		var e_mul: float = get_local_time_scale(float(e.get("x", 0.0)) + float(e.get("w", 32.0)) * 0.5, float(e.get("y", 0.0)) + float(e.get("h", 32.0)) * 0.5, eng.entities)
		var e_dt: float = world_dt * e_mul

		if et == "piston":
			var off_gp: String = str(e.get("offGroup", ""))
			if off_gp != "" and bool(eng.signal_groups.get(off_gp, false)):
				e["y"] = float(e["base_y"])
				e["state"] = "idle"
				continue
			e["local_clock"] = float(e.get("local_clock", 0.0)) + e_dt
			var cyc_pi: float = fposmod(float(e["local_clock"]) + float(e["offset"]), float(e["period"]))
			if cyc_pi < 0.85:
				e["state"] = "warn"
				e["y"] = float(e["base_y"])
			elif cyc_pi < 1.25:
				e["state"] = "pre"
				e["y"] = float(e["base_y"]) + 8.0
			elif cyc_pi < 1.85:
				e["state"] = "slam"
				e["y"] = float(e["base_y"]) + float(e["max_drop_px"]) * minf(1.0, (cyc_pi - 1.25) / 0.14)
			else:
				e["state"] = "retract"
				e["y"] = float(e["base_y"]) + float(e["max_drop_px"]) * maxf(0.0, 1.0 - (cyc_pi - 1.85) / maxf(0.2, float(e["period"]) - 1.85))
			if is_in_active_layer(e, eng.active_layer) and (str(e["state"]) == "slam" or str(e["state"]) == "retract"):
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 5.0, float(e["y"]) + 4.0, float(e["w"]) - 10.0, float(e["h"]) - 4.0)):
					eng.kill_player(false, "piston")
					return
			continue

		if et == "saw_track":
			var off_gs: String = str(e.get("offGroup", ""))
			if off_gs != "" and bool(eng.signal_groups.get(off_gs, false)):
				continue
			e["phase"] = float(e["phase"]) + e_dt * float(e["speed"])
			var u_saw: float = 0.5 - 0.5 * cos(float(e["phase"]))
			e["x"] = float(e["base_x"]) + float(e["dx_px"]) * u_saw
			e["y"] = float(e["base_y"]) - float(e["dy_px"]) * u_saw
			if is_in_active_layer(e, eng.active_layer) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + 8.0, float(e["w"]) - 16.0, float(e["h"]) - 16.0)):
				eng.kill_player(false, "saw")
				return
			continue

		if et == "electric_arc":
			var off_ga: String = str(e.get("offGroup", ""))
			if off_ga != "" and bool(eng.signal_groups.get(off_ga, false)):
				continue
			var ea_rect: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
			if bool(e.get("trapCatMirror", false)):
				for cl_cm_var in eng.echo_clones:
					var cl_cm: Dictionary = cl_cm_var
					if bool(cl_cm.get("cat_mirror", false)) and GridMath.aabb_overlap(Rect2(float(cl_cm["x"]), float(cl_cm["y"]), float(cl_cm["w"]), float(cl_cm["h"])), ea_rect):
						eng.signal_groups["cat_mirror_trapped"] = true
						var tug: String = str(e.get("trapUnlockGroup", ""))
						if tug != "":
							eng.signal_groups[tug] = true
						eng.emit_sfx("boss_phase_break")
						break
			if is_in_active_layer(e, eng.active_layer) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 4.0, float(e["y"]) + 4.0, float(e["w"]) - 8.0, float(e["h"]) - 6.0)):
				eng.kill_player(false, "arc")
				return
			continue

		if et == "s2_enemy":
			_step_s2_enemy(eng, e, p, p_rect, dt, e_dt)
			if bool(p.get("dead", false)):
				return
			continue

		if et == "curse_totem":
			var dt_ct: float = float(e.get("disable_timer", 0.0))
			if dt_ct > 0.0 and dt_ct < 9000.0:
				e["disable_timer"] = maxf(0.0, dt_ct - dt)
			continue

		if et == "trojan_heart":
			var rcd: float = float(e.get("respawn_cd", 0.0))
			if rcd > 0.0 and rcd < 500.0:
				e["respawn_cd"] = maxf(0.0, rcd - dt)
			if float(e["respawn_cd"]) > 0.0:
				continue
			if is_in_active_layer(e, eng.active_layer) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))):
				var th_m: String = str(e.get("mode", "heavy_curse"))
				if th_m == "shoot_to_buff":
					eng.kill_player(true, "trojan")
					return
				elif th_m == "heavy_curse":
					e["respawn_cd"] = 3.2
					p["heavy_curse_timer"] = 4.6
					eng.emit_sfx("poison")
					eng.emit_toast("中计：千斤坠 (4.6s) · 跳不高但抗狂风！", "LEAD BOOTS (4.6S) · WINDPROOF!", "s2_trojan_heart", "#a3e635")
				else:
					e["respawn_cd"] = 3.5
					p["reverse_curse_timer"] = 4.5
					eng.emit_sfx("poison")
					eng.emit_toast("中计：左右脑互搏 (4.5s) · 方向反转！", "CONTROLS REVERSED (4.5S)!", "s2_trojan_heart", "#e879f9")
			continue

		if et == "betray_spring":
			if float(e.get("spring_anim", 0.0)) > 0.0:
				e["spring_anim"] = maxf(0.0, float(e["spring_anim"]) - dt * 2.5)
			if is_in_active_layer(e, eng.active_layer) and float(p["grav_dir"]) > 0.0 and float(p["vy"]) >= -25.0:
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))):
					e["spring_anim"] = 1.0
					e["revealed_evil"] = true
					p["on_ground"] = false
					if bool(e.get("calibrated", false)):
						p["vy"] = -825.0
						p["spring_trail_timer"] = 0.44
						eng.emit_sfx("spring")
					else:
						p["vx"] = float(e.get("launch_vx", -455.0))
						p["vy"] = float(e.get("launch_vy", -510.0))
						eng.emit_sfx("fake_buzz")
			continue

		if et == "mimic_chest":
			var mc_rect: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
			if not bool(e.get("awake", false)) and is_in_active_layer(e, eng.active_layer) and p_rect.get_center().distance_to(mc_rect.get_center()) < 2.5 * GridMath.TILE:
				e["awake"] = true
				eng.emit_sfx("fake_buzz")
			if bool(e.get("awake", false)) and is_in_active_layer(e, eng.active_layer):
				if str(e.get("mode", "ambush")) == "ambush":
					e["hop_cd"] = float(e.get("hop_cd", 0.6)) - e_dt
					var gy_mc: float = float(e["ground_y"])
					if float(e["hop_cd"]) <= 0.0 and float(e["y"]) >= gy_mc - 1.0:
						e["hop_cd"] = 1.45
						e["vy"] = -340.0
						e["vx"] = (-1.0 if float(p["x"]) < float(e["x"]) else 1.0) * 115.0
					if float(e["y"]) < gy_mc or float(e["vy"]) < 0.0:
						e["vy"] = float(e["vy"]) + 1050.0 * e_dt
						e["y"] = float(e["y"]) + float(e["vy"]) * e_dt
						e["x"] = clampf(float(e["x"]) + float(e["vx"]) * e_dt, float(e["spawn_x"]) - 3.2 * GridMath.TILE, float(e["spawn_x"]) + 3.2 * GridMath.TILE)
						if float(e["y"]) >= gy_mc:
							e["y"] = gy_mc
							e["vy"] = 0.0
				if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + 8.0, float(e["w"]) - 16.0, float(e["h"]) - 12.0)):
					eng.kill_player(false, "mimic")
					return
			continue

		if et == "mimic_flag":
			if not is_in_active_layer(e, eng.active_layer):
				continue
			var mf_rect: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
			if not bool(e.get("revealed", false)) and not bool(e.get("tamed", false)) and p_rect.get_center().distance_to(mf_rect.get_center()) < 2.65 * GridMath.TILE:
				e["revealed"] = true
				eng.emit_sfx("fake_buzz")
				if str(e.get("mode", "")) == "flee_off":
					e["fleeing"] = true
			if bool(e.get("fleeing", false)):
				e["x"] = float(e["x"]) + float(e.get("fleeDir", 1.0)) * 235.0 * e_dt
				if absf(float(e["x"]) - float(e["spawn_x"])) > 3.2 * GridMath.TILE:
					e["y"] = float(e["y"]) + 420.0 * e_dt
					if float(e["y"]) > GridMath.WORLD_ORIGIN_Y + 90.0:
						if str(e.get("unlockGroup", "")) != "":
							eng.signal_groups[str(e["unlockGroup"])] = true
						eng.entities.remove_at(i)
				continue
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + 6.0, float(e["w"]) - 16.0, float(e["h"]) - 10.0)):
				if bool(e.get("tamed", false)):
					eng.trigger_level_win()
				else:
					eng.kill_player(true, "mimic_flag")
				return
			continue

		if et == "troll_hand":
			var off_gh: String = str(e.get("offGroup", ""))
			if bool(e.get("parried", false)) or (off_gh != "" and bool(eng.signal_groups.get(off_gh, false))):
				continue
			e["local_clock"] = float(e.get("local_clock", 0.0)) + e_dt
			var cyc_th: float = fposmod(float(e["local_clock"]) + float(e["offset"]), float(e["period"]))
			var th_mode: String = str(e.get("mode", "parry_duel"))
			if th_mode == "boost_up":
				var lift: float = sin((cyc_th / float(e["period"])) * TAU)
				var prev_thy: float = float(e["y"])
				e["y"] = float(e["base_y"]) - maxf(0.0, lift) * float(e["reach_px"])
				if is_in_active_layer(e, eng.active_layer) and float(p["vy"]) >= -30.0 and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 6.0, float(e["y"]) - 10.0, float(e["w"]) - 12.0, 28.0)):
					p["y"] = float(e["y"]) - float(p["h"]) + 4.0
					p["vy"] = minf(float(p["vy"]), (float(e["y"]) - prev_thy) / maxf(0.008, dt))
					p["on_ground"] = true
			else:
				if cyc_th < 0.75:
					e["state"] = "idle"
					e["x"] = float(e["base_x"])
					e["y"] = float(e["base_y"])
				elif cyc_th < 1.30:
					e["state"] = "windup"
					e["y"] = float(e["base_y"]) - 10.0
					e["x"] = float(e["base_x"]) + sin(cyc_th * 45.0) * 4.0
				elif cyc_th < 1.85:
					e["state"] = "slap"
					var u_th: float = minf(1.0, (cyc_th - 1.30) / 0.16)
					if th_mode == "parry_duel":
						e["x"] = float(e["base_x"]) - float(e["reach_px"]) * u_th
						e["y"] = float(e["base_y"])
					else:
						e["y"] = float(e["base_y"]) + float(e["reach_px"]) * u_th
				else:
					e["state"] = "recover"
					var u_rec: float = maxf(0.0, 1.0 - (cyc_th - 1.85) / maxf(0.2, float(e["period"]) - 1.85))
					if th_mode == "parry_duel":
						e["x"] = float(e["base_x"]) - float(e["reach_px"]) * u_rec
					else:
						e["y"] = float(e["base_y"]) + float(e["reach_px"]) * u_rec
				if is_in_active_layer(e, eng.active_layer) and str(e["state"]) == "slap" and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 10.0, float(e["y"]) + 10.0, float(e["w"]) - 20.0, float(e["h"]) - 20.0)):
					eng.kill_player(false, "slap")
					return
			continue

		if et == "fake_save":
			if is_in_active_layer(e, eng.active_layer) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 6.0, float(e["y"]) + 6.0, float(e["w"]) - 12.0, float(e["h"]) - 8.0)):
				if not bool(e.get("purified", false)):
					eng.kill_player(false, "fake_save")
					return
				elif not bool(e.get("active", false)):
					for oth_var in eng.entities:
						var oth: Dictionary = oth_var
						if str(oth.get("t", "")) == "checkpoint" or str(oth.get("t", "")) == "fake_save":
							oth["active"] = false
					e["active"] = true
					eng.save_checkpoint_at(float(e["gx"]), float(e["gy"]))
			continue

		if et == "peace_dove":
			e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
			if float(e["x"]) <= float(e["min_px"]):
				e["x"] = float(e["min_px"])
				e["vx"] = absf(float(e["vx"]))
			elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
				e["x"] = float(e["max_px"]) - float(e["w"])
				e["vx"] = -absf(float(e["vx"]))
			e["y"] = float(e["base_y"]) + sin(eng.time_elapsed * 3.6 + float(e["x"]) * 0.02) * 10.0
			if float(e.get("angry_timer", 0.0)) > 0.0:
				e["angry_timer"] = float(e["angry_timer"]) - dt
				e["bomb_cd"] = float(e.get("bomb_cd", 0.0)) - e_dt
				if float(e["bomb_cd"]) <= 0.0 and is_in_active_layer(e, eng.active_layer) and absf(float(p["x"]) - float(e["x"])) < 440.0:
					e["bomb_cd"] = 0.72
					eng.enemy_shots.append({
						"x": float(e["x"]) + float(e["w"]) * 0.5 - 7.0, "y": float(e["y"]) + float(e["h"]) - 6.0,
						"w": 14.0, "h": 14.0,
						"vx": -55.0 if float(p["x"]) < float(e["x"]) else 55.0,
						"vy": 80.0, "grav": 640.0, "kind": "lob",
						"layer": int(e.get("layer", -1)), "life": 2.4
					})
					eng.emit_sfx("shoot")
				if float(e["angry_timer"]) <= 0.0:
					var pgg2: String = str(e.get("peaceGateGroup", ""))
					if pgg2 != "":
						eng.signal_groups[pgg2] = true
					eng.emit_sfx("node_on")
			elif is_in_active_layer(e, eng.active_layer) and not bool(e.get("gifted_shield", false)) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))):
				e["gifted_shield"] = true
				p["shield"] = true
				eng.emit_sfx("shield_up")
				eng.hud_dirty = true
			continue

		if et == "s2_boss" and not bool(e.get("defeated", false)):
			_update_s2_boss_ai(eng, e, p, p_rect, dt, e_dt)
			if bool(p.get("dead", false)):
				return
			continue

		if et != "layer_term" and not is_in_active_layer(e, eng.active_layer):
			continue
		var er_post: Rect2 = Rect2(float(e.get("x", 0.0)), float(e.get("y", 0.0)), float(e.get("w", 0.0)), float(e.get("h", 0.0)))
		if er_post.size.x <= 0.0 or not GridMath.aabb_overlap(p_rect, er_post):
			continue

		if et == "decoy_btn" and not bool(e.get("pressed", false)):
			e["pressed"] = true
			eng.emit_sfx("fake_buzz")
			eng.emit_toast("红钮是装饰诱饵！去找发光青色节点！", "RED BUTTON IS A DECOY!", "cat_nav_taunt", "#ff2ab4")
		elif et == "signal_battery" or et == "root_item":
			if not bool(e.get("carried", false)) and eng.carrying_item.is_empty():
				e["carried"] = true
				eng.carrying_item = e
				eng.emit_sfx("coin")
				eng.hud_dirty = true
		elif et == "battery_slot" or et == "root_slot":
			if not bool(e.get("filled", false)) and not eng.carrying_item.is_empty():
				var req_c: String = str(e.get("reqCode", ""))
				var badge_c: String = str(eng.carrying_item.get("badgeCode", ""))
				if req_c == "" or badge_c == req_c:
					e["filled"] = true
					eng.filled_slot_keys[str(e["key"])] = true
					eng.consumed_carry_keys[str(eng.carrying_item["key"])] = true
					eng.carrying_item["carried"] = false
					eng.carrying_item["inserted"] = true
					eng.carrying_item["x"] = -99999.0
					eng.carrying_item = {}
					if str(e.get("group", "")) != "":
						eng.signal_groups[str(e["group"])] = true
					if str(e.get("countGroup", "")) != "":
						eng.signal_groups[str(e["countGroup"])] = int(eng.signal_groups.get(str(e["countGroup"]), 0)) + 1
					eng.emit_sfx("node_on")
					eng.hud_dirty = true
		elif et == "echo_rec_pad":
			if float(e.get("hit_cd", 0.0)) <= 0.0:
				e["hit_cd"] = 1.0
				eng.history_trail.clear()
				eng.emit_sfx("node_off")
		elif et == "portal" and eng.portal_cooldown <= 0.0 and str(e.get("role", "")) != "out":
			eng.portal_cooldown = 0.58
			eng.emit_sfx("portal_warp")
			if e.has("destLayer") and e["destLayer"] != null:
				eng.active_layer = int(e["destLayer"])
			if e.has("destX"):
				p["x"] = GridMath.gx_to_px(float(e["destX"])) + 6.0
				p["y"] = GridMath.gy_to_py(float(e.get("destY", 2.0)), 0.0) - float(p["h"])
				p["vx"] = float(e.get("exitDir", 0.0)) * 120.0
				p["vy"] = 0.0
			eng.hud_dirty = true
		elif et == "root_term":
			var rtm: String = str(e.get("mode", ""))
			if rtm == "jump_touch" and not bool(e.get("activated", false)):
				e["activated"] = true
				if str(e.get("group", "")) != "":
					eng.signal_groups[str(e["group"])] = true
				if str(e.get("countGroup", "")) != "":
					eng.signal_groups[str(e["countGroup"])] = int(eng.signal_groups.get(str(e["countGroup"]), 0)) + 1
				eng.emit_sfx("node_on")
			elif rtm == "calm_touch" and not bool(e.get("activated", false)):
				if float(p.get("attack_anim", 0.0)) <= 0.0 and eng.bullets.is_empty():
					e["activated"] = true
					if str(e.get("group", "")) != "":
						eng.signal_groups[str(e["group"])] = true
					if str(e.get("countGroup", "")) != "":
						eng.signal_groups[str(e["countGroup"])] = int(eng.signal_groups.get(str(e["countGroup"]), 0)) + 1
					eng.emit_sfx("real_win")
					if bool(e.get("winOnCalm", false)):
						eng.trigger_level_win()
						return
		elif et == "mem_shard":
			var sid2: String = str(e.get("shardId", e["key"]))
			eng.save.shards[sid2] = true
			eng.save.persist()
			eng.emit_sfx("ach_unlock")
			if eng.lv_id == 69 and not bool(p.get("shield", false)):
				p["shield"] = true
				eng.hud_dirty = true
			if eng.save.shards.size() >= 3:
				eng.unlock_ach("shard_hunter")
			eng.entities.remove_at(i)

static func _step_s2_enemy(eng: RefCounted, e: Dictionary, p: Dictionary, p_rect: Rect2, dt: float, e_dt: float) -> void:
	var off_g: String = str(e.get("offGroup", ""))
	if off_g != "" and bool(eng.signal_groups.get(off_g, false)):
		return
	if float(e.get("armor_flash", 0.0)) > 0.0:
		e["armor_flash"] = maxf(0.0, float(e["armor_flash"]) - dt)
	e["jolt_x"] = float(e.get("jolt_x", 0.0)) * pow(0.04, dt)

	var kind: String = str(e.get("kind", "patrol"))
	if kind == "forklift":
		e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
		if float(e["x"]) <= float(e["min_px"]):
			e["x"] = float(e["min_px"])
			e["vx"] = absf(float(e["vx"]))
		elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
			e["x"] = float(e["max_px"]) - float(e["w"])
			e["vx"] = -absf(float(e["vx"]))
		if is_in_active_layer(e, eng.active_layer) and GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 6.0, float(e["y"]) + 6.0, float(e["w"]) - 12.0, float(e["h"]) - 10.0)):
			if float(p["vy"]) >= 0.0 and float(p["y"]) + float(p["h"]) <= float(e["y"]) + 18.0:
				p["y"] = float(e["y"]) - float(p["h"])
				p["vy"] = -420.0
				p["on_ground"] = false
				eng.emit_sfx("spring")
			else:
				eng.kill_player(false, "forklift")
		return

	if kind == "turret":
		e["cycle"] = float(e.get("cycle", 0.0)) + e_dt
		var per_t: float = float(e.get("period", 2.8))
		var c_t: float = fposmod(float(e["cycle"]), per_t)
		var ap: String = "cool" if c_t < (per_t - 0.95) else ("lock" if c_t < (per_t - 0.12) else "fire")
		e["aim_phase"] = ap
		if ap == "fire" and not bool(e.get("fired_this_beat", false)) and is_in_active_layer(e, eng.active_layer) and absf(float(e["x"]) - float(p["x"])) < 620.0:
			e["fired_this_beat"] = true
			var dir_t: float = float(e["dir"]) if e.has("dir") else (-1.0 if float(p["x"]) < float(e["x"]) else 1.0)
			eng.enemy_shots.append({
				"x": (float(e["x"]) + float(e["w"])) if dir_t > 0.0 else (float(e["x"]) - 14.0),
				"y": float(e["y"]) + float(e["h"]) * 0.36,
				"w": 16.0, "h": 8.0,
				"vx": dir_t * float(e.get("shotSpd", 290.0)), "vy": 0.0,
				"layer": int(e.get("layer", -1)), "life": 3.2
			})
			eng.emit_sfx("shoot")
		elif ap != "fire":
			e["fired_this_beat"] = false
		return

	if kind == "mech_wisp":
		e["phase_clock"] = float(e.get("phase_clock", 0.0)) + e_dt
		var cyc_w: float = fposmod(float(e["phase_clock"]), 4.6)
		var phasing: bool = cyc_w >= 2.2 and cyc_w < 4.2
		e["is_phasing"] = phasing
		e["facing"] = -1 if float(p["x"]) < float(e["x"]) else 1
		if phasing and is_in_active_layer(e, eng.active_layer) and Vector2(float(p["x"]) - float(e["x"]), float(p["y"]) - float(e["y"])).length() < 380.0:
			var dv: Vector2 = Vector2((float(p["x"]) + 14.0) - (float(e["x"]) + float(e["w"]) * 0.5), (float(p["y"]) + 18.0) - (float(e["y"]) + float(e["h"]) * 0.5)).normalized()
			e["x"] = clampf(float(e["x"]) + dv.x * 108.0 * e_dt, float(e["min_px"]) - 70.0, float(e["max_px"]) + 70.0)
			e["y"] = clampf(float(e["y"]) + dv.y * 92.0 * e_dt, float(e["base_y"]) - 120.0, float(e["base_y"]) + 120.0)
		else:
			e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
			if float(e["x"]) <= float(e["min_px"]):
				e["x"] = float(e["min_px"])
				e["vx"] = absf(float(e["vx"]))
			elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
				e["x"] = float(e["max_px"]) - float(e["w"])
				e["vx"] = -absf(float(e["vx"]))
			var ty_w: float = float(e["base_y"]) + sin(eng.time_elapsed * 3.1 + float(e["spawn_x"]) * 0.025) * 28.0
			e["y"] = lerpf(float(e["y"]), ty_w, minf(1.0, e_dt * 5.0))
		if is_in_active_layer(e, eng.active_layer) and absf(float(e["x"]) - float(p["x"])) < 420.0:
			e["atk_cd"] = float(e.get("atk_cd", 3.2)) - e_dt
			if float(e["atk_cd"]) <= 0.0:
				e["atk_cd"] = 3.4
				var dvw: Vector2 = (p_rect.get_center() - Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)).normalized()
				eng.enemy_shots.append({
					"x": float(e["x"]) + float(e["w"]) * 0.5 - 6.0, "y": float(e["y"]) + float(e["h"]) * 0.5 - 6.0,
					"w": 13.0, "h": 13.0, "vx": dvw.x * 175.0, "vy": dvw.y * 175.0,
					"pierce_walls": true, "kind": "phase_orb", "layer": int(e.get("layer", -1)), "life": 3.1
				})
				eng.emit_sfx("phase_shift")
	elif kind == "drone" or kind == "mech_wasp":
		var near_p: bool = is_in_active_layer(e, eng.active_layer) and absf(float(e["x"]) - float(p["x"])) < 460.0
		e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
		if float(e["x"]) <= float(e["min_px"]):
			e["x"] = float(e["min_px"])
			e["vx"] = absf(float(e["vx"]))
		elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
			e["x"] = float(e["max_px"]) - float(e["w"])
			e["vx"] = -absf(float(e["vx"]))
		e["y"] = float(e["base_y"]) + sin(eng.time_elapsed * 3.4 + float(e["spawn_x"]) * 0.025) * 24.0
		e["facing"] = -1 if float(p["x"]) < float(e["x"]) else 1
		if near_p:
			e["atk_cd"] = float(e.get("atk_cd", 2.5)) - e_dt
			if float(e["atk_cd"]) <= 0.0:
				e["atk_cd"] = 2.65 if kind == "mech_wasp" else 3.2
				var dvd: Vector2 = (p_rect.get_center() - Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.55)).normalized()
				var spd_d: float = 245.0 if kind == "mech_wasp" else 210.0
				eng.enemy_shots.append({
					"x": float(e["x"]) + float(e["w"]) * 0.5 - 6.0, "y": float(e["y"]) + float(e["h"]) * 0.55,
					"w": 14.0, "h": 9.0, "vx": dvd.x * spd_d, "vy": clampf(dvd.y * spd_d, -150.0, 160.0),
					"kind": "aimed", "layer": int(e.get("layer", -1)), "life": 2.8
				})
				eng.emit_sfx("shoot")
	elif kind in ["mech_hopper", "mech_spider", "mech_crab"]:
		var gy_h: float = float(e.get("ground_y", e["y"]))
		e["leap_cd"] = float(e.get("leap_cd", 1.2)) - e_dt
		var dist_h: float = absf(p_rect.get_center().x - (float(e["x"]) + float(e["w"]) * 0.5))
		var in_sight: bool = is_in_active_layer(e, eng.active_layer) and dist_h < 310.0 and absf(float(p["y"]) - gy_h) < 150.0
		if float(e["y"]) >= gy_h - 0.5 and float(e["leap_cd"]) <= 0.0 and (in_sight or kind == "mech_hopper"):
			var jd: float = (-1.0 if float(p["x"]) < float(e["x"]) else 1.0) if in_sight else (1.0 if float(e["vx"]) >= 0.0 else -1.0)
			e["vy"] = -465.0 if kind == "mech_hopper" else (-415.0 if kind == "mech_crab" else -395.0)
			e["vx"] = jd * (185.0 if kind == "mech_spider" else (155.0 if kind == "mech_hopper" else 125.0))
			e["facing"] = int(jd)
			e["leap_cd"] = 1.35 if kind == "mech_hopper" else (1.85 if kind == "mech_spider" else 2.55)
			e["y"] = gy_h - 2.0
		if float(e["y"]) < gy_h or float(e.get("vy", 0.0)) < 0.0:
			e["vy"] = float(e.get("vy", 0.0)) + 1120.0 * e_dt
			e["y"] = float(e["y"]) + float(e["vy"]) * e_dt
			e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
			if float(e["y"]) >= gy_h:
				e["y"] = gy_h
				e["vy"] = 0.0
				if kind == "mech_crab" and is_in_active_layer(e, eng.active_layer) and dist_h < 440.0:
					for sd in [-1.0, 1.0]:
						eng.enemy_shots.append({
							"x": float(e["x"]) + float(e["w"]) * 0.5 - 7.0, "y": float(e["y"]) + float(e["h"]) - 14.0,
							"w": 14.0, "h": 10.0, "vx": sd * 195.0, "vy": 0.0,
							"kind": "bolt", "layer": int(e.get("layer", -1)), "life": 1.5
						})
		else:
			e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
			e["facing"] = 1 if float(e["vx"]) >= 0.0 else -1
		if float(e["x"]) <= float(e["min_px"]):
			e["x"] = float(e["min_px"])
			e["vx"] = absf(float(e["vx"]))
		elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
			e["x"] = float(e["max_px"]) - float(e["w"])
			e["vx"] = -absf(float(e["vx"]))
	else:
		var dist_x: float = p_rect.get_center().x - (float(e["x"]) + float(e["w"]) * 0.5)
		var abs_dx: float = absf(dist_x)
		var can_dash: bool = kind in ["mech_hound", "patrol", "mech_knight", "shield_mech"]
		if can_dash and is_in_active_layer(e, eng.active_layer):
			e["dash_cd"] = float(e.get("dash_cd", 1.2)) - e_dt
			var ds: String = str(e.get("dash_state", ""))
			if ds == "" and float(e["dash_cd"]) <= 0.0 and abs_dx < 265.0 and absf((float(p["y"]) + float(p["h"])) - (float(e["y"]) + float(e["h"]))) < 86.0:
				e["dash_state"] = "windup"
				e["dash_timer"] = 0.34
				e["dash_dir"] = 1.0 if dist_x >= 0.0 else -1.0
				e["facing"] = int(e["dash_dir"])
			elif ds == "windup":
				e["dash_timer"] = float(e["dash_timer"]) - e_dt
				if float(e["dash_timer"]) <= 0.0:
					e["dash_state"] = "dash"
					e["dash_timer"] = 0.48
			elif ds == "dash":
				e["dash_timer"] = float(e["dash_timer"]) - e_dt
				var bspd: float = 335.0 if kind == "mech_hound" else (295.0 if kind == "mech_knight" else 265.0)
				e["x"] = clampf(float(e["x"]) + float(e["dash_dir"]) * bspd * e_dt, float(e["min_px"]), float(e["max_px"]) - float(e["w"]))
				if float(e["dash_timer"]) <= 0.0 or float(e["x"]) <= float(e["min_px"]) or float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
					e["dash_state"] = "cool"
					e["dash_timer"] = 0.65
			elif ds == "cool":
				e["dash_timer"] = float(e["dash_timer"]) - e_dt
				if float(e["dash_timer"]) <= 0.0:
					e["dash_state"] = ""
					e["dash_cd"] = 1.85
		if str(e.get("dash_state", "")) == "":
			if absf(float(e.get("vx", 0.0))) > 0.01:
				e["x"] = float(e["x"]) + float(e["vx"]) * e_dt
				if float(e["x"]) <= float(e["min_px"]):
					e["x"] = float(e["min_px"])
					e["vx"] = absf(float(e["vx"]))
				elif float(e["x"]) + float(e["w"]) >= float(e["max_px"]):
					e["x"] = float(e["max_px"]) - float(e["w"])
					e["vx"] = -absf(float(e["vx"]))
				if kind != "shield_mech" and kind != "mech_knight":
					e["facing"] = 1 if float(e["vx"]) >= 0.0 else -1
				else:
					e["facing"] = -1 if float(p["x"]) < float(e["x"]) else 1
			else:
				e["facing"] = -1 if float(p["x"]) < float(e["x"]) else 1

		if kind == "mech_shroom" and is_in_active_layer(e, eng.active_layer) and abs_dx < 380.0:
			e["atk_cd"] = float(e.get("atk_cd", 2.9)) - e_dt
			if float(e["atk_cd"]) <= 0.0:
				e["atk_cd"] = 3.2
				var d_ms: float = 1.0 if dist_x >= 0.0 else -1.0
				eng.enemy_shots.append({
					"x": float(e["x"]) + float(e["w"]) * 0.5 - 6.0, "y": float(e["y"]) + 4.0,
					"w": 12.0, "h": 12.0, "vx": d_ms * clampf(abs_dx * 0.72, 95.0, 210.0),
					"vy": -295.0, "grav": 560.0, "kind": "lob", "layer": int(e.get("layer", -1)), "life": 2.4
				})
		elif kind in ["mech_tank", "mech_golem", "mech_exec"] and is_in_active_layer(e, eng.active_layer) and abs_dx < 520.0:
			e["atk_cd"] = float(e.get("atk_cd", 2.7)) - e_dt
			if float(e["atk_cd"]) <= 0.0:
				e["atk_cd"] = 2.9 if kind == "mech_tank" else 3.2
				var d_lg: float = -1.0 if float(p["x"]) < float(e["x"]) else 1.0
				e["facing"] = int(d_lg)
				if kind == "mech_exec":
					for vyo in [-45.0, 20.0]:
						eng.enemy_shots.append({
							"x": (float(e["x"]) + float(e["w"]) - 4.0) if d_lg > 0.0 else (float(e["x"]) - 14.0),
							"y": float(e["y"]) + float(e["h"]) * 0.42, "w": 18.0, "h": 12.0,
							"vx": d_lg * 235.0, "vy": vyo, "kind": "wave", "layer": int(e.get("layer", -1)), "life": 2.9
						})
				else:
					eng.enemy_shots.append({
						"x": (float(e["x"]) + float(e["w"]) - 4.0) if d_lg > 0.0 else (float(e["x"]) - 14.0),
						"y": float(e["y"]) + float(e["h"]) * 0.45, "w": 18.0, "h": 10.0,
						"vx": d_lg * 255.0, "vy": 0.0, "kind": "bolt", "layer": int(e.get("layer", -1)), "life": 3.0
					})
				eng.emit_sfx("shoot")

	if is_in_active_layer(e, eng.active_layer):
		var hit_r: Rect2 = Rect2(float(e["x"]) + 7.0, float(e["y"]) + 7.0, maxf(12.0, float(e["w"]) - 14.0), maxf(12.0, float(e["h"]) - 12.0))
		if GridMath.aabb_overlap(p_rect, hit_r):
			eng.kill_player(false, "enemy")

static func _update_s2_boss_ai(eng: RefCounted, boss: Dictionary, p: Dictionary, p_rect: Rect2, dt: float, e_dt: float) -> void:
	if float(boss.get("vuln_timer", 0.0)) > 0.0:
		boss["vuln_timer"] = maxf(0.0, float(boss["vuln_timer"]) - dt)
	if float(boss.get("armor_flash", 0.0)) > 0.0:
		boss["armor_flash"] = maxf(0.0, float(boss["armor_flash"]) - dt)
	if float(boss.get("stun_timer", 0.0)) > 0.0:
		boss["stun_timer"] = maxf(0.0, float(boss["stun_timer"]) - dt)
		return

	var bk: String = str(boss.get("bossKind", ""))
	if bk == "chrono_skull":
		var max_lead: float = 8.2 * GridMath.TILE
		if float(boss["x"]) < float(p["x"]) - max_lead:
			boss["x"] = float(p["x"]) - max_lead
		var hold: bool = false
		var wgs: Array = boss.get("waitGates", [])
		for gx_v in wgs:
			var gx_f: float = float(gx_v)
			if float(p["x"]) < GridMath.gx_to_px(gx_f) and float(boss["x"]) >= GridMath.gx_to_px(gx_f - 5.5):
				hold = true
				break
		if not hold:
			boss["x"] = float(boss["x"]) + float(boss.get("speed", 3.25)) * GridMath.TILE * e_dt
		boss["y"] = float(boss["base_y"]) + sin(eng.time_elapsed * 3.5) * 14.0
		if GridMath.aabb_overlap(p_rect, Rect2(float(boss["x"]) + 14.0, float(boss["y"]) + 14.0, float(boss["w"]) - 28.0, float(boss["h"]) - 28.0)):
			eng.kill_player(false, "boss_s2")
		return

	boss["atk_timer"] = float(boss.get("atk_timer", 1.6)) - e_dt
	if bk == "fracture_core":
		boss["active_core_layer"] = int(floor(eng.time_elapsed / 3.4)) % 2
	if bk == "mecha_sovereign" and int(boss.get("phase", 1)) == 2:
		boss["x"] = float(boss["base_x"]) + sin(eng.time_elapsed * 1.35) * (3.2 * GridMath.TILE)
	else:
		boss["y"] = float(boss["base_y"]) + sin(eng.time_elapsed * 2.6) * 8.0

	if float(boss["atk_timer"]) <= 0.0:
		boss["atk_timer"] = float(boss.get("atkInterval", 2.9))
		boss["vuln_timer"] = 2.2
		boss["mode_idx"] = (int(boss.get("mode_idx", 0)) + 1) % 4
		if absf(float(boss["x"]) - float(p["x"])) < 760.0:
			var dir_b: float = -1.0 if float(p["x"]) < float(boss["x"]) else 1.0
			var aim_low: bool = (int(boss["mode_idx"]) % 2) == 0
			eng.enemy_shots.append({
				"x": float(boss["x"]) + float(boss["w"]) * 0.5,
				"y": (GridMath.WORLD_ORIGIN_Y - 2.35 * GridMath.TILE) if aim_low else (GridMath.WORLD_ORIGIN_Y - 4.2 * GridMath.TILE),
				"w": 20.0, "h": 12.0, "vx": dir_b * 235.0, "vy": 0.0,
				"layer": int(boss["active_core_layer"]) if bk == "fracture_core" else -1,
				"life": 3.6
			})
			if bk == "reassembly_mech" and int(boss.get("phase", 1)) == 3 and not bool(boss.get("armor_cracked", false)) and int(p.get("bombs", 0)) <= 0:
				var any_b: bool = false
				for x_var in eng.entities:
					var x_d: Dictionary = x_var
					if str(x_d.get("t", "")) == "bomb_pickup":
						any_b = true
						break
				if not any_b:
					eng.entities.append({
						"key": "b67_bomb_" + str(Time.get_ticks_msec()),
						"t": "bomb_pickup",
						"x": float(boss["x"]) - 5.5 * GridMath.TILE,
						"y": GridMath.WORLD_ORIGIN_Y - 2.88 * GridMath.TILE,
						"w": 0.82 * GridMath.TILE, "h": 0.88 * GridMath.TILE,
						"layer": -1
					})

	if is_in_active_layer(boss, eng.active_layer):
		if bk == "fracture_core" and int(boss.get("phase", 1)) == 1 and eng.active_layer != int(boss.get("active_core_layer", 0)):
			return
		if GridMath.aabb_overlap(p_rect, Rect2(float(boss["x"]) + 16.0, float(boss["y"]) + 16.0, float(boss["w"]) - 32.0, float(boss["h"]) - 28.0)):
			eng.kill_player(false, "boss_s2")
