#[compute]
#version 460
#extension GL_EXT_shader_atomic_float : enable

// before I use two buffers 
// ping pong shit
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

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


// #####
// #####
// #####



void process_base_forces(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    
    // Calculate implicit velocity (no need to normalize by prev_dt)
    vec2 velocity = pos - last_pos;
    
    
    velocity *= params.velocityDamping;
    
    // Apply maximum velocity constraint
    float speed = length(velocity);
    if (speed > MAX_VELOCITY * dt) {
        velocity = (velocity / speed) * MAX_VELOCITY * dt;
    }
    
    // Gravity in Verlet is applied directly to position
    vec2 gravity_offset = vec2(0, 1) * (9.8 * GRAVITY_MULT * dt * dt);
    
    // Calculate new position using Verlet integration
    vec2 new_pos = pos + velocity + gravity_offset;
    
    // Store results
    read_particles_buffer.data[base] = new_pos.x;
    read_particles_buffer.data[base + 1] = new_pos.y;
    read_particles_buffer.data[base + 2] = pos.x;
    read_particles_buffer.data[base + 3] = pos.y;
}

void process_base_forces2(uint id, float dt, float prev_dt) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);

    vec2 velocity = (pos - last_pos) / prev_dt;
    
    // Apply gravity (without multiplying by damping)
    velocity += (9.8*GRAVITY_MULT) * dt * vec2(0, 1);
    
    // Apply damping separately
    velocity *= params.velocityDamping;
    
    // Apply maximum velocity constraint
    float speed = length(velocity);
    if (speed > MAX_VELOCITY) {
        velocity = (velocity / speed) * MAX_VELOCITY; // Normalize and scale to max velocity
    }

    // Calculate new position
    vec2 new_pos = pos + velocity * dt;
    vec2 new_last_pos = pos;
    
    // Update the position history (current pos becomes last pos)
    
    // Write updated values to buffer
    read_particles_buffer.data[base + 0] = new_pos.x;
    read_particles_buffer.data[base + 1] = new_pos.y;
    
    read_particles_buffer.data[base + 2] = new_last_pos.x;
    read_particles_buffer.data[base + 3] = new_last_pos.y;
}

void applyConstraint(uint id, float radius, vec2 c_center, float c_radius) {
    
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 m_constraint_center = c_center;//vec2(params.bounds_x, params.bounds_y);
    float constraint_radius = c_radius;//params.bound_radius;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    const float epsilon = 0.01; // Small offset to avoid precision issues
    
    // Use vector subtraction directly - no need for intermediate values
    vec2 v = m_constraint_center - pos;
    //float dist = sqrt(v.x * v.x + v.y * v.y);
    float dist = length(v);
    //float boundary_sq = boundary * boundary;
    
    // Only compute sqrt if needed (particle is outside boundary)
    if (dist > (constraint_radius - radius)-EPSILON) {

        vec2 n = v / dist;
        vec2 poss = m_constraint_center - n * (constraint_radius - radius);
        read_particles_buffer.data[base + 0] = poss.x;
        read_particles_buffer.data[base + 1] = poss.y;
        // lerp last position

        // vec2 start = m_constraint_center - n * (constraint_radius - radius);
        // vec2 temp_last_pos = last_pos;
        //last_pos = start;//mix(temp_last_pos, start, 5);

    }

    
}



void CheckCollision(uint index, uint id2)
{
    //const float3 objectPos = _positionBuffer[index];
    uint base = index * FLOATS_PER_PARTICLE;
    vec2 pos1 = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 lastpos1 = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);

    //const float3 collisionPos = _positionBuffer[id2];
    uint base2 = id2 * FLOATS_PER_PARTICLE;
    vec2 pos2 = vec2(read_particles_buffer.data[base2 + 0], read_particles_buffer.data[base2 + 1]);
    vec2 lastpos2 = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);

    // float currentDistance = length(pos2 - pos1);
    // const float desiredDistance = DIAMETER;

    vec2 v = pos1 - pos2;
    float dist2 = v.x * v.x + v.y * v.y;

    float radius = read_particles_buffer.data[base+6];
    float kradius = read_particles_buffer.data[base2+6];
    float min_dist = radius + kradius;
        
    // Check overlapping
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

        // read_particles_buffer.data[base + 2] = pos1.x;
        // read_particles_buffer.data[base + 3] = pos1.y;


        read_particles_buffer.data[base2 + 0] += obj2_pos.x;
        read_particles_buffer.data[base2 + 1] += obj2_pos.y;

        // read_particles_buffer.data[base + 2] = pos2.x;
        // read_particles_buffer.data[base + 3] = pos2.y;

    }
}

