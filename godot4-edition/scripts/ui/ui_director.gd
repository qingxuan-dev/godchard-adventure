class_name UiDirector
extends Control
signal stage_selected(stage_id: int)
signal touch_action(action_name: String, pressed: bool)
var levels: Array = []
var meta: Dictionary = {}
var textures: Dictionary = {}
var cjk_font: FontFile = null
var is_mobile_app: bool = false
var save: SaveManager
var shop: ShopSystem
var engine: StageEngine
var top_bar: ColorRect
var top_right_box: HBoxContainer
var title_panel: Control
var title_bg: TextureRect
var title_center: Control
var hud_label: Label
var touch_root: Control
var dpad_zone: Control
var btn_l_tex: TextureRect
var btn_r_tex: TextureRect
var btn_jump: TextureButton
var btn_shoot: TextureButton
var btn_slash: TextureButton
var btn_bomb: TextureButton
var btn_gold: TextureButton
var btn_layer: TextureButton
var stage_modal: Panel
var settings_modal: Panel
var death_modal: Panel
var death_label: Label
var cg_modal: Panel
var cg_tex_rect: TextureRect
var cg_title_lbl: Label
var cg_cap_lbl: Label
var shop_box: VBoxContainer
var toast_label: Label
var toast_timer: float = 0.0
var active_sector: int = 1
var cg_queue: Array = []
var cg_idx: int = 0
var cg_after_stage: int = 0
var last_vw: float = 0.0
var dpad_dir: int = 0
func setup(p_lv: Array, p_meta: Dictionary, p_tex: Dictionary, p_fnt: FontFile, p_mob: bool, p_save: SaveManager, p_shop: ShopSystem, p_eng: StageEngine) -> void:
	levels = p_lv; meta = p_meta; textures = p_tex; cjk_font = p_fnt; is_mobile_app = p_mob
	save = p_save; shop = p_shop; engine = p_eng
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if cjk_font != null:
		var th: Theme = Theme.new(); th.default_font = cjk_font; th.default_font_size = 15; theme = th
	_build_ui(); _relayout()
	engine.toast_emitted.connect(show_toast)
	engine.stage_cleared.connect(_on_stage_cleared)
	engine.player_died.connect(_on_player_died)
func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0: toast_label.text = ""
	var vw: float = maxf(960.0, get_viewport_rect().size.x)
	if absf(vw - last_vw) > 1.0: _relayout()
	if is_mobile_app and touch_root != null and touch_root.visible and not engine.current_level.is_empty() and not engine.player.is_empty():
		var lid: int = int(engine.current_level.get("id", 1))
		var props: Dictionary = engine.current_level.get("props", {})
		var p: Dictionary = engine.player
		btn_slash.visible = (lid >= 51) or save.magic_sword_unlocked or bool(p.get("sword_up", false))
		btn_bomb.visible = int(p.get("bombs", 0)) > 0
		btn_gold.visible = int(p.get("gold_charges", 0)) > 0 or float(p.get("golden_timer", 0.0)) > 0.0
		btn_layer.visible = bool(props.get("dualLayer", false))
