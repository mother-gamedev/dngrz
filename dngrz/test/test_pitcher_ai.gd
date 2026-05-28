class_name TestPitcherAI extends GdUnitTestSuite

func test_decision_returns_valid_pitch_type() -> void:
	var ai := PitcherAI.new()
	var d := ai.decide(0, 0, [])
	assert_array(PitchTypes.Type.values()).contains([d.pitch_type])

func test_target_inside_reasonable_area() -> void:
	var ai := PitcherAI.new()
	var d := ai.decide(0, 0, [])
	assert_float(absf(d.target.x)).is_less_equal(0.6)
	assert_float(d.target.y).is_between(0.1, 1.5)

func test_3_0_count_throws_strike() -> void:
	var ai := PitcherAI.new()
	var d := ai.decide(3, 0, [])
	assert_bool(StrikeZone.is_strike(d.target)).is_true()

func test_0_2_mixes_pitches_off_zone() -> void:
	var ai := PitcherAI.new()
	var non_fastball := 0
	for i in 100:
		var d := ai.decide(0, 2, [])
		if d.pitch_type != PitchTypes.Type.FASTBALL:
			non_fastball += 1
	assert_int(non_fastball).is_greater(30)

func test_avoids_immediate_repeat_majority() -> void:
	var ai := PitcherAI.new()
	var history: Array = []
	var repeats := 0
	for i in 100:
		var d := ai.decide(1, 1, history)
		if history.size() > 0 and d.pitch_type == history[history.size() - 1]:
			repeats += 1
		history.append(d.pitch_type)
		if history.size() > 5:
			history.pop_front()
	assert_int(repeats).is_less(70)

func test_decision_power_in_range() -> void:
	var ai := PitcherAI.new()
	for i in 50:
		var d := ai.decide(1, 1, [])
		assert_float(d.power).is_between(PitcherController.MIN_POWER, 1.0)

func test_decision_bend_within_limit() -> void:
	var ai := PitcherAI.new()
	for i in 50:
		var d := ai.decide(1, 1, [])
		assert_float(d.bend.length()).is_less_equal(PitcherController.BEND_MAX + 0.0001)

func test_behind_in_count_plays_it_safe() -> void:
	# At 3-0 the AI must throw a strike (existing rule) with low bend (don't miss).
	var ai := PitcherAI.new()
	for i in 20:
		var d := ai.decide(3, 0, [])
		assert_float(d.bend.length()).is_less(PitcherController.BEND_MAX * 0.5)
