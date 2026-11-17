extends Node2D
## 초식 한 번의 연출 (M6 → 디자인 시안 design-skill-effects-v4, design-skill-hero-* 반영).
## EffectPresets.resolve()가 만든 파라미터(계열 색, 수련 단계 크기)에 더해 초식마다 다른 연출을 코드로 그린다.
## - 12초식(매화검법/나한권/음양오행술 각 1~4초식)이 각자 고유한 모양을 가진다.
## - 픽셀 제약 없이 3D 게임처럼: 구체 음영, 다층 광채, 충격파 고리, 번개, 꽃잎 폭풍, 바닥 원근 마법진.
## - 가산 혼합(빛이 겹칠수록 밝아짐)으로 그린다. 몬스터 몸 위는 반투명 테두리 위주로 그려 과하게 가리지 않는다.
## - 연출 높이는 대상 위 MAX_RISE px로 제한해 상단 정보창을 덮지 않는다.
## kind: "technique"(초식 발동), "stage_up"(단계 상승 알림), "mastery"(대성 알림)

## 대상 발밑에서 위로 그릴 수 있는 최대 높이 (상단 정보창 보호)
const MAX_RISE := 340.0
## 초식 연출 최소 길이 (초). 너무 짧으면 모양이 보이지 않는다
const MIN_TECH_DURATION := 0.6

static var _glow_tex: Texture2D

var params: Dictionary = {}
var kind := "technique"
## 시전 위치(캐릭터 앞)와 대상 위치들 (Effects 레이어 좌표)
var origin := Vector2.ZERO
var targets: Array = []
var ground_y := 760.0
var text := ""
var age := 0.0
var duration := 0.3
## 초식 식별: 무공 ID와 초식 순서(1~4). 없으면 계열 기본 연출
var art_id := ""
var tech_order := 1

## 미리 계산한 파티클: {pos, vel, rot, spin, size, color}
var _particles: Array = []
var _cracks: Array = []
var _font: Font
var _seed := 0


func setup(p: Dictionary, effect_kind: String, from: Vector2, to: Array, ground: float, rng: RandomNumberGenerator, label: String = "") -> void:
	params = p
	kind = effect_kind
	origin = from
	targets = to
	ground_y = ground
	text = label
	art_id = String(p.get("art_id", ""))
	tech_order = int(p.get("tech_order", 1))
	_seed = rng.randi()
	duration = float(p.get("duration", 0.3))
	if kind == "technique":
		duration = maxf(duration, MIN_TECH_DURATION)
		# 빛 연출은 가산 혼합으로 그린다
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	elif kind == "stage_up":
		duration = maxf(duration, 1.2)
	elif kind == "mastery":
		duration = maxf(duration, 2.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = ThemeDB.fallback_font
	var n := int(p.get("particles", 0))
	if kind == "technique":
		n = maxi(n, 8)
	elif kind == "mastery":
		n = maxi(n, 40)
	elif kind == "stage_up":
		n = maxi(n, 16)
	var center := _impact_center()
	# 가산 혼합에서 흐리게 보이지 않도록 파티클은 기본색 위주로 쓴다
	var pc: Color = p.get("color_primary", Color.WHITE)
	var colors: Array = [pc, pc.lightened(0.35)]
	var elements: Array = p.get("element_colors", [])
	for i in n:
		var ang := rng.randf_range(-PI, PI)
		var spd := rng.randf_range(90.0, 280.0) * sqrt(float(p.get("scale", 1.0)))
		var col: Color = colors[i % 2]
		if not elements.is_empty() and i % 3 == 0:
			col = elements[i % elements.size()]
		_particles.append({
			"pos": (center + Vector2(0, -45)) if kind == "technique" else from,
			"vel": Vector2(cos(ang), sin(ang) - 0.5) * spd,
			"rot": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-8.0, 8.0),
			"size": rng.randf_range(5.0, 10.0) * sqrt(float(p.get("scale", 1.0))),
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
		pt["vel"] = pt["vel"] + Vector2(0, 260.0) * delta
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


# ---- 그리기 ----

func _draw() -> void:
	var t := clampf(age / maxf(0.01, duration), 0.0, 1.0)
	var fade := 1.0 - t
	var c1: Color = params.get("color_primary", Color.WHITE)
	var c2: Color = params.get("color_secondary", Color.WHITE)
	match kind:
		"technique":
			_draw_technique(t, fade, c1, c2)
		"stage_up":
			_glow(origin, 90.0 + 60.0 * t, c1, 0.5 * fade)
			_ring(origin, 40.0 + 90.0 * t, c1, fade, 5.0)
			_ring(origin, 20.0 + 60.0 * t, c2, fade, 3.0)
		"mastery":
			_glow(origin, 220.0 * (0.6 + t), c1, 0.45 * fade)
			for i in 16:
				var a := TAU * i / 16.0 + t * 0.6
				var r0 := 40.0 + 30.0 * t
				var r1 := r0 + 120.0 * (1.0 - absf(0.5 - t) * 1.2)
				var col := c1 if i % 2 == 0 else c2
				col.a = fade
				draw_line(origin + Vector2(cos(a), sin(a)) * r0, origin + Vector2(cos(a), sin(a)) * r1, col, 4.0)
			_ring(origin, 60.0 + 200.0 * t, c1, fade, 8.0)
			_ring(origin, 30.0 + 140.0 * t, Color(1, 0.9, 0.5), fade, 4.0)
			_magic_circle(Vector2(origin.x, ground_y), 120.0 + 40.0 * t, c1, fade, t * 2.0)
	_draw_particles(fade)
	if text != "" and _font:
		var col := c2.lerp(Color.WHITE, 0.5)
		col.a = clampf(fade * 1.6, 0.0, 1.0)
		var size := 30 if kind == "mastery" else 24
		var pos := origin + Vector2(-140, -150 - 40.0 * t)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 280, size, 6, Color(0, 0, 0, col.a))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 280, size, col)


