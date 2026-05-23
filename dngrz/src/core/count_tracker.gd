class_name CountTracker

signal walk
signal strikeout
signal out_recorded
signal side_retired

var balls: int = 0
var strikes: int = 0
var outs: int = 0

func add_ball() -> void:
	balls += 1
	if balls >= 4:
		walk.emit()

# On the 3rd strike, this self-records the out via add_out().
# Callers must not also call add_out() to avoid double-counting.
func add_strike() -> void:
	strikes += 1
	if strikes >= 3:
		add_out()
		strikeout.emit()

func add_foul() -> void:
	if strikes < 2:
		strikes += 1

func add_out() -> void:
	outs += 1
	out_recorded.emit()
	if outs >= 3:
		side_retired.emit()

func is_walk() -> bool:
	return balls >= 4

func is_strikeout() -> bool:
	return strikes >= 3

func is_side_retired() -> bool:
	return outs >= 3

func new_batter() -> void:
	balls = 0
	strikes = 0

func new_half_inning() -> void:
	balls = 0
	strikes = 0
	outs = 0
