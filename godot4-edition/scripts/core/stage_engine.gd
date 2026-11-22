class_name StageEngine
extends RefCounted

signal toast_emitted(msg: String)
signal player_died(cause: String)
signal stage_cleared(level_data: Dictionary)

var save: SaveManager
var shop: ShopSystem
var audio: ChiptunePlayer

var current_level: Dictionary = {}
var player: Dictionary = {}
var solids: Array = []
var entities: Array = []
var bullets: Array = []
var enemy_shots: Array = []

var cam_x: float = 0.0
var attempt_deaths: int = 0
var active_layer: int = 0
var signal_groups: Dictionary = {}
var polarity_groups: Dictionary = {}
var s3_valves: Dictionary = {}
var state_bag: Dictionary = { "sundial_phase": false, "boss_defeated": false }
var checkpoint: Dictionary = {}

func _init(p_save: SaveManager, p_shop: ShopSystem, p_audio: ChiptunePlayer) -> void:
	save = p_save
	shop = p_shop
	audio = p_audio

## Starts a brand-new stage session and resets per-stage 1-use Shop quotas.
func start_stage(level_data: Dictionary) -> bool:
	var lid = int(level_data.get("id", 1))
	if not save.is_stage_unlocked(lid):
		return false
	current_level = level_data
	save.last_lv = lid
	save.persist()
	attempt_deaths = 0
	checkpoint.clear()
	shop.reset_for_new_stage()
	reset_attempt()
	audio.select_track(false, lid)
	return true

## Respawns inside the same stage WITHOUT resetting Shop per-stage usage (`1/1` items stay spent).
func reset_attempt() -> void:
	if current_level.is_empty():
		return
	var props: Dictionary = current_level.get("props", {})
	var has_cp = not checkpoint.is_empty()

	active_layer = int(checkpoint.get("active_layer", 0)) if has_cp else 0
	signal_groups = checkpoint.get("signal_groups", {}).duplicate() if has_cp else {}
	polarity_groups = checkpoint.get("polarity_groups", {}).duplicate() if has_cp else {}
	s3_valves = checkpoint.get("s3_valves", {}).duplicate() if has_cp else {}
	state_bag["sundial_phase"] = bool(checkpoint.get("sundial_phase", false)) if has_cp else false
	state_bag["boss_defeated"] = false
	bullets.clear()
	enemy_shots.clear()
	solids.clear()
	entities.clear()

	var spawn_dict: Dictionary = current_level.get("spawn", { "x": 1.0, "y": 2.0 })
	var gx: float = float(checkpoint["x"]) if has_cp else float(spawn_dict.get("x", 1.0))
	var gy: float = float(checkpoint["y"]) if has_cp else float(spawn_dict.get("y", 2.0))
	var base_jumps = maxi(int(props.get("startJumps", 1)), int(checkpoint.get("max_jumps", 1)) if has_cp else 1)

	player = {
		"x": GridMath.gx_to_px(gx) + 10.0,
		"y": GridMath.gy_to_py(gy, 0.0) - 42.0,
		"w": 28.0,
		"h": 42.0,
		"vx": 0.0,
		"vy": 0.0,
		"facing": 1,
		"grav_dir": 1,
		"on_ground": false,
		"coyote": 0.0,
		"jumps_left": base_jumps,
		"max_jumps": base_jumps,
		"has_flight": has_cp and bool(checkpoint.get("has_flight", false)),
		"from_shop_flight": false,
		"has_wall_phase": false,
		"shield": bool(props.get("startShield", false)),
		"bullet_up": bool(props.get("bulletUp", false)) or (has_cp and bool(checkpoint.get("bullet_up", false))),
		"from_shop_bullet": false,
		"sword_up": false,
		"bombs": 0,
		"gold_charges": 0,
		"golden_timer": 0.0,
		"invuln_timer": 0.0,
		"melee_cd": 0.0,
		"dead": false
	}

	shop.apply_stage_buffs(player)

	var objs: Array = current_level.get("objs", [])
	for idx in range(objs.size()):
		_spawn_object(objs[idx], idx)

