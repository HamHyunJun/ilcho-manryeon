extends RefCounted
class_name InkArt
## 실루엣 + 손그림 질감 스타일의 캐릭터 그림 생성기 (시안 silhouette-chars 반영).
## - 주인공은 먹색 실루엣 하나로 그린다. 얼굴·옷 무늬 없이 모자·옷자락·무기 같은 큰 윤곽으로 구분한다.
## - 색은 무기(검 수술, 주먹 기운, 부적) 같은 작은 포인트에만 쓴다.
## - 도형(다각형·원·굵은 선)을 시안 좌표(200×240, 지면 y=222)로 적고, 가장자리를 잔떨림시켜 붓으로 그린 듯 만든다.
## - 이미지 파일 없이 코드로 텍스처를 만들고 ChibiArt와 같은 사전 형식으로 돌려준다(그리는 쪽 코드는 그대로).
## - 몬스터는 기존 도트 그림을 먹색으로 칠하고 눈만 주홍으로 남긴다 (ink_image).

const INK := Color("#0e0e0e")
const EYE_ACCENT := Color("#d8402f")
## 슈퍼샘플 배율 (크게 그린 뒤 줄여 가장자리를 부드럽게)
const SS := 2
## 시안 좌표 → 그림 픽셀: (p - ORIGIN) * S
const ORIGIN := Vector2(30, 18)
const S := 0.36
## 그림 크기 (그림 픽셀). 시안 x 30~190, y 18~225 (S배)
const W := 58
const H := 75

## 주인공 계열별 도형 (오른쪽을 보는 전투 자세)
## 항목: ["poly", [점...]] (점 대신 [제어점, 끝점]이면 2차 곡선), ["circle", 중심, 반지름], ["line", 시작, 끝, 굵기]
static func _hero_shapes(category: String) -> Dictionary:
	match category:
		"fist":
			# 권법가: 넓은 어깨, 휘날리는 머리띠, 맨주먹
			return {
				"shapes": [
					["circle", Vector2(102, 62), 12.0],
					["poly", [Vector2(92, 56), [Vector2(70, 50), Vector2(48, 60)], [Vector2(66, 56), Vector2(80, 62)], [Vector2(62, 66), Vector2(46, 80)], [Vector2(70, 66), Vector2(92, 65)]]],
					["poly", [Vector2(74, 80), Vector2(130, 80), Vector2(122, 130), Vector2(84, 130)]],
					["poly", [Vector2(84, 128), Vector2(122, 128), Vector2(130, 150), Vector2(74, 150)]],
					["poly", [Vector2(76, 148), Vector2(98, 148), Vector2(80, 196), Vector2(64, 222), Vector2(50, 220), Vector2(66, 192)]],
					["poly", [Vector2(106, 148), Vector2(130, 148), Vector2(140, 190), Vector2(152, 222), Vector2(134, 222), Vector2(124, 192)]],
					["poly", [Vector2(126, 84), Vector2(156, 98), Vector2(152, 110), Vector2(122, 100)]],
					["poly", [Vector2(78, 84), Vector2(56, 108), Vector2(64, 124), Vector2(74, 118), Vector2(70, 108), Vector2(88, 94)]],
				],
				"hand": Vector2(156, 104),
				"head": Rect2(80, 44, 46, 44),
			}
		"spell":
			# 부적 도사: 높은 관, 넓은 소매 도포, 뒷손에 지팡이
			return {
				"shapes": [
					["line", Vector2(64, 44), Vector2(70, 222), 5.0],
					["circle", Vector2(63, 42), 6.0],
					["poly", [Vector2(91, 34), Vector2(109, 34), Vector2(108, 52), Vector2(92, 52)]],
					["line", Vector2(84, 53), Vector2(116, 53), 5.0],
					["circle", Vector2(100, 66), 11.0],
					["poly", [Vector2(100, 74), Vector2(95, 96), Vector2(105, 96)]],
					["poly", [Vector2(86, 78), Vector2(114, 78), Vector2(124, 140), Vector2(134, 214), Vector2(66, 214), Vector2(76, 140)]],
					["poly", [Vector2(87, 82), [Vector2(72, 100), Vector2(64, 118)], Vector2(74, 124), [Vector2(80, 106), Vector2(92, 98)]]],
					["poly", [Vector2(111, 82), Vector2(138, 96), Vector2(134, 106), Vector2(109, 95)]],
					["poly", [Vector2(118, 92), Vector2(134, 100), Vector2(126, 126), Vector2(114, 112)]],
					["poly", [Vector2(66, 214), [Vector2(60, 200), Vector2(50, 196)], Vector2(70, 188)]],
				],
				"hand": Vector2(138, 101),
				"head": Rect2(80, 30, 40, 52),
			}
		_:
			# 삿갓 검객: 넓은 삿갓, 긴 외투, 펄럭이는 옷자락
			return {
				"shapes": [
					["poly", [Vector2(88, 74), Vector2(113, 74), Vector2(120, 120), Vector2(128, 150), Vector2(140, 206), Vector2(112, 200), Vector2(101, 166), Vector2(92, 202), Vector2(62, 208), Vector2(76, 150), Vector2(82, 118)]],
					["poly", [Vector2(77, 148), [Vector2(52, 158), Vector2(34, 176)], [Vector2(52, 171), Vector2(71, 178)]]],
					["poly", [Vector2(86, 80), Vector2(72, 112), Vector2(78, 116), Vector2(92, 92)]],
					["poly", [Vector2(108, 80), Vector2(132, 99), Vector2(127, 108), Vector2(104, 92)]],
					["circle", Vector2(131, 104), 4.5],
					["circle", Vector2(100, 66), 11.0],
					["poly", [Vector2(44, 60), [Vector2(100, 20), Vector2(158, 60)], [Vector2(100, 67), Vector2(44, 60)]]],
					["line", Vector2(96, 200), Vector2(96, 222), 5.0],
					["line", Vector2(106, 198), Vector2(108, 222), 5.0],
				],
				"hand": Vector2(131, 104),
				"head": Rect2(44, 24, 114, 56),
			}


