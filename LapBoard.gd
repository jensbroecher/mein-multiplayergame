extends Node3D
## A trackside lap board (the Lakeside Course's towers, regenerate_lakeside.gd): an LED panel that
## shows the leader's lap, and FINISH once the leader is home. Level feeds every board the
## standings rows it gives the start gantry (_feed_gantry), on every peer, so nothing is synced here.

## The Label3D that shows the lap.
@export var label_path: NodePath

var _label: Label3D
var _shown := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"lap_boards")
	_label = get_node_or_null(label_path) as Label3D
	_show("LAP 1")


## Called by Level with the standings rows (sorted by place): rows[0] is the leader.
func show_standings(rows: Array) -> void:
	if rows.is_empty():
		return
	var leader: Dictionary = rows[0]
	if bool(leader.get("finished", false)):
		_show("FINISH")
	else:
		_show("LAP %d" % int(leader.get("lap", 1)))


func _show(text: String) -> void:
	if text == _shown or _label == null:
		return
	_shown = text
	_label.text = text
