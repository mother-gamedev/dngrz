class_name TestBatterAI extends GdUnitTestSuite

func _ai(skill := 0.7) -> BatterAI:
	var a: BatterAI = auto_free(BatterAI.new())
	a.skill = skill
	return a

func _rng(seed_value := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _observable(pos := Vector3(0.0, 0.8, 0.0), tick := 60) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, 40.0))

func test_takes_obvious_ball() -> void:
	# Way outside the zone → never swing.
	var cmd := _ai().compute_command(_observable(Vector3(1.0, 0.8, 0.0)), 60, 0, 0, _rng())
	assert_object(cmd).is_null()

func test_swings_at_in_zone_with_two_strikes() -> void:
	var cmd := _ai().compute_command(_observable(Vector3(0.0, 0.8, 0.0)), 60, 0, 2, _rng())
	assert_object(cmd).is_not_null()

func test_commit_tick_is_before_crossing() -> void:
	var cmd := _ai().compute_command(_observable(Vector3(0.0, 0.8, 0.0)), 60, 0, 2, _rng())
	assert_int(cmd.commit_tick).is_less(60)

func test_deterministic_for_same_seed() -> void:
	var a := _ai().compute_command(_observable(), 60, 0, 2, _rng(42))
	var b := _ai().compute_command(_observable(), 60, 0, 2, _rng(42))
	assert_vector(a.cursor_point).is_equal(b.cursor_point)
	assert_int(a.commit_tick).is_equal(b.commit_tick)
	assert_int(a.swing_type).is_equal(b.swing_type)

func test_cursor_tracks_normalized_observable() -> void:
	var ai := BatterAI.new()
	ai.skill = 1.0  # min noise
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Ball crossing at zone center -> cursor should be near (0,0) in normalized space.
	var obs := BallStateAtTick.new(120, Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.0, 40.0))
	# Force a swing with a 2-strike count and a clearly in-zone pitch.
	var cmd := ai.compute_command(obs, 120, 0, 2, rng)
	assert_object(cmd).is_not_null()
	# Normalized center is ~ (0,0); allow the high-skill noise band.
	assert_float(cmd.cursor_point.length()).is_less(0.15)
	# placement_dir is dead -> ZERO.
	assert_vector(cmd.placement_dir).is_equal(Vector2.ZERO)
