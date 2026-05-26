# MSSB Batting Realignment — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign the batter to Mario Superstar Baseball's proven model — a forgiving cursor where contact QUALITY is the spatial distance from your cursor to the ball, timing is a whiff GATE that also TRADES with reach, and reach-misses get their own verdict — feel-testable in isolation against the existing AI pitcher.

**Architecture:** `ContactResolver` (pure) is rewritten: two whiff gates (timing + spatial reach), where good timing widens the catch radius (`effective_reach`), and quality is `spatial_q × (0.85 + 0.15·timing_q)` measured from the player's cursor. The cursor is restored to `BatterInput` (stateful, integrated, normalized plate space), latched at commit by `BatterController`, and the `BatterAI` tracks the same observable. Everything stays a pure function of `(SwingCommand, BallStateAtTick)` — no node/clock/delta/global-RNG on the resolution path — so determinism is preserved. Phase A keeps the existing human-bats / AI-pitches wiring (no role-config or pitcher changes — those are Phases B/C).

**Tech Stack:** Godot 4.5, GDScript (TAB indentation, always), gdUnit4 headless test suite.

**Spec:** `docs/superpowers/specs/2026-05-25-dngrz-mssb-duel-realignment-design.md` (rev 3). This plan implements **Phase A** (spec §3, §7). Phases B (pitcher charge+bend) and C (roles+polish) are planned separately after Phase A passes its feel-test kill-criterion.

**Conventions for every task:**
- GDScript files use **TAB** indentation, never spaces. The code blocks below show tabs; preserve them.
- Run the suite per the project workflow (memory `dngrz-gdunit4-workflow`): first import, then the gdUnit4 cmd tool. The exact commands are in Task 9; during earlier tasks, run the single named test file.
- Single-test run pattern (substitute the suite/test name):
  `GODOT46=<path-to-godot-4.6> ; timeout 120 "$GODOT46" --headless --path dngrz --import` then
  `timeout 300 "$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/test_contact_resolver.gd`
- Commit after each task.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `dngrz/src/core/contact_resolver.gd` | Pure contact resolution: two gates + spatial-from-cursor quality + cursor spray/launch | **Rewrite** |
| `dngrz/test/test_contact_resolver.gd` | Resolver unit tests | Rewrite (helper + cases) |
| `dngrz/src/data/swing_command.gd` | Committed swing snapshot | Modify (un-deprecate `cursor_point`; mark `placement_dir` dead) |
| `dngrz/src/data/swing_input.gd` | Per-tick input snapshot | Modify (doc only; `cursor` un-deprecated) |
| `dngrz/src/batter/batter_input.gd` | Gamepad → SwingInput; holds the live cursor | **Modify** (stateful normalized cursor) |
| `dngrz/test/test_batter_input.gd` | Input mapping tests | Modify (new `map` signature) |
| `dngrz/src/batter/batter_controller.gd` | Swing FSM; latches the swing | Modify (latch `cursor_point` at commit) |
| `dngrz/test/test_batter_controller.gd` | FSM tests | Modify (cursor now latched, not ZERO) |
| `dngrz/src/batter/batter_ai.gd` | AI batter (observable-only) | Modify (cursor in normalized space; drop `placement_dir`) |
| `dngrz/test/test_batter_ai.gd` | AI tests | Modify (cursor assertions) |
| `dngrz/src/game/at_bat_director.gd` | Live tick loop + HUD bridge | Modify (cursor bridge, reach verdict, `LATE_FLIGHT_TICKS` const) |
| `dngrz/scenes/ui/batting_view.gd` | Batter HUD (`_draw`) | Modify (cursor + reach ring + REACH verdict) |
| `dngrz/scenes/batter.tscn` | Batter scene | Modify (restore `CursorMarker`) |

---

## Task 1: Rewrite ContactResolver — two whiff gates (timing + reach) with a REACH verdict

This is the centerpiece. We rewrite the resolver to its full Phase-A form (gates + spatial quality + cursor spray/launch), driven test-first by the gate behaviors. Tasks 2–3 then add tests that lock down the quality-trade and spray behaviors this task implements.

**Files:**
- Rewrite: `dngrz/src/core/contact_resolver.gd`
- Rewrite: `dngrz/test/test_contact_resolver.gd`

- [ ] **Step 1: Replace the test helper and write the gate tests (RED)**

Replace the top of `dngrz/test/test_contact_resolver.gd` (the `_swing` helper now takes a normalized `cursor`, since the resolver reads it; `_ball` is unchanged):

