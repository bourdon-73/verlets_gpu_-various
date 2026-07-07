shader_type canvas_item;

uniform sampler2D tex;

void fragment() {
	vec2 uv = UV;
	COLOR = texture(tex, uv);
	//COLOR = vec4(0, .8, .7,  1.0);
}
