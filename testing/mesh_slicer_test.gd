extends Node3D

@export var meshinstance : MeshInstance3D
@export var plane : Plane
@export var cap_uv = Vector2.ZERO
@export var cap_material : Material

const INTERSECTMARKER = preload("res://testing/intersectmarker.tscn")

var markers = []


func _ready() -> void:
	#test_transform()
	print(Time.get_ticks_msec())
	slice(meshinstance)
	print(Time.get_ticks_msec())
	pass


func test_transform():
	
	# populate mdt from mesh or primitive -> arraymesh
	
	var mdt = _create_mdt(meshinstance.mesh)
	
	# test transformation
	
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		vertex += mdt.get_vertex_normal(i) * 2
		mdt.set_vertex(i, vertex)
	
	# build surface array for new arraymesh
	
	var surface_builder = SurfaceArrayBuilder.new()
	for i in range(mdt.get_face_count()): surface_builder.add_tri_from_mdt(mdt, i)
	
	# push mesh
	
	var arraymesh = ArrayMesh.new()
	arraymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_builder.build())
	
	#mdt.commit_to_surface(new_mesh)
	
	_create_mesh_instance(arraymesh, meshinstance)



func slice(mesh_instance : MeshInstance3D, plane : Plane = self.plane, hull = true):
	
	#if hull:
		#var inverse_hull = _create_mesh_instance(mesh_instance.mesh.create_outline(-0.1), mesh_instance)
		#slice(inverse_hull, plane, false)
	
	# mdt
	
	var mdt = _create_mdt(mesh_instance.mesh)
	
	# build tris into here
	
	var upper_surface_builder = SurfaceArrayBuilder.new()
	var lower_surface_builder = SurfaceArrayBuilder.new()
	
	# build caps into here
	
	var upper_cap_builder = SurfaceArrayBuilder.new()
	var lower_cap_builder = SurfaceArrayBuilder.new()
	
	
	# the actual tri pushing
	
	
	# store intersection points for later (gap filling)
	
	var intersections = {}
	var num_intersections = 0
	var intersection_sum = Vector3.ZERO
	
	
	# iterate through tris
	
	for i in range(mdt.get_face_count()):
		
		
		
		
		#await get_tree().create_timer(5.0).timeout
		
		
		
		
		var tri_intersect = _tri_plane_intersection(mdt, i, plane)
		#print("tri intersect: ", tri_intersect)
		
		# push non-intersecting tris into correct surface
		
		if tri_intersect > 0: 
			#print("building upper")
			upper_surface_builder.add_tri_from_mdt(mdt, i)
		if tri_intersect < 0: 
			#print("building lower")
			lower_surface_builder.add_tri_from_mdt(mdt, i)
		
		# slice intersecting tris
		
		if tri_intersect == 0: 
			
			# (edges, intersecting vertices, vertices)
			var ab = null
			var ac = null
			
			var vab
			var vac
			
			var vab_norm
			var vac_norm
			var vab_uv
			var vac_uv
			
			var a
			var b
			var c
			
			
			# get ABC from verts
			
			# get face index organized arrays of vertex signs (above or below plane)
			# and face index organized array of vertex(indices) (for wraparound)
			
			var vert_signs = []
			var vert_array = []
			vert_array.resize(3)
			vert_signs.resize(3)
			
			# hard to explain
			# cuts are 'upside down' relative to face vert index - to wind cap normals correctly
			
			var cuts_inverted = false
			
			for vert_i in range(3):
				var vert_index = mdt.get_face_vertex(i, vert_i)
				var vert = mdt.get_vertex(vert_index)
				
				vert_array[vert_i] = vert_index
				vert_signs[vert_i] = sign(plane.distance_to(vert))
			
			# iterate through vert array, if both neighbors are equal, vert is A
			
			var a_i = 0
			for vert_i in vert_array.size():
				if vert_signs[vert_i - 2] == vert_signs[vert_i - 1]: 
					a = vert_array[vert_i]
					a_i = vert_i
					
					# a in 'bottom' corners of face-vertex indexing
					
					if vert_i > 0: cuts_inverted = true
			
			# assume clockwise assignment - assign next vertex as C, prev as B (why did I do it this way?)
			
			c = vert_array[a_i - 2]
			b = vert_array[a_i - 1]
			
			# get intersection vertices
			
			#vab = plane.intersects_segment(mdt.get_vertex(a), mdt.get_vertex(b))
			#vac = plane.intersects_segment(mdt.get_vertex(a), mdt.get_vertex(c))
			#
			#print((mdt.get_vertex(a) - vab).length())
			
			vab = _plane_segment_intersection(plane, mdt.get_vertex(a), mdt.get_vertex(b))
			vac = _plane_segment_intersection(plane, mdt.get_vertex(a), mdt.get_vertex(c))
			
			# tip (a) positive or base positive
			
			var a_facing = sign(plane.distance_to(mdt.get_vertex(a)))
			if a_facing > 0: cuts_inverted = !cuts_inverted # TODO TODO
			
			# populate intersections dict
			 
			if !cuts_inverted: intersections[num_intersections] = [vab, vac]
			else:              intersections[num_intersections] = [vac, vab]
			num_intersections += 2
			intersection_sum += vab + vac
			
			# interpolate normal/uv for vab/vac
			
			var vab_d = mdt.get_vertex(a).distance_to(vab) / mdt.get_vertex(a).distance_to(mdt.get_vertex(b))
			var vac_d = mdt.get_vertex(a).distance_to(vac) / mdt.get_vertex(a).distance_to(mdt.get_vertex(c))
			
			vab_norm = mdt.get_vertex_normal(a).lerp(mdt.get_vertex_normal(b), vab_d)
			vac_norm = mdt.get_vertex_normal(a).lerp(mdt.get_vertex_normal(c), vac_d)
			
			vab_uv = mdt.get_vertex_uv(a).lerp(mdt.get_vertex_uv(b), vab_d)
			vac_uv = mdt.get_vertex_uv(a).lerp(mdt.get_vertex_uv(c), vac_d)
			
			# make new triangles from split (choose vab as quad bisecting vertex) 
			
			# build tip triangle (upper or lower)
			
			if a_facing > 0:
				upper_surface_builder.add_vert_from_mdt(mdt, a)
				upper_surface_builder.add_vert_manual(vac, vac_uv, vac_norm)
				upper_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
			
			else:
				lower_surface_builder.add_vert_from_mdt(mdt, a)
				lower_surface_builder.add_vert_manual(vac, vac_uv, vac_norm)
				lower_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
			
			# build base triangle 1 - vab b c
			
			if a_facing < 0:
				upper_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
				upper_surface_builder.add_vert_from_mdt(mdt, c)
				upper_surface_builder.add_vert_from_mdt(mdt, b)
			
			else:
				lower_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
				lower_surface_builder.add_vert_from_mdt(mdt, c)
				lower_surface_builder.add_vert_from_mdt(mdt, b)
			
			# build base triangle 2 - vab vac c
			
			if a_facing < 0:
				upper_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
				upper_surface_builder.add_vert_manual(vac, vac_uv, vac_norm)
				upper_surface_builder.add_vert_from_mdt(mdt, c)
			
			else:
				lower_surface_builder.add_vert_manual(vab, vab_uv, vab_norm)
				lower_surface_builder.add_vert_manual(vac, vac_uv, vac_norm)
				lower_surface_builder.add_vert_from_mdt(mdt, c)
				
			
			
		# TESTSETES
		
		
		
		#var arraymesh_upper = ArrayMesh.new()
		#var arraymesh_lower = ArrayMesh.new()
		#
		#arraymesh_upper.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, upper_surface_builder.build())
		#arraymesh_lower.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lower_surface_builder.build())
		#
		#print("upper tris: ", upper_surface_builder.verts.size())
		#
		## create mesh instances
		#
		#var upper_meshinstance = _create_mesh_instance(arraymesh_upper, mesh_instance)
		#var lower_meshinstance = _create_mesh_instance(arraymesh_lower, mesh_instance)
		
		
		
		#ADFJIDSAFISDAIJFOAD
	
	# create caps
	
	# get intersection com / average
	
	var intersection_com = intersection_sum / num_intersections
	
	# iterate through intersection pairs and create triangles
	# use plane normal and cap_uv
	
	for pair in intersections.values():
		var vab = pair[0]
		var vac = pair[1]
		
		# create upper triangles
		
		# create first vert
		
		upper_cap_builder.add_vert_manual(intersection_com, cap_uv, plane.normal)
		
		# if new face normal is opposite desired normal, flip it (vac then vab)
		# hacky - there is probably an analytical solution 
		
		var cross = (vab - intersection_com).cross(vac  - intersection_com)
		if cross.dot(-plane.normal) >= 0:
			upper_cap_builder.add_vert_manual(vac, cap_uv, plane.normal)
			upper_cap_builder.add_vert_manual(vab, cap_uv, plane.normal)
		else:
			upper_cap_builder.add_vert_manual(vab, cap_uv, plane.normal)
			upper_cap_builder.add_vert_manual(vac, cap_uv, plane.normal)
		
		
		# create lower triangles
		
		lower_cap_builder.add_vert_manual(intersection_com, cap_uv, plane.normal)
		
		if cross.dot(plane.normal) >= 0:
			lower_cap_builder.add_vert_manual(vac, cap_uv, plane.normal)
			lower_cap_builder.add_vert_manual(vab, cap_uv, plane.normal)
		else:
			lower_cap_builder.add_vert_manual(vab, cap_uv, plane.normal)
			lower_cap_builder.add_vert_manual(vac, cap_uv, plane.normal)
	
	# create meshes
	
	# create arraymeshes from builders
	
	var arraymesh_upper = ArrayMesh.new()
	var arraymesh_lower = ArrayMesh.new()
	
	arraymesh_upper.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, upper_surface_builder.build())
	arraymesh_lower.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lower_surface_builder.build())
	
	# create mesh instances
	
	var upper_meshinstance = _create_mesh_instance(arraymesh_upper, mesh_instance)
	var lower_meshinstance = _create_mesh_instance(arraymesh_lower, mesh_instance)
	
	# create caps
	
	# create cap arraymeshes
	
	var cap_arraymesh_upper = ArrayMesh.new()
	var cap_arraymesh_lower = ArrayMesh.new()
	
	cap_arraymesh_upper.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, upper_cap_builder.build())
	cap_arraymesh_lower.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lower_cap_builder.build())
	
	var cap_upper_meshinstance = _create_mesh_instance(cap_arraymesh_upper, mesh_instance)
	var cap_lower_meshinstance = _create_mesh_instance(cap_arraymesh_lower, mesh_instance)
	
	# set cap material
	
	cap_upper_meshinstance.set_surface_override_material(0, cap_material)
	cap_lower_meshinstance.set_surface_override_material(0, cap_material)
	
	# testing for visibility
	
	lower_meshinstance.position += Vector3(-4,0,0)
	cap_lower_meshinstance.position += Vector3(-4, 0, 0)


