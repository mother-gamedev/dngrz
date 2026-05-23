class_name PhaseIndicator extends PanelContainer

enum Phase { SETUP, PITCH, PLAY, RESOLVE }

const PHASE_NAMES := {
	Phase.SETUP: "SETUP",
	Phase.PITCH: "PITCH",
	Phase.PLAY: "PLAY",
	Phase.RESOLVE: "RESOLVE",
}

@export var current: Phase = Phase.PITCH:
	set(v):
		current = v
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	($V/Current as Label).text = PHASE_NAMES[current]
	for i in 4:
		var dot := get_node("V/Crumbs/Dot%d" % i) as ColorRect
		dot.color = Colors.BRAND if i == current else Colors.BORDER
