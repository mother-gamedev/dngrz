class_name TestBatterAI extends GdUnitTestSuite

func test_swings_at_strike_with_two_strikes() -> void:
	var ai := BatterAI.new()
	var ball := Vector3(0.0, 0.8, 0.0)  # zone center
	var d := ai.decide(ball, 0, 2)
	assert_bool(d.swing).is_true()

func test_takes_obvious_ball_with_no_strikes() -> void:
	var ai := BatterAI.new()
	var way_outside := Vector3(0.8, 0.8, 0.0)
	var d := ai.decide(way_outside, 0, 0)
	assert_bool(d.swing).is_false()

func test_protects_borderline_with_two_strikes() -> void:
	var ai := BatterAI.new()
	var borderline := Vector3(0.25, 1.15, 0.0)
	var swings := 0
	for i in 50:
		var d := ai.decide(borderline, 0, 2)
		if d.swing: swings += 1
	assert_int(swings).is_greater(30)

func test_timing_offset_has_variance() -> void:
	var ai := BatterAI.new()
	var center := Vector3(0.0, 0.8, 0.0)
	var offsets: Array = []
	for i in 50:
		var d := ai.decide(center, 0, 0)
		if d.swing: offsets.append(d.timing_offset)
	var sum := 0.0
	for o in offsets: sum += o
	var mean: float = sum / float(offsets.size())
	var sq_diff := 0.0
	for o in offsets: sq_diff += (o - mean) * (o - mean)
	var stddev := sqrt(sq_diff / float(offsets.size()))
	assert_float(stddev).is_greater(0.005)

func test_placement_centered_near_ball() -> void:
	var ai := BatterAI.new()
	var center := Vector3(0.0, 0.8, 0.0)
	var d := ai.decide(center, 0, 0)
	assert_float(d.placement.length()).is_less(0.15)
