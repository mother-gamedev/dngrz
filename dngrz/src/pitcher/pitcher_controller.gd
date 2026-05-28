class_name PitcherController extends Node3D

# MSSB pitcher skill (Plan 3a §4). Greenfield: aim -> hold-to-charge (the stick
# now sets BEND) -> release. The charge->power, perfect-window->accuracy and
# stick->bend math are PURE static functions (unit-tested headless); the node only
# times the hold (in _physics_process at the tick rate) and routes input.
#
# Releasing early = less power but the pitch keeps its base accuracy (the safe
# option). The perfect-release window sits at the TOP of the charge ramp: only
# there do you get both max power AND an accuracy bonus, and over-holding past it
# decays power and bleeds accuracy toward a meatball -- so reaching for max
# velocity demands a precise release (spec §4.2).

signal pitch_committed(cmd: PitchCommand)

enum State { IDLE, AIMING, CHARGING }

# Charge model knobs (feel-test tunable; the exact gesture is a Phase-B feel detail).
const CHARGE_TICKS := 45            # ticks (~0.75s @ 60Hz) to fill the ramp to 1.0
const MIN_POWER := 0.3              # no-charge / early release floor (still serviceable)
const PERFECT_BAND := 0.12          # [1.0 - PERFECT_BAND, 1.0] is the perfect-release window
const OVERHOLD_POWER_DECAY := 0.6   # power lost per unit charge past 1.0
const OVERHOLD_ACC_SPAN := 0.6      # charge past 1.0 over which accuracy falls to meatball
const MEATBALL_ACCURACY := 0.5      # accuracy floor when wildly over-held
const BEND_MAX := 0.4               # plate-plane metres of late break at full stick

const AIM_SPEED := 1.5              # m/s target movement while aiming
const AIM_X_LIMIT := 0.6
const AIM_Y_MIN := 0.1
const AIM_Y_MAX := 1.5
const STICK_DEADZONE := 0.2

var _state: State = State.IDLE
var _selected_pitch: PitchTypes.Type = PitchTypes.Type.FASTBALL
var _target: Vector3 = FieldConstants.STRIKE_ZONE_CENTER
var _held_ticks: int = 0
var _bend_stick: Vector2 = Vector2.ZERO

@onready var _target_marker: MeshInstance3D = $TargetMarker

func _ready() -> void:
	if _target_marker != null:
		_target_marker.visible = false

# --- Pure charge / power / bend model (no node state; unit-tested directly) ---

static func charge_for_ticks(held_ticks: int) -> float:
	return float(held_ticks) / float(CHARGE_TICKS)   # may exceed 1.0 (over-hold)

static func power_for_charge(charge: float) -> float:
	if charge <= 1.0:
		return lerpf(MIN_POWER, 1.0, clampf(charge, 0.0, 1.0))
	return clampf(1.0 - (charge - 1.0) * OVERHOLD_POWER_DECAY, MIN_POWER, 1.0)

static func accuracy_for_charge(charge: float, base_accuracy: float) -> float:
	if charge > 1.0:
		# Over-held: bleed from the perfect peak (1.0) toward a meatball — NOT from
		# base_accuracy. Decaying from base would create a 0.20 cliff at charge 1.0+ε
		# (peak 1.0 → just past peak 0.8 with base 0.8). Now continuous and monotonic.
		var over := (charge - 1.0) / OVERHOLD_ACC_SPAN
		return clampf(lerpf(1.0, MEATBALL_ACCURACY, over), MEATBALL_ACCURACY, 1.0)
	if charge >= 1.0 - PERFECT_BAND:
		# Perfect-release window: sharpen toward a bullseye.
		var t := (charge - (1.0 - PERFECT_BAND)) / PERFECT_BAND
		return clampf(lerpf(base_accuracy, 1.0, t), base_accuracy, 1.0)
	return base_accuracy   # early release keeps the pitch's base accuracy

static func bend_from_stick(stick: Vector2) -> Vector2:
	# RADIAL clamp so |bend| <= BEND_MAX even on diagonals. A per-axis clamp would
	# let Vector2(1,1) become (0.4, 0.4) with magnitude ~0.566 — 41% over the spec
	# cap, which would desync the batter's chevron telegraph (Task 7) from physics.
	var clamped := stick if stick.length() <= 1.0 else stick.normalized()
	return clamped * BEND_MAX

# Build the committed pitch from a charge level + a bend-stick reading. Pure w.r.t.
# the node's current selection + aim; used by both the input path and tests. The
# director stamps rng_seed + start_tick on receipt.
func build_release_command(charge: float, bend_stick: Vector2) -> PitchCommand:
	var pdata := PitchTypes.get_pitch(_selected_pitch)
	return PitchCommand.new(
		_selected_pitch,
		_target,
		power_for_charge(charge),
		accuracy_for_charge(charge, pdata.accuracy),
		bend_from_stick(bend_stick),
		PitchTypes.Tier.BASIC, 0, 0)

