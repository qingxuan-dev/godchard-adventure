class_name GridMath
extends RefCounted

const TILE: float = 48.0
const VIEWPORT_W: float = 960.0
const VIEWPORT_H: float = 540.0
const WORLD_ORIGIN_Y: float = 468.0

static func gx_to_px(gx: float) -> float:
	return gx * TILE

static func px_to_gx(px: float) -> float:
	return px / TILE

static func gy_to_py(gy: float, h_tiles: float = 0.0) -> float:
	return WORLD_ORIGIN_Y - (gy + h_tiles) * TILE

static func py_to_gy(py: float, h_tiles: float = 0.0) -> float:
	return (WORLD_ORIGIN_Y - py) / TILE - h_tiles

static func grid_to_world_rect(gx: float, gy: float, gw: float, gh: float) -> Rect2:
	return Rect2(gx_to_px(gx), gy_to_py(gy, gh), gw * TILE, gh * TILE)

static func world_to_grid_pos(px: float, py: float) -> Vector2:
	return Vector2(px_to_gx(px), py_to_gy(py, 0.0))

static func aabb_overlap(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x < b.position.x + b.size.x
		and a.position.x + a.size.x > b.position.x
		and a.position.y < b.position.y + b.size.y
		and a.position.y + a.size.y > b.position.y
	)

static func sample_slope_y(x_px: float, x0: float, y0: float, x1: float, y1: float) -> float:
	var dx: float = x1 - x0
	if absf(dx) < 0.001:
		return minf(y0, y1)
	var t: float = clampf((x_px - x0) / dx, 0.0, 1.0)
	return lerpf(y0, y1, t)

static func collide_aabb_with_slope(
	box: Rect2,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	snap_margin: float = 14.0
) -> Dictionary:
	var min_x: float = minf(x0, x1)
	var max_x: float = maxf(x0, x1)
	var foot_x: float = clampf(box.position.x + box.size.x * 0.5, min_x, max_x)
	if box.position.x + box.size.x <= min_x + 1.0 or box.position.x >= max_x - 1.0:
		return { "hit": false, "surface_y": 0.0, "normal": Vector2.UP, "t": 0.0 }
	var surf_y: float = sample_slope_y(foot_x, x0, y0, x1, y1)
	var foot_y: float = box.position.y + box.size.y
	var seg_vec: Vector2 = Vector2(x1 - x0, y1 - y0)
	var normal: Vector2 = Vector2(seg_vec.y, -seg_vec.x).normalized()
	if normal.y > 0.0:
		normal = -normal
	var dx_len: float = maxf(0.001, absf(x1 - x0))
	var ratio: float = clampf(absf(foot_x - x0) / dx_len, 0.0, 1.0)
	if foot_y >= surf_y - 4.0 and foot_y <= surf_y + snap_margin + 12.0:
		return {
			"hit": true,
			"surface_y": surf_y,
			"normal": normal,
			"t": ratio
		}
	return { "hit": false, "surface_y": surf_y, "normal": normal, "t": ratio }

