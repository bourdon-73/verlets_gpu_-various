#[compute]
#version 460
#extension GL_EXT_shader_atomic_float : enable

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 8;
const vec2 GRAVITY = vec2(0, 500);
const float MAX_VELOCITY = 1000.0;
const float MAX_ACCEL = 500.0;
const float RESPONSE_COEF = 0.70;
const float DAMPING = 0.998;

layout(set = 0, binding = 0) buffer StorageBuffer {
    float data[];
} storage_buffer;

layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer {
    float delta;
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
    float data[]; // read particles from here
} read_particles_buffer;

layout(set = 0, binding = 4) buffer WriteParticle {
    float data[]; // write particles to here
} write_particles_buffer;

// Apply gravity and integrate position
void applyGravity(float dt, inout vec2 pos, inout vec2 last_pos, inout vec2 accel, float radius) {
    // Add gravity
    accel += GRAVITY;
    
    // Clamp acceleration
    float accel_len_sq = dot(accel, accel);
    float max_accel_sq = MAX_ACCEL * MAX_ACCEL;
    
    if (accel_len_sq > max_accel_sq) {
        accel *= sqrt(max_accel_sq / accel_len_sq);
    }
    
    // Verlet integration
    vec2 velocity = pos - last_pos;
    //velocity *= 0.9989; // Small damping each frame
    velocity *= 0.99089; // Small damping each frame
    
    vec2 new_pos = pos + velocity + accel * dt * dt;
    
    // Update positions
    last_pos = pos;
    pos = new_pos;
}

void applyConstraint(inout vec2 pos, inout vec2 last_pos, float radius) {
    const vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    const float constraint_radius = params.bound_radius;
    
    // Vector from position to center
    vec2 v = m_constraint_center - pos;
    float dist = length(v);
    
    // Check if outside boundary
    if (dist > (constraint_radius - radius)) {
        vec2 n = v / dist;
        pos = m_constraint_center - n * (constraint_radius - radius);
    }
}

void solveCollisions2(uint id, inout vec2 pos, inout vec2 last_pos, float radius) {
    float response_coef = 0.75;
    uint objects_count = uint(params.particle_count);
    
    // Iterate over all except self
    for (uint k = 0; k < objects_count; ++k) {
        if (k == id) continue;
        
        // Get other particle data from READ buffer
        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(read_particles_buffer.data[kbase+0], read_particles_buffer.data[kbase+1]);
        float kradius = read_particles_buffer.data[kbase+6];
        
        vec2 delta_pos = pos - kpos;
        float dist2 = dot(delta_pos, delta_pos);
        float min_dist = radius + kradius;
        
        // Check if overlapping and avoid zero distance
        if (dist2 < min_dist * min_dist && dist2 > 0.501) {
            float dist = sqrt(dist2);
            vec2 n = delta_pos / dist;
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);
            float delta = 0.5 * response_coef * (dist - min_dist);
            
            // Only update our position
            pos -= n * (mass_ratio_2 * delta);
            //last_pos = pos;
        }
    }
}

void solveCollisions(uint id, inout vec2 pos, inout vec2 last_pos, float radius) {
    float response_coef = .75;
    vec2 velocity = pos - last_pos;
    uint objects_count = uint(params.particle_count);
        
    // Iterate over all except self
    for (uint k = 0; k < objects_count; ++k) {
        if (k == id) continue;

        // vars for object 2
        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(read_particles_buffer.data[kbase+0], read_particles_buffer.data[kbase+1]);
        float kradius = read_particles_buffer.data[kbase+6];
            
        vec2 v = pos - kpos;
        float dist2 = v.x * v.x + v.y * v.y;
        float min_dist = radius + kradius;
            
        // Check overlapping
        if (dist2 < min_dist * min_dist) {
            float dist = sqrt(dist2);
            vec2 n = v / dist;
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);
            float delta = 0.5 * response_coef * (dist - min_dist);
                
            // Update current particle
            pos -= n * (mass_ratio_2 * delta);
                
            // Update the other particle using atomic operation
            // This is where we need to be careful with concurrent updates
            vec2 kpos_delta = n * (mass_ratio_1 * delta);
                
            // We need atomic operations to safely update the other particle
            atomicAdd(write_particles_buffer.data[kbase+0], kpos_delta.x);
            atomicAdd(write_particles_buffer.data[kbase+1], kpos_delta.y);
        }
    }
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    float dt = params.delta;
    float dt_sub = dt / float(SUBSTEPS);
    
    // Early return checks
    if(bool(params.pause)) return;
    if (id >= uint(params.particle_count)) return;
    
    // Load particle data from READ buffer
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    vec2 accel = vec2(read_particles_buffer.data[base + 4], read_particles_buffer.data[base + 5]);
    float radius = read_particles_buffer.data[base + 6];
    
    // Apply simulation substeps
    for (int i = 0; i < SUBSTEPS; i++) {
        applyGravity(dt_sub, pos, last_pos, accel, radius);
        
        //Skip collision if there's only one particle
        // if (params.particle_count > 1) {
        //     solveCollisions2(id, pos, last_pos, radius);
        // }
        
        applyConstraint(pos, last_pos, radius);
    }
    
    // Reset acceleration for next frame
    accel = vec2(0.0);
    
    // Write results to WRITE buffer
    read_particles_buffer.data[base + 0] = pos.x;
    read_particles_buffer.data[base + 1] = pos.y;
    read_particles_buffer.data[base + 2] = last_pos.x;
    read_particles_buffer.data[base + 3] = last_pos.y;
    read_particles_buffer.data[base + 4] = accel.x;
    read_particles_buffer.data[base + 5] = accel.y;
    
    // // Copy other data (radius, color) from read to write buffer
    // write_particles_buffer.data[base + 6] = read_particles_buffer.data[base + 6];  // radius
    // write_particles_buffer.data[base + 7] = read_particles_buffer.data[base + 7];  // padding
    // write_particles_buffer.data[base + 8] = read_particles_buffer.data[base + 8];  // color r
    // write_particles_buffer.data[base + 9] = read_particles_buffer.data[base + 9];  // color g
    // write_particles_buffer.data[base + 10] = read_particles_buffer.data[base + 10]; // color b
    // write_particles_buffer.data[base + 11] = read_particles_buffer.data[base + 11]; // color a
    
    // Write debug info to storage buffer
    storage_buffer.data[id] = float(pos.x);
}