## Enforces Rule 2: Pit / Abyss falls (`cause == "abyss"`) ALWAYS clear Golden Body and kill immediately!
func kill_player(ignore_shield: bool, cause: String) -> void:
	if player.is_empty() or bool(player.get("dead", false)):
		return

	var is_pit_or_reset = (cause == "abyss" or cause == "tactical_reset")
	if not is_pit_or_reset and (float(player.get("invuln_timer", 0.0)) > 0.0 or float(player.get("golden_timer", 0.0)) > 0.0):
		return

	if is_pit_or_reset:
		player["golden_timer"] = 0.0
		player["invuln_timer"] = 0.0

	if not is_pit_or_reset and not ignore_shield and int(player.get("gold_charges", 0)) > 0 and float(player.get("golden_timer", 0.0)) <= 0.0:
		if shop.trigger_golden_body(player):
			audio.play_sfx(880.0, 0.22)
			toast_emitted.emit("✨ 不灭金身自动护体（10秒无敌，注意落坑必死）！")
			return

	if not is_pit_or_reset and not ignore_shield and bool(player.get("shield", false)):
		player["shield"] = false
		player["invuln_timer"] = 1.25
		player["vy"] = -250.0 * int(player["grav_dir"])
		audio.play_sfx(760.0, 0.16)
		toast_emitted.emit("能量护盾完美弹反致命伤！")
		return

	player["dead"] = true
	attempt_deaths += 1
	audio.play_sfx(145.0, 0.28)
	player_died.emit(cause)

func step_frame(raw_dt: float, input_state: Dictionary) -> void:
	if current_level.is_empty() or player.is_empty() or bool(player.get("dead", false)):
		return
	var clamped = clampf(raw_dt, 0.001, 0.05)
	var steps = maxi(1, ceili(clamped / 0.016))
	var sub_dt = clamped / float(steps)
	for _s in range(steps):
		_step_sub(sub_dt, input_state)
		if player.is_empty() or bool(player.get("dead", false)):
			break

