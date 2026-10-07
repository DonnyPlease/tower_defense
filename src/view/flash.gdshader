// Paints a sprite or drawing solid white, keeping its shape (the "got hit" flash).
shader_type canvas_item;

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}