```gdscript
class_name TestContactResolver extends GdUnitTestSuite

const TICK := 100

# Ball crossing the plate at zone center (height 0.8m), moving toward home at
# `speed`, at `tick`.
func _ball(pos := Vector3(0.0, 0.8, 0.0), speed := 40.0, tick := TICK) -> BallStateAtTick:
	return BallStateAtTick.new(tick, pos, Vector3(0.0, 0.0, speed))

# A committed swing. `cursor` is the normalized plate-space aim point the resolver
# now grades against (StrikeZone.get_plate_position space: (0,0)=center, ±1=edge).
func _swing(cursor := Vector2.ZERO, type := SwingCommand.SwingType.CONTACT,
		commit := TICK) -> SwingCommand:
	return SwingCommand.new(cursor, type, Vector2.ZERO, commit)

# --- Whiff gate 1: timing (preserved) ---

func test_on_time_cursor_on_ball_is_contact() -> void:
	# Ball at center, cursor on it, perfect timing -> contact.
	var r := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	assert_bool(r.is_whiff).is_false()

func test_gross_mistiming_whiffs() -> void:
	# 15 ticks late > CONTACT_TICKS (12): timing whiff even cursor-on-ball.
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 15), _ball())
	assert_bool(r.is_whiff).is_true()
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

func test_power_window_tighter_than_contact() -> void:
	var off := TICK + 10
	var contact := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, off), _ball())
	var power := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.POWER, off), _ball())
	assert_bool(contact.is_whiff).is_false()
	assert_bool(power.is_whiff).is_true()

# --- Whiff gate 2: spatial reach (NEW; reverses the old "location never gates") ---

func test_cursor_far_from_ball_whiffs_with_reach_verdict() -> void:
	# Ball at center, cursor parked at the zone edge (1.0 normalized), on time.
	# 1.0 > effective_reach (0.9 at perfect timing) -> a REACH whiff, not a timing whiff.
	var r := ContactResolver.resolve(_swing(Vector2(1.0, 0.0)), _ball())
	assert_bool(r.is_whiff).is_true()
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.REACH)

func test_cursor_near_ball_contacts() -> void:
	# Cursor 0.5 from a center ball, on time: within reach -> contact.
	var r := ContactResolver.resolve(_swing(Vector2(0.5, 0.0)), _ball())
	assert_bool(r.is_whiff).is_false()

# --- Judgment label (timing) preserved ---

func test_judgment_perfect_within_perfect_ticks() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 2), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.PERFECT)

func test_judgment_early_when_swing_precedes_crossing() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK - 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.EARLY)

func test_judgment_late_when_swing_follows_crossing() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK + 6), _ball())
	assert_int(r.judgment).is_equal(ContactResolver.Judgment.LATE)

func test_resolution_is_deterministic() -> void:
	var a := ContactResolver.resolve(_swing(Vector2(0.3, -0.2), SwingCommand.SwingType.POWER, TICK + 3), _ball())
	var b := ContactResolver.resolve(_swing(Vector2(0.3, -0.2), SwingCommand.SwingType.POWER, TICK + 3), _ball())
	assert_float(a.quality).is_equal(b.quality)
	assert_float(a.exit_velocity).is_equal(b.exit_velocity)
	assert_float(a.h_angle).is_equal(b.h_angle)
	assert_float(a.launch_angle).is_equal(b.launch_angle)
	assert_int(a.judgment).is_equal(b.judgment)
```

- [ ] **Step 2: Run the tests — verify they fail**

Run the single-file command for `res://test/test_contact_resolver.gd`.
Expected: FAIL/ERROR — `ContactResolver.Judgment.REACH` does not exist yet and contact behavior differs.

- [ ] **Step 3: Rewrite `contact_resolver.gd` to its full Phase-A form**

Replace the entire contents of `dngrz/src/core/contact_resolver.gd`:

```gdscript
class_name ContactResolver

# MSSB-faithful contact (Plan 3a, spec §3). TWO whiff gates and a spatial quality:
#   gate 1 = TIMING: |commit - crossing| within the whiff window (tap wider, hold tighter)
#   gate 2 = REACH:  the cursor must be within effective_reach of the ball's plate pos
#   good TIMING widens effective_reach (the two skills TRADE), and QUALITY is the
#   spatial distance from the player's CURSOR (not the zone center).
# Pure function of (SwingCommand, BallStateAtTick): no node, delta, wall clock, or
# global RNG (determinism contracts). Cursor + ball share NORMALIZED plate space
# (StrikeZone.get_plate_position: (0,0)=center, ±1=zone edge).

# Timing window in integer ticks anchored at the crossing tick (flight-speed-independent).
const PERFECT_TICKS := 3              # |dt| <= this reads PERFECT
const GOOD_TICKS := 7                 # timing-quality falloff window
const CONTACT_TICKS := 12             # timing whiff window (tap)
const POWER_WINDOW_SCALE := 0.7       # hold tightens the timing window

# Spatial reach in normalized plate units. BASE_REACH is the catch radius at neutral
# timing; perfect timing widens it by REACH_TIMING_BONUS (the trade). Y_WEIGHT is the
# single anisotropy/MSSB-X-dominance knob used by ALL plate distance math (default
# 1.0 = zone-relative, so the on-screen reach ring is a true circle).
const BASE_REACH := 0.6
const REACH_TIMING_BONUS := 0.5
const Y_WEIGHT := 1.0

# Exit velocity (incoming speed is the SINGLE path power/velocity flows through).
const CONTACT_EXIT_VELOCITY := 32.0
const POWER_EXIT_VELOCITY := 42.0
const PITCH_SPEED_FACTOR := 0.3

# Spray/launch from CURSOR POSITION (intentional) + a natural timing lean.
const SPRAY_MAX := 35.0               # deg; cursor.x = +/-1 -> oppo / pull
const TIMING_LEAN := 60.0             # deg per second of timing offset
const GROUND_LAUNCH := -5.0           # deg; cursor.y = -1 -> grounder
const FLY_LAUNCH := 45.0              # deg; cursor.y = +1 -> fly ball
const MISHIT_LAUNCH := 8.0            # deg; low-quality contact degrades toward this

# Timing verdict word + REACH (whiffed by location, not timing) for the HUD.
enum Judgment { EARLY, PERFECT, LATE, REACH }

class ContactResult:
	var is_whiff: bool
	var quality: float          # 0.0 to 1.0
	var exit_velocity: float    # m/s
	var launch_angle: float     # degrees
	var h_angle: float          # degrees (- = pull, + = oppo)
	var judgment: int           # Judgment.*

	func _init() -> void:
		is_whiff = true
		quality = 0.0
		exit_velocity = 0.0
		launch_angle = 0.0
		h_angle = 0.0
		judgment = Judgment.PERFECT

# Weighted plate-plane distance (single metric for reach gate + quality + HUD).
static func _plate_distance(a: Vector2, b: Vector2) -> float:
	var d := a - b
	return Vector2(d.x, d.y * Y_WEIGHT).length()

static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
	var result := ContactResult.new()
	var dt: int = swing.commit_tick - ball_at_contact.tick
	var is_power := swing.swing_type == SwingCommand.SwingType.POWER

	# Timing verdict word — set first so it survives a whiff early-return.
	if absi(dt) <= PERFECT_TICKS:
		result.judgment = Judgment.PERFECT
	elif dt < 0:
		result.judgment = Judgment.EARLY
	else:
		result.judgment = Judgment.LATE

	var whiff_window := float(CONTACT_TICKS)
	var quality_window := float(GOOD_TICKS)
	if is_power:
		whiff_window *= POWER_WINDOW_SCALE
		quality_window *= POWER_WINDOW_SCALE

	# Gate 1: TIMING. Out of the window -> whiff, keep EARLY/LATE.
	if float(absi(dt)) > whiff_window:
		result.is_whiff = true
		return result

	# timing_q: quadratic falloff within the quality window.
	var timing_q := clampf(1.0 - float(absi(dt)) / quality_window, 0.0, 1.0)
	timing_q = timing_q * timing_q

	# Gate 2: REACH, widened by good timing (the trade). Distance from the CURSOR to
	# the ball's normalized plate position.
	var effective_reach := BASE_REACH * (1.0 + REACH_TIMING_BONUS * timing_q)
	var ball_plate := StrikeZone.get_plate_position(ball_at_contact.position)
	var dist := _plate_distance(swing.cursor_point, ball_plate)
	if dist > effective_reach:
		result.is_whiff = true
		result.judgment = Judgment.REACH
		return result
	result.is_whiff = false

	# Quality: spatial PRIMARY; a small direct timing term makes nailing BOTH the apex
	# (most of timing's value is the reach widening above — the axes interact).
	var spatial_q := clampf(1.0 - dist / effective_reach, 0.0, 1.0)
	result.quality = spatial_q * (0.85 + 0.15 * timing_q)

	# Exit velocity: base (tap/hold) + incoming pitch speed (the only power path),
	# scaled by quality.
	var pitch_speed := ball_at_contact.velocity.length()
	var base_exit := POWER_EXIT_VELOCITY if is_power else CONTACT_EXIT_VELOCITY
	result.exit_velocity = (base_exit + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

	# Spray: cursor.x is the intentional pull/oppo lever, plus a natural timing lean.
	var timing_offset := SimClock.ticks_to_seconds(dt)
	var intended_spray := clampf(swing.cursor_point.x, -1.0, 1.0) * SPRAY_MAX
	result.h_angle = clampf(intended_spray + timing_offset * TIMING_LEAN, -45.0, 45.0)

	# Launch: cursor.y is the intentional ground/fly lever; poor quality degrades the
	# realized launch toward a flat mishit.
	var intended_launch := remap(clampf(swing.cursor_point.y, -1.0, 1.0), -1.0, 1.0, GROUND_LAUNCH, FLY_LAUNCH)
	result.launch_angle = clampf(lerpf(MISHIT_LAUNCH, intended_launch, result.quality), -10.0, 60.0)

	return result
```

- [ ] **Step 4: Run the tests — verify they pass**

Run the single-file command for `res://test/test_contact_resolver.gd`.
Expected: PASS (all Step-1 tests green).

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/core/contact_resolver.gd dngrz/test/test_contact_resolver.gd
git commit -m "feat(batting): ContactResolver two-gate (timing+reach) with REACH verdict"
```

---

## Task 2: Lock down spatial quality + the timing↔reach trade (tests)

The impl from Task 1 already computes these; here we add the characterization tests that pin the behavior (and would catch a regression in the formula).

**Files:**
- Modify: `dngrz/test/test_contact_resolver.gd`

- [ ] **Step 1: Add the quality + trade tests**

Append to `dngrz/test/test_contact_resolver.gd`:

```gdscript
# --- Spatial quality (measured from the cursor) ---

func test_cursor_on_ball_is_high_quality() -> void:
	var r := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	assert_bool(r.is_whiff).is_false()
	assert_float(r.quality).is_greater(0.9)

