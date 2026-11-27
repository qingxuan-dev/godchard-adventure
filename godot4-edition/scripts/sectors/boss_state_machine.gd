class_name BossStateMachine
extends RefCounted

const BOSS_CATALOG: Dictionary = {
	"lv010_grad": {
		"name_zh": "新手毕业·双假旗反光高台",
		"name_en": "GRADUATION GAUNTLET",
		"max_phase": 4, "hp": 3, "armor": 2, "sheathe": true
	},
	"lv020_gate": {
		"name_zh": "中期综合·机关道具守门阵",
		"name_en": "RELIC HANDOFF GATEKEEPER",
		"max_phase": 5, "hp": 4, "armor": 3, "sheathe": false
	},
	"lv030_fortress": {
		"name_zh": "三层要塞·承重柱倾塔核心",
		"name_en": "CITADEL PILLAR CORE",
		"max_phase": 4, "hp": 3, "armor": 2, "sheathe": false
	},
	"lv038_mechaskull": {
		"name_zh": "机甲骷髅王·追门重装",
		"name_en": "GATE-CHASER MECHASKULL",
		"max_phase": 5, "hp": 5, "armor": 4, "sheathe": false
	},
	"lv040_museum": {
		"name_zh": "恶意博物馆·六展厅模仿中枢",
		"name_en": "MALICE MUSEUM CURATOR",
		"max_phase": 6, "hp": 6, "armor": 3, "sheathe": false
	},
	"lv050_author": {
		"name_zh": "作者之影·锁链自断导演战",
		"name_en": "THE AUTHOR",
		"max_phase": 4, "hp": 1, "armor": 3, "sheathe": true
	},
	"lv060_signal": {
		"name_zh": "信号风暴核心",
		"name_en": "SIGNAL STORM CORE",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv067_blindbox": {
		"name_zh": "盲盒重装守卫",
		"name_en": "BLINDBOX MECHA GUARD",
		"max_phase": 3, "hp": 12, "armor": 3, "sheathe": false
	},
	"lv070_mecha": {
		"name_zh": "机械统御者",
		"name_en": "MECHA OVERLORD",
		"max_phase": 3, "hp": 12, "armor": 4, "sheathe": false
	},
	"lv080_fracture": {
		"name_zh": "裂界核心",
		"name_en": "FRACTURE CORE",
		"max_phase": 3, "hp": 9, "armor": 4, "sheathe": true
	},
	"lv088_reaper": {
		"name_zh": "死神钟骷髅",
		"name_en": "CHRONO REAPER SKULL",
		"max_phase": 4, "hp": 10, "armor": 2, "sheathe": false
	},
	"lv090_chrono": {
		"name_zh": "时间统御者",
		"name_en": "CHRONO SOVEREIGN",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv098_admin": {
		"name_zh": "管理员分身竞技场",
		"name_en": "ADMIN CLONE OFFICE",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv100_null": {
		"name_zh": "根源管理员 NULL",
		"name_en": "ROOT ADMIN: NULL",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": true
	},
	"lv110_cloud_ram": {
		"name_zh": "发条金角绵羊云王",
		"name_en": "CLOCKWORK CLOUD RAM KING",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv120_hydra_pipe": {
		"name_zh": "飞瀑九头巨管王",
		"name_en": "NINE-HEADED HYDRA PIPE KING",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv130_kitsune_tanuki": {
		"name_zh": "九尾幻影忍狸宗师",
		"name_en": "NINE-TAILED PHANTOM TANUKI",
		"max_phase": 3, "hp": 9, "armor": 9, "sheathe": true
	},
	"lv140_thunder_demon": {
		"name_zh": "苍穹万刃雷云魔神",
		"name_en": "THUNDERBLADE CLOUD DEMON",
		"max_phase": 3, "hp": 9, "armor": 3, "sheathe": false
	},
	"lv150_solaris": {
		"name_zh": "曜金圣殿主宰 SOLARIS",
		"name_en": "SOLARIS · APEX OF ARCADIA",
		"max_phase": 5, "hp": 34, "armor": 5, "sheathe": true
	}
}

const LEGACY_KIND_MAP: Dictionary = {
	"signal_storm": "lv060_signal",
	"reassembly_mech": "lv067_blindbox",
	"lv067_reassembly": "lv067_blindbox",
	"mecha_sovereign": "lv070_mecha",
	"fracture_core": "lv080_fracture",
	"chrono_skull": "lv088_reaper",
	"lv088_chrono_skull": "lv088_reaper",
	"chrono_regent": "lv090_chrono",
	"admin_arena": "lv098_admin",
	"lv098_admin_clone": "lv098_admin",
	"null_admin": "lv100_null",
	"cloud_ram": "lv110_cloud_ram",
	"pipe_kaiser": "lv120_hydra_pipe",
	"kage_tanuki": "lv130_kitsune_tanuki",
	"blade_archon": "lv140_thunder_demon",
	"solaris_painter": "lv150_solaris"
}

