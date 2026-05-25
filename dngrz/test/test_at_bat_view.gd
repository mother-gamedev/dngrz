class_name TestAtBatView extends GdUnitTestSuite

func test_defaults() -> void:
	var v := AtBatView.new()
	assert_object(v.ball_state).is_null()
	assert_object(v.last_play).is_null()
	assert_bool(v.swing_locked).is_false()

func test_stores_fields() -> void:
	var v := AtBatView.new()
	v.ball_state = BallStateAtTick.new(5, Vector3(0, 0.8, -1), Vector3.ZERO)
	v.break_marker = Vector2(-1.0, -0.3)
	v.observable_landing = Vector2(0.2, 0.1)
	v.swing_locked = true
	assert_int(v.ball_state.tick).is_equal(5)
	assert_vector(v.break_marker).is_equal(Vector2(-1.0, -0.3))
	assert_bool(v.swing_locked).is_true()
