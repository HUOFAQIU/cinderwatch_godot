class_name CWPixelPanel
extends RefCounted

# 1-unit stepped-corner pixel panel renderer (port of plate() in 72-ui.js)

const COL_BG := Color(0.0353, 0.0431, 0.0667, 0.86)
const COL_BD := Color(0.3647, 0.2980, 0.2078, 1.0)


static func draw_plate(ci: CanvasItem, x: float, y: float, w: float, h: float, s: int, bg: Color = COL_BG, bd: Color = COL_BD, hi: Color = Color(0.0, 0.0, 0.0, 0.0), alpha: float = 1.0) -> void:
	var sf := float(maxi(1, s))
	var rx := roundf(x)
	var ry := roundf(y)
	var rw := roundf(w)
	var rh := roundf(h)
	if rw < sf * 4.0 or rh < sf * 4.0:
		return
	var bdc := Color(bd.r, bd.g, bd.b, bd.a * alpha)
	var bgc := Color(bg.r, bg.g, bg.b, bg.a * alpha)
	ci.draw_rect(Rect2(rx + sf, ry, rw - 2.0 * sf, rh), bdc)
	ci.draw_rect(Rect2(rx, ry + sf, rw, rh - 2.0 * sf), bdc)
	ci.draw_rect(Rect2(rx + 2.0 * sf, ry + sf, rw - 4.0 * sf, rh - 2.0 * sf), bgc)
	ci.draw_rect(Rect2(rx + sf, ry + 2.0 * sf, rw - 2.0 * sf, rh - 4.0 * sf), bgc)
	if hi.a > 0.001:
		var hic := Color(hi.r, hi.g, hi.b, hi.a * alpha)
		ci.draw_rect(Rect2(rx + 2.0 * sf, ry + sf, rw - 4.0 * sf, sf), hic)
