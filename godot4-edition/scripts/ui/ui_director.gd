class_name UIDirector
extends Control

signal request_start_stage(stage_id: int)
signal request_retry_stage()
signal request_fresh_restart()
signal request_return_title()
signal request_quit_app()
signal request_toggle_fullscreen()

var save: SaveManager
var shop: ShopSystem
var engine: StageEngine
var audio: ChiptunePlayer
var textures: Dictionary = {}
var meta: Dictionary = {}
var font_main: Font = null
var is_mobile_platform: bool = true

var in_game: bool = false
var standby_mode: bool = false
var active_modal: String = ""

var selected_sector: int = 1
var selected_chapter: int = 1
var options_tab: String = "config"
var ach_filter: String = "all"
var lore_cat: String = "intro"
var reset_confirm_armed: bool = false

var cg_slides: Array = []
var cg_index: int = 0
var cg_after_stage_id: int = 0

var anim_time: float = 0.0
var banner_timer: float = 0.0
var banner_text: String = ""
var banner_color: Color = Color("#00f5ff")

var toast_timer: float = 0.0
var toast_text: String = ""
var toast_icon_key: String = "ui_hint"
var toast_color: Color = Color("#00f5ff")

var ach_toast_timer: float = 0.0
var ach_toast_title: String = ""
var ach_toast_icon: String = "ach_trophy"

# Dynamic Mobile Safe-Area Insets (avoids camera cutout, curved edges, Android back-gesture & status-bar zones)
var safe_left: float = 34.0
var safe_right: float = 34.0
var safe_top: float = 20.0
var safe_bottom: float = 20.0

# Root Views
var title_view: Control
var title_bg_view: TitleBgView
var title_safe_frame: Control
var title_logo_tex: TextureRect
var title_logo_base_y: float = 0.0
var btn_title_lang: Button
var lbl_title_lang: Label
var btn_start_img: TextureButton
var btn_opts_img: TextureButton
var btn_exit_img: TextureButton

var hud_view: Control
var hud_tl_hbox: HBoxContainer
var hud_tr_hbox: HBoxContainer
var btn_hud_grid: Button
var hud_buff_box: HBoxContainer
var hud_chip_pool: Array = []
var last_hud_sig: String = ""
var special_banner_panel: PanelContainer
var special_banner_lbl: Label
var fx_toast_panel: PanelContainer
var fx_toast_icon: TextureRect
var fx_toast_lbl: Label
var ach_toast_panel: PanelContainer
var ach_toast_icon_rect: TextureRect
var ach_toast_lbl: Label
var btn_hud_next: Button
var btn_hud_reset: Button
var btn_hud_hint: Button
var btn_hud_gear: Button

# High-Speed Multi-Touch & Vector Gamepad State (runs cleanly in `_unhandled_input`)
var touch_overlay: Control
var pad_buttons: Array = []
var dpad_left_rect: Rect2 = Rect2()
var dpad_right_rect: Rect2 = Rect2()
var dpad_down_rect: Rect2 = Rect2()
var dpad_zone_rect: Rect2 = Rect2()
var action_zone_rect: Rect2 = Rect2()
var last_pad_sig: String = ""

var touch_roles: Dictionary = {}
var touch_starts: Dictionary = {}
var touch_min_y: Dictionary = {}
var touch_currs: Dictionary = {}
var touch_prev_lr: Dictionary = {}
var swipe_down_hold_timer: float = 0.0

var touch_state: Dictionary = {
	"left": false,
	"right": false,
	"down": false,
	"jump": false,
	"shoot": false,
	"slash": false,
	"bomb": false,
	"layer": false,
	"gold": false
}
var prev_touch_state: Dictionary = {
	"left": false,
	"right": false,
	"down": false,
	"jump": false,
	"shoot": false,
	"slash": false,
	"bomb": false,
	"layer": false,
	"gold": false
}
var mouse_pad_pressed: bool = false
var mouse_pad_role: String = ""
var mouse_pad_start: Vector2 = Vector2.ZERO
var mouse_pad_min_y: float = 0.0
var mouse_pad_pos: Vector2 = Vector2.ZERO

# Single-Channel Subpixel Kinetic Scroll Controller (`SmoothScrollBox` — zero `ScrollContainer` conflict!)
var active_sliders: Array[HSlider] = []
var opt_scroll_clip: Control
var opt_body_vbox: VBoxContainer
var opt_scroll_y: float = 0.0

var hint_scroll_clip: Control
var hint_steps_vbox: VBoxContainer
var hint_scroll_y: float = 0.0

var scroll_pointer_down: bool = false
var scroll_press_pos: Vector2 = Vector2.ZERO
var scroll_last_y: float = 0.0
var scroll_is_dragging: bool = false
var scroll_velocity_y: float = 0.0

var hall_pointer_down: bool = false
var hall_swipe_start: Vector2 = Vector2.ZERO
var hall_swipe_consumed: bool = false

# Exclusive Modal Layer
var modal_backdrop: ColorRect
var hall_panel: PanelContainer
var hall_title_lbl: Label
var hall_prog_lbl: Label
var hall_home_btn: Button
var hall_sector_btns: Array[Button] = []
var hall_chapter_box: HBoxContainer
var hall_sub_lbl: Label
var hall_grid: GridContainer

var options_panel: PanelContainer
var opt_header_lbl: Label
var opt_tab_btns: Dictionary = {}

var death_panel: PanelContainer
var death_banner_rect: TextureRect
var death_cause_lbl: Label
var death_taunt_lbl: Label
var death_stat_lbl: Label
var btn_death_retry: Button
var btn_death_hint: Button
var btn_death_hall: Button

var hint_panel: PanelContainer
var hint_title_lbl: Label
var hint_quote_lbl: Label
var hint_blueprint: HintBlueprintView
var hint_illust_rect: TextureRect
var btn_hint_xray: Button
var btn_hint_resume: Button

var clear_panel: PanelContainer
var clear_title_lbl: Label
var clear_sub_lbl: Label
var clear_stars_box: HBoxContainer
var clear_stats_lbl: Label
var btn_clear_replay: Button
var btn_clear_hall: Button
var btn_clear_next: Button

var cg_panel: PanelContainer
var cg_badge_lbl: Label
var cg_art_rect: TextureRect
var cg_ep_lbl: Label
var cg_cap_lbl: Label
var cg_page_lbl: Label
var btn_cg_prev: Button
var btn_cg_next: Button

var exit_panel: PanelContainer
var exit_title_lbl: Label
var exit_desc_lbl: Label
var btn_exit_standby: Button
var btn_exit_quit: Button
var btn_exit_cancel: Button

var standby_veil: Button

func setup(
	p_save: SaveManager,
	p_shop: ShopSystem,
	p_engine: StageEngine,
	p_audio: ChiptunePlayer,
	p_textures: Dictionary,
	p_meta: Dictionary,
	p_font: Font,
	p_is_mobile: bool
) -> void:
	save = p_save
	shop = p_shop
	engine = p_engine
	audio = p_audio
	textures = p_textures
	meta = p_meta
	font_main = p_font
	is_mobile_platform = p_is_mobile

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_main != null:
		theme = _build_base_theme(font_main)

	_build_title_view()
	_build_hud_view()
	_build_touch_overlay()
	_build_modals()
	_build_standby_veil()

	sync_safe_area_and_layout()
	refresh_language_and_assets()
	show_title_screen()

func _tr(zh_txt: String, en_txt: String) -> String:
	return en_txt if save.lang == "en" else zh_txt

const UI_TEX_ALIASES: Dictionary = {
	"coin_gold": "ui_coin_hud",
	"shield_orb": "icon_shield",
	"icon_wings": "icon_wing",
	"sword_pickup": "icon_sword",
	"bullet_up": "s3_shop_bullet",
	"hud_wall_phase": "s3_shop_phase",
	"clock_item": "clock_gold"
}

func _tex(key: String) -> Texture2D:
	if textures.has(key):
		return textures[key]
	if UI_TEX_ALIASES.has(key) and textures.has(str(UI_TEX_ALIASES[key])):
		return textures[str(UI_TEX_ALIASES[key])]
	return null

# Maps physical Android DisplayServer safe area (cutouts / rounded corners / gesture bars) to UI coordinates
func sync_safe_area_and_layout() -> void:
	var vp_sz: Vector2 = get_viewport_rect().size
	var vw: float = maxf(960.0, vp_sz.x)
	var vh: float = maxf(540.0, vp_sz.y)

	var min_h_pad: float = 34.0 if (is_mobile_platform or vw > 980.0) else 20.0
	var min_top_pad: float = 20.0 if is_mobile_platform else 14.0
	var min_bot_pad: float = 20.0 if is_mobile_platform else 18.0

	var hw_left: float = 0.0
	var hw_right: float = 0.0
	var hw_top: float = 0.0
	var hw_bot: float = 0.0

	var scr_sz: Vector2i = DisplayServer.screen_get_size() if is_mobile_platform else DisplayServer.window_get_size()
	var win_sz: Vector2i = scr_sz if (scr_sz.x > 100 and scr_sz.y > 100) else DisplayServer.window_get_size()
	var safe_r: Rect2i = DisplayServer.get_display_safe_area()
	if win_sz.x > 100 and win_sz.y > 100 and safe_r.size.x > 100 and safe_r.size.y > 100:
		var sx: float = vw / float(win_sz.x)
		var sy: float = vh / float(win_sz.y)
		hw_left = clampf(float(safe_r.position.x) * sx, 0.0, 96.0)
		hw_top = clampf(float(safe_r.position.y) * sy, 0.0, 56.0)
		hw_right = clampf(float(win_sz.x - (safe_r.position.x + safe_r.size.x)) * sx, 0.0, 96.0)
		hw_bot = clampf(float(win_sz.y - (safe_r.position.y + safe_r.size.y)) * sy, 0.0, 48.0)

	safe_left = maxf(min_h_pad, hw_left + 10.0)
	safe_right = maxf(min_h_pad, hw_right + 10.0)
	safe_top = maxf(min_top_pad, hw_top + 6.0)
	safe_bottom = maxf(min_bot_pad, hw_bot + 6.0)

	if hud_tl_hbox != null:
		hud_tl_hbox.position = Vector2(safe_left, safe_top)
	if hud_tr_hbox != null:
		hud_tr_hbox.offset_left = -(safe_right + 286.0)
		hud_tr_hbox.offset_right = -safe_right
		hud_tr_hbox.offset_top = safe_top
		hud_tr_hbox.offset_bottom = safe_top + 52.0

	last_pad_sig = ""
	if touch_overlay != null:
		touch_overlay.queue_redraw()

func _build_base_theme(f: Font) -> Theme:
	var th: Theme = Theme.new()
	th.default_font = f
	th.default_font_size = 15
	var sb_btn: StyleBoxFlat = _make_flat_box(Color("#0c1842"), Color("#00f5ff"), 2, 6, 10, 6)
	var sb_hov: StyleBoxFlat = _make_flat_box(Color("#152a68"), Color("#67e8f9"), 2, 6, 10, 6)
	var sb_prs: StyleBoxFlat = _make_flat_box(Color("#08102c"), Color("#fde047"), 2, 6, 10, 6)
	var sb_dis: StyleBoxFlat = _make_flat_box(Color(0.06, 0.08, 0.16, 0.65), Color(0.35, 0.42, 0.55, 0.45), 1, 6, 10, 6)
	th.set_stylebox("normal", "Button", sb_btn)
	th.set_stylebox("hover", "Button", sb_hov)
	th.set_stylebox("pressed", "Button", sb_prs)
	th.set_stylebox("disabled", "Button", sb_dis)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("#ecfeff"))
	th.set_color("font_hover_color", "Button", Color("#ffffff"))
	th.set_color("font_pressed_color", "Button", Color("#fde047"))
	th.set_color("font_disabled_color", "Button", Color(0.58, 0.64, 0.75, 0.7))
	th.set_color("font_color", "Label", Color("#f1f5f9"))
	return th

func _make_flat_box(bg: Color, border: Color, bw: int = 2, radius: int = 8, pad_h: int = 10, pad_v: int = 6) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb

func _make_icon_slot_button(icon_key: String, sz: float = 50.0, border_col: Color = Color("#00f5ff"), badge_txt: String = "") -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_n: StyleBoxFlat = _make_flat_box(Color(0.03, 0.07, 0.22, 0.94), border_col, 2, 9, 4, 4)
	var sb_h: StyleBoxFlat = _make_flat_box(Color(0.10, 0.20, 0.48, 0.98), Color("#fde047"), 2, 9, 4, 4)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	var tr: TextureRect = TextureRect.new()
	tr.name = "IconRect"
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top_pad: float = 5.0 if badge_txt == "" else 3.0
	var bot_pad: float = 5.0 if badge_txt == "" else 14.0
	tr.offset_left = 6.0
	tr.offset_top = top_pad
	tr.offset_right = -6.0
	tr.offset_bottom = -bot_pad
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _tex(icon_key)
	b.add_child(tr)
	if badge_txt != "":
		var bl: Label = Label.new()
		bl.name = "BadgeLbl"
		bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bl.offset_top = -15.0
		bl.offset_bottom = -2.0
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.add_theme_font_size_override("font_size", 10)
		bl.add_theme_color_override("font_color", border_col.lightened(0.25))
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bl.text = badge_txt
		b.add_child(bl)
	return b

# ==============================================================================
# 1. TITLE SCREEN (Locked 960x540 16:9 UI Frame + Ultrawide Seamless Panorama)
# ==============================================================================
func _build_title_view() -> void:
	title_view = Control.new()
	title_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(title_view)

	title_bg_view = TitleBgView.new()
	title_bg_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_bg_view.setup(textures)
	title_view.add_child(title_bg_view)

	# Strictly locked 960x540 (16:9) centered container so UI never drifts from warrior!
	title_safe_frame = Control.new()
	title_safe_frame.anchor_left = 0.5
	title_safe_frame.anchor_right = 0.5
	title_safe_frame.anchor_top = 0.5
	title_safe_frame.anchor_bottom = 0.5
	title_safe_frame.offset_left = -480.0
	title_safe_frame.offset_right = 480.0
	title_safe_frame.offset_top = -270.0
	title_safe_frame.offset_bottom = 270.0
	title_safe_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_view.add_child(title_safe_frame)

	btn_title_lang = Button.new()
	btn_title_lang.anchor_left = 1.0
	btn_title_lang.anchor_right = 1.0
	btn_title_lang.anchor_top = 0.0
	btn_title_lang.anchor_bottom = 0.0
	btn_title_lang.offset_left = -114.0
	btn_title_lang.offset_right = -18.0
	btn_title_lang.offset_top = 18.0
	btn_title_lang.offset_bottom = 58.0
	btn_title_lang.flat = true
	var lang_bg: TextureRect = TextureRect.new()
	lang_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lang_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lang_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lang_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lang_bg.texture = _tex("btn_frame_cyan")
	btn_title_lang.add_child(lang_bg)
	lbl_title_lang = Label.new()
	lbl_title_lang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_title_lang.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title_lang.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_title_lang.add_theme_font_size_override("font_size", 14)
	lbl_title_lang.add_theme_color_override("font_color", Color("#ecfeff"))
	lbl_title_lang.add_theme_color_override("font_outline_color", Color("#040b24"))
	lbl_title_lang.add_theme_constant_override("outline_size", 4)
	btn_title_lang.add_child(lbl_title_lang)
	btn_title_lang.pressed.connect(func() -> void:
		audio.play_named("coin", 1.08)
		save.lang = "en" if save.lang == "zh" else "zh"
		save.persist()
		refresh_language_and_assets()
	)
	title_safe_frame.add_child(btn_title_lang)

	var left_col: Control = Control.new()
	left_col.position = Vector2(42.0, 92.0)
	left_col.size = Vector2(340.0, 362.0)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_safe_frame.add_child(left_col)

	title_logo_tex = TextureRect.new()
	title_logo_tex.position = Vector2(0.0, 0.0)
	title_logo_tex.size = Vector2(332.0, 114.0)
	title_logo_base_y = 0.0
	title_logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(title_logo_tex)

	var menu_vbox: VBoxContainer = VBoxContainer.new()
	menu_vbox.position = Vector2(54.0, 132.0)
	menu_vbox.size = Vector2(216.0, 208.0)
	menu_vbox.add_theme_constant_override("separation", 12)
	left_col.add_child(menu_vbox)

	btn_start_img = _make_arcade_img_btn("btn_start_zh", Vector2(212.0, 58.0))
	btn_start_img.pressed.connect(func() -> void:
		audio.play_named("coin", 1.05)
		open_level_select_from_title()
	)
	menu_vbox.add_child(btn_start_img)

	btn_opts_img = _make_arcade_img_btn("btn_opts_zh", Vector2(212.0, 58.0))
	btn_opts_img.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		open_options_modal("config")
	)
	menu_vbox.add_child(btn_opts_img)

	btn_exit_img = _make_arcade_img_btn("btn_exit_zh", Vector2(212.0, 58.0))
	btn_exit_img.pressed.connect(func() -> void:
		audio.play_named("block", 0.95)
		open_exit_modal()
	)
	menu_vbox.add_child(btn_exit_img)

