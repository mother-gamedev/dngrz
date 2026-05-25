class_name FieldAlignment

# A plain-data snapshot of fielder positions (parent spec §3 growth contract).
# Pure data — BattedBallResolver consumes this, never live fielder nodes.
# Plan 2 is STATIC (default()); Plan 3 adds shift deltas.
var positions: Dictionary  # position_key:String -> Vector3

func _init(p_positions: Dictionary = {}) -> void:
	positions = p_positions

# The default fielding alignment: infield + outfield from FieldConstants.
# Pitcher and catcher are excluded — they don't field batted balls in this model.
static func default() -> FieldAlignment:
	var keys := ["first_base", "second_base", "shortstop", "third_base",
		"left_field", "center_field", "right_field"]
	var p := {}
	for k in keys:
		p[k] = FieldConstants.FIELDER_POSITIONS[k]
	return FieldAlignment.new(p)
