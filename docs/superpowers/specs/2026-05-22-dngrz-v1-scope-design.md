# DNGRZ — v1 Scope Design

**Date:** 2026-05-22
**Parent spec:** `docs/superpowers/specs/2026-04-12-dngrz-game-design.md`
**Parent plan:** `docs/superpowers/plans/2026-04-12-core-baseball-prototype.md`
**Design handoff:** `/home/cner/Downloads/design_handoff_dngrz_ui/` (brand system + 14 screens + Phenom card system)

## Purpose

V1 answers the parent spec's foundational question: *is the pitch/bat duel fun on its own, without zones, Phenoms, factions, momentum, or any tactical layer?*

This spec scopes v1 to the smallest playable thing that can credibly answer that question — the local two-player + AI prototype defined in the parent plan, branded with the design handoff's visual system so v1 screenshots look like the shipping product.

## 1. Success Criteria & Kill-Switch

**V1's purpose:** Test the foundational design rule — pitch/bat with no zones must be fun on its own.

**Pass criteria (must hit BOTH):**

1. **Specific moment feel.** Hitting a well-located fastball *after* setting it up with a changeup feels weighty, crisp, and earned. Whiffing on a hanging breaker feels like *your* read failure, not the game's input lag or hitbox roulette. Test by self-report after 20+ at-bats: can you describe 3 distinct moments where contact felt *deserved*?
2. **Voluntary replay.** Within a week of v1 being playable, you sit down to play >1 session unprompted, including solo against AI. If you only play when you've blocked time to "test," replay value is broken.

**Kill-switch:** Both criteria failing after 1 week of v1 being playable → halt the project. Do not build tactical layer, do not pivot, do not "tune harder." The foundational design rule fired. Re-evaluate at the design level.

**Soft kill-switch (one of two failing):** Tune contact calculator parameters for up to 1 week. If still failing, escalate to halt.

## 2. Scope

### In v1

- Full local two-player pitch/bat per `2026-04-12-core-baseball-prototype.md` Tasks 1–16
- **AI Pitcher controller** (random/scripted pitch selection + location) — new task
- **AI Batter controller** (timing-based crude swing logic) — new task
- 5-inning game with full count, walk, strikeout, fielding, baserunning, scoring, walk-off
- GdUnit4 test coverage on all pure-logic classes (data, strike zone, contact, count, inning, ball trajectory)
- CSG greybox visuals for the **field** — no field art assets
- **Branded UI** per design handoff (Approach A):
  - Godot Theme + custom resources loading design tokens (colors, three Google Fonts, spacing)
  - Phenom card component (stub — displays "P1" / "P2" as initials since no Phenom data in v1)
  - HUD per screen #05 — score, count, outs, inning, phase indicator, diamond mini, pitcher+batter side panels with stub Phenom cards. Tactical clock / crowd momentum / zone list panels are **not wired** (no underlying systems) but are present as visual frames.
  - Pitching action view per screen #06 — branded pitch type selector, strike zone with dashed grid, aim cursor + accuracy ring, windup release meter
  - Batting action view per screen #07 — pitch motion trail, swing cursor over zone, 5-segment swing timing meter (EARLY / EARLY+ / PERFECT / LATE+ / LATE)
  - Post-match per screen #11 — result band, line score, basic Hype-style summary (no real progression underneath)

### Out of v1 (deferred to post-v1 milestones)

