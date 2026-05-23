@tool
extends EditorScript

func _run() -> void:
	var theme := Theme.new()
	var inter := load("res://themes/fonts/inter_tight_regular.ttf") as Font
	theme.default_font = inter
	theme.default_font_size = 14

	# Label defaults
	theme.set_color("font_color", "Label", Color("#f3f5fb"))

	# Panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#141a2c")
	panel_style.border_color = Color("#2a3349")
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# Button base
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#1c2338")
	btn_style.border_color = Color("#2a3349")
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	theme.set_stylebox("normal", "Button", btn_style)
	theme.set_color("font_color", "Button", Color("#f3f5fb"))

	ResourceSaver.save(theme, "res://themes/dngrz_theme.tres")
	print("Theme saved to res://themes/dngrz_theme.tres")
