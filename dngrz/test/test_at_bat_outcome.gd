class_name TestAtBatOutcome extends GdUnitTestSuite

func test_defaults_to_take_ball() -> void:
	var o := AtBatOutcome.new()
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.TAKE_BALL)
	assert_object(o.contact).is_null()
	assert_object(o.batted_trajectory).is_null()

func test_stores_kind_and_geometry() -> void:
	var o := AtBatOutcome.new(AtBatOutcome.Kind.CONTACT, Vector3(0.1, 0.8, 0.0), 42)
	assert_int(o.kind).is_equal(AtBatOutcome.Kind.CONTACT)
	assert_vector(o.crossing_position).is_equal(Vector3(0.1, 0.8, 0.0))
	assert_int(o.crossing_tick).is_equal(42)

func test_can_hold_contact_and_trajectory() -> void:
	var o := AtBatOutcome.new(AtBatOutcome.Kind.CONTACT, Vector3.ZERO, 0)
	o.contact = ContactResolver.ContactResult.new()
	o.batted_trajectory = BallTrajectory.create_batted(Vector3(0, 1, 0), 40.0, 25.0, 0.0)
	assert_object(o.contact).is_not_null()
	assert_object(o.batted_trajectory).is_not_null()
