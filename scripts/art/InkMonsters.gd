extends RefCounted
class_name InkMonsters
## 몬스터·보스 먹 실루엣 그림 (주인공 InkArt와 같은 붓 실루엣 스타일). 사람이 아닌 요괴·괴수 형태다.
## - 일반: 늑대 요괴, 도깨비, 여우 요괴, 거미 요괴, 두꺼비 요괴, 박쥐 날개 귀신, 멧돼지 괴수
## - 보스: 도깨비 대왕, 우두 귀졸, 구미호, 돌 거인, 혈귀 마왕
## - 몸 전체를 먹색 실루엣 하나로 그리고, 붉은 눈과 작은 포인트(엄니, 꼬리 끝, 금빛 무늬 등)만 색을 쓴다.
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
const BONE := Color("#e6dfcc")


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
			# 늑대 요괴: 구부정한 두 발 짐승, 긴 주둥이, 뾰족 귀, 등 갈기, 꼬리, 손톱
			return {"weapon": "claw", "hand": Vector2(138, 112), "shapes": _beast_legs() + [
				["poly", [Vector2(78, 132), [Vector2(50, 132), Vector2(36, 110)], [Vector2(54, 146), Vector2(82, 142)]]],
				["poly", [Vector2(78, 90), Vector2(116, 84), Vector2(124, 110), Vector2(120, 142), Vector2(80, 142), Vector2(72, 116)]],
				["poly", [Vector2(78, 94), Vector2(66, 82), Vector2(84, 86), Vector2(78, 70), Vector2(94, 80), Vector2(96, 66), Vector2(106, 80)]],
				["circle", Vector2(110, 76), 12.0],
				["poly", [Vector2(104, 70), Vector2(118, 64), Vector2(148, 78), Vector2(146, 84), Vector2(122, 90), Vector2(106, 90)]],
				["poly", [Vector2(100, 68), Vector2(98, 46), Vector2(110, 62)]],
				["poly", [Vector2(110, 64), Vector2(118, 44), Vector2(120, 66)]],
				["accent", BONE, ["poly", [Vector2(128, 86), Vector2(132, 94), Vector2(135, 86)]]],
				["eye", Vector2(122, 74), 8.0],
			] + _arms(Vector2(138, 112))}
		"brute":
			# 도깨비: 외뿔, 산발 머리, 불룩한 배, 짧고 굵은 다리, 도깨비 방망이
			return {"weapon": "spiked_club", "hand": Vector2(152, 114), "shapes": _ogre(false) + [
				["eye", Vector2(114, 80), 9.0],
			]}
		"masked":
			# 여우 요괴: 낮게 웅크린 몸, 큰 귀, 긴 주둥이, 위로 치솟은 꼬리(끝이 흰), 손톱
			return {"weapon": "claw", "hand": Vector2(140, 114), "shapes": _crouch_legs() + _fox_tails(1) + [
				["poly", [Vector2(90, 90), Vector2(118, 90), Vector2(122, 132), Vector2(84, 134)]],
				["circle", Vector2(108, 78), 11.0],
				["poly", [Vector2(108, 72), Vector2(142, 82), Vector2(112, 88)]],
				["poly", [Vector2(98, 72), Vector2(94, 46), Vector2(108, 68)]],
				["poly", [Vector2(108, 68), Vector2(114, 44), Vector2(120, 70)]],
				["eye", Vector2(118, 76), 9.0],
			] + _arms(Vector2(140, 114))}
		"archer":
			# 거미 요괴: 둥근 배, 여덟 다리, 등에 붉은 무늬, 여러 개의 눈, 먹물 침을 쏜다
			return {"weapon": "none", "hand": Vector2(144, 140), "shapes": [
				["line", Vector2(126, 134), Vector2(152, 100), 5.0], ["line", Vector2(152, 100), Vector2(176, 222), 4.0],
				["line", Vector2(122, 140), Vector2(142, 112), 5.0], ["line", Vector2(142, 112), Vector2(154, 222), 4.0],
				["line", Vector2(112, 140), Vector2(120, 106), 5.0], ["line", Vector2(120, 106), Vector2(118, 222), 4.0],
				["line", Vector2(104, 142), Vector2(84, 100), 5.0], ["line", Vector2(84, 100), Vector2(70, 222), 4.0],
				["line", Vector2(98, 140), Vector2(62, 96), 5.0], ["line", Vector2(62, 96), Vector2(40, 222), 4.0],
				["circle", Vector2(86, 118), 30.0],
				["circle", Vector2(72, 108), 22.0],
				["circle", Vector2(124, 138), 15.0],
				["poly", [Vector2(134, 146), Vector2(146, 150), Vector2(136, 156)]],
				["accent", RED, ["poly", [Vector2(80, 100), Vector2(88, 112), Vector2(80, 124), Vector2(72, 112)]]],
				["eye", Vector2(132, 134), 6.0],
				["eye", Vector2(126, 130), 5.0],
				["eye", Vector2(134, 140), 4.0],
			]}
		"guard":
			# 두꺼비 요괴: 납작하고 거대한 몸, 머리 위 툭 튀어나온 두 눈, 넓은 입
			return {"weapon": "none", "hand": Vector2(156, 148), "shapes": [
				["poly", [Vector2(54, 202), Vector2(58, 152), Vector2(84, 120), Vector2(122, 112), Vector2(152, 126), Vector2(164, 160), Vector2(156, 202)]],
				["circle", Vector2(118, 114), 13.0],
				["circle", Vector2(144, 120), 11.0],
				["poly", [Vector2(58, 196), Vector2(36, 222), Vector2(94, 222), Vector2(84, 194)]],
				["poly", [Vector2(128, 196), Vector2(122, 222), Vector2(156, 222), Vector2(152, 190)]],
				["circle", Vector2(80, 150), 6.0], ["circle", Vector2(98, 136), 5.0], ["circle", Vector2(70, 172), 5.0],
				["accent", RED, ["line", Vector2(112, 152), Vector2(164, 148), 3.0]],
				["eye", Vector2(120, 110), 9.0],
				["eye", Vector2(146, 116), 8.0],
			]}
		"blood_soldier":
			# 박쥐 날개 귀신: 굽은 뿔, 박쥐 날개, 가시 꼬리, 붉은 삼지창
			return {"weapon": "trident", "hand": Vector2(136, 106), "shapes": _beast_legs() + [
				["poly", [Vector2(90, 92), [Vector2(60, 58), Vector2(38, 68)], Vector2(52, 86), Vector2(42, 104), Vector2(60, 104), Vector2(62, 122), [Vector2(76, 106), Vector2(88, 110)]]],
				["line", Vector2(86, 138), Vector2(58, 162), 3.0],
				["poly", [Vector2(60, 158), Vector2(44, 158), Vector2(52, 172)]],
				["poly", [Vector2(86, 88), Vector2(116, 88), Vector2(118, 140), Vector2(84, 140)]],
				["circle", Vector2(102, 72), 11.0],
				["poly", [Vector2(94, 66), [Vector2(84, 54), Vector2(88, 40)], Vector2(98, 62)]],
				["poly", [Vector2(106, 62), [Vector2(114, 48), Vector2(124, 44)], Vector2(112, 68)]],
				["eye", Vector2(108, 72), 8.0],
			] + _arms(Vector2(136, 106))}
		"elite":
			# 멧돼지 괴수: 육중한 구부정 몸, 등 털 가시, 흰 엄니, 손톱
			return {"weapon": "claw", "hand": Vector2(142, 116), "shapes": _legs(4, 5) + [
				["poly", [Vector2(68, 98), Vector2(120, 86), Vector2(134, 112), Vector2(128, 148), Vector2(76, 148), Vector2(62, 122)]],
				["poly", [Vector2(70, 100), Vector2(58, 82), Vector2(76, 90), Vector2(72, 70), Vector2(90, 84), Vector2(90, 64), Vector2(104, 82)]],
				["circle", Vector2(118, 86), 14.0],
				["poly", [Vector2(108, 80), Vector2(130, 72), Vector2(150, 86), Vector2(150, 98), Vector2(130, 102), Vector2(112, 100)]],
				["poly", [Vector2(108, 74), Vector2(102, 58), Vector2(118, 70)]],
				["accent", BONE, ["poly", [Vector2(140, 98), Vector2(154, 82), Vector2(146, 100)]]],
				["eye", Vector2(128, 82), 9.0],
			] + _arms(Vector2(142, 116), 4.0)}
		"chief":
			# [보스] 도깨비 대왕: 두 뿔, 털 갈기, 금 허리띠, 금테 방망이
			return {"weapon": "club_gold", "hand": Vector2(152, 114), "shapes": _ogre(true) + [
				["accent", GOLD, ["poly", [Vector2(70, 138), Vector2(138, 138), Vector2(138, 146), Vector2(70, 146)]]],
				["eye", Vector2(114, 80), 10.0],
			]}
		"blood_guard":
			# [보스] 우두 귀졸: 소머리, 크게 휜 뿔, 코뚜레, 근육질 몸, 붉은 도끼
			return {"weapon": "axe_red", "hand": Vector2(140, 104), "shapes": _legs(4, 6) + [
				["poly", [Vector2(70, 84), Vector2(134, 84), Vector2(126, 148), Vector2(78, 148)]],
				["circle", Vector2(76, 92), 13.0], ["circle", Vector2(128, 92), 13.0],
				["circle", Vector2(104, 70), 13.0],
				["poly", [Vector2(108, 64), Vector2(132, 72), Vector2(130, 88), Vector2(106, 88)]],
				["poly", [Vector2(94, 62), [Vector2(70, 58), Vector2(60, 34)], Vector2(78, 50), Vector2(98, 56)]],
				["poly", [Vector2(110, 58), [Vector2(130, 48), Vector2(140, 26)], Vector2(138, 50), Vector2(116, 66)]],
				["accent", GOLD, ["circle", Vector2(132, 86), 3.0]],
				["accent", RED, ["poly", [Vector2(76, 124), Vector2(128, 124), Vector2(128, 130), Vector2(76, 130)]]],
				["eye", Vector2(114, 68), 9.0],
			] + _arms(Vector2(140, 104), 5.0)}
		"shadow_lord":
			# [보스] 구미호: 부채처럼 펼친 아홉 꼬리(끝이 보랏빛), 여우 머리, 보랏빛 여우불
			return {"weapon": "foxfire", "hand": Vector2(142, 112), "shapes": _crouch_legs() + _fox_tails(7) + [
				["poly", [Vector2(90, 88), Vector2(118, 88), Vector2(122, 132), Vector2(84, 134)]],
				["circle", Vector2(108, 76), 12.0],
				["poly", [Vector2(108, 70), Vector2(144, 80), Vector2(112, 88)]],
				["poly", [Vector2(98, 70), Vector2(92, 42), Vector2(108, 66)]],
				["poly", [Vector2(108, 66), Vector2(114, 40), Vector2(122, 68)]],
				["eye", Vector2(118, 74), 10.0],
			] + _arms(Vector2(142, 112))}
		"iron_general":
			# [보스] 돌 거인: 바위 덩어리 몸, 박힌 작은 머리, 거대한 주먹, 금빛 부적 무늬
			return {"weapon": "none", "hand": Vector2(156, 122), "shapes": [
				["poly", [Vector2(76, 156), Vector2(102, 156), Vector2(102, 222), Vector2(68, 222)]],
				["poly", [Vector2(110, 156), Vector2(136, 156), Vector2(146, 222), Vector2(112, 222)]],
				["poly", [Vector2(66, 90), Vector2(138, 86), Vector2(148, 128), Vector2(134, 164), Vector2(72, 164), Vector2(58, 126)]],
				["circle", Vector2(66, 96), 17.0], ["circle", Vector2(138, 94), 16.0],
				["poly", [Vector2(92, 62), Vector2(118, 58), Vector2(124, 86), Vector2(90, 88)]],
				["poly", [Vector2(130, 92), Vector2(158, 110), Vector2(150, 128), Vector2(124, 112)]],
				["circle", Vector2(156, 122), 13.0],
				["poly", [Vector2(70, 100), Vector2(50, 130), Vector2(62, 140), Vector2(80, 112)]],
				["accent", GOLD, ["line", Vector2(94, 112), Vector2(104, 134), 3.0]],
				["accent", GOLD, ["line", Vector2(104, 134), Vector2(116, 112), 3.0]],
				["accent", GOLD, ["line", Vector2(98, 146), Vector2(114, 146), 3.0]],
				["eye", Vector2(110, 72), 10.0],
			]}
		"blood_lord":
			# [보스] 혈귀 마왕: 크게 펼친 박쥐 날개, 뒤로 휜 큰 뿔, 붉은 허리띠, 피 묻은 손톱
			return {"weapon": "blood_claw", "hand": Vector2(142, 108), "shapes": _beast_legs(6) + [
				["poly", [Vector2(86, 86), [Vector2(44, 34), Vector2(28, 52)], Vector2(42, 80), Vector2(26, 110), Vector2(48, 108), Vector2(44, 146), [Vector2(70, 118), Vector2(90, 110)]]],
				["poly", [Vector2(74, 82), Vector2(130, 82), Vector2(126, 146), Vector2(78, 146)]],
				["circle", Vector2(76, 90), 11.0], ["circle", Vector2(128, 90), 11.0],
				["circle", Vector2(104, 64), 13.0],
				["poly", [Vector2(96, 56), [Vector2(78, 42), Vector2(68, 20)], Vector2(88, 40), Vector2(102, 52)]],
				["poly", [Vector2(110, 54), [Vector2(122, 36), Vector2(118, 16)], Vector2(126, 40), Vector2(116, 60)]],
				["poly", [Vector2(108, 70), Vector2(118, 72), Vector2(110, 82)]],
				["accent", RED, ["poly", [Vector2(78, 122), Vector2(126, 122), Vector2(126, 130), Vector2(78, 130)]]],
				["eye", Vector2(112, 62), 11.0],
			] + _arms(Vector2(142, 108), 5.0)}
	return {}


