shader_type canvas_item;
render_mode blend_disabled, unshaded;

// A copy of a texture: the dye's keep, read by the next frame's dye pass
// (a pass cannot read its own target).

uniform sampler2D from : filter_nearest, repeat_disable;

void fragment() {
	COLOR = texture(from, UV);
}
