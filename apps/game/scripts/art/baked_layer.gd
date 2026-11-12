class_name BakedLayer
extends Node2D
## A drawing that is rendered once into a texture at screen resolution and
## then shown as a single sprite (ADR-0013). The hand-inked art is thousands
## of antialiased strokes; drawing them every frame is cheap on a GPU but
## not where WebGL runs in software (CI browsers, blocklisted GPUs). Static
## art (paper, panel ground, borders, lettering) is baked; what moves is
## drawn live.
##
## Like DrawLayer, a painter Callable does the drawing, in this node's local
## coordinates, inside `area`. Call refresh() when what it draws changes.

var painter: Callable
var area := Rect2()
var _vp: SubViewport
var _canvas: Node2D
var _sprite: Sprite2D
var _scale := 0.0


static func make(owner_painter: Callable, bake_area: Rect2, z := 0) -> BakedLayer:
	var layer := BakedLayer.new()
	layer.painter = owner_painter
	layer.area = bake_area
	layer.z_index = z
	return layer


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(_paint)
	_vp.add_child(_canvas)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _vp.get_texture()
	add_child(_sprite)
	get_tree().root.size_changed.connect(refresh)
	refresh()


## Re-renders the texture (optionally over a new area) on the next frame.
func refresh(new_area: Variant = null) -> void:
	if new_area is Rect2:
		area = new_area
	if _vp == null:
		return
	# One texture pixel per screen pixel, so baked lines stay as crisp as live ones.
	_scale = clampf(get_tree().root.get_final_transform().get_scale().x, 1.0, 4.0)
	var px := Vector2i(maxi(1, ceili(area.size.x * _scale)), maxi(1, ceili(area.size.y * _scale)))
	_vp.size = px
	_canvas.scale = Vector2(_scale, _scale)
	_canvas.position = -area.position * _scale
	_sprite.position = area.position
	_sprite.scale = area.size / Vector2(px) if area.size.x > 0 and area.size.y > 0 else Vector2.ONE
	_canvas.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _paint() -> void:
	if painter.is_valid():
		painter.call(_canvas)
