class_name TrapRegistry
extends RefCounted

const ORIGINAL_98_IDS: Array[String] = [
	"amanita", "antidote_pad", "battery_slot", "beat_clock", "beat_gate",
	"betray_spring", "bomb_pickup", "ceiling_crusher", "chain_bomb", "checkpoint",
	"clock", "cloud", "coin", "conveyor", "cool_pad",
	"crafting", "curse_totem", "decoy_btn", "destructible", "echo_pad",
	"echo_rec_pad", "electric_arc", "enemy", "fake_error", "fake_plat",
	"fake_save", "fake_wall", "flag", "flower", "gem",
	"glass_panel", "gravity_pad", "heat_vent", "hourglass", "invis",
	"launcher", "layer_term", "mem_shard", "mimic_chest", "mimic_flag",
	"mirror", "moving_pit", "null_block", "paradox_gate", "peace_dove",
	"phase_plat", "pipe", "piston", "poison_item", "polarity_block",
	"polarity_node", "poop", "portal", "powerup", "princess",
	"qblock", "rail_plat", "root_item", "root_slot", "root_term",
	"s2_boss", "s2_enemy", "s3_bomb_trophy", "s3_boss", "s3_bush",
	"s3_catapult", "s3_cloud", "s3_drop_block", "s3_flower", "s3_ladybug",
	"s3_manju", "s3_mimic_flag", "s3_mole", "s3_slide_turf", "s3_suction_pipe",
	"s3_sun", "s3_sundial", "s3_tall_pipe", "s3_tanuki", "s3_valve",
	"saw_track", "shop", "shy_brick", "sign", "signal_battery",
	"signal_bridge", "signal_gate", "signal_node", "solid", "spikes",
	"spring", "time_bubble", "time_node", "time_slice_plat", "trojan_heart",
	"troll_hand", "vanish", "wind_zone"
]

const V2_EXTENSION_IDS: Array[String] = [
	"weight_scale", "spotlight", "poison_fog_door", "spore_key", "white_flower",
	"ghost_train", "patch_chip", "patch_slot", "return_slot", "debt_tag",
	"tanuki_log", "missile", "enemy_boss", "timed_gate", "ferry_plat",
	"control_orb", "wood_crate", "cloud_plat", "cloud_knife", "sign_landed",
	"perm_terminal", "sunglasses_sun", "peace_dove_nuke", "popup_404", "mirror_rotatable",
	"forklift", "wrench_shot"
]

static var _contracts_cache: Dictionary = {}

static func _entry(
	type_id: String,
	category: String,
	storage_kind: String,
	states: Array,
	damage_type: String,
	shield_interaction: String,
	reset_policy: String,
	visual_cue: String,
	audio_cue: String,
	warning_time: float = 0.0,
	subtypes: Dictionary = {}
) -> Dictionary:
	return {
		"type_id": type_id,
		"category": category,
		"storage_kind": storage_kind,
		"states": states,
		"damage_type": damage_type,
		"shield_interaction": shield_interaction,
		"reset_policy": reset_policy,
		"visual_cue": visual_cue,
		"audio_cue": audio_cue,
		"warning_time": warning_time,
		"subtypes": subtypes
	}

