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

# Shrunk from 280x360 + the whole Control shrunk from 380x600 — the prior HUD was
# blocking the 3D view of the plate. Translucent backdrop now also lets the field
# read through. (Feel-test #2 FAIL signal "too prominent / blocks the view".)
const ZONE_SIZE := Vector2(180, 230)
const SELECTOR_LABELS := ["FB", "CB", "SL", "CH"]
# Display the release meter from charge 0 .. 1.3 so the over-hold zone past 1.0 is
# visible — anything past 1.3 just pegs the bar. 1.3 = the "fully bled to meatball"
# point per PitcherController.OVERHOLD_ACC_SPAN.
const METER_DISPLAY_RANGE := 1.3

func _ready() -> void:
	custom_minimum_size = Vector2(300, 420)

func _draw() -> void:
	var center_x := size.x / 2.0

	# --- Pitch-type selector — 4 horizontal chips ---
	var slot_w := 44.0
	var slot_h := 26.0
	var gap := 6.0
	var total_w := slot_w * 4 + gap * 3
	var start_x := center_x - total_w / 2.0
	var sel_y := 8.0
	for i in 4:
		var x := start_x + i * (slot_w + gap)
		var rect := Rect2(x, sel_y, slot_w, slot_h)
		var is_selected := i == selected_pitch
		draw_rect(rect, Colors.BRAND if is_selected else Colors.BG_CARD, true)
		draw_rect(rect, Colors.BORDER_HI, false, 1.0)
		var text_color := Colors.BG_DEEP if is_selected else Colors.TEXT
		_draw_centered_text(SELECTOR_LABELS[i], Vector2(x + slot_w / 2.0, sel_y + slot_h / 2.0), text_color, 14)

	# --- Strike zone (3x3 dashed; translucent backdrop) ---
	var zone_top := sel_y + slot_h + 24.0
	var zone_left := center_x - ZONE_SIZE.x / 2.0
	var zone_rect := Rect2(zone_left, zone_top, ZONE_SIZE.x, ZONE_SIZE.y)
	draw_rect(zone_rect, Color(Colors.BG_BASE.r, Colors.BG_BASE.g, Colors.BG_BASE.b, 0.30), true)
	draw_rect(zone_rect, Colors.CHALK, false, 1.5)
	for i in [1, 2]:
		var vx := zone_left + ZONE_SIZE.x * float(i) / 3.0
		_draw_dashed_line(Vector2(vx, zone_top), Vector2(vx, zone_top + ZONE_SIZE.y), Colors.CHALK, 1.0)
		var hy := zone_top + ZONE_SIZE.y * float(i) / 3.0
		_draw_dashed_line(Vector2(zone_left, hy), Vector2(zone_left + ZONE_SIZE.x, hy), Colors.CHALK, 1.0)

	# --- Aim cursor + bend arrow inside the zone ---
	var zone_center := zone_rect.get_center()
	var cursor_pos := zone_center + Vector2(aim_position.x, -aim_position.y) * (ZONE_SIZE * 0.5)
	var accuracy_ring_radius := 18.0 / clampf(accuracy, 0.05, 1.0)
	draw_arc(cursor_pos, accuracy_ring_radius, 0.0, TAU, 32, Colors.BRAND_HOT, 1.2)
	draw_circle(cursor_pos, 6.0, Colors.BRAND)
	if bend.length() > 0.001:
		var bend_screen := Vector2(bend.x, -bend.y) / PitcherController.BEND_MAX * (ZONE_SIZE * 0.4)
		draw_line(cursor_pos, cursor_pos + bend_screen, Colors.BRAND_HOT, 2.0)
		draw_circle(cursor_pos + bend_screen, 3.5, Colors.BRAND_HOT)

	# --- Release meter (horizontal) ---
	# Layout left-to-right: charge fill grows right; perfect-release band highlighted
	# near the right edge of the legitimate (0..1) zone; over-hold (1..1.3) shown past
	# it with red tint. Fill color shifts by zone so a glance tells you safe/perfect/over.
	var meter_w := minf(size.x - 24.0, 300.0)
	var meter_h := 28.0
	var meter_x := center_x - meter_w / 2.0
	var meter_y := zone_top + ZONE_SIZE.y + 36.0
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Colors.BG_CARD, true)
	# over-hold backdrop
	var overhold_x := meter_x + meter_w * (1.0 / METER_DISPLAY_RANGE)
	var overhold_w := meter_x + meter_w - overhold_x
	draw_rect(Rect2(overhold_x, meter_y, overhold_w, meter_h),
		Color(Colors.HEAT.r, Colors.HEAT.g, Colors.HEAT.b, 0.18), true)
	# perfect band — brightens when fill is inside ("now release!" cue without a pulse)
	var perfect_lo := 1.0 - PitcherController.PERFECT_BAND
	var perfect_x := meter_x + meter_w * (perfect_lo / METER_DISPLAY_RANGE)
	var perfect_w := meter_w * (PitcherController.PERFECT_BAND / METER_DISPLAY_RANGE)
	var in_band := release_charge >= perfect_lo and release_charge <= 1.0
	var band_alpha := 0.95 if in_band else 0.40
	draw_rect(Rect2(perfect_x, meter_y, perfect_w, meter_h),
		Color(Colors.BRAND_HOT.r, Colors.BRAND_HOT.g, Colors.BRAND_HOT.b, band_alpha), true)
	# fill — color shifts by zone
	var clamped_charge := clampf(release_charge, 0.0, METER_DISPLAY_RANGE)
	var fill_w := meter_w * (clamped_charge / METER_DISPLAY_RANGE)
	var fill_color: Color
	if release_charge > 1.0:
		fill_color = Colors.HEAT
	elif release_charge >= perfect_lo:
		fill_color = Colors.BRAND_HOT
	else:
		fill_color = Colors.BRAND
	draw_rect(Rect2(meter_x, meter_y, fill_w, meter_h), fill_color, true)
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Colors.BORDER_HI, false, 1.5)
	# tick at charge 1.0 (boundary between legit ramp and over-hold)
	var tick_x := meter_x + meter_w * (1.0 / METER_DISPLAY_RANGE)
	draw_line(Vector2(tick_x, meter_y - 3.0), Vector2(tick_x, meter_y + meter_h + 3.0), Colors.CHALK, 1.5)
	# state cue text below the bar
	if in_band:
		_draw_centered_text("RELEASE!", Vector2(center_x, meter_y + meter_h + 18.0), Colors.BRAND_HOT, 18)
	elif release_charge > 1.0:
		_draw_centered_text("OVER-HELD", Vector2(center_x, meter_y + meter_h + 18.0), Colors.HEAT, 16)

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
