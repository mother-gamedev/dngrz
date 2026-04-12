# Core Baseball Prototype - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable local two-player pitch/bat duel in Godot 4.5 -- the foundational gameplay that everything else layers onto.

**Architecture:** Manual trajectory calculation for ball physics (not RigidBody3D) to maintain deterministic control over pitch curves and batted ball arcs. CSG primitives for greybox field. Pure GDScript classes for all game logic (testable without scenes). GdUnit4 for testing. State machine pattern for game flow (count -> at-bat -> half-inning -> game).

**Tech Stack:** Godot 4.5, GDScript, GdUnit4, CSG nodes for prototyping, Forward Plus renderer

**Spec reference:** `docs/superpowers/specs/2026-04-12-dngrz-game-design.md` -- Sections 1 (Core Game Loop, match structure only), 2 (Pitch vs. Bat)

**What this plan does NOT include (future plans):** Phenom abilities, zones, tactical phases, momentum, networking, menus, draft/constructed modes, progression. This is pure arcade baseball.

---

## File Structure

```
dngrz/                              # Godot project root (res://)
  src/
    data/
      field_constants.gd            # Baseball dimensions, base positions, scale
      pitch_types.gd                # Pitch type enum, speed/break/drop properties
    core/
      strike_zone.gd                # Is a pitch in the zone? Ball/strike determination
      contact_calculator.gd         # Swing timing + placement -> contact quality -> launch vector
      count_tracker.gd              # Balls, strikes, outs, foul logic
      inning_manager.gd             # Half-innings, side switching, score tracking, game-over
    ball/
      ball_trajectory.gd            # Parametric trajectory math (pitch curves, batted arcs)
      ball.gd                       # Node3D script: moves ball along trajectory each frame
    field/
      field_builder.gd              # Constructs CSG greybox field programmatically
    pitcher/
      pitcher_controller.gd         # Pitcher input: pick type, aim location, execute
    batter/
      batter_controller.gd          # Batter input: position cursor, time swing
    fielding/
      fielder_ai.gd                 # Single fielder: move toward ball, catch/field, throw
      fielding_manager.gd           # Manages all 9 fielders, assigns target, routes throws
    baserunning/
      baserunner.gd                 # Single runner: advance, hold, return
      baserunning_manager.gd        # All runners, force/tag logic, scoring
    camera/
      game_camera.gd                # Camera positions for pitch/bat/play phases, transitions
    ui/
      hud.gd                        # Score, count, outs, inning display
    game/
      game.gd                       # Main orchestrator: wires everything, manages phases
  scenes/
    game.tscn                       # Main scene
    ball.tscn                       # Ball mesh + script
    field.tscn                      # Field root (populated by field_builder)
    pitcher.tscn                    # Pitcher mesh + controller
    batter.tscn                     # Batter mesh + controller
    fielder.tscn                    # Fielder template mesh + ai
  test/
    test_strike_zone.gd
    test_contact_calculator.gd
    test_count_tracker.gd
    test_inning_manager.gd
    test_ball_trajectory.gd
    test_pitch_types.gd
```

---

### Task 1: Project Setup & GdUnit4

**Files:**
- Modify: `dngrz/project.godot`
- Create: `dngrz/addons/gdUnit4/` (via AssetLib)
- Create: `dngrz/src/data/field_constants.gd`
- Create: `dngrz/test/test_field_constants.gd`

- [ ] **Step 1: Create directory structure**

```bash
cd /home/cner/Projects/dngrz/dngrz
mkdir -p src/data src/core src/ball src/field src/pitcher src/batter src/fielding src/baserunning src/camera src/ui src/game
mkdir -p scenes test
```

- [ ] **Step 2: Install GdUnit4**

Open Godot editor, go to AssetLib tab, search "GdUnit4", install it. Then enable the plugin:
- Project > Project Settings > Plugins > GdUnit4 > Enable

If AssetLib is unavailable, clone manually:

```bash
cd /home/cner/Projects/dngrz/dngrz
git clone https://github.com/MikeSchulworx/gdUnit4.git addons/gdUnit4 --depth 1
```

Then enable in Project Settings > Plugins.

- [ ] **Step 3: Verify GdUnit4 works with a smoke test**

Create `test/test_smoke.gd`:

```gdscript
class_name TestSmoke extends GdUnitTestSuite

func test_godot_is_running() -> void:
    assert_bool(true).is_true()
```

Run from CLI:

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/
```

Expected: 1 test passed, exit code 0.

- [ ] **Step 4: Create field constants**

Create `src/data/field_constants.gd`:

```gdscript
class_name FieldConstants

# Scale: 1 unit = 1 meter
# Field oriented so home plate is at origin, second base is in -Z direction

# Base positions (real baseball dimensions)
const BASELINE_LENGTH := 27.43  # 90 feet
const MOUND_DISTANCE := 18.44  # 60.5 feet from home to rubber
const MOUND_HEIGHT := 0.254    # 10 inches elevation

const HOME_PLATE := Vector3(0.0, 0.0, 0.0)
const FIRST_BASE := Vector3(19.4, 0.0, -19.4)    # 45-degree angle from home
const SECOND_BASE := Vector3(0.0, 0.0, -38.8)     # straight up the middle
const THIRD_BASE := Vector3(-19.4, 0.0, -19.4)    # mirror of first
const MOUND := Vector3(0.0, MOUND_HEIGHT, -MOUND_DISTANCE)

# Outfield fence distances (center/left/right)
const FENCE_CENTER := 121.92   # 400 feet
const FENCE_CORNERS := 100.58  # 330 feet

# Strike zone (meters, approximate for "arcade" feel)
const STRIKE_ZONE_WIDTH := 0.43    # 17 inches (home plate width)
const STRIKE_ZONE_BOTTOM := 0.5    # knee height
const STRIKE_ZONE_TOP := 1.1       # mid-chest
const STRIKE_ZONE_CENTER := Vector3(0.0, 0.8, 0.0)  # center of zone at plate

# Fielder default positions
const FIELDER_POSITIONS := {
    "pitcher": Vector3(0.0, MOUND_HEIGHT, -MOUND_DISTANCE),
    "catcher": Vector3(0.0, 0.0, 1.5),
    "first_base": Vector3(15.0, 0.0, -18.0),
    "second_base": Vector3(5.0, 0.0, -28.0),
    "shortstop": Vector3(-5.0, 0.0, -28.0),
    "third_base": Vector3(-15.0, 0.0, -18.0),
    "left_field": Vector3(-50.0, 0.0, -70.0),
    "center_field": Vector3(0.0, 0.0, -90.0),
    "right_field": Vector3(50.0, 0.0, -70.0),
}
```

- [ ] **Step 5: Write test for field constants**

Create `test/test_field_constants.gd`:

```gdscript
class_name TestFieldConstants extends GdUnitTestSuite

func test_bases_form_diamond() -> void:
    # Distance from home to first should equal baseline length
    var dist := FieldConstants.HOME_PLATE.distance_to(FieldConstants.FIRST_BASE)
    assert_float(dist).is_equal_approx(FieldConstants.BASELINE_LENGTH, 0.5)

func test_bases_are_equidistant() -> void:
    var h_to_1 := FieldConstants.HOME_PLATE.distance_to(FieldConstants.FIRST_BASE)
    var one_to_2 := FieldConstants.FIRST_BASE.distance_to(FieldConstants.SECOND_BASE)
    var two_to_3 := FieldConstants.SECOND_BASE.distance_to(FieldConstants.THIRD_BASE)
    var three_to_h := FieldConstants.THIRD_BASE.distance_to(FieldConstants.HOME_PLATE)
    assert_float(h_to_1).is_equal_approx(one_to_2, 0.5)
    assert_float(one_to_2).is_equal_approx(two_to_3, 0.5)
    assert_float(two_to_3).is_equal_approx(three_to_h, 0.5)

func test_mound_is_elevated() -> void:
    assert_float(FieldConstants.MOUND.y).is_greater(0.0)

func test_strike_zone_has_positive_dimensions() -> void:
    assert_float(FieldConstants.STRIKE_ZONE_WIDTH).is_greater(0.0)
    assert_float(FieldConstants.STRIKE_ZONE_TOP).is_greater(FieldConstants.STRIKE_ZONE_BOTTOM)

func test_all_fielder_positions_exist() -> void:
    assert_int(FieldConstants.FIELDER_POSITIONS.size()).is_equal(9)
```

- [ ] **Step 6: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add dngrz/src/data/field_constants.gd dngrz/test/ dngrz/addons/ dngrz/project.godot
git commit -m "feat: project setup with GdUnit4 and field constants"
```

---

### Task 2: Pitch Type Data

**Files:**
- Create: `dngrz/src/data/pitch_types.gd`
- Create: `dngrz/test/test_pitch_types.gd`

- [ ] **Step 1: Write failing test**

Create `test/test_pitch_types.gd`:

```gdscript
class_name TestPitchTypes extends GdUnitTestSuite

func test_fastball_is_fastest() -> void:
    var fastball := PitchTypes.get_pitch(PitchTypes.Type.FASTBALL)
    var changeup := PitchTypes.get_pitch(PitchTypes.Type.CHANGEUP)
    assert_float(fastball.speed).is_greater(changeup.speed)

func test_curveball_has_drop() -> void:
    var curve := PitchTypes.get_pitch(PitchTypes.Type.CURVEBALL)
    assert_float(curve.drop).is_greater(0.0)

func test_slider_has_horizontal_break() -> void:
    var slider := PitchTypes.get_pitch(PitchTypes.Type.SLIDER)
    assert_float(absf(slider.h_break)).is_greater(0.0)

func test_all_pitches_have_positive_speed() -> void:
    for pitch_type in PitchTypes.Type.values():
        var pitch := PitchTypes.get_pitch(pitch_type)
        assert_float(pitch.speed).is_greater(0.0)

func test_changeup_is_slower_than_fastball() -> void:
    var fb := PitchTypes.get_pitch(PitchTypes.Type.FASTBALL)
    var ch := PitchTypes.get_pitch(PitchTypes.Type.CHANGEUP)
    assert_float(fb.speed - ch.speed).is_greater(5.0)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_pitch_types.gd
```

