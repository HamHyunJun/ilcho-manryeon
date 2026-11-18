extends RefCounted
class_name UiIcons
## UI 아이콘을 코드로 그린다 (이미지 파일 없음). 하단 앱바, 설정, 보스 표시, 장비 부위 아이콘.
## 모든 함수는 center 기준, s는 아이콘 한 변의 대략적인 크기(px).

## 화면 공통 색 (실루엣 + 손그림 질감 스타일)
## 캐릭터·몬스터·UI 바탕은 먹색(INK), 글자와 선은 뼈색(BONE), 강조는 주홍(ACCENT) 하나만 쓴다.
## 색은 기술 이펙트에 몰아 쓰고 UI는 무채색으로 둔다.
const INK := Color("#0e0e0e")
const INK_SOFT := Color("#1c1c1a")
const BONE := Color("#e6dfcc")
const BONE_DIM := Color("#9c968a")
const ACCENT := Color("#c8402e")
## 예전 금색 이름을 쓰는 코드를 위해 남겨 둔다 (지금은 뼈색 계열)
const GOLD := BONE
const GOLD_DK := BONE_DIM


## 붓으로 그은 듯 흔들리는 선. 같은 seed면 매 프레임 같은 모양이라 깜빡이지 않는다
static func ink_line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, seed_v: int = 1, wobble: float = 1.6) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var n := maxi(2, int(a.distance_to(b) / 10.0))
	var nrm := (b - a).orthogonal().normalized()
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + nrm * (r.randf_range(-wobble, wobble) if i < n else 0.0)
		# 끝으로 갈수록 살짝 가늘어지는 붓 자국
		var ww := w * lerpf(1.0, 0.55, absf(t - 0.4) / 0.6) * r.randf_range(0.8, 1.15)
		ci.draw_line(prev, p, col, maxf(1.0, ww))
		prev = p


## 위쪽 가장자리가 찢긴 종이처럼 들쭉날쭉한 띠 (x0~x1, top에서 bottom까지)
static func torn_band(ci: CanvasItem, x0: float, x1: float, top: float, bottom: float, col: Color, amp: float = 5.0, seed_v: int = 1) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, bottom))
	var x := x0
	while x < x1:
		pts.append(Vector2(x, top + r.randf_range(-amp, amp) * (0.4 + 0.6 * r.randf())))
		x += r.randf_range(5.0, 14.0)
	pts.append(Vector2(x1, top))
	pts.append(Vector2(x1, bottom))
	ci.draw_colored_polygon(pts, col)


## 거친 붓 원 (닫힌 고리)
static func ink_ring(ci: CanvasItem, c: Vector2, rad: float, col: Color, w: float, seed_v: int = 1, wobble: float = 2.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	var n := 48
	var first := 0.0
	for i in n + 1:
		var d := r.randf_range(-wobble, wobble) if i < n else first
		if i == 0:
			first = d
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * (rad + d))
	ci.draw_polyline(pts, col, w, true)


## 먹물 번짐 (붓으로 문지른 타원 자국). 선택된 칸 표시 등에 쓴다
static func ink_smear(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, seed_v: int = 1) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var k := r.randf_range(0.82, 1.08)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	ci.draw_colored_polygon(pts, col)


## 여러 점을 잇는 붓선 (마디마다 ink_line)
static func brush(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, seed_v: int = 1, wobble: float = 0.8) -> void:
	for i in pts.size() - 1:
		ink_line(ci, pts[i], pts[i + 1], col, w, seed_v + i * 13, wobble)


## 가장자리가 떨리는 채운 다각형
static func rough_fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, amp: float = 1.0, seed_v: int = 1) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var steps := maxi(1, int(a.distance_to(b) / 6.0))
		var nrm := (b - a).orthogonal().normalized()
		for s in steps:
			out.append(a.lerp(b, float(s) / steps) + (nrm * r.randf_range(-amp, amp) if s > 0 else Vector2.ZERO))
	if out.size() >= 3 and not Geometry2D.triangulate_polygon(out).is_empty():
		ci.draw_colored_polygon(out, col)
	elif pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


static func _circle_pts(c: Vector2, r: float, n: int = 20, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * squash))
	return pts


