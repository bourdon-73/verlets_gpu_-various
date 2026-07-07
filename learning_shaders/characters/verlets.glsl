#[compute]

#version 460


layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 4;
const float MAX_VELOCITY = 20000;
const float RESPONSE_COEF = 0.20;
const float GRAVITY_MULT = 150.0;
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

void process_base_forces(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    
    vec2 velocity = pos - last_pos;
    velocity *= params.velocityDamping;
    float speed = length(velocity);
    if (speed > MAX_VELOCITY * dt) {
        velocity = (velocity / speed) * MAX_VELOCITY * dt;
    }
    
    vec2 gravity_offset = vec2(0, 1) * (9.8 * GRAVITY_MULT * dt * dt);
    
    vec2 new_pos = pos + velocity + gravity_offset;
    
    read_particles_buffer.data[base] = new_pos.x;
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
        
	if (dist2 < (min_dist * min_dist) - EPSILON) {
		float dist = sqrt(dist2);
		vec2 normal = v / dist;
        float mass_ratio_1 = radius / (radius + kradius);
        float mass_ratio_2 = kradius / (radius + kradius);
		float delta = 0.5 * RESPONSE_COEF * (dist - min_dist);
		
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
        storage_buffer.data[storage_index + 0] = float(id);
        storage_buffer.data[storage_index + 1] = float(id + i + 1);
        CheckCollision(id, id + i + 1);
    }
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    float dt = params.delta;
    float prev_dt = params.prevDeltaTime;
    float dt2 = dt*dt;
    float prev_dt2 = prev_dt*prev_dt;
    float dt_sub = dt / float(SUBSTEPS);
    
    if(bool(params.pause)) return;
    if (id >= uint(params.particle_count)) return;
    
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
    float radius = read_particles_buffer.data[base + 6];
    
    vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    float constraint_radius = params.bound_radius;

    for (int i = 0; i < SUBSTEPS; i++) {
        process_base_forces(id, dt_sub);
        CollisionDetection(id);
        applyConstraint(id, radius, m_constraint_center, constraint_radius);
    }
}