func _build_ui() -> void:
	top_bar = ColorRect.new(); top_bar.color = Color(0.02, 0.05, 0.15, 0.88); top_bar.size = Vector2(960.0, 40.0); add_child(top_bar)
	var c_ico: TextureRect = TextureRect.new(); c_ico.texture = textures.get("ui_coin_hud", null); c_ico.position = Vector2(12.0, 7.0); c_ico.size = Vector2(26.0, 26.0); c_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; add_child(c_ico)
	hud_label = Label.new(); hud_label.position = Vector2(42.0, 9.0); hud_label.clip_text = true; hud_label.add_theme_font_size_override("font_size", 14); add_child(hud_label)
	top_right_box = HBoxContainer.new(); top_right_box.add_theme_constant_override("separation", 6); add_child(top_right_box)
	var b1: Button = Button.new(); b1.text = "重开" if is_mobile_app else "重开 [R]"; b1.custom_minimum_size = Vector2(72.0 if is_mobile_app else 84.0, 30.0); b1.pressed.connect(func() -> void: death_modal.visible = false; engine.reset_attempt()); top_right_box.add_child(b1)
	var bh: Button = Button.new(); bh.text = "提示" if is_mobile_app else "提示 [H]"; bh.custom_minimum_size = Vector2(72.0 if is_mobile_app else 84.0, 30.0); bh.pressed.connect(open_hint_modal); top_right_box.add_child(bh)
	var b2: Button = Button.new(); b2.text = "设置/商城" if is_mobile_app else "设置/商城 [Esc]"; b2.custom_minimum_size = Vector2(102.0 if is_mobile_app else 122.0, 30.0); b2.pressed.connect(toggle_settings_modal); top_right_box.add_child(b2)
	var b3: Button = Button.new(); b3.text = "选关" if is_mobile_app else "选关大厅"; b3.custom_minimum_size = Vector2(72.0 if is_mobile_app else 86.0, 30.0); b3.pressed.connect(func() -> void: _refresh_stage_modal(); stage_modal.visible = not stage_modal.visible); top_right_box.add_child(b3)
	if not is_mobile_app:
		var b4: Button = Button.new(); b4.text = "全屏 [F11]"; b4.custom_minimum_size = Vector2(88.0, 30.0); b4.pressed.connect(toggle_pc_fullscreen); top_right_box.add_child(b4)
	toast_label = Label.new(); toast_label.size = Vector2(620.0, 30.0); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.add_theme_color_override("font_color", Color("#fde047")); add_child(toast_label)
	touch_root = Control.new(); touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; touch_root.visible = false; add_child(touch_root)
	if is_mobile_app: _build_touch_gamepad()
	_build_title_panel(); _build_modals()
func _build_touch_gamepad() -> void:
	dpad_zone = Control.new(); dpad_zone.gui_input.connect(_on_dpad_input); touch_root.add_child(dpad_zone)
	btn_l_tex = TextureRect.new(); btn_l_tex.texture = textures.get("ui_btn_left", null); btn_l_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; btn_l_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE; dpad_zone.add_child(btn_l_tex)
	btn_r_tex = TextureRect.new(); btn_r_tex.texture = textures.get("ui_btn_right", null); btn_r_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; btn_r_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE; dpad_zone.add_child(btn_r_tex)
	btn_jump = _mk_tbtn("ui_btn_jump", "jump", "")
	btn_shoot = _mk_tbtn("ui_btn_bullet", "shoot", "")
	btn_slash = _mk_tbtn("ui_btn_melee", "slash", "")
	btn_bomb = _mk_tbtn("ui_btn_bomb", "bomb", "")
	btn_gold = _mk_tbtn("ui_btn_gold", "gold", "金身")
	btn_layer = _mk_tbtn("ui_btn_layer_touch", "layer", "切层")
func _mk_tbtn(tk: String, act: String, cap: String) -> TextureButton:
	var b: TextureButton = TextureButton.new(); b.ignore_texture_size = true; b.stretch_mode = TextureButton.STRETCH_SCALE; b.texture_normal = textures.get(tk, null)
	b.button_down.connect(func() -> void: touch_action.emit(act, true))
	if cap != "":
		var l: Label = Label.new(); l.text = cap; l.position = Vector2(14.0, 44.0); l.add_theme_font_size_override("font_size", 12); l.add_theme_color_override("font_color", Color("#fef08a")); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(l)
	touch_root.add_child(b); return b
func _on_dpad_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if (ev as InputEventScreenTouch).pressed: _set_dpad((ev as InputEventScreenTouch).position.x)
		else: dpad_dir = 0; touch_action.emit("left", false); touch_action.emit("right", false)
	elif ev is InputEventScreenDrag: _set_dpad((ev as InputEventScreenDrag).position.x)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (ev as InputEventMouseButton).pressed: _set_dpad((ev as InputEventMouseButton).position.x)
		else: dpad_dir = 0; touch_action.emit("left", false); touch_action.emit("right", false)