func test_cursor_farther_from_ball_lowers_quality() -> void:
	var on_ball := ContactResolver.resolve(_swing(Vector2.ZERO), _ball())
	var off := ContactResolver.resolve(_swing(Vector2(0.4, 0.0)), _ball())
	assert_bool(off.is_whiff).is_false()
	assert_float(off.quality).is_less(on_ball.quality)

# --- Timing TRADES with reach: perfect timing widens the catch radius ---

func test_perfect_timing_widens_reach() -> void:
	# Cursor 0.8 from a center ball. At perfect timing effective_reach is 0.9 (contact);
	# mistimed-but-in-window (dt=5) it shrinks toward BASE_REACH (0.6) -> a REACH whiff.
	var perfect := ContactResolver.resolve(_swing(Vector2(0.8, 0.0)), _ball())
	var mistimed := ContactResolver.resolve(_swing(Vector2(0.8, 0.0), SwingCommand.SwingType.CONTACT, TICK + 5), _ball())
	assert_bool(perfect.is_whiff).is_false()
	assert_bool(mistimed.is_whiff).is_true()
	assert_int(mistimed.judgment).is_equal(ContactResolver.Judgment.REACH)

func test_nailing_both_beats_nailing_one() -> void:
	# Same cursor offset; perfect timing should grade higher than in-window-but-off timing.
	var both := ContactResolver.resolve(_swing(Vector2(0.3, 0.0)), _ball())
	var loose := ContactResolver.resolve(_swing(Vector2(0.3, 0.0), SwingCommand.SwingType.CONTACT, TICK + 4), _ball())
	assert_bool(both.is_whiff).is_false()
	assert_bool(loose.is_whiff).is_false()
	assert_float(both.quality).is_greater(loose.quality)
```

- [ ] **Step 2: Run the tests — verify they pass**

Run the single-file command for `res://test/test_contact_resolver.gd`.
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add dngrz/test/test_contact_resolver.gd
git commit -m "test(batting): lock spatial quality + timing-reach trade"
```

---

## Task 3: Lock down cursor-position spray + launch (tests)

The old `placement_dir` spray/launch tests are obsolete (that field is dead). Replace them with cursor-position tests for the behavior Task 1 implemented.

**Files:**
- Modify: `dngrz/test/test_contact_resolver.gd`

- [ ] **Step 1: Add cursor spray/launch + exit-velo tests**

Append to `dngrz/test/test_contact_resolver.gd`:

```gdscript
# --- Spray / launch from cursor position (intentional) + timing lean ---

func test_cursor_inside_pulls_outside_goes_oppo() -> void:
	var pull := ContactResolver.resolve(_swing(Vector2(-0.4, 0.0)), _ball())
	var oppo := ContactResolver.resolve(_swing(Vector2(0.4, 0.0)), _ball())
	assert_float(pull.h_angle).is_less(0.0)
	assert_float(oppo.h_angle).is_greater(0.0)

func test_cursor_low_grounds_high_flies() -> void:
	var grounder := ContactResolver.resolve(_swing(Vector2(0.0, -0.4)), _ball())
	var fly := ContactResolver.resolve(_swing(Vector2(0.0, 0.4)), _ball())
	assert_float(fly.launch_angle).is_greater(grounder.launch_angle)

func test_early_timing_leans_pull() -> void:
	# Cursor on the ball; early timing adds a pull lean.
	var early := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT, TICK - 6), _ball())
	assert_bool(early.is_whiff).is_false()
	assert_float(early.h_angle).is_less(0.0)

func test_power_swing_hits_harder_than_contact() -> void:
	var contact := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.CONTACT), _ball())
	var power := ContactResolver.resolve(_swing(Vector2.ZERO, SwingCommand.SwingType.POWER), _ball())
	assert_float(power.exit_velocity).is_greater(contact.exit_velocity)

func test_exit_velocity_scales_with_pitch_speed() -> void:
	var slow := ContactResolver.resolve(_swing(Vector2.ZERO), _ball(Vector3(0.0, 0.8, 0.0), 35.0))
	var fast := ContactResolver.resolve(_swing(Vector2.ZERO), _ball(Vector3(0.0, 0.8, 0.0), 45.0))
	assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)
```

- [ ] **Step 2: Run the tests — verify they pass**

Run the single-file command for `res://test/test_contact_resolver.gd`.
Expected: PASS. The full `test_contact_resolver.gd` now covers both gates, quality, the trade, spray/launch, and exit velo.

- [ ] **Step 3: Commit**

```bash
git add dngrz/test/test_contact_resolver.gd
git commit -m "test(batting): cursor-position spray/launch + exit velo"
```

---

## Task 4: Un-deprecate `cursor_point`; latch it in the swing FSM

**Files:**
- Modify: `dngrz/src/data/swing_command.gd` (comments only)
- Modify: `dngrz/src/data/swing_input.gd` (comment only)
- Modify: `dngrz/src/batter/batter_controller.gd`
- Modify: `dngrz/test/test_batter_controller.gd`

- [ ] **Step 1: Write the failing test (RED)**

In `dngrz/test/test_batter_controller.gd`, replace the assertion that the emitted command's `cursor_point` is ZERO with one that it carries the latched cursor. Add this test (and delete/replace any existing `cursor_point == ZERO` assertion):

