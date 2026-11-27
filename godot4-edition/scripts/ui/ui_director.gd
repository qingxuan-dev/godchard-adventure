class_name UIDirector
extends Control

signal request_start_stage(stage_id: int)
signal request_retry_stage()
signal request_fresh_restart()
signal request_return_title()
signal request_quit_app()
signal request_toggle_fullscreen()

# All texture aliases map strictly to verified keys in data/game_metadata.json["assets"]
const UI_TEX_ALIASES: Dictionary = {
	"coin_gold": "ui_coin_hud",
	"shield_orb": "icon_shield",
	"icon_wings": "icon_wing",
	"sword_pickup": "icon_sword",
	"bullet_up": "s3_shop_bullet",
	"hud_wall_phase": "s3_shop_phase",
	"clock_item": "clock_gold"
}

const CHAPTER_META: Array = [
	{ "ch": 1, "act": 1, "zh": "第01章 · 本能误导课", "en": "CH.01 · Instinct Subversion", "theme_zh": "方向诱导 · 四态云 · 毒雾钥匙 · 假旗", "theme_en": "Direction · Clouds · Spore Key · Fake Flags", "cg_lv": 10, "icon": "hint_ill_reverse" },
	{ "ch": 2, "act": 1, "zh": "第02章 · 道具背锅局", "en": "CH.02 · Props Take the Blame", "theme_zh": "分类护盾 · 回声管 · 配重币 · 影长飞翼", "theme_en": "Shield Tag · Pipe Echo · Coin Weight · Shadow Wings", "cg_lv": 20, "icon": "hint_ill_alchemy" },
	{ "ch": 3, "act": 1, "zh": "第03章 · 状态与物理异常", "en": "CH.03 · State & Physics Anomaly", "theme_zh": "双窗解毒 · 材质重力 · 仇恨链 · 三钟", "theme_en": "Dual Cure · Material Gravity · Aggro · Tri-Clock", "cg_lv": 30, "icon": "hint_ill_mirror" },
	{ "ch": 4, "act": 1, "zh": "第04章 · 习惯反噬研究所", "en": "CH.04 · Habit Backlash Lab", "theme_zh": "三段下砸 · 护盾缓存 · 悖论门 · 追击战", "theme_en": "Ground Pound · Shield Cache · Paradox · Chase", "cg_lv": 40, "icon": "hint_ill_paradox" },
	{ "ch": 5, "act": 1, "zh": "第05章 · 作者恶意终考", "en": "CH.05 · Author's Final Exam", "theme_zh": "动态规则 · 黑屏听声 · 八假旗 · 让出胜利", "theme_en": "Rule Swap · Audio Dark · 8 Flags · Yield Win", "cg_lv": 50, "icon": "hint_ill_boss" },
	{ "ch": 6, "act": 2, "zh": "第06章 · 系统入侵与信号风暴", "en": "CH.06 · System Intrusion & Storm", "theme_zh": "Meta按钮 · 害羞砖 · 404弹窗 · 信号核心", "theme_en": "Meta UI · Shy Brick · 404 Popups · Signal Core", "cg_lv": 60, "icon": "hint_ill_signal" },
	{ "ch": 7, "act": 2, "zh": "第07章 · 机械城黑心工厂", "en": "CH.07 · Mecha Black-Heart Plant", "theme_zh": "VIP履带 · 核弹白鸽 · 叉车 · 机械统御者", "theme_en": "VIP Belt · Peace Dove · Forklift · Mecha Overlord", "cg_lv": 70, "icon": "s2_boss_mecha" },
	{ "ch": 8, "act": 2, "zh": "第08章 · 裂界与双层空间", "en": "CH.08 · Fracture & Dual-Layer", "theme_zh": "前景背景切层 · 双残影 · 玻璃栈道 · 裂界核心", "theme_en": "FG/BG Shift · Dual Echo · Glass · Fracture Core", "cg_lv": 80, "icon": "hint_ill_fracture" },
	{ "ch": 9, "act": 2, "zh": "第09章 · 时间线犯罪现场", "en": "CH.09 · Timeline Crime Scene", "theme_zh": "幽灵专列 · 假暂停 · 悬停剑波 · 时间统御者", "theme_en": "Ghost Train · Fake Pause · Sword Wave · Chrono", "cg_lv": 90, "icon": "s2_boss_chrono" },
	{ "ch": 10, "act": 2, "zh": "第10章 · 根源覆写与 NULL", "en": "CH.10 · Root Overwrite & NULL", "theme_zh": "读写管理权限 · 热修补丁 · 主动收剑 · NULL", "theme_en": "R/W/Admin Perm · Patches · Sheathe · NULL", "cg_lv": 100, "icon": "s2_boss_null" },
	{ "ch": 11, "act": 3, "zh": "第11章 · 晴空生态：田园无善意", "en": "CH.11 · Arcadia: No Kind Meadow", "theme_zh": "四色云海 · 五绿管 · 氮气瓢虫 · 绵羊云王", "theme_en": "4-State Clouds · 5 Pipes · Ladybug · Cloud-Ram", "cg_lv": 110, "icon": "s3_boss_110" },
	{ "ch": 12, "act": 3, "zh": "第12章 · 飞瀑水渠与压力工程", "en": "CH.12 · Aqueduct Pressure Works", "theme_zh": "上吸下喷 · 镜面拧阀 · 鼹鼠扳手 · 九头巨管王", "theme_en": "Suction/Jet · Mirror Valve · Mole · Hydra-Pipe", "cg_lv": 120, "icon": "s3_boss_120" },
	{ "ch": 13, "act": 3, "zh": "第13章 · 翠竹忍林与替身战争", "en": "CH.13 · Bamboo Ninja & Decoy War", "theme_zh": "忍狸木桩 · 拨动日晷 · 慢放刀客 · 九尾宗师", "theme_en": "Tanuki Log · Sundial · Slow Blade · Nine-Tail", "cg_lv": 130, "icon": "s3_boss_130" },
	{ "ch": 14, "act": 3, "zh": "第14章 · 苍穹云海与飞行战", "en": "CH.14 · Sky Sea & Aerial Combat", "theme_zh": "墨镜烈日 · 折叠飞翼 · 磁极渡轮 · 雷云魔神", "theme_en": "Blazing Sun · Fold Wings · Ferry · Thunder Demon", "cg_lv": 140, "icon": "s3_boss_140" },
	{ "ch": 15, "act": 3, "zh": "第15章 · 曜金圣殿与终章", "en": "CH.15 · Solaris Sanctuary Finale", "theme_zh": "圣殿四艺 · 倒悬金塔 · 五阶破甲 · SOLARIS", "theme_en": "Four Arts · Inverted Spire · 5-Phase SOLARIS", "cg_lv": 150, "icon": "s3_boss_150" }
]

var save: SaveManager
var shop: ShopSystem
var engine: Variant
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
var hall_view_mode: String = "stages" # "chapters" (15-chapter cards) or "stages" (10-stage grid)
var options_tab: String = "config"
var ach_filter: String = "all"
var lore_cat: String = "intro"
var reset_confirm_armed: bool = false

var max_hint_tier_this_attempt: int = 0

var cg_slides: Array = []
var cg_index: int = 0
var cg_after_stage_id: int = 0

var anim_time: float = 0.0
var clear_medal_anim_t: float = 0.0

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

# Accessibility Visual Audio Subtitle Entries
var active_subtitles: Array = []

# Dynamic Safe-Area Insets
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
var btn_title_chapters: Button
var btn_title_gallery: Button

# HUD Views
var hud_view: Control
var hud_tl_vbox: VBoxContainer
var hud_tl_hbox: HBoxContainer
var hud_stage_title_lbl: Label
var hud_bars_canvas: Control
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
var subtitle_overlay_canvas: Control
var btn_hud_next: Button
var btn_hud_reset: Button
var btn_hud_hint: Button
var btn_hud_gear: Button

# High-Speed Multi-Touch & Vector Gamepad State
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
	"sheathe": false,
	"interact": false,
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
	"sheathe": false,
	"interact": false,
	"bomb": false,
	"layer": false,
	"gold": false
}
var touch_latched_press: Dictionary = {
	"left": false, "right": false, "down": false, "jump": false,
	"shoot": false, "slash": false, "sheathe": false, "interact": false,
	"bomb": false, "layer": false, "gold": false
}
var touch_latched_release: Dictionary = {
	"left": false, "right": false, "down": false, "jump": false,
	"shoot": false, "slash": false, "sheathe": false, "interact": false,
	"bomb": false, "layer": false, "gold": false
}
var mouse_pad_pressed: bool = false
var mouse_pad_role: String = ""
var mouse_pad_start: Vector2 = Vector2.ZERO
var mouse_pad_min_y: float = 0.0
var mouse_pad_pos: Vector2 = Vector2.ZERO

# Single-Channel Subpixel Kinetic Scroll Controller (`SmoothScrollBox`)
var active_sliders: Array[HSlider] = []
var opt_scroll_clip: Control
var opt_body_vbox: VBoxContainer
var opt_scroll_y: float = 0.0

var hall_chapters_clip: Control
var hall_chapters_vbox: VBoxContainer
var hall_chapters_scroll_y: float = 0.0

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
var hall_medal_sum_lbl: Label
var hall_mode_toggle_btn: Button
var hall_cg_shortcut_btn: Button
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
var death_obs_tip_lbl: Label
var death_stat_lbl: Label
var btn_death_retry: Button
var btn_death_hint: Button
var btn_death_hall: Button

var hint_panel: PanelContainer
var hint_title_lbl: Label
var hint_quote_lbl: Label
var hint_tier_btns: Dictionary = {}
var hint_medal_note_lbl: Label
var hint_blueprint: HintBlueprintView
var hint_illust_rect: TextureRect
var btn_hint_xray: Button
var btn_hint_resume: Button

var clear_panel: PanelContainer
var clear_title_lbl: Label
var clear_sub_lbl: Label
var clear_medals_canvas: Control
var clear_medals_data: Dictionary = {}
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
var btn_cg_skip: Button
var btn_cg_prev: Button
var btn_cg_next: Button

var exit_panel: PanelContainer
var exit_title_lbl: Label
var exit_desc_lbl: Label
var btn_exit_standby: Button
var btn_exit_quit: Button
var btn_exit_cancel: Button

var standby_veil: Button

# ==============================================================================
# SAFE ENGINE / WORLDSTATE / SAVE INTROSPECTION HELPERS
# ==============================================================================
func _eng_get(prop_name: String, fallback: Variant) -> Variant:
	if engine == null:
		return fallback
	if typeof(engine) == TYPE_OBJECT:
		var val: Variant = (engine as Object).get(prop_name)
		if val != null:
			return val
	elif typeof(engine) == TYPE_DICTIONARY:
		return (engine as Dictionary).get(prop_name, fallback)
	return fallback

func _eng_set_if_has(prop_name: String, value: Variant) -> void:
	if engine == null or typeof(engine) != TYPE_OBJECT:
		return
	var obj: Object = engine as Object
	for p_info_v in obj.get_property_list():
		var p_info: Dictionary = p_info_v
		if str(p_info.get("name", "")) == prop_name:
			obj.set(prop_name, value)
			return

