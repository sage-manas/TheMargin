extends Node
## Decoupled gameplay events. Gameplay systems emit; story triggers, audio,
## saving and the web bridge listen. Nothing here holds state.

signal page_entered(page_id: String)
signal page_completed(page_id: String)
signal panel_moved(panel_id: String, position: Vector2i)
signal panel_released(panel_id: String)
## Nib is now wholly inside this panel, having last been inside another.
signal panel_entered(panel_id: String)
signal link_formed(a: String, b: String)
signal link_broken(a: String, b: String)
signal word_taken(slot_id: String, word: String)
signal word_placed(slot_id: String, word: String)
signal door_opened(object_id: String)
signal button_pressed(object_id: String)
signal button_released(object_id: String)
signal eraser_found
signal sketch_erased(sketch_id: String)
signal sketch_restored(sketch_id: String)
signal ink_collected(object_id: String)
signal sketch_inked(sketch_id: String)
## A scene card moved: `panel_id` is now `scene` ("" = now, by day).
signal scene_changed(panel_id: String, scene: String)
## A close-up control's switch turned on or off.
signal switch_changed(switch_id: String, on: bool)
## The reader swapped two panels (GDD §4.9). Not sent for the artist's swaps.
signal panels_swapped(a: String, b: String)
signal achievement_unlocked(code: String)
## Something worth persisting changed; GameState coalesces these into one save.
signal state_dirty