func _make_arcade_img_btn(tex_key: String, min_sz: Vector2) -> TextureButton:
	var tb: TextureButton = TextureButton.new()
	tb.custom_minimum_size = min_sz
	tb.ignore_texture_size = true
	tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tb.texture_normal = _tex(tex_key)
	tb.mouse_entered.connect(func() -> void: tb.modulate = Color(1.12, 1.12, 1.15, 1.0))
	tb.mouse_exited.connect(func() -> void: tb.modulate = Color.WHITE)
	tb.button_down.connect(func() -> void: tb.scale = Vector2(0.96, 0.96); tb.pivot_offset = tb.size * 0.5)
	tb.button_up.connect(func() -> void: tb.scale = Vector2.ONE)
	return tb

# ==============================================================================
# 2. SAFE-AREA IN-GAME CORNER HUD (50x50 Buttons, First-Tap Reliable!)
# ==============================================================================
func _build_hud_view() -> void:
	hud_view = Control.new()
	hud_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_view)

	hud_tl_hbox = HBoxContainer.new()
	hud_tl_hbox.position = Vector2(safe_left, safe_top)
	hud_tl_hbox.add_theme_constant_override("separation", 10)
	hud_tl_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_view.add_child(hud_tl_hbox)

	btn_hud_grid = _make_icon_slot_button("ui_grid", 50.0, Color("#00f5ff"), "选关")
	btn_hud_grid.pressed.connect(_on_hud_grid_pressed)
	hud_tl_hbox.add_child(btn_hud_grid)

	hud_buff_box = HBoxContainer.new()
	hud_buff_box.add_theme_constant_override("separation", 6)
	hud_buff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_tl_hbox.add_child(hud_buff_box)

	hud_chip_pool.clear()
	for _i in range(10):
		var pc: PanelContainer = PanelContainer.new()
		pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.visible = false
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr: TextureRect = TextureRect.new()
		tr.custom_minimum_size = Vector2(20.0, 20.0)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
		var lb: Label = Label.new()
		lb.add_theme_font_size_override("font_size", 13)
		lb.add_theme_color_override("font_color", Color("#f8fafc"))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(lb)
		pc.add_child(hb)
		hud_buff_box.add_child(pc)
		hud_chip_pool.append({ "panel": pc, "icon": tr, "label": lb, "border_hex": "" })

	hud_tr_hbox = HBoxContainer.new()
	hud_tr_hbox.anchor_left = 1.0
	hud_tr_hbox.anchor_right = 1.0
	hud_tr_hbox.offset_left = -(safe_right + 286.0)
	hud_tr_hbox.offset_right = -safe_right
	hud_tr_hbox.offset_top = safe_top
	hud_tr_hbox.offset_bottom = safe_top + 52.0
	hud_tr_hbox.alignment = BoxContainer.ALIGNMENT_END
	hud_tr_hbox.add_theme_constant_override("separation", 10)
	hud_tr_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_view.add_child(hud_tr_hbox)

	btn_hud_next = _make_icon_slot_button("ui_next_lv", 50.0, Color("#38bdf8"), "下关")
	btn_hud_next.pressed.connect(_on_hud_next_pressed)
	hud_tr_hbox.add_child(btn_hud_next)

	btn_hud_reset = _make_icon_slot_button("ui_restart", 50.0, Color("#4ade80"), "重开")
	btn_hud_reset.pressed.connect(_on_hud_reset_pressed)
	hud_tr_hbox.add_child(btn_hud_reset)

	btn_hud_hint = _make_icon_slot_button("ui_hint", 50.0, Color("#fde047"), "提示")
	btn_hud_hint.pressed.connect(_on_hud_hint_pressed)
	hud_tr_hbox.add_child(btn_hud_hint)

	btn_hud_gear = _make_icon_slot_button("ui_gear", 50.0, Color("#c084fc"), "设置")
	btn_hud_gear.pressed.connect(_on_hud_gear_pressed)
	hud_tr_hbox.add_child(btn_hud_gear)

	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.anchor_left = 0.5
	center_vbox.anchor_right = 0.5
	center_vbox.offset_left = -220.0
	center_vbox.offset_right = 220.0
	center_vbox.offset_top = 18.0
	center_vbox.offset_bottom = 130.0
	center_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	center_vbox.add_theme_constant_override("separation", 5)
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_view.add_child(center_vbox)

	special_banner_panel = PanelContainer.new()
	special_banner_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	special_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	special_banner_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.03, 0.06, 0.20, 0.88), Color("#00f5ff"), 1, 14, 14, 4))
	special_banner_lbl = Label.new()
	special_banner_lbl.add_theme_font_size_override("font_size", 13)
	special_banner_lbl.add_theme_color_override("font_color", Color("#ecfeff"))
	special_banner_panel.add_child(special_banner_lbl)
	special_banner_panel.visible = false
	center_vbox.add_child(special_banner_panel)

	fx_toast_panel = PanelContainer.new()
	fx_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fx_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_toast_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.04, 0.08, 0.24, 0.92), Color("#fde047"), 2, 14, 12, 4))
	var toast_hb: HBoxContainer = HBoxContainer.new()
	toast_hb.add_theme_constant_override("separation", 6)
	toast_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_toast_icon = TextureRect.new()
	fx_toast_icon.custom_minimum_size = Vector2(18.0, 18.0)
	fx_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_hb.add_child(fx_toast_icon)
	fx_toast_lbl = Label.new()
	fx_toast_lbl.add_theme_font_size_override("font_size", 13)
	toast_hb.add_child(fx_toast_lbl)
	fx_toast_panel.add_child(toast_hb)
	fx_toast_panel.visible = false
	center_vbox.add_child(fx_toast_panel)

	ach_toast_panel = PanelContainer.new()
	ach_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ach_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ach_toast_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.08, 0.05, 0.24, 0.94), Color("#fde047"), 2, 14, 14, 5))
	var ach_hb: HBoxContainer = HBoxContainer.new()
	ach_hb.add_theme_constant_override("separation", 8)
	ach_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ach_toast_icon_rect = TextureRect.new()
	ach_toast_icon_rect.custom_minimum_size = Vector2(20.0, 20.0)
	ach_toast_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ach_toast_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ach_toast_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ach_hb.add_child(ach_toast_icon_rect)
	ach_toast_lbl = Label.new()
	ach_toast_lbl.add_theme_font_size_override("font_size", 13)
	ach_toast_lbl.add_theme_color_override("font_color", Color("#fde047"))
	ach_hb.add_child(ach_toast_lbl)
	ach_toast_panel.add_child(ach_hb)
	ach_toast_panel.visible = false
	center_vbox.add_child(ach_toast_panel)

func _on_hud_grid_pressed() -> void:
	audio.play_named("block", 1.04)
	open_level_select_modal()

func _on_hud_next_pressed() -> void:
	var nxt: int = engine.lv_id + 1
	if nxt <= 150 and save.is_stage_unlocked(nxt):
		audio.play_named("coin", 1.08)
		request_start_stage.emit(nxt)
	else:
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("需先通关当前关卡才能解锁下一关！", "Clear this stage first to unlock the next!"), "ui_next_lv", "#fb7185")

func _on_hud_reset_pressed() -> void:
	audio.play_named("block", 1.08)
	request_retry_stage.emit()

func _on_hud_hint_pressed() -> void:
	if engine.is_hint_unlocked():
		audio.play_named("coin", 1.04)
		open_hint_modal()
	else:
		var cur_d: int = engine.get_max_deaths()
		audio.play_named("fake_buzz", 1.0)
		push_toast(
			_tr("本关失误满 5 次解锁蓝图提示 (%d/5)" % cur_d, "5 fails on this stage unlocks Blueprint (%d/5)" % cur_d),
			"ui_hint",
			"#fde047"
		)

func _on_hud_gear_pressed() -> void:
	audio.play_named("block", 1.0)
	open_options_modal("config")

func refresh_hud() -> void:
	if not in_game or engine.player.is_empty():
		return
	var p: Dictionary = engine.player
	var items: Array = []
	items.append(["coin_gold", str(save.coins), "#fde047"])
	if bool(p.get("shield", false)):
		items.append(["shield_orb", "", "#38bdf8"])
	if float(p.get("golden_timer", 0.0)) > 0.0:
		items.append(["ui_btn_gold", "%.1fs" % float(p["golden_timer"]), "#fde047"])
	elif int(p.get("gold_charges", 0)) > 0:
		items.append(["ui_btn_gold", "x1", "#fde047"])
	if bool(p.get("has_flight", false)):
		items.append(["icon_wings", "", "#67e8f9"])
	if bool(p.get("has_wall_phase", false)):
		items.append(["hud_wall_phase", "", "#c084fc"])
	if engine.is_magic_sword_enabled():
		items.append(["sword_pickup", "+" if bool(p.get("sword_up", false)) else "", "#00f5ff"])
	if bool(p.get("bullet_up", false)):
		items.append(["bullet_up", "", "#fb923c"])
	if int(p.get("bombs", 0)) > 0:
		items.append(["bomb", "x%d" % int(p["bombs"]), "#f43f5e"])
	if engine.is_dual_layer_active():
		items.append(["s2_ui_layer_btn", "B" if engine.active_layer == 1 else "A", "#c084fc" if engine.active_layer == 1 else "#00f5ff"])
	if engine.timer_left >= 0.0:
		items.append(["clock_item", "%.1fs" % maxf(0.0, engine.timer_left), "#fb7185"])

	var sig: String = str(items) + "|" + str(engine.is_hint_unlocked())
	if sig == last_hud_sig:
		return
	last_hud_sig = sig

	for i in range(hud_chip_pool.size()):
		var slot: Dictionary = hud_chip_pool[i]
		var pc: PanelContainer = slot["panel"]
		if i < items.size():
			var spec: Array = items[i]
			var ic_k: String = str(spec[0])
			var tx_s: String = str(spec[1])
			var c_hex: String = str(spec[2])
			(slot["icon"] as TextureRect).texture = _tex(ic_k)
			var lb: Label = slot["label"]
			lb.text = tx_s
			lb.visible = (tx_s != "")
			if str(slot["border_hex"]) != c_hex:
				slot["border_hex"] = c_hex
				pc.add_theme_stylebox_override("panel", _make_flat_box(Color(0.03, 0.07, 0.22, 0.90), Color(c_hex), 1, 8, 8, 4))
			pc.visible = true
		else:
			pc.visible = false

	var hint_icon_rect: TextureRect = btn_hud_hint.get_node_or_null("IconRect") as TextureRect
	if hint_icon_rect != null:
		hint_icon_rect.modulate = Color.WHITE if engine.is_hint_unlocked() else Color(0.65, 0.65, 0.72, 0.78)

# ==============================================================================
# 3. LAYERED INPUT CONTROLLERS:
#    A) `handle_priority_input` (`_input`) -> Single-Channel Modal SmoothScrollBox + Secondary-Finger HUD
#    B) `handle_unhandled_gameplay_input` (`_unhandled_input`) -> Virtual Gamepad + Rolling Swipe-Down
# ==============================================================================
func _build_touch_overlay() -> void:
	touch_overlay = Control.new()
	touch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_overlay.draw.connect(_draw_touch_overlay)
	add_child(touch_overlay)

func is_touch_pad_visible() -> bool:
	if not in_game or active_modal != "" or standby_mode:
		return false
	if save.pad_mode == "hide":
		return false
	if save.pad_mode == "always":
		return true
	return is_mobile_platform

func _ensure_pad_geometry(force: bool = false) -> void:
	if not is_touch_pad_visible() or engine.player.is_empty():
		pad_buttons.clear()
		last_pad_sig = ""
		return

	var vw: float = maxf(960.0, size.x)
	var vh: float = maxf(540.0, size.y)
	var p: Dictionary = engine.player
	var has_sword: bool = engine.is_magic_sword_enabled()
	var has_layer: bool = engine.is_dual_layer_active()
	var b_cnt: int = int(p.get("bombs", 0))
	var g_on: bool = int(p.get("gold_charges", 0)) > 0 or float(p.get("golden_timer", 0.0)) > 0.0
	var g_lbl: String = ("%.0f" % float(p["golden_timer"])) if float(p.get("golden_timer", 0.0)) > 0.0 else "G"
	var l_lbl: String = "B" if engine.active_layer == 1 else "A"
	var sig: String = "%.0f_%.0f_%.0f_%.0f_%.2f_%s_%s_%s_%d_%s_%s_%s" % [
		vw, vh, safe_left, safe_right, save.pad_scale, str(save.pad_swap), str(has_sword), str(has_layer), b_cnt, str(g_on), g_lbl, l_lbl
	]
	if not force and sig == last_pad_sig and not pad_buttons.is_empty():
		return
	last_pad_sig = sig
	pad_buttons.clear()

	var sc: float = clampf(save.pad_scale, 0.70, 1.50)
	var swap: bool = save.pad_swap

	# Harmonized proportional button dimensions (Left/Right/Down share identical 66*sc height!)
	var dpad_w: float = 82.0 * sc
	var dpad_h: float = 62.0 * sc
	var down_sz: float = 62.0 * sc
	var jump_sz: float = 84.0 * sc
	var act_sz: float = 66.0 * sc
	var sub_sz: float = 58.0 * sc
	var pad_l: float = maxf(26.0, safe_left)
	var pad_r: float = maxf(26.0, safe_right)
	var base_y: float = vh - maxf(20.0, safe_bottom)

	var move_on_left: bool = not swap
	var dpad_total_w: float = dpad_w * 2.0 + down_sz + 20.0 * sc
	var left_x0: float = pad_l if move_on_left else (vw - pad_r - dpad_total_w)
	var act_right_edge: float = (vw - pad_r) if move_on_left else (pad_l + jump_sz + act_sz + 28.0 * sc)

	dpad_left_rect = Rect2(left_x0, base_y - dpad_h, dpad_w, dpad_h)
	dpad_right_rect = Rect2(left_x0 + dpad_w + 10.0 * sc, base_y - dpad_h, dpad_w, dpad_h)
	dpad_down_rect = Rect2(left_x0 + dpad_w * 2.0 + 20.0 * sc, base_y - down_sz, down_sz, down_sz)
	dpad_zone_rect = Rect2(left_x0 - 24.0 * sc, base_y - dpad_h - 44.0 * sc, dpad_total_w + 48.0 * sc, dpad_h + 68.0 * sc)

	pad_buttons.append({ "action": "left", "tex": "ui_btn_left", "rect": dpad_left_rect, "label": "", "cluster": "dpad" })
	pad_buttons.append({ "action": "right", "tex": "ui_btn_right", "rect": dpad_right_rect, "label": "", "cluster": "dpad" })
	pad_buttons.append({ "action": "down", "tex": "ui_pipe_down", "rect": dpad_down_rect, "label": "", "cluster": "dpad" })

	var jx: float = act_right_edge - jump_sz
	var jy: float = base_y - jump_sz
	pad_buttons.append({ "action": "jump", "tex": "ui_btn_jump", "rect": Rect2(jx, jy, jump_sz, jump_sz), "label": "", "cluster": "action" })

	var sx: float = jx - act_sz - 12.0 * sc
	var sy: float = base_y - act_sz
	pad_buttons.append({ "action": "shoot", "tex": "ui_btn_bullet", "rect": Rect2(sx, sy, act_sz, act_sz), "label": "", "cluster": "action" })

	if has_sword:
		pad_buttons.append({ "action": "slash", "tex": "ui_btn_melee", "rect": Rect2(sx, sy - act_sz - 10.0 * sc, act_sz, act_sz), "label": "", "cluster": "action" })

	var top_act_x: float = jx + (jump_sz - sub_sz) * 0.5
	var top_act_y: float = jy - sub_sz - 10.0 * sc
	if b_cnt > 0:
		pad_buttons.append({ "action": "bomb", "tex": "ui_btn_bomb", "rect": Rect2(top_act_x, top_act_y, sub_sz, sub_sz), "label": str(b_cnt), "cluster": "action" })
		top_act_y -= (sub_sz + 8.0 * sc)

	if has_layer:
		pad_buttons.append({ "action": "layer", "tex": "s2_ui_layer_btn", "rect": Rect2(top_act_x, top_act_y, sub_sz, sub_sz), "label": l_lbl, "cluster": "action" })
		top_act_y -= (sub_sz + 8.0 * sc)

	if g_on:
		pad_buttons.append({ "action": "gold", "tex": "ui_btn_gold", "rect": Rect2(sx - sub_sz - 10.0 * sc, sy + (act_sz - sub_sz), sub_sz, sub_sz), "label": g_lbl, "cluster": "action" })

	var min_ax: float = sx - sub_sz - 34.0 * sc
	var max_ax: float = act_right_edge + 24.0 * sc
	var min_ay: float = minf(top_act_y, sy - act_sz - 36.0 * sc)
	action_zone_rect = Rect2(min_ax, min_ay, max_ax - min_ax, vh - min_ay)

