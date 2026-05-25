class_name TestSwingCommand extends GdUnitTestSuite

func test_defaults_to_contact_up_the_middle() -> void:
	var c := SwingCommand.new()
	assert_int(c.swing_type).is_equal(SwingCommand.SwingType.CONTACT)
	assert_vector(c.placement_dir).is_equal(Vector2.ZERO)
	assert_int(c.commit_tick).is_equal(0)

func test_stores_power_swing() -> void:
	var c := SwingCommand.new(Vector2(0.1, 0.8), SwingCommand.SwingType.POWER, Vector2(0.5, -0.5), 120)
	assert_int(c.swing_type).is_equal(SwingCommand.SwingType.POWER)
	assert_int(c.commit_tick).is_equal(120)
	assert_vector(c.cursor_point).is_equal(Vector2(0.1, 0.8))

func test_round_trips_through_dict() -> void:
	var c := SwingCommand.new(Vector2(0.1, 0.8), SwingCommand.SwingType.POWER, Vector2(0.5, -0.5), 120)
	var r := SwingCommand.from_dict(c.to_dict())
	assert_vector(r.cursor_point).is_equal(Vector2(0.1, 0.8))
	assert_int(r.swing_type).is_equal(SwingCommand.SwingType.POWER)
	assert_vector(r.placement_dir).is_equal(Vector2(0.5, -0.5))
	assert_int(r.commit_tick).is_equal(120)
