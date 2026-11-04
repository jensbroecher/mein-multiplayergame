extends RefCounted
## The bots' line-up: each bot drives a different car, drawn from every car the game has (PlayerCart.CAR_PRESETS), and
## is named after it ("Phantom", "Inferno"...), so the standings and the commentator say what you see. The cars the
## humans drive are left out while there are enough others. Before, the bots were always Viper, Shadow, Apex, Blaze and
## Nova on the first four cars.
##
## In a Grand Prix the standings are kept by name, so Level.gd draws the line-up once at the start
## (NetworkManager.gp_bot_roster, cleared where a GP begins) and keeps it for every stage.

const CAR_PRESETS = preload("res://PlayerCart.gd").CAR_PRESETS


## `count` bots: [{"name", "car_index"}], distinct cars, avoiding the car indices in `avoid` while it can.
static func make(count: int, avoid: Array = [], rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var free: Array[int] = []
	var taken: Array[int] = []
	for i in range(CAR_PRESETS.size()):
		if avoid.has(i):
			taken.append(i)
		else:
			free.append(i)
	_shuffle(free, rng)
	_shuffle(taken, rng)
	free.append_array(taken)
	var out: Array = []
	for k in range(mini(count, free.size())):
		var idx: int = free[k]
		out.append({"name": str(CAR_PRESETS[idx].get("name", "Racer %d" % (k + 1))), "car_index": idx})
	return out


static func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t
