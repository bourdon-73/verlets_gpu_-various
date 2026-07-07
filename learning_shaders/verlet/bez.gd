extends Node2D

# This approach uses compute shaders for maximum performance
# Only works in Godot 4.2+ with the Vulkan renderer

var curve_data = []  # Will store all curve control points
var curve_count = 20000

# Compute shader for generating curve mesh data
#const COMPUTE_SHADER_CODE 
##[compute]
##version 450
#
#// Structure to define a cubic bezier curve
#struct CurveData {
	#vec3 p0;
	#vec3 p1;
	#vec3 p2;
	#vec3 p3;
#};
#
#// Input buffer containing all curve data
#layout(set = 0, binding = 0, std430) readonly buffer CurveBuffer {
	#CurveData curves[];
#} curve_buffer;
#
#// Output buffer for vertices
#layout(set = 0, binding = 1, std430) buffer VertexBuffer {
	#vec3 vertices[];
#} vertex_buffer;
#
#// Output buffer for indices
#layout(set = 0, binding = 2, std430) buffer IndexBuffer {
	#uint indices[];
#} index_buffer;
#
#// Parameters
#layout(set = 0, binding = 3) uniform Params {
	#uint curve_count;
	#uint segments_per_curve;
#} params;
#
#// Cubic Bezier interpolation
#vec3 cubic_bezier(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	#float t2 = t * t;
	#float t3 = t2 * t;
	#float mt = 1.0 - t;
	#float mt2 = mt * mt;
	#float mt3 = mt2 * mt;
	#
	#return p0 * mt3 + p1 * 3.0 * mt2 * t + p2 * 3.0 * mt * t2 + p3 * t3;
#}

#// Main compute shader function
#layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
#void main() {
	#// Get the curve index
	#uint curve_idx = gl_GlobalInvocationID.x;
	#
	#// Make sure we dont go out of bounds
	#if (curve_idx >= params.curve_count) {
		#return;
	#}
	#
	#// Get the curve data
	#CurveData curve = curve_buffer.curves[curve_idx];
	#
	#// Calculate vertex offset for this curve
	#uint vertex_offset = curve_idx * (params.segments_per_curve + 1);
	#uint index_offset = curve_idx * params.segments_per_curve * 2;
	#
	#// Generate vertices along the curve
	#for (uint i = 0; i <= params.segments_per_curve; i++) {
		#float t = float(i) / float(params.segments_per_curve);
		#
		#// Calculate point on curve
		#vec3 point = cubic_bezier(curve.p0, curve.p1, curve.p2, curve.p3, t);
		#
		#// Store vertex
		#vertex_buffer.vertices[vertex_offset + i] = point;
		#
		#// Store indices for line segments
		#if (i > 0) {
			#index_buffer.indices[index_offset + (i-1)*2] = vertex_offset + i - 1;
			#index_buffer.indices[index_offset + (i-1)*2 + 1] = vertex_offset + i;
		#}
	#}
#}




#var rd: RenderingDevice
#var compute_pipeline: RID
#var curve_buffer: RID
#var vertex_buffer: RID
#var index_buffer: RID
#var params_buffer: RID
#var uniform_set: RID
#
#var mesh_instance: MeshInstance3D
#
#func _ready():
	## Create curve data
	#generate_curve_data()
	#
	## Setup compute shader pipeline
	#setup_compute_pipeline()
	#
	## Run the compute shader to generate mesh data
	#run_compute_shader()
	#
	## Create and display the mesh
	#create_mesh_from_buffers()
#
#func _exit_tree():
	## Clean up RenderingDevice resources
	#if rd:
		#rd.free_rid(compute_pipeline)
		#rd.free_rid(curve_buffer)
		#rd.free_rid(vertex_buffer)
		#rd.free_rid(index_buffer)
		#rd.free_rid(params_buffer)
		#rd.free_rid(uniform_set)
#
#func generate_curve_data():
	#randomize()
	#curve_data = []
	#
	#for i in range(curve_count):
		## Create a random cubic Bezier curve with 4 control points
		#var base_pos = Vector3(randf_range(-100, 100), randf_range(-50, 50), randf_range(-100, 100))
		#var p0 = base_pos
		#var p1 = base_pos + Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		#var p2 = base_pos + Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		#var p3 = base_pos + Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		#
		#curve_data.append({
			#"p0": p0,
			#"p1": p1,
			#"p2": p2,
			#"p3": p3
		#})
