class_name DebugOverlay
extends Control

var engine: Variant = null
var save: Variant = null
var font_ref: Font = null
var debug_enabled: bool = false
var show_hitboxes: bool = true
var show_vision_cones: bool = true
var show_trap_states: bool = true

func setup(p_engine: Variant, p_save: Variant, p_font: Font) -> void:
	engine = p_engine
	save = p_save
	font_ref = p_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = debug_enabled

func toggle_debug() -> bool:
	debug_enabled = not debug_enabled
	visible = debug_enabled
	queue_redraw()
	return debug_enabled

func _safe_prop(obj: Variant, key: String, fallback: Variant) -> Variant:
	if obj == null:
		return fallback
	if typeof(obj) == TYPE_DICTIONARY:
		var d: Dictionary = obj
		return d.get(key, fallback)
	if typeof(obj) == TYPE_OBJECT:
		var o: Object = obj
		var val: Variant = o.get(key)
		if val != null:
			return val
	return fallback

func _process(_delta: float) -> void:
	if debug_enabled and visible:
		queue_redraw()

func _draw() -> void:
	if not debug_enabled or engine == null:
		return
	var f: Font = font_ref if font_ref != null else ThemeDB.fallback_font
	if f == null:
		return

	var lv_id: int = int(_safe_prop(engine, "lv_id", 1))
	var player: Dictionary = _safe_prop(engine, "player", {})
	var solids: Array = _safe_prop(engine, "solids", [])
	var entities: Array = _safe_prop(engine, "entities", [])
	var cam_x: float = float(_safe_prop(engine, "cam_x", 0.0))
	var cam_y: float = float(_safe_prop(engine, "cam_y", 0.0))
	var active_layer: int = int(_safe_prop(engine, "active_layer", 0))

	var vp: Vector2 = get_viewport_rect().size
	var stage_ox: float = floorf((maxf(960.0, vp.x) - 960.0) * 0.5)
	var stage_oy: float = floorf((maxf(540.0, vp.y) - 540.0) * 0.5)
	var world_off: Vector2 = Vector2(stage_ox - cam_x, stage_oy - cam_y)

	if show_hitboxes:
		for s_var in solids:
			if typeof(s_var) != TYPE_DICTIONARY:
				continue
			var s: Dictionary = s_var
			if bool(s.get("broken", false)):
				continue
			var sr: Rect2 = Rect2(
				world_off.x + float(s.get("x", 0.0)),
				world_off.y + float(s.get("y", 0.0)),
				float(s.get("w", 48.0)),
				float(s.get("h", 48.0))
			)
			if sr.position.x + sr.size.x < stage_ox or sr.position.x > stage_ox + 960.0:
				continue
			draw_rect(sr, Color(0.0, 0.96, 1.0, 0.35), false, 1.0)

		for e_var in entities:
			if typeof(e_var) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = e_var
			if bool(e.get("dead", false)):
				continue
			var er: Rect2 = Rect2(
				world_off.x + float(e.get("x", 0.0)),
				world_off.y + float(e.get("y", 0.0)),
				float(e.get("w", 36.0)),
				float(e.get("h", 36.0))
			)
			if er.position.x + er.size.x < stage_ox - 40.0 or er.position.x > stage_ox + 1000.0:
				continue
			draw_rect(er, Color(0.98, 0.32, 0.45, 0.55), false, 1.0)
			if show_trap_states:
				var st_tag: String = str(e.get("trap_state", e.get("state", e.get("t", ""))))
				draw_string(f, Vector2(er.position.x, er.position.y - 3.0), st_tag, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 9, Color("#fde047"))

		if not player.is_empty():
			var pr: Rect2 = Rect2(
				world_off.x + float(player.get("x", 0.0)),
				world_off.y + float(player.get("y", 0.0)),
				float(player.get("w", 28.0)),
				float(player.get("h", 42.0))
			)
			draw_rect(pr, Color("#4ade80"), false, 2.0)

	var panel_r: Rect2 = Rect2(stage_ox + 12.0, stage_oy + 72.0, 292.0, 118.0)
	draw_rect(panel_r, Color(0.02, 0.04, 0.14, 0.86), true)
	draw_rect(panel_r, Color("#00f5ff"), false, 1.5)

	var px_gx: float = float(player.get("x", 0.0)) / 48.0
	var py_gy: float = (468.0 - (float(player.get("y", 0.0)) + float(player.get("h", 42.0)))) / 48.0
	var vx_v: float = float(player.get("vx", 0.0))
	var vy_v: float = float(player.get("vy", 0.0))
	var sheathed_s: String = "YES" if bool(player.get("sheathed", false)) else "NO"
	var ws: Variant = _safe_prop(engine, "world_state", null)
	var perm_s: String = str(_safe_prop(ws, "root_permission", _safe_prop(engine, "root_permission", "NONE")))

	var lines: Array[String] = [
		"[F3 DEBUG] FPS: %d | LV.%03d | Layer: %d" % [Engine.get_frames_per_second(), lv_id, active_layer],
		"Pos: (%.2f, %.2f) | Vel: (%.0f, %.0f)" % [px_gx, py_gy, vx_v, vy_v],
		"Jumps: %d/%d | Coyote: %.2fs | Sheathe: %s" % [int(player.get("jumps_left", 0)), int(player.get("max_jumps", 1)), float(player.get("coyote", 0.0)), sheathed_s],
		"Solids: %d | Entities: %d | Perm: %s" % [solids.size(), entities.size(), perm_s],
		"Grav: %.1f | Poison: %.1fs | Cure: %.1fs" % [float(player.get("grav_dir", 1.0)), float(player.get("poison_timer", 0.0)), float(player.get("antidote_window", 0.0))]
	]
	for i in range(lines.size()):
		draw_string(f, Vector2(panel_r.position.x + 8.0, panel_r.position.y + 18.0 + float(i) * 20.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 276.0, 11, Color("#67e8f9"))
