shader_type canvas_item;

// A body in Nightlight's sky, lit by its star (arcade/nightlight_sky.gd):
// the material of the layer that draws the bodies, each an instance of a
// MultiMesh of one white lump built Art.R across. The instance's colour is
// the body's one flat paint; everything else is worked out here from where
// the body is and where the star is, so there is no per-body data and no
// instance uniform (CLAUDE.md: garbage on Android past sixteen instances).
//
// The star never moves, so its place is one plain uniform, in the canvas's
// own pixels (the layer's global transform, as shaders/wind_2d.gdshader
// reads a tree's foot: the model matrix carries a MultiMesh instance's
// transform). The side of the lump that faces the star is lit, the other is
// a deep violet and never a black, with a soft line between; light falls
// off with distance, a quarter of it left at `reach`; inside `haze` the
// body warms toward an ember, more the deeper it is.

uniform vec2 star = vec2(0.0);
uniform float reach = 600.0;
uniform float haze = 230.0;
uniform vec3 star_col = vec3(1.0, 0.59, 0.38);
// The radius the lump's mesh is built at.
uniform float built = 64.0;

const vec3 SHADE = vec3(0.118, 0.102, 0.243);
const vec3 HOT = vec3(1.0, 0.91, 0.745);
const vec3 EMBER = vec3(0.69, 0.29, 0.157);

varying vec2 rel;
varying vec2 to_star;
varying float lit;
varying float heat;

void vertex() {
	vec2 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	vec2 here = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float scale = max(length(MODEL_MATRIX[0].xy), 0.0001);
	// the vertex as the body is turned, in the lump's own radii
	rel = (here - at) / (scale * built);
	vec2 d = star - at;
	float far = max(length(d), 0.0001);
	to_star = d / far;
	float k = far / reach;
	lit = 1.0 / (1.0 + 3.0 * k * k);
	heat = clamp(1.0 - far / haze, 0.0, 1.0);
}

void fragment() {
	// 1 on the point nearest the star, -1 on the one furthest from it
	float facing = dot(rel, to_star);
	vec3 paint = COLOR.rgb;
	vec3 day = mix(mix(SHADE, mix(paint, star_col, 0.3), 0.2 + 0.8 * lit), HOT, heat * 0.65);
	vec3 night = mix(mix(SHADE, paint, 0.16), EMBER, heat * 0.55);
	vec3 c = mix(night, day, smoothstep(-0.4, 0.4, facing));
	c = mix(c, vec3(1.0), 0.25 * lit * smoothstep(0.4, 1.0, facing));
	COLOR = vec4(c, COLOR.a);
}
