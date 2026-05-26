class_name TestContactResolver extends GdUnitTestSuite

const TICK := 100

func _ball(pos := Vector3(0.0, 0.8, 0.0), speed := 40.0, tick := TICK) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, speed))

func _swing(cursor := Vector2.ZERO, type := SwingCommand.SwingType.CONTACT,
		commit := TICK) -> SwingCommand:
	return SwingCommand.new(cursor, type, Vector2.ZERO, commit)

func test_on_time_cursor_on_ball_is_contact() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	assert_bool(r.is_whiff).is_false()

func test_gross_mistiming_whiffs() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 15), _ball())
	assert_bool(r.is_whiff).is_true()
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

func test_power_window_tighter_than_contact() -> void:
	var off := TICK + 10
	var contact := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, off), _ball())
	var power := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.POWER, off), _ball())
	assert_bool(contact.is_whiff).is_false()
	assert_bool(power.is_whiff).is_true()

func test_cursor_far_from_ball_whiffs_with_reach_verdict() -> void:
	var r := ContactResolver.resolve(_swing(Vector2(1.0, 0.0)), _ball())
	assert_bool(r.is_whiff).is_true()
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.REACH)

func test_cursor_near_ball_contacts() -> void:
	# 0.5 < effective_reach (BASE_REACH 0.6 widened to 0.9 at perfect timing) -> contact.
	var r := ContactResolver.resolve(_swing(Vector2(0.5, 0.0)), _ball())
	assert_bool(r.is_whiff).is_false()

func test_judgment_perfect_within_perfect_ticks() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 2), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.PERFECT)

func test_judgment_early_when_swing_precedes_crossing() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK - 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.EARLY)

func test_judgment_late_when_swing_follows_crossing() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

func test_resolution_is_deterministic() -> void:
	var a := ContactResolver.resolve(_swing(Vector2(0.3, -0.2), SwingCommand.SwingType.POWER, TICK + 3), _ball())
	var b := ContactResolver.resolve(_swing(Vector2(0.3, -0.2), SwingCommand.SwingType.POWER, TICK + 3), _ball())
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.h_angle).is_equal(b.h_angle)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
	assert_int(a.judgment).is_equal(b.judgment)

# --- Spatial quality (measured from the cursor) ---

func test_cursor_on_ball_is_high_quality() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	assert_bool(r.is_whiff).is_false()
	assert_float(r.quality).is_greater(0.9)

func test_cursor_farther_from_ball_lowers_quality() -> void:
	var on_ball := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	var off := ContactResolver.resolve(_swing(Vector2(0.4, 0.0)), _ball())
	assert_bool(off.is_whiff).is_false()
	assert_float(off.quality).is_less(on_ball.quality)

# --- Timing TRADES with reach: perfect timing widens the catch radius ---

func test_perfect_timing_widens_reach() -> void:
	# Cursor 0.8 from a center ball. At perfect timing effective_reach is 0.9 (contact);
	# mistimed-but-in-window (dt=5) it shrinks toward BASE_REACH (0.6) -> a REACH whiff.
	var perfect := ContactResolver.resolve(_swing(Vector2(0.8, 0.0)), _ball())
	var mistimed := ContactResolver.resolve(_swing(Vector2(0.8, 0.0), SwingCommand.SwingType.CONTACT, TICK + 5), _ball())
	assert_bool(perfect.is_whiff).is_false()
	assert_bool(mistimed.is_whiff).is_true()
	assert_int(mistimed.judgment).is_equal(ContactResolver.Judgment.REACH)

func test_nailing_both_beats_nailing_one() -> void:
	# Same cursor offset; perfect timing should grade higher than in-window-but-off timing.
	var both := ContactResolver.resolve(_swing(Vector2(0.3, 0.0)), _ball())
	var loose := ContactResolver.resolve(_swing(Vector2(0.3, 0.0), SwingCommand.SwingType.CONTACT, TICK + 4), _ball())
	assert_bool(both.is_whiff).is_false()
	assert_bool(loose.is_whiff).is_false()
	assert_float(both.quality).is_greater(loose.quality)

# --- Spray / launch from cursor position (intentional) + timing lean ---

func test_cursor_inside_pulls_outside_goes_oppo() -> void:
	var pull := ContactResolver.resolve(_swing(Vector2(-0.4, 0.0)), _ball())
	var oppo := ContactResolver.resolve(_swing(Vector2(0.4, 0.0)), _ball())
	assert_float(pull.h_angle).is_less(0.0)
	assert_float(oppo.h_angle).is_greater(0.0)

func test_cursor_low_grounds_high_flies() -> void:
	var grounder := ContactResolver.resolve(_swing(Vector2(0.0, -0.4)), _ball())
	var fly := ContactResolver.resolve(_swing(Vector2(0.0, 0.4)), _ball())
	assert_float(fly.launch_angle).is_greater(grounder.launch_angle)

func test_early_timing_leans_pull() -> void:
	# Cursor on the ball; early timing adds a pull lean.
	var early := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK - 6), _ball())
	assert_bool(early.is_whiff).is_false()
	assert_float(early.h_angle).is_less(0.0)

func test_power_swing_hits_harder_than_contact() -> void:
	var contact := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.POWER), _ball())
	assert_float(power.exit_velocity).is_greater(contact.exit_velocity)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactResolver.resolve(_swing(Vector2.ZERO), _ball(Vector3(0.0, 0.8, 0.0), 35.0))
	var fast := ContactResolver.resolve(_swing(Vector2.ZERO), _ball(Vector3(0.0, 0.8, 0.0), 45.0))
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)