void CollisionDetection(uint id) 
{
    if (params.particle_count <= 1) return; // No collision pairs if <=1

    uint N = uint(params.particle_count);
    uint pairs_before = (N - 1) * id - (id * (id - 1)) / 2;
    uint base_storage_index = pairs_before * 2;

    for (uint i = 0; i < (N - 1) - id; i++) {
        uint storage_index = base_storage_index + i * 2;
        storage_buffer.data[storage_index + 0] = float(id);     // FIRST particle
        storage_buffer.data[storage_index + 1] = float(id + i + 1); // SECOND particle
        CheckCollision(id, id + i + 1);
    }
}

void CollisionDetection_Pass1(uint id) {
    if (params.particle_count <= 1) return; // No collision pairs if <=1

    uint N = uint(params.particle_count);
    for (uint i = 0; i < (N - 1) - id; i++) {
        uint other_id = id + i + 1;
        
        // Check collision using existing particle data
        uint base_a = id * FLOATS_PER_PARTICLE;
        uint base_b = other_id * FLOATS_PER_PARTICLE;
        
        vec2 pos_a = vec2(read_particles_buffer.data[base_a + 0], read_particles_buffer.data[base_a + 1]);
        vec2 pos_b = vec2(read_particles_buffer.data[base_b + 0], read_particles_buffer.data[base_b + 1]);
        float radius_a = read_particles_buffer.data[base_a + 6];
        float radius_b = read_particles_buffer.data[base_b + 6];
        
        vec2 delta = pos_a - pos_b;
        float dist_squared = dot(delta, delta);
        float min_dist = radius_a + radius_b;
        
        if (dist_squared < (min_dist * min_dist) - EPSILON) {
            // Just store the IDs of colliding particles
            uint index = atomicAdd(counter, 1u);
            //uint index = atomicAdd(counter, 1u);
            collision_data.data[index].id_a = id;
            collision_data.data[index].id_b = other_id;

        }
    }
}

void CollisionResolution_Pass2(uint id) {
    vec2 total_displacement = vec2(0.0);
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    float radius = read_particles_buffer.data[base + 6];
    
    // Process all collisions involving this particle
    for (uint i = 0; i < counter; i++) {
        uint other_id;
        bool is_first_particle = false;
        
        // Check if this particle is involved in this collision
        if (collision_data.data[i].id_a == id) {
            other_id = collision_data.data[i].id_b;
            is_first_particle = true;
        } 
        else if (collision_data.data[i].id_b == id) {
            other_id = collision_data.data[i].id_a;
            is_first_particle = false;
        }
        else {
            // Not involved in this collision
            continue;
        }
        
        // Recalculate collision data from particle positions
        uint base_other = other_id * FLOATS_PER_PARTICLE;
        vec2 pos_other = vec2(read_particles_buffer.data[base_other + 0], 
                             read_particles_buffer.data[base_other + 1]);
        float radius_other = read_particles_buffer.data[base_other + 6];
        
        // Calculate collision response
        vec2 delta = pos - pos_other;
        float dist = length(delta);
        float min_dist = radius + radius_other;
        
        if (dist < min_dist - EPSILON) {  // Double-check collision is still valid
            vec2 normal = delta / dist;
            float penetration = min_dist - dist;
            
            float mass_ratio = is_first_particle ? 
                (radius_other / (radius + radius_other)) : 
                (radius / (radius + radius_other));
                
            total_displacement += normal * (mass_ratio * RESPONSE_COEF * penetration * 0.5);
        }
    }
    
    // Apply accumulated displacement once
    read_particles_buffer.data[base + 0] += total_displacement.x;
    read_particles_buffer.data[base + 1] += total_displacement.y;
}


void main() {
    uint id = gl_GlobalInvocationID.x;
    float dt = params.delta;
    float prev_dt = params.prevDeltaTime;
    float dt2 = dt*dt;
    float prev_dt2 = prev_dt*prev_dt;
    float dt_sub = dt / float(SUBSTEPS);
    
    // Early return for out-of-bounds particles
    if(bool(params.pause)) return;
    if (id >= uint(params.particle_count)) return;
    
    // Load particle data once (avoids repeated memory access)
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
    float radius = read_particles_buffer.data[base + 6];
    
    vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    float constraint_radius = params.bound_radius;


    // Apply simulation substeps
    for (int i = 0; i < SUBSTEPS; i++) {
        // Apply gravity and integration
        //applyGravity(id, dt_sub, pos, last_pos, accel, radius);
        process_base_forces(id,dt_sub);
 
        // USE PAIRS FOR COLLISIONS IF YOU EVER DO VERLETS IN COMPUTE WHICH YOU SHOULD NOT BTW 
        CollisionDetection(id);
        applyConstraint(id, radius,m_constraint_center, constraint_radius  );
    }
    
}

