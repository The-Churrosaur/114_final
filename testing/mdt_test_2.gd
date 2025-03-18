extends Node3D

@export var meshinstance : MeshInstance3D
@export var plane : Plane

const INTERSECTMARKER = preload("res://intersectmarker.tscn")
const V_MARKER = preload("res://v_marker.tscn")


func _ready() -> void:
	#transform_mesh()
	test_transform()
	pass


func test_transform():
	
	# populate mdt from mesh or primitive -> arraymesh
	var mdt = MeshDataTool.new()
	print(meshinstance.mesh)
	if meshinstance.mesh is PrimitiveMesh:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, meshinstance.mesh.get_mesh_arrays())
		mdt.create_from_surface(array_mesh, 0)
	else:
		mdt.create_from_surface(meshinstance.mesh, 0)
	
	# test transformation
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		vertex += mdt.get_vertex_normal(i)
		mdt.set_vertex(i, vertex)
	
	# build surface array for new arraymesh
	var surface_builder = SurfaceArrayBuilder.new()
	for i in range(mdt.get_face_count()): surface_builder.add_tri_from_mdt(mdt, i)
	
	# push mesh
	var arraymesh = ArrayMesh.new()
	arraymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_builder.build())
	
	#mdt.commit_to_surface(new_mesh)
	_replace_meshinstance(arraymesh)





func _replace_meshinstance(mesh : Mesh):
	
	var meshinstance_new = MeshInstance3D.new()
	meshinstance_new.mesh = mesh
	meshinstance_new.set_surface_override_material(0, meshinstance.get_surface_override_material(0))
	
	add_child(meshinstance_new)
	meshinstance_new.global_transform = meshinstance.global_transform
	#meshinstance.queue_free()