# -- PLANE MATH / HELPERS 


# returns positive, negative or zero
func _tri_plane_intersection(mdt : MeshDataTool, tri_index : int, plane : Plane) -> int:
	
	var a = mdt.get_vertex(mdt.get_face_vertex(tri_index, 0))
	var b = mdt.get_vertex(mdt.get_face_vertex(tri_index, 1))
	var c = mdt.get_vertex(mdt.get_face_vertex(tri_index, 2))
	
	var a_dist = plane.distance_to(a)
	var b_dist = plane.distance_to(b)
	var c_dist = plane.distance_to(c)
	
	# if touching, still counts
	
	if a_dist <= 0 and b_dist <= 0 and c_dist <= 0 : return -1
	elif a_dist >= 0 and b_dist >= 0 and c_dist >= 0 : return  1 
	
	return 0


func _plane_segment_intersection(plane : Plane, a : Vector3, b : Vector3):
	
	var ray_normal = (b - a)
	var ray_origin = a
	
	var dot_normals = ray_normal.dot(plane.normal)
	
	# ray and plane are orthogonal (no intersection)
	
	if is_zero_approx(dot_normals): 
		print("dot normals zero")
		return null
	
	# intersection calculation
	
	var t = -(ray_origin.dot(plane.normal) - plane.d) / dot_normals
	if is_zero_approx(t) : 
		print("t approx zero")
		return null
	
	# intersect is not within segment
	
	#if (t * t) > (b - a).length_squared() :
		#print("t longer than segment: ", t, ", ", (b - a).length())
		#return null
	
	print(t)
	
	# return intersect
	
	return a + ray_normal * t


