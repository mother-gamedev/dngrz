class_name TestBallTrajectory extends GdUnitTestSuite

func test_pitch_starts_at_mound() -> void:
	var traj := BallTrajectory.create_pitch(
		PitchTypes.Type.FASTBALL,
		Vector3(0.0, 0.8, 0.0),  # target: center of zone at plate
		1.0                        # accuracy
	)
	var start := traj.get_position(0.0)
	# Release point is ~1.8m above the mound rubber; tolerance covers that offset.
	assert_float(start.distance_to(FieldConstants.MOUND)).is_less(2.0)

func test_pitch_reaches_plate() -> void:
	var traj := BallTrajectory.create_pitch(
		PitchTypes.Type.FASTBALL,
		Vector3(0.0, 0.8, 0.0),
		1.0
	)
	# Fastball at ~42 m/s over ~18m should take ~0.43s
	var at_plate := traj.get_position(traj.flight_duration)
	assert_float(at_plate.z).is_equal_approx(0.0, 1.0)

func test_fastball_arrives_faster_than_changeup() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0)
	var ch := BallTrajectory.create_pitch(PitchTypes.Type.CHANGEUP, Vector3(0.0, 0.8, 0.0), 1.0)
	assert_float(fb.flight_duration).is_less(ch.flight_duration)

func test_curveball_drops_more() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0)
	var cv := BallTrajectory.create_pitch(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.8, 0.0), 1.0)
	# At endpoint, curveball should arrive lower than fastball due to drop
	var fb_end := fb.get_position(fb.flight_duration)
	var cv_end := cv.get_position(cv.flight_duration)
	# Curveball must arrive strictly lower than the fastball at the plate
	assert_float(cv_end.y).is_less(fb_end.y)

func test_batted_ball_trajectory_goes_forward() -> void:
	var traj := BallTrajectory.create_batted(
		FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
		40.0,     # exit velocity m/s
		25.0,     # launch angle degrees
		0.0       # horizontal angle (center field)
	)
	var mid := traj.get_position(1.0)
	# Ball should move toward outfield (negative Z in our coordinate system)
	assert_float(mid.z).is_less(0.0)

func test_batted_ball_goes_up_then_down() -> void:
	var traj := BallTrajectory.create_batted(
		FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
		40.0, 30.0, 0.0
	)
	var mid := traj.get_position(1.0)
	# Peak is at t = vy/g ≈ 2.04s for 40m/s @ 30°; sample well past peak to confirm descent.
	var late := traj.get_position(3.5)
	assert_float(mid.y).is_greater(1.0)   # goes up
	assert_float(late.y).is_less(mid.y)    # comes down

func test_ground_ball_stays_low() -> void:
	var traj := BallTrajectory.create_batted(
		FieldConstants.HOME_PLATE + Vector3(0, 0.5, 0),
		30.0, -5.0, 10.0  # negative launch = grounder
	)
	var pos := traj.get_position(0.5)
	assert_float(pos.y).is_less(1.0)

func test_accuracy_below_one_introduces_spin_jitter() -> void:
	# When accuracy < 1.0, create_pitch should add random jitter to spin_break.
	# Run multiple trajectories at low accuracy and verify they differ from
	# the deterministic (accuracy=1.0) baseline at least once.
	var baseline := BallTrajectory.create_pitch(
		PitchTypes.Type.FASTBALL,
		Vector3(0.0, 0.8, 0.0),
		1.0
	)
	var any_differs := false
	for i in 20:
		var jittered := BallTrajectory.create_pitch(
			PitchTypes.Type.FASTBALL,
			Vector3(0.0, 0.8, 0.0),
			0.0  # max inaccuracy
		)
		if not jittered.spin_break.is_equal_approx(baseline.spin_break):
			any_differs = true
			break
	assert_bool(any_differs).is_true()
