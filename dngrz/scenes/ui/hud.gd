class_name HUD extends Control

const PHENOM_CARD := preload("res://scenes/ui/phenom_card.tscn")

@onready var scoreboard: Scoreboard = $TopBar/Scoreboard
@onready var phase: PhaseIndicator = $TopLeft/Phase
@onready var diamond: DiamondMini = $TopRight/Diamond
@onready var momentum: MomentumBar = $Bottom/Momentum
@onready var zones: ZoneList = $Bottom/Zones
@onready var clock_you: TacticalClock = $Bottom/Clocks/You
@onready var clock_opp: TacticalClock = $Bottom/Clocks/Opp

func _ready() -> void:
	var p := PHENOM_CARD.instantiate() as PhenomCard
	p.initials = "P1"
	p.phenom_name = "PLAYER 1"
	p.role = "PITCHER"
	p.faction = Colors.Faction.EMBER
	p.size_variant = PhenomCard.SizeVariant.MD
	$LeftEdge/PitcherCard.add_child(p)

	var b := PHENOM_CARD.instantiate() as PhenomCard
	b.initials = "P2"
	b.phenom_name = "PLAYER 2"
	b.role = "BATTER"
	b.faction = Colors.Faction.VOLT
	b.size_variant = PhenomCard.SizeVariant.MD
	$RightEdge/BatterCard.add_child(b)

# Public API — orchestrator drives these (Task 15 will wire signals to these methods)
func set_count(balls_n: int, strikes_n: int, outs_n: int) -> void:
	scoreboard.balls = balls_n
	scoreboard.strikes = strikes_n
	scoreboard.outs = outs_n

func set_score(away: int, home: int) -> void:
	scoreboard.away_score = away
	scoreboard.home_score = home

func set_inning(inning_n: int, is_top: bool) -> void:
	scoreboard.inning = inning_n
	scoreboard.is_top = is_top

func set_phase(p: PhaseIndicator.Phase) -> void:
	phase.current = p

func set_bases(first: bool, second: bool, third: bool) -> void:
	diamond.first = first
	diamond.second = second
	diamond.third = third
