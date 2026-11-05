extends Node3D
## A grid slot's marking (SpawnIndicator.tscn: a flat 2m quad). It is placed by its spawn point, a child of the finish
## gate's node, which stands anywhere from on the road to 0.4m off it, and laid flat in the level's frame, so on many
## stages the slots floated over the asphalt or stood off a sloping grid at one end. Once the level's collision exists
## it lies down on the surface under it: the plane through four rays at its corners (the middle's normal if they don't
## all land), LIFT over it, keeping its heading. The rays look past the carts already standing on the grid.

## How far over the surface the quad lies (enough to win the depth test against the road at the grid's distances).
const LIFT := 0.035
const HALF := 0.9


func _ready() -> void:
	_settle()


func _settle() -> void:
	await get_tree().physics_frame
	var level: Node = get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level == null or not level.has_method("wait_for_collisions"):
		return
	await level.wait_for_collisions()
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c is CollisionObject3D:
			exclude.append((c as CollisionObject3D).get_rid())
	var xf := global_transform
	var flat := Basis(Vector3.UP, xf.basis.get_euler().y)
	var mid := _ground(space, xf.origin, exclude, INF)
	if mid.is_empty():
		return
	var base: Vector3 = mid["position"]
	var normal: Vector3 = mid["normal"]
	var corners: Array[Vector3] = []
	for o in [Vector3(HALF, 0, HALF), Vector3(-HALF, 0, HALF), Vector3(-HALF, 0, -HALF), Vector3(HALF, 0, -HALF)]:
		var h := _ground(space, xf.origin + flat * o, exclude, base.y)
		if h.is_empty():
			break
		corners.append(h["position"])
	if corners.size() == 4:
		var n: Vector3 = (corners[2] - corners[0]).cross(corners[3] - corners[1]).normalized()
		if n.y < 0.0:
			n = -n
		if n.y > 0.75:
			normal = n
	var fwd := -flat.z
	fwd -= normal * fwd.dot(normal)
	var sc := xf.basis.get_scale()
	global_transform = Transform3D(Basis.looking_at(fwd.normalized(), normal).scaled(sc), base + normal * LIFT)
	# The quad sits at the node's 5cm; the lift above is the whole of it.
	var mesh := get_node_or_null("MeshInstance3D") as Node3D
	if mesh:
		mesh.position = Vector3.ZERO


## The surface straight under `at` (from 3m over it), or empty if nothing fairly level is there, or (given `near`) it is
## more than a metre off that height.
func _ground(space: PhysicsDirectSpaceState3D, at: Vector3, exclude: Array[RID], near: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at - Vector3.UP * 6.0, 1)
	q.exclude = exclude
	q.hit_back_faces = false
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6:
		return {}
	if near != INF and absf((hit["position"] as Vector3).y - near) > 1.0:
		return {}
	return hit
