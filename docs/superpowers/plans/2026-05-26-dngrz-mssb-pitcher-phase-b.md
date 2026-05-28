# MSSB Pitcher Skill — Phase B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pitcher a real skill loop — aim → lock → charge (build power, the stick sets bend) → release — where power sets pitch velocity (more power = faster = less batter read-time, clamped to a read-time floor so the max heater is fast-but-hittable), a release-time **bend** snapshot curves the ball analytically without breaking determinism, the perfect-release window tightens as you reach for max power, and the committed bend is telegraphed honestly to the batter (magnitude included). Then flip the scene so the **human pitches and the AI bats** — with the AI batter reading the same honest, drifting indicator the human does (so bend can actually fool it) — feel-testable in isolation.

**Architecture:** Bend is a **single value snapshotted at release** into `PitchCommand.bend` (Vector2, plate-plane metres) and applied in `BallTrajectory.get_position` as its own quadratic `t²` block with **no z-component** — so `predict_crossing` (which solves on z) returns a byte-identical crossing tick with or without bend, and the pure `(PitchCommand, SwingCommand)` resolution stays replayable. `power` (0..1) scales the pitch's flight speed in `create_pitch` between a soft, readable newcomer floor (`MIN_POWER_SPEED_SCALE`) and a genuinely faster-than-baseline heater (`MAX_POWER_SPEED_SCALE`); the mapping is clamped here (never as a post-hoc tick floor, which would break the z=0 invariant), so `MAX_POWER_SPEED_SCALE` is the read-time-floor knob. The charge→power, perfect-window→accuracy, and stick→bend math live as **pure static functions** on `PitcherController` (unit-tested headless, like `BatterInput.map`); the node holds the aim/charge/release state machine and emits `pitch_committed`. `PitcherAI` authors the same `power`+`bend` it would as a human, so both seats use one struct. The director forwards power+bend into the AI pitch, starts the human pitcher aiming each IDLE, folds the committed bend into the batter's break cue, bridges the live charge/aim/bend into the pitching HUD, and — for the AI batter — reads the same honest current-state projection the human sees (sampled at a reaction tick before crossing), so a bending pitch can fool it. The batter HUD's break chevron is made magnitude-proportional so that telegraph actually reaches the screen.

**Tech Stack:** Godot 4.5, GDScript (TAB indentation, always), gdUnit4 headless test suite.

**Spec:** `docs/superpowers/specs/2026-05-25-dngrz-mssb-duel-realignment-design.md` (rev 3). This plan implements **Phase B** (spec §4, §5, §7). Phase A (batter realignment) is already merged on this branch; Phase C (two-field roles, panic recenter, confidence cone, PHENOM, balance tuning) is planned separately.

**Decisions baked in after the pre-execution cross-check (2026-05-27):**
- **Power is faithful to spec §4.2** — charging produces a *faster-than-baseline* pitch (max > today), clamped by `MAX_POWER_SPEED_SCALE` so it stays hittable. (Rejected the earlier "max = today's speed" reinterpretation, which made power a non-lever.)
- **The bend magnitude telegraph is rendered** (Task 7) — folding bend into `break_marker` is useless unless the chevron scales with magnitude; `batting_view.gd` currently `.normalized()`s it away.
- **The AI batter reads the honest observable** (Task 8) — Phase A fed it the *truth* crossing; against bend that's clairvoyant and would invalidate the Phase-B feel-test.

**Conventions for every task:**
- GDScript files use **TAB** indentation, never spaces. The code blocks below show tabs; preserve them exactly.
- Run the suite per the project workflow (memory `dngrz-gdunit4-workflow`): **import first, then** the gdUnit4 cmd tool with `--ignoreHeadlessMode`.
- Single-test run pattern (substitute the test file):
  `GODOT46=<path-to-godot-4.6> ; timeout 120 "$GODOT46" --headless --path dngrz --import` then
  `timeout 300 "$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/<file>.gd`
- Commit after each task.
- **A note on `create_pitch`:** the new `power`/`bend` parameters are appended **with defaults** (`power := 1.0`, `bend := Vector2.ZERO`). Every existing 4-arg call (`create_pitch(type, target, accuracy, rng)`) keeps compiling; note that default power 1.0 now maps to `MAX_POWER_SPEED_SCALE` (a faster pitch), but the existing trajectory tests are either relative or range-based (`flight ∈ (0.8, 2.0)`) and stay green at the chosen `1.2` scale — verify in Task 1.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `dngrz/src/ball/ball_trajectory.gd` | Pure trajectory: analytic bend block (no z) + power→speed (min..max) | **Modify** |
| `dngrz/test/test_ball_trajectory.gd` | Trajectory unit tests | Modify (add bend + power cases) |
| `dngrz/src/ball/ball_flight.gd` | Read-vs-truth flight; pass power+bend through | Modify (one line in `from_pitch`) |
| `dngrz/test/test_ball_flight.gd` | Flight unit tests | Modify (crossing-tick invariant under bend) |
| `dngrz/src/pitcher/pitcher_controller.gd` | Greenfield: aim→charge→release FSM + pure charge/power/bend math | **Rewrite** |
| `dngrz/test/test_pitcher_controller.gd` | Controller tests (pure helpers + builder) | Rewrite |
| `dngrz/src/pitcher/pitcher_ai.gd` | AI authors power + planned bend | Modify (extend `Decision`) |
| `dngrz/test/test_pitcher_ai.gd` | AI tests | Modify (power+bend cases) |
| `dngrz/scenes/ui/pitching_view.gd` | Bend indicator + perfect-release mark on the charge meter | Modify (`_draw`, eyeballed) |
| `dngrz/src/game/at_bat_director.gd` | Forward AI power+bend; start human aiming; fold bend cue; bridge pitch HUD; AI honest read; pitching camera | **Modify** |
| `dngrz/test/test_at_bat_director.gd` | Director tests | Modify (bend-in-flight + AI projection) |
| `dngrz/scenes/ui/batting_view.gd` | Magnitude-scaled break chevron (telegraph reaches the screen) | Modify (`_draw`, eyeballed) |
| `dngrz/project.godot` | `pitch_charge` input action (hold-to-charge) | Modify |
| `dngrz/scenes/at_bat.tscn` | Flip to human-pitches / AI-bats; controls label | Modify |

> **Task order note:** the `PitchingView.bend` export (Task 5) is added **before** the director bridge that writes it (Task 6) — GDScript statically rejects an unknown property on the typed `_pitching_view`. PitcherController's pure helpers (Task 3) likewise precede every reference. `create_pitch`'s new params (Task 1) precede the `from_pitch` passthrough (Task 2) and the controller/AI authors (Tasks 3/4).

---

## Task 1: BallTrajectory — analytic release-time bend (no z) + power→speed (faster-than-baseline, clamped)

