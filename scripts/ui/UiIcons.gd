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


## 엽전 두 닢 (상점)
static func coins(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	for o in [Vector2(-s * 0.18, s * 0.12), Vector2(s * 0.2, -s * 0.12)]:
		var p: Vector2 = c + o
		var r := s * 0.3
		ci.draw_circle(p, r, col.darkened(0.25))
		ci.draw_arc(p, r, 0, TAU, 32, col, s * 0.06)
		ci.draw_rect(Rect2(p - Vector2(r, r) * 0.34, Vector2(r, r) * 0.68), col, false, s * 0.05)


## 연꽃 (육성)
static func lotus(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var w := s * 0.05
	for k in [-2, -1, 0, 1, 2]:
		var ang: float = k * 0.42
		var tip: Vector2 = c + Vector2(sin(ang), -cos(ang)) * s * (0.48 - absf(k) * 0.06)
		var base := c + Vector2(k * s * 0.06, s * 0.18)
		var side := Vector2(cos(ang), sin(ang)) * s * 0.12
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			var m := base.lerp(tip, u) + side * sin(u * PI) * (1.0 if true else 1.0)
			pts.append(m)
		for i in range(8, -1, -1):
			var u := i / 8.0
			pts.append(base.lerp(tip, u) - side * sin(u * PI))
		ci.draw_polyline(pts, col, w)
	ci.draw_line(c + Vector2(-s * 0.42, s * 0.24), c + Vector2(s * 0.42, s * 0.24), col, w)
	ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.36, 0.25, PI - 0.25, 16, col, w)


## 아치형 문 (던전)
static func gate(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var w := s * 0.06
	var r := s * 0.34
	var top := c + Vector2(0, -s * 0.08)
	ci.draw_arc(top, r, PI, TAU, 24, col, w)
	ci.draw_line(top + Vector2(-r, 0), c + Vector2(-r, s * 0.42), col, w)
	ci.draw_line(top + Vector2(r, 0), c + Vector2(r, s * 0.42), col, w)
	ci.draw_line(c + Vector2(-r - s * 0.08, s * 0.42), c + Vector2(r + s * 0.08, s * 0.42), col, w)
	var r2 := r * 0.62
	ci.draw_arc(top + Vector2(0, s * 0.06), r2, PI, TAU, 20, col, w * 0.7)
	ci.draw_line(top + Vector2(-r2, s * 0.06), c + Vector2(-r2, s * 0.42), col, w * 0.7)
	ci.draw_line(top + Vector2(r2, s * 0.06), c + Vector2(r2, s * 0.42), col, w * 0.7)
	for i in 3:
		ci.draw_line(c + Vector2(-r2, s * (0.08 + i * 0.11)), c + Vector2(r2, s * (0.08 + i * 0.11)), col, w * 0.5)


## 원 안의 오망성 (소환)
static func pentagram(ci: CanvasItem, c: Vector2, s: float, col: Color = GOLD) -> void:
	var r := s * 0.44
	var w := s * 0.06
	ci.draw_arc(c, r, 0, TAU, 40, col, w)
	ci.draw_arc(c, r * 0.86, 0, TAU, 40, col, w * 0.5)
	var pts := PackedVector2Array()
	for i in 6:
		var ang := -PI * 0.5 + TAU * float((i * 2) % 5) / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.86)
	ci.draw_polyline(pts, col, w)


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


## 톱니바퀴 (설정)
static func gear(ci: CanvasItem, c: Vector2, s: float, col: Color = Color(0.92, 0.92, 0.96)) -> void:
	var r := s * 0.3
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		var side := d.orthogonal() * s * 0.08
		ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.9 + side * 1.3, c + d * r * 1.45 + side, c + d * r * 1.45 - side, c + d * r * 0.9 - side * 1.3]), col)
	ci.draw_circle(c, r, col)
	ci.draw_circle(c, r * 0.42, Color(0.08, 0.07, 0.12))


