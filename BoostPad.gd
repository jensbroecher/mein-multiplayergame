extends Area3D

@onready var decal = $Decal

func _ready():
	body_entered.connect(_on_body_entered)
	if decal:
		decal.texture_emission = decal.texture_albedo
		decal.emission_energy = 0.0

func _on_body_entered(body: Node3D):
	if body.has_method("client_start_pad_boost"):
		flash_boost_pad()
		if body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
			if body.multiplayer.multiplayer_peer != null:
				body.client_start_pad_boost.rpc()
			else:
				body.client_start_pad_boost()

func flash_boost_pad():
	if decal:
		var tween = create_tween()
		decal.emission_energy = 8.0 # Flash brightly
		# Smoothly fade back to 0.0
		tween.tween_property(decal, "emission_energy", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
