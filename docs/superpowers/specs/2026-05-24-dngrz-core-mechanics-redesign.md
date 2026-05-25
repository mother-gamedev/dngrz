# DNGRZ — Core-Mechanics Redesign

**Date:** 2026-05-24
**Parent spec:** `docs/superpowers/specs/2026-05-22-dngrz-v1-scope-design.md`
**Supersedes:** the batting/pitching feel model tested in Gate 1 (`docs/superpowers/gates/2026-05-23-gate1.md`)
**Validated by:** game-mechanics research (Mario Superstar Baseball, MLB The Show, Super Mega Baseball), an architecture review, and a network-architecture review (2026-05-24 session).

---

## Purpose

Gate 1 (the bare pitch/bat duel) tested as **not fun** — batting felt arbitrary. This spec redesigns the core so the duel is a genuine *skill* duel, and reframes the prototype to include the one thing that makes a swing a decision: **a defense to hit around.**

The redesign is grounded in three findings about *why* Gate 1 failed (all confirmed in code, not vibes):

1. **There was nothing to read.** The batting overlay drew the ball's *true* landing spot from the instant of release, and pitch *type* was never surfaced to the batter. Reading the pitch was impossible by construction.
2. **Timing didn't matter.** The contact window was ~±0.3s — almost any swing connected, and mistimed contact still launched the ball at 40% power.
3. **Aim was decorative.** `ContactCalculator` measures placement against the *zone center*, not against where the ball actually is — it never receives the ball's position at all. **Spatial aim has never been wired.**

Finding 3 is the headline: the most fundamental fix is a humble data-flow correction, independent of any new mechanic.

---

## Design pillars

- **North star:** Mario Superstar Baseball — easy to pick up, deep enough to reward mastery; cross-checked against MLB The Show (Zone hitting, meter/gesture pitching) and Super Mega Baseball.
- **The swing is a decision, not a reflex check.** *Read the pitch → aim the cursor → choose how to meet it → place it where the defense isn't.*
- **Skill is layered, not single-axis.** Reading, spatial aim, timing, and placement are distinct skills that compound.
- **Honest information.** What the batter *perceives* (the ball in flight) is the only channel for reading the pitch — never a pre-revealed answer. This is both the read-vs-truth contract (§7) and the network authority boundary (§9).
- **Deterministic core.** Resolution is a pure function of inputs + seed + tick. This serves single-player feel *and* makes online multiplayer an additive layer, not a rewrite (see §9).

---

## Scope

### In this spec (the redesigned core mechanics)
- The **at-bat**: pitch read, contact-zone cursor aim, swing commitment (contact/power), directional placement (spray + trajectory), bunt.
- The **delivery**: defensive alignment, pitch-type select, aim, timed power/accuracy meter, in-flight bend. Tiered execution (basic now; gesture/"Phenom" later).
- **Thin defense**: ~5–6 shiftable fielders; batted-ball-vs-fielder-snapshot resolution → out/hit.
- The **contact model** and explicit **input precedence**.
- The **swing state machine** with latch-at-press rules.
- The **read-vs-truth contract** and **plate-plane contact-space contract** (the slice of "camera" that cannot be deferred).
- The **determinism & networking contracts** that the implementation must respect now.

### Deferred to the *next* design pass (not this spec)
- **Camera / view / visuals / animation.** Specifically the unresolved tension: a pitch reads best from a batter's-eye view, but defensive holes read best from a field view. This is its own design session. *This spec freezes the input space (§7) so that design can proceed without reworking the controller.*

### Out of the redesigned core (deferred to later milestones, no rewrite required)
- **Swing-cancel / check-swing** — doable via tap-vs-commit (MLB The Show model), but deferred to v1.1 so it doesn't bog the core.
- **Phenom gesture/combo pitch input** — gesture recognition is its own subsystem. The core carries a `tier` flag + modifier hook only; the gesture layer is additive presentation/skill expression.
- **Real fielding, baserunning, throws** — `PlayOutcome` is shaped to grow into these (§3) without changing the resolution contract.
- **Actual netcode transport** (ENet, RPC wiring, matchmaking, server process) — the contracts in §9 make this additive.
- **Momentum / factions / tactical layer** — kept as *post-resolution modifier hooks*, never inside the resolver.

