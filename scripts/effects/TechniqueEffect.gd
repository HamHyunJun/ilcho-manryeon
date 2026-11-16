extends Node2D
## 초식 한 번의 연출 (M6). EffectPresets.resolve()가 만든 파라미터로 코드 드로잉만 한다.
## 텍스처 없이 draw_* 도형으로 그려 아트 제작량을 늘리지 않는다 (docs/03 4-2).
## kind: "technique"(초식 발동), "stage_up"(단계 상승 알림), "mastery"(대성 알림)

var params: Dictionary = {}
var kind := "technique"
## 시전 위치(캐릭터 앞)와 대상 위치들 (Effects 레이어 좌표)
var origin := Vector2.ZERO
var targets: Array = []
var ground_y := 760.0
var text := ""
var age := 0.0
var duration := 0.3

## 미리 계산한 파티클: {pos, vel, rot, spin, size, color}
var _particles: Array = []
var _cracks: Array = []
var _font: Font


func setup(p: Dictionary, effect_kind: String, from: Vector2, to: Array, ground: float, rng: RandomNumberGenerator, label: String = "") -> void:
	params = p
	kind = effect_kind
	origin = from
	targets = to
	ground_y = ground
	text = label
	duration = float(p.get("duration", 0.3))
	if kind == "stage_up":
		duration = maxf(duration, 1.2)
	elif kind == "mastery":
		duration = maxf(duration, 2.0)
	_font = ThemeDB.fallback_font
	var n := int(p.get("particles", 0))
	if kind == "mastery":
		n = maxi(n, 40)
	elif kind == "stage_up":
		n = maxi(n, 16)
	var center := _impact_center()
	var colors: Array = [p.get("color_primary", Color.WHITE), p.get("color_secondary", Color.WHITE)]
	var elements: Array = p.get("element_colors", [])
	for i in n:
		var ang := rng.randf_range(-PI, PI)
		var spd := rng.randf_range(80.0, 260.0) * float(p.get("scale", 1.0))
		var col: Color = colors[i % 2]
		if not elements.is_empty() and i % 3 == 0:
			col = elements[i % elements.size()]
		_particles.append({
			"pos": center if kind == "technique" else from,
			"vel": Vector2(cos(ang), sin(ang) - 0.4) * spd,
			"rot": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-8.0, 8.0),
			"size": rng.randf_range(4.0, 9.0) * sqrt(float(p.get("scale", 1.0))),
			"color": col,
		})
	for i in int(p.get("cracks", 0)):
		var pts := PackedVector2Array()
		var x := center.x + rng.randf_range(-30.0, 30.0)
		var dir := -1.0 if i % 2 == 0 else 1.0
		var pt := Vector2(x, ground_y)
		pts.append(pt)
		for k in 4:
			pt += Vector2(dir * rng.randf_range(12.0, 30.0) * float(p.get("scale", 1.0)), rng.randf_range(-3.0, 6.0))
			pts.append(pt)
		_cracks.append(pts)


func _impact_center() -> Vector2:
	if targets.is_empty():
		return origin + Vector2(80, 0)
	var sum := Vector2.ZERO
	for t in targets:
		sum += t
	return sum / targets.size()


func is_done() -> bool:
	return age >= duration


func advance(delta: float) -> void:
	age += delta
	for pt in _particles:
		pt["vel"] = pt["vel"] + Vector2(0, 320.0) * delta
		pt["pos"] = pt["pos"] + pt["vel"] * delta
		pt["rot"] = pt["rot"] + pt["spin"] * delta
	queue_redraw()


## 화면 흔들림 세기(px). 시작 직후가 가장 세고 줄어든다
func shake_amount() -> float:
	var s := float(params.get("shake", 0.0))
	if kind != "technique" or s <= 0.0:
		return 0.0
	var t := clampf(age / maxf(0.01, duration * 0.6), 0.0, 1.0)
	return s * (1.0 - t)


func _draw() -> void:
	var t := clampf(age / maxf(0.01, duration), 0.0, 1.0)
	var fade := 1.0 - t
	var c1: Color = params.get("color_primary", Color.WHITE)
	var c2: Color = params.get("color_secondary", Color.WHITE)
	var sc := float(params.get("scale", 1.0))
	var inten := float(params.get("intensity", 1.0))
	match kind:
		"technique":
			_draw_technique(t, fade, c1, c2, sc, inten)
		"stage_up":
			_draw_ring(origin, 40.0 + 90.0 * t, c1, fade, 5.0)
			_draw_ring(origin, 20.0 + 60.0 * t, c2, fade, 3.0)
		"mastery":
			for i in 16:
				var a := TAU * i / 16.0 + t * 0.6
				var r0 := 40.0 + 30.0 * t
				var r1 := r0 + 120.0 * (1.0 - absf(0.5 - t) * 1.2)
				var col := c1 if i % 2 == 0 else c2
				col.a = fade
				draw_line(origin + Vector2(cos(a), sin(a)) * r0, origin + Vector2(cos(a), sin(a)) * r1, col, 4.0)
			_draw_ring(origin, 60.0 + 200.0 * t, c1, fade, 8.0)
			_draw_ring(origin, 30.0 + 140.0 * t, Color(1, 0.9, 0.5), fade, 4.0)
	_draw_particles(fade)
	if text != "" and _font:
		var col := c2.lerp(Color.WHITE, 0.5)
		col.a = clampf(fade * 1.6, 0.0, 1.0)
		var size := 30 if kind == "mastery" else 24
		var pos := origin + Vector2(-140, -150 - 40.0 * t)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 280, size, 6, Color(0, 0, 0, col.a))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 280, size, col)


