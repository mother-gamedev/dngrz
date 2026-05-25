class_name TestSwingInput extends GdUnitTestSuite

func test_defaults() -> void:
	var i := SwingInput.new()
	assert_vector(i.cursor).is_equal(Vector2.ZERO)
	assert_bool(i.commit_pressed).is_false()
	assert_vector(i.placement_dir).is_equal(Vector2.ZERO)

func test_stores_fields() -> void:
	var i := SwingInput.new(Vector2(0.1, 0.2), true, Vector2(-1.0, 0.5))
	assert_vector(i.cursor).is_equal(Vector2(0.1, 0.2))
	assert_bool(i.commit_pressed).is_true()
	assert_vector(i.placement_dir).is_equal(Vector2(-1.0, 0.5))
