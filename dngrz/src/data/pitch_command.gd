class_name PitchCommand

# Authored pitch intent — the authoritative TRUTH record (spec §7). NEVER
# delivered in full to the batter, who only ever sees BallStateAtTick. Keeping
# PitchCommand and BallStateAtTick as distinct types makes the hidden-info /
# network-authority boundary structural. Serializable + tick-stamped (#1).
#
# `power`, `bend`, and `tier` are carried now but only consumed in Plan 3
# (pitcher meter + in-flight bend + Phenom layer). Wiring them in here keeps
# those later layers additive — no struct rewrite.
#
# Spec calls the seed field "seed"; stored as `rng_seed` to avoid shadowing the
# global GDScript `seed()` function.

var type: PitchTypes.Type
var target: Vector3   # intended plate-plane crossing location
var power: float      # 0..1 (exit-velocity ceiling contribution, Plan 3); 1.0 = full
var accuracy: float   # 0..1; lower widens seeded inaccuracy in BallTrajectory
var bend: Vector2     # in-flight steer intent (reserved, Plan 3)
var tier: PitchTypes.Tier
var rng_seed: int     # at-bat RNG seed — part of the truth record
var start_tick: int   # the tick the pitch was released

func _init(
		p_type: PitchTypes.Type = PitchTypes.Type.FASTBALL,
		p_target: Vector3 = FieldConstants.STRIKE_ZONE_CENTER,
		p_power: float = 1.0,
		p_accuracy: float = 1.0,
		p_bend: Vector2 = Vector2.ZERO,
		p_tier: PitchTypes.Tier = PitchTypes.Tier.BASIC,
		p_rng_seed: int = 0,
		p_start_tick: int = 0) -> void:
	type = p_type
	target = p_target
	power = p_power
	accuracy = p_accuracy
	bend = p_bend
	tier = p_tier
	rng_seed = p_rng_seed
	start_tick = p_start_tick

func to_dict() -> Dictionary:
	return {
		"type": int(type),
		"target": target,
		"power": power,
		"accuracy": accuracy,
		"bend": bend,
		"tier": int(tier),
		"rng_seed": rng_seed,
		"start_tick": start_tick,
	}

static func from_dict(d: Dictionary) -> PitchCommand:
	return PitchCommand.new(d["type"], d["target"], d["power"], d["accuracy"],
		d["bend"], d["tier"], d["rng_seed"], d["start_tick"])
