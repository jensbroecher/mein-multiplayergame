# CarPaint.gd
#
# Paint jobs for the procedural cars (regenerate_cars.gd). A paint job is a small Dictionary:
#   {"pattern": int, "finish": int, "primary": Color, "secondary": Color, "accent": Color,
#    "rim": Color, "number": int}
# The player picks it in CarSelection (saved per car in user://settings.cfg), NetworkManager
# carries it in the player's info, Level passes it to the spawned cart, and apply() writes it as
# per-instance parameters of car_body.gdshader on every mesh tagged "car_shader". Anything that
# arrives over the network goes through sanitize() first.
extends RefCounted

## Keep in step with car_body.gdshader's PAT_* and FIN_*.
const PATTERNS := ["Solid", "Racing Stripes", "Two-Tone", "Side Stripe", "Flames", "Checkered", "Camo",
	"Racer", "Fade", "Splinter", "Tiger", "Rally", "Streaks"]
const FINISHES := ["Gloss", "Metallic", "Matte", "Pearl", "Chrome"]

## The paint shop's colours (sRGB).
const PALETTE := [
	["Racing Red", Color(0.80, 0.07, 0.05)], ["Sunset Orange", Color(0.96, 0.42, 0.06)],
	["Taxi Yellow", Color(0.98, 0.78, 0.07)], ["Lime", Color(0.52, 0.82, 0.12)],
	["Mudrunner Teal", Color(0.19, 0.44, 0.38)], ["Racing Green", Color(0.04, 0.27, 0.15)],
	["Ocean Blue", Color(0.07, 0.36, 0.80)], ["Sky", Color(0.45, 0.72, 0.92)],
	["Navy", Color(0.05, 0.09, 0.28)], ["Purple", Color(0.40, 0.13, 0.62)],
	["Hot Pink", Color(0.95, 0.24, 0.55)], ["Snow White", Color(0.94, 0.94, 0.92)],
	["Silver", Color(0.70, 0.72, 0.74)], ["Gunmetal", Color(0.23, 0.25, 0.27)],
	["Jet Black", Color(0.03, 0.03, 0.035)], ["Sand", Color(0.82, 0.70, 0.48)],
	["Olive", Color(0.36, 0.40, 0.20)], ["Chocolate", Color(0.32, 0.18, 0.10)],
	["Strikeforce Lime", Color(0.62, 0.78, 0.24)], ["Graphite", Color(0.36, 0.38, 0.41)],
	["Shadow Violet", Color(0.46, 0.20, 0.82)],
]
const RIMS := [
	["Silver", Color(0.76, 0.77, 0.79)], ["Titanium", Color(0.46, 0.47, 0.49)], ["Gunmetal", Color(0.22, 0.23, 0.25)],
	["Black", Color(0.05, 0.05, 0.055)], ["White", Color(0.92, 0.92, 0.90)],
	["Gold", Color(0.86, 0.63, 0.24)], ["Bronze", Color(0.55, 0.35, 0.18)],
	["Red", Color(0.75, 0.08, 0.06)], ["Blue", Color(0.10, 0.30, 0.78)], ["Orange", Color(0.96, 0.45, 0.08)],
]

## Each model's factory paint; the Hunyuan model's colours for the rebuilt ones.
const FACTORY := {
	"Mudrunner": {"pattern": 0, "finish": 0, "primary": Color(0.19, 0.44, 0.38),
		"secondary": Color(0.94, 0.94, 0.92), "accent": Color(0.80, 0.07, 0.05),
		"rim": Color(0.76, 0.77, 0.79), "number": 53},
	"Phantom": {"pattern": 0, "finish": 0, "primary": Color(0.97, 0.74, 0.10),
		"secondary": Color(0.94, 0.94, 0.92), "accent": Color(0.03, 0.03, 0.035),
		"rim": Color(0.46, 0.47, 0.49), "number": 7},
	"Strikeforce": {"pattern": 0, "finish": 0, "primary": Color(0.62, 0.78, 0.24),
		"secondary": Color(0.94, 0.94, 0.92), "accent": Color(0.80, 0.07, 0.05),
		"rim": Color(0.05, 0.05, 0.055), "number": 24},
	"Centurion": {"pattern": 2, "finish": 1, "primary": Color(0.36, 0.38, 0.41),
		"secondary": Color(0.70, 0.72, 0.74), "accent": Color(0.96, 0.42, 0.06),
		"rim": Color(0.96, 0.45, 0.08), "number": 10},
	"Shadow": {"pattern": 9, "finish": 2, "primary": Color(0.23, 0.25, 0.27),
		"secondary": Color(0.03, 0.03, 0.035), "accent": Color(0.46, 0.20, 0.82),
		"rim": Color(0.22, 0.23, 0.25), "number": 13},
	"Interceptor": {"pattern": 11, "finish": 1, "primary": Color(0.07, 0.36, 0.80),
		"secondary": Color(0.94, 0.94, 0.92), "accent": Color(0.98, 0.78, 0.07),
		"rim": Color(0.86, 0.63, 0.24), "number": 5},
	"Viper": {"pattern": 12, "finish": 0, "primary": Color(0.52, 0.82, 0.12),
		"secondary": Color(0.23, 0.25, 0.27), "accent": Color(0.52, 0.82, 0.12),
		"rim": Color(0.05, 0.05, 0.055), "number": 3},
}
const FALLBACK := {"pattern": 0, "finish": 0, "primary": Color(0.80, 0.07, 0.05),
	"secondary": Color(0.94, 0.94, 0.92), "accent": Color(0.98, 0.78, 0.07),
	"rim": Color(0.76, 0.77, 0.79), "number": 7}