```gdscript
func test_latches_cursor_at_commit() -> void:
	var c := BatterController.new()
	c.arm(120)
	# Tick 100: button down with cursor at (0.3, -0.2) -> latched.
	c.step(SwingInput.new(Vector2(0.3, -0.2), true, Vector2.ZERO), 100)
	# Tick 103: release (tap) -> emits a CONTACT command carrying the latched cursor.
	var cmd := c.step(SwingInput.new(Vector2(0.9, 0.9), false, Vector2.ZERO), 103)
	assert_object(cmd).is_not_null()
	assert_vector(cmd.cursor_point).is_equal(Vector2(0.3, -0.2))
	assert_int(cmd.commit_tick).is_equal(100)
```

- [ ] **Step 2: Run the test — verify it fails**

Run the single-file command for `res://test/test_batter_controller.gd`.
Expected: FAIL — emitted `cursor_point` is currently `Vector2.ZERO`.

- [ ] **Step 3: Latch the cursor in `batter_controller.gd`**

Add a latch field and set it on the AIMING→CHARGING transition; emit it in `_make_command`.

Add to the var block (near `_placement_latched`):

```gdscript
var _cursor_latched: Vector2 = Vector2.ZERO
```

In `arm()`, reset it alongside `_placement_latched`:

```gdscript
	_placement_latched = Vector2.ZERO
	_cursor_latched = Vector2.ZERO
```

In `step()`, the `State.AIMING` branch where `input.commit_pressed`, latch the cursor (frozen at button-down):

```gdscript
			State.AIMING:
				if input.commit_pressed:
					_state = State.CHARGING
					_commit_tick = tick
					_placement_latched = input.placement_dir
					_cursor_latched = input.cursor
				elif tick >= _crossing_tick:
					_state = State.TAKEN
				return null
```

Replace `_make_command` to emit the latched cursor (placement stays ZERO — dead):

```gdscript
func _make_command(swing_type: SwingCommand.SwingType) -> SwingCommand:
	_play_swing(swing_type)
	return SwingCommand.new(_cursor_latched, swing_type, Vector2.ZERO, _commit_tick)
```

- [ ] **Step 4: Update the doc comments (no behavior)**

In `swing_command.gd`, change the `cursor_point` comment from "DEPRECATED…" to its live meaning:

```gdscript
var cursor_point: Vector2   # normalized plate-space aim, latched at commit (StrikeZone
                            #   space: (0,0)=center, ±1=edge). The MSSB cursor — ContactResolver
                            #   grades contact quality by its distance to the ball (spec §3).
var swing_type: SwingType
var placement_dir: Vector2  # DEAD (Plan 3a): spray/launch now derive from cursor position;
                            #   retained as an inert vestige for serialization. Emit ZERO.
```

In `swing_input.gd`, change the `cursor` comment to "live per-tick cursor aim (normalized plate space)".

- [ ] **Step 5: Run the test — verify it passes**

Run the single-file command for `res://test/test_batter_controller.gd`.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add dngrz/src/data/swing_command.gd dngrz/src/data/swing_input.gd dngrz/src/batter/batter_controller.gd dngrz/test/test_batter_controller.gd
git commit -m "feat(batting): latch cursor_point at commit; placement_dir retired"
```

---

## Task 5: Restore a stateful, normalized cursor in BatterInput

**Files:**
- Modify: `dngrz/src/batter/batter_input.gd`
- Modify: `dngrz/test/test_batter_input.gd`

- [ ] **Step 1: Write the failing tests (RED)**

Replace the body of `dngrz/test/test_batter_input.gd` with (new `map(left, commit, prev_cursor)` signature):

```gdscript
class_name TestBatterInput extends GdUnitTestSuite

func test_stick_integrates_cursor_from_previous() -> void:
	# Full-right stick moves the cursor right by CURSOR_SPEED from the previous pos.
	var si := BatterInput.map(Vector2(1.0, 0.0), false, Vector2.ZERO)
	assert_float(si.cursor.x).is_equal_approx(BatterInput.CURSOR_SPEED, 0.0001)
	assert_float(si.cursor.y).is_equal_approx(0.0, 0.0001)

func test_deadzone_holds_cursor_still() -> void:
	var prev := Vector2(0.3, -0.2)
	var si := BatterInput.map(Vector2(0.1, 0.1), false, prev)  # below DEADZONE
	assert_vector(si.cursor).is_equal(prev)

func test_cursor_clamped_to_reach_region() -> void:
	# Starting at the clamp edge and pushing further stays clamped.
	var si := BatterInput.map(Vector2(1.0, 0.0), false, Vector2(BatterInput.CURSOR_CLAMP, 0.0))
	assert_float(si.cursor.x).is_equal_approx(BatterInput.CURSOR_CLAMP, 0.0001)

func test_commit_flag_passthrough() -> void:
	var si := BatterInput.map(Vector2.ZERO, true, Vector2.ZERO)
	assert_bool(si.commit_pressed).is_true()
```

- [ ] **Step 2: Run the tests — verify they fail**

Run the single-file command for `res://test/test_batter_input.gd`.
Expected: FAIL — `map` takes 2 args today and returns a ZERO cursor; `CURSOR_SPEED`/`CURSOR_CLAMP` undefined.