## 짐승 다리 (뒤로 꺾인 발목)
static func _beast_legs(thick: float = 0.0) -> Array:
	return [
		["poly", [Vector2(82 - thick, 136), Vector2(100, 136), Vector2(102, 168), Vector2(92, 190), Vector2(98, 222), Vector2(76 - thick, 222), Vector2(80, 188), Vector2(84 - thick, 168)]],
		["poly", [Vector2(104, 136), Vector2(120 + thick, 136), Vector2(128 + thick, 170), Vector2(120, 192), Vector2(134 + thick, 222), Vector2(112, 222), Vector2(106, 192), Vector2(108, 168)]],
	]


## 웅크린 다리 (여우·구미호)
static func _crouch_legs() -> Array:
	return [
		["poly", [Vector2(84, 128), Vector2(100, 128), Vector2(86, 168), Vector2(62, 222), Vector2(46, 220), Vector2(70, 166)]],
		["poly", [Vector2(104, 128), Vector2(120, 128), Vector2(142, 170), Vector2(152, 222), Vector2(136, 222), Vector2(122, 172)]],
	]


## 여우 꼬리 n개를 부채꼴로. 끝은 한지색(1개) 또는 보랏빛(여러 개)
static func _fox_tails(n: int) -> Array:
	var out: Array = []
	var base := Vector2(98, 126)
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var ang := -PI * 0.9 if n == 1 else lerpf(-PI * 1.04, -PI * 0.36, t)
		var len := 58.0 if n == 1 else 56.0 + 18.0 * sin(t * PI)
		var fat := 22.0 if n == 1 else 9.0
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := dir.orthogonal()
		var tip := base + dir * len + nrm * (12.0 if n == 1 else 7.0)
		var mid := base + dir * len * 0.5
		# 부풀었다가 끝이 휘는 붓꼬리 (여러 개면 가늘게 갈라져 불꽃처럼)
		out.append(["poly", [base + nrm * 6.0, [mid + nrm * fat, tip + nrm * 3.0], tip + dir * 8.0, [mid - nrm * fat * 0.5, base - nrm * 6.0]]])
		out.append(["accent", BONE if n == 1 else VIOLET, ["circle", tip + dir * 3.0, 6.0 if n == 1 else 4.5]])
	return out


