class_name Sector3Arcadia
extends RefCounted

static func is_cloud_safe(s: Dictionary, sundial_phase: bool) -> bool:
	if bool(s.get("disarmed", false)) or str(s.get("mode", "")) == "safe_plat":
		return true
	if str(s.get("mode", "")) == "sundial_knife":
		var inv = bool(s.get("invert_sundial", false))
		var armed = sundial_phase if inv else (not sundial_phase)
		return not armed
	return false

static func is_solid_collidable(s: Dictionary, sundial_phase: bool) -> bool:
	if bool(s.get("broken", false)):
		return false
	if str(s.get("t", "")) == "s3_cloud":
		if str(s.get("mode", "")) == "fake_cloud":
			return false
		return is_cloud_safe(s, sundial_phase)
	return true

static func step_pre_move(
	dt: float,
	player: Dictionary,
	solids: Array,
	valves: Dictionary,
	sundial_phase: bool
) -> String:
	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])

	for s in solids:
		if bool(s.get("broken", false)):
			continue
		var st = str(s.get("t", ""))
		if st == "s3_tall_pipe":
			var pgrp = str(s.get("pipe_group", ""))
			var low = bool(valves.get(pgrp, false))
			if str(s.get("mode", "")) == "sundial_alt":
				low = (not sundial_phase) if bool(s.get("invert_sundial", false)) else sundial_phase
			var goal_h = float(s["target_h_px"] if low else s["orig_h_px"])
			if absf(float(s["h"]) - goal_h) > 0.5:
				var prev_y = float(s["y"])
				var delta = signf(goal_h - float(s["h"])) * minf(absf(goal_h - float(s["h"])), 260.0 * dt)
				s["h"] = float(s["h"]) + delta
				s["y"] = float(s["foot_y"]) - float(s["h"])
				if bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - prev_y) <= 10.0:
					if float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
						player["y"] = float(s["y"]) - float(player["h"])
			if str(s.get("mode", "")) == "lethal_drop" and not low and float(player["vy"]) > 520.0:
				var lip = Rect2(float(s["x"]) + 4.0, float(s["y"]) + float(s["h"]) - 24.0, float(s["w"]) - 8.0, 28.0)
				if GridMath.aabb_overlap(p_rect, lip):
					return "tall_pipe"
		elif st == "s3_cloud" and not is_cloud_safe(s, sundial_phase):
			if str(s.get("mode", "")) == "swoop_cloud" and not bool(s.get("swoop_triggered", false)) and absf(float(player["x"]) - float(s["x"])) < 120.0:
				s["swoop_triggered"] = true
				s["swoop_vy"] = 290.0
			if bool(s.get("swoop_triggered", false)):
				s["y"] = float(s["y"]) + float(s.get("swoop_vy", 0.0)) * dt
			if GridMath.aabb_overlap(p_rect, Rect2(s["x"], s["y"], s["w"], s["h"])):
				return "cloud_knife"
		elif st == "s3_drop_block":
			var fs = int(s.get("fall_state", 0))
			if fs == 0 and absf((float(player["x"]) + float(player["w"]) * 0.5) - (float(s["x"]) + float(s["w"]) * 0.5)) < float(s["w"]) * 0.72:
				s["fall_state"] = 1
				s["vy"] = -460.0 if bool(s.get("rise_trap", false)) else 480.0
			elif fs == 1:
				s["y"] = float(s["y"]) + float(s.get("vy", 0.0)) * dt
				if bool(s.get("crush_lethal", true)) and GridMath.aabb_overlap(p_rect, Rect2(s["x"], s["y"], s["w"], s["h"])):
					return "crush"
				if absf(float(s["y"]) - float(s["base_y"])) > GridMath.TILE * 4.2:
					s["fall_state"] = 2
		elif st == "s3_slide_turf" and not bool(s.get("triggered", false)):
			if absf(float(player["x"]) - float(s["x"])) <= float(s.get("trigger_dist_px", 96.0)):
				s["triggered"] = true
				s["x"] = float(s["x"]) + float(s.get("slide_dx_px", 0.0))
				s["y"] = float(s["y"]) - float(s.get("slide_dy_px", 0.0))
	return ""

