class_name ZoneList extends PanelContainer

func _ready() -> void:
	if not has_node("V"):
		return
	var v := $V as VBoxContainer
	if v.get_child_count() <= 1:  # only the header label
		for i in 4:
			var row := HBoxContainer.new()
			var icon := ColorRect.new()
			icon.custom_minimum_size = Vector2(10, 10)
			icon.color = Colors.BORDER
			row.add_child(icon)
			var label := Label.new()
			label.text = "—"
			label.add_theme_color_override("font_color", Colors.TEXT_MUTE)
			row.add_child(label)
			v.add_child(row)