---

## 1. The at-bat (batting)

Phases of a single pitch from the batter's side:

1. **Pre-pitch read.** The defensive alignment is visible. The batter decides which gap to hunt.
2. **Release & flight.** The batter identifies pitch type and location only by observing the ball: release point, flight speed, and a **break-direction marker** (a legibility aid, see §8). Pitches are slowed (the existing `PITCH_TIME_SCALE` knob) so the window fits **two sequential actions** — reposition *then* time — not one. This is precisely what Gate 1 got wrong.
3. **Aim.** The batter moves a **contact-zone cursor** to where they predict the ball crosses the plate. This is the spatial-aim skill that was never wired.
4. **Commit.** A single swing button:
   - **Tap = contact swing** — larger effective contact zone, less power.
   - **Hold = power swing** — contact zone shrinks, more power, higher fly-out risk.
5. **Place.** At the commit instant, a **directional input** sets where the ball is meant to go: horizontal = spray (pull/oppo), vertical = trajectory (ground ball ↔ line drive ↔ fly ball). Centered = line drive up the middle. **Bunt is a separate button**, not a directional combo.
6. **Resolve.** Contact quality is a function of timing precision, cursor-vs-ball overlap, and swing type. The directional input sets the *intended* spray/launch; contact quality determines how faithfully that intent is realized (poor contact degrades toward weak grounders/pops regardless of intent).

### Control model (gamepad-first; keyboard is a best-effort fallback)
The primary scheme is **two-stick**, which cleanly separates the two distinct skills the architecture review identified (continuous aim vs. instantaneous placement) and removes input ambiguity:
- **Left stick** — moves the contact-zone cursor (continuous, before commit).
- **Right stick** — directional placement (spray + trajectory), **sampled and latched at the commit instant**; centered = up-the-middle line drive.
- **Swing button** — tap = contact, hold = power.
- **Bunt button** — separate.

**Trajectory convention:** intuitive by default (push up = elevate/fly, down = ground ball). *Playtest note:* Mario and Super Mega Baseball both use the inverted convention (up = grounder); if intuitive feels wrong, flip it — this is a one-line tuning toggle, not an architectural choice.

**Open playtest question (does not block the spec):** a simpler **one-stick** scheme (left stick both moves the cursor and supplies the at-commit direction, Mario-style) is the fallback if two-stick feels overloaded at the contact moment. Both schemes feed the *same* `SwingCommand` (§9), so switching is a controller-layer change only.

---

## 2. The delivery (pitching)

Phases of a single pitch from the pitcher's side:

1. **Set the defense.** Shift the fielders into an alignment (produces a `FieldAlignment` snapshot, §3).
2. **Pick pitch type** from the realistic set (fastball, curveball, slider, changeup; `tier` flag reserved for later Phenom pitches).
3. **Aim** a target reticle to a plate location.
4. **Execute the meter.** A timed power/accuracy input: maxing power costs accuracy (the tempo tension). This is the proven two-stage meter (power, then accuracy).
5. **Bend in flight.** Steer the ball after release; **perfectly-timed pitches bend the least** (the accuracy-vs-movement tradeoff, lifted from Mario).

**Tiered execution:** basic pitches use the meter. Special "Phenom" pitches will later require a gesture/combo to pull off — *out of scope here*, but the `tier` field on the pitch command must exist now so the layer is additive.

**View note (informs the deferred camera pass):** the pitching turn contains an internal view transition — defensive alignment is a field-view task, while reticle aiming is a plate-view task. The camera design pass must account for this.

---

## 3. Thin defense — what makes the swing a decision

The minimal-but-real defense layer (the part Gate 1 cut entirely):

- **~5–6 fielders** at positions the pitcher shifts pre-pitch.
- A batted ball resolves against a **snapshot of fielder positions**: lands within a fielder's reach → out/fielded; lands in a gap → hit.
- **No baserunning, no throw animations, no fielder behavior yet** — only *"did it find a hole?"* That single question turns aiming into a genuine choice.

