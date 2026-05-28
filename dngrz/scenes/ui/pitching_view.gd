class_name PitchingView extends Control

@export var selected_pitch: PitchTypes.Type = PitchTypes.Type.FASTBALL:
	set(v):
		selected_pitch = v
		queue_redraw()
@export var aim_position: Vector2 = Vector2.ZERO:
	set(v):
		aim_position = v
		queue_redraw()
@export var accuracy: float = 1.0:
	set(v):
		accuracy = v
		queue_redraw()
@export var release_charge: float = 0.0:
	set(v):
		release_charge = v
		queue_redraw()
@export var bend: Vector2 = Vector2.ZERO:  # plate-plane metres; live release-time bend
	set(v):
		bend = v
		queue_redraw()

const ZONE_SIZE := Vector2(280, 360)
const SELECTOR_LABELS := ["FB", "CB", "SL", "CH"]
const SELECTOR_BINDINGS := ["1", "2", "3", "4"]

func _ready() -> void:
	custom_minimum_size = Vector2(380, 600)

func _draw() -> void:
	var center_x := size.x / 2.0

	# Pitch type selector — 4 horizontal slots near the top
	var slot_w := 60.0
	var slot_h := 36.0
	var gap := 8.0
	var total_w := slot_w * 4 + gap * 3
	var start_x := center_x - total_w / 2.0
	var y := 16.0
	for i in 4:
		var x := start_x + i * (slot_w + gap)
		var rect := Rect2(x, y, slot_w, slot_h)
		var is_selected := i == selected_pitch
		draw_rect(rect, Colors.BRAND if is_selected else Colors.BG_CARD, true)
		draw_rect(rect, Colors.BORDER_HI, false, 1.5)
		var text_color := Colors.BG_DEEP if is_selected else Colors.TEXT
		_draw_centered_text(SELECTOR_LABELS[i], Vector2(x + slot_w / 2.0, y + slot_h / 2.0), text_color, 18)
		_draw_centered_text(SELECTOR_BINDINGS[i], Vector2(x + slot_w / 2.0, y + slot_h + 12), Colors.TEXT_DIM, 11)

	# Zone overlay (3×3 dashed)
	var zone_top := y + slot_h + 48.0
	var zone_left := center_x - ZONE_SIZE.x / 2.0
	var zone_rect := Rect2(zone_left, zone_top, ZONE_SIZE.x, ZONE_SIZE.y)
	draw_rect(zone_rect, Colors.CHALK, false, 2.0)
	# Vertical lines
	for i in [1, 2]:
		var x := zone_left + ZONE_SIZE.x * float(i) / 3.0
		_draw_dashed_line(Vector2(x, zone_top), Vector2(x, zone_top + ZONE_SIZE.y), Colors.CHALK, 1.5)
	# Horizontal lines
	for i in [1, 2]:
		var yy := zone_top + ZONE_SIZE.y * float(i) / 3.0
		_draw_dashed_line(Vector2(zone_left, yy), Vector2(zone_left + ZONE_SIZE.x, yy), Colors.CHALK, 1.5)

	# Aim cursor inside zone.
	# aim_position uses +Y = high (world/strike-zone convention); screen Y is
	# +down, so negate Y here to render a high pitch toward the top of the zone.
	var zone_center := zone_rect.get_center()
	var cursor_pos := zone_center + Vector2(aim_position.x, -aim_position.y) * (ZONE_SIZE * 0.5)
	var accuracy_ring_radius := 24.0 / clampf(accuracy, 0.05, 1.0)
	draw_arc(cursor_pos, accuracy_ring_radius, 0.0, TAU, 32, Colors.BRAND_HOT, 1.5)
	draw_circle(cursor_pos, 8.0, Colors.BRAND)
	# Bend arrow: where the late break will pull the ball (plate convention: +y up,
	# so negate y for screen). Scaled by BEND_MAX so a full-stick bend reads clearly.
	if bend.length() > 0.001:
		var bend_screen := Vector2(bend.x, -bend.y) / PitcherController.BEND_MAX * (ZONE_SIZE * 0.4)
		draw_line(cursor_pos, cursor_pos + bend_screen, Colors.BRAND_HOT, 2.0)
		draw_circle(cursor_pos + bend_screen, 4.0, Colors.BRAND_HOT)

	# Release meter
	var meter_y := zone_top + ZONE_SIZE.y + 24.0
	var meter_w := 12.0
	var meter_h := 100.0
	var meter_x := center_x - meter_w / 2.0
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Colors.BG_CARD, true)
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Colors.BORDER_HI, false, 1.0)
	var fill_h := meter_h * clampf(release_charge, 0.0, 1.0)
	draw_rect(Rect2(meter_x, meter_y + meter_h - fill_h, meter_w, fill_h), Colors.BRAND, true)
	# Perfect-release window: the band at the top of the meter where max power + the
	# accuracy bonus live (spec §4.2). Release inside it, before over-holding.
	var band_h := meter_h * PitcherController.PERFECT_BAND
	draw_rect(Rect2(meter_x - 3.0, meter_y, meter_w + 6.0, band_h), Colors.BRAND_HOT, false, 2.0)

func _draw_centered_text(text: String, center: Vector2, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size * 0.5 + Vector2(0, text_size.y * 0.4), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float = 6.0, gap_len: float = 4.0) -> void:
	var diff := to - from
	var dist := diff.length()
	if dist < 0.01: return
	var dir := diff / dist
	var pos := 0.0
	while pos < dist:
		var seg_end := minf(pos + dash_len, dist)
		draw_line(from + dir * pos, from + dir * seg_end, color, width)
		pos = seg_end + gap_len
