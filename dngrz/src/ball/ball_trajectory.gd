class_name BallTrajectory

const GRAVITY := Vector3(0.0, -9.81, 0.0)

# Gate 1 feel knob. Real pitch physics puts a fastball at the plate in ~0.44s —
# unhittable for a human. This multiplies pitch flight time into a readable swing
# window while keeping the ball crossing the same target. 1.0 = bare realism;
# raise to slow pitches further. Tune this during the Gate 1 feel-test.
const PITCH_TIME_SCALE := 4.0

# Power maps to flight speed (spec §4.2: power -> velocity -> less batter read time).
# MIN = a soft, readable newcomer pitch (slower than baseline); MAX = a genuinely
# faster-than-baseline heater. MAX_POWER_SPEED_SCALE IS the read-time-floor clamp:
# the mapping is clamped here (power is clamped to 1.0), never as a post-hoc tick
# floor (which would break the z=0 crossing invariant). Lower MAX if the max heater
# feels unhittable in the feel-test.
const MIN_POWER_SPEED_SCALE := 0.7
const MAX_POWER_SPEED_SCALE := 1.2

var start_position: Vector3
var initial_velocity: Vector3
var spin_break: Vector3       # lateral/vertical break from spin (for pitches)
var bend: Vector2             # release-time steer snapshot (plate-plane metres, NO z); spec §4.3
var flight_duration: float    # expected time to reach target (pitches) or land (batted)
var is_pitch: bool

# Result of predict_crossing(): where and when the ball crosses a plate plane.
class CrossingPrediction:
	var position: Vector3
	var time: float

	func _init(p_position: Vector3, p_time: float) -> void:
		position = p_position
		time = p_time

func get_position(time: float) -> Vector3:
	var pos := start_position + initial_velocity * time + 0.5 * GRAVITY * time * time
	# Apply spin break as a quadratic curve that peaks at the end of flight
	if spin_break.length() > 0.001:
		var t_normalized := time / flight_duration if flight_duration > 0.0 else 0.0
		# Break builds gradually, most apparent in last third of flight
		var break_factor := t_normalized * t_normalized
		pos += spin_break * break_factor
	# Release-time bend (spec §4.3): analytic quadratic, peaks at the plate, NO z so
	# the crossing tick is byte-identical with or without bend (predict_crossing
	# solves on z). This is the seam Plan 3's pitcher steer expresses through.
	if bend.length() > 0.0001:
		var t_bend := time / flight_duration if flight_duration > 0.0 else 0.0
		pos += Vector3(bend.x, bend.y, 0.0) * (t_bend * t_bend)
	return pos

# NOTE (spec §4.3): bend is intentionally NOT differentiated here. Bend is a small
# lateral/vertical displacement that contributes negligibly to speed magnitude, and
# the exit-velocity term reads this un-bent speed. Accepted and documented; add the
# analytic derivative later only if a measurable discrepancy appears.
func get_velocity(time: float) -> Vector3:
	return initial_velocity + GRAVITY * time

# Analytic plate-plane crossing (spec §8). The z-motion is linear
# (z(t) = start.z + vz*t — gravity and spin-break have no z-component), so the
# crossing time is exact and the caller can address it by tick via SimClock.
# Pure: no node state, no clock, no RNG. The returned position INCLUDES break.
func predict_crossing(plane_z: float = 0.0) -> CrossingPrediction:
	var vz := initial_velocity.z
	if absf(vz) < 0.0001:
		return CrossingPrediction.new(get_position(flight_duration), flight_duration)
	var t := (plane_z - start_position.z) / vz
	if t < 0.0:
		t = flight_duration
	return CrossingPrediction.new(get_position(t), t)

static func create_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float, rng: RandomNumberGenerator, power: float = 1.0, bend: Vector2 = Vector2.ZERO) -> BallTrajectory:
	var traj := BallTrajectory.new()
	traj.is_pitch = true
	traj.bend = bend

	var pitch_data := PitchTypes.get_pitch(pitch_type)
	traj.start_position = FieldConstants.MOUND + Vector3(0.0, 1.8, 0.0)  # release point

	# Flight time from speed + distance, slowed by PITCH_TIME_SCALE for readability.
	# power scales the effective speed between MIN (soft/slow/readable) and MAX
	# (faster-than-baseline heater). The MAX clamp is the read-time floor.
	var speed_scale := lerpf(MIN_POWER_SPEED_SCALE, MAX_POWER_SPEED_SCALE, clampf(power, 0.0, 1.0))
	var distance := traj.start_position.distance_to(target)
	traj.flight_duration = (distance / (pitch_data.speed * speed_scale)) * PITCH_TIME_SCALE

	# Initial velocity to reach target (accounting for gravity).
	# target = start + v*t + 0.5*g*t^2  =>  v = (target - start - 0.5*g*t^2) / t
	var t := traj.flight_duration
	traj.initial_velocity = (target - traj.start_position - 0.5 * GRAVITY * t * t) / t

	# Apply break as spin deviation (not baked into initial velocity)
	traj.spin_break = Vector3(pitch_data.h_break, -pitch_data.drop, 0.0)

	# Accuracy adds deviation to where the pitch lands. The RNG is passed in
	# explicitly (determinism contract #5) so the same seed reproduces the same
	# pitch — no global randf in any resolution-relevant path.
	var inaccuracy := (1.0 - accuracy) * 0.15
	traj.spin_break += Vector3(
		rng.randf_range(-inaccuracy, inaccuracy),
		rng.randf_range(-inaccuracy, inaccuracy),
		0.0
	)

	return traj

static func create_batted(start: Vector3, exit_velocity: float, launch_angle_deg: float, h_angle_deg: float) -> BallTrajectory:
	var traj := BallTrajectory.new()
	traj.is_pitch = false
	traj.start_position = start
	traj.spin_break = Vector3.ZERO

	var launch_rad := deg_to_rad(launch_angle_deg)
	var h_rad := deg_to_rad(h_angle_deg)

	# Convert exit velo + angles to velocity vector.
	# Coords: -Z is toward center field, X is left/right.
	var horizontal_speed := exit_velocity * cos(launch_rad)
	traj.initial_velocity = Vector3(
		horizontal_speed * sin(h_rad),       # left-right
		exit_velocity * sin(launch_rad),     # up
		-horizontal_speed * cos(h_rad)       # toward outfield
	)

	# Estimate flight duration (time to hit ground).
	# Solve: 0 = start.y + vy*t + 0.5*g*t^2  =>  t = (-vy - sqrt(vy^2 - 2*g*sy)) / g
	var vy := traj.initial_velocity.y
	var sy := start.y
	var discriminant := vy * vy - 2.0 * GRAVITY.y * sy
	if discriminant >= 0.0:
		traj.flight_duration = (-vy - sqrt(discriminant)) / GRAVITY.y
	else:
		traj.flight_duration = 3.0  # fallback

	# Ground balls: short flight
	if launch_angle_deg < 5.0:
		traj.flight_duration = minf(traj.flight_duration, 0.3)

	return traj