func _step_sub(dt: float, inp: Dictionary) -> void:
	var lid = int(current_level.get("id", 1))
	var props: Dictionary = current_level.get("props", {})

	if float(player["golden_timer"]) > 0.0:
		player["golden_timer"] = maxf(0.0, float(player["golden_timer"]) - dt)
		player["invuln_timer"] = maxf(float(player["invuln_timer"]), float(player["golden_timer"]))
	elif float(player["invuln_timer"]) > 0.0:
		player["invuln_timer"] = maxf(0.0, float(player["invuln_timer"]) - dt)

	if bool(inp.get("gold_pressed", false)):
		inp["gold_pressed"] = false
		if shop.trigger_golden_body(player):
			audio.play_sfx(1046.0, 0.20)
			toast_emitted.emit("✨ 不灭金身已开启（10秒，落入深坑依然会死）！")

	if bool(inp.get("layer_pressed", false)):
		inp["layer_pressed"] = false
		if bool(props.get("dualLayer", false)) and bool(props.get("allowFreeLayerShift", false)):
			active_layer = 1 if active_layer == 0 else 0

	var move_dir = (1 if bool(inp.get("right", false)) else 0) - (1 if bool(inp.get("left", false)) else 0)
	if bool(props.get("mirrorInput", false)):
		move_dir = -move_dir
	if move_dir != 0:
		player["facing"] = move_dir

	var accel = 3500.0 if bool(player["on_ground"]) else 2600.0
	player["vx"] = move_toward(float(player["vx"]), float(move_dir) * 242.0, accel * dt)

	if bool(player["on_ground"]):
		player["coyote"] = 0.12
		player["jumps_left"] = int(player["max_jumps"])
	else:
		player["coyote"] = maxf(0.0, float(player["coyote"]) - dt)

	if bool(inp.get("jump_just_pressed", false)):
		inp["jump_just_pressed"] = false
		if bool(player["has_flight"]):
			player["vy"] = -410.0 * int(player["grav_dir"])
			audio.play_sfx(660.0, 0.09)
		elif float(player["coyote"]) > 0.0 or int(player["jumps_left"]) > 0:
			if float(player["coyote"]) <= 0.0:
				player["jumps_left"] = int(player["jumps_left"]) - 1
			else:
				player["jumps_left"] = maxi(0, int(player["max_jumps"]) - 1)
			player["coyote"] = 0.0
			player["on_ground"] = false
			player["vy"] = -592.0 * int(player["grav_dir"])
			audio.play_sfx(520.0, 0.09)

	if float(player["melee_cd"]) > 0.0:
		player["melee_cd"] = maxf(0.0, float(player["melee_cd"]) - dt)

	if bool(inp.get("slash_pressed", false)):
		inp["slash_pressed"] = false
		_perform_slash(lid)
	if bool(inp.get("shoot_pressed", false)):
		inp["shoot_pressed"] = false
		_fire_bullet()
	if bool(inp.get("bomb_pressed", false)):
		inp["bomb_pressed"] = false
		_throw_bomb()

	player["vy"] = clampf(float(player["vy"]) + 1320.0 * float(player["grav_dir"]) * dt, -765.0, 765.0)

	var c2 = Sector1And2Mechanics.step_mechanics(dt, player, solids, entities, bullets, active_layer, polarity_groups)
	if c2 != "":
		kill_player(false, c2)
		return

	if lid >= 101:
		var c3_pre = Sector3Arcadia.step_pre_move(dt, player, solids, s3_valves, bool(state_bag["sundial_phase"]))
		if c3_pre != "":
			kill_player(false, c3_pre)
			return

	var active_solids: Array = []
	for s in solids:
		if Sector1And2Mechanics.is_solid_collidable(s, active_layer, signal_groups):
			if lid < 101 or Sector3Arcadia.is_solid_collidable(s, bool(state_bag["sundial_phase"])):
				active_solids.append(s)

	var bounds: Dictionary = current_level.get("bounds", { "minX": -2.0, "maxX": 100.0 })
	var min_px = GridMath.gx_to_px(float(bounds.get("minX", -2.0)))
	var max_px = GridMath.gx_to_px(float(bounds.get("maxX", 100.0)))
	player["x"] = clampf(float(player["x"]) + float(player["vx"]) * dt, min_px, max_px - float(player["w"]))

	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])
	for s in active_solids:
		if (str(s["t"]) == "invis" or str(s["t"]) == "qblock") and not bool(s.get("revealed", true)):
			continue
		var sr = Rect2(s["x"], s["y"], s["w"], s["h"])
		if GridMath.aabb_overlap(p_rect, sr):
			if bool(player["has_wall_phase"]) and float(player["y"]) + float(player["h"]) > float(s["y"]) + 10.0 and float(s["w"]) <= GridMath.TILE * 3.4:
				continue
			if float(player["vx"]) > 0.0:
				player["x"] = float(s["x"]) - float(player["w"])
			elif float(player["vx"]) < 0.0:
				player["x"] = float(s["x"]) + float(s["w"])
			player["vx"] = 0.0
			p_rect.position.x = float(player["x"])

	var prev_y = float(player["y"])
	player["y"] = prev_y + float(player["vy"]) * dt
	player["on_ground"] = false
	p_rect.position.y = float(player["y"])

	for s in active_solids:
		var sr = Rect2(s["x"], s["y"], s["w"], s["h"])
		if not GridMath.aabb_overlap(p_rect, sr):
			continue
		if (str(s["t"]) == "invis" or str(s["t"]) == "qblock") and not bool(s.get("revealed", true)):
			if int(player["grav_dir"]) > 0 and float(player["vy"]) < 0.0 and prev_y >= sr.end.y - 14.0:
				s["revealed"] = true
				player["y"] = sr.end.y
				player["vy"] = 36.0
				_grant_loot(s)
			continue
		if int(player["grav_dir"]) > 0:
			if float(player["vy"]) >= 0.0 and prev_y + float(player["h"]) <= sr.position.y + 16.0:
				player["y"] = sr.position.y - float(player["h"])
				player["vy"] = 0.0
				player["on_ground"] = true
			elif float(player["vy"]) < 0.0 and prev_y >= sr.end.y - 16.0:
				player["y"] = sr.end.y
				player["vy"] = 30.0
				_grant_loot(s)
		else:
			if float(player["vy"]) <= 0.0 and prev_y >= sr.end.y - 16.0:
				player["y"] = sr.end.y
				player["vy"] = 0.0
				player["on_ground"] = true
			elif float(player["vy"]) > 0.0 and prev_y + float(player["h"]) <= sr.position.y + 16.0:
				player["y"] = sr.position.y - float(player["h"])
				player["vy"] = -30.0
		p_rect.position.y = float(player["y"])

	## Pit / Abyss check — ALWAYS kills immediately even during Golden Body!
	if float(player["y"]) > GridMath.WORLD_ORIGIN_Y + 95.0 or (int(player["grav_dir"]) < 0 and float(player["y"]) < GridMath.WORLD_ORIGIN_Y - 13.0 * GridMath.TILE):
		kill_player(true, "abyss")
		return

	_step_projectiles(dt, lid, active_solids)
	if bool(player["dead"]):
		return
	_step_common_entities(lid)
	if bool(player["dead"]):
		return

	if lid >= 101:
		var post_res = Sector3Arcadia.step_post_move(dt, player, solids, entities, enemy_shots, s3_valves)
		if post_res == "WIN":
			audio.play_sfx(1046.0, 0.25)
			stage_cleared.emit(current_level)
			return
		elif post_res != "":
			kill_player(false, post_res)
			return

	cam_x = clampf(float(player["x"]) - 360.0, min_px, maxf(min_px, max_px - GridMath.VIEWPORT_W))

