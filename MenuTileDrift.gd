extends TextureRect
## A menu tile's picture that is never quite still (MainMenu._add_tile, for the tiles that keep a picture: the
## courses, the cups, the Garage): it sits zoomed in a few percent and drifts slowly across, the zoom breathing
## in and out, each tile on its own phase so a page of them never moves in step. Under the pointer or the focus
## it leans in a little more. Slow and small on purpose (motion comfort): a full drift takes about 45 seconds.
## It lives inside a clipping holder the size of the picture's area, so the zoom never covers the tile's border.
## With `slides` (more than one picture: a course's key features, a cup's courses) it cross-fades to the next every
## SLIDE_HOLD seconds over SLIDE_FADE, each loaded on a background thread when its turn comes; the drift runs on
## through the fades (the next picture is a child, so it drifts with this one). Under the pointer or the focus the
## pictures come round HOVER_RATE times sooner, so a look at a tile shows what it holds.

## Where in its drift the tile starts (radians), set by the menu from the picture's name.
var phase := 0.0

const ZOOM := 1.08          # the resting zoom: room to drift without showing an edge
const BREATHE := 0.025      # the zoom's slow swing either way
const HOVER_ZOOM := 0.045   # leaning in under the pointer or focus
const ROOM_SHARE := 0.85    # how much of the zoom's spare room the drift uses

## The pictures to go round (paths; the first is the one in `texture`). Set by the menu before the tile is in the tree.
var slides: PackedStringArray = []

const SLIDE_HOLD := 5.0
const SLIDE_FADE := 1.2
const HOVER_RATE := 2.4

var _t := 0.0
var _hot := 0.0
var _slide := 0
var _slide_t := 0.0
var _next: TextureRect
var _pending := ""
var _fade_t := -1.0


func _ready() -> void:
	_t = phase * 7.0
	if slides.size() > 1:
		_next = TextureRect.new()
		_next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_next.expand_mode = expand_mode
		_next.stretch_mode = stretch_mode
		_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_next.modulate.a = 0.0
		add_child(_next)
		# Each tile's first change comes at its own time, so a page of them never changes in step.
		_slide_t = fposmod(phase * 2.3, SLIDE_HOLD * 0.8)
	_apply()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var tile := _tile()
	var hot := tile != null and (tile.is_hovered() or tile.has_focus())
	_hot = move_toward(_hot, 1.0 if hot else 0.0, delta * 1.6)
	if _next != null:
		_advance(delta * (HOVER_RATE if hot else 1.0), delta)
	_apply()


## The slideshow: hold, load the next picture in the background, fade it in, make it this one's.
func _advance(step: float, delta: float) -> void:
	_next.expand_mode = expand_mode
	_next.stretch_mode = stretch_mode
	if _fade_t >= 0.0:
		_fade_t += delta
		_next.modulate.a = smoothstep(0.0, 1.0, _fade_t / SLIDE_FADE)
		if _fade_t >= SLIDE_FADE:
			texture = _next.texture
			_next.modulate.a = 0.0
			_next.texture = null
			_fade_t = -1.0
			_slide_t = 0.0
		return
	_slide_t += step
	if _slide_t < SLIDE_HOLD:
		return
	if _pending.is_empty():
		_slide = (_slide + 1) % slides.size()
		_pending = slides[_slide]
		if ResourceLoader.load_threaded_request(_pending) != OK:
			_pending = ""
		return
	var st := ResourceLoader.load_threaded_get_status(_pending)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		_next.texture = ResourceLoader.load_threaded_get(_pending) as Texture2D
		_pending = ""
		_fade_t = 0.0
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_pending = ""
		_slide_t = 0.0


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
