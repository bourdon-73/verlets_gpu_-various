shader_type canvas_item;

uniform vec2 offset = vec2(10.0, 10.0); // base position offset
uniform float spacing = 30.0; // horizontal spacing between instances
uniform float wave_speed = 3.0;
uniform float wave_height = 10.0;
uniform float time : hint_range(0, 100); // updated from GDScript





void vertex() {
    float id = float(INSTANCE_ID); // unique per instance

    // Vertical wave motion
    float y_offset = sin(id + time * wave_speed) * wave_height;

    // Final position for this instance
    vec2 instance_pos = vec2(id * spacing, y_offset) + offset;

    // Debugging: Output color based on ID and position
    COLOR = vec4(abs(sin(id * 0.1)), abs(cos(id * 0.1)), 0.5, 1.0); // Color changes based on ID

    // Move the vertex!
    VERTEX += instance_pos;
}
