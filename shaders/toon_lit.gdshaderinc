// Shared body of the cozy cel shader: toon.gdshader, toon_wind.gdshader and
// toon_wood.gdshader #include this so the lighting has one source. Spec:
// 3d-toon-pipeline design section 2. Runs on gl_compatibility: nothing here
// reads depth or screen. A shader that #defines WOOD_GRAIN before the include
// also gets the grain block below; nothing else pays for it.

uniform vec4 albedo : source_color = vec4(1.0);
// Red channel = lit factor across NdotL remapped to 0..1. Nearest filtering
// keeps the bands hard. core/toon.gd ramp() builds the default.
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
// Shadow is a hue shift toward this tint, never a multiply toward black.
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0);

#ifdef WOOD_GRAIN
// Wood grain, cel. Rings around the piece's own axis with the heart of the
// log sitting off the surface, which is what turns a flat-sawn face's rings
// into cathedral figure and wraps a round post in bands. Object space, so a
// board that turns or a deck strip stretched along its length keeps the same
// grain. Two tones, never a gradient: the only softening is the one pixel of
// fwidth that stops a deck seen edge-on from shimmering.
varying vec3 grain_pos;
uniform vec3 grain_axis = vec3(0.0, 1.0, 0.0);
// Where the heart sits in the plane across the axis, in local units. Off the
// piece on purpose -- a ring centred inside a plank would read as a target.
uniform vec2 grain_heart = vec2(0.75, 0.9);
uniform float grain_scale = 16.0;           // rings per local unit
uniform float grain_width : hint_range(0.0, 0.5) = 0.075;
uniform float grain_wobble = 0.06;          // how far a ring wanders along the grain
uniform float grain_wobble_scale = 5.0;
uniform float grain_darken : hint_range(0.0, 1.0) = 0.82;

void vertex() {
	grain_pos = VERTEX;
}

float wood_band(vec3 p) {
	vec3 ax = normalize(grain_axis);
	// A reference never parallel to the axis, so the cross products below
	// give a stable pair of axes across the log.
	vec3 ref = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), step(0.9, abs(ax.y)));
	vec3 u = normalize(cross(ax, ref));
	vec3 v = cross(ax, u);
	vec2 rc = vec2(dot(p, u), dot(p, v)) - grain_heart;
	float along = dot(p, ax);
	float r = length(rc) * grain_scale + sin(along * grain_wobble_scale) * grain_wobble * grain_scale;
	// The band is centred on 0.5 so neither of its edges lands on fract()'s
	// wrap, where there is no derivative to antialias with.
	float d = abs(fract(r) - 0.5);
	float w = max(fwidth(r), 0.0008);
	return 1.0 - smoothstep(grain_width - w, grain_width + w, d);
}
#endif

void fragment() {
	vec3 base = albedo.rgb;
#ifdef WOOD_GRAIN
	base *= mix(1.0, grain_darken, wood_band(grain_pos));
#endif
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(1.0 - rim_width, 1.0 - facing);
	EMISSION = rim_color.rgb * base * rim * rim_strength;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = texture(ramp, vec2(t, 0.5)).r;
	// LIGHT_COLOR is colour * energy * PI, and the pipeline multiplies this
	// result by ALBEDO afterwards (scene.glsl: diffuse_light *= albedo), so
	// neither factor belongs here.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
