# DNGRZ Deterministic Core & Contact Data-Flow Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, deterministic resolution core for the redesigned at-bat — fixed-tick timing, seeded RNG, serializable Command structs, the truth/observable split, and a corrected `ContactResolver` that finally measures the swing cursor against the ball's *actual* position.

**Architecture:** Every module added here is a pure data/math unit with no node state, no `delta`, no wall clock, and no global RNG — exactly the "one-way door" contracts from §9 of the spec. Resolution becomes a pure function of `(commands + seed + tick)`. Nothing in this plan builds a new playable loop or touches input; it lays the foundation the playable duel (Plan 2) and the thin-defense/delivery layer (Plan 3) sit on top of.

**Tech Stack:** Godot 4.6.3 (GDScript), gdUnit4 v6.2.0-rc0 for tests.

**Source spec:** `docs/superpowers/specs/2026-05-24-dngrz-core-mechanics-redesign.md` — this plan implements the foundation slice: §4 (contact model), §7 (read-vs-truth + plate-plane contact space), §8 (`predict_crossing`), and §9 contracts #1–#6 and #8.

---

## Scope of this plan (Plan 1 of 3)

**In scope** — pure modules + their unit tests:
- `SimClock` — fixed integer-tick time base (contract #4).
- `BallStateAtTick` — the batter-observable per-tick ball projection (contract #6, the read-vs-truth split).
- `SwingCommand`, `PitchCommand` — serializable, tick-stamped intent structs (contract #1).
- `PitchTypes` — add break-marker + tier fields (§8, §2).
- `BallTrajectory` — accept an explicit seeded RNG (contract #5) and gain an analytic `predict_crossing()` query (§8).
- `ContactResolver` — replaces `ContactCalculator`; receives ball state; corrected input precedence (§4). **This is the headline fix** (spec finding #3: spatial aim was never wired).

**Explicitly NOT in scope (deferred to Plan 2 / Plan 3):**
- The swing state machine in `BatterController`, `AtBatDirector`, replacing `scenes/_gate1.gd`, two-stick controls, the break-marker *renderer*, in-flight bend. (Plan 2.)
- `FieldAlignment`, `BattedBallResolver`, `PlayOutcome`, pitcher alignment shift + meter. (Plan 3.)
- ENet/RPC transport, server process, matchmaking. (Post-prototype.)

**Left untouched on purpose:** `scenes/_gate1.gd` keeps running on its current path and `src/core/contact_calculator.gd` stays in place (only a deprecation banner is added). Plan 2 removes both when `AtBatDirector` replaces the orchestrator. Wiring the new resolver into the old `await`-timer loop now would be throwaway code, so we don't.

---

## Conventions (read before starting any task)

**Godot project root is `dngrz/`** (not the repo root). All `res://` paths and the test command run from `/home/cner/Projects/dngrz/dngrz/`. Filesystem paths in this plan are written repo-root-relative (e.g. `dngrz/src/core/sim_clock.gd`).

**Running tests (headless, gdUnit4 v6):**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
# Warm-up: REQUIRED the first run after adding any new `class_name` module, or
# gdUnit4 SIGSEGVs because the global script-class cache hasn't picked it up.
timeout 120 "$GODOT46" --headless --path . --import
# Run a single suite (substitute the file):
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add res://test/test_sim_clock.gd
# Run the whole suite: replace the file with res://test/
```

- `--ignoreHeadlessMode` is mandatory (gdUnit4 v6 exits 103 without it).
- `res://` prefixes are required on both the tool path and the `--add` target.
- The `--remote-debug tcp://127.0.0.1:0` warning is benign.
- Each task that adds a new `class_name` includes the `--import` warm-up as its own step.

**GDScript gotchas confirmed on this project (do not relearn the hard way):**
- **Static-method shadowing:** on a `class_name`-only module (implicitly `RefCounted`), a `static func` whose name matches an inherited `Object` method (`get_name`, `get_position`, `get_velocity`, …) is unreachable via `ClassName.method()`. All names in this plan were chosen to avoid that. `BallTrajectory.predict_crossing` is safe (RefCounted has no such method).
- **`seed` is a global GDScript function.** `PitchCommand` stores it as `rng_seed` to avoid shadowing; the wire dict key is `"rng_seed"`. (Spec calls it "seed".)
- **Float/double edge precision:** `Vector3` components are single-precision; `FieldConstants` are doubles. `StrikeZone` already uses `const _EDGE_EPSILON := 0.0001`. Use approximate asserts at literal edges.
- **Signal payload asserts:** gdUnit4's `is_emitted("name")` does an exact arg compare; for signals carrying vectors use a lambda+flag callback instead. (Not needed in this plan — no signals are added — but noted for the suite.)

**Discipline:** TDD (test first, watch it fail, minimal code, watch it pass), DRY, YAGNI, one commit per task.

---

## File Structure

| File | Created/Modified | Responsibility |
|---|---|---|
| `dngrz/src/core/sim_clock.gd` | **Create** | Fixed tick-rate constant + tick↔seconds conversions. No state. |
| `dngrz/src/data/ball_state_at_tick.gd` | **Create** | Observable per-tick ball state `{tick, position, velocity}` + plate projection + dict (de)serialization. |
| `dngrz/src/data/swing_command.gd` | **Create** | Committed swing snapshot `{cursor_point, swing_type, placement_dir, commit_tick}` + `SwingType` enum + dict (de)serialization. |
| `dngrz/src/data/pitch_command.gd` | **Create** | Authoritative pitch intent (truth record) + dict (de)serialization. |
| `dngrz/src/core/contact_resolver.gd` | **Create** | Pure `resolve(SwingCommand, BallStateAtTick) -> ContactResult`; corrected §4 precedence. |
| `dngrz/src/data/pitch_types.gd` | Modify | Add `break_marker: Vector2`, `Tier` enum, `tier` field to `PitchData`. |
| `dngrz/src/ball/ball_trajectory.gd` | Modify | `create_pitch` takes explicit `rng`; add `CrossingPrediction` + `predict_crossing()`. |
| `dngrz/src/ball/ball.gd` | Modify | Update the single `create_pitch` call site to pass a randomized RNG. |
| `dngrz/src/core/contact_calculator.gd` | Modify | Add deprecation banner only (removed in Plan 2). |
| `dngrz/test/test_sim_clock.gd` | **Create** | Tests for `SimClock`. |
| `dngrz/test/test_ball_state_at_tick.gd` | **Create** | Tests for `BallStateAtTick`. |
| `dngrz/test/test_swing_command.gd` | **Create** | Tests for `SwingCommand`. |
| `dngrz/test/test_pitch_command.gd` | **Create** | Tests for `PitchCommand`. |
| `dngrz/test/test_contact_resolver.gd` | **Create** | Precedence-table tests for `ContactResolver`. |
| `dngrz/test/test_deterministic_core.gd` | **Create** | End-to-end same-seed reproducibility test. |
| `dngrz/test/test_pitch_types.gd` | Modify | Add break-marker / tier / duplicate tests. |
| `dngrz/test/test_ball_trajectory.gd` | Modify | Update call sites for the RNG param; new seeded-determinism + `predict_crossing` tests. |

---

## Task 1: SimClock — fixed-tick time base

**Files:**
- Create: `dngrz/src/core/sim_clock.gd`
- Test: `dngrz/test/test_sim_clock.gd`

- [ ] **Step 1: Write the failing test**

Create `dngrz/test/test_sim_clock.gd`:

```gdscript
class_name TestSimClock extends GdUnitTestSuite

func test_tick_rate_is_sixty() -> void:
	assert_int(SimClock.TICK_RATE).is_equal(60)

func test_ticks_to_seconds() -> void:
	assert_float(SimClock.ticks_to_seconds(60)).is_equal_approx(1.0, 0.0001)
	assert_float(SimClock.ticks_to_seconds(6)).is_equal_approx(0.1, 0.0001)

func test_seconds_to_ticks_rounds_to_nearest() -> void:
	assert_int(SimClock.seconds_to_ticks(1.0)).is_equal(60)
	assert_int(SimClock.seconds_to_ticks(0.1)).is_equal(6)
	assert_int(SimClock.seconds_to_ticks(0.108)).is_equal(6)

func test_round_trip_is_stable() -> void:
	assert_float(SimClock.ticks_to_seconds(SimClock.seconds_to_ticks(0.5))).is_equal_approx(0.5, 0.01)
```

- [ ] **Step 2: Warm up the class cache, then run the test to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_sim_clock.gd
```
Expected: FAIL — `SimClock` is not a known class / parse error.

- [ ] **Step 3: Write the minimal implementation**

Create `dngrz/src/core/sim_clock.gd`:

```gdscript
class_name SimClock

# Fixed-tick simulation clock (determinism contract #4). Gameplay time is
# measured in integer ticks, never wall-clock seconds. Presentation may
# interpolate between ticks; resolution never does. The advancing tick counter
# that drives the at-bat lives in AtBatDirector (Plan 2) — this module is just
# the rate constant and the conversions, so both single-player and the future
# server agree on the same integer time base.
const TICK_RATE := 60  # ticks per second

# Seconds for a tick count — for human-facing tuning values only.
static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / float(TICK_RATE)

# Nearest whole tick for a duration in seconds.
static func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * float(TICK_RATE)))
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_sim_clock.gd
```
Expected: PASS — 4 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/core/sim_clock.gd dngrz/test/test_sim_clock.gd
git commit -m "feat(core): add SimClock fixed-tick time base"
```

---

## Task 2: BallStateAtTick — the observable ball projection

**Files:**
- Create: `dngrz/src/data/ball_state_at_tick.gd`
- Test: `dngrz/test/test_ball_state_at_tick.gd`

- [ ] **Step 1: Write the failing test**

Create `dngrz/test/test_ball_state_at_tick.gd`:

```gdscript
class_name TestBallStateAtTick extends GdUnitTestSuite

func test_stores_fields() -> void:
	var s := BallStateAtTick.new(42, Vector3(0.1, 0.8, 0.0), Vector3(0.0, 0.0, 40.0))
	assert_int(s.tick).is_equal(42)
	assert_vector(s.position).is_equal(Vector3(0.1, 0.8, 0.0))
	assert_vector(s.velocity).is_equal(Vector3(0.0, 0.0, 40.0))

func test_plate_point_projects_xy() -> void:
	var s := BallStateAtTick.new(0, Vector3(0.2, 0.9, -1.0), Vector3.ZERO)
	assert_vector(s.plate_point()).is_equal(Vector2(0.2, 0.9))

func test_round_trips_through_dict() -> void:
	var s := BallStateAtTick.new(7, Vector3(0.1, 0.8, 0.0), Vector3(1.0, 2.0, 3.0))
	var r := BallStateAtTick.from_dict(s.to_dict())
	assert_int(r.tick).is_equal(7)
	assert_vector(r.position).is_equal(Vector3(0.1, 0.8, 0.0))
	assert_vector(r.velocity).is_equal(Vector3(1.0, 2.0, 3.0))
```

- [ ] **Step 2: Warm up + run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_state_at_tick.gd
```
Expected: FAIL — `BallStateAtTick` unknown.

- [ ] **Step 3: Write the minimal implementation**

Create `dngrz/src/data/ball_state_at_tick.gd`:

```gdscript
class_name BallStateAtTick

# The batter-observable projection of the ball at one simulation tick
# (spec §7, contract #6). This is the ONLY channel the batter reads the pitch
# through. It deliberately carries no pitch type, no authored target, and no
# seed — those live in PitchCommand (the hidden truth). Keeping them separate
# types makes the hidden-information boundary structural, not bolted on.
var tick: int
var position: Vector3
var velocity: Vector3

func _init(p_tick: int = 0, p_position: Vector3 = Vector3.ZERO, p_velocity: Vector3 = Vector3.ZERO) -> void:
	tick = p_tick
	position = p_position
	velocity = p_velocity

# Plate-plane projection (x = horizontal, y = height) used by ContactResolver.
# This is the fixed 2D contact space of spec §7 — independent of any camera.
func plate_point() -> Vector2:
	return Vector2(position.x, position.y)

func to_dict() -> Dictionary:
	return {"tick": tick, "position": position, "velocity": velocity}

static func from_dict(d: Dictionary) -> BallStateAtTick:
	return BallStateAtTick.new(d["tick"], d["position"], d["velocity"])
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_state_at_tick.gd
```
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/data/ball_state_at_tick.gd dngrz/test/test_ball_state_at_tick.gd
git commit -m "feat(data): add BallStateAtTick observable ball projection"
```

---

## Task 3: PitchTypes — break marker + tier

**Files:**
- Modify: `dngrz/src/data/pitch_types.gd`
- Test: `dngrz/test/test_pitch_types.gd` (extend)

This task comes before the Command structs because `PitchCommand` (Task 5) references `PitchTypes.Tier`.

- [ ] **Step 1: Write the failing tests**

Append to `dngrz/test/test_pitch_types.gd` (after the existing tests):

```gdscript
func test_pitches_have_break_markers() -> void:
	var curve := PitchTypes.get_pitch(PitchTypes.Type.CURVEBALL)
	assert_float(curve.break_marker.y).is_less(0.0)  # curve breaks downward
	var slider := PitchTypes.get_pitch(PitchTypes.Type.SLIDER)
	assert_float(slider.break_marker.x).is_less(0.0)  # slider sweeps glove-side

func test_all_pitches_are_basic_tier() -> void:
	for pitch_type in PitchTypes.Type.values():
		assert_int(PitchTypes.get_pitch(pitch_type).tier).is_equal(PitchTypes.Tier.BASIC)

func test_duplicate_preserves_new_fields() -> void:
	var a := PitchTypes.get_pitch(PitchTypes.Type.SLIDER)
	var b := a.duplicate()
	assert_vector(b.break_marker).is_equal(a.break_marker)
	assert_int(b.tier).is_equal(a.tier)
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_pitch_types.gd
```
Expected: FAIL — `break_marker` / `Tier` / `tier` do not exist.

- [ ] **Step 3: Write the implementation**

Replace the entire contents of `dngrz/src/data/pitch_types.gd` with:

```gdscript
class_name PitchTypes

enum Type {
	FASTBALL,
	CURVEBALL,
	SLIDER,
	CHANGEUP,
}

# Execution tier (spec §2). BASIC pitches use the meter; PHENOM gesture/combo
# pitches are out of scope, but the flag must exist now so that layer is purely
# additive. Single source of truth — PitchCommand reuses PitchTypes.Tier.
enum Tier {
	BASIC,
	PHENOM,
}

class PitchData:
	var speed: float          # meters per second
	var h_break: float        # horizontal break in meters (+ = arm side, - = glove side)
	var drop: float           # additional downward break in meters
	var accuracy: float       # base accuracy multiplier (0-1, higher = more forgiving)
	var break_marker: Vector2 # normalized in-flight break cue shown to the batter (spec §8);
	                          #   plate-plane convention: x = horizontal, +y = up. The honest,
	                          #   observable hint of "what's coming" — the renderer is Plan 2.
	var tier: PitchTypes.Tier

	func _init(p_speed: float, p_h_break: float, p_drop: float, p_accuracy: float,
			p_break_marker: Vector2 = Vector2.ZERO, p_tier: PitchTypes.Tier = PitchTypes.Tier.BASIC) -> void:
		speed = p_speed
		h_break = p_h_break
		drop = p_drop
		accuracy = p_accuracy
		break_marker = p_break_marker
		tier = p_tier

	func duplicate() -> PitchData:
		return PitchData.new(speed, h_break, drop, accuracy, break_marker, tier)

# Speeds in m/s (1 mph ~ 0.447 m/s)
# Fastball ~95mph=42.5m/s, Curve ~80mph=35.8m/s, Slider ~87mph=38.9m/s, Change ~83mph=37.0m/s
# break_marker is an exaggerated, normalized legibility cue (not raw physics):
#   fastball = slight rise, curve = straight down, slider = glove-side sweep,
#   changeup = arm-side fade + drop.
static var _pitches := {
	Type.FASTBALL:  PitchData.new(42.5, 0.05, 0.1, 0.85, Vector2(0.0, -0.2)),
	Type.CURVEBALL: PitchData.new(35.8, 0.1, 0.6, 0.70, Vector2(0.0, -1.0)),
	Type.SLIDER:    PitchData.new(38.9, -0.4, 0.2, 0.75, Vector2(-1.0, -0.3)),
	Type.CHANGEUP:  PitchData.new(37.0, 0.15, 0.15, 0.80, Vector2(0.3, -0.5)),
}

static func get_pitch(pitch_type: Type) -> PitchData:
	return _pitches[pitch_type].duplicate()

static func display_name(pitch_type: Type) -> String:
	match pitch_type:
		Type.FASTBALL: return "Fastball"
		Type.CURVEBALL: return "Curveball"
		Type.SLIDER: return "Slider"
		Type.CHANGEUP: return "Changeup"
	return "Unknown"
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_pitch_types.gd
```
Expected: PASS — original 7 tests plus 3 new ones green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/data/pitch_types.gd dngrz/test/test_pitch_types.gd
git commit -m "feat(data): add break_marker and tier to PitchTypes"
```

---

## Task 4: SwingCommand — committed swing snapshot

**Files:**
- Create: `dngrz/src/data/swing_command.gd`
- Test: `dngrz/test/test_swing_command.gd`

- [ ] **Step 1: Write the failing test**

Create `dngrz/test/test_swing_command.gd`:

```gdscript
class_name TestSwingCommand extends GdUnitTestSuite

func test_defaults_to_contact_up_the_middle() -> void:
	var c := SwingCommand.new()
	assert_int(c.swing_type).is_equal(SwingCommand.SwingType.CONTACT)
	assert_vector(c.placement_dir).is_equal(Vector2.ZERO)
	assert_int(c.commit_tick).is_equal(0)

func test_stores_power_swing() -> void:
	var c := SwingCommand.new(Vector2(0.1, 0.8), SwingCommand.SwingType.POWER, Vector2(0.5, -0.5), 120)
	assert_int(c.swing_type).is_equal(SwingCommand.SwingType.POWER)
	assert_int(c.commit_tick).is_equal(120)
	assert_vector(c.cursor_point).is_equal(Vector2(0.1, 0.8))

func test_round_trips_through_dict() -> void:
	var c := SwingCommand.new(Vector2(0.1, 0.8), SwingCommand.SwingType.POWER, Vector2(0.5, -0.5), 120)
	var r := SwingCommand.from_dict(c.to_dict())
	assert_vector(r.cursor_point).is_equal(Vector2(0.1, 0.8))
	assert_int(r.swing_type).is_equal(SwingCommand.SwingType.POWER)
	assert_vector(r.placement_dir).is_equal(Vector2(0.5, -0.5))
	assert_int(r.commit_tick).is_equal(120)
```

- [ ] **Step 2: Warm up + run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_swing_command.gd
```
Expected: FAIL — `SwingCommand` unknown.

- [ ] **Step 3: Write the minimal implementation**

Create `dngrz/src/data/swing_command.gd`:

```gdscript
class_name SwingCommand

# A committed swing, snapshotted at the commit tick (spec §5, contract #1).
# Serializable, tick-stamped, carries no node state. The swing FSM (Plan 2)
# produces it from input; ContactResolver consumes it. Both the human and the
# AI batter emit this same struct — there is exactly one commit path.
enum SwingType {
	CONTACT,  # tap: larger effective contact zone, less power
	POWER,    # hold: contact zone shrinks, more power
}

var cursor_point: Vector2   # plate-plane (x = horizontal, y = height) cursor at commit
var swing_type: SwingType
var placement_dir: Vector2  # latched directional intent: x = spray (- pull / + oppo),
                            #   y = trajectory (- ground / + fly); (0,0) = up-the-middle line drive
var commit_tick: int        # the tick the swing button went DOWN — the timing reference (spec §5 latch rule)

func _init(
		p_cursor: Vector2 = Vector2.ZERO,
		p_swing_type: SwingType = SwingType.CONTACT,
		p_placement: Vector2 = Vector2.ZERO,
		p_commit_tick: int = 0) -> void:
	cursor_point = p_cursor
	swing_type = p_swing_type
	placement_dir = p_placement
	commit_tick = p_commit_tick

func to_dict() -> Dictionary:
	return {
		"cursor_point": cursor_point,
		"swing_type": int(swing_type),
		"placement_dir": placement_dir,
		"commit_tick": commit_tick,
	}

static func from_dict(d: Dictionary) -> SwingCommand:
	return SwingCommand.new(d["cursor_point"], d["swing_type"], d["placement_dir"], d["commit_tick"])
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_swing_command.gd
```
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/data/swing_command.gd dngrz/test/test_swing_command.gd
git commit -m "feat(data): add SwingCommand committed-swing struct"
```

---

## Task 5: PitchCommand — authoritative pitch intent (truth record)

**Files:**
- Create: `dngrz/src/data/pitch_command.gd`
- Test: `dngrz/test/test_pitch_command.gd`

Depends on `PitchTypes.Tier` (Task 3).

- [ ] **Step 1: Write the failing test**

Create `dngrz/test/test_pitch_command.gd`:

```gdscript
class_name TestPitchCommand extends GdUnitTestSuite

func test_defaults() -> void:
	var c := PitchCommand.new()
	assert_int(c.type).is_equal(PitchTypes.Type.FASTBALL)
	assert_int(c.tier).is_equal(PitchTypes.Tier.BASIC)
	assert_float(c.power).is_equal_approx(1.0, 0.0001)
	assert_int(c.start_tick).is_equal(0)

func test_stores_fields() -> void:
	var c := PitchCommand.new(PitchTypes.Type.SLIDER, Vector3(0.1, 0.6, 0.0), 0.8, 0.75,
		Vector2(0.2, -0.1), PitchTypes.Tier.BASIC, 4242, 30)
	assert_int(c.type).is_equal(PitchTypes.Type.SLIDER)
	assert_int(c.rng_seed).is_equal(4242)
	assert_int(c.start_tick).is_equal(30)
	assert_vector(c.bend).is_equal(Vector2(0.2, -0.1))

func test_round_trips_through_dict() -> void:
	var c := PitchCommand.new(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.7, 0.0), 0.9, 0.7,
		Vector2(0.1, 0.0), PitchTypes.Tier.PHENOM, 99, 12)
	var r := PitchCommand.from_dict(c.to_dict())
	assert_int(r.type).is_equal(PitchTypes.Type.CURVEBALL)
	assert_float(r.power).is_equal_approx(0.9, 0.0001)
	assert_float(r.accuracy).is_equal_approx(0.7, 0.0001)
	assert_int(r.tier).is_equal(PitchTypes.Tier.PHENOM)
	assert_int(r.rng_seed).is_equal(99)
	assert_int(r.start_tick).is_equal(12)
	assert_vector(r.target).is_equal(Vector3(0.0, 0.7, 0.0))
```

- [ ] **Step 2: Warm up + run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_pitch_command.gd
```
Expected: FAIL — `PitchCommand` unknown.

- [ ] **Step 3: Write the minimal implementation**

Create `dngrz/src/data/pitch_command.gd`:

```gdscript
class_name PitchCommand

# Authored pitch intent — the authoritative TRUTH record (spec §7). NEVER
# delivered in full to the batter, who only ever sees BallStateAtTick. Keeping
# PitchCommand and BallStateAtTick as distinct types makes the hidden-info /
# network-authority boundary structural. Serializable + tick-stamped (#1).
#
# `power`, `bend`, and `tier` are carried now but only consumed in Plan 3
# (pitcher meter + in-flight bend + Phenom layer). Wiring them in here keeps
# those later layers additive — no struct rewrite.
#
# Spec calls the seed field "seed"; stored as `rng_seed` to avoid shadowing the
# global GDScript `seed()` function.

var type: PitchTypes.Type
var target: Vector3   # intended plate-plane crossing location
var power: float      # 0..1 (exit-velocity ceiling contribution, Plan 3); 1.0 = full
var accuracy: float   # 0..1; lower widens seeded inaccuracy in BallTrajectory
var bend: Vector2     # in-flight steer intent (reserved, Plan 3)
var tier: PitchTypes.Tier
var rng_seed: int     # at-bat RNG seed — part of the truth record
var start_tick: int   # the tick the pitch was released

func _init(
		p_type: PitchTypes.Type = PitchTypes.Type.FASTBALL,
		p_target: Vector3 = FieldConstants.STRIKE_ZONE_CENTER,
		p_power: float = 1.0,
		p_accuracy: float = 1.0,
		p_bend: Vector2 = Vector2.ZERO,
		p_tier: PitchTypes.Tier = PitchTypes.Tier.BASIC,
		p_rng_seed: int = 0,
		p_start_tick: int = 0) -> void:
	type = p_type
	target = p_target
	power = p_power
	accuracy = p_accuracy
	bend = p_bend
	tier = p_tier
	rng_seed = p_rng_seed
	start_tick = p_start_tick

func to_dict() -> Dictionary:
	return {
		"type": int(type),
		"target": target,
		"power": power,
		"accuracy": accuracy,
		"bend": bend,
		"tier": int(tier),
		"rng_seed": rng_seed,
		"start_tick": start_tick,
	}

static func from_dict(d: Dictionary) -> PitchCommand:
	return PitchCommand.new(d["type"], d["target"], d["power"], d["accuracy"],
		d["bend"], d["tier"], d["rng_seed"], d["start_tick"])
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_pitch_command.gd
```
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/data/pitch_command.gd dngrz/test/test_pitch_command.gd
git commit -m "feat(data): add PitchCommand authoritative truth record"
```

---

## Task 6: BallTrajectory — explicit seeded RNG

**Files:**
- Modify: `dngrz/src/ball/ball_trajectory.gd:30-58` (`create_pitch`)
- Modify: `dngrz/src/ball/ball.gd:10-15` (`throw_pitch` call site)
- Test: `dngrz/test/test_ball_trajectory.gd` (rewrite — call sites change + new determinism tests)

Determinism contract #5: no resolution-relevant code may call global `randf*`. `create_pitch` currently calls `randf_range` directly. We make the RNG an explicit required parameter so the seed can flow from `PitchCommand.rng_seed` (in Plan 2's director) and so the same seed always reproduces the same pitch.

- [ ] **Step 1: Rewrite the test file with updated call sites + new determinism tests**

Replace the entire contents of `dngrz/test/test_ball_trajectory.gd` with:

```gdscript
class_name TestBallTrajectory extends GdUnitTestSuite

# A seeded RNG so trajectory tests are deterministic. create_pitch now requires
# an explicit RNG (determinism contract #5).
func _seeded_rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_pitch_starts_at_mound() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var start := traj.get_position(0.0)
	assert_float(start.distance_to(FieldConstants.MOUND)).is_less(2.0)

func test_pitch_reaches_plate() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var at_plate := traj.get_position(traj.flight_duration)
	assert_float(at_plate.z).is_equal_approx(0.0, 1.0)

func test_pitch_flight_is_playable() -> void:
	# Raw MLB physics puts a fastball at the plate in ~0.44s — unhittable. Flight
	# must be slowed into a readable swing window. Guards against regression.
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	assert_float(fb.flight_duration).is_greater(0.8)
	assert_float(fb.flight_duration).is_less(2.0)

func test_fastball_arrives_faster_than_changeup() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var ch := BallTrajectory.create_pitch(PitchTypes.Type.CHANGEUP, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	assert_float(fb.flight_duration).is_less(ch.flight_duration)

func test_curveball_drops_more() -> void:
	var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var cv := BallTrajectory.create_pitch(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.8, 0.0), 1.0, _seeded_rng())
	var fb_end := fb.get_position(fb.flight_duration)
	var cv_end := cv.get_position(cv.flight_duration)
	assert_float(cv_end.y).is_less(fb_end.y)

func test_batted_ball_trajectory_goes_forward() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0), 40.0, 25.0, 0.0)
	var mid := traj.get_position(1.0)
	assert_float(mid.z).is_less(0.0)

