class_name TestBatterInput extends GdUnitTestSuite

# Timing-first redesign (2026-05-25): no aim cursor. The left stick is a
# directional bias latched at commit; map() is left-stick + commit only.

func test_placement_is_left_stick() -> void:
	var s := BatterInput.map(Vector2(-0.8, 0.0), false)
	assert_vector(s.placement_dir).is_equal(Vector2(-0.8, 0.0))

func test_deadzone_zeros_small_input() -> void:
	var s := BatterInput.map(Vector2(0.1, 0.1), false)
	assert_vector(s.placement_dir).is_equal(Vector2.ZERO)

func test_commit_passthrough() -> void:
	var s := BatterInput.map(Vector2.ZERO, true)
	assert_bool(s.commit_pressed).is_true()

func test_cursor_is_always_neutral() -> void:
	# The cursor is gone: SwingInput.cursor is vestigial and never driven.
	var s := BatterInput.map(Vector2(1.0, -1.0), true)
	assert_vector(s.cursor).is_equal(Vector2.ZERO)
