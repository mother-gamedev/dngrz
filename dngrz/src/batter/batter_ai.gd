class_name BatterAI extends Node

class Decision:
	var swing: bool
	var timing_offset: float
	var placement: Vector2

	func _init(s: bool, t: float, p: Vector2) -> void:
		swing = s
		timing_offset = t
		placement = p

@export var batter_controller: NodePath
@export var enabled: bool = false
@export var skill: float = 0.7  # 0..1

# Pure decision function. `predicted_ball_at_plate` is the ball's predicted
# position when it crosses the plate plane.
func decide(predicted_ball_at_plate: Vector3, balls: int, strikes: int) -> Decision:
	var in_zone := StrikeZone.is_strike(predicted_ball_at_plate)
	var should := _should_swing(predicted_ball_at_plate, in_zone, balls, strikes)
	if not should:
		return Decision.new(false, 0.0, Vector2.ZERO)
	var timing := _swing_timing()
	var placement := _swing_placement()
	return Decision.new(true, timing, placement)

# Decision priorities, highest to lowest:
#  1. Protect the plate: at 2 strikes, ALWAYS swing at in-zone pitches.
#     This is realistic baseball (a real batter never takes a hittable strike
#     with 2 strikes) and makes test_swings_at_strike_with_two_strikes
#     deterministic.
#  2. Otherwise in zone: 85% swing rate (occasional take-for-look).
#  3. 2-strike protection on borderline: 75% chase rate within 0.15m of zone.
#  4. 3-ball discipline: only 5% chase rate outside the zone.
#  5. Close-but-outside: 40% chase rate within 0.08m of zone.
#  6. Default outside: 5% chase rate (looking for the rare bat-at-anything).
func _should_swing(ball: Vector3, in_zone: bool, balls: int, strikes: int) -> bool:
	# Way-outside-zone: a ball more than 0.3m from the zone is "obviously" a
	# ball. Nobody swings. Deterministic to keep the contract clean.
	var d := _distance_outside_zone(ball)
	if not in_zone and d > 0.3:
		return false

	if in_zone and strikes == 2:
		return true
	if in_zone:
		return randf() < 0.85
	if strikes == 2 and d < 0.15:
		return randf() < 0.75
	if balls >= 3:
		return randf() < 0.05
	if d < 0.08:
		return randf() < 0.4
	return randf() < 0.05

func _distance_outside_zone(ball: Vector3) -> float:
	var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var dx := maxf(0.0, absf(ball.x) - half_w)
	var dy := 0.0
	if ball.y < FieldConstants.STRIKE_ZONE_BOTTOM:
		dy = FieldConstants.STRIKE_ZONE_BOTTOM - ball.y
	elif ball.y > FieldConstants.STRIKE_ZONE_TOP:
		dy = ball.y - FieldConstants.STRIKE_ZONE_TOP
	return Vector2(dx, dy).length()

func _swing_timing() -> float:
	var spread := lerpf(0.08, 0.015, skill)
	return randf_range(-spread, spread)

# Placement noise around the ball's center. X is symmetric (pull/push spread).
# Y is intentionally asymmetric — biased slightly toward hitting *under* the
# ball (positive Y in plate-coords = swing cursor below ball = higher launch
# angle). Real batters lift more often than they bury, and Gate 1 will
# evaluate whether this produces too many fly outs.
func _swing_placement() -> Vector2:
	var noise_scale := lerpf(0.1, 0.02, skill)
	return Vector2(
		randf_range(-noise_scale, noise_scale),
		randf_range(-0.02, noise_scale * 0.5)
	)