const STAGE_DEFAULT_BOSS: Dictionary = {
	10: "lv010_grad",
	20: "lv020_gate",
	30: "lv030_fortress",
	38: "lv038_mechaskull",
	40: "lv040_museum",
	50: "lv050_author",
	60: "lv060_signal",
	67: "lv067_blindbox",
	70: "lv070_mecha",
	80: "lv080_fracture",
	88: "lv088_reaper",
	90: "lv090_chrono",
	98: "lv098_admin",
	100: "lv100_null",
	110: "lv110_cloud_ram",
	120: "lv120_hydra_pipe",
	130: "lv130_kitsune_tanuki",
	140: "lv140_thunder_demon",
	150: "lv150_solaris"
}

var state: Dictionary = {}

func _init() -> void:
	reset_empty()

func reset_empty() -> void:
	state = {
		"active": false,
		"boss_key": "",
		"name_zh": "",
		"name_en": "",
		"phase": 1,
		"max_phase": 1,
		"boss_hp": 0,
		"boss_max_hp": 0,
		"boss_armor": 0,
		"boss_max_armor": 0,
		"age_state": "young",
		"sheathe_required": false,
		"core_exposed": false,
		"defeated": false,
		"timer": 0.0,
		"calm_wait_timer": 0.0,
		"recorded_jump_dx": 0.0,
		"puzzle_flags": {},
		"hint_zh": "",
		"hint_en": ""
	}

static func resolve_boss_key(lv_id: int, lv_data: Dictionary, boss_ent: Dictionary = {}) -> String:
	if not boss_ent.is_empty():
		var bk_direct: String = str(boss_ent.get("bossKey", ""))
		if BOSS_CATALOG.has(bk_direct):
			return bk_direct
		var bkind: String = str(boss_ent.get("bossKind", boss_ent.get("boss_kind", "")))
		if BOSS_CATALOG.has(bkind):
			return bkind
		if LEGACY_KIND_MAP.has(bkind):
			return str(LEGACY_KIND_MAP[bkind])
	var props: Dictionary = lv_data.get("props", {}) if typeof(lv_data.get("props", null)) == TYPE_DICTIONARY else {}
	var prop_bid: String = str(props.get("bossId", ""))
	if BOSS_CATALOG.has(prop_bid):
		return prop_bid
	if LEGACY_KIND_MAP.has(prop_bid):
		return str(LEGACY_KIND_MAP[prop_bid])
	if STAGE_DEFAULT_BOSS.has(lv_id):
		return str(STAGE_DEFAULT_BOSS[lv_id])
	return ""

func init_for_stage(eng: RefCounted, lv_id: int, lv_data: Dictionary, cp: Dictionary = {}) -> void:
	reset_empty()
	var bkey: String = resolve_boss_key(lv_id, lv_data)
	if bkey == "":
		var objs: Array = lv_data.get("objs", [])
		for o_var in objs:
			var o: Dictionary = o_var
			if str(o.get("t", "")) in ["s2_boss", "s3_boss", "enemy_boss"]:
				bkey = resolve_boss_key(lv_id, lv_data, o)
				if bkey != "":
					break
	if bkey == "" or not BOSS_CATALOG.has(bkey):
		return

	var meta: Dictionary = BOSS_CATALOG[bkey]
	var max_hp: int = int(meta.get("hp", 9))
	var max_armor: int = int(meta.get("armor", 3))
	var max_p: int = int(meta.get("max_phase", 3))

	state = {
		"active": true,
		"boss_key": bkey,
		"name_zh": str(meta.get("name_zh", bkey)),
		"name_en": str(meta.get("name_en", bkey)),
		"phase": 1,
		"max_phase": max_p,
		"boss_hp": max_hp,
		"boss_max_hp": max_hp,
		"boss_armor": max_armor,
		"boss_max_armor": max_armor,
		"age_state": "young",
		"sheathe_required": bool(meta.get("sheathe", false)),
		"core_exposed": max_armor <= 0,
		"defeated": false,
		"timer": 0.0,
		"calm_wait_timer": 0.0,
		"recorded_jump_dx": 0.0,
		"puzzle_flags": _build_initial_flags(bkey),
		"hint_zh": _get_phase_hint_zh(bkey, 1),
		"hint_en": _get_phase_hint_en(bkey, 1)
	}

	if not cp.is_empty() and cp.has("boss_sm"):
		restore_checkpoint_snapshot(cp["boss_sm"])
	elif not cp.is_empty() and cp.has("boss_phase"):
		state["phase"] = clampi(int(cp.get("boss_phase", 1)), 1, max_p)
		state["boss_hp"] = clampi(int(cp.get("boss_hp", max_hp)), 1, max_hp)

	if eng != null:
		eng.boss_state = state

