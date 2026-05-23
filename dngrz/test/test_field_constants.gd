class_name TestFieldConstants extends GdUnitTestSuite

func test_bases_form_diamond() -> void:
	# Distance from home to first should equal baseline length
	var dist := FieldConstants.HOME_PLATE.distance_to(FieldConstants.FIRST_BASE)
	assert_float(dist).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.5)

func test_bases_are_equidistant() -> void:
	var h_to_1 := FieldConstants.HOME_PLATE.distance_to(FieldConstants.FIRST_BASE)
	var one_to_2 := FieldConstants.FIRST_BASE.distance_to(FieldConstants.SECOND_BASE)
	var two_to_3 := FieldConstants.SECOND_BASE.distance_to(FieldConstants.THIRD_BASE)
	var three_to_h := FieldConstants.THIRD_BASE.distance_to(FieldConstants.HOME_PLATE)
	assert_float(h_to_1).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.1)
	assert_float(one_to_2).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.1)
	assert_float(two_to_3).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.1)
	assert_float(three_to_h).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.1)

func test_mound_is_elevated() -> void:
	assert_float(FieldConstants.MOUND.y).is_greater(0.0)

func test_strike_zone_has_positive_dimensions() -> void:
	assert_float(FieldConstants.STRIKE_ZONE_WIDTH).is_greater(0.0)
	assert_float(FieldConstants.STRIKE_ZONE_TOP).is_greater(FieldConstants.STRIKE_ZONE_BOTTOM)

func test_all_fielder_positions_exist() -> void:
	assert_int(FieldConstants.FIELDER_POSITIONS.size()).is_equal(9)

func test_strike_zone_center_is_midpoint() -> void:
	var midpoint := (FieldConstants.STRIKE_ZONE_BOTTOM + FieldConstants.STRIKE_ZONE_TOP) / 2.0
	assert_float(FieldConstants.STRIKE_ZONE_CENTER.y).is_equal_approx(midpoint, 0.001)
	assert_float(FieldConstants.STRIKE_ZONE_CENTER.x).is_equal(0.0)
	assert_float(FieldConstants.STRIKE_ZONE_CENTER.z).is_equal(0.0)

func test_fielder_position_keys() -> void:
	var expected := ["pitcher", "catcher", "first_base", "second_base",
		"shortstop", "third_base", "left_field", "center_field", "right_field"]
	for key in expected:
		assert_bool(FieldConstants.FIELDER_POSITIONS.has(key)).is_true()