- [ ] **Step 3: Make BatterInput stateful + normalized**

Replace the contents of `dngrz/src/batter/batter_input.gd`:

```gdscript
class_name BatterInput

# Samples the gamepad into a SwingInput each tick. The MSSB realignment (Plan 3a)
# restores a CURSOR: the left stick DRAGS a normalized plate-space aim point
# (StrikeZone space, ±1 = zone edge), integrated per tick and clamped to a reach
# region slightly larger than the zone. `map` is pure (takes the previous cursor);
# `sample` is the thin Input-singleton wrapper that holds the live cursor.
const DEADZONE := 0.2
const CURSOR_SPEED := 0.04   # normalized units per tick (~2.4 zone-units/sec @ 60Hz)
const CURSOR_CLAMP := 2.0    # how far the cursor may roam (covers off-zone pitches)

var _cursor: Vector2 = Vector2.ZERO

# Pure mapping: integrate the plate-convention left stick (+y = up) into the cursor.
# placement_dir is dead (ZERO) — spray/launch derive from cursor position now.
static func map(left: Vector2, commit: bool, prev_cursor: Vector2) -> SwingInput:
	var move := left if left.length() >= DEADZONE else Vector2.ZERO
	var cursor := prev_cursor + move * CURSOR_SPEED
	cursor.x = clampf(cursor.x, -CURSOR_CLAMP, CURSOR_CLAMP)
	cursor.y = clampf(cursor.y, -CURSOR_CLAMP, CURSOR_CLAMP)
	return SwingInput.new(cursor, commit, Vector2.ZERO)

# Reads the live gamepad and advances the held cursor. Godot joypad Y is +down, so
# negate to the plate convention (+up).
func sample() -> SwingInput:
	var left := Vector2(_axis(JOY_AXIS_LEFT_X), -_axis(JOY_AXIS_LEFT_Y))
	var commit := Input.is_action_pressed("batter_swing")
	var si := map(left, commit, _cursor)
	_cursor = si.cursor
	return si

# Current live cursor (for the HUD bridge).
func current_cursor() -> Vector2:
	return _cursor

# Reset the cursor to center between at-bats.
func reset_cursor() -> void:
	_cursor = Vector2.ZERO

# The axis value from whichever connected joypad has the strongest signal (DualSense
# enumerates as two devices on Linux; device 0 may not carry the sticks).
static func _axis(axis: JoyAxis) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, axis)
		if absf(v) > absf(best):
			best = v
	return best
```

- [ ] **Step 4: Run the tests — verify they pass**

Run the single-file command for `res://test/test_batter_input.gd`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/batter/batter_input.gd dngrz/test/test_batter_input.gd
git commit -m "feat(batting): restore stateful normalized cursor in BatterInput"
```

---

## Task 6: AI batter tracks the observable cursor; drops placement

**Files:**
- Modify: `dngrz/src/batter/batter_ai.gd`
- Modify: `dngrz/test/test_batter_ai.gd`

- [ ] **Step 1: Write the failing test (RED)**

Add to `dngrz/test/test_batter_ai.gd`:

```gdscript
func test_cursor_tracks_normalized_observable() -> void:
	var ai := BatterAI.new()
	ai.skill = 1.0  # min noise
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Ball crossing at zone center -> cursor should be near (0,0) in normalized space.
	var obs := BallStateAtTick.new(120, Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.0, 40.0))
	# Force a swing with a 2-strike count and a clearly in-zone pitch.
	var cmd := ai.compute_command(obs, 120, 0, 2, rng)
	assert_object(cmd).is_not_null()
	# Normalized center is ~ (0,0); allow the high-skill noise band.
	assert_float(cmd.cursor_point.length()).is_less(0.15)
	# placement_dir is dead -> ZERO.
	assert_vector(cmd.placement_dir).is_equal(Vector2.ZERO)
```

- [ ] **Step 2: Run the test — verify it fails**

Run the single-file command for `res://test/test_batter_ai.gd`.
Expected: FAIL — the AI currently builds the cursor from `observable.plate_point()` (raw meters, so a center pitch gives y≈0.8, not 0) and authors a random `placement`.

- [ ] **Step 3: Fix the AI cursor space and drop placement**

In `dngrz/src/batter/batter_ai.gd`, in `compute_command`, replace the `cursor`, `placement`, `swing_type`, `latency`, and `return` lines so the cursor is normalized and placement is ZERO (delete the old `var placement := ...` line):

```gdscript
	var noise := lerpf(0.10, 0.02, skill)
	var cursor := StrikeZone.get_plate_position(ball_pos) + Vector2(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise))
	var swing_type := SwingCommand.SwingType.CONTACT if rng.randf() < 0.7 else SwingCommand.SwingType.POWER
	var latency := int(round(lerpf(8.0, 3.0, skill)))
	return SwingCommand.new(cursor, swing_type, Vector2.ZERO, crossing_tick - latency)
```

- [ ] **Step 4: Run the test — verify it passes**

