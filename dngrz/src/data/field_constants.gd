class_name FieldConstants

# Scale: 1 unit = 1 meter
# Field oriented so home plate is at origin, second base is in -Z direction

# Base positions (real baseball dimensions)
const BASELINE_LENGTH := 27.43  # 90 feet
const MOUND_DISTANCE := 18.44  # 60.5 feet from home to rubber
const MOUND_HEIGHT := 0.254    # 10 inches elevation

const HOME_PLATE := Vector3(0.0, 0.0, 0.0)
const FIRST_BASE := Vector3(19.4, 0.0, -19.4)    # 45-degree angle from home
const SECOND_BASE := Vector3(0.0, 0.0, -38.8)     # straight up the middle
const THIRD_BASE := Vector3(-19.4, 0.0, -19.4)    # mirror of first
const MOUND := Vector3(0.0, MOUND_HEIGHT, -MOUND_DISTANCE)

# Outfield fence distances (center/left/right)
const FENCE_CENTER := 121.92   # 400 feet
const FENCE_CORNERS := 100.58  # 330 feet

# Strike zone (meters, approximate for "arcade" feel)
const STRIKE_ZONE_WIDTH := 0.43    # 17 inches (home plate width)
const STRIKE_ZONE_BOTTOM := 0.5    # knee height
const STRIKE_ZONE_TOP := 1.1       # mid-chest
const STRIKE_ZONE_CENTER := Vector3(0.0, 0.8, 0.0)  # center of zone at plate

# Fielder default positions
const FIELDER_POSITIONS := {
	"pitcher": Vector3(0.0, MOUND_HEIGHT, -MOUND_DISTANCE),
	"catcher": Vector3(0.0, 0.0, 1.5),
	"first_base": Vector3(15.0, 0.0, -18.0),
	"second_base": Vector3(5.0, 0.0, -28.0),
	"shortstop": Vector3(-5.0, 0.0, -28.0),
	"third_base": Vector3(-15.0, 0.0, -18.0),
	"left_field": Vector3(-50.0, 0.0, -70.0),
	"center_field": Vector3(0.0, 0.0, -90.0),
	"right_field": Vector3(50.0, 0.0, -70.0),
}