#
#func setup_compute_pipeline():
	## Get the rendering device
	#rd = RenderingServer.create_local_rendering_device()
	#
	## Create shader
	#var shader_spirv = rd.shader_compile_spirv_from_source(COMPUTE_SHADER_CODE)
	#compute_pipeline = rd.compute_pipeline_create(shader_spirv)
	#
	## Create buffers
	#create_buffers()
	#
	## Create uniform set
	#var uniform_set_format = rd.uniform_set_format_create([
		#rd.uniform_set_format_add_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0, true),
		#rd.uniform_set_format_add_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1, false),
		#rd.uniform_set_format_add_binding(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2, false),
		#rd.uniform_set_format_add_binding(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 3, true)
	#])
	#
	#uniform_set = rd.uniform_set_create([
		#rd.uniform_set_create_binding(0, curve_buffer),
		#rd.uniform_set_create_binding(1, vertex_buffer),
		#rd.uniform_set_create_binding(2, index_buffer),
		#rd.uniform_set_create_binding(3, params_buffer)
	#], uniform_set_format)
#
#func create_buffers():
	#var segments_per_curve = 16
	#
	## Create curve buffer
	#var curve_data_bytes = PackedByteArray()
	#for curve in curve_data:
		## p0
		#curve_data_bytes.append_array(PackedFloat32Array([curve.p0.x, curve.p0.y, curve.p0.z]).to_byte_array())
		## p1
		#curve_data_bytes.append_array(PackedFloat32Array([curve.p1.x, curve.p1.y, curve.p1.z]).to_byte_array())
		## p2
		#curve_data_bytes.append_array(PackedFloat32Array([curve.p2.x, curve.p2.y, curve.p2.z]).to_byte_array())
		## p3
		#curve_data_bytes.append_array(PackedFloat32Array([curve.p3.x, curve.p3.y, curve.p3.z]).to_byte_array())
	#
	#curve_buffer = rd.storage_buffer_create(curve_data_bytes.size(), curve_data_bytes)
	#
	## Create vertex buffer
	#var vertex_count = curve_count * (segments_per_curve + 1)
	#var vertex_buffer_size = vertex_count * 3 * 4  # 3 floats per vertex, 4 bytes per float
	#vertex_buffer = rd.storage_buffer_create(vertex_buffer_size)
	#
	## Create index buffer
	#var index_count = curve_count * segments_per_curve * 2  # 2 indices per segment
	#var index_buffer_size = index_count * 4  # 4 bytes per index (uint)
	#index_buffer = rd.storage_buffer_create(index_buffer_size)
	#
	## Create params buffer
	#var params_bytes = PackedByteArray()
	## curve_count
	#params_bytes.append_array(PackedInt32Array([curve_count]).to_byte_array())
	## segments_per_curve
	#params_bytes.append_array(PackedInt32Array([segments_per_curve]).to_byte_array())
	#
	#params_buffer = rd.uniform_buffer_create(params_bytes.size(), params_bytes)
#
#func run_compute_shader():
	## Create a compute list
	#var compute_list = rd.compute_list_begin()
	#rd.compute_list_bind_compute_pipeline(compute_list, compute_pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	#
	## Dispatch compute shader
	#var groups_x = (curve_count + 63) / 64  # Round up division by 64
	#rd.compute_list_dispatch(compute_list, groups_x, 1, 1)
	#rd.compute_list_end()
	#
	## Submit and synchronize
	#rd.submit()
	#rd.sync()
#
#func create_mesh_from_buffers():
	## Read data back from buffers
	#var segments_per_curve = 16
	#var vertex_count = curve_count * (segments_per_curve + 1)
	#var vertex_data = rd.buffer_get_data(vertex_buffer)
	#
	#var index_count = curve_count * segments_per_curve * 2
	#var index_data = rd.buffer_get_data(index_buffer)
	#
	## Convert to Godot arrays
	#var vertices = PackedVector3Array()
	#vertices.resize(vertex_count)
	#for i in range(vertex_count):
		#var offset = i * 12  # 3 floats, 4 bytes each
		#var x = vertex_data.decode_float(offset)
		#var y = vertex_data.decode_float(offset + 4)
		#var z = vertex_data.decode_float(offset + 8)
		#vertices[i] = Vector3(x, y, z)
	#
	#var indices = PackedInt32Array()
	#indices.resize(index_count)
	#for i in range(index_count):
		#indices[i] = vertex_data.decode_u32(i * 4)
	#
	## Create mesh
	#var arrays = []
	#arrays.resize(Mesh.ARRAY_MAX)
	#arrays[Mesh.ARRAY_VERTEX] = vertices
	#arrays[Mesh.ARRAY_INDEX] = indices
	#
	#var mesh = ArrayMesh.new()
	#mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	#
	## Create mesh instance
	#mesh_instance = MeshInstance3D.new()
	#mesh_instance.mesh = mesh
	#
	## Create material
	#var material = StandardMaterial3D.new()
	#material.albedo_color = Color(0.2, 0.6, 1.0)
	#material.metallic = 0.4
	#material.roughness = 0.3
	#
	#mesh_instance.material_override = material
	#
	## Add to scene
	#add_child(mesh_instance)
#
## Call this from _process if you need to update curves dynamically
#func update_curves():
	## Update curve data
	## ...
	#
	## Re-run compute shader
	#run_compute_shader()
	#
	## Update mesh
	#create_mesh_from_buffers()
