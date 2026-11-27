class_name HintBlueprintView
extends Control

signal tier_changed(new_tier: int, full_hint_used: bool)

const TIER_LIGHT: int = 1
const TIER_MEDIUM: int = 2
const TIER_FULL: int = 3

const CIRCLED_NUMS: Array[String] = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧"]

const PITFALL_NAMES_ZH: Dictionary = {
	"C": "常识/道具反转",
	"I": "信息/路牌欺诈",
	"P": "物理/材质异常",
	"S": "状态/资源窗口",
	"T": "时间/残影记忆",
	"A": "敌人AI/仇恨利用",
	"M": "Meta/系统规则"
}

const PITFALL_NAMES_EN: Dictionary = {
	"C": "Common-Sense Subversion",
	"I": "Info / UI Deception",
	"P": "Physics / Material Anomaly",
	"S": "State / Resource Window",
	"T": "Time / Echo Memory",
	"A": "AI / Aggro Manipulation",
	"M": "Meta / System Rule"
}

var lv_data: Dictionary = {}
var textures: Dictionary = {}
var font: Font = null
var current_tier: int = TIER_LIGHT
var full_hint_used_by_stage: Dictionary = {}

var pan_norm: float = 0.0
var dragging: bool = false
var drag_touch_idx: int = -1
var drag_start_x: float = 0.0
var drag_start_pan: float = 0.0
var anim_t: float = 0.0

