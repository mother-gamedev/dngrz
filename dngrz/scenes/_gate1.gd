extends Node3D

# Inspector toggles — set in the editor or via instance properties.
@export var enable_pitcher_ai: bool = false:
	set(v):
		enable_pitcher_ai = v
		if is_inside_tree() and _pitcher_ai != null:
			_pitcher_ai.enabled = v
@export var enable_batter_ai: bool = false:
	set(v):
		enable_batter_ai = v
		if is_inside_tree() and _batter_ai != null:
			_batter_ai.enabled = v

@onready var _ball: Node3D = $Ball
@onready var _pitcher: Node3D = $Pitcher
@onready var _batter: Node3D = $Batter
@onready var _pitcher_ai: PitcherAI = $Pitcher/PitcherAI
@onready var _batter_ai: BatterAI = $Batter/BatterAI
@onready var _hud: Control = $HUDLayer/HUD

var _swung: bool = false
var _swing_timing: float = 0.0
var _swing_placement: Vector2 = Vector2.ZERO
var _pitch_start_time: float = 0.0
var _current_pitch_flight: float = 0.0
var _at_bat_count: int = 0

func _ready() -> void:
	# Wire AI toggles
	_pitcher_ai.enabled = enable_pitcher_ai
	_pitcher_ai.pitcher_controller = _pitcher.get_path()
	_batter_ai.enabled = enable_batter_ai
	_batter_ai.batter_controller = _batter.get_path()

	# Position the batter near home plate and pitcher on the mound
	_batter.position = Vector3(0.5, 0.0, 0.3)
	_pitcher.position = FieldConstants.MOUND

	# Wire signals
	_pitcher.pitch_executed.connect(_on_pitch_executed)
	_ball.pitch_arrived.connect(_on_pitch_arrived)
	_ball.ball_landed.connect(_on_ball_landed)
	_batter.swing_executed.connect(_on_swing)
	_batter.took_pitch.connect(_on_took_pitch)

	# Kick off the first at-bat
	_start_at_bat()

func _start_at_bat() -> void:
	_at_bat_count += 1
	print("--- AT-BAT %d ---" % _at_bat_count)
	_swung = false
	_swing_timing = 0.0
	_swing_placement = Vector2.ZERO
	_ball.reset()
	_pitcher.start_aiming()
	# If pitcher AI is enabled, it will fire automatically via its interval.
	# If disabled, the human must press 1-4 + WASD + Space.

func _on_pitch_executed(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
	print("Pitch: ", PitchTypes.display_name(pitch_type), " target=", target, " accuracy=", accuracy)
	_ball.throw_pitch(pitch_type, target, accuracy)
	_pitch_start_time = Time.get_ticks_msec() / 1000.0
	# Ball.gd doesn't expose flight_duration publicly; estimate ~0.5s for v1.
	# Post-Gate 1: add ball.get_flight_duration() -> float.
	_current_pitch_flight = 0.5
	_batter.start_at_bat(_current_pitch_flight)

	# If batter AI is enabled, decide partway through the pitch.
	if _batter_ai.enabled:
		await get_tree().create_timer(_current_pitch_flight * 0.6).timeout
		if not _swung and _batter.is_armed():
			var decision := _batter_ai.decide(target, 0, 0)  # count not tracked at this gate
			if decision.swing:
				_batter.request_swing(decision.timing_offset, decision.placement)
				_swung = true
				_swing_timing = decision.timing_offset
				_swing_placement = decision.placement

func _on_swing(timing_offset: float, placement: Vector2) -> void:
	_swung = true
	_swing_timing = timing_offset
	_swing_placement = placement
	if not _batter_ai.enabled:
		# Compute timing from when the human swung relative to expected arrival
		var now := Time.get_ticks_msec() / 1000.0
		var expected_arrival := _pitch_start_time + _current_pitch_flight
		_swing_timing = now - expected_arrival
	print("Swing: timing=", _swing_timing, " placement=", placement)

func _on_took_pitch() -> void:
	print("Took the pitch")

func _on_pitch_arrived(plate_position: Vector3) -> void:
	_batter.pitch_arrived(plate_position)
	if _swung:
		var pitch_speed := 42.0  # nominal — would ideally come from PitchTypes
		var contact := ContactCalculator.calculate(_swing_timing, _swing_placement, pitch_speed)
		if contact.is_whiff:
			print("WHIFF — swinging strike")
			_reset_after_delay(1.0)
		else:
			print("CONTACT — quality=%.2f, exit_velo=%.1f, launch=%.1f°, h_angle=%.1f°" % [
				contact.quality, contact.exit_velocity, contact.launch_angle, contact.h_angle
			])
			_ball.launch_batted(
				FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
				contact.exit_velocity,
				contact.launch_angle,
				contact.h_angle
			)
	else:
		var is_strike := StrikeZone.is_strike(plate_position)
		print("STRIKE" if is_strike else "BALL")
		_reset_after_delay(1.0)

func _on_ball_landed(landed_position: Vector3) -> void:
	print("Ball landed at: ", landed_position)
	_reset_after_delay(1.5)

func _reset_after_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	_start_at_bat()
