# Contributing to DNGRZ

Short, operational. These conventions exist because the project's TDD core + feel-test gates are load-bearing; ignoring them will break determinism, your `class_name` registry, or your feel-test verdict.

## Conventions (non-negotiable)

- **GDScript: TAB indentation, never spaces.** Code review rejects spaces. (If your editor auto-converts, fix it before you commit.)
- **`class_name` is project-wide unique.** A duplicate `class_name` *anywhere* in the project aborts the *entire* gdUnit4 run at discovery (exit 105 / "hides a global script class"). Before adding one, `grep -r "^class_name <YourName>" dngrz/`.
- **Plans live in `docs/superpowers/plans/`; specs in `docs/superpowers/specs/`.** New features start with a **spec**, then a **plan**, then code. The plan-then-code split is what lets each task be TDD'd in isolation.
- **All changes flow through a PR.** Direct pushes to `main` are blocked once branch protection is on.
- **CI must be green before merge.** The CI runs the full gdUnit4 suite headless — the same command you should be running locally.

## Feel-test gate (REQUIRED for batting / pitching / camera / control / HUD changes)

Any change that touches how the game *feels* — bat, pitch, camera, controls, HUD timing/visibility — must be **played by a human** and pass the relevant plan's gate criteria *before* the PR merges. The PR template has a checkbox for it; check it only when you've actually played the build and the PASS signals from the plan's "Step 3: Headed feel-test" hold.

If a FAIL signal triggered, stop and open a `feel-test-fail` issue capturing the FAIL signal + suspected knob — don't rationalize forward.

## Running the test suite

```bash
GODOT46=/path/to/Godot_v4.6.3-stable_linux.x86_64

# REQUIRED FIRST (after any class_name change — refreshes Godot's global class cache):
"$GODOT46" --headless --path dngrz --import

# Full suite:
"$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add res://test/

# Single suite (substitute the file):
"$GODOT46" --headless --path dngrz -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add res://test/test_pitcher_controller.gd
```

**Footgun:** the bare `GdUnitCmdTool.gd` form some older plan docs reference does NOT work — there is no root-level copy. The addon-path form (`res://addons/gdUnit4/bin/GdUnitCmdTool.gd`) is the only one that runs.

## Branch / commit / PR workflow

1. Branch off `main`: `git checkout -b feat/<short-name>` (or `chore/`, `fix/`, `docs/` as the kind dictates).
2. Commit small, logical chunks. Conventional Commits style (`feat(pitching): ...`, `fix(batting): ...`) for the subject; full reasoning in the body.
3. When the work is done **and locally tested green**, push and `gh pr create`.
4. Fill out the PR template — every checkbox is intentional. Don't tick the feel-test box without actually feel-testing.
5. CI runs (~10 min). If it fails, push fixes to the same branch — CI re-runs automatically.
6. Self-merge once green (solo workflow; required-reviewer rules aren't enforced).

## Labels (when filing issues)

Four orthogonal axes — apply at least `scope:` and `kind:` to every issue:

- `scope:` what part of the game (`scope:batting`, `scope:pitching`, `scope:fielding`, `scope:ui`, `scope:audio`, `scope:netcode`, `scope:dev-workflow`, `scope:docs`)
- `kind:` what type of work (`kind:bug`, `kind:feature`, `kind:design-spec`, `kind:feel-test-fix`, `kind:polish`, `kind:tech-debt`)
- `phase:` which plan/gate it belongs to (`phase:gate-1`, `phase:plan-1`, …, `phase:plan-3c`, `phase:gate-2`)
- `priority:` urgency (`priority:P0`/`P1`/`P2`/`P3`)
- `status:` lifecycle (`status:needs-design`, `status:needs-plan`, `status:in-progress`, `status:needs-feel-test`, `status:blocked`)

The issue templates pre-apply the right `kind:` and (where appropriate) `priority:` / `status:` for you. Add the `scope:` and `phase:` manually.

## Determinism notes (if your code touches the resolution path)

The deterministic core is a load-bearing pillar (`docs/superpowers/specs/2026-05-25-dngrz-mssb-duel-realignment-design.md` §2.3). On any code path that runs inside `AtBatResolver.resolve(pitch, swing)`:

- **No node access**, **no clock**, **no `delta`**, **no global RNG**.
- Pure function of `(PitchCommand, SwingCommand)` — same inputs → same outputs forever.
- RNG must be injected (a `RandomNumberGenerator` seeded from `PitchCommand.rng_seed`).
- Bend has **no z-component** (otherwise `predict_crossing` would shift the crossing tick and break replay).

If you're not sure whether your change is on the resolution path, ask in the PR.