The determinism centerpiece. Bend is applied in `get_position` as its **own** quadratic block (not inside the `spin_break` guard) with **zero z**, so the plate-crossing time is unchanged. `power` scales flight speed between a soft newcomer floor and a faster-than-baseline heater; the clamp at `MAX_POWER_SPEED_SCALE` is the read-time floor (spec §4.2: clamp the mapping, never the tick).

**Files:**
- Modify: `dngrz/src/ball/ball_trajectory.gd`
- Modify: `dngrz/test/test_ball_trajectory.gd`

- [ ] **Step 1: Write the failing tests (RED)**

Append to `dngrz/test/test_ball_trajectory.gd`:

```gdscript
# --- Release-time bend (Plan 3a §4.3): analytic, quadratic, NO z-component ---

func test_bend_displaces_crossing_x_but_not_z() -> void:
	# Same seed/target; a +x bend pulls the plate-crossing x off zero, z stays 0.
	var straight := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2.ZERO)
	var bent := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2(0.3, 0.0))
	var cs := straight.predict_crossing(0.0)
	var cb := bent.predict_crossing(0.0)
	assert_float(cb.position.x).is_greater(cs.position.x + 0.1)   # pulled by the bend
	assert_float(cb.position.z).is_equal_approx(0.0, 0.01)        # no z drift

func test_bend_does_not_change_crossing_time() -> void:
	# The whole determinism argument: z-free bend => identical crossing time.
	var straight := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2.ZERO)
	var bent := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2(0.4, -0.3))
	assert_float(bent.predict_crossing(0.0).time).is_equal_approx(straight.predict_crossing(0.0).time, 0.0001)

func test_bend_builds_late_not_early() -> void:
	# Quadratic t^2: at 25% of flight the bend has expressed <10% of its full offset.
	var bent := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2(0.4, 0.0))
	var straight := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0, Vector2.ZERO)
	var quarter := bent.flight_duration * 0.25
	var early_offset := absf(bent.get_position(quarter).x - straight.get_position(quarter).x)
	assert_float(early_offset).is_less(0.04)   # < 10% of the 0.4 bend

func test_higher_power_throws_faster() -> void:
	# Power -> velocity: more power = shorter flight = less batter read time (spec §4.2).
	var hard := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0)
	var soft := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 0.3)
	assert_float(hard.flight_duration).is_less(soft.flight_duration)

func test_max_power_stays_above_read_time_floor() -> void:
	# The fastest pitch (full power) must still be hittable — MAX_POWER_SPEED_SCALE is
	# the clamp. If this fails the max heater got unhittable; lower MAX_POWER_SPEED_SCALE.
	var hard := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(), 1.0)
	assert_float(hard.flight_duration).is_greater(0.8)

func test_bend_is_deterministic() -> void:
	var a := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 1.0, _seeded_rng(5), 0.8, Vector2(0.2, -0.1))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 1.0, _seeded_rng(5), 0.8, Vector2(0.2, -0.1))
	assert_vector(a.get_position(a.flight_duration)).is_equal(b.get_position(b.flight_duration))
```

- [ ] **Step 2: Run the tests — verify they fail**

Run the single-file command for `res://test/test_ball_trajectory.gd`.
Expected: FAIL/ERROR — `create_pitch` takes 4 args today; `bend` field absent.

- [ ] **Step 3: Add the bend field, the bend block, and power→speed**

In `dngrz/src/ball/ball_trajectory.gd`, add the power-speed constants under `PITCH_TIME_SCALE`:

```gdscript
# Power maps to flight speed (spec §4.2: power -> velocity -> less batter read time).
# MIN = a soft, readable newcomer pitch (slower than baseline); MAX = a genuinely
# faster-than-baseline heater. MAX_POWER_SPEED_SCALE IS the read-time-floor clamp:
# the mapping is clamped here (power is clamped to 1.0), never as a post-hoc tick
# floor (which would break the z=0 crossing invariant). Lower MAX if the max heater
# feels unhittable in the feel-test.
const MIN_POWER_SPEED_SCALE := 0.7
const MAX_POWER_SPEED_SCALE := 1.2
```

Add the `bend` field alongside `spin_break`:

```gdscript
var spin_break: Vector3       # lateral/vertical break from spin (for pitches)
var bend: Vector2             # release-time steer snapshot (plate-plane metres, NO z); spec §4.3
var flight_duration: float    # expected time to reach target (pitches) or land (batted)
```

In `get_position`, after the `spin_break` block and before `return pos`, add the bend block as its **own** block:

```gdscript
	# Release-time bend (spec §4.3): analytic quadratic, peaks at the plate, NO z so
	# the crossing tick is byte-identical with or without bend (predict_crossing
	# solves on z). This is the seam Plan 3's pitcher steer expresses through.
	if bend.length() > 0.0001:
		var t_bend := time / flight_duration if flight_duration > 0.0 else 0.0
		pos += Vector3(bend.x, bend.y, 0.0) * (t_bend * t_bend)
	return pos
```

Document the `get_velocity` caveat (the spec requires it not be left silent) — replace the `get_velocity` function with:

```gdscript
# NOTE (spec §4.3): bend is intentionally NOT differentiated here. Bend is a small
# lateral/vertical displacement that contributes negligibly to speed magnitude, and
# the exit-velocity term reads this un-bent speed. Accepted and documented; add the
# analytic derivative later only if a measurable discrepancy appears.
func get_velocity(time: float) -> Vector3:
	return initial_velocity + GRAVITY * time
```

Change the `create_pitch` signature and the flight-duration line to consume `power` + `bend`:

```gdscript
static func create_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float, rng: RandomNumberGenerator, power: float = 1.0, bend: Vector2 = Vector2.ZERO) -> BallTrajectory:
	var traj := BallTrajectory.new()
	traj.is_pitch = true
	traj.bend = bend

	var pitch_data := PitchTypes.get_pitch(pitch_type)
	traj.start_position = FieldConstants.MOUND + Vector3(0.0, 1.8, 0.0)  # release point

	# Flight time from speed + distance, slowed by PITCH_TIME_SCALE for readability.
	# power scales the effective speed between MIN (soft/slow/readable) and MAX
	# (faster-than-baseline heater). The MAX clamp is the read-time floor.
	var speed_scale := lerpf(MIN_POWER_SPEED_SCALE, MAX_POWER_SPEED_SCALE, clampf(power, 0.0, 1.0))
	var distance := traj.start_position.distance_to(target)
	traj.flight_duration = (distance / (pitch_data.speed * speed_scale)) * PITCH_TIME_SCALE
```

(Leave the rest of `create_pitch` — the `initial_velocity` solve, `spin_break`, and the seeded inaccuracy — unchanged.)

- [ ] **Step 4: Run the tests — verify they pass (including the pre-existing trajectory cases)**