Expected: FAIL -- `PitchTypes` not defined.

- [ ] **Step 3: Implement pitch types**

Create `src/data/pitch_types.gd`:

```gdscript
class_name PitchTypes

enum Type {
    FASTBALL,
    CURVEBALL,
    SLIDER,
    CHANGEUP,
}

class PitchData:
    var speed: float       # meters per second
    var h_break: float     # horizontal break in meters (+ = arm side, - = glove side)
    var drop: float        # additional downward break in meters
    var accuracy: float    # base accuracy multiplier (0-1, higher = more forgiving)

    func _init(p_speed: float, p_h_break: float, p_drop: float, p_accuracy: float) -> void:
        speed = p_speed
        h_break = p_h_break
        drop = p_drop
        accuracy = p_accuracy

# Speeds in m/s (1 mph ~ 0.447 m/s)
# Fastball ~95mph=42.5m/s, Curve ~80mph=35.8m/s, Slider ~87mph=38.9m/s, Change ~85mph=38.0m/s
static var _pitches := {
    Type.FASTBALL:  PitchData.new(42.5, 0.05, 0.1, 0.85),
    Type.CURVEBALL: PitchData.new(35.8, 0.1, 0.6, 0.70),
    Type.SLIDER:    PitchData.new(38.9, -0.4, 0.2, 0.75),
    Type.CHANGEUP:  PitchData.new(38.0, 0.15, 0.15, 0.80),
}

static func get_pitch(pitch_type: Type) -> PitchData:
    return _pitches[pitch_type]

static func get_name(pitch_type: Type) -> String:
    match pitch_type:
        Type.FASTBALL: return "Fastball"
        Type.CURVEBALL: return "Curveball"
        Type.SLIDER: return "Slider"
        Type.CHANGEUP: return "Changeup"
    return "Unknown"
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_pitch_types.gd
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/data/pitch_types.gd dngrz/test/test_pitch_types.gd
git commit -m "feat: pitch type data with speed, break, and drop properties"
```

---

### Task 3: Strike Zone Logic

**Files:**
- Create: `dngrz/src/core/strike_zone.gd`
- Create: `dngrz/test/test_strike_zone.gd`

- [ ] **Step 1: Write failing tests**

Create `test/test_strike_zone.gd`:

```gdscript
class_name TestStrikeZone extends GdUnitTestSuite

func test_center_pitch_is_strike() -> void:
    var center := Vector3(0.0, 0.8, 0.0)
    assert_bool(StrikeZone.is_strike(center)).is_true()

func test_pitch_above_zone_is_ball() -> void:
    var high := Vector3(0.0, 1.5, 0.0)
    assert_bool(StrikeZone.is_strike(high)).is_false()

func test_pitch_below_zone_is_ball() -> void:
    var low := Vector3(0.0, 0.2, 0.0)
    assert_bool(StrikeZone.is_strike(low)).is_false()

func test_pitch_outside_is_ball() -> void:
    var outside := Vector3(0.5, 0.8, 0.0)
    assert_bool(StrikeZone.is_strike(outside)).is_false()

func test_pitch_inside_is_ball() -> void:
    var inside := Vector3(-0.5, 0.8, 0.0)
    assert_bool(StrikeZone.is_strike(inside)).is_false()

func test_corner_pitch_is_strike() -> void:
    var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
    var corner := Vector3(half_w - 0.01, FieldConstants.STRIKE_ZONE_TOP - 0.01, 0.0)
    assert_bool(StrikeZone.is_strike(corner)).is_true()

func test_just_outside_corner_is_ball() -> void:
    var half_w := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
    var just_out := Vector3(half_w + 0.02, FieldConstants.STRIKE_ZONE_TOP + 0.02, 0.0)
    assert_bool(StrikeZone.is_strike(just_out)).is_false()

func test_plate_position_returns_normalized() -> void:
    # Center of zone should return (0, 0)
    var center := Vector3(0.0, 0.8, 0.0)
    var normalized := StrikeZone.get_plate_position(center)
    assert_float(normalized.x).is_equal_approx(0.0, 0.1)
    assert_float(normalized.y).is_equal_approx(0.0, 0.1)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_strike_zone.gd
```

Expected: FAIL -- `StrikeZone` not defined.

- [ ] **Step 3: Implement strike zone**

Create `src/core/strike_zone.gd`:

```gdscript
class_name StrikeZone

# Check if a pitch crossing the plate at `position` is a strike.
# position.x = horizontal (0 = center of plate)
# position.y = vertical height
# position.z is ignored (we evaluate at the plate plane)
static func is_strike(position: Vector3) -> bool:
    var half_width := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
    var in_horizontal := absf(position.x) <= half_width
    var in_vertical := position.y >= FieldConstants.STRIKE_ZONE_BOTTOM and position.y <= FieldConstants.STRIKE_ZONE_TOP
    return in_horizontal and in_vertical

# Returns the pitch position normalized to the strike zone.
# (0, 0) = center of zone, (-1, -1) = low-inside corner, (1, 1) = high-outside corner
static func get_plate_position(position: Vector3) -> Vector2:
    var half_width := FieldConstants.STRIKE_ZONE_WIDTH / 2.0
    var zone_height := FieldConstants.STRIKE_ZONE_TOP - FieldConstants.STRIKE_ZONE_BOTTOM
    var zone_center_y := (FieldConstants.STRIKE_ZONE_TOP + FieldConstants.STRIKE_ZONE_BOTTOM) / 2.0

    var norm_x := position.x / half_width if half_width > 0.0 else 0.0
    var norm_y := (position.y - zone_center_y) / (zone_height / 2.0) if zone_height > 0.0 else 0.0
    return Vector2(norm_x, norm_y)
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_strike_zone.gd
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/core/strike_zone.gd dngrz/test/test_strike_zone.gd
git commit -m "feat: strike zone detection with normalized plate position"
```

---

### Task 4: Contact Calculator

**Files:**
- Create: `dngrz/src/core/contact_calculator.gd`
- Create: `dngrz/test/test_contact_calculator.gd`

This is the core "feel" system -- swing timing and cursor placement produce contact quality, which determines launch angle and exit velocity.

- [ ] **Step 1: Write failing tests**

Create `test/test_contact_calculator.gd`:

```gdscript
class_name TestContactCalculator extends GdUnitTestSuite

# Timing: 0.0 = perfect, negative = early, positive = late
# Placement: Vector2 offset from pitch location (0,0 = dead center on ball)

func test_perfect_contact_gives_max_quality() -> void:
    var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    assert_float(result.quality).is_equal_approx(1.0, 0.05)

func test_late_timing_reduces_quality() -> void:
    var perfect := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    var late := ContactCalculator.calculate(0.08, Vector2.ZERO, 42.0)
    assert_float(late.quality).is_less(perfect.quality)

func test_early_timing_reduces_quality() -> void:
    var perfect := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    var early := ContactCalculator.calculate(-0.08, Vector2.ZERO, 42.0)
    assert_float(early.quality).is_less(perfect.quality)

func test_missed_placement_reduces_quality() -> void:
    var centered := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    var off_center := ContactCalculator.calculate(0.0, Vector2(0.1, 0.0), 42.0)
    assert_float(off_center.quality).is_less(centered.quality)

func test_whiff_on_terrible_timing() -> void:
    var result := ContactCalculator.calculate(0.3, Vector2(0.2, 0.2), 42.0)
    assert_bool(result.is_whiff).is_true()

func test_good_contact_has_exit_velocity() -> void:
    var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    assert_float(result.exit_velocity).is_greater(30.0)

func test_exit_velocity_scales_with_pitch_speed() -> void:
    var slow := ContactCalculator.calculate(0.0, Vector2.ZERO, 35.0)
    var fast := ContactCalculator.calculate(0.0, Vector2.ZERO, 45.0)
    assert_float(fast.exit_velocity).is_greater(slow.exit_velocity)

func test_early_timing_pulls_ball() -> void:
    # Early swing pulls the ball (negative h_angle = left for righty)
    var early := ContactCalculator.calculate(-0.04, Vector2.ZERO, 42.0)
    assert_float(early.h_angle).is_less(0.0)

func test_late_timing_pushes_ball_opposite() -> void:
    var late := ContactCalculator.calculate(0.04, Vector2.ZERO, 42.0)
    assert_float(late.h_angle).is_greater(0.0)

func test_perfect_timing_center_launch_angle() -> void:
    var result := ContactCalculator.calculate(0.0, Vector2.ZERO, 42.0)
    # Good contact should produce a reasonable launch angle (10-30 degrees)
    assert_float(result.launch_angle).is_between(5.0, 40.0)

func test_under_ball_produces_fly() -> void:
    # Swing cursor below ball center = fly ball (high launch angle)
    var result := ContactCalculator.calculate(0.0, Vector2(0.0, -0.05), 42.0)
    assert_float(result.launch_angle).is_greater(25.0)

func test_over_ball_produces_grounder() -> void:
    # Swing cursor above ball center = grounder (low launch angle)
    var result := ContactCalculator.calculate(0.0, Vector2(0.0, 0.05), 42.0)
    assert_float(result.launch_angle).is_less(15.0)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_contact_calculator.gd
```

Expected: FAIL -- `ContactCalculator` not defined.

- [ ] **Step 3: Implement contact calculator**

