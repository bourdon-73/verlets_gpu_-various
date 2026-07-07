shader_type canvas_item; // or use 'spatial' if you're doing 3D

uniform float time;
uniform vec4 color1 : source_color;
uniform vec4 color2 : source_color;

attribute float line_id; // 0 or 1 for two different lines
attribute float t_param; // from 0.0 to 1.0 along the line

void vertex() {
    // Define endpoints of two lines
    vec2 p0 = line_id < 0.5 ? vec2(-0.8, -0.3) : vec2(-0.8, 0.3);
    vec2 p1 = line_id < 0.5 ? vec2(0.8, -0.3) : vec2(0.8, 0.3);

    // Interpolate point along line
    vec2 pos = mix(p0, p1, t_param);

    // Add curve using sine wave
    float offset = sin(t_param * 3.1415) * 0.1; // curve height
    pos.y += offset * (line_id < 0.5 ? 1.0 : -1.0); // curve one up, one down

    VERTEX = vec3(pos, 0.0);
}

void fragment() {
    COLOR = line_id < 0.5 ? color1 : color2;
}
