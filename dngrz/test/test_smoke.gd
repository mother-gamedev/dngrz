class_name TestSmoke extends GdUnitTestSuite

func test_godot_is_running() -> void:
	assert_bool(true).is_true()
