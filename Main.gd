extends Node

const LEVEL_SCENE = preload("res://Level.tscn")

func _ready():
	pass

func start_game(is_host: bool):
	if is_host:
		var level = LEVEL_SCENE.instantiate()
		add_child(level)
	# Clients will get the level spawned automatically by MultiplayerSpawner