static func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## 엽전 두 닢 (상점): 붓으로 그린 동그라미와 네모 구멍
static func coins(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var k := 0
	for o in [Vector2(-s * 0.18, s * 0.12), Vector2(s * 0.2, -s * 0.12)]:
		k += 1
		var p: Vector2 = c + o
		var r := s * 0.3
		rough_fill(ci, _circle_pts(p, r, 18), Color(col, 0.18), 1.0, 300 + k)
		ink_ring(ci, p, r, col, s * 0.065, 310 + k, 1.2)
		var h := r * 0.34
		brush(ci, PackedVector2Array([p + Vector2(-h, -h), p + Vector2(h, -h), p + Vector2(h, h), p + Vector2(-h, h), p + Vector2(-h, -h)]), col, s * 0.05, 320 + k * 7, 0.6)


## 연꽃 (육성): 붓으로 그은 꽃잎 다섯 장
static func lotus(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var w := s * 0.055
	var idx := 0
	for k in [-2, -1, 0, 1, 2]:
		idx += 1
		var ang: float = k * 0.42
		var tip: Vector2 = c + Vector2(sin(ang), -cos(ang)) * s * (0.48 - absf(k) * 0.06)
		var base := c + Vector2(k * s * 0.06, s * 0.18)
		var side := Vector2(cos(ang), sin(ang)) * s * 0.12
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(base.lerp(tip, u) + side * sin(u * PI))
		for i in range(6, -1, -1):
			var u := i / 6.0
			pts.append(base.lerp(tip, u) - side * sin(u * PI))
		brush(ci, pts, col, w, 400 + idx * 31, 0.5)
	ink_line(ci, c + Vector2(-s * 0.42, s * 0.25), c + Vector2(s * 0.42, s * 0.23), col, w * 1.1, 470, 0.8)
	brush(ci, _arc_pts(c + Vector2(0, s * 0.1), s * 0.36, 0.3, PI - 0.3, 8), col, w, 480, 0.6)


## 아치형 문 (던전): 붓선 아치와 문살
static func gate(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var w := s * 0.065
	var r := s * 0.34
	var top := c + Vector2(0, -s * 0.08)
	var outer := PackedVector2Array([c + Vector2(-r, s * 0.42)])
	outer.append_array(_arc_pts(top, r, PI, TAU, 10))
	outer.append(c + Vector2(r, s * 0.42))
	rough_fill(ci, outer, Color(col, 0.14), 0.8, 500)
	brush(ci, outer, col, w, 510, 0.7)
	ink_line(ci, c + Vector2(-r - s * 0.1, s * 0.43), c + Vector2(r + s * 0.1, s * 0.41), col, w, 520, 0.8)
	var r2 := r * 0.6
	var inner := PackedVector2Array([c + Vector2(-r2, s * 0.42)])
	inner.append_array(_arc_pts(top + Vector2(0, s * 0.06), r2, PI, TAU, 8))
	inner.append(c + Vector2(r2, s * 0.42))
	brush(ci, inner, col, w * 0.7, 530, 0.5)
	for i in 3:
		ink_line(ci, c + Vector2(-r2, s * (0.1 + i * 0.11)), c + Vector2(r2, s * (0.1 + i * 0.11)), col, w * 0.5, 540 + i, 0.5)


## 원 안의 오망성 (소환): 붓 고리와 별
static func pentagram(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var r := s * 0.44
	var w := s * 0.06
	ink_ring(ci, c, r, col, w, 600, 1.4)
	var pts := PackedVector2Array()
	for i in 6:
		var ang := -PI * 0.5 + TAU * float((i * 2) % 5) / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.84)
	brush(ci, pts, col, w, 610, 0.7)


## 태극 문양
static func taiji(ci: CanvasItem, c: Vector2, r: float, rot: float = 0.0) -> void:
	var light := Color("#f5efe0")
	var dark := Color("#141018")
	ci.draw_circle(c, r, light)
	var pts := PackedVector2Array()
	for i in 33:
		var a := rot + PI * 0.5 + PI * i / 32.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, dark)
	var up := Vector2(cos(rot - PI * 0.5), sin(rot - PI * 0.5)) * r * 0.5
	ci.draw_circle(c + up, r * 0.5, dark)
	ci.draw_circle(c - up, r * 0.5, light)
	ci.draw_circle(c + up, r * 0.15, light)
	ci.draw_circle(c - up, r * 0.15, dark)
	ci.draw_arc(c, r, 0, TAU, 48, INK, 2.0)


## 톱니바퀴 (설정): 뼈색 붓 톱니와 먹색 구멍
static func gear(ci: CanvasItem, c: Vector2, s: float, col: Color = BONE) -> void:
	var r := s * 0.3
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		for o in [-0.2, -0.12, 0.12, 0.2]:
			var rr: float = r * (1.0 if absf(o) > 0.15 else 1.45)
			pts.append(c + Vector2(cos(a + o), sin(a + o)) * rr)
	rough_fill(ci, pts, col, 0.8, 700)
	rough_fill(ci, _circle_pts(c, r * 0.42, 14), INK, 0.6, 701)
	ink_ring(ci, c, r * 1.12, Color(INK, 0.5), 1.5, 702, 0.8)


## 보스 표시 (먹색 귀면): 검은 얼굴에 뼈색 뿔, 주홍 눈
static func boss_face(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.42
	rough_fill(ci, PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.45), c + Vector2(-r * 1.0, -r * 1.3), c + Vector2(-r * 0.3, -r * 0.8)]), BONE, 0.6, 710)
	rough_fill(ci, PackedVector2Array([c + Vector2(r * 0.75, -r * 0.45), c + Vector2(r * 1.0, -r * 1.3), c + Vector2(r * 0.3, -r * 0.8)]), BONE, 0.6, 711)
	rough_fill(ci, _circle_pts(c, r, 18), INK, 1.0, 712)
	ink_ring(ci, c, r, BONE, 2.0, 713, 1.0)
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(sx * r * 0.38, -r * 0.08)
		ci.draw_circle(e, r * 0.26, Color(ACCENT, 0.35))
		rough_fill(ci, PackedVector2Array([e + Vector2(-sx * r * 0.22, -r * 0.12), e + Vector2(sx * r * 0.2, -r * 0.02), e + Vector2(-sx * r * 0.16, r * 0.1)]), ACCENT, 0.4, 720 + int(sx))
	brush(ci, PackedVector2Array([c + Vector2(-r * 0.45, r * 0.42), c + Vector2(-r * 0.15, r * 0.32), c + Vector2(r * 0.15, r * 0.42), c + Vector2(r * 0.45, r * 0.32)]), BONE, 1.6, 730, 0.4)