## 도깨비 몸 (king: 두 뿔 + 털 갈기)
static func _ogre(king: bool) -> Array:
	var out: Array = [
		["poly", [Vector2(80, 158), Vector2(102, 158), Vector2(100, 222), Vector2(68, 222)]],
		["poly", [Vector2(108, 158), Vector2(130, 158), Vector2(142, 222), Vector2(110, 222)]],
		["circle", Vector2(104, 132), 34.0],
		["poly", [Vector2(70, 96), Vector2(138, 96), Vector2(142, 132), Vector2(66, 132)]],
		["circle", Vector2(106, 82), 14.0],
		["poly", [Vector2(90, 78), Vector2(82, 62), Vector2(96, 70), Vector2(94, 56), Vector2(104, 68)]],
		["poly", [Vector2(128, 98), Vector2(156, 106), Vector2(152, 122), Vector2(122, 112)]],
		["circle", Vector2(152, 114), 8.0],
		["poly", [Vector2(76, 100), Vector2(54, 130), Vector2(64, 140), Vector2(86, 114)]],
		["accent", BONE, ["poly", [Vector2(112, 90), Vector2(116, 98), Vector2(119, 90)]]],
	]
	if king:
		out.append(["poly", [Vector2(98, 72), [Vector2(90, 56), Vector2(94, 40)], Vector2(104, 68)]])
		out.append(["poly", [Vector2(110, 70), [Vector2(120, 54), Vector2(130, 46)], Vector2(116, 76)]])
		out.append(["poly", [Vector2(68, 98), Vector2(70, 80), Vector2(82, 90), Vector2(86, 74), Vector2(96, 92), Vector2(120, 92), Vector2(126, 76), Vector2(132, 92), Vector2(142, 84), Vector2(140, 102)]])
	else:
		out.append(["poly", [Vector2(102, 70), Vector2(108, 44), Vector2(114, 70)]])
	return out


