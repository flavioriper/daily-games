shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.055, 0.043, 0.055, 1.0);
uniform float outline_width = 0.018;
uniform float fur_length : hint_range(0.0, 0.2) = 0.055;
uniform float tuft_scale : hint_range(2.0, 40.0) = 22.0;
// How far the hull follows the fur out. 0.1 = v1 look: outline hugs the body
// and fur grows past it (soft under-edge). 1.0 = v2 cel look: hull wraps the
// fur tips so the silhouette reads as a fuzzy dark ink line.
uniform float fur_reach : hint_range(0.0, 1.5) = 0.1;

float hash31(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

// Smooth trilinear value noise — continuous, keeps the outline hull unbroken.
float value_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(cell);
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

void vertex() {
	// Outline hugs the base body; the fur coat grows over and past it so the
	// silhouette reads as soft fluff with a thin dark under-edge.
	float tuft = value_noise(VERTEX * tuft_scale);
	tuft = smoothstep(0.25, 0.85, tuft);
	VERTEX += NORMAL * (outline_width + fur_length * fur_reach * (0.3 + 0.7 * tuft));
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
