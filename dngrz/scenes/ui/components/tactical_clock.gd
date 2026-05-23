class_name TacticalClock extends PanelContainer

@export var label_text: String = "YOU":
	set(v):
		label_text = v
		_refresh()
@export var seconds: float = -1.0:
	set(v):
		seconds = v
		_refresh()
@export var warning: bool = false:
	set(v):
		warning = v
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	($V/Label as Label).text = label_text
	if seconds < 0.0:
		($V/Time as Label).text = "—"
		($V/Time as Label).add_theme_color_override("font_color", Colors.TEXT_MUTE)
	else:
		var m := int(seconds) / 60
		var s := int(seconds) % 60
		($V/Time as Label).text = "%d:%02d" % [m, s]
		var col := Colors.HEAT if warning else Colors.TEXT
		($V/Time as Label).add_theme_color_override("font_color", col)
