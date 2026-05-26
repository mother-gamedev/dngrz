class_name TestAtBatDirector extends GdUnitTestSuite

func _director() -> AtBatDirector:
	# Instantiated WITHOUT the scene: @onready node refs stay null and all node
	# access is guarded, so step_tick() exercises only the FSM core.
	var d: AtBatDirector = auto_free(AtBatDirector.new())
	d.enable_pitcher_ai = false
	d.enable_batter_ai = false
	return d

func _pitch(target := Vector3(0.0, 0.8, 0.0), seed_value := 7) -> PitchCommand:
	return PitchCommand.new(PitchTypes.Type.FASTBALL, target, 1.0, 1.0, Vector2.ZERO, PitchTypes.Tier.BASIC, seed_value, 0)

func test_begins_in_flight_after_pitch() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	assert_int(d.current_phase()).is_equal(AtBatDirector.Phase.PITCH_IN_FLIGHT)

func test_take_resolves_to_take_outcome_at_crossing() -> void:
	var d := _director()
	d.begin_at_bat(_pitch(Vector3(0.0, 0.8, 0.0)))  # in zone
	var guard := 0
	while d.current_phase() == AtBatDirector.Phase.PITCH_IN_FLIGHT and guard < 1000:
		d.step_tick()
		guard += 1
	assert_int(d.last_outcome().kind).is_equal(AtBatOutcome.Kind.TAKE_STRIKE)
	assert_int(d.current_phase()).is_equal(AtBatDirector.Phase.RESULT)

func test_injected_swing_resolves_to_contact() -> void:
	var d := _director()
	var pitch := _pitch()
	d.begin_at_bat(pitch)
	# Build a perfect swing from the director's own flight.
	var flight := BallFlight.from_pitch(d.current_pitch())
	var ct := flight.crossing_tick()
	d.set_pending_swing(SwingCommand.new(flight.state_at_tick(ct).plate_point(), SwingCommand.SwingType.CONTACT, Vector2.ZERO, ct))
	var guard := 0
	while d.current_phase() == AtBatDirector.Phase.PITCH_IN_FLIGHT and guard < 1000:
		d.step_tick()
		guard += 1
	assert_int(d.last_outcome().kind).is_equal(AtBatOutcome.Kind.CONTACT)

func test_result_phase_counts_down_to_idle() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var guard := 0
	while d.current_phase() != AtBatDirector.Phase.RESULT and guard < 1000:
		d.step_tick(); guard += 1
	guard = 0
	while d.current_phase() == AtBatDirector.Phase.RESULT and guard < 1000:
		d.step_tick(); guard += 1
	assert_int(d.current_phase()).is_equal(AtBatDirector.Phase.IDLE)

# --- Timing meter (view-model swing_timing / swing_locked) ---
# The needle is a live "press now" guide: early in flight it sits on the EARLY
# side and sweeps toward PERFECT (0) as the ball nears the plate, then locks to
# the committed swing's timing. Mirrors ContactResolver's tick math.

func test_swing_timing_sweeps_from_early_toward_perfect_during_flight() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var samples: Array[float] = []
	var guard := 0
	while d.current_phase() == AtBatDirector.Phase.PITCH_IN_FLIGHT and guard < 1000:
		d.step_tick()
		var v := d.get_view_state()
		if v.phase == AtBatDirector.Phase.PITCH_IN_FLIGHT:
			samples.append(v.swing_timing)
		guard += 1
	assert_int(samples.size()).is_greater(2)
	assert_float(samples[0]).is_less(0.0)                              # starts early
	assert_float(samples[samples.size() - 1]).is_greater(samples[0])  # sweeps toward perfect
	assert_bool(d.get_view_state().swing_locked).is_false()

func test_swing_timing_locks_to_perfect_for_on_time_commit() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var ct := BallFlight.from_pitch(d.current_pitch()).crossing_tick()
	d.set_pending_swing(SwingCommand.new(Vector2.ZERO, SwingCommand.SwingType.CONTACT, Vector2.ZERO, ct))
	d.step_tick()  # one flight tick with the swing latched
	assert_bool(d.get_view_state().swing_locked).is_true()
	assert_float(d.get_view_state().swing_timing).is_equal_approx(0.0, 0.001)

func test_swing_timing_pegs_early_for_early_commit() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var ct := BallFlight.from_pitch(d.current_pitch()).crossing_tick()
	# Commit a full whiff-window early (0.20s = 12 ticks) -> needle pegs EARLY (-1).
	d.set_pending_swing(SwingCommand.new(Vector2.ZERO, SwingCommand.SwingType.CONTACT, Vector2.ZERO, ct - 12))
	d.step_tick()
	assert_bool(d.get_view_state().swing_locked).is_true()
	assert_float(d.get_view_state().swing_timing).is_equal_approx(-1.0, 0.001)

# --- Flight continues past the plate (no "reset at PERFECT") ---
# The pitch keeps flying through the LATE half of the timing window before
# resolving, so the ball doesn't freeze the instant the needle hits center.

func test_flight_is_still_alive_at_the_crossing_tick() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var ct := BallFlight.from_pitch(d.current_pitch()).crossing_tick()
	var guard := 0
	while d.current_tick() < ct and guard < 1000:
		d.step_tick(); guard += 1
	assert_int(d.current_phase()).is_equal(AtBatDirector.Phase.PITCH_IN_FLIGHT)

func test_swing_timing_reaches_late_after_crossing() -> void:
	var d := _director()
	d.begin_at_bat(_pitch())
	var max_timing := -2.0
	var guard := 0
	while d.current_phase() == AtBatDirector.Phase.PITCH_IN_FLIGHT and guard < 1000:
		d.step_tick()
		var v := d.get_view_state()
		if v.phase == AtBatDirector.Phase.PITCH_IN_FLIGHT:
			max_timing = maxf(max_timing, v.swing_timing)
		guard += 1
	assert_float(max_timing).is_greater(0.0)  # swept past PERFECT into the LATE half

func test_late_flight_ticks_tracks_contact_window() -> void:
	# The flight-extension past the plate must equal the resolver's whiff window, or
	# late swings get accepted/dropped by a different bound than they're graded by.
	assert_int(AtBatDirector.LATE_FLIGHT_TICKS).is_equal(ContactResolver.CONTACT_TICKS)
