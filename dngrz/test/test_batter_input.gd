class_name TestBatterInput extends GdUnitTestSuite

func test_stick_integrates_cursor_from_previous() -> void:
	var si := BatterInput.map(Vector2(1.0, 0.0), false, Vector2.ZERO)
	assert_float(si.cursor.x).is_equal_approx(BatterInput.CURSOR_SPEED, 0.0001)
	assert_float(si.cursor.y).is_equal_approx(0.0, 0.0001)

func test_deadzone_holds_cursor_still() -> void:
	var prev := Vector2(0.3, -0.2)
	var si := BatterInput.map(Vector2(0.1, 0.1), false, prev)  # below DEADZONE
	assert_vector(si.cursor).is_equal(prev)

func test_cursor_clamped_to_reach_region() -> void:
	var si := BatterInput.map(Vector2(1.0, 0.0), false, Vector2(BatterInput.CURSOR_CLAMP, 0.0))
	assert_float(si.cursor.x).is_equal_approx(BatterInput.CURSOR_CLAMP, 0.0001)

func test_commit_flag_passthrough() -> void:
	var si := BatterInput.map(Vector2.ZERO, true, Vector2.ZERO)
	assert_bool(si.commit_pressed).is_true()

func test_cursor_clamped_negative_axis() -> void:
	var si := BatterInput.map(Vector2(-1.0, 0.0), false, Vector2(-BatterInput.CURSOR_CLAMP, 0.0))
	assert_float(si.cursor.x).is_equal_approx(-BatterInput.CURSOR_CLAMP, 0.0001)

func test_cursor_clamped_y_axis() -> void:
	var si := BatterInput.map(Vector2(0.0, 1.0), false, Vector2(0.0, BatterInput.CURSOR_CLAMP))
	assert_float(si.cursor.y).is_equal_approx(BatterInput.CURSOR_CLAMP, 0.0001)