# ---- 무기 (그림 픽셀 좌표, 위로 세운 모양, pivot = 쥔 곳) ----

static func _weapon(kind: String) -> Dictionary:
	match kind:
		"claw", "blood_claw":
			# 손톱 세 개 (위로 휜 갈고리)
			var tip := RED if kind == "blood_claw" else INK
			var s := 1.4 if kind == "blood_claw" else 1.0
			var parts: Array = []
			for i in 3:
				var x := (3.0 + i * 4.0) * s
				parts.append(["poly", [Vector2(x, 16 * s), Vector2(x + 1.5 * s, 4 * s + i * s), Vector2(x + 4 * s, 0.5 * s + i * s), Vector2(x + 2.5 * s, 6 * s + i * s), Vector2(x + 2.4 * s, 16 * s)], INK])
				parts.append(["poly", [Vector2(x + 1.5 * s, 4 * s + i * s), Vector2(x + 4 * s, 0.5 * s + i * s), Vector2(x + 2.6 * s, 5 * s + i * s)], tip])
			return _wpn(int(16 * s), int(20 * s), Vector2(7 * s, 16 * s), parts)
		"spiked_club", "club_gold":
			# 도깨비 방망이: 위가 굵은 몽둥이에 혹 같은 가시
			var band := GOLD if kind == "club_gold" else INK
			return _wpn(18, 46, Vector2(9, 42), [
				["poly", [Vector2(7.5, 45), Vector2(5, 16), Vector2(5, 5), Vector2(9, 1), Vector2(13, 5), Vector2(13, 16), Vector2(10.5, 45)], INK],
				["circle_pts", Vector2(4, 8), 2.0, INK], ["circle_pts", Vector2(14, 6), 2.0, INK], ["circle_pts", Vector2(4, 16), 1.8, INK],
				["circle_pts", Vector2(14, 14), 1.8, INK], ["circle_pts", Vector2(9, 11), 1.6, INK],
				["poly", [Vector2(5.4, 22), Vector2(12.6, 22), Vector2(12.3, 24.5), Vector2(5.7, 24.5)], band],
			])
		"trident":
			return _wpn(14, 60, Vector2(7, 40), [
				["line", Vector2(7, 12), Vector2(7, 59), 1.8, INK],
				["line", Vector2(2.5, 12), Vector2(11.5, 12), 1.8, INK],
				["poly", [Vector2(1.6, 12), Vector2(2.5, 2), Vector2(3.6, 12)], RED],
				["poly", [Vector2(6, 12), Vector2(7, 0), Vector2(8, 12)], RED],
				["poly", [Vector2(10.4, 12), Vector2(11.5, 2), Vector2(12.4, 12)], RED],
			])
		"axe_red":
			return _wpn(24, 60, Vector2(12, 50), [
				["line", Vector2(12, 4), Vector2(12, 59), 2.2, INK],
				["poly", [Vector2(12, 8), Vector2(19, 6), Vector2(22.5, 11), Vector2(23.5, 18), Vector2(22.5, 25), Vector2(19, 30), Vector2(12, 28)], INK],
				["poly", [Vector2(12, 12), Vector2(6, 12), Vector2(3.5, 15), Vector2(3, 18), Vector2(3.5, 21), Vector2(6, 24), Vector2(12, 24)], INK],
				["poly", [Vector2(21, 8), Vector2(23.5, 18), Vector2(21, 28), Vector2(20, 18)], RED],
			])
		"foxfire":
			# 보랏빛 여우불을 쥔 손톱
			return _wpn(18, 24, Vector2(9, 20), [
				["poly", [Vector2(9, 1), Vector2(13, 6), Vector2(15, 11), Vector2(13, 16), Vector2(9, 19), Vector2(5, 16), Vector2(3, 11), Vector2(5, 6)], Color(VIOLET, 0.85)],
				["poly", [Vector2(9, 6), Vector2(11.5, 10), Vector2(11, 14), Vector2(9, 16), Vector2(7, 14), Vector2(6.5, 10)], Color("#d9ccff")],
				["poly", [Vector2(5, 22), Vector2(6, 15), Vector2(7.5, 22)], INK],
				["poly", [Vector2(10.5, 22), Vector2(12, 15), Vector2(13, 22)], INK],
			])
		_:
			# 무기 없음 (몸으로 들이받거나 문다)
			return _wpn(2, 2, Vector2(1, 1), [])


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
		if kind == "circle_pts":
			var cc: Vector2 = p[1]
			pts = InkArt._circle(cc * k, float(p[2]) * k)
			col = p[3]
		elif kind == "line":
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
