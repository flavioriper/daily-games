shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The meter: one texel a chunk (CELLS_TOP across, one high), its mean
// pigments over the dye's texels at a stride of STEP, so the screen can
// read how full the chunk under the tip is (the ring on the squeeze
// button, puzzles/gumdrop_table.gd) with a readback of sixteen texels
// instead of the judge's whole picture.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D dye : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;

const int STEP = 4;

void fragment() {
	int cell = int(floor(UV.x * 16.0));
	ivec2 size = textureSize(dye, 0);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int y = 0; y < size.y; y += STEP) {
		for (int x = 0; x < size.x; x += STEP) {
			ivec2 p = ivec2(x, y);
			if (int(round(texelFetch(mask, p, 0).r * 255.0)) - 1 == cell) {
				sum += texelFetch(dye, p, 0).rgb;
				n += 1.0;
			}
		}
	}
	COLOR = vec4(n > 0.0 ? sum / n : vec3(0.0), 1.0);
}
