class_name MomentumBar extends PanelContainer

@export var value: float = 0.0:
	set(v):
		value = clampf(v, -100.0, 100.0)
		if is_inside_tree():
			queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(380, 56)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var bar_y := h / 2.0
	draw_rect(Rect2(0, bar_y - 4, w, 8), Colors.BG_CARD, true)
	draw_line(Vector2(w / 2, 0), Vector2(w / 2, h), Colors.BORDER_HI, 1.0)
	var needle_x := lerpf(0.0, w, (value + 100.0) / 200.0)
	draw_rect(Rect2(needle_x - 4, bar_y - 12, 8, 24), Colors.BRAND, true)