func _eng_call(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if engine != null and typeof(engine) == TYPE_OBJECT and (engine as Object).has_method(method_name):
		return (engine as Object).callv(method_name, args)
	return fallback

func _ws_get(prop_name: String, fallback: Variant) -> Variant:
	var ws: Variant = _eng_get("world_state", null)
	if ws != null and typeof(ws) == TYPE_OBJECT:
		var v: Variant = (ws as Object).get(prop_name)
		if v != null:
			return v
	return _eng_get(prop_name, fallback)

func _player_dict() -> Dictionary:
	var p: Variant = _eng_get("player", {})
	if typeof(p) == TYPE_DICTIONARY:
		return p
	return {}

func _cur_lv_id() -> int:
	return int(_eng_get("lv_id", 1))

func _cur_lv_data() -> Dictionary:
	var d: Variant = _eng_get("lv_data", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _levels_map() -> Dictionary:
	var m: Variant = _eng_get("levels_by_id", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}

func _is_dual_layer_stage() -> bool:
	var res: Variant = _eng_call("is_dual_layer_active", [], null)
	if res != null:
		return bool(res)
	var lv: Dictionary = _cur_lv_data()
	var props: Dictionary = lv.get("props", {})
	return bool(props.get("dualLayer", false))

func _is_sword_enabled() -> bool:
	var res: Variant = _eng_call("is_magic_sword_enabled", [], null)
	if res != null:
		return bool(res)
	var p: Dictionary = _player_dict()
	return save.magic_sword_unlocked or save.is_stage_cleared(50) or _cur_lv_id() >= 51 or bool(p.get("sword_up", false))

func _is_player_sheathed(p: Dictionary) -> bool:
	return bool(p.get("sheathed", p.get("sword_sheathed", _eng_get("sword_sheathed", false))))

func setup(
	p_save: SaveManager,
	p_shop: ShopSystem,
	p_engine: Variant,
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

	if audio != null:
		audio.visual_subtitles_enabled = save.visual_captions_on
		if not audio.visual_audio_cue.is_connected(_on_audio_visual_cue):
			audio.visual_audio_cue.connect(_on_audio_visual_cue)

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

func _tex(key: String) -> Texture2D:
	if textures.has(key):
		return textures[key]
	if UI_TEX_ALIASES.has(key) and textures.has(str(UI_TEX_ALIASES[key])):
		return textures[str(UI_TEX_ALIASES[key])]
	return null

func _format_time_sec(sec: float) -> String:
	if sec <= 0.0 or sec >= 99999.0:
		return "--:--"
	var mins: int = int(floorf(sec / 60.0))
	var rem: float = sec - float(mins) * 60.0
	return "%02d:%04.1f" % [mins, rem]

func sync_safe_area_and_layout() -> void:
	var vp_sz: Vector2 = get_viewport_rect().size
	var vw: float = maxf(960.0, vp_sz.x)
	var vh: float = maxf(540.0, vp_sz.y)

	var min_h_pad: float = 34.0 if (is_mobile_platform or vw > 980.0) else 20.0
	var min_top_pad: float = 18.0 if is_mobile_platform else 12.0
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

	if hud_tl_vbox != null:
		hud_tl_vbox.position = Vector2(safe_left, safe_top)
	if hud_tr_hbox != null:
		hud_tr_hbox.offset_left = -(safe_right + 286.0)
		hud_tr_hbox.offset_right = -safe_right
		hud_tr_hbox.offset_top = safe_top
		hud_tr_hbox.offset_bottom = safe_top + 52.0

	last_pad_sig = ""
	if touch_overlay != null:
		touch_overlay.queue_redraw()
	if hud_bars_canvas != null:
		hud_bars_canvas.queue_redraw()

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
# 1. TITLE SCREEN (Locked 960x540 16:9 UI Frame + Chapter / Gallery Quick Pills)
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

	# Top-right Quick Bar: 15-Chapter Cards + CG Gallery + Language Switch
	var tr_quick: HBoxContainer = HBoxContainer.new()
	tr_quick.anchor_left = 1.0
	tr_quick.anchor_right = 1.0
	tr_quick.offset_left = -362.0
	tr_quick.offset_right = -18.0
	tr_quick.offset_top = 18.0
	tr_quick.offset_bottom = 56.0
	tr_quick.alignment = BoxContainer.ALIGNMENT_END
	tr_quick.add_theme_constant_override("separation", 8)
	title_safe_frame.add_child(tr_quick)

	btn_title_chapters = Button.new()
	btn_title_chapters.custom_minimum_size = Vector2(114.0, 36.0)
	btn_title_chapters.pressed.connect(func() -> void:
		audio.play_named("coin", 1.06)
		hall_view_mode = "chapters"
		open_level_select_from_title()
	)
	tr_quick.add_child(btn_title_chapters)

	btn_title_gallery = Button.new()
	btn_title_gallery.custom_minimum_size = Vector2(114.0, 36.0)
	btn_title_gallery.pressed.connect(func() -> void:
		audio.play_named("coin", 1.06)
		open_options_modal("lore")
	)
	tr_quick.add_child(btn_title_gallery)

	btn_title_lang = Button.new()
	btn_title_lang.custom_minimum_size = Vector2(92.0, 36.0)
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
	tr_quick.add_child(btn_title_lang)

	var left_col: Control = Control.new()
	left_col.position = Vector2(42.0, 84.0)
	left_col.size = Vector2(344.0, 378.0)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_safe_frame.add_child(left_col)

	title_logo_tex = TextureRect.new()
	title_logo_tex.position = Vector2(0.0, 0.0)
	title_logo_tex.size = Vector2(336.0, 118.0)
	title_logo_base_y = 0.0
	title_logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(title_logo_tex)

	var menu_vbox: VBoxContainer = VBoxContainer.new()
	menu_vbox.position = Vector2(54.0, 134.0)
	menu_vbox.size = Vector2(216.0, 208.0)
	menu_vbox.add_theme_constant_override("separation", 12)
	left_col.add_child(menu_vbox)

	btn_start_img = _make_arcade_img_btn("btn_start_zh", Vector2(212.0, 58.0))
	btn_start_img.pressed.connect(func() -> void:
		audio.play_named("coin", 1.05)
		hall_view_mode = "stages"
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
# 2. IN-GAME HUD (Stage Title, Dual Poison/Cure Bars, Wing/Sun Gauges, Shield Tag,
#    Gravity/Mirror, Layer/Perm, Sheathe Badge, Carried Item, Boss Armor+HP, Subtitles)
# ==============================================================================
func _build_hud_view() -> void:
	hud_view = Control.new()
	hud_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_view)

	hud_tl_vbox = VBoxContainer.new()
	hud_tl_vbox.position = Vector2(safe_left, safe_top)
	hud_tl_vbox.add_theme_constant_override("separation", 4)
	hud_tl_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_view.add_child(hud_tl_vbox)

	hud_tl_hbox = HBoxContainer.new()
	hud_tl_hbox.add_theme_constant_override("separation", 8)
	hud_tl_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_tl_vbox.add_child(hud_tl_hbox)

	btn_hud_grid = _make_icon_slot_button("ui_grid", 50.0, Color("#00f5ff"), "选关")
	btn_hud_grid.pressed.connect(_on_hud_grid_pressed)
	hud_tl_hbox.add_child(btn_hud_grid)

	var tl_info_vb: VBoxContainer = VBoxContainer.new()
	tl_info_vb.add_theme_constant_override("separation", 3)
	tl_info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_tl_hbox.add_child(tl_info_vb)

	hud_stage_title_lbl = Label.new()
	hud_stage_title_lbl.add_theme_font_size_override("font_size", 12)
	hud_stage_title_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	hud_stage_title_lbl.add_theme_color_override("font_outline_color", Color("#020617"))
	hud_stage_title_lbl.add_theme_constant_override("outline_size", 3)
	hud_stage_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_info_vb.add_child(hud_stage_title_lbl)

	hud_buff_box = HBoxContainer.new()
	hud_buff_box.add_theme_constant_override("separation", 5)
	hud_buff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_info_vb.add_child(hud_buff_box)

	hud_chip_pool.clear()
	for _i in range(14):
		var pc: PanelContainer = PanelContainer.new()
		pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.visible = false
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr: TextureRect = TextureRect.new()
		tr.custom_minimum_size = Vector2(18.0, 18.0)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
		var lb: Label = Label.new()
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", Color("#f8fafc"))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(lb)
		pc.add_child(hb)
		hud_buff_box.add_child(pc)
		hud_chip_pool.append({ "panel": pc, "icon": tr, "label": lb, "border_hex": "" })

	# Dynamic Status Bars Canvas (Poison/Antidote dual-window, Shadow Wing Fuel, Sun Heat)
	hud_bars_canvas = Control.new()
	hud_bars_canvas.custom_minimum_size = Vector2(460.0, 44.0)
	hud_bars_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bars_canvas.draw.connect(_draw_hud_status_bars)
	hud_tl_vbox.add_child(hud_bars_canvas)

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
	center_vbox.offset_left = -240.0
	center_vbox.offset_right = 240.0
	center_vbox.offset_top = 14.0
	center_vbox.offset_bottom = 140.0
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

	# Accessibility Audio-Visual Subtitle Floating Overlay (Master GDD 10 & 11.3)
	subtitle_overlay_canvas = Control.new()
	subtitle_overlay_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subtitle_overlay_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_overlay_canvas.draw.connect(_draw_visual_subtitles)
	hud_view.add_child(subtitle_overlay_canvas)

func _on_audio_visual_cue(cue: Dictionary) -> void:
	if not save.visual_captions_on or not in_game:
		return
	push_visual_subtitle(
		str(cue.get("zh", "")),
		str(cue.get("en", "")),
		str(cue.get("icon", "ui_audio")),
		str(cue.get("color", "#00f5ff")),
		str(cue.get("wave", "chime")),
		1.85,
		str(cue.get("sfx", ""))
	)

func push_visual_subtitle(
	zh_txt: String,
	en_txt: String,
	icon_key: String = "ui_audio",
	color_hex: String = "#00f5ff",
	wave_type: String = "chime",
	dur: float = 1.80,
	tag: String = ""
) -> void:
	if not save.visual_captions_on:
		return
	if tag != "":
		for ex_v in active_subtitles:
			var ex: Dictionary = ex_v
			if str(ex.get("tag", "")) == tag:
				ex["zh"] = zh_txt
				ex["en"] = en_txt
				ex["icon"] = icon_key
				ex["color"] = color_hex
				ex["wave"] = wave_type
				ex["life"] = maxf(float(ex.get("life", 0.0)), dur)
				ex["max_life"] = maxf(float(ex.get("max_life", 0.2)), dur)
				if subtitle_overlay_canvas != null:
					subtitle_overlay_canvas.queue_redraw()
				return
	active_subtitles.append({
		"zh": zh_txt,
		"en": en_txt,
		"icon": icon_key,
		"color": color_hex,
		"wave": wave_type,
		"life": dur,
		"max_life": dur,
		"tag": tag
	})
	while active_subtitles.size() > 3:
		active_subtitles.pop_front()
	if subtitle_overlay_canvas != null:
		subtitle_overlay_canvas.queue_redraw()

func _draw_visual_subtitles() -> void:
	if not save.visual_captions_on or active_subtitles.is_empty() or font_main == null:
		return
	var vw: float = maxf(960.0, size.x)
	var vh: float = maxf(540.0, size.y)
	# Positioned cleanly in upper-bottom-center above virtual controls so it never blocks character or buttons
	var base_y: float = vh - maxf(24.0, safe_bottom) - (116.0 if is_touch_pad_visible() else 36.0)
	for i in range(active_subtitles.size()):
		var sub: Dictionary = active_subtitles[active_subtitles.size() - 1 - i]
		var life_r: float = clampf(float(sub.get("life", 0.0)) / maxf(0.15, float(sub.get("max_life", 1.8))), 0.0, 1.0)
		var alpha: float = clampf(life_r * 3.2, 0.0, 1.0)
		var txt: String = str(sub.get("en" if save.lang == "en" else "zh", ""))
		if txt == "":
			continue
		var col: Color = Color(str(sub.get("color", "#00f5ff")))
		var box_w: float = clampf(float(txt.length()) * 13.5 + 84.0, 240.0, 480.0)
		var box_h: float = 28.0
		var bx: float = (vw - box_w) * 0.5
		var by: float = base_y - float(i) * 33.0
		subtitle_overlay_canvas.draw_rect(Rect2(bx, by, box_w, box_h), Color(0.02, 0.05, 0.16, 0.88 * alpha), true)
		subtitle_overlay_canvas.draw_rect(Rect2(bx, by, box_w, box_h), Color(col.r, col.g, col.b, 0.92 * alpha), false, 1.6)

		var ic_tex: Texture2D = _tex(str(sub.get("icon", "ui_audio")))
		if ic_tex != null:
			subtitle_overlay_canvas.draw_texture_rect(ic_tex, Rect2(bx + 7.0, by + 4.0, 20.0, 20.0), false, Color(1.0, 1.0, 1.0, alpha))

		# Animated 4-bar equalizer sound-wave icon
		var wave_x0: float = bx + 31.0
		for wb in range(4):
			var wh: float = 4.0 + 12.0 * absf(sin(anim_time * (9.0 + float(wb) * 2.3) + float(i)))
			subtitle_overlay_canvas.draw_rect(
				Rect2(wave_x0 + float(wb) * 4.5, by + 14.0 - wh * 0.5, 3.0, wh),
				Color(col.r, col.g, col.b, alpha),
				true
			)

		subtitle_overlay_canvas.draw_string(
			font_main,
			Vector2(bx + 54.0, by + 19.0),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			box_w - 62.0,
			12,
			Color(1.0, 1.0, 1.0, alpha)
		)

func _draw_hud_status_bars() -> void:
	if not in_game or font_main == null:
		return
	var p: Dictionary = _player_dict()
	if p.is_empty():
		return

	var bars: Array = []
	var poison_t: float = float(p.get("poison_timer", 0.0))
	var poison_max: float = maxf(6.0, float(p.get("poison_max", 8.0)))
	if poison_t > 0.01:
		bars.append({
			"icon": "icon_poison",
			"label": (_tr("▲毒态 ", "▲TOXIN ") if save.colorblind_mode else _tr("毒态 ", "TOXIN ")) + "%.1fs" % poison_t,
			"ratio": clampf(poison_t / poison_max, 0.0, 1.0),
			"sub_tick": -1.0,
			"col": Color("#a3e635")
		})

	var cure_t: float = float(p.get("antidote_window", 0.0))
	var cure_max: float = maxf(4.0, float(p.get("antidote_max", 5.0)))
	var plant_short_t: float = float(p.get("antidote_short_window", p.get("plant_cure_window", cure_t * 0.5)))
	if cure_t > 0.01:
		bars.append({
			"icon": "item_antidote",
			"label": (_tr("◆解毒双窗 ", "◆CURE WIN ") if save.colorblind_mode else _tr("解毒窗 ", "CURE ")) + "%.1fs" % cure_t,
			"ratio": clampf(cure_t / cure_max, 0.0, 1.0),
			"sub_tick": clampf(plant_short_t / cure_max, 0.15, 0.85),
			"col": Color("#38bdf8")
		})

	var has_wings: bool = bool(p.get("has_flight", false))
	var wing_fuel: float = float(p.get("wing_fuel", p.get("flight_energy", -1.0)))
	var shadow_len: float = float(_ws_get("shadow_length_px", 64.0))
	if has_wings:
		var w_ratio: float = clampf(wing_fuel / 100.0, 0.0, 1.0) if wing_fuel >= 0.0 else clampf(shadow_len / 220.0, 0.12, 1.0)
		var folded_s: String = _tr("[折翼]", "[FOLD]") if bool(p.get("wings_folded", false)) else ""
		bars.append({
			"icon": "icon_wing",
			"label": _tr("影翼续航%s %.0f%%" % [folded_s, w_ratio * 100.0], "SHADOW WING%s %.0f%%" % [folded_s, w_ratio * 100.0]),
			"ratio": w_ratio,
			"sub_tick": -1.0,
			"col": Color("#67e8f9")
		})

	var heat_v: float = maxf(float(p.get("heat_meter", 0.0)), float(_ws_get("sun_heat", 0.0)))
	if heat_v > 1.0 or (_cur_lv_id() in [68, 132, 133, 141, 149, 150] and heat_v > 0.05):
		var h_ratio: float = clampf(heat_v / 100.0, 0.0, 1.0)
		bars.append({
			"icon": "s3_sun_angry",
			"label": _tr("☀太阳热量 %.0f%%" % (h_ratio * 100.0), "☀SOLAR HEAT %.0f%%" % (h_ratio * 100.0)),
			"ratio": h_ratio,
			"sub_tick": 0.75,
			"col": Color("#fb7185") if h_ratio >= 0.75 else Color("#fb923c")
		})

	hud_bars_canvas.visible = not bars.is_empty()
	if bars.is_empty():
		return

	for i in range(mini(3, bars.size())):
		var b: Dictionary = bars[i]
		var bx: float = 4.0 + float(i) * 168.0
		var by: float = 2.0
		var bw: float = 160.0
		var bh: float = 18.0
		var col: Color = b["col"]
		hud_bars_canvas.draw_rect(Rect2(bx, by, bw, bh), Color(0.02, 0.05, 0.16, 0.88), true)
		hud_bars_canvas.draw_rect(Rect2(bx + 22.0, by + 3.0, (bw - 25.0) * float(b["ratio"]), bh - 6.0), Color(col.r, col.g, col.b, 0.55), true)
		var sub_t: float = float(b["sub_tick"])
		if sub_t > 0.0:
			var tx: float = bx + 22.0 + (bw - 25.0) * sub_t
			hud_bars_canvas.draw_line(Vector2(tx, by + 2.0), Vector2(tx, by + bh - 2.0), Color("#fde047"), 2.0)
		hud_bars_canvas.draw_rect(Rect2(bx, by, bw, bh), col, false, 1.2)
		var ic: Texture2D = _tex(str(b["icon"]))
		if ic != null:
			hud_bars_canvas.draw_texture_rect(ic, Rect2(bx + 3.0, by + 1.0, 16.0, 16.0), false)
		hud_bars_canvas.draw_string(font_main, Vector2(bx + 24.0, by + 13.5), str(b["label"]), HORIZONTAL_ALIGNMENT_LEFT, bw - 26.0, 10, Color.WHITE)

func _on_hud_grid_pressed() -> void:
	audio.play_named("block", 1.04)
	open_level_select_modal()

func _on_hud_next_pressed() -> void:
	var nxt: int = _cur_lv_id() + 1
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
	# Master GDD 11.2: 3-tier progressive hint is ALWAYS accessible (Light hint never spoils!)
	audio.play_named("hint_popup", 1.02)
	open_hint_modal()

func _on_hud_gear_pressed() -> void:
	audio.play_named("block", 1.0)
	open_options_modal("config")

func refresh_hud() -> void:
	var p: Dictionary = _player_dict()
	if not in_game or p.is_empty():
		return

	var lv_id: int = _cur_lv_id()
	var lv: Dictionary = _cur_lv_data()
	var st_title: String = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	if hud_stage_title_lbl != null:
		var assist_tag: String = _tr(" [辅助]", " [ASSIST]") if save.assist_mode else ""
		hud_stage_title_lbl.text = "LV.%03d · %s%s" % [lv_id, st_title, assist_tag]

	var items: Array = []
	var coin_weight: int = int(p.get("carried_coins", p.get("coin_weight", 0)))
	var coin_lbl: String = ("%d (%+dkg)" % [save.coins, coin_weight]) if coin_weight > 0 else str(save.coins)
	items.append(["coin_gold", coin_lbl, "#fde047"])

	# Shield + Protection Category / Cache Tag (Master GDD 5.2 & Lv.011 / Lv.033)
	if bool(p.get("shield", false)):
		var sh_tag: String = str(p.get("shield_cache", p.get("shield_tag", "STD"))).to_upper()
		if sh_tag == "NONE" or sh_tag == "":
			sh_tag = "STD"
		items.append(["shield_orb", sh_tag, "#38bdf8"])

	if float(p.get("golden_timer", 0.0)) > 0.0:
		items.append(["ui_btn_gold", "%.1fs" % float(p["golden_timer"]), "#fde047"])
	elif int(p.get("gold_charges", 0)) > 0:
		items.append(["ui_btn_gold", "x1", "#fde047"])

	if int(p.get("max_jumps", 1)) >= 2 and not bool(p.get("has_flight", false)):
		var j_txt: String = "x3▼" if int(p["max_jumps"]) >= 3 else ("x%d" % int(p["max_jumps"]))
		items.append(["icon_spring", j_txt, "#4ade80"])

	if bool(p.get("has_wall_phase", false)):
		items.append(["hud_wall_phase", "PHASE", "#c084fc"])

	# Sword + Active Sheathe Stance Badge (`收剑中/持剑`)
	var sheathed_now: bool = _is_player_sheathed(p)
	if sheathed_now:
		items.append(["icon_sword", _tr("收剑中", "SHEATHED"), "#4ade80"])
	elif _is_sword_enabled():
		items.append(["sword_pickup", _tr("持剑+", "SWORD+") if bool(p.get("sword_up", false)) else _tr("持剑", "DRAWN"), "#00f5ff"])

	if bool(p.get("bullet_up", false)):
		items.append(["bullet_up", "FIRE+", "#fb923c"])

	if int(p.get("bombs", 0)) > 0:
		items.append(["bomb", "x%d" % int(p["bombs"]), "#f43f5e"])

	# Persistent Gravity Direction Badge (↑ / ↓ / ← / → + material memory)
	var g_vec: Variant = _ws_get("gravity_vec", Vector2(0.0, float(p.get("grav_dir", 1.0))))
	var gv: Vector2 = (g_vec as Vector2) if typeof(g_vec) == TYPE_VECTOR2 else Vector2(0.0, float(p.get("grav_dir", 1.0)))
	if gv.y < -0.2 or absf(gv.x) > 0.2:
		var g_arrow: String = "↑" if gv.y < -0.2 else ("←" if gv.x < -0.2 else ("→" if gv.x > 0.2 else "↓"))
		items.append(["gravity_pad", _tr("重力%s" % g_arrow, "GRAV%s" % g_arrow), "#fb7185"])

	# Persistent Mirror / Brain-Split Input Reversal Badge
	var is_mirrored: bool = bool(p.get("in_curse_mirror", false)) or float(p.get("reverse_curse_timer", 0.0)) > 0.0 or bool(_eng_get("mirror_input_active", false))
	if is_mirrored:
		items.append(["s2_curse_totem", _tr("⇄镜像反转", "⇄MIRROR"), "#f472b6"])

	# Foreground / Background Layer Badge (`表层/里层`)
	if _is_dual_layer_stage():
		var act_l: int = int(_eng_get("active_layer", _ws_get("active_layer", 0)))
		var l_txt: String = _tr("里层BG" if act_l == 1 else "表层FG", "BG-B" if act_l == 1 else "FG-A")
		items.append(["s2_ui_layer_btn", l_txt, "#c084fc" if act_l == 1 else "#00f5ff"])

	# Root Permission Badge (`READ` / `WRITE` / `ADMIN`)
	var perm_s: String = str(_ws_get("root_permission", "NONE")).to_upper()
	if perm_s != "" and perm_s != "NONE":
		var perm_col: String = "#4ade80" if perm_s == "READ" else ("#fde047" if perm_s == "WRITE" else "#fb7185")
		items.append(["s2_root_term", perm_s, perm_col])

	# Carried Item Slot (Spore Key, Patch Chip, Root Key, Battery, Receipt, Gems)
	var carry_d: Variant = _eng_get("carrying_item", {})
	if typeof(carry_d) == TYPE_DICTIONARY and not (carry_d as Dictionary).is_empty():
		var cd: Dictionary = carry_d
		var ct: String = str(cd.get("t", cd.get("kind", "")))
		var c_icon: String = "s2_battery"
		var c_name: String = str(cd.get("badgeCode", "ITEM"))
		if "spore" in ct:
			c_icon = "v2_spore_key"
			c_name = _tr("孢子钥", "SPORE")
		elif "patch" in ct:
			c_icon = "v2_patch_chip"
			c_name = str(cd.get("patchId", "PATCH"))
		elif ct == "root_item":
			c_icon = "s2_root_key"
			c_name = str(cd.get("badgeCode", "KEY"))
		items.append([c_icon, c_name, "#fde047"])
	elif bool(p.get("has_spore_key", false)):
		items.append(["v2_spore_key", _tr("孢子钥", "SPORE"), "#4ade80"])
	elif bool(p.get("has_receipt", false)):
		items.append(["ui_hint", _tr("收据", "RECEIPT"), "#fde047"])

	var gems_arr: Variant = _eng_get("collected_gems", [])
	if typeof(gems_arr) == TYPE_ARRAY and not (gems_arr as Array).is_empty():
		var ga: Array = gems_arr
		var last_g: String = str(ga[ga.size() - 1])
		items.append(["gem_" + last_g, "x%d" % ga.size(), "#fde047"])

	var t_left: float = float(_eng_get("timer_left", -1.0))
	if t_left >= 0.0:
		items.append(["clock_item", "%.1fs" % maxf(0.0, t_left), "#fb7185"])

	var sig: String = str(items) + "|" + hud_stage_title_lbl.text
	if sig != last_hud_sig:
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
					pc.add_theme_stylebox_override("panel", _make_flat_box(Color(0.03, 0.07, 0.22, 0.90), Color(c_hex), 1, 8, 7, 3))
				pc.visible = true
			else:
				pc.visible = false

	if hud_bars_canvas != null:
		hud_bars_canvas.queue_redraw()

# ==============================================================================
# 3. DUAL-END ANDROID TOUCH + PC KEYBOARD GAMEPAD (Sheathe `H`, Interact `F`, Layer `E`)
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
	var p: Dictionary = _player_dict()
	if not is_touch_pad_visible() or p.is_empty():
		pad_buttons.clear()
		last_pad_sig = ""
		return

	var vw: float = maxf(960.0, size.x)
	var vh: float = maxf(540.0, size.y)
	var has_sword: bool = _is_sword_enabled()
	var sheathed_now: bool = _is_player_sheathed(p)
	var has_layer: bool = _is_dual_layer_stage()
	var b_cnt: int = int(p.get("bombs", 0))
	var g_on: bool = int(p.get("gold_charges", 0)) > 0 or float(p.get("golden_timer", 0.0)) > 0.0
	var g_lbl: String = ("%.0f" % float(p["golden_timer"])) if float(p.get("golden_timer", 0.0)) > 0.0 else "G"
	var act_l: int = int(_eng_get("active_layer", _ws_get("active_layer", 0)))
	var l_lbl: String = "B" if act_l == 1 else "A"
	var sh_lbl: String = _tr("拔剑" if sheathed_now else "收剑", "DRAW" if sheathed_now else "SHTH")
	var int_lbl: String = _tr("交互", "ACT")

	var sig: String = "%.0f_%.0f_%.0f_%.0f_%.2f_%s_%s_%s_%s_%d_%s_%s_%s_%s" % [
		vw, vh, safe_left, safe_right, save.pad_scale, str(save.pad_swap),
		str(has_sword), str(sheathed_now), str(has_layer), b_cnt, str(g_on), g_lbl, l_lbl, save.lang
	]
	if not force and sig == last_pad_sig and not pad_buttons.is_empty():
		return
	last_pad_sig = sig
	pad_buttons.clear()

	var sc: float = clampf(save.pad_scale, 0.70, 1.45)
	var swap: bool = save.pad_swap

	var dpad_w: float = 80.0 * sc
	var dpad_h: float = 62.0 * sc
	var down_sz: float = 62.0 * sc
	var jump_sz: float = 84.0 * sc
	var act_sz: float = 64.0 * sc
	var sub_sz: float = 54.0 * sc
	var pad_l: float = maxf(26.0, safe_left)
	var pad_r: float = maxf(26.0, safe_right)
	var base_y: float = vh - maxf(18.0, safe_bottom)

	var move_on_left: bool = not swap
	var dpad_total_w: float = dpad_w * 2.0 + down_sz + 18.0 * sc
	var left_x0: float = pad_l if move_on_left else (vw - pad_r - dpad_total_w)
	var act_right_edge: float = (vw - pad_r) if move_on_left else (pad_l + jump_sz + act_sz + sub_sz + 32.0 * sc)

	dpad_left_rect = Rect2(left_x0, base_y - dpad_h, dpad_w, dpad_h)
	dpad_right_rect = Rect2(left_x0 + dpad_w + 9.0 * sc, base_y - dpad_h, dpad_w, dpad_h)
	dpad_down_rect = Rect2(left_x0 + dpad_w * 2.0 + 18.0 * sc, base_y - down_sz, down_sz, down_sz)
	dpad_zone_rect = Rect2(left_x0 - 22.0 * sc, base_y - dpad_h - 42.0 * sc, dpad_total_w + 44.0 * sc, dpad_h + 66.0 * sc)

	pad_buttons.append({ "action": "left", "tex": "ui_btn_left", "rect": dpad_left_rect, "label": "", "cluster": "dpad" })
	pad_buttons.append({ "action": "right", "tex": "ui_btn_right", "rect": dpad_right_rect, "label": "", "cluster": "dpad" })
	pad_buttons.append({ "action": "down", "tex": "ui_pipe_down", "rect": dpad_down_rect, "label": "", "cluster": "dpad" })

	var jx: float = act_right_edge - jump_sz
	var jy: float = base_y - jump_sz
	pad_buttons.append({ "action": "jump", "tex": "ui_btn_jump", "rect": Rect2(jx, jy, jump_sz, jump_sz), "label": "", "cluster": "action" })

	var sx: float = jx - act_sz - 10.0 * sc
	var sy: float = base_y - act_sz
	pad_buttons.append({ "action": "shoot", "tex": "ui_btn_bullet", "rect": Rect2(sx, sy, act_sz, act_sz), "label": "", "cluster": "action" })

	# Context Interact / Pick-Place-Throw Button (`F` / Touch Interact)
	var ix: float = sx - sub_sz - 10.0 * sc
	var iy: float = base_y - sub_sz
	pad_buttons.append({ "action": "interact", "tex": "ui_btn_check", "rect": Rect2(ix, iy, sub_sz, sub_sz), "label": int_lbl, "cluster": "action" })

	# Sword Slash + Dedicated Sheathe Toggle (`H` / Touch Sheathe)
	var top_mid_y: float = sy - act_sz - 9.0 * sc
	if has_sword or _cur_lv_id() in [50, 62, 99, 100, 129, 135, 148, 150]:
		pad_buttons.append({ "action": "slash", "tex": "ui_btn_melee", "rect": Rect2(sx, top_mid_y, act_sz, act_sz), "label": "", "cluster": "action" })
		pad_buttons.append({
			"action": "sheathe",
			"tex": "icon_sword",
			"rect": Rect2(ix, iy - sub_sz - 9.0 * sc, sub_sz, sub_sz),
			"label": sh_lbl,
			"cluster": "action",
			"highlight": sheathed_now
		})

	var top_act_x: float = jx + (jump_sz - sub_sz) * 0.5
	var top_act_y: float = jy - sub_sz - 9.0 * sc
	if has_layer:
		pad_buttons.append({ "action": "layer", "tex": "ui_btn_layer_touch", "rect": Rect2(top_act_x, top_act_y, sub_sz, sub_sz), "label": l_lbl, "cluster": "action" })
		top_act_y -= (sub_sz + 8.0 * sc)

	if b_cnt > 0:
		pad_buttons.append({ "action": "bomb", "tex": "ui_btn_bomb", "rect": Rect2(top_act_x, top_act_y, sub_sz, sub_sz), "label": str(b_cnt), "cluster": "action" })
		top_act_y -= (sub_sz + 8.0 * sc)

	if g_on:
		pad_buttons.append({ "action": "gold", "tex": "ui_btn_gold", "rect": Rect2(ix - sub_sz - 8.0 * sc, iy, sub_sz, sub_sz), "label": g_lbl, "cluster": "action" })

	var min_ax: float = ix - sub_sz - 28.0 * sc
	var max_ax: float = act_right_edge + 24.0 * sc
	var min_ay: float = minf(top_act_y, top_mid_y - 24.0 * sc)
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
		return [opt_scroll_clip, opt_body_vbox, "options"]
	if active_modal == "hint" and hint_scroll_clip != null and hint_steps_vbox != null:
		return [hint_scroll_clip, hint_steps_vbox, "hint"]
	if active_modal == "hall" and hall_view_mode == "chapters" and hall_chapters_clip != null and hall_chapters_vbox != null:
		return [hall_chapters_clip, hall_chapters_vbox, "chapters"]
	return []

func _get_max_scroll_for(clip: Control, vbox: VBoxContainer) -> float:
	if clip == null or vbox == null:
		return 0.0
	var content_h: float = maxf(vbox.size.y, vbox.get_combined_minimum_size().y)
	var view_h: float = maxf(80.0, clip.size.y)
	return maxf(0.0, content_h - view_h + 18.0)

func _apply_smooth_scroll(target_kind: String, new_y: float) -> void:
	if target_kind == "options":
		var max_s: float = _get_max_scroll_for(opt_scroll_clip, opt_body_vbox)
		opt_scroll_y = clampf(new_y, 0.0, max_s)
		if opt_body_vbox != null:
			opt_body_vbox.position = Vector2(0.0, -opt_scroll_y)
		if opt_scroll_clip != null:
			opt_scroll_clip.queue_redraw()
	elif target_kind == "chapters":
		var max_c: float = _get_max_scroll_for(hall_chapters_clip, hall_chapters_vbox)
		hall_chapters_scroll_y = clampf(new_y, 0.0, max_c)
		if hall_chapters_vbox != null:
			hall_chapters_vbox.position = Vector2(0.0, -hall_chapters_scroll_y)
		if hall_chapters_clip != null:
			hall_chapters_clip.queue_redraw()
	else:
		var max_h: float = _get_max_scroll_for(hint_scroll_clip, hint_steps_vbox)
		hint_scroll_y = clampf(new_y, 0.0, max_h)
		if hint_steps_vbox != null:
			hint_steps_vbox.position = Vector2(0.0, -hint_scroll_y)
		if hint_scroll_clip != null:
			hint_scroll_clip.queue_redraw()

func _get_cur_scroll_val(kind: String) -> float:
	if kind == "options":
		return opt_scroll_y
	if kind == "chapters":
		return hall_chapters_scroll_y
	return hint_scroll_y

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

		if active_modal == "hint" and hint_blueprint != null and hint_blueprint.handle_touch_pan(event):
			return true

		var spair: Array = _get_active_scroll_pair()
		if not spair.is_empty():
			var clip_c: Control = spair[0]
			var s_kind: String = str(spair[2])
			var cur_sy: float = _get_cur_scroll_val(s_kind)
			var clip_r: Rect2 = clip_c.get_global_rect()
			if clip_r.size.x < 40.0 or clip_r.size.y < 40.0:
				var vp_f: Vector2 = get_viewport_rect().size
				clip_r = Rect2(Vector2(maxf(960.0, vp_f.x) * 0.5 - 380.0, 96.0), Vector2(760.0, 360.0))

			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if clip_r.has_point(mb.position):
					if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
						scroll_velocity_y = 0.0
						_apply_smooth_scroll(s_kind, cur_sy + 48.0)
						return true
					elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
						scroll_velocity_y = 0.0
						_apply_smooth_scroll(s_kind, cur_sy - 48.0)
						return true
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						if clip_r.has_point(mb.position) and not _point_hits_any_slider(mb.position):
							scroll_pointer_down = true
							scroll_press_pos = mb.position
							scroll_last_y = mb.position.y
							scroll_is_dragging = false
							scroll_velocity_y = 0.0
							return false
					elif scroll_pointer_down:
						var was_dragging: bool = scroll_is_dragging
						scroll_pointer_down = false
						scroll_is_dragging = false
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
					_apply_smooth_scroll(s_kind, cur_sy - dy_step)
					scroll_velocity_y = lerpf(scroll_velocity_y, -dy_step * 58.0, 0.55)
					return true
			elif event is InputEventScreenDrag and scroll_is_dragging:
				return true

		if active_modal == "hall" and hall_view_mode == "stages" and hall_panel != null and hall_panel.is_visible_in_tree():
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

	if in_game and event is InputEventScreenTouch:
		var st_sec: InputEventScreenTouch = event as InputEventScreenTouch
		if st_sec.index > 0 and st_sec.pressed and _try_secondary_finger_hud_tap(st_sec.position):
			return true

	if in_game and active_modal == "" and not standby_mode and is_touch_pad_visible():
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			if handle_unhandled_gameplay_input(event):
				return true

	return false

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
	elif (not is_mobile_platform) and save.pad_mode == "always" and event is InputEventMouseButton:
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
	elif (not is_mobile_platform) and save.pad_mode == "always" and event is InputEventMouseMotion and mouse_pad_pressed:
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
		push_toast(_tr("通关第 50 关后解锁第二篇章「根源系统篇」！", "Clear Stage 50 to unlock Act II!"), "ui_grid", "#fb7185")
		return
	if target_sec == 3 and not save.is_stage_cleared(100) and not save.is_stage_unlocked(101):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("通关第 100 关后解锁第三篇章「晴空幻境篇」！", "Clear Stage 100 to unlock Act III!"), "ui_grid", "#fb7185")
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

	if dpad_down_rect.grow(12.0).has_point(cur_p):
		touch_state["down"] = true
		return

	if dy >= swipe_thresh:
		touch_state["down"] = true
		swipe_down_hold_timer = maxf(swipe_down_hold_timer, 0.20)
		if dy_from_start > absf(dx) * 1.05 or dy_from_peak >= swipe_thresh + 4.0:
			return

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
	var pad_grow: float = 14.0 * clampf(save.sensitivity, 0.5, 1.5)
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
	var before_state: Dictionary = touch_state.duplicate()
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
			# Swipe-down on Jump button while airborne -> triggers Ground Pound (`down` + `jump`) cleanly!
			if dy_a >= 24.0 and dy_a > absf(dx_a) * 1.25 and not _point_hits_action_btn(cur_p):
				touch_state["down"] = true
				swipe_down_hold_timer = maxf(swipe_down_hold_timer, 0.20)
			else:
				_apply_action_finger(cur_p)
		else:
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

	for k_edge in touch_state.keys():
		var was_on: bool = bool(before_state.get(k_edge, false))
		var now_on: bool = bool(touch_state.get(k_edge, false))
		if now_on and not was_on:
			touch_latched_press[k_edge] = true
		elif (not now_on) and was_on:
			touch_latched_release[k_edge] = true

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
		touch_latched_press[k] = false
		touch_latched_release[k] = false
	if touch_overlay != null:
		touch_overlay.queue_redraw()

func consume_touch_edges() -> Dictionary:
	var jp: bool = bool(touch_latched_press.get("jump", false)) or (bool(touch_state["jump"]) and not bool(prev_touch_state["jump"]))
	var jr: bool = (not jp) and (bool(touch_latched_release.get("jump", false)) or ((not bool(touch_state["jump"])) and bool(prev_touch_state["jump"])))
	var out: Dictionary = {
		"left": bool(touch_state["left"]),
		"right": bool(touch_state["right"]),
		"down": bool(touch_state["down"]) or bool(touch_latched_press.get("down", false)),
		"down_pressed": bool(touch_latched_press.get("down", false)) or (bool(touch_state["down"]) and not bool(prev_touch_state["down"])),
		"jump_held": bool(touch_state["jump"]) or jp,
		"jump_pressed": jp,
		"jump_released": jr,
		"shoot_pressed": bool(touch_latched_press.get("shoot", false)) or (bool(touch_state["shoot"]) and not bool(prev_touch_state["shoot"])),
		"slash_pressed": bool(touch_latched_press.get("slash", false)) or (bool(touch_state["slash"]) and not bool(prev_touch_state["slash"])),
		"sheathe_pressed": bool(touch_latched_press.get("sheathe", false)) or (bool(touch_state["sheathe"]) and not bool(prev_touch_state["sheathe"])),
		"interact_pressed": bool(touch_latched_press.get("interact", false)) or (bool(touch_state["interact"]) and not bool(prev_touch_state["interact"])),
		"interact_held": bool(touch_state["interact"]) or bool(touch_latched_press.get("interact", false)),
		"bomb_pressed": bool(touch_latched_press.get("bomb", false)) or (bool(touch_state["bomb"]) and not bool(prev_touch_state["bomb"])),
		"layer_pressed": bool(touch_latched_press.get("layer", false)) or (bool(touch_state["layer"]) and not bool(prev_touch_state["layer"])),
		"gold_pressed": bool(touch_latched_press.get("gold", false)) or (bool(touch_state["gold"]) and not bool(prev_touch_state["gold"]))
	}
	for k in touch_state.keys():
		prev_touch_state[k] = touch_state[k]
		touch_latched_press[k] = false
		touch_latched_release[k] = false
	if jp and not bool(touch_state["jump"]):
		prev_touch_state["jump"] = true
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
		var hl_active: bool = bool(b.get("highlight", false))
		var draw_r: Rect2 = r.grow(-2.0) if pressed_now else r
		var bg_c: Color = Color(0.05, 0.24, 0.18, alpha_base * 0.92) if hl_active else Color(0.03, 0.06, 0.18, alpha_base * 0.92)
		touch_overlay.draw_rect(draw_r.grow(-2.0), bg_c, true)
		var tint: Color = Color(1.22, 1.22, 1.05, 1.0) if pressed_now else Color(1.0, 1.0, 1.0, alpha_base)
		var tex: Texture2D = _tex(str(b["tex"]))
		if tex != null:
			touch_overlay.draw_texture_rect(tex, draw_r, false, tint)
		else:
			touch_overlay.draw_rect(draw_r, Color(0.05, 0.12, 0.32, alpha_base), true)
			touch_overlay.draw_rect(draw_r, Color("#00f5ff"), false, 2.0)
		if pressed_now or hl_active:
			touch_overlay.draw_rect(draw_r, Color("#4ade80") if hl_active else Color(0.0, 0.96, 1.0, 0.85), false, 2.2)
		var lbl_s: String = str(b.get("label", ""))
		if lbl_s != "" and font_main != null:
			touch_overlay.draw_rect(Rect2(draw_r.position.x + 2.0, draw_r.position.y + draw_r.size.y - 16.0, draw_r.size.x - 4.0, 14.0), Color(0.01, 0.03, 0.10, 0.78 * alpha_base), true)
			touch_overlay.draw_string(
				font_main,
				Vector2(draw_r.position.x + 2.0, draw_r.position.y + draw_r.size.y - 4.5),
				lbl_s,
				HORIZONTAL_ALIGNMENT_CENTER,
				draw_r.size.x - 4.0,
				10,
				Color("#4ade80") if hl_active else Color("#fde047")
			)

# ==============================================================================
# 4. EXCLUSIVE MODALS (15-Chapter Cards + 10-Stage Grid + 4-Medal Icons + Settings/Assist)
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
	pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#060c28"), border_col, 2, 12, 16, 12))
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

#Draws a crisp 4-tier medal badge (Copper / Silver / Gold / Anti-Troll) onto a Control
func _draw_medal_pip(c: Control, center: Vector2, rad: float, tier_key: String, earned: bool) -> void:
	var fill_c: Color = Color(0.14, 0.18, 0.28, 0.55)
	var rim_c: Color = Color(0.35, 0.42, 0.55, 0.45)
	if earned:
		if tier_key == "copper":
			fill_c = Color("#b45309")
			rim_c = Color("#fb923c")
		elif tier_key == "silver":
			fill_c = Color("#475569")
			rim_c = Color("#e2e8f0")
		elif tier_key == "gold":
			fill_c = Color("#ca8a04")
			rim_c = Color("#fde047")
		elif tier_key == "anti_troll":
			fill_c = Color("#7e22ce")
			rim_c = Color("#00f5ff")
	c.draw_circle(center, rad, fill_c)
	c.draw_arc(center, rad, 0.0, TAU, 16, rim_c, 1.6 if earned else 1.0)
	if earned and tier_key == "anti_troll":
		c.draw_circle(center, rad * 0.42, Color("#fde047"))

# --- 4A. STAGE & 15-CHAPTER SELECT HALL ---
func _build_hall_modal() -> void:
	hall_panel = _center_card(884.0, 496.0, Color("#00f5ff"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	hall_panel.add_child(vb)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	var grid_ic: TextureRect = TextureRect.new()
	grid_ic.custom_minimum_size = Vector2(24.0, 24.0)
	grid_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grid_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	grid_ic.texture = _tex("ui_grid")
	hdr.add_child(grid_ic)

	hall_title_lbl = Label.new()
	hall_title_lbl.add_theme_font_size_override("font_size", 18)
	hall_title_lbl.add_theme_color_override("font_color", Color("#ecfeff"))
	hdr.add_child(hall_title_lbl)

	var prog_pill: PanelContainer = PanelContainer.new()
	prog_pill.add_theme_stylebox_override("panel", _make_flat_box(Color("#052e26"), Color("#4ade80"), 1, 10, 8, 2))
	hall_prog_lbl = Label.new()
	hall_prog_lbl.add_theme_font_size_override("font_size", 12)
	hall_prog_lbl.add_theme_color_override("font_color", Color("#4ade80"))
	prog_pill.add_child(hall_prog_lbl)
	hdr.add_child(prog_pill)

	hall_medal_sum_lbl = Label.new()
	hall_medal_sum_lbl.add_theme_font_size_override("font_size", 12)
	hall_medal_sum_lbl.add_theme_color_override("font_color", Color("#fde047"))
	hdr.add_child(hall_medal_sum_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	hall_mode_toggle_btn = Button.new()
	hall_mode_toggle_btn.custom_minimum_size = Vector2(138.0, 34.0)
	hall_mode_toggle_btn.pressed.connect(func() -> void:
		audio.play_named("coin", 1.06)
		hall_view_mode = "chapters" if hall_view_mode == "stages" else "stages"
		scroll_velocity_y = 0.0
		_apply_smooth_scroll("chapters", 0.0)
		_refresh_hall_contents()
	)
	hdr.add_child(hall_mode_toggle_btn)

	hall_cg_shortcut_btn = Button.new()
	hall_cg_shortcut_btn.custom_minimum_size = Vector2(110.0, 34.0)
	hall_cg_shortcut_btn.pressed.connect(func() -> void:
		_open_chapter_cg_or_gallery(selected_chapter)
	)
	hdr.add_child(hall_cg_shortcut_btn)

	hall_home_btn = Button.new()
	hall_home_btn.custom_minimum_size = Vector2(74.0, 34.0)
	hall_home_btn.pressed.connect(func() -> void:
		audio.play_named("block", 1.0)
		close_all_modals(false)
		request_return_title.emit()
	)
	hdr.add_child(hall_home_btn)

	var close_b: Button = _make_icon_slot_button("ui_btn_x", 36.0, Color("#fb7185"))
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
		sb.custom_minimum_size = Vector2(0.0, 32.0)
		var captured_s: int = s_idx
		sb.pressed.connect(func() -> void: _on_select_sector(captured_s))
		sec_row.add_child(sb)
		hall_sector_btns.append(sb)

	hall_chapter_box = HBoxContainer.new()
	hall_chapter_box.add_theme_constant_override("separation", 6)
	vb.add_child(hall_chapter_box)

	hall_sub_lbl = Label.new()
	hall_sub_lbl.add_theme_font_size_override("font_size", 12)
	hall_sub_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vb.add_child(hall_sub_lbl)

	# 10-Stage Grid View
	hall_grid = GridContainer.new()
	hall_grid.columns = 5
	hall_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hall_grid.add_theme_constant_override("h_separation", 10)
	hall_grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(hall_grid)

	# 15-Chapter Theme Cards SmoothScrollBox View
	hall_chapters_clip = Control.new()
	hall_chapters_clip.clip_contents = true
	hall_chapters_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall_chapters_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hall_chapters_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	hall_chapters_clip.visible = false
	hall_chapters_clip.resized.connect(func() -> void:
		if hall_chapters_vbox != null:
			hall_chapters_vbox.size.x = maxf(200.0, hall_chapters_clip.size.x - 14.0)
			_apply_smooth_scroll("chapters", hall_chapters_scroll_y)
	)
	hall_chapters_clip.draw.connect(func() -> void:
		_draw_custom_scrollbar(hall_chapters_clip, hall_chapters_vbox, hall_chapters_scroll_y, Color("#00f5ff"))
	)
	vb.add_child(hall_chapters_clip)

	hall_chapters_vbox = VBoxContainer.new()
	hall_chapters_vbox.position = Vector2.ZERO
	hall_chapters_vbox.size = Vector2(830.0, 340.0)
	hall_chapters_vbox.add_theme_constant_override("separation", 8)
	hall_chapters_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hall_chapters_clip.add_child(hall_chapters_vbox)

func _open_chapter_cg_or_gallery(ch_idx: int) -> void:
	var cg_lv: int = ch_idx * 10
	var cgs_map: Dictionary = meta.get("milestoneCgs", {})
	var slides: Array = cgs_map.get(str(cg_lv), [])
	if not slides.is_empty() and (save.is_stage_cleared(cg_lv) or bool(save.seen_cgs.get(str((slides[0] as Dictionary).get("id", "")), false))):
		audio.play_named("coin", 1.08)
		open_cg_modal(slides, 0)
	else:
		audio.play_named("block", 1.04)
		open_options_modal("lore")

func _on_select_sector(sec: int) -> void:
	if sec == 2 and not save.is_stage_cleared(50) and not save.is_stage_unlocked(51):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("通关第 50 关后解锁第二篇章「根源系统篇」！", "Clear Stage 50 to unlock Act II!"), "ui_grid", "#fb7185")
		return
	if sec == 3 and not save.is_stage_cleared(100) and not save.is_stage_unlocked(101):
		audio.play_named("fake_buzz", 1.0)
		push_toast(_tr("通关第 100 关后解锁第三篇章「晴空幻境篇」！", "Clear Stage 100 to unlock Act III!"), "ui_grid", "#fb7185")
		return
	audio.play_named("coin", 1.06)
	selected_sector = sec
	var front_lv: int = save.get_highest_frontier_level(sec)
	selected_chapter = clampi(int(ceil(float(front_lv) / 10.0)), (sec - 1) * 5 + 1, sec * 5)
	_apply_smooth_scroll("chapters", 0.0)
	_refresh_hall_contents()

func _sync_hall_chapters_layout() -> void:
	if hall_chapters_clip == null or hall_chapters_vbox == null:
		return
	var tw: float = maxf(200.0, (hall_chapters_clip.size.x if hall_chapters_clip.size.x > 50.0 else 836.0) - 14.0)
	hall_chapters_vbox.custom_minimum_size.x = tw
	hall_chapters_vbox.size.x = tw
	hall_chapters_vbox.reset_size()
	hall_chapters_vbox.size.x = tw
	_apply_smooth_scroll("chapters", hall_chapters_scroll_y)

func _refresh_hall_contents() -> void:
	hall_title_lbl.text = _tr("15章总览" if hall_view_mode == "chapters" else "选择关卡", "15 CHAPTERS" if hall_view_mode == "chapters" else "STAGE SELECT")
	hall_prog_lbl.text = "%d / 150" % save.get_cleared_count(150)

	var m_counts: Dictionary = save.get_medal_counts() if save.has_method("get_medal_counts") else { "copper": 0, "silver": 0, "gold": 0, "anti_troll": 0 }
	hall_medal_sum_lbl.text = _tr(
		"铜%d · 银%d · 金%d · 反套路%d" % [int(m_counts.get("copper", 0)), int(m_counts.get("silver", 0)), int(m_counts.get("gold", 0)), int(m_counts.get("anti_troll", 0))],
		"C:%d · S:%d · G:%d · T:%d" % [int(m_counts.get("copper", 0)), int(m_counts.get("silver", 0)), int(m_counts.get("gold", 0)), int(m_counts.get("anti_troll", 0))]
	)

	hall_mode_toggle_btn.text = _tr("▦ 10关面板" if hall_view_mode == "chapters" else "❖ 15章卡片", "▦ 10-STAGE GRID" if hall_view_mode == "chapters" else "❖ 15 CHAPTERS")
	var cur_cg_lv: int = selected_chapter * 10
	hall_cg_shortcut_btn.text = _tr("▶ 本章CG" if save.is_stage_cleared(cur_cg_lv) else "▶ CG图鉴", "▶ CH CG" if save.is_stage_cleared(cur_cg_lv) else "▶ GALLERY")
	hall_home_btn.text = _tr("主页", "HOME")
	hall_home_btn.visible = in_game

	var sec_titles_zh: Array[String] = [
		"I. 经典反套路篇 (001–050)",
		"II. 根源系统篇 (051–100)",
		"III. 晴空幻境篇 (101–150)"
	]
	var sec_titles_en: Array[String] = [
		"I. CLASSIC SUBVERSION (001–050)",
		"II. ROOT SYSTEM (051–100)",
		"III. SUNLIT ARCADIA (101–150)"
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

	hall_chapter_box.visible = (hall_view_mode == "stages")
	hall_grid.visible = (hall_view_mode == "stages")
	hall_chapters_clip.visible = (hall_view_mode == "chapters")

	if hall_view_mode == "chapters":
		var ch_info_all: Dictionary = CHAPTER_META[clampi(selected_chapter - 1, 0, 14)]
		hall_sub_lbl.text = _tr(
			"上下顺滑滑动浏览全部 15 章主题卡片 · 点击任意章节进入 10 关选关或回看章节 CG",
			"Swipe vertically to browse all 15 Chapter Theme Cards · Tap a chapter to enter stages or watch CG"
		)
		for old_card in hall_chapters_vbox.get_children():
			hall_chapters_vbox.remove_child(old_card)
			old_card.queue_free()

		var ch_grid: GridContainer = GridContainer.new()
		ch_grid.columns = 3
		ch_grid.mouse_filter = Control.MOUSE_FILTER_PASS
		ch_grid.add_theme_constant_override("h_separation", 8)
		ch_grid.add_theme_constant_override("v_separation", 8)
		hall_chapters_vbox.add_child(ch_grid)

		for cm_v in CHAPTER_META:
			var cm: Dictionary = cm_v
			ch_grid.add_child(_build_chapter_theme_card(cm))

		call_deferred("_sync_hall_chapters_layout")
		return

	for ch_old in hall_chapter_box.get_children():
		ch_old.queue_free()

	var ch_start: int = (selected_sector - 1) * 5 + 1
	for ch_i in range(ch_start, ch_start + 5):
		var cb: Button = Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0.0, 28.0)
		var lv_a: int = (ch_i - 1) * 10 + 1
		var lv_b: int = ch_i * 10
		var ch_locked: bool = not save.is_stage_unlocked(lv_a)
		var ch_clr_cnt: int = 0
		for k_lv in range(lv_a, lv_b + 1):
			if save.is_stage_cleared(k_lv):
				ch_clr_cnt += 1
		cb.text = ("%sCH.%02d (%d/10)" % ["[锁]" if ch_locked else "", ch_i, ch_clr_cnt])
		var is_cur_ch: bool = (ch_i == selected_chapter)
		var c_col: Color = sec_cols[selected_sector - 1]
		cb.add_theme_stylebox_override(
			"normal",
			_make_flat_box(Color("#162c64") if is_cur_ch else Color("#09112c"), c_col if is_cur_ch else Color(0.22, 0.30, 0.48, 0.55), 2 if is_cur_ch else 1, 6, 6, 2)
		)
		var cap_ch: int = ch_i
		cb.pressed.connect(func() -> void:
			audio.play_named("block", 1.08)
			selected_chapter = cap_ch
			_refresh_hall_contents()
		)
		hall_chapter_box.add_child(cb)

	var cmeta: Dictionary = CHAPTER_META[clampi(selected_chapter - 1, 0, 14)]
	var ch_title_s: String = str(cmeta.get("en" if save.lang == "en" else "zh", ""))
	var ch_theme_s: String = str(cmeta.get("theme_en" if save.lang == "en" else "theme_zh", ""))
	hall_sub_lbl.text = "%s  —  %s   ·  %s" % [ch_title_s, ch_theme_s, _tr("左右滑动翻章", "Swipe for chapters")]

	for old_c in hall_grid.get_children():
		old_c.queue_free()

	var first_lv: int = (selected_chapter - 1) * 10 + 1
	var frontier_lv: int = save.get_highest_frontier_level(0)
	for lv_num in range(first_lv, first_lv + 10):
		hall_grid.add_child(_build_cyber_stage_card(lv_num, lv_num == frontier_lv))

func _build_chapter_theme_card(cm: Dictionary) -> Control:
	var ch_n: int = int(cm.get("ch", 1))
	var act_n: int = int(cm.get("act", 1))
	var lv_a: int = (ch_n - 1) * 10 + 1
	var lv_b: int = ch_n * 10
	var ch_unlocked: bool = save.is_stage_unlocked(lv_a)
	var clr_cnt: int = 0
	var gold_cnt: int = 0
	for k in range(lv_a, lv_b + 1):
		if save.is_stage_cleared(k):
			clr_cnt += 1
		var md: Dictionary = save.get_stage_medals(k) if save.has_method("get_stage_medals") else {}
		if bool(md.get("gold", false)):
			gold_cnt += 1

	var act_cols: Array[Color] = [Color("#00f5ff"), Color("#c084fc"), Color("#38bdf8")]
	var b_col: Color = act_cols[clampi(act_n - 1, 0, 2)] if ch_unlocked else Color("#334155")
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _make_flat_box(Color("#0b1538") if ch_unlocked else Color("#070d20"), b_col, 2 if ch_n == selected_chapter else 1, 8, 10, 8))

	var vb: VBoxContainer = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var top_hb: HBoxContainer = HBoxContainer.new()
	top_hb.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hb.add_theme_constant_override("separation", 6)
	var ic: TextureRect = TextureRect.new()
	ic.custom_minimum_size = Vector2(32.0, 32.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture = _tex(str(cm.get("icon", "ui_grid")))
	ic.modulate = Color.WHITE if ch_unlocked else Color(0.4, 0.45, 0.55, 0.7)
	top_hb.add_child(ic)

	var ttl: Label = Label.new()
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.clip_text = true
	ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ttl.text = str(cm.get("en" if save.lang == "en" else "zh", ""))
	ttl.add_theme_font_size_override("font_size", 13)
	ttl.add_theme_color_override("font_color", Color("#fde047") if clr_cnt == 10 else (Color("#ecfeff") if ch_unlocked else Color("#64748b")))
	top_hb.add_child(ttl)
	vb.add_child(top_hb)

	var th_lbl: Label = Label.new()
	th_lbl.clip_text = true
	th_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th_lbl.text = str(cm.get("theme_en" if save.lang == "en" else "theme_zh", "")) if ch_unlocked else _tr("需先通关第 %03d 关解锁" % (lv_a - 1), "Clear LV.%03d to unlock" % (lv_a - 1))
	th_lbl.add_theme_font_size_override("font_size", 11)
	th_lbl.add_theme_color_override("font_color", Color("#94a3b8") if ch_unlocked else Color("#475569"))
	vb.add_child(th_lbl)

	var bot_hb: HBoxContainer = HBoxContainer.new()
	bot_hb.mouse_filter = Control.MOUSE_FILTER_PASS
	bot_hb.add_theme_constant_override("separation", 6)
	var prog_l: Label = Label.new()
	prog_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_l.text = _tr("进度 %d/10 · 金章 %d" % [clr_cnt, gold_cnt], "%d/10 · Gold %d" % [clr_cnt, gold_cnt])
	prog_l.add_theme_font_size_override("font_size", 11)
	prog_l.add_theme_color_override("font_color", Color("#4ade80") if clr_cnt > 0 else Color("#64748b"))
	bot_hb.add_child(prog_l)

	var enter_b: Button = Button.new()
	enter_b.mouse_filter = Control.MOUSE_FILTER_PASS
	enter_b.custom_minimum_size = Vector2(68.0, 26.0)
	enter_b.text = _tr("选关", "OPEN")
	enter_b.disabled = not ch_unlocked
	enter_b.pressed.connect(func() -> void:
		if scroll_is_dragging:
			return
		audio.play_named("coin", 1.06)
		selected_chapter = ch_n
		selected_sector = act_n
		hall_view_mode = "stages"
		_refresh_hall_contents()
	)
	bot_hb.add_child(enter_b)

	var cg_lv: int = int(cm.get("cg_lv", ch_n * 10))
	var cg_ok: bool = save.is_stage_cleared(cg_lv)
	var cg_b: Button = Button.new()
	cg_b.mouse_filter = Control.MOUSE_FILTER_PASS
	cg_b.custom_minimum_size = Vector2(48.0, 26.0)
	cg_b.text = "CG"
	cg_b.disabled = not cg_ok
	cg_b.pressed.connect(func() -> void:
		if scroll_is_dragging:
			return
		_open_chapter_cg_or_gallery(ch_n)
	)
	bot_hb.add_child(cg_b)
	vb.add_child(bot_hb)
	return card

func _build_cyber_stage_card(lv_num: int, is_frontier: bool) -> Control:
	var unlocked: bool = save.is_stage_unlocked(lv_num)
	var cleared_lv: bool = save.is_stage_cleared(lv_num)
	var lv_info: Dictionary = _levels_map().get(lv_num, {})
	var st_name: String = str(lv_info.get("nameEn" if save.lang == "en" else "name", ""))
	var best_t: float = float(save.best_time_by_lv.get(str(lv_num), -1.0)) if ("best_time_by_lv" in save) else -1.0
	var has_shard: bool = bool(save.shards.get(str(lv_num), false))
	var medals: Dictionary = save.get_stage_medals(lv_num) if save.has_method("get_stage_medals") else {
		"copper": cleared_lv,
		"silver": int(save.best_stars.get(str(lv_num), 0)) >= 3,
		"gold": int(save.best_stars.get(str(lv_num), 0)) >= 5,
		"anti_troll": false
	}

	var btn: Button = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(158.0, 128.0)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	var border_c: Color = Color("#fde047") if is_frontier else (Color("#4ade80") if cleared_lv else (Color("#00f5ff") if unlocked else Color(0.25, 0.32, 0.46, 0.45)))
	btn.add_theme_stylebox_override("normal", _make_flat_box(Color(0.03, 0.06, 0.18, 0.80), border_c, 2 if (is_frontier or cleared_lv) else 1, 8, 4, 4))
	btn.add_theme_stylebox_override("hover", _make_flat_box(Color(0.08, 0.16, 0.38, 0.92), Color("#fde047"), 2, 8, 4, 4))

	# Prioritize redrawn `level_btn_1..30` frames (which already contain crisp baked numbers 1..30!)
	var use_numbered_frame: bool = unlocked and lv_num >= 1 and lv_num <= 30 and textures.has("level_btn_%d" % lv_num)
	var plate: TextureRect = TextureRect.new()
	plate.anchor_left = 0.0
	plate.anchor_right = 1.0
	plate.anchor_top = 0.0
	plate.anchor_bottom = 0.0
	plate.offset_left = 5.0
	plate.offset_top = 5.0
	plate.offset_right = -5.0
	plate.offset_bottom = 72.0
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if use_numbered_frame else TextureRect.STRETCH_SCALE
	plate.texture = _tex(("level_btn_%d" % lv_num) if use_numbered_frame else "ui_level_plate")
	plate.modulate = Color.WHITE if unlocked else Color(0.42, 0.46, 0.58, 0.88)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(plate)

	if not use_numbered_frame:
		var num_lbl: Label = Label.new()
		num_lbl.anchor_left = 0.0
		num_lbl.anchor_right = 1.0
		num_lbl.offset_top = 18.0
		num_lbl.offset_bottom = 58.0
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.text = ("%03d" % lv_num) if unlocked else ("[锁] %03d" % lv_num)
		num_lbl.add_theme_font_size_override("font_size", 21 if unlocked else 16)
		num_lbl.add_theme_color_override("font_color", Color("#fde047") if is_frontier else (Color("#ecfeff") if unlocked else Color("#64748b")))
		num_lbl.add_theme_color_override("font_outline_color", Color("#020617"))
		num_lbl.add_theme_constant_override("outline_size", 4)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(num_lbl)

	if cleared_lv:
		var chk: TextureRect = TextureRect.new()
		chk.anchor_left = 1.0
		chk.anchor_right = 1.0
		chk.offset_left = -22.0
		chk.offset_right = -6.0
		chk.offset_top = 6.0
		chk.offset_bottom = 22.0
		chk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chk.texture = _tex("badge_clear" if textures.has("badge_clear") else "ui_btn_check")
		chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(chk)

	if has_shard:
		var sh_ic: TextureRect = TextureRect.new()
		sh_ic.offset_left = 7.0
		sh_ic.offset_top = 6.0
		sh_ic.offset_right = 23.0
		sh_ic.offset_bottom = 22.0
		sh_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sh_ic.texture = _tex("s2_mem_shard")
		sh_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sh_ic)

	var name_lbl: Label = Label.new()
	name_lbl.anchor_left = 0.0
	name_lbl.anchor_right = 1.0
	name_lbl.offset_left = 6.0
	name_lbl.offset_right = -6.0
	name_lbl.offset_top = 74.0
	name_lbl.offset_bottom = 94.0
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text = st_name if unlocked else _tr("未解锁", "LOCKED")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color("#e2e8f0") if unlocked else Color("#475569"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	# Bottom Row: 4-Tier Medals (Copper/Silver/Gold/Anti-Troll) + Best Time
	var medal_bar: Control = Control.new()
	medal_bar.anchor_left = 0.0
	medal_bar.anchor_right = 1.0
	medal_bar.offset_left = 8.0
	medal_bar.offset_right = -8.0
	medal_bar.offset_top = 96.0
	medal_bar.offset_bottom = 122.0
	medal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_medals: Dictionary = medals.duplicate()
	var cap_best_t: float = best_t
	var cap_unlocked: bool = unlocked
	medal_bar.draw.connect(func() -> void:
		var order_m: Array[String] = ["copper", "silver", "gold", "anti_troll"]
		for mi in range(4):
			var mk: String = order_m[mi]
			_draw_medal_pip(medal_bar, Vector2(10.0 + float(mi) * 16.0, 12.0), 6.0, mk, cap_unlocked and bool(cap_medals.get(mk, false)))
		if font_main != null and cap_unlocked:
			var t_str: String = _format_time_sec(cap_best_t)
			medal_bar.draw_string(font_main, Vector2(72.0, 16.0), t_str, HORIZONTAL_ALIGNMENT_RIGHT, maxf(40.0, medal_bar.size.x - 74.0), 10, Color("#94a3b8") if cap_best_t <= 0.0 else Color("#67e8f9"))
	)
	btn.add_child(medal_bar)

	btn.pressed.connect(func() -> void:
		if hall_swipe_consumed:
			return
		if not save.is_stage_unlocked(lv_num):
			audio.play_named("fake_buzz", 1.0)
			push_toast(_tr("请按顺序通关前置关卡解锁第 %03d 关！" % lv_num, "Clear previous stages first to unlock Stage %03d!" % lv_num), "ui_grid", "#fb7185")
			return
		audio.play_named("coin", 1.1)
		close_all_modals(false)
		request_start_stage.emit(lv_num)
	)
	return btn

func _close_hall_or_return() -> void:
	var p: Dictionary = _player_dict()
	if in_game and not p.is_empty() and bool(p.get("dead", false)):
		var dc: String = str(_eng_get("pending_death_cause", "general"))
		open_death_modal(dc if dc != "" else "general")
	else:
		close_all_modals(true)

# --- 4B. SETTINGS, ACCESSIBILITY, SHOP, ACHIEVEMENTS & CG GALLERY MODAL ---
func _build_options_modal() -> void:
	options_panel = _center_card(842.0, 486.0, Color("#c084fc"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
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
	opt_header_lbl.add_theme_font_size_override("font_size", 18)
	opt_header_lbl.add_theme_color_override("font_color", Color("#f5d0fe"))
	hdr.add_child(opt_header_lbl)

	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)

	var close_b: Button = _make_icon_slot_button("ui_btn_x", 36.0, Color("#fb7185"))
	close_b.pressed.connect(func() -> void:
		audio.play_named("block", 0.96)
		var p: Dictionary = _player_dict()
		if in_game and not p.is_empty() and bool(p.get("dead", false)):
			var dc: String = str(_eng_get("pending_death_cause", "general"))
			open_death_modal(dc if dc != "" else "general")
		else:
			close_all_modals(true)
	)
	hdr.add_child(close_b)

	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	vb.add_child(tab_row)

	var tab_defs: Array = ["config", "assist", "shop", "ach", "lore"]
	for tk_var in tab_defs:
		var tk: String = str(tk_var)
		var tb: Button = Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0.0, 34.0)
		tb.pressed.connect(func() -> void:
			audio.play_named("block", 1.06)
			options_tab = tk
			reset_confirm_armed = false
			scroll_velocity_y = 0.0
			_apply_smooth_scroll("options", 0.0)
			_refresh_options_contents()
		)
		tab_row.add_child(tb)
		opt_tab_btns[tk] = tb

	opt_scroll_clip = Control.new()
	opt_scroll_clip.clip_contents = true
	opt_scroll_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opt_scroll_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	opt_scroll_clip.resized.connect(func() -> void:
		if opt_body_vbox != null:
			opt_body_vbox.size.x = maxf(200.0, opt_scroll_clip.size.x - 14.0)
			_apply_smooth_scroll("options", opt_scroll_y)
	)
	opt_scroll_clip.draw.connect(func() -> void:
		_draw_custom_scrollbar(opt_scroll_clip, opt_body_vbox, opt_scroll_y, Color("#c084fc"))
	)
	vb.add_child(opt_scroll_clip)

	opt_body_vbox = VBoxContainer.new()
	opt_body_vbox.position = Vector2.ZERO
	opt_body_vbox.size = Vector2(796.0, 350.0)
	opt_body_vbox.add_theme_constant_override("separation", 8)
	opt_body_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	opt_scroll_clip.add_child(opt_body_vbox)

func _sync_opt_vbox_layout() -> void:
	if opt_scroll_clip == null or opt_body_vbox == null:
		return
	var target_w: float = maxf(200.0, (opt_scroll_clip.size.x if opt_scroll_clip.size.x > 50.0 else 804.0) - 14.0)
	opt_body_vbox.custom_minimum_size.x = target_w
	opt_body_vbox.size.x = target_w
	opt_body_vbox.reset_size()
	opt_body_vbox.size.x = target_w
	_apply_smooth_scroll("options", opt_scroll_y)

func _refresh_options_contents() -> void:
	active_sliders.clear()
	opt_header_lbl.text = _tr("系统终端 · 操控、无障碍与图鉴商城 (支持顺滑滑动)", "SYSTEM TERMINAL · CONTROLS, ACCESSIBILITY & GALLERY")
	var shop_lock_tag: String = "" if shop.is_unlocked() else " [锁]"
	(opt_tab_btns["config"] as Button).text = _tr("◈ 音量与触控", "◈ CONTROLS")
	(opt_tab_btns["assist"] as Button).text = _tr("♿ 无障碍与辅助", "♿ ACCESSIBILITY")
	(opt_tab_btns["shop"] as Button).text = _tr("◆ 商城%s" % shop_lock_tag, "◆ SHOP%s" % shop_lock_tag)
	(opt_tab_btns["ach"] as Button).text = _tr("★ 成就", "★ ACHIEVEMENTS")
	(opt_tab_btns["lore"] as Button).text = _tr("▶ 剧情CG", "▶ CG GALLERY")

	for tk in opt_tab_btns.keys():
		var b: Button = opt_tab_btns[tk]
		var on: bool = (tk == options_tab)
		b.add_theme_stylebox_override(
			"normal",
			_make_flat_box(Color("#1d1648") if on else Color("#09112c"), Color("#fde047") if on else Color("#334155"), 2 if on else 1, 8, 6, 4)
		)

	for ch in opt_body_vbox.get_children():
		opt_body_vbox.remove_child(ch)
		ch.queue_free()

	if options_tab == "config":
		_populate_config_tab()
	elif options_tab == "assist":
		_populate_accessibility_tab()
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
	pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#0b1538"), Color(0.2, 0.4, 0.7, 0.45), 1, 8, 12, 7))
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
	lb.add_theme_font_size_override("font_size", 13)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)
	pc.add_child(hb)
	opt_body_vbox.add_child(pc)
	return hb

func _register_slider(sl: HSlider) -> void:
	sl.custom_minimum_size = Vector2(170.0, 28.0)
	active_sliders.append(sl)

func _populate_config_tab() -> void:
	# Keybinding Quick Legend Card
	var kb_card: PanelContainer = PanelContainer.new()
	kb_card.mouse_filter = Control.MOUSE_FILTER_PASS
	kb_card.add_theme_stylebox_override("panel", _make_flat_box(Color("#09163a"), Color("#00f5ff"), 1, 8, 12, 8))
	var kb_lbl: Label = Label.new()
	kb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kb_lbl.add_theme_font_size_override("font_size", 12)
	kb_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	kb_lbl.text = _tr(
		"键鼠快捷键：[A/D或←/→] 移动 · [W/Space/↑] 跳跃/三段下砸 · [S/↓] 下蹲/进管 · [J/Z] 远程射击 · [U/X] 破魔剑 · [H] 收剑切换 · [F] 情境交互/拾取放置投掷 · [E] 表里切层 · [R] 快速重开 · [F3] 碰撞调试",
		"PC Keys: [A/D] Move · [W/Space] Jump/Pound · [S] Crouch/Pipe · [J/Z] Shoot · [U/X] Sword · [H] Sheathe Toggle · [F] Interact/Pick/Throw · [E] Layer Shift · [R] Retry · [F3] Debug"
	)
	kb_card.add_child(kb_lbl)
	opt_body_vbox.add_child(kb_card)

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
	lbl_bv.custom_minimum_size = Vector2(44.0, 0.0)
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
	lbl_sv.custom_minimum_size = Vector2(44.0, 0.0)
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

	var r_swap: HBoxContainer = _make_setting_row("ui_hand_swap", _tr("左右手镜像互换 (含收剑钮与情境交互钮)", "Left/Right Hand Layout Swap"))
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
	lb_sc.custom_minimum_size = Vector2(46.0, 0.0)
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
	lb_op.custom_minimum_size = Vector2(46.0, 0.0)
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
	lb_sn.custom_minimum_size = Vector2(46.0, 0.0)
	lb_sn.text = "%d%%" % int(sl_sn.value)
	sl_sn.value_changed.connect(func(v: float) -> void:
		save.sensitivity = clampf(v / 100.0, 0.50, 1.50)
		lb_sn.text = "%d%%" % int(v)
		save.persist()
	)
	r_sn.add_child(sl_sn)
	r_sn.add_child(lb_sn)

	var r_rst: HBoxContainer = _make_setting_row("ui_skull", _tr("重置通关进度与存档 (保留操控与无障碍偏好)", "Reset Save Progress (Keeps Preferences)"))
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
			push_toast(_tr("存档已重置为第 001 关初始状态！", "Save progress reset to Stage 001!"), "ui_restart", "#fde047")
			close_all_modals(false)
			request_return_title.emit()
	)
	r_rst.add_child(b_rst)

# Master GDD 11.3: Dedicated Accessibility & Difficulty Assist Tab
func _populate_accessibility_tab() -> void:
	var r_cap: HBoxContainer = _make_setting_row("ui_audio", _tr("音频视觉声波字幕 (四态云/管道回声/三钟/日晷等图标替代)", "Audio-Visual Subtitles (Visual Icons for Puzzle Sounds)"))
	var b_cap: Button = Button.new()
	b_cap.mouse_filter = Control.MOUSE_FILTER_PASS
	b_cap.text = _tr("开启 ✓" if save.visual_captions_on else "关闭", "ENABLED ✓" if save.visual_captions_on else "OFF")
	b_cap.pressed.connect(func() -> void:
		save.visual_captions_on = not save.visual_captions_on
		if audio != null:
			audio.visual_subtitles_enabled = save.visual_captions_on
		var eb: Variant = _eng_get("event_bus", null)
		if eb != null and typeof(eb) == TYPE_OBJECT:
			(eb as Object).set("captions_enabled", save.visual_captions_on)
		if not save.visual_captions_on:
			active_subtitles.clear()
		save.persist()
		audio.play_named("mirror_ping", 1.0)
		_refresh_options_contents()
	)
	r_cap.add_child(b_cap)

	var r_cb: HBoxContainer = _make_setting_row("gem_blue", _tr("色盲形状/纹理编码辅助 (危险▲ / 承重◆ / 诱饵✕ / 信号◎)", "Colorblind Shape & Pattern Coding (▲Hazard / ◆Solid / ✕Bait)"))
	var b_cb: Button = Button.new()
	b_cb.mouse_filter = Control.MOUSE_FILTER_PASS
	b_cb.text = _tr("已开启 ✓" if save.colorblind_mode else "关闭", "ENABLED ✓" if save.colorblind_mode else "OFF")
	b_cb.pressed.connect(func() -> void:
		save.colorblind_mode = not save.colorblind_mode
		save.persist()
		last_hud_sig = ""
		audio.play_named("coin", 1.05)
		_refresh_options_contents()
	)
	r_cb.add_child(b_cb)

	var r_shk: HBoxContainer = _make_setting_row("ach_springstar", _tr("镜头抖动 / 屏幕震动强度调节", "Camera Shake Intensity"))
	var sl_shk: HSlider = HSlider.new()
	_register_slider(sl_shk)
	sl_shk.min_value = 0.0
	sl_shk.max_value = 100.0
	sl_shk.step = 5.0
	sl_shk.value = roundf(save.screen_shake_scale * 100.0)
	var lb_shk: Label = Label.new()
	lb_shk.custom_minimum_size = Vector2(46.0, 0.0)
	lb_shk.text = "%d%%" % int(sl_shk.value)
	sl_shk.value_changed.connect(func(v: float) -> void:
		save.screen_shake_scale = clampf(v / 100.0, 0.0, 1.0)
		lb_shk.text = "%d%%" % int(v)
		save.persist()
	)
	r_shk.add_child(sl_shk)
	r_shk.add_child(lb_shk)

	var r_fls: HBoxContainer = _make_setting_row("s3_sundial_orb", _tr("屏幕闪白 / 爆破闪光强度调节", "Screen Flash Intensity"))
	var sl_fls: HSlider = HSlider.new()
	_register_slider(sl_fls)
	sl_fls.min_value = 0.0
	sl_fls.max_value = 100.0
	sl_fls.step = 5.0
	sl_fls.value = roundf(save.screen_flash_scale * 100.0)
	var lb_fls: Label = Label.new()
	lb_fls.custom_minimum_size = Vector2(46.0, 0.0)
	lb_fls.text = "%d%%" % int(sl_fls.value)
	sl_fls.value_changed.connect(func(v: float) -> void:
		save.screen_flash_scale = clampf(v / 100.0, 0.0, 1.0)
		lb_fls.text = "%d%%" % int(v)
		save.persist()
	)
	r_fls.add_child(sl_fls)
	r_fls.add_child(lb_fls)

	var r_vib: HBoxContainer = _make_setting_row("icon_shield", _tr("手持设备触觉震动反馈", "Handheld Haptic Vibration"))
	var b_vib: Button = Button.new()
	b_vib.mouse_filter = Control.MOUSE_FILTER_PASS
	b_vib.text = _tr("开启" if save.vibrate_on else "关闭", "ON" if save.vibrate_on else "OFF")
	b_vib.pressed.connect(func() -> void:
		save.vibrate_on = not save.vibrate_on
		save.persist()
		_refresh_options_contents()
	)
	r_vib.add_child(b_vib)

	var r_ast: HBoxContainer = _make_setting_row("icon_wing", _tr("难度辅助模式 (放宽土狼时间/输入缓冲与Boss输出窗口，不改谜题)", "Difficulty Assist (Wider Coyote/Buffer & Boss Window, Keeps Puzzles)"))
	var b_ast: Button = Button.new()
	b_ast.mouse_filter = Control.MOUSE_FILTER_PASS
	b_ast.text = _tr("已开启 ✓" if save.assist_mode else "关闭 (标准)", "ASSIST ON ✓" if save.assist_mode else "STANDARD")
	b_ast.pressed.connect(func() -> void:
		save.assist_mode = not save.assist_mode
		_eng_set_if_has("assist_mode", save.assist_mode)
		save.persist()
		last_hud_sig = ""
		audio.play_named("shield_up", 1.05)
		_refresh_options_contents()
	)
	r_ast.add_child(b_ast)

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
	coin_lb.add_theme_font_size_override("font_size", 16)
	coin_lb.add_theme_color_override("font_color", Color("#fde047"))
	coin_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(coin_lb)
	var rule_lb: Label = Label.new()
	rule_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rule_lb.text = _tr("可选辅助神装：每关限用 1 次（不售卖唯一通关能力）", "Optional Assist Gear: Max 1 Use / Stage")
	rule_lb.add_theme_font_size_override("font_size", 12)
	rule_lb.add_theme_color_override("font_color", Color("#67e8f9"))
	rule_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(rule_lb)
	top_card.add_child(top_hb)
	opt_body_vbox.add_child(top_card)

	if not shop.is_unlocked():
		var lock_box: PanelContainer = PanelContainer.new()
		lock_box.mouse_filter = Control.MOUSE_FILTER_PASS
		lock_box.add_theme_stylebox_override("panel", _make_flat_box(Color("#1a0b2e"), Color("#fb7185"), 2, 10, 16, 12))
		var l_lbl: Label = Label.new()
		l_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l_lbl.text = _tr(
			"[锁] 炼金神装商城尚未解锁！通关第 50 关后开启（当前第一篇章进度 %d / 50）。所有关卡均无需商城道具即可无伤解谜通关！" % save.get_cleared_count(50),
			"[锁] ALCHEMY SHOP LOCKED! Clear Stage 50 to unlock (%d / 50). Every stage is 100%% solvable without shop items!" % save.get_cleared_count(50)
		)
		l_lbl.add_theme_color_override("font_color", Color("#fda4af"))
		lock_box.add_child(l_lbl)
		opt_body_vbox.add_child(lock_box)

	var p_ref: Dictionary = _player_dict()
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
		row_pc.add_theme_stylebox_override("panel", _make_flat_box(Color("#091332"), b_col, 1, 10, 12, 9))
		var hb: HBoxContainer = HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.add_theme_constant_override("separation", 12)

		var ic: TextureRect = TextureRect.new()
		ic.custom_minimum_size = Vector2(34.0, 34.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = _tex(str(it.get("icon", "coin_gold")))
		hb.add_child(ic)

		var mid_vb: VBoxContainer = VBoxContainer.new()
		mid_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_vb.mouse_filter = Control.MOUSE_FILTER_PASS
		mid_vb.add_theme_constant_override("separation", 2)
		var nm_lb: Label = Label.new()
		nm_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var used_tag: String = _tr("  [本关已触发1次]", "  [USED THIS STAGE]") if used_now else ""
		nm_lb.text = str(it.get("enName" if save.lang == "en" else "zhName", item_id)) + used_tag
		nm_lb.add_theme_font_size_override("font_size", 14)
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
		act_btn.custom_minimum_size = Vector2(124.0, 36.0)
		act_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		act_btn.disabled = not shop.is_unlocked()
		if not owned:
			act_btn.text = "%d G %s" % [price, _tr("购买", "BUY")]
		else:
			act_btn.text = _tr("已装备 ✓" if equipped else "点击装备", "EQUIPPED ✓" if equipped else "EQUIP")
		act_btn.pressed.connect(func() -> void:
			var res: Dictionary = shop.buy_or_toggle(item_id, _player_dict(), in_game)
			if not bool(res.get("ok", false)):
				audio.play_named("fake_buzz", 1.0)
				if str(res.get("reason", "")) == "no_coins":
					push_toast(_tr("金币不足！需要 %d G" % price, "Not enough coins! Need %d G" % price), "coin_gold", "#fb7185")
			else:
				audio.play_named("coin", 1.12)
				if str(res.get("action", "")) == "already_used_this_stage":
					push_toast(_tr("每件道具每关限用 1 次，将在下一关生效！", "1 use per stage—activates on next stage!"), "ui_hint", "#fde047")
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
			_apply_smooth_scroll("options", 0.0)
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
		["chapter", "章节 CG (8)", "CHAPTERS (8)"],
		["finale", "50关终章 (5)", "LV.50 FINALE (5)"],
		["true_finale", "100关根源 (7)", "LV.100 ROOT (7)"],
		["arcadia", "晴空终章 (9)", "S3 ARCADIA (9)"]
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
			_apply_smooth_scroll("options", 0.0)
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
		thumb.custom_minimum_size = Vector2(360.0, 134.0)
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

# --- 4C. DEATH TAUNT MODAL (With Non-Spoiling Observation Prompt on First Death!) ---
func _build_death_modal() -> void:
	death_panel = _center_card(560.0, 358.0, Color("#fb7185"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	death_panel.add_child(vb)

	death_banner_rect = TextureRect.new()
	death_banner_rect.custom_minimum_size = Vector2(320.0, 70.0)
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
	death_taunt_lbl.custom_minimum_size = Vector2(500.0, 50.0)
	death_taunt_lbl.add_theme_font_size_override("font_size", 14)
	death_taunt_lbl.add_theme_color_override("font_color", Color("#f1f5f9"))
	vb.add_child(death_taunt_lbl)

	death_obs_tip_lbl = Label.new()
	death_obs_tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_obs_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_obs_tip_lbl.add_theme_font_size_override("font_size", 12)
	death_obs_tip_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	vb.add_child(death_obs_tip_lbl)

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
	btn_death_retry.custom_minimum_size = Vector2(156.0, 40.0)
	btn_death_retry.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 12, 6))
	btn_death_retry.pressed.connect(func() -> void:
		audio.play_named("coin", 1.06)
		close_all_modals(true)
		request_retry_stage.emit()
	)
	btn_row.add_child(btn_death_retry)

	btn_death_hint = Button.new()
	btn_death_hint.custom_minimum_size = Vector2(156.0, 40.0)
	btn_death_hint.pressed.connect(func() -> void:
		audio.play_named("hint_popup", 1.04)
		open_hint_modal()
	)
	btn_row.add_child(btn_death_hint)

	btn_death_hall = Button.new()
	btn_death_hall.custom_minimum_size = Vector2(130.0, 40.0)
	btn_death_hall.pressed.connect(func() -> void:
		audio.play_named("block", 1.04)
		open_level_select_modal()
	)
	btn_row.add_child(btn_death_hall)

# --- 4D. 3-TIER PROGRESSIVE HINT & BLUEPRINT MODAL (Light -> Medium -> Full ①②③④⑤) ---
func _build_hint_modal() -> void:
	hint_panel = _center_card(842.0, 492.0, Color("#fde047"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	hint_panel.add_child(vb)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	var masc: TextureRect = TextureRect.new()
	masc.custom_minimum_size = Vector2(32.0, 32.0)
	masc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	masc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	masc.texture = _tex("troll_mascot")
	hdr.add_child(masc)

	hint_title_lbl = Label.new()
	hint_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_title_lbl.add_theme_font_size_override("font_size", 17)
	hint_title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	hdr.add_child(hint_title_lbl)

	btn_hint_xray = Button.new()
	btn_hint_xray.custom_minimum_size = Vector2(166.0, 32.0)
	btn_hint_xray.pressed.connect(func() -> void:
		var next_x: bool = not bool(_eng_get("xray_level", false))
		_eng_set_if_has("xray_level", next_x)
		if next_x:
			_record_hint_tier_usage(HintBlueprintView.TIER_FULL)
		audio.play_named("coin", 1.1)
		_refresh_hint_contents()
	)
	hdr.add_child(btn_hint_xray)

	var close_hb: Button = _make_icon_slot_button("ui_btn_x", 34.0, Color("#fb7185"))
	close_hb.pressed.connect(func() -> void:
		audio.play_named("block", 0.96)
		var p: Dictionary = _player_dict()
		if in_game and not p.is_empty() and bool(p.get("dead", false)):
			var dc: String = str(_eng_get("pending_death_cause", "general"))
			open_death_modal(dc if dc != "" else "general")
		else:
			close_all_modals(true)
	)
	hdr.add_child(close_hb)

	# 3-Tier Progressive Hint Selector Row (Light -> Medium -> Full)
	var tier_row: HBoxContainer = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	vb.add_child(tier_row)

	hint_tier_btns.clear()
	for t_id in [HintBlueprintView.TIER_LIGHT, HintBlueprintView.TIER_MEDIUM, HintBlueprintView.TIER_FULL]:
		var tb: Button = Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0.0, 32.0)
		var cap_tid: int = t_id
		tb.pressed.connect(func() -> void:
			audio.play_named("hint_popup", 0.96 + float(cap_tid) * 0.06)
			hint_blueprint.set_tier(cap_tid, _cur_lv_id())
			_record_hint_tier_usage(cap_tid)
			_apply_smooth_scroll("hint", 0.0)
			_refresh_hint_contents()
		)
		tier_row.add_child(tb)
		hint_tier_btns[t_id] = tb

	hint_medal_note_lbl = Label.new()
	hint_medal_note_lbl.add_theme_font_size_override("font_size", 11)
	hint_medal_note_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vb.add_child(hint_medal_note_lbl)

	var mid_hb: HBoxContainer = HBoxContainer.new()
	mid_hb.add_theme_constant_override("separation", 10)
	vb.add_child(mid_hb)

	hint_blueprint = HintBlueprintView.new()
	hint_blueprint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_blueprint.setup(textures, font_main)
	mid_hb.add_child(hint_blueprint)

	hint_illust_rect = TextureRect.new()
	hint_illust_rect.custom_minimum_size = Vector2(204.0, 158.0)
	hint_illust_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_illust_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mid_hb.add_child(hint_illust_rect)

	hint_quote_lbl = Label.new()
	hint_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_quote_lbl.add_theme_font_size_override("font_size", 12)
	hint_quote_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	vb.add_child(hint_quote_lbl)

	hint_scroll_clip = Control.new()
	hint_scroll_clip.clip_contents = true
	hint_scroll_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_scroll_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint_scroll_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	hint_scroll_clip.resized.connect(func() -> void:
		if hint_steps_vbox != null:
			hint_steps_vbox.size.x = maxf(200.0, hint_scroll_clip.size.x - 14.0)
			_apply_smooth_scroll("hint", hint_scroll_y)
	)
	hint_scroll_clip.draw.connect(func() -> void:
		_draw_custom_scrollbar(hint_scroll_clip, hint_steps_vbox, hint_scroll_y, Color("#fde047"))
	)
	vb.add_child(hint_scroll_clip)

	hint_steps_vbox = VBoxContainer.new()
	hint_steps_vbox.position = Vector2.ZERO
	hint_steps_vbox.size = Vector2(786.0, 128.0)
	hint_steps_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hint_steps_vbox.add_theme_constant_override("separation", 5)
	hint_scroll_clip.add_child(hint_steps_vbox)

	btn_hint_resume = Button.new()
	btn_hint_resume.custom_minimum_size = Vector2(230.0, 38.0)
	btn_hint_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_hint_resume.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 16, 5))
	btn_hint_resume.pressed.connect(func() -> void:
		audio.play_named("coin", 1.08)
		var p: Dictionary = _player_dict()
		var was_dead: bool = (not p.is_empty()) and bool(p.get("dead", false))
		close_all_modals(true)
		if was_dead:
			request_retry_stage.emit()
	)
	vb.add_child(btn_hint_resume)

func _record_hint_tier_usage(tier: int) -> void:
	max_hint_tier_this_attempt = maxi(max_hint_tier_this_attempt, tier)
	if tier >= HintBlueprintView.TIER_FULL:
		hint_blueprint.mark_full_hint_used(_cur_lv_id())
	_eng_set_if_has("hints_used_tier", max_hint_tier_this_attempt)
	_eng_set_if_has("used_full_hint", max_hint_tier_this_attempt >= HintBlueprintView.TIER_FULL)
	_eng_call("set_hint_tier_used", [max_hint_tier_this_attempt])

func _sync_hint_vbox_layout() -> void:
	if hint_scroll_clip == null or hint_steps_vbox == null:
		return
	var target_w: float = maxf(200.0, (hint_scroll_clip.size.x if hint_scroll_clip.size.x > 50.0 else 796.0) - 14.0)
	hint_steps_vbox.custom_minimum_size.x = target_w
	hint_steps_vbox.size.x = target_w
	hint_steps_vbox.reset_size()
	hint_steps_vbox.size.x = target_w
	_apply_smooth_scroll("hint", hint_scroll_y)

func _refresh_hint_contents() -> void:
	var lv: Dictionary = _cur_lv_data()
	var lv_id: int = _cur_lv_id()
	var nm: String = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	hint_title_lbl.text = "LV.%03d · %s — %s" % [lv_id, nm, _tr("三级渐进提示系统", "3-TIER PROGRESSIVE HINTS")]

	var xray_on: bool = bool(_eng_get("xray_level", false))
	btn_hint_xray.text = _tr("X-Ray 透视：已开启 ✓" if xray_on else "开启 X-Ray 机关透视", "X-RAY: ON ✓" if xray_on else "ENABLE X-RAY")

	var cur_t: int = hint_blueprint.get_tier()
	(hint_tier_btns[1] as Button).text = _tr("① 轻提示 · 观察线索 (不剧透)", "① LIGHT · Observe Clues")
	(hint_tier_btns[2] as Button).text = _tr("② 中提示 · 隐藏规则解析", "② MEDIUM · Hidden Rules")
	(hint_tier_btns[3] as Button).text = _tr("③ 完整提示 · 分步路线 ①②③", "③ FULL · Route ①②③④⑤")

	var t_cols: Dictionary = { 1: Color("#67e8f9"), 2: Color("#c084fc"), 3: Color("#fde047") }
	for tid in [1, 2, 3]:
		var tb: Button = hint_tier_btns[tid]
		var on_t: bool = (tid == cur_t)
		var tc: Color = t_cols[tid]
		tb.add_theme_stylebox_override("normal", _make_flat_box(Color("#182558") if on_t else Color("#09112c"), tc if on_t else Color("#334155"), 2 if on_t else 1, 7, 8, 4))

	var used_full: bool = hint_blueprint.has_used_full_hint(lv_id)
	hint_medal_note_lbl.text = _tr(
		"提示说明：轻提示不影响银章评定；主动展开【③完整提示】本局已记录为使用完整提示（不影响通关与解锁章节，仅影响本局银/金章挑战）" if used_full else "提示说明：轻提示指明观察对象不剧透且保留银章资格；需要时可随时主动展开中提示或完整路线 ①②③④⑤（绝不阻碍通关与解锁）",
		"Full Hint active for this run (never blocks clear/unlock; affects Silver/Gold challenge medal)." if used_full else "Light Hint keeps Silver Medal eligibility; expand Medium or Full Route ①②③④⑤ anytime without blocking clear/unlock."
	)

	var hpack: Dictionary = hint_blueprint.get_progressive_hints(save.lang)
	var p_tags: Array = hpack.get("pitfall_tags", [])
	var tag_prefix: String = ("[" + " / ".join(p_tags) + "]  ") if not p_tags.is_empty() else ""
	hint_quote_lbl.text = "◈ " + tag_prefix + str(lv.get("subtitleEn" if save.lang == "en" else "subtitle", ""))

	var ill_key: String = str(lv.get("hintIllust", ""))
	if ill_key != "" and textures.has(ill_key) and cur_t >= HintBlueprintView.TIER_MEDIUM:
		hint_illust_rect.texture = _tex(ill_key)
		hint_illust_rect.visible = true
	else:
		hint_illust_rect.visible = false

	for ch in hint_steps_vbox.get_children():
		hint_steps_vbox.remove_child(ch)
		ch.queue_free()

	var l_lbl: Label = Label.new()
	l_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_lbl.text = _tr("【轻提示 · 观察焦点】", "[LIGHT · OBSERVATION] ") + str(hpack.get("light", ""))
	l_lbl.add_theme_font_size_override("font_size", 13)
	l_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	hint_steps_vbox.add_child(l_lbl)

	if cur_t >= HintBlueprintView.TIER_MEDIUM:
		var m_lbl: Label = Label.new()
		m_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_lbl.text = _tr("【中提示 · 规则机制】", "[MEDIUM · HIDDEN RULE] ") + str(hpack.get("medium", ""))
		m_lbl.add_theme_font_size_override("font_size", 13)
		m_lbl.add_theme_color_override("font_color", Color("#e9d5ff"))
		hint_steps_vbox.add_child(m_lbl)

	if cur_t >= HintBlueprintView.TIER_FULL:
		var steps: Array = hpack.get("full", [])
		for i in range(steps.size()):
			var slb: Label = Label.new()
			slb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			slb.text = str(steps[i])
			slb.add_theme_font_size_override("font_size", 13)
			slb.add_theme_color_override("font_color", Color("#fef08a"))
			hint_steps_vbox.add_child(slb)

	btn_hint_resume.text = _tr("继续挑战 (可左右拖拽上方蓝图平移查看)", "CONTINUE CHALLENGE (Drag Blueprint to Pan)")
	call_deferred("_sync_hint_vbox_layout")

# --- 4E. STAGE CLEAR SUMMARY MODAL (4-Tier Medal Promotion Animation + Time + Deaths) ---
func _build_clear_modal() -> void:
	clear_panel = _center_card(612.0, 396.0, Color("#4ade80"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	clear_panel.add_child(vb)

	var hdr_hb: HBoxContainer = HBoxContainer.new()
	hdr_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr_hb.add_theme_constant_override("separation", 8)
	var chk_ic: TextureRect = TextureRect.new()
	chk_ic.custom_minimum_size = Vector2(28.0, 28.0)
	chk_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chk_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chk_ic.texture = _tex("badge_clear" if textures.has("badge_clear") else "ui_btn_check")
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

	# Animated 4-Tier Medal Promotion Showcase (Copper -> Silver -> Gold -> Anti-Troll)
	clear_medals_canvas = Control.new()
	clear_medals_canvas.custom_minimum_size = Vector2(540.0, 74.0)
	clear_medals_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_medals_canvas.draw.connect(_draw_clear_medals_showcase)
	vb.add_child(clear_medals_canvas)

	clear_stars_box = HBoxContainer.new()
	clear_stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	clear_stars_box.add_theme_constant_override("separation", 6)
	vb.add_child(clear_stars_box)

	clear_stats_lbl = Label.new()
	clear_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_stats_lbl.add_theme_font_size_override("font_size", 13)
	clear_stats_lbl.add_theme_color_override("font_color", Color("#fde047"))
	vb.add_child(clear_stats_lbl)

	var brow: HBoxContainer = HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 10)
	vb.add_child(brow)

	btn_clear_replay = Button.new()
	btn_clear_replay.custom_minimum_size = Vector2(128.0, 40.0)
	btn_clear_replay.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		close_all_modals(false)
		request_start_stage.emit(_cur_lv_id())
	)
	brow.add_child(btn_clear_replay)

	btn_clear_hall = Button.new()
	btn_clear_hall.custom_minimum_size = Vector2(128.0, 40.0)
	btn_clear_hall.pressed.connect(func() -> void:
		audio.play_named("block", 1.05)
		open_level_select_modal()
	)
	brow.add_child(btn_clear_hall)

	btn_clear_next = Button.new()
	btn_clear_next.custom_minimum_size = Vector2(196.0, 40.0)
	btn_clear_next.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 12, 6))
	btn_clear_next.pressed.connect(func() -> void: _on_clear_primary_action())
	brow.add_child(btn_clear_next)

func _draw_clear_medals_showcase() -> void:
	if font_main == null:
		return
	var specs: Array = [
		["copper", _tr("铜章 · 突破", "COPPER")],
		["silver", _tr("银章 · 稳健", "SILVER")],
		["gold", _tr("金章 · 精通", "GOLD")],
		["anti_troll", _tr("反套路徽章", "ANTI-TROLL")]
	]
	var w: float = maxf(480.0, clear_medals_canvas.size.x)
	var cell_w: float = w / 4.0
	for i in range(4):
		var mk: String = str(specs[i][0])
		var mlbl: String = str(specs[i][1])
		var earned: bool = bool(clear_medals_data.get(mk, false))
		var reveal_delay: float = float(i) * 0.18
		var local_t: float = clampf((clear_medal_anim_t - reveal_delay) / 0.28, 0.0, 1.0)
		var pop_scale: float = (1.0 + sin(local_t * PI) * 0.26) if (earned and local_t > 0.0 and local_t < 1.0) else 1.0
		var show_earned: bool = earned and (clear_medal_anim_t >= reveal_delay)
		var cx: float = cell_w * (float(i) + 0.5)
		var cy: float = 28.0
		if show_earned:
			clear_medals_canvas.draw_circle(Vector2(cx, cy), 22.0 * pop_scale, Color(1.0, 0.92, 0.35, 0.14))
		_draw_medal_pip(clear_medals_canvas, Vector2(cx, cy), 16.0 * pop_scale, mk, show_earned)
		clear_medals_canvas.draw_string(
			font_main,
			Vector2(cx - cell_w * 0.46, 64.0),
			mlbl,
			HORIZONTAL_ALIGNMENT_CENTER,
			cell_w * 0.92,
			11,
			Color("#fde047") if show_earned else Color("#64748b")
		)

func _on_clear_primary_action() -> void:
	var cur_lv: int = _cur_lv_id()
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

# --- 4F. SKIPPABLE CG STORY THEATER MODAL (Master GDD 8.2: Skip Still Unlocks Gallery!) ---
func _build_cg_modal() -> void:
	cg_panel = _center_card(852.0, 496.0, Color("#fde047"))
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	cg_panel.add_child(vb)

	var top_hb: HBoxContainer = HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 10)
	cg_badge_lbl = Label.new()
	cg_badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cg_badge_lbl.add_theme_font_size_override("font_size", 14)
	cg_badge_lbl.add_theme_color_override("font_color", Color("#fde047"))
	top_hb.add_child(cg_badge_lbl)

	cg_page_lbl = Label.new()
	cg_page_lbl.add_theme_font_size_override("font_size", 14)
	cg_page_lbl.add_theme_color_override("font_color", Color("#67e8f9"))
	top_hb.add_child(cg_page_lbl)

	btn_cg_skip = Button.new()
	btn_cg_skip.custom_minimum_size = Vector2(138.0, 30.0)
	btn_cg_skip.pressed.connect(_on_skip_cg_pressed)
	top_hb.add_child(btn_cg_skip)
	vb.add_child(top_hb)

	var art_frame: PanelContainer = PanelContainer.new()
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.add_theme_stylebox_override("panel", _make_flat_box(Color("#020617"), Color("#38bdf8"), 2, 8, 4, 4))
	cg_art_rect = TextureRect.new()
	cg_art_rect.custom_minimum_size = Vector2(780.0, 286.0)
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
	btn_cg_next.custom_minimum_size = Vector2(176.0, 38.0)
	btn_cg_next.add_theme_stylebox_override("normal", _make_flat_box(Color("#064e3b"), Color("#4ade80"), 2, 8, 14, 5))
	btn_cg_next.pressed.connect(func() -> void:
		if cg_index + 1 < cg_slides.size():
			cg_index += 1
			audio.play_named("coin", 1.06)
			_refresh_cg_slide()
		else:
			_finish_cg_theater()
	)
	brow.add_child(btn_cg_next)
	vb.add_child(brow)