# --- Inspection seams (director + tests) ---

func get_selected_pitch() -> PitchTypes.Type: return _selected_pitch
func get_target() -> Vector3: return _target
func is_aiming() -> bool: return _state != State.IDLE
func current_charge() -> float: return charge_for_ticks(_held_ticks)
func current_bend() -> Vector2: return bend_from_stick(_bend_stick)

func select_pitch(pitch_type: PitchTypes.Type) -> void:
	_selected_pitch = pitch_type

func set_target(target: Vector3) -> void:
	_target = target
	if _target_marker != null:
		_target_marker.position = _target

func start_aiming() -> void:
	_state = State.AIMING
	_target = FieldConstants.STRIKE_ZONE_CENTER
	_held_ticks = 0
	_bend_stick = Vector2.ZERO
	if _target_marker != null:
		_target_marker.visible = true
		_target_marker.position = _target

func stop_aiming() -> void:
	_state = State.IDLE
	_held_ticks = 0
	_bend_stick = Vector2.ZERO
	if _target_marker != null:
		_target_marker.visible = false

# Programmatic pitch (AI). Forwards power + bend so the AI seat uses the same struct.
func request_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float = 1.0, power: float = 1.0, bend: Vector2 = Vector2.ZERO) -> void:
	pitch_committed.emit(PitchCommand.new(pitch_type, target, power, accuracy, bend, PitchTypes.Tier.BASIC, 0, 0))

# --- Input timing (tick-rate; eyeballed in the feel-test) ---

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.IDLE:
		return
	if event.is_action_pressed("pitch_fastball"):
		_selected_pitch = PitchTypes.Type.FASTBALL
	elif event.is_action_pressed("pitch_curveball"):
		_selected_pitch = PitchTypes.Type.CURVEBALL
	elif event.is_action_pressed("pitch_slider"):
		_selected_pitch = PitchTypes.Type.SLIDER
	elif event.is_action_pressed("pitch_changeup"):
		_selected_pitch = PitchTypes.Type.CHANGEUP
	if event.is_action_pressed("pitch_charge"):
		_state = State.CHARGING
		_held_ticks = 0
		_bend_stick = Vector2.ZERO
	elif event.is_action_released("pitch_charge") and _state == State.CHARGING:
		var cmd := build_release_command(charge_for_ticks(_held_ticks), _bend_stick)
		stop_aiming()
		pitch_committed.emit(cmd)

func _physics_process(_delta: float) -> void:
	match _state:
		State.AIMING:
			_aim()
		State.CHARGING:
			_held_ticks += 1
			# The same stick now means BEND (sequenced after aim — no channel conflict).
			_bend_stick = _pov_to_world(_stick())

# The mound camera (set up by AtBatDirector when the human pitches) looks down
# world +Z, which makes its screen-right correspond to world -X — a true mirror
# of the batter cam. So the player's PITCHER-VIEW input space (+x = pitcher's
# right) is world -X. We flip here at the input boundary; the rest of the
# controller stays in world coords, and the director's HUD bridge re-flips for
# display so the HUD cursor, the bend arrow, and the 3D ball all agree with the
# stick direction. (Tests for the pure bend_from_stick still use world coords.)
static func _pov_to_world(v: Vector2) -> Vector2:
	return Vector2(-v.x, v.y)

func _aim() -> void:
	var move := _pov_to_world(_stick() + _keys())
	if move.length() > 0.0:
		_target.x = clampf(_target.x + move.x * AIM_SPEED / float(SimClock.TICK_RATE), -AIM_X_LIMIT, AIM_X_LIMIT)
		_target.y = clampf(_target.y + move.y * AIM_SPEED / float(SimClock.TICK_RATE), AIM_Y_MIN, AIM_Y_MAX)
		if _target_marker != null:
			_target_marker.position = _target

func _keys() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_action_pressed("aim_left"): v.x -= 1.0
	if Input.is_action_pressed("aim_right"): v.x += 1.0
	if Input.is_action_pressed("aim_up"): v.y += 1.0
	if Input.is_action_pressed("aim_down"): v.y -= 1.0
	return v

# Left stick, plate convention (+y = up). Godot joypad Y is +down, so negate.
func _stick() -> Vector2:
	var raw := Vector2(_axis(JOY_AXIS_LEFT_X), -_axis(JOY_AXIS_LEFT_Y))
	return raw if raw.length() >= STICK_DEADZONE else Vector2.ZERO

static func _axis(axis: JoyAxis) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, axis)
		if absf(v) > absf(best):
			best = v
	return best