func test_batted_ball_goes_up_then_down() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0), 40.0, 30.0, 0.0)
	var mid := traj.get_position(1.0)
	var late := traj.get_position(3.5)
	assert_float(mid.y).is_greater(1.0)
	assert_float(late.y).is_less(mid.y)

func test_ground_ball_stays_low() -> void:
	var traj := BallTrajectory.create_batted(FieldConstants.HOME_PLATE + Vector3(0, 0.5, 0), 30.0, -5.0, 10.0)
	var pos := traj.get_position(0.5)
	assert_float(pos.y).is_less(1.0)

# --- Seeded RNG determinism (contract #5) ---

func test_accuracy_one_is_deterministic_regardless_of_seed() -> void:
	# At accuracy 1.0 there is zero inaccuracy jitter, so the seed is irrelevant.
	var a := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(1))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng(999))
	assert_vector(a.spin_break).is_equal(b.spin_break)

func test_same_seed_reproduces_trajectory() -> void:
	var a := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(7))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(7))
	assert_vector(a.spin_break).is_equal(b.spin_break)

func test_different_seeds_diverge_at_low_accuracy() -> void:
	var a := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(1))
	var b := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 0.0, _seeded_rng(2))
	assert_bool(a.spin_break.is_equal_approx(b.spin_break)).is_false()
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_trajectory.gd
```
Expected: FAIL — `create_pitch` is still the 3-arg version; the 4-arg calls error, and the new determinism tests fail.

- [ ] **Step 3: Update `create_pitch` to take an explicit RNG**

In `dngrz/src/ball/ball_trajectory.gd`, replace the `create_pitch` function (currently lines 30–58) with:

```gdscript
static func create_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float, rng: RandomNumberGenerator) -> BallTrajectory:
	var traj := BallTrajectory.new()
	traj.is_pitch = true

	var pitch_data := PitchTypes.get_pitch(pitch_type)
	traj.start_position = FieldConstants.MOUND + Vector3(0.0, 1.8, 0.0)  # release point

	# Flight time based on speed and distance, slowed by PITCH_TIME_SCALE so the
	# swing window is human-readable (bare realism is ~0.44s — unhittable).
	var distance := traj.start_position.distance_to(target)
	traj.flight_duration = (distance / pitch_data.speed) * PITCH_TIME_SCALE

	# Initial velocity to reach target (accounting for gravity).
	# target = start + v*t + 0.5*g*t^2  =>  v = (target - start - 0.5*g*t^2) / t
	var t := traj.flight_duration
	traj.initial_velocity = (target - traj.start_position - 0.5 * GRAVITY * t * t) / t

	# Apply break as spin deviation (not baked into initial velocity)
	traj.spin_break = Vector3(pitch_data.h_break, -pitch_data.drop, 0.0)

	# Accuracy adds deviation to where the pitch lands. The RNG is passed in
	# explicitly (determinism contract #5) so the same seed reproduces the same
	# pitch — no global randf in any resolution-relevant path.
	var inaccuracy := (1.0 - accuracy) * 0.15
	traj.spin_break += Vector3(
		rng.randf_range(-inaccuracy, inaccuracy),
		rng.randf_range(-inaccuracy, inaccuracy),
		0.0
	)

	return traj
