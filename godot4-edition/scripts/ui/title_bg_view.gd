class_name TitleBgView
extends Control

var textures: Dictionary = {}
var t_sec: float = 0.0
var stars: Array = []
var clouds: Array = []
var embers: Array = []
var traffic: Array = []
var runes: Array = []

func setup(p_textures: Dictionary) -> void:
	textures = p_textures
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_particles()

func _init_particles() -> void:
	stars.clear()
	var palette: Array[Color] = [
		Color("#ffffff"), Color("#00f5ff"), Color("#67e8f9"),
		Color("#ff2ab4"), Color("#c084fc"), Color("#fde047")
	]
	for idx in range(126):
		var is_meteor: bool = idx >= 92
		stars.append({
			"x": float((idx * 89) % 1920) - 480.0,
			"y": float((idx * 47) % 390),
			"vx": -195.0 - float((idx % 5) * 32) if is_meteor else 0.0,
			"vy": 96.0 + float((idx % 4) * 24) if is_meteor else 0.0,
			"sz": 2.2 if (idx % 3 == 0) else 1.5,
			"phase": float(idx) * 0.43,
			"col": palette[idx % palette.size()],
			"meteor": is_meteor
		})

	clouds = [
		{ "key": "cloud_safe", "x": -220.0, "y": 58.0, "w": 112.0, "h": 52.0, "vx": 8.2, "alpha": 0.15 },
		{ "key": "cloud_safe", "x": 80.0, "y": 48.0, "w": 116.0, "h": 54.0, "vx": 9.5, "alpha": 0.17 },
		{ "key": "cloud_safe", "x": 420.0, "y": 76.0, "w": 96.0, "h": 44.0, "vx": 6.8, "alpha": 0.13 },
		{ "key": "cloud_safe", "x": 760.0, "y": 38.0, "w": 124.0, "h": 58.0, "vx": 11.2, "alpha": 0.15 },
		{ "key": "cloud_safe", "x": 1120.0, "y": 62.0, "w": 108.0, "h": 50.0, "vx": 9.0, "alpha": 0.14 }
	]

	embers.clear()
	for i in range(24):
		embers.append({
			"ox": float((i % 9) - 4) * 5.2,
			"y_off": float(i * 4.5),
			"spd": 26.0 + float((i % 5) * 9),
			"sz": 2.0 + float(i % 2)
		})

	traffic.clear()
	for i in range(22):
		var go_r: bool = (i % 2) == 0
		traffic.append({
			"x": float((i * 107) % 1920) - 480.0,
			"y": 292.0 + float((i * 19) % 132),
			"vx": (68.0 + float((i % 4) * 26)) * (1.0 if go_r else -1.0),
			"col": Color("#00f5ff") if go_r else Color("#ff2ab4")
		})

	runes.clear()
	for i in range(16):
		runes.append({
			"x": 540.0 + float((i * 37) % 240),
			"y": 190.0 + float((i * 29) % 210),
			"vy": -14.0 - float((i % 4) * 5.5),
			"ph": float(i) * 0.71,
			"sz": 3.0 + float(i % 3) * 1.2
		})

func step_anim(dt: float) -> void:
	t_sec += dt
	for st_var in stars:
		var st: Dictionary = st_var
		if bool(st["meteor"]):
			st["x"] = float(st["x"]) + float(st["vx"]) * dt
			st["y"] = float(st["y"]) + float(st["vy"]) * dt
			if float(st["x"]) < -480.0 or float(st["y"]) > 410.0:
				st["x"] = 1120.0 + randf() * 320.0
				st["y"] = -20.0 - randf() * 120.0
	for cl_var in clouds:
		var cl: Dictionary = cl_var
		cl["x"] = float(cl["x"]) + float(cl["vx"]) * dt
		if float(cl["x"]) > 1460.0:
			cl["x"] = -480.0 - float(cl["w"])
	for em_var in embers:
		var em: Dictionary = em_var
		em["y_off"] = fposmod(float(em["y_off"]) + float(em["spd"]) * dt, 102.0)
	for tr_var in traffic:
		var tr: Dictionary = tr_var
		var nx: float = float(tr["x"]) + float(tr["vx"]) * dt
		if nx > 1460.0:
			nx = -480.0
		elif nx < -480.0:
			nx = 1460.0
		tr["x"] = nx
	for rn_var in runes:
		var rn: Dictionary = rn_var
		var ny: float = float(rn["y"]) + float(rn["vy"]) * dt
		if ny < 120.0:
			ny = 395.0
		rn["y"] = ny
	queue_redraw()

