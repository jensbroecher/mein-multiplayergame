extends CanvasLayer
## The swipe between screens. cover() sweeps a panel across the screen, set_covered() snaps it there,
## reveal() sweeps it away and fades it out, fade_out() just fades it. Main.gd uses them to swap
## screens (_swipe) and round the loading screen, whose colour the panel matches.
##
## While the panel is up it takes the mouse, so a second click can't reach the screen under it.
## `busy` is true from cover() until reveal() or fade_out() ends.

const SWIPE_SHADER := preload("res://screen_swipe.gdshader")
const COVER_TIME := 0.34
const REVEAL_TIME := 0.5
const FADE_TIME := 0.25

var busy := false

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	# Above the loading screen (100) and every menu; runs while the game is paused or sped up.
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = SWIPE_SHADER
	_rect = ColorRect.new()
	_rect.name = "Swipe"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.material = _mat
	add_child(_rect)


## Sweeps the panel in until it covers the screen.
func cover(duration: float = COVER_TIME) -> void:
	await _finish_running()
	busy = true
	_set_state(0.0, 0.0, 0.0)
	visible = true
	_tween = _new_tween()
	_tween.tween_property(_mat, "shader_parameter/cover", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished


## The screen covered at once, for handing over from something the same colour.
func set_covered() -> void:
	await _finish_running()
	busy = true
	_set_state(1.0, 0.0, 0.0)
	visible = true


## Sweeps the panel away to the right, fading as it goes.
func reveal(duration: float = REVEAL_TIME) -> void:
	await _finish_running()
	if not visible:
		busy = false
		return
	_tween = _new_tween()
	_tween.tween_property(_mat, "shader_parameter/release", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_mat, "shader_parameter/fade", 1.0, duration * 0.55).set_delay(duration * 0.45)
	await _tween.finished
	_done()


## Fades the covered screen away without a sweep.
func fade_out(duration: float = FADE_TIME) -> void:
	await _finish_running()
	if not visible:
		busy = false
		return
	_tween = _new_tween()
	_tween.tween_property(_mat, "shader_parameter/fade", 1.0, duration)
	await _tween.finished
	_done()


func _new_tween() -> Tween:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	return tween


## A swipe asked for while another is still running waits for it, so nothing awaits a tween that
## was killed.
func _finish_running() -> void:
	if _tween and _tween.is_running():
		await _tween.finished


func _set_state(cover_amount: float, release_amount: float, fade_amount: float) -> void:
	_mat.set_shader_parameter("cover", cover_amount)
	_mat.set_shader_parameter("release", release_amount)
	_mat.set_shader_parameter("fade", fade_amount)


func _done() -> void:
	visible = false
	busy = false
	_set_state(0.0, 0.0, 0.0)
