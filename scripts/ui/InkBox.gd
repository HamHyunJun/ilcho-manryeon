extends StyleBox
class_name InkBox
## 손그림 질감 상자 (StyleBoxFlat 대신 쓰는 붓 테두리 상자).
## - 바탕은 가장자리가 살짝 떨리는 먹색 면, 테두리는 붓으로 그은 듯 굵기가 고르지 않은 선.
## - StyleBoxFlat과 같은 이름의 속성(bg_color, border_color, set_border_width_all, set_corner_radius_all 등)을
##   받아서, 기존 코드에서 StyleBoxFlat.new()를 InkBox.new()로 바꾸기만 하면 된다.
## - 모서리 둥글기는 모서리를 비스듬히 깎는 정도로만 흉내 낸다.
## - 떨림 모양은 상자 크기로 정해지므로 매 프레임 같은 모양이다 (깜빡이지 않음).

var bg_color := Color(0.08, 0.08, 0.075, 0.92)
var border_color := Color(0.9, 0.87, 0.8, 0.5)
var border_width_left := 0
var border_width_top := 0
var border_width_right := 0
var border_width_bottom := 0
var corner_radius_top_left := 0
var corner_radius_top_right := 0
var corner_radius_bottom_right := 0
var corner_radius_bottom_left := 0
var draw_center := true
var anti_aliasing := true
## 떨림 세기 배율 (0이면 반듯한 상자)
var roughness := 1.0
## 같은 크기 상자끼리 모양을 다르게 하고 싶을 때
var seed_salt := 0


func set_border_width_all(w: int) -> void:
	border_width_left = w
	border_width_top = w
	border_width_right = w
	border_width_bottom = w
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if get_content_margin(side) < 0.0:
			set_content_margin(side, float(w))


func set_corner_radius_all(r: int) -> void:
	corner_radius_top_left = r
	corner_radius_top_right = r
	corner_radius_bottom_right = r
	corner_radius_bottom_left = r


func _border_w() -> float:
	return float(maxi(maxi(border_width_left, border_width_right), maxi(border_width_top, border_width_bottom)))


## 떨리는 테두리 점들 (시계 방향). inset만큼 안쪽으로
func _outline(rect: Rect2, inset: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var r := rect.grow(-inset)
	var amp := minf(1.4 * roughness, minf(r.size.x, r.size.y) / 8.0)
	var cut_tl := minf(corner_radius_top_left * 0.45, minf(r.size.x, r.size.y) * 0.3)
	var cut_tr := minf(corner_radius_top_right * 0.45, minf(r.size.x, r.size.y) * 0.3)
	var cut_br := minf(corner_radius_bottom_right * 0.45, minf(r.size.x, r.size.y) * 0.3)
	var cut_bl := minf(corner_radius_bottom_left * 0.45, minf(r.size.x, r.size.y) * 0.3)
	var corners := [
		r.position + Vector2(cut_tl, 0), r.position + Vector2(r.size.x - cut_tr, 0),
		r.position + Vector2(r.size.x, cut_tr), r.end - Vector2(0, cut_br),
		r.end - Vector2(cut_br, 0), r.position + Vector2(cut_bl, r.size.y),
		r.position + Vector2(0, r.size.y - cut_bl), r.position + Vector2(0, cut_tl),
	]
	var pts := PackedVector2Array()
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var len := a.distance_to(b)
		if len < 0.5:
			continue
		var steps := maxi(1, int(len / 12.0))
		var nrm := (b - a).orthogonal().normalized()
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			pts.append(p + nrm * rng.randf_range(-amp, amp) if s > 0 else p)
	return pts


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.size.x) * 7919 + int(rect.size.y) * 104729 + seed_salt
	var bw := _border_w()
	if draw_center and bg_color.a > 0.0:
		var fill := _outline(rect, 0.0, rng)
		if fill.size() >= 3:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, fill, PackedColorArray([bg_color]))
	if bw > 0.0 and border_color.a > 0.0:
		# 붓선: 굵은 선 하나 + 살짝 어긋난 가는 선 하나 (번진 듯한 테두리)
		var line := _outline(rect, bw * 0.5, rng)
		if line.size() >= 2:
			line.append(line[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, line, PackedColorArray([border_color]), bw, anti_aliasing)
			var thin := PackedVector2Array()
			for i in line.size():
				thin.append(line[i] + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)))
			RenderingServer.canvas_item_add_polyline(to_canvas_item, thin, PackedColorArray([Color(border_color, border_color.a * 0.45)]), maxf(1.0, bw * 0.5), anti_aliasing)
