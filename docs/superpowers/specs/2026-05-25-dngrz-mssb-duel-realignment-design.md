# DNGRZ — MSSB-Faithful Duel Realignment (Plan 3a)

**Status:** Approved design (2026-05-25)
**Supersedes:** the *quality model* of `2026-05-25-dngrz-batting-feel-redesign.md` (timing-as-quality). The deterministic core, structs, and tick architecture from Plans 1–2 are unchanged.
**Builds on:** `2026-05-24-dngrz-core-mechanics-redesign.md` (Plan 3 = the decision layer). This is the **pitcher-skill + batting-realignment** slice of Plan 3.

## 1. Why this exists

The merged "timing-first" batting was feel-tested only "fine enough." Deep real-code research into our closest comp — **Mario Superstar Baseball**, via the `roeming/mssb-dtk` decompilation (`src/game/game_batter.c` is fully decompiled) — revealed that our model and MSSB's proven model are **inverses**:

| | Our merged "timing-first" | MSSB (proven) |
|---|---|---|
| Whiff gate | timing `dt` window | swing-frame window + bat reach |
| **Quality axis** | **timing** falloff | **spatial** — distance from your **cursor** |
| Cursor | removed | free analog cursor you drag to track the ball |
| Location measured from | zone center | **your cursor** |

Crucially, **our earlier free-cursor failure was an MLB-The-Show-Zone implementation, not MSSB.** The Show grades on a tiny PCI with punishing precision. MSSB grades on a **wide (~1.0-unit) bat**, a **smooth 0→200 quality ramp**, and PERFECT/NICE band widths that are **lerp-widened by a `contactSize` stat + an easy-mode table**. *"Easy to make contact, hard to make perfect."* That tunable forgiveness is the arcade-casual + esports-depth dial.

We realign the **whole duel** to MSSB's formula. Full research notes: memory `dngrz-mssb-decomp-research`.

## 2. Pillars (esports invariants)

1. **Perfect information** — the batter can see everything they need in time (live observable landing dot + break cue + the 3D ball; deterministic physics). No hidden late surprises with no tell.
2. **Symmetric counterplay** — every tool has an answer. The pitcher's curve is answered by the batter's cursor tracking; the batter's tracking is answered by the pitcher's late break + speed/movement tradeoff.
3. **Determinism** — integer ticks, seeded RNG, authoritative input streams, truth record distinct from observable. Replayable.
4. **Forgiveness is a dial, not a constant** — the same systems serve a newcomer (wide bands) and a tournament (narrow bands) via a single `contact`/difficulty parameter.

## 3. The Batter

### 3.1 Forgiving cursor (re-introduced, MSSB-tuned)
- Re-activate `SwingInput.cursor` and `SwingCommand.cursor_point` (currently retained-but-deprecated ZERO vestiges). The cursor lives in **normalized plate space** — the same space `StrikeZone.get_plate_position` returns: `(0,0)` = zone center, `±1` = zone edges.
- The **left stick drags the cursor** (integrated per tick at a tunable speed), clamped to a **reach box** slightly larger than the zone (so you can chase just off the plate). `BatterInput` becomes stateful: it holds `_cursor`, and `sample()` integrates it each tick; the pure `map(left, commit, prev_cursor) -> SwingInput` stays unit-testable.
- The cursor is **frozen at swing-commit** (button-down). `BatterController` latches `cursor_point` alongside the existing `placement` latch. This makes the commit instant unambiguous and removes twitch-after-commit unfairness (MSSB freezes `batPosition2` at swing start).
- Optional panic recenter (a button) snaps the cursor toward center fast — MSSB's 3× L-trigger auto-center. *Phase C polish, not required for A.*

### 3.2 Timing = pure GATE (not quality)
- Keep `ContactResolver`'s existing tick window as the **whiff gate**: `dt = commit_tick − crossing_tick`; `|dt| > whiff_window` ⇒ whiff. Tap (CONTACT) gets the wider window, hold (POWER) the tighter one (`POWER_WINDOW_SCALE`). This is our determinism-safe equivalent of MSSB's slap-2-10 / charge-3-9 frame table.
- **Timing does NOT grade contact quality** (the MSSB-faithful change). The `EARLY/PERFECT/LATE` judgment is reported for the HUD verdict word — *"were you on time"* — but it no longer multiplies quality.
- Timing **does** still bias spray (`TIMING_LEAN`: early → pull, late → oppo), exactly as MSSB indexes its launch-angle table by swing frame. Keep this.