```

- [ ] **Step 4: Update the one call site in `ball.gd`**

In `dngrz/src/ball/ball.gd`, replace `throw_pitch` (currently lines 10–15) with:

```gdscript
func throw_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
	# Ball is a pure VIEW of a trajectory. The legacy _gate1 loop is not the
	# deterministic path, so it uses a randomized RNG here. Plan 2's AtBatDirector
	# will pass a seeded RNG derived from PitchCommand.rng_seed instead.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_trajectory = BallTrajectory.create_pitch(pitch_type, target, accuracy, rng)
	position = _trajectory.start_position
	_time = 0.0
	_active = true
	visible = true
```

- [ ] **Step 5: Run the trajectory suite to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_trajectory.gd
```
Expected: PASS — 11 tests green.

- [ ] **Step 6: Run `test_ball.gd` to confirm the view still works**

`ball.gd`'s `throw_pitch` signature is unchanged, so `test_ball.gd` should still pass untouched:

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball.gd
```
Expected: PASS — 5 tests green.

- [ ] **Step 7: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/ball/ball_trajectory.gd dngrz/src/ball/ball.gd dngrz/test/test_ball_trajectory.gd
git commit -m "refactor(ball): create_pitch takes explicit seeded RNG (determinism #5)"
```

---

## Task 7: BallTrajectory — analytic `predict_crossing()`

