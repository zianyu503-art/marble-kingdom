class_name Ink
extends RefCounted

## Small drawing helpers shared by the map, battle and plinko views.

const BLACK := Color(0.08, 0.08, 0.1)


static func font() -> Font:
	return ThemeDB.fallback_font


## Centered text with a dark outline, the look used for names in the videos.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline := 4, outline_col := BLACK) -> void:
	var f := font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * 0.5, -size * 0.35)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_left(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline := 4) -> void:
	var f := font()
	if outline > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, BLACK)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, line := 2.0) -> void:
	ci.draw_circle(c, r, fill)
	ci.draw_arc(c, r, 0, TAU, maxi(12, int(r * 1.5)), BLACK, line)


static func box(ci: CanvasItem, r: Rect2, fill: Color, line := 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, BLACK, false, line)


static func short_number(v: float) -> String:
	if v >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))