func _grant_loot(s: Dictionary) -> void:
	if bool(s.get("used", false)):
		return
	s["used"] = true
	var ug = str(s.get("unlock_group", ""))
	if ug != "":
		signal_groups[ug] = true
	var lt = str(s.get("loot", ""))
	if lt == "coin":
		save.add_coins(5)
	elif lt == "shield":
		player["shield"] = true
	elif lt == "bullet_up":
		player["bullet_up"] = true
		player["from_shop_bullet"] = false
	elif lt == "flight":
		player["has_flight"] = true
		player["from_shop_flight"] = false
	elif lt == "double_jump":
		player["max_jumps"] = maxi(int(player["max_jumps"]), 2)
		player["jumps_left"] = int(player["max_jumps"])

func _perform_slash(lid: int) -> void:
	if float(player["melee_cd"]) > 0.0:
		return
	if lid < 51 and not save.magic_sword_unlocked:
		return
	for e in entities:
		if str(e.get("t", "")) == "peace_dove":
			e["angry"] = true
	player["melee_cd"] = 0.28
	audio.play_sfx(420.0, 0.08)
	var sw = 108.0 if bool(player["sword_up"]) else 70.0
	var sh = 72.0 if bool(player["sword_up"]) else 60.0
	var sx = (float(player["x"]) + 10.0) if int(player["facing"]) > 0 else (float(player["x"]) + 18.0 - sw)
	var box = Rect2(sx, float(player["y"]) - 12.0, sw, sh)
	if bool(player["sword_up"]):
		bullets.append({
			"x": float(player["x"]), "y": float(player["y"]) + 4.0, "w": 36.0, "h": 30.0,
			"vx": float(player["facing"]) * 590.0, "upgraded": true, "s3_wave": true, "reflected": false, "life": 0.52
		})
	if lid >= 101:
		Sector3Arcadia.handle_attack_hit(box, 6 if bool(player["sword_up"]) else 3, true, true, solids, entities, enemy_shots, s3_valves, state_bag, save)

func _fire_bullet() -> void:
	for e in entities:
		if str(e.get("t", "")) == "peace_dove":
			e["angry"] = true
	audio.play_sfx(760.0, 0.07)
	var up = bool(player["bullet_up"])
	bullets.append({
		"x": float(player["x"]) + (float(player["w"]) if int(player["facing"]) > 0 else -24.0),
		"y": float(player["y"]) + 10.0,
		"w": 28.0 if up else 24.0,
		"h": 18.0,
		"vx": float(player["facing"]) * (545.0 if up else 455.0),
		"upgraded": up,
		"s3_wave": false,
		"reflected": false,
		"life": 2.2
	})

func _throw_bomb() -> void:
	if int(player["bombs"]) <= 0:
		return
	player["bombs"] = int(player["bombs"]) - 1
	var c = Vector2(float(player["x"]) + float(player["facing"]) * 92.0, float(player["y"]))
	for s in solids:
		if str(s.get("t", "")) == "destructible" and not bool(s.get("broken", false)):
			if Rect2(s["x"], s["y"], s["w"], s["h"]).get_center().distance_to(c) <= 150.0:
				s["broken"] = true