Run the single-file command for `res://test/test_batter_ai.gd`.
Expected: PASS. (If other AI tests asserted the old `plate_point()`-meter cursor or a non-zero placement, update them to the normalized space / ZERO placement now.)

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/batter/batter_ai.gd dngrz/test/test_batter_ai.gd
git commit -m "feat(batting): AI cursor in normalized plate space; drop placement"
```

---

## Task 7: Director — pin the timing/flight coupling and bridge the cursor + reach verdict

The HUD `_draw` is verified by eye in the feel-test (headless-untested per `godot-headless-draw-untested`); here we make the one unit-testable change (the constant coupling) and wire the bridge.

**Files:**
- Modify: `dngrz/src/game/at_bat_director.gd`
- Modify: `dngrz/test/test_at_bat_director.gd`

- [ ] **Step 1: Write the test (pins the coupling)**

Add to `dngrz/test/test_at_bat_director.gd`:

```gdscript
func test_late_flight_ticks_tracks_contact_window() -> void:
	# The flight-extension past the plate must equal the resolver's whiff window, or
	# late swings get accepted/dropped by a different bound than they're graded by.
	assert_int(AtBatDirector.LATE_FLIGHT_TICKS).is_equal(ContactResolver.CONTACT_TICKS)
```

- [ ] **Step 2: Run the test**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: PASS today (both are 12) — Step 3 makes it a reference so a future retune can't silently desync, and the test guards that.

- [ ] **Step 3: Make the coupling a reference + bridge the cursor**

In `at_bat_director.gd`, replace the `LATE_FLIGHT_TICKS` literal:

```gdscript
const LATE_FLIGHT_TICKS := ContactResolver.CONTACT_TICKS
```

In `_present()`, inside the `PITCH_IN_FLIGHT` HUD-bridge block (where `_batting_view` is non-null), add the live cursor so the player sees where they're aiming. **Leave `observable_landing` as the current-state projection — do NOT repoint it at `state_at_tick(crossing_tick)` (that would be the rejected clairvoyant dot, spec §4.3):**

```gdscript
				_batting_view.cursor = _batter_input.current_cursor()
```

Reset the cursor between at-bats: in `_present()`'s `IDLE` branch, alongside the other HUD resets:

```gdscript
			_batter_input.reset_cursor()
			if _batting_view != null:
				_batting_view.cursor = Vector2.ZERO