## 수련 단계에 따른 크기 배율 (입문 0.85 ~ 대성 1.3). 화면을 덮지 않도록 상한을 둔다
func _grow() -> float:
	var st := float(params.get("stage", 1))
	return lerpf(0.85, 1.3, clampf((st - 1.0) / 6.0, 0.0, 1.0))


func _draw_technique(t: float, fade: float, c1: Color, c2: Color) -> void:
	var g := _grow()
	var inten := float(params.get("intensity", 1.0))
	var a := fade * lerpf(0.75, 1.0, inten)
	var center := _impact_center()
	var body := center + Vector2(0, -45)
	var hand := origin + Vector2(6, -48)
	var category := String(params.get("category", "sword"))
	var key := art_id
	if key == "":
		key = {"sword": "plum_blossom_sword", "fist": "arhat_fist", "spell": "yin_yang_five_elements"}.get(category, "plum_blossom_sword")
	match key:
		"arhat_fist":
			match tech_order:
				2: _fist_triple(t, a, body, g)
				3: _fist_palm_wind(t, a, hand, body, g)
				4: _fist_vajra(t, a, center, body, g)
				_: _fist_straight(t, a, hand, body, g)
		"yin_yang_five_elements":
			match tech_order:
				2: _spell_flame(t, a, center, g)
				3: _spell_water(t, a, center, body, g)
				4: _spell_thunder(t, a, center, body, g)
				_: _spell_talisman(t, a, hand, body, g)
		_:
			match tech_order:
				2: _plum_cross(t, a, center, body, g)
				3: _plum_thrust(t, a, hand, body, g)
				4: _plum_bloom(t, a, center, body, g)
				_: _plum_slash(t, a, body, g)
	# 단계 공통 부가 연출: 충격파 고리, 먼지, 지면 균열, 대성 이중 고리
	var sw := float(params.get("shockwave", 0))
	if sw > 0.0:
		_ellipse_ring(Vector2(center.x, ground_y - 4), minf(sw, 180.0) * t, c1, a * 0.7, 3.0)
	if params.get("dust", false):
		for i in 5:
			var dx := (i - 2) * 22.0 * g
			draw_circle(Vector2(center.x + dx, ground_y - 6 - 10 * t), (6.0 + 10.0 * t) * g * 0.6, Color(0.5, 0.45, 0.4, 0.25 * fade))
	for pts in _cracks:
		draw_polyline(pts, Color(c1, 0.5 * fade), 2.0)
	if params.get("mastery_burst", false):
		_ring(body, 40.0 + 160.0 * t, Color(1, 0.9, 0.5), fade, 6.0)
		_ring(body, 20.0 + 110.0 * t, c1, fade, 3.0)


# ---- 매화검법 (분홍 매화, 검기) ----

const PINK := Color("#ff7fb8")
const PINK_L := Color("#ffc4dd")

