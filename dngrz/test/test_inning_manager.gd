class_name TestInningManager extends GdUnitTestSuite

var _manager: InningManager

func before_test() -> void:
	_manager = InningManager.new()

func test_starts_at_top_of_first() -> void:
	assert_int(_manager.inning).is_equal(1)
	assert_bool(_manager.is_top).is_true()

func test_score_starts_at_zero() -> void:
	assert_int(_manager.home_score).is_equal(0)
	assert_int(_manager.away_score).is_equal(0)

func test_advance_half_goes_to_bottom() -> void:
	_manager.advance_half_inning()
	assert_int(_manager.inning).is_equal(1)
	assert_bool(_manager.is_top).is_false()

func test_advance_two_halves_goes_to_next_inning() -> void:
	_manager.advance_half_inning()
	_manager.advance_half_inning()
	assert_int(_manager.inning).is_equal(2)
	assert_bool(_manager.is_top).is_true()

func test_add_run_away_in_top() -> void:
	_manager.add_run()
	assert_int(_manager.away_score).is_equal(1)
	assert_int(_manager.home_score).is_equal(0)

func test_add_run_home_in_bottom() -> void:
	_manager.advance_half_inning()  # bottom of 1st
	_manager.add_run()
	assert_int(_manager.home_score).is_equal(1)
	assert_int(_manager.away_score).is_equal(0)

func test_game_not_over_before_five_innings() -> void:
	# Play through 4 full innings
	for i in 8:
		_manager.advance_half_inning()
	assert_bool(_manager.is_game_over()).is_false()

func test_game_over_after_five_full_innings() -> void:
	# Play through 5 full innings (10 half-innings)
	for i in 10:
		_manager.advance_half_inning()
	assert_bool(_manager.is_game_over()).is_true()

func test_batting_team_away_in_top() -> void:
	assert_str(_manager.batting_team()).is_equal("away")

func test_batting_team_home_in_bottom() -> void:
	_manager.advance_half_inning()
	assert_str(_manager.batting_team()).is_equal("home")

func test_game_over_walk_off_bottom_of_fifth() -> void:
	# Go to bottom of 5th with home trailing
	for i in 9:  # top1 bot1 top2 bot2 top3 bot3 top4 bot4 top5
		_manager.advance_half_inning()
	# Now in bottom of 5th. Add a run for home to tie then walk off
	_manager.away_score = 1
	_manager.add_run()  # home ties at 1
	_manager.add_run()  # home leads 2-1
	assert_bool(_manager.is_game_over()).is_true()

func test_tied_game_in_bottom_of_fifth_is_not_over() -> void:
	# Top 1 → ... → Bot 5
	for i in 9:
		_manager.advance_half_inning()
	_manager.away_score = 1
	_manager.add_run()  # home ties at 1
	assert_bool(_manager.is_game_over()).is_false()

func test_tied_game_advances_to_terminate() -> void:
	# Same setup as above, then advance to inning 6 (game over by inning-limit)
	for i in 9:
		_manager.advance_half_inning()
	_manager.away_score = 1
	_manager.add_run()
	_manager.advance_half_inning()  # now top of 6
	assert_bool(_manager.is_game_over()).is_true()

func test_game_over_signal_emits_on_walk_off() -> void:
	var monitor := monitor_signals(_manager)
	# Walk to bot 5
	for i in 9:
		_manager.advance_half_inning()
	_manager.away_score = 1
	_manager.add_run()  # 1-1
	_manager.add_run()  # 2-1 home — walk-off
	await assert_signal(monitor).is_emitted("game_over_signal")

func test_game_over_signal_emits_on_natural_end() -> void:
	var monitor := monitor_signals(_manager)
	# 10 half-innings, no scoring (0-0 nobody wins, just expires)
	for i in 10:
		_manager.advance_half_inning()
	await assert_signal(monitor).is_emitted("game_over_signal")

func test_game_over_signal_does_not_emit_early() -> void:
	var monitor := monitor_signals(_manager)
	# Bot 4, home leading 5-0 — not over yet
	for i in 7:
		_manager.advance_half_inning()
	_manager.away_score = 0
	for i in 5:
		_manager.add_run()  # home scoring 5 in bot 4
	await assert_signal(monitor).is_not_emitted("game_over_signal")
