extends RefCounted
## The race screens' look, shared by the HUD and the end panel (RaceUI.gd) and the pause menu (PauseMenu.gd), so the
## two popups match. Fonts (SIL Open Font License, the licences beside them in fonts/):
##   Russo One (fonts/RussoOne-Regular.ttf): the big numbers (place, speed, the countdown) and the panels' titles.
##     Its digits are proportional: a number that changes every frame goes in fixed cells (RaceUI's speed).
##   Titillium Web SemiBold and Bold (fonts/TitilliumWeb-*.ttf): everything else. Its digits are all one width, so
##     the lap clock and the results' times don't jitter.
## HUD text over the 3D view has a dark outline and a soft shadow (`outline`), so it reads on snow and sky alike.

const DISPLAY_PATH := "res://fonts/RussoOne-Regular.ttf"
const TEXT_PATH := "res://fonts/TitilliumWeb-SemiBold.ttf"
const BOLD_PATH := "res://fonts/TitilliumWeb-Bold.ttf"

const COL_TEXT := Color(0.93, 0.95, 0.98)
const COL_DIM := Color(0.62, 0.68, 0.76)
const COL_ACCENT := Color(0.15, 0.75, 0.92)   # the menus' teal (MainMenu.COL_TEAL)
const COL_OUTLINE := Color(0.02, 0.03, 0.05, 0.85)

static var _fonts := {}
static var _theme: Theme = null


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Font = load(path)
		_fonts[path] = f if f else ThemeDB.fallback_font
	return _fonts[path]


static func display() -> Font:
	return _font(DISPLAY_PATH)


static func text() -> Font:
	return _font(TEXT_PATH)


static func bold() -> Font:
	return _font(BOLD_PATH)


## The pause menu's panel: dark navy, a slate border, rounded, a soft shadow.
static func panel_style(margin_x := 30.0, margin_y := 25.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.098, 0.098, 0.137, 0.92)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.196, 0.235, 0.314, 1)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	return sb


static func _button_box(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## A theme for a race screen's root controls: the text font, buttons like the main menu's chrome buttons (a teal
## border under the pointer and on focus, for pads), the separators.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = text()
	t.default_font_size = 18
	var normal := _button_box(Color(0.12, 0.14, 0.2, 1), Color(0.28, 0.34, 0.44, 1))
	var hover := _button_box(Color(0.16, 0.2, 0.28, 1), COL_ACCENT)
	var pressed := _button_box(Color(0.08, 0.1, 0.14, 1), COL_ACCENT)
	var focus := _button_box(Color(0, 0, 0, 0), COL_ACCENT, 2)
	focus.draw_center = false
	var disabled := _button_box(Color(0.1, 0.11, 0.15, 0.8), Color(0.2, 0.23, 0.3, 1))
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("disabled", type, disabled)
		t.set_color("font_color", type, COL_TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(COL_DIM, 0.6))
		t.set_font("font", type, bold())
	var sep := StyleBoxLine.new()
	sep.color = Color(0.28, 0.34, 0.44, 0.9)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 6)
	t.set_color("font_color", "Label", COL_TEXT)
	_theme = t
	return t


## A label drawn over the 3D view: its font and size, a dark outline `outline_px` wide and a soft drop shadow.
static func outline(l: Label, font: Font, size: int, outline_px := 8, col := Color(-1, 0, 0)) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", COL_OUTLINE)
	l.add_theme_constant_override("outline_size", outline_px)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, outline_px / 4))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, outline_px / 3))
	l.add_theme_constant_override("shadow_outline_size", outline_px)
	if col.r >= 0.0:
		l.add_theme_color_override("font_color", col)


## A panel's title (the pause menu's GAME PAUSED, the end panel's RACE FINISHED).
static func title(l: Label, size := 30) -> void:
	l.add_theme_font_override("font", display())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
