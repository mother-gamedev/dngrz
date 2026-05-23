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
@onready var _pitching_view: PitchingView = $HUDLayer/PitchingView
@onready var _batting_view: BattingView = $HUDLayer/BattingView

enum Phase { AIMING, BALL_IN_FLIGHT, RESULT }
var _phase: Phase = Phase.AIMING

var _swung: bool = false
var _swing_timing: float = 0.0
var _swing_placement: Vector2 = Vector2.ZERO
var _pitch_start_time: float = 0.0
var _current_pitch_flight: float = 0.0
var _at_bat_count: int = 0
var _ball_trail: Array = []

func _ready() -> void:
	print("=========================================")
	print("DNGRZ Gate 1 — feel-test scene")
	print("PITCH controls: 1=Fastball  2=Curveball  3=Slider  4=Changeup")
	print("                WASD = aim    Space = throw")
	print("BAT   controls: arrow keys = cursor    Enter = swing")
	print("AI toggles: enable_pitcher_ai / enable_batter_ai on Gate1 inspector")
	print("=========================================")

	_pitcher_ai.enabled = enable_pitcher_ai
	_pitcher_ai.pitcher_controller = _pitcher.get_path()
	_batter_ai.enabled = enable_batter_ai
	_batter_ai.batter_controller = _batter.get_path()

	_batter.position = Vector3(0.5, 0.0, 0.3)
	_pitcher.position = FieldConstants.MOUND

	_pitcher.pitch_executed.connect(_on_pitch_executed)
	_ball.pitch_arrived.connect(_on_pitch_arrived)
	_ball.ball_landed.connect(_on_ball_landed)
	_batter.swing_executed.connect(_on_swing)
	_batter.took_pitch.connect(_on_took_pitch)

	_start_at_bat()

func _process(_delta: float) -> void:
	# Keep the pitching view in sync with the controller while the human aims.
	if _phase == Phase.AIMING and not enable_pitcher_ai:
		var t: Vector3 = _pitcher.get_target()
		var norm := StrikeZone.get_plate_position(t)
		_pitching_view.selected_pitch = _pitcher.get_selected_pitch()
		_pitching_view.aim_position = norm
		var pdata := PitchTypes.get_pitch(_pitcher.get_selected_pitch())
		_pitching_view.accuracy = pdata.accuracy

	# Keep the batting view live during pitch flight.
	if _phase == Phase.BALL_IN_FLIGHT:
		_batting_view.aim_position = _batter.get_cursor_position() * 2.0

		var t_now := Time.get_ticks_msec() / 1000.0
		var t_expected := _pitch_start_time + _current_pitch_flight
		var dt := t_now - t_expected
		if not _swung:
			_batting_view.swing_timing = clampf(dt / 0.15, -1.0, 1.0)

		if _ball.is_active():
			var ball_pos: Vector3 = _ball.position
			var normalized := Vector2(
				clampf(ball_pos.x / 0.6, -1.0, 1.0),
				clampf((ball_pos.y - 0.8) / 0.6, -1.0, 1.0)
			)
			_ball_trail.append(normalized)
			while _ball_trail.size() > 4:
				_ball_trail.pop_front()
			var pv := PackedVector2Array()
			for p in _ball_trail:
				pv.append(p)
			_batting_view.ball_positions_history = pv
			_batting_view.predicted_landing = normalized

func _start_at_bat() -> void:
	_at_bat_count += 1
	print("--- AT-BAT %d ---" % _at_bat_count)
	_swung = false
	_swing_timing = 0.0
	_swing_placement = Vector2.ZERO
	_ball_trail.clear()
	_ball.reset()
	_pitcher.start_aiming()
	_phase = Phase.AIMING
	_pitching_view.visible = not enable_pitcher_ai
	_batting_view.visible = false
	_batting_view.swing_locked = false
	_batting_view.ball_positions_history = PackedVector2Array()
	_batting_view.swing_timing = 0.0

func _on_pitch_executed(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
	print("Pitch: ", PitchTypes.display_name(pitch_type), " target=", target, " accuracy=", accuracy)
	_ball.throw_pitch(pitch_type, target, accuracy)
	_pitch_start_time = Time.get_ticks_msec() / 1000.0
	# Ball.gd doesn't expose flight_duration publicly; estimate ~0.5s for v1.
	# Post-Gate 1: add ball.get_flight_duration() -> float.
	_current_pitch_flight = 0.5
	_batter.start_at_bat(_current_pitch_flight)
	_phase = Phase.BALL_IN_FLIGHT
	_pitching_view.visible = false
	_batting_view.visible = not enable_batter_ai
	_batting_view.swing_locked = false
	_batting_view.predicted_landing = StrikeZone.get_plate_position(target)

	if _batter_ai.enabled:
		await get_tree().create_timer(_current_pitch_flight * 0.6).timeout
		if not _swung and _batter.is_armed():
			var decision := _batter_ai.decide(target, 0, 0)
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
		var now := Time.get_ticks_msec() / 1000.0
		var expected_arrival := _pitch_start_time + _current_pitch_flight
		_swing_timing = now - expected_arrival
	_batting_view.swing_locked = true
	_batting_view.swing_timing = clampf(_swing_timing / 0.15, -1.0, 1.0)
	print("Swing: timing=", _swing_timing, " placement=", placement)

func _on_took_pitch() -> void:
	print("Took the pitch")

func _on_pitch_arrived(plate_position: Vector3) -> void:
	_batter.pitch_arrived(plate_position)
	if _swung:
		var pitch_speed := 42.0
		var contact := ContactCalculator.calculate(_swing_timing, _swing_placement, pitch_speed)
		if contact.is_whiff:
			print("WHIFF — swinging strike")
			_phase = Phase.RESULT
			_reset_after_delay(1.0)
		else:
			print("CONTACT — quality=%.2f, exit_velo=%.1f, launch=%.1f°, h_angle=%.1f°" % [
				contact.quality, contact.exit_velocity, contact.launch_angle, contact.h_angle
			])
			_phase = Phase.RESULT
			_ball.launch_batted(
				FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
				contact.exit_velocity,
				contact.launch_angle,
				contact.h_angle
			)
	else:
		var is_strike := StrikeZone.is_strike(plate_position)
		print("STRIKE" if is_strike else "BALL")
		_phase = Phase.RESULT
		_reset_after_delay(1.0)

func _on_ball_landed(landed_position: Vector3) -> void:
	print("Ball landed at: ", landed_position)
	_reset_after_delay(1.5)

func _reset_after_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	_start_at_bat()
