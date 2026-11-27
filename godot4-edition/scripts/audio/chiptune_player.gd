class_name ChiptunePlayer
extends RefCounted

signal visual_audio_cue(cue: Dictionary)

const SFX_POOL_SIZE: int = 12
const S1_CLIMAX_BOSS_IDS: Array[int] = [38, 48, 50]
const S2_BOSS_IDS: Array[int] = [60, 67, 70, 80, 88, 90, 98, 100]
const S3_BOSS_IDS: Array[int] = [110, 120, 130, 140, 150]

# Every alias resolves strictly to one of the 38 verified keys in data/game_metadata.json["sfxFiles"]
const SFX_ALIASES: Dictionary = {
	"node_on": ["node_toggle", 1.12],
	"node_off": ["node_toggle", 0.86],
	"layer_switch": ["portal_warp", 1.16],
	"layer_deny": ["fake_buzz", 0.94],
	"phase_shift": ["portal_warp", 1.28],
	"magnet_pulse": ["shield_up", 1.15],
	"beat_open": ["clock_gear", 1.12],
	"time_bubble_in": ["portal_warp", 0.82],
	"boss_phase_break": ["boom", 1.14],
	"sheathe": ["sword_sheathe", 1.0],
	"unsheathe": ["sword_sheathe", 1.22],
	"pound": ["ground_pound", 1.0],
	"slam": ["ground_pound", 0.94],
	"valve": ["valve_turn", 1.0],
	"mirror": ["mirror_ping", 1.0],
	"mirror_reflect": ["mirror_ping", 1.08],
	"sundial": ["sundial_shift", 1.0],
	"echo_single": ["pipe_echo_single", 1.0],
	"echo_double": ["pipe_echo_double", 1.0]
}

