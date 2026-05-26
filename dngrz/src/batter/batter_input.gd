class_name BatterInput

# Samples the gamepad into a SwingInput each tick. The 2026-05-25 timing-first
# redesign removed the free aim cursor: the left stick is now a directional BIAS
# (x = spray, y = trajectory) that the FSM latches at the commit instant — not a
# point you chase. Deadzone collapses to neutral (up-the-middle). `map` is pure
# (testable); `sample` is the thin Input-singleton wrapper, the ONLY place the
# FSM's input touches Input.
const DEADZONE := 0.2

# Pure mapping from the plate-convention left stick (+y = up) to a SwingInput.
# cursor_point is dead (kept ZERO) — see SwingCommand.cursor_point.
static func map(left: Vector2, commit: bool) -> SwingInput:
	var placement := left if left.length() >= DEADZONE else Vector2.ZERO
	return SwingInput.new(Vector2.ZERO, commit, placement)

# Reads the live gamepad. Godot joypad Y axes are +down, so negate to the plate
# convention (+up). Swing on the `batter_swing` action. We read across ALL
# connected joypads rather than a hardcoded device 0: the DualSense on Linux
# enumerates as two devices (gamepad + motion sensors), so device 0 may not be
# the stick-bearing one.
func sample() -> SwingInput:
	var left := Vector2(_axis(JOY_AXIS_LEFT_X), -_axis(JOY_AXIS_LEFT_Y))
	var commit := Input.is_action_pressed("batter_swing")
	return map(left, commit)

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