**Files:**
- Modify: `dngrz/src/ball/ball_trajectory.gd` (add inner class + method)
- Test: `dngrz/test/test_ball_trajectory.gd` (extend)

§8: the break marker (and Plan 2's contact sampling) must reflect *predicted* movement, not the current cheat of drawing the authored target. §9 wants the crossing addressable by tick. The z-motion has no gravity or break component, so the crossing time is exact.

- [ ] **Step 1: Write the failing tests**

Append to `dngrz/test/test_ball_trajectory.gd`:

```gdscript
func test_predict_crossing_reaches_plate_plane() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(c.position.z).is_equal_approx(0.0, 0.01)

func test_predict_crossing_time_matches_flight_duration() -> void:
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(c.time).is_equal_approx(traj.flight_duration, 0.05)

func test_predict_crossing_includes_break() -> void:
	# Slider sweeps glove-side, so the crossing x is pulled off the authored
	# target x (0.0) by the spin break — proving the query reflects movement.
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0, 0.8, 0), 1.0, _seeded_rng())
	var c := traj.predict_crossing(0.0)
	assert_float(absf(c.position.x)).is_greater(0.05)
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_trajectory.gd
```
Expected: FAIL — `predict_crossing` does not exist.

- [ ] **Step 3: Add the inner class and method**

In `dngrz/src/ball/ball_trajectory.gd`, add the `CrossingPrediction` inner class directly below the member-variable declarations (after `var is_pitch: bool`), and add the `predict_crossing` method below the existing `get_velocity` function:

```gdscript
# Result of predict_crossing(): where and when the ball crosses a plate plane.
class CrossingPrediction:
	var position: Vector3
	var time: float

	func _init(p_position: Vector3, p_time: float) -> void:
		position = p_position
		time = p_time
```

```gdscript
# Analytic plate-plane crossing (spec §8). The z-motion is linear
# (z(t) = start.z + vz*t — gravity and spin-break have no z-component), so the
# crossing time is exact and the caller can address it by tick via SimClock.
# Pure: no node state, no clock, no RNG. The returned position INCLUDES break.
func predict_crossing(plane_z: float = 0.0) -> CrossingPrediction:
	var vz := initial_velocity.z
	if absf(vz) < 0.0001:
		return CrossingPrediction.new(get_position(flight_duration), flight_duration)
	var t := (plane_z - start_position.z) / vz
	if t < 0.0:
		t = flight_duration
	return CrossingPrediction.new(get_position(t), t)
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_ball_trajectory.gd
```
Expected: PASS — 14 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/ball/ball_trajectory.gd dngrz/test/test_ball_trajectory.gd
git commit -m "feat(ball): add analytic predict_crossing query (spec §8)"
```

---

## Task 8: ContactResolver — the corrected contact model (headline fix)

**Files:**
- Create: `dngrz/src/core/contact_resolver.gd`
- Test: `dngrz/test/test_contact_resolver.gd`

Replaces `ContactCalculator`. The old model measured placement against the *zone center*, hardcoded pitch speed, and derived spray from timing (`h_angle = timing × factor`) — directly fighting stick-at-contact placement. `ContactResolver` instead **receives the ball's actual state** and applies the §4 precedence:

| Input | Governs |
|---|---|
| cursor vs. actual ball | whiff vs. contact + base quality |
| swing timing | quality + a small natural pull/oppo lean |
| directional placement (latched) | **authoritative** intended spray + trajectory |
| tap vs. hold | power output + contact-zone size |

Poor overlap or poor timing degrades the realized result toward weak contact *regardless of* directional intent — intent is honored only to the degree the swing was well executed.

- [ ] **Step 1: Write the failing tests**

Create `dngrz/test/test_contact_resolver.gd`:

```gdscript
class_name TestContactResolver extends GdUnitTestSuite

const TICK := 100

# Ball sitting on the plate at zone center, moving toward home at `speed`.
func _ball(pos := Vector3(0.0, 0.8, 0.0), speed := 40.0, tick := TICK) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, speed))