# -- ARRAYMESH / MESHINSTANCE / MDT


# populate mdt from mesh or primitive -> arraymesh

func _create_mdt(mesh : Mesh) -> MeshDataTool:
	
	var mdt = MeshDataTool.new()
	
	if mesh is PrimitiveMesh:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays())
		mdt.create_from_surface(array_mesh, 0)
	else:
		mdt.create_from_surface(mesh, 0)
		
	return mdt


func _create_mesh_instance(mesh : Mesh, old_instance : MeshInstance3D):
	
	var meshinstance_new = MeshInstance3D.new()
	meshinstance_new.mesh = mesh
	add_child(meshinstance_new)
	
	meshinstance_new.set_surface_override_material(0, old_instance.get_surface_override_material(0))
	meshinstance_new.global_transform = old_instance.global_transform
	
	return meshinstance_new


func _replace_meshinstance(mesh : Mesh):
	
	var meshinstance_new = MeshInstance3D.new()
	meshinstance_new.mesh = mesh
	meshinstance_new.set_surface_override_material(0, meshinstance.get_surface_override_material(0))
	
	add_child(meshinstance_new)
	meshinstance_new.global_transform = meshinstance.global_transform
	#meshinstance.queue_free()


func _visualize_marker(pos, text = "", color = Color.RED):
	var marker = INTERSECTMARKER.instantiate()
	add_child(marker)
	marker.position = pos
	marker.label.text = text
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	marker.set_surface_override_material(0, mat)
	markers.append(marker)

func _clear_markers():
	for m in markers: 
		m.queue_free()
	markers.clear()
