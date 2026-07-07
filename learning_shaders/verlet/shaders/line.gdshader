shader_type canvas_item;

uniform float time;
uniform vec2 mouse;
uniform vec2 resolution = vec2(1280.0, 720.0); // Default value; set from script if needed

const vec3 BACK_COLOR  = vec3(0.3);
const vec3 LINE_COLOR1 = vec3(0.35, 0.95, 0.51);
const vec3 LINE_COLOR2 = vec3(0.95, 0.95, 0.10);

// Function to draw line segment from A to B
float segment(vec2 P, vec2 A, vec2 B, float r) {
    vec2 g = B - A;
    vec2 h = P - A;
    float d = length(h - g * clamp(dot(g, h) / dot(g, g), 0.0, 1.0));
    return smoothstep(r, 0.5 * r, d);
}

// Function to draw endless line through A and B
float line(vec2 P, vec2 A, vec2 B, float r) {
    vec2 g = B - A;
    float d = abs(dot(normalize(vec2(g.y, -g.x)), P - A));
    return smoothstep(r, 0.5 * r, d);
}

void fragment() {
    vec2 fragCoord = SCREEN_UV * resolution;
    vec2 uv = (fragCoord * 2.0 - resolution) / resolution.y;
    vec2 mo = (mouse * 2.0 - resolution) / resolution.y;

    float thickness = (0.7 + 0.4 * sin(time)) * 0.051;
    vec3 color = BACK_COLOR;

    // Draw endless line
    float intensity = line(uv, vec2(0.0), mo, thickness * 0.5);
    color = mix(color, LINE_COLOR1, intensity);

    // Draw line segment
    intensity = segment(uv, vec2(0.0), mo, thickness);
    color = mix(color, LINE_COLOR2, intensity);

    COLOR = vec4(color, 1.0);
}