## 보스 표시 (붉은 귀면)
static func boss_face(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.42
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.5), c + Vector2(-r * 0.95, -r * 1.25), c + Vector2(-r * 0.35, -r * 0.8)]), Color("#f0e0b0"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, -r * 0.5), c + Vector2(r * 0.95, -r * 1.25), c + Vector2(r * 0.35, -r * 0.8)]), Color("#f0e0b0"))
	ci.draw_circle(c, r, Color("#d8312c"))
	ci.draw_arc(c, r, 0, TAU, 32, Color("#4a0c0c"), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.25), c + Vector2(-r * 0.1, -r * 0.05), c + Vector2(-r * 0.55, r * 0.1)]), Color("#ffe14a"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 0.25), c + Vector2(r * 0.1, -r * 0.05), c + Vector2(r * 0.55, r * 0.1)]), Color("#ffe14a"))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.35), Vector2(r, r * 0.25)), Color("#4a0c0c"))
	for i in 4:
		ci.draw_rect(Rect2(c + Vector2(-r * 0.45 + i * r * 0.25, r * 0.35), Vector2(r * 0.15, r * 0.12)), Color.WHITE)


## 장비 부위 아이콘. slot: weapon/helmet/armor/shoes/accessory
static func slot_icon(ci: CanvasItem, slot: String, c: Vector2, s: float, col: Color) -> void:
	var dk := col.darkened(0.45)
	var lt := col.lightened(0.25)
	match slot:
		"helmet":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, s * 0.18), c + Vector2(s * 0.42, s * 0.18), c + Vector2(s * 0.24, -s * 0.14), c + Vector2(-s * 0.24, -s * 0.14)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.3), Vector2(s * 0.2, s * 0.16)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.46, s * 0.14), Vector2(s * 0.92, s * 0.08)), dk)
			ci.draw_line(c + Vector2(-s * 0.18, -s * 0.06), c + Vector2(s * 0.18, -s * 0.06), lt, 2.0)
		"armor":
			var pts := PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.38), c + Vector2(-s * 0.4, -s * 0.24), c + Vector2(-s * 0.32, s * 0.4), c + Vector2(s * 0.32, s * 0.4), c + Vector2(s * 0.4, -s * 0.24), c + Vector2(s * 0.18, -s * 0.38), c + Vector2(0, -s * 0.22)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, -s * 0.22), c + Vector2(0, s * 0.4), dk, 2.0)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.06), c + Vector2(s * 0.3, s * 0.06), dk, 2.0)
			ci.draw_line(c + Vector2(-s * 0.32, -s * 0.18), c + Vector2(-s * 0.26, s * 0.3), lt, 2.0)
		"shoes":
			var pts := PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.4), c + Vector2(s * 0.08, -s * 0.4), c + Vector2(s * 0.08, s * 0.1), c + Vector2(s * 0.42, s * 0.2), c + Vector2(s * 0.42, s * 0.4), c + Vector2(-s * 0.2, s * 0.4)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.32), Vector2(s * 0.62, s * 0.08)), dk)
			ci.draw_line(c + Vector2(-s * 0.14, -s * 0.34), c + Vector2(-s * 0.14, s * 0.2), lt, 2.0)
		"weapon":
			ci.draw_line(c + Vector2(-s * 0.32, s * 0.32), c + Vector2(s * 0.38, -s * 0.38), col, s * 0.12)
			ci.draw_line(c + Vector2(-s * 0.26, s * 0.26), c + Vector2(s * 0.34, -s * 0.34), lt, s * 0.03)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.12), c + Vector2(-s * 0.12, s * 0.3), dk.lightened(0.3), s * 0.08)
			ci.draw_line(c + Vector2(-s * 0.32, s * 0.32), c + Vector2(-s * 0.42, s * 0.42), dk, s * 0.1)
		_:
			# 장신구: 옥패
			ci.draw_arc(c + Vector2(0, -s * 0.26), s * 0.1, 0, TAU, 16, col, 2.0)
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.28, col)
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.1, dk)
			ci.draw_line(c + Vector2(0, s * 0.34), c + Vector2(0, s * 0.46), Color("#e0283a"), 3.0)
			ci.draw_arc(c + Vector2(0, s * 0.06), s * 0.2, 3.6, 5.2, 10, lt, 2.0)


## 외곽선 있는 글자
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 5) -> void:
	var font := ThemeDB.fallback_font
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, size, outline, Color(0, 0, 0, 0.85 * col.a))
	ci.draw_string(font, pos, s, align, width, size, col)


## 모서리가 둥근 사각형 채우기/테두리
static func round_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, border: Color = Color(0, 0, 0, 0), border_w: float = 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	if border_w > 0.0:
		sb.border_color = border
		sb.set_border_width_all(int(border_w))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
