class_name TestBattedBallResolver extends GdUnitTestSuite

# Build a deterministic batted trajectory, find where it lands, then place
# fielders relative to that landing so the test doesn't depend on tuned physics.
func _batted() -> BallTrajectory:
	return BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 1, 0), 40.0, 25.0, 0.0)

func test_ball_in_reach_is_out() -> void:
	var traj := _batted()
	var landing := BattedBallResolver._landing_point(traj)
	var align := FieldAlignment.new({"f": landing})  # fielder exactly at the landing spot
	var play := BattedBallResolver.resolve(traj, align)
	assert_bool(play.is_out).is_true()
	assert_float(play.reach_margin).is_greater(0.0)

func test_ball_in_gap_is_hit() -> void:
	var traj := _batted()
	var landing := BattedBallResolver._landing_point(traj)
	var far := landing + Vector3(50, 0, 50)  # nearest fielder ~70m away
	var align := FieldAlignment.new({"f": far})
	var play := BattedBallResolver.resolve(traj, align)
	assert_bool(play.is_out).is_false()
	assert_float(play.reach_margin).is_less(0.0)

func test_picks_nearest_fielder() -> void:
	var traj := _batted()
	var landing := BattedBallResolver._landing_point(traj)
	var align := FieldAlignment.new({
		"near": landing + Vector3(2, 0, 0),
		"far": landing + Vector3(40, 0, 0),
	})
	var play := BattedBallResolver.resolve(traj, align)
	assert_str(play.nearest_fielder).is_equal("near")

func test_landing_is_on_the_ground() -> void:
	var landing := BattedBallResolver._landing_point(_batted())
	assert_float(landing.y).is_equal_approx(0.0, 0.0001)

func test_default_alignment_resolves() -> void:
	var play := BattedBallResolver.resolve(_batted(), FieldAlignment.default())
	assert_str(play.nearest_fielder).is_not_equal("")
