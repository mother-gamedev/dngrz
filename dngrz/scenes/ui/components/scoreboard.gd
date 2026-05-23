class_name Scoreboard extends PanelContainer

@export var away_score: int = 0:
	set(v):
		away_score = v
		_refresh()
@export var home_score: int = 0:
	set(v):
		home_score = v
		_refresh()
@export var inning: int = 1:
	set(v):
		inning = v
		_refresh()
@export var is_top: bool = true:
	set(v):
		is_top = v
		_refresh()
@export var balls: int = 0:
	set(v):
		balls = v
		_refresh()
@export var strikes: int = 0:
	set(v):
		strikes = v
		_refresh()
@export var outs: int = 0:
	set(v):
		outs = v
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	($HBox/Away/Score as Label).text = str(away_score)
	($HBox/Home/Score as Label).text = str(home_score)
	($HBox/Center/Inning as Label).text = ("TOP" if is_top else "BOT") + " " + str(inning)
	($HBox/Center/Count as Label).text = "%d-%d  %d OUT" % [balls, strikes, outs]
