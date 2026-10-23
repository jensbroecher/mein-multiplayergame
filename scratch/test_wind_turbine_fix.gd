@tool
extends SceneTree

const WindTurbineBuilder = preload("res://WindTurbineBuilder.gd")

func _init() -> void:
	print("Checking compilation of WindTurbineBuilder...")
	var t = WindTurbineBuilder.new()
	print("Instantiated successfully.")
	quit()
