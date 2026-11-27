class_name WorldState
extends RefCounted

const PERM_NONE: String = "NONE"
const PERM_READ: String = "READ"
const PERM_WRITE: String = "WRITE"
const PERM_ADMIN: String = "ADMIN"

const PHASE_DAY: String = "day"
const PHASE_DUSK: String = "dusk"
const PHASE_NIGHT: String = "night"

var gravity_vec: Vector2 = Vector2(0.0, 1.0)
var last_surface_material: String = "stone"
var gravity_locked_anchor: bool = false

var global_frozen: bool = false
var global_slow: bool = false
var timer_rate: float = 1.0
var enemy_time_scale: float = 1.0
var mech_time_scale: float = 1.0
var proj_time_scale: float = 1.0
var rewind_active: bool = false
var time_loan_debt: float = 0.0
var clock_scopes: Dictionary = {}

var active_layer: int = 0
var last_layer_preview: Dictionary = {}

var wind_inertia_vx: float = 0.0
var wind_inertia_vy: float = 0.0
var active_wind_vec: Vector2 = Vector2.ZERO

var water_pressure_total: float = 100.0
var water_level_offset_px: float = 0.0
var water_flow_dir: int = 1
var pipe_pressures: Dictionary = {}

var sundial_phase_idx: int = 0
var sundial_phase_name: String = "day"
var sun_heat: float = 0.0
var shadow_length_px: float = 64.0
var shadow_dir: float = -1.0
var shadow_rect: Rect2 = Rect2(0.0, 0.0, 36.0, 12.0)
var spotlights_on: Dictionary = {}

var root_permission: String = "NONE"
var installed_patches: Dictionary = {}
var safe_mode_active: bool = false
var reward_debt: int = 0

func reset_for_attempt(props: Dictionary = {}, cp: Dictionary = {}) -> void:
	var init_g: float = float(props.get("gravity", 1.0))
	if absf(init_g) < 0.05:
		init_g = 1.0
	gravity_vec = Vector2(0.0, signf(init_g))
	last_surface_material = "stone"
	gravity_locked_anchor = false

	global_frozen = false
	global_slow = false
	timer_rate = 1.0
	enemy_time_scale = 1.0
	mech_time_scale = 1.0
	proj_time_scale = 1.0
	rewind_active = false
	time_loan_debt = 0.0
	clock_scopes.clear()

	active_layer = int(props.get("startLayer", 0))
	last_layer_preview = {}

	wind_inertia_vx = 0.0
	wind_inertia_vy = 0.0
	active_wind_vec = Vector2.ZERO

	water_pressure_total = float(props.get("waterPressure", 100.0))
	water_level_offset_px = 0.0
	water_flow_dir = int(props.get("waterFlowDir", 1))
	pipe_pressures.clear()

	var init_phase: String = str(props.get("sundialPhase", "day"))
	set_sundial_phase(init_phase)
	sun_heat = 0.0
	shadow_length_px = 64.0
	shadow_dir = -1.0
	spotlights_on.clear()

	root_permission = str(props.get("startPermission", "NONE"))
	installed_patches.clear()
	safe_mode_active = false
	reward_debt = 0

	if not cp.is_empty():
		restore_checkpoint_snapshot(cp.get("world_state", {}))

func get_grav_dir_scalar() -> float:
	if gravity_vec.y < -0.1:
		return -1.0
	return 1.0

func set_gravity_vector(vec: Vector2) -> void:
	if gravity_locked_anchor:
		return
	if vec.length_squared() < 0.01:
		gravity_vec = Vector2(0.0, 1.0)
	else:
		gravity_vec = vec.normalized()

func record_surface_material(skin_or_type: String) -> void:
	if skin_or_type == "":
		return
	var low: String = skin_or_type.to_lower()
	if "wood" in low or "crate" in low or "tanuki_log" in low:
		last_surface_material = "wood"
	elif "metal" in low or "steel" in low or "copper" in low or "cyber" in low:
		last_surface_material = "metal"
	elif "water" in low or "turf" in low or "ice" in low:
		last_surface_material = "water"
	elif "glass" in low:
		last_surface_material = "glass"
	else:
		last_surface_material = "stone"

