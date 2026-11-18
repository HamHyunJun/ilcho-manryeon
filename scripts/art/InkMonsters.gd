extends RefCounted
class_name InkMonsters
## 몬스터·보스 먹 실루엣 그림 (주인공 InkArt와 같은 붓 실루엣 스타일).
## - 몸 전체를 먹색 실루엣 하나로 그리고, 붉은 눈과 작은 포인트(머리띠 꼬리, 투구 술, 금장 등)만 색을 쓴다.
## - 도형은 주인공과 같은 시안 좌표(200×240, 지면 y=222)에 오른쪽을 보도록 적고, 다 그린 뒤 좌우를 뒤집어 왼쪽(주인공 쪽)을 보게 한다.
## - 결과는 ChibiArt.monster()와 같은 사전 형식(body, flash, ko, weapon, weapon_pivot, size, hand)이다.
##
## 도형 항목: ["poly", 점들] / ["circle", 중심, 반지름] / ["line", 시작, 끝, 굵기]
##            ["accent", 색, 도형] = 포인트 색 도형 / ["eye", 중심, 너비] = 붉은 눈 (쓰러진 그림에서는 지운다)

const INK := InkArt.INK
const EYE := Color("#e0402e")
const RED := Color("#c8302a")
const GOLD := Color("#d9a441")
const VIOLET := Color("#8a6ad8")


static func has_kind(kind: String) -> bool:
	return _spec(kind).size() > 0


## ChibiArt.monster()와 같은 형식으로 그림을 만든다
static func build(kind: String) -> Dictionary:
	var spec := _spec(kind)
	var normal := _paint(spec["shapes"], true)
	var ko := _paint(spec["shapes"], false)
	normal.flip_x()
	ko.flip_x()
	var w := _weapon(String(spec["weapon"]))
	var wimg: Image = w["image"]
	wimg.flip_x()
	var piv: Vector2 = w["pivot"]
	var hand: Vector2 = InkArt._to_art(spec["hand"])
	return {
		"body": ImageTexture.create_from_image(normal),
		"flash": ImageTexture.create_from_image(InkArt._white(normal)),
		"ko": ImageTexture.create_from_image(ko),
		"image": normal,
		"weapon": ImageTexture.create_from_image(wimg),
		"weapon_pivot": Vector2(float(wimg.get_width()) / float(ChibiArt.UPSCALE) - piv.x, piv.y),
		"size": Vector2(InkArt.W, InkArt.H),
		"hand": Vector2(InkArt.W - hand.x, hand.y),
	}


# ---- 칠하기 ----

