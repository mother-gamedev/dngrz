class_name SimClock

# Fixed-tick simulation clock (determinism contract #4). Gameplay time is
# measured in integer ticks, never wall-clock seconds. Presentation may
# interpolate between ticks; resolution never does. The advancing tick counter
# that drives the at-bat lives in AtBatDirector (Plan 2) — this module is just
# the rate constant and the conversions, so both single-player and the future
# server agree on the same integer time base.
const TICK_RATE := 60  # ticks per second

# Seconds for a tick count — for human-facing tuning values only.
static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / float(TICK_RATE)

# Nearest whole tick for a duration in seconds.
static func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * float(TICK_RATE)))
