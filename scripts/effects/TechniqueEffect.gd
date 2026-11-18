extends Node2D
## 초식 한 번의 연출 (실루엣 + 손그림 질감 스타일 시안 반영).
## EffectPresets.resolve()가 만든 파라미터(계열 색, 수련 단계 크기)에 더해 초식마다 다른 연출을 코드로 그린다.
## - 12초식(매화검법/나한권/음양오행술 각 1~4초식)이 각자 고유한 모양을 가진다.
##   매화검법: 일섬·영살난무·용아돌·패도참 (붉은 검기)
##   나한권: 파산권·삼연권·장풍·금강진 (주황 권풍, 금강진은 황금빛)
##   음양오행술: 부적술·화염부·수류부·천뢰부 (노란 부적, 오행 원소색)
## - 캐릭터·몬스터·UI는 먹색이고 색은 이펙트에만 쓴다. 굵은 반투명 색 띠 + 흰 심지 + 옅은 번짐,
##   선은 손으로 그은 듯 떨린다.
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
		# 손그림 스타일: 가산 혼합 대신 일반 혼합으로 칠해 흙빛 배경 위에서도 색이 또렷하게 남는다
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


# ---- 손그림 붓 도형 (실루엣 + 손그림 질감 스타일) ----
# 색은 이펙트에만 쓴다. 굵고 반투명한 색 띠 + 가는 흰 심지 + 옅은 번짐, 가장자리는 손으로 그은 듯 떨린다.

## 붓선: 점들을 잇되 마디마다 살짝 흔들고, 끝으로 갈수록 가늘게
func _ink(pts: PackedVector2Array, col: Color, w: float, salt: int, wobble: float = 2.0) -> void:
	if pts.size() < 2 or col.a <= 0.0:
		return
	var prev := pts[0]
	for i in range(1, pts.size()):
		var k := float(i) / (pts.size() - 1)
		var j := Vector2(_hash01(salt * 31 + i) - 0.5, _hash01(salt * 17 + i * 3) - 0.5) * wobble * 2.0
		var p := pts[i] + (j if i < pts.size() - 1 else Vector2.ZERO)
		var ww := w * lerpf(1.0, 0.45, k) * lerpf(0.85, 1.1, _hash01(salt + i * 7))
		draw_line(prev, p, col, maxf(1.0, ww))
		prev = p


## 색 띠 + 흰 심지 한 번에
func _stroke(pts: PackedVector2Array, col: Color, a: float, w: float, salt: int) -> void:
	_ink(pts, Color(col, 0.45 * a), w, salt, 2.5)
	_ink(pts, Color(col, 0.9 * a), w * 0.45, salt + 1, 1.6)
	_ink(pts, Color(1, 1, 1, a), maxf(1.5, w * 0.14), salt + 2, 1.0)


## 원호 위의 점들
func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 20, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var ang := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * squash))
	return pts