- All of parent spec sections 3–12 *as gameplay systems*: Phenoms, factions, synergies, momentum, zones, tactical phases, signature plays, draft/constructed modes, ranked, progression, monetization, onboarding tutorials, reconnection, network architecture
- Phenom-specific fantasy pitches — only realistic pitch types (fastball, curveball, slider, changeup)
- Tactical clock, chess clock, auto-tactical assist (visual frames present in HUD but inert)
- Mind game tendency tracking / scouting
- Audio beyond placeholder beeps
- All art beyond CSG primitives for the field and placeholder portraits for stub Phenom cards
- Zone reveal cinematic (screen #09), signature play cinematic (screen #10)
- Animations beyond essentials for feel feedback (swing timing needle, score scale-bump on run scored)
- Roster manager (#02), draft (#03), pre-match sideboard (#04), tactical overlay (#08), spectator (#12), store (#13), progression (#14)

### Explicitly NOT in v1 even though tempting

- **"Just one zone"** or **"just one Phenom ability"** to see how it feels — defeats the gate. Test the bare core.
- **Quick polish pass on field visuals** — CSG greybox only until gate passes.
- **Stat tracking dashboards** beyond basic in-game HUD.
- **Real Phenom roster wired through** — stubs only.

## 3. Milestone Structure (Approach B — feel-gate first)

Two milestones with a hard gate between them.

### Milestone 1 — Feel-Gate Prototype

| # | Task | TDD? | Output |
|---|------|------|--------|
| 1 | Project setup + GdUnit4 + field_constants | Y | Plugin works, constants tested |
| 2 | Pitch type data | Y | 4 pitch types with speed/break/drop |
| 3 | Strike zone logic | Y | `is_strike`, plate position math |
| 4 | Contact calculator | Y | Quality, exit velocity, launch angle, h_angle |
| 5 | Count tracker | Y | Balls/strikes/outs/fouls/signals |
| 6 | Inning manager | Y | Score, half-inning, walk-off |
| 7 | Ball trajectory | Y | Pitch curves + batted ball arcs |
| 7b | **Godot Theme + design tokens** *(new)* | N | Theme resource with handoff colors, three Google Fonts loaded, GameBtn chamfered style as StyleBoxFlat |
| 7c | **Phenom card component** *(new, stub)* | N | Reusable PackedScene at sm/md/lg sizes, displays initials, faction header (parametric color), portrait well placeholder |
| 8 | Greybox field scene | N | Visual field with bases, mound, fence |
| 9 | Ball scene | N | Ball moves along trajectory |
| 10 | Pitcher controller (human) | N | Aim + select pitch + throw — **uses branded pitching view per screen #06** |
| 10a | **Pitcher AI** *(new)* | Y on decision fn | AI selects pitch + target |
| 11 | Batter controller (human) | N | Cursor + swing timing — **uses branded batting view per screen #07** |
| 11a | **Batter AI** *(new)* | Y on decision fn | AI times swing crudely |
| 11b | **Branded HUD (visual frame)** *(new)* | N | Screen #05 layout — scoreboard, count, phase indicator, diamond mini, stub pitcher/batter panels. Tactical clock / momentum / zone panels are present but inert. |

**🛑 GATE 1: Feel-test.** Solo session: human pitches against AI batter for 20+ ABs, then AI pitches to human for 20+ ABs. Hot-seat with a friend for 1 full at-bat sequence. Evaluate against Section 1 criteria.

- **Pass:** Continue to Milestone 2
- **Soft fail:** Tune contact calculator constants up to 1 week
- **Hard fail:** Halt project

### Milestone 2 — Full Prototype

| # | Task | TDD? | Output |
|---|------|------|--------|
| 12 | Fielding AI + fielding manager | Partial | 9 fielders move to ball, catch, throw |
| 13 | Baserunning + baserunning manager | Partial | Runners, force/tag, scoring resolution |
| 14 | Camera system | N | Pitch/bat/play camera transitions |
| 15 | HUD state wiring | N | Connect live MatchState to HUD widgets built in 11b |
| 16 | Game orchestrator | Partial | Wires phases: pitch → resolve → next batter |
| 16a | **Branded post-match screen** *(new)* | N | Screen #11 — result band, line score, summary card |

**🛑 GATE 2: Replay-test.** Play 3+ full 5-inning games solo vs AI. Hot-seat at least 1 full game with a friend. Re-evaluate Section 1 criteria with the full loop.

- **Pass:** v1 ships. Spec the tactical layer (post-v1 milestone per parent design doc).
- **Fail:** Diagnose — if pitch/bat still feels good but the full loop drags, it's a fielding/pacing issue (tune). If pitch/bat regresses under noise, halt.

## 4. Execution Rhythm

### Per-task loop

1. **Spawn one focused subagent** for the task. Subagent receives:
   - Task spec from the implementation plan file (plan is source of truth, not parent-conversation memory)
   - Reference to parent game design spec + this v1 spec
   - Reference to design handoff README at `/home/cner/Downloads/design_handoff_dngrz_ui/README.md` for any UI task
   - Reference to GdUnit4 patterns in prior completed tasks
   - Explicit "TDD where applicable" instruction
2. **Subagent works the task** — TDD for logic tasks; scene-driven for visual tasks (build → run scene → verify visually).
3. **Subagent reports back** — diff summary, test results, any deviations from spec.
4. **Parent runs verify-before-completion** — does the implementation match the task spec? Tests pass? Any silent failures?
5. **Code review gate** — invoke `ecc:code-review` or `engineering:verify-implementation` on the diff before marking the task complete.
6. **Commit** — per the plan's commit message format. One task = one commit.
7. **TaskUpdate to completed.** Move to next task.

### Strategic compaction

- **Plan file is state truth.** Each completed task gets `- [x]` in the plan markdown. Subagents read from the plan, don't inherit parent's full conversation. Context budget stays small.
- **Per-milestone checkpoint summary.** After Milestone 1 (and before Gate 1), write a one-page "state of the prototype" note: what's built, what tests cover, what's deferred. This becomes the entry point for any future session.
- **No auto-compact reliance.** Don't let conversation grow into auto-summary; checkpoint explicitly between milestones.

### Continuous learning v2

- Project-scoped (NOT global) — instincts learned here stay in dngrz, don't contaminate other projects
- Watch for: Godot 4.5 gotchas, GdUnit4 patterns that work/fail, GDScript idioms specific to this project, design-token wiring patterns, gameplay tuning constants that needed revision
- Review project instincts after each milestone — promote stable ones to skills/commands if they recur

### Review gates

- **Per task:** code-review on diff before mark-complete
- **Per milestone:** full prototype walkthrough (manual playtest) before declaring milestone done
- **Gate 1 (after Milestone 1):** 1-week solo feel-test window, hard kill-switch evaluation per Section 1 criteria
- **Gate 2 (after Milestone 2):** full-game feel-test + replay-test, v1 ship decision

### Out-of-loop safety

- If a task fails verify or review twice, escalate to interactive debugging — don't burn more subagent cycles on the same failing approach.
- If a tuning task drags >1 day (e.g., contact calculator constants), flag for soft kill-switch evaluation early.

## 5. Visual Direction

V1 honors the design handoff as the visual source of truth. All UI tasks must consult `/home/cner/Downloads/design_handoff_dngrz_ui/README.md` for tokens and layouts.

**Implementation notes for Godot:**

- **Theme resource** at `dngrz/themes/dngrz.tres` — load Inter Tight, Archivo Black, JetBrains Mono via Godot's FontFile system (download .ttf or use a local fonts dir). Set color palette using the hex values from the design tokens table. Build a chamfered StyleBoxFlat or use a custom StyleBox subclass for the `GameBtn` clip-path corner effect (approximate with corner detail mesh if pure StyleBox can't do clip-path).
- **Phenom card** at `dngrz/scenes/ui/phenom_card.tscn` — Control-based PackedScene, parametric across `sm` / `md` / `lg` sizes and faction color. In v1 it displays "P1" / "P2" initials with no real Phenom data behind it; the props are there for post-v1.
- **HUD** at `dngrz/scenes/ui/hud.tscn` — full screen #05 layout. Live data: score, count, outs, inning, phase indicator, base occupancy, current pitcher/batter stub cards. Inert visual frames: tactical clock cells (showing "—"), crowd momentum bar (showing centered/neutral), zone list (showing "—" rows). Inert frames are explicit visual placeholders, not hidden — players see where the systems will live.
- **Pitching view** (screen #06) — overlaid on field render, branded pitch selector + strike zone + aim cursor + release meter.
- **Batting view** (screen #07) — overlaid on field render, swing cursor + zone + 5-segment timing meter.
- **Post-match** (screen #11) — overlay scene after game-over signal, with result band, line score table, summary card.

**What is NOT implemented in v1 UI:**

- Roster, draft, pre-match, tactical overlay, spectator, store, progression screens
- Zone reveal cinematic, signature play cinematic
- Animations beyond: swing-timing needle live, score scale-bump on run, phase indicator transition

**Asset placeholders in v1:**

- Phenom portraits: use solid faction-tint color blocks with 2-letter initials in Archivo Black — match the design handoff's `Placeholder` style with diagonal stripes if convenient
- Stadium / hero render slots: ignored in v1 (no main menu yet)
- Team logos / org branding: ignored in v1 (no esports framing yet)

## 6. Open Items (resolved during execution)

- **Font loading approach in Godot:** Whether to vendor .ttf files or use Godot's import-from-Google-Fonts plugin. Decide during Task 7b.
- **Chamfered button corner:** Whether StyleBoxFlat with corner_radius can approximate the clip-path effect, or whether a custom shader / corner-cut TextureRect is needed. Decide during Task 7b; accept "close enough" if pure StyleBox falls short — v1 is feel-test, not visual ship.
- **AI controller architecture:** Whether pitcher/batter AI live as Controllers (drop-in swap with human controller) or as separate "AI brain" nodes that drive a Controller. Decide during Task 10a; favor whichever minimizes refactor when full game state arrives in Milestone 2.
