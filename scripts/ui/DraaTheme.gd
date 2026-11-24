class_name DraaTheme
extends RefCounted
## Claymorphism-for-games theme factory (§52 + ui-ux-pro-max DRAA tokens).
## Chunky rounded panels, thick borders, double shadows, cheerful orange
## primary + trust-blue CTA. Vector/shape-coded buttons — no emoji icons
## (cross-platform font consistency + screen-reader labels instead).
## Touch targets >= 96px (≈48dp @2x), 16px gaps, RTL-aware.

const PRIMARY := Color(0.976, 0.451, 0.086)   # #F97316 playful orange
const ON_PRIMARY := Color(0.059, 0.09, 0.165) # #0F172A
const ACCENT := Color(0.149, 0.388, 0.922)    # #2563EB trust blue
const BG := Color(1.0, 0.969, 0.929)          # #FFF7ED
const INK := Color(0.604, 0.204, 0.071)       # #9A3412
const CARD := Color(1, 1, 1)
const DANGER := Color(0.863, 0.149, 0.149)
const HP_GOOD := Color(0.2, 0.75, 0.3)
const HP_LOW := Color(0.9, 0.2, 0.2)

static var _font: Font


static func font() -> Font:
	if _font:
		return _font
	# Bundled Cairo first (ships Arabic glyphs); else system fallback chain.
	for path in ["res://assets/fonts/Cairo-Bold.ttf", "res://assets/fonts/Cairo-Regular.ttf"]:
		if FileAccess.file_exists(path):
			var bundled := load(path) as FontFile
			if bundled:
				_font = bundled
				return _font
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Cairo", "Tajawal", "Rubik", "Noto Kufi Arabic", "Segoe UI", "Arial"])
	sys.font_weight = 700
	_font = sys
	return _font


static func panel_style(bg: Color = CARD, border: Color = PRIMARY, radius: int = 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.06, 0.03, 0.02, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(18)
	s.shadow_color = Color(0.06, 0.03, 0.02, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


static func make_button(text: String, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var f := font()
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 34)
	var bg := ACCENT
	var fg := Color.WHITE
	var border := ACCENT.darkened(0.25)
	if kind == "primary":
		bg = PRIMARY
		fg = ON_PRIMARY
		border = INK
	elif kind == "ghost":
		bg = Color(1, 1, 1, 0.12)
		fg = Color.WHITE
		border = Color(1, 1, 1, 0.5)
	elif kind == "danger":
		bg = DANGER
		fg = Color.WHITE
		border = DANGER.darkened(0.3)
	b.add_theme_stylebox_override("normal", button_style(bg, border))
	b.add_theme_stylebox_override("hover", button_style(bg.lightened(0.1), border))
	b.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.12), border))
	b.add_theme_stylebox_override("disabled", button_style(bg.lerp(Color(0.5, 0.5, 0.5), 0.6), Color(0.5, 0.5, 0.5)))
	b.add_theme_stylebox_override("focus", button_style(bg, Color.WHITE))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	return b


static func make_action_button(text: String, sub: String, diameter: float, bg: Color) -> Button:
	var b := Button.new()
	b.text = text + "\n" + sub
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 28)
	var st := button_style(bg, bg.darkened(0.3))
	st.set_corner_radius_all(int(diameter / 2.0))
	b.add_theme_stylebox_override("normal", st)
	var pr := button_style(bg.darkened(0.15), bg.darkened(0.35))
	pr.set_corner_radius_all(int(diameter / 2.0))
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", button_style(Color(0.4, 0.4, 0.4, 0.7), Color(0.3, 0.3, 0.3)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	return b


static func make_label(text: String, size: int = 30, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func make_bar(fill: Color, back: Color, min_size: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = min_size
	p.max_value = 100.0
	p.value = 100.0
	p.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = back
	bg.set_corner_radius_all(10)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(10)
	fg.border_color = Color(0, 0, 0, 0.4)
	fg.set_border_width_all(2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


static func apply_rtl(control: Control, rtl: bool = true) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
