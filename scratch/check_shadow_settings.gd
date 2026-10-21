extends SceneTree

func _init() -> void:
	print("--- DirectionalLight3D Default Properties ---")
	var dl := DirectionalLight3D.new()
	print("shadow_bias: ", dl.shadow_bias)
	print("shadow_normal_bias: ", dl.shadow_normal_bias)
	print("shadow_blur: ", dl.shadow_blur)
	print("directional_shadow_mode: ", dl.directional_shadow_mode)
	print("directional_shadow_max_distance: ", dl.directional_shadow_max_distance)
	print("directional_shadow_pancake_size: ", dl.directional_shadow_pancake_size)
	print("directional_shadow_fade_start: ", dl.directional_shadow_fade_start)
	print("directional_shadow_blend_splits: ", dl.directional_shadow_blend_splits)
	dl.free()
	quit()
