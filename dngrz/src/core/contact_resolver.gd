class_name ContactResolver

# Replaces ContactCalculator. The headline fix (spec finding #3): this resolver
# RECEIVES the ball's actual state at the contact plane and measures the cursor
# against where the ball really is — spatial aim is finally wired. It is a pure
# function of (SwingCommand, BallStateAtTick): no node state, no delta, no wall
# clock, no global RNG (determinism contracts #2, #3).
#
# Precedence (spec §4):
#   cursor vs. actual ball  -> whiff vs. contact + base quality
#   swing timing            -> quality + a small natural pull/oppo lean
#   directional placement   -> AUTHORITATIVE intended spray + trajectory
#   tap vs. hold            -> power output + contact-zone size

const TIMING_WINDOW := 0.10          # s; quality reaches 0 at this offset (still contact until TIMING_WHIFF)
const TIMING_WHIFF := 0.20           # s; |offset| beyond this is an automatic whiff
const CONTACT_ZONE_RADIUS := 0.18    # m; cursor-vs-ball tolerance for a tap (contact) swing
const POWER_ZONE_RADIUS := 0.11      # m; smaller tolerance for a hold (power) swing

const CONTACT_EXIT_VELOCITY := 32.0  # m/s base exit velo, contact swing, perfect quality
const POWER_EXIT_VELOCITY := 42.0    # m/s base exit velo, power swing, perfect quality
const PITCH_SPEED_FACTOR := 0.3      # incoming-speed contribution to exit velo

const GROUND_LAUNCH := -5.0          # deg; placement_dir.y = -1 (down -> grounder)
const FLY_LAUNCH := 45.0             # deg; placement_dir.y = +1 (up -> fly ball)
const MISHIT_LAUNCH := 8.0           # deg; what low-quality contact degrades toward
const SPRAY_MAX := 35.0              # deg; placement_dir.x = +/-1 -> oppo / pull
const TIMING_LEAN := 60.0            # deg per second of timing offset (natural pull/oppo)

class ContactResult:
	var is_whiff: bool
	var quality: float          # 0.0 to 1.0
	var exit_velocity: float    # m/s
	var launch_angle: float     # degrees from horizontal
	var h_angle: float          # degrees (0 = center, - = pull, + = oppo)

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0

static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
	var result := ContactResult.new()

	# Timing from exact tick math (spec §9), never a wall clock. Early = negative.
	var timing_offset := SimClock.ticks_to_seconds(swing.commit_tick - ball_at_contact.tick)

	# Cursor vs. the ACTUAL ball at the plate plane (the headline fix).
	var placement_offset := swing.cursor_point - ball_at_contact.plate_point()
	var placement_dist := placement_offset.length()

	# Tap = bigger zone / less power; hold = smaller zone / more power (spec §4).
	var is_power := swing.swing_type == SwingCommand.SwingType.POWER
	var zone_radius := POWER_ZONE_RADIUS if is_power else CONTACT_ZONE_RADIUS

	# Whiff: swung where the ball isn't, or grossly mistimed.
	if placement_dist > zone_radius or absf(timing_offset) > TIMING_WHIFF:
		result.is_whiff = true
		return result
	result.is_whiff = false

	# Quality: how well the cursor overlapped the ball AND how well it was timed.
	var overlap_q := clampf(1.0 - placement_dist / zone_radius, 0.0, 1.0)
	var timing_q := clampf(1.0 - absf(timing_offset) / TIMING_WINDOW, 0.0, 1.0)
	result.quality = 0.5 * overlap_q + 0.5 * timing_q
	result.quality = result.quality * result.quality  # quadratic falloff for sharper feel

	# Power output (tap vs hold), scaled by incoming speed and quality.
	var pitch_speed := ball_at_contact.velocity.length()
	var base_exit := POWER_EXIT_VELOCITY if is_power else CONTACT_EXIT_VELOCITY
	result.exit_velocity = (base_exit + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	# Trajectory: placement_dir.y is AUTHORITATIVE intent; quality decides how
	# faithfully it is realized (poor contact degrades toward a flat mishit).
	var intended_launch := remap(clampf(swing.placement_dir.y, -1.0, 1.0), -1.0, 1.0, GROUND_LAUNCH, FLY_LAUNCH)
	result.launch_angle = lerpf(MISHIT_LAUNCH, intended_launch, result.quality)
	result.launch_angle = clampf(result.launch_angle, -10.0, 60.0)

	# Spray: placement_dir.x is AUTHORITATIVE; a small natural timing lean is
	# added (early -> pull, late -> oppo). Intent honored to the degree executed.
	var intended_spray := clampf(swing.placement_dir.x, -1.0, 1.0) * SPRAY_MAX
	var timing_lean := timing_offset * TIMING_LEAN
	result.h_angle = lerpf(0.0, intended_spray, result.quality) + timing_lean
	result.h_angle = clampf(result.h_angle, -45.0, 45.0)

	return result
