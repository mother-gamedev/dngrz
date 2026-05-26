# DNGRZ — Batting Feel Redesign: Timing-First (2026-05-25)

Status: **DRAFT for review** — supersedes the free-cursor batting model from the
Plan 2 playable duel. No code is changed until this is approved.

## 1. Why we're here

Two feel-tests of the Plan 2 batting model failed the same way: *"it does not feel
good or even close to how it should."* Research into shipped baseball games (design +
real source code) found the root cause:

> **We shipped MLB The Show's hardest expert tier — free-cursor ("Zone") placement —
> as our only mode, with *less* forgiveness than the real thing, and with the cursor
> in a different perceptual plane than the 3D ball.**

The player was asked to do **three concurrent tasks** in ~1–1.7 s: (a) predict where
the ball crosses, (b) drag a free cursor there, (c) time the press. Accessible/fun
baseball games ask for **one** (timing) plus an optional coarse bias. Wii Sports = pure
timing; MLB The Show "Directional" and Mario Superstar Baseball = timing + coarse stance/
flick; Super Mega Baseball = forgiving zone + timing. Free-cursor point-overlap is the
opt-in veteran tier everywhere it appears.

Key user insight — *"it didn't feel slower CROSSING home plate, just on the way to it"* —
is correct: slowing total flight time does nothing to the **contact window at the plate**,
which is the thing that decides fairness. Our window was already anchored at the plate
(`crossing_tick`), but it was drowned out by the cursor-hunt and had no legible
early/perfect/late readout, so it read as random.

**Reference code:** [`kuhe/Angular-Baseball`](https://github.com/kuhe/Angular-Baseball)
(deterministic TS sim) resolves contact as a **signed timing offset anchored at a single
plate-crossing instant** + a directional bias — flight-speed-independent by construction.
That is the model we adopt. Our `contact_resolver.gd` is already ~80% of it.

## 2. The pivot (decided)

**Timing-first + 8-way directional bias.** (Closest to Mario Superstar Baseball / Show
"Directional" / Wii Sports.)

- **Timing is the primary skill.** WHEN you swing decides contact and base quality.
- **No free cursor.** Aim collapses to a coarse left-stick *bias* sampled at the commit
  tick — not a point you chase.
- **One commit button, optional depth.** Tap A = contact, hold A = power (unchanged).

This is mostly **removal** of the cursor system plus a resolver pivot and better feedback —
not a rewrite.

## 3. Player experience / input model

| Input | Meaning |
|---|---|
| (watch) | The 3D ball + the overlay's predicted-landing ring tell you *where/when* it crosses. |
| **Left stick** (at commit) | Directional **bias**, sampled at the press tick. Deadzone → neutral (up-the-middle). `x`: − pull / + oppo. `y`: − ground / + fly. |
| **A — tap** | CONTACT swing: wider timing window, less power. |
| **A — hold** | POWER swing: tighter timing window, more power. |

The whole skill loop becomes: **read the pitch → flick a direction (optional) → press A on time.**
No cursor to drive. The timing meter is the primary feedback surface.

## 4. The timing window (the crux)

Expressed in **integer ticks anchored at `crossing_tick`** (the tick the ball crosses the
plate), so the window is identical for a 95 mph fastball and a 78 mph changeup.

```
timing_offset = swing.commit_tick - crossing_tick   # ticks; <0 early, >0 late
```

| Tier | offset | feel |
|---|---|---|
| PERFECT | ≤ 3 ticks (±50 ms) | squared up |
| GOOD | ≤ 7 ticks (±117 ms) | solid contact |
| CONTACT | ≤ 12 ticks (±200 ms) | weak / edge contact |
| WHIFF | > 12 ticks | swing and miss |

- **POWER swing tightens the window** (× ~0.7): higher reward, less margin.
- These four numbers are the primary feel knobs (§8).

## 5. Contact resolution (`contact_resolver.gd` rewrite)

Timing-first: **timing gates contact and drives base quality; the ball's plate location
modulates quality (zone discipline); placement_dir biases direction only.** No player
cursor anywhere.

```gdscript
static func resolve(swing: SwingCommand, ball_at_contact: BallStateAtTick) -> ContactResult:
    var r := ContactResult.new()

    # 1) TIMING is the primary gate. Signed ticks; <0 early, >0 late.
    var dt: int = swing.commit_tick - ball_at_contact.tick
    var window := float(GOOD_TICKS)
    if swing.swing_type == SwingCommand.SwingType.POWER:
        window *= POWER_WINDOW_SCALE        # ~0.7, tighter
    if absi(dt) > CONTACT_TICKS:
        r.is_whiff = true; return r          # mistimed -> whiff, regardless of location
    r.is_whiff = false

    # 2) Quality = timing quality * location factor (zone discipline, NO cursor).
    #    location_factor falls off as the BALL crosses farther from zone center.
    var timing_q := clampf(1.0 - float(absi(dt)) / window, 0.0, 1.0)
    timing_q = timing_q * timing_q           # quadratic falloff (sharper feel)
    var plate := ball_at_contact.plate_point()                 # ball's crossing pos
    var loc_factor := clampf(1.0 - plate.length() / CHASE_FALLOFF, MIN_LOC_FACTOR, 1.0)
    r.quality = timing_q * loc_factor

    # 3) Judgment label for the HUD (legible early/perfect/late).
    r.judgment = (PERFECT if absi(dt) <= PERFECT_TICKS else (EARLY if dt < 0 else LATE))

    # 4) Exit velocity: incoming speed + base, scaled by quality.
    var base_exit := POWER_EXIT_VELOCITY if swing.swing_type == POWER else CONTACT_EXIT_VELOCITY
    r.exit_velocity = (base_exit + ball_at_contact.velocity.length() * PITCH_SPEED_FACTOR) \
        * (0.4 + 0.6 * r.quality)

    # 5) Direction = AUTHORITATIVE 8-way bias, honored to the degree executed, plus a
    #    natural timing lean (early -> pull, late -> oppo). Same shape as today.
    var t_sec := SimClock.ticks_to_seconds(dt)
    r.h_angle = clampf(lerpf(0.0, clampf(swing.placement_dir.x,-1,1)*SPRAY_MAX, r.quality)
        + t_sec * TIMING_LEAN, -45.0, 45.0)
    r.launch_angle = clampf(lerpf(MISHIT_LAUNCH,
        remap(clampf(swing.placement_dir.y,-1,1), -1,1, GROUND_LAUNCH, FLY_LAUNCH), r.quality),
        -10.0, 60.0)
    return r
```

Changes vs current resolver:
- **Removed:** `cursor_point` as the whiff gate (`placement_dist > zone_radius`). The
  player no longer aims a point at the ball.
- **Added:** `location_factor` from the *ball's* plate position (zone discipline without a
  cursor) and an explicit `judgment` (EARLY/PERFECT/LATE) for the HUD.
