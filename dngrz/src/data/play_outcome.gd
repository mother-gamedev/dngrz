class_name PlayOutcome

# Result of resolving a batted ball against a fielder snapshot (parent spec §3).
# v0 only branches out/hit, but carries the geometry a richer system needs so
# later fielding/baserunning consume it without changing the contract.
var is_out: bool
var landing_point: Vector3
var nearest_fielder: String
var reach_margin: float  # meters; >=0 = a fielder reached it (out), <0 = fell in a gap (hit)

func _init(p_is_out: bool = false, p_landing_point: Vector3 = Vector3.ZERO,
		p_nearest_fielder: String = "", p_reach_margin: float = 0.0) -> void:
	is_out = p_is_out
	landing_point = p_landing_point
	nearest_fielder = p_nearest_fielder
	reach_margin = p_reach_margin
