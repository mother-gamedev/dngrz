# DNGRZ Plan 2 — The Playable Duel: Design

**Date:** 2026-05-25
**Parent spec:** `docs/superpowers/specs/2026-05-24-dngrz-core-mechanics-redesign.md`
**Builds on:** Plan 1 (`docs/superpowers/plans/2026-05-25-dngrz-deterministic-core.md`, merged PR #1) — the pure deterministic core.
**Reviewed by:** architecture-sage, network-architect, gameplay-coder, mechanics-architect (2026-05-25 cross-agent review). This design incorporates their findings.

---

## 1. Purpose

Plan 1 built the pure, deterministic resolution core (fixed-tick clock, seeded RNG, the Command structs, `ContactResolver`, `predict_crossing`). It is fully unit-tested but **not yet playable** — nothing wires it into a live loop. Plan 2 makes the redesigned at-bat **playable and feel-testable**: a live, tick-driven duel with real controls, honest pitch readability, and — per the cross-agent review — a **thin static defense** so that placement is a real decision rather than decoration.

This design replaces the `scenes/_gate1.gd` orchestrator (`_process(delta)` + `await` timers) with a tick-driven `AtBatDirector`, and removes the deprecated `ContactCalculator`.

---

## 2. Decisions (locked)

- **Presentation:** reuse the existing 3D field scene + `BattingView`/`PitchingView` overlays as a placeholder. The camera/view redesign stays deferred (parent spec §12); Plan 2 only adds fielder markers + a break-marker chevron + observable-only data.
- **Controls:** **one-stick is the default** (left stick aims the contact cursor *and* supplies the at-commit placement direction, Mario-style, latched at button-down); **two-stick is a toggle** (right stick = placement). Both feed the same `SwingCommand`, so the scheme is a controller-layer concern. Keyboard scheme deferred. *(Reversed from an earlier two-stick-first call after mechanics-architect + gameplay-coder both flagged at-commit right-stick as a fourth simultaneous skill that fights "easy to pick up.")*
- **Thin static defense pulled forward into Plan 2** *(mechanics-architect)*: a **static** fielder layout + `BattedBallResolver` v0 (did the batted ball land within a fielder's reach? → out/hit). This makes placement consequential and lets Plan 2 test parent-spec §11.3. Pitcher-driven shifting, alignment UI, and the richer pitcher (meter/in-flight bend) stay in Plan 3.
- **Bunt deferred** (consistent with swing-cancel → v1.1).

---

## 3. Scope

### In Plan 2
- **`AtBatDirector`** — tick-driven phase FSM + wiring; holds the hidden truth; the live loop.
- **`BallFlight`** — the read-vs-truth projection: trajectory + start_tick → analytic `BallStateAtTick` at any tick; the single home of the float→tick rounding and the seam Plan 3's bend will modify.
- **`AtBatResolver`** — pure static `resolve(PitchCommand, SwingCommand|null) -> AtBatOutcome`.
- **`AtBatOutcome`** — data: outcome kind + `ContactResult` + batted trajectory + crossing geometry.
- **Swing FSM** in `BatterController`, stepping on an **input struct** (human and AI feed the same struct = the one commit path); one-stick default + two-stick toggle.
- **`BatterAI`** reworked to observable-only input + its own seeded RNG, emitting a `SwingCommand` via the same path.
- **`PitcherController`/`PitcherAI`** emit a `PitchCommand` (director stamps `rng_seed` + `start_tick`).
- **Thin static defense:** `FieldAlignment` (plain-data fielder snapshot), `BattedBallResolver` v0, `PlayOutcome` (carries the geometry a richer system will need); fielder markers + out/hit feedback in the scene.
- **`BattingView`** changes: remove the true-target cheat; add `observable_predicted_landing` (from observable `predict_crossing`) + a **break-marker chevron** (appears early in flight).
- New gamepad **input actions** in `project.godot`.
- **Live-tunable** `PITCH_TIME_SCALE` + break-marker magnitude + a **debug "reveal" toggle** (to verify reading skill is real).
- **Remove** `scenes/_gate1.gd` and `src/core/contact_calculator.gd` (+ its test).

### Out (Plan 3 / later)
Pitcher meter + in-flight bend + defensive alignment shifting + alignment UI; bunt; polished keyboard scheme; camera/view redesign; swing-cancel/check-swing; baserunning, throws, fielder animation; networking transport. *(Note: the `tier`/Phenom layer is being explored in a separate design track; Plan 2 only carries the existing `PitchTypes.Tier` flag and adds no Phenom mechanics.)*

---

## 4. Architecture

Module map (**bold = new in Plan 2**, *italic = modified*):

| Module | Home | Responsibility | Interface |
|---|---|---|---|
| **`AtBatDirector`** | `src/game/at_bat_director.gd` | Owns the advancing integer tick, the phase FSM, the hidden truth (`PitchCommand`+seed), and wiring. Drives the live loop; never computes contact/placement inline. | `step_tick()`; `get_view_state() -> AtBatView` |
| **`BallFlight`** | `src/ball/ball_flight.gd` | Wraps a `BallTrajectory` + `start_tick`. The read-vs-truth projection + the float→tick rounding home + the Plan-3 bend seam. Pure (RefCounted). | `static from_pitch(PitchCommand) -> BallFlight`; `crossing_tick() -> int`; `state_at_tick(int) -> BallStateAtTick` |
| **`AtBatResolver`** | `src/core/at_bat_resolver.gd` | Pure static resolution of an entire at-bat from commands alone. | `static resolve(pitch: PitchCommand, swing: SwingCommand) -> AtBatOutcome` (swing may be `null` = take) |
| **`AtBatOutcome`** | `src/data/at_bat_outcome.gd` | Result of an at-bat. | `{kind: Kind, contact: ContactResult, batted_trajectory: BallTrajectory, crossing_position: Vector3, crossing_tick: int}` where `Kind {WHIFF, CONTACT, TAKE_STRIKE, TAKE_BALL}` |
| **`FieldAlignment`** | `src/fielding/field_alignment.gd` | Plain-data fielder-position snapshot (from `FieldConstants.FIELDER_POSITIONS` + future shift deltas). | `{position_key -> Vector3}`; `static default() -> FieldAlignment` |
| **`BattedBallResolver`** | `src/fielding/batted_ball_resolver.gd` | Pure: batted trajectory + alignment snapshot → out/hit. | `static resolve(trajectory: BallTrajectory, alignment: FieldAlignment) -> PlayOutcome` |
| **`PlayOutcome`** | `src/data/play_outcome.gd` | Out/hit + the geometry a richer system grows into. | `{is_out: bool, landing_point: Vector3, nearest_fielder: String, reach_margin: float}` |
| **`AtBatView`** | `src/game/at_bat_view.gd` | One read-only view-model the views pull each frame. | `{phase, ball_state: BallStateAtTick, prev_ball_state: BallStateAtTick, break_marker: Vector2, observable_landing: Vector2, swing_locked: bool, last_play: PlayOutcome}` |
| *`BatterController`* | `src/batter/batter_controller.gd` | Hosts the swing FSM; steps on an input struct; emits `SwingCommand`. | `step(input: SwingInput, tick: int)`; `signal swing_committed(SwingCommand)` |
| *`BatterAI`* | `src/batter/batter_ai.gd` | Produces the same `SwingInput`/`SwingCommand` from observable state + seeded RNG. | `compute_command(observable: BallStateAtTick, crossing_tick, current_tick, balls, strikes, rng) -> SwingCommand` (null = take) |
| *`PitcherController`/`PitcherAI`* | `src/pitcher/…` | Emit a `PitchCommand`. | `signal pitch_committed(PitchCommand)` |
| *`BattingView`* | `scenes/ui/batting_view.gd` | Renderer only; observable data + break-marker chevron. | pull from `AtBatView` |

### 4.1 The tick loop (architecture-sage C2, network-architect C1, gameplay-coder R1)
- `AtBatDirector` is driven by **`_physics_process` as a one-line trampoline**: `func _physics_process(_delta): step_tick()`. **All** logic lives in `step_tick()` — there is exactly one tick code path; tests call `step_tick()` directly.
- `var _tick: int` is **incremented by exactly 1 per `step_tick()`**. `delta` is never read by any resolution path. Gameplay time = tick count.
- `_ready()` **asserts `Engine.physics_ticks_per_second == SimClock.TICK_RATE`** (or sets it from the constant) to prevent silent desync. Director `process_mode = ALWAYS` is set explicitly so pause semantics are intentional.
- The body of `step_tick()` is the **future authoritative-server loop seam** — documented as single-player scaffolding so a server can drive ticks without a scene tree.

### 4.2 Phase FSM
`IDLE → PITCH_IN_FLIGHT → RESOLVED → RESULT → (IDLE)`. The `RESULT` pause is a **tick countdown** (`RESULT_TICKS = SimClock.seconds_to_ticks(2.0)`), never an `await` (network-architect M1).
- **IDLE:** pitcher commits a `PitchCommand`; director stamps `rng_seed` (from one `RandomNumberGenerator.randomize()`'d at scene start, `.randi()` per at-bat) and `start_tick = _tick`; builds `BallFlight.from_pitch(pitch)`; → PITCH_IN_FLIGHT.
- **PITCH_IN_FLIGHT:** each tick, feed `BatterController.step(input, _tick)` and update the view-model with `flight.state_at_tick(_tick)` (observable only). On commit, store the `SwingCommand`. When `_tick >= flight.crossing_tick()` → resolve.
- **resolve:** director-level **tick-window acceptance check** on `swing.commit_tick` (network-architect I2; loose single-player bounds, comment "server replaces these bounds"); `outcome = AtBatResolver.resolve(pitch, swing_or_null)`; if `outcome.kind == CONTACT`, `play = BattedBallResolver.resolve(outcome.batted_trajectory, FieldAlignment.default())` and the `Ball` view launches the batted trajectory; → RESOLVED → RESULT.

### 4.3 Resolution is pure over commands (network-architect contracts #1–#9)
`AtBatResolver.resolve(pitch, swing)` reads `pitch.rng_seed` (no separate seed param — architecture-sage C1), rebuilds the `BallFlight` deterministically, samples `BallStateAtTick` at the **rounded** `crossing_tick` (the same rounding `BallFlight` uses everywhere — architecture-sage C3), then:
- `swing != null` → `ContactResolver.resolve(swing, ball_at_crossing)`; on contact, build the batted trajectory via `BallTrajectory.create_batted(...)` so `AtBatOutcome.batted_trajectory` is populated for the downstream defense call.
- `swing == null` (take) → `StrikeZone.is_strike(crossing_position)` → `TAKE_STRIKE`/`TAKE_BALL`.

This keeps the authoritative outcome a pure function of `(PitchCommand, SwingCommand)` — a future server resolves from the two commands alone. The director's live `BallFlight` is for presentation/timing only.

### 4.4 Read-vs-truth, enforced live (parent spec §7; all four reviewers)
The director holds `PitchCommand` (truth). It hands `BatterController`, `BatterAI`, and `BattingView` **only** `BallStateAtTick` (computed **analytically** via `BallFlight.state_at_tick`, never sampled from the live `Ball` node) plus the pitch's `break_marker`. The current `BattingView.predicted_landing = StrikeZone.get_plate_position(true_target)` cheat (`_gate1.gd:140`) is deleted; the growing incoming-ball cue is re-anchored to `observable_predicted_landing` (from observable `predict_crossing`), which drifts as the break manifests — **that drift is the read challenge.**

### 4.5 Controls (gameplay-coder R2/R3; mechanics-architect Q3)
- New `project.godot` joypad input (sticks read via `Input.get_joy_axis` / actions; swing on a face button).
- **Input is sampled into a `SwingInput` struct** `{cursor: Vector2, commit_pressed: bool, placement_dir: Vector2}` by a thin sampling layer; the FSM transitions consume the struct, never the `Input` singleton (architecture-sage M3) — this is what makes the FSM unit-testable and lets the AI feed the identical struct.
- **One-stick default:** left stick moves the cursor continuously; at button-**down**, the left stick's current direction is latched as `placement_dir` (centered ⇒ up-the-middle). **Two-stick toggle:** right stick supplies `placement_dir`.
- `commit_tick` and `placement_dir` latch at button-**down**. Tap vs hold by held-tick count (`TAP_THRESHOLD_TICKS = 6` ≈ 100 ms) → `CONTACT`/`POWER`. **Hold past `crossing_tick` ⇒ auto-commit POWER** with the latched placement (gameplay-coder R3).
- Timing feel: aim the `PERFECT` band at ~3–4 ticks to absorb input+display latency (gameplay-coder R6).

### 4.6 Views pull (architecture-sage I2/I3)
The director exposes one `get_view_state() -> AtBatView` carrying current **and previous** `BallStateAtTick`. Views read it in `_process` and **interpolate** via `Engine.get_physics_interpolation_fraction()` so the ball doesn't snap once per tick. `BattingView`'s `@export` setters already queue redraws, so it stays a dumb renderer; it gains a break-marker chevron and the observable-landing anchor.

### 4.7 Defense flow (mechanics-architect; parent spec §3 growth contract)
Static only in Plan 2: `FieldAlignment.default()` reads `FieldConstants.FIELDER_POSITIONS`. After a `CONTACT` outcome, `BattedBallResolver.resolve(batted_trajectory, alignment)` computes the landing point, the nearest fielder, and the reach margin → `is_out`. Fielders render as static markers; the scene shows out vs hit. `PlayOutcome` already carries the richer geometry (landing point, nearest fielder, reach margin) so Plan 3's shifting/baserunning consume it without changing the contract.

---

## 5. Testing

- **`AtBatResolver` + `AtBatOutcome`** (pure): full unit coverage — whiff/contact/take-strike/take-ball; deterministic by `pitch.rng_seed`; perfect-timing swing at the rounded crossing tick yields `quality > 0.99` (guards the float→tick boundary, architecture-sage C3).
- **`BallFlight`** (pure): `state_at_tick` analytic correctness; `crossing_tick` rounding; determinism by seed.
- **`BattedBallResolver` + `FieldAlignment` + `PlayOutcome`** (pure): ball into a gap → hit; into a fielder's reach → out; reach-margin geometry correct.
- **`AtBatDirector`**: tested by calling `step_tick()` directly (no real frames/timers), injecting `PitchCommand`/`SwingInput`, asserting phase transitions, the tick-window acceptance check, and the RESULT countdown.
- **`BatterController` FSM**: feed a `SwingInput` sequence, assert the emitted `SwingCommand` (commit_tick + placement_dir latched at button-down; tap vs hold; hold-past-crossing → POWER).
- **`BatterAI`**: deterministic by its seeded RNG; never receives truth/seed; emits a valid `SwingCommand`.
- **Not headless-testable** (Godot limitation): `_draw` rendering (break-marker chevron, fielder markers) and analog feel — flagged for manual check.

---

## 6. Success criteria for Plan 2

With the static-defense sliver, Plan 2 can test parent-spec §11.1 (reading), §11.2 (timing), **and §11.3 (aiming at a hole is a real decision)**. §11.4 (voluntary replay) remains only partially indicative until Plan 3's richer pitcher/shifting. The build must make `PITCH_TIME_SCALE` + break magnitude live-tunable and include a debug reveal toggle so §11.1 is measurable (mechanics-architect Q4) rather than guessed.

A Plan 2 feel-test PASSES if, over 20+ at-bats: reads change swings (not guesses), well-timed contact feels meaningfully better than mistimed, and placing into a visible gap feels earned. Failing these after a tuning week escalates to design-level re-evaluation (parent spec kill-switch).

---

## 7. What Plan 3 becomes

With defense's static sliver in Plan 2, Plan 3 narrows to **delivery richness + dynamic defense**: pitcher power/accuracy meter, in-flight bend (plugs into `BallFlight` — the seam isolated in Plan 2), defensive alignment shifting + its UI, and consuming `PlayOutcome` toward baserunning. The `tier`/Phenom gesture layer remains a later additive pass (and is being explored in a separate design track).
