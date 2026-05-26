class_name TestAtBatResolver extends GdUnitTestSuite

func _pitch(target := Vector3(0.0, 0.8, 0.0), seed_value := 7) -> PitchCommand:
	return PitchCommand.new(PitchTypes.Type.FASTBALL, target, 1.0, 1.0,
		Vector2.ZERO, PitchTypes.Tier.BASIC, seed_value, 0)

# A swing committed exactly on the crossing tick = a perfectly-timed swing
# (timing-first; there is no cursor to place — cursor_point stays ZERO).
func _perfect_swing(pitch: PitchCommand, type := SwingCommand.SwingType.CONTACT, placement := Vector2.ZERO) -> SwingCommand:
	var ct := BallFlight.from_pitch(pitch).crossing_tick()
	return SwingCommand.new(Vector2.ZERO, type, placement, ct)

func test_take_in_zone_is_strike() -> void:
	var o := AtBatResolver.resolve(_pitch(Vector3(0.0, 0.8, 0.0)), null)
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.TAKE_STRIKE)

func test_take_out_of_zone_is_ball() -> void:
	# 1.6m is well above the strike-zone top (1.1m).
	var o := AtBatResolver.resolve(_pitch(Vector3(0.0, 1.6, 0.0)), null)
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.TAKE_BALL)

func test_perfect_swing_makes_contact() -> void:
	var pitch := _pitch()
	var o := AtBatResolver.resolve(pitch, _perfect_swing(pitch))
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.CONTACT)
	assert_object(o.batted_trajectory).is_not_null()
	assert_object(o.contact).is_not_null()

func test_mistimed_swing_whiffs() -> void:
	# Timing-first: location never gates contact, but a grossly mistimed swing
	# (well beyond CONTACT_TICKS) is a swing-and-miss with no batted ball.
	var pitch := _pitch()
	var ct := BallFlight.from_pitch(pitch).crossing_tick()
	var swing := SwingCommand.new(Vector2.ZERO, SwingCommand.SwingType.CONTACT, Vector2.ZERO, ct + 20)
	var o := AtBatResolver.resolve(pitch, swing)
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.WHIFF)
	assert_object(o.batted_trajectory).is_null()

func test_deterministic_same_inputs() -> void:
	var pitch := _pitch(Vector3(0.0, 0.8, 0.0), 12345)
	var swing := _perfect_swing(pitch, SwingCommand.SwingType.POWER, Vector2(0.2, 0.1))
	var a := AtBatResolver.resolve(pitch, swing)
	var b := AtBatResolver.resolve(pitch, swing)
	assert_int(a.kind).is_equal(b.kind)
	assert_float(a.contact.exit_velocity).is_equal(b.contact.exit_velocity)