static func handle_attack_hit(
	hit_box: Rect2,
	dmg: int,
	is_sword: bool,
	is_upgraded_proj: bool,
	solids: Array,
	entities: Array,
	enemy_shots: Array,
	valves: Dictionary,
	state_bag: Dictionary,
	save: SaveManager
) -> bool:
	var hit = false
	if is_sword:
		for i in range(enemy_shots.size() - 1, -1, -1):
			var sh: Dictionary = enemy_shots[i]
			if GridMath.aabb_overlap(hit_box, Rect2(sh["x"], sh["y"], sh["w"], sh["h"])):
				enemy_shots.remove_at(i)
				hit = true

	if is_sword or is_upgraded_proj:
		for s in solids:
			if str(s.get("t", "")) == "s3_cloud" and not bool(s.get("disarmed", false)):
				if GridMath.aabb_overlap(hit_box, Rect2(s["x"], s["y"], s["w"], s["h"])):
					s["disarmed"] = true
					s["mode"] = "safe_plat"
					hit = true

	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		var er = Rect2(e["x"], e["y"], e["w"], e["h"])
		if not GridMath.aabb_overlap(hit_box, er):
			continue
		var et = str(e.get("t", ""))
		if et == "s3_valve":
			if not bool(e.get("fake", false)) and str(e.get("pipe_group", "")) != "":
				valves[str(e["pipe_group"])] = true
				e["spun"] = true
				for b in entities:
					if str(b.get("t", "")) == "s3_boss" and str(b.get("boss_kind", "")) == "pipe_kaiser":
						b["stun_timer"] = 4.6
			hit = true
		elif et == "s3_sundial" and float(e.get("hit_cd", 0.0)) <= 0.0:
			e["hit_cd"] = 0.35
			state_bag["sundial_phase"] = not bool(state_bag.get("sundial_phase", false))
			hit = true
		elif et == "s3_bomb_trophy" and float(e.get("fuse", -1.0)) < 0.0:
			e["fuse"] = 1.35
			hit = true
		elif et == "s3_mimic_flag" and is_sword and not bool(e.get("tamed", false)):
			e["hp"] = int(e.get("hp", 2)) - 1
			hit = true
			if int(e["hp"]) <= 0:
				if str(e.get("mode", "")) == "tame_goal":
					e["tamed"] = true
				else:
					entities.remove_at(i)
					save.add_coins(3)
		elif et == "s3_bush" and is_sword:
			entities.remove_at(i)
			save.add_coins(2)
			hit = true
		elif et == "s3_tanuki" and bool(e.get("is_clone", false)):
			solids.append({
				"key": "log_" + str(e.get("key", "")),
				"t": "solid",
				"x": float(e["x"]),
				"y": float(e["y"]) + 8.0,
				"base_x": float(e["x"]),
				"base_y": float(e["y"]) + 8.0,
				"w": 48.0,
				"h": 44.0,
				"skin": "wood",
				"broken": false,
				"revealed": true
			})
			entities.remove_at(i)
			hit = true
		elif et in ["s3_flower", "s3_tanuki", "s3_manju", "s3_ladybug", "s3_mole"]:
			e["hp"] = int(e.get("hp", 2)) - dmg
			hit = true
			if int(e["hp"]) <= 0:
				entities.remove_at(i)
				save.add_coins(3)
		elif et == "s3_boss":
			var eff = maxi(1, dmg / 2) if (str(e.get("boss_kind", "")) == "pipe_kaiser" and float(e.get("stun_timer", 0.0)) <= 0.0) else dmg
			e["hp"] = int(e.get("hp", 26)) - eff
			hit = true
			if int(e["hp"]) <= 0:
				entities.remove_at(i)
				state_bag["boss_defeated"] = true
				save.add_coins(25)
	return hit

