class_name UiDirector
extends Control

signal stage_selected(stage_id: int)
signal touch_action(action_name: String, pressed: bool)

var levels: Array = []
var meta: Dictionary = {}
var textures: Dictionary = {}
var save: SaveManager
var shop: ShopSystem
var engine: StageEngine

var title_panel: Panel
var hud_label: Label
var touch_root: Control
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

func setup(p_levels: Array, p_meta: Dictionary, p_tex: Dictionary, p_save: SaveManager, p_shop: ShopSystem, p_engine: StageEngine) -> void:
	levels = p_levels
	meta = p_meta
	textures = p_tex
	save = p_save
	shop = p_shop
	engine = p_engine
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(960, 540)
	_build_ui()

	engine.toast_emitted.connect(show_toast)
	engine.stage_cleared.connect(_on_stage_cleared)
	engine.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.text = ""

func _build_ui() -> void:
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.03, 0.06, 0.16, 0.84)
	top_bar.size = Vector2(960, 38)
	add_child(top_bar)

	hud_label = Label.new()
	hud_label.position = Vector2(12, 7)
	hud_label.add_theme_font_size_override("font_size", 15)
	add_child(hud_label)

	var btn_retry = Button.new()
	btn_retry.text = "重开[R]"
	btn_retry.position = Vector2(648, 4)
	btn_retry.size = Vector2(82, 30)
	btn_retry.pressed.connect(func() -> void:
		death_modal.visible = false
		engine.reset_attempt()
	)
	add_child(btn_retry)

	var btn_settings = Button.new()
	btn_settings.text = "设置 / 商城"
	btn_settings.position = Vector2(736, 4)
	btn_settings.size = Vector2(112, 30)
	btn_settings.pressed.connect(func() -> void:
		_refresh_shop_ui()
		settings_modal.visible = not settings_modal.visible
	)
	add_child(btn_settings)

	var btn_stages = Button.new()
	btn_stages.text = "选关大厅"
	btn_stages.position = Vector2(854, 4)
	btn_stages.size = Vector2(96, 30)
	btn_stages.pressed.connect(func() -> void:
		_refresh_stage_modal()
		stage_modal.visible = not stage_modal.visible
	)
	add_child(btn_stages)

	toast_label = Label.new()
	toast_label.position = Vector2(180, 44)
	toast_label.size = Vector2(600, 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color("#fde047"))
	add_child(toast_label)

	_build_touch_gamepad()
	_build_title_panel()
	_build_modals()

func _build_touch_gamepad() -> void:
	touch_root = Control.new()
	touch_root.size = Vector2(960, 540)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_root.visible = false
	add_child(touch_root)

	_make_hold_btn("◀", Vector2(22, 438), Vector2(82, 78), "left")
	_make_hold_btn("▶", Vector2(118, 438), Vector2(82, 78), "right")
	_make_tap_btn("跳跃", Vector2(846, 438), Vector2(92, 78), "jump")
	_make_tap_btn("射击", Vector2(744, 448), Vector2(88, 68), "shoot")
	_make_tap_btn("挥剑", Vector2(646, 448), Vector2(86, 68), "slash")
	_make_tap_btn("炸弹", Vector2(852, 358), Vector2(84, 66), "bomb")
	_make_tap_btn("金身[G]", Vector2(754, 358), Vector2(86, 66), "gold")
	_make_tap_btn("切层[E]", Vector2(656, 358), Vector2(86, 66), "layer")

func _make_hold_btn(txt: String, pos: Vector2, sz: Vector2, act: String) -> void:
	var b = Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.modulate = Color(1, 1, 1, 0.78)
	b.button_down.connect(func() -> void: touch_action.emit(act, true))
	b.button_up.connect(func() -> void: touch_action.emit(act, false))
	touch_root.add_child(b)

func _make_tap_btn(txt: String, pos: Vector2, sz: Vector2, act: String) -> void:
	var b = Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.modulate = Color(1, 1, 1, 0.78)
	b.button_down.connect(func() -> void: touch_action.emit(act, true))
	touch_root.add_child(b)

func _build_title_panel() -> void:
	title_panel = Panel.new()
	title_panel.size = Vector2(960, 540)
	if textures.has("cyber_skyline_bg"):
		var bg = TextureRect.new()
		bg.texture = textures["cyber_skyline_bg"]
		bg.size = Vector2(960, 540)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_panel.add_child(bg)

	var card = ColorRect.new()
	card.color = Color(0.03, 0.06, 0.18, 0.88)
	card.position = Vector2(210, 110)
	card.size = Vector2(540, 320)
	title_panel.add_child(card)

	var title_lbl = Label.new()
	title_lbl.text = "GODCHARD ADVENTURE\n哥查德的大冒险 · 全150关原生版"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(230, 136)
	title_lbl.size = Vector2(500, 72)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	title_panel.add_child(title_lbl)

	var start_btn = Button.new()
	start_btn.text = "开始冒险 / CONTINUE"
	start_btn.position = Vector2(310, 224)
	start_btn.size = Vector2(340, 48)
	start_btn.pressed.connect(func() -> void:
		title_panel.visible = false
		touch_root.visible = true
		stage_selected.emit(save.unlocked_max)
	)
	title_panel.add_child(start_btn)

	var hall_btn = Button.new()
	hall_btn.text = "关卡选择大厅 (01–150)"
	hall_btn.position = Vector2(310, 284)
	hall_btn.size = Vector2(340, 44)
	hall_btn.pressed.connect(func() -> void:
		_refresh_stage_modal()
		stage_modal.visible = true
	)
	title_panel.add_child(hall_btn)

	var opt_btn = Button.new()
	opt_btn.text = "系统设置 & 专属金币商城"
	opt_btn.position = Vector2(310, 340)
	opt_btn.size = Vector2(340, 44)
	opt_btn.pressed.connect(func() -> void:
		_refresh_shop_ui()
		settings_modal.visible = true
	)
	title_panel.add_child(opt_btn)

	add_child(title_panel)

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
	death_label.text = "💀 阵亡 (%s)\n\n“%s”" % [cause, quote]
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
		b.text = ("%02d" % id) if unlocked else ("🔒%d" % id)
		b.disabled = not unlocked
		b.position = Vector2(16 + (i % 10) * 83, 56 + int(i / 10) * 76)
		b.size = Vector2(76, 56)
		b.pressed.connect(func() -> void:
			title_panel.visible = false
			touch_root.visible = true
			stage_modal.visible = false
			death_modal.visible = false
			stage_selected.emit(id)
		)
		stage_modal.add_child(b)

func _refresh_shop_ui() -> void:
	for c in shop_box.get_children():
		c.queue_free()
	if not shop.is_unlocked():
		var lbl = Label.new()
		lbl.text = "🔒 实打实通关【第 50 关】后正式开启设置内金币商城！\n届时可用金币购买飞翼、魔剑强化、烈焰弹、穿墙术、炸弹、护盾与不灭金身（100G起，每关限用1次）。"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shop_box.add_child(lbl)
		return

	var wallet = Label.new()
	wallet.text = "💰 持有金币：%d G  （每件道具在单个关卡内严格限用 1 次，重生或关闭不补发）" % save.coins
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
		tags.append("金身待发[G]")
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