func apply_gravity_pad(pad: Dictionary, override_mat: String = "") -> Vector2:
	if gravity_locked_anchor:
		return gravity_vec
	var mat: String = override_mat if override_mat != "" else last_surface_material
	var pad_mode: String = str(pad.get("gravMode", ""))
	if pad_mode == "rotate_90" or (pad_mode == "material_memory" and mat == "metal"):
		var rotated: Vector2 = Vector2(-gravity_vec.y, gravity_vec.x)
		if absf(rotated.y) < 0.1 and absf(rotated.x) > 0.5:
			gravity_vec = rotated.normalized()
		else:
			gravity_vec = Vector2(0.0, -get_grav_dir_scalar())
		return gravity_vec
	if pad.has("gravVecX") or pad.has("gravVecY"):
		var gx: float = float(pad.get("gravVecX", 0.0))
		var gy: float = float(pad.get("gravVecY", -1.0))
		set_gravity_vector(Vector2(gx, gy))
		return gravity_vec
	var gdir: float = float(pad.get("dir", -1.0))
	gravity_vec = Vector2(0.0, -1.0 if gdir < 0.0 else 1.0)
	return gravity_vec

func apply_clock_scope(scope: String, active: bool, factor: float = 1.0, group_id: String = "") -> void:
	var key: String = group_id if group_id != "" else scope
	clock_scopes[key] = { "scope": scope, "active": active, "factor": factor }
	if scope == "enemy_speed":
		enemy_time_scale = factor if active else 1.0
	elif scope == "mech_freeze":
		mech_time_scale = 0.0 if active else 1.0
	elif scope == "timer_only":
		timer_rate = 0.0 if active else factor
	elif scope == "rewind_plat":
		rewind_active = active
		mech_time_scale = -1.0 if active else 1.0
	elif scope == "time_loan":
		if active:
			timer_rate = maxf(1.0, factor)
			enemy_time_scale = maxf(1.0, factor * 0.65)
			time_loan_debt += 4.5
		else:
			timer_rate = 0.45
			enemy_time_scale = 0.55
	elif scope == "proj_freeze":
		proj_time_scale = 0.0 if active else 1.0

func get_domain_dt(raw_dt: float, domain: String, pos: Vector2 = Vector2.ZERO, time_bubbles: Array = []) -> float:
	if global_frozen and domain != "player" and domain != "projectile_unfrozen":
		return 0.0
	var base: float = raw_dt * (0.38 if global_slow else 1.0)
	if domain == "enemy":
		base *= enemy_time_scale
	elif domain == "mech":
		base *= absf(mech_time_scale)
	elif domain == "projectile":
		base *= proj_time_scale
	elif domain == "timer":
		return raw_dt * timer_rate * (0.4 if global_slow else 1.0)

	if pos != Vector2.ZERO and not time_bubbles.is_empty():
		var bubble_mul: float = 1.0
		for tb_var in time_bubbles:
			var tb: Dictionary = tb_var
			if str(tb.get("t", "")) != "time_bubble":
				continue
			var cx: float = float(tb.get("x", 0.0)) + float(tb.get("w", 0.0)) * 0.5
			var cy: float = float(tb.get("y", 0.0)) + float(tb.get("h", 0.0)) * 0.5
			var r_px: float = float(tb.get("radius_px", 120.0))
			if pos.distance_to(Vector2(cx, cy)) <= r_px:
				var sf: float = float(tb.get("slow_factor", 0.28))
				if sf < bubble_mul:
					bubble_mul = sf
		base *= bubble_mul
	return base