## 주인공 그림. 반환 형식은 ChibiArt.hero()와 같다
static func hero(category: String) -> Dictionary:
	var spec := _hero_shapes(category)
	var k := float(ChibiArt.UPSCALE * SS)
	var img := Image.create_empty(int(W * k), int(H * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed_v := 11
	for sh in spec["shapes"]:
		seed_v += 7
		for poly in _shape_polys(sh, k):
			_fill(img, _rough(poly, 2.2 * SS, seed_v), INK)
	var body := _downsample(img)
	var weapon_kind: String = {"fist": "fist", "spell": "talisman"}.get(category, "sword")
	var weapon: Dictionary
	match weapon_kind:
		"fist":
			weapon = _weapon_fist()
		"talisman":
			weapon = _weapon_talisman()
		_:
			weapon = _weapon_sword()
	var hr: Rect2 = spec["head"]
	return {
		"body": ImageTexture.create_from_image(body),
		"flash": ImageTexture.create_from_image(_white(body)),
		"image": body,
		"weapon": weapon["tex"],
		"weapon_pivot": weapon["pivot"],
		"weapon_kind": weapon_kind,
		"size": Vector2(W, H),
		"hand": _to_art(spec["hand"]),
		## 상단 프로필용 얼굴 영역 (그림 픽셀 단위)
		"head_rect": Rect2(_to_art(hr.position), hr.size * S),
	}


static func _to_art(p: Vector2) -> Vector2:
	return (p - ORIGIN) * S


# ---- 무기 (그림 픽셀 좌표로 직접 그린다. 손잡이 = pivot) ----

## 장검: 먹색 칼날, 짧은 코등이, 붉은 수술
static func _weapon_sword() -> Dictionary:
	var k := float(ChibiArt.UPSCALE * SS)
	var img := Image.create_empty(int(12 * k), int(46 * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var sc := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p * k)
		return out
	# 칼날 (끝이 뾰족), 코등이, 손잡이
	_fill(img, _rough(sc.call([Vector2(5, 3), Vector2(7, 0.5), Vector2(7.6, 3), Vector2(7.2, 35), Vector2(4.8, 35)]), 1.2 * SS, 3), INK)
	_fill(img, _rough(sc.call([Vector2(2, 34.5), Vector2(10, 34.5), Vector2(10, 36.5), Vector2(2, 36.5)]), 0.8 * SS, 4), INK)
	_fill(img, sc.call([Vector2(5.2, 36.5), Vector2(6.8, 36.5), Vector2(6.8, 41.5), Vector2(5.2, 41.5)]), INK)
	# 붉은 수술 (손잡이 끝에서 늘어짐)
	_fill(img, _rough(sc.call([Vector2(5.4, 41.5), Vector2(7.2, 41.5), Vector2(8.6, 45.5), Vector2(4.2, 45.5)]), 0.8 * SS, 5), Color("#d8402f"))
	var out := _downsample(img)
	return {"tex": ImageTexture.create_from_image(out), "pivot": Vector2(6, 38)}


## 맨주먹: 먹색 주먹과 주황 기운
static func _weapon_fist() -> Dictionary:
	var k := float(ChibiArt.UPSCALE * SS)
	var img := Image.create_empty(int(20 * k), int(20 * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, _rough(_circle(Vector2(10, 10) * k, 8.0 * k), 1.5 * SS, 6), Color(0.94, 0.54, 0.17, 0.35))
	_fill(img, _rough(_circle(Vector2(10, 10) * k, 6.2 * k), 1.2 * SS, 7), Color("#f08a2c"))
	_fill(img, _rough(_circle(Vector2(9.5, 10) * k, 4.6 * k), 1.0 * SS, 8), INK)
	var out := _downsample(img)
	return {"tex": ImageTexture.create_from_image(out), "pivot": Vector2(6, 10)}


## 부적: 노란 종이와 먹 글씨
static func _weapon_talisman() -> Dictionary:
	var k := float(ChibiArt.UPSCALE * SS)
	var img := Image.create_empty(int(14 * k), int(22 * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var paper := PackedVector2Array([Vector2(3, 2) * k, Vector2(11, 2) * k, Vector2(11, 18) * k, Vector2(3, 18) * k])
	_fill(img, _rough(paper, 1.0 * SS, 9), Color("#e8c547"))
	_fill(img, _rough(_line_poly(Vector2(6.5, 4) * k, Vector2(6.8, 15) * k, 1.2 * k), 0.6 * SS, 10), INK)
	_fill(img, _rough(_line_poly(Vector2(8.6, 5) * k, Vector2(8.4, 11) * k, 1.0 * k), 0.6 * SS, 11), Color("#8a1a10"))
	# 쥔 손
	_fill(img, _rough(_circle(Vector2(7, 19) * k, 3.0 * k), 0.8 * SS, 12), INK)
	var out := _downsample(img)
	return {"tex": ImageTexture.create_from_image(out), "pivot": Vector2(7, 19)}


# ---- 도형 → 다각형 ----

static func _shape_polys(sh: Array, k: float) -> Array:
	var kind: String = sh[0]
	match kind:
		"circle":
			return [_circle((sh[1] - ORIGIN) * S * k, float(sh[2]) * S * k)]
		"line":
			var a: Vector2 = (sh[1] - ORIGIN) * S * k
			var b: Vector2 = (sh[2] - ORIGIN) * S * k
			var w := float(sh[3]) * S * k
			return [_line_poly(a, b, w), _circle(a, w * 0.5), _circle(b, w * 0.5)]
		_:
			var pts := PackedVector2Array()
			var prev := Vector2.ZERO
			for e in sh[1]:
				if e is Array:
					# 2차 곡선: 이전 점 → 제어점 → 끝점
					var c: Vector2 = e[0]
					var end: Vector2 = e[1]
					for i in range(1, 9):
						var t := i / 8.0
						var p := prev.lerp(c, t).lerp(c.lerp(end, t), t)
						pts.append((p - ORIGIN) * S * k)
					prev = end
				else:
					pts.append((e - ORIGIN) * S * k)
					prev = e
			return [pts]


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(12, int(r * 0.6))
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _line_poly(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var n := (b - a).orthogonal().normalized() * w * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])


## 가장자리 잔떨림: 변을 잘게 나누고 수직으로 조금씩 흔든다 (붓 자국)
static func _rough(pts: PackedVector2Array, amp: float, seed_v: int) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var steps := maxi(1, int(a.distance_to(b) / (3.0 * SS)))
		var nrm := (b - a).orthogonal().normalized()
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			out.append(p + nrm * r.randf_range(-amp, amp) * (0.5 + 0.5 * r.randf()))
	return out


## 다각형 채우기 (스캔라인, 짝홀 규칙)
static func _fill(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var y0 := pts[0].y
	var y1 := pts[0].y
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var iw := img.get_width()
	var n := pts.size()
	for y in range(maxi(0, int(floor(y0))), mini(img.get_height(), int(ceil(y1)) + 1)):
		var yc := y + 0.5
		var xs: Array = []
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for j in range(0, xs.size() - 1, 2):
			var xa := clampi(int(round(xs[j])), 0, iw)
			var xb := clampi(int(round(xs[j + 1])), 0, iw)
			if xb > xa:
				img.fill_rect(Rect2i(xa, y, xb - xa, 1), col)


static func _downsample(img: Image) -> Image:
	var out := img.duplicate()
	out.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_LANCZOS)
	return out


## 불투명 부분을 흰색으로 (피격 번쩍임)
static func _white(img: Image) -> Image:
	var s := img.duplicate()
	for y in s.get_height():
		for x in s.get_width():
			var a: float = s.get_pixel(x, y).a
			if a > 0.0:
				s.set_pixel(x, y, Color(1, 1, 1, a))
	return s


## 몬스터 도트 그림을 먹색 실루엣으로: 불투명 픽셀은 먹색, 눈동자 픽셀만 주홍으로 남긴다
static func ink_image(img: Image, keep_eyes: bool = true) -> Image:
	var s := img.duplicate()
	for y in s.get_height():
		for x in s.get_width():
			var c: Color = s.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var eye: bool = keep_eyes and (c.is_equal_approx(ChibiArt.EYE) or c.is_equal_approx(ChibiArt.EYE_HI))
			s.set_pixel(x, y, Color(EYE_ACCENT, c.a) if eye else Color(INK, c.a))
	return s
