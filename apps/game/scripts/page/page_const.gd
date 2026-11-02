class_name PageConst
extends RefCounted
## Geometry rules of the page. Changing these changes every puzzle.

const PAGE_SIZE := Vector2i(640, 360)
const MARGIN := 16
const GUTTER := 8
const GRID := 8
## Visible ink border thickness, drawn inside the panel rect.
const BORDER := 2
## Border collision also reaches this far into the gutter, so two neighbouring
## panels' borders seal the gutter completely except where a link opens it.
const OUTER := 4
## Smallest opening overlap that counts as a passage.
const MIN_PASSAGE_H := 16
const MIN_PASSAGE_W := 12
