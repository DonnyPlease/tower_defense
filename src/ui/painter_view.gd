class_name PainterView
extends Control
## A control that draws itself with a painter function
## func(ci: CanvasItem, center: Vector2, size: float), e.g. a tower icon.

var painter: Callable


func _init(p_painter: Callable = Callable()) -> void:
	painter = p_painter
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size / 2, minf(size.x, size.y))
