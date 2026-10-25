extends Node3D
## A race car on show (the Lakeside paddock's tables): the car's own meshes at race size, laid out by
## the generator like the car's scene, and its paint job (CarPaint) applied at load, since paint is
## per-instance shader parameters on the meshes.

const CarPaint = preload("res://CarPaint.gd")

@export var paint: Dictionary = {}


func _ready() -> void:
	if not paint.is_empty():
		CarPaint.apply(self, paint)
