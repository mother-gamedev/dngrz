class_name TestBatterController extends GdUnitTestSuite

const CROSS := 60

func _ctrl() -> BatterController:
	return auto_free(BatterController.new())

func _in(cursor := Vector2(0.1, 0.8), commit := false, placement := Vector2.ZERO) -> SwingInput:
	return SwingInput.new(cursor, commit, placement)

func test_tap_commits_contact_with_latched_values() -> void:
	var c := _ctrl()
	c.arm(CROSS)
	# tick 10: button down with cursor + placement → latch
	assert_object(c.step(_in(Vector2(0.1, 0.8), true, Vector2(-1.0, 0.0)), 10)).is_null()
	# tick 12: released after 2 ticks (< 6) → CONTACT, latched at tick 10
	var cmd: SwingCommand = c.step(_in(Vector2(0.3, 0.2), false, Vector2(1.0, 1.0)), 12)
	assert_object(cmd).is_not_null()
	assert_int(cmd.swing_type).is_equal(SwingCommand.SwingType.CONTACT)
	assert_int(cmd.commit_tick).is_equal(10)
	assert_vector(cmd.cursor_point).is_equal(Vector2(0.1, 0.8))    # latched at down, not the tick-12 cursor
	assert_vector(cmd.placement_dir).is_equal(Vector2(-1.0, 0.0))  # latched at down

func test_hold_commits_power() -> void:
	var c := _ctrl()
	c.arm(CROSS)
	c.step(_in(Vector2.ZERO, true), 10)
	for t in range(11, 18):
		c.step(_in(Vector2.ZERO, true), t)  # holding
	var cmd: SwingCommand = c.step(_in(Vector2.ZERO, false), 18)  # released after 8 ticks
	assert_object(cmd).is_not_null()
	assert_int(cmd.swing_type).is_equal(SwingCommand.SwingType.POWER)

func test_hold_past_crossing_auto_commits_power() -> void:
	var c := _ctrl()
	c.arm(CROSS)
	c.step(_in(Vector2.ZERO, true), 50)  # down, never released
	var cmd: SwingCommand = null
	for t in range(51, CROSS + 1):
		var r: SwingCommand = c.step(_in(Vector2.ZERO, true), t)
		if r != null:
			cmd = r
	assert_object(cmd).is_not_null()
	assert_int(cmd.swing_type).is_equal(SwingCommand.SwingType.POWER)
	assert_int(cmd.commit_tick).is_equal(50)

func test_never_pressed_is_taken() -> void:
	var c := _ctrl()
	c.arm(CROSS)
	for t in range(1, CROSS + 1):
		assert_object(c.step(_in(Vector2.ZERO, false), t)).is_null()
	assert_bool(c.is_taken()).is_true()
