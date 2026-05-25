class_name PitchTypes

enum Type {
	FASTBALL,
	CURVEBALL,
	SLIDER,
	CHANGEUP,
}

# Execution tier (spec §2). BASIC pitches use the meter; PHENOM gesture/combo
# pitches are out of scope, but the flag must exist now so that layer is purely
# additive. Single source of truth — PitchCommand reuses PitchTypes.Tier.
enum Tier {
	BASIC,
	PHENOM,
}

class PitchData:
	var speed: float          # meters per second
	var h_break: float        # horizontal break in meters (+ = arm side, - = glove side)
	var drop: float           # additional downward break in meters
	var accuracy: float       # base accuracy multiplier (0-1, higher = more forgiving)
	var break_marker: Vector2 # normalized in-flight break cue shown to the batter (spec §8);
							  #   plate-plane convention: x = horizontal, +y = up. The honest,
							  #   observable hint of "what's coming" — the renderer is Plan 2.
	var tier: PitchTypes.Tier

	func _init(p_speed: float, p_h_break: float, p_drop: float, p_accuracy: float,
			p_break_marker: Vector2 = Vector2.ZERO, p_tier: PitchTypes.Tier = PitchTypes.Tier.BASIC) -> void:
		speed = p_speed
		h_break = p_h_break
		drop = p_drop
		accuracy = p_accuracy
		break_marker = p_break_marker
		tier = p_tier

	func duplicate() -> PitchData:
		return PitchData.new(speed, h_break, drop, accuracy, break_marker, tier)

# Speeds in m/s (1 mph ~ 0.447 m/s)
# Fastball ~95mph=42.5m/s, Curve ~80mph=35.8m/s, Slider ~87mph=38.9m/s, Change ~83mph=37.0m/s
# break_marker is an exaggerated, normalized legibility cue (not raw physics):
#   fastball = slight rise, curve = straight down, slider = glove-side sweep,
#   changeup = arm-side fade + drop.
static var _pitches := {
	Type.FASTBALL:  PitchData.new(42.5, 0.05, 0.1, 0.85, Vector2(0.0, -0.2)),
	Type.CURVEBALL: PitchData.new(35.8, 0.1, 0.6, 0.70, Vector2(0.0, -1.0)),
	Type.SLIDER:    PitchData.new(38.9, -0.4, 0.2, 0.75, Vector2(-1.0, -0.3)),
	Type.CHANGEUP:  PitchData.new(37.0, 0.15, 0.15, 0.80, Vector2(0.3, -0.5)),
}

static func get_pitch(pitch_type: Type) -> PitchData:
	return _pitches[pitch_type].duplicate()

static func display_name(pitch_type: Type) -> String:
	match pitch_type:
		Type.FASTBALL: return "Fastball"
		Type.CURVEBALL: return "Curveball"
		Type.SLIDER: return "Slider"
		Type.CHANGEUP: return "Changeup"
	return "Unknown"
