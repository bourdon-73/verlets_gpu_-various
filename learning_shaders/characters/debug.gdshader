shader_type canvas_item;

uniform sampler2D boid_data;

void fragment() {
    vec2 uv = UV;
    vec4 data = texture(boid_data, uv);
    COLOR = data; // Visualize data directly
}
