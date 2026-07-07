#[compute]
#version 460
#extension GL_EXT_shader_atomic_float : enable

// before I use two buffers 
// ping pong shit
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 24;
const vec2 GRAVITY = vec2(0, 500);
const float MAX_VELOCITY = 500.0;
const float MAX_ACCEL = 500.0;
const float RESPONSE_COEF = 0.70;
const float DAMPING = 0.998;


struct Particle {
    vec2 pos;
    vec2 last_pos;
    vec2 accel;
    float radius;
    float pad0; // padding for alignment
    vec4 color;
};

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
    float data[]; // the whole big float array!
} read_particles_buffer;

layout(set = 0, binding = 4) buffer WriteParticle {
    float data[]; // the whole big float array!
} write_particles_buffer;










// Apply gravity and integrate position
void applyGravity(uint id, float dt, inout vec2 pos, inout vec2 last_pos, inout vec2 accel, float radius) {
    // Add gravity
    accel += GRAVITY;
    
    // Clamp acceleration - use squared magnitude comparison for performance
    float accel_len_sq = dot(accel, accel);
    float max_accel_sq = MAX_ACCEL * MAX_ACCEL;
    
    if (accel_len_sq > max_accel_sq) {
        accel *= sqrt(max_accel_sq / accel_len_sq); // Only use sqrt when actually needed
    }

    
    // Verlet integration
    vec2 velocity = pos - last_pos;
    velocity *= 0.9989; // Small damping each frame
    //pos += velocity;
    vec2 new_pos = pos + velocity + accel * dt * dt;
    

    // Update positions
    last_pos = pos;
    pos = new_pos;
    
    // Clear acceleration for next frame
    accel = vec2(0.0);
}

// Apply constraint keeping particles within a circle
// void applyConstraint2(inout vec2 pos, inout vec2 last_pos, float radius) {
//     // Calculate velocity before constraint
//     vec2 velocity = pos - last_pos;
    
//     const vec2 center = vec2(500, -200);
//     const float constraint_radius = 100.0;
//     const float boundary = constraint_radius - radius;
//     const float epsilon = 0.01; // Small offset to avoid precision issues
    
//     // Use vector subtraction directly - no need for intermediate values
//     vec2 to_center = center - pos;
//     float dist_sq = dot(to_center, to_center);
//     float boundary_sq = boundary * boundary;
    
//     // Only compute sqrt if needed (particle is outside boundary)
//     if (dist_sq > boundary_sq) {
//         float dist = sqrt(dist_sq);
//         vec2 n = to_center / dist;
        
//         // Place particle at boundary
//         pos = center - n * (boundary - epsilon);
        
//         // For sliding: project velocity onto the tangent
//         vec2 tangent = vec2(-n.y, n.x); // Perpendicular to normal
        
//         // Project velocity onto the tangent (preserve tangential component)
//         float tangential_velocity = dot(velocity, tangent);
        
//         // Apply minimal friction
//         tangential_velocity *= DAMPING;
        
//         // Rebuild velocity using only tangential component
//         vec2 new_velocity = tangent * tangential_velocity;
        
//         // Update last_pos to maintain new velocity
//         last_pos = pos - new_velocity;
//     }
// }

void applyConstraint(inout vec2 pos, inout vec2 last_pos, float radius) {
    // Calculate velocity before constraint
    vec2 velocity = pos - last_pos;
    
    const vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    const float constraint_radius = params.bound_radius;
    const float boundary = constraint_radius - radius;
    const float epsilon = 0.01; // Small offset to avoid precision issues
    
    // Use vector subtraction directly - no need for intermediate values
    vec2 v = m_constraint_center - pos;
    //float dist = sqrt(v.x * v.x + v.y * v.y);
    float dist = length(v);
    //float boundary_sq = boundary * boundary;
    
    // Only compute sqrt if needed (particle is outside boundary)
    if (dist > (constraint_radius - radius)) {

        vec2 n = v / dist;
        pos = m_constraint_center - n * (constraint_radius - radius);

        // lerp last position

        vec2 start = m_constraint_center - n * (constraint_radius - radius);
        vec2 temp_last_pos = last_pos;
        //last_pos = start;//mix(temp_last_pos, start, 5);

    }
}


