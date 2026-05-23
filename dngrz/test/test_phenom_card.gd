class_name TestPhenomCard extends GdUnitTestSuite

const CARD_SCENE := preload("res://scenes/ui/phenom_card.tscn")

func test_card_loads() -> void:
	var card := CARD_SCENE.instantiate()
	assert_object(card).is_not_null()
	card.queue_free()

func test_md_size_default() -> void:
	var card := CARD_SCENE.instantiate()
	add_child(card)
	await get_tree().process_frame
	assert_float(card.size.x).is_equal_approx(150.0, 1.0)
	assert_float(card.size.y).is_equal_approx(210.0, 1.0)
	card.queue_free()

func test_sm_size() -> void:
	var card := CARD_SCENE.instantiate()
	card.size_variant = card.SizeVariant.SM
	add_child(card)
	await get_tree().process_frame
	assert_float(card.size.x).is_equal_approx(100.0, 1.0)
	assert_float(card.size.y).is_equal_approx(140.0, 1.0)
	card.queue_free()

func test_lg_size() -> void:
	var card := CARD_SCENE.instantiate()
	card.size_variant = card.SizeVariant.LG
	add_child(card)
	await get_tree().process_frame
	assert_float(card.size.x).is_equal_approx(220.0, 1.0)
	assert_float(card.size.y).is_equal_approx(308.0, 1.0)
	card.queue_free()

func test_initials_displayed() -> void:
	var card := CARD_SCENE.instantiate()
	card.initials = "XY"
	add_child(card)
	await get_tree().process_frame
	var label := card.get_node("Portrait/Initials") as Label
	assert_str(label.text).is_equal("XY")
	card.queue_free()

func test_faction_color_applied_to_header() -> void:
	var card := CARD_SCENE.instantiate()
	card.faction = Colors.Faction.EMBER
	add_child(card)
	await get_tree().process_frame
	var header := card.get_node("Header") as Panel
	var sb := header.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(sb.bg_color.is_equal_approx(Colors.EMBER)).is_true()
	card.queue_free()