# A swing whose cursor sits exactly on the ball, committed exactly on the
# crossing tick (perfect timing) unless overridden.
func _swing(cursor := Vector2(0.0, 0.8), type := SwingCommand.SwingType.CONTACT,
		placement := Vector2.ZERO, commit := TICK) -> SwingCommand:
	return SwingCommand.new(cursor, type, placement, commit)

func test_perfect_contact_is_high_quality() -> void:
	var r := ContactResolver.resolve(_swing(), _ball())
	assert_bool(r.is_whiff).is_false()
	assert_float(r.quality).is_greater(0.9)

func test_cursor_far_from_ball_whiffs() -> void:
	var r := ContactResolver.resolve(_swing(Vector2(0.5, 0.8)), _ball())
	assert_bool(r.is_whiff).is_true()

func test_power_zone_is_smaller_than_contact_zone() -> void:
	# Cursor 0.15m off the ball: contacts on a CONTACT swing, whiffs on POWER.
	var off := Vector2(0.15, 0.8)
	var contact := ContactResolver.resolve(_swing(off, SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(off, SwingCommand.SwingType.POWER), _ball())
	assert_bool(contact.is_whiff).is_false()
	assert_bool(power.is_whiff).is_true()

func test_power_swing_hits_harder_than_contact() -> void:
	var contact := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.POWER), _ball())
	assert_float(power.exit_velocity).is_greater(contact.exit_velocity)

