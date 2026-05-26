class_name BatterInput

# Samples the gamepad into a SwingInput each tick. The MSSB realignment (Plan 3a)
# restores a CURSOR: the left stick DRAGS a normalized plate-space aim point
# (StrikeZone space, ±1 = zone edge), integrated per tick and clamped to a reach
# region slightly larger than the zone. `map` is pure (takes the previous cursor);
# `sample` is the thin Input-singleton wrapper that holds the live cursor.
const DEADZONE := 0.2
const CURSOR_SPEED := 0.04   # normalized units per tick (~2.4 zone-units/sec @ 60Hz)
const CURSOR_CLAMP := 2.0    # how far the cursor may roam (covers off-zone pitches)

var _cursor: Vector2 = Vector2.ZERO

# Pure mapping: integrate the plate-convention left stick (+y = up) into the cursor.
# placement_dir is dead (ZERO) — spray/launch derive from cursor position now.
static func map(left: Vector2, commit: bool, prev_cursor: Vector2) -> SwingInput:
	var move := left if left.length() >= DEADZONE else Vector2.ZERO
	var cursor := prev_cursor + move * CURSOR_SPEED
	# Box clamp = the cursor's ROAM region only. Contact reach (ContactResolver) is
	# measured cursor-to-BALL, not cursor-to-center, so this box shape is independent
	# of the catch geometry — keep it a simple per-axis clamp.
	cursor.x = clampf(cursor.x, -CURSOR_CLAMP, CURSOR_CLAMP)
	cursor.y = clampf(cursor.y, -CURSOR_CLAMP, CURSOR_CLAMP)
	return SwingInput.new(cursor, commit, Vector2.ZERO)

# Reads the live gamepad and advances the held cursor. Godot joypad Y is +down, so
# negate to the plate convention (+up).
func sample() -> SwingInput:
	var left := Vector2(_axis(JOY_AXIS_LEFT_X), -_axis(JOY_AXIS_LEFT_Y))
	var commit := Input.is_action_pressed("batter_swing")
	var si := map(left, commit, _cursor)
	_cursor = si.cursor
	return si

# Current live cursor (for the HUD bridge).
func current_cursor() -> Vector2:
	return _cursor

# Reset the cursor to center between at-bats. Called by AtBatDirector on IDLE.
func reset_cursor() -> void:
	_cursor = Vector2.ZERO

# The axis value from whichever connected joypad has the strongest signal (DualSense
# enumerates as two devices on Linux; device 0 may not carry the sticks).
static func _axis(axis: JoyAxis) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, axis)
		if absf(v) > absf(best):
			best = v
	return best