func _unlock_all_current_cg_slides() -> void:
	var dirty: bool = false
	for sl_v in cg_slides:
		if typeof(sl_v) == TYPE_DICTIONARY:
			var sl: Dictionary = sl_v
			var cid: String = str(sl.get("id", sl.get("img", "")))
			if cid != "" and not bool(save.seen_cgs.get(cid, false)):
				save.seen_cgs[cid] = true
				dirty = true
	if dirty:
		save.persist()

func _on_skip_cg_pressed() -> void:
	# Master GDD 8.2: Skipping CG still records all slides into Gallery (`跳过仍入图鉴`)!
	_unlock_all_current_cg_slides()
	audio.play_named("coin", 1.1)
	_finish_cg_theater()

func _finish_cg_theater() -> void:
	_unlock_all_current_cg_slides()
	audio.play_named("coin", 1.14)
	var after_lv: int = cg_after_stage_id
	close_all_modals(false)
	if after_lv > 0 and after_lv < 150:
		request_start_stage.emit(after_lv + 1)
	elif after_lv == 150:
		open_level_select_modal()
	elif not in_game:
		show_title_screen()

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
	btn_cg_skip.text = _tr("跳过 (仍入图鉴) »", "SKIP (Saves CG) »")
	cg_art_rect.texture = _tex(str(sl.get("img", "")))
	cg_ep_lbl.text = str(sl.get("enEp" if save.lang == "en" else "zhEp", ""))
	cg_cap_lbl.text = str(sl.get("enCap" if save.lang == "en" else "zhCap", ""))
	btn_cg_prev.visible = cg_slides.size() > 1
	btn_cg_prev.disabled = (cg_index <= 0)
	btn_cg_prev.text = _tr("◀ 上一幕", "◀ PREV")
	if cg_index + 1 < cg_slides.size():
		btn_cg_next.text = _tr("下一幕 ▶", "NEXT PANEL ▶")
	elif cg_after_stage_id > 0 and cg_after_stage_id < 150:
		btn_cg_next.text = _tr("前往第 %03d 关 ▶" % (cg_after_stage_id + 1), "STAGE %03d ▶" % (cg_after_stage_id + 1))
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
	active_subtitles.clear()
	close_all_modals(true)
	title_view.visible = true
	hud_view.visible = false
	touch_overlay.visible = false
	audio.select_track(true, 1)