### Growth contract (so this never needs a rewrite)
- `FieldAlignment` = a plain-data snapshot of fielder positions (the existing `FieldConstants.FIELDER_POSITIONS` plus shift deltas).
- `BattedBallResolver.resolve(trajectory, FieldAlignment) -> PlayOutcome` is a **pure function over the snapshot**, never over live fielder nodes.
- `PlayOutcome` carries the **geometry a richer system will need** — landing point, nearest fielder, reach margin — even though v0 only branches out/hit. Real fielding later replaces only the resolver's internals; baserunning consumes `PlayOutcome` downstream; throw animations react to it. None change the contract.

---

## 4. Contact model & input precedence

`ContactCalculator` is replaced by **`ContactResolver`** with a corrected signature. The current model conflates "placement vs. ball" with "placement vs. zone center," hardcodes pitch speed, and derives spray from timing (`h_angle = timing × factor`) — which directly fights stick-at-contact placement.

The re-derived precedence:

| Input | Governs |
|---|---|
| **Cursor vs. actual ball position** at the contact plane | Whiff vs. contact, and base contact quality (the resolver **must receive ball state**). |
| **Swing timing** (button-down vs. crossing tick) | Contact quality, plus a small natural pull/oppo lean (early → pull, late → oppo). |
| **Directional input** (latched at commit) | **Authoritative** intended spray and trajectory. |
| **Tap vs. hold** | Power output and contact-zone size (contact = bigger/weaker, power = smaller/stronger). |

Poor cursor overlap or poor timing degrades the realized result toward weak contact, *regardless of* the directional intent — so intent is honored only to the degree the swing was well-executed.

---

## 5. The swing state machine

Four inputs converge near the commit moment (cursor position, directional placement, tap/hold, timing). They are coherent **only when separated in time**, via an FSM living in `BatterController`:

```
IDLE → READY            (at-bat armed)
READY → AIMING          : cursor moves continuously
AIMING → CHARGING       : swing button DOWN
                          → latch commit_tick (timing)
                          → latch directional input (placement)
CHARGING → COMMITTED     : button released within hold threshold → contact (tap)
                           OR hold threshold elapsed → power (hold)
COMMITTED → RESOLVED     : ball reaches contact plane → ContactResolver
(any) → TAKEN            : ball passes the plane, never committed
```

**Latch rules (must be explicit):**
- **Timing is always the button-*down* instant**, for both tap and hold — otherwise power swings read unfairly late.
- **Directional placement is latched at button-down**, so stick drift during the hold window doesn't penalize the player.
- **Hold duration selects swing *type* only** (~80–120ms threshold), never timing.
- **The AI batter drives this same FSM** (it sets cursor/direction/commit as inputs). There must be **one commit path**, not the current parallel `await`-timer path in `_gate1.gd`, which races the human commit.

---

## 6. Module architecture

The codebase already separates pure data/math from scene nodes, and `src/{game,fielding,baserunning,camera,field}` are scaffolded. Formalized modules (**bold = new**, *italic = exists, mostly survives*):

| Module | Responsibility | Home | Interface (data → data) |
|---|---|---|---|
| *PitchTypes* | Static pitch catalog | `src/data` | survives; add break-marker + `tier` fields |
| *BallTrajectory* | Pure flight math | `src/ball` | survives; add `predict_crossing()` query; accept seeded RNG |
| *Ball* (Node3D) | Renders a trajectory; emits arrival/landing | `src/ball` | becomes a pure *view* of `BallTrajectory` |
| **PitchCommand** | Authored pitch intent | `src/data` | `{type, target, power, accuracy, bend, tier, seed}` |
| **SwingCommand** | Committed swing snapshot | `src/data` | `{cursor_point, swing_type, placement_dir, commit_tick}` |
| **BallStateAtTick** | Per-tick observable ball state | `src/data` | `{position, velocity}` — the batter-visible projection |
| **ContactResolver** (replaces *ContactCalculator*) | timing × cursor-vs-ball × swing-type → batted-ball params | `src/core` | `resolve(SwingCommand, BallStateAtContact) -> ContactResult` |
| **BattedBallResolver** | batted trajectory + fielder snapshot → outcome | `src/fielding` | `resolve(trajectory, FieldAlignment) -> PlayOutcome` |
| **FieldAlignment** | Fielder positions + shift deltas | `src/fielding` | `{position_key -> Vector3}` |
| *BatterController / PitcherController* | Input → Command; the swing FSM lives here | `src/batter`, `src/pitcher` | emit serializable Commands |
| **AtBatDirector** (replaces `_gate1.gd` orchestration) | Tick-driven phase FSM + wiring only | `src/game` | owns phases; computes no timing/placement inline |