## 1초식 횡베기: 대상을 가르는 큰 초승달 검기 + 분홍 광채
func _plum_slash(t: float, a: float, body: Vector2, g: float) -> void:
	var sweep := clampf(t * 2.2, 0.0, 1.0)
	var r := 96.0 * g
	var a0 := -2.5
	var a1 := lerpf(a0, 0.9, sweep)
	_glow(body, 120.0 * g, PINK, 0.35 * a)
	if a1 > a0 + 0.05:
		draw_arc(body, r, a0, a1, 32, Color(PINK, 0.25 * a), 30.0 * g)
		draw_arc(body, r, a0 + 0.2, a1, 32, Color(PINK, 0.7 * a), 12.0 * g)
		draw_arc(body, r, a0 + 0.5, a1, 28, Color(1, 1, 1, a), 4.0 * g)
		_sparkle(body + Vector2(cos(a1), sin(a1)) * r, 16.0 * g, Color(1, 1, 1, a))
	_sparkles_around(body, 90.0 * g, 6, PINK_L, a, t)


## 2초식 X자 베기: 대상 위에서 교차하는 두 줄기 빛 + 바닥 고리
func _plum_cross(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var L := 105.0 * g
	_magic_circle(Vector2(center.x, ground_y), 95.0 * g, PINK, a * 0.6, t * 1.5)
	for i in 2:
		var k := clampf((t - 0.15 * i) * 2.6, 0.0, 1.0)
		if k <= 0.0:
			continue
		var d := Vector2(1, -0.85 if i == 0 else 0.85).normalized()
		var p0 := body - d * L
		var p1 := body - d * L + d * 2.0 * L * k
		_beam(p0, p1, PINK, a, 26.0 * g)
	_glow(body, 80.0 * g, PINK, 0.4 * a)
	_sparkles_around(body, 110.0 * g, 8, PINK_L, a, t)


## 3초식 삼연 찌르기: 주인공 칼끝에서 대상으로 뻗는 세 줄기 찌르기
func _plum_thrust(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	for i in 3:
		var k := clampf((t - 0.12 * i) * 3.0, 0.0, 1.0)
		if k <= 0.0:
			continue
		var y := (i - 1) * 24.0 * g
		var from := Vector2(hand.x + 20.0, body.y + y)
		var to := Vector2(lerpf(from.x, body.x + 30.0, k), body.y + y)
		var w := 10.0 * g
		var pts := PackedVector2Array([from + Vector2(0, -w * 0.25), to + Vector2(-26 * g, -w * 0.5), to, to + Vector2(-26 * g, w * 0.5), from + Vector2(0, w * 0.25)])
		draw_colored_polygon(pts, Color(PINK, 0.55 * a))
		draw_line(from, to, Color(1, 1, 1, a), 2.5 * g)
		_glow(to, 34.0 * g, PINK, 0.8 * a)
		_sparkle(to, 12.0 * g, Color(1, 1, 1, a))
	_glow(body, 70.0 * g, PINK, 0.3 * a)


## 4초식 매화 만개: 대상 위로 피어나는 거대한 다섯 꽃잎 매화 + 원근 마법진 + 꽃잎 폭풍
func _plum_bloom(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	_magic_circle(Vector2(center.x, ground_y), 150.0 * g, PINK, a, t * 2.0)
	var bloom := _ease_back(clampf(t * 2.0, 0.0, 1.0))
	var r := 88.0 * g * bloom
	_glow(body, 170.0 * g, PINK, 0.45 * a)
	if r > 2.0:
		_plum_flower(body, r, t * 1.2, a)
	_ring(body, 40.0 + 170.0 * g * t, PINK_L, a * 0.8, 4.0)
	# 꽃잎 폭풍: 대상 둘레를 돌며 퍼진다
	for i in 26:
		var ang := TAU * i / 26.0 + t * 5.0
		var rr := (50.0 + 150.0 * t) * g * (0.6 + 0.4 * _hash01(i))
		var p := body + Vector2(cos(ang) * rr, sin(ang) * rr * 0.55)
		_petal(p, 9.0 * g, ang * 2.0, Color(PINK_L if i % 3 else Color.WHITE, a * 0.9))
	_sparkles_around(body, 160.0 * g, 10, Color.WHITE, a, t)


# ---- 나한권 (금빛, 주황 기공) ----

const GOLD := Color("#ffb43c")
const GOLD_L := Color("#fff0b0")

## 1초식 직권: 속도선 + 대상에 터지는 빛 구체와 방사형 가시
func _fist_straight(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 3.0, 0.0, 1.0)
	for i in 7:
		var y := (i - 3) * 9.0 * g
		var x0 := lerpf(hand.x, body.x - 40.0, clampf(k - 0.1 * absf(i - 3), 0.0, 1.0) * 0.6)
		draw_line(Vector2(x0, body.y + y), Vector2(lerpf(hand.x, body.x, k), body.y + y), Color(GOLD, 0.7 * a * (1.0 - absf(i - 3) / 4.0)), 3.0)
	if t > 0.2:
		var it := clampf((t - 0.2) / 0.8, 0.0, 1.0)
		_sphere(body, 32.0 * g * (0.7 + 0.5 * it), GOLD, a)
		_spikes(body, 34.0 * g, 85.0 * g * (0.6 + 0.6 * it), 12, GOLD_L, a)
		_ellipse_ring(body, 60.0 * g + 70.0 * it * g, GOLD, a * (1.0 - it), 4.0, 0.55)


## 2초식 삼연타: 대상 둘레 세 곳에 차례로 터지는 빛 구체
func _fist_triple(t: float, a: float, body: Vector2, g: float) -> void:
	var offs := [Vector2(-26, -28), Vector2(14, 0), Vector2(46, 26)]
	for i in 3:
		var k := clampf((t - 0.18 * i) / 0.45, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var p: Vector2 = body + offs[i] * g
		var fk := 1.0 - k
		_sphere(p, 26.0 * g * (0.6 + 0.6 * k), GOLD, a * fk * 1.3)
		_spikes(p, 26.0 * g, 64.0 * g * (0.5 + 0.7 * k), 10, GOLD_L, a * fk)
		_ring(p, 30.0 * g + 40.0 * k * g, GOLD, a * fk, 3.0)


## 3초식 장풍: 손바닥에서 뻗어 나가는 금빛 초승달 장풍 + 수평 속도선
func _fist_palm_wind(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 1.8, 0.0, 1.0)
	var front := Vector2(lerpf(hand.x + 20.0, body.x + 10.0, k), body.y)
	for i in 8:
		var y := (i - 3.5) * 12.0 * g
		var len := 120.0 * g * (0.6 + 0.4 * _hash01(i))
		draw_line(Vector2(front.x - 30.0 - len, front.y + y), Vector2(front.x - 30.0, front.y + y), Color(GOLD_L, 0.6 * a), 2.5)
	var r := 70.0 * g
	_glow(front, 90.0 * g, GOLD, 0.4 * a)
	draw_arc(front + Vector2(-r * 0.6, 0), r, -1.2, 1.2, 28, Color(GOLD, 0.3 * a), 26.0 * g)
	draw_arc(front + Vector2(-r * 0.6, 0), r, -1.1, 1.1, 28, Color(GOLD, 0.8 * a), 10.0 * g)
	draw_arc(front + Vector2(-r * 0.6, 0), r, -0.95, 0.95, 24, Color(1, 1, 1, a), 3.5 * g)
	if k >= 1.0:
		_glow(body, 80.0 * g, GOLD, 0.5 * a)
		_sparkles_around(body, 80.0 * g, 6, GOLD_L, a, t)


## 4초식 금강일격: 대상 위의 거대한 금빛 구체가 내리꽂히고, 바닥에 원근 마법진과 충격파
func _fist_vajra(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	_magic_circle(Vector2(center.x, ground_y), 150.0 * g, GOLD, a, -t)
	_ground_grid(Vector2(center.x, ground_y), 150.0 * g, GOLD, a * 0.8)
	var drop := clampf(t * 2.5, 0.0, 1.0)
	var p := body + Vector2(0, lerpf(-150.0, -10.0, drop * drop) * g)
	var r := 58.0 * g * (1.0 if drop < 1.0 else 1.0 + 0.25 * (t - 0.4))
	_sphere(p, r, GOLD, a * (0.85 if drop >= 1.0 else 1.0))
	if drop >= 1.0:
		var k := (t - 0.4) / 0.6
		_ellipse_ring(Vector2(center.x, ground_y - 4), 60.0 * g + 160.0 * g * k, GOLD_L, a * (1.0 - k), 6.0)
		_spikes(body, 50.0 * g, 130.0 * g, 16, GOLD_L, a * (1.0 - k))
		for i in 10:
			var ang := -PI * _hash01(i + 3)
			var d := Vector2(cos(ang), sin(ang)) * (40.0 + 120.0 * k) * g
			draw_rect(Rect2(Vector2(center.x, ground_y - 8) + d, Vector2(5, 5) * g), Color(GOLD_L, a * (1.0 - k)))


# ---- 음양오행술 (부적, 오행 원소) ----

const TALISMAN := Color("#ffe25a")
const FIRE := Color("#ff6a2a")
const FIRE_L := Color("#ffd27a")
const WATER := Color("#5fd8ff")
const THUNDER := Color("#fff27a")

## 1초식 부적 발사: 빛나는 부적 세 장이 날아가 터진다
func _spell_talisman(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	for i in 3:
		var k := clampf((t - 0.1 * i) * 2.2, 0.0, 1.0)
		var y := (i - 1) * 26.0 * g
		var p := hand.lerp(body + Vector2(-10, y * 0.6), k) + Vector2(0, y * (1.0 - k) - sin(k * PI) * 30.0)
		if k < 1.0:
			_glow(p, 30.0 * g, TALISMAN, 0.8 * a)
			var rot := k * 6.0 + i
			var s := 9.0 * g
			var pts := PackedVector2Array([p + Vector2(-s * 0.6, -s).rotated(rot), p + Vector2(s * 0.6, -s).rotated(rot), p + Vector2(s * 0.6, s).rotated(rot), p + Vector2(-s * 0.6, s).rotated(rot)])
			draw_colored_polygon(pts, Color(TALISMAN, a))
			draw_line(p + Vector2(0, -s * 0.6).rotated(rot), p + Vector2(0, s * 0.6).rotated(rot), Color(1, 0.3, 0.2, a), 2.0)
			# 불꽃 꼬리
			for j in 3:
				var tail := p - (body - hand).normalized() * (10.0 + j * 9.0) * g
				_sparkle(tail, (6.0 - j) * g, Color(TALISMAN, a * 0.6))
		else:
			var e := clampf((t - 0.1 * i - 0.45) / 0.4, 0.0, 1.0)
			_glow(body + Vector2(0, y * 0.6), 60.0 * g, TALISMAN, a * (1.0 - e))
			_zigzag(body + Vector2(0, y * 0.6), 50.0 * g, 6, THUNDER, a * (1.0 - e), i)


## 2초식 화염: 대상 둘레에서 솟구치는 불기둥과 바닥 화염 고리
func _spell_flame(t: float, a: float, center: Vector2, g: float) -> void:
	var base := Vector2(center.x, ground_y)
	_ellipse_ring(base + Vector2(0, -2), 110.0 * g, FIRE, a, 5.0)
	_glow(base + Vector2(0, -50), 130.0 * g, FIRE, 0.4 * a)
	var rise := _ease_back(clampf(t * 2.4, 0.0, 1.0))
	for i in 9:
		var u := (i - 4) / 4.0
		var x := base.x + u * 95.0 * g
		var h := (120.0 - absf(u) * 55.0) * g * rise * (0.85 + 0.3 * sin(age * 25.0 + i))
		var w := (22.0 - absf(u) * 6.0) * g
		var y := base.y + 4.0 - absf(u) * 10.0
		_flame(Vector2(x, y), h, w, FIRE, a * 0.85)
		_flame(Vector2(x, y), h * 0.65, w * 0.6, FIRE_L, a)
	for i in 10:
		var k := fmod(t * 1.5 + _hash01(i), 1.0)
		var p := base + Vector2((_hash01(i + 20) - 0.5) * 180.0 * g, -k * 200.0 * g)
		draw_rect(Rect2(p, Vector2(4, 4)), Color(FIRE_L, a * (1.0 - k)))


## 3초식 수류: 대상을 감싸는 물의 소용돌이와 물방울
func _spell_water(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var rmax := 105.0 * g * clampf(0.4 + t * 1.5, 0.0, 1.0)
	_glow(body, rmax * 1.3, WATER, 0.3 * a)
	for arm in 4:
		var pts := PackedVector2Array()
		for s in 34:
			var u := s / 33.0
			var ang := u * TAU * 1.4 + arm * TAU / 4.0 + age * 7.0
			var rr := rmax * u
			pts.append(body + Vector2(cos(ang) * rr, sin(ang) * rr * 0.8))
		draw_polyline(pts, Color(WATER, 0.35 * a), 10.0 * g)
		draw_polyline(pts, Color(0.85, 0.97, 1.0, a), 3.0 * g)
	_ring(body, rmax, Color(WATER, 1.0), a * 0.8, 4.0)
	for i in 12:
		var ang := TAU * i / 12.0 + age * 2.0
		var p := body + Vector2(cos(ang), sin(ang) * 0.8) * (rmax + 22.0 * g)
		_drop(p, 7.0 * g, Color(WATER, a))
	_ellipse_ring(Vector2(center.x, ground_y - 2), rmax * 0.9, WATER, a * 0.6, 3.0)


## 4초식 뇌정 태극: 하늘에서 내리꽂는 번개와 바닥의 태극 문양
func _spell_thunder(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var base := Vector2(center.x, ground_y)
	_taiji(base, 120.0 * g, a, age * 3.0)
	_magic_circle(base, 150.0 * g, THUNDER, a * 0.8, t * 2.0)
	var top_y := maxf(base.y - MAX_RISE, base.y - 330.0)
	var flick := int(age * 24.0)
	for i in 3:
		var dx := (i - 1) * 46.0 * g
		var from := Vector2(base.x + dx * 1.6 + (_hash01(i + flick) - 0.5) * 30.0, top_y)
		var to := body + Vector2(dx * 0.4, 20.0)
		if (flick + i) % 3 != 0:
			_bolt(from, to, flick * 7 + i, THUNDER, a)
	_glow(body, 120.0 * g, THUNDER, 0.6 * a * (0.7 + 0.3 * sin(age * 40.0)))
	_sparkles_around(body, 120.0 * g, 8, Color.WHITE, a, t)


# ---- 공통 도형 ----

static func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		var gt := GradientTexture2D.new()
		gt.width = 128
		gt.height = 128
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.35, Color(1, 1, 1, 0.45))
		gt.gradient = gr
		_glow_tex = gt
	return _glow_tex


## 부드러운 광채 (가산 혼합에서 빛 번짐)
func _glow(p: Vector2, r: float, col: Color, alpha: float) -> void:
	if r <= 0.5 or alpha <= 0.0:
		return
	draw_texture_rect(_glow_texture(), Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, clampf(alpha, 0.0, 1.0)))


func _ring(center: Vector2, r: float, col: Color, alpha: float, width: float) -> void:
	draw_arc(center, maxf(1.0, r), 0.0, TAU, 48, Color(col, clampf(alpha, 0.0, 1.0)), width)


## 원근 타원 고리 (바닥에 누운 원)
func _ellipse_ring(center: Vector2, r: float, col: Color, alpha: float, width: float, squash: float = 0.3) -> void:
	if r <= 1.0 or alpha <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * i / 48.0
		pts.append(center + Vector2(cos(ang) * r, sin(ang) * r * squash))
	draw_polyline(pts, Color(col, clampf(alpha, 0.0, 1.0)), width)


## 바닥 원근 마법진: 이중 고리, 눈금, 회전하는 별 문양, 룬 점
func _magic_circle(center: Vector2, r: float, col: Color, alpha: float, rot: float) -> void:
	if alpha <= 0.0:
		return
	var sq := 0.3
	_ellipse_ring(center, r, col, alpha, 3.0, sq)
	_ellipse_ring(center, r * 0.82, col, alpha * 0.8, 2.0, sq)
	_ellipse_ring(center, r * 0.45, col, alpha * 0.7, 2.0, sq)
	for i in 24:
		var ang := TAU * i / 24.0 + rot * 0.5
		var p0 := center + Vector2(cos(ang) * r * 0.82, sin(ang) * r * 0.82 * sq)
		var p1 := center + Vector2(cos(ang) * r * (0.9 if i % 2 else 0.97), sin(ang) * r * (0.9 if i % 2 else 0.97) * sq)
		draw_line(p0, p1, Color(col, alpha * 0.9), 2.0)
	var star := PackedVector2Array()
	for i in 6:
		var ang := TAU * (i * 2 % 5) / 5.0 + rot
		star.append(center + Vector2(cos(ang) * r * 0.78, sin(ang) * r * 0.78 * sq))
	draw_polyline(star, Color(col, alpha * 0.8), 2.0)
	_glow(center, r * 0.9, col, alpha * 0.25)


## 바닥 원근 격자 (방사선)
func _ground_grid(center: Vector2, r: float, col: Color, alpha: float) -> void:
	for i in 16:
		var ang := TAU * i / 16.0
		draw_line(center, center + Vector2(cos(ang) * r, sin(ang) * r * 0.3), Color(col, alpha * 0.6), 2.0)


## 여러 겹 광선 (검기)
func _beam(p0: Vector2, p1: Vector2, col: Color, alpha: float, width: float) -> void:
	draw_line(p0, p1, Color(col, 0.25 * alpha), width)
	draw_line(p0, p1, Color(col, 0.7 * alpha), width * 0.45)
	draw_line(p0, p1, Color(1, 1, 1, alpha), width * 0.15)
	_glow(p1, width * 1.6, col, alpha)


## 음영이 있는 빛 구체: 바깥 광채, 몸체, 왼쪽 위 반사광, 흰 중심
func _sphere(p: Vector2, r: float, col: Color, alpha: float) -> void:
	_glow(p, r * 2.4, col, 0.6 * alpha)
	draw_circle(p, r, Color(col, 0.45 * alpha))
	draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.78, Color(col, 0.6 * alpha))
	draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.45, Color(col.lightened(0.5), 0.7 * alpha))
	draw_circle(p + Vector2(-r * 0.35, -r * 0.38), r * 0.16, Color(1, 1, 1, alpha))
	draw_arc(p, r, 0.3, 1.9, 16, Color(col.lightened(0.3), 0.6 * alpha), 2.0)


## 방사형 가시 (충격)
func _spikes(p: Vector2, r0: float, r1: float, n: int, col: Color, alpha: float) -> void:
	for i in n:
		var ang := TAU * i / n + _seed % 7
		var len := lerpf(r0, r1, 0.6 + 0.4 * _hash01(i))
		var d := Vector2(cos(ang), sin(ang))
		var side := d.orthogonal() * 3.0
		draw_colored_polygon(PackedVector2Array([p + d * r0 + side, p + d * len, p + d * r0 - side]), Color(col, alpha))


## 반짝이 (네 갈래 별)
func _sparkle(p: Vector2, s: float, col: Color) -> void:
	if col.a <= 0.0:
		return
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.22, 0), p + Vector2(0, s), p + Vector2(-s * 0.22, 0)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, s * 0.22), p + Vector2(s, 0), p + Vector2(0, -s * 0.22)]), col)


