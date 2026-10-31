extends RefCounted
## The player's Grand Prix trophies (user://trophies.cfg), shown in the garage's trophy hall. Main.gd
## records one when a Grand Prix that started from its first stage ends on the podium with a local
## player in the top three: one per Grand Prix, for the best local place.
##
## Per cup (the section is the cup's name): gold, silver and bronze (how many of each), best (0 first,
## 1 second, 2 third), car (the car of the best result, its latest win at that place) and date.

const FILE := "user://trophies.cfg"
const PLACES := ["gold", "silver", "bronze"]


## Records the result of a finished Grand Prix: `ranking` is NetworkManager.build_gp_ranking() (best
## first), `local_names` the names that are the players on this machine. Returns the place recorded
## (0..2), or -1 for none.
static func record_gp(cup_name: String, ranking: Array, local_names: Array) -> int:
	var place := -1
	var car_index := 0
	for i in mini(3, ranking.size()):
		var row: Dictionary = ranking[i]
		if not bool(row.get("is_bot", false)) and local_names.has(str(row.get("name", ""))):
			place = i
			car_index = int(row.get("car_index", 0))
			break
	if place < 0 or cup_name.is_empty():
		return -1
	var config := ConfigFile.new()
	config.load(FILE)
	var key: String = PLACES[place]
	config.set_value(cup_name, key, int(config.get_value(cup_name, key, 0)) + 1)
	var best := int(config.get_value(cup_name, "best", 99))
	if place <= best:
		var presets: Array = preload("res://PlayerCart.gd").CAR_PRESETS
		config.set_value(cup_name, "best", place)
		config.set_value(cup_name, "car", str(presets[clampi(car_index, 0, presets.size() - 1)].name))
		config.set_value(cup_name, "date", Time.get_date_string_from_system())
	config.save(FILE)
	return place


## The record of one cup: {gold, silver, bronze, best (-1 for none won), car, date}.
static func cup(cup_name: String) -> Dictionary:
	var config := ConfigFile.new()
	config.load(FILE)
	var best := int(config.get_value(cup_name, "best", -1))
	return {
		"gold": int(config.get_value(cup_name, "gold", 0)),
		"silver": int(config.get_value(cup_name, "silver", 0)),
		"bronze": int(config.get_value(cup_name, "bronze", 0)),
		"best": best if best >= 0 and best <= 2 else -1,
		"car": str(config.get_value(cup_name, "car", "")),
		"date": str(config.get_value(cup_name, "date", "")),
	}
