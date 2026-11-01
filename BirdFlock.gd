class_name BirdFlock
extends Node3D
## A flock of five birds (models/animals/birds.glb: one skeleton, one flapping animation, the five laid out
## in a loose group) that circles over the level. The node's position is the middle of the circle, so a level
## stores only the transform and the exports; the model is instanced when the node enters the tree.
## Local scenery, not synced, with no collider.

@export var model: PackedScene = preload("res://models/animals/birds.glb")
## The model is 0.37m across a bird: the level's wildlife is about twice life size, to suit the RC carts.
@export var bird_scale: float = 6.0
## Radius of the circle (metres) and the flock's speed along it (m/s).
@export var radius: float = 90.0
@export var speed: float = 11.0
@export var clockwise: bool = false
## Slow rise and fall of the flock and how far (metres) each way.
@export var bob_height: float = 2.5
@export var bob_period: float = 7.0
## Flapping speed (1 is the file's own, 0.68s a beat) and how far the flock banks into the turn (degrees).
@export var flap_speed: float = 1.0
@export var bank_deg: float = 14.0
## Turns the model so its beaks lead along the flight (degrees about up).
@export var model_yaw_deg: float = 0.0
## The model's middle in its own frame (the mean of the five birds), moved onto the node's pivot.
@export var model_centre: Vector3 = Vector3(0.0, 0.0, 0.44)
## Which of the file's animations flaps ("" the first), and nodes of the file to drop (a camera, a light).
@export var animation_name: String = ""
@export var drop_nodes: PackedStringArray = []
## For a file of a single bird: how many copies to fly together, scattered over `spread` (metres, at the
## node's scale: x across, y up, z along the flight), each flapping at its own phase and rate. 1 flies the
## model once, as it comes (birds.glb already holds five).
## A texture to lay over the model's own material, for a file that came without it (the seagull's lives in
## its own folder and the .blend doesn't name it).
@export var albedo_texture: Texture2D
@export var copies: int = 1
@export var spread: Vector3 = Vector3(12.0, 3.0, 12.0)

var _angle: float = 0.0
var _pivot: Node3D
var _time: float = 0.0


func _ready() -> void:
	if model == null:
		return
	_pivot = Node3D.new()
	_pivot.name = "FlockPivot"
	add_child(_pivot, false, Node.INTERNAL_MODE_FRONT)
	for i in maxi(copies, 1):
		var body := model.instantiate() as Node3D
		body.name = "Birds%d" % i
		body.scale = Vector3.ONE * bird_scale
		body.rotation.y = deg_to_rad(model_yaw_deg)
		body.position = -(body.basis * model_centre)
		if copies > 1:
			body.position += Vector3(randf_range(-1.0, 1.0) * spread.x, randf_range(-1.0, 1.0) * spread.y,
				randf_range(-1.0, 1.0) * spread.z)
		_pivot.add_child(body)
		for dn in drop_nodes:
			var d := body.find_child(dn, true, false)
			if d != null:
				d.get_parent().remove_child(d)
				d.free()
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The skinned birds' bounds are the bind pose's: don't cull them as they flap.
			(mi as MeshInstance3D).extra_cull_margin = 4.0
			if albedo_texture != null:
				_texture(mi as MeshInstance3D)
		var players := body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var ap := players[0] as AnimationPlayer
			var names := ap.get_animation_list()
			var pick := animation_name if animation_name in names else (names[0] if not names.is_empty() else "")
			if pick != "":
				var anim := ap.get_animation(pick)
				anim.loop_mode = Animation.LOOP_LINEAR
				ap.speed_scale = flap_speed * (randf_range(0.9, 1.1) if copies > 1 else 1.0)
				ap.play(pick)
				ap.seek(randf() * anim.length, true)
	# Each flock starts at its own place on the circle.
	_angle = randf() * TAU
	_time = randf() * 100.0
	_place(0.0)


func _texture(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for surf in mi.mesh.get_surface_count():
		var src := mi.get_active_material(surf)
		var mat: StandardMaterial3D = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
		mat.albedo_texture = albedo_texture
		mat.albedo_color = Color.WHITE
		mat.roughness = 0.9
		mi.set_surface_override_material(surf, mat)


func _process(delta: float) -> void:
	_place(delta)


func _place(delta: float) -> void:
	if _pivot == null:
		return
	var dir := -1.0 if clockwise else 1.0
	_angle += dir * speed / maxf(radius, 1.0) * delta
	_time += delta
	var y := sin(_time * TAU / maxf(bob_period, 0.1)) * bob_height
	_pivot.position = Vector3(cos(_angle) * radius, y, sin(_angle) * radius)
	# The tangent is the flight's heading; the model's own forward is -z.
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle)) * dir
	var basis := Basis.looking_at(tangent, Vector3.UP)
	# Banking into the turn: the inside wing drops.
	basis = basis * Basis(Vector3.FORWARD, deg_to_rad(bank_deg) * dir)
	_pivot.basis = basis
