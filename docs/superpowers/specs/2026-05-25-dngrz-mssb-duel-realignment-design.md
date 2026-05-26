# DNGRZ — MSSB-Faithful Duel Realignment (Plan 3a)

**Status:** Approved design — rev 2 (2026-05-26, revised after a 2-agent adversarial review)
**Supersedes:** the *quality model* of `2026-05-25-dngrz-batting-feel-redesign.md` (timing-as-sole-quality) and **reverses** its decision #1 ("location never gates contact"). The deterministic core, structs, and tick architecture from Plans 1–2 are unchanged.
**Builds on:** `2026-05-24-dngrz-core-mechanics-redesign.md` (Plan 3 = the decision layer). This is the **pitcher-skill + batting-realignment** slice.

## 0. Rev-2 changes (from red-team)
A design + a technical agent red-teamed rev 1. Adopted: **bend is a release-time SNAPSHOT, not a continuous mid-flight stream** (preserves the pure `(pitch, swing)` resolver + determinism, and is what makes the duel fair); **the landing indicator is truthful** (perfect information — we lean esports/truth, not party-game deception); **timing keeps a residual effect on quality** (verdict stays honest, gradient preserved); plus the reach-whiff verdict, two-field role config, exit-velo de-duplication, read-time floor, honest spray model, a Phase-A kill-criterion, and a corrected scene-recovery note.

## 1. Why this exists

The merged "timing-first" batting was feel-tested only "fine enough." Deep real-code research into our closest comp — **Mario Superstar Baseball**, via the `roeming/mssb-dtk` decompilation (`src/game/game_batter.c` is fully decompiled) — showed our model and MSSB's proven model are **inverses**:

| | Our merged "timing-first" | MSSB (proven) |
|---|---|---|
| Whiff gate | timing `dt` window | swing-frame window **+ bat reach** |
| Quality axis | timing falloff | **spatial — distance from your cursor** |
| Cursor | removed | free analog cursor you drag to track the ball |

Crucially, **our earlier free-cursor failure was an MLB-The-Show-Zone implementation, not MSSB.** The Show grades on a tiny PCI with punishing precision. MSSB grades on a **wide (~1.0-unit) bat**, a **smooth quality ramp**, and PERFECT/NICE band widths **lerp-widened by a `contactSize` stat + an easy-mode table**. *"Easy to make contact, hard to make perfect."* That tunable forgiveness is the arcade-casual ↔ esports-depth dial. Full research notes: memory `dngrz-mssb-decomp-research`.

**Positioning:** we sit on the **esports/truth** side of MSSB. We keep MSSB's *shape* (cursor tracking, charge, movement, slap/charge) but reject its *party-game deception* (a lying straight-line dot). Information is honest; skill is reading + executing fast under real pressure.

## 2. Pillars (esports invariants)

1. **Perfect information** — the batter can see everything needed *in time*. The landing indicator shows the ball's **true** plate-crossing position throughout flight (no hidden late surprise). The 3D ball may curve late as cosmetic juice, but the graded destination is never hidden.
2. **Symmetric counterplay** — every tool has an answer. The pitcher's bend = honest placement under time pressure (pull the ball off-center / out of zone); the batter's answer = move the cursor there and time it (or lay off). The batter's tracking = answered by the pitcher's speed (less travel time) + the speed-vs-movement tradeoff.
3. **Determinism** — integer ticks, seeded RNG, pure `(PitchCommand, SwingCommand)` resolution, truth distinct from observable, replayable. **No mutable in-flight state on the resolution path.**
4. **Forgiveness is a dial, not a constant** — one `contact`/difficulty parameter serves newcomer (wide bands) and tournament (narrow bands).

## 3. The Batter

