class_name TestBallTrajectory extends GdUnitTestSuite

# A seeded RNG so trajectory tests are deterministic. create_pitch now requires
# an explicit RNG (determinism contract #5).
func _seeded_rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_pitch_starts_at_mound() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var start := traj.get_position(0.0)
	assert_float(start.distance_to(FieldConstants.MOUND)).is_less(2.0)

func test_pitch_reaches_plate() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var at_plate := traj.get_position(traj.flight_duration)
	assert_float(at_plate.z).is_equal_approx(0.0, 1.0)

func test_pitch_flight_is_playable() -> void:
	# Raw MLB physics puts a fastball at the plate in ~0.44s — unhittable. Flight
	# must be slowed into a readable swing window. Guards against regression.
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	assert_float(fb.flight_duration).is_greater(0.8)
	assert_float(fb.flight_duration).is_less(2.0)

func test_fastball_arrives_faster_than_changeup() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var ch := BallTrajectory.create_pitch(PitchTypes.Type.CHANGEUP, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	assert_float(fb.flight_duration).is_less(ch.flight_duration)

func test_curveball_drops_more() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var cv := BallTrajectory.create_pitch(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var fb_end := fb.get_position(fb.flight_duration)
	var cv_end := cv.get_position(cv.flight_duration)
	assert_float(cv_end.y).is_less(fb_end.y)

func test_batted_ball_trajectory_goes_forward() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0), 40.0, 25.0, 0.0)
	var mid := traj.get_position(1.0)
	assert_float(mid.z).is_less(0.0)

func test_batted_ball_goes_up_then_down() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0), 40.0, 30.0, 0.0)
	var mid := traj.get_position(1.0)
	var late := traj.get_position(3.5)
	assert_float(mid.y).is_greater(1.0)
	assert_float(late.y).is_less(mid.y)

func test_ground_ball_stays_low() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 0.5, 0), 30.0, -5.0, 10.0)
	var pos := traj.get_position(0.5)
	assert_float(pos.y).is_less(1.0)

# --- Seeded RNG determinism (contract #5) ---

func test_accuracy_one_is_deterministic_regardless_of_seed() -> void:
	# At accuracy 1.0 there is zero inaccuracy jitter, so the seed is irrelevant.
	var a := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(1))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(999))
	assert_vector(a.spin_break).is_equal(b.spin_break)

func test_same_seed_reproduces_trajectory() -> void:
	var a := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(7))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(7))
	assert_vector(a.spin_break).is_equal(b.spin_break)

func test_different_seeds_diverge_at_low_accuracy() -> void:
	var a := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(1))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(2))
	assert_bool(a.spin_break.is_equal_approx(b.spin_break)).is_false()

func test_predict_crossing_reaches_plate_plane() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(c.position.z).is_equal_approx(0.0, 0.01)

func test_predict_crossing_time_matches_flight_duration() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(c.time).is_equal_approx(traj.flight_duration, 0.05)

func test_predict_crossing_includes_break() -> void:
	# Slider sweeps glove-side, so the crossing x is pulled off the authored
	# target x (0.0) by the spin break — proving the query reflects movement.
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(absf(c.position.x)).is_greater(0.05)