func _set_dpad(lx: float) -> void:
	var want: int = -1 if lx < dpad_zone.size.x * 0.5 else 1
	if want != dpad_dir: dpad_dir = want; touch_action.emit("left", want < 0); touch_action.emit("right", want > 0)
func _build_title_panel() -> void:
	title_panel = Control.new(); add_child(title_panel)
	title_bg = TextureRect.new(); title_bg.texture = textures.get("title_bg_wide", textures.get("cyber_skyline_bg", null)); title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; title_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; title_panel.add_child(title_bg)
	title_center = Control.new(); title_center.size = Vector2(960.0, 540.0); title_panel.add_child(title_center)
	var logo: TextureRect = TextureRect.new(); logo.texture = textures.get("logo_title", null); logo.position = Vector2(240.0, 28.0); logo.size = Vector2(480.0, 150.0); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; title_center.add_child(logo)
	var ha: TextureRect = TextureRect.new(); ha.texture = textures.get("hero_melee_slash", null); ha.position = Vector2(104.0, 248.0); ha.size = Vector2(168.0, 168.0); ha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ha.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; title_center.add_child(ha)
	var ca: TextureRect = TextureRect.new(); ca.texture = textures.get("cat_nav_smug", null); ca.position = Vector2(692.0, 260.0); ca.size = Vector2(148.0, 148.0); ca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; title_center.add_child(ca)
	var sb: TextureButton = TextureButton.new(); sb.ignore_texture_size = true; sb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED; sb.texture_normal = textures.get("btn_start_zh", null); sb.position = Vector2(325.0, 202.0); sb.size = Vector2(310.0, 74.0)
	sb.pressed.connect(func() -> void: title_panel.visible = false; touch_root.visible = is_mobile_app; stage_selected.emit(save.unlocked_max)); title_center.add_child(sb)
	var hb: Button = Button.new(); hb.text = "★ 关卡选择大厅 (01 - 150)"; hb.position = Vector2(335.0, 288.0); hb.size = Vector2(290.0, 48.0); hb.pressed.connect(func() -> void: _refresh_stage_modal(); stage_modal.visible = true); title_center.add_child(hb)
	var ob: TextureButton = TextureButton.new(); ob.ignore_texture_size = true; ob.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED; ob.texture_normal = textures.get("btn_opts_zh", null); op_connect(ob); title_center.add_child(ob)
	if not is_mobile_app:
		var eb: TextureButton = TextureButton.new(); eb.ignore_texture_size = true; eb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED; eb.texture_normal = textures.get("btn_exit_zh", null); eb.position = Vector2(355.0, 426.0); eb.size = Vector2(250.0, 56.0); eb.pressed.connect(func() -> void: get_tree().quit()); title_center.add_child(eb)
func op_connect(ob: TextureButton) -> void:
	ob.position = Vector2(325.0, 348.0); ob.size = Vector2(310.0, 68.0); ob.pressed.connect(toggle_settings_modal)
