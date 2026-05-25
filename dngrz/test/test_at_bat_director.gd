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
