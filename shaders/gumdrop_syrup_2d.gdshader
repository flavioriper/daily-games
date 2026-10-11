shader_type canvas_item;

// Gumdrop's syrup as it is shown (arcade/gumdrop_screen.gd): the fluid's
// dye texture (arcade/gumdrop_fluid.gd, three pigment amounts a texel)
// drawn over the tray as colour soaked through clear jelly. The colour is
// arcade/gumdrop_sim.gd's: the hue of the pigments' shares at the
// strength of their sum, deepened past the card's shade. Plain colour,
// nothing lit: a normal taken from the dye's slope (tried 2026-10-11)
// made every fold a crease of foil. The jelly's own light lies on the
// walls' mesh over this.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

void fragment() {
	vec3 pig = texture(TEXTURE, UV).rgb * AMOUNT_TOP;
	vec4 col = colour_of(pig);
	// a little richer where it is deep, as a thick syrup is
	vec3 shade = mix(col.rgb, col.rgb * col.rgb, 0.12 * col.a);
	COLOR = vec4(shade, col.a * 0.96);
}
