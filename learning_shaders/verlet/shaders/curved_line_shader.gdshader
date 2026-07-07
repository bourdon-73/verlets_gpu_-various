shader_type canvas_item;
render_mode unshaded;

uniform float base_thickness = 20.0;
uniform float time = 0.0;

in float Cus; // this is our t_param from 0.0 to 1.0

void vertex() {
    float t = custom0;

    // Wavy curve
    float wave = sin(t * 6.283 + time) * 20.0;

    // Apply wave curve on Y
    VERTEX.y += wave;

    // Optional: thickness animation — you could scale outward if using normals
}

void fragment() {
    COLOR = COLOR;
}
