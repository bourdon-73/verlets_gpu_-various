const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 8;
const float MAX_VELOCITY = 2000;
const float RESPONSE_COEF = 0.10;
const float GRAVITY_MULT = 10.0;
const float EPSILON = .001;


struct Particle {
    vec2 pos;
    vec2 last_pos;
    vec2 accel;
    float radius;
    float pad0; // padding for alignment
    vec4 color;
};

struct CollisionPair {
    uint id_a;
    uint id_b;
};


layout(set = 0, binding = 0) buffer StorageBuffer {
    float data[];
} storage_buffer;

layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer {
    float delta;
    float prevDeltaTime;
    float velocityDamping;
    float particle_count;
    float bound_radius;
    float bounds_x;
    float bounds_y;
    float pause;

} params;

layout(set = 0, binding = 2) buffer PosBuffer {
    float data[];
} pos_buffer;

layout(set = 0, binding = 3) buffer ReadParticles {
    float data[]; // the whole big float array!
} read_particles_buffer;

layout(set = 0, binding = 4) buffer WriteParticle {
    float data[]; // the whole big float array!
} write_particles_buffer;


layout(set = 0, binding = 5) buffer CollisionData {
    CollisionPair data[];
} collision_data;


layout(set = 0, binding = 6, std430) coherent buffer Counter
{
	uint counter;
};
