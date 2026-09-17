shader_type spatial;
render_mode unshaded;

uniform sampler2D tex: source_color, filter_nearest;

void vertex() {}

void fragment() {
	// embarrasingly simple shader for just blitting the damn colors of the texture
	vec4 col = texture(tex, UV);
	if (col.a < .5) discard;
	ALBEDO = col.rgb;
	//ALBEDO = vec3(UV.y);
}
