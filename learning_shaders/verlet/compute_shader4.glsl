#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 8;
const vec2 GRAVITY = vec2(0, 500);
const float MAX_VELOCITY = 1000.0;
const float MAX_ACCEL = 500.0;
const float RESPONSE_COEF = 0.70;
const float DAMPING = 0.998;

// Shared memory for collision processing
shared vec4 sharedParticleData[128]; // position.xy, radius, mass

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
} params;

layout(set = 0, binding = 2) buffer PosBuffer {
    float data[];
} pos_buffer;

layout(set = 0, binding = 3) buffer Particles {
    float data[]; // the whole big float array!
} particles_buffer;

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
    vec2 new_pos = pos + velocity + accel * dt * dt;
    
    // Update positions
    last_pos = pos;
    pos = new_pos;
    
    // Clear acceleration for next frame
    accel = vec2(0.0);
}

// Apply constraint keeping particles within a circle
void applyConstraint(inout vec2 pos, inout vec2 last_pos, float radius) {
    // Calculate velocity before constraint
    vec2 velocity = pos - last_pos;
    
    const vec2 center = vec2(500, -1000);
    const float constraint_radius = 1000.0;
    const float boundary = constraint_radius - radius;
    const float epsilon = 0.015; // Small offset to avoid precision issues
    
    // Use vector subtraction directly - no need for intermediate values
    vec2 to_center = center - pos;
    float dist_sq = dot(to_center, to_center);
    float boundary_sq = boundary * boundary;
    
    // Only compute sqrt if needed (particle is outside boundary)
    if (dist_sq > boundary_sq) {
        float dist = sqrt(dist_sq);
        vec2 n = to_center / dist;
        
        // Place particle at boundary
        pos = center - n * (boundary - epsilon);
        
        // For sliding: project velocity onto the tangent
        vec2 tangent = vec2(-n.y, n.x); // Perpendicular to normal
        
        // Project velocity onto the tangent (preserve tangential component)
        float tangential_velocity = dot(velocity, tangent);
        
        // Apply minimal friction
        tangential_velocity *= DAMPING;
        
        // Rebuild velocity using only tangential component
        vec2 new_velocity = tangent * tangential_velocity;
        
        // Update last_pos to maintain new velocity
        last_pos = pos - new_velocity;
    }
}

// Solve collisions between particles

void solveCollisions(uint id, inout vec2 pos, inout vec2 last_pos, float radius) {
    uint base = id * FLOATS_PER_PARTICLE;

    //vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    //vec2 last_pos = vec2(particles_buffer.data[base + 2], particles_buffer.data[base + 3]);
    vec2 accel = vec2(particles_buffer.data[base + 4], particles_buffer.data[base + 5]);
    //float radius = particles_buffer.data[base + 6];

    // Calculate current velocity
    vec2 velocity = pos - last_pos;
    
    // Clamp velocity to prevent explosion
    float max_velocity = 1000.0; // Adjust as needed
    float vel_len = length(velocity);
    if (vel_len > max_velocity) {
        velocity = normalize(velocity) * max_velocity;
        last_pos = pos - velocity; // Adjust last_pos to match clamped velocity
    }

    //float response_coef = 0.75; // Slightly lower for stability
    uint particle_count = uint(params.particle_count);

    for (uint k = 0; k < particle_count; ++k) {
        if (k == id) continue;

        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(particles_buffer.data[kbase + 0], particles_buffer.data[kbase + 1]);
        float kradius = particles_buffer.data[kbase + 6];

        vec2 v = pos - kpos;
        float dist2 = dot(v, v);
        float min_dist = radius + kradius;

        if (dist2 < min_dist * min_dist && dist2 > 0.001) { // Avoid division by nearly zero
            float dist = sqrt(dist2);
            vec2 n = v / dist; // Normalized collision normal
            
            // Calculate penetration depth
            float penetration = min_dist - dist;
            
            // Apply position correction (limited to prevent overshooting)
            float max_correction = min_dist * 0.2; // Limit correction to 20% of total radius
            float correction = min(penetration, max_correction);
            
            // Calculate mass ratio for position response
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);
            
            // Apply position correction
            pos += n * (correction * mass_ratio_2);
            
            // Adjust velocity to respond to collision
            vec2 rel_velocity = velocity; // relative velocity (simplified since we can't modify other particle)
            float vel_along_normal = dot(rel_velocity, n);
            
            // Only apply velocity response if particles are moving toward each other
            if (vel_along_normal < 0) {
                // Calculate impulse
                float restitution = 0.05; // Coefficient of restitution (bounciness)
                float impulse_scalar = -(1.0 + restitution) * vel_along_normal;
                
                // Apply impulse to velocity
                velocity += impulse_scalar * n * mass_ratio_2;
            }
        }
    }

    // Apply damping to all collisions to prevent energy build-up
    float damping = 1.0;
    velocity *= damping;
    
    // Update last_pos to maintain new velocity
    last_pos = pos - velocity;

    // Write back
    particles_buffer.data[base + 0] = pos.x;
    particles_buffer.data[base + 1] = pos.y;
    particles_buffer.data[base + 2] = last_pos.x;
    particles_buffer.data[base + 3] = last_pos.y;
    particles_buffer.data[base + 4] = accel.x;
    particles_buffer.data[base + 5] = accel.y;
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    float dt = params.delta;
    float dt_sub = dt / float(SUBSTEPS);
    
    // Early return for out-of-bounds particles
    if (id >= uint(params.particle_count)) return;
    
    // Load particle data once (avoids repeated memory access)
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(particles_buffer.data[base + 2], particles_buffer.data[base + 3]);
    vec2 accel = vec2(particles_buffer.data[base + 4], particles_buffer.data[base + 5]);
    float radius = particles_buffer.data[base + 6];
    
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
    particles_buffer.data[base + 0] = pos.x;
    particles_buffer.data[base + 1] = pos.y;
    particles_buffer.data[base + 2] = last_pos.x;
    particles_buffer.data[base + 3] = last_pos.y;
    particles_buffer.data[base + 4] = accel.x;
    particles_buffer.data[base + 5] = accel.y;
    
    // Write debug info to storage buffer
    storage_buffer.data[id] = float(params.particle_count);
}