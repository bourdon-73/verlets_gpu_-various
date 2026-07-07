#[compute]

#version 450

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

const int FLOATS_PER_PARTICLE = 12;
const int SUBSTEPS = 1;
const vec2 GRAVITY = vec2(0, 500);

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


// void main() {
// 	storage_buffer.data[gl_GlobalInvocationID.x] = float(params.particle_count);
//     //particles_buffer.data[gl_GlobalInvocationID.x] = float(params.particle_count);
//     uint id = gl_GlobalInvocationID.x;
//     uint base = id * FLOATS_PER_PARTICLE;

//     float pos_x = particles_buffer.data[base + 0];
//     float pos_y = particles_buffer.data[base + 1];

//     //pos_x = 0
//     pos_y += .5;

//     //float(69)
    
//     particles_buffer.data[base + 0] = pos_x;
//     particles_buffer.data[base + 1] = pos_y;
//     //imageStore()

// }

// void main() {
// 	storage_buffer.data[gl_GlobalInvocationID.x] = gl_GlobalInvocationID.x;
    
//     // uint id = gl_GlobalInvocationID.x;
//     // storage_buffer.data[id] = particles_buffer.data[id];

//     uint id = gl_GlobalInvocationID.x;
//     float dt = params.delta;
//     // if (id >= params.particle_count) {
//     // return;
//     // }

//     uint base = id * FLOATS_PER_PARTICLE;

//     float pos_x = particles_buffer.data[base + 0];
//     float pos_y = particles_buffer.data[base + 1];
//     float last_pos_x = particles_buffer.data[base + 2];
//     float last_pos_y = particles_buffer.data[base + 3];
//     float accel_x = particles_buffer.data[base + 4];
//     float accel_y = particles_buffer.data[base + 5];
//     float radius = particles_buffer.data[base + 6];

//     vec2 pos = vec2(pos_x, pos_y);
//     vec2 last_pos = vec2(last_pos_x, last_pos_y);
//     vec2 accel = vec2(accel_x, accel_y);

//     // Add gravity
//     accel += GRAVITY;

//     // Verlet integration
//     vec2 velocity = pos - last_pos;
//     vec2 new_pos = pos + velocity + accel * dt * dt;

//     // Store back
//     particles_buffer.data[base + 0] = new_pos.x;
//     particles_buffer.data[base + 1] = new_pos.y;

//     particles_buffer.data[base + 2] = pos.x; // new last_pos = old pos
//     particles_buffer.data[base + 3] = pos.y;

//     particles_buffer.data[base + 4] = 0.0; // Clear accel after applying it
//     particles_buffer.data[base + 5] = 0.0;

//     // particles_buffer.data[base + 6] = float(params.particle_count);
//     storage_buffer.data[gl_GlobalInvocationID.x] = float(velocity.y);

// }



// Verlet integration step function
void applyGravity(uint id, float dt) {
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

    // Initialize with a tiny offset if no velocity (helps first-frame motion)
    if (distance(pos, last_pos) < 0.0001) {
        float angle = float(id % 360) * 3.14159 / 180.0;
        vec2 tiny_offset = vec2(cos(angle), sin(angle)) * 0.001;
        last_pos = pos - tiny_offset;
    }

    // Add gravity
    accel += GRAVITY;
    // Clamp acceleration
    float max_accel = 500.0;
    float accel_len = length(accel);
    if (accel_len > max_accel) {
        accel = normalize(accel) * max_accel;
    }
    // // Verlet integration
    vec2 velocity = pos - last_pos;
    //velocity *= 0.99998; // <- damping factor (tune this!)
    vec2 new_pos = pos + velocity + accel * dt * dt;

    // vec2 velocity = (pos - last_pos) * 1;
    // vec2 new_pos = pos + velocity + accel * dt * dt;

    // Write back
    particles_buffer.data[base + 0] = new_pos.x;
    particles_buffer.data[base + 1] = new_pos.y;
    particles_buffer.data[base + 2] = pos.x;
    particles_buffer.data[base + 3] = pos.y;
    particles_buffer.data[base + 4] = 0.0;
    particles_buffer.data[base + 5] = 0.0;

    // Optional: store something in the debug buffer
    
}

