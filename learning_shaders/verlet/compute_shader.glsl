#[compute]

#version 450

layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer ColorBuffer {
    float data[];
} color_buffer;

layout(set = 0, binding = 1) buffer PosBuffer {
    float pos_data[];  // flattened position data
};

layout(set = 0, binding = 2) buffer AccelBuffer {
    float accel_data[];  // flattened acceleration data
};

layout(set = 0, binding = 3) buffer LastPosBuffer {
    float last_pos_data[];  // flattened position data
};

// layout(set = 0, binding = 4) buffer DeltaBuffer {
//     float delta_data[];  // delta time
// };

layout(set = 0, binding = 4, std430) restrict buffer ParamsBuffer
{
	float time;
	float noiseScale;
	float isoLevel;
	float numVoxelsPerAxis;
	float scale;
	float posX;
	float posY;
	float noiseOffsetX;
	float noiseOffsetY;
}
params;

struct Particle {
    vec2 pos;
    vec2 last_pos;
    vec2 accel;
    //float radius;
    //vec4 color;
};

void main() {
    uint id = gl_GlobalInvocationID.x;  // Get unique thread ID
    //if (id >= 4) return;

    // Retrieve the data with consistent indexing
    vec2 pos = vec2(pos_data[id * 2], pos_data[id * 2 + 1]);
    vec2 last_pos = vec2(last_pos_data[id * 2], last_pos_data[id * 2 + 1]);
    vec2 accel = vec2(accel_data[id * 2], accel_data[id * 2 + 1]);
    float dt = delta_data[0]; // Assuming delta is a single value in the buffer

    vec2 velocity = pos - last_pos;
    vec2 new_pos = pos + velocity + accel * dt * dt;

    // Update the data with consistent indexing
    last_pos_data[id * 2] = pos.x;
    last_pos_data[id * 2 + 1] = pos.y;
    pos_data[id * 2] = new_pos.x;
    pos_data[id * 2 + 1] = new_pos.y;
}