func _relayout() -> void:
	var vw: float = maxf(960.0, get_viewport_rect().size.x)
	last_vw = vw; size = Vector2(vw, 540.0); top_bar.size = Vector2(vw, 40.0)
	var tr_w: float = 340.0 if is_mobile_app else 488.0
	top_right_box.position = Vector2(vw - tr_w - 10.0, 5.0); hud_label.size = Vector2(maxf(190.0, vw - tr_w - 56.0), 26.0)
	toast_label.position = Vector2((vw - 620.0) * 0.5, 44.0)
	title_panel.size = Vector2(vw, 540.0); title_bg.size = Vector2(vw, 540.0); title_center.position = Vector2((vw - 960.0) * 0.5, 0.0)
	stage_modal.position = Vector2((vw - 860.0) * 0.5, 44.0); settings_modal.position = Vector2((vw - 840.0) * 0.5, 46.0)
	death_modal.position = Vector2((vw - 480.0) * 0.5, 145.0); cg_modal.position = Vector2((vw - 800.0) * 0.5, 34.0)
	if is_mobile_app:
		var sc: float = clampf(save.pad_scale, 0.75, 1.35)
		touch_root.size = Vector2(vw, 540.0); touch_root.modulate = Color(1, 1, 1, clampf(save.pad_opacity, 0.35, 1.0))
		var dw: float = 212.0 * sc; var dh: float = 90.0 * sc
		dpad_zone.size = Vector2(dw, dh); btn_l_tex.size = Vector2(96.0 * sc, dh); btn_r_tex.position = Vector2(114.0 * sc, 0.0); btn_r_tex.size = Vector2(96.0 * sc, dh)
		var jsz: Vector2 = Vector2(94.0 * sc, 94.0 * sc); var asz: Vector2 = Vector2(74.0 * sc, 74.0 * sc); var ssz: Vector2 = Vector2(66.0 * sc, 66.0 * sc)
		btn_jump.size = jsz; btn_shoot.size = asz; btn_slash.size = asz; btn_bomb.size = ssz; btn_gold.size = ssz; btn_layer.size = ssz
		if not save.pad_swap:
			dpad_zone.position = Vector2(22.0, 540.0 - dh - 18.0); var rx: float = vw - 22.0
			btn_jump.position = Vector2(rx - jsz.x, 540.0 - jsz.y - 16.0); btn_shoot.position = Vector2(rx - jsz.x - asz.x - 14.0, 540.0 - asz.y - 18.0); btn_slash.position = Vector2(rx - jsz.x - asz.x * 2.0 - 26.0, 540.0 - asz.y - 18.0)
			btn_bomb.position = Vector2(rx - ssz.x - 6.0, 540.0 - jsz.y - ssz.y - 26.0); btn_gold.position = Vector2(rx - ssz.x * 2.0 - 18.0, 540.0 - jsz.y - ssz.y - 26.0); btn_layer.position = Vector2(rx - ssz.x * 3.0 - 30.0, 540.0 - jsz.y - ssz.y - 26.0)
		else:
			dpad_zone.position = Vector2(vw - dw - 22.0, 540.0 - dh - 18.0); var lx: float = 22.0
			btn_jump.position = Vector2(lx, 540.0 - jsz.y - 16.0); btn_shoot.position = Vector2(lx + jsz.x + 14.0, 540.0 - asz.y - 18.0); btn_slash.position = Vector2(lx + jsz.x + asz.x + 26.0, 540.0 - asz.y - 18.0)
			btn_bomb.position = Vector2(lx + 6.0, 540.0 - jsz.y - ssz.y - 26.0); btn_gold.position = Vector2(lx + ssz.x + 18.0, 540.0 - jsz.y - ssz.y - 26.0); btn_layer.position = Vector2(lx + ssz.x * 2.0 + 30.0, 540.0 - jsz.y - ssz.y - 26.0)
func toggle_pc_fullscreen() -> void:
	var m: int = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else DisplayServer.WINDOW_MODE_FULLSCREEN)
func toggle_settings_modal() -> void: _refresh_shop_ui(); settings_modal.visible = not settings_modal.visible
func hide_death_modal() -> void: death_modal.visible = false
func open_hint_modal() -> void:
	var steps: Array = engine.current_level.get("hintSteps", [])
	show_toast(str(steps[0]) if steps.size() > 0 else str(engine.current_level.get("subtitle", "")))
