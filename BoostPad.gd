extends Area3D

@export var flash_brightness: float = 3.0
## Multiplier for pad boost force / top speed (1.0 = default). Set per pad in the inspector.
@export_range(0.1, 5.0, 0.05) var boost_strength: float = 1.0
## How long the boost lasts in seconds.
@export_range(0.2, 8.0, 0.1) var boost_duration: float = 2.0

var mesh_instances: Array[MeshInstance3D] = []
var mats: Array[BaseMaterial3D] = []
var flash_tween: Tween

func _ready():
	body_entered.connect(_on_body_entered)
	_find_mesh_instances(self)
	_init_materials()

func _find_mesh_instances(node: Node):
	if node is MeshInstance3D:
		mesh_instances.append(node)
	for child in node.get_children():
		_find_mesh_instances(child)

func _init_materials():
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var active_mat = mesh_instance.get_active_material(i)
				if active_mat is BaseMaterial3D:
					var duplicated_mat = active_mat.duplicate()
					mesh_instance.set_surface_override_material(i, duplicated_mat)
					duplicated_mat.emission_enabled = true
					if duplicated_mat.emission_texture == null:
						duplicated_mat.emission_texture = duplicated_mat.albedo_texture
					if duplicated_mat.emission == Color.BLACK:
						duplicated_mat.emission = Color.WHITE
					duplicated_mat.emission_energy_multiplier = 0.0
					mats.append(duplicated_mat)

func _on_body_entered(body: Node3D):
	if body.has_method("client_start_pad_boost"):
		flash_boost_pad()
		if NetworkManager.current_game_mode != NetworkManager.GameMode.MULTIPLAYER:
			if body.get("is_local_player") or body.get("is_ai"):
				body.client_start_pad_boost(boost_strength, boost_duration)
		else:
			if body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
				body.client_start_pad_boost.rpc(boost_strength, boost_duration)

func flash_boost_pad():
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
		
	for mat in mats:
		mat.emission_energy_multiplier = flash_brightness
		
	flash_tween = create_tween().set_parallel(true)
	for mat in mats:
		flash_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