func preview_layer_shift(
	player_rect: Rect2,
	target_solids: Array,
	target_layer: int,
	invert_grav: bool = false,
	free_shift: bool = false
) -> Dictionary:
	var shrink_box: Rect2 = Rect2(
		player_rect.position.x + 3.0,
		player_rect.position.y + 3.0,
		maxf(4.0, player_rect.size.x - 6.0),
		maxf(4.0, player_rect.size.y - 6.0)
	)
	var overlaps: Array = []
	for ts_var in target_solids:
		var ts: Dictionary = ts_var
		var sr: Rect2 = Rect2(float(ts.get("x", 0.0)), float(ts.get("y", 0.0)), float(ts.get("w", 0.0)), float(ts.get("h", 0.0)))
		if GridMath.aabb_overlap(shrink_box, sr):
			overlaps.append(ts)

	var nudge_y: float = player_rect.position.y
	if overlaps.size() > 0:
		var hs0: Dictionary = overlaps[0]
		var only_lip: bool = (
			overlaps.size() == 1
			and (player_rect.position.y + player_rect.size.y - float(hs0["y"])) <= 14.0
			and (player_rect.position.y > float(hs0["y"]) - player_rect.size.y - 2.0)
		)
		var lip_ok: bool = false
		if only_lip:
			var nudged_box: Rect2 = Rect2(
				player_rect.position.x + 3.0,
				float(hs0["y"]) - player_rect.size.y + 2.0,
				shrink_box.size.x,
				shrink_box.size.y
			)
			lip_ok = true
			for ts2_var in target_solids:
				var ts2: Dictionary = ts2_var
				if ts2 != hs0:
					var sr2: Rect2 = Rect2(float(ts2["x"]), float(ts2["y"]), float(ts2["w"]), float(ts2["h"]))
					if GridMath.aabb_overlap(nudged_box, sr2):
						lip_ok = false
						break
		if lip_ok:
			nudge_y = float(hs0["y"]) - player_rect.size.y
		else:
			var res_blk: Dictionary = {
				"safe": false,
				"blocked": true,
				"has_floor": false,
				"target_layer": target_layer,
				"nudge_y": player_rect.position.y,
				"preview_rect": player_rect,
				"reason": "blocked"
			}
			last_layer_preview = res_blk
			return res_blk

	var target_g: float = (-1.0 if target_layer == 1 else 1.0) if invert_grav else get_grav_dir_scalar()
	var probe_h: float = GridMath.TILE * 4.0
	var foot_probe: Rect2 = (
		Rect2(player_rect.position.x - 10.0, nudge_y + player_rect.size.y - 8.0, player_rect.size.x + 20.0, probe_h)
		if target_g > 0.0
		else Rect2(player_rect.position.x - 10.0, nudge_y - probe_h + 8.0, player_rect.size.x + 20.0, probe_h)
	)
	var has_floor: bool = free_shift
	if not has_floor:
		for ts3_var in target_solids:
			var ts3: Dictionary = ts3_var
			var sr3: Rect2 = Rect2(float(ts3["x"]), float(ts3["y"]), float(ts3["w"]), float(ts3["h"]))
			if GridMath.aabb_overlap(foot_probe, sr3):
				has_floor = true
				break

	var res_ok: Dictionary = {
		"safe": has_floor,
		"blocked": false,
		"has_floor": has_floor,
		"target_layer": target_layer,
		"nudge_y": nudge_y,
		"preview_rect": Rect2(player_rect.position.x, nudge_y, player_rect.size.x, player_rect.size.y),
		"reason": "ok" if has_floor else "no_floor"
	}
	last_layer_preview = res_ok
	return res_ok

func step_wind_inertia(dt: float, zone_vec: Vector2, mass_mul: float = 1.0, wings_folded: bool = false) -> Vector2:
	active_wind_vec = zone_vec
	var area_mul: float = 0.42 if wings_folded else 1.0
	var eff_mul: float = clampf(mass_mul * area_mul, 0.08, 2.0)
	if zone_vec.length_squared() > 0.01:
		var target_wx: float = clampf(zone_vec.x * eff_mul, -260.0, 260.0)
		var target_wy: float = clampf(zone_vec.y * eff_mul, -440.0, 440.0)
		wind_inertia_vx = move_toward(wind_inertia_vx, target_wx, 520.0 * dt)
		wind_inertia_vy = move_toward(wind_inertia_vy, target_wy, 640.0 * dt)
	else:
		wind_inertia_vx = move_toward(wind_inertia_vx, 0.0, 380.0 * dt)
		wind_inertia_vy = move_toward(wind_inertia_vy, 0.0, 480.0 * dt)
	return Vector2(wind_inertia_vx, wind_inertia_vy)