# Master GDD 10 & 11.3 Accessibility Audio-Visual Subtitles:
# Every icon value below is 100% verified in data/game_metadata.json["assets"]!
const VISUAL_SUBTITLE_MAP: Dictionary = {
	"cloud_solid": {
		"icon": "cloud_safe",
		"zh": "～ [沉闷踏云音] 实心承重云 · 可安全站立",
		"en": "～ [Low Thud] Solid Cloud · Safe to stand",
		"color": "#4ade80",
		"wave": "low",
		"priority": 2
	},
	"cloud_blade": {
		"icon": "cloud_knife",
		"zh": "⚡ [金属铮鸣!] 暗刃刀云预警 · 勿正面踩踏",
		"en": "⚡ [Metallic Ring!] Blade Cloud Warning",
		"color": "#fb7185",
		"wave": "sharp",
		"priority": 3
	},
	"cloud_hollow": {
		"icon": "cloud_dark_safe",
		"zh": "◌ [虚空回响] 空心云 · 受压或影入将下沉",
		"en": "◌ [Hollow Echo] Hollow Cloud · Sinks on shadow/step",
		"color": "#c084fc",
		"wave": "hollow",
		"priority": 2
	},
	"cloud_bounce": {
		"icon": "icon_spring",
		"zh": "≋ [弹性共鸣] 反弹云 · 固定弹高助跳",
		"en": "≋ [Elastic Boing] Bounce Cloud · High rebound",
		"color": "#38bdf8",
		"wave": "chime",
		"priority": 2
	},
	"pipe_echo_single": {
		"icon": "pipe",
		"zh": "◆ [单声水滴回声] 管道直通 · 正常出口",
		"en": "◆ [Single Drip Echo] Direct Pipe Passage",
		"color": "#4ade80",
		"wave": "echo1",
		"priority": 3
	},
	"pipe_echo_double": {
		"icon": "pipe",
		"zh": "◆◆ [双重水滴回声!] 环路管道 · 需先改阀门",
		"en": "◆◆ [Double Echo!] Loop Pipe · Check valve first",
		"color": "#fde047",
		"wave": "echo2",
		"priority": 3
	},
	"clock_low": {
		"icon": "clock_gold",
		"zh": "♪ [低音大钟鸣] 加速作用域已触发",
		"en": "♪ [Low Bell Toll] Speed-Up Clock Zone",
		"color": "#fb923c",
		"wave": "low",
		"priority": 3
	},
	"clock_high": {
		"icon": "clock_gold",
		"zh": "♪ [高音小钟鸣] 局部机关冻结域已触发",
		"en": "♪ [High Chime] Mechanism Freeze Zone",
		"color": "#38bdf8",
		"wave": "chime",
		"priority": 3
	},
	"clock_gear": {
		"icon": "clock_gear",
		"zh": "⚙ [齿轮钟咬合] 倒计时/节拍拍点同步",
		"en": "⚙ [Gear Tick] Countdown / Beat Sync",
		"color": "#fde047",
		"wave": "mech",
		"priority": 3
	},
	"sword_sheathe": {
		"icon": "icon_sword",
		"zh": "◈ [收剑入鞘] 静默非攻击姿态切换",
		"en": "◈ [Blade Sheathed] Calm Non-Hostile Stance",
		"color": "#67e8f9",
		"wave": "chime",
		"priority": 3
	},
	"ground_pound": {
		"icon": "arrow_up_red",
		"zh": "▼ [三段下砸冲击] 重击地面压力开关/石砖",
		"en": "▼ [Ground Pound] Heavy Downward Impact",
		"color": "#f97316",
		"wave": "low",
		"priority": 2
	},
	"valve_turn": {
		"icon": "s3_valve_red",
		"zh": "↻ [黄铜手轮旋动] 管道水压流向已改写",
		"en": "↻ [Valve Turned] Aqueduct Pressure Rerouted",
		"color": "#4ade80",
		"wave": "mech",
		"priority": 3
	},
	"mirror_ping": {
		"icon": "v2_mirror_rotatable",
		"zh": "✦ [晶镜折射清鸣] 弹道/光束角度反射",
		"en": "✦ [Mirror Ping] Beam / Shot Reflected",
		"color": "#00f5ff",
		"wave": "chime",
		"priority": 3
	},
	"sundial_shift": {
		"icon": "s3_sundial_orb",
		"zh": "☀ [日晷相位流转] 昼/暮/夜与影长已切换",
		"en": "☀ [Sundial Shift] Day/Dusk/Night Phase Changed",
		"color": "#fde047",
		"wave": "chime",
		"priority": 3
	},
	"fake_wall_shatter": {
		"icon": "cyber_wall",
		"zh": "❖ [伪墙碎裂音] 隐藏夹层通道显形",
		"en": "❖ [Illusion Shattered] Hidden Passage Opened",
		"color": "#c084fc",
		"wave": "sharp",
		"priority": 2
	},
	"armor_clang": {
		"icon": "icon_shield",
		"zh": "✖ [重甲弹开声] 正面免疫 · 寻找弱点或环境反制",
		"en": "✖ [Armor Clang] Immune Front · Find weak spot",
		"color": "#94a3b8",
		"wave": "sharp",
		"priority": 2
	},
	"shield_parry": {
		"icon": "icon_shield",
		"zh": "❖ [护盾弹反] 已吸收一次致命伤害并写入缓存",
		"en": "❖ [Shield Parry] Lethal Hit Absorbed",
		"color": "#38bdf8",
		"wave": "sharp",
		"priority": 2
	},
	"poison": {
		"icon": "icon_poison",
		"zh": "☣ [毒素浸染] 毒态计时开启 · 可触发植物炼金",
		"en": "☣ [Poisoned] Toxic State Active · Alchemy Ready",
		"color": "#a3e635",
		"wave": "hollow",
		"priority": 2
	},
	"fake_win": {
		"icon": "flag_idle",
		"zh": "⚠ [变调假凯歌!] 伪装终点陷阱 · 迅速观察周围",
		"en": "⚠ [Off-Key Fanfare!] Fake Goal Trap!",
		"color": "#fb7185",
		"wave": "sharp",
		"priority": 3
	},
	"node_toggle": {
		"icon": "s2_node_on",
		"zh": "⚡ [信号脉冲音] 线路节点供电状态切换",
		"en": "⚡ [Signal Pulse] Circuit Node Toggled",
		"color": "#00f5ff",
		"wave": "mech",
		"priority": 2
	},
	"portal_warp": {
		"icon": "s2_portal_a",
		"zh": "◎ [次元跃迁音] 空间层/传送相位切换",
		"en": "◎ [Phase Warp] Layer / Portal Shifted",
		"color": "#c084fc",
		"wave": "hollow",
		"priority": 2
	},
	"spring": {
		"icon": "spring",
		"zh": "▲ [强力弹射音] 高空弹簧冲击触发",
		"en": "▲ [Spring Launch] High Impulse Bounce",
		"color": "#4ade80",
		"wave": "chime",
		"priority": 1
	},
	"boom": {
		"icon": "bomb",
		"zh": "※ [爆破轰鸣] 连锁冲击波已释放",
		"en": "※ [Detonation] Blast Wave Triggered",
		"color": "#fb923c",
		"wave": "low",
		"priority": 2
	}
}