func _step_projectiles(dt: float, lid: int, active_solids: Array) -> void:
	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["x"] = float(b["x"]) + float(b["vx"]) * dt
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			bullets.remove_at(i)
			continue
		var br = Rect2(b["x"], b["y"], b["w"], b["h"])
		var wave = bool(b.get("s3_wave", false))
		var up = bool(b.get("upgraded", false))
		if lid >= 101 and Sector3Arcadia.handle_attack_hit(br, 4 if wave else (2 if up else 1), wave, up or wave, solids, entities, enemy_shots, s3_valves, state_bag, save):
			if not wave:
				bullets.remove_at(i)
				continue
		for s in active_solids:
			var sr = Rect2(s["x"], s["y"], s["w"], s["h"])
			if not GridMath.aabb_overlap(br, sr):
				continue
			if str(s["t"]) == "mirror":
				b["vx"] = -float(b["vx"])
				b["reflected"] = true
			elif str(s["t"]) == "destructible" and (bool(s.get("bullet_break", false)) or up or (bool(s.get("mirror_break", false)) and bool(b.get("reflected", false)))):
				s["broken"] = true
				bullets.remove_at(i)
				break
			elif not wave:
				bullets.remove_at(i)
				break

	for i in range(enemy_shots.size() - 1, -1, -1):
		var sh: Dictionary = enemy_shots[i]
		sh["vy"] = float(sh.get("vy", 0.0)) + float(sh.get("grav", 0.0)) * dt
		sh["x"] = float(sh["x"]) + float(sh["vx"]) * dt
		sh["y"] = float(sh["y"]) + float(sh["vy"]) * dt
		sh["life"] = float(sh["life"]) - dt
		if float(sh["life"]) <= 0.0:
			enemy_shots.remove_at(i)
			continue
		if GridMath.aabb_overlap(p_rect, Rect2(sh["x"], sh["y"], sh["w"], sh["h"])):
			enemy_shots.remove_at(i)
			kill_player(false, "enemy")
			return

func _step_common_entities(lid: int) -> void:
	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])
	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		var er = Rect2(e["x"], e["y"], e["w"], e["h"])
		if not GridMath.aabb_overlap(p_rect, er):
			continue
		var et = str(e.get("t", ""))
		if et == "coin":
			save.add_coins(1)
			entities.remove_at(i)
		elif et == "spring":
			player["vy"] = -790.0 * int(player["grav_dir"])
		elif et == "gravity_pad":
			player["grav_dir"] = -1 if int(e.get("dir", -1)) < 0 else 1
		elif et == "spike":
			kill_player(false, "spike")
			return
		elif et == "checkpoint" and not bool(e.get("s3_fake", false)):
			checkpoint = {
				"x": float(e["gx"]),
				"y": float(e["gy"]),
				"max_jumps": int(player["max_jumps"]),
				"has_flight": bool(player["has_flight"]) and not bool(player["from_shop_flight"]),
				"bullet_up": bool(player["bullet_up"]) and not bool(player["from_shop_bullet"]),
				"active_layer": active_layer,
				"signal_groups": signal_groups.duplicate(),
				"polarity_groups": polarity_groups.duplicate(),
				"s3_valves": s3_valves.duplicate(),
				"sundial_phase": bool(state_bag["sundial_phase"])
			}
		elif et == "flag":
			if bool(e.get("fake", false)):
				kill_player(true, "fake_flag")
				return
			var props: Dictionary = current_level.get("props", {})
			if lid >= 101 and bool(props.get("s3BossLockGoal", false)) and not bool(state_bag["boss_defeated"]):
				var has_boss = false
				for x in entities:
					if str(x.get("t", "")) == "s3_boss":
						has_boss = true
				if has_boss:
					return
			audio.play_sfx(1046.0, 0.25)
			stage_cleared.emit(current_level)
			return