func enter_gameplay_hud(stage_id: int) -> void:
	in_game = true
	max_hint_tier_this_attempt = 0
	active_subtitles.clear()
	if hint_blueprint != null:
		hint_blueprint.reset_stage_hint_usage(stage_id)
	close_all_modals(true)
	title_view.visible = false
	hud_view.visible = true
	touch_overlay.visible = true
	sync_safe_area_and_layout()
	last_hud_sig = ""
	last_pad_sig = ""
	var lv: Dictionary = _levels_map().get(stage_id, _cur_lv_data())
	var st_title: String = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	var sec_col: Color = Color("#38bdf8") if stage_id >= 101 else (Color("#c084fc") if stage_id >= 51 else Color("#00f5ff"))
	show_stage_banner("LV.%03d · %s" % [stage_id, st_title], sec_col, 3.0)
	refresh_hud()
	touch_overlay.queue_redraw()

func open_level_select_from_title() -> void:
	var target_lv: int = save.last_lv if save.is_stage_unlocked(save.last_lv) else save.get_highest_frontier_level(0)
	selected_chapter = clampi(int(ceil(float(target_lv) / 10.0)), 1, 15)
	selected_sector = clampi(int(ceil(float(selected_chapter) / 5.0)), 1, 3)
	_open_exclusive("hall", hall_panel)
	_refresh_hall_contents()

