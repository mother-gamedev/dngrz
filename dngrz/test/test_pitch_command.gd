class_name TestPitchCommand extends GdUnitTestSuite

func test_defaults() -> void:
	var c := PitchCommand.new()
	assert_int(c.type).is_equal(PitchTypes.Type.FASTBALL)
	assert_int(c.tier).is_equal(PitchTypes.Tier.BASIC)
	assert_float(c.power).is_equal_approx(1.0, 0.0001)
	assert_int(c.start_tick).is_equal(0)

func test_stores_fields() -> void:
	var c := PitchCommand.new(PitchTypes.Type.SLIDER, Vector3(0.1, 0.6, 0.0), 0.8, 0.75,
		Vector2(0.2, -0.1), PitchTypes.Tier.BASIC, 4242, 30)
	assert_int(c.type).is_equal(PitchTypes.Type.SLIDER)
	assert_int(c.rng_seed).is_equal(4242)
	assert_int(c.start_tick).is_equal(30)
	assert_vector(c.bend).is_equal(Vector2(0.2, -0.1))

func test_round_trips_through_dict() -> void:
	var c := PitchCommand.new(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.7, 0.0), 0.9, 0.7,
		Vector2(0.1, 0.0), PitchTypes.Tier.PHENOM, 99, 12)
	var r := PitchCommand.from_dict(c.to_dict())
	assert_int(r.type).is_equal(PitchTypes.Type.CURVEBALL)
	assert_float(r.power).is_equal_approx(0.9, 0.0001)
	assert_float(r.accuracy).is_equal_approx(0.7, 0.0001)
	assert_int(r.tier).is_equal(PitchTypes.Tier.PHENOM)
	assert_int(r.rng_seed).is_equal(99)
	assert_int(r.start_tick).is_equal(12)
	assert_vector(r.target).is_equal(Vector3(0.0, 0.7, 0.0))