func test_placement_dir_x_sets_spray() -> void:
	var pull := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(-1.0, 0.0)), _ball())
	var oppo := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(1.0, 0.0)), _ball())
	assert_float(pull.h_angle).is_less(0.0)
	assert_float(oppo.h_angle).is_greater(0.0)

func test_placement_dir_y_sets_trajectory() -> void:
	var grounder := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(0.0, -1.0)), _ball())
	var fly := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2(0.0, 1.0)), _ball())
	assert_float(fly.launch_angle).is_greater(grounder.launch_angle)

func test_early_timing_adds_pull_lean() -> void:
	# Commit 6 ticks before the crossing = 0.1s early -> pull (negative h_angle).
	var early := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK - 6), _ball())
	assert_float(early.h_angle).is_less(0.0)

func test_late_timing_adds_oppo_lean() -> void:
	var late := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 6), _ball())
	assert_float(late.h_angle).is_greater(0.0)

func test_poor_timing_reduces_quality() -> void:
	var perfect := ContactResolver.resolve(_swing(), _ball())
	var mistimed := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 5), _ball())
	assert_float(mistimed.quality).is_less(perfect.quality)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 35.0))
	var fast := ContactResolver.resolve(_swing(), _ball(Vector3(0.0, 0.8, 0.0), 45.0))
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)