// void main() {
//     uint id = gl_GlobalInvocationID.x;
//     float dt = params.delta;
//     float prev_dt = params.prevDeltaTime;
//     float dt2 = dt*dt;
//     float prev_dt2 = prev_dt*prev_dt;
//     float dt_sub = dt / float(SUBSTEPS);
    
//     // Early return for out-of-bounds particles
//     if(bool(params.pause)) return;
//     if (id >= uint(params.particle_count)) return;
    
//     // Load particle data once (avoids repeated memory access)
//     uint base = id * FLOATS_PER_PARTICLE;
//     vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
//     vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
//     vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
//     float radius = read_particles_buffer.data[base + 6];
    
//     vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
//     float constraint_radius = params.bound_radius;


//     // Apply simulation substeps
//     for (int i = 0; i < SUBSTEPS; i++) {
//         // Apply gravity and integration
//         //applyGravity(id, dt_sub, pos, last_pos, accel, radius);
//         process_base_forces(id,dt);
 
//         // USE PAIRS FOR COLLISIONS IF YOU EVER DO VERLETS IN COMPUTE WHICH YOU SHOULD NOT BTW 
//         //CollisionDetection(id);
//         if (id == 0) counter = 0;
//         memoryBarrier();
//         barrier();
//         CollisionDetection_Pass1(id);

//         CollisionResolution_Pass2(id);
//         applyConstraint(id, radius,m_constraint_center, constraint_radius  );
//     }
    
// }


// void main() {
//     uint id = gl_GlobalInvocationID.x;
//     float dt = params.delta;
//     float prev_dt = params.prevDeltaTime;
//     float dt2 = dt*dt;
//     float prev_dt2 = prev_dt*prev_dt;
//     float dt_sub = dt / float(SUBSTEPS);
    
//     // Early return for out-of-bounds particles
//     if(bool(params.pause)) return;
//     if (id >= uint(params.particle_count)) return;
    
//     // Load particle data once (avoids repeated memory access)
//     uint base = id * FLOATS_PER_PARTICLE;
//     vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
//     vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
//     vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
//     float radius = read_particles_buffer.data[base + 6];
    
//     vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
//     float constraint_radius = params.bound_radius;


//     // Apply simulation substeps
// for (int i = 0; i < SUBSTEPS; i++) {
//         // 1. Apply forces
//         process_base_forces(id, dt);
        
//         // === FIRST SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all threads to finish forces
        
//         // 2. Reset counter and prepare for collision detection
//         if (id == 0) {
//             counter = 0;
//         }
        
//         // === SECOND SYNCHRONIZATION POINT ===
//         barrier();  // Make sure counter is reset before proceeding
        
//         // 3. Collision detection phase
//         CollisionDetection_Pass1(id);
        
//         // === THIRD SYNCHRONIZATION POINT ===
//         barrier();  // Wait for ALL collision detections to complete
        
//         // 4. Collision resolution phase
//         CollisionResolution_Pass2(id);
        
//         // === FOURTH SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all collision resolutions to complete
        
//         // 5. Apply constraints
//         applyConstraint(id, radius, m_constraint_center, constraint_radius);
        
//         // === FIFTH SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all constraint applications to finish
//     }
    
// }

// void main() {
//     uint id = gl_GlobalInvocationID.x;
//     float dt = params.delta;
    
//     // Early return checks
//     if(bool(params.pause)) return;
//     if (id >= uint(params.particle_count)) return;
    
//     // Load particle data
//     uint base = id * FLOATS_PER_PARTICLE;
//     // ... [load other data] ...
    
//     // Apply simulation substeps
//     for (int i = 0; i < SUBSTEPS; i++) {
//         // 1. Apply forces
//         process_base_forces(id, dt);
        
//         // === FIRST SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all threads to finish forces
        
//         // 2. Reset counter and prepare for collision detection
//         if (id == 0) {
//             counter = 0;
//         }
        
//         // === SECOND SYNCHRONIZATION POINT ===
//         barrier();  // Make sure counter is reset before proceeding
        
//         // 3. Collision detection phase
//         CollisionDetection_Pass1(id);
        
//         // === THIRD SYNCHRONIZATION POINT ===
//         barrier();  // Wait for ALL collision detections to complete
        
//         // 4. Collision resolution phase
//         CollisionResolution_Pass2(id);
        
//         // === FOURTH SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all collision resolutions to complete
        
//         // 5. Apply constraints
//         applyConstraint(id, radius, m_constraint_center, constraint_radius);
        
//         // === FIFTH SYNCHRONIZATION POINT ===
//         barrier();  // Wait for all constraint applications to finish
//     }
// }