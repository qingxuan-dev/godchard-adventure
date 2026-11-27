class_name TrapBase
extends Node2D

signal state_changed(old_state: StringName, new_state: StringName)
signal trap_activated(trap_uuid: String, source: Variant)
signal trap_deactivated(trap_uuid: String)

const STATE_IDLE: StringName = &"idle"
const STATE_ARMED: StringName = &"armed"
const STATE_WARNING: StringName = &"warning"
const STATE_ACTIVE: StringName = &"active"
const STATE_COOLDOWN: StringName = &"cooldown"
const STATE_RESET: StringName = &"reset"

@export var trap_id: StringName = &""
@export var initial_state: StringName = &"idle"
@export var warning_time: float = 0.8
@export var reset_policy: StringName = &"checkpoint"

var uuid: String = ""
var type_id: String = ""
var category: String = "terrain"
var current_state: StringName = &"idle"
var state_timer: float = 0.0
var active_duration: float = 0.65
var cooldown_duration: float = 0.85
var reset_duration: float = 0.15
var layer_id: int = -1
var signal_group: String = ""
var damage_type: String = "none"
var shield_interaction: String = "none"
var is_enabled: bool = true
var trigger_count: int = 0
var config_data: Dictionary = {}
var checkpoint_snapshot: Dictionary = {}

func _ready() -> void:
	current_state = initial_state

func configure(data: Dictionary) -> void:
	config_data = data.duplicate(true)
	uuid = str(data.get("uuid", data.get("key", "")))
	type_id = str(data.get("t", str(trap_id)))
	if trap_id == &"" and type_id != "":
		trap_id = StringName(type_id)
	if data.has("initialState"):
		initial_state = StringName(str(data["initialState"]))
	if data.has("warningTime"):
		warning_time = maxf(0.0, float(data["warningTime"]))
	if data.has("activeDuration"):
		active_duration = maxf(0.05, float(data["activeDuration"]))
	if data.has("cooldownDuration"):
		cooldown_duration = maxf(0.0, float(data["cooldownDuration"]))
	if data.has("resetPolicy"):
		reset_policy = StringName(str(data["resetPolicy"]))
	layer_id = int(data["layer"]) if (data.has("layer") and data["layer"] != null) else -1
	signal_group = str(data.get("group", data.get("unlockGroup", "")))
	damage_type = str(data.get("damageType", damage_type))
	shield_interaction = str(data.get("shieldInteraction", shield_interaction))
	if data.has("x") and data.has("y"):
		var oh: float = float(data.get("h", 1.0))
		position = Vector2(GridMath.gx_to_px(float(data["x"])), GridMath.gy_to_py(float(data["y"]), oh))
	current_state = initial_state
	state_timer = 0.0
	trigger_count = 0
	save_checkpoint_state()

func _transition_to(next_state: StringName, duration: float = 0.0) -> void:
	if current_state == next_state:
		state_timer = duration
		return
	var prev_state: StringName = current_state
	current_state = next_state
	state_timer = duration
	state_changed.emit(prev_state, next_state)

func arm() -> void:
	if not is_enabled:
		return
	if current_state == STATE_IDLE or current_state == STATE_RESET:
		_transition_to(STATE_ARMED, 0.0)

func activate(source: Node = null) -> void:
	activate_from_any(source)

func activate_from_any(source: Variant = null) -> void:
	if not is_enabled:
		return
	if current_state == STATE_ACTIVE or current_state == STATE_WARNING:
		return
	trigger_count += 1
	if warning_time > 0.001:
		_transition_to(STATE_WARNING, warning_time)
	else:
		_transition_to(STATE_ACTIVE, active_duration)
		trap_activated.emit(uuid, source)

func deactivate() -> void:
	if current_state == STATE_IDLE:
		return
	if cooldown_duration > 0.001:
		_transition_to(STATE_COOLDOWN, cooldown_duration)
	else:
		_transition_to(STATE_IDLE, 0.0)
	trap_deactivated.emit(uuid)

func step_lifecycle(dt: float) -> void:
	if not is_enabled:
		return
	if current_state == STATE_WARNING:
		state_timer -= dt
		if state_timer <= 0.0:
			_transition_to(STATE_ACTIVE, active_duration)
			trap_activated.emit(uuid, null)
	elif current_state == STATE_ACTIVE:
		if active_duration > 0.0:
			state_timer -= dt
			if state_timer <= 0.0:
				_transition_to(STATE_COOLDOWN, cooldown_duration)
	elif current_state == STATE_COOLDOWN:
		state_timer -= dt
		if state_timer <= 0.0:
			_transition_to(STATE_RESET, reset_duration)
	elif current_state == STATE_RESET:
		state_timer -= dt
		if state_timer <= 0.0:
			_transition_to(initial_state, 0.0)

func save_checkpoint_state() -> Dictionary:
	checkpoint_snapshot = {
		"state": String(current_state),
		"state_timer": state_timer,
		"pos_x": position.x,
		"pos_y": position.y,
		"is_enabled": is_enabled,
		"trigger_count": trigger_count
	}
	return checkpoint_snapshot

func reset_to_checkpoint() -> void:
	if reset_policy == &"persistent" or reset_policy == &"persistent_shard":
		return
	if reset_policy == &"checkpoint" and not checkpoint_snapshot.is_empty():
		var saved_st: StringName = StringName(str(checkpoint_snapshot.get("state", String(initial_state))))
		_transition_to(saved_st, float(checkpoint_snapshot.get("state_timer", 0.0)))
		position = Vector2(float(checkpoint_snapshot.get("pos_x", position.x)), float(checkpoint_snapshot.get("pos_y", position.y)))
		is_enabled = bool(checkpoint_snapshot.get("is_enabled", true))
		trigger_count = int(checkpoint_snapshot.get("trigger_count", 0))
		return
	full_reset()

func full_reset() -> void:
	_transition_to(initial_state, 0.0)
	is_enabled = true
	trigger_count = 0
	if config_data.has("x") and config_data.has("y"):
		var oh: float = float(config_data.get("h", 1.0))
		position = Vector2(GridMath.gx_to_px(float(config_data["x"])), GridMath.gy_to_py(float(config_data["y"]), oh))

func get_debug_state() -> Dictionary:
	return {
		"uuid": uuid,
		"trap_id": String(trap_id),
		"type_id": type_id,
		"category": category,
		"state": String(current_state),
		"state_timer": snappedf(state_timer, 0.001),
		"warning_time": warning_time,
		"reset_policy": String(reset_policy),
		"layer": layer_id,
		"signal_group": signal_group,
		"damage_type": damage_type,
		"shield_interaction": shield_interaction,
		"is_enabled": is_enabled,
		"trigger_count": trigger_count,
		"position": { "x": position.x, "y": position.y }
	}
