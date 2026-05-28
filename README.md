# DNGRZ

> Legends forged by play.

A deterministic-core 1v1 arcade baseball game in the spirit of Mario Superstar Baseball — a real *duel* between a pitcher and a batter, where every swing reads, every pitch lies a little, and *easy to make contact, hard to make perfect*. Built in **Godot 4.6.3** with a TDD core and feel-test-gated mechanics.

## Quickstart

1. **Install Godot 4.6.3** (Linux x86_64 standard build): <https://godotengine.org/download/archive/4.6.3-stable/>
   The current local-dev binary is `Godot_v4.6.3-stable_linux.x86_64`; CI pins the same version.
2. **Open the project**: `dngrz/project.godot` in the Godot editor.
3. **Run the live duel**: open `scenes/at_bat.tscn` and press F6 (Play Scene). Default scene is **human pitches / AI bats** (the current Phase B feel-test config) — see `dngrz/scenes/at_bat.tscn` to flip seats.

## Run the test suite (headless)

The full gdUnit4 suite, run exactly as CI runs it:

```bash
GODOT46=/path/to/Godot_v4.6.3-stable_linux.x86_64

# Import warm-up (required after any class_name change):
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

The bare `GdUnitCmdTool.gd` form some older plan docs reference does **not** work — the addon-path form above is the verified one.

## Where to find things

- **Specs** (the why + what): `docs/superpowers/specs/` — start with the most recent dated file.
- **Plans** (the how, step-by-step): `docs/superpowers/plans/` — implementation plans, TDD'd task by task.
- **Game source**: `dngrz/src/` (ball / batter / pitcher / core / fielding / data / game).
- **Scenes**: `dngrz/scenes/` (gameplay) and `dngrz/scenes/ui/` (HUD overlays).
- **Tests**: `dngrz/test/` (one `test_<module>.gd` per source module).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The short version: branch off `main`, open a PR, fill out the template (the feel-test checkbox is mandatory for batting/pitching/camera/control/HUD changes), wait for CI green, merge.

## Status

Phase A (batter realignment) merged. Phase B (pitcher charge/bend/power + honest AI batter + mound camera) implemented on `feat/mssb-duel-realignment`, full suite 205/205 green, awaiting headed feel-test gate. Next: Phase C (two-field roles, panic recenter, confidence cone, PHENOM hooks, balance tuning).
