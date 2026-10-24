extends Control
## An item's symbol in the HUD (the item slots, the kill feed): the same white outline the item boxes
## show (ItemSymbols.gd), drawn as anti-aliased lines over a soft dark edge so it reads on any
## background. `item` is PlayerCart.ItemType's name; empty or "NONE" draws nothing.

const ItemSymbols = preload("res://ItemSymbols.gd")

@export var item := "":
	set(v):
		item = v
		queue_redraw()
## Stroke width as a share of the icon's size.
@export var stroke := 0.065
@export var colour := Color(1, 1, 1)
@export var edge := Color(0.02, 0.04, 0.08, 0.55)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if item == "" or item == "NONE":
		return
	var side := minf(size.x, size.y)
	var half := side * 0.42
	var centre := size * 0.5
	var w := maxf(side * stroke, 1.2)
	var strokes := ItemSymbols.strokes(item)
	for pass_i in 2:
		var col := edge if pass_i == 0 else colour
		var width := w * 2.2 if pass_i == 0 else w
		for s in strokes:
			if s.size() > 2:
				var c: Vector2 = centre + Vector2(s[0].x, -s[0].y) * half
				draw_circle(c, maxf(float(s[1]) * half, w * 0.6) + (w * 0.6 if pass_i == 0 else 0.0), col)
				continue
			var pts := PackedVector2Array()
			for p in (s[0] as PackedVector2Array):
				pts.append(centre + Vector2(p.x, -p.y) * half)
			if s[1]:
				pts.append(pts[0])
			draw_polyline(pts, col, width, true)
