extends TextureRect
## A menu tile's picture that is never quite still (MainMenu._add_tile, for the tiles that keep a picture: the
## courses, the cups, the Garage): it sits zoomed in a few percent and drifts slowly across, the zoom breathing
## in and out, each tile on its own phase so a page of them never moves in step. Under the pointer or the focus
## it leans in a little more. Slow and small on purpose (motion comfort): a full drift takes about 45 seconds.
## It lives inside a clipping holder the size of the picture's area, so the zoom never covers the tile's border.

## Where in its drift the tile starts (radians), set by the menu from the picture's name.
var phase := 0.0

const ZOOM := 1.08          # the resting zoom: room to drift without showing an edge
const BREATHE := 0.025      # the zoom's slow swing either way
const HOVER_ZOOM := 0.045   # leaning in under the pointer or focus
const ROOM_SHARE := 0.85    # how much of the zoom's spare room the drift uses

var _t := 0.0
var _hot := 0.0


func _ready() -> void:
	_t = phase * 7.0
	_apply()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var tile := _tile()
	var hot := tile != null and (tile.is_hovered() or tile.has_focus())
	_hot = move_toward(_hot, 1.0 if hot else 0.0, delta * 1.6)
	_apply()


func _apply() -> void:
	var k := ZOOM + BREATHE * sin(_t * 0.17 + phase) + HOVER_ZOOM * smoothstep(0.0, 1.0, _hot)
	pivot_offset = size * 0.5
	scale = Vector2(k, k)
	# The drift stays inside the room the zoom leaves round the picture's area, so no edge ever shows.
	var room := size * (k - 1.0) * 0.5 * ROOM_SHARE
	position = Vector2(sin(_t * 0.137 + phase * 1.7), cos(_t * 0.109 + phase)) * room


func _tile() -> BaseButton:
	var n := get_parent()
	while n != null and not (n is BaseButton):
		n = n.get_parent()
	return n as BaseButton
