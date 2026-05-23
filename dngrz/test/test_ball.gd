class_name TestBall extends GdUnitTestSuite

const BALL_SCENE := preload("res://scenes/ball.tscn")

func test_starts_inactive() -> void:
	var ball := BALL_SCENE.instantiate()
	assert_bool(ball.is_active()).is_false()
	ball.queue_free()

func test_throw_pitch_activates() -> void:
	var ball := BALL_SCENE.instantiate()
	add_child(ball)
	await get_tree().process_frame
	ball.throw_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0)
	assert_bool(ball.is_active()).is_true()
	assert_bool(ball.visible).is_true()
	ball.queue_free()

func test_launch_batted_activates() -> void:
	var ball := BALL_SCENE.instantiate()
	add_child(ball)
	await get_tree().process_frame
	ball.launch_batted(Vector3(0, 1, 0), 40.0, 25.0, 0.0)
	assert_bool(ball.is_active()).is_true()
	ball.queue_free()

func test_reset_deactivates() -> void:
	var ball := BALL_SCENE.instantiate()
	add_child(ball)
	await get_tree().process_frame
	ball.throw_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0)
	ball.reset()
	assert_bool(ball.is_active()).is_false()
	assert_bool(ball.visible).is_false()
	ball.queue_free()

func test_pitch_arrived_signal_fires() -> void:
	var ball := BALL_SCENE.instantiate()
	add_child(ball)
	await get_tree().process_frame
	var fired := [false]
	ball.pitch_arrived.connect(func(_p: Vector3) -> void: fired[0] = true)
	ball.throw_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0)
	# Fastball flight is ~0.43s; simulate enough frames via _process calls.
	for i in 60:
		ball._process(0.016)  # ~16ms per simulated frame
		if not ball.is_active():
			break
	assert_bool(fired[0]).is_true()
	assert_bool(ball.is_active()).is_false()
	ball.queue_free()