Create `src/core/contact_calculator.gd`:

```gdscript
class_name ContactCalculator

# Tuning constants
const TIMING_WINDOW := 0.1         # seconds -- perfect window is +/- this
const WHIFF_THRESHOLD := 0.15      # combined timing + placement error that causes a miss
const PLACEMENT_WINDOW := 0.12     # meters -- perfect placement window
const BASE_EXIT_VELOCITY := 35.0   # m/s base exit velo on perfect contact
const PITCH_SPEED_FACTOR := 0.3    # how much pitch speed adds to exit velo
const BASE_LAUNCH_ANGLE := 18.0    # degrees -- perfect contact launch angle
const TIMING_PULL_FACTOR := 150.0  # degrees per second of timing offset -> horizontal angle
const PLACEMENT_ANGLE_FACTOR := 200.0  # launch angle degrees per meter of vertical offset

class ContactResult:
    var is_whiff: bool
    var quality: float          # 0.0 to 1.0
    var exit_velocity: float    # m/s
    var launch_angle: float     # degrees from horizontal
    var h_angle: float          # horizontal angle in degrees (0 = center, - = pull, + = oppo)

    func _init() -> void:
        is_whiff = true
        quality = 0.0
        exit_velocity = 0.0
        launch_angle = 0.0
        h_angle = 0.0

# timing_offset: seconds from perfect (0 = perfect, - = early, + = late)
# placement_offset: Vector2 from ball center in meters (0,0 = dead on)
# pitch_speed: m/s of the incoming pitch
static func calculate(timing_offset: float, placement_offset: Vector2, pitch_speed: float) -> ContactResult:
    var result := ContactResult.new()

    # Calculate error magnitudes
    var timing_error := absf(timing_offset) / TIMING_WINDOW
    var placement_error := placement_offset.length() / PLACEMENT_WINDOW
    var total_error := timing_error + placement_error

    # Whiff check
    if total_error > WHIFF_THRESHOLD / 0.05:  # normalized threshold
        result.is_whiff = true
        return result

    # Quality: 1.0 at perfect, drops with error
    result.is_whiff = false
    result.quality = clampf(1.0 - (timing_error * 0.5 + placement_error * 0.5), 0.0, 1.0)
    result.quality = result.quality * result.quality  # quadratic falloff for sharper feel

    # Exit velocity: base + pitch speed contribution, scaled by quality
    result.exit_velocity = (BASE_EXIT_VELOCITY + pitch_speed * PITCH_SPEED_FACTOR) * (0.4 + 0.6 * result.quality)

    # Launch angle: base angle modified by vertical placement offset
    # Hitting under the ball (negative y offset) = higher launch, over the ball = lower
    result.launch_angle = BASE_LAUNCH_ANGLE - placement_offset.y * PLACEMENT_ANGLE_FACTOR
    result.launch_angle = clampf(result.launch_angle, -10.0, 60.0)

    # Horizontal angle: early = pull, late = oppo
    result.h_angle = timing_offset * TIMING_PULL_FACTOR
    # Add horizontal placement influence
    result.h_angle += placement_offset.x * 50.0
    result.h_angle = clampf(result.h_angle, -45.0, 45.0)

    return result
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_contact_calculator.gd
```

Expected: All tests pass. Tune constants if needed to satisfy the test assertions.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/core/contact_calculator.gd dngrz/test/test_contact_calculator.gd
git commit -m "feat: contact calculator with timing, placement, and launch physics"
```

---

### Task 5: Count Tracker

**Files:**
- Create: `dngrz/src/core/count_tracker.gd`
- Create: `dngrz/test/test_count_tracker.gd`

- [ ] **Step 1: Write failing tests**

Create `test/test_count_tracker.gd`:

```gdscript
class_name TestCountTracker extends GdUnitTestSuite

var _tracker: CountTracker

func before_test() -> void:
    _tracker = CountTracker.new()

func test_starts_at_zero() -> void:
    assert_int(_tracker.balls).is_equal(0)
    assert_int(_tracker.strikes).is_equal(0)
    assert_int(_tracker.outs).is_equal(0)

func test_ball_increments() -> void:
    _tracker.add_ball()
    assert_int(_tracker.balls).is_equal(1)

func test_four_balls_is_walk() -> void:
    for i in 4:
        _tracker.add_ball()
    assert_bool(_tracker.is_walk()).is_true()

func test_strike_increments() -> void:
    _tracker.add_strike()
    assert_int(_tracker.strikes).is_equal(1)

func test_three_strikes_is_strikeout() -> void:
    for i in 3:
        _tracker.add_strike()
    assert_bool(_tracker.is_strikeout()).is_true()

func test_strikeout_adds_out() -> void:
    for i in 3:
        _tracker.add_strike()
    assert_int(_tracker.outs).is_equal(1)

func test_foul_with_two_strikes_stays_at_two() -> void:
    _tracker.add_strike()
    _tracker.add_strike()
    _tracker.add_foul()
    assert_int(_tracker.strikes).is_equal(2)

func test_foul_with_less_than_two_strikes_adds_strike() -> void:
    _tracker.add_foul()
    assert_int(_tracker.strikes).is_equal(1)

func test_new_batter_resets_count() -> void:
    _tracker.add_ball()
    _tracker.add_strike()
    _tracker.new_batter()
    assert_int(_tracker.balls).is_equal(0)
    assert_int(_tracker.strikes).is_equal(0)

func test_new_batter_preserves_outs() -> void:
    _tracker.add_out()
    _tracker.new_batter()
    assert_int(_tracker.outs).is_equal(1)

func test_three_outs_is_side_retired() -> void:
    for i in 3:
        _tracker.add_out()
    assert_bool(_tracker.is_side_retired()).is_true()

func test_new_half_inning_resets_outs() -> void:
    _tracker.add_out()
    _tracker.add_out()
    _tracker.new_half_inning()
    assert_int(_tracker.outs).is_equal(0)
    assert_int(_tracker.balls).is_equal(0)
    assert_int(_tracker.strikes).is_equal(0)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_count_tracker.gd
```

Expected: FAIL -- `CountTracker` not defined.

- [ ] **Step 3: Implement count tracker**

Create `src/core/count_tracker.gd`:

```gdscript
class_name CountTracker

signal walk
signal strikeout
signal out_recorded
signal side_retired

var balls: int = 0
var strikes: int = 0
var outs: int = 0

func add_ball() -> void:
    balls += 1
    if balls >= 4:
        walk.emit()

func add_strike() -> void:
    strikes += 1
    if strikes >= 3:
        add_out()
        strikeout.emit()

func add_foul() -> void:
    if strikes < 2:
        strikes += 1

func add_out() -> void:
    outs += 1
    out_recorded.emit()
    if outs >= 3:
        side_retired.emit()

func is_walk() -> bool:
    return balls >= 4

func is_strikeout() -> bool:
    return strikes >= 3

func is_side_retired() -> bool:
    return outs >= 3

func new_batter() -> void:
    balls = 0
    strikes = 0

func new_half_inning() -> void:
    balls = 0
    strikes = 0
    outs = 0
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_count_tracker.gd
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/core/count_tracker.gd dngrz/test/test_count_tracker.gd
git commit -m "feat: count tracker with balls, strikes, outs, fouls, and signals"
```

---

### Task 6: Inning Manager

**Files:**
- Create: `dngrz/src/core/inning_manager.gd`
- Create: `dngrz/test/test_inning_manager.gd`

- [ ] **Step 1: Write failing tests**

Create `test/test_inning_manager.gd`:

```gdscript
class_name TestInningManager extends GdUnitTestSuite

var _manager: InningManager

func before_test() -> void:
    _manager = InningManager.new()

func test_starts_at_top_of_first() -> void:
    assert_int(_manager.inning).is_equal(1)
    assert_bool(_manager.is_top).is_true()

func test_score_starts_at_zero() -> void:
    assert_int(_manager.home_score).is_equal(0)
    assert_int(_manager.away_score).is_equal(0)

func test_advance_half_goes_to_bottom() -> void:
    _manager.advance_half_inning()
    assert_int(_manager.inning).is_equal(1)
    assert_bool(_manager.is_top).is_false()

func test_advance_two_halves_goes_to_next_inning() -> void:
    _manager.advance_half_inning()
    _manager.advance_half_inning()
    assert_int(_manager.inning).is_equal(2)
    assert_bool(_manager.is_top).is_true()

func test_add_run_away_in_top() -> void:
    _manager.add_run()
    assert_int(_manager.away_score).is_equal(1)
    assert_int(_manager.home_score).is_equal(0)

func test_add_run_home_in_bottom() -> void:
    _manager.advance_half_inning()  # bottom of 1st
    _manager.add_run()
    assert_int(_manager.home_score).is_equal(1)
    assert_int(_manager.away_score).is_equal(0)

func test_game_not_over_before_five_innings() -> void:
    # Play through 4 full innings
    for i in 8:
        _manager.advance_half_inning()
    assert_bool(_manager.is_game_over()).is_false()

func test_game_over_after_five_full_innings() -> void:
    # Play through 5 full innings (10 half-innings)
    for i in 10:
        _manager.advance_half_inning()
    assert_bool(_manager.is_game_over()).is_true()

func test_batting_team_away_in_top() -> void:
    assert_str(_manager.batting_team()).is_equal("away")

func test_batting_team_home_in_bottom() -> void:
    _manager.advance_half_inning()
    assert_str(_manager.batting_team()).is_equal("home")

