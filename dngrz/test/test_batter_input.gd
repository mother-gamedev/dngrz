class_name TestBatterInput extends GdUnitTestSuite

func test_one_stick_placement_is_left_stick() -> void:
	var bi := BatterInput.new()  # two_stick defaults false
	var s := BatterInput.map(Vector2(-0.8, 0.0), Vector2(0.9, 0.9), false, Vector2.ZERO, false)
	assert_vector(s.placement_dir).is_equal(Vector2(-0.8, 0.0))  # left stick, ignores right

func test_two_stick_placement_is_right_stick() -> void:
	var s := BatterInput.map(Vector2(-0.8, 0.0), Vector2(0.9, -0.3), false, Vector2.ZERO, true)
	assert_vector(s.placement_dir).is_equal(Vector2(0.9, -0.3))

func test_deadzone_zeros_small_input() -> void:
	var s := BatterInput.map(Vector2(0.1, 0.1), Vector2.ZERO, false, Vector2.ZERO, false)
	assert_vector(s.placement_dir).is_equal(Vector2.ZERO)

func test_cursor_moves_and_clamps() -> void:
	# Large left stick over one step nudges the cursor and stays within range.
	var s := BatterInput.map(Vector2(1.0, 0.0), Vector2.ZERO, false, Vector2(0.49, 0.0), false)
	assert_float(s.cursor.x).is_between(0.49, 0.5)  # moved right but clamped at 0.5

func test_commit_passthrough() -> void:
	var s := BatterInput.map(Vector2.ZERO, Vector2.ZERO, true, Vector2.ZERO, false)
	assert_bool(s.commit_pressed).is_true()
