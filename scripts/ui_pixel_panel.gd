class_name CWPixelPanel
extends Control

# 1-unit stepped-corner pixel panel & 3-state button renderer
# Exact port of plate() in 72-ui.js:21-26

const COL_BG := Color(0.0353, 0.0431, 0.0667, 0.86)     # rgba(9,11,17,0.86)
const COL_BG2 := Color(0.0941, 0.1059, 0.1490, 0.94)    # rgba(24,27,38,0.94)
const COL_BTN := Color(0.0627, 0.0706, 0.1059, 0.96)    # rgba(16,18,27,0.96)
const COL_BD := Color(0.3647, 0.2980, 0.2078, 1.0)      # #5d4c35
const COL_BD_DIM := Color(0.2275, 0.2039, 0.1725, 1.0)  # #3a342c
const COL_BD_HI := Color(0.9098, 0.6902, 0.2902, 1.0)   # #e8b04a
const COL_HI := Color(0.9098, 0.6902, 0.2902, 0.18)     # rgba(232,176,74,0.18)

var ui_s: int = 3
var bg_color: Color = COL_BG
var border_color: Color = COL_BD
var hi_color: Color = Color(0.0, 0.0, 0.0, 0.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_plate_style(p_s: int, p_bg: Color = COL_BG, p_bd: Color = COL_BD, p_hi: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	ui_s = maxi(1, p_s)
	bg_color = p_bg
	border_color = p_bd
	hi_color = p_hi
	queue_redraw()


func _draw() -> void:
	draw_plate(self, 0.0, 0.0, size.x, size.y, ui_s, bg_color, border_color, hi_color)


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
	# Outer stepped border (1s chamfered corners)
	ci.draw_rect(Rect2(rx + sf, ry, rw - 2.0 * sf, rh), bdc)
	ci.draw_rect(Rect2(rx, ry + sf, rw, rh - 2.0 * sf), bdc)
	# Inner fill (inset by 1s/2s)
	ci.draw_rect(Rect2(rx + 2.0 * sf, ry + sf, rw - 4.0 * sf, rh - 2.0 * sf), bgc)
	ci.draw_rect(Rect2(rx + sf, ry + 2.0 * sf, rw - 2.0 * sf, rh - 4.0 * sf), bgc)
	# Optional 1s top highlight bar
	if hi.a > 0.001:
		var hic := Color(hi.r, hi.g, hi.b, hi.a * alpha)
		ci.draw_rect(Rect2(rx + 2.0 * sf, ry + sf, rw - 4.0 * sf, sf), hic)