func test_game_over_walk_off_bottom_of_fifth() -> void:
    # Go to bottom of 5th with home trailing
    for i in 9:  # top1 bot1 top2 bot2 top3 bot3 top4 bot4 top5
        _manager.advance_half_inning()
    # Now in bottom of 5th. Add a run for home to tie then walk off
    _manager.away_score = 1
    _manager.add_run()  # home ties at 1
    _manager.add_run()  # home leads 2-1
    assert_bool(_manager.is_game_over()).is_true()
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_inning_manager.gd
```

Expected: FAIL -- `InningManager` not defined.

- [ ] **Step 3: Implement inning manager**

Create `src/core/inning_manager.gd`:

```gdscript
class_name InningManager

signal half_inning_changed
signal run_scored(team: String)
signal game_over_signal

const TOTAL_INNINGS := 5

var inning: int = 1
var is_top: bool = true
var home_score: int = 0
var away_score: int = 0

func batting_team() -> String:
    return "away" if is_top else "home"

func fielding_team() -> String:
    return "home" if is_top else "away"

func add_run() -> void:
    if is_top:
        away_score += 1
        run_scored.emit("away")
    else:
        home_score += 1
        run_scored.emit("home")

func advance_half_inning() -> void:
    if is_top:
        is_top = false
    else:
        is_top = true
        inning += 1
    half_inning_changed.emit()

func is_game_over() -> bool:
    # Game ends after 5 full innings
    if inning > TOTAL_INNINGS:
        return true
    # Walk-off: bottom of last inning, home takes the lead
    if inning == TOTAL_INNINGS and not is_top and home_score > away_score:
        return true
    return false

func get_inning_display() -> String:
    var half := "Top" if is_top else "Bot"
    return "%s %d" % [half, inning]
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_inning_manager.gd
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/core/inning_manager.gd dngrz/test/test_inning_manager.gd
git commit -m "feat: inning manager with scoring, half-inning tracking, and walk-off detection"
```

---

### Task 7: Ball Trajectory Math

**Files:**
- Create: `dngrz/src/ball/ball_trajectory.gd`
- Create: `dngrz/test/test_ball_trajectory.gd`

- [ ] **Step 1: Write failing tests**

Create `test/test_ball_trajectory.gd`:

```gdscript
class_name TestBallTrajectory extends GdUnitTestSuite

func test_pitch_starts_at_mound() -> void:
    var traj := BallTrajectory.create_pitch(
        PitchTypes.Type.FASTBALL,
        Vector3(0.0, 0.8, 0.0),  # target: center of zone at plate
        1.0                        # accuracy
    )
    var start := traj.get_position(0.0)
    assert_float(start.distance_to(FieldConstants.MOUND)).is_less(1.0)

func test_pitch_reaches_plate() -> void:
    var traj := BallTrajectory.create_pitch(
        PitchTypes.Type.FASTBALL,
        Vector3(0.0, 0.8, 0.0),
        1.0
    )
    # Fastball at ~42 m/s over ~18m should take ~0.43s
    var at_plate := traj.get_position(traj.flight_duration)
    assert_float(at_plate.z).is_equal_approx(0.0, 1.0)

func test_fastball_arrives_faster_than_changeup() -> void:
    var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0)
    var ch := BallTrajectory.create_pitch(PitchTypes.Type.CHANGEUP, Vector3(0.0, 0.8, 0.0), 1.0)
    assert_float(fb.flight_duration).is_less(ch.flight_duration)

func test_curveball_drops_more() -> void:
    var fb := BallTrajectory.create_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0)
    var cv := BallTrajectory.create_pitch(PitchTypes.Type.CURVEBALL, Vector3(0.0, 0.8, 0.0), 1.0)
    # At midpoint, curveball should be higher (hasn't dropped yet) or at endpoint lower
    var fb_end := fb.get_position(fb.flight_duration)
    var cv_end := cv.get_position(cv.flight_duration)
    # Curveball should arrive lower due to drop
    assert_float(cv_end.y).is_less(fb_end.y + 0.1)

func test_batted_ball_trajectory_goes_forward() -> void:
    var traj := BallTrajectory.create_batted(
        FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
        40.0,     # exit velocity m/s
        25.0,     # launch angle degrees
        0.0       # horizontal angle (center field)
    )
    var mid := traj.get_position(1.0)
    # Ball should move toward outfield (negative Z in our coordinate system)
    assert_float(mid.z).is_less(0.0)

func test_batted_ball_goes_up_then_down() -> void:
    var traj := BallTrajectory.create_batted(
        FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
        40.0, 30.0, 0.0
    )
    var mid := traj.get_position(1.0)
    var late := traj.get_position(3.0)
    assert_float(mid.y).is_greater(1.0)   # goes up
    assert_float(late.y).is_less(mid.y)    # comes down

func test_ground_ball_stays_low() -> void:
    var traj := BallTrajectory.create_batted(
        FieldConstants.HOME_PLATE + Vector3(0, 0.5, 0),
        30.0, -5.0, 10.0  # negative launch = grounder
    )
    var pos := traj.get_position(0.5)
    assert_float(pos.y).is_less(1.0)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_ball_trajectory.gd
```

Expected: FAIL -- `BallTrajectory` not defined.

- [ ] **Step 3: Implement ball trajectory**

Create `src/ball/ball_trajectory.gd`:

```gdscript
class_name BallTrajectory

const GRAVITY := Vector3(0.0, -9.81, 0.0)

var start_position: Vector3
var initial_velocity: Vector3
var spin_break: Vector3       # lateral/vertical break from spin (for pitches)
var flight_duration: float    # expected time to reach target (pitches) or land (batted)
var is_pitch: bool

func get_position(time: float) -> Vector3:
    var pos := start_position + initial_velocity * time + 0.5 * GRAVITY * time * time
    # Apply spin break as a sinusoidal curve that peaks at the end of flight
    if spin_break.length() > 0.001:
        var t_normalized := time / flight_duration if flight_duration > 0.0 else 0.0
        # Break builds gradually, most apparent in last third of flight
        var break_factor := t_normalized * t_normalized
        pos += spin_break * break_factor
    return pos

func get_velocity(time: float) -> Vector3:
    return initial_velocity + GRAVITY * time

static func create_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> BallTrajectory:
    var traj := BallTrajectory.new()
    traj.is_pitch = true

    var pitch_data := PitchTypes.get_pitch(pitch_type)
    traj.start_position = FieldConstants.MOUND + Vector3(0.0, 1.8, 0.0)  # release point

    # Calculate flight time based on speed and distance
    var distance := traj.start_position.distance_to(target)
    traj.flight_duration = distance / pitch_data.speed

    # Calculate initial velocity to reach target (accounting for gravity)
    var t := traj.flight_duration
    # Solve: target = start + v*t + 0.5*g*t^2 => v = (target - start - 0.5*g*t^2) / t
    traj.initial_velocity = (target - traj.start_position - 0.5 * GRAVITY * t * t) / t

    # Apply break as spin deviation (not baked into initial velocity)
    traj.spin_break = Vector3(pitch_data.h_break, -pitch_data.drop, 0.0)

    # Accuracy affects how close to target the pitch actually ends up
    # Lower accuracy = more random deviation (applied via spin_break offset)
    var inaccuracy := (1.0 - accuracy) * 0.15
    traj.spin_break += Vector3(
        randf_range(-inaccuracy, inaccuracy),
        randf_range(-inaccuracy, inaccuracy),
        0.0
    )

    return traj

static func create_batted(start: Vector3, exit_velocity: float, launch_angle_deg: float, h_angle_deg: float) -> BallTrajectory:
    var traj := BallTrajectory.new()
    traj.is_pitch = false
    traj.start_position = start
    traj.spin_break = Vector3.ZERO

    var launch_rad := deg_to_rad(launch_angle_deg)
    var h_rad := deg_to_rad(h_angle_deg)

    # Convert exit velo + angles to velocity vector
    # In our coords: -Z is toward center field, X is left/right
    var horizontal_speed := exit_velocity * cos(launch_rad)
    traj.initial_velocity = Vector3(
        horizontal_speed * sin(h_rad),       # left-right
        exit_velocity * sin(launch_rad),     # up
        -horizontal_speed * cos(h_rad)       # toward outfield
    )

    # Estimate flight duration (time to hit ground)
    # Solve: 0 = start.y + vy*t + 0.5*g*t^2
    var vy := traj.initial_velocity.y
    var sy := start.y
    # Quadratic: 0.5*g*t^2 + vy*t + sy = 0 => t = (-vy - sqrt(vy^2 - 2*g*sy)) / g
    var discriminant := vy * vy - 2.0 * GRAVITY.y * sy
    if discriminant >= 0.0:
        traj.flight_duration = (-vy - sqrt(discriminant)) / GRAVITY.y
    else:
        traj.flight_duration = 3.0  # fallback

    # Ground balls: short flight
    if launch_angle_deg < 5.0:
        traj.flight_duration = minf(traj.flight_duration, 0.3)

    return traj
```

- [ ] **Step 4: Run tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_ball_trajectory.gd
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/ball/ball_trajectory.gd dngrz/test/test_ball_trajectory.gd
git commit -m "feat: ball trajectory system for pitches and batted balls"
```

---

### Task 8: Greybox Field Scene

**Files:**
- Create: `dngrz/src/field/field_builder.gd`
- Create: `dngrz/scenes/field.tscn` (via editor or script)

No TDD for this task -- it's visual/scene work. Verify by running the scene.

- [ ] **Step 1: Create field builder**

Create `src/field/field_builder.gd`:

```gdscript
class_name FieldBuilder

static func build(parent: Node3D) -> void:
    _create_ground(parent)
    _create_infield_dirt(parent)
    _create_bases(parent)
    _create_mound(parent)
    _create_outfield_wall(parent)
    _create_foul_lines(parent)

static func _create_ground(parent: Node3D) -> void:
    var ground := CSGBox3D.new()
    ground.name = "Ground"
    ground.size = Vector3(300.0, 0.1, 300.0)
    ground.position = Vector3(0.0, -0.05, -80.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.5, 0.15)  # grass green
    ground.material = mat
    parent.add_child(ground)

static func _create_infield_dirt(parent: Node3D) -> void:
    var dirt := CSGBox3D.new()
    dirt.name = "InfieldDirt"
    dirt.size = Vector3(55.0, 0.12, 55.0)
    dirt.position = Vector3(0.0, -0.01, -19.4)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.6, 0.45, 0.25)  # dirt brown
    dirt.material = mat
    parent.add_child(dirt)

static func _create_bases(parent: Node3D) -> void:
    var base_positions := {
        "HomePlate": FieldConstants.HOME_PLATE,
        "FirstBase": FieldConstants.FIRST_BASE,
        "SecondBase": FieldConstants.SECOND_BASE,
        "ThirdBase": FieldConstants.THIRD_BASE,
    }
    for base_name in base_positions:
        var base := CSGBox3D.new()
        base.name = base_name
        base.size = Vector3(0.38, 0.06, 0.38)
        base.position = base_positions[base_name] + Vector3(0.0, 0.03, 0.0)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.WHITE
        base.material = mat
        parent.add_child(base)

static func _create_mound(parent: Node3D) -> void:
    var mound := CSGCylinder3D.new()
    mound.name = "Mound"
    mound.radius = 2.75
    mound.height = FieldConstants.MOUND_HEIGHT
    mound.position = Vector3(0.0, FieldConstants.MOUND_HEIGHT / 2.0, -FieldConstants.MOUND_DISTANCE)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55, 0.4, 0.2)
    mound.material = mat
    parent.add_child(mound)

    # Pitching rubber
    var rubber := CSGBox3D.new()
    rubber.name = "PitchingRubber"
    rubber.size = Vector3(0.61, 0.05, 0.15)
    rubber.position = FieldConstants.MOUND + Vector3(0.0, 0.025, 0.0)
    var rmat := StandardMaterial3D.new()
    rmat.albedo_color = Color.WHITE
    rubber.material = rmat
    parent.add_child(rubber)

static func _create_outfield_wall(parent: Node3D) -> void:
    # Approximate outfield fence as arc of boxes
    var segments := 20
    for i in segments:
        var angle := lerp(-PI / 4.0, PI / 4.0, float(i) / float(segments - 1))
        # Interpolate distance: shorter at corners, longer at center
        var t := absf(float(i) / float(segments - 1) - 0.5) * 2.0
        var dist := lerpf(FieldConstants.FENCE_CENTER, FieldConstants.FENCE_CORNERS, t)
        var pos := Vector3(sin(angle) * dist, 1.5, -cos(angle) * dist)

        var wall := CSGBox3D.new()
        wall.name = "Fence_%d" % i
        wall.size = Vector3(dist * PI / float(segments) * 1.1, 3.0, 0.3)
        wall.position = pos
        wall.rotation.y = angle
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.2, 0.3, 0.15)
        wall.material = mat
        parent.add_child(wall)

static func _create_foul_lines(parent: Node3D) -> void:
    # Left foul line
    var left_line := CSGBox3D.new()
    left_line.name = "LeftFoulLine"
    left_line.size = Vector3(0.08, 0.02, 150.0)
    left_line.position = Vector3(-37.5, 0.01, -75.0)
    left_line.rotation.y = PI / 4.0
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    left_line.material = mat
    parent.add_child(left_line)

    # Right foul line
    var right_line := CSGBox3D.new()
    right_line.name = "RightFoulLine"
    right_line.size = Vector3(0.08, 0.02, 150.0)
    right_line.position = Vector3(37.5, 0.01, -75.0)
    right_line.rotation.y = -PI / 4.0
    right_line.material = mat
    parent.add_child(right_line)
```

- [ ] **Step 2: Create field scene**

Create `scenes/field.tscn` in the Godot editor:
1. Create new scene with root `Node3D`, name it "Field"
2. Attach a script that calls the builder on `_ready`:

Create `scenes/field_setup.gd`:

```gdscript
extends Node3D

func _ready() -> void:
    FieldBuilder.build(self)
```

Attach `field_setup.gd` to the Field root node. Save as `scenes/field.tscn`.

- [ ] **Step 3: Add lighting**

Add children to the Field scene in editor:
1. `DirectionalLight3D` -- rotation `(-45, 30, 0)` degrees, energy `1.2`, shadow enabled
2. `WorldEnvironment` with default `Environment` resource -- ambient light set to sky color, tone mapping ACES

Or add via script in `field_setup.gd` `_ready()`:

```gdscript
func _ready() -> void:
    FieldBuilder.build(self)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 30, 0)
    light.light_energy = 1.2
    light.shadow_enabled = true
    add_child(light)

    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.4, 0.5, 0.6)
    environment.ambient_light_energy = 0.5
    environment.tonemap_mode = Environment.TONE_MAP_ACES
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.5, 0.7, 1.0)
    env.environment = environment
    add_child(env)
```

- [ ] **Step 4: Test visually**

Run the field scene in Godot (F6 with `field.tscn` open). Verify:
- Green ground visible
- Brown infield dirt
- White bases at correct positions (diamond shape)
- Pitcher's mound elevated
- Outfield wall arc visible
- Foul lines extending from home plate

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/field/field_builder.gd dngrz/scenes/
git commit -m "feat: greybox baseball field with CSG primitives"
```

---

### Task 9: Ball Scene & Movement

**Files:**
- Create: `dngrz/src/ball/ball.gd`
- Create: `dngrz/scenes/ball.tscn`

- [ ] **Step 1: Create ball script**

Create `src/ball/ball.gd`:

```gdscript
extends Node3D

signal pitch_arrived(plate_position: Vector3)
signal ball_landed(position: Vector3)

var _trajectory: BallTrajectory
var _time: float = 0.0
var _active: bool = false

@onready var _mesh: MeshInstance3D = $Mesh

