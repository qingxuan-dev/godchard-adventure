class_name ChiptunePlayer
extends RefCounted

var player_node: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0
var bgm_phase: float = 0.0
var sfx_phase: float = 0.0
var sfx_freq: float = 0.0
var sfx_remain: float = 0.0
var step_timer: float = 0.0
var step_idx: int = 0
var active_notes: Array[float] = [220.0, 261.63, 329.63, 440.0, 392.0, 329.63, 293.66, 246.94]
var step_duration: float = 0.19

const TRACK_TITLE: Array[float] = [523.25, 659.25, 783.99, 1046.5, 783.99, 659.25, 587.33, 783.99]
const TRACK_CYBER: Array[float] = [220.0, 261.63, 329.63, 440.0, 392.0, 329.63, 293.66, 246.94]
const TRACK_ARCADIA: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33]
const TRACK_SKY: Array[float] = [587.33, 659.25, 783.99, 987.77, 880.0, 783.99, 659.25, 523.25]
const TRACK_BOSS_S3: Array[float] = [329.63, 392.0, 493.88, 659.25, 587.33, 493.88, 440.0, 392.0]

func _init(node: AudioStreamPlayer) -> void:
	player_node = node
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.12
	player_node.stream = gen
	player_node.play()
	playback = player_node.get_stream_playback() as AudioStreamGeneratorPlayback

func select_track(is_title: bool, stage_id: int) -> void:
	if is_title:
		active_notes = TRACK_TITLE
		step_duration = 0.21
	elif stage_id >= 101:
		var is_boss = stage_id in [110, 120, 130, 140, 150]
		active_notes = TRACK_BOSS_S3 if is_boss else (TRACK_SKY if stage_id >= 126 else TRACK_ARCADIA)
		step_duration = 0.16 if is_boss else 0.19
	else:
		active_notes = TRACK_CYBER
		step_duration = 0.19

func play_sfx(freq: float, dur: float = 0.10) -> void:
	sfx_freq = freq
	sfx_remain = dur

func fill_buffer(volume: float) -> void:
	if playback == null:
		return
	var frames = playback.get_frames_available()
	var dt = 1.0 / sample_rate
	for _i in range(frames):
		step_timer += dt
		if step_timer >= step_duration:
			step_timer -= step_duration
			step_idx = (step_idx + 1) % active_notes.size()
		bgm_phase = fmod(bgm_phase + active_notes[step_idx] * dt, 1.0)
		var s: float = (0.045 if bgm_phase < 0.5 else -0.045)
		if sfx_remain > 0.0:
			sfx_remain -= dt
			sfx_phase = fmod(sfx_phase + sfx_freq * dt, 1.0)
			s += (0.14 if sfx_phase < 0.5 else -0.14)
		s *= volume
		playback.push_frame(Vector2(s, s))