## 들쭉날쭉한 번개 경로
func _jag(p0: Vector2, p1: Vector2, seg: int, amp: float, salt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var nrm := (p1 - p0).orthogonal().normalized()
	for i in seg + 1:
		var k := float(i) / seg
		var off := (_hash01(salt * 13 + i) - 0.5) * amp * 2.0 if i > 0 and i < seg else 0.0
		pts.append(p0.lerp(p1, k) + nrm * off)
	return pts


## 초승달(검기): 원호를 따라 가운데가 가장 두껍고 양 끝이 뾰족한 붓 띠. 가장자리는 잔떨림
## (다각형 삼각분할이 깨지지 않도록 짧은 굵은 선을 이어 그린다)
func _crescent(c: Vector2, r: float, a0: float, a1: float, thick: float, col: Color, salt: int) -> void:
	if a1 <= a0 + 0.02 or col.a <= 0.0:
		return
	var n := 26
	var prev := Vector2.ZERO
	for i in n + 1:
		var k := float(i) / n
		var ang := lerpf(a0, a1, k)
		var th := maxf(1.0, thick * sin(k * PI))
		var rr := r - th * 0.5 + (_hash01(salt + i) - 0.5) * 2.5
		var p := c + Vector2(cos(ang), sin(ang)) * rr
		if i > 0:
			draw_line(prev, p, col, th)
			draw_circle(p, th * 0.5, col)
		prev = p


## 잔상 붓털: 원호를 따라 짧게 끊긴 흰 선
func _hairs(c: Vector2, r: float, a0: float, a1: float, n: int, a: float, salt: int) -> void:
	for i in n:
		var ang := lerpf(a0, a1, _hash01(salt + i))
		var rr := r * lerpf(0.85, 1.15, _hash01(salt + i * 5))
		var p0 := c + Vector2(cos(ang), sin(ang)) * rr
		var p1 := c + Vector2(cos(ang - 0.18), sin(ang - 0.18)) * (rr + 4.0)
		draw_line(p0, p1, Color(1, 1, 1, 0.7 * a), 1.5)


# ---- 매화검법 (붉은 검기: 삿갓 검객) ----

const BLADE := Color("#d8402f")
const BLADE_L := Color("#ff8a70")

## 1초식 일섬: 한 번에 그어 내는 붉은 초승달 베기와 잔상
func _plum_slash(t: float, a: float, body: Vector2, g: float) -> void:
	var sweep := clampf(t * 2.4, 0.0, 1.0)
	var r := 100.0 * g
	var c := body + Vector2(-20, 20) * g
	var a0 := -2.6
	var a1 := lerpf(a0, -0.4, sweep)
	_glow(body, 110.0 * g, BLADE, 0.25 * a)
	for k in 3:
		_crescent(c, r - k * 6.0, a0 + k * 0.12, a1, (22.0 - k * 6.0) * g, Color(BLADE, (0.3 + k * 0.25) * a), 10 + k)
	_crescent(c, r - 14.0 * g, a0 + 0.35, a1, 5.0 * g, Color(1, 1, 1, a), 20)
	_hairs(c, r, a0, a1, 12, a, 30)


## 2초식 영살난무: 대상 둘레에 어지럽게 교차하는 칼자국
func _plum_cross(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	for i in 6:
		var k := clampf((t - 0.08 * i) * 3.0, 0.0, 1.0)
		if k <= 0.0:
			continue
		var ang := PI * _hash01(100 + i)
		var d := Vector2(cos(ang), sin(ang))
		var off := Vector2(_hash01(110 + i) - 0.5, _hash01(120 + i) - 0.5) * 80.0 * g
		var L := (60.0 + 40.0 * _hash01(130 + i)) * g
		var p0 := body + off - d * L
		var p1 := p0 + d * 2.0 * L * k
		_stroke(_jag(p0, p1, 4, 2.0, 140 + i), BLADE, a, 14.0 * g, 150 + i * 3)
	_glow(body, 80.0 * g, BLADE, 0.3 * a)


## 3초식 용아돌: 칼끝에서 일직선으로 뻗어 적을 꿰뚫는 찌르기와 나선 기운
func _plum_thrust(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 3.0, 0.0, 1.0)
	var from := Vector2(hand.x + 16.0, body.y)
	var to := Vector2(lerpf(from.x, body.x + 160.0 * g, k), body.y)
	var w := 22.0 * g
	if to.x - from.x < 4.0:
		return
	draw_colored_polygon(PackedVector2Array([from, to + Vector2(0, -w), to + Vector2(0, w)]), Color(BLADE, 0.4 * a))
	draw_colored_polygon(PackedVector2Array([from, to + Vector2(0, -w * 0.3), to + Vector2(0, w * 0.3)]), Color(1, 1, 1, 0.9 * a))
	var n := int(24 * k)
	for i in n:
		var x := lerpf(from.x, to.x, float(i) / 24.0)
		var y := body.y + sin(i * 0.9 + t * 10.0) * (4.0 + i * 0.6) * g
		draw_circle(Vector2(x, y), (2.0 + i * 0.07) * g, Color(Color.WHITE if i % 2 else BLADE_L, a))
	for i in 6:
		var x := lerpf(from.x, to.x, _hash01(160 + i))
		var y := body.y + (_hash01(170 + i) - 0.5) * w * 1.4
		draw_line(Vector2(x, y), Vector2(x + 18.0 * g, y), Color(1, 1, 1, 0.7 * a), 1.3)
	_glow(to, 40.0 * g, BLADE, 0.6 * a)


## 4초식 패도참: 머리 위에서 내리찍는 거대한 초승달과 갈라지는 땅
func _plum_bloom(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var sweep := clampf(t * 2.2, 0.0, 1.0)
	var c := body + Vector2(-30, 10) * g
	var r := 110.0 * g
	var a0 := -1.8
	var a1 := lerpf(a0, 0.7, sweep)
	_crescent(c, r, a0, a1, 30.0 * g, Color(BLADE, 0.7 * a), 200)
	_crescent(c, r - 8.0 * g, a0 + 0.1, a1, 7.0 * g, Color(1, 1, 1, a), 210)
	_hairs(c, r, a0, a1, 10, a, 220)
	if t > 0.35:
		var k := clampf((t - 0.35) * 2.5, 0.0, 1.0)
		var base := Vector2(center.x, ground_y - 2)
		for i in 7:
			var ang := lerpf(-0.6, 0.6, i / 6.0) + (PI if i % 2 else 0.0)
			var end := base + Vector2(cos(ang) * 130.0 * g * k, sin(ang) * 18.0 * g * k)
			_ink(_jag(base, end, 5, 5.0, 230 + i), Color(Color.WHITE if i % 3 == 0 else BLADE, a), 3.0, 240 + i, 1.5)
		for i in 10:
			var p := base + Vector2((_hash01(250 + i) - 0.5) * 200.0 * g, -_hash01(260 + i) * 60.0 * k)
			var s := (3.0 + _hash01(270 + i) * 5.0) * g
			draw_rect(Rect2(p, Vector2(s, s)), Color(BLADE, a))
	_glow(body, 140.0 * g, BLADE, 0.3 * a)


# ---- 나한권 (주황 권풍: 권법가 / 금강진은 황금빛) ----

const FIST := Color("#f08a2c")
const FIST_L := Color("#ffc27a")
const VAJRA := Color("#d9a441")

## 1초식 파산권: 주먹에서 원뿔꼴로 퍼지는 권풍 물결
func _fist_straight(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 2.5, 0.0, 1.0)
	var from := Vector2(hand.x + 14.0, body.y)
	var reach := (body.x - from.x) + 70.0 * g
	for i in 4:
		var kk := clampf(k - i * 0.12, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var x := from.x + reach * kk * (0.35 + i * 0.22)
		var h := (18.0 + i * 20.0) * g
		_stroke(_arc_pts(Vector2(x - h * 0.6, body.y), h, -0.9, 0.9, 12), FIST if i % 2 == 0 else FIST_L, a, (9.0 - i) * g, 300 + i * 5)
	for i in 10:
		var ang := (_hash01(320 + i) - 0.5) * 1.4
		var l := (40.0 + _hash01(330 + i) * 80.0) * g * k
		_ink(PackedVector2Array([from + Vector2(cos(ang), sin(ang)) * 16.0, from + Vector2(cos(ang), sin(ang)) * (16.0 + l)]), Color(FIST, 0.8 * a), 2.0, 340 + i, 1.0)
	_glow(from, 34.0 * g, FIST, 0.8 * a)
	draw_circle(from, 9.0 * g, Color(1, 1, 1, a))


## 2초식 삼연권: 대상 위에서 연달아 터지는 세 번의 권풍
func _fist_triple(t: float, a: float, body: Vector2, g: float) -> void:
	for i in 3:
		var k := clampf((t - 0.15 * i) * 3.0, 0.0, 1.0)
		if k <= 0.0:
			continue
		var p := body + Vector2((i - 1) * 26.0, (i - 1) * -18.0) * g
		var aa := a * (1.0 - k * 0.6)
		_stroke(_arc_pts(p, (14.0 + 44.0 * k) * g, -1.1, 1.1, 14), FIST, aa, 9.0 * g, 360 + i * 7)
		_stroke(_arc_pts(p, (8.0 + 26.0 * k) * g, -1.0, 1.0, 10), FIST_L, aa, 6.0 * g, 380 + i * 7)
		_glow(p, 30.0 * g, FIST, 0.7 * aa)
		draw_circle(p, 6.0 * g * (1.0 - k * 0.5), Color(1, 1, 1, aa))


## 3초식 장풍: 손바닥에서 날아가 대상을 휘감는 회오리 바람
func _fist_palm_wind(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 2.2, 0.0, 1.0)
	var c := hand.lerp(body, k)
	for j in 2:
		var pts := PackedVector2Array()
		for i in 40:
			var u := i / 39.0
			var ang := u * PI * 6.0 + t * 12.0 + j * PI
			var rr := (4.0 + u * 30.0) * g
			pts.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.5 - u * 60.0 * g))
		_ink(pts, Color(FIST, 0.85 * a), 4.0 * g, 400 + j, 1.0)
		_ink(pts, Color(1, 1, 1, 0.8 * a), 1.5, 410 + j, 0.6)
	for i in 5:
		var y := hand.y - 30.0 + i * 15.0
		_ink(_arc_pts(Vector2(hand.x + 10.0, y + 60.0), 60.0 + i * 8.0, -1.3, -0.3, 10), Color(FIST_L, 0.6 * a), 2.0, 420 + i, 1.0)
	_glow(c, 50.0 * g, FIST, 0.4 * a)


## 4초식 금강진: 바닥에 펼쳐지는 황금 결계 고리와 대상 뒤 광배
func _fist_vajra(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var k := _ease_back(clampf(t * 2.0, 0.0, 1.0))
	var base := Vector2(center.x, ground_y - 4)
	var r := 100.0 * g * k
	if r > 2.0:
		_ink(_arc_pts(base, r, 0.0, TAU, 40, 0.32), Color(VAJRA, 0.9 * a), 4.0, 440, 1.5)
		_ink(_arc_pts(base, r * 0.82, 0.0, TAU, 36, 0.32), Color(VAJRA, 0.6 * a), 2.0, 441, 1.2)
		for i in 12:
			var ang := TAU * i / 12.0 + t * 1.5
			draw_circle(base + Vector2(cos(ang) * r * 0.91, sin(ang) * r * 0.91 * 0.32), 4.0 * g, Color(1, 1, 1, a))
	var hr := 110.0 * g * k
	if hr > 2.0:
		_ink(_arc_pts(body, hr, PI * 1.1, PI * 1.9, 24), Color(VAJRA, 0.7 * a), 6.0, 450, 2.0)
		for i in 14:
			var ang := PI * (1.05 + 0.9 * i / 13.0)
			var r1 := hr * (1.0 + 0.25 * _hash01(460 + i))
			_ink(PackedVector2Array([body + Vector2(cos(ang), sin(ang)) * hr * 0.6, body + Vector2(cos(ang), sin(ang)) * r1]), Color(VAJRA, 0.8 * a), 2.0, 470 + i, 1.0)
	_glow(body, 120.0 * g, VAJRA, 0.3 * a)


# ---- 음양오행술 (노란 부적과 벼락: 부적 도사 / 오행 원소색) ----

const TALISMAN := Color("#e8c547")
const FIRE := Color("#e8562a")
const FIRE_L := Color("#ffb04a")
const WATER := Color("#46d3d0")
const THUNDER := Color("#f2df5a")

## 부적 한 장 (노란 종이 + 먹 글씨 두 줄)
func _paper(p: Vector2, s: float, rot: float, a: float) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	draw_rect(Rect2(-s * 0.32, -s * 0.5, s * 0.64, s), Color(TALISMAN, a))
	draw_line(Vector2(-s * 0.08, -s * 0.36), Vector2(-s * 0.05, s * 0.34), Color(0.1, 0.05, 0.02, a), 2.0)
	draw_line(Vector2(s * 0.12, -s * 0.3), Vector2(s * 0.1, s * 0.2), Color(0.6, 0.1, 0.05, a), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 1초식 부적술: 부적이 날아가 대상 위에서 터진다
func _spell_talisman(t: float, a: float, hand: Vector2, body: Vector2, g: float) -> void:
	var k := clampf(t * 2.2, 0.0, 1.0)
	for i in 3:
		var kk := clampf(k - i * 0.1, 0.0, 1.0)
		var arc := Vector2(0, -sin(kk * PI) * (40.0 + i * 16.0) * g)
		var p := hand.lerp(body + Vector2(0, (i - 1) * 20.0 * g), kk) + arc
		if kk < 1.0:
			_paper(p, 22.0 * g, kk * 6.0 + i, a)
	if k >= 1.0:
		var e := clampf((t - 0.45) * 2.5, 0.0, 1.0)
		_stroke(_arc_pts(body, (16.0 + 50.0 * e) * g, 0.0, TAU, 22), TALISMAN, a * (1.0 - e * 0.5), 8.0 * g, 500)
		for i in 8:
			var ang := TAU * i / 8.0
			_ink(PackedVector2Array([body + Vector2(cos(ang), sin(ang)) * 20.0 * g, body + Vector2(cos(ang), sin(ang)) * (30.0 + 50.0 * e) * g]), Color(1, 1, 1, a), 2.0, 510 + i, 1.0)
		_glow(body, 70.0 * g, TALISMAN, 0.6 * a)


## 2초식 화염부: 대상 발밑에서 치솟는 불길 (붓으로 그은 불꽃 혀)
func _spell_flame(t: float, a: float, center: Vector2, g: float) -> void:
	var k := clampf(t * 2.0, 0.0, 1.0)
	for tgt in (targets if not targets.is_empty() else [center]):
		var base := Vector2(tgt.x, ground_y - 2)
		for i in 7:
			var x := base.x + (i - 3) * 12.0 * g
			var h := (60.0 + 50.0 * _hash01(520 + i)) * g * k * (1.0 - absf(i - 3) / 5.0)
			var sway := sin(age * 14.0 + i) * 8.0 * g
			var pts := PackedVector2Array([Vector2(x, base.y), Vector2(x + sway * 0.5, base.y - h * 0.5), Vector2(x + sway, base.y - h)])
			_ink(pts, Color(FIRE, 0.75 * a), 12.0 * g, 530 + i, 2.0)
			_ink(pts, Color(FIRE_L, 0.9 * a), 5.0 * g, 540 + i, 1.5)
			_ink(pts, Color(1, 1, 0.9, a), 1.8, 550 + i, 1.0)
		_glow(base + Vector2(0, -40.0 * g), 70.0 * g, FIRE, 0.5 * a)


## 3초식 수류부: 대상을 중심으로 퍼지는 청록 물결 고리와 물방울
func _spell_water(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	for i in 4:
		var k := clampf(t * 1.6 - i * 0.15, 0.0, 1.0)
		if k <= 0.0:
			continue
		_stroke(_arc_pts(body, (20.0 + 110.0 * k) * g, -PI, PI, 32, 0.55), WATER, a * (1.0 - k * 0.7), (7.0 - i) * g, 600 + i * 5)
	for i in 10:
		var ang := TAU * _hash01(620 + i)
		var rr := (30.0 + 100.0 * t) * g * (0.6 + 0.4 * _hash01(630 + i))
		var p := body + Vector2(cos(ang) * rr, sin(ang) * rr * 0.55 - 30.0 * t)
		draw_circle(p, 4.0 * g, Color(WATER if i % 3 else Color.WHITE, a))
	_glow(body, 90.0 * g, WATER, 0.35 * a)


## 4초식 천뢰부: 부적이 뿌려진 자리마다 내리꽂히는 벼락
func _spell_thunder(t: float, a: float, center: Vector2, body: Vector2, g: float) -> void:
	var flick := int(age * 24.0)
	var spots: Array = targets if not targets.is_empty() else [center]
	for si in spots.size():
		var tgt: Vector2 = spots[si]
		var hit := tgt + Vector2(0, -40)
		var top := Vector2(hit.x + (_hash01(700 + si) - 0.5) * 40.0, hit.y - MAX_RISE + 40.0)
		if (flick + si) % 3 != 0:
			var pts := _jag(top, hit, 9, 14.0 * g, 710 + si * 11 + flick % 4)
			_ink(pts, Color(THUNDER, 0.7 * a), 8.0 * g, 720 + si, 1.0)
			_ink(pts, Color(1, 1, 1, a), 2.2, 730 + si, 0.5)
		_glow(hit, 50.0 * g, THUNDER, 0.6 * a)
		draw_circle(hit, 8.0 * g, Color(1, 1, 1, a))
		_paper(hit + Vector2(0, -26.0 * g), 18.0 * g, 0.2 * sin(age * 9.0 + si), a)
	_glow(body, 110.0 * g, THUNDER, 0.25 * a * (0.7 + 0.3 * sin(age * 40.0)))


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
		draw_colored_polygon(pts, Color(BLADE, 0.32 * alpha))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(BLADE_L, 0.9 * alpha), 3.0)
		_glow(c, r * 0.45, BLADE_L, 0.35 * alpha)
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
