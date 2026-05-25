class_name BatterController extends Node3D

# Swing FSM (parent spec §5). Steps on a SwingInput each tick and returns a
# SwingCommand on the tick it commits (else null). Timing, placement, and cursor
# are latched at button-DOWN. Tap (<TAP_THRESHOLD_TICKS) = CONTACT, hold = POWER;
# held through the crossing tick auto-commits POWER. Human input (BatterInput)
# and the AI feed the same SwingInput — one commit path.

const TAP_THRESHOLD_TICKS := 6  # ~100ms at 60Hz

enum State { IDLE, AIMING, CHARGING, COMMITTED, TAKEN }

var _state: State = State.IDLE
var _crossing_tick: int = 0
var _cursor: Vector2 = Vector2.ZERO          # current (for the marker / display)
var _commit_tick: int = 0
var _cursor_latched: Vector2 = Vector2.ZERO
var _placement_latched: Vector2 = Vector2.ZERO

@onready var _cursor_marker: MeshInstance3D = $CursorMarker if has_node("CursorMarker") else null

func _ready() -> void:
	if _cursor_marker != null:
		_cursor_marker.visible = false

func cursor() -> Vector2:
	return _cursor

func is_taken() -> bool:
	return _state == State.TAKEN

# Arm for a new at-bat; crossing_tick is when the pitch reaches the plate.
func arm(p_crossing_tick: int) -> void:
	_state = State.AIMING
	_crossing_tick = p_crossing_tick
	_cursor = Vector2.ZERO
	if _cursor_marker != null:
		_cursor_marker.visible = true

# Advance one tick. Returns a SwingCommand on the commit tick, else null.
func step(input: SwingInput, tick: int) -> SwingCommand:
	match _state:
		State.AIMING:
			_cursor = input.cursor
			_update_marker()
			if input.commit_pressed:
				_state = State.CHARGING
				_commit_tick = tick
				_cursor_latched = input.cursor
				_placement_latched = input.placement_dir
			elif tick >= _crossing_tick:
				_state = State.TAKEN
			return null
		State.CHARGING:
			if not input.commit_pressed:
				var held := tick - _commit_tick
				var st := SwingCommand.SwingType.CONTACT if held < TAP_THRESHOLD_TICKS else SwingCommand.SwingType.POWER
				_state = State.COMMITTED
				return _make_command(st)
			elif tick >= _crossing_tick:
				_state = State.COMMITTED
				return _make_command(SwingCommand.SwingType.POWER)
			return null
		_:
			return null

func _make_command(swing_type: SwingCommand.SwingType) -> SwingCommand:
	if _cursor_marker != null:
		_cursor_marker.visible = false
	return SwingCommand.new(_cursor_latched, swing_type, _placement_latched, _commit_tick)

func _update_marker() -> void:
	if _cursor_marker == null:
		return
	# Place at the WORLD strike-zone plane, not batter-local: the marker is a child
	# of the batter (offset (0.5,0,0.3)), so a local position would inherit that
	# offset and drift right of / inside the batter instead of over the plate.
	_cursor_marker.global_position = FieldConstants.STRIKE_ZONE_CENTER + Vector3(_cursor.x, _cursor.y, 0.0)
