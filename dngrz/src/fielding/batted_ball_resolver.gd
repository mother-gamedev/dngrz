class_name BattedBallResolver

# Pure: a batted-ball trajectory + a fielder snapshot -> out/hit (parent spec §3).
# v0 question only: did the ball land within a fielder's reach? In reach -> out;
# in a gap -> hit. No baserunning, no throws, no fielder movement. Tunable.
const FIELDER_REACH := 6.0  # meters a static fielder can cover from their spot

static func resolve(trajectory: BallTrajectory, alignment: FieldAlignment) -> PlayOutcome:
	var landing := _landing_point(trajectory)
	var nearest_key := ""
	var nearest_dist := INF
	for key in alignment.positions:
		var fpos: Vector3 = alignment.positions[key]
		# Ground-plane distance only — height doesn't matter for "can they get there".
		var d := Vector2(landing.x - fpos.x, landing.z - fpos.z).length()
		if d < nearest_dist:
			nearest_dist = d
			nearest_key = key
	var reach_margin := FIELDER_REACH - nearest_dist
	return PlayOutcome.new(reach_margin >= 0.0, landing, nearest_key, reach_margin)

# Where the batted ball returns to ground. create_batted sets flight_duration to
# the time-to-ground (capped short for grounders), so the end of the arc is the
# landing/contact point. Pure — no node state.
static func _landing_point(trajectory: BallTrajectory) -> Vector3:
	var pos := trajectory.get_position(trajectory.flight_duration)
	return Vector3(pos.x, 0.0, pos.z)
