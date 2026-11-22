class_name Sector1And2Mechanics
extends RefCounted
static func is_in_layer(obj: Dictionary, active_layer: int) -> bool:
	var lyr: int = int(obj.get("layer", -1))
	return lyr < 0 or lyr == active_layer
static func is_solid_collidable(s: Dictionary, active_layer: int, signal_groups: Dictionary) -> bool:
	if bool(s.get("broken", false)) or not is_in_layer(s, active_layer): return false
	var t: String = str(s.get("t", ""))
	if t in ["fake_wall", "fake_plat"]: return false
	if t == "signal_gate":
		var on: bool = str(s.get("group", "")) != "" and bool(signal_groups.get(str(s["group"]), false))
		return on if bool(s.get("invert", false)) else (not on)
	if t == "signal_bridge":
		var on2: bool = str(s.get("group", "")) != "" and bool(signal_groups.get(str(s["group"]), false))
		return (not on2) if bool(s.get("invert", false)) else on2
	if t in ["phase_plat", "null_block"]: return str(s.get("phase_state", "solid")) != "ghost"
	if t == "glass_panel": return bool(s.get("real", true))
	if t == "beat_gate": return not bool(s.get("is_open", false))
	if t == "shy_brick": return bool(s.get("shy_solid", true))
	return true
static func step_mechanics(dt: float, player: Dictionary, solids: Array, entities: Array, bullets: Array, active_layer: int, polarity_groups: Dictionary, signal_groups: Dictionary = {}, save: SaveManager = null, t_sec: float = 0.0) -> String:
	var p_rect: Rect2 = Rect2(float(player["x"]), float(player["y"]), float(player["w"]), float(player["h"]))
	for s in solids:
		var st: String = str(s.get("t", ""))
		if bool(s.get("broken", false)):
			if st == "vanish" and float(s.get("respawn_timer", 0.0)) > 0.0:
				s["respawn_timer"] = float(s["respawn_timer"]) - dt
				if float(s["respawn_timer"]) <= 0.0: s["broken"] = false; s["vanish_timer"] = -1.0
			continue
		if not is_in_layer(s, active_layer): continue
		if st == "vanish":
			var vt: float = float(s.get("vanish_timer", -1.0))
			if vt >= 0.0:
				s["vanish_timer"] = vt - dt
				if float(s["vanish_timer"]) <= 0.0: s["broken"] = true; s["respawn_timer"] = 2.2
			elif bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - float(s["y"])) <= 8.0 and float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
				s["vanish_timer"] = 0.48
		elif st == "phase_plat":
			var per: float = maxf(1.4, float(s.get("period", 3.4)))
			s["phase_state"] = "solid" if (fposmod(t_sec + float(s.get("offset", 0.0)), per) / per) < 0.56 else "ghost"
		elif st == "polarity_block":
			var orange: bool = bool(polarity_groups.get(str(s.get("group", "")), false))
			var tx: float = float(s["orange_x"] if orange else s["blue_x"])
			var ty: float = float(s["orange_y"] if orange else s["blue_y"])
			var dx: float = (tx - float(s["x"])) * minf(1.0, dt * 7.5)
			var dy: float = (ty - float(s["y"])) * minf(1.0, dt * 7.5)
			s["x"] = float(s["x"]) + dx; s["y"] = float(s["y"]) + dy
			if bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - float(s["y"])) <= 10.0 and float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
				player["x"] = float(player["x"]) + dx; player["y"] = float(player["y"]) + dy
		elif st == "conveyor":
			if bool(player["on_ground"]) and absf(float(player["y"]) + float(player["h"]) - float(s["y"])) <= 8.0 and float(player["x"]) + float(player["w"]) > float(s["x"]) and float(player["x"]) < float(s["x"]) + float(s["w"]):
				player["x"] = float(player["x"]) + float(s.get("belt_vx", 135.0)) * dt
	for b_idx in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[b_idx]
		var br: Rect2 = Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]))
		var hit: bool = false
		for e_idx in range(entities.size() - 1, -1, -1):
			var e: Dictionary = entities[e_idx]
			if not is_in_layer(e, active_layer) or not GridMath.aabb_overlap(br, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))): continue
			var et: String = str(e.get("t", ""))
			if et == "signal_node" and not bool(e.get("fake", false)):
				var g1: String = str(e.get("group", ""))
				if g1 != "": signal_groups[g1] = not bool(signal_groups.get(g1, false))
				hit = true; break
			elif et == "polarity_node":
				var g2: String = str(e.get("group", ""))
				if g2 != "": polarity_groups[g2] = not bool(polarity_groups.get(g2, false))
				hit = true; break
			elif et in ["enemy", "s2_enemy"] and str(e.get("kind", "")) != "forklift":
				e["hp"] = int(e.get("hp", 4)) - (3 if bool(b.get("upgraded", false)) else 1)
				if int(e["hp"]) <= 0:
					var ug: String = str(e.get("unlock_group", ""))
					if ug != "": signal_groups[ug] = true
					entities.remove_at(e_idx)
					if save != null: save.add_coins(2)
				hit = true; break
			elif et == "s2_boss" and not bool(e.get("defeated", false)):
				e["hp"] = int(e.get("hp", 25)) - (3 if bool(b.get("upgraded", false)) else 1)
				if int(e["hp"]) <= 0:
					e["defeated"] = true
					if save != null: save.add_coins(20)
				hit = true; break
		if hit and not bool(b.get("s3_wave", false)): bullets.remove_at(b_idx)
	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		var et: String = str(e.get("t", ""))
		if et != "layer_term" and not is_in_layer(e, active_layer): continue
		var er: Rect2 = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		if et == "wind_zone" and GridMath.aabb_overlap(p_rect, er):
			player["x"] = float(player["x"]) + float(e.get("vx", 0.0)) * dt; player["vy"] = float(player["vy"]) + float(e.get("vy", 0.0)) * dt
		elif et == "electric_arc" and GridMath.aabb_overlap(p_rect, er): return "electric"
		elif et in ["enemy", "s2_enemy"]:
			var vxm: float = float(e.get("vx", -95.0 if et == "s2_enemy" else 0.0))
			if et == "enemy" and absf(float(player["x"]) - float(e["x"])) < 380.0: vxm = signf(float(player["x"]) - float(e["x"])) * 112.0; e["vx"] = vxm
			e["x"] = float(e["x"]) + vxm * dt
			if et == "s2_enemy":
				if float(e["x"]) <= float(e.get("min_px", -9999.0)): e["vx"] = absf(vxm)
				elif float(e["x"]) >= float(e.get("max_px", 99999.0)): e["vx"] = -absf(vxm)
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 4.0, float(e["y"]) + 4.0, float(e["w"]) - 8.0, float(e["h"]) - 6.0)): return "enemy"
		elif et == "s2_boss" and not bool(e.get("defeated", false)):
			e["x"] = float(e.get("base_x", e["x"])) + sin(t_sec * 1.6) * 84.0
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]) + 8.0, float(e["y"]) + 8.0, float(e["w"]) - 16.0, float(e["h"]) - 16.0)): return "boss"
		elif et == "peace_dove" and bool(e.get("angry", false)):
			var dv: Vector2 = (p_rect.get_center() - er.get_center()).normalized()
			e["x"] = float(e["x"]) + dv.x * 340.0 * dt; e["y"] = float(e["y"]) + dv.y * 340.0 * dt
			if GridMath.aabb_overlap(p_rect, Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))): return "enemy"
	return ""
