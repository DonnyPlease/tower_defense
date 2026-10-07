shader_type canvas_item;
// Darkness over the field at night, with a pool of light around every tower.

const int MAX_LIGHTS = 64;
uniform vec4 lights[MAX_LIGHTS]; // x, y, radius (field pixels)
uniform int count = 0;
uniform vec2 field_size = vec2(800.0, 600.0);
uniform float darkness = 0.58;

void fragment() {
	vec2 p = UV * field_size;
	float lit = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= count) {
			break;
		}
		float d = distance(p, lights[i].xy);
		lit = max(lit, 1.0 - smoothstep(lights[i].z * 0.45, lights[i].z, d));
	}
	COLOR = vec4(0.02, 0.03, 0.12, darkness * (1.0 - lit));
}
