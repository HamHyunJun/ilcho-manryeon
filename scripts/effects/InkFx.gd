extends RefCounted
class_name InkFx
## 전투 타격 효과용 붓 그림 모음 (먹 실루엣 스타일).
## - crescent: 붓으로 휘두른 초승달 궤적 (가운데가 두껍고 양끝이 가늘다)
## - splash: 맞은 자리에 튀는 먹물과 붉은 점
## - burst: 쓰러질 때 사방으로 뻗는 먹 가시
## 같은 seed면 매 프레임 같은 모양이라 깜빡이지 않는다.

const INK := Color("#0e0e0e")
const RED := Color("#d8402f")
const BONE := Color("#e6dfcc")


## 초승달 궤적: center 기준 반지름 r, 각도 a0→a1 (라디안), 최대 굵기 w
static func crescent(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, w: float, col: Color, seed_v: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var a := lerpf(a0, a1, t)
		var th := w * sin(t * PI) * rng.randf_range(0.85, 1.1)
		var dir := Vector2(cos(a), sin(a))
		outer.append(center + dir * (r + th * 0.5))
		inner.append(center + dir * (r - th * 0.5))
	inner.reverse()
	var pts := outer + inner
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_colored_polygon(pts, col)
	# 갈라진 붓털 자국
	for k in 2:
		var off := rng.randf_range(-w * 0.35, w * 0.35)
		var hp := PackedVector2Array()
		for i in range(2, n - 1):
			var a := lerpf(a0, a1, float(i) / n)
			hp.append(center + Vector2(cos(a), sin(a)) * (r + off))
		ci.draw_polyline(hp, Color(col, col.a * 0.6), 1.5)


## 먹물 튀김: 큰 먹 방울 몇 개 + 작은 붉은 점. size: 퍼지는 반지름, t: 0~1 진행
static func splash(ci: CanvasItem, c: Vector2, size: float, t: float, seed_v: int = 1, accent: Color = RED) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var a := clampf(1.0 - t, 0.0, 1.0)
	for i in 7:
		var ang := rng.randf_range(0, TAU)
		var dist := size * rng.randf_range(0.3, 1.0) * (0.5 + 0.5 * t)
		var rad := size * rng.randf_range(0.08, 0.2) * (1.0 - t * 0.5)
		ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * dist, rad, Color(INK, 0.9 * a))
	for i in 5:
		var ang := rng.randf_range(0, TAU)
		var dist := size * rng.randf_range(0.4, 1.2) * (0.5 + 0.5 * t)
		ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * dist, size * rng.randf_range(0.04, 0.09), Color(accent, a))
	# 가운데 붓 획 두 개 (X자 베인 자국)
	var l := size * 0.9
	var s1 := Vector2(-l, -l * 0.6)
	ci.draw_line(c + s1 * (1.0 - t * 0.3), c - s1 * (1.0 - t * 0.3), Color(accent, a), maxf(1.0, size * 0.12 * a))


## 먹 가시 폭발 (쓰러지는 순간)
static func burst(ci: CanvasItem, c: Vector2, r0: float, r1: float, seed_v: int = 1, col: Color = INK) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 9:
		var ang := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector2(cos(ang), sin(ang))
		var len := rng.randf_range(r0, r1)
		var nrm := dir.orthogonal() * rng.randf_range(2.5, 4.5)
		ci.draw_colored_polygon(PackedVector2Array([c + dir * r0 * 0.5 + nrm, c + dir * len, c + dir * r0 * 0.5 - nrm]), col)
	for i in 4:
		var ang := rng.randf_range(0, TAU)
		ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * rng.randf_range(r0, r1 * 1.1), rng.randf_range(2.0, 4.0), RED)


## 먹 화살: 몸통 붓선 + 붉은 깃 + 뒤로 남는 붓 꼬리
static func arrow(ci: CanvasItem, tip: Vector2, dir_x: float, t: float) -> void:
	var tail := tip + Vector2(-dir_x * 30, 0)
	ci.draw_line(tip, tail, INK, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(dir_x * 8, 0), tip + Vector2(0, -4), tip + Vector2(0, 4)]), INK)
	ci.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-dir_x * 6, -5), tail + Vector2(dir_x * 4, 0), tail + Vector2(-dir_x * 6, 5)]), RED)
	# 붓 꼬리
	var trail := 60.0 * minf(t * 3.0, 1.0)
	ci.draw_line(tail, tail + Vector2(-dir_x * trail, -1), Color(INK, 0.35), 2.0)
