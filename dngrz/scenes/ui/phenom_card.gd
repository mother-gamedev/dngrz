class_name PhenomCard extends Control

enum SizeVariant { SM, MD, LG }

const SIZES := {
	SizeVariant.SM: Vector2(100, 140),
	SizeVariant.MD: Vector2(150, 210),
	SizeVariant.LG: Vector2(220, 308),
}

const INITIAL_FONT_SIZES := {
	SizeVariant.SM: 22,
	SizeVariant.MD: 36,
	SizeVariant.LG: 56,
}

const _ARCHIVO := preload("res://themes/fonts/archivo_black.ttf")
const _MONO := preload("res://themes/fonts/jetbrains_mono_regular.ttf")

@export var size_variant: SizeVariant = SizeVariant.MD:
	set(v):
		size_variant = v
		if is_inside_tree(): _apply()
@export var faction: Colors.Faction = Colors.Faction.EMBER:
	set(v):
		faction = v
		if is_inside_tree(): _apply()
@export var phenom_name: String = "P1":
	set(v):
		phenom_name = v
		if is_inside_tree(): _apply()
@export var initials: String = "P1":
	set(v):
		initials = v
		if is_inside_tree(): _apply()
@export var role: String = "":
	set(v):
		role = v
		if is_inside_tree(): _apply()
@export var positions: String = "":
	set(v):
		positions = v
		if is_inside_tree(): _apply()
@export var stats_line: String = "":
	set(v):
		stats_line = v
		if is_inside_tree(): _apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	var dims: Vector2 = SIZES[size_variant]
	custom_minimum_size = dims
	size = dims

	var faction_col := Colors.faction_color(faction)
	var faction_deep_col := Colors.faction_deep(faction)

	# Header
	var header := $Header as Panel
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = faction_col
	header.add_theme_stylebox_override("panel", header_sb)
	($Header/Glyph as Label).text = Colors.faction_glyph(faction)
	($Header/Role as Label).text = role.to_upper()

	# Portrait — radial faction tint approximation
	var portrait_sb := StyleBoxFlat.new()
	portrait_sb.bg_color = faction_deep_col
	($Portrait as Panel).add_theme_stylebox_override("panel", portrait_sb)
	var initials_label := $Portrait/Initials as Label
	initials_label.text = initials
	initials_label.add_theme_font_size_override("font_size", INITIAL_FONT_SIZES[size_variant])
	initials_label.add_theme_font_override("font", _ARCHIVO)

	# Name
	var name_sb := StyleBoxFlat.new()
	name_sb.bg_color = Colors.BG_CARD
	($NameLockup as Panel).add_theme_stylebox_override("panel", name_sb)
	($NameLockup/Name as Label).text = phenom_name
	($NameLockup/Name as Label).add_theme_font_override("font", _ARCHIVO)

	# Stats
	var stats_sb := StyleBoxFlat.new()
	stats_sb.bg_color = Colors.BG_CARD_HI
	($Stats as Panel).add_theme_stylebox_override("panel", stats_sb)
	($Stats/Positions as Label).text = positions
	($Stats/StatsLine as Label).text = stats_line
	($Stats/Positions as Label).add_theme_font_override("font", _MONO)
	($Stats/StatsLine as Label).add_theme_font_override("font", _MONO)
