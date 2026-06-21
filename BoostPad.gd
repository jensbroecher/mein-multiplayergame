extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body.has_method("client_start_boost") and body.has_method("is_multiplayer_authority"):
		if body.is_multiplayer_authority():
			if body.multiplayer.multiplayer_peer != null:
				body.client_start_boost.rpc()
			else:
				body.client_start_boost()