The `_gate1.gd` god-orchestrator splits: `AtBatDirector` (phases + wiring), resolver calls, and view-binding where **views pull/subscribe rather than the director pushing every frame**.

---

## 7. Read-vs-truth contract & plate-plane contact-space contract

### Read-vs-truth (also the network authority boundary, §9)
Three explicit views of one at-bat:
- **TRUTH** (authoritative): full `PitchCommand` + seed + resolved crossing point + break. Never delivered in full to the batter.
- **PITCHER VIEW:** own target/meter/outcome + flight.
- **BATTER VIEW:** release point, per-tick `BallStateAtTick` (the readable flight + break marker), strike-zone context — but **not** the true target or seeded inaccuracy. The batter reads truth only by observing the ball, exactly as in real baseball.

`PitchCommand` (truth) and `BallStateAtTick` (observable) **must be distinct types** so the hidden-information boundary is structural, not bolted on.

### Plate-plane contact-space contract (the un-deferrable slice of "camera")
The cursor and directional input operate in a **fixed 2D plate plane** (x = horizontal, y = height), **independent of whatever camera renders it.** The camera/visual pass defers the *renderer*, not the *input space*. If the camera were allowed to define the input space, swapping views later would rewrite the controller.

---

## 8. Pitch readability

- Pitch identity is cued by **release point + flight speed/trajectory**, reinforced by a **break-direction marker** (chevron-style) as the honest, in-flight version of "what's coming."
- The flight window must accommodate **reposition-then-time** (two sequential actions). `PITCH_TIME_SCALE` is the tuning knob.
- `BallTrajectory` needs a `predict_crossing()` query so the break marker reflects predicted movement rather than the current cheat of drawing the true authored target.

---

## 9. Determinism & networking contracts

**Topology decision:** client-server **authoritative**, with a **custom fixed-tick simulation loop** and a **delay-based input model**. *Not* rollback, *not* P2P lockstep, *not* Godot's high-level scene replication for the duel. The discrete at-bat (two consequential inputs, ~1s flight window) lets the server collect both commands, resolve once on an authoritative tick, and broadcast — rollback-grade timing fairness with no re-simulation, because the flight window absorbs realistic latency.

**Authority:** server owns the hidden truth (target/break/seed), validates both commands against the tick window, and runs both resolvers. Clients render authoritative state; presentation never feeds back into resolution. A laggy batter is judged on **the tick they were observing at button-down**, not on packet arrival.

**The nine contracts the implementation must respect now** (cheap now, rewrite later — most are also single-player correctness fixes):

1. **All consequential input is a serializable Command struct stamped with an integer tick.** (`PitchCommand`, `SwingCommand`.) No gameplay decision rides on node state or signals alone.
2. **Resolution is a pure function of (commands + seed + tick).** Same inputs → same output on any machine, every time.
3. **No resolver reads live node transforms, `delta`, wall clock, or global RNG.** Snapshots in, results out.
4. **The simulation clock is a fixed integer tick** (recommend 60). Gameplay time = tick count; presentation may interpolate between ticks. This **replaces** `ball.gd`'s `_time += delta` and `_gate1.gd`'s `Time.get_ticks_msec()` — the same fix that makes timing feel crisp.
5. **All randomness flows from a seeded, server-owned RNG passed explicitly.** Refactor `BallTrajectory.create_pitch` to accept an RNG/seed; ban global `randf*` from any resolution path. The at-bat seed is part of the truth record.
6. **Truth is projected into per-player views** (`PitchCommand` vs `BallStateAtTick` as separate types).
7. **The `AtBatDirector` FSM is tick-driven**, never `await get_tree().create_timer(...)`.
8. **Inputs carry the tick they were observed at**; resolution accepts/rejects by tick window (`SwingCommand.commit_tick`).
9. **Intent is separated from presentation everywhere** — controllers emit Commands; views render authoritative state.

