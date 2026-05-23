class_name StrikeZone

# Float-precision tolerance for boundary comparisons.
# Vector3 components are single-precision floats; FieldConstants values are
# doubles. Without this slack, a literal-edge pitch like (half_w, 1.1, 0)
# would round to ~1.10000002 and fail the <= comparison against double 1.1.
const _EDGE_EPSILON := 0.0001

# Check if a pitch crossing the plate at `pitch_position` is a strike.
# pitch_position.x = horizontal (0 = center of plate)
# pitch_position.y = vertical height
# pitch_position.z is ignored (we evaluate at the plate plane)
static func is_strike(pitch_position: Vector3) -> bool:
	var half_width := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var in_horizontal := absf(pitch_position.x) <= half_width + _EDGE_EPSILON
	var in_vertical := pitch_position.y >= FieldConstants.STRIKE_ZONE_BOTTOM - _EDGE_EPSILON \
		and pitch_position.y <= FieldConstants.STRIKE_ZONE_TOP + _EDGE_EPSILON
	return in_horizontal and in_vertical

# Returns the pitch position normalized to the strike zone.
# (0, 0) = center of zone, (-1, -1) = low-inside corner, (1, 1) = high-outside corner
static func get_plate_position(pitch_position: Vector3) -> Vector2:
	var half_width := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
	var zone_height := FieldConstants.STRIKE_ZONE_TOP - FieldConstants.STRIKE_ZONE_BOTTOM
	var zone_center_y := (FieldConstants.STRIKE_ZONE_TOP + FieldConstants.STRIKE_ZONE_BOTTOM) / 2.0

	var norm_x := pitch_position.x / half_width if half_width > 0.0 else 0.0
	var norm_y := (pitch_position.y - zone_center_y) / (zone_height / 2.0) if zone_height > 0.0 else 0.0
	return Vector2(norm_x, norm_y)
