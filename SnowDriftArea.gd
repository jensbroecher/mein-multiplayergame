# SnowDriftArea.gd
# Soft, non-blocking snow drift volume that allows vehicles to sink smoothly
# into the snow without bouncing or launching, while applying powdery snow drag and tire spray.
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_snow_drift"):
		body.enter_snow_drift()
	elif "is_in_snow" in body:
		body.set("is_in_snow", true)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_snow_drift"):
		body.exit_snow_drift()
	elif "is_in_snow" in body:
		body.set("is_in_snow", false)
