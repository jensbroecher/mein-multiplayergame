# AuroraClock.gd
#
# Advances the `aurora_clock` global shader uniform that animates aurora_sky.gdshader.
#
# The sky reads this instead of TIME on purpose: a sky shader that uses TIME makes Godot rebuild
# the radiance cubemap every frame, while a global float only moves the visible sky. Declared in
# project.godot under [shader_globals].
extends Node

func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"aurora_clock", Time.get_ticks_msec() * 0.001)
