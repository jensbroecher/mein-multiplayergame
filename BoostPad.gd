extends Area3D

@onready var mesh_instance = $Decal

var mat: StandardMaterial3D

func _ready():
	body_entered.connect(_on_body_entered)
	if mesh_instance:
		# Duplicate material so instance values don't leak to other boost pads
		mat = mesh_instance.get_active_material(0).duplicate()
		mesh_instance.material_override = mat
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0

func _on_body_entered(body: Node3D):
	if body.has_method("client_start_pad_boost"):
		flash_boost_pad()
		if NetworkManager.current_game_mode != NetworkManager.GameMode.MULTIPLAYER:
			if body.get("is_local_player"):
				body.client_start_pad_boost()
		else:
			if body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
				body.client_start_pad_boost.rpc()

func flash_boost_pad():
	if mesh_instance and mat:
		mat.emission_energy_multiplier = 8.0
		var tween = create_tween()
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
