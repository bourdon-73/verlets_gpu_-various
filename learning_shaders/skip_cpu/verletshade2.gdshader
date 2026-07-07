shader_type canvas_item;
render_mode unshaded;

uniform sampler2D particles_data; // RGBA32F texture
uniform float particles_count;
uniform float texture_width; // in texels

vec4 read_particle_data(float particle_index, float offset) {
    float tex_index = particle_index * 2.0 + offset;
    float x = mod(tex_index, texture_width);
    float y = floor(tex_index / texture_width);
    vec2 uv = (vec2(x, y) + 0.5) / texture_width;
    return texture(particles_data, uv);
}

void vertex() {
    float id = float(INSTANCE_ID);

    vec4 d0 = read_particle_data(id, 0.0); // pos.x, pos.y, rot, size
    vec4 d1 = read_particle_data(id, 1.0); // r, g, b, a

    vec2 pos = d0.xy;
    float rot = d0.z;
    float size = d0.w;

    vec4 color = d1;

    // Scale and rotate
    vec2 local_pos = VERTEX * size;
    mat2 rot_matrix = mat2(vec2(cos(rot), -sin(rot)), vec2(sin(rot), cos(rot)));
    local_pos = rot_matrix * local_pos;

    VERTEX = local_pos + pos;
	//VERTEX = VERTEX + vec2(200.0, 0.0); // moves everything right

    COLOR = color;
}