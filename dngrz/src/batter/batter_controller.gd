class_name BatterController extends Node3D

# Swing FSM (parent spec §5). Steps on a SwingInput each tick and returns a
# SwingCommand on the tick it commits (else null). The 2026-05-25 timing-first
# redesign removed the free aim cursor: only the timing (commit tick) and the
# directional placement bias are latched at button-DOWN — there is nothing to
# aim. Tap (<TAP_THRESHOLD_TICKS) = CONTACT, hold = POWER; held through the
# crossing tick auto-commits POWER. Human input (BatterInput) and the AI feed the
# same SwingInput — one commit path.

const TAP_THRESHOLD_TICKS := 6  # ~100ms at 60Hz

enum State { IDLE, AIMING, CHARGING, COMMITTED, TAKEN }

var _state: State = State.IDLE
var _crossing_tick: int = 0
var _commit_tick: int = 0
var _placement_latched: Vector2 = Vector2.ZERO
var _cursor_latched: Vector2 = Vector2.ZERO

@onready var _bat_pivot: Node3D = $BatPivot if has_node("BatPivot") else null

# Presentation-only swing animation (wall-clock tween — never touches the tick
# sim or resolution). The bat sits cocked at rest and sweeps through the zone on
# commit, then settles back. Degrees, in the pivot's local space.
# Left-handed batter, viewed from the camera behind home (at +Z, looking -Z), so
# the on-screen "clock" is a roll about the world Z view-axis. REST is the cocked
# ~4 o'clock pose; SWING rolls CLOCKWISE ~240° (negative Z reads clockwise from
# +Z) through 6 and 9 o'clock to a ~12 o'clock follow-through. The X/Y tilt is
# held across the swing (it just sets where on the clock the bat sits + its depth);
# only Z sweeps, so the direction is controlled solely by the Z delta's sign.
# Pure presentation — tune by eye in the feel-test (flip the SWING Z sign to
# reverse the spin direction).
const _BAT_REST := Vector3(55.0, 40.0, 0.0)
const _BAT_SWING := Vector3(55.0, 40.0, -240.0)
var _swing_tween: Tween

func _ready() -> void:
	if _bat_pivot != null:
		_bat_pivot.rotation_degrees = _BAT_REST

func is_taken() -> bool:
	return _state == State.TAKEN

# Arm for a new at-bat; crossing_tick is when the pitch reaches the plate.
func arm(p_crossing_tick: int) -> void:
	_state = State.AIMING
	_crossing_tick = p_crossing_tick
	_placement_latched = Vector2.ZERO
	_cursor_latched = Vector2.ZERO
	_reset_bat()

# Advance one tick. Returns a SwingCommand on the commit tick, else null.
func step(input: SwingInput, tick: int) -> SwingCommand:
	match _state:
		State.AIMING:
			if input.commit_pressed:
				_state = State.CHARGING
				_commit_tick = tick
				_placement_latched = input.placement_dir
				_cursor_latched = input.cursor
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
	_play_swing(swing_type)
	return SwingCommand.new(_cursor_latched, swing_type, Vector2.ZERO, _commit_tick)

# Snap the bat back to the cocked ready pose (next pitch). No-op headlessly.
func _reset_bat() -> void:
	if _bat_pivot == null or not is_inside_tree():
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_bat_pivot.rotation_degrees = _BAT_REST

# Sweep the bat through the zone, then settle. Tap = quick compact cut; hold =
# a beat slower for a bigger arc. Pure presentation; guarded out in unit tests.
func _play_swing(swing_type: SwingCommand.SwingType) -> void:
	if _bat_pivot == null or not is_inside_tree():
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var swing_time := 0.10 if swing_type == SwingCommand.SwingType.CONTACT else 0.16
	_swing_tween = create_tween()
	_swing_tween.tween_property(_bat_pivot, "rotation_degrees", _BAT_SWING, swing_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_bat_pivot, "rotation_degrees", _BAT_REST, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
