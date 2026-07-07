#[compute]

#version 460

layout(local_size_x = 16, local_size_y = 16) in;

// Output image
layout(rgba32f, binding = 0) uniform writeonly image2D result_image;

// Frame counter
layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer {
    float frame;
} params;

// Optional: write to storage buffer (can keep or remove)
layout(set = 0, binding = 2) buffer StorageBuffer {
    float data[];  // flattened position data
} storage_buffer;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    uint id = gl_GlobalInvocationID.x;// * gl_NumWorkGroups.x * gl_WorkGroupSize.x + gl_GlobalInvocationID.x;

    float t = params.frame * 0.05;

    // Normalize coordinates to 0–1
    vec2 uv = vec2(coords) / vec2(imageSize(result_image));
    
    // Fun per-pixel color variation based on position + time
    float r = 0.5 + 0.5 * sin(t + uv.x * 10.0);
    float g = 0.5 + 0.5 * sin(t + uv.y * 15.0);
    float b = 0.5 + 0.5 * sin(t + (uv.x + uv.y) * 20.0);

    imageStore(result_image, coords, vec4(r, g, b, 1.0));

    storage_buffer.data[id] = t;
}