### 3.3 Quality = spatial, measured from the cursor
- At the fixed crossing tick, `ball_plate = StrikeZone.get_plate_position(ball_at_contact.position)`; `offset = ball_plate − swing.cursor_point`; `dist = offset.length()` (**2D** plate-plane distance — our zone is 2D and the ball moves in 2D; lightly horizontal-weighted, mirroring MSSB's X-dominant grading).
- **Spatial reach gate:** `dist > REACH_RADIUS` ⇒ whiff (you couldn't get the bat there). `REACH_RADIUS` is generous and widened by the forgiveness dial — this is MSSB's `batContactRange`, the reason a wide bat feels good.
- **Quality ramp:** within reach, `quality` is a smooth function of `dist` (1.0 at `dist≈0`, falling to 0 at `REACH_RADIUS`), bucketed WHIFF→WEAK→NICE→PERFECT. The **PERFECT/NICE band widths scale with a `contact` forgiveness parameter** (global generosity + difficulty setting now; per-character stat later). This is the single most important tuning surface.
- Net feel target (MSSB): *easy to make contact, hard to make perfect.* Both gates are forgiving; the skill is putting the cursor where the ball will actually be at the plate — which a curve actively fights.

### 3.4 Slap vs charge, spray
- The tap/hold swing FSM (`BatterController`) already maps to MSSB's slap/charge — **reused as-is**. Tap = CONTACT (wider timing gate, wider reach, less power); hold = POWER (tighter, more power). Optionally adopt MSSB's over-charge power decay later.
- **Spray/trajectory stay emergent** for now (one-stick load budget): horizontal = `TIMING_LEAN` + cursor's horizontal position (inside contact → pull); vertical/launch = quality-scaled toward the existing `MISHIT_LAUNCH..FLY_LAUNCH`. No second explicit aim control this slice. (`placement_dir` is derived from cursor + timing rather than a separate latch; explicit spray via a second stick/d-pad is a later option.)

## 4. The Pitcher (MSSB charge + continuous curve)

### 4.1 Sequence
Aim target → select type → **charge** (hold to build power; a tight *perfect-release* window; over-hold decays power) → release → **continuous in-flight curve** (hold the stick during flight; the ball bends toward it).

### 4.2 Power (activates the inert `PitchCommand.power`)
- Power → **pitch velocity**: faster pitch reaches the plate sooner, so the batter has **less read time** (the crossing tick moves *earlier*). Per the timing-first invariant we preserve: this changes *read time*, NOT the tick widths of the timing gate (which stay flight-speed-independent).
- Power → **exit-velocity ceiling**: a squared-up fast pitch leaves the bat harder. (A deliberate divergence — MSSB only does velocity; the user chose velocity + exit-velo.)
- Charged/perfect pitches **curve less** (MSSB's speed-vs-movement tradeoff): scale max bend down with power.

### 4.3 Continuous in-flight bend (activates the inert `PitchCommand.bend`)
- Applied **analytically** at `BallTrajectory.get_position`, after the existing `spin_break` block:
  ```gdscript
  var t_norm := time / flight_duration if flight_duration > 0.0 else 0.0
  pos += Vector3(bend.x, bend.y, 0.0) * (t_norm * t_norm)   # quadratic; peaks at the plate
  ```
- **No z component ⇒ the crossing tick is byte-identical with or without bend.** `BallFlight.crossing_tick()` (z-linear) is unaffected; bend moves only WHERE the ball crosses, never WHEN. This is the contract MSSB's engine enforces (separate `pitchCurveVeloV1/2` vs the fixed `framesUntilBallReachesBatterZ`).
- **Continuous steer** = the pitcher's per-tick stick samples (digitized; MSSB's `anyCurveInput` is left/straight/right) accumulate the `bend` vector, *ramped* toward max over N ticks by a `curveControl` knob (MSSB's 8→2 frame ramp); releasing the stick ramps back toward 0. The director accumulates this each tick and updates the live `bend` used by the observable ball.
- **Determinism:** the per-tick steer samples are authoritative inputs on the tick stream (same status as swing inputs), so replays reproduce. The `bend` value is part of the truth record at each tick. (Implementation note: `BallFlight` gains a mutable `bend` the director advances; `get_position` reads it.)

### 4.4 PHENOM / star pitches
Hook only this slice — the `tier` flag already exists. Later: forced max curve, deterministic-seeded late jump, or apparent-speed change, all at the same analytic seam.

## 5. Roles

Both sides are full MSSB-skill controls. Build **both human paths** (human-bat *and* human-pitch); the **AI fills whichever seat the human isn't in** for solo play. `at_bat_director` gains a role config (replacing the two booleans `enable_pitcher_ai`/`enable_batter_ai` with a clearer human-seat selector). Local same-screen 1v1 falls out; netcode is a later layer.

- **AI batter** (`BatterAI`) sets `cursor_point` by tracking the observable predicted crossing position (MSSB's AI reads the straight-line predicted-X). It emits the same `SwingCommand`.
- **AI pitcher** (`PitcherAI`) authors `power` + a planned `bend` (target-driven curve), not live human steering — parity without a reflex model.

## 6. Component changes (file-by-file)

**Reused unchanged:** deterministic tick core (`SimClock`, `BallStateAtTick`), `PitchTypes`, `BallFlight.crossing_tick()` math, `at_bat_resolver`/`at_bat_outcome` shapes, the tap/hold swing FSM structure, `StrikeZone`.

**Changed:**
- `src/core/contact_resolver.gd` — **rewrite** (TDD). Timing = pure gate; add spatial reach gate + spatial-from-cursor quality with forgiveness-widened bands. Consumes `swing.cursor_point` (un-deprecated). Keep exit-velo, timing-lean spray, launch-degradation shaping.
- `src/data/swing_command.gd` / `swing_input.gd` — un-deprecate `cursor_point` / `cursor`; update doc comments. Struct shapes already correct.
- `src/batter/batter_input.gd` — stateful cursor: hold `_cursor`, integrate from left stick each tick, clamp to reach box; pure `map(left, commit, prev_cursor)`.
- `src/batter/batter_controller.gd` — latch `cursor_point` at commit (restore the cursor latch removed in the timing-first pivot); keep FSM + bat anim.
- `src/batter/batter_ai.gd` — set `cursor_point` from predicted crossing tracking.
- `src/pitcher/pitcher_controller.gd` — charge build + perfect-release window + over-hold decay; sample continuous curve input during flight; emit `power`/`bend`.
- `src/pitcher/pitcher_ai.gd` — author `power` + planned `bend`.
- `src/ball/ball_trajectory.gd` — add the analytic `bend` term (no z).
- `src/ball/ball_flight.gd` — mutable `bend` advanced per tick by the director; `state_at_tick` applies it.
- `src/game/at_bat_director.gd` — role config; pitch charge/curve input collection; bend accumulation into `BallFlight`; cursor bridge to the batting HUD; verdict bridge updated (quality now spatial).
- `scenes/ui/batting_view.gd` — render the cursor + reach indicator; keep the verdict/contact callout (quality source changes).
- `scenes/ui/pitching_view.gd` — drive the existing `release_charge` meter from the real charge; show curve direction; perfect-window cue.
- `scenes/*.tscn` — restore the batter `CursorMarker` (recoverable: `git show 07d75d3^:dngrz/scenes/_gate1.gd` and the pre-pivot batter scene).

## 7. Phasing (for the implementation plan)

- **Phase A — Batter realignment.** Forgiving cursor + timing-gate + spatial-from-cursor quality + forgiveness bands + cursor HUD. Feel-test vs the existing AI pitcher. *Highest feel-risk; first.*
- **Phase B — Pitcher charge + curve.** Charge/perfect-window + power effects + continuous bend; flip so the human can pitch and the AI bats (with cursor tracking).
- **Phase C — Roles + polish.** Both-human/role config, panic recenter, over-charge decay, PHENOM hooks, tuning.

## 8. Testing

- **TDD the `ContactResolver` rewrite first** (RED→GREEN): cases for timing gate (EARLY/LATE whiff), spatial reach gate (cursor too far ⇒ whiff), quality ramp by distance, forgiveness-band widening, exit-velo/spray/launch shaping.
- Pure modules (`BallTrajectory` bend, `BatterInput.map`, `BatterAI`, `PitcherAI`, `BatterController` cursor latch) unit-tested headlessly.
- `_draw` HUD (cursor, charge meter, verdict) stays headless-untested (per `godot-headless-draw-untested`) — eyeball in feel-tests.
- Full gdUnit4 suite green per `dngrz-gdunit4-workflow` (import warm-up + `--ignoreHeadlessMode`); maintain/raise the current 176-test baseline.

## 9. Out of scope

PHENOM/star special behaviors (hook only), netcode/online, baserunning beyond the existing `PlayOutcome`, dynamic field-shift UI (separate Plan 3 slice), camera/visual polish, explicit second-stick spray aim.

## 10. Risks & mitigations

- **Re-introducing a cursor reopens the failure that caused the pivot.** Mitigation: this is the *MSSB* cursor, not the Show cursor — wide reach gate, smooth ramp, forgiveness-widened bands, quality-from-cursor (not zone-center), timing-as-gate. The forgiveness dial is the explicit lever; feel-test Phase A in isolation before adding pitcher complexity.
- **Continuous bend determinism.** Mitigation: per-tick steer samples are authoritative tick-stream inputs; bend is analytic with no z so the crossing tick is invariant; the truth record is reproducible.
- **Pitcher input-chain length** (aim → type → charge → steer). Mitigation: the chain is sequential not concurrent; provide forgiving defaults so a newcomer can throw a serviceable pitch without mastering every stage.