func _draw() -> void:
	var vw: float = maxf(960.0, size.x)
	var vh: float = maxf(540.0, size.y)
	draw_rect(Rect2(0.0, 0.0, vw, vh), Color("#040824"), true)

	# Lock core key art strictly to 16:9 (960x540) centered at stage_ox while extending 1920x540 ultrawide skyline edge-to-edge
	var scale_y: float = vh / 540.0
	var core_w: float = 960.0 * scale_y
	var stage_ox: float = floorf((vw - core_w) * 0.5)

	if textures.has("title_bg_ultrawide"):
		var uw_tex: Texture2D = textures["title_bg_ultrawide"]
		var uw_w: float = 1920.0 * scale_y
		var uw_x: float = stage_ox - 480.0 * scale_y
		draw_texture_rect(uw_tex, Rect2(uw_x, 0.0, uw_w, vh), false)
	elif textures.has("title_bg_wide"):
		var bg_tex: Texture2D = textures["title_bg_wide"]
		draw_texture_rect(bg_tex, Rect2(stage_ox, 0.0, core_w, vh), false)
	elif textures.has("cyber_skyline_bg_wide"):
		var cy_tex: Texture2D = textures["cyber_skyline_bg_wide"]
		var cy_w: float = 1920.0 * scale_y
		draw_texture_rect(cy_tex, Rect2(stage_ox - 480.0 * scale_y, 0.0, cy_w, vh), false)

	# Full moon atmospheric silver-cyan corona aligned to the moon in title_bg_ultrawide
	var moon_pos: Vector2 = Vector2(stage_ox + 382.0 * scale_y, 108.0 * scale_y)
	var moon_r: float = (58.0 + sin(t_sec * 1.9) * 5.0) * scale_y
	draw_circle(moon_pos, moon_r, Color(0.62, 0.88, 1.0, 0.06))
	draw_circle(moon_pos, moon_r * 0.65, Color(0.86, 0.96, 1.0, 0.08))

	# Cyber skyline searchlight beams
	var beam_xs: Array[float] = [-160.0, 190.0, 470.0, 790.0, 1140.0]
	var beam_cols: Array[Color] = [
		Color(0.0, 0.96, 1.0, 0.045),
		Color(0.0, 0.96, 1.0, 0.055),
		Color(1.0, 0.16, 0.71, 0.05),
		Color(0.75, 0.52, 0.99, 0.05),
		Color(0.0, 0.96, 1.0, 0.045)
	]
	for bi in range(beam_xs.size()):
		var bx: float = stage_ox + beam_xs[bi] * scale_y
		var sway: float = sin(t_sec * (0.55 + float(bi) * 0.14) + float(bi)) * 110.0 * scale_y
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(bx - 12.0 * scale_y, 490.0 * scale_y),
			Vector2(bx + 12.0 * scale_y, 490.0 * scale_y),
			Vector2(bx + sway + 48.0 * scale_y, 20.0 * scale_y),
			Vector2(bx + sway - 48.0 * scale_y, 20.0 * scale_y)
		])
		draw_colored_polygon(pts, beam_cols[bi])

	# Distant cyber traffic light-streams
	for tr_var in traffic:
		var tr: Dictionary = tr_var
		var tx: float = stage_ox + float(tr["x"]) * scale_y
		var ty: float = (float(tr["y"]) + sin(t_sec * 2.4 + float(tr["y"])) * 2.5) * scale_y
		var tc: Color = tr["col"]
		draw_rect(Rect2(tx, ty, 13.0 * scale_y, 2.0 * scale_y), Color(tc.r, tc.g, tc.b, 0.56), true)

	# Twinkling cyber starfield & shooting meteors
	for st_var in stars:
		var st: Dictionary = st_var
		var sx: float = stage_ox + float(st["x"]) * scale_y
		var sy: float = float(st["y"]) * scale_y
		var sc: Color = st["col"]
		if bool(st["meteor"]):
			draw_line(Vector2(sx, sy), Vector2(sx + 36.0 * scale_y, sy - 19.0 * scale_y), Color(sc.r, sc.g, sc.b, 0.44), 2.0 * scale_y)
			draw_rect(Rect2(sx - 1.5, sy - 1.5, 3.0 * scale_y, 3.0 * scale_y), Color.WHITE, true)
		else:
			var tw: float = 0.35 + 0.65 * absf(sin(t_sec * 3.2 + float(st["phase"])))
			var ssz: float = float(st["sz"]) * scale_y
			draw_rect(Rect2(sx, sy, ssz, ssz), Color(sc.r, sc.g, sc.b, tw * 0.85), true)

	# Soft drifting night clouds
	for cl_var in clouds:
		var cl: Dictionary = cl_var
		var ck: String = str(cl["key"])
		if textures.has(ck):
			var cy_bob: float = float(cl["y"]) + sin(t_sec * 1.8 + float(cl["x"]) * 0.01) * 4.0
			draw_texture_rect(
				textures[ck],
				Rect2(stage_ox + float(cl["x"]) * scale_y, cy_bob * scale_y, float(cl["w"]) * scale_y, float(cl["h"]) * scale_y),
				false,
				Color(0.65, 0.78, 1.0, float(cl["alpha"]))
			)

	# Floating arcane cyber-runes drifting around the hooded swordsman's rooftop silhouette
	for rn_var in runes:
		var rn: Dictionary = rn_var
		var rx: float = stage_ox + (float(rn["x"]) + sin(t_sec * 2.1 + float(rn["ph"])) * 10.0) * scale_y
		var ry: float = float(rn["y"]) * scale_y
		var ra: float = 0.20 + 0.38 * absf(sin(t_sec * 2.8 + float(rn["ph"])))
		var rsz: float = float(rn["sz"]) * scale_y
		draw_rect(Rect2(rx, ry, rsz, rsz), Color(0.0, 0.96, 1.0, ra), false, 1.2 * scale_y)

	# Mysterious hooded swordsman's golden alchemy orb pulse, sword glint & rising embers locked at (stage_ox + 608, 242)
	var orb_pos: Vector2 = Vector2(stage_ox + 608.0 * scale_y, 242.0 * scale_y)
	var glow_r: float = (36.0 + sin(t_sec * 4.2) * 8.5) * scale_y
	draw_circle(orb_pos, glow_r, Color(0.98, 0.75, 0.14, 0.16))
	draw_circle(orb_pos, glow_r * 0.58, Color(0.99, 0.94, 0.54, 0.26))
	draw_circle(orb_pos, glow_r * 0.26, Color(1.0, 0.98, 0.84, 0.46))

	# Subtle sword scabbard glint along the hooded warrior's blade
	var glint_t: float = fposmod(t_sec * 0.55, 1.0)
	if glint_t < 0.35:
		var gp: float = glint_t / 0.35
		var p_blade0: Vector2 = Vector2(stage_ox + 626.0 * scale_y, 272.0 * scale_y)
		var p_blade1: Vector2 = Vector2(stage_ox + 694.0 * scale_y, 326.0 * scale_y)
		var g_pt: Vector2 = p_blade0.lerp(p_blade1, gp)
		draw_circle(g_pt, 5.0 * scale_y, Color(0.75, 0.98, 1.0, (1.0 - absf(gp - 0.5) * 2.0) * 0.65))

	for em_var in embers:
		var em: Dictionary = em_var
		var y_off: float = float(em["y_off"])
		var ex: float = orb_pos.x + (float(em["ox"]) + sin(t_sec * 3.0 + float(em["ox"])) * 6.5) * scale_y
		var ey: float = orb_pos.y - y_off * scale_y
		var ea: float = clampf(1.0 - y_off / 102.0, 0.0, 1.0)
		var esz: float = float(em["sz"]) * scale_y
		draw_rect(Rect2(ex, ey, esz, esz), Color(0.99, 0.88, 0.28, ea), true)
