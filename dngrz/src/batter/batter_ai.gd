class_name BatterAI extends Node

# Drives the at-bat from the SAME observable channel the human sees (a
# BallStateAtTick — never the hidden PitchCommand/seed) and an explicitly-passed
# seeded RNG (determinism contract #5). Produces the SwingCommand the director
# resolves — one commit path with the human FSM.

@export var enabled: bool = false
@export var skill: float = 0.7  # 0..1

# Returns a SwingCommand to swing, or null to take. `observable` is the AI's read
# of where the ball crosses; commit a few ticks before crossing, scaled by skill.
func compute_command(observable: BallStateAtTick, crossing_tick: int, balls: int, strikes: int, rng: RandomNumberGenerator) -> SwingCommand:
	var ball_pos := observable.position
	var in_zone := StrikeZone.is_strike(ball_pos)
	if not _should_swing(ball_pos, in_zone, balls, strikes, rng):
		return null
	var noise := lerpf(0.10, 0.02, skill)
	var cursor := observable.plate_point() + Vector2(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise))
	var placement := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.6))
	var swing_type := SwingCommand.SwingType.CONTACT if rng.randf() < 0.7 else SwingCommand.SwingType.POWER
	var latency := int(round(lerpf(8.0, 3.0, skill)))
	return SwingCommand.new(cursor, swing_type, placement, crossing_tick - latency)

func _should_swing(ball: Vector3, in_zone: bool, balls: int, strikes: int, rng: RandomNumberGenerator) -> bool:
	var d := _distance_outside_zone(ball)
	if not in_zone and d > 0.3:
		return false
	if in_zone and strikes == 2:
		return true
	if in_zone:
		return rng.randf() < 0.85
	if strikes == 2 and d < 0.15:
		return rng.randf() < 0.75
	if balls >= 3:
		return rng.randf() < 0.05
	if d < 0.08:
		return rng.randf() < 0.4
	return rng.randf() < 0.05

func _distance_outside_zone(ball: Vector3) -> float:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var dx := maxf(0.0, absf(ball.x) - half_w)
	var dy := 0.0
	if ball.y < FieldConstants.STRIKE_ZONE_BOTTOM:
		dy = FieldConstants.STRIKE_ZONE_BOTTOM - ball.y
	elif ball.y > FieldConstants.STRIKE_ZONE_TOP:
		dy = ball.y - FieldConstants.STRIKE_ZONE_TOP
	return Vector2(dx, dy).length()
