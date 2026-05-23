extends Node3D

signal pitch_arrived(plate_position: Vector3)
signal ball_landed(landed_position: Vector3)

var _trajectory: BallTrajectory
var _time: float = 0.0
var _active: bool = false

func throw_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
	_trajectory = BallTrajectory.create_pitch(pitch_type, target, accuracy)
	position = _trajectory.start_position
	_time = 0.0
	_active = true
	visible = true

func launch_batted(start: Vector3, exit_velocity: float, launch_angle: float, h_angle: float) -> void:
	_trajectory = BallTrajectory.create_batted(start, exit_velocity, launch_angle, h_angle)
	position = start
	_time = 0.0
	_active = true
	visible = true

func reset() -> void:
	_active = false
	visible = false
	_time = 0.0

func is_active() -> bool:
	return _active

func get_current_velocity() -> Vector3:
	if _trajectory:
		return _trajectory.get_velocity(_time)
	return Vector3.ZERO

func _process(delta: float) -> void:
	if not _active:
		return

	_time += delta
	position = _trajectory.get_position(_time)

	if _trajectory.is_pitch:
		if position.z >= 0.0:
			_active = false
			pitch_arrived.emit(position)
	else:
		if position.y <= 0.0 and _time > 0.1:
			position.y = 0.0
			_active = false
			ball_landed.emit(position)
