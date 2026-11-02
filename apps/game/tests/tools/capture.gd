extends Node
## Developer tool: renders pages to PNG for art review (not a test; needs a
## window, so run without --headless):
##   godot --path apps/game res://tests/tools/capture.tscn -- <out_dir>
## Captures the page start state and the solved positions of page 1.

func _ready() -> void:
	WordLibrary.load_words()
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	await _shot(out, "p01_start", "ch01_p01", {})
	await _shot(out, "p01_linked", "ch01_p01", {"panels": {"p3": [416, 40]}}, [470, 144])
	await _shot(out, "p01_dropped", "ch01_p01", {"panels": {"p3": [416, 72]}, "slots": {"nb:0": null}}, [600, 328], "OPEN")
	await _shot(out, "p01_open", "ch01_p01", {"panels": {"p3": [416, 72]}, "slots": {"nb:0": null, "door1:label": "OPEN"}}, [560, 328], "SHUT")
	await _shot(out, "p02", "ch01_p02", {})
	await _turn_shot(out)
	get_tree().quit()


## The page-turn shader frozen mid-turn: page 1 curling away over page 2.
func _turn_shot(dir: String) -> void:
	var old := ImageTexture.create_from_image(Image.load_from_file(dir.path_join("p01_open.png")))
	var page := ComicPage.new()
	add_child(page)
	page.build(ComicPage.load_def("ch01_p02"))
	var layer := CanvasLayer.new()
	add_child(layer)
	var turn := PageTurn.new()
	layer.add_child(turn)
	turn.texture = old
	turn.visible = true
	(turn.material as ShaderMaterial).set_shader_parameter("progress", 0.45)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("turn_mid.png"))
	layer.queue_free()
	page.queue_free()


func _shot(dir: String, name: String, page_id: String, state: Dictionary, pos: Variant = null, carrying := "") -> void:
	var page := ComicPage.new()
	add_child(page)
	page.build(ComicPage.load_def(page_id), state, {"position": pos, "carrying": carrying})
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	page.queue_free()
	await get_tree().process_frame