func recompute_water_pressure(valves: Dictionary, pipes: Array) -> void:
	pipe_pressures.clear()
	var open_groups: Array[String] = []
	for p_var in pipes:
		var p: Dictionary = p_var
		var grp: String = str(p.get("pipe_group", p.get("pipeGroup", "")))
		if grp == "":
			continue
		var shut: bool = bool(valves.get(grp, false))
		var blocked_by_stone: bool = bool(p.get("stone_plugged", false))
		if not shut and not blocked_by_stone and not (grp in open_groups):
			open_groups.append(grp)
	if open_groups.is_empty():
		return
	var share: float = water_pressure_total / float(open_groups.size())
	for g_name in open_groups:
		pipe_pressures[g_name] = share

func get_pipe_pressure(pipe_group: String) -> float:
	if pipe_group == "":
		return water_pressure_total
	return float(pipe_pressures.get(pipe_group, 0.0))

func set_sundial_phase(phase_name: String) -> void:
	var low: String = phase_name.to_lower()
	if low == "night" or low == "2":
		sundial_phase_idx = 2
		sundial_phase_name = PHASE_NIGHT
	elif low == "dusk" or low == "sunset" or low == "1":
		sundial_phase_idx = 1
		sundial_phase_name = PHASE_DUSK
	else:
		sundial_phase_idx = 0
		sundial_phase_name = PHASE_DAY

func advance_sundial_phase(step_count: int = 1) -> String:
	sundial_phase_idx = posmod(sundial_phase_idx + step_count, 3)
	if sundial_phase_idx == 0:
		sundial_phase_name = PHASE_DAY
	elif sundial_phase_idx == 1:
		sundial_phase_name = PHASE_DUSK
	else:
		sundial_phase_name = PHASE_NIGHT
	return sundial_phase_name

func compute_shadow_metrics(player_rect: Rect2, light_sources: Array, floor_y: float = GridMath.WORLD_ORIGIN_Y - 2.0 * GridMath.TILE) -> Dictionary:
	var active_light: Vector2 = Vector2.ZERO
	var has_custom_light: bool = false
	var best_dist: float = 999999.0
	var p_center: Vector2 = player_rect.get_center()

	for ls_var in light_sources:
		var ls: Dictionary = ls_var
		if bool(ls.get("broken", false)) or bool(ls.get("off", false)):
			continue
		var lx: float = float(ls.get("x", 0.0)) + float(ls.get("w", 32.0)) * 0.5
		var ly: float = float(ls.get("y", 0.0)) + float(ls.get("h", 32.0)) * 0.5
		var d: float = p_center.distance_to(Vector2(lx, ly))
		if d < best_dist:
			best_dist = d
			active_light = Vector2(lx, ly)
			has_custom_light = true

	if not has_custom_light:
		if sundial_phase_name == PHASE_DAY:
			active_light = Vector2(p_center.x + 24.0, p_center.y - 320.0)
		elif sundial_phase_name == PHASE_DUSK:
			active_light = Vector2(p_center.x - 260.0, p_center.y - 120.0)
		else:
			active_light = Vector2(p_center.x + 280.0, p_center.y - 95.0)

	shadow_rect = GridMath.project_shadow_on_floor(active_light, player_rect, floor_y, 340.0)
	var height_above_floor: float = maxf(0.0, floor_y - (player_rect.position.y + player_rect.size.y))
	var altitude_shrink: float = clampf(1.0 - height_above_floor / 380.0, 0.25, 1.35)
	var phase_mul: float = 1.45 if sundial_phase_name == PHASE_DUSK else (1.65 if sundial_phase_name == PHASE_NIGHT else 0.85)
	shadow_length_px = clampf(shadow_rect.size.x * altitude_shrink * phase_mul, 18.0, 280.0)
	shadow_dir = 1.0 if p_center.x >= active_light.x else -1.0
	var wing_drain_rate: float = clampf(1150.0 / maxf(22.0, shadow_length_px), 5.5, 38.0)

	return {
		"shadow_rect": shadow_rect,
		"shadow_length_px": shadow_length_px,
		"shadow_dir": shadow_dir,
		"wing_drain_rate": wing_drain_rate,
		"light_pos": active_light
	}