func _build_initial_flags(bkey: String) -> Dictionary:
	if bkey == "lv010_grad":
		return { "glass_shattered": false, "fake_flag_knocked": false, "sky_ladder_revealed": false }
	if bkey == "lv020_gate":
		return { "lens_used": false, "pipe_weighted": false, "follower_trapped": false, "wing_box_opened": false, "shield_weighted": false }
	if bkey == "lv030_fortress":
		return { "bomb_crafted": false, "chest_piped": false, "brake_broken": false, "pillar_slot_loaded": false, "tower_tilted": false }
	if bkey == "lv038_mechaskull":
		return { "fake_door_smashed": false, "mirror_room_lured": false, "gate_lock_reflected": false, "boss_trapped_in_gate": false }
	if bkey == "lv040_museum":
		return { "halls_cleared": 0 }
	if bkey == "lv050_author":
		return { "keys_slotted": 0, "chains_snapped": false, "fake_flag_gifted": false, "maintenance_hole_open": false }
	if bkey == "lv060_signal":
		return { "outer_lit": false, "red_cut": false, "blue_cut": false, "green_intact": true, "ground_pin_hits": 0 }
	if bkey == "lv070_mecha":
		return { "left_normal_charged": false, "right_reflect_charged": false, "lifted_over_furnace": false, "cables_cut": 0, "ground_wire_intact": true }
	if bkey == "lv080_fracture":
		return { "fake_popups_closed": 0, "real_popup_kept": true, "inside_shield": false, "mirrors_inward": 0 }
	if bkey == "lv090_chrono":
		return { "past_pulse_spent": false, "present_echo_hit": false, "future_chain_broken": false, "rewind_nodes_locked": 0 }
	if bkey == "lv100_null":
		return { "calm_lit": 0, "baited_stop": false, "null_self_deleting": false }
	if bkey == "lv110_cloud_ram":
		return { "windmill_rammed": false, "altar_locks_cut": 0, "long_jump_recorded": false, "dangling_off_edge": false }
	if bkey == "lv120_hydra_pipe":
		return { "dual_siphon": false, "high_heads_broken": 0, "empty_pool_inhaled": false, "bottom_vent_open": false }
	if bkey == "lv130_kitsune_tanuki":
		return { "illusions_collided": false, "shadows_stripped": false, "feint_baited": false, "tails_remaining": 9 }
	if bkey == "lv140_thunder_demon":
		return { "outer_clouds_shaved": 0, "cracked_cloud_kept": true, "lightning_reflected": false, "wind_wall_crashed": false, "cloud_pushed_core": false }
	if bkey == "lv150_solaris":
		return {
			"windmill_armor_broken": false,
			"water_refract_broken": false,
			"shadow_struck": false,
			"wind_double_broken": false,
			"sunset_active": false,
			"final_flare_active": false,
			"throne_core_open": false
		}
	return {}

func _get_phase_hint_zh(bkey: String, phase: int) -> String:
	if bkey == "lv010_grad":
		return "乘第2枚导弹撞碎上方玻璃，砍倒假旗杆后别进地下伪门，借玻璃反光跳上高空隐藏梯！"
	if bkey == "lv020_gate":
		return "把金币、追影怪与卸下的护盾分别交给对应配重/电磁开关，切勿贪留全部道具！"
	if bkey == "lv030_fortress":
		return "底层炼弹喂宝箱怪上二层，打断升降梯制动器把炸弹挤进承重柱侧槽，三层引爆倾塔成坡！"
	if bkey == "lv038_mechaskull":
		return "勿打机甲骷髅王（越打甲越厚）！引它撞假门、用镜面反炮弹打门锁，最后站门外诱它冲门自困！"
	if bkey == "lv050_author":
		return "停火勿打作者！集齐3枚钥匙插入路线槽让作者冲断自身锁链，把假旗留给它，从底座维修孔通关！"
	if bkey == "lv060_signal":
		return "点亮外环 -> 断红线过载 -> 切蓝线接地 -> 保留绿线稳压 -> 斩击暴露接地钉3次！"
	if bkey == "lv070_mecha":
		return "左肩喂普通弹、右肩喂镜面反射弹，乘巨掌托至熔炉上方，断双缆留地线诱其自反破甲！"
	if bkey == "lv080_fracture":
		return "关3假窗留真窗作反射面，钻进Boss护盾内不攻击，将4面玻璃镜朝内让弹幕循环自毁！"
	if bkey == "lv090_chrono":
		return "直击会让Boss回溯年轻！过去耗脉冲 -> 现在打回声 -> 未来断老化链 -> 锁3时锚后斩核心锚！"
	if bkey == "lv100_null":
		return "点亮两座CALM终端，朝第3座走去并在空白地板前急停，诱NULL复制越界自删后斩断根线！"
	if bkey == "lv110_cloud_ram":
		return "诱撞风车露齿轮 -> 花粉偏转云刃开双锁 -> 录制向右长跳后左短跳诱云王冲出祭坛边缘斩发条！"
	if bkey == "lv120_hydra_pipe":
		return "关左开右互吸 -> 镜面导水束打爆最高压3头 -> 趁吸空池开底泄压阀破水盾斩核心！"
	if bkey == "lv130_kitsune_tanuki":
		return "跳跃诱幻身互撞 -> 日晷切相消6影 -> 半途收剑/蹲断假挥诱真身露背自断九尾！"
	if bkey == "lv140_thunder_demon":
		return "只削两片外云保留裂纹云反雷击 -> 木箱改风撞右风墙 -> 收翼穿刀云把最后云片推入雷核！"
	if bkey == "lv150_solaris":
		if phase <= 1:
			return "阶段1【风车草甸】：只躲不打！诱SOLARIS俯冲撞碎自身第1层护甲！"
		if phase == 2:
			return "阶段2【飞瀑巨管】：转动三阀形成水幕，将太阳光束折射回自身击碎第2层护甲！"
		if phase == 3:
			return "阶段3【翠竹忍林】：借替身木桩诱出真身，挥剑斩击地面太阳影子而非本体！"
		if phase == 4:
			return "阶段4【苍穹浮岛】：利用逆风飞板让SOLARIS连续两次俯冲撞碎第3、4层护甲！"
		return "阶段5【曜金王座】：拨日晷至日落(黄昏)，收剑+背身静止等待终极光束熄灭，击打王座核心一次！"
	return "观察Boss阶段机制弱点破除护甲！"

