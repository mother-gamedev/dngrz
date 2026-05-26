class_name ContactResolver

# Timing-first contact (2026-05-25 batting-feel redesign, spec §5). WHEN the swing
# commits relative to the ball's plate-crossing tick is the primary skill and the
# only gate on hit-vs-whiff. There is NO player cursor: the ball's own plate
# location modulates quality (zone discipline), and the latched stick direction
# biases spray/trajectory. Still a pure function of (SwingCommand, BallStateAtTick):
# no node state, no delta, no wall clock, no global RNG (determinism contracts).
#
# Precedence (spec §5):
#   swing timing vs. crossing tick -> whiff-vs-contact + base quality + EARLY/LATE
#   ball's plate location          -> quality multiplier (zone discipline, no cursor)
#   directional placement          -> AUTHORITATIVE intended spray + trajectory
#   tap vs. hold                   -> power output + window tightness

# Timing window in integer ticks anchored at the crossing tick, so it is identical
# for a 95 mph fastball and a 78 mph changeup. These four are the primary feel knobs.
const PERFECT_TICKS := 3              # |dt| <= this reads PERFECT (±50 ms @ 60 Hz)
const GOOD_TICKS := 7                 # quality falloff window (quality -> 0 here)
const CONTACT_TICKS := 12             # whiff window: |dt| beyond this is a swing-and-miss
const POWER_WINDOW_SCALE := 0.7       # hold tightens BOTH windows: higher reward, less margin

# Zone discipline (no cursor): location read from the BALL's normalized plate pos.
const CHASE_FALLOFF := 2.0            # normalized zone units; quality craters this far out
const MIN_LOC_FACTOR := 0.25         # floor: a timed swing on a bad pitch still makes weak contact

const CONTACT_EXIT_VELOCITY := 32.0  # m/s base exit velo, contact swing, perfect quality
const POWER_EXIT_VELOCITY := 42.0    # m/s base exit velo, power swing, perfect quality
const PITCH_SPEED_FACTOR := 0.3      # incoming-speed contribution to exit velo

const GROUND_LAUNCH := -5.0          # deg; placement_dir.y = -1 (down -> grounder)
const FLY_LAUNCH := 45.0             # deg; placement_dir.y = +1 (up -> fly ball)
const MISHIT_LAUNCH := 8.0           # deg; what low-quality contact degrades toward
const SPRAY_MAX := 35.0              # deg; placement_dir.x = +/-1 -> oppo / pull
const TIMING_LEAN := 60.0            # deg per second of timing offset (natural pull/oppo)

# Legible early/perfect/late readout for the HUD verdict word (spec §6). Always set
# on the result — even on a whiff, so a mistimed swing still flashes EARLY or LATE.
enum Judgment { EARLY, PERFECT, LATE }

class ContactResult:
	var is_whiff: bool
	var quality: float          # 0.0 to 1.0
	var exit_velocity: float    # m/s
	var launch_angle: float     # degrees from horizontal
	var h_angle: float          # degrees (0 = center, - = pull, + = oppo)
	var judgment: int           # Judgment.{EARLY, PERFECT, LATE}

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0
		judgment = Judgment.PERFECT

static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
	var result := ContactResult.new()

	# 1) TIMING is the primary gate. Signed ticks from exact tick math (never a wall
	#    clock); <0 early, >0 late.
	var dt: int = swing.commit_tick - ball_at_contact.tick
	var is_power := swing.swing_type == SwingCommand.SwingType.POWER

	# Verdict word — set first so it survives the whiff early-return.
	if absi(dt) <= PERFECT_TICKS:
		result.judgment = Judgment.PERFECT
	elif dt < 0:
		result.judgment = Judgment.EARLY
	else:
		result.judgment = Judgment.LATE

	# Hold tightens both the quality falloff and the whiff window. Whiff is decided
	# by TIMING ALONE — a pitch's location never gates contact (spec §9 decision #1).
	var quality_window := float(GOOD_TICKS)
	var whiff_window := float(CONTACT_TICKS)
	if is_power:
		quality_window *= POWER_WINDOW_SCALE
		whiff_window *= POWER_WINDOW_SCALE
	if float(absi(dt)) > whiff_window:
		result.is_whiff = true
		return result
	result.is_whiff = false

	# 2) Quality = quadratic timing quality * location factor. The location factor
	#    falls off as the BALL crosses farther from zone center (normalized plate
	#    position, NOT a player cursor) — chasing a bad pitch yields weak contact.
	var timing_q := clampf(1.0 - float(absi(dt)) / quality_window, 0.0, 1.0)
	timing_q = timing_q * timing_q   # quadratic falloff for sharper feel
	var zone_pos := StrikeZone.get_plate_position(ball_at_contact.position)
	var loc_factor := clampf(1.0 - zone_pos.length() / CHASE_FALLOFF, MIN_LOC_FACTOR, 1.0)
	result.quality = timing_q * loc_factor

	# 3) Exit velocity: base (tap/hold) + incoming speed, scaled by quality.
	var pitch_speed := ball_at_contact.velocity.length()
	var base_exit := POWER_EXIT_VELOCITY if is_power else CONTACT_EXIT_VELOCITY
	result.exit_velocity = (base_exit + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	# 4) Spray: placement_dir.x is AUTHORITATIVE intent honored to the degree executed,
	#    plus a small natural timing lean (early -> pull, late -> oppo).
	var timing_offset := SimClock.ticks_to_seconds(dt)
	var intended_spray := clampf(swing.placement_dir.x, -1.0, 1.0) * SPRAY_MAX
	result.h_angle = lerpf(0.0, intended_spray, result.quality) + timing_offset * TIMING_LEAN
	result.h_angle = clampf(result.h_angle, -45.0, 45.0)

	# 5) Trajectory: placement_dir.y is AUTHORITATIVE; poor contact degrades the
	#    realized launch toward a flat mishit.
	var intended_launch := remap(clampf(swing.placement_dir.y, -1.0, 1.0), -1.0, 1.0, GROUND_LAUNCH, FLY_LAUNCH)
	result.launch_angle = lerpf(MISHIT_LAUNCH, intended_launch, result.quality)
	result.launch_angle = clampf(result.launch_angle, -10.0, 60.0)

	return result
