#[compute]
#version 460
#extension GL_EXT_shader_atomic_float : enable
#include "shared_data.glsl"


// before I use two buffers 
// ping pong shit
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;


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



        // vec2 start = m_constraint_center - n * (constraint_radius - radius);
        // vec2 temp_last_pos = last_pos;
        //last_pos = start;//mix(temp_last_pos, start, 5);

    }

    
}

void applyConstraint2(uint id, float radius, vec2 c_center, float c_radius) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base + 0], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    
    // Calculate vector from center to particle
    vec2 v = pos - c_center;
    float dist = length(v);
    
    // Only apply constraint if particle is outside boundary
    if (dist > (c_radius - radius) - EPSILON) {
        // Normalize direction vector
        vec2 n = v / dist;
        
        // Calculate correct position on boundary
        vec2 corrected_pos = c_center + n * (c_radius - radius);
        
        // Calculate the velocity (pos - last_pos)
        vec2 velocity = pos - last_pos;
        
        // Calculate reflection direction - dot product for projection
        float vdotn = dot(velocity, n);
        
        // Apply bounce with damping
        const float BOUNCE_DAMPING = 1.0; // Adjust between 0-1 as needed
        vec2 reflected_velocity = velocity - 2.0 * vdotn * n;
        reflected_velocity *= BOUNCE_DAMPING;
        
        // Update position
        read_particles_buffer.data[base + 0] = corrected_pos.x;
        read_particles_buffer.data[base + 1] = corrected_pos.y;
        
        // Update last_pos to maintain the reflected velocity
        read_particles_buffer.data[base + 2] = corrected_pos.x - reflected_velocity.x;
        read_particles_buffer.data[base + 3] = corrected_pos.y - reflected_velocity.y;
    }
}

void applyConstraint3(uint id, float radius, vec2 c_center, float c_radius) {
    
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

void main() {

    uint id = gl_GlobalInvocationID.x;
    storage_buffer.data[0] = float(params.bound_radius);
    uint base = id * FLOATS_PER_PARTICLE;
    float radius = read_particles_buffer.data[base + 6];
    vec2 m_constraint_center = vec2(params.bounds_x, params.bounds_y);
    float constraint_radius = params.bound_radius;

    //for (int i = 0; i < SUBSTEPS; i++) {
 
    applyConstraint(id, radius,m_constraint_center, constraint_radius  );
    //}

}