func _get_phase_hint_en(bkey: String, phase: int) -> String:
	if bkey == "lv150_solaris":
		if phase < 5:
			return "SOLARIS PHASE %d/5: Bait self-damage to break armor! Direct hits heal its armor!" % phase
		return "SOLARIS FINAL: Shift Sundial to Dusk, SHEATHE sword, turn back & wait still, then strike Throne Core!"
	if bkey == "lv100_null":
		return "Light 2 CALM terminals, stop short before blank floor so NULL copies & self-deletes!"
	if bkey == "lv050_author":
		return "Hold fire! Slot 3 keys so Author snaps its own chains, then exit via flagpole base!"
	return "Break Boss Armor via stage mechanism before striking Core!"

func on_puzzle_event(eng: RefCounted, event_tag: String, payload: Dictionary = {}) -> void:
	if not bool(state.get("active", false)) or bool(state.get("defeated", false)):
		return
	var bkey: String = str(state["boss_key"])
	var flags: Dictionary = state["puzzle_flags"]

	if bkey == "lv010_grad":
		if event_tag == "glass_shattered":
			flags["glass_shattered"] = true
			state["boss_armor"] = maxi(0, int(state["boss_armor"]) - 1)
		elif event_tag == "fake_flag_knocked":
			flags["fake_flag_knocked"] = true
			state["boss_armor"] = 0
			flags["sky_ladder_revealed"] = true
			state["core_exposed"] = true
			eng.signal_groups["lv010_sky_ladder"] = true

	elif bkey == "lv030_fortress":
		if event_tag in ["brake_broken", "pillar_slot_loaded", "squeeze_bomb_into_side_slot"]:
			flags["pillar_slot_loaded"] = true
			state["phase"] = 3
			state["boss_armor"] = 1
		elif event_tag in ["side_slot_detonated", "tilt_tower_form_slope"]:
			flags["tower_tilted"] = true
			state["boss_armor"] = 0
			state["boss_hp"] = 0
			state["defeated"] = true
			eng.signal_groups["lv030_tower_tilted"] = true
			eng.emit_toast("承重柱侧槽爆破成功 · 整座高塔倾斜化作通天斜坡！", "TOWER TILTED INTO RAMP!", "boom", "#4ade80")

	elif bkey == "lv038_mechaskull":
		if event_tag in ["gate_lock_reflected", "shatter_gate_lock", "advance_into_mirror_room"]:
			flags["gate_lock_reflected"] = true
			state["boss_armor"] = 1
			state["phase"] = 4
		elif event_tag in ["boss_charged_gate", "drop_lock_trap_boss"]:
			flags["boss_trapped_in_gate"] = true
			state["boss_armor"] = 0
			state["boss_hp"] = 0
			state["defeated"] = true
			eng.signal_groups["lv038_hatch_open"] = true
			eng.emit_toast("机甲骷髅王冲门自困 · 检修通道已开启！", "MECHASKULL TRAPPED IN GATE!", "ach_mechaskull", "#4ade80")

	elif bkey == "lv050_author":
		if event_tag in ["key_slotted", "charge_snap_own_chains"]:
			if event_tag == "charge_snap_own_chains":
				flags["keys_slotted"] = 2
			flags["keys_slotted"] = int(flags.get("keys_slotted", 0)) + 1
			state["boss_armor"] = maxi(0, 3 - int(flags["keys_slotted"]))
			if int(flags["keys_slotted"]) >= 3:
				flags["chains_snapped"] = true
				flags["maintenance_hole_open"] = true
				state["core_exposed"] = true
				state["defeated"] = true
				eng.signal_groups["lv050_chains_broken"] = true
				eng.signal_groups["lv050_maint_open"] = true
				eng.emit_toast("作者撞断锁链奔向假旗 · 快从旗杆底座维修孔离开！", "CHAINS SNAPPED · ENTER BASE HATCH!", "ach_grand50", "#4ade80")

	elif bkey == "lv060_signal":
		if event_tag in ["cut_red", "enter_overload_phase"]:
			flags["red_cut"] = true
			state["phase"] = 2
			state["boss_armor"] = maxi(0, int(state["boss_armor"]) - 1)
		elif event_tag in ["cut_blue", "divert_pulse_expose_ground_spike"] and (bool(flags.get("red_cut", false)) or event_tag == "divert_pulse_expose_ground_spike"):
			flags["blue_cut"] = true
			state["phase"] = 3
			if bool(flags.get("green_intact", true)):
				state["boss_armor"] = 0
				state["core_exposed"] = true
				eng.signal_groups["b60_cable"] = true
		elif event_tag == "cut_green":
			flags["green_intact"] = false
			state["core_exposed"] = false
			state["boss_armor"] = maxi(1, int(state["boss_armor"]))
			eng.emit_sfx("fake_buzz")
			eng.emit_toast("误切绿线导致稳定器断电 · 正在自动重连！", "GREEN STABILIZER CUT · REBOOTING!", "s2_node_overload", "#f43f5e")
			flags["green_intact"] = true

	elif bkey == "lv070_mecha":
		if event_tag in ["left_shoulder_normal", "charge_left_normal"]:
			flags["left_normal_charged"] = true
			state["boss_armor"] = maxi(1, int(state["boss_armor"]) - 1)
		elif event_tag in ["right_shoulder_reflect", "charge_right_imbalance"]:
			flags["right_reflect_charged"] = true
			state["boss_armor"] = maxi(1, int(state["boss_armor"]) - 1)
		elif event_tag in ["lifted_over_furnace", "hoist_above_furnace"]:
			if bool(flags.get("left_normal_charged", false)) and bool(flags.get("right_reflect_charged", false)):
				flags["lifted_over_furnace"] = true
				state["phase"] = 2
		elif event_tag in ["cable_cut", "self_reflect_cannon_shatter_core"]:
			if event_tag == "self_reflect_cannon_shatter_core":
				flags["cables_cut"] = 2
			flags["cables_cut"] = int(flags.get("cables_cut", 0)) + 1
			if int(flags["cables_cut"]) >= 2 and bool(flags.get("ground_wire_intact", true)):
				state["phase"] = 3
				state["boss_armor"] = 0
				state["core_exposed"] = true
				eng.signal_groups["b70_side"] = true

	elif bkey == "lv080_fracture":
		if event_tag in ["mirror_inward", "trap_barrage_self_destruct_core"]:
			if event_tag == "trap_barrage_self_destruct_core":
				flags["mirrors_inward"] = 3
			flags["mirrors_inward"] = mini(4, int(flags.get("mirrors_inward", 0)) + 1)
			state["boss_armor"] = maxi(0, 4 - int(flags["mirrors_inward"]))
			if int(flags["mirrors_inward"]) >= 4:
				state["phase"] = 3
				state["core_exposed"] = true
				eng.signal_groups["b80_echo_lock"] = true
				eng.emit_toast("四镜朝内弹幕循环自毁 · 挥剑斩断根源线！", "SELF-BARRAGE SHATTERED SHIELD!", "mirror_wall", "#4ade80")

	elif bkey == "lv090_chrono":
		if event_tag == "past_pulse":
			flags["past_pulse_spent"] = true
			state["age_state"] = "mature"
			state["phase"] = 2
			state["boss_armor"] = 2
		elif event_tag == "present_echo":
			flags["present_echo_hit"] = true
			state["boss_armor"] = 1
		elif event_tag in ["future_chain_broken", "enter_senile_phase"]:
			flags["future_chain_broken"] = true
			state["age_state"] = "aged"
			state["phase"] = 3
		elif event_tag in ["time_node_locked", "lock_rewind_expose_core_anchor"]:
			if event_tag == "lock_rewind_expose_core_anchor":
				state["age_state"] = "aged"
				flags["rewind_nodes_locked"] = 2
			flags["rewind_nodes_locked"] = mini(3, int(flags.get("rewind_nodes_locked", 0)) + 1)
			if int(flags["rewind_nodes_locked"]) >= 3 and str(state["age_state"]) == "aged":
				state["boss_armor"] = 0
				state["core_exposed"] = true
				eng.signal_groups["b90_final_sw"] = true

	elif bkey == "lv100_null":
		if event_tag == "calm_terminal_lit":
			flags["calm_lit"] = mini(3, int(flags.get("calm_lit", 0)) + 1)
			state["boss_armor"] = maxi(0, 3 - int(flags["calm_lit"]))
			eng.signal_groups["b100_calm_count"] = int(flags["calm_lit"])
			if int(flags["calm_lit"]) >= 3:
				state["core_exposed"] = true
		elif event_tag in ["null_stepped_void", "null_continues_into_self_delete_zone", "lock_delete_animation_expose_root"]:
			flags["null_self_deleting"] = true
			state["boss_armor"] = 0
			state["core_exposed"] = true
			eng.signal_groups["b100_null_locked"] = true
			eng.emit_toast("NULL 复制急停失败跌入删除区 · 快点亮第3终端斩断根线！", "NULL LOCKED IN VOID DELETION!", "s2_boss_null", "#4ade80")

	elif bkey == "lv110_cloud_ram":
		if event_tag == "windmill_rammed":
			flags["windmill_rammed"] = true
			state["phase"] = 2
			state["boss_armor"] = 2
		elif event_tag == "altar_lock_cut":
			flags["altar_locks_cut"] = mini(2, int(flags.get("altar_locks_cut", 0)) + 1)
			if int(flags["altar_locks_cut"]) >= 2:
				state["phase"] = 3
				state["boss_armor"] = 1
		elif event_tag == "overshot_altar":
			flags["dangling_off_edge"] = true
			state["boss_armor"] = 0
			state["core_exposed"] = true
			eng.emit_toast("绵羊云王复制长跳冲出祭坛 · 快斩发条核心！", "CLOUD RAM DANGLING · SLASH CORE!", "s3_boss_110", "#4ade80")

	elif bkey == "lv120_hydra_pipe":
		if event_tag == "dual_siphon":
			flags["dual_siphon"] = true
			state["phase"] = 2
			state["boss_armor"] = 2
		elif event_tag == "high_pressure_head_broken":
			flags["high_heads_broken"] = mini(3, int(flags.get("high_heads_broken", 0)) + 1)
			if int(flags["high_heads_broken"]) >= 3:
				state["phase"] = 3
				state["boss_armor"] = 1
		elif event_tag == "bottom_relief_vented":
			flags["bottom_vent_open"] = true
			state["boss_armor"] = 0
			state["core_exposed"] = true

	elif bkey == "lv130_kitsune_tanuki":
		if event_tag == "illusions_collided":
			flags["illusions_collided"] = true
			state["phase"] = 2
		elif event_tag == "sundial_stripped_shadows":
			flags["shadows_stripped"] = true
			state["phase"] = 3
			flags["tails_remaining"] = mini(int(flags.get("tails_remaining", 9)), 3)
			state["boss_armor"] = int(flags["tails_remaining"])
		elif event_tag == "feint_baited":
			flags["feint_baited"] = true
			flags["tails_remaining"] = 0
			state["boss_armor"] = 0
			state["core_exposed"] = true
			eng.emit_toast("九尾忍狸复制半途收剑自断九尾 · 背后尾根已暴露！", "NINE TAILS SEVERED · STRIKE TAIL ROOT!", "s3_boss_130", "#4ade80")

	elif bkey == "lv140_thunder_demon":
		if event_tag == "cloud_shaved":
			flags["outer_clouds_shaved"] = int(flags.get("outer_clouds_shaved", 0)) + 1
			state["boss_armor"] = maxi(1, 3 - mini(2, int(flags["outer_clouds_shaved"])))
		elif event_tag == "lightning_reflected":
			flags["lightning_reflected"] = true
			state["phase"] = 2
			state["boss_armor"] = 1
		elif event_tag == "cloud_pushed_core":
			flags["cloud_pushed_core"] = true
			state["phase"] = 3
			state["boss_armor"] = 0
			state["core_exposed"] = true

	elif bkey == "lv150_solaris":
		if event_tag == "solaris_self_break_1" and not bool(flags.get("windmill_armor_broken", false)):
			flags["windmill_armor_broken"] = true
			state["boss_armor"] = 4
			state["phase"] = 2
		elif event_tag == "solaris_self_break_2" and not bool(flags.get("water_refract_broken", false)):
			flags["water_refract_broken"] = true
			state["boss_armor"] = 3
			state["phase"] = 3
		elif event_tag == "solaris_shadow_hit" and not bool(flags.get("shadow_struck", false)):
			flags["shadow_struck"] = true
			state["phase"] = 4
		elif event_tag == "solaris_self_break_3_4" and not bool(flags.get("wind_double_broken", false)):
			flags["wind_double_broken"] = true
			state["boss_armor"] = 1
			state["phase"] = 5
			flags["final_flare_active"] = true
		elif event_tag == "throne_core_struck" and bool(flags.get("throne_core_open", false)):
			state["boss_armor"] = 0
			state["boss_hp"] = 0
			state["defeated"] = true
			eng.s3_boss_defeated = true
			eng.trigger_level_win()

	state["hint_zh"] = _get_phase_hint_zh(bkey, int(state["phase"]))
	state["hint_en"] = _get_phase_hint_en(bkey, int(state["phase"]))
	eng.hud_dirty = true

