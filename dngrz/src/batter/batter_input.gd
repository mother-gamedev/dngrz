class_name BatterInput

# Samples the gamepad into a SwingInput each tick. One-stick is the DEFAULT: the
# left stick aims the cursor AND supplies the at-commit placement direction.
# Two-stick toggle uses the right stick for placement. `map` is pure (testable);
# `sample` is the thin Input-singleton wrapper. This is the ONLY place the FSM's
# input touches Input.
const DEADZONE := 0.2
const CURSOR_RANGE := 0.5    # plate-plane half-extent
const CURSOR_STEP := 0.03    # cursor movement per tick at full stick

var two_stick: bool = false

# Pure mapping from plate-convention stick vectors (+y = up) to a SwingInput.
static func map(left: Vector2, right: Vector2, commit: bool, prev_cursor: Vector2, two_stick_mode: bool) -> SwingInput:
	var move := left if left.length() >= DEADZONE else Vector2.ZERO
	var cursor := prev_cursor + move * CURSOR_STEP
	cursor.x = clampf(cursor.x, -CURSOR_RANGE, CURSOR_RANGE)
	cursor.y = clampf(cursor.y, -CURSOR_RANGE, CURSOR_RANGE)
	var raw_placement := right if two_stick_mode else left
	var placement := raw_placement if raw_placement.length() >= DEADZONE else Vector2.ZERO
	return SwingInput.new(cursor, commit, placement)

# Reads the live gamepad. Godot joypad Y axes are +down, so negate to the plate
# convention (+up). Swing on the `batter_swing` action. We read across ALL
# connected joypads rather than a hardcoded device 0: the DualSense on Linux
# enumerates as two devices (gamepad + motion sensors), so device 0 may not be
# the stick-bearing one.
func sample(prev_cursor: Vector2) -> SwingInput:
	var left := Vector2(_axis(JOY_AXIS_LEFT_X), -_axis(JOY_AXIS_LEFT_Y))
	var right := Vector2(_axis(JOY_AXIS_RIGHT_X), -_axis(JOY_AXIS_RIGHT_Y))
	var commit := Input.is_action_pressed("batter_swing")
	return map(left, right, commit, prev_cursor, two_stick)

# The axis value from whichever connected joypad has the strongest signal — so a
# multi-device controller (e.g. DualSense gamepad + motion-sensor sub-device) is
# read from the device that actually carries the sticks, regardless of index.
static func _axis(axis: JoyAxis) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, axis)
		if absf(v) > absf(best):
			best = v
	return best