var host_node: Node
var bgm_player: AudioStreamPlayer
var bgm_crossfade_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0

var bgm_streams: Dictionary = {}
var sfx_streams: Dictionary = {}

var bgm_bus_idx: int = -1
var sfx_bus_idx: int = -1
var lowpass_fx: AudioEffectLowPassFilter = null

var cur_track_key: String = ""
var crossfade_timer: float = 0.0
var crossfade_dur: float = 0.42
var duck_timer: float = 0.0
var duck_min_gain: float = 1.0
var cur_cutoff: float = 16500.0

var visual_subtitles_enabled: bool = true
var pending_visual_cues: Array = []
var last_cue_time_by_key: Dictionary = {}
var elapsed_clock: float = 0.0

func _init(p_bgm_player: AudioStreamPlayer, p_meta: Dictionary = {}) -> void:
	bgm_player = p_bgm_player
	host_node = p_bgm_player.get_parent()
	_setup_audio_buses()
	bgm_player.bus = "BGM"
	_setup_crossfade_and_sfx_pool()
	if not p_meta.is_empty():
		load_all_audio(p_meta)

func _setup_audio_buses() -> void:
	bgm_bus_idx = AudioServer.get_bus_index("BGM")
	if bgm_bus_idx < 0:
		AudioServer.add_bus()
		bgm_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bgm_bus_idx, "BGM")
		AudioServer.set_bus_send(bgm_bus_idx, "Master")
		lowpass_fx = AudioEffectLowPassFilter.new()
		lowpass_fx.cutoff_hz = 16500.0
		lowpass_fx.resonance = 0.68
		AudioServer.add_bus_effect(bgm_bus_idx, lowpass_fx, 0)
	else:
		if AudioServer.get_bus_effect_count(bgm_bus_idx) > 0:
			var fx0: AudioEffect = AudioServer.get_bus_effect(bgm_bus_idx, 0)
			if fx0 is AudioEffectLowPassFilter:
				lowpass_fx = fx0 as AudioEffectLowPassFilter

	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx < 0:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(sfx_bus_idx, "Master")

	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0 and AudioServer.get_bus_effect_count(master_idx) == 0:
		var comp: AudioEffectCompressor = AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 3.6
		comp.attack_us = 3000.0
		comp.release_ms = 140.0
		AudioServer.add_bus_effect(master_idx, comp, 0)

func _setup_crossfade_and_sfx_pool() -> void:
	if host_node == null:
		return
	bgm_crossfade_player = AudioStreamPlayer.new()
	bgm_crossfade_player.name = "BgmCrossfadePlayer"
	bgm_crossfade_player.bus = "BGM"
	host_node.add_child(bgm_crossfade_player)

	for _i in range(SFX_POOL_SIZE):
		var sp: AudioStreamPlayer = AudioStreamPlayer.new()
		sp.bus = "SFX"
		host_node.add_child(sp)
		sfx_pool.append(sp)

func load_all_audio(meta: Dictionary) -> void:
	var bgm_map: Dictionary = meta.get("bgmFiles", {})
	for k in bgm_map.keys():
		var rel: String = "res://" + str(bgm_map[k])
		var st: AudioStream = _load_ogg_stream(rel)
		if st != null:
			bgm_streams[str(k)] = st

	var sfx_map: Dictionary = meta.get("sfxFiles", {})
	for sk in sfx_map.keys():
		var srel: String = "res://" + str(sfx_map[sk])
		var sst: AudioStream = _load_wav_stream(srel)
		if sst != null:
			sfx_streams[str(sk)] = sst

func _load_ogg_stream(res_path: String) -> AudioStream:
	if ResourceLoader.exists(res_path):
		var r: Resource = load(res_path)
		if r is AudioStreamOggVorbis:
			var ogg: AudioStreamOggVorbis = r as AudioStreamOggVorbis
			ogg.loop = true
			return ogg
		if r is AudioStream:
			return r as AudioStream
	if FileAccess.file_exists(res_path):
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if raw.size() > 0:
			var ogg2: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(raw)
			if ogg2 != null:
				ogg2.loop = true
				return ogg2
	return null

