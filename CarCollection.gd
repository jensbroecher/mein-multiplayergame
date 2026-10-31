extends RefCounted
## The car collection: the garage's categories and which cars are in the player's line-up, the cars the
## car select screen offers. Cars are known by their preset name (PlayerCart.CAR_PRESETS), so the
## presets can grow without moving anything.
##
## The line-up is saved as the cars left out (settings.cfg, [garage] hidden_cars), so a new car joins it
## by itself. It is never empty: with every car left out, all of them are offered.

const CAR_PRESETS = preload("res://PlayerCart.gd").CAR_PRESETS

## The garage's galleries, in the order they line the hall. A car no category names goes into the last
## one, NEW_ARRIVALS, which only exists while it holds a car.
const CATEGORIES := [
	{"name": "Hypercars", "color": Color(0.98, 0.32, 0.30),
		"cars": ["Fulmine", "Nocturne", "Mirage", "Inferno", "Zephyr"]},
	{"name": "Rally & Raid", "color": Color(1.0, 0.62, 0.18),
		"cars": ["Interceptor", "Sandstorm", "Obsidian", "Trailblazer", "Apex"]},
	{"name": "Buggies", "color": Color(0.30, 0.82, 0.98),
		"cars": ["Shadow", "Centurion", "Vortex"]},
	{"name": "4x4 & Monsters", "color": Color(0.55, 0.92, 0.28),
		"cars": ["Strikeforce", "Phantom", "Mudrunner", "Titan"]},
]
const NEW_ARRIVALS := {"name": "New Arrivals", "color": Color(0.86, 0.52, 1.0)}

const SETTINGS := "user://settings.cfg"


## The categories with the preset indices of their cars: [{name, color, cars: [index, ...]}], empty
## ones left out.
static func galleries() -> Array:
	var out: Array = []
	var placed := {}
	for cat in CATEGORIES:
		var cars: Array = []
		for car_name in cat["cars"]:
			var i := index_of(str(car_name))
			if i >= 0 and not placed.has(i):
				cars.append(i)
				placed[i] = true
		if not cars.is_empty():
			out.append({"name": cat["name"], "color": cat["color"], "cars": cars})
	var rest: Array = []
	for i in CAR_PRESETS.size():
		if not placed.has(i):
			rest.append(i)
	if not rest.is_empty():
		out.append({"name": NEW_ARRIVALS["name"], "color": NEW_ARRIVALS["color"], "cars": rest})
	return out


static func index_of(car_name: String) -> int:
	for i in CAR_PRESETS.size():
		if str(CAR_PRESETS[i].name) == car_name:
			return i
	return -1


## The names of the cars left out of the line-up.
static func hidden_cars() -> Array:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return []
	var v: Variant = config.get_value("garage", "hidden_cars", [])
	return (v as Array).duplicate() if v is Array else []


static func in_lineup(index: int) -> bool:
	return lineup().has(index)


## Puts a car in the line-up or takes it out. Taking out the last car is refused (returns false).
static func set_in_lineup(index: int, on: bool) -> bool:
	var car_name := str(CAR_PRESETS[index].name)
	var hidden := hidden_cars()
	if on:
		hidden.erase(car_name)
	else:
		if lineup_size() <= 1 and in_lineup(index):
			return false
		if not hidden.has(car_name):
			hidden.append(car_name)
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("garage", "hidden_cars", hidden)
	config.save(SETTINGS)
	return true


## The preset indices in the line-up, in the presets' order; every car if none is left in.
static func lineup() -> Array:
	var hidden := hidden_cars()
	var out: Array = []
	for i in CAR_PRESETS.size():
		if not hidden.has(str(CAR_PRESETS[i].name)):
			out.append(i)
	if out.is_empty():
		for i in CAR_PRESETS.size():
			out.append(i)
	return out


static func lineup_size() -> int:
	return lineup().size()
