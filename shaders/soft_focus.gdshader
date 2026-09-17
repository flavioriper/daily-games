shader_type spatial;
// Drawn in the transparent pass (blend_mix) because that is when the
// Compatibility renderer has taken its copies of the screen and the depth;
// an opaque quad reads the previous frame's screen and no depth at all
// (probed 2026-09-17). render_priority on the material puts it first among
// the transparents, so the water and the pollen draw over it rather than
// vanishing under the copy.
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, depth_draw_never, fog_disabled;

// The campsite's soft focus: the concept banner's depth of field, which
// gl_compatibility has no CameraAttributes for. Everything past focus_start
// (a view distance, set by world/stage.gd to just behind the thing being
// framed) blurs in over focus_range by sampling the screen texture's own mip
// levels -- a blur the GPU has already computed -- and lightens a hair
// toward the haze, the shading direction's "depth through colour".
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float focus_start = 8.0;
uniform float focus_range = 9.0;
uniform float max_lod = 3.0;
uniform vec4 haze_color : source_color = vec4(0.91, 0.95, 0.97, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.16;

void vertex() {
	// A QuadMesh spans -0.5..0.5; this pins it to the whole frame whatever
	// the camera does, so the node's transform never matters.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	// OpenGL depth: the NDC z is depth * 2 - 1. The inverse projection is the
	// camera's real one, frustum offset included, so this holds under the
	// menu's shift lens.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0);
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float dist = -v.z / v.w;
	float k = smoothstep(focus_start, focus_start + focus_range, dist);
	vec3 col = textureLod(screen_tex, SCREEN_UV, k * max_lod).rgb;
	ALBEDO = mix(col, haze_color.rgb, k * haze);
	ALPHA = 1.0;
}