- **Kept:** quadratic quality falloff, `TIMING_LEAN` spray, placement-as-authoritative-intent,
  tap/hold power model.

**Distance floor (downstream, `batted_ball_resolver.gd`):** keep weak-but-on-time contact
legible — a dribbler, not nothing (Angular-Baseball pattern: `if dist < FLOOR: dist =
dist*0.25 + FLOOR*0.75`).

## 6. Feedback / overlay (`batting_view.gd`)

- **Remove** the free aim cursor (the `aim_position` ring) and the 3D `CursorMarker`.
- **Keep** the predicted-landing ring + break chevron (the *where*), and the 3D ball (the
  *what/when*, already chosen as the single pitch read).
- **Timing meter is the hero:** live needle sweeps EARLY→PERFECT→LATE as the ball nears the
  plate (already wired), **locks on commit**, and **flashes the verdict word** (PERFECT /
  EARLY / LATE) plus a **contact-quality callout** (e.g. PERFECT! / Solid / Weak / Whiff) —
  Super Mega Baseball was specifically dinged for *omitting* this; it is required, not polish.

## 7. SwingCommand & determinism

`SwingCommand { swing_type, placement_dir, commit_tick }` is unchanged in shape.
`cursor_point` is **retained but unused for resolution** (kept for a possible future opt-in
"Zone" mode; deprecate in comment). Resolution stays a **pure function of (pitch, swing)**,
tick-stamped — netcode remains purely additive.

## 8. Tuning knobs (feel-test these)

`PERFECT_TICKS=3`, `GOOD_TICKS=7`, `CONTACT_TICKS=12`, `POWER_WINDOW_SCALE=0.7`,
`CHASE_FALLOFF` (how far out of the zone before contact quality craters), `MIN_LOC_FACTOR`
(floor so a timed swing on a bad pitch still makes weak contact), and `PITCH_TIME_SCALE`
(flight telegraph — affects anticipation only, *not* the contact window).

## 9. Decisions (resolved 2026-05-25)

1. **Zone discipline:** ✅ KEEP the soft `location_factor`. Timing alone gates hit-vs-whiff;
   a pitch crossing far outside the zone yields weaker contact automatically (measured from
   the BALL's plate position — no cursor). Preserves plate-discipline strategy.
2. **Placement capture:** ✅ ANALOG stick direction sampled at the commit tick (deadzone =
   neutral / up-the-middle). No hard 8-way quantize.
3. **Bunt / take:** out of scope this pass ("take" = no swing, already handled).

## 10. Files touched (scope)

| File | Change |
|---|---|
| `src/core/contact_resolver.gd` | rewrite `resolve` → timing-first (§5) |
| `src/data/swing_command.gd` | comment: `cursor_point` deprecated/unused |
| `src/batter/batter_input.gd` | drop cursor integration; placement = stick dir at commit |
| `src/batter/batter_controller.gd` | drop cursor latch + `CursorMarker`; keep bat anim |
| `scenes/batter.tscn` | remove `CursorMarker` |
| `scenes/ui/batting_view.gd` | remove aim cursor; add verdict + contact callout |
| `src/game/at_bat_director.gd` | feed judgment/quality to view; drop cursor bridge |
| `test/test_contact_resolver.gd` (+ others) | retarget tests to timing-first behavior |

## 11. Test plan (TDD targets, headless)

- dt=0, centered pitch → high-quality CONTACT.
- |dt| > CONTACT_TICKS → WHIFF (regardless of placement/location).
- early swing → `h_angle` pulls; late swing → opposite field.
- POWER window tighter than CONTACT (an offset that CONTACT survives, POWER whiffs).
- pitch crossing far outside zone → lower quality than same timing down the middle.
- judgment label maps correctly (EARLY / PERFECT / LATE) at the tier boundaries.
- (rendering/verdict callout = feel-test; `_draw` is not headless-testable.)

## 12. Not in this pass

HUD panel layout repolish (deferred); bat-pose fine-tuning (the bat anim stays but exact
poses are a separate feel-task); pitcher-side input model; defense.
