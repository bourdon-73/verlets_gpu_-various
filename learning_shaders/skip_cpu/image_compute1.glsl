#[compute]

#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Output image (optional – not used for gravity here)
layout(rgba32f, binding = 0) uniform writeonly image2D result_image;

// Frame counter
layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer {
    float frame;
    float delta_time; // <-- Add this to control simulation step
    float mouse_x;
    float mouse_y;

} params;

// Particle data: [pos.x, pos.y, vel.x, vel.y] per particle (4 floats)
layout(set = 0, binding = 2) buffer StorageBuffer {
    float data[]; // 4 * particle_count floats
} storage_buffer;

layout(set = 0, binding = 3, std430) restrict buffer CameraParamsBuffer {
    float camera_position_x;
    float camera_position_y;
    float camera_size_x;
    float camera_size_y;
    float viewport_size_x;
    float viewport_size_y; // <-- Add this to control simulation step

} cam_params;


const float GRAVITY = -.0098; // meters per second squared (downward)


uvec2 get_next(uvec2 current, uvec2 size) {
    current.x += 1;
    if (current.x >= size.x) {
        current.x = 0;
        current.y += 1;
    }
    return current;
}



void main() {
    uvec2 gid = gl_GlobalInvocationID.xy;
    uint id = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 800;//params.texture_width;


    // camera viewport size
    vec2 local_viewport_size = vec2(cam_params.viewport_size_x/cam_params.camera_size_x, cam_params.viewport_size_y/cam_params.camera_size_y);
    bool skip = (id % 2u) == 1u;

    vec4 color;
    if (skip) {
        // Use the highlight color on skipped positions
        color = vec4(1.0, 0.5, 0.0, 1.0); // orange
        color = vec4(1.0, 1.0, 1.0, 1.0);
    
        if (gid == ivec2(1, 0)){
            color = vec4(float(params.mouse_x/local_viewport_size.x), float(params.mouse_y/local_viewport_size.y), 1.0, 1.0);
            //color = vec4(1.0, 0.5, 0.0, 1.0);
        }

    } else {
        // Normal coloring logic
        vec2 vel = vec2(0.0, 0.0);
        vel.y += GRAVITY * params.delta_time;

        float r = abs(vel.y) * 0.1;
        float g = 0.5 + 0.5 * sin((params.frame / 10.0) + float(id));
        float b = 1.0;

        //           x, y, rot, size
        color = vec4(r, g, g, g);
        if (gid == ivec2(0, 0)){
            color = vec4(float(params.mouse_x/local_viewport_size.x), float(params.mouse_y/local_viewport_size.y), b, 1.0);

        }
        //color = vec4(0, 0, 0, 0);
    }

    //color = vec4(10.0, 1.0, 1.0, 1.0);
    imageStore(result_image, ivec2(gid), color);
    //storage_buffer.data[id] = float(local_viewport_size.y);
}


