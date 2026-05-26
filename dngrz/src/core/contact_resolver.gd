class_name ContactResolver

# MSSB-faithful contact (Plan 3a, spec §3). TWO whiff gates and a spatial quality:
#   gate 1 = TIMING: |commit - crossing| within the whiff window (tap wider, hold tighter)
#   gate 2 = REACH:  the cursor must be within effective_reach of the ball's plate pos
#   good TIMING widens effective_reach (the two skills TRADE), and QUALITY is the
#   spatial distance from the player's CURSOR (not the zone center).
# Pure function of (SwingCommand, BallStateAtTick): no node, delta, wall clock, or
# global RNG (determinism contracts). Cursor + ball share NORMALIZED plate space
# (StrikeZone.get_plate_position: (0,0)=center, ±1=zone edge).

const PERFECT_TICKS := 3
const GOOD_TICKS := 7
const CONTACT_TICKS := 12
const POWER_WINDOW_SCALE := 0.7

const BASE_REACH := 0.6
const REACH_TIMING_BONUS := 0.5
const Y_WEIGHT := 1.0

const CONTACT_EXIT_VELOCITY := 32.0
const POWER_EXIT_VELOCITY := 42.0
const PITCH_SPEED_FACTOR := 0.3

const SPRAY_MAX := 35.0
const TIMING_LEAN := 60.0
const GROUND_LAUNCH := -5.0
const FLY_LAUNCH := 45.0
const MISHIT_LAUNCH := 8.0

enum Judgment { EARLY, PERFECT, LATE, REACH }

class ContactResult:
	var is_whiff: bool
	var quality: float
	var exit_velocity: float
	var launch_angle: float
	var h_angle: float
	var judgment: int

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0
		judgment = Judgment.PERFECT

static func _plate_distance(a: Vector2, b: Vector2) -> float:
	var d := a - b
	return Vector2(d.x, d.y * Y_WEIGHT).length()

static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
	var result := ContactResult.new()
	var dt: int = swing.commit_tick - ball_at_contact.tick
	var is_power := swing.swing_type == SwingCommand.SwingType.POWER

	if absi(dt) <= PERFECT_TICKS:
		result.judgment = Judgment.PERFECT
	elif dt < 0:
		result.judgment = Judgment.EARLY
	else:
		result.judgment = Judgment.LATE

	var whiff_window := float(CONTACT_TICKS)
	var quality_window := float(GOOD_TICKS)
	if is_power:
		whiff_window *= POWER_WINDOW_SCALE
		quality_window *= POWER_WINDOW_SCALE

	if float(absi(dt)) > whiff_window:
		result.is_whiff = true
		return result

	var timing_q := clampf(1.0 - float(absi(dt)) / quality_window, 0.0, 1.0)
	timing_q = timing_q * timing_q

	var effective_reach := BASE_REACH * (1.0 + REACH_TIMING_BONUS * timing_q)
	var ball_plate := StrikeZone.get_plate_position(ball_at_contact.position)
	var dist := _plate_distance(swing.cursor_point, ball_plate)
	if dist > effective_reach:
		result.is_whiff = true
		result.judgment = Judgment.REACH
		return result
	result.is_whiff = false

	var spatial_q := clampf(1.0 - dist / effective_reach, 0.0, 1.0)
	result.quality = spatial_q * (0.85 + 0.15 * timing_q)

	var pitch_speed := ball_at_contact.velocity.length()
	var base_exit := POWER_EXIT_VELOCITY if is_power else CONTACT_EXIT_VELOCITY
	result.exit_velocity = (base_exit + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	var timing_offset := SimClock.ticks_to_seconds(dt)
	var intended_spray := clampf(swing.cursor_point.x, -1.0, 1.0) * SPRAY_MAX
	result.h_angle = clampf(intended_spray + timing_offset * TIMING_LEAN, -45.0, 45.0)

	var intended_launch := remap(clampf(swing.cursor_point.y, -1.0, 1.0), -1.0, 1.0, GROUND_LAUNCH, FLY_LAUNCH)
	result.launch_angle = clampf(lerpf(MISHIT_LAUNCH, intended_launch, result.quality), -10.0, 60.0)

	return result
