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

func test_display_name_returns_human_names() -> void:
	assert_str(PitchTypes.display_name(PitchTypes.Type.FASTBALL)).is_equal("Fastball")
	assert_str(PitchTypes.display_name(PitchTypes.Type.CURVEBALL)).is_equal("Curveball")
	assert_str(PitchTypes.display_name(PitchTypes.Type.SLIDER)).is_equal("Slider")
	assert_str(PitchTypes.display_name(PitchTypes.Type.CHANGEUP)).is_equal("Changeup")

func test_get_pitch_returns_independent_copy() -> void:
	var a := PitchTypes.get_pitch(PitchTypes.Type.FASTBALL)
	a.speed = 0.0
	var b := PitchTypes.get_pitch(PitchTypes.Type.FASTBALL)
	assert_float(b.speed).is_greater(0.0)

func test_pitches_have_break_markers() -> void:
	var curve := PitchTypes.get_pitch(PitchTypes.Type.CURVEBALL)
	assert_float(curve.break_marker.y).is_less(0.0)  # curve breaks downward
	var slider := PitchTypes.get_pitch(PitchTypes.Type.SLIDER)
	assert_float(slider.break_marker.x).is_less(0.0)  # slider sweeps glove-side

func test_all_pitches_are_basic_tier() -> void:
	for pitch_type in PitchTypes.Type.values():
		assert_int(PitchTypes.get_pitch(pitch_type).tier).is_equal(PitchTypes.Tier.BASIC)

func test_duplicate_preserves_new_fields() -> void:
	var a := PitchTypes.get_pitch(PitchTypes.Type.SLIDER)
	var b := a.duplicate()
	assert_vector(b.break_marker).is_equal(a.break_marker)
	assert_int(b.tier).is_equal(a.tier)