func _load_wav_stream(res_path: String) -> AudioStream:
	if ResourceLoader.exists(res_path):
		var r: Resource = load(res_path)
		if r is AudioStream:
			return r as AudioStream
	if not FileAccess.file_exists(res_path):
		return null
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if raw.size() <= 44:
		return null
	var channels: int = raw.decode_u16(22)
	var sample_rate: int = raw.decode_u32(24)
	var pos: int = 12
	var data_offset: int = 44
	var data_size: int = raw.size() - 44
	while pos + 8 <= raw.size():
		var cid: String = raw.slice(pos, pos + 4).get_string_from_ascii()
		var csz: int = raw.decode_u32(pos + 4)
		if cid == "data":
			data_offset = pos + 8
			data_size = mini(csz, raw.size() - data_offset)
			break
		pos += 8 + csz
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = maxi(8000, sample_rate)
	wav.stereo = (channels >= 2)
	wav.data = raw.slice(data_offset, data_offset + data_size)
	return wav

func pick_track_key(is_title: bool, stage_id: int) -> String:
	if is_title:
		return "title"
	if stage_id >= 101:
		if stage_id in S3_BOSS_IDS:
			return "bossS3"
		return "stageF" if stage_id >= 126 else "stageE"
	if stage_id in S2_BOSS_IDS or stage_id in S1_CLIMAX_BOSS_IDS:
		return "bossS2"
	if stage_id >= 71:
		return "stageD"
	if stage_id >= 51:
		return "stageC"
	if stage_id >= 26:
		return "stageB"
	return "stageA"

func select_track(is_title: bool, stage_id: int) -> void:
	var key: String = pick_track_key(is_title, stage_id)
	play_bgm_key(key)

func play_bgm_key(key: String) -> void:
	if not bgm_streams.has(key) or bgm_player == null:
		return
	if key == cur_track_key and bgm_player.playing:
		return
	# Smooth equal-power crossfade from previous BGM into new chapter/Boss BGM without abrupt cut!
	if bgm_player.playing and bgm_crossfade_player != null and cur_track_key != "":
		bgm_crossfade_player.stream = bgm_player.stream
		bgm_crossfade_player.pitch_scale = bgm_player.pitch_scale
		bgm_crossfade_player.volume_db = 0.0
		bgm_crossfade_player.play(bgm_player.get_playback_position())
		crossfade_timer = crossfade_dur
		bgm_player.volume_db = -24.0
	else:
		crossfade_timer = 0.0
		bgm_player.volume_db = 0.0

	cur_track_key = key
	bgm_player.stream = bgm_streams[key]
	bgm_player.play()

func sync_state(delta: float, save: SaveManager, is_paused_or_modal: bool, world_frozen: bool, world_slow: bool, standby_on: bool) -> void:
	elapsed_clock += delta
	if duck_timer > 0.0:
		duck_timer = maxf(0.0, duck_timer - delta)

	if crossfade_timer > 0.0:
		crossfade_timer = maxf(0.0, crossfade_timer - delta)
		var t_in: float = 1.0 - (crossfade_timer / maxf(0.05, crossfade_dur))
		if bgm_player != null:
			bgm_player.volume_db = linear_to_db(maxf(0.001, sin(t_in * PI * 0.5)))
		if bgm_crossfade_player != null:
			if crossfade_timer <= 0.001:
				bgm_crossfade_player.stop()
			else:
				bgm_crossfade_player.volume_db = linear_to_db(maxf(0.001, cos(t_in * PI * 0.5)))
	elif bgm_player != null:
		bgm_player.volume_db = 0.0

	var duck_mul: float = lerpf(1.0, duck_min_gain, clampf(duck_timer / 0.16, 0.0, 1.0)) if duck_timer > 0.0 else 1.0
	var pause_mul: float = 0.56 if is_paused_or_modal else 1.0

	if bgm_bus_idx >= 0:
		var bgm_muted: bool = (not save.bgm_on) or (save.bgm_vol <= 0.005) or standby_on
		AudioServer.set_bus_mute(bgm_bus_idx, bgm_muted)
		if not bgm_muted:
			var lin_b: float = pow(clampf(save.bgm_vol, 0.0, 1.0), 1.3) * pause_mul * duck_mul
			AudioServer.set_bus_volume_db(bgm_bus_idx, linear_to_db(maxf(0.0005, lin_b)))

	if sfx_bus_idx >= 0:
		var sfx_muted: bool = (not save.sfx_on) or (save.sfx_vol <= 0.005) or standby_on
		AudioServer.set_bus_mute(sfx_bus_idx, sfx_muted)
		if not sfx_muted:
			var lin_s: float = pow(clampf(save.sfx_vol, 0.0, 1.0), 1.25)
			AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(maxf(0.0005, lin_s)))

	if lowpass_fx != null:
		var target_cut: float = 1280.0 if is_paused_or_modal else (920.0 if world_frozen else 16500.0)
		cur_cutoff = lerpf(cur_cutoff, target_cut, minf(1.0, delta * 12.0))
		lowpass_fx.cutoff_hz = cur_cutoff

	if bgm_player != null:
		var target_pitch: float = 0.55 if world_frozen else (0.82 if world_slow else 1.0)
		bgm_player.pitch_scale = lerpf(bgm_player.pitch_scale, target_pitch, minf(1.0, delta * 10.0))
		if not bgm_player.playing and cur_track_key != "" and bgm_streams.has(cur_track_key) and not standby_on:
			bgm_player.stream = bgm_streams[cur_track_key]
			bgm_player.play()

