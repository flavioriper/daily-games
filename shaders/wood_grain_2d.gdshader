shader_type canvas_item;

// The HUD's wood, grained. Set as a Control's `material` so it modulates the
// StyleBoxFlat the panel already draws: the rounded corners, the thick bottom
// edge and the antialiasing all come for free, and the darker edge grains
// along with the face because the darkening is a multiply on whatever colour
// was drawn rather than a colour of its own. One material serves the tray,
// its trough and the plaque. Same two-tone ring figure as the 3D wood
// (shaders/toon_lit.gdshaderinc), measured in pixels instead of local units.

varying vec2 grain_pos;
// The heart of the log, in pixels from the panel's top-left corner. Below and
// left of the card, so its rings cross the face as long shallow arcs.
uniform vec2 grain_heart = vec2(90.0, 300.0);
uniform float grain_period = 23.0;   // pixels between rings
uniform float grain_width : hint_range(0.0, 0.5) = 0.16;
uniform float grain_wobble = 2.5;    // pixels a ring wanders along its length
uniform float grain_wobble_period = 130.0;
uniform float grain_darken : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	grain_pos = VERTEX;
}

void fragment() {
	float r = (length(grain_pos - grain_heart)
		+ sin(grain_pos.x / grain_wobble_period * TAU) * grain_wobble) / grain_period;
	// Centred on 0.5 so neither edge of the band lands on fract()'s wrap.
	float d = abs(fract(r) - 0.5);
	float w = max(fwidth(r), 0.0008);
	float band = 1.0 - smoothstep(grain_width - w, grain_width + w, d);
	COLOR.rgb *= mix(1.0, grain_darken, band);
}