func _spawn_object(o: Dictionary, idx: int) -> void:
	var lid = int(current_level.get("id", 1))
	var key = "%d_%d" % [lid, idx]
	var t = str(o.get("t", "solid"))
	var w_tiles = float(o.get("w", 1.0))
	var h_tiles = float(o.get("h", 1.0))
	var sx = GridMath.gx_to_px(float(o.get("x", 0.0)))
	var sy = GridMath.gy_to_py(float(o.get("y", 0.0)), h_tiles)

	if t in ["solid", "invis", "qblock", "destructible", "mirror", "fake_wall", "fake_plat", "conveyor", "polarity_block", "signal_gate"]:
		solids.append({
			"key": key, "t": t, "x": sx, "y": sy, "base_x": sx, "base_y": sy,
			"w": w_tiles * GridMath.TILE, "h": h_tiles * GridMath.TILE,
			"skin": str(o.get("skin", "grass" if lid >= 101 else "steel")),
			"layer": int(o.get("layer", -1)),
			"revealed": (not bool(o.get("invis", false))) if t == "qblock" else (t != "invis"),
			"loot": str(o.get("loot", "")),
			"unlock_group": str(o.get("unlockGroup", "")),
			"bullet_break": bool(o.get("bulletBreak", false)),
			"mirror_break": bool(o.get("mirrorBreak", false)),
			"belt_vx": float(o.get("beltVx", 180.0)),
			"group": str(o.get("group", "")),
			"blue_x": GridMath.gx_to_px(float(o.get("blueX", o.get("x", 0.0)))),
			"blue_y": GridMath.gy_to_py(float(o.get("blueY", o.get("y", 0.0))), h_tiles),
			"orange_x": GridMath.gx_to_px(float(o.get("orangeX", o.get("x", 0.0)))),
			"orange_y": GridMath.gy_to_py(float(o.get("orangeY", o.get("y", 0.0))), h_tiles),
			"broken": false
		})
	elif lid >= 101 and t in ["s3_tall_pipe", "s3_cloud", "s3_drop_block", "s3_slide_turf"]:
		solids.append({
			"key": key, "t": t, "x": sx, "y": sy, "base_x": sx, "base_y": sy,
			"foot_y": GridMath.gy_to_py(float(o.get("y", 0.0)), 0.0),
			"w": w_tiles * GridMath.TILE, "h": h_tiles * GridMath.TILE,
			"orig_h_px": h_tiles * GridMath.TILE,
			"target_h_px": float(o.get("targetH", 1.4)) * GridMath.TILE,
			"pipe_group": str(o.get("pipeGroup", "")),
			"mode": str(o.get("mode", "")),
			"invert_sundial": bool(o.get("invertSundial", false)),
			"disarmed": str(o.get("mode", "")) == "safe_plat",
			"rise_trap": bool(o.get("riseTrap", false)),
			"crush_lethal": bool(o.get("crushLethal", true)),
			"slide_dx_px": float(o.get("slideDx", 2.4)) * GridMath.TILE,
			"slide_dy_px": float(o.get("slideDy", 0.0)) * GridMath.TILE,
			"trigger_dist_px": float(o.get("triggerDx", 2.0)) * GridMath.TILE,
			"broken": false
		})
	else:
		var eh = h_tiles if o.has("h") else 1.15
		var ew = w_tiles if o.has("w") else 1.05
		entities.append({
			"key": key, "t": t, "gx": float(o.get("x", 0.0)), "gy": float(o.get("y", 0.0)),
			"x": sx, "y": GridMath.gy_to_py(float(o.get("y", 0.0)), eh),
			"base_x": sx, "home_y": sy,
			"w": ew * GridMath.TILE, "h": eh * GridMath.TILE,
			"hp": int(o.get("hp", 2)),
			"mode": str(o.get("mode", "")),
			"fake": bool(o.get("fake", false)),
			"s3_fake": bool(o.get("s3Fake", false)),
			"pipe_group": str(o.get("pipeGroup", "")),
			"min_px": GridMath.gx_to_px(float(o.get("minGx", float(o.get("x", 0.0)) - 3.0))),
			"max_px": GridMath.gx_to_px(float(o.get("maxGx", float(o.get("x", 0.0)) + 3.0))),
			"trigger_px": GridMath.gx_to_px(float(o.get("triggerGx", 10.0))),
			"boss_kind": str(o.get("bossKind", "")),
			"dir": int(o.get("dir", -1)),
			"vx": float(o.get("vx", 0.0)),
			"vy": float(o.get("vy", 0.0)),
			"group": str(o.get("group", "")),
			"layer": int(o.get("layer", -1))
		})