func _point_hits_any_slider(pt: Vector2) -> bool:
	for sl in active_sliders:
		if is_instance_valid(sl) and sl.is_visible_in_tree():
			if sl.get_global_rect().grow(10.0).has_point(pt):
				return true
	return false

func _point_hits_any_hud_button(pt: Vector2) -> bool:
	var btns: Array = [btn_hud_grid, btn_hud_next, btn_hud_reset, btn_hud_hint, btn_hud_gear]
	for b_var in btns:
		var b: Button = b_var
		if b != null and b.is_visible_in_tree() and b.get_global_rect().grow(10.0).has_point(pt):
			return true
	return false

func _try_secondary_finger_hud_tap(pt: Vector2) -> bool:
	if not in_game or active_modal != "" or standby_mode:
		return false
	var pairs: Array = [
		[btn_hud_grid, Callable(self, "_on_hud_grid_pressed")],
		[btn_hud_next, Callable(self, "_on_hud_next_pressed")],
		[btn_hud_reset, Callable(self, "_on_hud_reset_pressed")],
		[btn_hud_hint, Callable(self, "_on_hud_hint_pressed")],
		[btn_hud_gear, Callable(self, "_on_hud_gear_pressed")]
	]
	for pr in pairs:
		var b: Button = pr[0]
		if b != null and b.is_visible_in_tree() and b.get_global_rect().grow(10.0).has_point(pt):
			var cb: Callable = pr[1]
			cb.call()
			return true
	return false

func _get_active_scroll_pair() -> Array:
	if active_modal == "options" and opt_scroll_clip != null and opt_body_vbox != null:
		return [opt_scroll_clip, opt_body_vbox, true]
	if active_modal == "hint" and hint_scroll_clip != null and hint_steps_vbox != null:
		return [hint_scroll_clip, hint_steps_vbox, false]
	return []

func _get_max_scroll_for(clip: Control, vbox: VBoxContainer) -> float:
	if clip == null or vbox == null:
		return 0.0
	var content_h: float = maxf(vbox.size.y, vbox.get_combined_minimum_size().y)
	var view_h: float = maxf(80.0, clip.size.y)
	return maxf(0.0, content_h - view_h + 18.0)

func _apply_smooth_scroll(is_opt: bool, new_y: float) -> void:
	if is_opt:
		var max_s: float = _get_max_scroll_for(opt_scroll_clip, opt_body_vbox)
		opt_scroll_y = clampf(new_y, 0.0, max_s)
		if opt_body_vbox != null:
			opt_body_vbox.position = Vector2(0.0, -opt_scroll_y)
		if opt_scroll_clip != null:
			opt_scroll_clip.queue_redraw()
	else:
		var max_h: float = _get_max_scroll_for(hint_scroll_clip, hint_steps_vbox)
		hint_scroll_y = clampf(new_y, 0.0, max_h)
		if hint_steps_vbox != null:
			hint_steps_vbox.position = Vector2(0.0, -hint_scroll_y)
		if hint_scroll_clip != null:
			hint_scroll_clip.queue_redraw()

# Priority 1 (`_input`): Unified Single-Channel Modal Scroll + Hall Swipe + Secondary-Finger (`index > 0`) HUD Tap
func handle_priority_input(event: InputEvent) -> bool:
	if standby_mode:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			standby_mode = false
			standby_veil.visible = false
			audio.play_named("coin", 1.06)
			return true
		return false

	if active_modal != "":
		if not touch_currs.is_empty():
			clear_touch_inputs()

		# 1. Hint Blueprint horizontal pan
		if active_modal == "hint" and hint_blueprint != null and hint_blueprint.handle_touch_pan(event):
			return true

		# 2. Single-Channel Subpixel SmoothScrollBox (`InputEventMouse*` covers Mouse Wheel, Mouse Drag, AND Android `emulate_mouse_from_touch`!)
		# Consume duplicate raw `InputEventScreenDrag` during active scroll so nothing double-fires!
		var spair: Array = _get_active_scroll_pair()
		if not spair.is_empty():
			var clip_c: Control = spair[0]
			var is_opt_m: bool = bool(spair[2])
			var cur_sy: float = opt_scroll_y if is_opt_m else hint_scroll_y
			var clip_r: Rect2 = clip_c.get_global_rect()
			if clip_r.size.x < 40.0 or clip_r.size.y < 40.0:
				var vp_f: Vector2 = get_viewport_rect().size
				clip_r = Rect2(Vector2(maxf(960.0, vp_f.x) * 0.5 - 320.0, 96.0), Vector2(640.0, 360.0))

			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if clip_r.has_point(mb.position):
					if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
						scroll_velocity_y = 0.0
						_apply_smooth_scroll(is_opt_m, cur_sy + 48.0)
						return true
					elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
						scroll_velocity_y = 0.0
						_apply_smooth_scroll(is_opt_m, cur_sy - 48.0)
						return true
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						if clip_r.has_point(mb.position) and not _point_hits_any_slider(mb.position):
							scroll_pointer_down = true
							scroll_press_pos = mb.position
							scroll_last_y = mb.position.y
							scroll_is_dragging = false
							scroll_velocity_y = 0.0
							# Do NOT consume press yet so tapping child Buttons (`购买`, `开启`) still arms them!
							return false
					elif scroll_pointer_down:
						var was_dragging: bool = scroll_is_dragging
						scroll_pointer_down = false
						scroll_is_dragging = false
						# Move release outside child Button bounds and let Viewport clear gui.mouse_focus cleanly!
						if was_dragging:
							mb.position = Vector2(-9999.0, -9999.0)
							mb.global_position = Vector2(-9999.0, -9999.0)
						return false
			elif event is InputEventMouseMotion and scroll_pointer_down:
				var mm: InputEventMouseMotion = event as InputEventMouseMotion
				var total_dy: float = mm.position.y - scroll_press_pos.y
				if not scroll_is_dragging and absf(total_dy) > 6.0:
					scroll_is_dragging = true
					var f_own: Control = get_viewport().gui_get_focus_owner()
					if f_own != null:
						f_own.release_focus()
				if scroll_is_dragging:
					var dy_step: float = mm.position.y - scroll_last_y
					scroll_last_y = mm.position.y
					_apply_smooth_scroll(is_opt_m, cur_sy - dy_step)
					scroll_velocity_y = lerpf(scroll_velocity_y, -dy_step * 58.0, 0.55)
					return true
			elif event is InputEventScreenDrag and scroll_is_dragging:
				return true

		# 3. Stage Select Hall Chapter Swipe (`向左/右/上/下划` 顺滑切换章节 CH.1~15)
		if active_modal == "hall" and hall_panel != null and hall_panel.is_visible_in_tree():
			var h_rect: Rect2 = hall_grid.get_global_rect().grow(14.0)
			if event is InputEventMouseButton:
				var mb_h: InputEventMouseButton = event as InputEventMouseButton
				if mb_h.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb_h.pressed and h_rect.has_point(mb_h.position):
					_step_hall_chapter(1)
					return true
				elif mb_h.button_index == MOUSE_BUTTON_WHEEL_UP and mb_h.pressed and h_rect.has_point(mb_h.position):
					_step_hall_chapter(-1)
					return true
				elif mb_h.button_index == MOUSE_BUTTON_LEFT:
					if mb_h.pressed and h_rect.has_point(mb_h.position):
						hall_pointer_down = true
						hall_swipe_start = mb_h.position
						hall_swipe_consumed = false
					elif not mb_h.pressed and hall_pointer_down:
						var sw_done: bool = hall_swipe_consumed
						hall_pointer_down = false
						hall_swipe_consumed = false
						if sw_done:
							mb_h.position = Vector2(-9999.0, -9999.0)
							mb_h.global_position = Vector2(-9999.0, -9999.0)
						return false
			elif event is InputEventMouseMotion and hall_pointer_down and not hall_swipe_consumed:
				var mm_h: InputEventMouseMotion = event as InputEventMouseMotion
				var diff: Vector2 = mm_h.position - hall_swipe_start
				if absf(diff.x) > 46.0 or absf(diff.y) > 46.0:
					var step_ch: int = (-1 if diff.x > 0.0 else 1) if absf(diff.x) >= absf(diff.y) else (-1 if diff.y > 0.0 else 1)
					hall_swipe_consumed = true
					_step_hall_chapter(step_ch)
					return true

		return false

	# Multi-touch secondary finger (`st.index > 0` ONLY!) on top HUD buttons while Finger #0 holds D-pad!
	# (`st.index == 0` is handled natively by Godot's GUI `Button` nodes with zero race!)
	if in_game and event is InputEventScreenTouch:
		var st_sec: InputEventScreenTouch = event as InputEventScreenTouch
		if st_sec.index > 0 and st_sec.pressed and _try_secondary_finger_hud_tap(st_sec.position):
			return true

	return false

# Priority 3 (`_unhandled_input`): Virtual Gamepad + Rolling-Anchor Swipe-Down (`向下划`)
func handle_unhandled_gameplay_input(event: InputEvent) -> bool:
	if not in_game or active_modal != "" or standby_mode:
		return false

	if not is_touch_pad_visible():
		if not touch_currs.is_empty():
			clear_touch_inputs()
		return false

	_ensure_pad_geometry()
	var consumed: bool = false

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			# Never steal touches aimed at top HUD buttons!
			if _point_hits_any_hud_button(st.position):
				return false
			var role: String = _classify_touch_zone(st.position)
			touch_roles[st.index] = role
			touch_starts[st.index] = st.position
			touch_min_y[st.index] = st.position.y
			touch_currs[st.index] = st.position
			consumed = true
			if role != "canvas" and save.vibrate_on and is_mobile_platform:
				Input.vibrate_handheld(10)
		else:
			if touch_currs.has(st.index):
				touch_currs.erase(st.index)
				touch_roles.erase(st.index)
				touch_starts.erase(st.index)
				touch_min_y.erase(st.index)
				touch_prev_lr.erase(st.index)
				consumed = true
		_recompute_touch_actions()
		touch_overlay.queue_redraw()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if not touch_currs.has(sd.index):
			if _point_hits_any_hud_button(sd.position):
				return false
			touch_roles[sd.index] = _classify_touch_zone(sd.position)
			touch_starts[sd.index] = sd.position
			touch_min_y[sd.index] = sd.position.y
		touch_currs[sd.index] = sd.position
		var prev_min: float = float(touch_min_y.get(sd.index, sd.position.y))
		if sd.position.y < prev_min:
			touch_min_y[sd.index] = sd.position.y
		consumed = true
		_recompute_touch_actions()
		touch_overlay.queue_redraw()
	elif save.pad_mode == "always" and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _point_hits_any_hud_button(mb.position):
					return false
				var mrole: String = _classify_touch_zone(mb.position)
				if mrole != "canvas":
					mouse_pad_pressed = true
					mouse_pad_role = mrole
					mouse_pad_start = mb.position
					mouse_pad_min_y = mb.position.y
					mouse_pad_pos = mb.position
					consumed = true
			elif mouse_pad_pressed:
				mouse_pad_pressed = false
				mouse_pad_role = ""
				consumed = true
			_recompute_touch_actions()
			touch_overlay.queue_redraw()
	elif save.pad_mode == "always" and event is InputEventMouseMotion and mouse_pad_pressed:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		mouse_pad_pos = mm.position
		if mm.position.y < mouse_pad_min_y:
			mouse_pad_min_y = mm.position.y
		_recompute_touch_actions()
		touch_overlay.queue_redraw()

	return consumed

func _step_hall_chapter(delta_ch: int) -> void:
	var target_ch: int = clampi(selected_chapter + delta_ch, 1, 15)
	if target_ch == selected_chapter:
		return
	var target_sec: int = clampi(int(ceil(float(target_ch) / 5.0)), 1, 3)
	if target_sec == 2 and not save.is_stage_cleared(50) and not save.is_stage_unlocked(51):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("实打实通关第 50 关后解锁第二板块！", "Clear Stage 50 to unlock Sector 2!"), "ui_grid", "#fb7185")
		return
	if target_sec == 3 and not save.is_stage_cleared(100) and not save.is_stage_unlocked(101):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("通关第 100 关后解锁第三板块！", "Clear Stage 100 to unlock Sector 3!"), "ui_grid", "#fb7185")
		return
	audio.play_named("block", 1.08)
	selected_sector = target_sec
	selected_chapter = target_ch
	_refresh_hall_contents()

func _classify_touch_zone(pt: Vector2) -> String:
	var pad_grow: float = 14.0 * clampf(save.sensitivity, 0.5, 1.5)
	if dpad_zone_rect.grow(pad_grow).has_point(pt):
		return "dpad"
	if action_zone_rect.grow(pad_grow).has_point(pt):
		return "action"
	return "canvas"

func _apply_dpad_finger(idx_key: Variant, cur_p: Vector2, start_p: Vector2, min_y_val: float) -> void:
	var dy_from_peak: float = cur_p.y - min_y_val
	var dy_from_start: float = cur_p.y - start_p.y
	var dy: float = maxf(dy_from_peak, dy_from_start)
	var dx: float = cur_p.x - start_p.x
	var swipe_thresh: float = 14.0 * clampf(1.25 - save.sensitivity * 0.25, 0.60, 1.10)

	# Direct Down / Pipe button hit
	if dpad_down_rect.grow(12.0).has_point(cur_p):
		touch_state["down"] = true
		return

	# Rolling-anchor Swipe-Down gesture (`向下划` 进管 / 下蹲): works even while already holding Left/Right!
	if dy >= swipe_thresh:
		touch_state["down"] = true
		swipe_down_hold_timer = maxf(swipe_down_hold_timer, 0.20)
		if dy_from_start > absf(dx) * 1.05 or dy_from_peak >= swipe_thresh + 4.0:
			return

	# Zero-deadzone horizontal Left <-> Right projection with smooth hysteresis
	var mid_x: float = (dpad_left_rect.get_center().x + dpad_right_rect.get_center().x) * 0.5
	var prev_dir: String = str(touch_prev_lr.get(idx_key, ""))
	var chosen: String = ""
	if cur_p.x < mid_x - 4.0:
		chosen = "left"
	elif cur_p.x > mid_x + 4.0:
		chosen = "right"
	elif prev_dir != "":
		chosen = prev_dir
	else:
		chosen = "left" if cur_p.x < mid_x else "right"
	touch_prev_lr[idx_key] = chosen
	touch_state[chosen] = true

func _apply_action_finger(pt: Vector2) -> void:
	var pad_grow: float = 16.0 * clampf(save.sensitivity, 0.5, 1.5)
	var best_act: String = ""
	var best_dist: float = 999999.0
	for b_var in pad_buttons:
		var b: Dictionary = b_var
		if str(b.get("cluster", "")) != "action":
			continue
		var r: Rect2 = b["rect"]
		if r.grow(pad_grow).has_point(pt):
			var d: float = pt.distance_to(r.get_center())
			if d < best_dist:
				best_dist = d
				best_act = str(b["action"])
	if best_act != "":
		touch_state[best_act] = true

