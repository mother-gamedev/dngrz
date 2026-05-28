class_name TestPitcherController extends GdUnitTestSuite

const PITCHER_SCENE := preload("res://scenes/pitcher.tscn")

# --- Pure charge model (no scene needed) ---

func test_power_rises_with_charge_to_max_at_full() -> void:
	assert_float(PitcherController.power_for_charge(0.0)).is_equal_approx(PitcherController.MIN_POWER, 0.0001)
	assert_float(PitcherController.power_for_charge(1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(PitcherController.power_for_charge(0.5)).is_greater(PitcherController.power_for_charge(0.2))

func test_overhold_decays_power() -> void:
	# Holding past the top of the ramp bleeds power back down.
	assert_float(PitcherController.power_for_charge(1.6)).is_less(PitcherController.power_for_charge(1.0))
	assert_float(PitcherController.power_for_charge(3.0)).is_greater_equal(PitcherController.MIN_POWER)

func test_early_release_keeps_base_accuracy() -> void:
	# Releasing before the perfect window is the safe, lower-power option.
	assert_float(PitcherController.accuracy_for_charge(0.5, 0.8)).is_equal_approx(0.8, 0.0001)

func test_perfect_window_sharpens_accuracy() -> void:
	# Nailing the top of the ramp earns an accuracy bonus above the pitch's base.
	assert_float(PitcherController.accuracy_for_charge(1.0, 0.8)).is_greater(0.8)

func test_overhold_degrades_to_meatball() -> void:
	# A charge just past the band: mid-slope decay, not pinned to the floor.
	var acc := PitcherController.accuracy_for_charge(1.3, 0.8)
	assert_float(acc).is_less(0.8)
	assert_float(acc).is_greater_equal(PitcherController.MEATBALL_ACCURACY)

func test_accuracy_is_continuous_across_peak() -> void:
	# No accuracy cliff just past the perfect peak: over-hold decays smoothly from
	# the peak (1.0), not from base_accuracy. The buggy version dropped ~0.20 at
	# charge = 1.0 + epsilon.
	var peak := PitcherController.accuracy_for_charge(1.0, 0.8)
	var just_past := PitcherController.accuracy_for_charge(1.01, 0.8)
	assert_float(absf(peak - just_past)).is_less(0.02)

func test_newcomer_floor_is_serviceable() -> void:
	# A do-nothing pitch (no charge) is a slower-but-accurate straight ball (spec §10).
	assert_float(PitcherController.power_for_charge(0.0)).is_equal_approx(PitcherController.MIN_POWER, 0.0001)
	assert_float(PitcherController.accuracy_for_charge(0.0, 0.85)).is_equal_approx(0.85, 0.0001)

func test_bend_scales_with_stick() -> void:
	assert_vector(PitcherController.bend_from_stick(Vector2(1.0, 0.0))).is_equal(Vector2(PitcherController.BEND_MAX, 0.0))
	assert_vector(PitcherController.bend_from_stick(Vector2.ZERO)).is_equal(Vector2.ZERO)
	assert_float(PitcherController.bend_from_stick(Vector2(2.0, 0.0)).x).is_equal_approx(PitcherController.BEND_MAX, 0.0001)  # clamped

func test_bend_diagonal_respects_max_magnitude() -> void:
	# Spec: BEND_MAX caps total bend magnitude (the batter HUD chevron is scaled to
	# it in Task 7). Per-axis clamping would let diagonals exceed BEND_MAX.
	var diag := PitcherController.bend_from_stick(Vector2(1.0, 1.0))
	assert_float(diag.length()).is_less_equal(PitcherController.BEND_MAX + 0.0001)
	# The radial clamp also preserves direction — diagonal stays diagonal.
	assert_float(absf(diag.x - diag.y)).is_less(0.0001)

func test_charge_for_ticks_normalizes_to_ramp() -> void:
	assert_float(PitcherController.charge_for_ticks(PitcherController.CHARGE_TICKS)).is_equal_approx(1.0, 0.0001)
	assert_float(PitcherController.charge_for_ticks(0)).is_equal_approx(0.0, 0.0001)

# --- The release command builder (uses the selected pitch + aim) ---

func test_build_release_command_carries_power_bend_accuracy() -> void:
	var p: PitcherController = PITCHER_SCENE.instantiate()
	add_child(p)
	await get_tree().process_frame
	p.select_pitch(PitchTypes.Type.SLIDER)
	p.set_target(Vector3(0.1, 0.6, 0.0))
	# Perfect-window charge, full-right bend stick.
	var cmd: PitchCommand = p.build_release_command(1.0, Vector2(1.0, 0.0))
	assert_int(cmd.type).is_equal(PitchTypes.Type.SLIDER)
	assert_vector(cmd.target).is_equal(Vector3(0.1, 0.6, 0.0))
	assert_float(cmd.power).is_equal_approx(1.0, 0.0001)
	assert_vector(cmd.bend).is_equal(Vector2(PitcherController.BEND_MAX, 0.0))
	# Perfect-window charge (1.0) earns the accuracy bonus to a 1.0 bullseye, even
	# for the SLIDER's base accuracy of 0.75. A `> 0.0` assertion let the cliff bug
	# (Bug 2 of the post-Task-3 fix pass) slip through.
	assert_float(cmd.accuracy).is_equal_approx(1.0, 0.0001)
	p.queue_free()

# --- AI / programmatic path still works (now forwards power+bend) ---

func test_request_pitch_emits_pitch_command() -> void:
	var p: PitcherController = PITCHER_SCENE.instantiate()
	add_child(p)
	await get_tree().process_frame
	var captured := [null]
	p.pitch_committed.connect(func(cmd: PitchCommand) -> void: captured[0] = cmd)
	p.request_pitch(PitchTypes.Type.SLIDER, Vector3(0.1, 0.6, 0.0), 0.75, 0.9, Vector2(0.2, -0.1))
	assert_object(captured[0]).is_not_null()
	var cmd: PitchCommand = captured[0]
	assert_int(cmd.type).is_equal(PitchTypes.Type.SLIDER)
	assert_vector(cmd.target).is_equal(Vector3(0.1, 0.6, 0.0))
	assert_float(cmd.accuracy).is_equal_approx(0.75, 0.0001)
	assert_float(cmd.power).is_equal_approx(0.9, 0.0001)
	assert_vector(cmd.bend).is_equal(Vector2(0.2, -0.1))
	p.queue_free()
