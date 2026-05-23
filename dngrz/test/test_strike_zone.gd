class_name TestStrikeZone extends GdUnitTestSuite

func test_center_pitch_is_strike() -> void:
	var center := Vector3(0.0, 0.8, 0.0)
	assert_bool(StrikeZone.is_strike(center)).is_true()

func test_pitch_above_zone_is_ball() -> void:
	var high := Vector3(0.0, 1.5, 0.0)
	assert_bool(StrikeZone.is_strike(high)).is_false()

func test_pitch_below_zone_is_ball() -> void:
	var low := Vector3(0.0, 0.2, 0.0)
	assert_bool(StrikeZone.is_strike(low)).is_false()

func test_pitch_outside_is_ball() -> void:
	var outside := Vector3(0.5, 0.8, 0.0)
	assert_bool(StrikeZone.is_strike(outside)).is_false()

func test_pitch_inside_is_ball() -> void:
	var inside := Vector3(-0.5, 0.8, 0.0)
	assert_bool(StrikeZone.is_strike(inside)).is_false()

func test_corner_pitch_is_strike() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var corner := Vector3(half_w - 0.01, FieldConstants.STRIKE_ZONE_TOP - 0.01, 0.0)
	assert_bool(StrikeZone.is_strike(corner)).is_true()

func test_just_outside_corner_is_ball() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var just_out := Vector3(half_w + 0.02, FieldConstants.STRIKE_ZONE_TOP + 0.02, 0.0)
	assert_bool(StrikeZone.is_strike(just_out)).is_false()

func test_plate_position_returns_normalized() -> void:
	# Center of zone should return (0, 0)
	var center := Vector3(0.0, 0.8, 0.0)
	var normalized := StrikeZone.get_plate_position(center)
	assert_float(normalized.x).is_equal_approx(0.0, 0.1)
	assert_float(normalized.y).is_equal_approx(0.0, 0.1)

func test_exact_top_edge_is_strike() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var edge := Vector3(half_w, FieldConstants.STRIKE_ZONE_TOP, 0.0)
	assert_bool(StrikeZone.is_strike(edge)).is_true()

func test_exact_bottom_edge_is_strike() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var edge := Vector3(-half_w, FieldConstants.STRIKE_ZONE_BOTTOM, 0.0)
	assert_bool(StrikeZone.is_strike(edge)).is_true()

func test_plate_position_at_top_right_edge_is_one_one() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var edge := Vector3(half_w, FieldConstants.STRIKE_ZONE_TOP, 0.0)
	var normalized := StrikeZone.get_plate_position(edge)
	assert_float(normalized.x).is_equal_approx(1.0, 0.001)
	assert_float(normalized.y).is_equal_approx(1.0, 0.001)

func test_plate_position_at_bottom_left_edge_is_negative_one() -> void:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var edge := Vector3(-half_w, FieldConstants.STRIKE_ZONE_BOTTOM, 0.0)
	var normalized := StrikeZone.get_plate_position(edge)
	assert_float(normalized.x).is_equal_approx(-1.0, 0.001)
	assert_float(normalized.y).is_equal_approx(-1.0, 0.001)

func test_well_outside_top_with_epsilon_still_ball() -> void:
	# Guard that the epsilon doesn't silently widen the zone in a perceptible way.
	# A pitch 1cm above the top must still be a ball.
	var above := Vector3(0.0, FieldConstants.STRIKE_ZONE_TOP + 0.01, 0.0)
	assert_bool(StrikeZone.is_strike(above)).is_false()