func _recompute_touch_actions() -> void:
	for k in touch_state.keys():
		touch_state[k] = false
	if swipe_down_hold_timer > 0.0:
		touch_state["down"] = true

	for idx_k in touch_currs.keys():
		var role: String = str(touch_roles.get(idx_k, "canvas"))
		var cur_p: Vector2 = touch_currs[idx_k]
		var start_p: Vector2 = touch_starts.get(idx_k, cur_p)
		var min_yv: float = float(touch_min_y.get(idx_k, start_p.y))
		if role == "dpad":
			_apply_dpad_finger(idx_k, cur_p, start_p, min_yv)
		elif role == "action":
			var dy_a: float = cur_p.y - min_yv
			var dx_a: float = cur_p.x - start_p.x
			if dy_a >= 24.0 and dy_a > absf(dx_a) * 1.25 and not _point_hits_action_btn(cur_p):
				touch_state["down"] = true
				swipe_down_hold_timer = maxf(swipe_down_hold_timer, 0.20)
			else:
				_apply_action_finger(cur_p)
		else:
			# Open-canvas swipe-down anywhere on screen -> instant pipe entry / crouch!
			var dy_c: float = cur_p.y - min_yv
			var dx_c: float = cur_p.x - start_p.x
			if dy_c >= 18.0 and dy_c > absf(dx_c) * 1.10:
				touch_state["down"] = true
				swipe_down_hold_timer = maxf(swipe_down_hold_timer, 0.24)

	if mouse_pad_pressed:
		if mouse_pad_role == "dpad":
			_apply_dpad_finger("mouse", mouse_pad_pos, mouse_pad_start, mouse_pad_min_y)
		elif mouse_pad_role == "action":
			_apply_action_finger(mouse_pad_pos)

func _point_hits_action_btn(pt: Vector2) -> bool:
	for b_var in pad_buttons:
		var b: Dictionary = b_var
		if str(b.get("cluster", "")) == "action" and (b["rect"] as Rect2).grow(8.0).has_point(pt):
			return true
	return false

func clear_touch_inputs() -> void:
	touch_roles.clear()
	touch_starts.clear()
	touch_min_y.clear()
	touch_currs.clear()
	touch_prev_lr.clear()
	swipe_down_hold_timer = 0.0
	mouse_pad_pressed = false
	mouse_pad_role = ""
	for k in touch_state.keys():
		touch_state[k] = false
		prev_touch_state[k] = false
	if touch_overlay != null:
		touch_overlay.queue_redraw()

func consume_touch_edges() -> Dictionary:
	var out: Dictionary = {
		"left": bool(touch_state["left"]),
		"right": bool(touch_state["right"]),
		"down": bool(touch_state["down"]),
		"down_pressed": bool(touch_state["down"]) and not bool(prev_touch_state["down"]),
		"jump_held": bool(touch_state["jump"]),
		"jump_pressed": bool(touch_state["jump"]) and not bool(prev_touch_state["jump"]),
		"jump_released": (not bool(touch_state["jump"])) and bool(prev_touch_state["jump"]),
		"shoot_pressed": bool(touch_state["shoot"]) and not bool(prev_touch_state["shoot"]),
		"slash_pressed": bool(touch_state["slash"]) and not bool(prev_touch_state["slash"]),
		"bomb_pressed": bool(touch_state["bomb"]) and not bool(prev_touch_state["bomb"]),
		"layer_pressed": bool(touch_state["layer"]) and not bool(prev_touch_state["layer"]),
		"gold_pressed": bool(touch_state["gold"]) and not bool(prev_touch_state["gold"])
	}
	for k in touch_state.keys():
		prev_touch_state[k] = touch_state[k]
	return out

func _draw_touch_overlay() -> void:
	if not is_touch_pad_visible():
		return
	_ensure_pad_geometry()
	var alpha_base: float = clampf(save.pad_opacity, 0.25, 1.0)
	for b_var in pad_buttons:
		var b: Dictionary = b_var
		var act: String = str(b["action"])
		var r: Rect2 = b["rect"]
		var pressed_now: bool = bool(touch_state.get(act, false))
		var draw_r: Rect2 = r.grow(-2.0) if pressed_now else r
		touch_overlay.draw_rect(draw_r.grow(-2.0), Color(0.03, 0.06, 0.18, alpha_base * 0.92), true)
		var tint: Color = Color(1.22, 1.22, 1.05, 1.0) if pressed_now else Color(1.0, 1.0, 1.0, alpha_base)
		var tex: Texture2D = _tex(str(b["tex"]))
		if tex != null:
			touch_overlay.draw_texture_rect(tex, draw_r, false, tint)
		else:
			touch_overlay.draw_rect(draw_r, Color(0.05, 0.12, 0.32, alpha_base), true)
			touch_overlay.draw_rect(draw_r, Color("#00f5ff"), false, 2.0)
		if pressed_now:
			touch_overlay.draw_rect(draw_r, Color(0.0, 0.96, 1.0, 0.85), false, 2.0)
		var lbl_s: String = str(b.get("label", ""))
		if lbl_s != "" and font_main != null:
			touch_overlay.draw_string(
				font_main,
				Vector2(draw_r.position.x + draw_r.size.x - 16.0, draw_r.position.y + draw_r.size.y - 6.0),
				lbl_s,
				HORIZONTAL_ALIGNMENT_RIGHT,
				-1.0,
				13,
				Color("#fde047")
			)

# ==============================================================================
# 4. EXCLUSIVE MODALS (Locked 16:9 Proportions + Single-Channel SmoothScrollBox)
# ==============================================================================
func _build_modals() -> void:
	modal_backdrop = ColorRect.new()
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.color = Color(0.01, 0.02, 0.09, 0.90)
	modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_backdrop.visible = false
	add_child(modal_backdrop)

	_build_hall_modal()
	_build_options_modal()
	_build_death_modal()
	_build_hint_modal()
	_build_clear_modal()
	_build_cg_modal()
	_build_exit_modal()

func _center_card(w: float, h: float, border_col: Color) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 0.5
	pc.anchor_bottom = 0.5
	pc.offset_left = -w * 0.5
	pc.offset_right = w * 0.5
	pc.offset_top = -h * 0.5
	pc.offset_bottom = h * 0.5
	pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#060c28"), border_col, 2, 12, 16, 14))
	pc.visible = false
	modal_backdrop.add_child(pc)
	return pc

func _draw_custom_scrollbar(clip: Control, vbox: VBoxContainer, cur_y: float, bar_col: Color) -> void:
	if clip == null or vbox == null:
		return
	var max_s: float = _get_max_scroll_for(clip, vbox)
	if max_s <= 2.0:
		return
	var view_h: float = maxf(60.0, clip.size.y)
	var content_h: float = view_h + max_s
	var track_x: float = clip.size.x - 6.0
	clip.draw_rect(Rect2(track_x, 2.0, 4.0, view_h - 4.0), Color(0.08, 0.14, 0.30, 0.65), true)
	var thumb_h: float = clampf((view_h / content_h) * (view_h - 4.0), 26.0, view_h - 8.0)
	var ratio: float = clampf(cur_y / max_s, 0.0, 1.0)
	var thumb_y: float = 2.0 + ratio * (view_h - 4.0 - thumb_h)
	clip.draw_rect(Rect2(track_x, thumb_y, 4.0, thumb_h), bar_col, true)

# --- 4A. STAGE SELECT HALL (3 Sectors + CH.1~15 + 5x2 `ui_level_plate` Cards) ---
func _build_hall_modal() -> void:
	hall_panel = _center_card(868.0, 486.0, Color("#00f5ff"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	hall_panel.add_child(vb)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	vb.add_child(hdr)

	var grid_ic: TextureRect = TextureRect.new()
	grid_ic.custom_minimum_size = Vector2(26.0, 26.0)
	grid_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grid_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	grid_ic.texture = _tex("ui_grid")
	hdr.add_child(grid_ic)

	hall_title_lbl = Label.new()
	hall_title_lbl.add_theme_font_size_override("font_size", 20)
	hall_title_lbl.add_theme_color_override("font_color", Color("#ecfeff"))
	hdr.add_child(hall_title_lbl)

	var prog_pill: PanelContainer = PanelContainer.new()
	prog_pill.add_theme_stylebox_override("panel", _make_flat_box(Color("#052e26"), Color("#4ade80"), 1, 12, 10, 2))
	hall_prog_lbl = Label.new()
	hall_prog_lbl.add_theme_font_size_override("font_size", 13)
	hall_prog_lbl.add_theme_color_override("font_color", Color("#4ade80"))
	prog_pill.add_child(hall_prog_lbl)
	hdr.add_child(prog_pill)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	hall_home_btn = Button.new()
	hall_home_btn.custom_minimum_size = Vector2(82.0, 38.0)
	hall_home_btn.pressed.connect(func() -> void:
		audio.play_named("block", 1.0)
		close_all_modals(false)
		request_return_title.emit()
	)
	hdr.add_child(hall_home_btn)

	var close_b: Button = _make_icon_slot_button("ui_btn_x", 38.0, Color("#fb7185"))
	close_b.pressed.connect(func() -> void:
		audio.play_named("block", 0.96)
		_close_hall_or_return()
	)
	hdr.add_child(close_b)

	var sec_row: HBoxContainer = HBoxContainer.new()
	sec_row.add_theme_constant_override("separation", 8)
	vb.add_child(sec_row)
	hall_sector_btns.clear()
	for s_idx in range(1, 4):
		var sb: Button = Button.new()
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size = Vector2(0.0, 34.0)
		var captured_s: int = s_idx
		sb.pressed.connect(func() -> void: _on_select_sector(captured_s))
		sec_row.add_child(sb)
		hall_sector_btns.append(sb)

	hall_chapter_box = HBoxContainer.new()
	hall_chapter_box.add_theme_constant_override("separation", 8)
	vb.add_child(hall_chapter_box)

	hall_sub_lbl = Label.new()
	hall_sub_lbl.add_theme_font_size_override("font_size", 12)
	hall_sub_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vb.add_child(hall_sub_lbl)

	hall_grid = GridContainer.new()
	hall_grid.columns = 5
	hall_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hall_grid.add_theme_constant_override("h_separation", 10)
	hall_grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(hall_grid)

func _on_select_sector(sec: int) -> void:
	if sec == 2 and not save.is_stage_cleared(50) and not save.is_stage_unlocked(51):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("实打实通关第 50 关后解锁第二板块！", "Clear Stage 50 to unlock Sector 2!"), "ui_grid", "#fb7185")
		return
	if sec == 3 and not save.is_stage_cleared(100) and not save.is_stage_unlocked(101):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("通关第 100 关后解锁第三板块「晴空幻境」！", "Clear Stage 100 to unlock Sector 3 Sunlit Arcadia!"), "ui_grid", "#fb7185")
		return
	audio.play_named("coin", 1.06)
	selected_sector = sec
	var front_lv: int = save.get_highest_frontier_level(sec)
	selected_chapter = clampi(int(ceil(float(front_lv) / 10.0)), (sec - 1) * 5 + 1, sec * 5)
	_refresh_hall_contents()

func _refresh_hall_contents() -> void:
	hall_title_lbl.text = _tr("选择关卡", "STAGE SELECT")
	hall_prog_lbl.text = "%d / 150" % save.get_cleared_count(150)
	hall_home_btn.text = _tr("主页", "HOME")
	hall_home_btn.visible = in_game

	var sec_titles_zh: Array[String] = [
		"SECTOR 1 · 常识崩坏 (01–50)",
		"SECTOR 2 · 根源覆写 (51–100)",
		"SECTOR 3 · 晴空幻境 (101–150)"
	]
	var sec_titles_en: Array[String] = [
		"SECTOR 1 · LOGIC BREAK (01–50)",
		"SECTOR 2 · ROOT OVERWRITE (51–100)",
		"SECTOR 3 · SUNLIT ARCADIA (101–150)"
	]
	var sec_cols: Array[Color] = [Color("#00f5ff"), Color("#c084fc"), Color("#38bdf8")]

	for i in range(3):
		var s_num: int = i + 1
		var btn: Button = hall_sector_btns[i]
		var locked_sec: bool = (s_num == 2 and not save.is_stage_cleared(50) and not save.is_stage_unlocked(51)) or (s_num == 3 and not save.is_stage_cleared(100) and not save.is_stage_unlocked(101))
		var prefix: String = "[锁] " if locked_sec else ""
		btn.text = prefix + (sec_titles_en[i] if save.lang == "en" else sec_titles_zh[i])
		var active_s: bool = (selected_sector == s_num)
		var col: Color = sec_cols[i]
		btn.add_theme_stylebox_override(
			"normal",
			_make_flat_box(Color(col.r * 0.22, col.g * 0.22, col.b * 0.30, 0.95) if active_s else Color("#0a1334"), col if active_s else Color(0.25, 0.35, 0.55, 0.65), 2 if active_s else 1, 8, 8, 4)
		)

	for ch_old in hall_chapter_box.get_children():
		ch_old.queue_free()

	var ch_start: int = (selected_sector - 1) * 5 + 1
	for ch_i in range(ch_start, ch_start + 5):
		var cb: Button = Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0.0, 30.0)
		var lv_a: int = (ch_i - 1) * 10 + 1
		var lv_b: int = ch_i * 10
		var ch_locked: bool = not save.is_stage_unlocked(lv_a)
		cb.text = ("%sCH.%d (%02d–%02d)" % ["[锁] " if ch_locked else "", ch_i, lv_a, lv_b])
		var is_cur_ch: bool = (ch_i == selected_chapter)
		var c_col: Color = sec_cols[selected_sector - 1]
		cb.add_theme_stylebox_override(
			"normal",
			_make_flat_box(Color("#162c64") if is_cur_ch else Color("#09112c"), c_col if is_cur_ch else Color(0.22, 0.30, 0.48, 0.55), 2 if is_cur_ch else 1, 6, 6, 3)
		)
		var cap_ch: int = ch_i
		cb.pressed.connect(func() -> void:
			audio.play_named("block", 1.08)
			selected_chapter = cap_ch
			_refresh_hall_contents()
		)
		hall_chapter_box.add_child(cb)

	var ch_names_zh: Dictionary = {
		1: "第一章 · 反转迷城 (01–10)", 2: "第二章 · 剧毒炼金工坊 (11–20)", 3: "第三章 · 失重发条要塞 (21–30)",
		4: "第四章 · 时空悖论回廊 (31–40)", 5: "第五章 · 破晓终焉试炼 (41–50)", 6: "第六章 · 信号死区 (51–60)",
		7: "第七章 · 机甲重工坟场 (61–70)", 8: "第八章 · 维度裂隙双生层 (71–80)", 9: "第九章 · 逆时发条圣殿 (81–90)",
		10: "第十章 · ROOT/00 根源核心 (91–100)", 11: "第十一章 · 微风花田的善意谎言 (101–110)",
		12: "第十二章 · 云端绵羊与藏刀草甸 (111–120)", 13: "第十三章 · 水管迷森与伪装旗阵 (121–130)",
		14: "第十四章 · 日晷逆风车与暴走太阳 (131–140)", 15: "第十五章 · 晴空幻境终极圣殿 (141–150)"
	}
	var ch_names_en: Dictionary = {
		1: "CH.1 · Reversal Maze (01–10)", 2: "CH.2 · Toxic Alchemy Foundry (11–20)", 3: "CH.3 · Zero-G Citadel (21–30)",
		4: "CH.4 · Chrono Paradox Gallery (31–40)", 5: "CH.5 · Dawn Gauntlet (41–50)", 6: "CH.6 · Signal Deadzone (51–60)",
		7: "CH.7 · Mecha Graveyard (61–70)", 8: "CH.8 · Dual-Layer Fracture (71–80)", 9: "CH.9 · Chrono Cathedral (81–90)",
		10: "CH.10 · ROOT/00 Core (91–100)", 11: "CH.11 · Sunlit Meadow Lies (101–110)",
		12: "CH.12 · Dagger Clouds & Pastures (111–120)", 13: "CH.13 · Pipe Woods & Mimic Flags (121–130)",
		14: "CH.14 · Sundial Windmills & Angry Sun (131–140)", 15: "CH.15 · Grand Sky Sanctuary (141–150)"
	}
	var base_sub: String = str(ch_names_en.get(selected_chapter, "") if save.lang == "en" else ch_names_zh.get(selected_chapter, ""))
	hall_sub_lbl.text = base_sub + _tr("   ·  左右或上下滑动可快速翻页", "   ·  Swipe to switch chapters")

	for old_c in hall_grid.get_children():
		old_c.queue_free()

	var first_lv: int = (selected_chapter - 1) * 10 + 1
	var frontier_lv: int = save.get_highest_frontier_level(0)
	for lv_num in range(first_lv, first_lv + 10):
		hall_grid.add_child(_build_cyber_stage_card(lv_num, lv_num == frontier_lv))

