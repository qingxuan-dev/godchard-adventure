class_name ChiptunePlayer
extends RefCounted

const SFX_POOL_SIZE: int = 8
const S2_BOSS_IDS: Array[int] = [60, 67, 70, 80, 88, 90, 98, 100]
const S3_BOSS_IDS: Array[int] = [110, 120, 130, 140, 150]

const SFX_ALIASES: Dictionary = {
	"node_on": ["node_toggle", 1.12],
	"node_off": ["node_toggle", 0.86],
	"layer_switch": ["portal_warp", 1.16],
	"layer_deny": ["fake_buzz", 0.94],
	"phase_shift": ["portal_warp", 1.28],
	"magnet_pulse": ["shield_up", 1.15],
	"beat_open": ["node_toggle", 1.24],
	"time_bubble_in": ["portal_warp", 0.82],
	"boss_phase_break": ["boom", 1.14]
}

var host_node: Node
var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0

var bgm_streams: Dictionary = {}
var sfx_streams: Dictionary = {}

var bgm_bus_idx: int = -1
var sfx_bus_idx: int = -1
var lowpass_fx: AudioEffectLowPassFilter = null

var cur_track_key: String = ""
var duck_timer: float = 0.0
var duck_min_gain: float = 1.0
var cur_cutoff: float = 16500.0

func _init(p_bgm_player: AudioStreamPlayer, p_meta: Dictionary = {}) -> void:
	bgm_player = p_bgm_player
	host_node = p_bgm_player.get_parent()
	_setup_audio_buses()
	bgm_player.bus = "BGM"
	_setup_sfx_pool()
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

func _setup_sfx_pool() -> void:
	if host_node == null:
		return
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
	if stage_id in S2_BOSS_IDS:
		return "bossS2"
	if stage_id >= 71:
		return "stageD"
	if stage_id >= 51:
		return "stageC"
	if stage_id >= 31:
		return "stageB"
	return "stageA"

func select_track(is_title: bool, stage_id: int) -> void:
	var key: String = pick_track_key(is_title, stage_id)
	if key == cur_track_key and bgm_player.playing:
		return
	cur_track_key = key
	if bgm_streams.has(key):
		bgm_player.stream = bgm_streams[key]
		bgm_player.play()

func sync_state(delta: float, save: SaveManager, is_paused_or_modal: bool, world_frozen: bool, world_slow: bool, standby_on: bool) -> void:
	if duck_timer > 0.0:
		duck_timer = maxf(0.0, duck_timer - delta)

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

func play_named(sfx_name: String, pitch: float = 1.0) -> void:
	var resolved_name: String = sfx_name
	var resolved_pitch: float = pitch
	if not sfx_streams.has(resolved_name) and SFX_ALIASES.has(resolved_name):
		var pair: Array = SFX_ALIASES[resolved_name]
		resolved_name = str(pair[0])
		resolved_pitch = pitch * float(pair[1])
	if not sfx_streams.has(resolved_name) or sfx_pool.is_empty():
		return
	if resolved_name in ["spring", "fake_wall_shatter", "enemy_kill", "shield_parry", "boom", "die", "fake_buzz", "real_win"]:
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
