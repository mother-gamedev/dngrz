class_name BallFlight

# The read-vs-truth projection of a pitch in flight. Wraps the pure BallTrajectory
# plus the release tick, and answers "where is the observable ball at tick N?".
# This is the SINGLE home of the float-time -> integer-tick rounding, and the
# seam Plan 3's in-flight bend will modify. Pure (RefCounted): no node, no clock.
var trajectory: BallTrajectory
var start_tick: int

func _init(p_trajectory: BallTrajectory, p_start_tick: int) -> void:
	trajectory = p_trajectory
	start_tick = p_start_tick

# Build the flight for a pitch command, using its seed (determinism contract #5).
static func from_pitch(pitch: PitchCommand) -> BallFlight:
	var rng := RandomNumberGenerator.new()
	rng.seed = pitch.rng_seed
	var traj := BallTrajectory.create_pitch(pitch.type, pitch.target, pitch.accuracy, rng, pitch.power, pitch.bend)
	return BallFlight.new(traj, pitch.start_tick)

# The integer tick at which the ball crosses the plate plane (z = 0). Rounded
# ONCE here so every consumer agrees on the same crossing tick.
func crossing_tick() -> int:
	var crossing := trajectory.predict_crossing(0.0)
	return start_tick + SimClock.seconds_to_ticks(crossing.time)

# The observable ball state at an absolute tick — computed analytically from the
# trajectory, never sampled from a live node (determinism contract #3).
func state_at_tick(tick: int) -> BallStateAtTick:
	var t := SimClock.ticks_to_seconds(tick - start_tick)
	if t < 0.0:
		t = 0.0
	return BallStateAtTick.new(tick, trajectory.get_position(t), trajectory.get_velocity(t))