```

(The existing RESULT-phase bridge already forwards `_last_outcome.contact.judgment` to `_batting_view.swing_judgment`; `Judgment.REACH` flows through unchanged — Task 8 renders it.)

- [ ] **Step 4: Run the test — verify it passes**

Run the single-file command for `res://test/test_at_bat_director.gd`.
Expected: PASS. (The `_batting_view.cursor` export is added in Task 8; the unit test above does not instantiate `_batting_view`, so it is green regardless. If you run the live scene before Task 8, add Task 8's export first.)

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/game/at_bat_director.gd dngrz/test/test_at_bat_director.gd
git commit -m "feat(batting): pin LATE_FLIGHT_TICKS to CONTACT_TICKS; bridge cursor"
```

---

## Task 8: Batting HUD — render the cursor, reach ring, and REACH verdict; restore CursorMarker

`_draw` and `.tscn` changes are not headless-testable; they are verified in the Task 9 feel-test. Keep them minimal and correct.

**Files:**
- Modify: `dngrz/scenes/ui/batting_view.gd`
- Modify: `dngrz/scenes/batter.tscn`

- [ ] **Step 1: Add a `cursor` export + render it and the reach ring**

In `dngrz/scenes/ui/batting_view.gd`, add an export (near `predicted_landing`):

```gdscript
@export var cursor: Vector2 = Vector2.ZERO:  # normalized plate-space aim (the player's bat)
	set(v):
		cursor = v
		queue_redraw()
```

In `_draw()`, after the predicted-landing ring block, draw the cursor and its reach ring (`BASE_REACH` is in normalized units, so scale by half the zone width):

```gdscript
	# Player cursor (the bat) + its catch radius (the reach gate).
	var cursor_screen := _zone_to_screen(cursor, zone_rect)
	var reach_px := ContactResolver.BASE_REACH * (zone_rect.size.x * 0.5)
	draw_arc(cursor_screen, reach_px, 0.0, TAU, 40, Color(Colors.COOL.r, Colors.COOL.g, Colors.COOL.b, 0.5), 1.5)
	draw_circle(cursor_screen, 7.0, Colors.COOL)
```

- [ ] **Step 2: Render the REACH verdict word**

In `_draw_verdict()`, add a `REACH` case to the `match swing_judgment` so a location-miss reads distinctly instead of falling through to "LATE":

```gdscript
	match swing_judgment:
		ContactResolver.Judgment.PERFECT:
			word = "PERFECT"
			word_color = Colors.COOL
		ContactResolver.Judgment.EARLY:
			word = "EARLY"
			word_color = Colors.BRAND
		ContactResolver.Judgment.REACH:
			word = "MISSED"
			word_color = Colors.HEAT
		_:
			word = "LATE"
			word_color = Colors.BRAND
```

- [ ] **Step 3: Restore the CursorMarker node in `batter.tscn`**

View the pre-pivot scene **as a reference only** — do NOT `git checkout` it (that would delete the current `BatPivot/BatMesh`):

```bash
git show 1117c98^:dngrz/scenes/batter.tscn
```

Re-add to the current `dngrz/scenes/batter.tscn`, on top of the existing resources: a `SphereMesh` sub-resource (small radius ~0.05) + a bright `StandardMaterial3D`, and a `MeshInstance3D` node named `CursorMarker` (child of the batter root) using them. Set `load_steps` in the scene header to the actual new resource count after editing (do not trust any prior "8→6"/"6→8" note — the current scene is `load_steps=6`; adding a mesh + material makes it ~8). This node's presence is what the Phase-B/visual wiring needs; it does not have to be positioned this task.

- [ ] **Step 4: Sanity-run the import (no test; `_draw` is eyeballed in Task 9)**

`timeout 120 "$GODOT46" --headless --path dngrz --import`
Expected: clean import, no parse/resource errors mentioning `batting_view.gd` or `batter.tscn`.

- [ ] **Step 5: Commit**

```bash
git add dngrz/scenes/ui/batting_view.gd dngrz/scenes/batter.tscn
git commit -m "feat(batting): HUD cursor + reach ring + REACH verdict; restore CursorMarker"
```

---

## Task 9: Full suite green + feel-test gate (kill-criterion)

**Files:** none (verification + manual feel-test).

- [ ] **Step 1: Import, then run the full gdUnit4 suite headless**

```bash
GODOT46=<path-to-godot-4.6>
timeout 120 "$GODOT46" --headless --path dngrz --import
timeout 300 "$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 GdUnitCmdTool.gd --ignoreHeadlessMode --add res://test/
```

Expected: clean import; full suite GREEN, 0 failures. Report the new total (the prior baseline was 176; this plan rewrites ~14 contact-resolver cases and adds input/AI/director cases).

- [ ] **Step 2: Fix any red tests from the rewrite**

If any non-touched suite fails (e.g. an `at_bat_resolver` case still assuming timing-quality, or a `batter_ai` case asserting the old meter-space cursor / non-zero placement), update its expectations to the new model (timing gates + spatial-from-cursor quality; AI cursor normalized; `placement_dir` ZERO). Re-run Step 1 until green. Commit:

```bash
git add -A
git commit -m "test(batting): align remaining suites to MSSB realignment"
```

- [ ] **Step 3: Headed feel-test against the AI pitcher (the kill-criterion gate)**

Run the game headed (DualSense), human batting vs the existing AI pitcher. Evaluate against the spec's Phase-A **kill-criterion** (spec §7):
- Set the threshold first, e.g. "a competent tester should make contact on the clear majority of swings where the cursor is visibly on the ball; whiffs should feel like *my cursor was off* or *I was early/late*, not random."
- PASS signals: contact feels *forgiving* (wide bat), PERFECT feels *earned* (cursor on ball + good timing), a reach-miss reads as "MISSED" and feels fair (you can see your cursor wasn't there), timing still matters (great timing rescues a marginal cursor).
- FAIL signals (revert to timing-first, do NOT rationalize forward): the cursor feels "arbitrary/overloading" as the original free-cursor did; whiffs feel random; you can't tell why you missed.

- [ ] **Step 4: Record the verdict**

If PASS: note tuning observations (`BASE_REACH`, `CURSOR_SPEED`, `Y_WEIGHT`, `REACH_TIMING_BONUS`, the quality band thresholds) and proceed to plan Phase B (pitcher charge + bend). If FAIL: capture the specific feel failure, revert the branch, and reassess the thesis with the user.

---

## Self-Review (completed by the plan author)

**Spec coverage (§3, §7):** forgiving cursor (Tasks 4–5, 8) ✓; normalized space + anisotropy knob `Y_WEIGHT` (Task 1) ✓; two whiff gates with REACH verdict (Tasks 1, 8) ✓; quality = `spatial_q × (0.85+0.15·timing_q)` (Tasks 1–2) ✓; timing↔reach trade (Tasks 1–2) ✓; cursor-position spray + launch, `placement_dir` retired (Tasks 1, 3, 4, 6) ✓; AI parity in the same observable space (Task 6) ✓; current-state projection indicator kept, not repointed (Task 7) ✓; `LATE_FLIGHT_TICKS` coupling pinned (Task 7) ✓; CursorMarker restored without clobbering the bat (Task 8) ✓; kill-criterion feel-test (Task 9) ✓. **Deferred to Phases B/C (correctly out of Phase A):** pitcher charge/bend, two-field role config, panic recenter, confidence cone, PHENOM, balance tuning.

**Placeholders:** none — every code step shows complete code; constants have starting values; `<path-to-godot-4.6>` is the one operator-supplied value (the project's Godot binary).

**Type consistency:** `ContactResolver.Judgment.REACH`, `BASE_REACH`, `CONTACT_TICKS` referenced consistently across Tasks 1/7/8; `BatterInput.CURSOR_SPEED`/`CURSOR_CLAMP`/`map(left,commit,prev_cursor)`/`current_cursor()`/`reset_cursor()` consistent across Tasks 5/7; `SwingCommand.new(cursor, type, placement, commit)` arg order matches the existing struct; `cursor_point`/`placement_dir` usage consistent (latched / ZERO).
