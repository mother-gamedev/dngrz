class_name TestDeterministicCore extends GdUnitTestSuite

# Same seed + same commands => identical contact result, proving the core is a
# pure function of (commands + seed + tick) (spec §9 contract #2). This is the
# property that makes the future authoritative-server netcode an additive layer
# rather than a rewrite.
func _resolve_once(seed_value: int) -> ContactResolver.ContactResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0.1, 0.8, 0.0), 0.6, rng)
	var crossing := traj.predict_crossing(0.0)
	var crossing_tick := SimClock.seconds_to_ticks(crossing.time)
	var ball_at_contact := BallStateAtTick.new(crossing_tick, crossing.position, traj.get_velocity(crossing.time))
	# A batter who reads it perfectly: cursor on the predicted crossing, on-tick.
	var plate := StrikeZone.get_plate_position(crossing.position)
	var swing := SwingCommand.new(plate, SwingCommand.SwingType.POWER, Vector2.ZERO, crossing_tick)
	return ContactResolver.resolve(swing, ball_at_contact)

func test_same_seed_same_result() -> void:
	var a := _resolve_once(12345)
	var b := _resolve_once(12345)
	assert_bool(a.is_whiff).is_equal(b.is_whiff)
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
	assert_float(a.h_angle).is_equal(b.h_angle)

func test_pipeline_produces_contact_for_a_perfect_read() -> void:
	var r := _resolve_once(12345)
	assert_bool(r.is_whiff).is_false()
	assert_float(r.exit_velocity).is_greater(0.0)
