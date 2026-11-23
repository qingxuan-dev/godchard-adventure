class_name HintBlueprintView
extends Control

var lv_data: Dictionary = {}
var textures: Dictionary = {}
var font: Font = null
var pan_norm: float = 0.0
var dragging: bool = false
var drag_start_x: float = 0.0
var drag_start_pan: float = 0.0
var anim_t: float = 0.0

func setup(p_textures: Dictionary, p_font: Font) -> void:
	textures = p_textures
	font = p_font
	custom_minimum_size = Vector2(460.0, 152.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_stage(p_lv: Dictionary) -> void:
	lv_data = p_lv
	pan_norm = 0.0
	queue_redraw()

func reset_pan() -> void:
	pan_norm = 0.0
	queue_redraw()

func step_anim(dt: float) -> void:
	anim_t += dt
	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				drag_start_x = mb.position.x
				drag_start_pan = pan_norm
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var dx: float = mm.position.x - drag_start_x
		pan_norm = clampf(drag_start_pan - dx / maxf(120.0, size.x * 0.75), 0.0, 1.0)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		pan_norm = clampf(pan_norm - sd.relative.x / maxf(120.0, size.x * 0.75), 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var w: float = maxf(200.0, size.x)
	var h: float = maxf(110.0, size.y)
	draw_rect(Rect2(0.0, 0.0, w, h), Color("#030926"), true)
	draw_rect(Rect2(1.0, 1.0, w - 2.0, h - 2.0), Color(0.0, 0.96, 1.0, 0.38), false, 2.0)

	var gx_step: float = 24.0
	var cx_line: float = gx_step
	while cx_line < w:
		draw_line(Vector2(cx_line, 0.0), Vector2(cx_line, h), Color(0.0, 0.96, 1.0, 0.07), 1.0)
		cx_line += gx_step
	var cy_line: float = gx_step
	while cy_line < h:
		draw_line(Vector2(0.0, cy_line), Vector2(w, cy_line), Color(0.0, 0.96, 1.0, 0.07), 1.0)
		cy_line += gx_step

	if lv_data.is_empty():
		return

	var bounds_d: Dictionary = lv_data.get("bounds", { "minX": -2.0, "maxX": 36.0 })
	var min_gx: float = float(bounds_d.get("minX", -2.0))
	var max_gx: float = float(bounds_d.get("maxX", 36.0))
	var total_span: float = maxf(16.0, max_gx - min_gx)
	var view_span: float = minf(total_span, 34.0)
	var max_off: float = maxf(0.0, total_span - view_span)
	var view_start: float = min_gx + pan_norm * max_off

	var objs: Array = lv_data.get("objs", [])
	var max_gy: float = 8.5
	for o_var in objs:
		var o_chk: Dictionary = o_var
		var top_gy: float = float(o_chk.get("y", 0.0)) + float(o_chk.get("h", 1.0))
		if top_gy > max_gy and top_gy < 16.0:
			max_gy = top_gy

	var pad_x: float = 14.0
	var pad_top: float = 12.0
	var pad_bot: float = 16.0
	var scale_x: float = (w - pad_x * 2.0) / view_span
	var scale_y: float = (h - pad_top - pad_bot) / (max_gy + 1.2)

	var waypoints: Array[Vector2] = []
	var real_goal: Vector2 = Vector2(w - 28.0, h * 0.5)
	var has_goal: bool = false

	for o_var in objs:
		var o: Dictionary = o_var
		var ot: String = str(o.get("t", ""))
		var ox_g: float = float(o.get("x", 0.0))
		var oy_g: float = float(o.get("y", 0.0))
		var ow_g: float = float(o.get("w", 1.0))
		var oh_g: float = float(o.get("h", 1.0))
		var bx: float = pad_x + (ox_g - view_start) * scale_x
		var bw: float = maxf(5.0, ow_g * scale_x)
		var bh: float = maxf(5.0, oh_g * scale_y)
		var by: float = h - pad_bot - (oy_g + oh_g) * scale_y

		if bx + bw < -16.0 or bx > w + 16.0:
			continue

		if ot in ["solid", "vanish", "destructible", "s3_tall_pipe", "s3_slide_turf", "s3_drop_block", "conveyor", "rail_plat", "polarity_block", "phase_plat", "signal_bridge", "shy_brick"]:
			var fill_c: Color = Color(0.14, 0.52, 0.68, 0.65)
			if ot == "destructible":
				fill_c = Color(0.96, 0.45, 0.18, 0.75)
			elif ot == "s3_tall_pipe":
				fill_c = Color(0.13, 0.77, 0.37, 0.78)
			draw_rect(Rect2(bx, by, bw, bh), fill_c, true)
			draw_rect(Rect2(bx, by, bw, bh), Color("#38bdf8"), false, 1.0)
		elif ot == "fake_wall" or ot == "fake_plat":
			draw_rect(Rect2(bx, by, bw, bh), Color(0.75, 0.52, 0.99, 0.24), true)
			draw_rect(Rect2(bx, by, bw, bh), Color("#c084fc"), false, 1.5)
		elif ot == "invis":
			var ih: float = maxf(6.0, 0.8 * scale_y)
			var iy: float = h - pad_bot - (oy_g + 0.8) * scale_y
			draw_rect(Rect2(bx, iy, maxf(8.0, bw), ih), Color(0.0, 0.96, 1.0, 0.22), true)
			draw_rect(Rect2(bx, iy, maxf(8.0, bw), ih), Color("#00f5ff"), false, 1.5)
			waypoints.append(Vector2(bx + bw * 0.5, iy - 4.0))
		elif ot == "qblock":
			var qy: float = h - pad_bot - (oy_g + 0.9) * scale_y
			draw_rect(Rect2(bx, qy, maxf(8.0, scale_x), maxf(8.0, scale_y * 0.9)), Color("#facc15"), true)
		elif ot == "s3_cloud" or ot == "cloud":
			var safe_c: bool = (ot == "cloud" and not bool(o.get("knife", false))) or (ot == "s3_cloud" and str(o.get("mode", "")) == "safe_plat")
			draw_rect(Rect2(bx, by, maxf(10.0, bw), maxf(6.0, bh)), Color("#38bdf8") if safe_c else Color("#fb7185"), true)
		elif ot in ["checkpoint", "spring", "s3_valve", "s3_sundial", "s3_catapult", "signal_node", "polarity_node", "pipe", "portal", "hourglass"]:
			var wy: float = h - pad_bot - (oy_g + 1.0) * scale_y
			var is_fake_v: bool = bool(o.get("fake", false)) or bool(o.get("s3Fake", false))
			draw_circle(Vector2(bx + 5.0, wy + 5.0), 4.5, Color("#fb7185") if is_fake_v else Color("#4ade80"))
			if not is_fake_v:
				waypoints.append(Vector2(bx + 5.0, wy))
		elif ot == "flag" or ot == "s3_mimic_flag" or ot == "mimic_flag":
			var fy: float = h - pad_bot - (oy_g + 1.6) * scale_y
			var is_real_goal: bool = (ot == "flag" and not bool(o.get("fake", false))) or (ot == "s3_mimic_flag" and str(o.get("mode", "")) == "tame_goal") or (ot == "mimic_flag" and str(o.get("mode", "")) == "sword_tame")
			if is_real_goal:
				real_goal = Vector2(bx + 6.0, fy + 6.0)
				has_goal = true
				if textures.has("star_gold"):
					draw_texture_rect(textures["star_gold"], Rect2(bx - 3.0, fy - 2.0, 14.0, 14.0), false)
				else:
					draw_circle(real_goal, 6.0, Color("#fde047"))
			else:
				draw_line(Vector2(bx, fy), Vector2(bx + 10.0, fy + 10.0), Color("#ff2a85"), 2.2)
				draw_line(Vector2(bx + 10.0, fy), Vector2(bx, fy + 10.0), Color("#ff2a85"), 2.2)
		elif ot in ["spikes", "flower", "amanita", "s3_bush", "s3_flower", "s3_ladybug", "s3_manju", "s3_mole", "s2_enemy", "enemy", "s3_boss", "s2_boss"]:
			var hy: float = h - pad_bot - (oy_g + 0.9) * scale_y
			draw_rect(Rect2(bx, hy, maxf(6.0, bw * 0.8), 5.0), Color(0.96, 0.25, 0.37, 0.78), true)

	var spawn_d: Dictionary = lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
	var start_pt: Vector2 = Vector2(
		pad_x + (float(spawn_d.get("x", 2.0)) - view_start) * scale_x + 5.0,
		h - pad_bot - (float(spawn_d.get("y", 2.0)) + 1.1) * scale_y
	)
	draw_circle(start_pt, 5.0, Color("#00f5ff"))

	if has_goal:
		var route_pts: Array[Vector2] = [start_pt]
		waypoints.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for wp in waypoints:
			if wp.distance_to(route_pts[route_pts.size() - 1]) > 22.0 and ((real_goal.x >= start_pt.x and wp.x > start_pt.x and wp.x < real_goal.x) or (real_goal.x < start_pt.x and wp.x < start_pt.x and wp.x > real_goal.x)):
				route_pts.append(wp)
				if route_pts.size() >= 6:
					break
		route_pts.append(real_goal)
		for ri in range(1, route_pts.size()):
			var p0: Vector2 = route_pts[ri - 1]
			var p1: Vector2 = route_pts[ri]
			var mid: Vector2 = Vector2((p0.x + p1.x) * 0.5, minf(p0.y, p1.y) - 10.0)
			var segs: int = 8
			for si in range(segs):
				var t0: float = float(si) / float(segs)
				var t1: float = float(si + 0.55) / float(segs)
				var q0: Vector2 = p0.lerp(mid, t0).lerp(mid.lerp(p1, t0), t0)
				var q1: Vector2 = p0.lerp(mid, t1).lerp(mid.lerp(p1, t1), t1)
				draw_line(q0, q1, Color("#fde047"), 2.0)

	if total_span > view_span + 1.0:
		var bar_w: float = maxf(36.0, (view_span / total_span) * (w - 24.0))
		var bar_x: float = 12.0 + pan_norm * (w - 24.0 - bar_w)
		draw_rect(Rect2(12.0, h - 7.0, w - 24.0, 4.0), Color(1.0, 1.0, 1.0, 0.12), true)
		draw_rect(Rect2(bar_x, h - 7.0, bar_w, 4.0), Color("#00f5ff"), true)