func _sparkles_around(p: Vector2, r: float, n: int, col: Color, alpha: float, t: float) -> void:
	for i in n:
		var ang := TAU * _hash01(i + 40)
		var rr := r * (0.4 + 0.6 * _hash01(i + 60)) * (0.6 + 0.6 * t)
		var tw := 0.5 + 0.5 * sin(age * 18.0 + i * 1.7)
		_sparkle(p + Vector2(cos(ang), sin(ang)) * rr, (6.0 + 6.0 * tw) * _grow(), Color(col, alpha * tw))


## 매화 꽃잎 하나 (물방울 모양)
func _petal(p: Vector2, s: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var u := i / 9.0
		var ang := lerpf(-PI * 0.5, PI * 0.5, u)
		pts.append(p + Vector2(cos(ang) * s * 0.55 + s * 0.2, sin(ang) * s).rotated(rot))
	pts.append(p + Vector2(-s * 0.8, 0).rotated(rot))
	draw_colored_polygon(pts, col)


## 다섯 꽃잎 매화: 반투명 꽃잎 + 밝은 테두리 + 금빛 수술
func _plum_flower(p: Vector2, r: float, rot: float, alpha: float) -> void:
	for i in 5:
		var ang := TAU * i / 5.0 + rot - PI * 0.5
		var c := p + Vector2(cos(ang), sin(ang)) * r * 0.55
		var pts := PackedVector2Array()
		for k in 20:
			var u := TAU * k / 20.0
			var local := Vector2(cos(u) * r * 0.52, sin(u) * r * 0.42)
			# 꽃잎 끝을 살짝 오목하게
			if cos(u) > 0.85:
				local.x -= r * 0.08
			pts.append(c + local.rotated(ang))
		draw_colored_polygon(pts, Color(PINK, 0.32 * alpha))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(PINK_L, 0.9 * alpha), 3.0)
		_glow(c, r * 0.45, PINK_L, 0.35 * alpha)
	_glow(p, r * 0.6, Color.WHITE, 0.6 * alpha)
	for i in 10:
		var ang := TAU * i / 10.0 + rot
		var tip := p + Vector2(cos(ang), sin(ang)) * r * 0.32
		draw_line(p, tip, Color(1, 0.9, 0.5, alpha), 2.0)
		draw_circle(tip, 3.0, Color(1, 0.85, 0.3, alpha))


