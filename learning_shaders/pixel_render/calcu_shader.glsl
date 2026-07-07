#[compute]
// simple_image.compute
#version 450

layout(local_size_x = 8, local_size_y = 8) in;

layout(rgba8, binding = 0) writeonly uniform image2D img;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(img);

    float u = float(pixel_coords.x) / float(size.x);
    float v = float(pixel_coords.y) / float(size.y);

    vec4 color = vec4(u, v, 1.0 - u, 1.0); // Some gradient
    imageStore(img, pixel_coords, color);
}
