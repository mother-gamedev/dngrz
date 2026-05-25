class_name TestBallStateAtTick extends GdUnitTestSuite

func test_stores_fields() -> void:
	var s := BallStateAtTick.new(42, Vector3(0.1, 0.8, 0.0), Vector3(0.0, 0.0, 40.0))
	assert_int(s.tick).is_equal(42)
	assert_vector(s.position).is_equal(Vector3(0.1, 0.8, 0.0))
	assert_vector(s.velocity).is_equal(Vector3(0.0, 0.0, 40.0))

func test_plate_point_projects_xy() -> void:
	var s := BallStateAtTick.new(0, Vector3(0.2, 0.9, -1.0), Vector3.ZERO)
	assert_vector(s.plate_point()).is_equal(Vector2(0.2, 0.9))

func test_round_trips_through_dict() -> void:
	var s := BallStateAtTick.new(7, Vector3(0.1, 0.8, 0.0), Vector3(1.0, 2.0, 3.0))
	var r := BallStateAtTick.from_dict(s.to_dict())
	assert_int(r.tick).is_equal(7)
	assert_vector(r.position).is_equal(Vector3(0.1, 0.8, 0.0))
	assert_vector(r.velocity).is_equal(Vector3(1.0, 2.0, 3.0))