static func _ensure_built() -> void:
	if not _contracts_cache.is_empty():
		return
	var std_states: Array = ["idle", "armed", "warning", "active", "cooldown", "reset"]
	var passive_states: Array = ["idle", "active", "reset"]
	var collect_states: Array = ["idle", "collected", "reset"]
	var enemy_states: Array = ["idle", "patrol", "alert", "windup", "attack", "stunned", "dead"]
	var boss_states: Array = ["intro", "phase_1", "phase_2", "phase_3", "vulnerable", "defeated"]

	var reg: Dictionary = {
		# --- 1. Terrain & Platforms (18 original) ---
		"ceiling_crusher": _entry("ceiling_crusher", "terrain", "solid", std_states, "crush", "block_parry", "attempt", "s2_ceiling_crusher", "fake_buzz", 0.24, {
			"drop": { "rise_back": false }, "yo_yo": { "rise_back": true }
		}),
		"conveyor": _entry("conveyor", "terrain", "solid", passive_states, "none", "none", "checkpoint", "cyber_floor", "clock_gear", 0.0, {
			"vip_fast": { "belt_vx": 340.0 }, "reverse": { "belt_vx": -185.0 }, "normal": { "belt_vx": 135.0 }
		}),
		"destructible": _entry("destructible", "terrain", "solid", ["intact", "cracked", "broken"], "none", "none", "checkpoint", "plat_copper_destruct", "boom", 0.0, {
			"bomb_only": { "bullet_break": false }, "bullet_break": { "bullet_break": true }, "mirror_break": { "mirror_break": true }
		}),
		"fake_plat": _entry("fake_plat", "terrain", "solid", ["disguised", "shattered"], "none", "none", "attempt", "plat_float_deck", "fake_wall_shatter"),
		"fake_wall": _entry("fake_wall", "terrain", "solid", ["disguised", "shattered"], "none", "none", "attempt", "cyber_wall", "fake_wall_shatter", 0.0, {
			"passable": { "loop_back": false }, "loop_back": { "loop_back": true }, "one_way_back": { "one_way_back": true }
		}),
		"glass_panel": _entry("glass_panel", "terrain", "solid", ["untested", "solid_verified", "phantom_revealed", "shy_ghost"], "none", "reflect", "attempt", "mirror_wall", "mirror_ping", 0.0, {
			"real": { "solid": true }, "phantom": { "solid": false }, "schrodinger": { "gaze_ghost": true }
		}),
		"invis": _entry("invis", "terrain", "solid", ["hidden", "revealed", "looted"], "none", "none", "checkpoint", "qblock_used", "block", 0.0, {
			"bump_reveal": { "step_reveal": false }, "step_reveal": { "step_reveal": true }, "echo_bridge": { "timed_fade": true }, "kaizo_bridge": { "pushable_after_hit": true }
		}),
		"moving_pit": _entry("moving_pit", "terrain", "solid", std_states, "none", "none", "attempt", "s2_moving_pit", "spring", 0.12, {
			"flee": { "return": false }, "return": { "return": true }
		}),
		"null_block": _entry("null_block", "terrain", "solid", ["solid", "warn", "ghost", "deleting"], "void", "ignore_pierce", "attempt", "s2_phase_ghost", "fake_buzz", 0.85, {
			"periodic": { "gold_safe": false }, "gold_immortal": { "gold_safe": true }, "white_void": { "self_delete_boss": true }
		}),
		"phase_plat": _entry("phase_plat", "terrain", "solid", ["solid", "warn", "ghost"], "none", "none", "attempt", "s2_phase_solid", "node_toggle", 0.75, {
			"periodic": {}, "hologram_clone_only": { "clone_activate": true }
		}),
		"piston": _entry("piston", "terrain", "entity", std_states, "crush", "block_parry", "attempt", "s2_piston_head", "block", 0.85),
		"rail_plat": _entry("rail_plat", "terrain", "solid", ["idle", "moving", "dwell"], "none", "none", "checkpoint", "s2_rail_plat", "clock_gear"),
		"s3_drop_block": _entry("s3_drop_block", "terrain", "solid", ["idle", "shake", "fall", "landed", "risen"], "crush", "block_parry", "attempt", "s3_stone_brick", "ground_pound", 0.22, {
			"drop_stay": { "stay_solid": true }, "rise_trap": { "rise_trap": true }, "anti_newton": { "directional_impulse": true }
		}),
		"s3_slide_turf": _entry("s3_slide_turf", "terrain", "solid", ["idle", "sliding", "settled", "sunk"], "none", "none", "attempt", "s3_float_grass", "spring", 0.15, {
			"horizontal": {}, "elevator": {}, "pull_bottom": {}
		}),
		"saw_track": _entry("saw_track", "terrain", "entity", ["patrol", "stopped"], "blade", "block_parry", "attempt", "s2_saw_blade", "cloud_blade"),
		"shy_brick": _entry("shy_brick", "terrain", "solid", ["solid", "grace", "ghost"], "none", "none", "attempt", "s2_shy_brick", "block", 0.13, {
			"shy": { "gaze_vanish": true }, "stare": { "gaze_solid": true }
		}),
		"solid": _entry("solid", "terrain", "solid", passive_states, "none", "none", "checkpoint", "platform_steel", "block", 0.0, {
			"steel": { "material": "metal" }, "copper": { "material": "metal" }, "wood": { "material": "wood" }, "stone": { "material": "stone" }, "weight_scale": { "role": "weight_scale" }
		}),
		"vanish": _entry("vanish", "terrain", "solid", ["solid", "cracking", "broken", "respawn"], "none", "none", "attempt", "plat_vanish_hover", "block", 0.48),

		# --- 2. Hazards & Environmental Dangers (12 original) ---
		"amanita": _entry("amanita", "hazard", "entity", ["idle", "alchemy_converted", "consumed"], "poison", "ignore_pierce", "auto_regen", "mushroom_amanita", "poison"),
		"cloud": _entry("cloud", "hazard", "solid", ["solid", "warning", "blade_active", "hollow_fade", "bounce"], "blade", "cache_overload", "attempt", "cloud_safe", "cloud_solid", 0.25, {
			"solid": { "audio_cue": "cloud_solid", "safe": true },
			"blade": { "audio_cue": "cloud_blade", "safe": false, "brittle_core": true },
			"hollow": { "audio_cue": "cloud_hollow", "safe": false, "fake_poof": true },
			"bounce": { "audio_cue": "cloud_bounce", "safe": true, "bounce_vy": -720.0 }
		}),
		"cool_pad": _entry("cool_pad", "hazard", "entity", ["idle", "cooling", "shattered_ice"], "none", "none", "attempt", "ach_iceclock", "coin", 0.0, {
			"static_cool": {}, "pushable_ice": { "pushable": true }
		}),
		"electric_arc": _entry("electric_arc", "hazard", "entity", std_states, "electric", "block_parry", "checkpoint", "laser_gate", "fake_buzz", 0.35),
		"flower": _entry("flower", "hazard", "entity", ["idle", "ambush", "spore_yield", "pacified"], "pierce", "magnetic_attract", "auto_regen", "flower_skull", "poison", 0.25, {
			"skull": { "default": true },
			"spore_giver": { "poison_gives_spore_key": true },
			"white_cure_aggro": { "visual_cue": "v2_flower_white", "aggro_when_healthy": true },
			"magnetic": { "attracts_shield": true }
		}),
		"heat_vent": _entry("heat_vent", "hazard", "entity", ["rest", "warn", "erupt", "off"], "thermal", "block_parry", "checkpoint", "plat_copper_destruct", "boom", 1.0),
		"poop": _entry("poop", "hazard", "entity", ["idle", "falling", "sliding", "wedged"], "poison", "ignore_pierce", "attempt", "poop", "poison", 0.0, {
			"lethal": {}, "slip_boost": { "boost_vx": 330.0 }, "spring_shell": { "spawn_step_shell": true }, "sticky_push": { "pushable_wedge": true }
		}),
		"s3_bush": _entry("s3_bush", "hazard", "entity", ["concealed", "rustling", "revealed", "cleared"], "blade", "block_parry", "attempt", "s3_bush_blade", "cloud_blade", 0.25, {
			"ambush_blade": {}, "stalk_bush": { "gaze_freeze": true }, "reflect_clip": { "reflects_slash": true }, "safe": { "harmless": true }
		}),
		"s3_cloud": _entry("s3_cloud", "hazard", "solid", ["solid", "blades_out", "swooping", "hollow_poof", "frozen_bridge", "disarmed"], "blade", "block_parry", "attempt", "s3_cloud_safe", "cloud_solid", 0.28, {
			"safe_plat": { "audio_cue": "cloud_solid", "safe": true },
			"solid": { "audio_cue": "cloud_solid", "safe": true },
			"hidden_knife": { "audio_cue": "cloud_blade", "safe": false },
			"blade": { "audio_cue": "cloud_blade", "safe": false },
			"fake_cloud": { "audio_cue": "cloud_hollow", "safe": false },
			"hollow": { "audio_cue": "cloud_hollow", "safe": false, "thunder_solidifies": true },
			"bounce": { "audio_cue": "cloud_bounce", "safe": true, "bounce_vy": -735.0 },
			"swoop_cloud": { "audio_cue": "cloud_blade", "swoop": true },
			"thunder": { "audio_cue": "boom", "swoop": true, "solidifies_hollow": true },
			"sundial_knife": { "audio_cue": "sundial_shift", "phase_bound": true }
		}),
		"s3_flower": _entry("s3_flower", "hazard", "entity", ["idle", "predict_windup", "lunge", "angry", "rewarded"], "pierce", "block_parry", "attempt", "s3_pink_flower", "shoot", 0.40, {
			"lunge": {}, "jump_block": {}, "predictive": { "predicts_jump_arc": true }, "polite": { "reflects_front": false }, "polite_reflect": { "reflects_front": true }, "flag_biter": { "guards_flag": true }
		}),
		"s3_manju": _entry("s3_manju", "hazard", "entity", ["patrol", "waiting_drop", "spiked", "clumped", "bounce_pad"], "spike", "block_parry", "attempt", "s3_mon_manju", "spring", 0.20, {
			"spike_morph": {}, "sky_drop": { "becomes_pad_on_cut": true }, "jump_mimic": { "copies_short_hop": true }
		}),
		"spikes": _entry("spikes", "hazard", "entity", ["active", "anchored_floor"], "spike", "block_parry", "checkpoint", "spikes_red", "armor_clang"),

		# --- 3. Enemies & Bosses (11 original) ---
		"enemy": _entry("enemy", "enemy", "entity", enemy_states, "physical", "block_parry", "attempt", "enemy_follower", "enemy_kill", 0.32, {
			"follower": {}, "shadow_follower": { "tracks_shadow": true, "pit_shell": true }, "flying": {}, "spore_carrier": { "drops_stun_spore": true }, "boss": { "chase_gate": true }
		}),
		"mimic_chest": _entry("mimic_chest", "enemy", "entity", ["sleeping", "awake", "swallowed", "spitting", "dead"], "physical", "block_parry", "checkpoint", "s2_mimic_chest", "fake_buzz", 0.30, {
			"ambush": {}, "bomb_feed": { "swallows_bomb": true }, "bullet_spit": { "spits_back_bullet": true }, "token_spit": { "spits_admin_token": true }
		}),
		"mimic_flag": _entry("mimic_flag", "enemy", "entity", ["disguised", "revealed", "fleeing", "tamed"], "pierce", "ignore_pierce", "checkpoint", "s2_mimic_flag", "fake_buzz", 0.25, {
			"bite": {}, "flee_off": {}, "sword_tame": {}, "mimic_action": {}
		}),
		"peace_dove": _entry("peace_dove", "enemy", "entity", ["patrol", "watching", "lock_warn", "angry_nuke", "pacified"], "explosive", "block_parry", "attempt", "s2_peace_dove", "fake_buzz", 0.55),
		"s2_boss": _entry("s2_boss", "boss", "entity", boss_states, "physical", "block_parry", "checkpoint", "s2_boss_signal", "boom", 0.70, {
			"lv060_signal": {}, "lv070_mecha": {}, "lv080_fracture": {}, "lv090_chrono": {}, "lv100_null": {},
			"signal_storm": {}, "reassembly_mech": {}, "mecha_sovereign": {}, "fracture_core": {}, "chrono_skull": {}, "chrono_regent": {}, "admin_arena": {}, "null_admin": {}
		}),
		"s2_enemy": _entry("s2_enemy", "enemy", "entity", enemy_states, "physical", "block_parry", "attempt", "s2_bot_patrol", "enemy_kill", 0.34, {
			"patrol": {}, "drone": {}, "turret": {}, "forklift": { "carries_pallet": true }, "mech_hopper": {}, "mech_shroom": {}, "mech_hound": {}, "mech_spider": {}, "mech_crab": {}, "mech_tank": {}, "mech_golem": {}, "mech_knight": {}, "mech_exec": {}, "shield_mech": {}, "mech_wasp": {}, "mech_wisp": {}, "red_cat_mirror": {}, "entity_cat_chip": {}
		}),
		"s3_boss": _entry("s3_boss", "boss", "entity", boss_states, "physical", "block_parry", "checkpoint", "s3_boss_150", "boom", 0.75, {
			"lv110_cloud_ram": {}, "lv120_hydra_pipe": {}, "lv130_kitsune_tanuki": {}, "lv140_thunder_demon": {}, "lv150_solaris": {},
			"cloud_ram": {}, "pipe_kaiser": {}, "kage_tanuki": {}, "blade_archon": {}, "solaris_painter": {}
		}),
		"s3_ladybug": _entry("s3_ladybug", "enemy", "entity", ["patrol", "sprint", "slipstream", "plugged_pipe"], "physical", "block_parry", "attempt", "s3_mon_ladybug", "spring", 0.25),
		"s3_mimic_flag": _entry("s3_mimic_flag", "enemy", "entity", ["disguised", "awake", "fleeing", "tamed"], "physical", "block_parry", "attempt", "s3_mimic_flag", "fake_buzz", 0.25, {
			"decoy": {}, "tame_goal": {}, "fleeing": {}, "mimic_action": {}
		}),
		"s3_mole": _entry("s3_mole", "enemy", "entity", ["buried", "emerged", "throwing"], "physical", "block_parry", "attempt", "s3_mon_mole", "shoot", 0.35),
		"s3_tanuki": _entry("s3_tanuki", "enemy", "entity", ["idle", "cloning", "copy_pose", "log_transformed"], "physical", "block_parry", "attempt", "s3_mon_tanuki", "spring", 0.30),

		# --- 4. Transport, Spatial & Kinetic Connectors (9 original) ---
		"betray_spring": _entry("betray_spring", "transport", "entity", ["disguised", "betray_fling", "calibrated"], "none", "none", "checkpoint", "s2_betray_spring", "spring", 0.0),
		"launcher": _entry("launcher", "transport", "entity", ["idle", "charging", "firing", "recoil"], "explosive", "block_parry", "attempt", "missile_launcher", "shoot", 0.35, {
			"standard": {}, "cycled_types": { "missile_types": ["cracked", "cooled_rideable", "homing_bait"] }
		}),
		"pipe": _entry("pipe", "transport", "entity", ["idle", "echo_cue", "warping", "rerouted"], "none", "none", "checkpoint", "pipe", "pipe_echo_single", 0.0, {
			"direct": { "audio_cue": "pipe_echo_single" }, "loop_trap": { "audio_cue": "pipe_echo_double" }
		}),
		"portal": _entry("portal", "transport", "entity", ["active", "cooldown", "locked"], "none", "none", "checkpoint", "s2_portal_a", "portal_warp"),
		"s3_catapult": _entry("s3_catapult", "transport", "entity", ["armed", "launching", "cooldown"], "none", "none", "attempt", "s3_catapult_trap", "spring", 0.0, {
			"forward_vault": { "vx": 515.0, "vy": -845.0 },
			"back_fling": { "vx": -455.0, "vy": -835.0 },
			"high_secret": { "vx": 0.0, "vy": -935.0 },
			"wind_splitter": { "blocks_wind": true }
		}),
		"s3_suction_pipe": _entry("s3_suction_pipe", "transport", "entity", ["sucking", "shut_off", "stone_plugged"], "crush", "block_parry", "checkpoint", "s3_suction_pipe", "valve_turn", 0.25),
		"s3_tall_pipe": _entry("s3_tall_pipe", "transport", "solid", ["raised", "lowering", "lowered", "rocket_geyser"], "crush", "block_parry", "checkpoint", "s3_pipe_tall", "valve_turn", 0.0, {
			"block": {}, "rocket": { "launch_vy": -785.0 }, "sundial_alt": {}, "lethal_drop": {}
		}),
		"spring": _entry("spring", "transport", "entity", ["idle", "compressed", "launch"], "none", "none", "attempt", "spring", "spring"),
		"wind_zone": _entry("wind_zone", "transport", "entity", ["blowing", "reversed", "off"], "none", "none", "checkpoint", "arrow_up_cyan", "sundial_shift"),

		# --- 5. Chrono, Rhythm & Echoes (10 original) ---
		"beat_clock": _entry("beat_clock", "chrono", "entity", ["ticking", "triggered"], "none", "none", "attempt", "clock_gear", "clock_high"),
		"beat_gate": _entry("beat_gate", "chrono", "solid", ["closed", "warn", "open"], "none", "none", "attempt", "s2_beat_gate", "clock_low", 0.85),
		"clock": _entry("clock", "chrono", "entity", ["ticking", "activated", "broken"], "none", "none", "attempt", "clock_gold", "clock_gear", 0.0, {
			"enemy_speed": { "audio_cue": "clock_high" },
			"mech_freeze": { "audio_cue": "clock_low" },
			"timer_only": { "audio_cue": "clock_gear" },
			"rewind_plat": { "audio_cue": "clock_low" },
			"time_loan": { "audio_cue": "clock_high" }
		}),
		"echo_pad": _entry("echo_pad", "chrono", "entity", ["idle", "depressed", "latched"], "none", "none", "checkpoint", "s2_node_on", "node_toggle"),
		"echo_rec_pad": _entry("echo_rec_pad", "chrono", "entity", ["idle", "recording", "cleared"], "none", "none", "attempt", "s2_node_off", "node_toggle"),
		"hourglass": _entry("hourglass", "chrono", "entity", ["ready", "rewinding", "cooldown"], "none", "none", "attempt", "time_hourglass", "hint_popup"),
		"paradox_gate": _entry("paradox_gate", "chrono", "solid", ["locked", "damaged_future", "open"], "none", "none", "checkpoint", "laser_gate", "portal_warp"),
		"time_bubble": _entry("time_bubble", "chrono", "entity", ["active", "suspended_wave"], "none", "none", "attempt", "s2_time_node", "clock_low"),
		"time_node": _entry("time_node", "chrono", "entity", ["idle", "active", "cooldown"], "none", "none", "checkpoint", "s2_time_node", "clock_low"),
		"time_slice_plat": _entry("time_slice_plat", "chrono", "solid", ["ghost", "solidified"], "none", "none", "attempt", "s2_phase_warn", "clock_high"),

		# --- 6. Signal, Root Permissions & Meta UI (14 original) ---
		"battery_slot": _entry("battery_slot", "system", "entity", ["empty", "filled"], "none", "none", "checkpoint", "s2_node_off", "node_toggle"),
		"curse_totem": _entry("curse_totem", "system", "entity", ["active", "disabled"], "none", "none", "checkpoint", "s2_curse_totem", "poison", 0.0, {
			"mirror_lr": {}, "anti_jump_shoot": {}, "auto_fire": {}, "dual_brain": {}
		}),
		"decoy_btn": _entry("decoy_btn", "system", "entity", ["unpressed", "pressed_trap", "weighted_safe"], "meta_warp", "ignore_pierce", "attempt", "ui_btn_x", "fake_buzz"),
		"fake_error": _entry("fake_error", "system", "solid", ["active", "walkable", "pushable_block", "safe_mode_docked", "closed"], "none", "none", "checkpoint", "s2_fake_error", "fake_wall_shatter", 0.0, {
			"close_x": {}, "normal_x": {}, "walk_top": {}, "rogue_walkable": {}, "wire_pushable": { "pushable_on_slash": true }, "load_bearing": { "sustains_floor": true }
		}),
		"fake_save": _entry("fake_save", "system", "entity", ["corrupted", "purified", "active_checkpoint"], "meta_warp", "block_parry", "checkpoint", "s2_fake_save", "fake_buzz"),
		"layer_term": _entry("layer_term", "system", "entity", ["foreground", "background"], "none", "none", "checkpoint", "s2_layer_term", "portal_warp"),
		"root_item": _entry("root_item", "system", "entity", ["idle", "carried", "inserted"], "none", "none", "checkpoint", "s2_root_key", "coin"),
		"root_slot": _entry("root_slot", "system", "entity", ["empty", "filled", "swapped"], "none", "none", "checkpoint", "s2_node_off", "node_toggle"),
		"root_term": _entry("root_term", "system", "entity", ["locked", "read_mode", "write_mode", "admin_mode", "calm_verified"], "none", "none", "checkpoint", "s2_root_term", "sword_sheathe", 0.0, {
			"shoot": {}, "jump_touch": {}, "calm_touch": { "sheathe_required": true }, "perm_cycle": { "cycles_rwa": true }
		}),
		"signal_battery": _entry("signal_battery", "system", "entity", ["idle", "carried", "inserted"], "none", "none", "checkpoint", "s2_battery", "coin"),
		"signal_bridge": _entry("signal_bridge", "system", "solid", ["off", "energized"], "none", "none", "checkpoint", "s2_phase_solid", "node_toggle"),
		"signal_gate": _entry("signal_gate", "system", "solid", ["closed", "open"], "none", "none", "checkpoint", "laser_gate", "node_toggle"),
		"signal_node": _entry("signal_node", "system", "entity", ["off", "on", "overload", "decoy"], "none", "none", "checkpoint", "s2_node_on", "node_toggle"),
		"trojan_heart": _entry("trojan_heart", "system", "entity", ["idle", "heavy_curse", "reverse_curse", "debt_converted", "thrown_short"], "meta_warp", "ignore_pierce", "attempt", "s2_trojan_heart", "poison"),

		# --- 7. Physics & Environmental Controllers (7 original) ---
		"gravity_pad": _entry("gravity_pad", "physics", "entity", ["ready", "flipped"], "none", "none", "attempt", "gravity_pad", "spring"),
		"mirror": _entry("mirror", "physics", "solid", ["fixed", "rotatable", "broken"], "none", "reflect", "checkpoint", "v2_mirror_rotatable", "mirror_ping", 0.0, {
			"fixed": { "rotatable": false }, "rotatable": { "rotatable": true, "step_deg": 45.0 }
		}),
		"polarity_block": _entry("polarity_block", "physics", "solid", ["blue_pole", "orange_pole", "moving"], "none", "magnetic_attract", "checkpoint", "s2_mag_blue", "node_toggle"),
		"polarity_node": _entry("polarity_node", "physics", "entity", ["blue", "orange"], "none", "none", "checkpoint", "s2_mag_node_blue", "node_toggle"),
		"s3_sun": _entry("s3_sun", "physics", "entity", ["sleeping", "tracking_heat", "tracking_shadow", "swooping", "blinded"], "thermal", "block_parry", "attempt", "s3_sun_angry", "shoot", 0.65),
		"s3_sundial": _entry("s3_sundial", "physics", "entity", ["day", "dusk", "night"], "none", "none", "checkpoint", "s3_sundial_orb", "sundial_shift"),
		"s3_valve": _entry("s3_valve", "physics", "entity", ["closed", "spun_open", "decoy_ambush", "severed"], "none", "none", "checkpoint", "s3_valve_red", "valve_turn"),

		# --- 8. Collectibles, Items, NPCs & Meta Actors (17 original) ---
		"antidote_pad": _entry("antidote_pad", "collectible", "entity", collect_states, "none", "none", "auto_regen", "item_antidote", "real_win"),
		"bomb_pickup": _entry("bomb_pickup", "collectible", "entity", collect_states, "none", "none", "auto_regen", "bomb", "coin"),
		"chain_bomb": _entry("chain_bomb", "collectible", "entity", ["idle", "fusing", "exploded", "pushed"], "explosive", "block_parry", "attempt", "bomb", "boom", 0.24),
		"checkpoint": _entry("checkpoint", "collectible", "entity", ["inactive", "active", "fake_ambush"], "none", "none", "checkpoint", "checkpoint_on", "coin"),
		"coin": _entry("coin", "collectible", "entity", ["idle", "collected", "placed_weight"], "none", "none", "attempt", "coin_1", "coin"),
		"crafting": _entry("crafting", "collectible", "entity", ["ready", "synthesizing"], "none", "none", "attempt", "crafting_station", "coin"),
		"flag": _entry("flag", "collectible", "entity", ["idle", "fake_celebrate", "fleeing", "fallen_lever", "cleared"], "meta_warp", "ignore_pierce", "attempt", "flag_idle", "real_win", 0.0, {
			"true_goal": {}, "loop_back": {}, "freeze_taunt": {}, "tentacle_back": {}, "fleeing": {}, "mimic_action": {}
		}),
		"gem": _entry("gem", "collectible", "entity", collect_states, "none", "none", "attempt", "gem_blue", "coin"),
		"mem_shard": _entry("mem_shard", "collectible", "entity", ["uncollected", "shadow_slotted", "collected"], "none", "none", "persistent_shard", "s2_mem_shard", "ach_unlock"),
		"poison_item": _entry("poison_item", "collectible", "entity", collect_states, "none", "none", "auto_regen", "mushroom_poison", "poison"),
		"powerup": _entry("powerup", "collectible", "entity", collect_states, "none", "none", "checkpoint", "icon_spring", "coin"),
		"princess": _entry("princess", "collectible", "entity", ["waiting", "order_flipped", "weight_mode", "satisfied"], "none", "none", "attempt", "npc_princess", "real_win"),
		"qblock": _entry("qblock", "collectible", "solid", ["ready", "hidden", "used", "memory_lit"], "none", "none", "attempt", "qblock", "block"),
		"s3_bomb_trophy": _entry("s3_bomb_trophy", "collectible", "entity", ["pedestal", "cracked_shell", "fusing", "exploded"], "explosive", "block_parry", "auto_regen", "s3_bomb_trophy", "fake_win", 0.75),
		"shop": _entry("shop", "collectible", "entity", ["open", "circuit_cut", "closed_debt"], "meta_warp", "ignore_pierce", "attempt", "shop_frame", "coin"),
		"sign": _entry("sign", "collectible", "entity", ["standing", "falling", "landed_flat", "landed_slope", "wire_live"], "crush", "block_parry", "attempt", "sign_right", "block", 0.20, {
			"truth": {}, "lie": {}, "fall": {}, "fall_slope": { "creates_slope": true }, "wire_shock": { "damage_type": "electric" }, "knife": { "damage_type": "blade" }, "reverse_grammar": {}
		}),
		"troll_hand": _entry("troll_hand", "collectible", "entity", ["idle", "windup", "slap", "boost_up", "parried", "shorted"], "crush", "block_parry", "checkpoint", "s2_troll_hand", "armor_clang", 0.55),

		# --- 9. v2.0 Dedicated Sub-Entities & New Object Types ---
		"weight_scale": _entry("weight_scale", "physics", "solid", ["balanced", "light_high", "heavy_low", "overloaded"], "none", "none", "attempt", "v2_weight_scale", "clock_gear"),
		"spotlight": _entry("spotlight", "physics", "entity", ["lit", "extinguished", "broken"], "none", "none", "checkpoint", "v2_spotlight_lamp", "mirror_ping"),
		"poison_fog_door": _entry("poison_fog_door", "system", "solid", ["sealed", "unlocked"], "poison", "ignore_pierce", "checkpoint", "v2_poison_fog_door", "poison"),
		"spore_key": _entry("spore_key", "collectible", "entity", ["spawned", "carried", "used"], "none", "none", "checkpoint", "v2_spore_key", "coin"),
		"white_flower": _entry("white_flower", "hazard", "entity", ["dormant_in_poison", "cure_aggro"], "pierce", "block_parry", "attempt", "v2_flower_white", "poison"),
		"ghost_train": _entry("ghost_train", "transport", "solid", ["running", "decoupled", "parked_wrong_station"], "crush", "block_parry", "checkpoint", "v2_ghost_train", "clock_low", 0.45),
		"patch_chip": _entry("patch_chip", "system", "entity", ["idle", "carried", "installed", "shorted_hand"], "none", "none", "checkpoint", "v2_patch_chip", "node_toggle"),
		"patch_slot": _entry("patch_slot", "system", "entity", ["empty", "patched", "swapped"], "none", "none", "checkpoint", "s2_node_off", "node_toggle"),
		"return_slot": _entry("return_slot", "system", "entity", ["ready", "refunded"], "none", "none", "checkpoint", "shop_frame", "coin"),
		"debt_tag": _entry("debt_tag", "collectible", "entity", ["dropped", "carried", "settled"], "none", "none", "attempt", "s2_trojan_heart", "coin"),
		"tanuki_log": _entry("tanuki_log", "terrain", "solid", ["tall_log", "flat_log", "switch_pressing"], "none", "none", "attempt", "s3_mon_tanuki_log", "block"),
		"missile": _entry("missile", "transport", "entity", ["flying", "rideable_cooled", "cracked", "homing_bait"], "explosive", "block_parry", "attempt", "missile", "shoot"),
		"enemy_boss": _entry("enemy_boss", "boss", "entity", boss_states, "physical", "block_parry", "checkpoint", "enemy_boss", "boom", 0.65),
		"timed_gate": _entry("timed_gate", "chrono", "solid", ["closed", "open"], "none", "none", "attempt", "laser_gate", "clock_gear"),
		"ferry_plat": _entry("ferry_plat", "transport", "solid", ["docked_neg", "sailing", "docked_pos"], "none", "none", "checkpoint", "s2_plat_float_deck", "node_toggle"),
		"control_orb": _entry("control_orb", "system", "entity", ["held", "roof_mounted", "bottom_mounted", "slotted"], "none", "none", "checkpoint", "s3_sundial_orb", "node_toggle"),
		"wood_crate": _entry("wood_crate", "terrain", "solid", ["idle", "pushed", "gaze_frozen"], "none", "none", "attempt", "s3_wood_crate", "block"),
		"cloud_plat": _entry("cloud_plat", "terrain", "solid", ["breathing", "rule_swapped"], "none", "none", "attempt", "cloud_safe", "cloud_solid"),
		"cloud_knife": _entry("cloud_knife", "hazard", "entity", ["hovering", "rule_swapped"], "blade", "cache_overload", "attempt", "cloud_knife", "cloud_blade"),
		"sign_landed": _entry("sign_landed", "terrain", "solid", ["landed_flat", "landed_slope"], "none", "none", "attempt", "sign_right", "block"),
		"perm_terminal": _entry("perm_terminal", "system", "entity", ["read", "write", "admin"], "none", "none", "checkpoint", "v2_perm_terminal", "node_toggle"),
		"sunglasses_sun": _entry("sunglasses_sun", "physics", "entity", ["sleeping", "heat_lock", "swooping", "blinded"], "thermal", "block_parry", "attempt", "v2_sunglasses_sun", "shoot"),
		"peace_dove_nuke": _entry("peace_dove_nuke", "enemy", "entity", ["watching", "valve_inspect", "disarmed"], "explosive", "block_parry", "attempt", "v2_peace_dove_nuke", "fake_buzz"),
		"popup_404": _entry("popup_404", "system", "solid", ["active", "walkable", "pushable_block", "closed"], "none", "none", "checkpoint", "v2_popup_404", "fake_wall_shatter"),
		"mirror_rotatable": _entry("mirror_rotatable", "physics", "solid", ["angle_0", "angle_45", "angle_90", "angle_135"], "none", "reflect", "checkpoint", "v2_mirror_rotatable", "mirror_ping"),
		"forklift": _entry("forklift", "enemy", "entity", ["patrol", "lifting_pallet"], "crush", "block_parry", "attempt", "v2_forklift", "clock_gear"),
		"wrench_shot": _entry("wrench_shot", "hazard", "entity", ["thrown", "parried_friendly"], "physical", "block_parry", "attempt", "s3_mon_mole", "mirror_ping")
	}
	_contracts_cache = reg

