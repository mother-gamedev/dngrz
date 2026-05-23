class_name TestCountTracker extends GdUnitTestSuite

var _tracker: CountTracker

func before_test() -> void:
	_tracker = CountTracker.new()

func test_starts_at_zero() -> void:
	assert_int(_tracker.balls).is_equal(0)
	assert_int(_tracker.strikes).is_equal(0)
	assert_int(_tracker.outs).is_equal(0)

func test_ball_increments() -> void:
	_tracker.add_ball()
	assert_int(_tracker.balls).is_equal(1)

func test_four_balls_is_walk() -> void:
	for i in 4:
		_tracker.add_ball()
	assert_bool(_tracker.is_walk()).is_true()

func test_strike_increments() -> void:
	_tracker.add_strike()
	assert_int(_tracker.strikes).is_equal(1)

func test_three_strikes_is_strikeout() -> void:
	for i in 3:
		_tracker.add_strike()
	assert_bool(_tracker.is_strikeout()).is_true()

func test_strikeout_adds_out() -> void:
	for i in 3:
		_tracker.add_strike()
	assert_int(_tracker.outs).is_equal(1)

func test_foul_with_two_strikes_stays_at_two() -> void:
	_tracker.add_strike()
	_tracker.add_strike()
	_tracker.add_foul()
	assert_int(_tracker.strikes).is_equal(2)

func test_foul_with_less_than_two_strikes_adds_strike() -> void:
	_tracker.add_foul()
	assert_int(_tracker.strikes).is_equal(1)

func test_new_batter_resets_count() -> void:
	_tracker.add_ball()
	_tracker.add_strike()
	_tracker.new_batter()
	assert_int(_tracker.balls).is_equal(0)
	assert_int(_tracker.strikes).is_equal(0)

func test_new_batter_preserves_outs() -> void:
	_tracker.add_out()
	_tracker.new_batter()
	assert_int(_tracker.outs).is_equal(1)

func test_three_outs_is_side_retired() -> void:
	for i in 3:
		_tracker.add_out()
	assert_bool(_tracker.is_side_retired()).is_true()

func test_new_half_inning_resets_outs() -> void:
	_tracker.add_out()
	_tracker.add_out()
	_tracker.new_half_inning()
	assert_int(_tracker.outs).is_equal(0)
	assert_int(_tracker.balls).is_equal(0)
	assert_int(_tracker.strikes).is_equal(0)

func test_walk_signal_emits_on_fourth_ball() -> void:
	var monitor := monitor_signals(_tracker)
	for i in 4:
		_tracker.add_ball()
	await assert_signal(monitor).is_emitted("walk")

func test_strikeout_signal_emits_on_third_strike() -> void:
	var monitor := monitor_signals(_tracker)
	for i in 3:
		_tracker.add_strike()
	await assert_signal(monitor).is_emitted("strikeout")

func test_out_recorded_emits_per_out() -> void:
	var monitor := monitor_signals(_tracker)
	_tracker.add_out()
	_tracker.add_out()
	await assert_signal(monitor).is_emitted("out_recorded")

func test_side_retired_emits_on_third_out() -> void:
	var monitor := monitor_signals(_tracker)
	for i in 3:
		_tracker.add_out()
	await assert_signal(monitor).is_emitted("side_retired")

func test_no_walk_signal_on_third_ball() -> void:
	var monitor := monitor_signals(_tracker)
	for i in 3:
		_tracker.add_ball()
	await assert_signal(monitor).is_not_emitted("walk")
