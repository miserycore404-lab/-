class_name UITheme
extends RefCounted
## Visual identity: palette, fonts and the shared Control theme.
##
## Palette: "Moscow winter" — ink-blue night, frost paper, birch white,
## and one accent: the red of a bullfinch's breast (and of old Soviet stamps).

const INK := Color(0.055, 0.067, 0.09)
const INK_2 := Color(0.09, 0.105, 0.135)
const PAPER := Color(0.91, 0.89, 0.84)
const PAPER_DIM := Color(0.66, 0.66, 0.66)
const FROST := Color(0.78, 0.84, 0.92)
const MUTED := Color(0.55, 0.6, 0.68)
const RED := Color(0.79, 0.22, 0.18)
const RED_DEEP := Color(0.55, 0.12, 0.1)
const AMBER := Color(0.93, 0.66, 0.34)
const METRO_BROWN := Color(0.55, 0.35, 0.2)

static var _fonts := {}
static var _theme: Theme


static func _font(path: String) -> FontFile:
	if not _fonts.has(path):
		var f: FontFile = load(path)
		_fonts[path] = f
	return _fonts[path]


static func font_serif() -> Font:
	return _font("res://assets/fonts/PTSerif-Regular.ttf")


static func font_serif_italic() -> Font:
	return _font("res://assets/fonts/PTSerif-Italic.ttf")


static func font_serif_bold() -> Font:
	return _font("res://assets/fonts/PTSerif-Bold.ttf")


static func font_title() -> Font:
	return _font("res://assets/fonts/PTSerifCaption-Regular.ttf")


static func font_sans() -> Font:
	return _font("res://assets/fonts/PTSansNarrow-Regular.ttf")


static func font_sans_bold() -> Font:
	return _font("res://assets/fonts/PTSansNarrow-Bold.ttf")


static func font_mono() -> Font:
	return _font("res://assets/fonts/PTMono-Regular.ttf")


static func font_hand() -> Font:
	return _font("res://assets/fonts/MarckScript-Regular.ttf")


## Letter-spaced variation of a font, for small caps-style labels.
static func spaced(base: Font, spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	return fv


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_serif()
	t.default_font_size = 26
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", RED)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(s, "Button", empty)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_font("normal_font", "RichTextLabel", font_serif())
	t.set_font("italics_font", "RichTextLabel", font_serif_italic())
	t.set_font("bold_font", "RichTextLabel", font_serif_bold())
	t.set_font("mono_font", "RichTextLabel", font_mono())
	t.set_font_size("normal_font_size", "RichTextLabel", 26)
	t.set_font_size("italics_font_size", "RichTextLabel", 26)
	t.set_font_size("bold_font_size", "RichTextLabel", 26)
	# scrollbars: a thin frost line
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(FROST, 0.45)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	var track := StyleBoxFlat.new()
	track.bg_color = Color(FROST, 0.08)
	track.content_margin_left = 2
	track.content_margin_right = 2
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	_theme = t
	return t


static func label(text: String, font: Font, size: int, color := PAPER, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


## Anchor a control to a point of its parent (0..1 on each axis) with
## explicit offsets. Unlike setting `position` after a preset, this holds
## regardless of when the parent receives its size.
static func place(c: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom
