class_name AtBatResolver

# Pure resolution of an entire at-bat from the two commands alone (the property
# that makes future authoritative-server netcode an additive layer). No node
# state, no wall clock, no global RNG — the seed lives in pitch.rng_seed.
#   swing == null  =>  the batter took the pitch (strike/ball by the zone).

static func resolve(pitch: PitchCommand, swing: SwingCommand) -> AtBatOutcome:
	var flight := BallFlight.from_pitch(pitch)
	var crossing_tick := flight.crossing_tick()
	var ball_at_contact := flight.state_at_tick(crossing_tick)
	var crossing_pos := ball_at_contact.position

	if swing == null:
		var take_kind := AtBatOutcome.Kind.TAKE_STRIKE if StrikeZone.is_strike(crossing_pos) else AtBatOutcome.Kind.TAKE_BALL
		return AtBatOutcome.new(take_kind, crossing_pos, crossing_tick)

	var contact := ContactResolver.resolve(swing, ball_at_contact)
	if contact.is_whiff:
		var whiff := AtBatOutcome.new(AtBatOutcome.Kind.WHIFF, crossing_pos, crossing_tick)
		whiff.contact = contact
		return whiff

	var hit := AtBatOutcome.new(AtBatOutcome.Kind.CONTACT, crossing_pos, crossing_tick)
	hit.contact = contact
	hit.batted_trajectory = BallTrajectory.create_batted(
		FieldConstants.HOME_PLATE + Vector3(0.0, 1.0, 0.0),
		contact.exit_velocity, contact.launch_angle, contact.h_angle)
	return hit
