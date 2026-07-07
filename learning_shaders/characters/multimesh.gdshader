shader_type canvas_item;
render_mode unshaded;

uniform sampler2D particles_data; // RGBA32F texture
uniform sampler2D vertex_positions_tex; // RGBA32F texture
//uniform float particles_count;
uniform float texture_width; // in texels
uniform float texture_height; // in texels
uniform float vertex_texture_width; // in texels
uniform vec2 viewport_size;

vec4 read_particle_data2(float particle_index, float offset) {
    float tex_index = particle_index * 2.0 + offset;
    float x = mod(tex_index, texture_width);
    float y = floor(tex_index / texture_width);
    vec2 uv = (vec2(x, y) + 0.5) / texture_width;
    return texture(particles_data, uv);
}




vec2 read_vertex_position(float vertex_id) {
	// return texel position
    float x = mod(vertex_id, vertex_texture_width);
    float y = floor(vertex_id / vertex_texture_width);

    vec2 uv = (vec2(x, y) + 0.5) / vertex_texture_width;
    return texture(vertex_positions_tex, uv).xy;
}

vec2 read_vertex_position2(float vertex_id) {
    float x = mod(vertex_id, vertex_texture_width);
    float y = floor(vertex_id / vertex_texture_width);
    vec2 uv = (vec2(x, y) + 0.5) / vertex_texture_width;
    return texture(vertex_positions_tex, uv).xy;
}
// Simple hash function to get consistent pseudo-random numbers
float rand(float x) {
    return fract(sin(x) * 43758.5453123);
}

vec3 random_color(float id) {
    return vec3(
        rand(id + 1.0),
        rand(id + 2.0),
        rand(id + 3.0)
    );
}


vec4 read_particle_data3(float particle_index, float offset) {
    float tex_index = particle_index + offset;
    float x = mod(tex_index, texture_width);
    float y = floor(tex_index / texture_width);
    vec2 uv = (vec2(x, y) + 0.5) / texture_width;
    return texture(particles_data, uv);
}

vec4 read_particle_data(float particle_index, float offset) {
    float tex_index = particle_index + offset;
    float x = mod(tex_index, texture_width);
    float y = floor(tex_index / texture_width);
    vec2 uv = (vec2(x + 0.5, y + 0.5)) / vec2(texture_width, texture_height);
    return texture(particles_data, uv);
}


void vertex() {
    float id = float(INSTANCE_ID);

    vec4 d0 = read_particle_data(id, 0.0); // pos.x, pos.y, rot, size
    //vec4 d1 = read_particle_data(id, 1.0); // r, g, b, a

    vec2 pos = d0.xy;
    float rot = d0.z;
    float size = d0.w;

    //vec4 color = d1;
    //vec4 color = vec4(.5, 1.0, 0, 1.0);

    // Scale and rotate

    vec2 local_pos = VERTEX * size;
    mat2 rot_matrix = mat2(vec2(cos(rot), -sin(rot)), vec2(sin(rot), cos(rot)));
    local_pos = rot_matrix * local_pos;


    float v_id = float(VERTEX_ID);
    vec2 pos2 = read_vertex_position(v_id);
	float total_verts_per_instance = 64.0;/* known value */; // maybe passed via uniform
	float global_vertex_index = id * total_verts_per_instance + v_id;
	// VERTEX means for each instances
	//VERTEX = vec2(0.0, 0.0);
	////if (VERTEX_ID > -1) {
	VERTEX = pos + local_pos;
	//VERTEX = vec2(1.0, 1.0);
	//}

	vec3 color = random_color(float(INSTANCE_ID));
	COLOR = vec4(color, 1.0);

    //if (INSTANCE_ID == 0) {
        //// First instance: greenish
        //COLOR = vec4(0.0, 0.8, 0.2, 1.0);
    //} else if (INSTANCE_ID == 1) {
        //// Second instance: blueish
        //COLOR = vec4(0.2, 0.4, 0.9, 1.0);
    //}
}