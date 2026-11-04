shader_type canvas_item;
render_mode blend_add, unshaded;

// A thread of the swarm's lattice (ui/menu/swarm_tab.gd): a unit quad laid
// from one dot of the face to its neighbour, soft across and fading out at
// both ends so it never shows a square tip. Additive, so the cover is folded
// into the colour. No instance uniform.

void fragment() {
	float across = 1.0 - smoothstep(0.0, 0.5, abs(UV.y - 0.5));
	float along = sin(UV.x * 3.14159265);
	float a = across * across * along * COLOR.a;
	COLOR = vec4(COLOR.rgb * a, 1.0);
}