### 3.1 Forgiving cursor (re-introduced, MSSB-tuned)
- Re-activate `SwingInput.cursor` + `SwingCommand.cursor_point` (currently retained-but-deprecated ZERO vestiges — struct shapes already correct, so this is wiring + comments, not a rewrite). The cursor lives in **normalized plate space** — the space `StrikeZone.get_plate_position` returns: `(0,0)` = zone center, `±1` = zone edges.
- The **left stick drags the cursor** (integrated per tick at a tunable speed), clamped to a **reach box** slightly larger than the zone. `BatterInput` becomes stateful: it holds `_cursor` and integrates it each tick in `sample()`; the pure mapping becomes `map(left, commit, prev_cursor) -> SwingInput` (signature change — breaks `test_batter_input`, budgeted in §8).
- The cursor is **frozen at swing-commit** (button-down). `BatterController` latches `cursor_point` alongside the existing `placement` latch (this **breaks** `test_batter_controller`'s `cursor_point == ZERO` assertion — budgeted §8). Freezing makes the commit instant unambiguous and removes twitch-after-commit unfairness.
- Optional panic recenter (button) snaps the cursor toward center fast (MSSB's 3× auto-center). *Phase C polish.*

### 3.2 Whiff = TWO gates (timing **and** reach)
A swing is a whiff if **either**:
- **Timing gate:** `dt = commit_tick − crossing_tick`; `|dt| > whiff_window`. Tap (CONTACT) wider, hold (POWER) tighter (`POWER_WINDOW_SCALE`). Our determinism-safe analog of MSSB's slap-2-10 / charge-3-9 frame table.
- **Reach gate:** `dist = |ball_plate − cursor| > REACH_RADIUS` — the bat couldn't get there. This **reverses** the old "location never gates contact" decision; it is intentional (MSSB's `batContactRange`) and `REACH_RADIUS` is generous (widened by the forgiveness dial).

**Verdicts must distinguish the two whiffs.** Timing whiff → EARLY / LATE. Reach whiff → a distinct word (e.g. **"MISSED"/"REACH"**), so the HUD never flashes "PERFECT" on a swing-and-miss. (Judgment is always set, as today.)

### 3.3 Quality = spatial (primary) × timing (residual)
Within both gates, at the fixed crossing tick:
- `ball_plate = StrikeZone.get_plate_position(ball_at_contact.position)` (the **truthful, bent** crossing — see §4.3); `offset = ball_plate − swing.cursor_point`; `dist = offset.length()` (**2D**, lightly horizontal-weighted per MSSB; the weight is a named knob).
- `spatial_q` = smooth ramp from 1.0 at `dist≈0` to 0 at `REACH_RADIUS`, **bucketed** WEAK→NICE→PERFECT with band widths scaled by the `contact` forgiveness dial. **Primary axis** = the new skill.
- `timing_q` = the existing quadratic timing falloff (within the whiff window). **Residual multiplier**, not the primary: `quality = spatial_q × (TIMING_FLOOR + (1 − TIMING_FLOOR) × timing_q)`, `TIMING_FLOOR ≈ 0.6`. So perfect tracking with mediocre (but in-window) timing still produces good — not great — contact; nailing both is the apex. This keeps the EARLY/PERFECT/LATE verdict **honest** (it moves the outcome) and preserves the gradient that already feel-tested okay, while making tracking the headline skill. Two independent skill axes = the esports ceiling.
- Net feel target: *easy to make contact, hard to make perfect.* Both gates forgiving; mastery is putting the cursor where the ball truly ends up **and** timing it.

### 3.4 Spray, slap/charge — honest single-stick model
- The tap/hold FSM (`BatterController`) already maps to MSSB slap/charge — **reused**. Tap = CONTACT (wider gates, less power); hold = POWER (tighter, more power).
- **Spray is fully emergent and `placement_dir` is retired as an authoritative input** (it becomes a derived/vestigial field, honestly — not a half-driven contradiction). With one stick owning cursor-tracking, spray is derived: horizontal = `TIMING_LEAN` (early→pull, late→oppo, per MSSB's frame-indexed launch table) + the cursor's horizontal position (inside contact → pull); vertical/launch = quality-scaled toward the existing `MISHIT_LAUNCH..FLY_LAUNCH`. **Accepted cost:** the hitter trades explicit spray control for tracking. Explicit spray (a second stick / d-pad) is a deliberately deferred depth lever (§9), revisited only if Phase A proves the hitter is strategically shallow.

## 4. The Pitcher (MSSB charge + release-time bend)

### 4.1 Sequence
Aim target → select type → **charge** (hold to build power; a tight *perfect-release* window; over-hold decays power; during charge the stick sets the **bend** direction/amount) → release (commits power **and** bend as a snapshot). No continuous mid-flight steering — the bend is fixed at release. *(Exact bend-setting UX — held-during-charge vs a one-time post-release nudge — is a Phase-B feel-test detail; the design commitment is "single committed value by release," not the input gesture.)*

### 4.2 Power (activates the inert `PitchCommand.power`)
- Power → **pitch velocity**: faster pitch reaches the plate sooner ⇒ **less batter read/cursor-travel time** (the crossing tick moves earlier). Feed `power` into `BallTrajectory.create_pitch`'s speed (signature change; ripples to `test_ball_trajectory`/`test_ball_flight`).
- **Exit-velo ceiling falls out for free — no separate term.** The resolver already scales exit velocity by incoming pitch speed (`PITCH_SPEED_FACTOR`, `contact_resolver.gd:97`). A higher-power pitch is faster, so it already yields a higher exit-velo ceiling when squared up. Adding a second power→exit-velo term would **double-count** — so we don't. (This still delivers the "velocity + exit-velo" intent via one path.)
- **Read-time floor:** clamp max power's velocity contribution (or floor `crossing_tick − start_tick ≥ MIN_READ_TICKS`) so a max heater is never literally unhittable. `seconds_to_ticks` rounds, so the floor is explicit.
- Charged/perfect pitches **curve less** (MSSB speed-vs-movement tradeoff): scale max `bend` down with power. This is the primary counterweight keeping fast+bend from dominating.

### 4.3 Release-time bend (activates the inert `PitchCommand.bend`)
- **Snapshot, committed at release**, stored as `PitchCommand.bend: Vector2` (already present). Applied **analytically** in `BallTrajectory.get_position`, after the existing `spin_break` block:
  ```gdscript
  var t_norm := time / flight_duration if flight_duration > 0.0 else 0.0
  pos += Vector3(bend.x, bend.y, 0.0) * (t_norm * t_norm)   # quadratic; peaks at the plate (cosmetic late curve)
  ```
- **No z component ⇒ the crossing tick is byte-identical with/without bend** (`predict_crossing` solves on z, `ball_trajectory.gd:47`). Bend moves only WHERE the ball crosses, never WHEN.
- **`BallFlight` stays PURE** (no mutable bend, no director mutation). Because bend is in `PitchCommand`, `BallFlight.from_pitch(pitch)` reproduces it; the live observable ball and the `AtBatResolver` rebuild agree on the same bent crossing (no two-source-of-truth). `AtBatResolver.resolve(pitch, swing)` signature is **unchanged**. Replay/netcode stay additive.
- **Truthful indicator (the fairness mechanism):** the batting HUD's landing indicator shows the **true crossing position** computed from the committed trajectory (incl. bend), available throughout flight — a READ, not a guess. The 3D ball still bends late (the `t²` cosmetic), but the indicator never lies. *Tuning knob:* if playtests show this trivializes location-reading, we can add indicator uncertainty/delay as a difficulty dial — but the default is honest.

### 4.4 PHENOM / star pitches
Hook only — the `tier` flag exists. Later: forced max bend, deterministic-seeded behaviors, apparent-speed change — all at the same analytic seam, all snapshot-expressible.

## 5. Roles
Both sides are full MSSB-skill controls. Build **both human paths**; the AI fills the empty seat for solo play. **Role config = two independent per-seat fields** (e.g. `batter_seat ∈ {HUMAN, AI}`, `pitcher_seat ∈ {HUMAN, AI}`) replacing the two booleans — NOT a single human-seat enum, which couldn't express both-AI (attract mode) or the headless pure-FSM test mode. HUD visibility derives from `*_seat == HUMAN`. (Touches `at_bat.tscn` + all 9 `test_at_bat_director` factory calls — budgeted §8.)
- **AI batter** sets `cursor_point` by tracking the truthful predicted crossing (it already emits a `cursor`, `batter_ai.gd:19` — least-disruptive side).
- **AI pitcher** authors `power` + a planned `bend` — identical struct to the human path (the snapshot model makes human and AI converge).

## 6. Component changes (file-by-file)
**Reused unchanged:** deterministic tick core, `PitchTypes`, `BallFlight.crossing_tick()` math, **`AtBatResolver`/`AtBatOutcome` (signature + shape)**, the tap/hold FSM structure, `StrikeZone`.

**Changed:**
- `src/core/contact_resolver.gd` — **rewrite (TDD).** Two whiff gates (timing + reach); quality = `spatial_q × residual_timing`; consumes `swing.cursor_point`; distinct reach-whiff verdict; keep exit-velo (single path), timing-lean spray, launch degradation.
- `src/data/swing_command.gd` / `swing_input.gd` — un-deprecate `cursor_point`/`cursor`; `placement_dir` demoted to derived/vestigial (documented).
- `src/data/ball_state_at_tick.gd` — verify it carries the bent plate position the resolver needs (it carries `position`; bend is already in the trajectory, so no new field expected — confirm in TDD).
- `src/batter/batter_input.gd` — stateful cursor; integrate from left stick, clamp to reach box; `map(left, commit, prev_cursor)`.
- `src/batter/batter_controller.gd` — latch `cursor_point` at commit; keep FSM + bat anim.
- `src/batter/batter_ai.gd` — set `cursor_point` from truthful predicted crossing.
- `src/pitcher/pitcher_controller.gd` — charge build + perfect-release window + over-hold decay; stick sets bend during charge; emit `power`/`bend` at release.
- `src/pitcher/pitcher_ai.gd` — author `power` + planned `bend`.
- `src/ball/ball_trajectory.gd` — analytic `bend` term (no z); `create_pitch` takes `power`→speed with the read-time floor.
- `src/ball/ball_flight.gd` — **stays pure**; only consumes the now-populated `PitchCommand.bend`/`power` via `from_pitch`.
- `src/game/at_bat_director.gd` — two-field role config + HUD-visibility; charge input; truthful-indicator bridge; re-pin `LATE_FLIGHT_TICKS == ContactResolver.CONTACT_TICKS` if the timing gate is retuned.
- `scenes/ui/batting_view.gd` — render cursor + reach ring + truthful landing indicator; keep verdict/contact callout.
- `scenes/ui/pitching_view.gd` — drive `release_charge` from the real charge; show bend direction + perfect-window cue.
- `scenes/batter.tscn` / `at_bat.tscn` — **scene-recovery correction:** restore `CursorMarker` from `git show 1117c98^:dngrz/scenes/batter.tscn` (NOT `_gate1.gd`, which is a script). The current scene reused those resource slots for the bat capsule mesh — do **not** `git checkout` the old scene (it would delete the bat). Re-add the cursor sphere/material *on top*, raising `load_steps` (~6→~8). (Memory `dngrz-core-mechanics-redesign`'s "8→6" note is inaccurate; corrected here.)

## 7. Phasing
- **Phase A — Batter realignment.** Forgiving cursor + two-gate whiff + spatial×residual-timing quality + forgiveness bands + cursor/reach/indicator HUD. Feel-test vs the existing AI pitcher. *Highest feel-risk; first.*
  - **Kill-criterion (falsifiable retry of a failed mechanic):** if a median tester whiffs more than a set threshold on swings where the cursor is on the ball, or reports the cursor feels "arbitrary/overloading" as before, the MSSB-cursor thesis is wrong → revert to timing-first, do not rationalize forward. Set the exact threshold at Phase-A start.
- **Phase B — Pitcher charge + bend.** Charge/perfect-window + power (velocity, read-time floor) + release-time bend + truthful indicator; flip so the human can pitch, AI bats.
- **Phase C — Roles + polish.** Two-field role config, panic recenter, over-charge decay, PHENOM hooks, tuning.

## 8. Testing — honest blast radius
This is **not** a "maintain 176" maintenance pass; the realignment rewrites the locked test corpus. Budget **~30+ tests** rewritten/deleted/added:
- `test_contact_resolver` (≈18): cases asserting timing-as-quality (`test_poor_timing_reduces_quality`) and `test_location_never_gates_contact` **invert**; the `_swing()` helper must pass real cursors; add reach-gate + forgiveness-band + residual-timing cases.
- `test_batter_input`: `map` signature change is a **compile break** — all calls updated.
- `test_batter_controller`: `cursor_point == ZERO` assertion inverts.
- `test_at_bat_resolver`: cursor wiring + whiff-source cases.
- `test_at_bat_director` (9): two-field role config in the factory; verdict/indicator bridge.
- `test_ball_trajectory`/`test_ball_flight`: `create_pitch` power arg + bend term.
- **TDD the `ContactResolver` rewrite first** (RED→GREEN). Note: green tests prove determinism/math, **not** that the mechanic is *fair or fun* — that's the Phase-A feel-test + kill-criterion, not the suite. Don't conflate.
- Full gdUnit4 run per `dngrz-gdunit4-workflow` (import warm-up + `--ignoreHeadlessMode`); `_draw` HUD stays headless-untested (`godot-headless-draw-untested`) — eyeball in feel-tests.

## 9. Out of scope
PHENOM/star behaviors (hook only), netcode/online, baserunning beyond `PlayOutcome`, dynamic field-shift UI (separate Plan 3 slice), camera/visual polish, **explicit second-stick spray aim** (deferred depth lever), continuous mid-flight steer (rejected for determinism + fairness).

## 10. Risks & mitigations
- **Re-introducing a cursor reopens the failure that caused the pivot.** Mitigation: MSSB forgiveness (wide reach gate, smooth ramp, dial-widened bands, quality-from-cursor, two-gate not precise-grade) + a written **Phase-A kill-criterion** so the retry is falsifiable, not rationalized.
- **Truthful indicator could trivialize pitch-reading.** Mitigation: it's a tuning knob — add indicator uncertainty/delay if needed; default honest (esports lean).
- **Pitcher input-chain length** (aim → type → charge → bend). Mitigation: sequential not concurrent; a do-nothing newcomer pitch (no charge, no bend) must still be a serviceable, readable straight pitch — define that floor in Phase B.
- **Fast + bend compounding** (less read time *and* movement). Mitigation: the charged-pitches-curve-less tradeoff + read-time floor; verify in balance tuning that fast+bend isn't a dominant un-counterable strategy.
- **Spatial whiff vs existing strike/ball logic + the `LATE_FLIGHT_TICKS`/`CONTACT_TICKS` coupling.** Mitigation: distinct reach verdict; re-pin the constant coupling explicitly in the director.
