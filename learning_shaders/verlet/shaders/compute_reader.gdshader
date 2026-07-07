shader_type canvas_item;

uniform vec2 offset = vec2(10.0, 10.0);
uniform float spacing = 30.0;
uniform float wave_speed = 3.0;
uniform float wave_height = 10.0;
uniform float time : hint_range(0, 100);

// Access the computed data (assumed to be passed as a uniform or buffer)
uniform float data_buffer[100];  // Assuming a max of 100 instances

void vertex() {
    float id = float(INSTANCE_ID); // Unique per instance

    // Use the computed `y_offset` from the data_buffer
    float y_offset = data_buffer[int(id)];

    // Final position for this instance
    vec2 instance_pos = vec2(id * spacing, y_offset) + offset;

    // Debugging: Output color based on ID and position
    COLOR = vec4(abs(sin(id * 0.2)), abs(cos(id * 0.2)), 0.5, 1.0); // Color changes based on ID

    // Move the vertex!
    VERTEX += instance_pos;
}