func step_sun_heat(dt: float, in_shade_or_cool: bool, attacked_this_step: bool) -> float:
	if attacked_this_step:
		sun_heat = minf(100.0, sun_heat + 16.0)
	if in_shade_or_cool:
		sun_heat = maxf(0.0, sun_heat - 34.0 * dt)
	elif sundial_phase_name == PHASE_DAY:
		sun_heat = minf(100.0, sun_heat + 4.5 * dt)
	else:
		sun_heat = maxf(0.0, sun_heat - 10.0 * dt)
	return sun_heat

func set_permission(perm: String) -> bool:
	var up: String = perm.to_upper()
	if up in [PERM_NONE, PERM_READ, PERM_WRITE, PERM_ADMIN]:
		root_permission = up
		return true
	return false

func has_permission(req_perm: String) -> bool:
	var order: Dictionary = { "NONE": 0, "READ": 1, "WRITE": 2, "ADMIN": 3 }
	return int(order.get(root_permission, 0)) >= int(order.get(req_perm.to_upper(), 1))

func install_patch(slot_id: String, patch_id: String) -> Dictionary:
	installed_patches[slot_id] = patch_id
	return {
		"slot": slot_id,
		"patch": patch_id,
		"all_patches": installed_patches.duplicate()
	}

func swap_patches(slot_a: String, slot_b: String) -> void:
	var pa: String = str(installed_patches.get(slot_a, ""))
	var pb: String = str(installed_patches.get(slot_b, ""))
	installed_patches[slot_a] = pb
	installed_patches[slot_b] = pa

func export_checkpoint_snapshot() -> Dictionary:
	return {
		"gravity_x": gravity_vec.x,
		"gravity_y": gravity_vec.y,
		"last_surface_material": last_surface_material,
		"gravity_locked_anchor": gravity_locked_anchor,
		"active_layer": active_layer,
		"water_pressure_total": water_pressure_total,
		"water_level_offset_px": water_level_offset_px,
		"water_flow_dir": water_flow_dir,
		"sundial_phase_idx": sundial_phase_idx,
		"sundial_phase_name": sundial_phase_name,
		"root_permission": root_permission,
		"installed_patches": installed_patches.duplicate(true),
		"safe_mode_active": safe_mode_active,
		"reward_debt": reward_debt
	}

func restore_checkpoint_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	gravity_vec = Vector2(float(snap.get("gravity_x", 0.0)), float(snap.get("gravity_y", 1.0)))
	if gravity_vec.length_squared() < 0.01:
		gravity_vec = Vector2(0.0, 1.0)
	last_surface_material = str(snap.get("last_surface_material", "stone"))
	gravity_locked_anchor = bool(snap.get("gravity_locked_anchor", false))
	active_layer = int(snap.get("active_layer", active_layer))
	water_pressure_total = float(snap.get("water_pressure_total", 100.0))
	water_level_offset_px = float(snap.get("water_level_offset_px", 0.0))
	water_flow_dir = int(snap.get("water_flow_dir", 1))
	set_sundial_phase(str(snap.get("sundial_phase_name", "day")))
	set_permission(str(snap.get("root_permission", "NONE")))
	if typeof(snap.get("installed_patches", null)) == TYPE_DICTIONARY:
		installed_patches = snap["installed_patches"].duplicate(true)
	safe_mode_active = bool(snap.get("safe_mode_active", false))
	reward_debt = int(snap.get("reward_debt", 0))