static func get_all_contracts() -> Dictionary:
	_ensure_built()
	return _contracts_cache

static func get_original_98_types() -> Array[String]:
	return ORIGINAL_98_IDS.duplicate()

static func get_v2_extension_types() -> Array[String]:
	return V2_EXTENSION_IDS.duplicate()

static func has_type(type_id: String) -> bool:
	_ensure_built()
	return _contracts_cache.has(type_id)

static func get_contract(type_id: String, sub_type: String = "") -> Dictionary:
	_ensure_built()
	if not _contracts_cache.has(type_id):
		return {}
	var base: Dictionary = _contracts_cache[type_id].duplicate(true)
	if sub_type != "":
		var subs: Dictionary = base.get("subtypes", {})
		if subs.has(sub_type) and typeof(subs[sub_type]) == TYPE_DICTIONARY:
			var sub_d: Dictionary = subs[sub_type]
			for k in sub_d.keys():
				base[k] = sub_d[k]
	return base

static func get_reset_policy(type_id: String) -> String:
	var c: Dictionary = get_contract(type_id)
	return str(c.get("reset_policy", "attempt"))

static func can_shield_block(type_id: String, sub_type: String = "", shield_cache: String = "") -> bool:
	var c: Dictionary = get_contract(type_id, sub_type)
	if c.is_empty():
		return true
	var inter: String = str(c.get("shield_interaction", "block_parry"))
	if inter == "ignore_pierce":
		return false
	if inter == "cache_overload" and shield_cache != "" and shield_cache == str(c.get("damage_type", "")):
		# Lv033: Shield remembers last absorbed hazard tag and overloads if uncalibrated!
		return false
	return inter in ["block_parry", "magnetic_attract", "cache_overload", "reflect"]