func _build_cyber_stage_card(lv_num: int, is_frontier: bool) -> Control:
	var unlocked: bool = save.is_stage_unlocked(lv_num)
	var cleared_lv: bool = save.is_stage_cleared(lv_num)
	var stars_cnt: int = int(save.best_stars.get(str(lv_num), 0))
	var lv_info: Dictionary = engine.levels_by_id.get(lv_num, {})
	var st_name: String = str(lv_info.get("nameEn" if save.lang == "en" else "name", ""))

	var btn: Button = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(154.0, 120.0)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	var border_c: Color = Color("#fde047") if is_frontier else (Color("#4ade80") if cleared_lv else (Color("#00f5ff") if unlocked else Color(0.25, 0.32, 0.46, 0.45)))
	btn.add_theme_stylebox_override("normal", _make_flat_box(Color(0.03, 0.06, 0.18, 0.72), border_c, 2 if (is_frontier or cleared_lv) else 1, 8, 4, 4))
	btn.add_theme_stylebox_override("hover", _make_flat_box(Color(0.08, 0.16, 0.38, 0.88), Color("#fde047"), 2, 8, 4, 4))

	var plate: TextureRect = TextureRect.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.offset_left = 3.0
	plate.offset_top = 3.0
	plate.offset_right = -3.0
	plate.offset_bottom = -3.0
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture = _tex("ui_level_plate")
	plate.modulate = Color.WHITE if unlocked else Color(0.42, 0.46, 0.58, 0.90)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(plate)

	if cleared_lv:
		var chk: TextureRect = TextureRect.new()
		chk.anchor_left = 1.0
		chk.anchor_right = 1.0
		chk.offset_left = -24.0
		chk.offset_right = -8.0
		chk.offset_top = 7.0
		chk.offset_bottom = 23.0
		chk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chk.texture = _tex("ui_btn_check")
		chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(chk)

	var inner_vb: VBoxContainer = VBoxContainer.new()
	inner_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_vb.offset_left = 8.0
	inner_vb.offset_right = -8.0
	inner_vb.offset_top = 10.0
	inner_vb.offset_bottom = -8.0
	inner_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vb.add_theme_constant_override("separation", 3)
	inner_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner_vb)

	var num_lbl: Label = Label.new()
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.text = ("%02d" % lv_num) if unlocked else ("[锁] %02d" % lv_num)
	num_lbl.add_theme_font_size_override("font_size", 24 if unlocked else 19)
	num_lbl.add_theme_color_override("font_color", Color("#fde047") if is_frontier else (Color("#ecfeff") if unlocked else Color("#64748b")))
	num_lbl.add_theme_color_override("font_outline_color", Color("#020617"))
	num_lbl.add_theme_constant_override("outline_size", 4)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vb.add_child(num_lbl)

	var name_lbl: Label = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text = st_name if unlocked else _tr("未解锁", "LOCKED")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color("#cbd5e1") if unlocked else Color("#475569"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vb.add_child(name_lbl)

	var stars_hb: HBoxContainer = HBoxContainer.new()
	stars_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hb.add_theme_constant_override("separation", 3)
	stars_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for si in range(5):
		var sr: TextureRect = TextureRect.new()
		sr.custom_minimum_size = Vector2(15.0, 15.0)
		sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sr.texture = _tex("star_gold" if (cleared_lv and si < stars_cnt) else "star_empty")
		sr.modulate = Color.WHITE if unlocked else Color(0.45, 0.50, 0.62, 0.65)
		sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_hb.add_child(sr)
	inner_vb.add_child(stars_hb)

	btn.pressed.connect(func() -> void:
		if hall_swipe_consumed:
			return
		if not save.is_stage_unlocked(lv_num):
			audio.play_named("fake_buzz", 1.0)
			push_toast(_tr("请按顺序通关前置关卡解锁第 %02d 关！" % lv_num, "Clear previous stages first to unlock Stage %02d!" % lv_num), "ui_grid", "#fb7185")
			return
		audio.play_named("coin", 1.1)
		close_all_modals(false)
		request_start_stage.emit(lv_num)
	)
	return btn

func _close_hall_or_return() -> void:
	if in_game and not engine.player.is_empty() and bool(engine.player.get("dead", false)):
		open_death_modal(engine.pending_death_cause if engine.pending_death_cause != "" else "general")
	else:
		close_all_modals(true)

# --- 4B. SYSTEM TERMINAL MODAL (4 Tabs + Single-Channel Subpixel `SmoothScrollBox`!) ---
func _build_options_modal() -> void:
	options_panel = _center_card(828.0, 476.0, Color("#c084fc"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	options_panel.add_child(vb)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	vb.add_child(hdr)

	var gear_ic: TextureRect = TextureRect.new()
	gear_ic.custom_minimum_size = Vector2(26.0, 26.0)
	gear_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear_ic.texture = _tex("ui_gear")
	hdr.add_child(gear_ic)

	opt_header_lbl = Label.new()
	opt_header_lbl.add_theme_font_size_override("font_size", 19)
	opt_header_lbl.add_theme_color_override("font_color", Color("#f5d0fe"))
	hdr.add_child(opt_header_lbl)

	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)

	var close_b: Button = _make_icon_slot_button("ui_btn_x", 38.0, Color("#fb7185"))
	close_b.pressed.connect(func() -> void:
		audio.play_named("block", 0.96)
		if in_game and not engine.player.is_empty() and bool(engine.player.get("dead", false)):
			open_death_modal(engine.pending_death_cause if engine.pending_death_cause != "" else "general")
		else:
			close_all_modals(true)
	)
	hdr.add_child(close_b)

	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	vb.add_child(tab_row)

	var tab_defs: Array = ["config", "shop", "ach", "lore"]
	for tk_var in tab_defs:
		var tk: String = str(tk_var)
		var tb: Button = Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0.0, 36.0)
		tb.pressed.connect(func() -> void:
			audio.play_named("block", 1.06)
			options_tab = tk
			reset_confirm_armed = false
			scroll_velocity_y = 0.0
			_apply_smooth_scroll(true, 0.0)
			_refresh_options_contents()
		)
		tab_row.add_child(tb)
		opt_tab_btns[tk] = tb

	# Custom `SmoothScrollBox` (`clip_contents = true`) — eliminates Godot `ScrollContainer` dual-channel touch bugs!
	opt_scroll_clip = Control.new()
	opt_scroll_clip.clip_contents = true
	opt_scroll_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opt_scroll_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	opt_scroll_clip.resized.connect(func() -> void:
		if opt_body_vbox != null:
			opt_body_vbox.size.x = maxf(200.0, opt_scroll_clip.size.x - 14.0)
			_apply_smooth_scroll(true, opt_scroll_y)
	)
	opt_scroll_clip.draw.connect(func() -> void:
		_draw_custom_scrollbar(opt_scroll_clip, opt_body_vbox, opt_scroll_y, Color("#c084fc"))
	)
	vb.add_child(opt_scroll_clip)

	opt_body_vbox = VBoxContainer.new()
	opt_body_vbox.position = Vector2.ZERO
	opt_body_vbox.size = Vector2(780.0, 340.0)
	opt_body_vbox.add_theme_constant_override("separation", 10)
	opt_body_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	opt_scroll_clip.add_child(opt_body_vbox)

func _sync_opt_vbox_layout() -> void:
	if opt_scroll_clip == null or opt_body_vbox == null:
		return
	var target_w: float = maxf(200.0, (opt_scroll_clip.size.x if opt_scroll_clip.size.x > 50.0 else 794.0) - 14.0)
	opt_body_vbox.custom_minimum_size.x = target_w
	opt_body_vbox.size.x = target_w
	opt_body_vbox.reset_size()
	opt_body_vbox.size.x = target_w
	_apply_smooth_scroll(true, opt_scroll_y)

func _refresh_options_contents() -> void:
	active_sliders.clear()
	opt_header_lbl.text = _tr("系统终端 · 设置与炼金商城 (支持上下顺滑滑动)", "SYSTEM TERMINAL · CONFIG & SHOP (Swipe to Scroll)")
	var shop_lock_tag: String = "" if shop.is_unlocked() else " [锁]"
	(opt_tab_btns["config"] as Button).text = _tr("◈ 基础与操控", "◈ CONFIG")
	(opt_tab_btns["shop"] as Button).text = _tr("◆ 炼金商城%s" % shop_lock_tag, "◆ SHOP%s" % shop_lock_tag)
	(opt_tab_btns["ach"] as Button).text = _tr("★ 成就殿堂", "★ ACHIEVEMENTS")
	(opt_tab_btns["lore"] as Button).text = _tr("▶ 剧情 CG", "▶ LORE & CGs")

	for tk in opt_tab_btns.keys():
		var b: Button = opt_tab_btns[tk]
		var on: bool = (tk == options_tab)
		b.add_theme_stylebox_override(
			"normal",
			_make_flat_box(Color("#1d1648") if on else Color("#09112c"), Color("#fde047") if on else Color("#334155"), 2 if on else 1, 8, 8, 4)
		)

	for ch in opt_body_vbox.get_children():
		opt_body_vbox.remove_child(ch)
		ch.queue_free()

	if options_tab == "config":
		_populate_config_tab()
	elif options_tab == "shop":
		_populate_shop_tab()
	elif options_tab == "ach":
		_populate_ach_tab()
	else:
		_populate_lore_tab()

	call_deferred("_sync_opt_vbox_layout")

func _make_setting_row(icon_key: String, title_txt: String) -> HBoxContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#0b1538"), Color(0.2, 0.4, 0.7, 0.45), 1, 8, 12, 8))
	var hb: HBoxContainer = HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_theme_constant_override("separation", 10)
	var ic: TextureRect = TextureRect.new()
	ic.custom_minimum_size = Vector2(22.0, 22.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture = _tex(icon_key)
	hb.add_child(ic)
	var lb: Label = Label.new()
	lb.text = title_txt
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.add_theme_font_size_override("font_size", 14)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)
	pc.add_child(hb)
	opt_body_vbox.add_child(pc)
	return hb

func _register_slider(sl: HSlider) -> void:
	sl.custom_minimum_size = Vector2(180.0, 30.0)
	active_sliders.append(sl)

func _populate_config_tab() -> void:
	var r_lang: HBoxContainer = _make_setting_row("ui_grid", _tr("界面语言 / Language", "Language / 界面语言"))
	var b_lang: Button = Button.new()
	b_lang.mouse_filter = Control.MOUSE_FILTER_PASS
	b_lang.text = "简体中文  ⇄  English" if save.lang == "zh" else "English  ⇄  简体中文"
	b_lang.pressed.connect(func() -> void:
		audio.play_named("coin", 1.05)
		save.lang = "en" if save.lang == "zh" else "zh"
		save.persist()
		refresh_language_and_assets()
		_refresh_options_contents()
	)
	r_lang.add_child(b_lang)

	var r_full: HBoxContainer = _make_setting_row("ui_fullscreen", _tr("全屏显示切换 (电脑端 F11)", "Fullscreen Mode (PC F11)"))
	var b_full: Button = Button.new()
	b_full.mouse_filter = Control.MOUSE_FILTER_PASS
	b_full.text = _tr("切换全屏 / 窗口", "Toggle Fullscreen")
	b_full.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		request_toggle_fullscreen.emit()
	)
	r_full.add_child(b_full)

	var r_bgm: HBoxContainer = _make_setting_row("ach_trophy", _tr("背景音乐 (BGM)", "Background Music (BGM)"))
	var b_bgm: Button = Button.new()
	b_bgm.mouse_filter = Control.MOUSE_FILTER_PASS
	b_bgm.text = _tr("开启" if save.bgm_on else "静音", "ON" if save.bgm_on else "MUTE")
	b_bgm.pressed.connect(func() -> void:
		save.bgm_on = not save.bgm_on
		save.persist()
		_refresh_options_contents()
	)
	r_bgm.add_child(b_bgm)
	var sl_bgm: HSlider = HSlider.new()
	_register_slider(sl_bgm)
	sl_bgm.min_value = 0.0
	sl_bgm.max_value = 100.0
	sl_bgm.step = 1.0
	sl_bgm.value = roundf(save.bgm_vol * 100.0)
	var lbl_bv: Label = Label.new()
	lbl_bv.custom_minimum_size = Vector2(46.0, 0.0)
	lbl_bv.text = "%d%%" % int(sl_bgm.value)
	sl_bgm.value_changed.connect(func(v: float) -> void:
		save.bgm_vol = clampf(v / 100.0, 0.0, 1.0)
		lbl_bv.text = "%d%%" % int(v)
		save.persist()
	)
	r_bgm.add_child(sl_bgm)
	r_bgm.add_child(lbl_bv)

	var r_sfx: HBoxContainer = _make_setting_row("ui_audio", _tr("游戏音效 (SFX)", "Sound Effects (SFX)"))
	var b_sfx: Button = Button.new()
	b_sfx.mouse_filter = Control.MOUSE_FILTER_PASS
	b_sfx.text = _tr("开启" if save.sfx_on else "静音", "ON" if save.sfx_on else "MUTE")
	b_sfx.pressed.connect(func() -> void:
		save.sfx_on = not save.sfx_on
		save.persist()
		if save.sfx_on:
			audio.play_named("coin", 1.0)
		_refresh_options_contents()
	)
	r_sfx.add_child(b_sfx)
	var sl_sfx: HSlider = HSlider.new()
	_register_slider(sl_sfx)
	sl_sfx.min_value = 0.0
	sl_sfx.max_value = 100.0
	sl_sfx.step = 1.0
	sl_sfx.value = roundf(save.sfx_vol * 100.0)
	var lbl_sv: Label = Label.new()
	lbl_sv.custom_minimum_size = Vector2(46.0, 0.0)
	lbl_sv.text = "%d%%" % int(sl_sfx.value)
	sl_sfx.value_changed.connect(func(v: float) -> void:
		save.sfx_vol = clampf(v / 100.0, 0.0, 1.0)
		lbl_sv.text = "%d%%" % int(v)
		save.persist()
	)
	r_sfx.add_child(sl_sfx)
	r_sfx.add_child(lbl_sv)

	var r_pad: HBoxContainer = _make_setting_row("ui_btn_jump", _tr("虚拟按键显示模式", "Touch Gamepad Visibility"))
	var mode_names: Dictionary = {
		"auto": _tr("自动 (安卓显示/电脑隐藏)", "AUTO (Mobile On / PC Off)"),
		"always": _tr("常驻显示", "ALWAYS SHOW"),
		"hide": _tr("隐藏按键", "HIDDEN")
	}
	var b_pad: Button = Button.new()
	b_pad.mouse_filter = Control.MOUSE_FILTER_PASS
	b_pad.text = str(mode_names.get(save.pad_mode, "AUTO"))
	b_pad.pressed.connect(func() -> void:
		if save.pad_mode == "auto":
			save.pad_mode = "always"
		elif save.pad_mode == "always":
			save.pad_mode = "hide"
		else:
			save.pad_mode = "auto"
		save.persist()
		last_pad_sig = ""
		audio.play_named("block", 1.04)
		_refresh_options_contents()
	)
	r_pad.add_child(b_pad)

	var r_swap: HBoxContainer = _make_setting_row("ui_hand_swap", _tr("左右手镜像互换 (支持滑指与向下划进管)", "Left-Handed Layout Swap"))
	var b_swap: Button = Button.new()
	b_swap.mouse_filter = Control.MOUSE_FILTER_PASS
	b_swap.text = _tr("已开启 (右方向/左动作)" if save.pad_swap else "默认 (左方向/右动作)", "SWAPPED" if save.pad_swap else "STANDARD")
	b_swap.pressed.connect(func() -> void:
		save.pad_swap = not save.pad_swap
		save.persist()
		last_pad_sig = ""
		audio.play_named("block", 1.04)
		_refresh_options_contents()
	)
	r_swap.add_child(b_swap)

	var r_sc: HBoxContainer = _make_setting_row("ui_padscale", _tr("触控按键尺寸缩放", "Gamepad Button Scale"))
	var sl_sc: HSlider = HSlider.new()
	_register_slider(sl_sc)
	sl_sc.min_value = 70.0
	sl_sc.max_value = 145.0
	sl_sc.step = 5.0
	sl_sc.value = roundf(save.pad_scale * 100.0)
	var lb_sc: Label = Label.new()
	lb_sc.custom_minimum_size = Vector2(48.0, 0.0)
	lb_sc.text = "%d%%" % int(sl_sc.value)
	sl_sc.value_changed.connect(func(v: float) -> void:
		save.pad_scale = clampf(v / 100.0, 0.70, 1.45)
		last_pad_sig = ""
		lb_sc.text = "%d%%" % int(v)
		save.persist()
	)
	r_sc.add_child(sl_sc)
	r_sc.add_child(lb_sc)

	var r_op: HBoxContainer = _make_setting_row("ui_opacity", _tr("触控按键不透明度", "Gamepad Opacity"))
	var sl_op: HSlider = HSlider.new()
	_register_slider(sl_op)
	sl_op.min_value = 25.0
	sl_op.max_value = 100.0
	sl_op.step = 5.0
	sl_op.value = roundf(save.pad_opacity * 100.0)
	var lb_op: Label = Label.new()
	lb_op.custom_minimum_size = Vector2(48.0, 0.0)
	lb_op.text = "%d%%" % int(sl_op.value)
	sl_op.value_changed.connect(func(v: float) -> void:
		save.pad_opacity = clampf(v / 100.0, 0.25, 1.0)
		lb_op.text = "%d%%" % int(v)
		save.persist()
	)
	r_op.add_child(sl_op)
	r_op.add_child(lb_op)

	var r_sn: HBoxContainer = _make_setting_row("ui_sensitivity", _tr("多指触控与下滑灵敏度", "Multi-Touch & Swipe Sensitivity"))
	var sl_sn: HSlider = HSlider.new()
	_register_slider(sl_sn)
	sl_sn.min_value = 50.0
	sl_sn.max_value = 150.0
	sl_sn.step = 5.0
	sl_sn.value = roundf(save.sensitivity * 100.0)
	var lb_sn: Label = Label.new()
	lb_sn.custom_minimum_size = Vector2(48.0, 0.0)
	lb_sn.text = "%d%%" % int(sl_sn.value)
	sl_sn.value_changed.connect(func(v: float) -> void:
		save.sensitivity = clampf(v / 100.0, 0.50, 1.50)
		lb_sn.text = "%d%%" % int(v)
		save.persist()
	)
	r_sn.add_child(sl_sn)
	r_sn.add_child(lb_sn)

	var r_vib: HBoxContainer = _make_setting_row("ach_springstar", _tr("手持设备震动反馈", "Haptic Vibration"))
	var b_vib: Button = Button.new()
	b_vib.mouse_filter = Control.MOUSE_FILTER_PASS
	b_vib.text = _tr("开启" if save.vibrate_on else "关闭", "ON" if save.vibrate_on else "OFF")
	b_vib.pressed.connect(func() -> void:
		save.vibrate_on = not save.vibrate_on
		save.persist()
		_refresh_options_contents()
	)
	r_vib.add_child(b_vib)

	var r_rst: HBoxContainer = _make_setting_row("ui_skull", _tr("重置通关进度与存档 (保留按键与音量偏好)", "Reset Save Progress (Keeps Controls/Audio)"))
	var b_rst: Button = Button.new()
	b_rst.mouse_filter = Control.MOUSE_FILTER_PASS
	b_rst.text = _tr("再次点击确认清空！" if reset_confirm_armed else "重置存档数据", "CLICK AGAIN TO CONFIRM!" if reset_confirm_armed else "Reset Save Data")
	if reset_confirm_armed:
		b_rst.add_theme_stylebox_override("normal", _make_flat_box(Color("#4c0519"), Color("#fb7185"), 2, 6, 10, 6))
	b_rst.pressed.connect(func() -> void:
		if not reset_confirm_armed:
			reset_confirm_armed = true
			audio.play_named("fake_buzz", 1.0)
			_refresh_options_contents()
		else:
			reset_confirm_armed = false
			save.reset_progress_keep_prefs()
			shop.reset_for_new_stage()
			audio.play_named("boom", 1.0)
			push_toast(_tr("存档已重置为第 01 关初始状态！", "Save progress reset to Stage 01!"), "ui_restart", "#fde047")
			close_all_modals(false)
			request_return_title.emit()
	)
	r_rst.add_child(b_rst)