func step_boss(eng: RefCounted, dt: float, world_dt: float) -> void:
	if not bool(state.get("active", false)) or bool(state.get("defeated", false)):
		return
	var p: Dictionary = eng.player
	if p.is_empty() or bool(p.get("dead", false)):
		return

	state["timer"] = float(state.get("timer", 0.0)) + world_dt
	var bkey: String = str(state["boss_key"])
	var flags: Dictionary = state["puzzle_flags"]

	# Lv100 NULL: detect abrupt player stop after lighting 2 CALM terminals!
	if bkey == "lv100_null":
		var calm_cnt: int = maxi(int(flags.get("calm_lit", 0)), int(eng.signal_groups.get("b100_calm_count", 0)))
		flags["calm_lit"] = calm_cnt
		if calm_cnt >= 2 and not bool(flags.get("null_self_deleting", false)):
			if absf(float(p.get("vx", 0.0))) < 8.0 and bool(p.get("on_ground", false)):
				state["calm_wait_timer"] = float(state.get("calm_wait_timer", 0.0)) + dt
				if float(state["calm_wait_timer"]) >= 0.85:
					on_puzzle_event(eng, "null_stepped_void", {})
			else:
				state["calm_wait_timer"] = 0.0

	# Lv110 Cloud Ram: record rightward long jump then bait left short hop
	elif bkey == "lv110_cloud_ram":
		if int(state["phase"]) >= 2 and not bool(flags.get("dangling_off_edge", false)):
			if not bool(p.get("on_ground", false)) and float(p.get("vx", 0.0)) > 175.0:
				flags["long_jump_recorded"] = true
			elif bool(flags.get("long_jump_recorded", false)) and not bool(p.get("on_ground", false)) and float(p.get("vx", 0.0)) < -40.0:
				on_puzzle_event(eng, "overshot_altar", {})

	# Lv130 Nine-Tailed Tanuki: detect feint slash count from PlayerController
	elif bkey == "lv130_kitsune_tanuki":
		if eng.world_state.sundial_phase_name != WorldState.PHASE_DAY and not bool(flags.get("shadows_stripped", false)):
			on_puzzle_event(eng, "sundial_stripped_shadows", {})
		if int(p.get("feint_slash_count", 0)) > 0 and not bool(flags.get("feint_baited", false)):
			on_puzzle_event(eng, "feint_baited", {})

	# Lv150 SOLARIS: 5-phase self-armor-break + Dusk + Sheathed + Back-turned stillness -> Throne Core open!
	elif bkey == "lv150_solaris":
		var boss_ent: Dictionary = _find_boss_entity(eng)
		var boss_x: float = float(boss_ent.get("x", float(p["x"]) + 180.0)) if not boss_ent.is_empty() else (float(p["x"]) + 180.0)
		var ph_s: int = int(state["phase"])

		if ph_s == 1 and float(state["timer"]) >= 4.2 and int(p.get("attack_count_stage", 0)) == 0:
			on_puzzle_event(eng, "solaris_self_break_1", {})
		elif ph_s == 2 and eng.s3_valves.size() >= 3:
			on_puzzle_event(eng, "solaris_self_break_2", {})
		elif ph_s == 4 and float(state["timer"]) >= 11.0:
			on_puzzle_event(eng, "solaris_self_break_3_4", {})
		elif ph_s >= 5 and not bool(flags.get("throne_core_open", false)):
			var is_dusk: bool = (eng.world_state.sundial_phase_name == WorldState.PHASE_DUSK) or eng.s3_sundial_phase
			flags["sunset_active"] = is_dusk
			var is_sheathed: bool = bool(p.get("sheathed", false))
			var facing_away: bool = ((float(p["x"]) < boss_x and int(p["facing"]) < 0) or (float(p["x"]) >= boss_x and int(p["facing"]) > 0))
			var is_still: bool = absf(float(p.get("vx", 0.0))) < 10.0 and bool(p.get("on_ground", false))
			if is_dusk and is_sheathed and facing_away and is_still:
				state["calm_wait_timer"] = float(state.get("calm_wait_timer", 0.0)) + dt
				if float(state["calm_wait_timer"]) >= 1.20:
					flags["throne_core_open"] = true
					state["boss_armor"] = 0
					state["core_exposed"] = true
					eng.signal_groups["lv150_throne_core_open"] = true
					eng.emit_sfx("real_win")
					eng.emit_toast("☀ 日落耀斑已熄灭 · 王座核心暴露，出剑一击定乾坤！", "FLARE EXTINGUISHED · STRIKE THE THRONE CORE!", "s3_sundial_orb", "#fde047")
			else:
				state["calm_wait_timer"] = maxf(0.0, float(state.get("calm_wait_timer", 0.0)) - dt * 0.5)

