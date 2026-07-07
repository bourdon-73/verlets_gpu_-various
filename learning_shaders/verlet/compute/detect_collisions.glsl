#[compute]
#version 460
#extension GL_EXT_shader_atomic_float : enable
#include "shared_data.glsl"


// before I use two buffers 
// ping pong shit
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void process_base_forces(uint id, float dt) {
    uint base = id * FLOATS_PER_PARTICLE;
    vec2 pos = vec2(read_particles_buffer.data[base], read_particles_buffer.data[base + 1]);
    vec2 last_pos = vec2(read_particles_buffer.data[base + 2], read_particles_buffer.data[base + 3]);
    
    // Calculate implicit velocity (no need to normalize by prev_dt)
    vec2 velocity = pos - last_pos;
    
    // Apply damping
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



void main() {

    uint id = gl_GlobalInvocationID.x;
    storage_buffer.data[0] = float(params.bound_radius);


    for (int i = 0; i < SUBSTEPS; i++) {
 
        process_base_forces(id,params.delta );
    }

}