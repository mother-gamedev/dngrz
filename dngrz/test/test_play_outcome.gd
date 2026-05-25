class_name TestPlayOutcome extends GdUnitTestSuite

func test_defaults_to_not_out() -> void:
	var p := PlayOutcome.new()
	assert_bool(p.is_out).is_false()

func test_stores_geometry() -> void:
	var p := PlayOutcome.new(true, Vector3(10, 0, -30), "shortstop", 1.5)
	assert_bool(p.is_out).is_true()
	assert_vector(p.landing_point).is_equal(Vector3(10, 0, -30))
	assert_str(p.nearest_fielder).is_equal("shortstop")
	assert_float(p.reach_margin).is_equal_approx(1.5, 0.0001)
