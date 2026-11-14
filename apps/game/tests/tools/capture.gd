extends Node
## Developer tool: renders pages to PNG for art review (not a test; needs a
## window, so run without --headless):
##   godot --path apps/game res://tests/tools/capture.tscn -- <out_dir>
## Captures the page start state and the solved positions of pages 1 and 3–8, and
## the sandboxes (mechanics, weight, eraser, ink, platforms, scenes, close-ups, swap, stretch).

func _ready() -> void:
	WordLibrary.load_words()
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	await _shot(out, "p01_start", "ch01_p01", {})
	await _shot(out, "p01_linked", "ch01_p01", {"panels": {"p3": [416, 40]}}, [470, 144])
	await _shot(out, "p01_dropped", "ch01_p01", {"panels": {"p3": [416, 72]}, "slots": {"nb:0": null}}, [600, 328], "OPEN")
	await _shot(out, "p01_open", "ch01_p01", {"panels": {"p3": [416, 72]}, "slots": {"nb:0": null, "door1:label": "OPEN"}}, [560, 328], "SHUT")
	await _shot(out, "p02", "ch01_p02", {})
	await _shot(out, "p03_start", "ch01_p03", {})
	await _shot(out, "p03_thawed", "ch01_p03", {"scenes": {"later": "b"}}, [200, 328])
	await _shot(out, "p03_climb", "ch01_p03", {}, [128, 238])
	await _shot(out, "p04_start", "ch01_p04", {})
	await _shot(out, "p04_open", "ch01_p04", {"panels": {"h": [216, 16]}, "controls": {"lever1": true}}, [250, 328])
	await _shot(out, "p05_start", "ch01_p05", {})
	await _shot(out, "p05_steps", "ch01_p05", {"scenes": {"later": "s1", "night": "s2"}}, [256, 220])
	await _shot(out, "p05_asleep", "ch01_p05", {"scenes": {"later": "s1", "night": "m"}}, [520, 130])
	await _shot(out, "p06_start", "ch01_p06", {})
	await _shot(out, "p06_night", "ch01_p06", {"panels": {"n": [224, 40]}, "scenes": {"night": "n"}, "controls": {"lock": "308"}}, [100, 168])
	await _shot(out, "p07_start", "ch01_p07", {})
	await _shot(out, "p07_bridge", "ch01_p07", {"panels": {"v": [424, 224]}, "controls": {"lever1": true}}, [300, 144], "OPEN")
	await _shot(out, "p07_vine", "ch01_p07", {"panels": {"v": [424, 224]}, "controls": {"lever1": true}, "scenes": {"later": "r"}, "slots": {"cap_a:0": null}}, [512, 144], "OPEN")
	await _shot(out, "p08_start", "ch01_p08", {})
	await _shot(out, "p08_erased", "ch01_p08", {"fired": ["from_the_top"]}, [300, 144])
	await _shot(out, "p08_risen", "ch01_p08", {"panels": {"l": [16, 16]}, "fired": ["from_the_top"]}, [120, 144])
	await _shot(out, "c2p1", "ch02_p01", {})
	await _shot(out, "c2p2", "ch02_p02", {"sizes": {"a": [304, 144]}}, [200, 144])
	await _shot(out, "c2p3", "ch02_p03", {})
	await _shot(out, "c2p4", "ch02_p04", {})
	await _shot(out, "c2p5", "ch02_p05", {"sizes": {"n": [200, 328]}, "scenes": {"later": "n"}})
	await _shot(out, "c2p6", "ch02_p06", {"panels": {"lever_room": [216, 16], "empty": [16, 16]}, "controls": {"lever1": true}})
	await _shot(out, "c2p7", "ch02_p07", {})
	await _shot(out, "c2p8", "ch02_p08", {})
	await _shot(out, "sb_start", "sb_mechanics", {})
	await _shot(out, "sb_risen", "sb_mechanics", {"slots": {"cap_s1:0": null, "c1:label": "UP"}, "objects": {"c1": [172, 16]}}, [200, 32])
	await _shot(out, "sb_lowered", "sb_mechanics", {"panels": {"s2": [320, 112]}, "slots": {"cap_s1:0": null, "c1:label": "UP", "cap_s2:0": null}, "objects": {"c1": [172, 16]}}, [450, 200], "HEAVY")
	await _shot(out, "sbw_start", "sb_weight", {})
	await _shot(out, "sbw_pressed", "sb_weight", {"slots": {"cap_w1:0": null, "c1:label": "HEAVY"}}, [200, 168])
	await _shot(out, "sbe_start", "sb_eraser", {})
	await _shot(out, "sbe_reach", "sb_eraser", {}, [184, 168], "", ["eraser"])
	await _shot(out, "sbe_full", "sb_eraser", {"sketches": {"wall": false}}, [420, 168], "", ["eraser"])
	await _shot(out, "sbe_done", "sb_eraser", {"sketches": {"wall": false, "shelf": false, "step1": true, "step2": true}, "objects": {"box": [44, 128]}}, [568, 104], "", ["eraser"])
	await _shot(out, "sbi_start", "sb_ink", {})
	await _shot(out, "sbi_full", "sb_ink", {"collected": ["drop"]}, [96, 168], "", ["ink"])
	await _shot(out, "sbi_reach", "sb_ink", {"collected": ["drop"]}, [146, 168], "", ["ink", "eraser"])
	await _shot(out, "sbi_traced", "sb_ink", {"collected": ["drop", "well"], "sketches": {"f1": "inked", "f2": "inked", "f3": "inked"}}, [528, 128], "", ["ink"])
	await _shot(out, "sbp_start", "sb_platforms", {})
	await _shot(out, "sbp_ferry", "sb_platforms", {"slots": {"ferry:label": null}, "objects": {"ferry": [176, 56], "lift1": [88, 56]}}, [432, 72], "STOP")
	await _shot(out, "sbp_done", "sb_platforms", {"slots": {"ferry:label": null, "cap_up:0": "STOP", "box:label": "LEFT", "lift3:label": "UP"}, "objects": {"ferry": [264, 56], "lift3": [116, 88], "box": [2, 64]}}, [400, 312], "DOWN")
	await _shot(out, "sbs_start", "sb_scenes", {})
	await _shot(out, "sbs_moved", "sb_scenes", {"scenes": {"later": "b", "night": "n"}}, [200, 208])
	await _shot(out, "sbc_start", "sb_closeups", {})
	await _shot(out, "sbc_ready", "sb_closeups", {"panels": {"h": [216, 16]}, "controls": {"lever1": true, "safe": "410"}}, [420, 328])
	await _shot(out, "sbw2_start", "sb_swap", {})
	await _shot(out, "sbw2_swapped", "sb_swap", {"panels": {"door_room": [416, 16], "hall": [16, 16], "start": [216, 16]}})
	await _shot(out, "sbt_start", "sb_stretch", {})
	await _shot(out, "sbt_stretched", "sb_stretch", {"sizes": {"a": [304, 144]}}, [200, 144])
	await _erase_shot(out)
	await _turn_shot(out)
	get_tree().quit()


## Page 1.8 with the artist's eraser halfway through the little room.
func _erase_shot(dir: String) -> void:
	var page := ComicPage.new()
	add_child(page)
	page.build(ComicPage.load_def("ch01_p08"), {}, {"position": [300, 144], "carrying": ""})
	page.erase_panel("p1")
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(ComicPanel.ERASE_ROW_SEC * 4.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("p08_erasing.png"))
	page.queue_free()
	await get_tree().process_frame


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


func _shot(dir: String, name: String, page_id: String, state: Dictionary, pos: Variant = null, carrying := "", found := []) -> void:
	var page := ComicPage.new()
	add_child(page)
	page.build(ComicPage.load_def(page_id), state, {"position": pos, "carrying": carrying}, found)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	page.queue_free()
	await get_tree().process_frame
