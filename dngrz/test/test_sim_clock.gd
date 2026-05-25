class_name TestSimClock extends GdUnitTestSuite

func test_tick_rate_is_sixty() -> void:
	assert_int(SimClock.TICK_RATE).is_equal(60)

func test_ticks_to_seconds() -> void:
	assert_float(SimClock.ticks_to_seconds(60)).is_equal_approx(1.0, 0.0001)
	assert_float(SimClock.ticks_to_seconds(6)).is_equal_approx(0.1, 0.0001)

func test_seconds_to_ticks_rounds_to_nearest() -> void:
	assert_int(SimClock.seconds_to_ticks(1.0)).is_equal(60)
	assert_int(SimClock.seconds_to_ticks(0.1)).is_equal(6)
	assert_int(SimClock.seconds_to_ticks(0.108)).is_equal(6)

func test_round_trip_is_stable() -> void:
	assert_float(SimClock.ticks_to_seconds(SimClock.seconds_to_ticks(0.5))).is_equal_approx(0.5, 0.01)