static func _paint(shapes: Array, eyes: bool) -> Image:
	var k := float(ChibiArt.UPSCALE * InkArt.SS)
	var img := Image.create_empty(int(InkArt.W * k), int(InkArt.H * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed_v := 31
	# 먹 몸통 먼저, 포인트 색과 눈은 위에
	for sh in shapes:
		seed_v += 7
		var kind: String = sh[0]
		if kind == "accent" or kind == "eye":
			continue
		for poly in InkArt._shape_polys(sh, k):
			InkArt._fill(img, InkArt._rough(poly, 2.2 * InkArt.SS, seed_v), INK)
	for sh in shapes:
		seed_v += 5
		var kind: String = sh[0]
		if kind == "accent":
			var col: Color = sh[1]
			for poly in InkArt._shape_polys(sh[2], k):
				InkArt._fill(img, InkArt._rough(poly, 1.4 * InkArt.SS, seed_v), col)
		elif kind == "eye" and eyes:
			var c: Vector2 = (sh[1] - InkArt.ORIGIN) * InkArt.S * k
			var ew := float(sh[2]) * 1.4 * InkArt.S * k
			# 눈꼬리가 올라간 가는 눈
			var pts := PackedVector2Array([c + Vector2(-ew * 0.5, ew * 0.12), c + Vector2(0, -ew * 0.22), c + Vector2(ew * 0.55, -ew * 0.38), c + Vector2(ew * 0.1, ew * 0.2)])
			InkArt._fill(img, pts, EYE)
	return InkArt._downsample(img)


# ---- 몸 부품 (오른쪽을 보는 기준) ----

static func _legs(spread: float = 0.0, thick: float = 0.0) -> Array:
	return [
		["poly", [Vector2(82 - thick, 138), Vector2(98, 138), Vector2(90 - spread * 0.5, 190), Vector2(80 - spread, 222), Vector2(62 - spread - thick, 222), Vector2(76 - spread * 0.5 - thick, 188)]],
		["poly", [Vector2(104, 138), Vector2(120 + thick, 138), Vector2(128 + spread * 0.5 + thick, 188), Vector2(142 + spread + thick, 222), Vector2(124 + spread, 222), Vector2(112 + spread * 0.5, 190)]],
	]


## 앞팔(무기 쥔 손이 끝) + 뒷팔
static func _arms(hand: Vector2, thick: float = 0.0) -> Array:
	return [
		["poly", [Vector2(108, 80 - thick * 0.5), hand + Vector2(4, -6 - thick * 0.5), hand + Vector2(0, 6 + thick * 0.5), Vector2(104, 96 + thick)]],
		["circle", hand, 5.0 + thick * 0.3],
		["poly", [Vector2(90, 82), Vector2(74 - thick, 112), Vector2(80, 118), Vector2(96, 94)]],
	]


static func _spec(kind: String) -> Dictionary:
	match kind:
		"bandit":
			# 산적: 부스스한 머리, 휘날리는 머리띠, 해진 조끼, 도
			return {"weapon": "broad", "hand": Vector2(134, 104), "shapes": _legs(4) + [
				["poly", [Vector2(84, 78), Vector2(118, 78), Vector2(124, 136), Vector2(116, 146), Vector2(108, 136), Vector2(100, 148), Vector2(92, 136), Vector2(84, 146), Vector2(78, 136)]],
				["circle", Vector2(100, 64), 13.0],
				["poly", [Vector2(86, 62), Vector2(82, 46), Vector2(92, 52), Vector2(95, 40), Vector2(102, 50), Vector2(112, 42), Vector2(112, 54), Vector2(118, 56), Vector2(113, 62)]],
				["accent", RED, ["poly", [Vector2(88, 58), [Vector2(72, 50), Vector2(56, 58)], [Vector2(70, 58), Vector2(86, 64)]]]],
				["eye", Vector2(107, 64), 9.0],
			] + _arms(Vector2(134, 104))}
		"brute":
			# 거한: 작은 민머리, 떡 벌어진 어깨, 굵은 팔다리, 몽둥이
			return {"weapon": "club", "hand": Vector2(152, 112), "shapes": _legs(6, 6) + [
				["poly", [Vector2(70, 84), Vector2(134, 82), Vector2(144, 118), Vector2(132, 150), Vector2(78, 150), Vector2(64, 118)]],
				["circle", Vector2(104, 70), 10.0],
				["poly", [Vector2(98, 74), Vector2(114, 74), Vector2(106, 92)]],
				["poly", [Vector2(126, 86), Vector2(156, 104), Vector2(150, 120), Vector2(120, 106)]],
				["circle", Vector2(152, 112), 8.0],
				["poly", [Vector2(76, 88), Vector2(56, 122), Vector2(66, 132), Vector2(86, 104)]],
				["eye", Vector2(110, 68), 8.0],
			]}
		"masked":
			# 흑의 자객: 뾰족한 두건, 휘날리는 목도리, 낮게 웅크린 자세, 단검
			return {"weapon": "dagger", "hand": Vector2(140, 112), "shapes": [
				["poly", [Vector2(84, 128), Vector2(100, 128), Vector2(86, 168), Vector2(62, 222), Vector2(46, 220), Vector2(70, 166)]],
				["poly", [Vector2(104, 128), Vector2(120, 128), Vector2(142, 170), Vector2(152, 222), Vector2(136, 222), Vector2(122, 172)]],
				["poly", [Vector2(90, 84), Vector2(118, 86), Vector2(122, 132), Vector2(82, 134)]],
				["circle", Vector2(106, 72), 11.0],
				["poly", [Vector2(94, 64), Vector2(106, 56), Vector2(118, 64), Vector2(118, 80), Vector2(92, 78)]],
				["poly", [Vector2(96, 62), Vector2(72, 70), Vector2(94, 74)]],
				["poly", [Vector2(92, 82), [Vector2(66, 76), Vector2(46, 90)], [Vector2(68, 88), Vector2(90, 90)]]],
				["eye", Vector2(112, 70), 10.0],
			] + _arms(Vector2(140, 112))}
		"archer":
			# 삿갓 궁수: 원뿔 삿갓, 긴 도포, 등 뒤 화살통, 활
			return {"weapon": "bow", "hand": Vector2(138, 102), "shapes": [
				["poly", [Vector2(88, 76), Vector2(114, 76), Vector2(122, 130), Vector2(134, 206), Vector2(106, 204), Vector2(100, 170), Vector2(94, 204), Vector2(66, 208), Vector2(78, 130)]],
				["line", Vector2(96, 200), Vector2(94, 222), 5.0],
				["line", Vector2(106, 200), Vector2(110, 222), 5.0],
				["line", Vector2(84, 84), Vector2(72, 132), 9.0],
				["line", Vector2(80, 84), Vector2(72, 64), 2.5],
				["line", Vector2(85, 84), Vector2(82, 62), 2.5],
				["accent", RED, ["circle", Vector2(72, 64), 2.6]],
				["circle", Vector2(100, 68), 11.0],
				["poly", [Vector2(50, 68), [Vector2(84, 54), Vector2(100, 34)], [Vector2(116, 54), Vector2(150, 68)], [Vector2(100, 74), Vector2(50, 68)]]],
				["eye", Vector2(108, 72), 8.0],
			] + _arms(Vector2(138, 102))}
		"guard":
			# 철갑 수문위사: 술 달린 투구, 어깨 갑옷, 비늘 치마, 긴 창
			return {"weapon": "spear", "hand": Vector2(136, 104), "shapes": _legs(0, 2) + [
				["poly", [Vector2(80, 80), Vector2(120, 80), Vector2(122, 128), Vector2(128, 152), Vector2(72, 152), Vector2(78, 128)]],
				["circle", Vector2(84, 86), 11.0],
				["circle", Vector2(118, 86), 11.0],
				["circle", Vector2(100, 66), 12.0],
				["poly", [Vector2(85, 66), Vector2(87, 50), Vector2(100, 43), Vector2(113, 50), Vector2(116, 66)]],
				["line", Vector2(80, 66), Vector2(120, 66), 4.0],
				["accent", RED, ["poly", [Vector2(100, 44), [Vector2(88, 30), Vector2(74, 34)], [Vector2(86, 38), Vector2(96, 48)]]]],
				["eye", Vector2(108, 70), 8.0],
			] + _arms(Vector2(136, 104), 2.0)}
		"blood_soldier":
			# 흑혈대 졸개: 짧은 상투, 긴 핏빛 머리띠 꼬리, 허리띠, 도
			return {"weapon": "broad", "hand": Vector2(136, 106), "shapes": _legs(8) + [
				["poly", [Vector2(84, 80), Vector2(118, 80), Vector2(120, 140), Vector2(80, 140)]],
				["circle", Vector2(102, 66), 12.0],
				["circle", Vector2(96, 50), 5.0],
				["accent", RED, ["poly", [Vector2(90, 62), [Vector2(70, 58), Vector2(50, 70)], [Vector2(66, 64), Vector2(56, 80)], [Vector2(74, 68), Vector2(90, 68)]]]],
				["accent", RED, ["poly", [Vector2(80, 120), Vector2(120, 120), Vector2(120, 126), Vector2(80, 126)]]],
				["eye", Vector2(109, 66), 9.0],
			] + _arms(Vector2(136, 106))}
		"elite":
			# 흑혈대 정예: 두건과 복면, 뿔 같은 어깨 갑주, 짧은 망토, 큰 칼
			return {"weapon": "great_blade", "hand": Vector2(138, 106), "shapes": _legs(4, 3) + [
				["poly", [Vector2(86, 80), [Vector2(60, 120), Vector2(50, 176)], Vector2(72, 170), [Vector2(80, 130), Vector2(92, 110)]]],
				["poly", [Vector2(80, 80), Vector2(122, 80), Vector2(124, 142), Vector2(76, 142)]],
				["poly", [Vector2(74, 92), Vector2(70, 72), Vector2(92, 82)]],
				["poly", [Vector2(128, 92), Vector2(134, 72), Vector2(112, 82)]],
				["circle", Vector2(102, 66), 12.0],
				["poly", [Vector2(88, 62), Vector2(102, 50), Vector2(116, 60), Vector2(118, 80), Vector2(86, 80)]],
				["accent", RED, ["poly", [Vector2(80, 112), Vector2(124, 112), Vector2(124, 118), Vector2(80, 118)]]],
				["eye", Vector2(110, 66), 10.0],
			] + _arms(Vector2(138, 106), 3.0)}
		"chief":
			# [보스] 산채 두목: 상투, 털 깃, 넓은 어깨, 뒤로 휘날리는 망토, 금장 대도
			return {"weapon": "broad_gold", "hand": Vector2(140, 106), "shapes": _legs(8, 4) + [
				["poly", [Vector2(84, 82), [Vector2(50, 120), Vector2(36, 196)], Vector2(52, 190), Vector2(60, 204), [Vector2(74, 150), Vector2(92, 110)]]],
				["poly", [Vector2(76, 82), Vector2(126, 82), Vector2(130, 144), Vector2(72, 144)]],
				["poly", [Vector2(74, 84), Vector2(80, 72), Vector2(88, 80), Vector2(96, 70), Vector2(104, 80), Vector2(112, 70), Vector2(118, 80), Vector2(126, 72), Vector2(130, 88), Vector2(100, 96)]],
				["circle", Vector2(102, 62), 13.0],
				["poly", [Vector2(94, 52), Vector2(98, 34), Vector2(106, 52)]],
				["poly", [Vector2(98, 70), Vector2(116, 70), Vector2(108, 90)]],
				["accent", GOLD, ["poly", [Vector2(76, 122), Vector2(130, 122), Vector2(130, 128), Vector2(76, 128)]]],
				["eye", Vector2(110, 62), 10.0],
			] + _arms(Vector2(140, 106), 4.0)}
		"blood_guard":
			# [보스] 흑혈대 혈위대장: 뿔 투구, 육중한 갑옷, 붉은 술, 긴 창
			return {"weapon": "spear_red", "hand": Vector2(138, 104), "shapes": _legs(4, 5) + [
				["poly", [Vector2(78, 80), Vector2(124, 80), Vector2(128, 130), Vector2(134, 156), Vector2(68, 156), Vector2(74, 130)]],
				["circle", Vector2(82, 86), 13.0],
				["circle", Vector2(120, 86), 13.0],
				["circle", Vector2(100, 64), 12.0],
				["poly", [Vector2(84, 66), Vector2(86, 50), Vector2(100, 44), Vector2(114, 50), Vector2(117, 66)]],
				["poly", [Vector2(86, 52), [Vector2(72, 44), Vector2(70, 26)], Vector2(90, 46)]],
				["poly", [Vector2(114, 52), [Vector2(128, 44), Vector2(130, 26)], Vector2(110, 46)]],
				["accent", RED, ["poly", [Vector2(98, 44), [Vector2(90, 30), Vector2(98, 22)], [Vector2(104, 32), Vector2(102, 44)]]]],
				["accent", RED, ["poly", [Vector2(74, 132), Vector2(128, 132), Vector2(128, 138), Vector2(74, 138)]]],
				["eye", Vector2(108, 68), 9.0],
			] + _arms(Vector2(138, 104), 4.0)}
		"shadow_lord":
			# [보스] 무영객: 크게 펄럭이는 두건 망토, 낮은 자세, 쌍단검, 보랏빛 기운
			return {"weapon": "twin_dagger", "hand": Vector2(142, 110), "shapes": [
				["poly", [Vector2(96, 60), [Vector2(48, 90), Vector2(30, 160)], Vector2(46, 152), Vector2(40, 200), [Vector2(70, 170), Vector2(84, 196)], [Vector2(96, 150), Vector2(112, 132)], Vector2(118, 80)]],
				["poly", [Vector2(86, 130), Vector2(102, 130), Vector2(88, 170), Vector2(66, 222), Vector2(50, 220), Vector2(72, 168)]],
				["poly", [Vector2(106, 130), Vector2(120, 130), Vector2(142, 172), Vector2(154, 222), Vector2(138, 222), Vector2(124, 174)]],
				["poly", [Vector2(90, 84), Vector2(120, 86), Vector2(122, 134), Vector2(84, 134)]],
				["circle", Vector2(106, 70), 11.0],
				["poly", [Vector2(90, 66), [Vector2(100, 46), Vector2(120, 58)], Vector2(120, 80), Vector2(92, 80)]],
				["poly", [Vector2(92, 60), Vector2(70, 50), Vector2(90, 70)]],
				["accent", VIOLET, ["poly", [Vector2(40, 200), [Vector2(30, 186), Vector2(34, 170)], [Vector2(44, 184), Vector2(50, 192)]]]],
				["accent", VIOLET, ["poly", [Vector2(30, 160), [Vector2(26, 146), Vector2(34, 136)], [Vector2(36, 150), Vector2(42, 156)]]]],
				["eye", Vector2(112, 70), 11.0],
			] + _arms(Vector2(142, 110))}
		"iron_general":
			# [보스] 철벽 관주: 높은 투구와 금빛 술, 넓은 어깨 갑옷, 수염, 망토, 금창
			return {"weapon": "spear_gold", "hand": Vector2(140, 104), "shapes": _legs(2, 5) + [
				["poly", [Vector2(84, 82), [Vector2(58, 130), Vector2(48, 210)], Vector2(70, 204), [Vector2(80, 150), Vector2(92, 112)]]],
				["poly", [Vector2(76, 80), Vector2(126, 80), Vector2(130, 130), Vector2(136, 158), Vector2(66, 158), Vector2(72, 130)]],
				["poly", [Vector2(64, 92), Vector2(76, 76), Vector2(96, 82), Vector2(90, 98)]],
				["poly", [Vector2(138, 92), Vector2(126, 76), Vector2(106, 82), Vector2(112, 98)]],
				["circle", Vector2(100, 64), 12.0],
				["poly", [Vector2(84, 64), Vector2(88, 44), Vector2(100, 36), Vector2(112, 44), Vector2(116, 64)]],
				["line", Vector2(78, 64), Vector2(122, 64), 4.0],
				["poly", [Vector2(96, 72), Vector2(114, 72), Vector2(106, 94)]],
				["accent", GOLD, ["poly", [Vector2(100, 36), [Vector2(92, 22), Vector2(80, 18)], [Vector2(94, 28), Vector2(104, 38)]]]],
				["accent", GOLD, ["poly", [Vector2(72, 132), Vector2(130, 132), Vector2(130, 138), Vector2(72, 138)]]],
				["eye", Vector2(108, 66), 9.0],
			] + _arms(Vector2(140, 104), 4.0)}
		"blood_lord":
			# [보스] 흑혈대주 혈마도: 상투, 수염, 갈기 같은 찢긴 망토, 핏빛 허리띠, 거대한 혈마도
			return {"weapon": "blood_blade", "hand": Vector2(142, 104), "shapes": _legs(10, 5) + [
				["poly", [Vector2(88, 78), [Vector2(46, 110), Vector2(30, 180)], Vector2(42, 176), Vector2(36, 206), Vector2(52, 194), Vector2(56, 214), [Vector2(72, 160), Vector2(94, 116)]]],
				["poly", [Vector2(76, 80), Vector2(126, 80), Vector2(132, 146), Vector2(70, 146)]],
				["poly", [Vector2(70, 90), Vector2(66, 70), Vector2(90, 80)]],
				["poly", [Vector2(132, 90), Vector2(136, 70), Vector2(112, 80)]],
				["circle", Vector2(102, 62), 13.0],
				["circle", Vector2(98, 44), 6.0],
				["line", Vector2(98, 40), Vector2(84, 30), 3.0],
				["poly", [Vector2(96, 70), Vector2(118, 70), Vector2(112, 86), Vector2(104, 100)]],
				["accent", RED, ["poly", [Vector2(70, 120), Vector2(132, 120), Vector2(132, 128), Vector2(70, 128)]]],
				["accent", RED, ["poly", [Vector2(96, 128), Vector2(104, 128), Vector2(98, 148), Vector2(90, 146)]]],
				["eye", Vector2(110, 62), 11.0],
			] + _arms(Vector2(142, 104), 5.0)}
	return {}


# ---- 무기 (그림 픽셀 좌표, 위로 세운 모양, pivot = 쥔 곳) ----

static func _weapon(kind: String) -> Dictionary:
	match kind:
		"club":
			return _wpn(14, 40, Vector2(7, 36), [
				["poly", [Vector2(5.5, 39), Vector2(4, 12), Vector2(5, 3), Vector2(9, 1), Vector2(12, 5), Vector2(11, 14), Vector2(8.5, 39)], INK],
				["poly", [Vector2(3, 10), Vector2(1, 8), Vector2(4, 7)], INK],
				["poly", [Vector2(12, 12), Vector2(14, 10), Vector2(11, 8)], INK],
			])
		"bow":
			return _wpn(16, 46, Vector2(8, 23), [
				["line", Vector2(8, 2), Vector2(3.5, 23), 3.0, INK],
				["line", Vector2(3.5, 23), Vector2(8, 44), 3.0, INK],
				["line", Vector2(8.5, 2), Vector2(8.5, 44), 0.9, INK],
				["line", Vector2(6, 21), Vector2(6, 25), 3.0, RED],
			])
		"spear", "spear_red", "spear_gold":
			var tip := {"spear": INK, "spear_red": RED, "spear_gold": GOLD}[kind] as Color
			return _wpn(12, 64, Vector2(6, 42), [
				["line", Vector2(6, 10), Vector2(6, 63), 1.8, INK],
				["poly", [Vector2(6, 0), Vector2(9, 8), Vector2(6, 12), Vector2(3, 8)], tip],
				["poly", [Vector2(5, 12), Vector2(7, 12), Vector2(9, 19), Vector2(3, 19)], RED if kind != "spear_gold" else GOLD],
			])
		"great_blade":
			return _wpn(18, 54, Vector2(9, 48), [
				["poly", [Vector2(5, 42), Vector2(4, 10), Vector2(9, 1), Vector2(14, 6), Vector2(13, 42)], INK],
				["poly", [Vector2(2, 42), Vector2(16, 42), Vector2(16, 44.5), Vector2(2, 44.5)], INK],
				["line", Vector2(9, 44.5), Vector2(9, 52), 2.2, INK],
				["line", Vector2(12.6, 8), Vector2(12.2, 40), 0.8, RED],
			])
		"twin_dagger":
			return _wpn(12, 28, Vector2(6, 22), [
				["poly", [Vector2(4.6, 18), Vector2(6, 1), Vector2(7.6, 18)], INK],
				["poly", [Vector2(2, 18), Vector2(10, 18), Vector2(10, 20), Vector2(2, 20)], INK],
				["line", Vector2(6, 20), Vector2(6, 26), 1.8, INK],
				["poly", [Vector2(5.5, 4), Vector2(6.4, 2), Vector2(7, 14)], VIOLET],
			])
		"dagger":
			return _wpn(10, 26, Vector2(5, 21), [
				["poly", [Vector2(3.8, 17), Vector2(5, 1.5), Vector2(6.4, 17)], INK],
				["poly", [Vector2(1.5, 17), Vector2(8.5, 17), Vector2(8.5, 19), Vector2(1.5, 19)], INK],
				["line", Vector2(5, 19), Vector2(5, 25), 1.6, INK],
			])
		"blood_blade":
			return _wpn(22, 60, Vector2(11, 53), [
				["poly", [Vector2(6, 46), Vector2(5, 14), Vector2(9, 4), Vector2(14, 0.5), Vector2(17, 8), Vector2(16, 46)], INK],
				["poly", [Vector2(15.4, 8), Vector2(17, 8), Vector2(16, 44), Vector2(14.6, 44)], RED],
				["poly", [Vector2(2, 46), Vector2(20, 46), Vector2(20, 49), Vector2(2, 49)], INK],
				["line", Vector2(11, 49), Vector2(11, 57), 2.4, INK],
				["poly", [Vector2(10, 57), Vector2(12, 57), Vector2(14, 60), Vector2(8, 60)], RED],
			])
		"broad_gold":
			return _wpn(16, 48, Vector2(8, 42), [
				["poly", [Vector2(5, 37), Vector2(5, 9), Vector2(9, 1), Vector2(13, 6), Vector2(12, 37)], INK],
				["poly", [Vector2(2, 37), Vector2(14, 37), Vector2(14, 39.5), Vector2(2, 39.5)], GOLD],
				["line", Vector2(8, 39.5), Vector2(8, 46), 2.0, INK],
			])
		_:
			# 도: 살짝 휜 넓은 칼날
			return _wpn(14, 42, Vector2(7, 37), [
				["poly", [Vector2(4.5, 33), Vector2(4.5, 9), Vector2(8, 1.5), Vector2(11, 6), Vector2(10, 33)], INK],
				["poly", [Vector2(2, 33), Vector2(12, 33), Vector2(12, 35), Vector2(2, 35)], INK],
				["line", Vector2(7, 35), Vector2(7, 41), 1.8, INK],
			])


## 무기 이미지: 항목 ["poly", 점들, 색] / ["line", 시작, 끝, 굵기, 색]
static func _wpn(w: int, h: int, pivot: Vector2, parts: Array) -> Dictionary:
	var k := float(ChibiArt.UPSCALE * InkArt.SS)
	var img := Image.create_empty(int(w * k), int(h * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed_v := 3
	for p in parts:
		seed_v += 3
		var kind: String = p[0]
		var pts := PackedVector2Array()
		var col: Color
		if kind == "line":
			var a: Vector2 = p[1]
			var b: Vector2 = p[2]
			pts = InkArt._line_poly(a * k, b * k, float(p[3]) * k)
			col = p[4]
		else:
			for v in p[1]:
				pts.append(Vector2(v) * k)
			col = p[2]
		InkArt._fill(img, InkArt._rough(pts, 0.7 * InkArt.SS, seed_v), col)
	return {"image": InkArt._downsample(img), "pivot": pivot}