static func segment_intersects_aabb(p0: Vector2, p1: Vector2, rect: Rect2) -> Dictionary:
	var d: Vector2 = p1 - p0
	var t_min: float = 0.0
	var t_max: float = 1.0
	var hit_normal: Vector2 = Vector2.ZERO

	if absf(d.x) < 0.00001:
		if p0.x < rect.position.x or p0.x > rect.position.x + rect.size.x:
			return { "hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO, "t": 1.0 }
	else:
		var inv_dx: float = 1.0 / d.x
		var tx1: float = (rect.position.x - p0.x) * inv_dx
		var tx2: float = (rect.position.x + rect.size.x - p0.x) * inv_dx
		var nx: Vector2 = Vector2(-1.0, 0.0) if inv_dx > 0.0 else Vector2(1.0, 0.0)
		if tx1 > tx2:
			var tmp_x: float = tx1
			tx1 = tx2
			tx2 = tmp_x
		if tx1 > t_min:
			t_min = tx1
			hit_normal = nx
		if tx2 < t_max:
			t_max = tx2
		if t_min > t_max:
			return { "hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO, "t": 1.0 }

	if absf(d.y) < 0.00001:
		if p0.y < rect.position.y or p0.y > rect.position.y + rect.size.y:
			return { "hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO, "t": 1.0 }
	else:
		var inv_dy: float = 1.0 / d.y
		var ty1: float = (rect.position.y - p0.y) * inv_dy
		var ty2: float = (rect.position.y + rect.size.y - p0.y) * inv_dy
		var ny: Vector2 = Vector2(0.0, -1.0) if inv_dy > 0.0 else Vector2(0.0, 1.0)
		if ty1 > ty2:
			var tmp_y: float = ty1
			ty1 = ty2
			ty2 = tmp_y
		if ty1 > t_min:
			t_min = ty1
			hit_normal = ny
		if ty2 < t_max:
			t_max = ty2
		if t_min > t_max:
			return { "hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO, "t": 1.0 }

	var hit_pt: Vector2 = p0 + d * t_min
	return { "hit": true, "point": hit_pt, "normal": hit_normal, "t": t_min }

static func reflect_velocity(vel: Vector2, normal: Vector2, speed_scale: float = 1.0) -> Vector2:
	var n: Vector2 = normal.normalized()
	if n.length_squared() < 0.0001:
		return -vel * speed_scale
	var r: Vector2 = vel - 2.0 * vel.dot(n) * n
	return r * speed_scale

static func reflect_by_mirror_angle(vel: Vector2, angle_deg: float, boost: float = 1.08) -> Vector2:
	var norm_deg: float = fposmod(angle_deg, 180.0)
	if absf(norm_deg - 90.0) < 8.0:
		return Vector2(-vel.x, vel.y) * boost
	if absf(norm_deg) < 8.0 or absf(norm_deg - 180.0) < 8.0:
		return Vector2(vel.x, -vel.y) * boost
	var rad: float = deg_to_rad(angle_deg)
	var tangent: Vector2 = Vector2(cos(rad), sin(rad)).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	return reflect_velocity(vel, normal, boost)

static func is_in_sight_cone(
	observer_pos: Vector2,
	facing_dir: Vector2,
	target_pos: Vector2,
	max_dist: float,
	half_angle_deg: float = 55.0
) -> bool:
	var delta: Vector2 = target_pos - observer_pos
	var dist: float = delta.length()
	if dist <= 0.001:
		return true
	if dist > max_dist:
		return false
	var f_norm: Vector2 = facing_dir.normalized()
	if f_norm.length_squared() < 0.0001:
		return false
	var cos_val: float = (delta / dist).dot(f_norm)
	return cos_val >= cos(deg_to_rad(half_angle_deg))

static func is_player_looking_at(
	player_center: Vector2,
	player_facing: int,
	target_rect: Rect2,
	max_dist: float = 480.0
) -> bool:
	var t_center: Vector2 = target_rect.get_center()
	var dx: float = t_center.x - player_center.x
	if absf(dx) <= 6.0:
		return false
	if absf(dx) > max_dist:
		return false
	return (dx * float(player_facing)) > 0.0

static func raycast_solids(
	origin: Vector2,
	target: Vector2,
	solids: Array,
	ignore_keys: Dictionary = {}
) -> Dictionary:
	var best_t: float = 2.0
	var best_hit: Dictionary = { "hit": false, "point": target, "normal": Vector2.ZERO, "t": 1.0, "solid": {} }
	for s_var in solids:
		var s: Dictionary = s_var
		if bool(s.get("broken", false)):
			continue
		var skey: String = str(s.get("key", ""))
		if skey != "" and bool(ignore_keys.get(skey, false)):
			continue
		var st: String = str(s.get("t", ""))
		if st == "fake_wall" or st == "fake_plat":
			continue
		if (st == "invis" or st == "qblock") and not bool(s.get("revealed", false)):
			continue
		var rect: Rect2 = Rect2(float(s.get("x", 0.0)), float(s.get("y", 0.0)), float(s.get("w", 0.0)), float(s.get("h", 0.0)))
		var res: Dictionary = segment_intersects_aabb(origin, target, rect)
		if bool(res.get("hit", false)) and float(res.get("t", 1.0)) < best_t:
			best_t = float(res["t"])
			best_hit = {
				"hit": true,
				"point": res["point"],
				"normal": res["normal"],
				"t": best_t,
				"solid": s
			}
	return best_hit

static func has_line_of_sight(origin: Vector2, target: Vector2, solids: Array) -> bool:
	var res: Dictionary = raycast_solids(origin, target, solids)
	return not bool(res.get("hit", false))

static func project_shadow_on_floor(
	light_pos: Vector2,
	caster_rect: Rect2,
	floor_y: float = WORLD_ORIGIN_Y - 2.0 * TILE,
	max_shadow_len: float = 340.0
) -> Rect2:
	var cx: float = caster_rect.position.x + caster_rect.size.x * 0.5
	var cy: float = caster_rect.position.y + caster_rect.size.y * 0.5
	var dy: float = maxf(24.0, cy - light_pos.y)
	var dx: float = cx - light_pos.x
	var fall_dist: float = maxf(0.0, floor_y - cy)
	var proj_x: float = cx + (dx / dy) * fall_dist
	var slant_factor: float = clampf(absf(dx) / dy, 0.25, 3.2)
	var shadow_w: float = clampf(caster_rect.size.x * (0.9 + slant_factor * 1.15), 24.0, max_shadow_len)
	var sx: float = proj_x - shadow_w * 0.5
	if dx > 4.0:
		sx = cx
	elif dx < -4.0:
		sx = cx - shadow_w + caster_rect.size.x
	return Rect2(sx, floor_y - 10.0, shadow_w, 14.0)
