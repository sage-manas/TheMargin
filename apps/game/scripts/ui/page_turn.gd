class_name PageTurn
extends TextureRect
## Full-screen page-turn transition over a snapshot of the outgoing page.
## The next page is built underneath while this plays.

const SHADER := preload("res://shaders/page_turn.gdshader")
const DURATION := 0.9
const FADE_DURATION := 0.45


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	visible = false


## Snapshot of what is currently on screen.
func capture() -> ImageTexture:
	await RenderingServer.frame_post_draw
	return ImageTexture.create_from_image(get_viewport().get_texture().get_image())


func play(snapshot: Texture2D, fade_only := false) -> void:
	texture = snapshot
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("fade_only", fade_only)
	mat.set_shader_parameter("progress", 0.0)
	visible = true
	if not fade_only:
		Audio.play("page_turn", 0.02)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, FADE_DURATION if fade_only else DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished
	visible = false
	texture = null
