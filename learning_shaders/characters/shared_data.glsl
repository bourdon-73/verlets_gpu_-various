
//███▓▒░ PARTICLES ·•· ░▒▓███//


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
    float data[];
} read_particles_buffer;

layout(set = 0, binding = 4) buffer WriteParticle {
    float data[];
} write_particles_buffer;

layout(set = 0, binding = 5) buffer CollisionData {
    CollisionPair data[];
} collision_data;

layout(set = 0, binding = 6, std430) coherent buffer Counter {
	uint counter;
};

layout(rgba32f, binding = 7) uniform writeonly image2D PARTICLE_CENTER;

//layout(rgba32f, binding = 5) uniform writeonly image2D CTRLPoints;