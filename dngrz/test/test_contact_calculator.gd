class_name TestContactCalculator extends GdUnitTestSuite

# Timing: 0.0 = perfect, negative = early, positive = late
# Placement: Vector2 offset from pitch location (0,0 = dead center on ball)

func test_perfect_contact_gives_max_quality() -> void:
	var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	assert_float(result.quality).is_equal_approx(1.0, 0.05)

func test_late_timing_reduces_quality() -> void:
	var perfect := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	var late := ContactCalculator.calculate(0.08, Vector2.ZERO, 42.0)
	assert_float(late.quality).is_less(perfect.quality)

func test_early_timing_reduces_quality() -> void:
	var perfect := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	var early := ContactCalculator.calculate(-0.08, Vector2.ZERO, 42.0)
	assert_float(early.quality).is_less(perfect.quality)

func test_missed_placement_reduces_quality() -> void:
	var centered := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	var off_center := ContactCalculator.calculate(0.0, Vector2(0.1, 0.0), 42.0)
	assert_float(off_center.quality).is_less(centered.quality)

func test_whiff_on_terrible_timing() -> void:
	var result := ContactCalculator.calculate(0.3, Vector2(0.2, 0.2), 42.0)
	assert_bool(result.is_whiff).is_true()

func test_good_contact_has_exit_velocity() -> void:
	var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	assert_float(result.exit_velocity).is_greater(30.0)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactCalculator.calculate(0.0, Vector2.ZERO, 35.0)
	var fast := ContactCalculator.calculate(0.0, Vector2.ZERO, 45.0)
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)

func test_early_timing_pulls_ball() -> void:
	# Early swing pulls the ball (negative h_angle = left for righty)
	var early := ContactCalculator.calculate(-0.04, Vector2.ZERO, 42.0)
	assert_float(early.h_angle).is_less(0.0)

func test_late_timing_pushes_ball_opposite() -> void:
	var late := ContactCalculator.calculate(0.04, Vector2.ZERO, 42.0)
	assert_float(late.h_angle).is_greater(0.0)

func test_perfect_timing_center_launch_angle() -> void:
	var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
	# Good contact should produce a reasonable launch angle (10-30 degrees)
	assert_float(result.launch_angle).is_between(5.0, 40.0)

func test_under_ball_produces_fly() -> void:
	# Swing cursor below ball center = fly ball (high launch angle)
	var result := ContactCalculator.calculate(0.0, Vector2(0.0, -0.05), 42.0)
	assert_float(result.launch_angle).is_greater(25.0)

func test_over_ball_produces_grounder() -> void:
	# Swing cursor above ball center = grounder (low launch angle)
	var result := ContactCalculator.calculate(0.0, Vector2(0.0, 0.05), 42.0)
	assert_float(result.launch_angle).is_less(15.0)
