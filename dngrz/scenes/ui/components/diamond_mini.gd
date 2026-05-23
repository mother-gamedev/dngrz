class_name DiamondMini extends Control

@export var first: bool = false:
	set(v):
		first = v
		queue_redraw()
@export var second: bool = false:
	set(v):
		second = v
		queue_redraw()
@export var third: bool = false:
	set(v):
		third = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.5
	var home := c + Vector2(0, r)
	var first_b := c + Vector2(r, 0)
	var second_b := c - Vector2(0, r)
	var third_b := c - Vector2(r, 0)

	draw_line(home, first_b, Colors.BORDER_HI, 2.0)
	draw_line(first_b, second_b, Colors.BORDER_HI, 2.0)
	draw_line(second_b, third_b, Colors.BORDER_HI, 2.0)
	draw_line(third_b, home, Colors.BORDER_HI, 2.0)

	_draw_base(home, 10.0, false, Colors.CHALK)
	_draw_base(first_b, 10.0, first, Colors.BRAND)
	_draw_base(second_b, 10.0, second, Colors.BRAND)
	_draw_base(third_b, 10.0, third, Colors.BRAND)

func _draw_base(pos: Vector2, s: float, occupied: bool, fill: Color) -> void:
	var rect := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
	if occupied:
		draw_rect(rect, fill, true)
	else:
		draw_rect(rect, Colors.BG_CARD, true)
		draw_rect(rect, Colors.BORDER_HI, false, 1.5)
