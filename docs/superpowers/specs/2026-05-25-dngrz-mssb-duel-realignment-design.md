# DNGRZ — MSSB-Faithful Duel Realignment (Plan 3a)

**Status:** Approved design — rev 3 (2026-05-26, after two adversarial-review rounds)
**Supersedes:** the *quality model* of `2026-05-25-dngrz-batting-feel-redesign.md` (timing-as-sole-quality) and **reverses** its decision #1 ("location never gates contact"). The deterministic core, structs, and tick architecture from Plans 1–2 are unchanged.
**Builds on:** `2026-05-24-dngrz-core-mechanics-redesign.md` (Plan 3 = the decision layer). This is the **pitcher-skill + batting-realignment** slice.

## 0. Revision history
- **rev 1:** initial MSSB realignment.
- **rev 2 (red-team #1):** bend → release-time snapshot (pure resolver + determinism preserved); reach-whiff gate; two-field roles; exit-velo de-dup; read-time floor.
- **rev 3 (red-team #2):** the rev-2 "truthful indicator" **over-corrected into a slot-machine pitcher** and was rejected. Now: **honest-but-not-prophetic indicator** (current-state projection that drifts + break cue that telegraphs bend shape *and magnitude*) — you read & predict, nothing lies. **Timing TRADES with spatial** (great timing widens effective reach) so it's a genuine second skill axis with an honest verdict. **Batter regains intentional spray + launch-angle** via cursor position (a trade-off, not a pure penalty). Plus: reach-whiff verdict channel, velocity-clamp (not tick-floor) for read-time, mandatory anisotropic-space weighting, `placement_dir` retired as DEAD (not "derived"), pitcher controller is greenfield, max-power-heater anti-dominance, corrected scene/test notes. Determinism core (snapshot bend) re-verified sound.

## 1. Why this exists
The merged "timing-first" batting felt only "fine enough." Real-code research into our closest comp — **Mario Superstar Baseball**, via the `roeming/mssb-dtk` decompilation (`src/game/game_batter.c` fully decompiled) — showed our model and MSSB's proven model are **inverses**:

| | Our merged "timing-first" | MSSB (proven) |
|---|---|---|
| Whiff gate | timing `dt` window | swing-frame window **+ bat reach** |
| Quality axis | timing falloff | **spatial — distance from your cursor** |
| Cursor | removed | free analog cursor you drag to track the ball |

Crucially, **our earlier free-cursor failure was an MLB-The-Show-Zone implementation, not MSSB.** The Show grades on a tiny PCI with punishing precision. MSSB grades on a **wide (~1.0-unit) bat**, a **smooth quality ramp**, and PERFECT/NICE band widths **lerp-widened by a stat + an easy-mode table**. *"Easy to make contact, hard to make perfect."* That tunable forgiveness is the arcade-casual ↔ esports-depth dial. Full research: memory `dngrz-mssb-decomp-research`.

**Positioning:** esports/truth side of MSSB. We keep its *shape* (cursor tracking, charge, movement, slap/charge) and its *mind-game* (read the pitch, predict the break, scheme placement), but reject **dishonest information** (a dot that lies). Information is honest; it is **not clairvoyant** — mastery is reading + predicting + executing fast, like the comps (Smash/Rocket League: knowable systems, hidden *intent*).

## 2. Pillars (esports invariants)
1. **Honest, non-clairvoyant information.** Every cue is truthful: the landing indicator shows where the ball heads *right now* (it drifts as the late break expresses), and the break cue telegraphs the bend's *shape and magnitude* up front. Nothing lies — but nothing prophesies the exact landing either. The skill is reading those honest cues and predicting, before your commit deadline.
2. **Symmetric counterplay with real risk.** Every tool can be answered, and every answer can be *wrong*. Pitcher's bend = honest but un-prophesied placement; batter's answer = read the cue, predict where it ends up, place the cursor, time it (and they can mis-predict). Batter's tracking = answered by the pitcher's speed (less predict/execute time) + the speed-vs-movement tradeoff + location mixing.
3. **Determinism.** Integer ticks, seeded RNG, pure `(PitchCommand, SwingCommand)` resolution, truth distinct from observable, replayable. No mutable in-flight state on the resolution path. (Re-verified: snapshot bend keeps this intact.)
4. **Forgiveness is a dial, not a constant.** One `contact`/difficulty parameter serves newcomer (wide bands/reach) and tournament (narrow).

## 3. The Batter
### 3.1 Forgiving cursor (re-introduced, MSSB-tuned)
- Re-activate `SwingInput.cursor` + `SwingCommand.cursor_point` (retained-but-deprecated ZERO vestiges — wiring + comments, not a struct rewrite). The cursor lives in **normalized plate space** (`StrikeZone.get_plate_position`: `(0,0)` center, `±1` zone edges).
- **Left stick drags the cursor** (integrated per tick, tunable speed), clamped to a reach region. `BatterInput` becomes stateful (`_cursor` integrated in `sample()`); pure `map(left, commit, prev_cursor) -> SwingInput` (signature change — breaks `test_batter_input`).
- **Frozen at swing-commit** (button-down); `BatterController` latches `cursor_point` (breaks `test_batter_controller`'s `cursor_point==ZERO` assertion).
- **Anisotropy is mandatory, not flavor.** `get_plate_position` normalizes x by half-width (~0.215 m) and y by half-height (~0.3 m) independently, so raw normalized distance is ~1.4× tighter vertically. All distance math (reach gate + quality ramp) uses a **single weighted metric** so the catch zone is a physically coherent shape, and **the input cursor clamp uses that same metric** (so a pinned stick never sits in a corner that auto-whiffs). The weight is a named, tuned knob; using one consistent metric everywhere is required.
- Optional panic recenter (button), Phase C.

### 3.2 Whiff = TWO gates (timing **and** reach), with distinct verdicts
A swing whiffs if **either**:
- **Timing gate:** `dt = commit_tick − crossing_tick`; `|dt| > whiff_window`. Tap (CONTACT) wider, hold (POWER) tighter. → verdict **EARLY / LATE**.
- **Reach gate:** weighted `dist(ball_plate, cursor) > effective_reach`. → a **distinct reach verdict (e.g. "MISSED")**. (Reverses the old "location never gates" decision; intentional — MSSB bat reach.)

`ContactResult` gains a **`whiff_reason`** (or `Judgment.REACH`) so the HUD never flashes "PERFECT" on a swing-and-miss. The timing `Judgment` is still always set.

### 3.3 Quality = spatial (primary) × timing (interacting, not stacked)
The two axes **trade** — this is the esports ceiling and MSSB's "perfect contact" feel:
- **Timing widens effective reach:** `effective_reach = BASE_REACH × (1 + REACH_TIMING_BONUS × timing_q)` (`timing_q` = the existing quadratic timing falloff in-window; `REACH_TIMING_BONUS ≈ 0.5`). Perfect timing *forgives spatial error* (bigger catch zone); sloppy-but-in-window timing shrinks it. So great timing can rescue a slightly mis-placed cursor, and dead-on tracking can rescue slightly-off timing — they interact.
- **`spatial_q`** = smooth ramp `clamp(1 − dist/effective_reach, 0, 1)`, bucketed WEAK→NICE→PERFECT with band widths scaled by the `contact` forgiveness dial. Primary axis.
- **Quality** = `spatial_q × (0.85 + 0.15 × timing_q)` — most of timing's value is the *reach interaction* above; this small direct term makes nailing **both** the clear apex without making timing a flat tax. Verdict word is now **honest** (timing materially moves the outcome).
- **Boundary:** define `dist == effective_reach` as a reach-whiff (not a 0-quality dink) — the binary reach gate and the continuous `spatial_q` agree at the edge.
- Net feel: *easy to make contact, hard to make perfect*; mastery = predict the landing, place the cursor, **and** time it.

### 3.4 Intentional spray + launch (regained), slap/charge
- Tap/hold FSM (`BatterController`) = MSSB slap/charge, **reused**. Tap=CONTACT, hold=POWER.
- **Cursor position is an intentional spray + launch lever** (the batter's restored offensive decision): high cursor → fly, low → ground; inside → pull, outside → oppo; plus the timing lean (early→pull, late→oppo). To *aim*, the batter biases the cursor off the ball's true spot, paying a **small quality cost** — a real risk/reward (scheme placement vs maximize contact), not a pure penalty. This restores grounder-vs-fly and pull-vs-oppo as deliberate choices without a second stick.
- **`placement_dir` is RETIRED as DEAD** (not "derived"): the resolver stops reading it; `BatterAI` stops authoring it (emits ZERO); the field stays in the struct/serialization as an inert vestige. (Resolves the AI/test contradiction the review found.)
- Explicit second-stick spray remains a deferred *additional* lever (§9), no longer a missing primitive.

## 4. The Pitcher (MSSB charge + release-time bend) — greenfield
The current `PitcherController` is keyboard WASD aim + immediate throw, **no charge, no analog, no stick-curve**. This section is a **net-new build**, not a modification — so aim and bend can be sequenced to avoid any input-channel conflict by construction.

### 4.1 Sequence
Aim target → lock → select type → **charge** (hold to build power; tight *perfect-release* window; over-hold decays power; the stick sets **bend** direction/amount in this phase) → release (commits power **and** bend as a snapshot). No continuous mid-flight steering. *(Exact bend gesture is a Phase-B feel-test detail; the commitment is "single value by release.")*

### 4.2 Power (activates inert `PitchCommand.power`)
- Power → **pitch velocity** ⇒ less batter predict/execute time (crossing tick earlier). Feed `power` into `create_pitch`'s speed (signature change; ripples to `test_ball_trajectory`/`test_ball_flight`).
- **Exit-velo ceiling rides the existing speed term** (`contact_resolver.gd:97`, `PITCH_SPEED_FACTOR`) — a faster pitch already yields a higher exit-velo when squared up. **No separate power→exit-velo term** (would double-count).
- **Read-time floor = clamp the power→speed mapping BEFORE trajectory construction** (NOT a post-hoc tick floor — flooring the crossing tick would break the z=0 crossing invariant). Guarantees a minimum predict/execute window so max heaters aren't unhittable.
- **Anti-dominance:** the perfect-release window **tightens as power rises** (max velocity demands max precision; missing it → meatball/ball). With bend now a real read (§4.3), the "charged pitches curve less" tradeoff also has teeth. Together these stop "spam max heaters" from being a dominant line. Verify in balance tuning that fast+bend isn't degenerate.

### 4.3 Release-time bend (activates inert `PitchCommand.bend`)
- **Snapshot at release**, stored in `PitchCommand.bend: Vector2`. Applied analytically in `BallTrajectory.get_position` as its **own block** (not inside the `spin_break` guard), after spin_break:
  ```gdscript
  var t_norm := time / flight_duration if flight_duration > 0.0 else 0.0
  pos += Vector3(bend.x, bend.y, 0.0) * (t_norm * t_norm)   # quadratic; late visual break, no z
  ```
- **No z ⇒ crossing tick byte-identical** with/without bend (`predict_crossing` solves on z). `BallFlight` stays **pure**; both the observable path (director) and the graded path (`AtBatResolver.resolve(pitch, swing)`, signature unchanged) rebuild from the same `PitchCommand` and agree on the same bent crossing. Determinism re-verified sound.
- **Caveat to document:** `get_velocity` is not differentiated for bend, so the exit-velo speed term uses the un-bent speed. Bend is lateral and contributes negligibly to speed magnitude — accept it and note it (or add the derivative later); do not silently leave it unexplained.
- **Honest, non-clairvoyant indicator (the fairness mechanism):**
  - The landing indicator shows the ball's **current-state projected crossing** — i.e. keep `at_bat_director._present`'s existing `observable_landing = get_plate_position(bs.position)` (current ball state), which **genuinely drifts** as the `t²` bend expresses late. Do **NOT** repoint it at `state_at_tick(crossing_tick)` (that would be the rejected clairvoyant dot).
  - The **break cue telegraphs the bend's shape AND magnitude** up front (extend `PitchTypes.break_marker` / the chevron so a bigger committed `bend` shows a bigger cue). So the batter can *read* how much it will break and *predict* the landing — honest, not hidden — then must place + time before commit.
  - Optional clarity layer (Phase C tuning): an early confidence cone that tightens over flight.

### 4.4 PHENOM / star pitches
Hook only (`tier` flag exists). Later: forced max bend, seeded deception, apparent-speed change — all snapshot-expressible at the analytic seam.

## 5. Roles
Both sides are full MSSB-skill controls; AI fills the empty seat solo. **Role config = two independent per-seat fields** (`batter_seat`/`pitcher_seat ∈ {HUMAN, AI}`) replacing the two booleans — isomorphic, so it preserves both-AI (attract) and the headless pure-FSM test mode. HUD visibility derives from `*_seat == HUMAN`. (Touches `at_bat.tscn` + the **single** `_director()` test factory helper — not 9 call sites.)
- **AI batter** sets `cursor_point` from the **same observable** the human sees (the current-state projection, NOT `state_at_tick(crossing_tick)` — else the AI reads truth the human can't and is cheating). It already emits a `cursor`.
- **AI pitcher** authors `power` + a planned `bend` — identical struct to the human path.

## 6. Component changes (file-by-file)
**Reused unchanged:** deterministic tick core, `PitchTypes` (extend the cue), `BallFlight.crossing_tick()` math, **`AtBatResolver`/`AtBatOutcome` signatures**, the tap/hold FSM structure, `StrikeZone`.

**Changed:**
- `src/core/contact_resolver.gd` — **rewrite (TDD).** Two whiff gates (timing + reach) with a `whiff_reason`/`Judgment.REACH`; quality = `spatial_q × (0.85 + 0.15·timing_q)` with timing-widened `effective_reach`; weighted anisotropic distance; consumes `swing.cursor_point`; cursor-position spray+launch; keep exit-velo (single speed path).
- `src/data/swing_command.gd` / `swing_input.gd` — un-deprecate `cursor`/`cursor_point`; mark `placement_dir` DEAD (inert vestige).
- `src/batter/batter_input.gd` — stateful cursor, integrate + clamp (gate metric); `map(left, commit, prev_cursor)`.
- `src/batter/batter_controller.gd` — latch `cursor_point` at commit.
- `src/batter/batter_ai.gd` — set `cursor_point` from the human-visible current-state projection; stop authoring `placement_dir` (ZERO).
- `src/pitcher/pitcher_controller.gd` — **greenfield:** charge build + perfect-release window (tightens with power) + over-hold decay; aim→lock→charge(+stick bend); emit `power`/`bend` at release.
- `src/pitcher/pitcher_ai.gd` — author `power` + planned `bend`.
- `src/ball/ball_trajectory.gd` — analytic `bend` block (no z, own block); `create_pitch` takes clamped `power`→speed; note `get_velocity` ignores bend.
- `src/ball/ball_flight.gd` — stays pure; consumes populated `PitchCommand.bend`/`power`.
- `src/game/at_bat_director.gd` — two-field role config + HUD visibility; charge input; **keep** `observable_landing` as the current-state projection (do not repoint to crossing-tick); feed the magnitude-telegraphing cue; reach-verdict bridge; replace the `LATE_FLIGHT_TICKS = 12` literal with `const LATE_FLIGHT_TICKS := ContactResolver.CONTACT_TICKS` so a timing retune can't desync.
- `scenes/ui/batting_view.gd` — render cursor + reach ring (gate metric) + current-projection indicator; magnitude-scaled break cue; branch `_draw_verdict` on `whiff_reason`.
- `scenes/ui/pitching_view.gd` — drive `release_charge` from real charge; show bend + perfect-window cue.
- `scenes/batter.tscn` / `at_bat.tscn` — restore `CursorMarker` by **re-adding the cursor sphere/material/node on top of the current scene** (the current scene's resource slots hold the bat capsule — do **not** `git checkout` the pre-pivot scene, that would delete `BatPivot/BatMesh`). The recoverable reference is `git show 1117c98^:dngrz/scenes/batter.tscn` (the *scene*, not `_gate1.gd`). Set `load_steps` to whatever the final resource count is (don't trust prior "8→6"/"6→8" notes — both were wrong; the current scene is `load_steps=6`).

## 7. Phasing
- **Phase A — Batter realignment.** Forgiving cursor (anisotropic-correct) + two-gate whiff (with reach verdict) + spatial×timing-trade quality + cursor-position spray/launch + cursor/reach/projection HUD. Feel-test vs the existing AI pitcher.
  - **Kill-criterion (falsifiable):** if a median tester whiffs above a set threshold on cursor-on-ball swings, or reports the cursor "arbitrary/overloading" as before, the MSSB-cursor thesis is wrong → revert to timing-first, don't rationalize. Threshold set at Phase-A start. (Ensure the indicator + anisotropy are correct first, so the test isn't tripped by a wiring bug.)
- **Phase B — Pitcher charge + bend.** Greenfield charge/perfect-window (tightens with power) + power (clamped velocity) + release-time bend + magnitude-telegraphing cue; flip so the human pitches, AI bats.
- **Phase C — Roles + polish.** Two-field roles, panic recenter, over-charge decay, confidence cone, PHENOM hooks, balance tuning (heater/fast+bend, spray trade values).

## 8. Testing — honest blast radius
Not a "maintain 176" maintenance pass — the realignment rewrites locked tests. **~22–26 touched**, concentrated in `test_contact_resolver`:
- `test_contact_resolver` (~14): timing-as-sole-quality + `test_location_never_gates_contact` + placement cases **invert**; `_swing()` helper takes a cursor; add reach-gate, reach-verdict, timing-trade, forgiveness-band cases.
- `test_batter_input`: `map` signature change = **compile break**; 4 calls updated.
- `test_batter_controller`: `cursor_point==ZERO` assertion inverts.
- `test_at_bat_resolver`: cursor wiring + whiff-source cases.
- `test_at_bat_director`: **one** `_director()` factory helper edits for the two-field roles (not 9 call sites).
- `test_ball_trajectory`/`test_ball_flight`: `create_pitch` power arg + bend block.
- **TDD the `ContactResolver` rewrite first** (RED→GREEN). Green proves determinism/math, **not** fairness/fun — that's the Phase-A feel-test + kill-criterion. Full gdUnit4 run per `dngrz-gdunit4-workflow`; `_draw` HUD stays headless-untested (`godot-headless-draw-untested`).

## 9. Out of scope
PHENOM/star behaviors (hook only), netcode/online, baserunning beyond `PlayOutcome`, dynamic field-shift UI (separate Plan 3 slice), camera/visual polish, **explicit second-stick spray** (additional deferred lever), continuous mid-flight steer (rejected), clairvoyant landing dot (rejected).

## 10. Risks & mitigations
- **Re-introducing a cursor reopens the pivot's failure.** Mitigation: MSSB forgiveness (wide reach, smooth ramp, dial-widened bands, anisotropy-correct, two-gate not precise-grade) + the written Phase-A kill-criterion.
- **Indicator too generous → trivial; too stingy → unfair guess.** Mitigation: current-state projection + magnitude-telegraphing cue is the chosen midpoint; the confidence cone + cue magnitude are the tuning knobs. Re-confirm in feel-test that bend is a *read* (batter can be wrong) but not a *blind guess*.
- **Max-power-heater dominance.** Mitigation: power-tightened perfect-release window + meaningful bend tradeoff + velocity clamp; verify fast+bend isn't degenerate; check a "camp dead-center and react" batter doesn't beat an anticipating one.
- **Pitcher input-chain length** (greenfield). Mitigation: sequential not concurrent; a do-nothing newcomer pitch (no charge, no bend) must be a serviceable, readable straight pitch — define that floor in Phase B.
- **Anisotropic-space inconsistency** reads as "the cursor lies" and could trip the kill-criterion on an artifact. Mitigation: one weighted metric for clamp + reach + quality; verify before the feel-test.
- **Highest-skill DECISION per side** (the depth check): batter = *predict the break + scheme placement vs maximize contact*; pitcher = *sequence location/speed/break to beat the batter's prediction under the release-precision tax*. If a feel-test shows either side reduces to pure execution with no decision, revisit before Plan 3's later slices.