func _populate_shop_tab() -> void:
	var top_card: PanelContainer = PanelContainer.new()
	top_card.mouse_filter = Control.MOUSE_FILTER_PASS
	top_card.add_theme_stylebox_override("panel", _make_flat_box(Color("#0c193d"), Color("#fde047"), 2, 10, 14, 10))
	var top_hb: HBoxContainer = HBoxContainer.new()
	top_hb.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hb.add_theme_constant_override("separation", 10)
	var c_ic: TextureRect = TextureRect.new()
	c_ic.custom_minimum_size = Vector2(26.0, 26.0)
	c_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c_ic.texture = _tex("coin_gold")
	top_hb.add_child(c_ic)
	var coin_lb: Label = Label.new()
	coin_lb.text = _tr("持有金币：%d G" % save.coins, "GOLD COINS: %d G" % save.coins)
	coin_lb.add_theme_font_size_override("font_size", 17)
	coin_lb.add_theme_color_override("font_color", Color("#fde047"))
	coin_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(coin_lb)
	var rule_lb: Label = Label.new()
	rule_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rule_lb.text = _tr("铁律：每件神装每关限用 1 次（重开不补发）· 不灭金身落坑照样必死", "RULE: Max 1 Use / Stage (no retry refill) · Golden Body dies in pits!")
	rule_lb.add_theme_font_size_override("font_size", 12)
	rule_lb.add_theme_color_override("font_color", Color("#67e8f9"))
	rule_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(rule_lb)
	top_card.add_child(top_hb)
	opt_body_vbox.add_child(top_card)

	if not shop.is_unlocked():
		var lock_box: PanelContainer = PanelContainer.new()
		lock_box.mouse_filter = Control.MOUSE_FILTER_PASS
		lock_box.add_theme_stylebox_override("panel", _make_flat_box(Color("#1a0b2e"), Color("#fb7185"), 2, 10, 16, 14))
		var l_lbl: Label = Label.new()
		l_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l_lbl.text = _tr(
			"[锁] 炼金神装商城尚未解锁！\n实打实通关【第 50 关】后正式开启设置内商城（当前第一板块已通关 %d / 50 关）。解锁后可用金币购买飞翼、魔剑强化、烈焰弹、穿墙术、炸弹、护盾与不灭金身（100G 起）。" % save.get_cleared_count(50),
			"[锁] ALCHEMY SHOP LOCKED!\nClear Stage 50 to unlock the embedded Coin Shop (Sector 1 progress: %d / 50). Items start at 100G." % save.get_cleared_count(50)
		)
		l_lbl.add_theme_color_override("font_color", Color("#fda4af"))
		lock_box.add_child(l_lbl)
		opt_body_vbox.add_child(lock_box)

	for it_var in shop.catalog:
		var it: Dictionary = it_var
		var item_id: String = str(it.get("id", ""))
		var price: int = int(it.get("price", 100))
		var owned: bool = shop.is_owned(item_id)
		var equipped: bool = shop.is_equipped(item_id)
		var used_now: bool = in_game and shop.has_used_in_stage(item_id)

		var row_pc: PanelContainer = PanelContainer.new()
		row_pc.mouse_filter = Control.MOUSE_FILTER_PASS
		var b_col: Color = Color("#4ade80") if (owned and equipped) else (Color("#64748b") if owned else Color("#38bdf8"))
		row_pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#091332"), b_col, 1, 10, 12, 10))
		var hb: HBoxContainer = HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.add_theme_constant_override("separation", 12)

		var ic: TextureRect = TextureRect.new()
		ic.custom_minimum_size = Vector2(36.0, 36.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_k: String = str(it.get("icon", "coin_gold"))
		if icon_k == "hud_wall_phase" and not textures.has("hud_wall_phase"):
			icon_k = "shield_orb"
		ic.texture = _tex(icon_k)
		hb.add_child(ic)

		var mid_vb: VBoxContainer = VBoxContainer.new()
		mid_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_vb.mouse_filter = Control.MOUSE_FILTER_PASS
		mid_vb.add_theme_constant_override("separation", 3)
		var nm_lb: Label = Label.new()
		nm_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var used_tag: String = _tr("  [本关已触发1次]", "  [USED THIS STAGE]") if used_now else ""
		nm_lb.text = str(it.get("enName" if save.lang == "en" else "zhName", item_id)) + used_tag
		nm_lb.add_theme_font_size_override("font_size", 15)
		nm_lb.add_theme_color_override("font_color", Color("#fde047") if owned else Color("#ecfeff"))
		mid_vb.add_child(nm_lb)

		var ds_lb: Label = Label.new()
		ds_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ds_lb.text = str(it.get("enDesc" if save.lang == "en" else "zhDesc", ""))
		ds_lb.add_theme_font_size_override("font_size", 12)
		ds_lb.add_theme_color_override("font_color", Color("#94a3b8"))
		mid_vb.add_child(ds_lb)
		hb.add_child(mid_vb)

		var act_btn: Button = Button.new()
		act_btn.custom_minimum_size = Vector2(126.0, 38.0)
		act_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		act_btn.disabled = not shop.is_unlocked()
		if not owned:
			act_btn.text = "%d G %s" % [price, _tr("购买", "BUY")]
		else:
			act_btn.text = _tr("已装备 ✓" if equipped else "已卸下 (点击装备)", "EQUIPPED ✓" if equipped else "EQUIP")
		act_btn.pressed.connect(func() -> void:
			var res: Dictionary = shop.buy_or_toggle(item_id, engine.player, in_game)
			if not bool(res.get("ok", false)):
				audio.play_named("fake_buzz", 1.0)
				if str(res.get("reason", "")) == "no_coins":
					push_toast(_tr("金币不足！需要 %d G" % price, "Not enough coins! Need %d G" % price), "coin_gold", "#fb7185")
			else:
				audio.play_named("coin", 1.12)
				if str(res.get("action", "")) == "already_used_this_stage":
					push_toast(_tr("每件道具每关限用 1 次，将在下一关生效！", "1 use per stage—will activate on next stage!"), "ui_hint", "#fde047")
				last_hud_sig = ""
				last_pad_sig = ""
				refresh_hud()
				_refresh_options_contents()
		)
		hb.add_child(act_btn)
		row_pc.add_child(hb)
		opt_body_vbox.add_child(row_pc)

func _populate_ach_tab() -> void:
	var ach_list: Array = meta.get("achievements", [])
	var unlocked_cnt: int = 0
	for a_var in ach_list:
		var a_d: Dictionary = a_var
		if bool(save.achievements.get(str(a_d.get("id", "")), false)):
			unlocked_cnt += 1

	var f_row: HBoxContainer = HBoxContainer.new()
	f_row.mouse_filter = Control.MOUSE_FILTER_PASS
	f_row.add_theme_constant_override("separation", 8)
	var sum_lb: Label = Label.new()
	sum_lb.text = _tr("已解锁成就：%d / %d" % [unlocked_cnt, ach_list.size()], "Unlocked: %d / %d" % [unlocked_cnt, ach_list.size()])
	sum_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_lb.add_theme_color_override("font_color", Color("#fde047"))
	sum_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_row.add_child(sum_lb)

	var cats: Array = [["all", "全部", "ALL"], ["prog", "主线", "PROGRESS"], ["star", "星级", "STARS"], ["troll", "反套路", "TROLL"]]
	for c_pair in cats:
		var cid: String = str(c_pair[0])
		var fb: Button = Button.new()
		fb.mouse_filter = Control.MOUSE_FILTER_PASS
		fb.text = str(c_pair[2] if save.lang == "en" else c_pair[1])
		fb.pressed.connect(func() -> void:
			ach_filter = cid
			_apply_smooth_scroll(true, 0.0)
			_refresh_options_contents()
		)
		f_row.add_child(fb)
	opt_body_vbox.add_child(f_row)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	opt_body_vbox.add_child(grid)

	for a_var in ach_list:
		var a: Dictionary = a_var
		var cat: String = str(a.get("cat", "prog"))
		if ach_filter != "all" and cat != ach_filter and not (ach_filter == "troll" and not (cat in ["prog", "star"])):
			continue
		var aid: String = str(a.get("id", ""))
		var got: bool = bool(save.achievements.get(aid, false))
		var card: PanelContainer = PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_flat_box(Color("#0c183c") if got else Color("#070d22"), Color("#fde047") if got else Color("#1e293b"), 1, 8, 10, 8))
		var hb: HBoxContainer = HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.add_theme_constant_override("separation", 8)
		var ic: TextureRect = TextureRect.new()
		ic.custom_minimum_size = Vector2(28.0, 28.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = _tex(str(a.get("icon", "ach_trophy")))
		ic.modulate = Color.WHITE if got else Color(0.35, 0.4, 0.5, 0.65)
		hb.add_child(ic)
		var tvb: VBoxContainer = VBoxContainer.new()
		tvb.mouse_filter = Control.MOUSE_FILTER_PASS
		tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tl: Label = Label.new()
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl.text = str(a.get("enTitle" if save.lang == "en" else "zhTitle", aid))
		tl.add_theme_font_size_override("font_size", 13)
		tl.add_theme_color_override("font_color", Color("#fde047") if got else Color("#64748b"))
		tvb.add_child(tl)
		var dl: Label = Label.new()
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.text = str(a.get("enDesc" if save.lang == "en" else "zhDesc", ""))
		dl.add_theme_font_size_override("font_size", 11)
		dl.add_theme_color_override("font_color", Color("#cbd5e1") if got else Color("#475569"))
		tvb.add_child(dl)
		hb.add_child(tvb)
		card.add_child(hb)
		grid.add_child(card)

func _populate_lore_tab() -> void:
	var c_row: HBoxContainer = HBoxContainer.new()
	c_row.mouse_filter = Control.MOUSE_FILTER_PASS
	c_row.add_theme_constant_override("separation", 6)
	var lore_tabs: Array = [
		["intro", "序章漫画 (6)", "PROLOGUE (6)"],
		["chapter", "S1/S2 章节 (8)", "CHAPTERS (8)"],
		["finale", "50关终章 (5)", "LV.50 FINALE (5)"],
		["true_finale", "100关根源 (7)", "LV.100 ROOT (7)"],
		["arcadia", "晴空幻境 (9)", "S3 ARCADIA (9)"]
	]
	for lt in lore_tabs:
		var lkey: String = str(lt[0])
		var b: Button = Button.new()
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = str(lt[2] if save.lang == "en" else lt[1])
		var active_l: bool = (lore_cat == lkey)
		b.add_theme_stylebox_override("normal", _make_flat_box(Color("#1d2b64") if active_l else Color("#09112c"), Color("#00f5ff") if active_l else Color("#334155"), 2 if active_l else 1, 6, 6, 4))
		b.pressed.connect(func() -> void:
			lore_cat = lkey
			_apply_smooth_scroll(true, 0.0)
			_refresh_options_contents()
		)
		c_row.add_child(b)
	opt_body_vbox.add_child(c_row)

	var datasets: Dictionary = meta.get("loreDatasets", {})
	var items: Array = datasets.get(lore_cat, [])
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	opt_body_vbox.add_child(grid)

	for idx in range(items.size()):
		var item: Dictionary = items[idx]
		var req_lv: int = int(item.get("reqLv", 0))
		var unlocked_cg: bool = (req_lv <= 0) or save.is_stage_cleared(req_lv) or bool(save.seen_cgs.get(str(item.get("id", "")), false))
		var card: PanelContainer = PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_flat_box(Color("#0a1436"), Color("#38bdf8") if unlocked_cg else Color("#1e293b"), 1, 8, 10, 8))
		var vb_i: VBoxContainer = VBoxContainer.new()
		vb_i.mouse_filter = Control.MOUSE_FILTER_PASS
		vb_i.add_theme_constant_override("separation", 6)

		var thumb: TextureRect = TextureRect.new()
		thumb.custom_minimum_size = Vector2(360.0, 136.0)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.texture = _tex(str(item.get("img", ""))) if unlocked_cg else _tex("ui_level_plate")
		if not unlocked_cg:
			thumb.modulate = Color(0.32, 0.36, 0.48, 0.8)
		vb_i.add_child(thumb)

		var ep_l: Label = Label.new()
		ep_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ep_l.text = str(item.get("enEp" if save.lang == "en" else "zhEp", "")) if unlocked_cg else (_tr("[锁] 通关第 %d 关解锁该 CG" % req_lv, "[锁] Clear Stage %d to unlock CG" % req_lv))
		ep_l.add_theme_font_size_override("font_size", 13)
		ep_l.add_theme_color_override("font_color", Color("#fde047") if unlocked_cg else Color("#64748b"))
		vb_i.add_child(ep_l)

		if unlocked_cg:
			var view_b: Button = Button.new()
			view_b.mouse_filter = Control.MOUSE_FILTER_PASS
			view_b.text = _tr("全屏赏析画卷", "OPEN IN THEATER")
			var cap_idx: int = idx
			view_b.pressed.connect(func() -> void:
				audio.play_named("coin", 1.06)
				open_cg_modal([items[cap_idx]], 0)
			)
			vb_i.add_child(view_b)
		card.add_child(vb_i)
		grid.add_child(card)

