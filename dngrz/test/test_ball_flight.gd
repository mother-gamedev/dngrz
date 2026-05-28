class_name TestBallFlight extends GdUnitTestSuite

func _pitch(seed_value := 7, start_tick := 100) -> PitchCommand:
	return PitchCommand.new(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0),
		1.0, 1.0, Vector2.ZERO, PitchTypes.Tier.BASIC, seed_value, start_tick)

func test_from_pitch_builds_flight() -> void:
	var f := BallFlight.from_pitch(_pitch())
	assert_object(f.trajectory).is_not_null()
	assert_int(f.start_tick).is_equal(100)

func test_crossing_tick_is_after_start() -> void:
	var f := BallFlight.from_pitch(_pitch(7, 100))
	assert_int(f.crossing_tick()).is_greater(100)

func test_state_at_start_tick_is_at_release() -> void:
	var f := BallFlight.from_pitch(_pitch(7, 100))
	var s := f.state_at_tick(100)
	assert_int(s.tick).is_equal(100)
	# Release point is near the mound (z strongly negative), not the plate.
	assert_float(s.position.z).is_less(-10.0)

func test_state_at_crossing_reaches_plate() -> void:
	var f := BallFlight.from_pitch(_pitch(7, 100))
	var s := f.state_at_tick(f.crossing_tick())
	assert_float(s.position.z).is_equal_approx(0.0, 0.1)

func test_same_seed_is_deterministic() -> void:
	var a := BallFlight.from_pitch(_pitch(12345, 0))
	var b := BallFlight.from_pitch(_pitch(12345, 0))
	assert_int(a.crossing_tick()).is_equal(b.crossing_tick())
	var sa := a.state_at_tick(a.crossing_tick())
	var sb := b.state_at_tick(b.crossing_tick())
	assert_vector(sa.position).is_equal(sb.position)

func _bent_pitch(bend: Vector2, seed_value := 7, start_tick := 100) -> PitchCommand:
	return PitchCommand.new(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0),
		1.0, 1.0, bend, PitchTypes.Tier.BASIC, seed_value, start_tick)

func test_bend_keeps_crossing_tick_identical() -> void:
	# The crossing tick is solved on z; bend has no z, so it must not move (spec §4.3).
	var straight := BallFlight.from_pitch(_bent_pitch(Vector2.ZERO))
	var bent := BallFlight.from_pitch(_bent_pitch(Vector2(0.4, -0.2)))
	assert_int(bent.crossing_tick()).is_equal(straight.crossing_tick())

func test_bend_moves_crossing_position() -> void:
	var straight := BallFlight.from_pitch(_bent_pitch(Vector2.ZERO))
	var bent := BallFlight.from_pitch(_bent_pitch(Vector2(0.4, 0.0)))
	var ct := straight.crossing_tick()
	var sx := straight.state_at_tick(ct).position.x
	var bx := bent.state_at_tick(ct).position.x
	assert_float(bx).is_greater(sx + 0.1)
