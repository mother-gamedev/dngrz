class_name InningManager

signal half_inning_changed
signal run_scored(team: String)
signal game_over_signal

const TOTAL_INNINGS := 5

var inning: int = 1
var is_top: bool = true
var home_score: int = 0
var away_score: int = 0

func batting_team() -> String:
	return "away" if is_top else "home"

func fielding_team() -> String:
	return "home" if is_top else "away"

func add_run() -> void:
	if is_top:
		away_score += 1
		run_scored.emit("away")
	else:
		home_score += 1
		run_scored.emit("home")

func advance_half_inning() -> void:
	if is_top:
		is_top = false
	else:
		is_top = true
		inning += 1
	half_inning_changed.emit()

func is_game_over() -> bool:
	# Game ends after 5 full innings
	if inning > TOTAL_INNINGS:
		return true
	# Walk-off: bottom of last inning, home takes the lead
	if inning == TOTAL_INNINGS and not is_top and home_score > away_score:
		return true
	return false

func get_inning_display() -> String:
	var half := "Top" if is_top else "Bot"
	return "%s %d" % [half, inning]