static func factory(car_name: String) -> Dictionary:
	return (FACTORY.get(car_name, FALLBACK) as Dictionary).duplicate()


## Only the valid fields of a paint job (anything else dropped, values clamped). What
## NetworkManager stores from a peer: small, and safe to pass on to everyone in spawn data.
static func clean(value: Variant) -> Dictionary:
	var out := {}
	if not value is Dictionary:
		return out
	var d: Dictionary = value
	if d.get("pattern") is int:
		out["pattern"] = clampi(d["pattern"], 0, PATTERNS.size() - 1)
	if d.get("finish") is int:
		out["finish"] = clampi(d["finish"], 0, FINISHES.size() - 1)
	if d.get("number") is int:
		out["number"] = clampi(d["number"], 0, 99)
	for key in ["primary", "secondary", "accent", "rim"]:
		if d.get(key) is Color:
			var c: Color = d[key]
			out[key] = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), 1.0)
	return out


## A complete paint job for the model from anything (saved, received, or junk): the valid fields
## of `value` over the model's factory paint.
static func sanitize(value: Variant, car_name: String) -> Dictionary:
	var out: Dictionary = factory(car_name)
	out.merge(clean(value), true)
	return out


## Writes the paint job onto every car_body.gdshader mesh under `root`.
static func apply(root: Node, paint: Dictionary) -> void:
	if root is GeometryInstance3D and root.has_meta("car_shader"):
		var g: GeometryInstance3D = root
		g.set_instance_shader_parameter("paint_primary", paint["primary"])
		g.set_instance_shader_parameter("paint_secondary", paint["secondary"])
		g.set_instance_shader_parameter("paint_accent", paint["accent"])
		g.set_instance_shader_parameter("paint_rim", paint["rim"])
		g.set_instance_shader_parameter("paint_pattern", paint["pattern"])
		g.set_instance_shader_parameter("paint_finish", paint["finish"])
		g.set_instance_shader_parameter("paint_number", paint["number"])
	for c in root.get_children():
		apply(c, paint)


## Is this model paintable (a procedural car)?
static func is_paintable(model_root: Node) -> bool:
	return model_root != null and model_root.has_meta("procedural_car")


## A random but presentable paint job (AI carts, the paint shop's dice): the body colour from the
## palette, a secondary that stands out from it, an accent that differs from both.
static func random(rng: RandomNumberGenerator, car_name: String) -> Dictionary:
	var p: Dictionary = factory(car_name)
	# Weighted toward the patterns that read best from a chase camera.
	var bag := [0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 11, 12]
	p["pattern"] = bag[rng.randi() % bag.size()]
	p["finish"] = [0, 0, 1, 1, 1, 2, 3][rng.randi() % 7]
	var primary: Color = PALETTE[rng.randi() % PALETTE.size()][1]
	var secondary: Color = primary
	for attempt in 12:
		secondary = PALETTE[rng.randi() % PALETTE.size()][1]
		if _contrast(primary, secondary) > 0.35:
			break
	var accent: Color = secondary
	for attempt in 12:
		accent = PALETTE[rng.randi() % PALETTE.size()][1]
		if _contrast(accent, primary) > 0.25 and _contrast(accent, secondary) > 0.25:
			break
	p["primary"] = primary
	p["secondary"] = secondary
	p["accent"] = accent
	p["rim"] = RIMS[rng.randi() % RIMS.size()][1]
	p["number"] = rng.randi_range(1, 99)
	return p


static func _contrast(a: Color, b: Color) -> float:
	return absf(a.get_luminance() - b.get_luminance()) + 0.5 * Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
