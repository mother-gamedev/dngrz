extends Node3D

# Pitch type select (1/2/3/4) is handled one-shot in _unhandled_input; aim
# (WASD) is polled continuously in _process. No keys are shared between them.

signal pitch_committed(cmd: PitchCommand)

var _selected_pitch: PitchTypes.Type = PitchTypes.Type.FASTBALL
var _target: Vector3 = FieldConstants.STRIKE_ZONE_CENTER
var _is_aiming: bool = false
var _aim_speed := 1.5  # m/s cursor movement

@onready var _target_marker: MeshInstance3D = $TargetMarker

func _ready() -> void:
	if _target_marker != null:
		_target_marker.visible = false

func get_selected_pitch() -> PitchTypes.Type:
	return _selected_pitch

func get_target() -> Vector3:
	return _target

func start_aiming() -> void:
	_is_aiming = true
	_target = FieldConstants.STRIKE_ZONE_CENTER
	if _target_marker != null:
		_target_marker.visible = true
		_target_marker.position = _target

func stop_aiming() -> void:
	_is_aiming = false
	if _target_marker != null:
		_target_marker.visible = false

func _build_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> PitchCommand:
	return PitchCommand.new(pitch_type, target, 1.0, accuracy, Vector2.ZERO, PitchTypes.Tier.BASIC, 0, 0)

# Programmatic pitch (AI). The director stamps rng_seed + start_tick on receipt.
func request_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float = 1.0) -> void:
	pitch_committed.emit(_build_pitch(pitch_type, target, accuracy))

func _unhandled_input(event: InputEvent) -> void:
	if not _is_aiming:
		return
	# Pitch type select (Q/W/E/R)
	if event.is_action_pressed("pitch_fastball"):
		_selected_pitch = PitchTypes.Type.FASTBALL
	elif event.is_action_pressed("pitch_curveball"):
		_selected_pitch = PitchTypes.Type.CURVEBALL
	elif event.is_action_pressed("pitch_slider"):
		_selected_pitch = PitchTypes.Type.SLIDER
	elif event.is_action_pressed("pitch_changeup"):
		_selected_pitch = PitchTypes.Type.CHANGEUP
	if event.is_action_pressed("pitch_throw"):
		_execute_pitch()

func _process(delta: float) -> void:
	if not _is_aiming:
		return
	var move := Vector2.ZERO
	if Input.is_action_pressed("aim_left"):
		move.x -= 1.0
	if Input.is_action_pressed("aim_right"):
		move.x += 1.0
	if Input.is_action_pressed("aim_up"):
		move.y += 1.0
	if Input.is_action_pressed("aim_down"):
		move.y -= 1.0
	if move.length() > 0.0:
		_target.x += move.x * _aim_speed * delta
		_target.y += move.y * _aim_speed * delta
		_target.x = clampf(_target.x, -0.6, 0.6)
		_target.y = clampf(_target.y, 0.1, 1.5)
		if _target_marker != null:
			_target_marker.position = _target

func _execute_pitch() -> void:
	var pdata := PitchTypes.get_pitch(_selected_pitch)
	pitch_committed.emit(_build_pitch(_selected_pitch, _target, pdata.accuracy))
	_is_aiming = false
	if _target_marker != null:
		_target_marker.visible = false
