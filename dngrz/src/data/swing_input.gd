class_name SwingInput

# A per-tick input snapshot consumed by the BatterController swing FSM. Both the
# human input sampler (BatterInput) and the AI produce this, so the FSM has one
# code path. Carries no node state.
var cursor: Vector2          # live per-tick cursor aim (normalized plate space)
var commit_pressed: bool     # is the swing button held this tick?
var placement_dir: Vector2   # directional intent to latch at the commit instant

func _init(p_cursor: Vector2 = Vector2.ZERO, p_commit: bool = false, p_placement: Vector2 = Vector2.ZERO) -> void:
	cursor = p_cursor
	commit_pressed = p_commit
	placement_dir = p_placement