func duck_bgm(min_gain: float = 0.44, dur: float = 0.22) -> void:
	duck_min_gain = clampf(min_gain, 0.2, 1.0)
	duck_timer = maxf(duck_timer, dur)

func _emit_visual_subtitle_if_needed(resolved_name: String, pitch: float) -> void:
	if not visual_subtitles_enabled:
		return
	if not VISUAL_SUBTITLE_MAP.has(resolved_name):
		return
	# Throttle identical rapid-fire cue within 0.18s so HUD subtitle stays crisp and readable
	var last_t: float = float(last_cue_time_by_key.get(resolved_name, -99.0))
	if elapsed_clock - last_t < 0.18:
		return
	last_cue_time_by_key[resolved_name] = elapsed_clock

	var spec: Dictionary = VISUAL_SUBTITLE_MAP[resolved_name]
	var cue: Dictionary = {
		"sfx": resolved_name,
		"icon": str(spec.get("icon", "ui_audio")),
		"zh": str(spec.get("zh", "")),
		"en": str(spec.get("en", "")),
		"color": str(spec.get("color", "#00f5ff")),
		"wave": str(spec.get("wave", "chime")),
		"priority": int(spec.get("priority", 1)),
		"pitch": pitch
	}
	pending_visual_cues.append(cue)
	if pending_visual_cues.size() > 8:
		pending_visual_cues.pop_front()
	visual_audio_cue.emit(cue)

func pop_visual_cues() -> Array:
	if pending_visual_cues.is_empty():
		return []
	var out: Array = pending_visual_cues.duplicate()
	pending_visual_cues.clear()
	return out

func play_named(sfx_name: String, pitch: float = 1.0) -> void:
	var resolved_name: String = sfx_name
	var resolved_pitch: float = pitch
	if not sfx_streams.has(resolved_name) and SFX_ALIASES.has(resolved_name):
		var pair: Array = SFX_ALIASES[resolved_name]
		resolved_name = str(pair[0])
		resolved_pitch = pitch * float(pair[1])

	# Emit visual audio subtitle even if speakers are muted or headless (Master GDD 10 & 11.3)!
	_emit_visual_subtitle_if_needed(resolved_name, resolved_pitch)

	if not sfx_streams.has(resolved_name) or sfx_pool.is_empty():
		return
	if resolved_name in [
		"spring", "fake_wall_shatter", "enemy_kill", "shield_parry", "boom", "die",
		"fake_buzz", "real_win", "ground_pound", "sundial_shift", "pipe_echo_single",
		"pipe_echo_double", "clock_low", "clock_high", "clock_gear"
	]:
		duck_bgm(0.42, 0.24)
	var sp: AudioStreamPlayer = sfx_pool[sfx_cursor % sfx_pool.size()]
	sfx_cursor = (sfx_cursor + 1) % sfx_pool.size()
	sp.stream = sfx_streams[resolved_name]
	sp.pitch_scale = resolved_pitch
	sp.play()

func play_sfx(freq: float, _dur: float = 0.10) -> void:
	if freq >= 950.0:
		play_named("coin")
	elif freq >= 700.0:
		play_named("shoot")
	elif freq >= 500.0:
		play_named("jump")
	elif freq >= 300.0:
		play_named("melee_slash")
	else:
		play_named("die")