## 장비 부위 아이콘. slot: weapon/helmet/armor/shoes/accessory
## 등급 색으로 칠한 면 + 먹색 붓 외곽선 + 뼈색 붓 하이라이트
static func slot_icon(ci: CanvasItem, slot: String, c: Vector2, s: float, col: Color) -> void:
	var lt := col.lightened(0.35)
	var ow := maxf(1.5, s * 0.05)
	var seed_v := slot.hash() % 1000
	var shape := PackedVector2Array()
	match slot:
		"helmet":
			shape = PackedVector2Array([c + Vector2(-s * 0.44, s * 0.2), c + Vector2(s * 0.44, s * 0.2), c + Vector2(s * 0.26, -s * 0.14), c + Vector2(s * 0.1, -s * 0.16), c + Vector2(s * 0.08, -s * 0.32), c + Vector2(-s * 0.08, -s * 0.32), c + Vector2(-s * 0.1, -s * 0.16), c + Vector2(-s * 0.26, -s * 0.14)])
		"armor":
			shape = PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.38), c + Vector2(-s * 0.42, -s * 0.24), c + Vector2(-s * 0.32, s * 0.4), c + Vector2(s * 0.32, s * 0.4), c + Vector2(s * 0.42, -s * 0.24), c + Vector2(s * 0.18, -s * 0.38), c + Vector2(0, -s * 0.2)])
		"shoes":
			shape = PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.4), c + Vector2(s * 0.08, -s * 0.4), c + Vector2(s * 0.1, s * 0.08), c + Vector2(s * 0.42, s * 0.2), c + Vector2(s * 0.44, s * 0.4), c + Vector2(-s * 0.22, s * 0.4)])
		"weapon":
			var d := Vector2(1, -1).normalized()
			var n := d.orthogonal() * s * 0.065
			var a := c + Vector2(-s * 0.26, s * 0.26)
			var b := c + Vector2(s * 0.4, -s * 0.4)
			shape = PackedVector2Array([a + n, b + n * 0.4, b + d * s * 0.06, b - n * 0.4, a - n])
			rough_fill(ci, shape, col, 0.6, seed_v)
			brush(ci, PackedVector2Array([a + n, b + n * 0.4, b + d * s * 0.06, b - n * 0.4, a - n, a + n]), INK, ow, seed_v + 1, 0.4)
			ink_line(ci, c + Vector2(-s * 0.36, s * 0.12), c + Vector2(-s * 0.12, s * 0.36), INK, s * 0.09, seed_v + 2, 0.4)
			ink_line(ci, a, c + Vector2(-s * 0.44, s * 0.44), INK, s * 0.09, seed_v + 3, 0.4)
			ink_line(ci, a + d * s * 0.1, b - d * s * 0.08, Color(lt, 0.8), maxf(1.0, s * 0.02), seed_v + 4, 0.3)
			return
		_:
			# 장신구: 옥패 (고리 + 둥근 패 + 주홍 술)
			ink_ring(ci, c + Vector2(0, -s * 0.27), s * 0.1, INK, ow, seed_v, 0.5)
			rough_fill(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.29, 18), col, 0.8, seed_v + 1)
			ink_ring(ci, c + Vector2(0, s * 0.06), s * 0.29, INK, ow, seed_v + 2, 0.8)
			rough_fill(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.1, 12), INK, 0.4, seed_v + 3)
			ink_line(ci, c + Vector2(0, s * 0.35), c + Vector2(1, s * 0.48), ACCENT, 3.0, seed_v + 4, 0.4)
			brush(ci, _arc_pts(c + Vector2(0, s * 0.06), s * 0.2, 3.6, 5.0, 6), Color(lt, 0.9), maxf(1.0, s * 0.03), seed_v + 5, 0.3)
			return
	rough_fill(ci, shape, col, 0.8, seed_v)
	var loop := shape.duplicate()
	loop.append(shape[0])
	brush(ci, loop, INK, ow, seed_v + 1, 0.5)
	# 하이라이트 붓 자국 한 줄
	ink_line(ci, shape[1].lerp(shape[2], 0.2), shape[1].lerp(shape[2], 0.8) + (c - shape[1]) * 0.25, Color(lt, 0.8), maxf(1.0, s * 0.03), seed_v + 2, 0.4)


