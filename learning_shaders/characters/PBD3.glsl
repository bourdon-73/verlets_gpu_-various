#[compute]

#version 460

layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 8;
const float MAX_VELOCITY = 500;
const float RESPONSE_COEF = 0.40;
const float GRAVITY_MULT = 20.0;
const float EPSILON = .01;

struct Particle {
    vec2 pos;
    vec2 last_pos;
    vec2 accel;
    float radius;
    float pad0;
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
    float mouse_x;
    float mouse_y;
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

layout(rgba32f, binding = 7) uniform writeonly image2D Particle_Pos;

layout(rgba32f, binding = 8) uniform writeonly image2D Particle_Color;


void process_base_forces(uint id, float dt_sub) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    
    // Calculate velocity based on current and previous position
    vec2 velocity = pos - last_pos;
    
    // Apply damping - scaled appropriately for substeps
    // For substeps, we want (damping^substeps) = params.velocityDamping
    // So we use pow(params.velocityDamping, 1/SUBSTEPS) for each substep
    float substep_damping = pow(params.velocityDamping, 1.0/float(SUBSTEPS));
    velocity *= substep_damping;
    
    // Limit velocity - scale max velocity by dt_sub
    float max_vel_scaled = MAX_VELOCITY * dt_sub;
    float speed = length(velocity);
    if (speed > max_vel_scaled) {
        velocity = (velocity / speed) * max_vel_scaled;
    }
    
    // Gravity uses dt_sub^2 for verlet integration
    vec2 gravity_offset = vec2(0, 1) * (9.8 * GRAVITY_MULT * dt_sub * dt_sub);
    
    // Update position using verlet integration
    vec2 new_pos = pos + velocity + gravity_offset;
    
    // Update particle data
    read_particles_buffer.data[base + 0] = new_pos.x;
    read_particles_buffer.data[base + 1] = new_pos.y;
    read_particles_buffer.data[base + 2] = pos.x;
    read_particles_buffer.data[base + 3] = pos.y;
}

void applyConstraint(uint id, float radius, vec2 c_center, float c_radius) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 m_constraint_center = c_center;
    float constraint_radius = c_radius;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    
    vec2 v = m_constraint_center - pos;
    float dist = length(v);
    

    float tolerance = max(1e-6, (constraint_radius - radius) * 0.01);
    if (dist > (constraint_radius - radius)-EPSILON) {
        vec2 n = v / dist;
        vec2 poss = m_constraint_center - n * (constraint_radius - radius);
        read_particles_buffer.data[base + 0] = poss.x;
        read_particles_buffer.data[base + 1] = poss.y;
    }
}

void CheckCollision(uint index, uint id2) {
    uint base = index * FLOATS_PER_PARTICLE;
    vec2 pos1 = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 lastpos1 = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);

    uint base2 = id2 * FLOATS_PER_PARTICLE;
    vec2 pos2 = vec2(read_particles_buffer.data[base2 + 0], read_particles_buffer.data[base2 + 1]);
    vec2 lastpos2 = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);

    vec2 v = pos1 - pos2;
    float dist2 = v.x * v.x + v.y * v.y;

    float radius = read_particles_buffer.data[base+6];
    float kradius = read_particles_buffer.data[base2+6];
    float min_dist = radius + kradius;
    float scaled_res_coef = RESPONSE_COEF / SUBSTEPS;        

    float tolerance = max(1e-6, min_dist * 0.01);
    //if (dist2 < (min_dist * min_dist) - tolerance){
	if (dist2 < (min_dist * min_dist) - EPSILON) {
		float dist = sqrt(dist2);
		vec2 normal = v / dist;
        float mass_ratio_1 = radius / (radius + kradius);
        float mass_ratio_2 = kradius / (radius + kradius);
		float delta = 0.5 * scaled_res_coef * (dist - min_dist);
		
		vec2 obj1_pos = normal * (mass_ratio_2 * delta);
		vec2 obj2_pos = normal * (mass_ratio_1 * delta);

        read_particles_buffer.data[base + 0] -= obj1_pos.x;
        read_particles_buffer.data[base + 1] -= obj1_pos.y;

        read_particles_buffer.data[base2 + 0] += obj2_pos.x;
        read_particles_buffer.data[base2 + 1] += obj2_pos.y;
    }
}

void CollisionDetection(uint id) {
    if (params.particle_count <= 1) return;

    uint N = uint(params.particle_count);
    uint pairs_before = (N - 1) * id - (id * (id - 1)) / 2;
    uint base_storage_index = pairs_before * 2;

    for (uint i = 0; i < (N - 1) - id; i++) {
        uint storage_index = base_storage_index + i * 2;
        //storage_buffer.data[storage_index + 0] = float(id);
        //storage_buffer.data[storage_index + 1] = float(id + i + 1);
        CheckCollision(id, id + i + 1);
    }
}

vec4 Write_to_image(uint index){
    uint base = index * FLOATS_PER_PARTICLE;

    float x = read_particles_buffer.data[base + 0];
    float y = read_particles_buffer.data[base + 1];
    float radius = read_particles_buffer.data[base + 6];
    vec4 pos = vec4(x, y, 0.0, radius); 
    return pos;

}

void main() {
    uvec2 gid = gl_GlobalInvocationID.xy;

    uint idd = gl_GlobalInvocationID.x;
    //uint id = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * //100;//params.texture_width;
    uint id = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * gl_WorkGroupSize.x * gl_NumWorkGroups.x;
    float dt = params.delta;
    float prev_dt = params.prevDeltaTime;
    float dt2 = dt*dt;
    float prev_dt2 = prev_dt*prev_dt;
    float dt_sub = dt / float(SUBSTEPS);
    
    if(bool(params.pause)) return;
    if (id >= uint(params.particle_count)) return;
    
    uint base = id * FLOATS_PER_PARTICLE;
    // vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    // vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    // vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
    float radius = read_particles_buffer.data[base + 6];
    
    vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    float constraint_radius = params.bound_radius;

    for (int i = 0; i < SUBSTEPS; i++) {
        process_base_forces(id, dt_sub);
        CollisionDetection(id);
        applyConstraint(id, radius, m_constraint_center, constraint_radius);
    }

    // bool skip = (id % 2u) == 1u;
    vec4 data = vec4(1.0, 0.0, 0.0, 1.0);

    // if (skip) {
    //     data = vec4(1.0, 0.0, 1.0, 1.0);
    // } else {
    //     data = vec4(500.0, 150.0, 1.0, 1.0);
    //     //data = vec4(0.0, 1.0, 1.0, 1.0);

    // }

    data = Write_to_image(id);
    if (id == 4){
    } 
    
    
    //data = vec4(params.mouse_x, params.mouse_y, 0.0, 1.0);
    // read_particles_buffer.data[base + 0] = float(params.mouse_x);
    // read_particles_buffer.data[base + 1] = float(params.mouse_y);



    imageStore(Particle_Pos, ivec2(gid), data);
    //storage_buffer.data[id] = id;

}