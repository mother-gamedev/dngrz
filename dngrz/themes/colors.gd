extends Node
# Colors from design handoff /home/cner/Downloads/design_handoff_dngrz_ui/README.md
# DO NOT change these without updating the design handoff first.

# Surfaces
const BG_DEEP    := Color("#070912")
const BG_BASE    := Color("#0d1220")
const BG_SURFACE := Color("#141a2c")
const BG_CARD    := Color("#1c2338")
const BG_CARD_HI := Color("#252e48")
const BORDER     := Color("#2a3349")
const BORDER_HI  := Color("#3a4566")

# Text
const TEXT      := Color("#f3f5fb")
const TEXT_DIM  := Color("#8b95ad")
const TEXT_MUTE := Color("#525c75")
const CHALK     := Color("#e8ecf3")

# Signal
const BRAND     := Color("#FFCC00")
const BRAND_HOT := Color("#FFB400")
const HEAT      := Color("#FF3D57")
const COOL      := Color("#2CD0FF")

# Field
const TURF      := Color("#1d4a2d")
const TURF_DARK := Color("#163a23")
const DIRT      := Color("#8a5a2b")

# Factions
const EMBER         := Color("#FF5B3D")
const EMBER_DEEP    := Color("#5a1d10")
const VOLT          := Color("#2CD0FF")
const VOLT_DEEP     := Color("#0a3d54")
const VERDANT       := Color("#5FE26B")
const VERDANT_DEEP  := Color("#0e3f1b")
const UMBRA         := Color("#C177FF")
const UMBRA_DEEP    := Color("#3b1958")

enum Faction { EMBER, VOLT, VERDANT, UMBRA }

static func faction_color(f: Faction) -> Color:
	match f:
		Faction.EMBER:   return EMBER
		Faction.VOLT:    return VOLT
		Faction.VERDANT: return VERDANT
		Faction.UMBRA:   return UMBRA
	return TEXT

static func faction_deep(f: Faction) -> Color:
	match f:
		Faction.EMBER:   return EMBER_DEEP
		Faction.VOLT:    return VOLT_DEEP
		Faction.VERDANT: return VERDANT_DEEP
		Faction.UMBRA:   return UMBRA_DEEP
	return BG_CARD

static func faction_glyph(f: Faction) -> String:
	match f:
		Faction.EMBER:   return "◆"
		Faction.VOLT:    return "◇"
		Faction.VERDANT: return "◈"
		Faction.UMBRA:   return "◉"
	return "·"