static func create_trap_node(data: Dictionary) -> TrapBase:
	var node: TrapBase = TrapBase.new()
	var tid: String = str(data.get("t", "solid"))
	var sub: String = str(data.get("subType", data.get("mode", "")))
	var contract: Dictionary = get_contract(tid, sub)
	if not contract.is_empty():
		node.trap_id = StringName(tid)
		node.category = str(contract.get("category", "terrain"))
		node.warning_time = float(contract.get("warning_time", 0.0))
		node.reset_policy = StringName(str(contract.get("reset_policy", "checkpoint")))
		node.damage_type = str(contract.get("damage_type", "none"))
		node.shield_interaction = str(contract.get("shield_interaction", "none"))
	node.configure(data)
	return node

static func validate_registry_completeness() -> Dictionary:
	_ensure_built()
	var missing_orig: Array[String] = []
	var malformed: Array[String] = []
	var req_keys: Array[String] = [
		"type_id", "category", "states", "damage_type",
		"shield_interaction", "reset_policy", "visual_cue", "audio_cue"
	]
	for oid in ORIGINAL_98_IDS:
		if not _contracts_cache.has(oid):
			missing_orig.append(oid)
	for k in _contracts_cache.keys():
		var ks: String = str(k)
		var entry: Dictionary = _contracts_cache[ks]
		for rk in req_keys:
			if not entry.has(rk):
				malformed.append(ks + ":" + rk)
			elif rk in ["category", "damage_type", "shield_interaction", "reset_policy", "visual_cue", "audio_cue"] and str(entry[rk]) == "":
				malformed.append(ks + ":empty_" + rk)
			elif rk == "states" and (typeof(entry[rk]) != TYPE_ARRAY or (entry[rk] as Array).is_empty()):
				malformed.append(ks + ":empty_states")
	return {
		"ok": missing_orig.is_empty() and malformed.is_empty(),
		"original_98_count": ORIGINAL_98_IDS.size(),
		"total_registered": _contracts_cache.size(),
		"missing_original": missing_orig,
		"malformed_entries": malformed
	}
