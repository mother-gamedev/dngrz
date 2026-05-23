extends Node3D

# Emitted when the player (or AI via request_swing) commits a swing.
# timing_offset is filled in by the game orchestrator (initial value 0.0);
# the controller passes through the cursor position as placement.
signal swing_executed(timing_offset: float, placement: Vector2)
signal took_pitch  # batter let the pitch go by

var _can_swing: bool = false
var _pitch_arrival_time: float = 0.0
var _cursor: Vector2 = Vector2.ZERO  # relative to strike zone center
var _cursor_speed := 2.0
var _swung: bool = false

@onready var _cursor_marker: MeshInstance3D = $CursorMarker

func _ready() -> void:
	if _cursor_marker != null:
		_cursor_marker.visible = false

func get_cursor_position() -> Vector2:
	return _cursor

func is_armed() -> bool:
	return _can_swing and not _swung

func start_at_bat(pitch_flight_duration: float) -> void:
	_can_swing = true
	_swung = false
	_pitch_arrival_time = pitch_flight_duration
	_cursor = Vector2.ZERO
	if _cursor_marker != null:
		_cursor_marker.visible = true
		_update_cursor_marker()

func pitch_arrived(_plate_position: Vector3) -> void:
	_can_swing = false
	if _cursor_marker != null:
		_cursor_marker.visible = false
	if not _swung:
		took_pitch.emit()

# Programmatic swing — used by AI (Task 11a) to drive the controller.
func request_swing(timing_offset: float, placement: Vector2) -> void:
	_swung = true
	swing_executed.emit(timing_offset, placement)

func _unhandled_input(event: InputEvent) -> void:
	if not _can_swing or _swung:
		return
	if event.is_action_pressed("batter_swing"):
		_swung = true
		_execute_swing()

func _process(delta: float) -> void:
	if not _can_swing or _swung:
		return
	var move := Vector2.ZERO
	if Input.is_action_pressed("bat_cursor_left"):
		move.x -= 1.0
	if Input.is_action_pressed("bat_cursor_right"):
		move.x += 1.0
	if Input.is_action_pressed("bat_cursor_up"):
		move.y += 1.0
	if Input.is_action_pressed("bat_cursor_down"):
		move.y -= 1.0
	if move.length() > 0.0:
		_cursor += move.normalized() * _cursor_speed * delta
		_cursor.x = clampf(_cursor.x, -0.5, 0.5)
		_cursor.y = clampf(_cursor.y, -0.5, 0.5)
		_update_cursor_marker()

func _execute_swing() -> void:
	# The actual timing is computed by the game orchestrator (see game.gd
	# Task 16). Emit cursor as placement; orchestrator fills timing.
	swing_executed.emit(0.0, _cursor)

func _update_cursor_marker() -> void:
	if _cursor_marker == null:
		return
	_cursor_marker.position = Vector3(
		_cursor.x,
		FieldConstants.STRIKE_ZONE_CENTER.y + _cursor.y,
		0.0
	)