void solveCollisions3(uint id, inout vec2 pos, inout vec2 last_pos, float radius) {
    float response_coef = .75;
    //response_coef = .05;
    vec2 velocity = pos - last_pos;
    uint objects_count = uint(params.particle_count);
        
            // Iterate over all except self
            for (uint k = 0; k < objects_count; ++k) {
                if (k == id) continue;

                // vars for object 2
                uint kbase = k * FLOATS_PER_PARTICLE;
                vec2 kpos = vec2(read_particles_buffer.data[kbase+0], read_particles_buffer.data[kbase+1]);
                float kradius = read_particles_buffer.data[kbase+6];
                vec2 temp_pos = pos; 

                vec2 v = pos - kpos;
                float dist2 = v.x * v.x + v.y * v.y;
                //float mum = leng
                float min_dist = radius + kradius;
                //last_pos = pos;
                // Check overlapping
                if (dist2 < min_dist * min_dist) {
                    float dist  = sqrt(dist2);
                    vec2 n = v / dist;
                    float mass_ratio_1 = radius / (radius + kradius);
                    float mass_ratio_2 = kradius / (radius + kradius);
                    float delta = 0.5 * response_coef * (dist - min_dist); // .5 is sharing displacement equally 
                    // Update positions
                    //pos -= n * ((mass_ratio_2) * delta)*.5;
                    pos -= n * (mass_ratio_2 * delta);


                }
            }
}


void solveCollisions2(uint id, inout vec2 pos, inout vec2 last_pos, float radius) {
    float response_coef = 0.75;  // Keep the response coefficient, but you can tweak it for smoother collisions.
    float damping_factor = 0.98;  // Damping factor for velocity (between 0 and 1)
    float max_velocity = 10.0;   // Maximum velocity to prevent particles from exploding.
    
    vec2 velocity = pos - last_pos;  // Calculate velocity
    uint objects_count = uint(params.particle_count);
    
    // Iterate over all other particles (except self)
    for (uint k = 0; k < objects_count; ++k) {
        if (k == id) continue;  // Skip the current particle

        // Vars for object 2 (the other particle)
        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(read_particles_buffer.data[kbase + 0], read_particles_buffer.data[kbase + 1]);
        float kradius = read_particles_buffer.data[kbase + 6];
        
        vec2 v = pos - kpos;  // Vector from the current particle to the other particle
        float dist2 = v.x * v.x + v.y * v.y;  // Squared distance between particles
        float min_dist = radius + kradius;  // Minimum distance before collision

        // Check if particles are overlapping
        if (dist2 < min_dist * min_dist) {
            float dist = sqrt(dist2);  // Actual distance between particles
            vec2 n = v / dist;  // Normalized vector pointing from the other particle to this one

            // Calculate mass ratio (so that each particle contributes to the correction)
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);

            // Calculate displacement based on response coefficient and the overlap distance
            float delta = 0.5 * response_coef * (dist - min_dist);  // Half the overlap to avoid double correction
            pos -= n * (mass_ratio_2 * delta);  // Move this particle by its mass ratio

            // Apply damping to velocity (reduces bouncing and jittering)
            velocity *= damping_factor;  // Reduce the velocity by the damping factor

            // Clamp velocity to prevent excessive speed (exploding particles)
            if (length(velocity) > max_velocity) {
                velocity = normalize(velocity) * max_velocity;  // Set velocity to max if it exceeds
            }

            // Update last position based on the new velocity after damping
            last_pos = pos - velocity;
        }
    }

    // Apply final velocity update to position
    pos = last_pos + velocity;  // Update the particle's position based on the velocity
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
    float dt2 = dt*dt;
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
    
    // Apply simulation substeps
    for (int i = 0; i < SUBSTEPS; i++) {
        // Apply gravity and integration
        applyGravity(id, dt_sub, pos, last_pos, accel, radius);
        
        // Skip collision if there's only one particle
        if (params.particle_count > 1) {
            solveCollisions(id, pos, last_pos, radius);
        }
        
        // Apply constraint
        applyConstraint(pos, last_pos, radius);
    }
    



    // Write back to memory just once after all calculations
    read_particles_buffer.data[base + 0] = pos.x;
    read_particles_buffer.data[base + 1] = pos.y;
    read_particles_buffer.data[base + 2] = last_pos.x;
    read_particles_buffer.data[base + 3] = last_pos.y;
    read_particles_buffer.data[base + 4] = accel.x;
    read_particles_buffer.data[base + 5] = accel.y;
    
    // Write debug info to storage buffer
    storage_buffer.data[id] = float(params.particle_count);
}