func open_level_select_modal() -> void:
	var cur_lv: int = _cur_lv_id() if in_game else save.last_lv
	selected_chapter = clampi(int(ceil(float(cur_lv) / 10.0)), 1, 15)
	selected_sector = clampi(int(ceil(float(selected_chapter) / 5.0)), 1, 3)
	_open_exclusive("hall", hall_panel)
	_refresh_hall_contents()

func open_options_modal(tab_key: String = "config") -> void:
	options_tab = tab_key
	reset_confirm_armed = false
	_open_exclusive("options", options_panel)
	_apply_smooth_scroll("options", 0.0)
	_refresh_options_contents()

func open_death_modal(cause_key: String) -> void:
	_open_exclusive("death", death_panel)
	var causes: Dictionary = meta.get("causeLabels", {})
	var c_obj: Dictionary = causes.get(cause_key, causes.get("general", { "zh": "× 死因：初见杀陷阱", "en": "× CAUSE: TROLL TRAP" }))
	death_cause_lbl.text = str(c_obj.get("en" if save.lang == "en" else "zh", ""))

	var taunts_map: Dictionary = meta.get("deathTaunts", {})
	var pool: Array = taunts_map.get(cause_key, taunts_map.get("general", []))
	if pool.is_empty():
		death_taunt_lbl.text = _tr("墨镜赛博猫：「就这？复盘一下刚才触发机关的细节喵！」", "Cyber-Cat: 'Review what triggered that mechanism!'")
	else:
		var pick: Dictionary = pool[randi() % pool.size()]
		death_taunt_lbl.text = str(pick.get("en" if save.lang == "en" else "zh", ""))

	# Master GDD 11.2: After first death, gently prompt observation without spoiling!
	var att_d: int = int(_eng_get("attempt_deaths", 1))
	var max_d: int = int(_eng_call("get_max_deaths", [], att_d))
	death_obs_tip_lbl.text = _tr(
		"◈ 复盘线索：回想刚才触发机关的声音、阴影或状态变化（点击【三级提示】可查看不剧透观察焦点）",
		"◈ Review Clue: Notice the sound, shadow, or state change right before failure (Tap [3-Tier Hint] for spoiler-free focus)"
	)
	death_stat_lbl.text = _tr("本局失误：%d 次  |  历史最高：%d 次" % [att_d, max_d], "Attempt Fails: %d  |  Stage Max: %d" % [att_d, max_d])
	btn_death_retry.text = _tr("↻ 立即重来 (R)", "↻ RETRY (R)")
	btn_death_hint.text = _tr("◈ 三级渐进提示", "◈ 3-TIER HINT")
	btn_death_hall.text = _tr("▦ 选关大厅", "▦ STAGES")

