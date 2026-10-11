shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The judge: for each texel of the dye, how near its colour is to the
// flavour its cell is wanted in (red) and how strong it is (green). The
// screen reads this back and takes each cell's mean.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D dye : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform vec3 want[16];

void fragment() {
	int cell = cell_of(mask, UV);
	if (cell < 0 || cell >= 16) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec4 col = colour_of(texture(dye, UV).rgb * AMOUNT_TOP);
		COLOR = vec4(nearness_of(col, want[cell]), col.a, 0.0, 1.0);
	}
}