func _inject_pad_opts() -> void:
	var row0: HBoxContainer = HBoxContainer.new(); row0.add_theme_constant_override("separation", 8)
	var vb: Button = Button.new(); vb.text = "音量:%d%%" % int(round(save.volume * 100.0)); vb.pressed.connect(func() -> void: save.volume = 0.0 if save.volume > 0.85 else (save.volume + 0.25); save.persist(); _refresh_shop_ui()); row0.add_child(vb)
	if is_mobile_app:
		var scb: Button = Button.new(); scb.text = "按键:%d%%" % int(round(save.pad_scale * 100.0)); scb.pressed.connect(func() -> void: save.pad_scale = 0.8 if save.pad_scale >= 1.25 else (save.pad_scale + 0.15); save.persist(); _relayout(); _refresh_shop_ui()); row0.add_child(scb)
		var opb: Button = Button.new(); opb.text = "透明度:%d%%" % int(round(save.pad_opacity * 100.0)); opb.pressed.connect(func() -> void: save.pad_opacity = 0.45 if save.pad_opacity >= 0.95 else minf(1.0, save.pad_opacity + 0.2); save.persist(); _relayout(); _refresh_shop_ui()); row0.add_child(opb)
		var swb: Button = Button.new(); swb.text = "左手互换:开" if save.pad_swap else "左手互换:关"; swb.pressed.connect(func() -> void: save.pad_swap = not save.pad_swap; save.persist(); _relayout(); _refresh_shop_ui()); row0.add_child(swb)
	else:
		var kl: Label = Label.new(); kl.text = "电脑端：A/D移动 W/Space跳跃 J射击 U魔剑 B炸弹 E切层 G金身 R重开 F11全屏"; row0.add_child(kl)
	shop_box.add_child(row0)
func _build_modals() -> void:
	stage_modal = Panel.new()
	stage_modal.position = Vector2(50, 44)
	stage_modal.size = Vector2(860, 452)
	stage_modal.visible = false
	add_child(stage_modal)

	settings_modal = Panel.new()
	settings_modal.position = Vector2(60, 46)
	settings_modal.size = Vector2(840, 448)
	settings_modal.visible = false
	var opt_head = Label.new()
	opt_head.text = "系统设置 · 炼金神装商城（通关第50关解锁 · 每件道具每关限用1次 · 金身落坑必死）"
	opt_head.position = Vector2(20, 12)
	opt_head.add_theme_color_override("font_color", Color("#fde047"))
	settings_modal.add_child(opt_head)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 46)
	scroll.size = Vector2(800, 386)
	shop_box = VBoxContainer.new()
	shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_box)
	settings_modal.add_child(scroll)

	var close_opt = Button.new()
	close_opt.text = "关闭"
	close_opt.position = Vector2(752, 8)
	close_opt.size = Vector2(72, 30)
	close_opt.pressed.connect(func() -> void: settings_modal.visible = false)
	settings_modal.add_child(close_opt)
	add_child(settings_modal)

	death_modal = Panel.new()
	death_modal.position = Vector2(240, 145)
	death_modal.size = Vector2(480, 240)
	death_modal.visible = false
	death_label = Label.new()
	death_label.position = Vector2(24, 24)
	death_label.size = Vector2(432, 120)
	death_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_modal.add_child(death_label)
	var d_retry = Button.new()
	d_retry.text = "再来一次"
	d_retry.position = Vector2(60, 168)
	d_retry.size = Vector2(160, 44)
	d_retry.pressed.connect(func() -> void:
		death_modal.visible = false
		engine.reset_attempt()
	)
	death_modal.add_child(d_retry)
	var d_hall = Button.new()
	d_hall.text = "选关大厅"
	d_hall.position = Vector2(260, 168)
	d_hall.size = Vector2(160, 44)
	d_hall.pressed.connect(func() -> void:
		death_modal.visible = false
		_refresh_stage_modal()
		stage_modal.visible = true
	)
	death_modal.add_child(d_hall)
	add_child(death_modal)

	cg_modal = Panel.new()
	cg_modal.position = Vector2(80, 34)
	cg_modal.size = Vector2(800, 472)
	cg_modal.visible = false
	cg_tex_rect = TextureRect.new()
	cg_tex_rect.position = Vector2(80, 16)
	cg_tex_rect.size = Vector2(640, 320)
	cg_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cg_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cg_modal.add_child(cg_tex_rect)
	cg_title_lbl = Label.new()
	cg_title_lbl.position = Vector2(30, 344)
	cg_title_lbl.size = Vector2(740, 28)
	cg_title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	cg_modal.add_child(cg_title_lbl)
	cg_cap_lbl = Label.new()
	cg_cap_lbl.position = Vector2(30, 374)
	cg_cap_lbl.size = Vector2(740, 52)
	cg_cap_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cg_modal.add_child(cg_cap_lbl)
	var cg_next = Button.new()
	cg_next.text = "继续下一幕 ▶"
	cg_next.position = Vector2(620, 426)
	cg_next.size = Vector2(150, 36)
	cg_next.pressed.connect(_advance_cg)
	cg_modal.add_child(cg_next)
	add_child(cg_modal)

