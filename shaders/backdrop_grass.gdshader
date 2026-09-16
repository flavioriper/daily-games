shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded, specular_disabled;

// The backdrop meadow's blades, leaning in the wind. Unshaded on purpose: the
// landscape's colour is painted into its texture (art/landscape.blend), the way
// every card in that file was authored, so the stage's sun must not relight it.
// UV2.x is how far up its blade a vertex sits -- 0 at the root, 1 at the tip --
// baked in Blender because the ground rolls, so a root's own height says
// nothing about where the blade begins.
// motion_scale is the project-wide global that reduce-motion sets to 0, the
// same switch shaders/toon_wind.gdshader reads.

global uniform float motion_scale;

uniform sampler2D albedo : source_color, filter_linear_mipmap, hint_default_white;
// World units the tip travels. Bigger and slower than the board's own tufts:
// this is a whole field seen from far off, where a fast flutter reads as noise.
// Both re-tuned for the low-horizon camera (world/stage.gd): the old 0.09 /
// 0.11 pair was set when the meadow was seen from 68 degrees, almost
// straight down, where a blade's sway is mostly foreshortened away. Seen
// nearly edge-on at 7 degrees, the same sway sits far more in-plane with the
// screen and reads larger than it did, so both numbers came down a third on
// a rendered frame rather than staying at their top-down values by default.
uniform float sway_amount = 0.06;
uniform float sway_speed = 0.5;
// How far apart two blades have to stand before they lean differently. Low
// numbers make the gust long, so the wind crosses the meadow in broad waves
// instead of every blade doing its own thing. Widened alongside sway_amount:
// a shorter, choppier gust reads as noise at this shallower angle where each
// blade's motion is more visible on its own.
uniform float gust_scale = 0.08;

void vertex() {
	float h = UV2.x;
	h *= h;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * sway_speed + (wp.x + wp.z * 0.8) * gust_scale;
	VERTEX.x += sin(ph) * sway_amount * h * motion_scale;
	VERTEX.z += cos(ph * 0.8) * sway_amount * 0.6 * h * motion_scale;
}

void fragment() {
	ALBEDO = texture(albedo, UV).rgb;
}
