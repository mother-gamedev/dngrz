class_name AtBatView

# The single read-only view-model the views pull each frame (parent spec §6 —
# views pull, the director doesn't push). Carries current AND previous ball
# state so presentation can interpolate between physics ticks.
var phase: int = 0
var ball_state: BallStateAtTick = null
var prev_ball_state: BallStateAtTick = null
var break_marker: Vector2 = Vector2.ZERO
var observable_landing: Vector2 = Vector2.ZERO   # where the pitch LOOKS like it'll cross (drifts with break)
var swing_timing: float = 0.0                    # -1..1 timing needle, 0 = PERFECT (commit at the crossing tick)
var swing_locked: bool = false
var last_play: PlayOutcome = null
