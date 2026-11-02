class_name DrawLayer
extends Node2D
## A canvas item whose drawing is delegated to a callable, so a single owner
## can paint several z-ordered layers without an extra script per layer.

var painter: Callable


static func make(owner_painter: Callable, z := 0) -> DrawLayer:
	var layer := DrawLayer.new()
	layer.painter = owner_painter
	layer.z_index = z
	return layer


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
