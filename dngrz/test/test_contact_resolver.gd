class_name TestContactResolver extends GdUnitTestSuite

const TICK := 100

# Ball crossing the plate at zone center (height 0.8m), moving toward home at
# `speed`, at `tick`. The 2026-05-25 timing-first redesign decides contact from
# WHEN the swing commits relative to this crossing tick — not from a cursor.
func _ball(pos := Vector3(0.0, 0.8, 0.0), speed := 40.0, tick := TICK) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, speed))

# A committed swing. `cursor_point` is retained in the struct but UNUSED by the
# timing-first resolver (spec §7), so the helper no longer takes it — only the
# things resolution reads: swing_type, placement bias, and the commit tick.
func _swing(type := SwingCommand.SwingType.CONTACT, placement := Vector2.ZERO,
		commit := TICK) -> SwingCommand:
	return SwingCommand.new(Vector2.ZERO, type, placement, commit)

# --- Timing is the primary gate (spec §4, §11) ---

func test_on_time_centered_pitch_is_high_quality_contact() -> void:
	var r := ContactResolver.resolve(_swing(), _ball())
	assert_bool(r.is_whiff).is_false()
	assert_float(r.quality).is_greater(0.9)

func test_gross_mistiming_whiffs_regardless_of_location() -> void:
	# 15 ticks late > CONTACT_TICKS (12): a whiff even on a perfect center pitch.
	var r := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 15), _ball())
	assert_bool(r.is_whiff).is_true()

func test_location_never_gates_contact() -> void:
	# A pitch crossing well outside the zone, swung on time, still makes contact
	# (timing alone gates hit-vs-whiff). Quality just suffers — see below.
	var r := ContactResolver.resolve(_swing(), _ball(Vector3(0.6, 0.8, 0.0)))
	assert_bool(r.is_whiff).is_false()

func test_power_window_tighter_than_contact() -> void:
	# An offset that survives on CONTACT but whiffs on POWER. CONTACT whiff window
	# = CONTACT_TICKS (12); POWER tightens it by POWER_WINDOW_SCALE (~8.4). 10 ticks
	# late: CONTACT survives, POWER whiffs.
	var off := TICK + 10
	var contact := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, off), _ball())
	var power := ContactResolver.resolve(_swing(SwingCommand.SwingType.POWER, Vector2.ZERO, off), _ball())
	assert_bool(contact.is_whiff).is_false()
	assert_bool(power.is_whiff).is_true()

# --- Zone discipline: location modulates QUALITY, measured from the ball (§5, §9) ---

func test_pitch_outside_zone_lowers_quality_than_down_the_middle() -> void:
	var center := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0)))
	var outside := ContactResolver.resolve(_swing(), _ball(Vector3(0.6, 0.8, 0.0)))
	assert_bool(outside.is_whiff).is_false()
	assert_float(outside.quality).is_less(center.quality)

func test_poor_timing_reduces_quality() -> void:
	var perfect := ContactResolver.resolve(_swing(), _ball())
	var mistimed := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 5), _ball())
	assert_float(mistimed.quality).is_less(perfect.quality)

# --- Judgment label for the HUD (spec §6, §11) ---

func test_judgment_perfect_within_perfect_ticks() -> void:
	var r := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 2), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.PERFECT)

func test_judgment_early_when_swing_precedes_crossing() -> void:
	var r := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK - 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.EARLY)

func test_judgment_late_when_swing_follows_crossing() -> void:
	var r := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

func test_judgment_set_even_on_whiff() -> void:
	# A late whiff should still read LATE on the HUD (verdict word vs callout).
	var r := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 15), _ball())
	assert_bool(r.is_whiff).is_true()
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

# --- Direction: timing lean + authoritative placement bias (spec §5) ---

func test_early_timing_pulls() -> void:
	var early := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK - 6), _ball())
	assert_bool(early.is_whiff).is_false()
	assert_float(early.h_angle).is_less(0.0)

func test_late_timing_goes_oppo() -> void:
	var late := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 6), _ball())
	assert_bool(late.is_whiff).is_false()
	assert_float(late.h_angle).is_greater(0.0)

func test_placement_dir_x_sets_spray() -> void:
	var pull := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2(-1.0, 0.0)), _ball())
	var oppo := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2(1.0, 0.0)), _ball())
	assert_float(pull.h_angle).is_less(0.0)
	assert_float(oppo.h_angle).is_greater(0.0)

func test_placement_dir_y_sets_trajectory() -> void:
	var grounder := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2(0.0, -1.0)), _ball())
	var fly := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, Vector2(0.0, 1.0)), _ball())
	assert_float(fly.launch_angle).is_greater(grounder.launch_angle)

func test_poor_quality_degrades_trajectory_intent_toward_mishit() -> void:
	# §5: intent is honored only to the degree the swing was well executed. With a
	# fly-ball bias, clean contact elevates; a near-whiff mistime collapses the
	# realized launch toward the flat mishit.
	var fly_intent := Vector2(0.0, 1.0)
	var clean := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, fly_intent, TICK), _ball())
	var poor := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT, fly_intent, TICK + 9), _ball())
	assert_float(poor.launch_angle).is_less(clean.launch_angle)
	assert_float(absf(poor.launch_angle - ContactResolver.MISHIT_LAUNCH)).is_less(absf(poor.launch_angle - ContactResolver.FLY_LAUNCH))

# --- Power / exit velocity / determinism (kept) ---

func test_power_swing_hits_harder_than_contact() -> void:
	var contact := ContactResolver.resolve(_swing(SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(SwingCommand.SwingType.POWER), _ball())
	assert_float(power.exit_velocity).is_greater(contact.exit_velocity)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 35.0))
	var fast := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 45.0))
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)

func test_resolution_is_deterministic() -> void:
	var a := ContactResolver.resolve(_swing(SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	var b := ContactResolver.resolve(_swing(SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.h_angle).is_equal(b.h_angle)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
	assert_int(a.judgment).is_equal(b.judgment)