func _on_player_died(cause: String) -> void:
	var quote = str(engine.current_level.get("trollQuote", "小心反套路陷阱喵！"))
	death_label.text = "★ 阵亡 (%s)\n\n“%s”" % [cause, quote]
	death_modal.visible = true

func _refresh_stage_modal() -> void:
	for c in stage_modal.get_children():
		c.queue_free()
	var labels = ["SECTOR 1 · 常识崩坏 (01-50)", "SECTOR 2 · 根源覆写 (51-100)", "SECTOR 3 · 晴空幻境 (101-150)"]
	for s in [1, 2, 3]:
		var sb = Button.new()
		sb.text = labels[s - 1]
		sb.position = Vector2(16 + (s - 1) * 255, 10)
		sb.size = Vector2(245, 32)
		sb.pressed.connect(func() -> void:
			active_sector = s
			_refresh_stage_modal()
		)
		stage_modal.add_child(sb)

	var close_b = Button.new()
	close_b.text = "关闭"
	close_b.position = Vector2(782, 10)
	close_b.size = Vector2(64, 32)
	close_b.pressed.connect(func() -> void: stage_modal.visible = false)
	stage_modal.add_child(close_b)

	var base_id = (active_sector - 1) * 50 + 1
	for i in range(50):
		var id = base_id + i
		var unlocked = save.is_stage_unlocked(id)
		var b = Button.new()
		b.text = ("%02d" % id) if unlocked else ("[锁]%d" % id)
		b.disabled = not unlocked
		b.position = Vector2(16 + (i % 10) * 83, 56 + int(i / 10) * 76)
		b.size = Vector2(76, 56)
		b.pressed.connect(func() -> void:
			title_panel.visible = false
			touch_root.visible = is_mobile_app
			stage_modal.visible = false
			death_modal.visible = false
			stage_selected.emit(id)
		)
		stage_modal.add_child(b)

func _refresh_shop_ui() -> void:
	for c in shop_box.get_children():
		c.queue_free()
	_inject_pad_opts()
	if not shop.is_unlocked():
		var lbl = Label.new()
		lbl.text = "[锁]实打实通关【第 50 关】后正式开启设置内金币商城！\n届时可用金币购买飞翼、魔剑强化、烈焰弹、穿墙术、炸弹、护盾与不灭金身（100G起，每关限用1次）。"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shop_box.add_child(lbl)
		return

	var wallet = Label.new()
	wallet.text = "★ 持有金币：%d G  （每件道具在单个关卡内严格限用 1 次，重生或关闭不补发）" % save.coins
	wallet.add_theme_color_override("font_color", Color("#fde047"))
	shop_box.add_child(wallet)

	var in_game = not title_panel.visible
	for item in shop.catalog:
		var id = str(item.get("id", ""))
		var row = HBoxContainer.new()
		var owned = bool(save.shop_owned.get(id, false))
		var used = owned and in_game and shop.has_used_in_stage(id)
		var tag = ("[本关已用 1/1]" if used else "[本关可用 1次]") if (owned and in_game) else ""
		var info = Label.new()
		info.text = "%s [%dG] %s — %s" % [str(item.get("zhName", "")), int(item.get("price", 100)), tag, str(item.get("zhDesc", ""))]
		info.custom_minimum_size = Vector2(610, 38)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(145, 36)
		var eq = shop.is_item_equipped(id)
		btn.text = ("购买 %dG" % int(item.get("price", 100))) if not owned else (("已开(本关已用)" if used else "已装备:开") if eq else "已拥有:关")
		btn.pressed.connect(func() -> void:
			var msg = shop.purchase_or_toggle(id, in_game, engine.player)
			show_toast(msg)
			_refresh_shop_ui()
		)
		row.add_child(btn)
		shop_box.add_child(row)

