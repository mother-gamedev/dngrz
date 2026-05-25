class_name BallStateAtTick

# The batter-observable projection of the ball at one simulation tick
# (spec §7, contract #6). This is the ONLY channel the batter reads the pitch
# through. It deliberately carries no pitch type, no authored target, and no
# seed — those live in PitchCommand (the hidden truth). Keeping them separate
# types makes the hidden-information boundary structural, not bolted on.
var tick: int
var position: Vector3
var velocity: Vector3

func _init(p_tick: int = 0, p_position: Vector3 = Vector3.ZERO, p_velocity: Vector3 = Vector3.ZERO) -> void:
	tick = p_tick
	position = p_position
	velocity = p_velocity

# Plate-plane projection (x = horizontal, y = height) used by ContactResolver.
# This is the fixed 2D contact space of spec §7 — independent of any camera.
func plate_point() -> Vector2:
	return Vector2(position.x, position.y)

func to_dict() -> Dictionary:
	return {"tick": tick, "position": position, "velocity": velocity}

static func from_dict(d: Dictionary) -> BallStateAtTick:
	return BallStateAtTick.new(d["tick"], d["position"], d["velocity"])
