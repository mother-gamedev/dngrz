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
			pass  # waiting for a pitch (Task 14 triggers AI / listens for human)
		Phase.PITCH_IN_FLIGHT:
			_collect_swing()
			if _tick >= _crossing_tick:
				_resolve()
		Phase.RESULT:
			if _tick >= _result_until_tick:
				_phase = Phase.IDLE
	_present()  # Task 14 fills this in; no-op here

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

# Hooks filled by Task 14; null-guarded no-ops here so the core tests run headless.
func _collect_swing() -> void: pass
func _arm_batter() -> void: pass
func _resolve_defense(_outcome: AtBatOutcome) -> void: pass
func _present() -> void: pass