func open_hint_modal() -> void:
	var lv: Dictionary = _cur_lv_data()
	hint_blueprint.set_stage(lv, true)
	_record_hint_tier_usage( maxi(HintBlueprintView.TIER_LIGHT, hint_blueprint.get_tier()) )
	_open_exclusive("hint", hint_panel)
	_apply_smooth_scroll("hint", 0.0)
	_refresh_hint_contents()

func open_clear_modal(win_res: Dictionary) -> void:
	_open_exclusive("clear", clear_panel)
	clear_medal_anim_t = 0.0

	var lv_id: int = _cur_lv_id()
	var lv: Dictionary = _cur_lv_data()
	var stars_n: int = int(win_res.get("stars", 5))
	var reward_g: int = int(win_res.get("reward", 25))
	var iq_score: int = int(win_res.get("iq", 250))
	var clear_sec: float = float(win_res.get("time_elapsed", _eng_get("time_elapsed", 0.0)))
	var att_d: int = int(_eng_get("attempt_deaths", 0))

	# Resolve 4-tier medals (if StageEngine used legacy 2-arg mark_stage_cleared, evaluate/update cleanly with hint tier & time!)
	var used_full_h: bool = hint_blueprint.has_used_full_hint(lv_id)
	var eff_hint_tier: int = 3 if used_full_h else max_hint_tier_this_attempt
	if win_res.has("medals") and typeof(win_res["medals"]) == TYPE_DICTIONARY:
		clear_medals_data = (win_res["medals"] as Dictionary).duplicate()
	elif save.has_method("evaluate_stage_medals"):
		var has_sh: bool = bool(save.shards.get(str(lv_id), false))
		var anti_t: bool = bool(win_res.get("anti_troll_earned", _eng_get("anti_troll_earned", false)))
		var lv_st_cfg: int = int(lv.get("stars", 3))
		clear_medals_data = save.evaluate_stage_medals(lv_id, att_d, clear_sec, eff_hint_tier, has_sh, anti_t, lv_st_cfg)
		save.persist()
	else:
		clear_medals_data = { "copper": true, "silver": (att_d <= 3 and not used_full_h), "gold": (att_d == 0 and eff_hint_tier == 0), "anti_troll": false }

	clear_title_lbl.text = _tr("第 %03d 关 突破成功！" % lv_id, "STAGE %03d CLEARED!" % lv_id)
	var c_txt: String = str(lv.get("clearTextEn" if save.lang == "en" else "clearText", ""))
	if c_txt == "":
		c_txt = str(lv.get("nameEn" if save.lang == "en" else "name", ""))
	clear_sub_lbl.text = c_txt

	for ch in clear_stars_box.get_children():
		ch.queue_free()
	for si in range(5):
		var sr: TextureRect = TextureRect.new()
		sr.custom_minimum_size = Vector2(26.0, 26.0)
		sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sr.texture = _tex("star_gold" if si < stars_n else "star_empty")
		clear_stars_box.add_child(sr)

	var hint_stat_s: String = _tr("完整提示" if used_full_h else ("轻/中提示" if eff_hint_tier > 0 else "无提示"), "Full Hint" if used_full_h else ("Light/Med" if eff_hint_tier > 0 else "No Hint"))
	clear_stats_lbl.text = _tr(
		"用时：%s  |  失误：%d 次  |  %s  |  IQ %d  |  赏金 +%d G (共 %d G)" % [_format_time_sec(clear_sec), att_d, hint_stat_s, iq_score, reward_g, save.coins],
		"Time: %s  |  Fails: %d  |  %s  |  IQ %d  |  +%d G (Total %d G)" % [_format_time_sec(clear_sec), att_d, hint_stat_s, iq_score, reward_g, save.coins]
	)
	btn_clear_replay.text = _tr("↻ 重玩本关", "↻ REPLAY")
	btn_clear_hall.text = _tr("▦ 选关大厅", "▦ STAGES")

	var cgs_map: Dictionary = meta.get("milestoneCgs", {})
	if cgs_map.has(str(lv_id)):
		var cnt: int = (cgs_map[str(lv_id)] as Array).size()
		btn_clear_next.text = _tr("▶ 观看章节 CG (%d幕) ▶" % cnt, "▶ WATCH CG (%d) ▶" % cnt)
	elif lv_id < 150:
		btn_clear_next.text = _tr("下一关 (LV.%03d) ▶" % (lv_id + 1), "NEXT (LV.%03d) ▶" % (lv_id + 1))
	else:
		btn_clear_next.text = _tr("★ 150关大满贯达成！", "★ ALL 150 CLEARED!")

	clear_medals_canvas.queue_redraw()