Run the single-file command for `res://test/test_ball_trajectory.gd`.
Expected: PASS. The pre-existing `test_pitch_flight_is_playable` (flight ∈ 0.8–2.0) must still pass at default power 1.0 → scale 1.2 (a ~1.45s fastball). If it fails low, `MAX_POWER_SPEED_SCALE` is too high — but 1.2 is safe; do not change it without re-checking.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/ball/ball_trajectory.gd dngrz/test/test_ball_trajectory.gd
git commit -m "feat(pitching): analytic release-time bend (no z) + power->speed (faster-than-baseline, clamped)"
```

---

## Task 2: BallFlight — thread power+bend through; lock the crossing-tick invariant

One line in `from_pitch`, plus the test that proves the determinism claim end-to-end: a bent and an unbent pitch with the same seed/target cross the plate at the **same tick** (different position).

**Files:**
- Modify: `dngrz/src/ball/ball_flight.gd`
- Modify: `dngrz/test/test_ball_flight.gd`

- [ ] **Step 1: Write the failing test (RED)**

Append to `dngrz/test/test_ball_flight.gd`:

```gdscript
func _bent_pitch(bend: Vector2, seed_value := 7, start_tick := 100) -> PitchCommand:
	return PitchCommand.new(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0),
		1.0, 1.0, bend, PitchTypes.Tier.BASIC, seed_value, start_tick)

func test_bend_keeps_crossing_tick_identical() -> void:
	# The crossing tick is solved on z; bend has no z, so it must not move (spec §4.3).
	var straight := BallFlight.from_pitch(_bent_pitch(Vector2.ZERO))
	var bent := BallFlight.from_pitch(_bent_pitch(Vector2(0.4, -0.2)))
	assert_int(bent.crossing_tick()).is_equal(straight.crossing_tick())

func test_bend_moves_crossing_position() -> void:
	var straight := BallFlight.from_pitch(_bent_pitch(Vector2.ZERO))
	var bent := BallFlight.from_pitch(_bent_pitch(Vector2(0.4, 0.0)))
	var ct := straight.crossing_tick()
	var sx := straight.state_at_tick(ct).position.x
	var bx := bent.state_at_tick(ct).position.x
	assert_float(bx).is_greater(sx + 0.1)
```

- [ ] **Step 2: Run the test — verify it fails**

Run the single-file command for `res://test/test_ball_flight.gd`.
Expected: FAIL — `from_pitch` does not pass `bend`, so the bent crossing position equals the straight one.

- [ ] **Step 3: Pass power+bend in `from_pitch`**

In `dngrz/src/ball/ball_flight.gd`, change the `create_pitch` call inside `from_pitch`:

```gdscript
static func from_pitch(pitch: PitchCommand) -> BallFlight:
	var rng := RandomNumberGenerator.new()
	rng.seed = pitch.rng_seed
	var traj := BallTrajectory.create_pitch(pitch.type, pitch.target, pitch.accuracy, rng, pitch.power, pitch.bend)
	return BallFlight.new(traj, pitch.start_tick)
```

- [ ] **Step 4: Run the test — verify it passes**

Run the single-file command for `res://test/test_ball_flight.gd`.
Expected: PASS (new + existing cases).

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/ball/ball_flight.gd dngrz/test/test_ball_flight.gd
git commit -m "feat(pitching): thread power+bend through BallFlight; lock crossing-tick invariant"
```

---

## Task 3: PitcherController — pure charge / power / bend math (headless)

Before any node/input wiring, build and lock the **pure** decision math as static functions (testable without a scene, like `BatterInput.map`). The node in Task 4 only times and routes input into these.

**Files:**
- Rewrite: `dngrz/src/pitcher/pitcher_controller.gd`
- Rewrite: `dngrz/test/test_pitcher_controller.gd`

- [ ] **Step 1: Replace the test file with the pure-helper tests (RED)**

Replace the entire contents of `dngrz/test/test_pitcher_controller.gd`:

```gdscript
class_name TestPitcherController extends GdUnitTestSuite

const PITCHER_SCENE := preload("res://scenes/pitcher.tscn")

# --- Pure charge model (no scene needed) ---

