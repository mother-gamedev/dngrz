class_name AtBatDirector extends Node3D

# The live, tick-driven at-bat loop (replaces _gate1.gd). ONE tick path:
# _physics_process is a trampoline to step_tick(); gameplay time is the integer
# _tick and `delta` never enters resolution. Holds the hidden PitchCommand truth
# and hands views/controllers only observable BallStateAtTick. This file is the
# FSM core; live node wiring (input, AI, Ball, views) is added in a later task
# and guarded for null so the core is unit-testable headlessly.

enum Phase { IDLE, PITCH_IN_FLIGHT, RESULT }

@export var enable_pitcher_ai: bool = true
@export var enable_batter_ai: bool = false

const RESULT_TICKS := 120          # ~2s at 60Hz
const COMMIT_WINDOW_GRACE := 10    # ticks; a future server replaces these bounds

var _tick: int = 0
var _phase: Phase = Phase.IDLE
var _pitch: PitchCommand = null
var _flight: BallFlight = null
var _crossing_tick: int = 0
var _swing: SwingCommand = null
var _result_until_tick: int = 0
var _last_outcome: AtBatOutcome = null
var _rng := RandomNumberGenerator.new()

@onready var _ball: Node3D = get_node_or_null("Ball")
@onready var _pitcher: Node = get_node_or_null("Pitcher")
@onready var _batter: BatterController = get_node_or_null("Batter")
@onready var _pitcher_ai: PitcherAI = get_node_or_null("Pitcher/PitcherAI")
@onready var _batter_ai: BatterAI = get_node_or_null("Batter/BatterAI")
@onready var _batting_view: BattingView = get_node_or_null("HUDLayer/BattingView")
@onready var _pitching_view: PitchingView = get_node_or_null("HUDLayer/PitchingView")

var _view := AtBatView.new()
var _batter_input := BatterInput.new()
var _ai_rng := RandomNumberGenerator.new()
var _ai_swing_done: bool = false

func _ready() -> void:
	assert(Engine.physics_ticks_per_second == SimClock.TICK_RATE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if _pitcher != null and _pitcher.has_signal("pitch_committed"):
		_pitcher.pitch_committed.connect(_on_pitch_committed)

func get_view_state() -> AtBatView:
	return _view

# --- Test/inspection seams ---
func current_phase() -> Phase: return _phase
func current_tick() -> int: return _tick
func current_pitch() -> PitchCommand: return _pitch
func last_outcome() -> AtBatOutcome: return _last_outcome
func set_pending_swing(swing: SwingCommand) -> void: _swing = swing

# Start an at-bat from a given command (stamps the seed + release tick).
func begin_at_bat(cmd: PitchCommand) -> void:
	cmd.rng_seed = _rng.randi() if cmd.rng_seed == 0 else cmd.rng_seed
	cmd.start_tick = _tick
	_pitch = cmd
	_flight = BallFlight.from_pitch(cmd)
	_crossing_tick = _flight.crossing_tick()
	_swing = null
	_phase = Phase.PITCH_IN_FLIGHT
	_arm_batter()

func _physics_process(_delta: float) -> void:
	step_tick()

# The single tick path.
func step_tick() -> void:
	_tick += 1
	match _phase:
		Phase.IDLE:
			_step_idle()
		Phase.PITCH_IN_FLIGHT:
			_collect_swing()
			if _tick >= _crossing_tick:
				_resolve()
		Phase.RESULT:
			if _tick >= _result_until_tick:
				_phase = Phase.IDLE
				_pitch = null
	_present()

func _resolve() -> void:
	var swing := _swing
	# Director-level tick-window acceptance check (a server replaces these bounds).
	if swing != null and (swing.commit_tick < _pitch.start_tick or swing.commit_tick > _crossing_tick + COMMIT_WINDOW_GRACE):
		swing = null
	_last_outcome = AtBatResolver.resolve(_pitch, swing)
	if _last_outcome.kind == AtBatOutcome.Kind.CONTACT:
		_resolve_defense(_last_outcome)
	_phase = Phase.RESULT
	_result_until_tick = _tick + RESULT_TICKS

func _step_idle() -> void:
	# Deliver one AI pitch per at-bat; the human delivers via input → pitch_committed.
	if enable_pitcher_ai and _pitch == null and _pitcher_ai != null:
		var d := _pitcher_ai.decide(0, 0, [])
		begin_at_bat(PitchCommand.new(d.pitch_type, d.target, 1.0, d.accuracy, Vector2.ZERO, PitchTypes.Tier.BASIC, 0, 0))

func _on_pitch_committed(cmd: PitchCommand) -> void:
	if _phase == Phase.IDLE:
		begin_at_bat(cmd)

func _arm_batter() -> void:
	_ai_swing_done = false
	_ai_rng.seed = _pitch.rng_seed + 1
	if _batter != null:
		_batter.arm(_crossing_tick)

func _collect_swing() -> void:
	if _swing != null:
		return
	if enable_batter_ai:
		if not _ai_swing_done and _batter_ai != null:
			var observable := _flight.state_at_tick(_crossing_tick)
			var cmd: SwingCommand = _batter_ai.compute_command(observable, _crossing_tick, 0, 0, _ai_rng)
			_ai_swing_done = true
			if cmd != null:
				_swing = cmd  # latch; resolve uses commit_tick for timing
	elif _batter != null:
		var emitted: SwingCommand = _batter.step(_batter_input.sample(_batter.cursor()), _tick)
		if emitted != null:
			_swing = emitted

func _resolve_defense(outcome: AtBatOutcome) -> void:
	_view.last_play = BattedBallResolver.resolve(outcome.batted_trajectory, FieldAlignment.default())
	if _ball != null and _ball.has_method("launch_batted"):
		_ball.launch_batted(FieldConstants.HOME_PLATE + Vector3(0, 1, 0),
			outcome.contact.exit_velocity, outcome.contact.launch_angle, outcome.contact.h_angle)

func _present() -> void:
	_view.phase = _phase
	if _phase == Phase.PITCH_IN_FLIGHT and _flight != null:
		var bs := _flight.state_at_tick(_tick)
		_view.prev_ball_state = _view.ball_state
		_view.ball_state = bs
		_view.break_marker = PitchTypes.get_pitch(_pitch.type).break_marker
		_view.observable_landing = StrikeZone.get_plate_position(bs.position)
		if _ball != null:
			_ball.position = bs.position
		# --- Bridge: push observable data into HUD view nodes ---
		if _batting_view != null:
			_batting_view.predicted_landing = _view.observable_landing
			_batting_view.break_marker = _view.break_marker
			_batting_view.pitch_progress = clampf(
				float(_tick - _pitch.start_tick) / maxf(float(_crossing_tick - _pitch.start_tick), 1.0),
				0.0, 1.0)
			var hist := _batting_view.ball_positions_history
			hist.append(_view.observable_landing)
			_batting_view.ball_positions_history = hist
			if _batter != null:
				_batting_view.aim_position = _batter.cursor()
	if _phase == Phase.IDLE:
		_view.ball_state = null
		# --- Bridge: reset HUD view nodes on IDLE ---
		if _batting_view != null:
			_batting_view.predicted_landing = Vector2.ZERO
			_batting_view.break_marker = Vector2.ZERO
			_batting_view.pitch_progress = 0.0
			_batting_view.ball_positions_history = PackedVector2Array()
