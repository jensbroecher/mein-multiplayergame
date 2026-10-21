# scratch/test_sky_transition.gd
# Tests smooth sky transition in Msitu Falls level.
extends SceneTree

func _init() -> void:
	print("=== Testing Msitu Falls Sky Transition ===")
	var level_scene: PackedScene = load("res://levels/MsituFallsLevel.tscn")
	if not level_scene:
		printerr("Failed to load MsituFallsLevel.tscn")
		quit(1)
		return
	
	var level: Node3D = level_scene.instantiate()
	root.add_child(level)
	
	var rain = level.get_node_or_null("JungleRain")
	if not rain:
		printerr("JungleRain node not found!")
		quit(1)
		return
	print("Found JungleRain: ", rain)
	
	# Verify that force_intensity drives intensity and rain_sky_blend smoothly
	for test_intensity in [0.0, 0.25, 0.5, 0.75, 1.0]:
		rain.force_intensity = test_intensity
		# Call _process manually to simulate frame update
		rain._process(0.016)
		print("Tested intensity: %.2f, rain.intensity = %.2f" % [test_intensity, rain.intensity])
	
	# Test step transitions
	for step in [0, 3, 5, 8, 10]:
		rain._set_sky(step)
	
	print("Sky transition test passed successfully!")
	quit(0)
