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

## Scenery lines: furniture and decoration are drawn thin in this grey, so
## the things Nib can use (heavy ink) stand out (GDD §9).
const SCENERY := Color("77726a")
const LEAF := Color("6f8f5c")
const WOOD_DARK := Color("a8772b")
## Ice, and glow paint that only shows at night (GDD §4.7).
const ICE := Color("cfe3ee")
const GLOW := Color("d8f27a")
## The wash over a panel at night.
const NIGHT_WASH := Color("1b2140")


## A colour faded toward the panel paper, for scenery fills.
static func muted(c: Color, k := 0.45) -> Color:
	return c.lerp(PAPER, k)


## Panel background presets referenced by page data ("bg").
## paper/dot colours plus halftone strength at the top and bottom of the panel.
const PANEL_STYLES := {
	"room_warm": {"paper": PAPER, "dot": SHADOW, "top": 0.0, "bottom": 0.55, "spacing": 4.0},
	"room_blue": {"paper": Color("e4e6df"), "dot": BLUE_LIGHT, "top": 0.6, "bottom": 0.0, "spacing": 4.0},
	"plain": {"paper": Color("f5eedb"), "dot": PAGE_FIBER, "top": 0.0, "bottom": 0.25, "spacing": 6.0},
	"sketch": {"paper": PAGE, "dot": PAGE, "top": 0.0, "bottom": 0.0, "spacing": 4.0},
	# Chapter 2 (GDD §9): newsprint grey and cyan.
	"news": {"paper": Color("ebe8de"), "dot": Color("b9c9c9"), "top": 0.0, "bottom": 0.5, "spacing": 4.0},
	"news_cyan": {"paper": Color("e2eced"), "dot": Color("8fb8c2"), "top": 0.55, "bottom": 0.0, "spacing": 4.0},
}
