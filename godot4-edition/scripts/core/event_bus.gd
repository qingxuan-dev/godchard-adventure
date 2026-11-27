class_name EventBus
extends RefCounted

var listeners: Dictionary = {}
var event_queue: Array = []
var event_history: Array = []
var visual_captions: Array = []
var captions_enabled: bool = true
var max_active_captions: int = 5
var max_history: int = 96
var last_step_msec: int = -999

const SFX_CAPTION_PRESETS: Dictionary = {
	"cloud_solid": {
		"zh": "【沉闷落脚声】承重实云 · 安全落脚",
		"en": "[SOLID THUD] Weight-Bearing Cloud",
		"icon": "cloud_safe",
		"color": "#38bdf8",
		"dur": 1.55,
		"important": true
	},
	"cloud_blade": {
		"zh": "【金属颤音】藏刀危云 · 侧面碎核卸刀！",
		"en": "[METALLIC RING] Blade Cloud · Hit Side Core!",
		"icon": "cloud_knife",
		"color": "#fb7185",
		"dur": 1.85,
		"important": true
	},
	"cloud_hollow": {
		"zh": "【空心噗声】虚胖假云 · 雷击可短暂凝实",
		"en": "[HOLLOW POOF] Fake Cloud · Thunder Solidifies",
		"icon": "cloud_safe",
		"color": "#cbd5e1",
		"dur": 1.65,
		"important": true
	},
	"cloud_bounce": {
		"zh": "【弹性嗡鸣】高弹跳云 · 固定弹升",
		"en": "[BOUNCE HUM] Elastic Cloud · Fixed Launch",
		"icon": "cloud_safe",
		"color": "#4ade80",
		"dur": 1.50,
		"important": true
	},
	"pipe_echo_single": {
		"zh": "【单滴回声】真实单向连通管道",
		"en": "[SINGLE ECHO] Connected Transit Pipe",
		"icon": "pipe",
		"color": "#4ade80",
		"dur": 1.75,
		"important": true
	},
	"pipe_echo_double": {
		"zh": "【双重回声】循环回路管道 · 需改阀门！",
		"en": "[DOUBLE ECHO] Loop Pipe · Reroute Valve!",
		"icon": "pipe",
		"color": "#c084fc",
		"dur": 1.85,
		"important": true
	},
	"clock_low": {
		"zh": "【低音钟鸣】低频相位 · 召唤/减速节拍",
		"en": "[LOW CHIME] Bass Frequency Beat",
		"icon": "clock_gold",
		"color": "#38bdf8",
		"dur": 1.65,
		"important": true
	},
	"clock_high": {
		"zh": "【高音钟鸣】高频相位 · 加速/唤醒节拍",
		"en": "[HIGH CHIME] Treble Frequency Beat",
		"icon": "clock_gold",
		"color": "#fde047",
		"dur": 1.65,
		"important": true
	},
	"clock_gear": {
		"zh": "【齿轮滴答】局部时钟作用域切换",
		"en": "[GEAR TICK] Local Time Scope Active",
		"icon": "clock_gear",
		"color": "#fb923c",
		"dur": 1.60,
		"important": true
	},
	"sword_sheathe": {
		"zh": "【收剑入鞘】解除武器敌意 · 非攻击姿态",
		"en": "[SWORD SHEATHED] Non-Aggression Stance",
		"icon": "icon_sword",
		"color": "#4ade80",
		"dur": 1.75,
		"important": true
	},
	"ground_pound": {
		"zh": "【三段下砸】重锤震击地面机关",
		"en": "[GROUND POUND] Heavy Downward Impact",
		"icon": "icon_spring",
		"color": "#a855f7",
		"dur": 1.35,
		"important": true
	},
	"valve_turn": {
		"zh": "【阀门旋转】水渠压力池流向重分配",
		"en": "[VALVE SPUN] Aqueduct Pressure Rerouted",
		"icon": "s3_valve_red",
		"color": "#38bdf8",
		"dur": 1.60,
		"important": true
	},
	"mirror_ping": {
		"zh": "【镜面清音】反射角偏转 · 弹道折返",
		"en": "[MIRROR PING] Trajectory Reflected",
		"icon": "mirror_wall",
		"color": "#67e8f9",
		"dur": 1.45,
		"important": true
	},
	"sundial_shift": {
		"zh": "【日晷移相】光影与昼暮夜相位流转",
		"en": "[SUNDIAL SHIFT] Day/Dusk/Night Shifted",
		"icon": "s3_sundial_orb",
		"color": "#fde047",
		"dur": 1.75,
		"important": true
	},
	"shield_parry": {
		"zh": "【护盾弹反】抵消一次匹配致命伤害",
		"en": "[SHIELD PARRY] Matched Hit Negated",
		"icon": "icon_shield",
		"color": "#00f5ff",
		"dur": 1.45,
		"important": true
	},
	"armor_clang": {
		"zh": "【护甲铿锵】免疫直击 · 寻找机制弱点",
		"en": "[ARMOR CLANG] Immune · Use Puzzle Weakness",
		"icon": "ach_shield",
		"color": "#94a3b8",
		"dur": 1.35,
		"important": false
	},
	"fake_wall_shatter": {
		"zh": "【全息碎裂】伪墙/伪窗已被识破",
		"en": "[SHATTER] Illusion Broken",
		"icon": "qblock",
		"color": "#c084fc",
		"dur": 1.40,
		"important": false
	},
	"fake_buzz": {
		"zh": "【警报蜂鸣】触发诱饵或非法顺序！",
		"en": "[TRAP BUZZ] Decoy or Invalid Sequence!",
		"icon": "ui_skull",
		"color": "#f43f5e",
		"dur": 1.45,
		"important": false
	},
	"poison": {
		"zh": "【毒素沸腾】毒态计时生效 · 可催化植物",
		"en": "[TOXIN] Poison Active · Reacts With Flora",
		"icon": "icon_poison",
		"color": "#c084fc",
		"dur": 1.50,
		"important": false
	},
	"portal_warp": {
		"zh": "【空间跃迁】传送门相位折跃",
		"en": "[PORTAL WARP] Spatial Phase Jump",
		"icon": "s2_portal_a",
		"color": "#38bdf8",
		"dur": 1.30,
		"important": false
	},
	"node_toggle": {
		"zh": "【信号切换】节点电平已翻转",
		"en": "[SIGNAL] Node Toggled",
		"icon": "s2_node_on",
		"color": "#00f5ff",
		"dur": 1.25,
		"important": false
	}
}

