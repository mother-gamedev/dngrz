class_name TestPitcherController extends GdUnitTestSuite

const PITCHER_SCENE := preload("res://scenes/pitcher.tscn")

func test_request_pitch_emits_pitch_command() -> void:
	var p := PITCHER_SCENE.instantiate()
	add_child(p)
	await get_tree().process_frame
	var captured := [null]
	p.pitch_committed.connect(func(cmd: PitchCommand) -> void: captured[0] = cmd)
	p.request_pitch(PitchTypes.Type.SLIDER, Vector3(0.1, 0.6, 0.0), 0.75)
	assert_object(captured[0]).is_not_null()
	var cmd: PitchCommand = captured[0]
	assert_int(cmd.type).is_equal(PitchTypes.Type.SLIDER)
	assert_vector(cmd.target).is_equal(Vector3(0.1, 0.6, 0.0))
	assert_float(cmd.accuracy).is_equal_approx(0.75, 0.0001)
	p.queue_free()
