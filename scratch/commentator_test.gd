extends Node
# Drives RaceCommentator with made-up standings and lists what it says (no audio needed).
# Headless:  Godot --headless --path . res://scratch/commentator_test.tscn
const MAX_LAPS := 3
var c: Node
var t := 0.0
var heard: Array = []

func rows(order: Array, lap := 1, finished_count := 0) -> Array:
	var out: Array = []
	for i in order.size():
		out.append({"id": order[i], "pos": i + 1, "name": NAMES[order[i]], "finished": i < finished_count, "lap": lap})
	return out

const NAMES := {1: "Jens", 2: "Bot_Alpha", 3: "x_Shadow-99_x \ud83d\ude80", 4: "Zoe"}

func run(seconds: float, order: Array, lap := 1, finished_count := 0) -> void:
	var end := t + seconds
	while t < end:
		t += 0.1
		c._process(0.1)
		c.update(rows(order, lap, finished_count), MAX_LAPS)

func _ready() -> void:
	c = load("res://RaceCommentator.gd").new()
	add_child(c)
	c.said.connect(func(s): heard.append("%5.1fs  %s" % [t, s]))
	c.update(rows([1, 2, 3, 4]), MAX_LAPS)
	print("before GO: ", heard.size(), " calls (want 0)")
	c.begin()
	run(3.0, [1, 2, 3, 4])               # opening call
	run(4.0, [2, 1, 3, 4])               # swap inside the grace: silent
	run(1.0, [3, 2, 1, 4])               # still grace-ish / settled
	run(0.5, [1, 3, 2, 4])               # flicker back: nothing
	run(3.0, [1, 3, 2, 4])
	run(3.0, [3, 1, 2, 4])               # 0.5s blip... then holds: call after hold
	run(2.0, [3, 1, 2, 4])
	run(1.0, [4, 3, 1, 2])               # new leader too soon after: waits out cooldown
	run(10.0, [4, 3, 1, 2])
	run(1.0, [4, 3, 1, 2], 3)            # leader on last lap
	run(4.0, [4, 3, 1, 2], 3, 1)         # winner across the line
	run(1.0, [4, 3, 1, 2], 3, 2)
	run(1.0, [4, 3, 1, 2], 3, 3)
	run(1.0, [4, 3, 1, 2], 3, 4)         # fourth: no call
	run(6.0, [4, 3, 1, 2], 3, 4)
	for line in heard:
		print(line)
	print("name clean: '%s' / '%s'" % [c._clean_name("x_Shadow-99_x \ud83d\ude80"), c._clean_name("\ud83d\ude80")])
	get_tree().quit()
