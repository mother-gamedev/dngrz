class_name ChamferedButton extends Button

@export var notch_px: float = 10.0
@export var fill_color: Color = Color("#FFCC00")
@export var hover_color: Color = Color("#FFB400")

var _polygon: Polygon2D
var _hovered := false

func _ready() -> void:
	flat = true
	_polygon = Polygon2D.new()
	add_child(_polygon)
	move_child(_polygon, 0)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	resized.connect(_update_polygon)
	_update_polygon()

func _on_hover_changed(h: bool) -> void:
	_hovered = h
	_update_polygon()

func _update_polygon() -> void:
	if _polygon == null: return
	var w := size.x
	var h := size.y
	var n := minf(notch_px, w * 0.5)
	_polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(w - n, 0),
		Vector2(w, n),
		Vector2(w, h),
		Vector2(0, h),
	])
	_polygon.color = hover_color if _hovered else fill_color
