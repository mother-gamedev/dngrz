class_name BattingView extends Control

# Properties (orchestrator drives these — see Task 16)
@export var aim_position: Vector2 = Vector2.ZERO:
	set(v):
		aim_position = v
		queue_redraw()
@export var ball_positions_history: PackedVector2Array = PackedVector2Array():
	set(v):
		ball_positions_history = v
		queue_redraw()
@export var predicted_landing: Vector2 = Vector2.ZERO:  # OBSERVABLE predicted crossing (drifts with break) — never the true target
	set(v):
		predicted_landing = v
		queue_redraw()
@export var break_marker: Vector2 = Vector2.ZERO:
	set(v):
		break_marker = v
		queue_redraw()
@export var swing_timing: float = 0.0:  # -1..1, where 0 = perfect
	set(v):
		swing_timing = v
		queue_redraw()
@export var swing_locked: bool = false:
	set(v):
		swing_locked = v
		queue_redraw()
@export var pitch_progress: float = 0.0:  # 0 = just released, 1 = at the plate
	set(v):
		pitch_progress = v
		queue_redraw()

const ZONE_SIZE := Vector2(340, 440)
const TIMING_LABELS := ["EARLY", "EARLY+", "PERFECT", "LATE+", "LATE"]

func _ready() -> void:
	custom_minimum_size = Vector2(440, 680)

func _draw() -> void:
	var center_x := size.x / 2.0
	var zone_top := 32.0
	var zone_left := center_x - ZONE_SIZE.x / 2.0
	var zone_rect := Rect2(zone_left, zone_top, ZONE_SIZE.x, ZONE_SIZE.y)

	# Zone backdrop + dashed grid (3×3). Translucent so the 3D field and ball
	# show through the overlay instead of being hidden behind a solid panel.
	draw_rect(zone_rect, Color(Colors.BG_BASE.r, Colors.BG_BASE.g, Colors.BG_BASE.b, 0.45), true)
	draw_rect(zone_rect, Colors.CHALK, false, 2.0)
	for i in [1, 2]:
		var x := zone_left + ZONE_SIZE.x * float(i) / 3.0
		_draw_dashed_line(Vector2(x, zone_top), Vector2(x, zone_top + ZONE_SIZE.y), Colors.CHALK, 1.5)
		var yy := zone_top + ZONE_SIZE.y * float(i) / 3.0
		_draw_dashed_line(Vector2(zone_left, yy), Vector2(zone_left + ZONE_SIZE.x, yy), Colors.CHALK, 1.5)

	# Motion trail dots (last 4 ball positions, fading)
	for i in ball_positions_history.size():
		var p: Vector2 = ball_positions_history[i]
		var screen_p := _zone_to_screen(p, zone_rect)
		var alpha := float(i + 1) / float(maxi(1, ball_positions_history.size()))
		draw_circle(screen_p, 5.0, Color(Colors.COOL.r, Colors.COOL.g, Colors.COOL.b, alpha))

	# Predicted landing ring
	var landing_screen := _zone_to_screen(predicted_landing, zone_rect)
	draw_arc(landing_screen, 18.0, 0.0, TAU, 32, Colors.HEAT, 2.0)

	# Break-direction chevron — the honest in-flight read cue (spec §8). Drawn at
	# the predicted-landing anchor, pointing in the pitch's break direction.
	if break_marker.length() > 0.01:
		var anchor := _zone_to_screen(predicted_landing, zone_rect)
		var dir := Vector2(break_marker.x, -break_marker.y).normalized()  # +y = up in zone space
		var tip := anchor + dir * 26.0
		var wing := dir.rotated(2.5) * 12.0
		var wing2 := dir.rotated(-2.5) * 12.0
		draw_line(tip, tip + wing, Colors.HEAT, 3.0)
		draw_line(tip, tip + wing2, Colors.HEAT, 3.0)

	# Incoming ball — grows as it nears the plate so the pitch reads as coming
	# at you. It is full size when it arrives; swing as it fills the ring.
	if pitch_progress > 0.0 and pitch_progress < 1.0:
		var incoming := _zone_to_screen(predicted_landing, zone_rect)
		var r := lerpf(4.0, 24.0, pitch_progress)
		draw_circle(incoming, r, Color(Colors.CHALK.r, Colors.CHALK.g, Colors.CHALK.b, 0.95))
		draw_arc(incoming, r + 2.0, 0.0, TAU, 24, Colors.BRAND, 2.0)

	# Aim cursor
	var aim_screen := _zone_to_screen(aim_position, zone_rect)
	draw_circle(aim_screen, 8.0, Colors.BRAND)
	draw_arc(aim_screen, 14.0, 0.0, TAU, 32, Colors.BRAND_HOT, 1.5)

	# Timing meter (below zone)
	_draw_timing_meter(center_x, zone_top + ZONE_SIZE.y + 32.0)

func _draw_timing_meter(center_x: float, y: float) -> void:
	var seg_w := 60.0
	var seg_h := 28.0
	var total_w := seg_w * 5
	var start_x := center_x - total_w / 2.0
	for i in 5:
		var x := start_x + i * seg_w
		var rect := Rect2(x, y, seg_w, seg_h)
		var seg_color: Color
		match i:
			0, 4: seg_color = Colors.HEAT
			1, 3: seg_color = Colors.BRAND_HOT
			_: seg_color = Colors.BRAND
		draw_rect(rect, seg_color.darkened(0.6), true)
		draw_rect(rect, Colors.BORDER_HI, false, 1.0)
		_draw_centered_text(TIMING_LABELS[i], Vector2(x + seg_w / 2.0, y + seg_h / 2.0), Colors.TEXT, 10)

	# Needle
	var needle_pos := lerpf(start_x, start_x + total_w, (clampf(swing_timing, -1.0, 1.0) + 1.0) / 2.0)
	var needle_color := Colors.CHALK if not swing_locked else Colors.BRAND
	draw_line(Vector2(needle_pos, y - 6), Vector2(needle_pos, y + seg_h + 6), needle_color, 3.0)

func _zone_to_screen(zone_pos: Vector2, zone_rect: Rect2) -> Vector2:
	var clamped := Vector2(clampf(zone_pos.x, -1.0, 1.0), clampf(zone_pos.y, -1.0, 1.0))
	# Zone data uses +Y = high; screen Y is +down, so negate Y for display.
	return zone_rect.get_center() + Vector2(clamped.x, -clamped.y) * (zone_rect.size * 0.5)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float = 6.0, gap_len: float = 4.0) -> void:
	var diff := to - from
	var dist := diff.length()
	if dist < 0.01:
		return
	var dir := diff / dist
	var pos := 0.0
	while pos < dist:
		var seg_end := minf(pos + dash_len, dist)
		draw_line(from + dir * pos, from + dir * seg_end, color, width)
		pos = seg_end + gap_len

func _draw_centered_text(text: String, center: Vector2, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size * 0.5 + Vector2(0, text_size.y * 0.4), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
