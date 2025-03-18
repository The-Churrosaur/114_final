extends Node3D

@export var meshinstance : MeshInstance3D
@export var plane : Plane

const INTERSECTMARKER = preload("res://intersectmarker.tscn")
const V_MARKER = preload("res://v_marker.tscn")

# helper struct (sigh)
class MyIntersectEdge:
	var v0_index : int 
	var v1_index : int
	var intersect : Vector3 = Vector3.ZERO


## squish vertices on positive or negative side? this side to be cut
var plane_cut_side = -1.0


func _ready() -> void:
	transform_mesh()
	#test_transform()
	pass


func test_transform():
	
	var mdt = MeshDataTool.new()
	print(meshinstance.mesh)
	if meshinstance.mesh is PrimitiveMesh:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, meshinstance.mesh.get_mesh_arrays())
		mdt.create_from_surface(array_mesh, 0)
	else:
		mdt.create_from_surface(meshinstance.mesh, 0)
	print(mdt.get_vertex_count())
	
	for i in range(mdt.get_vertex_count()):
		print("vertex: ", mdt.get_vertex(i))
		var vertex = mdt.get_vertex(i)
		vertex += mdt.get_vertex_normal(i) * 10
		mdt.set_vertex(i, vertex)
	
	# push mesh
	var new_mesh = ArrayMesh.new()
	mdt.commit_to_surface(new_mesh)
	_replace_meshinstance(new_mesh)


func transform_mesh():
	
	var mdt = MeshDataTool.new()
	
	# fill mdt from primitive or mesh
	
	if meshinstance.mesh is PrimitiveMesh:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, meshinstance.mesh.get_mesh_arrays())
		mdt.create_from_surface(array_mesh, 0)
	else:
		mdt.create_from_surface(meshinstance.mesh, 0)
	
	# fill intersects, points to push and place to push to
	
	# should be index synced
	var intersect_edges : Array[MyIntersectEdge]
	var cut_side_verts : PackedInt32Array = []
	var intersect_com : Vector3 = Vector3.ZERO
	
	for i in range(mdt.get_vertex_count()):
		print(mdt.get_vertex(i))
	
	for i in range(mdt.get_edge_count()):
		
		var v0_index = mdt.get_edge_vertex(i, 0)
		var v1_index = mdt.get_edge_vertex(i, 1)
		var v0 = mdt.get_vertex(v0_index)
		var v1 = mdt.get_vertex(v1_index)
		
		var intersect_point = plane.intersects_segment(v1, v0)
		var v0_distance = plane.distance_to(v0)
		var v1_distance = plane.distance_to(v1)
		
		# if intersect
		if intersect_point: 
			
			#print("segment intersecting: ", v0, v1)
			#print("intersection:         ", intersect_point)
			
			#var v_0_marker = V_MARKER.instantiate()
			#var v_1_marker = V_MARKER.instantiate()
			#var intersectmarker = INTERSECTMARKER.instantiate()
			#add_child(v_0_marker)
			#add_child(v_1_marker)
			#add_child(intersectmarker)
			#
			#v_0_marker.position = v0
			#v_1_marker.position = v1
			#intersectmarker.position = intersect_point
			
			# append to intersect edges
			var my_edge = MyIntersectEdge.new()
			my_edge.v0_index = v0_index
			my_edge.v1_index = v1_index
			my_edge.intersect = intersect_point
			intersect_edges.append(my_edge)
			
			# update com
			if intersect_com == Vector3.ZERO: intersect_com = intersect_point
			else: intersect_com += intersect_point; intersect_com /= 2.0 
		
		# elif segment is on cut side
		elif sign(plane.distance_to(v1)) * plane_cut_side > 0:
			cut_side_verts.append(v0_index)
			cut_side_verts.append(v1_index)
	
	# push intersect verts (after iteration)
	
	for my_edge in intersect_edges:
		
		await get_tree().create_timer(5.0).timeout
		
		var v0_index = my_edge.v0_index
		var v1_index = my_edge.v1_index
		var v0 = mdt.get_vertex(v0_index)
		var v1 = mdt.get_vertex(v1_index)
		
		var v0_distance = plane.distance_to(v0)
		var v1_distance = plane.distance_to(v1)
		
		# get cut_side vert
		var cut_vert_index = null
		if sign(v0_distance) == plane_cut_side: cut_vert_index = v0_index
		if sign(v1_distance) == plane_cut_side: cut_vert_index = v1_index
		
		# special case, cut side vert is actually coplanar (nothing to cut)
		if !cut_vert_index or plane.has_point(mdt.get_vertex(cut_vert_index)): 
			continue
		
		#print("intersecting vertex pushed: ", mdt.get_vertex(cut_vert_index), my_edge.intersect)
		var v_0_marker = V_MARKER.instantiate()
		var intersectmarker = INTERSECTMARKER.instantiate()
		add_child(v_0_marker)
		add_child(intersectmarker)
		
		v_0_marker.position = mdt.get_vertex(cut_vert_index)
		intersectmarker.position = my_edge.intersect
		
		# push cut vert to intersect
		print("my edge intersect ", my_edge.intersect)
		print("old ver pos: ", mdt.get_vertex(cut_vert_index))
		mdt.set_vertex(cut_vert_index, my_edge.intersect)
		print("new ver pos: ", mdt.get_vertex(cut_vert_index))
		
		var new_mesh = ArrayMesh.new()
		mdt.commit_to_surface(new_mesh)
		_replace_meshinstance(new_mesh)
		
		
		# TODO interpolate UV
	
	# push cut_side verts to com
	for vert_index in cut_side_verts:
		mdt.set_vertex(vert_index, intersect_com)
	
	# push mesh
	var new_mesh = ArrayMesh.new()
	mdt.commit_to_surface(new_mesh)
	_replace_meshinstance(new_mesh)


func side_or_intersect(v1, v0):
	if plane.intersects_segment(v1, v0): return 0
	else: return sign(plane.distance_to(v1))


func _replace_meshinstance(mesh : Mesh):
	
	var meshinstance_new = MeshInstance3D.new()
	meshinstance_new.mesh = mesh
	meshinstance_new.set_surface_override_material(0, meshinstance.get_surface_override_material(0))
	
	add_child(meshinstance_new)
	meshinstance_new.global_transform = meshinstance.global_transform
	#meshinstance.queue_free()
