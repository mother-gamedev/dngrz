class_name AtBatOutcome

# The full result of one at-bat, produced purely by AtBatResolver from the
# commands. Carries enough for the director to present and for the defense
# layer to consume the batted trajectory (parent spec §3 growth contract).
enum Kind { WHIFF, CONTACT, TAKE_STRIKE, TAKE_BALL }

var kind: Kind
var contact: ContactResolver.ContactResult  # null unless a swing was made (CONTACT or WHIFF)
var batted_trajectory: BallTrajectory        # null unless kind == CONTACT
var crossing_position: Vector3               # where the pitch crossed the plate (observable)
var crossing_tick: int

func _init(p_kind: Kind = Kind.TAKE_BALL, p_crossing_position: Vector3 = Vector3.ZERO, p_crossing_tick: int = 0) -> void:
	kind = p_kind
	contact = null
	batted_trajectory = null
	crossing_position = p_crossing_position
	crossing_tick = p_crossing_tick