func setup(p_textures: Dictionary, p_font: Font) -> void:
	textures = p_textures
	font = p_font
	custom_minimum_size = Vector2(460.0, 158.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_stage(p_lv: Dictionary, keep_tier_if_same: bool = false) -> void:
	var prev_id: int = int(lv_data.get("id", -1))
	var next_id: int = int(p_lv.get("id", 0))
	lv_data = p_lv
	pan_norm = 0.0
	if not keep_tier_if_same or prev_id != next_id:
		if has_used_full_hint(next_id):
			current_tier = TIER_FULL
		else:
			current_tier = TIER_LIGHT
	queue_redraw()

func set_tier(p_tier: int, stage_id_override: int = -1) -> void:
	var clamped: int = clampi(p_tier, TIER_LIGHT, TIER_FULL)
	current_tier = clamped
	var sid: int = stage_id_override if stage_id_override > 0 else int(lv_data.get("id", 0))
	if clamped == TIER_FULL and sid > 0:
		full_hint_used_by_stage[str(sid)] = true
	queue_redraw()
	tier_changed.emit(current_tier, has_used_full_hint(sid))

func get_tier() -> int:
	return current_tier

func has_used_full_hint(stage_id: int) -> bool:
	return bool(full_hint_used_by_stage.get(str(stage_id), false))

func mark_full_hint_used(stage_id: int) -> void:
	if stage_id > 0:
		full_hint_used_by_stage[str(stage_id)] = true

func reset_stage_hint_usage(stage_id: int) -> void:
	full_hint_used_by_stage.erase(str(stage_id))
	if int(lv_data.get("id", 0)) == stage_id:
		current_tier = TIER_LIGHT
		queue_redraw()

# Extracts Light / Medium / Full progressive hint texts cleanly with full fallback support
func get_progressive_hints(lang: String = "zh") -> Dictionary:
	var is_en: bool = (lang == "en")
	var tiers_d: Dictionary = {}
	var raw_tiers: Variant = lv_data.get("hint_tiers_en" if is_en else "hint_tiers", lv_data.get("hint_tiers", {}))
	if typeof(raw_tiers) == TYPE_DICTIONARY:
		tiers_d = raw_tiers

	var light_txt: String = str(tiers_d.get("light_en" if is_en else "light", tiers_d.get("light", "")))
	var medium_txt: String = str(tiers_d.get("medium_en" if is_en else "medium", tiers_d.get("medium", "")))
	var full_steps: Array = []
	var raw_full: Variant = tiers_d.get("full_en" if is_en else "full", tiers_d.get("full", []))
	if typeof(raw_full) == TYPE_ARRAY:
		full_steps = (raw_full as Array).duplicate()

	if full_steps.is_empty():
		var legacy_steps: Variant = lv_data.get("hintStepsEn" if is_en else "hintSteps", lv_data.get("hintSteps", []))
		if typeof(legacy_steps) == TYPE_ARRAY:
			full_steps = (legacy_steps as Array).duplicate()

	# Synthesize spoiler-free Light & Medium hints if a stage only supplied legacy fields
	var p_types: Array = lv_data.get("pitfallTypes", [])
	var p_tags: Array[String] = []
	for pt_v in p_types:
		var code: String = str(pt_v)
		if is_en and PITFALL_NAMES_EN.has(code):
			p_tags.append(str(PITFALL_NAMES_EN[code]))
		elif (not is_en) and PITFALL_NAMES_ZH.has(code):
			p_tags.append(str(PITFALL_NAMES_ZH[code]))

	var sub_s: String = str(lv_data.get("subtitleEn" if is_en else "subtitle", lv_data.get("subtitle", "")))
	var quote_s: String = str(lv_data.get("trollQuoteEn" if is_en else "trollQuote", lv_data.get("trollQuote", "")))

	if light_txt == "":
		if is_en:
			var focus_en: String = (", ".join(p_tags)) if not p_tags.is_empty() else "suspicious stage props, shadows, and sound cues"
			light_txt = "Observe carefully without rushing: pay attention to %s. Look at blueprint scan rings (◎) for key objects before acting." % focus_en
		else:
			var focus_zh: String = ("、".join(p_tags)) if not p_tags.is_empty() else "起点的墙体粒子、机关阴影与声音差异"
			light_txt = "先停步观察而非盲冲：留意本关的【%s】（见上方雷达脉冲圈 ◎ 标注处），先用试探射击或短跳验证反应。" % focus_zh

	if medium_txt == "":
		if sub_s != "":
			medium_txt = (_tr_local(is_en, "隐藏规则解析：", "Hidden Rule: ")) + sub_s + (" — " + quote_s if quote_s != "" else "")
		elif quote_s != "":
			medium_txt = quote_s
		elif not full_steps.is_empty():
			medium_txt = str(full_steps[0])
		else:
			medium_txt = _tr_local(is_en, "陷阱遵循确定性因果规则：利用前一次失败暴露的材质、朝向或状态变化反制机关。", "Every trap follows deterministic rules: use the state, shadow, or sound revealed on failure to turn the mechanism to your advantage.")

	var formatted_full: Array[String] = []
	for i in range(full_steps.size()):
		var raw_line: String = str(full_steps[i]).strip_edges()
		var has_circled: bool = false
		for cn in CIRCLED_NUMS:
			if raw_line.begins_with(cn):
				has_circled = true
				break
		if has_circled:
			formatted_full.append(raw_line)
		else:
			var badge_n: String = CIRCLED_NUMS[i] if i < CIRCLED_NUMS.size() else ("(%d)" % (i + 1))
			formatted_full.append("%s %s" % [badge_n, raw_line])

	return {
		"light": light_txt,
		"medium": medium_txt,
		"full": formatted_full,
		"pitfall_tags": p_tags
	}

func _tr_local(is_en: bool, zh_s: String, en_s: String) -> String:
	return en_s if is_en else zh_s

func reset_pan() -> void:
	pan_norm = 0.0
	queue_redraw()

func step_anim(dt: float) -> void:
	anim_t += dt
	if visible:
		queue_redraw()

func handle_touch_pan(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	var gr: Rect2 = get_global_rect()
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and gr.has_point(st.position):
			drag_touch_idx = st.index
			drag_start_x = st.position.x
			drag_start_pan = pan_norm
			return true
		elif not st.pressed and st.index == drag_touch_idx:
			drag_touch_idx = -1
			return true
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == drag_touch_idx:
			var dx: float = sd.position.x - drag_start_x
			pan_norm = clampf(drag_start_pan - dx / maxf(120.0, size.x * 0.75), 0.0, 1.0)
			queue_redraw()
			return true
	return false

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

func _is_cloud_safe_bp(o: Dictionary) -> bool:
	var sub: String = str(o.get("subType", ""))
	if sub != "":
		return sub == "solid" or sub == "bounce"
	var ot: String = str(o.get("t", ""))
	if ot == "cloud":
		return not bool(o.get("knife", false)) and not bool(o.get("poison", false))
	return str(o.get("mode", "")) == "safe_plat"

func _is_real_goal_bp(o: Dictionary) -> bool:
	var ot: String = str(o.get("t", ""))
	if bool(o.get("fake", false)):
		return false
	if ot == "flag":
		return true
	if ot == "s3_mimic_flag":
		return str(o.get("mode", "")) == "tame_goal"
	if ot == "mimic_flag":
		return str(o.get("mode", "")) == "sword_tame"
	return false

func _draw() -> void:
	var w: float = maxf(200.0, size.x)
	var h: float = maxf(110.0, size.y)
	draw_rect(Rect2(0.0, 0.0, w, h), Color("#030926"), true)
	var border_col: Color = Color("#67e8f9") if current_tier == TIER_LIGHT else (Color("#c084fc") if current_tier == TIER_MEDIUM else Color("#fde047"))
	draw_rect(Rect2(1.0, 1.0, w - 2.0, h - 2.0), border_col, false, 2.0)

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
		if typeof(o_var) != TYPE_DICTIONARY:
			continue
		var o_chk: Dictionary = o_var
		var top_gy: float = float(o_chk.get("y", 0.0)) + float(o_chk.get("h", 1.0))
		if top_gy > max_gy and top_gy < 18.0:
			max_gy = top_gy

	var pad_x: float = 14.0
	var pad_top: float = 18.0
	var pad_bot: float = 16.0
	var scale_x: float = (w - pad_x * 2.0) / view_span
	var scale_y: float = (h - pad_top - pad_bot) / (max_gy + 1.4)

	var uuid_screen_map: Dictionary = {}
	var waypoints: Array[Vector2] = []
	var observe_rings: Array[Vector2] = []
	var real_goal: Vector2 = Vector2(w - 28.0, h * 0.5)
	var has_goal: bool = false

	for o_var in objs:
		if typeof(o_var) != TYPE_DICTIONARY:
			continue
		var o: Dictionary = o_var
		var ot: String = str(o.get("t", ""))
		var role_s: String = str(o.get("role", ""))
		var ox_g: float = float(o.get("x", 0.0))
		var oy_g: float = float(o.get("y", 0.0))
		var ow_g: float = float(o.get("w", 1.0))
		var oh_g: float = float(o.get("h", 1.0))
		var bx: float = pad_x + (ox_g - view_start) * scale_x
		var bw: float = maxf(5.0, ow_g * scale_x)
		var bh: float = maxf(5.0, oh_g * scale_y)
		var by: float = h - pad_bot - (oy_g + oh_g) * scale_y

		var ouuid: String = str(o.get("uuid", ""))
		if ouuid != "":
			uuid_screen_map[ouuid] = Vector2(bx + bw * 0.5, by + bh * 0.5)

		if bx + bw < -20.0 or bx > w + 20.0:
			continue

		if ot in [
			"solid", "vanish", "destructible", "s3_tall_pipe", "s3_slide_turf",
			"s3_drop_block", "conveyor", "rail_plat", "polarity_block", "phase_plat",
			"signal_bridge", "shy_brick", "glass_panel", "weight_scale", "ghost_train"
		]:
			var fill_c: Color = Color(0.14, 0.52, 0.68, 0.65)
			if ot == "destructible":
				fill_c = Color(0.96, 0.45, 0.18, 0.78)
				observe_rings.append(Vector2(bx + bw * 0.5, by + bh * 0.5))
			elif ot == "s3_tall_pipe":
				fill_c = Color(0.13, 0.77, 0.37, 0.78)
			elif ot == "weight_scale" or role_s == "weight_scale":
				fill_c = Color(0.98, 0.80, 0.12, 0.82)
				observe_rings.append(Vector2(bx + bw * 0.5, by))
			draw_rect(Rect2(bx, by, bw, bh), fill_c, true)
			draw_rect(Rect2(bx, by, bw, bh), Color("#38bdf8"), false, 1.0)
		elif ot == "fake_wall" or ot == "fake_plat" or ot == "fake_error":
			observe_rings.append(Vector2(bx + bw * 0.5, by + bh * 0.5))
			if current_tier == TIER_LIGHT:
				# Tier 1 Light Hint: draw like normal terrain + subtle observation ring (no spoiler!)
				draw_rect(Rect2(bx, by, bw, bh), Color(0.16, 0.48, 0.66, 0.60), true)
				draw_rect(Rect2(bx, by, bw, bh), Color("#67e8f9"), false, 1.0)
			else:
				draw_rect(Rect2(bx, by, bw, bh), Color(0.75, 0.52, 0.99, 0.26), true)
				draw_rect(Rect2(bx, by, bw, bh), Color("#c084fc"), false, 1.5)
		elif ot == "invis":
			if current_tier >= TIER_MEDIUM:
				var ih: float = maxf(6.0, 0.8 * scale_y)
				var iy: float = h - pad_bot - (oy_g + 0.8) * scale_y
				draw_rect(Rect2(bx, iy, maxf(8.0, bw), ih), Color(0.0, 0.96, 1.0, 0.24), true)
				draw_rect(Rect2(bx, iy, maxf(8.0, bw), ih), Color("#00f5ff"), false, 1.5)
				waypoints.append(Vector2(bx + bw * 0.5, iy - 4.0))
			else:
				observe_rings.append(Vector2(bx + bw * 0.5, by))
		elif ot == "qblock":
			var qy: float = h - pad_bot - (oy_g + 0.9) * scale_y
			draw_rect(Rect2(bx, qy, maxf(8.0, scale_x), maxf(8.0, scale_y * 0.9)), Color("#facc15"), true)
		elif ot == "s3_cloud" or ot == "cloud" or ot == "cloud_knife":
			observe_rings.append(Vector2(bx + bw * 0.5, by + bh * 0.5))
			var safe_c: bool = _is_cloud_safe_bp(o)
			var c_col: Color = Color("#94a3b8") if current_tier == TIER_LIGHT else (Color("#38bdf8") if safe_c else Color("#fb7185"))
			draw_rect(Rect2(bx, by, maxf(10.0, bw), maxf(6.0, bh)), c_col, true)
		elif ot in [
			"checkpoint", "spring", "s3_valve", "s3_sundial", "s3_catapult",
			"signal_node", "polarity_node", "pipe", "portal", "hourglass",
			"mirror", "root_term", "layer_term", "clock", "beat_clock", "spotlight",
			"poison_fog_door", "spore_key"
		]:
			var wy: float = h - pad_bot - (oy_g + 1.0) * scale_y
			var pt_c: Vector2 = Vector2(bx + 5.0, wy + 5.0)
			observe_rings.append(pt_c)
			var is_fake_v: bool = bool(o.get("fake", false)) or bool(o.get("s3Fake", false))
			var dot_c: Color = Color("#67e8f9") if current_tier == TIER_LIGHT else (Color("#fb7185") if is_fake_v else Color("#4ade80"))
			draw_circle(pt_c, 4.5, dot_c)
			if not is_fake_v:
				waypoints.append(Vector2(bx + 5.0, wy))
		elif ot == "flag" or ot == "s3_mimic_flag" or ot == "mimic_flag":
			var fy: float = h - pad_bot - (oy_g + 1.6) * scale_y
			var is_real_g: bool = _is_real_goal_bp(o)
			if current_tier == TIER_LIGHT:
				# Tier 1 Light Hint: show flags neutrally with observation ring, never spoil which flag is fake!
				draw_circle(Vector2(bx + 5.0, fy + 5.0), 5.0, Color("#fde047"))
				observe_rings.append(Vector2(bx + 5.0, fy + 5.0))
			elif is_real_g:
				real_goal = Vector2(bx + 6.0, fy + 6.0)
				has_goal = true
				if textures.has("star_gold"):
					draw_texture_rect(textures["star_gold"], Rect2(bx - 3.0, fy - 2.0, 14.0, 14.0), false)
				else:
					draw_circle(real_goal, 6.0, Color("#fde047"))
			else:
				draw_line(Vector2(bx, fy), Vector2(bx + 10.0, fy + 10.0), Color("#ff2a85"), 2.2)
				draw_line(Vector2(bx + 10.0, fy), Vector2(bx, fy + 10.0), Color("#ff2a85"), 2.2)
		elif ot in [
			"spikes", "flower", "amanita", "s3_bush", "s3_flower", "s3_ladybug",
			"s3_manju", "s3_mole", "s2_enemy", "enemy", "s3_boss", "s2_boss",
			"enemy_boss", "peace_dove", "s3_sun"
		]:
			var hy: float = h - pad_bot - (oy_g + 0.9) * scale_y
			draw_rect(Rect2(bx, hy, maxf(6.0, bw * 0.8), 5.0), Color(0.96, 0.25, 0.37, 0.78), true)

	var spawn_d: Dictionary = lv_data.get("spawn", { "x": 2.0, "y": 2.0 })
	var start_pt: Vector2 = Vector2(
		pad_x + (float(spawn_d.get("x", 2.0)) - view_start) * scale_x + 5.0,
		h - pad_bot - (float(spawn_d.get("y", 2.0)) + 1.1) * scale_y
	)
	draw_circle(start_pt, 5.5, Color("#00f5ff"))

	# Tier 1 & Tier 2: Pulsing radar observation rings around key puzzle mechanisms
	if current_tier <= TIER_MEDIUM:
		var pulse_r: float = 8.5 + sin(anim_t * 4.4) * 2.5
		var shown_rings: int = 0
		for op in observe_rings:
			if op.x >= 8.0 and op.x <= w - 8.0 and op.y >= 14.0 and op.y <= h - 10.0:
				draw_arc(op, pulse_r, 0.0, TAU, 20, Color(0.99, 0.88, 0.28, 0.62), 1.4)
				shown_rings += 1
				if shown_rings >= 8:
					break

	# Tier 3 Full Hint ONLY: Draw numbered step-by-step ①②③④⑤ route curve to real goal!
	if current_tier == TIER_FULL:
		var route_pts: Array[Vector2] = [start_pt]
		var sol_steps: Variant = lv_data.get("solution_steps", [])
		if typeof(sol_steps) == TYPE_ARRAY and not (sol_steps as Array).is_empty():
			for st_v in (sol_steps as Array):
				if typeof(st_v) == TYPE_DICTIONARY:
					var tgt_u: String = str((st_v as Dictionary).get("target", ""))
					if uuid_screen_map.has(tgt_u):
						var spt: Vector2 = uuid_screen_map[tgt_u]
						if spt.distance_to(route_pts[route_pts.size() - 1]) > 14.0:
							route_pts.append(spt)
							if route_pts.size() >= 6:
								break
		if route_pts.size() <= 1:
			waypoints.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			for wp in waypoints:
				if wp.distance_to(route_pts[route_pts.size() - 1]) > 22.0 and ((real_goal.x >= start_pt.x and wp.x > start_pt.x and wp.x < real_goal.x) or (real_goal.x < start_pt.x and wp.x < start_pt.x and wp.x > real_goal.x)):
					route_pts.append(wp)
					if route_pts.size() >= 6:
						break
		if has_goal and real_goal.distance_to(route_pts[route_pts.size() - 1]) > 10.0:
			route_pts.append(real_goal)

		for ri in range(1, route_pts.size()):
			var p0: Vector2 = route_pts[ri - 1]
			var p1: Vector2 = route_pts[ri]
			var mid: Vector2 = Vector2((p0.x + p1.x) * 0.5, minf(p0.y, p1.y) - 12.0)
			var segs: int = 8
			for si in range(segs):
				var t0: float = float(si) / float(segs)
				var t1: float = float(si + 0.55) / float(segs)
				var q0: Vector2 = p0.lerp(mid, t0).lerp(mid.lerp(p1, t0), t0)
				var q1: Vector2 = p0.lerp(mid, t1).lerp(mid.lerp(p1, t1), t1)
				draw_line(q0, q1, Color("#fde047"), 2.2)

			if font != null and ri - 1 < CIRCLED_NUMS.size():
				var badge_pos: Vector2 = p1 + Vector2(-6.0, -6.0)
				draw_circle(p1, 7.5, Color(0.03, 0.07, 0.22, 0.92))
				draw_arc(p1, 7.5, 0.0, TAU, 16, Color("#fde047"), 1.3)
				draw_string(font, badge_pos + Vector2(0.0, 10.0), CIRCLED_NUMS[ri - 1], HORIZONTAL_ALIGNMENT_CENTER, 13.0, 10, Color("#fde047"))

	# Top-left radar mode header tag
	if font != null:
		var mode_tag: String = "SCAN L1 · OBSERVE TARGETS" if current_tier == TIER_LIGHT else ("SCAN L2 · MECHANISM RULES" if current_tier == TIER_MEDIUM else "SCAN L3 · FULL TACTICAL ROUTE ①②③")
		draw_rect(Rect2(6.0, 4.0, 214.0, 14.0), Color(0.02, 0.05, 0.16, 0.84), true)
		draw_string(font, Vector2(10.0, 14.5), mode_tag, HORIZONTAL_ALIGNMENT_LEFT, 206.0, 9, border_col)

	if total_span > view_span + 1.0:
		var bar_w: float = maxf(36.0, (view_span / total_span) * (w - 24.0))
		var bar_x: float = 12.0 + pan_norm * (w - 24.0 - bar_w)
		draw_rect(Rect2(12.0, h - 7.0, w - 24.0, 4.0), Color(1.0, 1.0, 1.0, 0.12), true)
		draw_rect(Rect2(bar_x, h - 7.0, bar_w, 4.0), border_col, true)