void applyConstraint2(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;

    float pos_x = particles_buffer.data[base + 0];
    float pos_y = particles_buffer.data[base + 1];
    float last_pos_x = particles_buffer.data[base + 2];
    float last_pos_y = particles_buffer.data[base + 3];
    float accel_x = particles_buffer.data[base + 4];
    float accel_y = particles_buffer.data[base + 5];
    float radius = particles_buffer.data[base + 6];

    vec2 pos = vec2(pos_x, pos_y);
    vec2 new_pos = vec2(pos_x, pos_y);
    vec2 last_pos = vec2(last_pos_x, last_pos_y);
    vec2 accel = vec2(accel_x, accel_y);

    vec2 center = vec2(500, -300);
    float constraint_radius = 200.0;
    float boundary = constraint_radius - radius;

    vec2 to_center = pos - center;
    //float dist = length(to_center);
    vec2 v = center - pos;
    float dist = sqrt(v.x * v.x + v.y * v.y);


    if (dist > (constraint_radius - radius)) {
        vec2 n = v / dist;
        pos = center - n * (constraint_radius - radius);
    }

    

    // Write back
    particles_buffer.data[base + 0] = pos.x;
    particles_buffer.data[base + 1] = pos.y;
    particles_buffer.data[base + 2] = last_pos.x;
    particles_buffer.data[base + 3] = last_pos.y;
    particles_buffer.data[base + 4] = accel.x;
    particles_buffer.data[base + 5] = accel.y;
}

void applyConstraint(uint id, float dt) {
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

    // Calculate velocity before constraint
    vec2 velocity = pos - last_pos;
    
    vec2 center = vec2(500, -300);
    float constraint_radius = 800.0;
    float boundary = constraint_radius - radius;

    vec2 to_center = center - pos;
    float dist = length(to_center);

    // If outside boundary
    if (dist > boundary) {
        // Normalize direction vector (pointing toward center)
        vec2 n = to_center / dist;
        
        // Place particle at boundary with a tiny epsilon to avoid precision issues
        float epsilon = 0.01; // Small offset to avoid sticking due to precision
        vec2 new_pos = center - n * (boundary - epsilon);
        
        // For sliding: project velocity onto the tangent
        vec2 tangent = vec2(-n.y, n.x); // Perpendicular to normal
        
        // Project velocity onto the tangent (preserve tangential component)
        float tangential_velocity = dot(velocity, tangent);
        
        // Apply very minimal friction
        float friction = 0.998;
        tangential_velocity *= friction;
        
        // Add a small minimum velocity along the tangent in the direction of gravity
        // This helps particles overcome "sticky spots" due to numerical precision
        //float gravity_tangent = dot(GRAVITY, tangent);
        //float min_slide = 0.05 * sign(gravity_tangent); // Minimal slide in gravity direction
        
        // Apply the minimum sliding velocity in the appropriate direction
        // if (abs(tangential_velocity) < abs(min_slide)) {
        //     tangential_velocity = min_slide;
        // }
        
        // Rebuild velocity using only tangential component
        vec2 new_velocity = tangent * tangential_velocity;
        
        // Update position and last_pos
        pos = new_pos;
        last_pos = pos - new_velocity;
    }

    // Write back
    particles_buffer.data[base + 0] = pos.x;
    particles_buffer.data[base + 1] = pos.y;
    particles_buffer.data[base + 2] = last_pos.x;
    particles_buffer.data[base + 3] = last_pos.y;
    particles_buffer.data[base + 4] = 0.0;
    particles_buffer.data[base + 5] = 0.0;
}

// very slidy and bugs out
void solveCollisions(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;

    vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(particles_buffer.data[base + 2], particles_buffer.data[base + 3]);
    vec2 accel = vec2(particles_buffer.data[base + 4], particles_buffer.data[base + 5]);
    float radius = particles_buffer.data[base + 6];

    float response_coef = 0.95;
    uint particle_count = uint(params.particle_count);


    // Clamp velocity to prevent explosion
    vec2 velocity = pos - last_pos;
    float max_velocity = 500.0;
    float vel_len = length(velocity);
    if (vel_len > max_velocity) {
        velocity = normalize(velocity) * max_velocity;
        last_pos = pos - velocity;
    }

    for (uint k = 0; k < particle_count; ++k) {
        if (k == id) continue;

        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(particles_buffer.data[kbase + 0], particles_buffer.data[kbase + 1]);
        float kradius = particles_buffer.data[kbase + 6];

        vec2 v = pos - kpos;
        float dist2 = dot(v, v);
        float min_dist = radius + kradius;

        if (dist2 < min_dist * min_dist) {
            float dist = sqrt(dist2);
            vec2 n = dist > 0.0 ? v / dist : vec2(1.0, 0.0); // prevent NaN
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);
            float delta = 0.5 * response_coef * (dist - min_dist);

            pos -= n * (mass_ratio_2 * delta);
            // Don't update kpos unless you have atomic writes or ping-ponging (see below)
        }
    }

   // last_pos += (pos - last_pos) * 2.5;  // Apply "soft" damping or correction

    velocity = pos - last_pos;
    // Apply very minimal damping (or none)
    float damping = 0.998; // Almost no damping
    velocity *= damping;
    last_pos = (pos - velocity) ;



    // Write back
    particles_buffer.data[base + 0] = pos.x;
    particles_buffer.data[base + 1] = pos.y;
    particles_buffer.data[base + 2] = last_pos.x;
    particles_buffer.data[base + 3] = last_pos.y;
    particles_buffer.data[base + 4] = accel.x;
    particles_buffer.data[base + 5] = accel.y;
}