func _get_milestone_cgs(lid: int) -> Array:
	var cgs_dict: Dictionary = meta.get("cgs", {})
	if lid == 50:
		var a: Array = cgs_dict.get("s1FinaleCgs", [])
		var b: Array = cgs_dict.get("s2Post50Cgs", [])
		return a + b
	if lid == 100:
		return cgs_dict.get("s2FinaleCgs", [])
	if lid == 150:
		return cgs_dict.get("s3FinaleCgs", [])
	var ch1: Array = cgs_dict.get("chapterCgs", [])
	var ch3: Array = cgs_dict.get("s3ChapterCgs", [])
	var all_ch: Array = ch1 + ch3
	for item in all_ch:
		if int(item.get("reqLv", -1)) == lid:
			return [item]
	return []

func _on_stage_cleared(lv: Dictionary) -> void:
	var lid = int(lv.get("id", 1))
	save.record_stage_clear(lid, engine.attempt_deaths)
	var seq = _get_milestone_cgs(lid)
	if seq.size() > 0:
		cg_queue = seq
		cg_idx = 0
		cg_after_stage = lid
		_render_cg_slide()
		cg_modal.visible = true
	else:
		show_toast("150关大满贯通关！" if lid == 150 else ("STAGE %d CLEAR!" % lid))
		if lid < 150:
			stage_selected.emit(lid + 1)

func _render_cg_slide() -> void:
	if cg_idx >= cg_queue.size():
		return
	var s: Dictionary = cg_queue[cg_idx]
	var ik = str(s.get("img", ""))
	cg_tex_rect.texture = textures.get(ik, null)
	cg_title_lbl.text = "%s (%d/%d) · %s" % [str(s.get("zhBadge", "CG")), cg_idx + 1, cg_queue.size(), str(s.get("zhEp", ""))]
	cg_cap_lbl.text = str(s.get("zhCap", ""))

func _advance_cg() -> void:
	cg_idx += 1
	if cg_idx >= cg_queue.size():
		cg_modal.visible = false
		if cg_after_stage < 150:
			stage_selected.emit(cg_after_stage + 1)
		else:
			title_panel.visible = true
			touch_root.visible = false
		return
	_render_cg_slide()

func update_hud() -> void:
	if engine.current_level.is_empty():
		return
	var p = engine.player
	var tags: Array[String] = []
	if float(p.get("golden_timer", 0.0)) > 0.0:
		tags.append("金身%.0fs" % float(p["golden_timer"]))
	elif int(p.get("gold_charges", 0)) > 0:
		tags.append("金身待发" if is_mobile_app else "金身[G]")
	if bool(p.get("shield", false)):
		tags.append("护盾")
	if bool(p.get("has_flight", false)):
		tags.append("飞翼")
	if bool(p.get("has_wall_phase", false)):
		tags.append("穿墙")
	if int(p.get("bombs", 0)) > 0:
		tags.append("炸弹×%d" % int(p["bombs"]))
	var buff_str = (" | " + " ".join(PackedStringArray(tags))) if tags.size() > 0 else ""
	hud_label.text = "第 %d 关: %s  |  金币: %dG  |  失误: %d%s" % [
		int(engine.current_level.get("id", 1)),
		str(engine.current_level.get("name", "")),
		save.coins,
		engine.attempt_deaths,
		buff_str
	]

func show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_timer = 2.8