func open_cg_modal(slides: Array, after_stage: int = 0) -> void:
	cg_slides = slides
	cg_index = 0
	cg_after_stage_id = after_stage
	_open_exclusive("cg", cg_panel)
	_refresh_cg_slide()

func open_exit_modal() -> void:
	_open_exclusive("exit", exit_panel)
	exit_title_lbl.text = _tr("离开哥查德的大冒险？", "LEAVE GODCHARD ADVENTURE?")
	exit_desc_lbl.text = _tr("双槽原子存档已实时保护你的奖章、最佳用时、CG图鉴与金币进度。", "Dual-slot atomic save protects all your medals, best times, CGs, and coins.")
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
	if btn_title_chapters != null:
		btn_title_chapters.text = "❖ 15 CHAPTERS" if is_en else "❖ 15章选关"
	if btn_title_gallery != null:
		btn_title_gallery.text = "▶ CG GALLERY" if is_en else "▶ CG图鉴"
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
	last_pad_sig = ""
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
	elif active_modal == "clear":
		if clear_medal_anim_t < 1.5:
			clear_medal_anim_t += dt
			clear_medals_canvas.queue_redraw()

	# Subpixel kinetic inertia coasting for SmoothScrollBox (`options`, `hint`, `chapters`)
	var spair: Array = _get_active_scroll_pair()
	if not spair.is_empty() and not scroll_is_dragging and absf(scroll_velocity_y) > 4.0:
		var s_kind: String = str(spair[2])
		var cur_y_step: float = _get_cur_scroll_val(s_kind)
		_apply_smooth_scroll(s_kind, cur_y_step + scroll_velocity_y * dt)
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

	# Step Accessibility Audio-Visual Subtitles & Sync from EventBus if present
	var eb: Variant = _eng_get("event_bus", null)
	if eb != null and typeof(eb) == TYPE_OBJECT and (eb as Object).has_method("get_active_captions"):
		if (eb as Object).has_method("step_captions"):
			(eb as Object).call("step_captions", dt)
		var eb_caps: Variant = (eb as Object).call("get_active_captions")
		if typeof(eb_caps) == TYPE_ARRAY:
			for ec_v in (eb_caps as Array):
				if typeof(ec_v) == TYPE_DICTIONARY:
					var ec: Dictionary = ec_v
					push_visual_subtitle(
						str(ec.get("zh", "")),
						str(ec.get("en", "")),
						str(ec.get("icon", "ui_audio")),
						str(ec.get("color", "#00f5ff")),
						"chime",
						float(ec.get("life", 1.2)),
						str(ec.get("tag", "eb"))
					)

	if not active_subtitles.is_empty():
		for si in range(active_subtitles.size() - 1, -1, -1):
			var sd: Dictionary = active_subtitles[si]
			sd["life"] = float(sd.get("life", 0.0)) - dt
			if float(sd["life"]) <= 0.0:
				active_subtitles.remove_at(si)
		if subtitle_overlay_canvas != null:
			subtitle_overlay_canvas.queue_redraw()

	if in_game and active_modal == "":
		var p_chk: Dictionary = _player_dict()
		var need_refresh: bool = bool(_eng_get("hud_dirty", false))
		if float(_eng_get("timer_left", -1.0)) >= 0.0:
			need_refresh = true
		if float(p_chk.get("golden_timer", 0.0)) > 0.0 or float(p_chk.get("poison_timer", 0.0)) > 0.0 or float(p_chk.get("antidote_window", 0.0)) > 0.0 or bool(p_chk.get("has_flight", false)) or float(_ws_get("sun_heat", 0.0)) > 0.5:
			need_refresh = true
		if need_refresh:
			_eng_set_if_has("hud_dirty", false)
			refresh_hud()
		if is_touch_pad_visible():
			_ensure_pad_geometry()
