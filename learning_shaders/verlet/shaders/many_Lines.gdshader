shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform int line_count;
uniform sampler2D line_data;

//vec3 render_lines(vec2 uv) {
	//vec3 final_color = vec3(0.3); // background
	//for (int i = 0; i < line_count; i++) {
		//vec4 line_a = line_data[i * 2];
		//vec4 line_b = line_data[i * 2 + 1];
//
		//vec2 start = line_a.xy;
		//vec2 end = line_a.zw;
		//float thickness = line_b.x;
		//vec3 color = line_b.yzw;
//
		//// Get distance from point to line segment
		//vec2 pa = uv - start;
		//vec2 ba = end - start;
		//float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		//float d = length(pa - ba * h);
//
		//float alpha = smoothstep(thickness, thickness * 0.5, d);
		//final_color = mix(final_color, color, alpha);
	//}
	//return final_color;
//}
//
//void fragment() {
	//vec2 uv = (SCREEN_UV * 2.0 - 1.0); // [-1, 1] range
	//COLOR = vec4(render_lines(uv), 1.0);
//}
