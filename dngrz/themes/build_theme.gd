@tool
extends EditorScript

# WARNING: Running this script overwrites res://themes/dngrz_theme.tres.
# Any hand-edits to the .tres (e.g., added Button/hover or Button/pressed
# styleboxes, custom corner radii) will be lost. Update this script to match
# the .tres before re-running, or write to a sibling _generated.tres and
# manually diff.
#
# This script is the canonical *generator*, not the canonical *artifact*.
# The .tres on disk is what the project actually loads.

const ColorsModule := preload("res://themes/colors.gd")

func _run() -> void:
	var theme := Theme.new()
	var inter := load("res://themes/fonts/inter_tight_regular.ttf") as Font
	assert(inter != null, "Inter Tight font failed to load")
	theme.default_font = inter
	theme.default_font_size = 14

	# Label defaults
	theme.set_color("font_color", "Label", ColorsModule.TEXT)

	# Panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ColorsModule.BG_SURFACE
	panel_style.border_color = ColorsModule.BORDER
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# Button base
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ColorsModule.BG_CARD
	btn_style.border_color = ColorsModule.BORDER
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	theme.set_stylebox("normal", "Button", btn_style)
	theme.set_color("font_color", "Button", ColorsModule.TEXT)

	ResourceSaver.save(theme, "res://themes/dngrz_theme.tres")
	print("Theme saved to res://themes/dngrz_theme.tres")
