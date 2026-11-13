extends Control
## The race camera's "signal lost" (RaceUI adds one under its HUD on first use, so each split-screen view has its own):
## when a racer leaves the drivable area (PlayerCart._update_out_of_bounds) the feed breaks up, cuts to dark digital
## static with SIGNAL LOST and RECONNECTING, the cart is respawned behind the cut, and the feed glitches back in.
## `weak(amount)` breaks the picture up a little (driving away from the course, before the cut): it eases toward it, so
## turning back clears it. signal_lost.gdshader draws it; nothing flashes bright (motion comfort).

## The cut's phases (seconds): the picture breaks up, the static holds (the cart respawns under it), the picture returns.
const RAMP := 0.3
const HOLD := 1.2
const RESTORE := 0.55
## When the cart is moved, from the start: the static is up by then.
const RESPAWN_AT := 0.38
const WEAK_GLITCH := 0.5
const WEAK_EASE := 3.0

const LOST_SOUND := "res://sounds/ui/signal_lost.wav"
const RESTORE_SOUND := "res://sounds/ui/signal_restore.wav"
## The clips' levels (measured RMS in dBFS by scratch/measure_clip_rms.gd) brought to about -24 dBFS.
const LOST_DB := 0.0
const RESTORE_DB := -5.0

var camera_label := "CAM 1"

var _rect: ColorRect
var _mat: ShaderMaterial
var _title: Label
var _sub: Label
var _cam: Label
var _warn: Label
var _t := -1.0
var _weak_target := 0.0
var _weak := 0.0
var _restored_sound := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://signal_lost.gdshader")
	_mat.set_shader_parameter("seed", randf() * 100.0)
	_rect.material = _mat
	add_child(_rect)
	var font: Font = load("res://fonts/NotoSansSC-Yunhai.otf") if ResourceLoader.exists("res://fonts/NotoSansSC-Yunhai.otf") else null
	_title = _label(font, "SIGNAL LOST", Color(0.92, 0.94, 0.96))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub = _label(font, "RECONNECTING", Color(0.62, 0.68, 0.74))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cam = _label(font, camera_label, Color(0.85, 0.87, 0.9))
	_cam.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_warn = _label(font, "WEAK SIGNAL - RETURN TO THE COURSE", Color(1.0, 0.78, 0.35))
	_warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	visible = false
	set_process(true)


func _label(font: Font, text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


## Breaks the picture up by `amount` (0..1, eased): driving away from the course.
func weak(amount: float) -> void:
	_weak_target = clampf(amount, 0.0, 1.0)


## Runs the cut from the start: break-up, static, restore.
func cut() -> void:
	if _t >= 0.0 and _t < RAMP + HOLD:
		return
	_t = 0.0
	_restored_sound = false
	_mat.set_shader_parameter("seed", randf() * 100.0)
	if ResourceLoader.exists(LOST_SOUND):
		MusicManager.play_sfx(LOST_SOUND, LOST_DB)


func is_cutting() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_weak = move_toward(_weak, _weak_target, WEAK_EASE * delta)
	var g := 0.0
	var c := 0.0
	if _t >= 0.0:
		_t += delta
		if _t < RAMP:
			g = lerpf(0.35, 1.0, _t / RAMP)
			c = smoothstep(RAMP * 0.6, RAMP, _t)
		elif _t < RAMP + HOLD:
			g = 1.0
			c = 1.0
		elif _t < RAMP + HOLD + RESTORE:
			var k: float = (_t - RAMP - HOLD) / RESTORE
			c = 1.0 - smoothstep(0.0, 0.35, k)
			g = 1.0 - k * k
			if not _restored_sound:
				_restored_sound = true
				if ResourceLoader.exists(RESTORE_SOUND):
					MusicManager.play_sfx(RESTORE_SOUND, RESTORE_DB)
		else:
			_t = -1.0
	g = maxf(g, _weak * WEAK_GLITCH)
	var on: bool = g > 0.003 or c > 0.003
	visible = on
	if not on:
		return
	_mat.set_shader_parameter("glitch", g)
	_mat.set_shader_parameter("cut", c)
	var h: float = maxf(size.y, 1.0)
	var big: int = int(clampf(h * 0.085, 18.0, 96.0))
	var small: int = int(clampf(h * 0.03, 11.0, 32.0))
	var show_cut: bool = c > 0.5
	_title.visible = show_cut
	_sub.visible = show_cut
	_cam.visible = show_cut
	if show_cut:
		_title.add_theme_font_size_override("font_size", big)
		_sub.add_theme_font_size_override("font_size", small)
		_cam.add_theme_font_size_override("font_size", small)
		_title.reset_size()
		_sub.reset_size()
		_cam.reset_size()
		_title.position = Vector2((size.x - _title.size.x) * 0.5, h * 0.5 - _title.size.y * 0.75)
		var dots: int = int(_t / 0.3) % 4
		_sub.text = "NO VIDEO FEED  -  RECONNECTING" + ".".repeat(dots)
		_sub.position = Vector2((size.x - _sub.size.x) * 0.5, h * 0.5 + _title.size.y * 0.35)
		_cam.text = ("● " if int(_t * 2.0) % 2 == 0 else "  ") + camera_label
		_cam.position = Vector2((size.x - _cam.size.x) * 0.5, _title.position.y - _cam.size.y * 1.6)
	var warn_on: bool = _weak > 0.05 and not show_cut and _t < 0.0
	_warn.visible = warn_on
	if warn_on:
		_warn.add_theme_font_size_override("font_size", small)
		_warn.reset_size()
		_warn.position = Vector2((size.x - _warn.size.x) * 0.5, h * 0.2)
		_warn.modulate.a = clampf(_weak * 2.0, 0.0, 1.0) * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.006))