func _find_boss_entity(eng: RefCounted) -> Dictionary:
	for e_var in eng.entities:
		var e: Dictionary = e_var
		if str(e.get("t", "")) in ["s2_boss", "s3_boss", "enemy_boss"]:
			return e
		if str(e.get("t", "")) == "enemy" and str(e.get("kind", "")) == "boss":
			return e
	return {}

func on_boss_hit(eng: RefCounted, boss_ent: Dictionary, dmg: int, hit_meta: Dictionary = {}) -> bool:
	if not bool(state.get("active", false)):
		return false
	var bkey: String = str(state["boss_key"])
	var target_part: String = str(hit_meta.get("target_part", "body"))
	var reflected: bool = bool(hit_meta.get("reflected", false))

	# Anti-sponge punishment rules per v2.0 Section 2 & 3:
	if bkey == "lv038_mechaskull" and not reflected:
		state["boss_armor"] = mini(8, int(state["boss_armor"]) + 1)
		eng.emit_sfx("armor_clang")
		eng.add_float_text(float(boss_ent.get("x", 0.0)), float(boss_ent.get("y", 0.0)) - 14.0, "ARMOR +1!", "#f43f5e")
		return true

	if bkey == "lv050_author":
		eng.emit_sfx("fake_buzz")
		eng.emit_toast("攻击作者会触发舞台护盾重置 · 请插钥匙让它自断锁链！", "DO NOT ATTACK THE AUTHOR · USE KEYS!", "cat_nav_taunt", "#f43f5e")
		return true

	if bkey == "lv090_chrono" and not bool(state.get("core_exposed", false)) and not reflected:
		state["age_state"] = "young"
		state["boss_hp"] = int(state["boss_max_hp"])
		eng.emit_sfx("clock_high")
		eng.add_float_text(float(boss_ent.get("x", 0.0)), float(boss_ent.get("y", 0.0)) - 14.0, "REWIND!", "#c084fc")
		return true

	if bkey == "lv100_null" and not bool(state.get("core_exposed", false)):
		state["boss_hp"] = mini(int(state["boss_max_hp"]), int(state["boss_hp"]) + 2)
		eng.emit_sfx("fake_buzz")
		eng.add_float_text(float(boss_ent.get("x", 0.0)), float(boss_ent.get("y", 0.0)) - 14.0, "COPIED +HP!", "#f43f5e")
		return true

	if bkey == "lv150_solaris":
		if target_part == "shadow":
			on_puzzle_event(eng, "solaris_shadow_hit", {})
			return true
		if target_part == "throne_core" and bool(state["puzzle_flags"].get("throne_core_open", false)):
			on_puzzle_event(eng, "throne_core_struck", {})
			return true
		if int(state["boss_armor"]) > 0 and not reflected:
			state["boss_armor"] = mini(int(state["boss_max_armor"]), int(state["boss_armor"]) + 1)
			eng.emit_sfx("armor_clang")
			eng.add_float_text(float(boss_ent.get("x", 0.0)), float(boss_ent.get("y", 0.0)) - 16.0, "ABSORBED!", "#fde047")
			eng.emit_toast("SOLARIS 吸收剑能回复护甲 · 必须诱其自破五甲并在王座前收剑！", "SOLARIS ABSORBS ATTACKS · BAIT SELF-BREAK!", "s3_boss_150", "#fde047")
			return true

	# Standard puzzle-gated vulnerability check when armor remains
	if int(state["boss_armor"]) > 0 and not bool(state.get("core_exposed", false)) and not reflected:
		# Allow legacy Sector1And2Mechanics / Sector3Arcadia signal-group vulnerability to also break armor!
		return false

	var eff_dmg: int = maxi(1, dmg)
	state["boss_hp"] = maxi(0, int(state["boss_hp"]) - eff_dmg)
	if not boss_ent.is_empty():
		boss_ent["hp"] = int(state["boss_hp"])
		boss_ent["hit_flash"] = 0.20
	if int(state["boss_hp"]) <= 0:
		state["defeated"] = true
		if not boss_ent.is_empty():
			boss_ent["defeated"] = true
		eng.s3_boss_defeated = true
	eng.hud_dirty = true
	return false

func export_checkpoint_snapshot() -> Dictionary:
	return state.duplicate(true)

func restore_checkpoint_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	state = snap.duplicate(true)