static func step_post_move(
	dt: float,
	player: Dictionary,
	solids: Array,
	entities: Array,
	enemy_shots: Array,
	valves: Dictionary
) -> String:
	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])

	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		if float(e.get("cd", 0.0)) > 0.0:
			e["cd"] = maxf(0.0, float(e["cd"]) - dt)
		if float(e.get("hit_cd", 0.0)) > 0.0:
			e["hit_cd"] = maxf(0.0, float(e["hit_cd"]) - dt)
		if float(e.get("stun_timer", 0.0)) > 0.0:
			e["stun_timer"] = maxf(0.0, float(e["stun_timer"]) - dt)

		var er = Rect2(e["x"], e["y"], e["w"], e["h"])
		var et = str(e.get("t", ""))

		if et == "s3_valve" and not bool(e.get("spun", false)) and GridMath.aabb_overlap(p_rect, er):
			if bool(e.get("fake", false)):
				return "tall_pipe"
			if str(e.get("pipe_group", "")) != "":
				valves[str(e["pipe_group"])] = true
			e["spun"] = true
		elif et == "s3_catapult" and float(e.get("cd", 0.0)) <= 0.0 and GridMath.aabb_overlap(p_rect, er):
			e["cd"] = 0.45
			var m = str(e.get("mode", "forward_vault"))
			if m == "back_fling":
				player["vx"] = -520.0
				player["vy"] = -510.0
			elif m == "high_secret":
				player["vy"] = -860.0
			else:
				player["vx"] = 490.0
				player["vy"] = -665.0
		elif et == "s3_bomb_trophy":
			var fuse = float(e.get("fuse", -1.0))
			if fuse < 0.0 and GridMath.aabb_overlap(p_rect, er):
				e["fuse"] = 1.35
			elif fuse >= 0.0:
				fuse -= dt
				e["fuse"] = fuse
				if fuse <= 0.0:
					var center = er.get_center()
					for s in solids:
						if str(s.get("t", "")) == "destructible" and not bool(s.get("broken", false)):
							var sc = Rect2(s["x"], s["y"], s["w"], s["h"]).get_center()
							if sc.distance_to(center) <= 156.0:
								s["broken"] = true
					if p_rect.get_center().distance_to(center) <= 96.0:
						return "trophy_bomb"
					entities.remove_at(i)
					continue
		elif et == "s3_suction_pipe":
			var off = bool(valves.get(str(e.get("pipe_group", "")), false))
			if not off and absf(p_rect.get_center().x - er.get_center().x) < 68.0 and float(player["y"]) > float(e["y"]):
				player["vy"] = float(player["vy"]) - 1750.0 * dt
				if GridMath.aabb_overlap(p_rect, er):
					return "suction_pipe"
		elif et == "s3_mimic_flag" and GridMath.aabb_overlap(p_rect, er):
			return "WIN" if bool(e.get("tamed", false)) else "mimic_flag"
		elif et == "s3_bush" and str(e.get("mode", "")) != "safe":
			var inner = Rect2(float(e["x"]) + 10.0, float(e["y"]) + 8.0, float(e["w"]) - 20.0, float(e["h"]) - 8.0)
			if GridMath.aabb_overlap(p_rect, inner):
				return "bush_blade"
		elif et == "s3_tanuki":
			if not bool(e.get("cloned", false)) and not bool(e.get("is_clone", false)) and absf(float(player["x"]) - float(e["x"])) < 220.0:
				e["cloned"] = true
				var cl = e.duplicate(true)
				cl["key"] = str(e.get("key", "")) + "_clone"
				cl["x"] = float(e["x"]) - 56.0
				cl["is_clone"] = true
				cl["hp"] = 1
				entities.append(cl)
			if GridMath.aabb_overlap(p_rect, er):
				return "tanuki"
		elif et == "s3_mole":
			e["clock"] = float(e.get("clock", 0.0)) + dt
			if float(e["clock"]) >= 2.2:
				e["clock"] = 0.0
				enemy_shots.append({
					"x": float(e["x"]) + 12.0, "y": float(e["y"]), "w": 16.0, "h": 16.0,
					"vx": -190.0 if float(player["x"]) < float(e["x"]) else 190.0,
					"vy": -360.0, "grav": 780.0, "life": 2.8
				})
			if GridMath.aabb_overlap(p_rect, er):
				return "mole"
		elif et == "s3_ladybug":
			var d = int(e.get("dir", -1))
			e["x"] = float(e["x"]) + d * 145.0 * dt
			if float(e["x"]) <= float(e.get("min_px", 0.0)):
				e["dir"] = 1
			elif float(e["x"]) >= float(e.get("max_px", 9999.0)):
				e["dir"] = -1
			if GridMath.aabb_overlap(p_rect, Rect2(e["x"], e["y"], e["w"], e["h"])):
				return "ladybug"
		elif (et == "s3_flower" or et == "s3_manju") and str(e.get("mode", "")) != "polite":
			if GridMath.aabb_overlap(p_rect, er):
				return "flower" if et == "s3_flower" else "manju"
		elif et == "s3_sun":
			if float(player["x"]) >= float(e.get("trigger_px", 480.0)):
				e["awake"] = true
			if bool(e.get("awake", false)):
				var sc = float(e.get("swoop_clock", 1.2)) - dt
				e["swoop_clock"] = sc
				e["x"] = float(player["x"]) + cos(sc * 1.8) * 220.0
				e["y"] = float(e.get("home_y", 80.0)) + maxf(0.0, sin(sc * 2.1)) * 270.0
				if GridMath.aabb_overlap(p_rect, Rect2(e["x"], e["y"], e["w"], e["h"])):
					return "troll_sun"
		elif et == "s3_boss":
			if float(e.get("stun_timer", 0.0)) <= 0.0:
				var pc = float(e.get("phase_clock", 0.0)) + dt
				e["phase_clock"] = pc
				e["x"] = float(e.get("base_x", e["x"])) + sin(pc * 1.7) * 96.0
				var at = float(e.get("atk_timer", 1.5)) - dt
				if at <= 0.0:
					at = 1.55
					var dir_v = (p_rect.get_center() - er.get_center()).normalized()
					enemy_shots.append({
						"x": er.get_center().x, "y": er.get_center().y, "w": 16.0, "h": 16.0,
						"vx": dir_v.x * 255.0, "vy": dir_v.y * 255.0, "grav": 0.0, "life": 3.2
					})
				e["atk_timer"] = at
			if GridMath.aabb_overlap(p_rect, Rect2(e["x"], e["y"], e["w"], e["h"])):
				return "boss"
	return ""
