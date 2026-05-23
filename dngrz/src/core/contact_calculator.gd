class_name ContactCalculator

# Tuning constants — Gate 1 will revisit these.
const TIMING_WINDOW := 0.1         # seconds — perfect window is +/- this
const WHIFF_THRESHOLD := 0.15      # combined timing + placement error that causes a miss
const PLACEMENT_WINDOW := 0.12     # meters — perfect placement window
const BASE_EXIT_VELOCITY := 35.0   # m/s base exit velo on perfect contact
const PITCH_SPEED_FACTOR := 0.3    # how much pitch speed adds to exit velo
const BASE_LAUNCH_ANGLE := 18.0    # degrees — perfect contact launch angle
const TIMING_PULL_FACTOR := 150.0  # degrees per second of timing offset -> horizontal angle
const PLACEMENT_ANGLE_FACTOR := 200.0  # launch angle degrees per meter of vertical offset

class ContactResult:
	var is_whiff: bool
	var quality: float          # 0.0 to 1.0
	var exit_velocity: float    # m/s
	var launch_angle: float     # degrees from horizontal
	var h_angle: float          # horizontal angle in degrees (0 = center, - = pull, + = oppo)

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0

# timing_offset: seconds from perfect (0 = perfect, - = early, + = late)
# placement_offset: Vector2 from ball center in meters (0,0 = dead on)
# pitch_speed: m/s of the incoming pitch
static func calculate(timing_offset: float, placement_offset: Vector2, pitch_speed: float) -> ContactResult:
	var result := ContactResult.new()

	# Calculate error magnitudes (normalized — 1.0 means at the edge of the window)
	var timing_error := absf(timing_offset) / TIMING_WINDOW
	var placement_error := placement_offset.length() / PLACEMENT_WINDOW
	var total_error := timing_error + placement_error

	# Whiff check: WHIFF_THRESHOLD is expressed in raw input units; convert to
	# normalized error space by dividing by 0.05 (a "small reference window").
	# Result: total_error > 3.0 triggers a whiff. The 0.05 magic number is
	# preserved from the design spec — Gate 1 will retune it.
	if total_error > WHIFF_THRESHOLD / 0.05:
		result.is_whiff = true
		return result

	# Quality: 1.0 at perfect, drops with error, quadratic falloff for sharper feel.
	result.is_whiff = false
	result.quality = clampf(1.0 - (timing_error * 0.5 + placement_error * 0.5), 0.0, 1.0)
	result.quality = result.quality * result.quality

	# Exit velocity: base + pitch speed contribution, scaled by quality.
	result.exit_velocity = (BASE_EXIT_VELOCITY + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	# Launch angle: base angle modified by vertical placement offset.
	# Hitting under the ball (negative y offset) = higher launch; over = lower.
	result.launch_angle = BASE_LAUNCH_ANGLE - placement_offset.y * PLACEMENT_ANGLE_FACTOR
	result.launch_angle = clampf(result.launch_angle, -10.0, 60.0)

	# Horizontal angle: early = pull (negative), late = oppo (positive).
	result.h_angle = timing_offset * TIMING_PULL_FACTOR
	result.h_angle += placement_offset.x * 50.0  # horizontal placement nudge
	result.h_angle = clampf(result.h_angle, -45.0, 45.0)

	return result