## 불꽃 (물방울을 뒤집은 모양)
func _flame(base: Vector2, h: float, w: float, col: Color, alpha: float) -> void:
	if h <= 2.0:
		return
	var pts := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var ang := lerpf(0.0, PI, u)
		pts.append(base + Vector2(-cos(ang) * w, sin(ang) * w * 0.4))
	pts.append(base + Vector2(sin(age * 20.0) * w * 0.3, -h))
	draw_colored_polygon(pts, Color(col, alpha))


func _drop(p: Vector2, s: float, col: Color) -> void:
	draw_circle(p + Vector2(0, s * 0.3), s * 0.6, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.55, s * 0.2), p + Vector2(0, -s), p + Vector2(s * 0.55, s * 0.2)]), col)


## 지그재그 전기 불꽃
func _zigzag(p: Vector2, r: float, n: int, col: Color, alpha: float, salt: int) -> void:
	for i in n:
		var ang := TAU * i / n + salt
		var pts := PackedVector2Array([p])
		var cur := p
		for k in 3:
			cur += Vector2(cos(ang), sin(ang)) * r / 3.0 + Vector2(cos(ang + 1.5), sin(ang + 1.5)) * (8.0 if k % 2 == 0 else -8.0)
			pts.append(cur)
		draw_polyline(pts, Color(col, alpha), 2.0)


