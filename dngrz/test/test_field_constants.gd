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
	assert_float(h_to_1).is_equal_approx(one_to_2, 0.5)
	assert_float(one_to_2).is_equal_approx(two_to_3, 0.5)
	assert_float(two_to_3).is_equal_approx(three_to_h, 0.5)

func test_mound_is_elevated() -> void:
	assert_float(FieldConstants.MOUND.y).is_greater(0.0)

func test_strike_zone_has_positive_dimensions() -> void:
	assert_float(FieldConstants.STRIKE_ZONE_WIDTH).is_greater(0.0)
	assert_float(FieldConstants.STRIKE_ZONE_TOP).is_greater(FieldConstants.STRIKE_ZONE_BOTTOM)

func test_all_fielder_positions_exist() -> void:
	assert_int(FieldConstants.FIELDER_POSITIONS.size()).is_equal(9)