# --- 4C. DEATH TAUNT MODAL ---
func _build_death_modal() -> void:
	death_panel = _center_card(540.0, 338.0, Color("#fb7185"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	death_panel.add_child(vb)

	death_banner_rect = TextureRect.new()
	death_banner_rect.custom_minimum_size = Vector2(320.0, 74.0)
	death_banner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	death_banner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	death_banner_rect.texture = _tex("death_taunt_banner")
	vb.add_child(death_banner_rect)

	death_cause_lbl = Label.new()
	death_cause_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_cause_lbl.add_theme_font_size_override("font_size", 16)
	death_cause_lbl.add_theme_color_override("font_color", Color("#fb7185"))
	vb.add_child(death_cause_lbl)

	death_taunt_lbl = Label.new()
	death_taunt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_taunt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_taunt_lbl.custom_minimum_size = Vector2(480.0, 56.0)
	death_taunt_lbl.add_theme_font_size_override("font_size", 14)
	death_taunt_lbl.add_theme_color_override("font_color", Color("#f1f5f9"))
	vb.add_child(death_taunt_lbl)

	death_stat_lbl = Label.new()
	death_stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_stat_lbl.add_theme_font_size_override("font_size", 12)
	death_stat_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vb.add_child(death_stat_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	btn_death_retry = Button.new()
	btn_death_retry.custom_minimum_size = Vector2(156.0, 42.0)
	btn_death_retry.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 12, 6))
	btn_death_retry.pressed.connect(func() -> void:
		audio.play_named("coin", 1.06)
		close_all_modals(true)
		request_retry_stage.emit()
	)
	btn_row.add_child(btn_death_retry)

	btn_death_hint = Button.new()
	btn_death_hint.custom_minimum_size = Vector2(150.0, 42.0)
	btn_death_hint.pressed.connect(func() -> void:
		if engine.is_hint_unlocked():
			audio.play_named("coin", 1.04)
			open_hint_modal()
		else:
			audio.play_named("fake_buzz", 1.0)
	)
	btn_row.add_child(btn_death_hint)

	btn_death_hall = Button.new()
	btn_death_hall.custom_minimum_size = Vector2(130.0, 42.0)
	btn_death_hall.pressed.connect(func() -> void:
		audio.play_named("block", 1.04)
		open_level_select_modal()
	)
	btn_row.add_child(btn_death_hall)

# --- 4D. HINT & BLUEPRINT MODAL (`SmoothScrollBox` for hint steps) ---
func _build_hint_modal() -> void:
	hint_panel = _center_card(816.0, 474.0, Color("#fde047"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	hint_panel.add_child(vb)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	vb.add_child(hdr)

	var masc: TextureRect = TextureRect.new()
	masc.custom_minimum_size = Vector2(34.0, 34.0)
	masc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	masc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	masc.texture = _tex("troll_mascot")
	hdr.add_child(masc)

	hint_title_lbl = Label.new()
	hint_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_title_lbl.add_theme_font_size_override("font_size", 18)
	hint_title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	hdr.add_child(hint_title_lbl)

	btn_hint_xray = Button.new()
	btn_hint_xray.custom_minimum_size = Vector2(168.0, 34.0)
	btn_hint_xray.pressed.connect(func() -> void:
		engine.xray_level = not engine.xray_level
		audio.play_named("coin", 1.1)
		_refresh_hint_contents()
	)
	hdr.add_child(btn_hint_xray)

	hint_quote_lbl = Label.new()
	hint_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_quote_lbl.add_theme_font_size_override("font_size", 12)
	hint_quote_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	vb.add_child(hint_quote_lbl)

	var mid_hb: HBoxContainer = HBoxContainer.new()
	mid_hb.add_theme_constant_override("separation", 10)
	vb.add_child(mid_hb)

	hint_blueprint = HintBlueprintView.new()
	hint_blueprint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_blueprint.setup(textures, font_main)
	mid_hb.add_child(hint_blueprint)

	hint_illust_rect = TextureRect.new()
	hint_illust_rect.custom_minimum_size = Vector2(210.0, 152.0)
	hint_illust_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_illust_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mid_hb.add_child(hint_illust_rect)

	hint_scroll_clip = Control.new()
	hint_scroll_clip.clip_contents = true
	hint_scroll_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_scroll_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint_scroll_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	hint_scroll_clip.resized.connect(func() -> void:
		if hint_steps_vbox != null:
			hint_steps_vbox.size.x = maxf(200.0, hint_scroll_clip.size.x - 14.0)
			_apply_smooth_scroll(false, hint_scroll_y)
	)
	hint_scroll_clip.draw.connect(func() -> void:
		_draw_custom_scrollbar(hint_scroll_clip, hint_steps_vbox, hint_scroll_y, Color("#fde047"))
	)
	vb.add_child(hint_scroll_clip)

	hint_steps_vbox = VBoxContainer.new()
	hint_steps_vbox.position = Vector2.ZERO
	hint_steps_vbox.size = Vector2(760.0, 140.0)
	hint_steps_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hint_steps_vbox.add_theme_constant_override("separation", 5)
	hint_scroll_clip.add_child(hint_steps_vbox)

	btn_hint_resume = Button.new()
	btn_hint_resume.custom_minimum_size = Vector2(220.0, 40.0)
	btn_hint_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_hint_resume.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 16, 6))
	btn_hint_resume.pressed.connect(func() -> void:
		audio.play_named("coin", 1.08)
		var was_dead: bool = (not engine.player.is_empty()) and bool(engine.player.get("dead", false))
		close_all_modals(true)
		if was_dead:
			request_retry_stage.emit()
	)
	vb.add_child(btn_hint_resume)

func _sync_hint_vbox_layout() -> void:
	if hint_scroll_clip == null or hint_steps_vbox == null:
		return
	var target_w: float = maxf(200.0, (hint_scroll_clip.size.x if hint_scroll_clip.size.x > 50.0 else 770.0) - 14.0)
	hint_steps_vbox.custom_minimum_size.x = target_w
	hint_steps_vbox.size.x = target_w
	hint_steps_vbox.reset_size()
	hint_steps_vbox.size.x = target_w
	_apply_smooth_scroll(false, hint_scroll_y)

func _refresh_hint_contents() -> void:
	var lv: Dictionary = engine.lv_data
	var nm: String = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	hint_title_lbl.text = "LV.%02d · %s — %s" % [engine.lv_id, nm, _tr("破局蓝图", "BLUEPRINT")]
	btn_hint_xray.text = _tr("X-Ray 透视：已开启 ✓" if engine.xray_level else "开启 X-Ray 机关透视", "X-RAY: ON ✓" if engine.xray_level else "ENABLE X-RAY")
	hint_quote_lbl.text = "◈ " + str(lv.get("trollQuoteEn" if save.lang == "en" else "trollQuote", ""))
	hint_blueprint.set_stage(lv)

	var ill_key: String = str(lv.get("hintIllust", ""))
	if ill_key != "" and textures.has(ill_key):
		hint_illust_rect.texture = _tex(ill_key)
		hint_illust_rect.visible = true
	else:
		hint_illust_rect.visible = false

	for ch in hint_steps_vbox.get_children():
		hint_steps_vbox.remove_child(ch)
		ch.queue_free()
	var steps: Array = lv.get("hintStepsEn" if save.lang == "en" else "hintSteps", [])
	for i in range(steps.size()):
		var slb: Label = Label.new()
		slb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slb.text = "%d. %s" % [i + 1, str(steps[i])]
		slb.add_theme_font_size_override("font_size", 13)
		slb.add_theme_color_override("font_color", Color("#e2e8f0"))
		hint_steps_vbox.add_child(slb)

	btn_hint_resume.text = _tr("继续挑战 (可拖拽上方蓝图平移查看)", "CONTINUE CHALLENGE (Drag Blueprint to Pan)")
	call_deferred("_sync_hint_vbox_layout")

# --- 4E. STAGE CLEAR SUMMARY MODAL ---
func _build_clear_modal() -> void:
	clear_panel = _center_card(540.0, 344.0, Color("#4ade80"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	clear_panel.add_child(vb)

	var hdr_hb: HBoxContainer = HBoxContainer.new()
	hdr_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr_hb.add_theme_constant_override("separation", 8)
	var chk_ic: TextureRect = TextureRect.new()
	chk_ic.custom_minimum_size = Vector2(28.0, 28.0)
	chk_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chk_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chk_ic.texture = _tex("ui_btn_check")
	hdr_hb.add_child(chk_ic)
	clear_title_lbl = Label.new()
	clear_title_lbl.add_theme_font_size_override("font_size", 22)
	clear_title_lbl.add_theme_color_override("font_color", Color("#4ade80"))
	hdr_hb.add_child(clear_title_lbl)
	vb.add_child(hdr_hb)

	clear_sub_lbl = Label.new()
	clear_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_sub_lbl.add_theme_font_size_override("font_size", 14)
	clear_sub_lbl.add_theme_color_override("font_color", Color("#ecfeff"))
	vb.add_child(clear_sub_lbl)

	clear_stars_box = HBoxContainer.new()
	clear_stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	clear_stars_box.add_theme_constant_override("separation", 8)
	vb.add_child(clear_stars_box)

	clear_stats_lbl = Label.new()
	clear_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_stats_lbl.add_theme_font_size_override("font_size", 15)
	clear_stats_lbl.add_theme_color_override("font_color", Color("#fde047"))
	vb.add_child(clear_stats_lbl)

	var brow: HBoxContainer = HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 10)
	vb.add_child(brow)

	btn_clear_replay = Button.new()
	btn_clear_replay.custom_minimum_size = Vector2(126.0, 42.0)
	btn_clear_replay.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		close_all_modals(false)
		request_start_stage.emit(engine.lv_id)
	)
	brow.add_child(btn_clear_replay)

	btn_clear_hall = Button.new()
	btn_clear_hall.custom_minimum_size = Vector2(126.0, 42.0)
	btn_clear_hall.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		open_level_select_modal()
	)
	brow.add_child(btn_clear_hall)

	btn_clear_next = Button.new()
	btn_clear_next.custom_minimum_size = Vector2(180.0, 42.0)
	btn_clear_next.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 12, 6))
	btn_clear_next.pressed.connect(func() -> void: _on_clear_primary_action())
	brow.add_child(btn_clear_next)

func _on_clear_primary_action() -> void:
	var cur_lv: int = engine.lv_id
	var cgs_map: Dictionary = meta.get("milestoneCgs", {})
	if cgs_map.has(str(cur_lv)):
		var slides: Array = cgs_map[str(cur_lv)]
		if not slides.is_empty():
			audio.play_named("coin", 1.12)
			open_cg_modal(slides, cur_lv)
			return
	if cur_lv < 150:
		audio.play_named("coin", 1.1)
		close_all_modals(false)
		request_start_stage.emit(cur_lv + 1)
	else:
		open_level_select_modal()

# --- 4F. CG STORY THEATER MODAL ---
func _build_cg_modal() -> void:
	cg_panel = _center_card(846.0, 492.0, Color("#fde047"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	cg_panel.add_child(vb)

	var top_hb: HBoxContainer = HBoxContainer.new()
	cg_badge_lbl = Label.new()
	cg_badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cg_badge_lbl.add_theme_font_size_override("font_size", 14)
	cg_badge_lbl.add_theme_color_override("font_color", Color("#fde047"))
	top_hb.add_child(cg_badge_lbl)
	cg_page_lbl = Label.new()
	cg_page_lbl.add_theme_font_size_override("font_size", 14)
	cg_page_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	top_hb.add_child(cg_page_lbl)
	vb.add_child(top_hb)

	var art_frame: PanelContainer = PanelContainer.new()
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.add_theme_stylebox_override("panel", _make_flat_box(Color("#020617"), Color("#38bdf8"), 2, 8, 4, 4))
	cg_art_rect = TextureRect.new()
	cg_art_rect.custom_minimum_size = Vector2(780.0, 290.0)
	cg_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cg_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_frame.add_child(cg_art_rect)
	vb.add_child(art_frame)

	cg_ep_lbl = Label.new()
	cg_ep_lbl.add_theme_font_size_override("font_size", 16)
	cg_ep_lbl.add_theme_color_override("font_color", Color("#ecfeff"))
	vb.add_child(cg_ep_lbl)

	cg_cap_lbl = Label.new()
	cg_cap_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cg_cap_lbl.custom_minimum_size = Vector2(780.0, 44.0)
	cg_cap_lbl.add_theme_font_size_override("font_size", 13)
	cg_cap_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	vb.add_child(cg_cap_lbl)

	var brow: HBoxContainer = HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_END
	brow.add_theme_constant_override("separation", 10)
	btn_cg_prev = Button.new()
	btn_cg_prev.custom_minimum_size = Vector2(116.0, 38.0)
	btn_cg_prev.pressed.connect(func() -> void:
		if cg_index > 0:
			cg_index -= 1
			audio.play_named("block", 1.05)
			_refresh_cg_slide()
	)
	brow.add_child(btn_cg_prev)

	btn_cg_next = Button.new()
	btn_cg_next.custom_minimum_size = Vector2(168.0, 38.0)
	btn_cg_next.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 14, 5))
	btn_cg_next.pressed.connect(func() -> void:
		if cg_index + 1 < cg_slides.size():
			cg_index += 1
			audio.play_named("coin", 1.06)
			_refresh_cg_slide()
		else:
			audio.play_named("coin", 1.14)
			var after_lv: int = cg_after_stage_id
			close_all_modals(false)
			if after_lv > 0 and after_lv < 150:
				request_start_stage.emit(after_lv + 1)
			elif after_lv == 150:
				open_level_select_modal()
			elif not in_game:
				show_title_screen()
	)
	brow.add_child(btn_cg_next)
	vb.add_child(brow)