// middle 
void solveCollisions2(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;

    vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(particles_buffer.data[base + 2], particles_buffer.data[base + 3]);
    vec2 accel = vec2(particles_buffer.data[base + 4], particles_buffer.data[base + 5]);
    float radius = particles_buffer.data[base + 6];

    // Calculate current velocity
    vec2 velocity = pos - last_pos;
    
    // Clamp velocity to prevent explosion
    float max_velocity = 1000.0; // Adjust as needed
    float vel_len = length(velocity);
    if (vel_len > max_velocity) {
        velocity = normalize(velocity) * max_velocity;
        last_pos = pos - velocity; // Adjust last_pos to match clamped velocity
    }

    float response_coef = 0.90; // Slightly lower for stability
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
                float restitution = 0.0; // Coefficient of restitution (bounciness)
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

// high friction
void solveCollisions3(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;

    vec2 pos = vec2(particles_buffer.data[base + 0], particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(particles_buffer.data[base + 2], particles_buffer.data[base + 3]);
    vec2 accel = vec2(particles_buffer.data[base + 4], particles_buffer.data[base + 5]);
    float radius = particles_buffer.data[base + 6];

    // Calculate current velocity
    vec2 velocity = pos - last_pos;
    
    // Clamp velocity to prevent explosion
    float max_velocity = 1000.0;
    float vel_len = length(velocity);
    if (vel_len > max_velocity) {
        velocity = normalize(velocity) * max_velocity;
        last_pos = pos - velocity;
    }

    float response_coef = 0.90;
    uint particle_count = uint(params.particle_count);

    for (uint k = 0; k < particle_count; ++k) {
        if (k == id) continue;

        uint kbase = k * FLOATS_PER_PARTICLE;
        vec2 kpos = vec2(particles_buffer.data[kbase + 0], particles_buffer.data[kbase + 1]);
        float kradius = particles_buffer.data[kbase + 6];

        vec2 v = pos - kpos;
        float dist2 = dot(v, v);
        float min_dist = radius + kradius;

        if (dist2 < min_dist * min_dist && dist2 > 0.001) {
            float dist = sqrt(dist2);
            vec2 n = v / dist; // Normalized collision normal
            
            // Calculate penetration depth
            float penetration = min_dist - dist;
            
            // Apply position correction (limited to prevent overshooting)
            float max_correction = min_dist * 0.2;
            float correction = min(penetration, max_correction);
            
            // Calculate mass ratio for position response
            float mass_ratio_1 = radius / (radius + kradius);
            float mass_ratio_2 = kradius / (radius + kradius);
            
            // Apply position correction
            pos += n * (correction * mass_ratio_2);
            
            // Adjust velocity to respond to collision
            vec2 rel_velocity = velocity;
            float vel_along_normal = dot(rel_velocity, n);
            
            // Decompose velocity into normal and tangential components
            vec2 vel_normal = vel_along_normal * n;
            vec2 vel_tangent = rel_velocity - vel_normal;
            
            // Only apply velocity response if particles are moving toward each other
            if (vel_along_normal < 0) {
                // Calculate impulse for normal component
                float restitution = 0.3; // Increased bounciness
                float impulse_scalar = -(1.0 + restitution) * vel_along_normal;
                
                // Apply impulse to normal velocity component only
                vec2 new_vel_normal = impulse_scalar * n * mass_ratio_2;
                
                // Set friction coefficient (lower = more slidy)
                float friction = 0.05; // Very low friction for slidy effect
                
                // Apply reduced friction to tangential component
                vec2 new_vel_tangent = vel_tangent * (1.0 - friction);
                
                // Combine normal and tangential components
                velocity = new_vel_normal + new_vel_tangent;
            }
        }
    }

    // Apply very minimal damping (or none)
    float damping = 0.998; // Almost no damping
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
    float dt2 = dt / float(SUBSTEPS);

    // Uncomment this for safety in production
    // if (id >= uint(params.particle_count)) return;

    
    for (int i = 0; i < SUBSTEPS; i++) {
        applyGravity(id, dt2);
        //if (params.particle_count >= 2){
        solveCollisions2(id, dt2);
        applyConstraint(id, dt2);

        //}
    }
    
    storage_buffer.data[id] = float(params.particle_count);

    // if (params.particle_count >= 2){
    //     solveCollisions(id, dt);

    // }

}

