class_name TestBatterController extends GdUnitTestSuite

const BATTER_SCENE := preload("res://scenes/batter.tscn")

func test_batter_loads() -> void:
	var batter := BATTER_SCENE.instantiate()
	assert_object(batter).is_not_null()
	batter.queue_free()

func test_default_cursor_is_zero() -> void:
	var batter := BATTER_SCENE.instantiate()
	add_child(batter)
	await get_tree().process_frame
	var cursor: Vector2 = batter.get_cursor_position()
	assert_float(cursor.x).is_equal_approx(0.0, 0.001)
	assert_float(cursor.y).is_equal_approx(0.0, 0.001)
	batter.queue_free()

func test_start_at_bat_arms() -> void:
	var batter := BATTER_SCENE.instantiate()
	add_child(batter)
	await get_tree().process_frame
	batter.start_at_bat(0.4)
	assert_bool(batter.is_armed()).is_true()
	batter.queue_free()

func test_pitch_arrived_disarms_and_emits_took_pitch() -> void:
	var batter := BATTER_SCENE.instantiate()
	add_child(batter)
	await get_tree().process_frame
	batter.start_at_bat(0.4)
	var took := [false]
	batter.took_pitch.connect(func(): took[0] = true)
	batter.pitch_arrived(Vector3(0, 0.8, 0))
	assert_bool(batter.is_armed()).is_false()
	assert_bool(took[0]).is_true()
	batter.queue_free()

func test_request_swing_emits_signal() -> void:
	var batter := BATTER_SCENE.instantiate()
	add_child(batter)
	await get_tree().process_frame
	batter.start_at_bat(0.4)
	var fired := [false]
	var got_timing := [9.9]
	var got_placement := [Vector2.ZERO]
	batter.swing_executed.connect(func(t, p):
		fired[0] = true
		got_timing[0] = t
		got_placement[0] = p
	)
	batter.request_swing(0.05, Vector2(0.1, -0.05))
	assert_bool(fired[0]).is_true()
	assert_float(got_timing[0]).is_equal_approx(0.05, 0.001)
	assert_float(got_placement[0].x).is_equal_approx(0.1, 0.001)
	batter.queue_free()
