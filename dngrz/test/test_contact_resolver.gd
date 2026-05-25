class_name TestContactResolver extends GdUnitTestSuite

const TICK := 100

# Ball sitting on the plate at zone center, moving toward home at `speed`.
func _ball(pos := Vector3(0.0, 0.8, 0.0), speed := 40.0, tick := TICK) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, speed))

# A swing whose cursor sits exactly on the ball, committed exactly on the
# crossing tick (perfect timing) unless overridden.
func _swing(cursor := Vector2(0.0, 0.8), type := SwingCommand.SwingType.CONTACT,
		placement := Vector2.ZERO, commit := TICK) -> SwingCommand:
	return SwingCommand.new(cursor, type, placement, commit)

func test_perfect_contact_is_high_quality() -> void:
	var r := ContactResolver.resolve(_swing(), _ball())
	assert_bool(r.is_whiff).is_false()
	assert_float(r.quality).is_greater(0.9)

func test_cursor_far_from_ball_whiffs() -> void:
	var r := ContactResolver.resolve(_swing(Vector2(0.5, 0.8)), _ball())
	assert_bool(r.is_whiff).is_true()

func test_power_zone_is_smaller_than_contact_zone() -> void:
	# Cursor 0.15m off the ball: contacts on a CONTACT swing, whiffs on POWER.
	var off := Vector2(0.15, 0.8)
	var contact := ContactResolver.resolve(_swing(off, SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(off, SwingCommand.SwingType.POWER), _ball())
	assert_bool(contact.is_whiff).is_false()
	assert_bool(power.is_whiff).is_true()

func test_power_swing_hits_harder_than_contact() -> void:
	var contact := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.POWER), _ball())
	assert_float(power.exit_velocity).is_greater(contact.exit_velocity)

func test_placement_dir_x_sets_spray() -> void:
	var pull := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(-1.0, 0.0)), _ball())
	var oppo := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(1.0, 0.0)), _ball())
	assert_float(pull.h_angle).is_less(0.0)
	assert_float(oppo.h_angle).is_greater(0.0)

func test_placement_dir_y_sets_trajectory() -> void:
	var grounder := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(0.0, -1.0)), _ball())
	var fly := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(0.0, 1.0)), _ball())
	assert_float(fly.launch_angle).is_greater(grounder.launch_angle)

func test_early_timing_adds_pull_lean() -> void:
	# Commit 6 ticks before the crossing = 0.1s early -> pull (negative h_angle).
	var early := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK - 6), _ball())
	assert_float(early.h_angle).is_less(0.0)

func test_late_timing_adds_oppo_lean() -> void:
	var late := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 6), _ball())
	assert_float(late.h_angle).is_greater(0.0)

func test_poor_timing_reduces_quality() -> void:
	var perfect := ContactResolver.resolve(_swing(), _ball())
	var mistimed := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 5), _ball())
	assert_float(mistimed.quality).is_less(perfect.quality)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 35.0))
	var fast := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 45.0))
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)

func test_gross_mistiming_whiffs() -> void:
	# 18 ticks = 0.3s late, beyond the whiff window.
	var r := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 18), _ball())
	assert_bool(r.is_whiff).is_true()

func test_resolution_is_deterministic() -> void:
	var a := ContactResolver.resolve(_swing(Vector2(0.05, 0.82), SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	var b := ContactResolver.resolve(_swing(Vector2(0.05, 0.82), SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.h_angle).is_equal(b.h_angle)
	assert_float(a.launch_angle).is_equal(b.launch_angle)

func test_poor_quality_degrades_trajectory_intent_toward_mishit() -> void:
	# §4: intent is honored only to the degree the swing was well executed. With a
	# fly-ball intent (placement_dir.y = 1.0), clean contact should elevate, but a
	# near-whiff mistime must collapse the realized launch toward the flat mishit.
	var fly_intent := Vector2(0.0, 1.0)
	var clean := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, fly_intent, TICK), _ball())
	var poor := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, fly_intent, TICK + 9), _ball())
	assert_float(poor.launch_angle).is_less(clean.launch_angle)
	assert_float(absf(poor.launch_angle - ContactResolver.MISHIT_LAUNCH)).is_less(absf(poor.launch_angle - ContactResolver.FLY_LAUNCH))
