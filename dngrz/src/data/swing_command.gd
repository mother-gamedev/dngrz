class_name SwingCommand

# A committed swing, snapshotted at the commit tick (spec §5, contract #1).
# Serializable, tick-stamped, carries no node state. The swing FSM (Plan 2)
# produces it from input; ContactResolver consumes it. Both the human and the
# AI batter emit this same struct — there is exactly one commit path.
enum SwingType {
	CONTACT,  # tap: larger effective contact zone, less power
	POWER,    # hold: contact zone shrinks, more power
}

var cursor_point: Vector2   # normalized plate-space aim, latched at commit (StrikeZone
                            #   space: (0,0)=center, ±1=edge). The MSSB cursor — ContactResolver
                            #   grades contact quality by its distance to the ball (spec §3).
var swing_type: SwingType
var placement_dir: Vector2  # DEAD (Plan 3a): spray/launch now derive from cursor position;
                            #   retained as an inert vestige for serialization. Emit ZERO.
var commit_tick: int        # the tick the swing button went DOWN — the timing reference (spec §5 latch rule)

func _init(
		p_cursor: Vector2 = Vector2.ZERO,
		p_swing_type: SwingType = SwingType.CONTACT,
		p_placement: Vector2 = Vector2.ZERO,
		p_commit_tick: int = 0) -> void:
	cursor_point = p_cursor
	swing_type = p_swing_type
	placement_dir = p_placement
	commit_tick = p_commit_tick

func to_dict() -> Dictionary:
	return {
		"cursor_point": cursor_point,
		"swing_type": int(swing_type),
		"placement_dir": placement_dir,
		"commit_tick": commit_tick,
	}

static func from_dict(d: Dictionary) -> SwingCommand:
	return SwingCommand.new(d["cursor_point"], d["swing_type"], d["placement_dir"], d["commit_tick"])
