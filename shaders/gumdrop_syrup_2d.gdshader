shader_type canvas_item;

// Gumdrop's syrup as it is shown (puzzles/gumdrop_table.gd): the fluid's
// dye texture (puzzles/gumdrop_fluid.gd, three pigment amounts a texel)
// drawn over the dark gel as a blob of coloured jelly. The colour is
// puzzles/gumdrop_sim.gd's: the hue of the pigments' shares at the
// strength of their sum, deepened past the card's shade. At the card's
// shade the colour is the card's own (the player matches by eye and the
// judge by colour_of); under it the tint is pale, toward MILK, as the
// judge sees it (nearness_of mixes toward white), so a thin pour reads
// as "more"; over it, darker.
//
// Since 2026-10-14 (the user: "the tint should be more satisfactory to
// see it filling") the pour has a body: its front is a rounded edge
// (coverage, a short ramp of the amount) with a darker lip just inside
// it, like the meniscus of a thick syrup, and nothing inside the blob is
// lit from the dye's slope (tried 2026-10-11: every fold a crease of
// foil). The jelly's own light lies on the skin's mesh over this.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

const vec3 MILK = vec3(0.96, 0.95, 0.94);
// The amount the blob's edge lies at, and over which it is solid.
const float EDGE_LO = 0.02;
const float EDGE_HI = 0.09;
// The lip: how far in from the edge it shades, and how dark. Faint since
// the tint spreads on after the release (2026-10-14): at 0.72 the thin
// front of a spreading tint was a grey fringe over half the chunk.
const float LIP_TO = 0.22;
const float LIP = 0.92;

// The serve's sweep of light (2026-10-26, spec gumdrop-fun 4.4; the table
// sets these while a served mould is told): a soft white band
// `sweep_w` of the tray wide, its long edges from upper left to lower
// right, its middle `sweep_at` of the way from the tray's lower-left
// corner to its upper right, `sweep_a` at its middle and nothing at its
// edges. Here, not a mesh of its own, so it lies on the tint only (never
// on the bare tray) and the seams' mesh over it; it costs no draw.
uniform float sweep_at = -1.0;
uniform float sweep_a = 0.0;
uniform float sweep_w = 0.28;

void fragment() {
	vec3 pig = texture(TEXTURE, UV).rgb * AMOUNT_TOP;
	float c = pig.r + pig.g + pig.b;
	vec4 col = colour_of(pig);
	float cover = smoothstep(EDGE_LO, EDGE_HI, c);
	vec3 shade = mix(MILK, col.rgb, col.a);
	// a little richer where it is deep, as a thick syrup is
	shade = mix(shade, shade * shade, 0.1 * col.a);
	float lip = mix(LIP, 1.0, smoothstep(EDGE_HI, LIP_TO, c));
	// along the tray's diagonal from its lower-left corner, 0 to 1
	float along = (UV.x + 1.0 - UV.y) * 0.5;
	// across the band, in tray widths (the diagonal is sqrt(2) of one)
	float off = (along - sweep_at) * 1.41421356 / sweep_w;
	float band = abs(off) < 0.5 ? pow(cos(3.14159265 * off), 2.0) : 0.0;
	vec3 lit = mix(shade * lip, vec3(1.0), band * sweep_a);
	COLOR = vec4(lit, cover);
}
