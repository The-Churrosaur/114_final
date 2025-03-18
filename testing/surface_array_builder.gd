
## builds a surface array from mdt data. Does not use indices to build tris
class_name SurfaceArrayBuilder
extends RefCounted


var verts = PackedVector3Array()
var uvs = PackedVector2Array()
var normals = PackedVector3Array()

## face index
func add_tri_from_mdt(mdt : MeshDataTool, i : int):
	
	var v0 = mdt.get_face_vertex(i, 0)
	var v1 = mdt.get_face_vertex(i, 1)
	var v2 = mdt.get_face_vertex(i, 2)
	
	add_vert_from_mdt(mdt, v0)
	add_vert_from_mdt(mdt, v1)
	add_vert_from_mdt(mdt, v2)


## adds a single vert - unpredictable
func add_vert_from_mdt(mdt : MeshDataTool, i : int):
	
	var vertex = mdt.get_vertex(i)
	var uv = mdt.get_vertex_uv(i)
	var normal = mdt.get_vertex_normal(i)
	
	verts.append(vertex)
	uvs.append(uv)
	normals.append(normal)


## what it says on the tin
func add_vert_manual(vertex : Vector3, uv: Vector2, normal: Vector3):
	verts.append(vertex)
	uvs.append(uv)
	normals.append(normal)


func build() -> Array: 
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	return surface_array
