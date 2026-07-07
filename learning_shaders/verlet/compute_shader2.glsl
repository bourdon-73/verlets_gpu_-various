#[compute]

#version 450

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 4;
const vec2 GRAVITY = vec2(0, 500);
const float RESPONSE_COEF = 0.75;

struct Particle {
    vec2 pos;
    vec2 last_pos;
    vec2 accel;
    float radius;
    float pad0; // padding for alignment
    vec4 color;
};

layout(set = 0, binding = 0) buffer StorageBuffer {
    float data[];  // flattened position data
}storage_buffer;

layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer
{
    float delta;
    float particle_count;  // Add this line to track actual particle count
} params;

layout(set = 0, binding = 2) buffer PosBuffer {
    float data[];  // flattened position data
}pos_buffer;

layout(set = 0, binding = 3) buffer Particles {
    float data[]; // the whole big float array!
}particles_buffer;

// Shared memory for particle data access during collision detection
shared float shared_positions[256 * 3]; // x, y, radius for up to 256 particles

void solveCollisions() {
    uint id = gl_GlobalInvocationID.x;
    if (id >= uint(params.particle_count)) {
        return;
    }
    
    uint base = id * FLOATS_PER_PARTICLE;
    float pos_x = particles_buffer.data[base + 0];
    float pos_y = particles_buffer.data[base + 1];
    float radius = particles_buffer.data[base + 6];
    
    // Load positions into shared memory for faster access
    uint local_id = gl_LocalInvocationID.x;
    if (local_id < 256) {
        shared_positions[local_id * 3 + 0] = pos_x;
        shared_positions[local_id * 3 + 1] = pos_y;
        shared_positions[local_id * 3 + 2] = radius;
    }
    
    barrier(); // Wait for all threads to load data
    
    // Check collisions with all particles that have higher IDs (to avoid duplicate checks)
    for (uint j = id + 1; j < uint(params.particle_count); j++) {
        float other_x, other_y, other_radius;
        
        if (j < gl_WorkGroupSize.x * gl_NumWorkGroups.x) {
            uint other_local_id = j % 256;
            // Use shared memory for threads in the same work group
            if (other_local_id < 256 && j / 256 == id / 256) {
                other_x = shared_positions[other_local_id * 3 + 0];
                other_y = shared_positions[other_local_id * 3 + 1];
                other_radius = shared_positions[other_local_id * 3 + 2];
            } else {
                // Otherwise fetch from global memory
                uint other_base = j * FLOATS_PER_PARTICLE;
                other_x = particles_buffer.data[other_base + 0];
                other_y = particles_buffer.data[other_base + 1];
                other_radius = particles_buffer.data[other_base + 6];
            }
            
            // Calculate distance
            vec2 v = vec2(pos_x - other_x, pos_y - other_y);
            float dist2 = v.x * v.x + v.y * v.y;
            float min_dist = radius + other_radius;
            
            // Check if particles overlap
            if (dist2 < min_dist * min_dist) {
                float dist = sqrt(dist2);
                vec2 n = dist > 0.0001 ? v / dist : vec2(1.0, 0.0); // Normalized direction vector
                
                // Calculate mass ratios based on radius (as in the C++ code)
                float mass_ratio_1 = radius / (radius + other_radius);
                float mass_ratio_2 = other_radius / (radius + other_radius);
                float delta_correction = 0.5 * RESPONSE_COEF * (dist - min_dist);
                
                // Apply position correction to resolve collision
                vec2 correction1 = -n * (mass_ratio_2 * delta_correction);
                vec2 correction2 = n * (mass_ratio_1 * delta_correction);
                
                // Update positions
                particles_buffer.data[base + 0] += correction1.x;
                particles_buffer.data[base + 1] += correction1.y;
                
                uint other_base = j * FLOATS_PER_PARTICLE;
                particles_buffer.data[other_base + 0] += correction2.x;
                particles_buffer.data[other_base + 1] += correction2.y;
            }
        }
    }
}

// Apply circular boundary constraint similar to C++ version
void applyConstraint() {
    uint id = gl_GlobalInvocationID.x;
    if (id >= uint(params.particle_count)) {
        return;
    }
    
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    float radius = particles_buffer.data[base + 6];
    
    // Assuming constraint is a circle centered at (400, 300) with radius 290
    vec2 constraint_center = vec2(400, 300);
    float constraint_radius = 290.0;
    
    vec2 v = constraint_center - pos;
    float dist = length(v);
    
    if (dist > (constraint_radius - radius)) {
        vec2 n = v / dist;
        vec2 new_pos = constraint_center - n * (constraint_radius - radius);
        
        particles_buffer.data[base + 0] = new_pos.x;
        particles_buffer.data[base + 1] = new_pos.y;
    }
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    float dt = params.delta / float(SUBSTEPS);
    
    // Early exit if this thread doesn't correspond to a valid particle
    if (id >= uint(params.particle_count)) {
        return;
    }

    // Perform sub-steps for more stable physics
    for (int step = 0; step < SUBSTEPS; step++) {
        uint base = id * FLOATS_PER_PARTICLE;
        
        float pos_x = particles_buffer.data[base + 0];
        float pos_y = particles_buffer.data[base + 1];
        float last_pos_x = particles_buffer.data[base + 2];
        float last_pos_y = particles_buffer.data[base + 3];
        float accel_x = particles_buffer.data[base + 4];
        float accel_y = particles_buffer.data[base + 5];
        float radius = particles_buffer.data[base + 6];
        
        vec2 pos = vec2(pos_x, pos_y);
        vec2 last_pos = vec2(last_pos_x, last_pos_y);
        vec2 accel = vec2(accel_x, accel_y);
        
        // Fix for identical positions: create small initial offset
        if (distance(pos, last_pos) < 0.0001) {
            // Add a tiny initial random displacement
            float angle = float(id % 360) * 3.14159 / 180.0;
            vec2 tiny_offset = vec2(cos(angle), sin(angle)) * 0.001;
            last_pos = pos - tiny_offset;
            
            particles_buffer.data[base + 2] = last_pos.x;
            particles_buffer.data[base + 3] = last_pos.y;
        }
        
        // Add gravity
        accel += GRAVITY;
        
        // Store updated acceleration
        particles_buffer.data[base + 4] = accel.x;
        particles_buffer.data[base + 5] = accel.y;
        
        // Verlet integration
        vec2 velocity = pos - last_pos;
        vec2 new_pos = pos + velocity + accel * dt * dt;
        
        // Update positions
        particles_buffer.data[base + 0] = new_pos.x;
        particles_buffer.data[base + 1] = new_pos.y;
        particles_buffer.data[base + 2] = pos.x; // new last_pos = old pos
        particles_buffer.data[base + 3] = pos.y;
        
        // Reset acceleration after applying
        particles_buffer.data[base + 4] = 0.0;
        particles_buffer.data[base + 5] = 0.0;
        
        // Ensure all threads have updated their positions before collision detection
        barrier();
        
        // Solve collisions between particles
        solveCollisions();
        
        // Apply constraint after collisions
        barrier();
        applyConstraint();
        
        // Ensure all physics operations are complete before next sub-step
        barrier();
    }
    
    // Debug output - store some useful data for visualization
    storage_buffer.data[id] = float(params.particle_count);
}