## 붓 띠 게이지: 먹색 홈 + 색 채움(끝이 거칠게 끊김) + 뼈색 붓 테두리
static func ink_bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color, seed_v: int = 1) -> void:
	var g := r.grow(2)
	rough_fill(ci, PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]), Color(0.03, 0.03, 0.03, 0.9), 0.8, seed_v)
	if ratio > 0.0:
		var w := r.size.x * clampf(ratio, 0.0, 1.0)
		var pts := PackedVector2Array([r.position, Vector2(r.position.x + w, r.position.y), Vector2(r.position.x + w - minf(4.0, w), r.end.y), Vector2(r.position.x, r.end.y)])
		rough_fill(ci, pts, col, 0.6, seed_v + 1)
		ink_line(ci, r.position + Vector2(3, 3), Vector2(r.position.x + maxf(w - 5, 3), r.position.y + 3), Color(1, 1, 1, 0.22), 2.0, seed_v + 2, 0.4)
	brush(ci, PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y), g.position]), Color(BONE, 0.45), 1.6, seed_v + 3, 0.5)


## 외곽선 있는 글자
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 5) -> void:
	var font := InkTheme.font_for(size)
	var fs := InkTheme.px(size)
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, fs, outline, Color(0, 0, 0, 0.85 * col.a))
	ci.draw_string(font, pos, s, align, width, fs, col)


## 모서리가 둥근 사각형 채우기/테두리
static func round_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, border: Color = Color(0, 0, 0, 0), border_w: float = 0.0) -> void:
	var sb := InkBox.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	if border_w > 0.0:
		sb.border_color = border
		sb.set_border_width_all(int(border_w))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
