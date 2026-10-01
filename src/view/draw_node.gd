class_name DrawNode
extends Node2D
## A node that draws with a function func(ci: CanvasItem) -> void. Call
## queue_redraw() to draw again (e.g. every frame for moving things).

var painter: Callable


func _init(p_painter: Callable = Callable(), depth: int = 0) -> void:
	painter = p_painter
	z_index = depth
	z_as_relative = false


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