**Timing on the wire:** tick-based, not timestamp-based. `crossing_tick = start_tick + flight_ticks`; `timing_offset = (commit_tick − crossing_tick) / tick_rate`. Ticks are exact integers and need no clock-sync; timestamps would re-introduce float drift and NTP-style skew.

**Godot 4.6 fit:** `ENetMultiplayerPeer` + reliable `@rpc` for the discrete commands + a custom authoritative tick loop. `MultiplayerSynchronizer`/`Spawner` are unsuitable for the timing-critical duel (they stream transforms — the frame-coupled thing we're eliminating) but fine for cosmetic/lobby state.

**One-way doors (decide now):** fixed tick clock; tick-stamped Commands; pure resolvers over snapshots; seeded explicit RNG; truth/observable split; analytic tick-addressed crossing; tick-driven FSM.

**Safe to defer (additive, no rewrite):** transport/RPC wiring, server process, matchmaking/lobby/NAT, edge distribution, and **fixed-point math** — only needed if clients later re-simulate contact for zero-latency feedback (with a single authoritative server, float32 + the existing `_EDGE_EPSILON` discipline is sufficient). Keeping resolvers pure makes that swap mechanical.

---

## 10. Files affected

- **Replace:** `src/core/contact_calculator.gd` → `ContactResolver` (corrected signature; receives ball state).
- **Heavily restructure:** `scenes/_gate1.gd` → `AtBatDirector` (tick-driven, no inline timing/placement); `src/batter/batter_controller.gd` (gains the swing FSM).
- **Extend (additive):** `src/ball/ball_trajectory.gd` (`predict_crossing()`, seeded RNG); `src/data/pitch_types.gd` (break marker, `tier`); `src/pitcher/pitcher_controller.gd` (alignment + meter + bend).
- **New, in scaffolded homes:** `src/fielding/` (`BattedBallResolver`, `FieldAlignment`); `src/game/` (`AtBatDirector`); `src/data/` (`PitchCommand`, `SwingCommand`, `BallStateAtTick`).
- **Clock refactor first:** `ball.gd` (`_time += delta` → tick-addressed) and `_gate1.gd` (timer awaits → FSM ticks) — highest-leverage determinism fix, independently useful single-player.
- **Survives:** `ball.gd` (as view), `strike_zone.gd`, `field_constants.gd`, both AI `decide()` functions (payloads widen to Commands; seed AI RNG if AI must be authoritative/replayable).

---

## 11. Success criteria (how we know the redesign worked)

This redesign re-opens the question Gate 1 asked, now with the spatial layer included. Pass criteria (self-report after 20+ at-bats per side):

1. **Reading is a skill.** You can describe distinct moments where you correctly (or incorrectly) *read* a pitch type/location out of the hand and it changed your swing — not guessed.
2. **Timing is rewarded.** Well-timed contact feels meaningfully better than mistimed; a whiff feels like *your* read/timing failure, not arbitrary.
3. **Aiming at the hole is a real decision.** Placing the ball into a gap in the defense feels earned and consequential — the defense's alignment visibly matters to your choice.
4. **Voluntary replay.** You play more than one session unprompted within a week of it being playable.

Failing 1–3 after a tuning week → escalate to a design-level re-evaluation (per the parent spec's kill-switch discipline). The redesign's first job is to make 1–3 *possible at all*, which Gate 1's mechanics prevented.

---

## 12. Next design pass

**Camera / view / visuals / animation.** Central knot to solve there: reconciling the batter's-eye view (best for reading a pitch) with a field view (best for spotting defensive holes), plus the pitcher's in-turn view transition (alignment vs. reticle). This spec has frozen the **plate-plane input space** (§7) so that pass can proceed without reworking the controller.