func throw_pitch(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
    _trajectory = BallTrajectory.create_pitch(pitch_type, target, accuracy)
    position = _trajectory.start_position
    _time = 0.0
    _active = true
    visible = true

func launch_batted(start: Vector3, exit_velocity: float, launch_angle: float, h_angle: float) -> void:
    _trajectory = BallTrajectory.create_batted(start, exit_velocity, launch_angle, h_angle)
    position = start
    _time = 0.0
    _active = true

func reset() -> void:
    _active = false
    visible = false
    _time = 0.0

func _process(delta: float) -> void:
    if not _active:
        return

    _time += delta
    position = _trajectory.get_position(_time)

    if _trajectory.is_pitch:
        # Check if pitch has reached the plate (z >= 0)
        if position.z >= 0.0:
            _active = false
            pitch_arrived.emit(position)
    else:
        # Check if batted ball has landed
        if position.y <= 0.0 and _time > 0.1:
            position.y = 0.0
            _active = false
            ball_landed.emit(position)

func is_active() -> bool:
    return _active

func get_current_velocity() -> Vector3:
    if _trajectory:
        return _trajectory.get_velocity(_time)
    return Vector3.ZERO
```

- [ ] **Step 2: Create ball scene**

Create `scenes/ball.tscn` in editor:
1. Root: `Node3D`, name "Ball"
2. Child: `MeshInstance3D`, name "Mesh"
   - Mesh: `SphereMesh` with radius `0.037` (baseball is ~7.4cm diameter)
   - Material: `StandardMaterial3D` with albedo color white
3. Attach `src/ball/ball.gd` to root

Or create programmatically -- save scene from editor after setup.

- [ ] **Step 3: Test ball movement visually**

Create a temporary test scene to verify ball flight. In the field scene, add a test script:

```gdscript
# Temporary test -- add to field_setup.gd _ready() to verify ball:
var ball_scene := preload("res://scenes/ball.tscn")
var ball := ball_scene.instantiate()
add_child(ball)
ball.throw_pitch(PitchTypes.Type.FASTBALL, Vector3(0.0, 0.8, 0.0), 1.0)

# Add a camera to see it
var cam := Camera3D.new()
cam.position = Vector3(0, 15, 8)
cam.look_at(Vector3(0, 0, -FieldConstants.MOUND_DISTANCE))
add_child(cam)
```

Run scene. Verify ball travels from mound to plate. Remove test code after.

- [ ] **Step 4: Commit**

```bash
git add dngrz/src/ball/ball.gd dngrz/scenes/ball.tscn
git commit -m "feat: ball scene with pitch and batted ball trajectory movement"
```

---

### Task 10: Pitcher Controller

**Files:**
- Create: `dngrz/src/pitcher/pitcher_controller.gd`
- Create: `dngrz/scenes/pitcher.tscn`

- [ ] **Step 1: Create pitcher controller**

Create `src/pitcher/pitcher_controller.gd`:

```gdscript
extends Node3D

signal pitch_executed(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float)

var _selected_pitch: PitchTypes.Type = PitchTypes.Type.FASTBALL
var _target: Vector3 = FieldConstants.STRIKE_ZONE_CENTER
var _is_aiming: bool = false
var _aim_speed := 1.5  # meters per second cursor movement

@onready var _target_marker: MeshInstance3D = $TargetMarker

func _ready() -> void:
    _update_target_marker()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_aiming:
        return

    # Pitch type selection (1-4 keys)
    if event.is_action_pressed("pitch_fastball"):
        _selected_pitch = PitchTypes.Type.FASTBALL
    elif event.is_action_pressed("pitch_curveball"):
        _selected_pitch = PitchTypes.Type.CURVEBALL
    elif event.is_action_pressed("pitch_slider"):
        _selected_pitch = PitchTypes.Type.SLIDER
    elif event.is_action_pressed("pitch_changeup"):
        _selected_pitch = PitchTypes.Type.CHANGEUP

    # Throw
    if event.is_action_pressed("pitch_throw"):
        _execute_pitch()

func _process(delta: float) -> void:
    if not _is_aiming:
        return

    # Move target with WASD or arrow keys
    var move := Vector2.ZERO
    if Input.is_action_pressed("aim_left"):
        move.x -= 1.0
    if Input.is_action_pressed("aim_right"):
        move.x += 1.0
    if Input.is_action_pressed("aim_up"):
        move.y += 1.0
    if Input.is_action_pressed("aim_down"):
        move.y -= 1.0

    if move.length() > 0.0:
        _target.x += move.x * _aim_speed * delta
        _target.y += move.y * _aim_speed * delta
        # Clamp to reasonable area around the zone
        _target.x = clampf(_target.x, -0.6, 0.6)
        _target.y = clampf(_target.y, 0.1, 1.5)
        _update_target_marker()

func start_aiming() -> void:
    _is_aiming = true
    _target = FieldConstants.STRIKE_ZONE_CENTER
    _target_marker.visible = true
    _update_target_marker()

func stop_aiming() -> void:
    _is_aiming = false
    _target_marker.visible = false

func _execute_pitch() -> void:
    _is_aiming = false
    _target_marker.visible = false
    var pitch_data := PitchTypes.get_pitch(_selected_pitch)
    pitch_executed.emit(_selected_pitch, _target, pitch_data.accuracy)

func _update_target_marker() -> void:
    if _target_marker:
        _target_marker.position = _target
```

- [ ] **Step 2: Create pitcher scene**

Create `scenes/pitcher.tscn`:
1. Root: `Node3D`, name "Pitcher"
2. Child: `MeshInstance3D`, name "Body" -- `CapsuleMesh` (radius 0.3, height 1.8), positioned at `(0, 0.9, 0)`, brown material
3. Child: `MeshInstance3D`, name "TargetMarker" -- `SphereMesh` (radius 0.04), red semi-transparent material
4. Attach `src/pitcher/pitcher_controller.gd` to root
5. Position the pitcher scene at `FieldConstants.MOUND`

- [ ] **Step 3: Set up input actions**

Add to `project.godot` input map (via Project Settings > Input Map):

| Action | Key (Pitcher) |
|--------|---------------|
| `pitch_fastball` | `1` |
| `pitch_curveball` | `2` |
| `pitch_slider` | `3` |
| `pitch_changeup` | `4` |
| `aim_left` | `A` |
| `aim_right` | `D` |
| `aim_up` | `W` |
| `aim_down` | `S` |
| `pitch_throw` | `Space` |

- [ ] **Step 4: Commit**

```bash
git add dngrz/src/pitcher/pitcher_controller.gd dngrz/scenes/pitcher.tscn dngrz/project.godot
git commit -m "feat: pitcher controller with pitch selection, aiming, and execution"
```

---

### Task 11: Batter Controller

**Files:**
- Create: `dngrz/src/batter/batter_controller.gd`
- Create: `dngrz/scenes/batter.tscn`

- [ ] **Step 1: Create batter controller**

Create `src/batter/batter_controller.gd`:

```gdscript
extends Node3D

signal swing_result(timing_offset: float, placement_offset: Vector2)
signal took_pitch  # batter didn't swing

var _can_swing: bool = false
var _pitch_arrival_time: float = 0.0
var _cursor: Vector2 = Vector2.ZERO  # relative to strike zone center
var _cursor_speed := 2.0
var _swung: bool = false

@onready var _cursor_marker: MeshInstance3D = $CursorMarker

func _unhandled_input(event: InputEvent) -> void:
    if not _can_swing:
        return

    if event.is_action_pressed("batter_swing") and not _swung:
        _swung = true
        _execute_swing()

func _process(delta: float) -> void:
    if not _can_swing or _swung:
        return

    # Move batting cursor with arrow keys / right stick
    var move := Vector2.ZERO
    if Input.is_action_pressed("bat_cursor_left"):
        move.x -= 1.0
    if Input.is_action_pressed("bat_cursor_right"):
        move.x += 1.0
    if Input.is_action_pressed("bat_cursor_up"):
        move.y += 1.0
    if Input.is_action_pressed("bat_cursor_down"):
        move.y -= 1.0

    if move.length() > 0.0:
        _cursor += move.normalized() * _cursor_speed * delta
        _cursor.x = clampf(_cursor.x, -0.5, 0.5)
        _cursor.y = clampf(_cursor.y, -0.5, 0.5)
        _update_cursor_marker()

func start_at_bat(pitch_flight_duration: float) -> void:
    _can_swing = true
    _swung = false
    _pitch_arrival_time = pitch_flight_duration
    _cursor = Vector2.ZERO
    _cursor_marker.visible = true
    _update_cursor_marker()

func pitch_arrived(plate_position: Vector3) -> void:
    _can_swing = false
    _cursor_marker.visible = false
    if not _swung:
        took_pitch.emit()

func _execute_swing() -> void:
    # Calculate timing offset: how far from the pitch arrival we swung
    # This will be set by the game orchestrator based on when the pitch actually arrives
    # For now, emit the cursor position -- the game.gd will calculate timing
    swing_result.emit(0.0, _cursor)  # timing filled in by game.gd

func _update_cursor_marker() -> void:
    if _cursor_marker:
        _cursor_marker.position = Vector3(
            _cursor.x,
            FieldConstants.STRIKE_ZONE_CENTER.y + _cursor.y,
            0.0
        )

func get_cursor_position() -> Vector2:
    return _cursor
```

- [ ] **Step 2: Create batter scene**

Create `scenes/batter.tscn`:
1. Root: `Node3D`, name "Batter"
2. Child: `MeshInstance3D`, name "Body" -- `CapsuleMesh` (radius 0.3, height 1.8), positioned at `(0, 0.9, 0)`, blue material
3. Child: `MeshInstance3D`, name "CursorMarker" -- `SphereMesh` (radius 0.03), yellow semi-transparent material
4. Attach `src/batter/batter_controller.gd` to root
5. Position at `Vector3(0.5, 0, 0.3)` (batter's box, right-handed)

- [ ] **Step 3: Set up batter input actions**

Add to input map:

| Action | Key (Batter) |
|--------|--------------|
| `batter_swing` | `Enter` / `Return` |
| `bat_cursor_left` | `Left` arrow |
| `bat_cursor_right` | `Right` arrow |
| `bat_cursor_up` | `Up` arrow |
| `bat_cursor_down` | `Down` arrow |

- [ ] **Step 4: Commit**

```bash
git add dngrz/src/batter/batter_controller.gd dngrz/scenes/batter.tscn dngrz/project.godot
git commit -m "feat: batter controller with swing cursor and timing"
```

---

### Task 12: Game Orchestrator & Camera

**Files:**
- Create: `dngrz/src/game/game.gd`
- Create: `dngrz/src/camera/game_camera.gd`
- Create: `dngrz/scenes/game.tscn`

This task wires everything together into a playable pitch/bat duel.

- [ ] **Step 1: Create game camera**

Create `src/camera/game_camera.gd`:

```gdscript
extends Camera3D

enum View { PITCH, BAT, PLAY }

const POSITIONS := {
    View.PITCH: Vector3(0.0, 3.0, -22.0),   # behind pitcher, elevated
    View.BAT: Vector3(0.0, 2.5, 3.0),        # behind batter
    View.PLAY: Vector3(0.0, 25.0, 5.0),      # high broadcast view
}

const LOOK_TARGETS := {
    View.PITCH: Vector3(0.0, 0.8, 0.0),      # look at strike zone
    View.BAT: Vector3(0.0, 1.0, -18.0),       # look at pitcher
    View.PLAY: Vector3(0.0, 0.0, -40.0),      # look at field center
}

var _current_view: View = View.PITCH
var _tween: Tween

func set_view(view: View, instant: bool = false) -> void:
    _current_view = view
    if instant:
        position = POSITIONS[view]
        look_at(LOOK_TARGETS[view])
        return

    if _tween:
        _tween.kill()
    _tween = create_tween().set_parallel(true)
    _tween.tween_property(self, "position", POSITIONS[view], 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    _tween.tween_callback(look_at.bind(LOOK_TARGETS[view])).set_delay(0.5)
```

- [ ] **Step 2: Create game orchestrator**

Create `src/game/game.gd`:

```gdscript
extends Node3D

enum Phase { WAITING, PITCHING, BALL_IN_FLIGHT, SWING_EVAL, PLAY, RESULT }

var _phase: Phase = Phase.WAITING
var _count: CountTracker
var _innings: InningManager
var _pitch_start_time: float = 0.0
var _swing_time: float = -1.0

@onready var _ball: Node3D = $Ball
@onready var _pitcher: Node3D = $Pitcher
@onready var _batter: Node3D = $Batter
@onready var _camera: Camera3D = $GameCamera
@onready var _hud: Control = $HUD

func _ready() -> void:
    _count = CountTracker.new()
    add_child(_count)
    _innings = InningManager.new()
    add_child(_innings)

    _ball.pitch_arrived.connect(_on_pitch_arrived)
    _ball.ball_landed.connect(_on_ball_landed)
    _pitcher.pitch_executed.connect(_on_pitch_executed)
    _batter.swing_result.connect(_on_swing)
    _batter.took_pitch.connect(_on_took_pitch)
    _count.walk.connect(_on_walk)
    _count.strikeout.connect(_on_strikeout)
    _count.side_retired.connect(_on_side_retired)
    _innings.game_over_signal.connect(_on_game_over)

    _start_at_bat()

func _start_at_bat() -> void:
    _phase = Phase.PITCHING
    _ball.reset()
    _swing_time = -1.0
    _camera.set_view(_camera.View.PITCH)
    _pitcher.start_aiming()
    _update_hud()

func _on_pitch_executed(pitch_type: PitchTypes.Type, target: Vector3, accuracy: float) -> void:
    _phase = Phase.BALL_IN_FLIGHT
    _pitch_start_time = Time.get_ticks_msec() / 1000.0
    _ball.throw_pitch(pitch_type, target, accuracy)
    _camera.set_view(_camera.View.BAT)
    _batter.start_at_bat(_ball._trajectory.flight_duration)

func _on_swing(timing_offset: float, cursor: Vector2) -> void:
    _swing_time = Time.get_ticks_msec() / 1000.0

func _on_pitch_arrived(plate_position: Vector3) -> void:
    _batter.pitch_arrived(plate_position)

    if _swing_time > 0.0:
        # Calculate actual timing offset
        var pitch_end_time := _pitch_start_time + _ball._trajectory.flight_duration
        var timing := _swing_time - pitch_end_time
        var cursor := _batter.get_cursor_position()

        # Calculate placement offset (cursor vs actual pitch location)
        var zone_pos := StrikeZone.get_plate_position(plate_position)
        var placement := Vector2(cursor.x - plate_position.x, cursor.y - (plate_position.y - FieldConstants.STRIKE_ZONE_CENTER.y))

        var contact := ContactCalculator.calculate(timing, placement, _ball._trajectory.initial_velocity.length())

        if contact.is_whiff:
            # Swinging strike
            _count.add_strike()
            _start_at_bat()
        else:
            # Contact! Launch the ball
            _phase = Phase.PLAY
            _camera.set_view(_camera.View.PLAY)
            _ball.launch_batted(
                FieldConstants.HOME_PLATE + Vector3(0, 1.0, 0),
                contact.exit_velocity,
                contact.launch_angle,
                contact.h_angle
            )
    else:
        # Batter didn't swing -- check strike zone
        if StrikeZone.is_strike(plate_position):
            _count.add_strike()
        else:
            _count.add_ball()
        _start_at_bat()

func _on_ball_landed(land_position: Vector3) -> void:
    # Simplified: check if it's fair or foul, in the field or over the fence
    var is_fair := _is_fair_ball(land_position)
    var is_home_run := land_position.distance_to(FieldConstants.HOME_PLATE) > FieldConstants.FENCE_CORNERS

    if not is_fair:
        _count.add_foul()
        _start_at_bat()
        return

    if is_home_run:
        _innings.add_run()
        _count.new_batter()
        _start_at_bat()
        return

    # For now, simplified: any fair ball in play is a single (base hit)
    # Full fielding/baserunning comes in later tasks
    _count.new_batter()
    _start_at_bat()

func _is_fair_ball(pos: Vector3) -> bool:
    # Fair ball: between the foul lines (within 45-degree cone from home plate toward outfield)
    if pos.z >= 0.0:
        return false  # behind home plate
    var angle := atan2(pos.x, -pos.z)
    return absf(angle) <= PI / 4.0  # within 45 degrees of center field

func _on_walk() -> void:
    _count.new_batter()
    _start_at_bat()

func _on_strikeout() -> void:
    _count.new_batter()
    _start_at_bat()

func _on_side_retired() -> void:
    _innings.advance_half_inning()
    if _innings.is_game_over():
        _on_game_over()
        return
    _count.new_half_inning()
    _start_at_bat()

func _on_game_over() -> void:
    _phase = Phase.RESULT
    print("GAME OVER -- Home: %d  Away: %d" % [_innings.home_score, _innings.away_score])

func _update_hud() -> void:
    if _hud and _hud.has_method("update_display"):
        _hud.update_display(_count, _innings)
```

- [ ] **Step 3: Create HUD**

Create `src/ui/hud.gd`:

```gdscript
extends Control

@onready var _count_label: Label = $CountLabel
@onready var _score_label: Label = $ScoreLabel
@onready var _inning_label: Label = $InningLabel

func update_display(count: CountTracker, innings: InningManager) -> void:
    if _count_label:
        _count_label.text = "%d-%d | %d Out" % [count.balls, count.strikes, count.outs]
    if _score_label:
        _score_label.text = "Away %d - Home %d" % [innings.away_score, innings.home_score]
    if _inning_label:
        _inning_label.text = innings.get_inning_display()
```

- [ ] **Step 4: Build game scene**

Create `scenes/game.tscn` in editor:
1. Root: `Node3D`, name "Game", attach `src/game/game.gd`
2. Instance child: `scenes/field.tscn`
3. Instance child: `scenes/ball.tscn`, name "Ball"
4. Instance child: `scenes/pitcher.tscn`, name "Pitcher", position at `FieldConstants.MOUND + Vector3(0, 0, 0)`
5. Instance child: `scenes/batter.tscn`, name "Batter", position at `Vector3(0.5, 0, 0.3)`
6. Child: `Camera3D`, name "GameCamera", attach `src/camera/game_camera.gd`, position at `(0, 3, -22)`
7. Child: `CanvasLayer` > `Control` (full rect), name "HUD", attach `src/ui/hud.gd`
   - Child Label "CountLabel" -- top-left, font size 24
   - Child Label "ScoreLabel" -- top-center, font size 24
   - Child Label "InningLabel" -- top-right, font size 24

Set `scenes/game.tscn` as the main scene in Project Settings > Application > Run > Main Scene.

- [ ] **Step 5: Playtest the pitch/bat loop**

Run the project (F5). Verify:
- Pitcher can aim with WASD and select pitches with 1-4
- Space throws the pitch
- Camera transitions from pitcher view to batter view
- Ball travels from mound to plate
- Batter can move cursor with arrows and swing with Enter
- Swinging strike, called strike, ball, and foul outcomes work
- Count updates on HUD
- Strikeout and walk trigger new batters
- 3 outs change the inning

- [ ] **Step 6: Commit**

```bash
git add dngrz/src/game/game.gd dngrz/src/camera/game_camera.gd dngrz/src/ui/hud.gd dngrz/scenes/game.tscn dngrz/project.godot
git commit -m "feat: playable pitch/bat duel with game state, camera, and HUD"
```

---

### Task 13: Basic Fielding

**Files:**
- Create: `dngrz/src/fielding/fielder_ai.gd`
- Create: `dngrz/src/fielding/fielding_manager.gd`
- Create: `dngrz/scenes/fielder.tscn`
- Modify: `dngrz/src/game/game.gd`

- [ ] **Step 1: Create fielder AI**

Create `src/fielding/fielder_ai.gd`:

```gdscript
extends Node3D

signal ball_fielded(fielder: Node3D)
signal throw_completed(target_base: Vector3)

var position_name: String = ""
var home_position: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _speed := 8.0  # m/s run speed
var _is_chasing: bool = false
var _has_ball: bool = false
var _throw_target: Vector3 = Vector3.ZERO
var _ball_ref: Node3D = null

const CATCH_RADIUS := 2.0  # meters

func _process(delta: float) -> void:
    if _is_chasing and not _has_ball:
        var dir := (_target - position).normalized()
        dir.y = 0  # stay on ground
        position += dir * _speed * delta

        # Check if close enough to catch/field
        if _ball_ref and position.distance_to(_ball_ref.position) < CATCH_RADIUS:
            _has_ball = true
            _is_chasing = false
            ball_fielded.emit(self)

func chase_ball(ball: Node3D, intercept_position: Vector3) -> void:
    _ball_ref = ball
    _target = intercept_position
    _target.y = 0
    _is_chasing = true
    _has_ball = false

func return_home() -> void:
    _is_chasing = false
    _has_ball = false
    _ball_ref = null
    # Tween back to home position
    var tween := create_tween()
    tween.tween_property(self, "position", home_position, 1.0).set_ease(Tween.EASE_OUT)

func throw_to(target: Vector3) -> void:
    _has_ball = false
    throw_completed.emit(target)
```

- [ ] **Step 2: Create fielding manager**

Create `src/fielding/fielding_manager.gd`:

```gdscript
extends Node3D

signal ball_caught(fielder: Node3D)
signal ball_thrown_to_base(base_position: Vector3)

var _fielders: Array[Node3D] = []
var _fielder_scene: PackedScene

func _ready() -> void:
    _fielder_scene = preload("res://scenes/fielder.tscn")

func setup_fielders() -> void:
    for child in get_children():
        child.queue_free()
    _fielders.clear()

    for pos_name in FieldConstants.FIELDER_POSITIONS:
        if pos_name == "pitcher" or pos_name == "catcher":
            continue  # pitcher and catcher handled separately
        var fielder := _fielder_scene.instantiate()
        fielder.position_name = pos_name
        fielder.home_position = FieldConstants.FIELDER_POSITIONS[pos_name]
        fielder.position = fielder.home_position
        fielder.ball_fielded.connect(_on_ball_fielded)
        add_child(fielder)
        _fielders.append(fielder)

func dispatch_to_ball(ball: Node3D, land_position: Vector3) -> void:
    # Find closest fielder to the landing position
    var closest: Node3D = null
    var closest_dist := INF
    for fielder in _fielders:
        var dist := fielder.position.distance_to(land_position)
        if dist < closest_dist:
            closest_dist = dist
            closest = fielder

    if closest:
        closest.chase_ball(ball, land_position)

func reset_fielders() -> void:
    for fielder in _fielders:
        fielder.return_home()

func _on_ball_fielded(fielder: Node3D) -> void:
    ball_caught.emit(fielder)
    # Throw to first base by default (simplified)
    fielder.throw_to(FieldConstants.FIRST_BASE)
    ball_thrown_to_base.emit(FieldConstants.FIRST_BASE)
    # Return all fielders home after a delay
    get_tree().create_timer(1.5).timeout.connect(reset_fielders)
```

- [ ] **Step 3: Create fielder scene**

Create `scenes/fielder.tscn`:
1. Root: `Node3D`, name "Fielder", attach `src/fielding/fielder_ai.gd`
2. Child: `MeshInstance3D`, name "Body" -- `CapsuleMesh` (radius 0.25, height 1.7), gray material

- [ ] **Step 4: Integrate fielding into game.gd**

Add to `game.gd` -- add `@onready var _fielding: Node3D = $FieldingManager` and update `_on_ball_landed`:

```gdscript
# Add to _ready():
_fielding.ball_caught.connect(_on_ball_caught)
_fielding.setup_fielders()

# Replace the simplified _on_ball_landed:
func _on_ball_landed(land_position: Vector3) -> void:
    var is_fair := _is_fair_ball(land_position)
    var is_home_run := land_position.distance_to(FieldConstants.HOME_PLATE) > FieldConstants.FENCE_CORNERS

    if not is_fair:
        _count.add_foul()
        _fielding.reset_fielders()
        _start_at_bat()
        return

    if is_home_run:
        _innings.add_run()
        _count.new_batter()
        _fielding.reset_fielders()
        _start_at_bat()
        return

    # Dispatch fielders to the ball
    _fielding.dispatch_to_ball(_ball, land_position)

func _on_ball_caught(_fielder: Node3D) -> void:
    # For now: any fielded ball is an out
    _count.add_out()
    if not _count.is_side_retired():
        _count.new_batter()
        _start_at_bat()
```

Add `FieldingManager` node (Node3D with `fielding_manager.gd`) as child of Game scene.

- [ ] **Step 5: Playtest fielding**

Run the game. Hit the ball into the field. Verify:
- Nearest fielder runs to the ball landing spot
- Fielder catches/fields the ball
- An out is recorded
- Fielders return to home positions

- [ ] **Step 6: Commit**

```bash
git add dngrz/src/fielding/ dngrz/scenes/fielder.tscn dngrz/src/game/game.gd dngrz/scenes/game.tscn
git commit -m "feat: basic fielding with AI chase, catch, and throw"
```

---

### Task 14: Basic Baserunning

**Files:**
- Create: `dngrz/src/baserunning/baserunner.gd`
- Create: `dngrz/src/baserunning/baserunning_manager.gd`
- Modify: `dngrz/src/game/game.gd`

- [ ] **Step 1: Create baserunner**

Create `src/baserunning/baserunner.gd`:

```gdscript
extends Node3D

signal reached_base(base_index: int)
signal scored

var current_base: int = 0  # 0=home, 1=first, 2=second, 3=third, 4=scored
var _target_base: int = 0
var _speed := 7.5  # m/s
var _is_running: bool = false

const BASE_POSITIONS := [
    Vector3(0.0, 0.0, 0.0),   # home (FieldConstants.HOME_PLATE)
]

func _ready() -> void:
    # Initialize from FieldConstants
    pass

func _process(delta: float) -> void:
    if not _is_running:
        return

    var target_pos := _get_base_position(_target_base)
    var dir := (target_pos - position).normalized()
    dir.y = 0
    position += dir * _speed * delta

    if position.distance_to(target_pos) < 0.5:
        current_base = _target_base
        _is_running = false
        if current_base >= 4:
            scored.emit()
        else:
            reached_base.emit(current_base)

func advance_to(base_index: int) -> void:
    _target_base = base_index
    _is_running = true

func _get_base_position(base_index: int) -> Vector3:
    match base_index:
        0: return FieldConstants.HOME_PLATE
        1: return FieldConstants.FIRST_BASE
        2: return FieldConstants.SECOND_BASE
        3: return FieldConstants.THIRD_BASE
        _: return FieldConstants.HOME_PLATE  # scoring = running home
```

- [ ] **Step 2: Create baserunning manager**

Create `src/baserunning/baserunning_manager.gd`:

```gdscript
extends Node3D

signal runner_scored

var _runners: Array[Node3D] = []

func place_batter_runner() -> void:
    var runner := Node3D.new()
    var script := preload("res://src/baserunning/baserunner.gd")
    runner.set_script(script)
    runner.position = FieldConstants.HOME_PLATE
    runner.current_base = 0

    # Visual
    var mesh := MeshInstance3D.new()
    mesh.mesh = CapsuleMesh.new()
    mesh.mesh.radius = 0.2
    mesh.mesh.height = 1.5
    mesh.position = Vector3(0, 0.75, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.4, 0.9)
    mesh.material_override = mat
    runner.add_child(mesh)

    runner.scored.connect(_on_runner_scored.bind(runner))
    add_child(runner)
    _runners.append(runner)

func advance_all_runners(bases: int) -> void:
    for runner in _runners:
        var new_base := runner.current_base + bases
        runner.advance_to(mini(new_base, 4))

func clear_runners() -> void:
    for runner in _runners:
        runner.queue_free()
    _runners.clear()

func get_runners_on_base() -> int:
    var count := 0
    for runner in _runners:
        if runner.current_base >= 1 and runner.current_base <= 3:
            count += 1
    return count

func _on_runner_scored(runner: Node3D) -> void:
    runner_scored.emit()
    _runners.erase(runner)
    runner.queue_free()
```

- [ ] **Step 3: Integrate baserunning into game.gd**

Add `@onready var _baserunning: Node3D = $BaserunningManager` and wire into the game flow:

```gdscript
# In _ready():
_baserunning.runner_scored.connect(_on_runner_scored)

# On contact (in _on_pitch_arrived, after launching batted ball):
_baserunning.place_batter_runner()

# In _on_ball_landed, for fair non-HR hits:
_baserunning.advance_all_runners(1)  # simplified: single

# In _on_ball_caught:
# Out recorded, remove batter-runner (simplified: all runners hold)

func _on_runner_scored() -> void:
    _innings.add_run()
    _update_hud()

# On new half-inning:
_baserunning.clear_runners()
```

Add `BaserunningManager` node (Node3D with `baserunning_manager.gd`) as child of Game scene.

- [ ] **Step 4: Playtest with baserunning**

Run the game. Verify:
- On a hit, a runner appears at home and runs to first
- On a home run, the runner runs all the way around and scores
- Score updates on HUD
- Runners clear on half-inning change

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/baserunning/ dngrz/src/game/game.gd dngrz/scenes/game.tscn
git commit -m "feat: basic baserunning with runner advancement and scoring"
```

---

### Task 15: Polish & Full Game Loop Verification

**Files:**
- Modify: `dngrz/src/game/game.gd`
- Modify: `dngrz/src/ui/hud.gd`

- [ ] **Step 1: Add pitch type display to HUD**

Update `src/ui/hud.gd`:

```gdscript
extends Control

@onready var _count_label: Label = $CountLabel
@onready var _score_label: Label = $ScoreLabel
@onready var _inning_label: Label = $InningLabel
@onready var _info_label: Label = $InfoLabel

func update_display(count: CountTracker, innings: InningManager) -> void:
    if _count_label:
        _count_label.text = "%d-%d | %d Out" % [count.balls, count.strikes, count.outs]
    if _score_label:
        _score_label.text = "Away %d - Home %d" % [innings.away_score, innings.home_score]
    if _inning_label:
        _inning_label.text = innings.get_inning_display()

func show_info(text: String) -> void:
    if _info_label:
        _info_label.text = text
        # Auto-clear after 2 seconds
        get_tree().create_timer(2.0).timeout.connect(func(): _info_label.text = "")

func show_game_over(home: int, away: int) -> void:
    if _info_label:
        if home > away:
            _info_label.text = "GAME OVER - HOME WINS %d-%d" % [home, away]
        elif away > home:
            _info_label.text = "GAME OVER - AWAY WINS %d-%d" % [away, home]
        else:
            _info_label.text = "TIE GAME %d-%d" % [home, away]
```

Add a `Label` named "InfoLabel" to the HUD scene -- centered, large font, for event feedback.

- [ ] **Step 2: Add event feedback to game.gd**

Add `_hud.show_info()` calls throughout game.gd for player feedback:

```gdscript
# In _on_pitch_arrived, after determining outcome:
# Swinging strike:
_hud.show_info("Swinging Strike!")

# Called strike:
_hud.show_info("Strike!")

# Ball:
_hud.show_info("Ball")

# In _on_ball_landed:
# Foul:
_hud.show_info("Foul Ball")

# Home run:
_hud.show_info("HOME RUN!")

# In _on_strikeout:
_hud.show_info("STRIKEOUT!")

# In _on_walk:
_hud.show_info("Walk")

# In _on_game_over:
_hud.show_game_over(_innings.home_score, _innings.away_score)
```

- [ ] **Step 3: Run all tests**

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/
```

Expected: All tests pass.

- [ ] **Step 4: Full playtest**

Run the complete game. Play through a full 5-inning game. Verify:
- Pitching: all 4 pitch types work, aiming is responsive
- Batting: swing timing affects contact quality, cursor placement affects launch angle
- Count: balls, strikes, fouls, walks, strikeouts all track correctly
- Fielding: fielders chase and catch batted balls
- Baserunning: runners advance and score
- Innings: sides switch after 3 outs, game ends after 5 innings
- HUD: count, score, inning, and event feedback all display correctly
- Home runs score runs
- Walk-off ending works in bottom of 5th

- [ ] **Step 5: Commit**

```bash
git add dngrz/src/ dngrz/scenes/
git commit -m "feat: complete core baseball prototype with full game loop"
```

---

## Implementation Priority

If time is limited, tasks can be cut at these boundaries:

**Minimum playable (Tasks 1-12):** Pitch/bat duel with count, scoring, and camera. No fielding or baserunning -- every hit is tracked by outcome only. This tests the core feel.

**With fielding (add Task 13):** Fielders chase balls and record outs. Still no runners visible.

**Full prototype (all tasks):** Complete game loop with all systems integrated.