func test_gross_mistiming_whiffs() -> void:
	# 18 ticks = 0.3s late, beyond the whiff window.
	var r := ContactResolver.resolve(_swing(Vector2(0.0, 0.8), SwingCommand.SwingType.CONTACT, Vector2.ZERO, TICK + 18), _ball())
	assert_bool(r.is_whiff).is_true()

func test_resolution_is_deterministic() -> void:
	var a := ContactResolver.resolve(_swing(Vector2(0.05, 0.82), SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	var b := ContactResolver.resolve(_swing(Vector2(0.05, 0.82), SwingCommand.SwingType.POWER, Vector2(0.3, -0.4), TICK + 3), _ball())
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.h_angle).is_equal(b.h_angle)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
```

- [ ] **Step 2: Warm up + run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_contact_resolver.gd
```
Expected: FAIL — `ContactResolver` unknown.

- [ ] **Step 3: Write the implementation**

Create `dngrz/src/core/contact_resolver.gd`:

```gdscript
class_name ContactResolver

# Replaces ContactCalculator. The headline fix (spec finding #3): this resolver
# RECEIVES the ball's actual state at the contact plane and measures the cursor
# against where the ball really is — spatial aim is finally wired. It is a pure
# function of (SwingCommand, BallStateAtTick): no node state, no delta, no wall
# clock, no global RNG (determinism contracts #2, #3).
#
# Precedence (spec §4):
#   cursor vs. actual ball  -> whiff vs. contact + base quality
#   swing timing            -> quality + a small natural pull/oppo lean
#   directional placement   -> AUTHORITATIVE intended spray + trajectory
#   tap vs. hold            -> power output + contact-zone size

const TIMING_WINDOW := 0.10          # s; |offset| beyond this rapidly loses quality
const TIMING_WHIFF := 0.20           # s; |offset| beyond this is an automatic whiff
const CONTACT_ZONE_RADIUS := 0.18    # m; cursor-vs-ball tolerance for a tap (contact) swing
const POWER_ZONE_RADIUS := 0.11      # m; smaller tolerance for a hold (power) swing

const CONTACT_EXIT_VELOCITY := 32.0  # m/s base exit velo, contact swing, perfect quality
const POWER_EXIT_VELOCITY := 42.0    # m/s base exit velo, power swing, perfect quality
const PITCH_SPEED_FACTOR := 0.3      # incoming-speed contribution to exit velo

const GROUND_LAUNCH := -5.0          # deg; placement_dir.y = -1 (down -> grounder)
const FLY_LAUNCH := 45.0             # deg; placement_dir.y = +1 (up -> fly ball)
const MISHIT_LAUNCH := 8.0           # deg; what low-quality contact degrades toward
const SPRAY_MAX := 35.0              # deg; placement_dir.x = +/-1 -> oppo / pull
const TIMING_LEAN := 60.0            # deg per second of timing offset (natural pull/oppo)

class ContactResult:
	var is_whiff: bool
	var quality: float          # 0.0 to 1.0
	var exit_velocity: float    # m/s
	var launch_angle: float     # degrees from horizontal
	var h_angle: float          # degrees (0 = center, - = pull, + = oppo)

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0

static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
	var result := ContactResult.new()

	# Timing from exact tick math (spec §9), never a wall clock. Early = negative.
	var timing_offset := SimClock.ticks_to_seconds(swing.commit_tick - ball_at_contact.tick)

	# Cursor vs. the ACTUAL ball at the plate plane (the headline fix).
	var placement_offset := swing.cursor_point - ball_at_contact.plate_point()
	var placement_dist := placement_offset.length()

	# Tap = bigger zone / less power; hold = smaller zone / more power (spec §4).
	var is_power := swing.swing_type == SwingCommand.SwingType.POWER
	var zone_radius := POWER_ZONE_RADIUS if is_power else CONTACT_ZONE_RADIUS

	# Whiff: swung where the ball isn't, or grossly mistimed.
	if placement_dist > zone_radius or absf(timing_offset) > TIMING_WHIFF:
		result.is_whiff = true
		return result
	result.is_whiff = false

	# Quality: how well the cursor overlapped the ball AND how well it was timed.
	var overlap_q := clampf(1.0 - placement_dist / zone_radius, 0.0, 1.0)
	var timing_q := clampf(1.0 - absf(timing_offset) / TIMING_WINDOW, 0.0, 1.0)
	result.quality = 0.5 * overlap_q + 0.5 * timing_q
	result.quality = result.quality * result.quality  # quadratic falloff for sharper feel

	# Power output (tap vs hold), scaled by incoming speed and quality.
	var pitch_speed := ball_at_contact.velocity.length()
	var base_exit := POWER_EXIT_VELOCITY if is_power else CONTACT_EXIT_VELOCITY
	result.exit_velocity = (base_exit + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	# Trajectory: placement_dir.y is AUTHORITATIVE intent; quality decides how
	# faithfully it is realized (poor contact degrades toward a flat mishit).
	var intended_launch := remap(clampf(swing.placement_dir.y, -1.0, 1.0), -1.0, 1.0, GROUND_LAUNCH, FLY_LAUNCH)
	result.launch_angle = lerpf(MISHIT_LAUNCH, intended_launch, result.quality)
	result.launch_angle = clampf(result.launch_angle, -10.0, 60.0)

	# Spray: placement_dir.x is AUTHORITATIVE; a small natural timing lean is
	# added (early -> pull, late -> oppo). Intent honored to the degree executed.
	var intended_spray := clampf(swing.placement_dir.x, -1.0, 1.0) * SPRAY_MAX
	var timing_lean := timing_offset * TIMING_LEAN
	result.h_angle = lerpf(0.0, intended_spray, result.quality) + timing_lean
	result.h_angle = clampf(result.h_angle, -45.0, 45.0)

	return result
```

- [ ] **Step 4: Run to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_contact_resolver.gd
```
Expected: PASS — 12 tests green.

- [ ] **Step 5: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/src/core/contact_resolver.gd dngrz/test/test_contact_resolver.gd
git commit -m "feat(core): add ContactResolver with ball-state-aware contact model (spec §4)"
```

---

## Task 9: End-to-end determinism proof + deprecate ContactCalculator

**Files:**
- Create: `dngrz/test/test_deterministic_core.gd`
- Modify: `dngrz/src/core/contact_calculator.gd` (deprecation banner only)

This ties the whole core together: seed → trajectory → predicted crossing → `BallStateAtTick` → `ContactResolver`, and proves the same seed yields a bit-identical result (contract #2). It also confirms the pieces compose with the types they actually exposed.

- [ ] **Step 1: Write the failing test**

Create `dngrz/test/test_deterministic_core.gd`:

```gdscript
class_name TestDeterministicCore extends GdUnitTestSuite

# Same seed + same commands => identical contact result, proving the core is a
# pure function of (commands + seed + tick) (spec §9 contract #2). This is the
# property that makes the future authoritative-server netcode an additive layer
# rather than a rewrite.
func _resolve_once(seed_value: int) -> ContactResolver.ContactResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var traj := BallTrajectory.create_pitch(PitchTypes.Type.SLIDER, Vector3(0.1, 0.8, 0.0), 0.6, rng)
	var crossing := traj.predict_crossing(0.0)
	var crossing_tick := SimClock.seconds_to_ticks(crossing.time)
	var ball_at_contact := BallStateAtTick.new(crossing_tick, crossing.position, traj.get_velocity(crossing.time))
	# A batter who reads it perfectly: cursor on the predicted crossing, on-tick.
	var plate := Vector2(crossing.position.x, crossing.position.y)
	var swing := SwingCommand.new(plate, SwingCommand.SwingType.POWER, Vector2(0.2, 0.3), crossing_tick)
	return ContactResolver.resolve(swing, ball_at_contact)

func test_same_seed_same_result() -> void:
	var a := _resolve_once(12345)
	var b := _resolve_once(12345)
	assert_bool(a.is_whiff).is_equal(b.is_whiff)
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
	assert_float(a.h_angle).is_equal(b.h_angle)

func test_pipeline_produces_contact_for_a_perfect_read() -> void:
	var r := _resolve_once(12345)
	assert_bool(r.is_whiff).is_false()
	assert_float(r.exit_velocity).is_greater(0.0)
```

- [ ] **Step 2: Warm up + run to verify it fails**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_deterministic_core.gd
```
Expected: FAIL — the suite errors until the file is recognized; once recognized the assertions run.

> If `test_pipeline_produces_contact_for_a_perfect_read` fails because the perfect-read swing whiffs, the seeded crossing drifted outside the POWER zone — switch that helper's swing to `SwingCommand.SwingType.CONTACT` (the bigger zone). `test_same_seed_same_result` is the load-bearing test and does not depend on contact-vs-whiff.

- [ ] **Step 3: Add the deprecation banner to ContactCalculator**

`ContactCalculator` is intentionally left in place so `scenes/_gate1.gd` keeps running until Plan 2 replaces the orchestrator. Add a banner at the top of `dngrz/src/core/contact_calculator.gd` so no new code is built on it. Replace the existing first three lines:

```gdscript
class_name ContactCalculator

# Tuning constants — Gate 1 will revisit these.
```

with:

```gdscript
class_name ContactCalculator

# DEPRECATED (2026-05-25): superseded by ContactResolver, which receives the
# ball's actual state and applies the corrected spec §4 input precedence. This
# class measures placement against the ZONE CENTER (not the ball) and derives
# spray from timing — the exact bugs the redesign fixes. It survives only so the
# legacy scenes/_gate1.gd loop keeps running; Plan 2 removes both together. Do
# NOT build new code on this class.

# Tuning constants — superseded; see ContactResolver.
```

- [ ] **Step 4: Run the new test to verify it passes**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 180 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/test_deterministic_core.gd
```
Expected: PASS — 2 tests green.

- [ ] **Step 5: Run the FULL suite to confirm no regressions**

```bash
GODOT46=/home/cner/Public/Applications/Godot/Godot_v4.6.3-stable_linux.x86_64
cd /home/cner/Projects/dngrz/dngrz
timeout 120 "$GODOT46" --headless --path . --import
timeout 300 "$GODOT46" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/
```
Expected: PASS — the full suite green (the tests that survived migration plus everything added in Tasks 1–9). `test_contact_calculator.gd` still passes (ContactCalculator is behaviorally unchanged). If any suite fails, fix before committing.

- [ ] **Step 6: Commit**

```bash
cd /home/cner/Projects/dngrz
git add dngrz/test/test_deterministic_core.gd dngrz/src/core/contact_calculator.gd
git commit -m "test(core): prove end-to-end seed determinism; deprecate ContactCalculator"
```

---

## Done criteria for Plan 1

- All new modules exist and are pure (no node state, no `delta`, no wall clock, no global `randf*`): `SimClock`, `BallStateAtTick`, `SwingCommand`, `PitchCommand`, `ContactResolver`; plus `predict_crossing()` and seeded `create_pitch` on `BallTrajectory`; plus break-marker/tier on `PitchTypes`.
- The full gdUnit4 suite is green.
- `scenes/_gate1.gd` still runs (unchanged); `ContactCalculator` carries a deprecation banner and is otherwise untouched.
- The "one-way door" contracts the spec demanded now (§9 #1, #2, #3, #4, #5, #6, #8) are in place as testable code: tick-stamped serializable Commands, pure tick-addressed resolution over snapshots, seeded explicit RNG, and the truth/observable type split.

**Hand-off to Plan 2:** with the deterministic core real, Plan 2 writes the swing FSM (`BatterController`) + `AtBatDirector` (the tick-driven phase machine that wires `predict_crossing` → `BallStateAtTick` → `ContactResolver` into a live loop), replaces `scenes/_gate1.gd`, removes `ContactCalculator`, and adds the break-marker renderer + two-stick controls — all against signatures that now exist rather than speculative ones.