func _refresh_cg_slide() -> void:
	if cg_slides.is_empty():
		return
	var sl: Dictionary = cg_slides[cg_index]
	var cid: String = str(sl.get("id", sl.get("img", "")))
	if cid != "":
		save.seen_cgs[cid] = true
		save.persist()
	cg_badge_lbl.text = str(sl.get("enBadge" if save.lang == "en" else "zhBadge", "STORY CG"))
	cg_page_lbl.text = "%d / %d" % [cg_index + 1, cg_slides.size()]
	cg_art_rect.texture = _tex(str(sl.get("img", "")))
	cg_ep_lbl.text = str(sl.get("enEp" if save.lang == "en" else "zhEp", ""))
	cg_cap_lbl.text = str(sl.get("enCap" if save.lang == "en" else "zhCap", ""))
	btn_cg_prev.visible = cg_slides.size() > 1
	btn_cg_prev.disabled = (cg_index <= 0)
	btn_cg_prev.text = _tr("◀ 上一幕", "◀ PREV")
	if cg_index + 1 < cg_slides.size():
		btn_cg_next.text = _tr("下一幕 ▶", "NEXT PANEL ▶")
	elif cg_after_stage_id > 0 and cg_after_stage_id < 150:
		btn_cg_next.text = _tr("前往第 %d 关 ▶" % (cg_after_stage_id + 1), "STAGE %d ▶" % (cg_after_stage_id + 1))
	else:
		btn_cg_next.text = _tr("完成赏析 ✓", "FINISH ✓")

# --- 4G. EXIT / STANDBY MODAL ---
func _build_exit_modal() -> void:
	exit_panel = _center_card(440.0, 236.0, Color("#00f5ff"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	exit_panel.add_child(vb)

	exit_title_lbl = Label.new()
	exit_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_title_lbl.add_theme_font_size_override("font_size", 19)
	exit_title_lbl.add_theme_color_override("font_color", Color("#00f5ff"))
	vb.add_child(exit_title_lbl)

	exit_desc_lbl = Label.new()
	exit_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_desc_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(exit_desc_lbl)

	var brow: HBoxContainer = HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 10)
	vb.add_child(brow)

	btn_exit_standby = Button.new()
	btn_exit_standby.custom_minimum_size = Vector2(124.0, 40.0)
	btn_exit_standby.pressed.connect(func() -> void:
		close_all_modals(false)
		standby_mode = true
		standby_veil.visible = true
	)
	brow.add_child(btn_exit_standby)

	btn_exit_quit = Button.new()
	btn_exit_quit.custom_minimum_size = Vector2(124.0, 40.0)
	btn_exit_quit.add_theme_stylebox_override("normal", _make_flat_box(Color("#4c0519"), Color("#fb7185"), 2, 8, 10, 6))
	btn_exit_quit.pressed.connect(func() -> void:
		request_quit_app.emit()
	)
	brow.add_child(btn_exit_quit)

	btn_exit_cancel = Button.new()
	btn_exit_cancel.custom_minimum_size = Vector2(106.0, 40.0)
	btn_exit_cancel.pressed.connect(func() -> void:
		audio.play_named("block", 1.0)
		close_all_modals(true)
	)
	brow.add_child(btn_exit_cancel)

func _build_standby_veil() -> void:
	standby_veil = Button.new()
	standby_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	standby_veil.add_theme_stylebox_override("normal", _make_flat_box(Color(0.0, 0.01, 0.04, 0.96), Color.TRANSPARENT, 0, 0, 0, 0))
	standby_veil.add_theme_stylebox_override("hover", _make_flat_box(Color(0.0, 0.01, 0.04, 0.96), Color.TRANSPARENT, 0, 0, 0, 0))
	standby_veil.text = "◈ STANDBY MODE · 轻触屏幕任意位置唤醒哥查德"
	standby_veil.visible = false
	standby_veil.pressed.connect(func() -> void:
		standby_mode = false
		standby_veil.visible = false
		audio.play_named("coin", 1.06)
	)
	add_child(standby_veil)

# ==============================================================================
# 5. PUBLIC NAVIGATION, STATE & FRAME ANIMATION API
# ==============================================================================
func is_modal_open() -> bool:
	return active_modal != "" or standby_mode

func close_all_modals(_clear_pads: bool = true) -> void:
	active_modal = ""
	scroll_pointer_down = false
	scroll_is_dragging = false
	scroll_velocity_y = 0.0
	hall_pointer_down = false
	hall_swipe_consumed = false
	modal_backdrop.visible = false
	hall_panel.visible = false
	options_panel.visible = false
	death_panel.visible = false
	hint_panel.visible = false
	clear_panel.visible = false
	cg_panel.visible = false
	exit_panel.visible = false
	clear_touch_inputs()

func _open_exclusive(modal_name: String, panel: PanelContainer) -> void:
	close_all_modals(true)
	active_modal = modal_name
	modal_backdrop.visible = true
	panel.visible = true

func show_title_screen() -> void:
	in_game = false
	close_all_modals(true)
	title_view.visible = true
	hud_view.visible = false
	touch_overlay.visible = false
	audio.select_track(true, 1)

func enter_gameplay_hud(stage_id: int) -> void:
	in_game = true
	close_all_modals(true)
	title_view.visible = false
	hud_view.visible = true
	touch_overlay.visible = true
	sync_safe_area_and_layout()
	last_hud_sig = ""
	last_pad_sig = ""
	var lv: Dictionary = engine.levels_by_id.get(stage_id, {})
	var st_title: String = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	var sec_col: Color = Color("#38bdf8") if stage_id >= 101 else (Color("#c084fc") if stage_id >= 51 else Color("#00f5ff"))
	show_stage_banner("LV.%02d · %s" % [stage_id, st_title], sec_col, 3.2)
	refresh_hud()
	touch_overlay.queue_redraw()

func open_level_select_from_title() -> void:
	var target_lv: int = save.last_lv if save.is_stage_unlocked(save.last_lv) else save.get_highest_frontier_level(0)
	selected_chapter = clampi(int(ceil(float(target_lv) / 10.0)), 1, 15)
	selected_sector = clampi(int(ceil(float(selected_chapter) / 5.0)), 1, 3)
	_open_exclusive("hall", hall_panel)
	_refresh_hall_contents()

func open_level_select_modal() -> void:
	var cur_lv: int = engine.lv_id if in_game else save.last_lv
	selected_chapter = clampi(int(ceil(float(cur_lv) / 10.0)), 1, 15)
	selected_sector = clampi(int(ceil(float(selected_chapter) / 5.0)), 1, 3)
	_open_exclusive("hall", hall_panel)
	_refresh_hall_contents()

func open_options_modal(tab_key: String = "config") -> void:
	options_tab = tab_key
	reset_confirm_armed = false
	_open_exclusive("options", options_panel)
	_apply_smooth_scroll(true, 0.0)
	_refresh_options_contents()

func open_death_modal(cause_key: String) -> void:
	_open_exclusive("death", death_panel)
	var causes: Dictionary = meta.get("causeLabels", {})
	var c_obj: Dictionary = causes.get(cause_key, causes.get("general", { "zh": "× 死因：初见杀陷阱", "en": "× CAUSE: TROLL TRAP" }))
	death_cause_lbl.text = str(c_obj.get("en" if save.lang == "en" else "zh", ""))

	var taunts_map: Dictionary = meta.get("deathTaunts", {})
	var pool: Array = taunts_map.get(cause_key, taunts_map.get("general", []))
	if pool.is_empty():
		death_taunt_lbl.text = _tr("墨镜赛博猫：「就这？再动动你 250 的小脑瓜喵！」", "Cyber-Cat: 'Is that all? Think outside the box!'")
	else:
		var pick: Dictionary = pool[randi() % pool.size()]
		death_taunt_lbl.text = str(pick.get("en" if save.lang == "en" else "zh", ""))

	var max_d: int = engine.get_max_deaths()
	death_stat_lbl.text = _tr("本轮失误：%d 次  |  累计最高：%d 次" % [engine.attempt_deaths, max_d], "Attempt Fails: %d  |  Stage Max: %d" % [engine.attempt_deaths, max_d])
	btn_death_retry.text = _tr("↻ 立即重来 (R)", "↻ RETRY (R)")
	if engine.is_hint_unlocked():
		btn_death_hint.text = _tr("★ 破局蓝图", "★ BLUEPRINT")
	else:
		btn_death_hint.text = _tr("[锁] 提示 (%d/5)" % max_d, "[锁] HINT (%d/5)" % max_d)
	btn_death_hall.text = _tr("▦ 选关大厅", "▦ STAGES")

func open_hint_modal() -> void:
	_open_exclusive("hint", hint_panel)
	_apply_smooth_scroll(false, 0.0)
	_refresh_hint_contents()

func open_clear_modal(win_res: Dictionary) -> void:
	_open_exclusive("clear", clear_panel)
	var stars_n: int = int(win_res.get("stars", 5))
	var reward_g: int = int(win_res.get("reward", 25))
	var iq_score: int = int(win_res.get("iq", 250))
	var lv: Dictionary = engine.lv_data

	clear_title_lbl.text = _tr("第 %02d 关 突破成功！" % engine.lv_id, "STAGE %02d CLEARED!" % engine.lv_id)
	var c_txt: String = str(lv.get("clearTextEn" if save.lang == "en" else "clearText", ""))
	if c_txt == "":
		c_txt = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	clear_sub_lbl.text = c_txt

	for ch in clear_stars_box.get_children():
		ch.queue_free()
	for si in range(5):
		var sr: TextureRect = TextureRect.new()
		sr.custom_minimum_size = Vector2(32.0, 32.0)
		sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sr.texture = _tex("star_gold" if si < stars_n else "star_empty")
		clear_stars_box.add_child(sr)

	clear_stats_lbl.text = _tr(
		"智商评级：IQ %d   |   本轮失误：%d   |   赏金：+%d G (总计 %d G)" % [iq_score, engine.attempt_deaths, reward_g, save.coins],
		"IQ Rating: %d   |   Fails: %d   |   Bounty: +%d G (Total %d G)" % [iq_score, engine.attempt_deaths, reward_g, save.coins]
	)
	btn_clear_replay.text = _tr("↻ 重玩本关", "↻ REPLAY")
	btn_clear_hall.text = _tr("▦ 选关大厅", "▦ STAGES")

	var cgs_map: Dictionary = meta.get("milestoneCgs", {})
	if cgs_map.has(str(engine.lv_id)):
		var cnt: int = (cgs_map[str(engine.lv_id)] as Array).size()
		btn_clear_next.text = _tr("▶ 观看剧情 CG (%d幕) ▶" % cnt, "▶ WATCH CG (%d) ▶" % cnt)
	elif engine.lv_id < 150:
		btn_clear_next.text = _tr("下一关 (LV.%02d) ▶" % (engine.lv_id + 1), "NEXT (LV.%02d) ▶" % (engine.lv_id + 1))
	else:
		btn_clear_next.text = _tr("★ 150关大满贯达成！", "★ ALL 150 CLEARED!")

func open_cg_modal(slides: Array, after_stage: int = 0) -> void:
	cg_slides = slides
	cg_index = 0
	cg_after_stage_id = after_stage
	_open_exclusive("cg", cg_panel)
	_refresh_cg_slide()

func open_exit_modal() -> void:
	_open_exclusive("exit", exit_panel)
	exit_title_lbl.text = _tr("离开哥查德的大冒险？", "LEAVE GODCHARD ADVENTURE?")
	exit_desc_lbl.text = _tr("你的通关星级、金币与神装进度均已实时自动保存。", "Your stars, coins, and shop items are automatically saved.")
	btn_exit_standby.text = _tr("◈ 静音待机", "◈ STANDBY")
	btn_exit_quit.text = _tr("× 退出应用", "× QUIT APP")
	btn_exit_cancel.text = _tr("返回", "CANCEL")

func _set_btn_badge(b: Button, txt: String) -> void:
	if b == null:
		return
	var bl: Label = b.get_node_or_null("BadgeLbl") as Label
	if bl != null:
		bl.text = txt

func refresh_language_and_assets() -> void:
	var is_en: bool = (save.lang == "en")
	lbl_title_lang.text = "中文" if is_en else "EN"
	title_logo_tex.texture = _tex("logo_title_en" if is_en else "logo_title")
	btn_start_img.texture_normal = _tex("btn_start_en" if is_en else "btn_start_zh")
	btn_opts_img.texture_normal = _tex("btn_opts_en" if is_en else "btn_opts_zh")
	btn_exit_img.texture_normal = _tex("btn_exit_en" if is_en else "btn_exit_zh")
	_set_btn_badge(btn_hud_grid, "MAP" if is_en else "选关")
	_set_btn_badge(btn_hud_next, "NXT" if is_en else "下关")
	_set_btn_badge(btn_hud_reset, "RST" if is_en else "重开")
	_set_btn_badge(btn_hud_hint, "HNT" if is_en else "提示")
	_set_btn_badge(btn_hud_gear, "CFG" if is_en else "设置")
	standby_veil.text = "◈ STANDBY MODE · Tap Anywhere to Resume" if is_en else "◈ 静音待机中 · 轻触屏幕任意位置唤醒哥查德"
	last_hud_sig = ""
	if active_modal == "hall":
		_refresh_hall_contents()
	elif active_modal == "options":
		_refresh_options_contents()
	elif active_modal == "hint":
		_refresh_hint_contents()
	elif active_modal == "cg":
		_refresh_cg_slide()

func show_stage_banner(txt: String, col: Color = Color("#00f5ff"), dur: float = 2.8) -> void:
	banner_text = txt
	banner_color = col
	banner_timer = dur
	special_banner_lbl.text = txt
	special_banner_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.03, 0.06, 0.20, 0.88), col, 1, 14, 14, 4))
	special_banner_panel.visible = true

func push_toast(txt: String, icon_key: String = "ui_hint", color_hex: String = "#00f5ff") -> void:
	toast_text = txt
	toast_icon_key = icon_key
	toast_color = Color(color_hex)
	toast_timer = 2.4
	fx_toast_icon.texture = _tex(icon_key)
	fx_toast_lbl.text = txt
	fx_toast_lbl.add_theme_color_override("font_color", toast_color)
	fx_toast_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.04, 0.08, 0.24, 0.94), toast_color, 2, 14, 12, 4))
	fx_toast_panel.visible = true

func push_ach_toast(ach_id: String) -> void:
	var ach_list: Array = meta.get("achievements", [])
	var title_s: String = ach_id
	var icon_s: String = "ach_trophy"
	for a_var in ach_list:
		var a: Dictionary = a_var
		if str(a.get("id", "")) == ach_id:
			title_s = str(a.get("enTitle" if save.lang == "en" else "zhTitle", ach_id))
			icon_s = str(a.get("icon", "ach_trophy"))
			break
	ach_toast_title = title_s
	ach_toast_icon = icon_s
	ach_toast_timer = 3.2
	ach_toast_icon_rect.texture = _tex(icon_s)
	ach_toast_lbl.text = _tr("★ 解锁成就：%s" % title_s, "★ ACHIEVEMENT: %s" % title_s)
	ach_toast_panel.visible = true

func step_ui(dt: float) -> void:
	anim_time += dt
	if title_view.visible:
		title_bg_view.step_anim(dt)
		title_logo_tex.position.y = title_logo_base_y + sin(anim_time * 2.15) * 4.5

	if active_modal == "hint":
		hint_blueprint.step_anim(dt)

	# Subpixel kinetic inertia coasting for SmoothScrollBox (`options` & `hint`)
	if (active_modal == "options" or active_modal == "hint") and not scroll_is_dragging and absf(scroll_velocity_y) > 4.0:
		var is_opt_step: bool = (active_modal == "options")
		var cur_y_step: float = opt_scroll_y if is_opt_step else hint_scroll_y
		_apply_smooth_scroll(is_opt_step, cur_y_step + scroll_velocity_y * dt)
		scroll_velocity_y *= exp(-6.8 * dt)
		if absf(scroll_velocity_y) <= 4.0:
			scroll_velocity_y = 0.0

	if swipe_down_hold_timer > 0.0:
		swipe_down_hold_timer = maxf(0.0, swipe_down_hold_timer - dt)
		if swipe_down_hold_timer <= 0.0:
			_recompute_touch_actions()
			if touch_overlay != null:
				touch_overlay.queue_redraw()

	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - dt)
		if banner_timer <= 0.0:
			special_banner_panel.visible = false

	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - dt)
		if toast_timer <= 0.0:
			fx_toast_panel.visible = false

	if ach_toast_timer > 0.0:
		ach_toast_timer = maxf(0.0, ach_toast_timer - dt)
		if ach_toast_timer <= 0.0:
			ach_toast_panel.visible = false

	if in_game and active_modal == "":
		if engine.hud_dirty or engine.timer_left >= 0.0 or float(engine.player.get("golden_timer", 0.0)) > 0.0:
			engine.hud_dirty = false
			refresh_hud()
