class_name Sector1And2Mechanics
extends RefCounted

static func is_solid_collidable(s: Dictionary, active_layer: int, signal_groups: Dictionary) -> bool:
	if bool(s.get("broken", false)):
		return false
	var t = str(s.get("t", ""))
	if t == "fake_wall" or t == "fake_plat":
		return false
	var lyr = int(s.get("layer", -1))
	if lyr >= 0 and lyr != active_layer:
		return false
	if t == "signal_gate":
		var grp = str(s.get("group", ""))
		if grp != "" and bool(signal_groups.get(grp, false)):
			return false
	return true

static func step_mechanics(
	dt: float,
	player: Dictionary,
	solids: Array,
	entities: Array,
	bullets: Array,
	active_layer: int,
	polarity_groups: Dictionary
) -> String:
	var p_rect = Rect2(player["x"], player["y"], player["w"], player["h"])

	for s in solids:
		if bool(s.get("broken", false)):
			continue
		var st = str(s.get("t", ""))
		if st == "polarity_block":
			var grp = str(s.get("group", ""))
			var orange = bool(polarity_groups.get(grp, false))
			var tx: float = float(s["orange_x"] if orange else s["blue_x"])
			var ty: float = float(s["orange_y"] if orange else s["blue_y"])
			var dx = (tx - float(s["x"])) * minf(1.0, dt * 7.5)
			var dy = (ty - float(s["y"])) * minf(1.0, dt * 7.5)
			s["x"] = float(s["x"]) + dx
			s["y"] = float(s["y"]) + dy
			if bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - float(s["y"])) <= 10.0:
				if float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
					player["x"] = float(player["x"]) + dx
					player["y"] = float(player["y"]) + dy
		elif st == "conveyor":
			if bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - float(s["y"])) <= 8.0:
				if float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
					player["x"] = float(player["x"]) + float(s.get("belt_vx", 180.0)) * dt

	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		var lyr = int(e.get("layer", -1))
		if lyr >= 0 and lyr != active_layer:
			continue
		var er = Rect2(e["x"], e["y"], e["w"], e["h"])
		var et = str(e.get("t", ""))
		if et == "wind_zone" and GridMath.aabb_overlap(p_rect, er):
			player["x"] = float(player["x"]) + float(e.get("vx", 0.0)) * dt
			player["vy"] = float(player["vy"]) + float(e.get("vy", 0.0)) * dt
		elif et == "polarity_node":
			for b_idx in range(bullets.size() - 1, -1, -1):
				var b: Dictionary = bullets[b_idx]
				var br = Rect2(b["x"], b["y"], b["w"], b["h"])
				if GridMath.aabb_overlap(br, er):
					var grp = str(e.get("group", ""))
					if grp != "":
						polarity_groups[grp] = not bool(polarity_groups.get(grp, false))
					bullets.remove_at(b_idx)
					break
		elif et == "peace_dove" and bool(e.get("angry", false)):
			var dir = Vector2(float(player["x"]) - float(e["x"]), float(player["y"]) - float(e["y"])).normalized()
			e["x"] = float(e["x"]) + dir.x * 340.0 * dt
			e["y"] = float(e["y"]) + dir.y * 340.0 * dt
			if GridMath.aabb_overlap(p_rect, Rect2(e["x"], e["y"], e["w"], e["h"])):
				return "enemy"
	return ""
