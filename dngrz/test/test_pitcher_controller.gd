class_name TestPitcherController extends GdUnitTestSuite

const PITCHER_SCENE := preload("res://scenes/pitcher.tscn")

func test_pitcher_loads() -> void:
	var pitcher := PITCHER_SCENE.instantiate()
	assert_object(pitcher).is_not_null()
	pitcher.queue_free()

func test_default_pitch_is_fastball() -> void:
	var pitcher := PITCHER_SCENE.instantiate()
	assert_int(pitcher.get_selected_pitch()).is_equal(PitchTypes.Type.FASTBALL)
	pitcher.queue_free()

func test_default_target_is_zone_center() -> void:
	var pitcher := PITCHER_SCENE.instantiate()
	var target: Vector3 = pitcher.get_target()
	assert_float(target.distance_to(FieldConstants.STRIKE_ZONE_CENTER)).is_less(0.001)
	pitcher.queue_free()

func test_request_pitch_emits_signal() -> void:
	var pitcher := PITCHER_SCENE.instantiate()
	add_child(pitcher)
	await get_tree().process_frame
	var fired := [false]
	var emitted_type := [PitchTypes.Type.FASTBALL]
	pitcher.pitch_executed.connect(func(t, _target, _acc):
		fired[0] = true
		emitted_type[0] = t
	)
	pitcher.request_pitch(PitchTypes.Type.CURVEBALL, Vector3(0.2, 0.7, 0.0), 0.85)
	assert_bool(fired[0]).is_true()
	assert_int(emitted_type[0]).is_equal(PitchTypes.Type.CURVEBALL)
	pitcher.queue_free()
