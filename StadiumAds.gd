extends Node
## Nyota Stadium's sponsor artwork: draws every board's advert into one atlas when the level
## loads and hands it to the board and sign materials (`ads_tex`).
##
## The level generator runs headless, where nothing can draw text, so the artwork is made here:
## a SubViewport renders the cells once, the image is copied out with mipmaps (a viewport texture
## has none, and the boards are seen from far across the bowl) and the viewport is freed.
## Fictional sponsors only.

## Materials that sample the atlas.
@export var targets: Array[ShaderMaterial] = []

const COLS := 2
const ROWS := 8
const CELL := Vector2i(1024, 128)

## [main text, small text, background, text colour, accent colour, layout 0..2]
const ADS := [
	["MATUMAINI GP", "RC VIBE GRAND PRIX", Color(0.93, 0.42, 0.07), Color(1, 1, 1), Color(0.05, 0.32, 0.17), 0],
	["NYOTA STADIUM", "KARIBU!", Color(0.05, 0.30, 0.16), Color(0.98, 0.80, 0.15), Color(0.93, 0.42, 0.07), 1],
	["KAHAWA BORA", "COFFEE FROM THE HIGHLANDS", Color(0.95, 0.90, 0.78), Color(0.30, 0.17, 0.08), Color(0.62, 0.36, 0.14), 2],
	["SIMU+", "4G  5G  EVERYWHERE", Color(0.97, 0.97, 0.96), Color(0.08, 0.52, 0.24), Color(0.95, 0.75, 0.10), 0],
	["JUA SOLAR", "POWER FROM THE SUN", Color(0.98, 0.78, 0.10), Color(0.08, 0.08, 0.08), Color(0.93, 0.42, 0.07), 2],
	["BARABARA TYRES", "GRIP ON ANY ROAD", Color(0.07, 0.07, 0.08), Color(0.98, 0.80, 0.12), Color(0.85, 0.85, 0.85), 0],
	["KILELE ENERGY", "FUEL  LUBRICANTS", Color(0.07, 0.24, 0.58), Color(1, 1, 1), Color(0.95, 0.28, 0.12), 1],
	["MBUNI AIR", "FLY THE SAVANNA", Color(0.28, 0.58, 0.88), Color(1, 1, 1), Color(0.98, 0.82, 0.25), 2],
	["HARAKA PAY", "SEND  PAY  SAVE", Color(0.09, 0.48, 0.24), Color(1, 1, 1), Color(0.98, 0.80, 0.12), 0],
	["CHAI MOTO", "HOT TEA, COLD DRINKS", Color(0.74, 0.09, 0.10), Color(1, 1, 1), Color(0.98, 0.80, 0.15), 1],
	["TWIGA CEMENT", "BUILT TO LAST", Color(0.52, 0.53, 0.55), Color(0.98, 0.55, 0.12), Color(0.15, 0.15, 0.16), 2],
	["MAJI SAFI", "PURE SPRING WATER", Color(0.72, 0.88, 0.98), Color(0.05, 0.22, 0.52), Color(0.10, 0.50, 0.85), 0],
	["SAMAKI FOODS", "FRESH FROM THE LAKE", Color(0.04, 0.42, 0.45), Color(1, 1, 1), Color(0.98, 0.70, 0.20), 1],
	["RC VIBE GP", "SEASON 2026", Color(0.30, 0.12, 0.50), Color(1, 1, 1), Color(0.98, 0.72, 0.20), 2],
	["SIMBA MOTORS", "SINCE 1974", Color(0.45, 0.06, 0.08), Color(0.98, 0.82, 0.35), Color(0.98, 0.82, 0.35), 0],
	["BAHATI LOTTO", "TRY YOUR LUCK", Color(0.80, 0.10, 0.50), Color(0.99, 0.92, 0.20), Color(1, 1, 1), 1],
]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * COLS, CELL.y * ROWS)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "sans-serif"])
	bold.font_weight = 900
	var plain := SystemFont.new()
	plain.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	plain.font_weight = 700
	for i in range(ADS.size()):
		_draw_cell(vp, i, ADS[i], bold, plain)
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img: Image = vp.get_texture().get_image()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	for m in targets:
		if m:
			m.set_shader_parameter("ads_tex", tex)
	vp.queue_free()


func _draw_cell(vp: SubViewport, i: int, ad: Array, bold: Font, plain: Font) -> void:
	var cell := Control.new()
	cell.position = Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y)
	cell.size = Vector2(CELL)
	cell.clip_contents = true
	vp.add_child(cell)
	var bg := ColorRect.new()
	bg.color = ad[2]
	bg.size = Vector2(CELL)
	cell.add_child(bg)
	var layout: int = ad[5]
	var fg: Color = ad[3]
	var accent: Color = ad[4]
	var text_x := 40.0
	if layout == 0:
		# A slanted accent band on the left.
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([Vector2(0, 0), Vector2(150, 0), Vector2(110, 128), Vector2(0, 128)])
		band.color = accent
		cell.add_child(band)
		var band2 := Polygon2D.new()
		band2.polygon = PackedVector2Array([Vector2(160, 0), Vector2(180, 0), Vector2(140, 128), Vector2(120, 128)])
		band2.color = accent
		cell.add_child(band2)
		text_x = 200.0
	elif layout == 1:
		# A round badge with a star.
		var disc := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in range(40):
			var a: float = TAU * float(k) / 40.0
			pts.append(Vector2(86, 64) + Vector2(cos(a), sin(a)) * 50.0)
		disc.polygon = pts
		disc.color = accent
		cell.add_child(disc)
		var star := Polygon2D.new()
		var sp := PackedVector2Array()
		for k in range(10):
			var a2: float = -PI * 0.5 + TAU * float(k) / 10.0
			var r: float = 34.0 if k % 2 == 0 else 14.0
			sp.append(Vector2(86, 66) + Vector2(cos(a2), sin(a2)) * r)
		star.polygon = sp
		star.color = ad[2]
		cell.add_child(star)
		text_x = 170.0
	else:
		# Underlined, with stripes at the right end.
		var line := ColorRect.new()
		line.color = accent
		line.position = Vector2(40, 104)
		line.size = Vector2(600, 8)
		cell.add_child(line)
		for k in range(3):
			var st := Polygon2D.new()
			var x0: float = 860.0 + k * 50.0
			st.polygon = PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 30, 0), Vector2(x0 - 10, 128), Vector2(x0 - 40, 128)])
			st.color = accent
			cell.add_child(st)
	var main := Label.new()
	main.text = ad[0]
	main.add_theme_font_override("font", bold)
	main.add_theme_font_size_override("font_size", 76)
	main.add_theme_color_override("font_color", fg)
	main.add_theme_constant_override("outline_size", 4)
	main.add_theme_color_override("font_outline_color", fg)
	main.position = Vector2(text_x, 4)
	main.size = Vector2(CELL.x - text_x - 20, 96)
	main.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(main)
	var sub := Label.new()
	sub.text = ad[1]
	sub.add_theme_font_override("font", plain)
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", fg.lerp(ad[2], 0.15))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub.position = Vector2(text_x, 84)
	sub.size = Vector2(CELL.x - text_x - 30, 40)
	cell.add_child(sub)