## 번개 줄기: 굵은 광채 + 흰 심지 + 가지
func _bolt(from: Vector2, to: Vector2, salt: int, col: Color, alpha: float) -> void:
	var pts := PackedVector2Array([from])
	var segs := 9
	for i in range(1, segs):
		var u := float(i) / segs
		var p := from.lerp(to, u)
		p.x += (_hash01(salt * 31 + i) - 0.5) * 46.0
		pts.append(p)
	pts.append(to)
	draw_polyline(pts, Color(col, 0.3 * alpha), 14.0)
	draw_polyline(pts, Color(col, 0.8 * alpha), 5.0)
	draw_polyline(pts, Color(1, 1, 1, alpha), 2.0)
	# 가지
	var bi := 3 + salt % 3
	if bi < pts.size():
		var b0 := pts[bi]
		draw_polyline(PackedVector2Array([b0, b0 + Vector2(28, 24), b0 + Vector2(22, 50)]), Color(col, 0.7 * alpha), 2.5)
	_glow(to, 60.0, col, alpha)


## 바닥 태극 문양 (원근)
func _taiji(center: Vector2, r: float, alpha: float, rot: float) -> void:
	var sq := 0.3
	var light := PackedVector2Array()
	var dark := PackedVector2Array()
	for i in 33:
		var u := PI * i / 32.0
		light.append(center + Vector2(cos(u + rot) * r, sin(u + rot) * r * sq))
		dark.append(center + Vector2(cos(u + rot + PI) * r, sin(u + rot + PI) * r * sq))
	draw_colored_polygon(light, Color(1, 1, 0.85, 0.35 * alpha))
	draw_colored_polygon(dark, Color(0.45, 0.35, 1.0, 0.3 * alpha))
	_ellipse_ring(center, r, THUNDER, alpha, 3.0, sq)
	var c1 := center + Vector2(cos(rot) * r * 0.5, sin(rot) * r * 0.5 * sq)
	var c2 := center + Vector2(cos(rot + PI) * r * 0.5, sin(rot + PI) * r * 0.5 * sq)
	_ellipse_ring(c1, r * 0.12, Color(0.45, 0.35, 1.0), alpha, 4.0, sq)
	_ellipse_ring(c2, r * 0.12, Color(1, 1, 0.85), alpha, 4.0, sq)


func _draw_particles(fade: float) -> void:
	var shape: String = params.get("particle_shape", "petal")
	for pt in _particles:
		var col: Color = pt["color"]
		col.a = fade
		var s: float = pt["size"]
		match shape:
			"petal":
				_petal(pt["pos"], s, pt["rot"], col)
			"spark":
				var dir: Vector2 = pt["vel"].normalized() * s * 1.6
				draw_line(pt["pos"] - dir, pt["pos"] + dir, col, 2.5)
			_:
				_sparkle(pt["pos"], s, col)


## 0~1 결정적 난수 (프레임마다 같은 값)
func _hash01(i: int) -> float:
	var h := (i * 73856093) ^ (_seed * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10000) / 10000.0


## 살짝 넘쳤다 돌아오는 이징
func _ease_back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)
