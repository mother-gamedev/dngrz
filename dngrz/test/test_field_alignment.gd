class_name TestFieldAlignment extends GdUnitTestSuite

func test_stores_positions() -> void:
	var a := FieldAlignment.new({"shortstop": Vector3(-5, 0, -28)})
	assert_vector(a.positions["shortstop"]).is_equal(Vector3(-5, 0, -28))

func test_default_has_non_battery_fielders() -> void:
	var a := FieldAlignment.default()
	# 4 infield + 3 outfield = 7; pitcher and catcher are excluded (they don't field batted balls in v0).
	assert_int(a.positions.size()).is_equal(7)
	assert_bool(a.positions.has("shortstop")).is_true()
	assert_bool(a.positions.has("center_field")).is_true()
	assert_bool(a.positions.has("pitcher")).is_false()
	assert_bool(a.positions.has("catcher")).is_false()

func test_default_positions_match_field_constants() -> void:
	var a := FieldAlignment.default()
	assert_vector(a.positions["shortstop"]).is_equal(FieldConstants.FIELDER_POSITIONS["shortstop"])