func _draw_technique(t: float, fade: float, c1: Color, c2: Color, sc: float, inten: float) -> void:
	var center := _impact_center()
	var col := c1
	col.a = fade * inten
	# 잔상: 캐릭터 뒤로 반투명 사각형 2개
	if params.get("afterimage", false):
		for i in 2:
			var ac := c2
			ac.a = 0.35 * fade / (i + 1)
			draw_rect(Rect2(origin + Vector2(-60 - 18 * i - 40, -96), Vector2(48, 96)), ac)
	# 기본 모티프
	match params.get("motif", "slash"):
		"slash":
			var r := 30.0 + 120.0 * t * sc
			draw_arc(origin + Vector2(0, -48), r, -0.9, 0.9, 20, col, 4.0 + 2.0 * sc)
			var c2a := c2
			c2a.a = fade * 0.8
			draw_arc(origin + Vector2(0, -48), r * 0.85, -0.7, 0.7, 16, c2a, 2.0)
		"burst":
			draw_circle(center + Vector2(0, -40), (14.0 + 30.0 * t) * sc, Color(col, col.a * 0.5))
			_draw_ring(center + Vector2(0, -40), (20.0 + 50.0 * t) * sc, c1, fade * inten, 4.0)
		"talisman":
			for i in 3:
				var a := t * 4.0 + TAU * i / 3.0
				var p := origin + Vector2(40, -60) + Vector2(cos(a), sin(a)) * 30.0 * sc
				_draw_talisman(p, a, 10.0 * sc, col)
	# 충격파: 대상 위치에 퍼지는 고리
	var sw := float(params.get("shockwave", 0))
	if sw > 0.0:
		_draw_ring(Vector2(center.x, ground_y - 10), sw * t, c1, fade * inten, 3.0 + sc)
	# 검기(파동): 캐릭터에서 대상까지 날아가는 초승달
	if params.get("wave_projectile", false):
		var p := origin.lerp(center, clampf(t * 1.6, 0.0, 1.0)) + Vector2(0, -50)
		var wc := c2
		wc.a = fade
		draw_arc(p, 26.0 * sc, -1.1, 1.1, 14, wc, 5.0 + sc * 2.0)
		draw_arc(p + Vector2(-6, 0), 22.0 * sc, -1.0, 1.0, 12, Color(c1, fade), 3.0)
	# 먼지: 지면 근처 회색 원
	if params.get("dust", false):
		for i in 5:
			var dx := (i - 2) * 22.0 * sc
			draw_circle(Vector2(center.x + dx, ground_y - 6 - 10 * t), (6.0 + 10.0 * t) * sc * 0.6, Color(0.7, 0.66, 0.6, 0.45 * fade))
	# 지면 균열
	for pts in _cracks:
		draw_polyline(pts, Color(0.12, 0.1, 0.08, fade), 3.0)
		draw_polyline(pts, Color(c1, 0.5 * fade), 1.0)
	# 대성: 큰 이중 고리
	if params.get("mastery_burst", false):
		_draw_ring(center + Vector2(0, -50), 40.0 + 160.0 * t, Color(1, 0.9, 0.5), fade, 6.0)
		_draw_ring(center + Vector2(0, -50), 20.0 + 110.0 * t, c1, fade, 3.0)


func _draw_particles(fade: float) -> void:
	var shape: String = params.get("particle_shape", "petal")
	for pt in _particles:
		var col: Color = pt["color"]
		col.a = fade
		var s: float = pt["size"]
		match shape:
			"petal":
				var pts := PackedVector2Array()
				for k in 6:
					var a := TAU * k / 6.0
					pts.append(pt["pos"] + Vector2(cos(a) * s, sin(a) * s * 0.5).rotated(pt["rot"]))
				draw_colored_polygon(pts, col)
			"spark":
				var dir: Vector2 = pt["vel"].normalized() * s * 1.6
				draw_line(pt["pos"] - dir, pt["pos"] + dir, col, 2.0)
			_:
				_draw_talisman(pt["pos"], pt["rot"], s, col)


func _draw_talisman(p: Vector2, rot: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(-s * 0.5, -s).rotated(rot), p + Vector2(s * 0.5, -s).rotated(rot),
		p + Vector2(s * 0.5, s).rotated(rot), p + Vector2(-s * 0.5, s).rotated(rot)])
	draw_colored_polygon(pts, col)


func _draw_ring(center: Vector2, r: float, col: Color, alpha: float, width: float) -> void:
	var c := col
	c.a = clampf(alpha, 0.0, 1.0)
	draw_arc(center, maxf(1.0, r), 0.0, TAU, 40, c, width)