func subscribe(event_name: String, callback: Callable) -> void:
	if event_name == "" or not callback.is_valid():
		return
	if not listeners.has(event_name):
		listeners[event_name] = []
	var arr: Array = listeners[event_name]
	for cb_var in arr:
		var cb: Callable = cb_var
		if cb == callback:
			return
	arr.append(callback)

func unsubscribe(event_name: String, callback: Callable) -> void:
	if not listeners.has(event_name):
		return
	var arr: Array = listeners[event_name]
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] == callback:
			arr.remove_at(i)

func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	var evt: Dictionary = {
		"name": event_name,
		"payload": payload.duplicate(true),
		"tick_ms": Time.get_ticks_msec()
	}
	event_queue.append(evt)
	event_history.append(evt)
	while event_history.size() > max_history:
		event_history.pop_front()
	if listeners.has(event_name):
		var arr: Array = listeners[event_name].duplicate()
		for cb_var in arr:
			var cb: Callable = cb_var
			if cb.is_valid():
				cb.call(evt)

func pop_events() -> Array:
	var out: Array = event_queue.duplicate()
	event_queue.clear()
	return out

func get_event_log() -> Array:
	return event_history.duplicate()

func push_sfx_caption(sfx_name: String, world_pos: Vector2 = Vector2.ZERO, force: bool = false) -> Dictionary:
	if not captions_enabled and not force:
		return {}
	if not SFX_CAPTION_PRESETS.has(sfx_name):
		return {}
	var preset: Dictionary = SFX_CAPTION_PRESETS[sfx_name]
	return push_visual_caption(
		str(preset.get("zh", sfx_name)),
		str(preset.get("en", sfx_name)),
		str(preset.get("icon", "ui_audio")),
		str(preset.get("color", "#67e8f9")),
		float(preset.get("dur", 1.55)),
		world_pos,
		sfx_name
	)

func push_visual_caption(
	zh: String,
	en: String,
	icon: String = "ui_audio",
	color_hex: String = "#67e8f9",
	duration: float = 1.60,
	world_pos: Vector2 = Vector2.ZERO,
	tag: String = ""
) -> Dictionary:
	if tag != "":
		for existing_var in visual_captions:
			var existing: Dictionary = existing_var
			if str(existing.get("tag", "")) == tag:
				existing["zh"] = zh
				existing["en"] = en
				existing["icon"] = icon
				existing["color"] = color_hex
				existing["life"] = maxf(float(existing.get("life", 0.0)), duration)
				existing["max_life"] = maxf(float(existing.get("max_life", 0.1)), duration)
				existing["x"] = world_pos.x
				existing["y"] = world_pos.y
				return existing
	var entry: Dictionary = {
		"zh": zh,
		"en": en,
		"icon": icon,
		"color": color_hex,
		"life": maxf(0.25, duration),
		"max_life": maxf(0.25, duration),
		"x": world_pos.x,
		"y": world_pos.y,
		"has_world_pos": world_pos != Vector2.ZERO,
		"tag": tag
	}
	visual_captions.append(entry)
	while visual_captions.size() > max_active_captions:
		visual_captions.pop_front()
	return entry

func step_captions(dt: float) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if abs(now_ms - last_step_msec) < 4:
		return
	last_step_msec = now_ms
	for i in range(visual_captions.size() - 1, -1, -1):
		var cap: Dictionary = visual_captions[i]
		cap["life"] = float(cap.get("life", 0.0)) - dt
		if float(cap["life"]) <= 0.0:
			visual_captions.remove_at(i)

func get_active_captions() -> Array:
	return visual_captions

func clear_transient() -> void:
	event_queue.clear()
	visual_captions.clear()

func clear_listeners() -> void:
	listeners.clear()