func test_power_rises_with_charge_to_max_at_full() -> void:
	assert_float(PitcherController.power_for_charge(0.0)).is_equal_approx(PitcherController.MIN_POWER, 0.0001)
	assert_float(PitcherController.power_for_charge(1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(PitcherController.power_for_charge(0.5)).is_greater(PitcherController.power_for_charge(0.2))

func test_overhold_decays_power() -> void:
	# Holding past the top of the ramp bleeds power back down.
	assert_float(PitcherController.power_for_charge(1.6)).is_less(PitcherController.power_for_charge(1.0))
	assert_float(PitcherController.power_for_charge(3.0)).is_greater_equal(PitcherController.MIN_POWER)

func test_early_release_keeps_base_accuracy() -> void:
	# Releasing before the perfect window is the safe, lower-power option.
	assert_float(PitcherController.accuracy_for_charge(0.5, 0.8)).is_equal_approx(0.8, 0.0001)

func test_perfect_window_sharpens_accuracy() -> void:
	# Nailing the top of the ramp earns an accuracy bonus above the pitch's base.
	assert_float(PitcherController.accuracy_for_charge(1.0, 0.8)).is_greater(0.8)

func test_overhold_degrades_to_meatball() -> void:
	# A charge just past the band: mid-slope decay, not pinned to the floor.
	var acc := PitcherController.accuracy_for_charge(1.3, 0.8)
	assert_float(acc).is_less(0.8)
	assert_float(acc).is_greater_equal(PitcherController.MEATBALL_ACCURACY)

func test_newcomer_floor_is_serviceable() -> void:
	# A do-nothing pitch (no charge) is a slower-but-accurate straight ball (spec §10).
	assert_float(PitcherController.power_for_charge(0.0)).is_equal_approx(PitcherController.MIN_POWER, 0.0001)
	assert_float(PitcherController.accuracy_for_charge(0.0, 0.85)).is_equal_approx(0.85, 0.0001)

func test_bend_scales_with_stick() -> void:
	assert_vector(PitcherController.bend_from_stick(Vector2(1.0, 0.0))).is_equal(Vector2(PitcherController.BEND_MAX, 0.0))
	assert_vector(PitcherController.bend_from_stick(Vector2.ZERO)).is_equal(Vector2.ZERO)
	assert_float(PitcherController.bend_from_stick(Vector2(2.0, 0.0)).x).is_equal_approx(PitcherController.BEND_MAX, 0.0001)  # clamped

func test_charge_for_ticks_normalizes_to_ramp() -> void:
	assert_float(PitcherController.charge_for_ticks(PitcherController.CHARGE_TICKS)).is_equal_approx(1.0, 0.0001)
	assert_float(PitcherController.charge_for_ticks(0)).is_equal_approx(0.0, 0.0001)

# --- The release command builder (uses the selected pitch + aim) ---

func test_build_release_command_carries_power_bend_accuracy() -> void:
	var p := PITCHER_SCENE.instantiate()
	add_child(p)
	await get_tree().process_frame
	p.select_pitch(PitchTypes.Type.SLIDER)
	p.set_target(Vector3(0.1, 0.6, 0.0))
	# Perfect-window charge, full-right bend stick.
	var cmd := p.build_release_command(1.0, Vector2(1.0, 0.0))
	assert_int(cmd.type).is_equal(PitchTypes.Type.SLIDER)
	assert_vector(cmd.target).is_equal(Vector3(0.1, 0.6, 0.0))
	assert_float(cmd.power).is_equal_approx(1.0, 0.0001)
	assert_vector(cmd.bend).is_equal(Vector2(PitcherController.BEND_MAX, 0.0))
	assert_float(cmd.accuracy).is_greater(0.0)
	p.queue_free()

# --- AI / programmatic path still works (now forwards power+bend) ---

func test_request_pitch_emits_pitch_command() -> void:
	var p := PITCHER_SCENE.instantiate()
	add_child(p)
	await get_tree().process_frame
	var captured := [null]
	p.pitch_committed.connect(func(cmd: PitchCommand) -> void: captured[0] = cmd)
	p.request_pitch(PitchTypes.Type.SLIDER, Vector3(0.1, 0.6, 0.0), 0.75, 0.9, Vector2(0.2, -0.1))
	assert_object(captured[0]).is_not_null()
	var cmd: PitchCommand = captured[0]
	assert_int(cmd.type).is_equal(PitchTypes.Type.SLIDER)
	assert_vector(cmd.target).is_equal(Vector3(0.1, 0.6, 0.0))
	assert_float(cmd.accuracy).is_equal_approx(0.75, 0.0001)
	assert_float(cmd.power).is_equal_approx(0.9, 0.0001)
	assert_vector(cmd.bend).is_equal(Vector2(0.2, -0.1))
	p.queue_free()
```

- [ ] **Step 2: Run the tests — verify they fail**

Run the single-file command for `res://test/test_pitcher_controller.gd`.
Expected: FAIL/ERROR — `PitcherController` has no `class_name`, no static helpers, no `build_release_command`/`select_pitch`/`set_target`, and `request_pitch` takes 3 args.

- [ ] **Step 3: Rewrite `pitcher_controller.gd` (greenfield FSM + pure helpers)**

Replace the entire contents of `dngrz/src/pitcher/pitcher_controller.gd`:

```gdscript
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
		# Over-held: bleed toward a meatball (the precision tax on max power).
		var over := (charge - 1.0) / OVERHOLD_ACC_SPAN
		return clampf(lerpf(base_accuracy, MEATBALL_ACCURACY, over), MEATBALL_ACCURACY, base_accuracy)
	if charge >= 1.0 - PERFECT_BAND:
		# Perfect-release window: sharpen toward a bullseye.
		var t := (charge - (1.0 - PERFECT_BAND)) / PERFECT_BAND
		return clampf(lerpf(base_accuracy, 1.0, t), base_accuracy, 1.0)
	return base_accuracy   # early release keeps the pitch's base accuracy

static func bend_from_stick(stick: Vector2) -> Vector2:
	return Vector2(clampf(stick.x, -1.0, 1.0), clampf(stick.y, -1.0, 1.0)) * BEND_MAX

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
			_bend_stick = _stick()

func _aim() -> void:
	var move := _stick() + _keys()
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
```

- [ ] **Step 4: Run the tests — verify they pass**

Run the single-file command for `res://test/test_pitcher_controller.gd`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/pitcher/pitcher_controller.gd dngrz/test/test_pitcher_controller.gd
git commit -m "feat(pitching): greenfield PitcherController — charge/power/bend FSM"
```

---

## Task 4: PitcherAI — author power + planned bend (same struct as the human)

The AI seat must emit `power` and a planned `bend` so the human-bats / AI-pitches mode (Phase A's wiring) and attract mode get the full pitcher. Keep it count-aware and bounded; the global `randf` here is off the resolution path (the director stamps the deterministic seed onto the resulting `PitchCommand`).

**Files:**
- Modify: `dngrz/src/pitcher/pitcher_ai.gd`
- Modify: `dngrz/test/test_pitcher_ai.gd`

- [ ] **Step 1: Write the failing tests (RED)**

Append to `dngrz/test/test_pitcher_ai.gd`:

```gdscript
func test_decision_power_in_range() -> void:
	var ai := PitcherAI.new()
	for i in 50:
		var d := ai.decide(1, 1, [])
		assert_float(d.power).is_between(PitcherController.MIN_POWER, 1.0)

func test_decision_bend_within_limit() -> void:
	var ai := PitcherAI.new()
	for i in 50:
		var d := ai.decide(1, 1, [])
		assert_float(d.bend.length()).is_less_equal(PitcherController.BEND_MAX + 0.0001)

func test_behind_in_count_plays_it_safe() -> void:
	# At 3-0 the AI must throw a strike (existing rule) with low bend (don't miss).
	var ai := PitcherAI.new()
	for i in 20:
		var d := ai.decide(3, 0, [])
		assert_float(d.bend.length()).is_less(PitcherController.BEND_MAX * 0.5)
```

- [ ] **Step 2: Run the tests — verify they fail**

Run the single-file command for `res://test/test_pitcher_ai.gd`.
Expected: FAIL — `Decision` has no `power`/`bend`.

- [ ] **Step 3: Extend `Decision` and author power+bend**

In `dngrz/src/pitcher/pitcher_ai.gd`, replace the `Decision` class and `decide` function:

```gdscript
class Decision:
	var pitch_type: PitchTypes.Type
	var target: Vector3
	var accuracy: float
	var power: float
	var bend: Vector2

	func _init(pt: PitchTypes.Type, t: Vector3, a: float, p: float = 1.0, b: Vector2 = Vector2.ZERO) -> void:
		pitch_type = pt
		target = t
		accuracy = a
		power = p
		bend = b

# Pure decision function — testable without scene tree.
# The director calls decide() then request_pitch() exactly once per at-bat.
func decide(balls: int, strikes: int, history: Array) -> Decision:
	var pitch_type := _select_pitch_type(balls, strikes, history)
	var target := _select_target(balls, strikes, pitch_type)
	var accuracy := _accuracy_for(balls, strikes)
	var power := _power_for(balls, strikes)
	var bend := _bend_for(balls, strikes)
	return Decision.new(pitch_type, target, accuracy, power, bend)

# Behind in the count -> safe (high power-with-control, low bend). Ahead -> bend more.
func _power_for(balls: int, strikes: int) -> float:
	if balls >= 3: return 0.85
	if strikes == 2: return 0.95
	return randf_range(0.7, 1.0)

func _bend_for(balls: int, strikes: int) -> Vector2:
	var scale := 0.25 if balls >= 3 else (0.85 if strikes == 2 else 0.55)
	var b := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.2)) * scale
	if b.length() > 1.0:
		b = b.normalized()
	return b * PitcherController.BEND_MAX
```

- [ ] **Step 4: Run the tests — verify they pass**

Run the single-file command for `res://test/test_pitcher_ai.gd`.
Expected: PASS (new + existing cases; `Decision.new(pt,t,a)` callers still work via defaults).

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/pitcher/pitcher_ai.gd dngrz/test/test_pitcher_ai.gd
git commit -m "feat(pitching): PitcherAI authors power + planned bend"
```

---

## Task 5: PitchingView — bend indicator + perfect-release mark on the charge meter

`_draw` is not headless-testable (verified by eye in Task 11). Add a `bend` export and two cues: a small arrow showing the live bend off the aim cursor, and a tick on the release meter marking the perfect-release window. **This precedes the director task so the typed `_pitching_view.bend` write parses.**

**Files:**
- Modify: `dngrz/scenes/ui/pitching_view.gd`

- [ ] **Step 1: Add the `bend` export**

In `dngrz/scenes/ui/pitching_view.gd`, after the `release_charge` export:

```gdscript
@export var bend: Vector2 = Vector2.ZERO:  # plate-plane metres; live release-time bend
	set(v):
		bend = v
		queue_redraw()
```

- [ ] **Step 2: Draw the bend arrow off the aim cursor**

In `_draw()`, after the aim cursor `draw_circle(cursor_pos, 8.0, Colors.BRAND)` line:

```gdscript
	# Bend arrow: where the late break will pull the ball (plate convention: +y up,
	# so negate y for screen). Scaled by BEND_MAX so a full-stick bend reads clearly.
	if bend.length() > 0.001:
		var bend_screen := Vector2(bend.x, -bend.y) / PitcherController.BEND_MAX * (ZONE_SIZE * 0.4)
		draw_line(cursor_pos, cursor_pos + bend_screen, Colors.BRAND_HOT, 2.0)
		draw_circle(cursor_pos + bend_screen, 4.0, Colors.BRAND_HOT)
```

- [ ] **Step 3: Mark the perfect-release window on the meter**

In `_draw()`, after the release-meter fill `draw_rect(...fill_h...)` line:

```gdscript
	# Perfect-release window: the band at the top of the meter where max power + the
	# accuracy bonus live (spec §4.2). Release inside it, before over-holding.
	var band_h := meter_h * PitcherController.PERFECT_BAND
	draw_rect(Rect2(meter_x - 3.0, meter_y, meter_w + 6.0, band_h), Colors.BRAND_HOT, false, 2.0)
```

- [ ] **Step 4: Sanity-run the import**

`timeout 120 "$GODOT46" --headless --path dngrz --import`
Expected: clean import, no parse errors mentioning `pitching_view.gd`.

- [ ] **Step 5: Commit**

```bash
git add dngrz/scenes/ui/pitching_view.gd
git commit -m "feat(pitching): pitching HUD bend arrow + perfect-release window mark"
```

---

## Task 6: Director — forward AI power+bend, start human aiming, fold bend into the cue, bridge the pitching HUD

The director changes are integration wiring. The director's unit tests instantiate it **without** the scene (all `@onready` refs null and guarded), so the human-aim / pitching-HUD / pitcher branches are null-skipped there — they are verified in the Task 11 feel-test. The one new unit-safe behavior (the AI pitch carries the authored power+bend through to the flight) is locked by a test that compares crossing geometry. (`PitchingView.bend` from Task 5 now exists, so the typed bridge write parses.)

**Files:**
- Modify: `dngrz/src/game/at_bat_director.gd`
- Modify: `dngrz/test/test_at_bat_director.gd`

- [ ] **Step 1: Write the test (pins AI power+bend reaching the flight)**

Append to `dngrz/test/test_at_bat_director.gd`:

```gdscript
func test_begin_at_bat_preserves_bend_in_flight() -> void:
	# A bent pitch handed to the director must reach the plate bent (the director
	# rebuilds the flight from the same PitchCommand the resolver grades).
	var d := _director()
	var p := _pitch()
	p.bend = Vector2(0.35, 0.0)
	d.begin_at_bat(p)
	var flight := BallFlight.from_pitch(d.current_pitch())
	var ct := flight.crossing_tick()
	# Same seed/target straight pitch for comparison.
	var straight := BallFlight.from_pitch(_pitch())
	assert_float(flight.state_at_tick(ct).position.x).is_greater(straight.state_at_tick(ct).position.x + 0.1)
	assert_int(flight.crossing_tick()).is_equal(straight.crossing_tick())   # tick invariant holds
```

- [ ] **Step 2: Run the test — verify it passes meaningfully**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: PASS already (Tasks 1–2 made the flight bend-aware; `begin_at_bat` already rebuilds via `BallFlight.from_pitch`). This test guards that a later refactor can't drop bend on the director path. If it fails, the flight isn't consuming `PitchCommand.bend` — revisit Task 2.

- [ ] **Step 3: Forward AI power+bend in `_step_idle` and start the human pitcher aiming**

In `dngrz/src/game/at_bat_director.gd`, replace `_step_idle`:

```gdscript
func _step_idle() -> void:
	# Deliver one AI pitch per at-bat; the human delivers via input → pitch_committed.
	if enable_pitcher_ai and _pitch == null and _pitcher_ai != null:
		var d := _pitcher_ai.decide(0, 0, [])
		begin_at_bat(PitchCommand.new(d.pitch_type, d.target, d.power, d.accuracy, d.bend, PitchTypes.Tier.BASIC, 0, 0))
	elif not enable_pitcher_ai and _pitcher != null and _pitcher.has_method("start_aiming") and not _pitcher.is_aiming():
		# Human pitches: hand control to the pitcher; it emits pitch_committed on release.
		_pitcher.start_aiming()
```

- [ ] **Step 4: Fold the committed bend into the batter's break cue**

The batter's honest read of "how much it will break" = the per-type `break_marker` shape **plus** the committed bend magnitude (spec §4.3). In `_present`, inside the `PITCH_IN_FLIGHT` block, replace the `break_marker` line:

```gdscript
		# Break cue telegraphs the pitch type's shape AND the committed bend magnitude
		# (spec §4.3): a bigger bend shows a bigger cue. CUE_BEND_GAIN maps bend metres
		# to the normalized marker space (Task 7 makes the batting view scale by it).
		_view.break_marker = PitchTypes.get_pitch(_pitch.type).break_marker + _pitch.bend * CUE_BEND_GAIN
```

Add the gain constant near `LATE_FLIGHT_TICKS`:

```gdscript
# Maps committed bend (plate-plane metres) into the normalized break-cue space so the
# batter's chevron telegraphs bend magnitude honestly. Feel-test tunable.
const CUE_BEND_GAIN := 2.5
```

- [ ] **Step 5: Bridge the live charge / aim / bend into the pitching HUD (human pitcher)**

In `_present`, after the phase blocks (just before the function ends), add a pitching-HUD bridge that runs whenever a human pitches (it must update during IDLE aiming + charging, not just in flight):

```gdscript
	# --- Bridge: drive the pitching HUD from the live pitcher (human seat only) ---
	if _pitching_view != null and not enable_pitcher_ai and _pitcher != null and _pitcher.has_method("current_charge"):
		_pitching_view.selected_pitch = _pitcher.get_selected_pitch()
		_pitching_view.aim_position = StrikeZone.get_plate_position(_pitcher.get_target())
		_pitching_view.release_charge = _pitcher.current_charge()
		_pitching_view.bend = _pitcher.current_bend()
```

- [ ] **Step 6: Run the director suite — verify green**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: PASS (the new branches are null-guarded in the scene-less test; existing timing/flight cases unchanged).

- [ ] **Step 7: Commit**

```bash
git add dngrz/src/game/at_bat_director.gd dngrz/test/test_at_bat_director.gd
git commit -m "feat(pitching): director forwards power+bend, starts human aiming, telegraphs bend, bridges pitch HUD"
```

---

## Task 7: Batting HUD — make the break chevron magnitude-proportional (the telegraph reaches the screen)

The director folds bend magnitude into `break_marker` (Task 6), but `batting_view.gd` currently `.normalized()`s it and draws a **fixed-length** chevron with no stem — so the magnitude is thrown away and a 0.4 bend looks identical to a 0.05 bend. Spec §6 lists `batting_view.gd` as needing a "magnitude-scaled break cue." Make the chevron length scale with `break_marker.length()` and add a stem so the length is visible. `_draw` is eyeballed in Task 11.

**Files:**
- Modify: `dngrz/scenes/ui/batting_view.gd`

- [ ] **Step 1: Replace the chevron block with a magnitude-scaled stem+chevron**

In `dngrz/scenes/ui/batting_view.gd`, replace the existing break-chevron block (the `if break_marker.length() > 0.01:` block that builds `dir`, `tip`, `wing`, `wing2` and draws the two wing lines):

```gdscript
	# Break cue — the honest in-flight read (spec §4.3/§8): a stem + chevron pointing
	# in the break direction, whose LENGTH scales with break_marker magnitude so a
	# bigger committed bend telegraphs a bigger cue. Clamped to stay legible.
	if break_marker.length() > 0.01:
		var anchor := _zone_to_screen(predicted_landing, zone_rect)
		var dir := Vector2(break_marker.x, -break_marker.y).normalized()  # +y = up in zone space
		var cue_len := clampf(break_marker.length() * 22.0, 14.0, 48.0)
		var tip := anchor + dir * cue_len
		var wing := dir.rotated(2.5) * (cue_len * 0.46)
		var wing2 := dir.rotated(-2.5) * (cue_len * 0.46)
		draw_line(anchor, tip, Colors.HEAT, 3.0)
		draw_line(tip, tip + wing, Colors.HEAT, 3.0)
		draw_line(tip, tip + wing2, Colors.HEAT, 3.0)
```

- [ ] **Step 2: Sanity-run the import**

`timeout 120 "$GODOT46" --headless --path dngrz --import`
Expected: clean import, no parse errors mentioning `batting_view.gd`.

- [ ] **Step 3: Commit**

```bash
git add dngrz/scenes/ui/batting_view.gd
git commit -m "feat(batting): magnitude-scaled break chevron (bend telegraph reaches the screen)"
```

---

## Task 8: AI batter reads the honest current-state projection (not the truth crossing)

Phase A feeds the AI batter `_flight.state_at_tick(_crossing_tick)` — the **true** bent crossing position — so against the new bend it is effectively clairvoyant and cannot be fooled, which would invalidate the Phase-B bend feel-test (spec §5: the AI must read the *same observable* the human sees, NOT `state_at_tick(crossing_tick)`). Fix it: extract the honest plate projection the human HUD already uses, and have the AI decide at a reaction tick before crossing from that drifting projection.

**Files:**
- Modify: `dngrz/src/game/at_bat_director.gd`
- Modify: `dngrz/test/test_at_bat_director.gd`

- [ ] **Step 1: Write the failing test (RED)**

Append to `dngrz/test/test_at_bat_director.gd`:

```gdscript
func test_project_to_plate_lags_the_late_bend() -> void:
	# At the AI's reaction tick, the honest projection of a bending pitch does NOT
	# reach the true crossing x (the late t^2 break hasn't expressed) — so bend can
	# fool the AI batter (spec §5: same observable as the human, not clairvoyant).
	var p := _pitch()
	p.bend = Vector2(0.4, 0.0)
	var flight := BallFlight.from_pitch(p)
	var ct := flight.crossing_tick()
	var read_tick := ct - AtBatDirector.AI_REACTION_TICKS
	var projected := AtBatDirector._project_to_plate(flight.state_at_tick(read_tick))
	var truth := flight.state_at_tick(ct).position
	assert_float(absf(projected.x - truth.x)).is_greater(0.02)
```

- [ ] **Step 2: Run the test — verify it fails**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: FAIL/ERROR — `AtBatDirector.AI_REACTION_TICKS` and `_project_to_plate` do not exist yet.

- [ ] **Step 3: Extract the projection helper and add the reaction constant**

In `dngrz/src/game/at_bat_director.gd`, add the constant near `LATE_FLIGHT_TICKS`:

```gdscript
# How many ticks before crossing the AI batter commits its read. It reads the same
# honest current-state projection the human sees AT this tick, so the late bend
# (which expresses after) can fool it (spec §5).
const AI_REACTION_TICKS := 8
```

Add the static projection helper (the same math `_present` uses inline today). Place it among the other functions:

```gdscript
# Honest current-state projection of a ball to the plate plane z=0 (gravity
# included). This is what the batter can INFER from the ball RIGHT NOW — it drifts
# as the late t^2 bend expresses and is NOT the clairvoyant truth-crossing.
static func _project_to_plate(bs: BallStateAtTick) -> Vector3:
	if absf(bs.velocity.z) <= 0.0001:
		return bs.position
	var tt := maxf(0.0, -bs.position.z / bs.velocity.z)
	return Vector3(
		bs.position.x + bs.velocity.x * tt,
		bs.position.y + bs.velocity.y * tt + 0.5 * BallTrajectory.GRAVITY.y * tt * tt,
		0.0)
```

Refactor `_present` to use the helper (no behavior change). Replace the inline projection block (the `var land := bs.position` … `_view.observable_landing = StrikeZone.get_plate_position(land)` lines) with:

```gdscript
			# Honest landing projection (the batter's read): current ball state → z=0.
			# NOT the clairvoyant truth-crossing.
			_view.observable_landing = StrikeZone.get_plate_position(_project_to_plate(bs))
```

- [ ] **Step 4: Feed the AI batter the honest projection at its reaction tick**

In `_collect_swing`, replace the `enable_batter_ai` branch so the AI decides at the reaction tick from the projected landing (not the truth crossing):

```gdscript
	if enable_batter_ai:
		if not _ai_swing_done and _batter_ai != null and _tick >= _crossing_tick - AI_REACTION_TICKS:
			# Read the honest, drifting projection from the CURRENT ball state — the
			# same thing the human sees — so the late bend can fool the AI (spec §5).
			var bs := _flight.state_at_tick(_tick)
			var observable := BallStateAtTick.new(_tick, _project_to_plate(bs), bs.velocity)
			var cmd: SwingCommand = _batter_ai.compute_command(observable, _crossing_tick, 0, 0, _ai_rng)
			_ai_swing_done = true
			if cmd != null:
				_swing = cmd  # latch; resolve uses commit_tick for timing
```

- [ ] **Step 5: Run the test + the director suite — verify green**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: PASS. The existing director cases (which use `enable_batter_ai = false`) are unaffected; the projection refactor is behavior-preserving for `observable_landing`.

- [ ] **Step 6: Watch the AI-vs-AI suites**

Run any suite that exercises a full AI at-bat (e.g. `res://test/test_deterministic_core.gd`). The AI batter now commits at `crossing - AI_REACTION_TICKS` reading a projection instead of on the first flight tick reading the truth — outcomes may shift. If a test asserted a specific AI-vs-AI outcome, update its expectation to the new (honest) behavior; do not revert the fix. (Defer the full run to Task 11 if isolated runs are green.)

- [ ] **Step 7: Commit**

```bash
git add dngrz/src/game/at_bat_director.gd dngrz/test/test_at_bat_director.gd
git commit -m "feat(batting): AI batter reads the honest drifting projection, not the truth crossing"
```

---

## Task 9: Input action + scene flip to human-pitches / AI-bats

Add the hold-to-charge action and flip the live scene so the human pitches against the AI batter (spec §7 Phase B). The DualSense uses the left stick to aim, a held button to charge (the stick then sets bend), and release to throw; keyboard keeps WASD aim + SPACE charge.

**Files:**
- Modify: `dngrz/project.godot`
- Modify: `dngrz/scenes/at_bat.tscn`

- [ ] **Step 1: Add the `pitch_charge` input action**

In `dngrz/project.godot`, inside the `[input]` section, add a `pitch_charge` action bound to keyboard SPACE (keycode 32) and joypad button 0 (cross/A — safe because the batter is AI when the human pitches, so it does not collide with `batter_swing`). Add after the `pitch_throw` block:

```
pitch_charge={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":0,"pressure":0.0,"pressed":false,"script":null)
]
}
```

(Leave the existing `pitch_throw` action in place — unused by the new controller but harmless.)

- [ ] **Step 2: Flip the scene roles + update the controls label**

In `dngrz/scenes/at_bat.tscn`, change the `AtBat` node's flags:

```
[node name="AtBat" type="Node3D"]
script = ExtResource("1_gate")
enable_pitcher_ai = false
enable_batter_ai = true
```

Update the `ControlsLabel` text to describe pitching:

```
text = "PITCH: 1-4 type | left stick / WASD aim | HOLD A (SPACE) to charge — stick sets bend — release to throw     (AI bats)"
```

- [ ] **Step 3: Import + sanity-run the live scene briefly**

`timeout 120 "$GODOT46" --headless --path dngrz --import`
Expected: clean import, no parse/resource errors.

- [ ] **Step 4: Commit**

```bash
git add dngrz/project.godot dngrz/scenes/at_bat.tscn
git commit -m "feat(pitching): pitch_charge action; flip live scene to human-pitches / AI-bats"
```

---

## Task 10: Pitching camera — behind the mound, looking in (human pitcher)

The behind-the-plate camera (Phase A, feel-test-passed) is the *batting* POV — looking at your own pitch through it reads backwards. When the human pitches, swing that single camera behind the mound looking in toward the plate. Pure presentation (eyeballed in the Task 11 feel-test); the scene's batting transform is left untouched and only overridden at runtime when the human pitches, so flipping the scene back to AI-pitches/human-bats restores the batting POV automatically.

**Files:**
- Modify: `dngrz/src/game/at_bat_director.gd`

- [ ] **Step 1: Add a guarded camera ref**

Near the other `@onready` node refs in `at_bat_director.gd` (e.g. after `_pitching_view`):

```gdscript
@onready var _camera: Camera3D = get_node_or_null("Camera")
```

- [ ] **Step 2: Reposition the camera for the human pitcher in `_ready`**

In `_ready()`, after the HUD-visibility block (the `_pitching_view.visible = ...` lines), add:

```gdscript
	# Camera POV: the scene's default transform is the feel-tested behind-the-plate
	# BATTING view. When the human pitches, swing the same camera behind the mound
	# looking in toward the plate so your own pitch reads correctly (presentation
	# only; the position/fov are feel-tuned in the Task 11 gate). look_at_from_position
	# avoids hand-building the basis and keeps "up" stable.
	if not enable_pitcher_ai and _camera != null:
		_camera.look_at_from_position(
			Vector3(0.0, 2.2, FieldConstants.MOUND.z - 2.5),  # behind the mound (more -Z)
			FieldConstants.STRIKE_ZONE_CENTER,                # look toward the plate (+Z)
			Vector3.UP)
		_camera.fov = 55.0
```

- [ ] **Step 3: Import + sanity-run**

`timeout 120 "$GODOT46" --headless --path dngrz --import`
Expected: clean import; no parse errors mentioning `at_bat_director.gd`. (The camera move is visual — confirmed in Task 11.)

- [ ] **Step 4: Commit**

```bash
git add dngrz/src/game/at_bat_director.gd
git commit -m "feat(pitching): mound-side pitching camera when the human pitches"
```

---

## Task 11: Full suite green + Phase B feel-test gate

**Files:** none (verification + manual feel-test).

- [ ] **Step 1: Import, then run the full gdUnit4 suite headless**

```bash
GODOT46=<path-to-godot-4.6>
timeout 120 "$GODOT46" --headless --path dngrz --import
timeout 300 "$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/
```

Expected: clean import; full suite GREEN, 0 failures. Report the new total (Phase A's baseline was ~181; this plan adds ~6 trajectory, ~2 flight, ~9 pitcher-controller, ~3 pitcher-AI, ~2 director cases).

- [ ] **Step 2: Fix any red tests from the ripple**

Likely sources: (a) any caller of `create_pitch` / `Decision` / `request_pitch` / `PitchCommand.new` (all kept backward-compatible via defaults — should be none); (b) an AI-vs-AI outcome test affected by the Task-8 AI-read change. Update such an expectation to the new honest behavior; do not revert. Re-run Step 1 until green. Commit:

```bash
git add -A
git commit -m "test(pitching): align remaining suites to Phase B pitcher"
```

- [ ] **Step 3: Headed feel-test — human pitches vs the AI batter (the gate)**

Run the game headed (DualSense). Aim, hold to charge, set bend with the stick, release. Evaluate:
- **PASS signals:** charging is a real risk/reward (release early = soft/safe/readable; nail the top band = fast + sharp; over-hold = wild meatball you can feel); a max-power heater is *faster* than the Phase-A baseline but still hittable; bend curves the ball late and legibly, and the AI batter can be **fooled** by it (it reacts to the drifting indicator, doesn't pre-snap to the truth); the batter-side break chevron visibly grows with bend; a no-charge "panic" pitch is still a serviceable strike.
- **FAIL signals (stop and reassess with the user, don't rationalize forward):** charge timing feels arbitrary/unreadable; max heater is unhittable (lower `MAX_POWER_SPEED_SCALE`); bend feels random rather than aimed; power collapses to one useful value (no reason to throw soft *or* max); the AI batter still looks clairvoyant (the Task-8 read didn't take) or helpless.
- **Camera (Task 10) — tune it here:** the view is now behind the mound looking in toward the plate. Confirm it reads correctly (you see your pitch travel away toward the AI batter/zone) and adjust the position/`fov` in `at_bat_director.gd` if the framing is off — the starting values (`z = MOUND.z - 2.5`, `y = 2.2`, `fov = 55`) are a guess. A FAIL signal here is the view being disorienting or hiding the ball's break.

- [ ] **Step 4: Record the verdict**

If PASS: note tuning observations (`CHARGE_TICKS`, `PERFECT_BAND`, `MIN_POWER`, `OVERHOLD_*`, `BEND_MAX`, `MIN_POWER_SPEED_SCALE`, `MAX_POWER_SPEED_SCALE`, `CUE_BEND_GAIN`, `AI_REACTION_TICKS`, and the camera position/`fov`) and proceed to plan Phase C (two-field roles, panic recenter, confidence cone, PHENOM hooks, balance tuning incl. fast+bend degeneracy). If FAIL: capture the specific feel failure and reassess the charge/bend model with the user before continuing.

---

## Self-Review (completed by the plan author, updated after the pre-execution cross-check)

**Spec coverage (§4, §5, §7 Phase B):**
- §4.1 sequence aim→lock→charge(+stick bend)→release — Task 3 (FSM) ✓
- §4.2 power→velocity (FASTER, less read-time), read-time floor via the `MAX_POWER_SPEED_SCALE` clamp (mapping clamped before trajectory build, not a tick floor), perfect-window tightens with power, over-hold decay — Tasks 1, 3. Exit-velo: **unchanged** — `ContactResolver` already scales by `ball_at_contact.velocity.length()`, so a faster pitch raises exit-velo through that single path (no resolver edit; avoids the double-count §4.2 forbids) ✓
- §4.3 release-time bend: snapshot in `PitchCommand.bend`, own analytic `t²` block, no z ⇒ identical crossing tick, `BallFlight` stays pure, `get_velocity` caveat documented, honest current-state landing indicator **kept** (now via the extracted `_project_to_plate` helper, behavior-preserving), magnitude-telegraphing cue **wired (Task 6) AND rendered (Task 7)** ✓
- §4.4 PHENOM — hook only, untouched (out of scope) ✓
- §5 roles: AI pitcher authors power+bend (Task 4); the human-pitches flip (Task 9); **AI batter reads the same honest observable, not the truth crossing (Task 8)** — closes the §5 "AI must not read truth the human can't" requirement ✓
- §6 changed files: `batting_view.gd` "magnitude-scaled break cue" — Task 7 ✓ (was the gap the cross-check caught)
- §7 Phase B: greenfield charge/window/power/bend + magnitude cue + flip to human-pitches/AI-bats — all tasks ✓
- **Pitching camera (Task 10):** added at the user's request — runtime override behind the mound; batting POV untouched. Presentation-only, eyeball-tuned in Task 11.

**Deferred to Phase C (correctly out of Phase B):** two-field role config, panic recenter, confidence cone, PHENOM behaviors, balance tuning (fast+bend degeneracy, spray trade values).

**Cross-check resolutions (2026-05-27):** power direction → spec-faithful max>today + floor (Task 1); break-magnitude telegraph → rendered (Task 7); AI clairvoyance → fixed (Task 8). Technical review found **no blockers** (class_name `PitcherController` is new — no collision; static helpers + consts callable as `PitcherController.X`; all `create_pitch`/`PitchCommand.new`/`Decision.new`/`request_pitch` callers backward-compatible; gdUnit4 assertion methods exist; anchors verified).

**Task-ordering correctness:** `PitcherController` pure helpers (Task 3) precede every reference (Tasks 4/5/6/8). `PitchingView.bend` (Task 5) precedes the typed `_pitching_view.bend` write (Task 6). `create_pitch` power/bend params (Task 1) precede the `from_pitch` passthrough (Task 2) and the controller/AI authors (Tasks 3/4). `_project_to_plate` + `AI_REACTION_TICKS` are defined and consumed within Task 8.

**Type consistency:** `PitcherController.{MIN_POWER, BEND_MAX, PERFECT_BAND, MEATBALL_ACCURACY, CHARGE_TICKS, power_for_charge, accuracy_for_charge, bend_from_stick, charge_for_ticks, build_release_command, current_charge, current_bend, get_selected_pitch, get_target, is_aiming, start_aiming, select_pitch, set_target}` consistent across Tasks 3/4/5/6/8. `create_pitch(type, target, accuracy, rng, power := 1.0, bend := Vector2.ZERO)` matches Tasks 1/2. `PitchCommand.new(type, target, power, accuracy, bend, tier, rng_seed, start_tick)` matches the struct across Tasks 3/4/6. `BallStateAtTick.new(tick, position, velocity)` matches Task 8. `AtBatDirector.{AI_REACTION_TICKS, _project_to_plate, CUE_BEND_GAIN}` consistent across Tasks 6/8 and the tests.

**One judgment call flagged for review:** the exact charge/bend **gesture** and `pitch_charge` binding (joypad cross / SPACE) are my choice — the spec defers the gesture to the feel-test (§4.1). All curve constants and the camera framing are starting points, tunable via the named constants in the Task 11 gate.
