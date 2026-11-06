class_name Palette
extends RefCounted
## Chapter 1 palette. Every colour drawn in the game comes from here (GDD §9).

const INK := Color("1d1b26")
const PAGE := Color("f7f1e1")          # margins and gutters
const PAGE_FIBER := Color("e6dcc4")
const PAPER := Color("f2e8cf")         # panel interiors
const PAPER_DARK := Color("e0d1ad")    # ground fill
const SHADOW := Color("c9b994")        # lifted-panel shadows, hatching
const RED := Color("c44536")           # Nib's scarf, loose words
const BLUE := Color("5b7a99")
const BLUE_LIGHT := Color("a9bccb")
const OCHRE := Color("d9a441")
const CAPTION := Color("f3d98b")       # narrator caption boxes
const PENCIL := Color("8d8a86")
const BUBBLE := Color("fffcf3")
const WHITE := Color("fbf7ea")
const NIGHT := Color("2f2b3d")
const ERASER := Color("e3a6a1")        # the artist's pink rubber

## Characters used in text-grid sprites (see Sprites).
const SPRITE_MAP := {
	"K": INK,
	"W": WHITE,
	"R": RED,
	"B": BLUE,
	"Y": OCHRE,
	"P": PENCIL,
	"G": SHADOW,
}

## Panel background presets referenced by page data ("bg").
## paper/dot colours plus halftone strength at the top and bottom of the panel.
const PANEL_STYLES := {
	"room_warm": {"paper": PAPER, "dot": SHADOW, "top": 0.0, "bottom": 0.55, "spacing": 4.0},
	"room_blue": {"paper": Color("e4e6df"), "dot": BLUE_LIGHT, "top": 0.6, "bottom": 0.0, "spacing": 4.0},
	"plain": {"paper": Color("f5eedb"), "dot": PAGE_FIBER, "top": 0.0, "bottom": 0.25, "spacing": 6.0},
	"sketch": {"paper": PAGE, "dot": PAGE, "top": 0.0, "bottom": 0.0, "spacing": 4.0},
}
