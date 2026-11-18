extends RefCounted
class_name MonsterArt
## 스테이지 확장(20스테이지)용 추가 몬스터 2등신 픽셀 아트.
## ChibiArt의 산적/복면 자객/산채 두목과 같은 틀(56×56 캔버스, 32×26 큰 네모 머리, 굵은 외곽선)을 쓰고,
## 종류마다 색, 머리 장식(삿갓, 투구, 민머리, 상투, 두건), 갑옷, 망토, 무기만 바꿔 찍는다.
## ChibiArt.monster(kind)가 SPECS에 있는 종류를 만나면 여기서 그림을 만든다. 결과 형식은 ChibiArt와 같다.


const STEEL := Color("#9aa4b6")
const STEEL_HI := Color("#c9d1de")
const STEEL_DK := Color("#5f6879")
const GOLD := Color("#ffcf4a")

## 종류별 그림 사양
## pal: 색(hair, hair_hi, main, light, dark, band, sash) / head: band·hood·bamboo·helmet·bald·topknot
## beard: 턱수염 / scar: 뺨 흉터 / mask: 아래 얼굴 복면 / armor: 금속 어깨·가슴판 / trim: 테두리 색
## cape: [망토 색, 그림자 색] / plume: 투구 술 색 / weapon: club·bow·spear·great_blade·twin_dagger·broad
const SPECS := {
	# 거한: 민머리에 수염, 큰 몽둥이
	"brute": {
		"pal": {"hair": Color("#3b2a1c"), "hair_hi": Color("#5a412b"), "main": Color("#6f7a3a"), "light": Color("#8e9a4e"), "dark": Color("#4c5527"), "band": Color("#c8323a"), "sash": Color("#3a2e2a")},
		"head": "bald", "beard": true, "scar": true, "weapon": "club",
	},
	# 삿갓 궁수: 커다란 삿갓, 녹회색 옷, 활
	"archer": {
		"pal": {"hair": Color("#2e2a24"), "hair_hi": Color("#4a4438"), "main": Color("#5d7a5a"), "light": Color("#7b9a76"), "dark": Color("#3e563c"), "band": Color("#c9a45c"), "sash": Color("#8a5a2e")},
		"head": "bamboo", "weapon": "bow",
	},
	# 철갑 수문위사: 쇠 투구와 가슴판, 긴 창
	"guard": {
		"pal": {"hair": Color("#2a2a33"), "hair_hi": Color("#40404c"), "main": Color("#4a5a7a"), "light": Color("#6577a0"), "dark": Color("#323e57"), "band": Color("#c8323a"), "sash": Color("#2a3142")},
		"head": "helmet", "armor": true, "plume": Color("#d4303a"), "weapon": "spear",
	},
	# 흑혈대 졸개: 검은 옷에 핏빛 머리띠, 도
	"blood_soldier": {
		"pal": {"hair": Color("#1e1a20"), "hair_hi": Color("#38303a"), "main": Color("#2e2a33"), "light": Color("#443e4b"), "dark": Color("#1c1a20"), "band": Color("#b3121f"), "sash": Color("#b3121f")},
		"head": "band", "scar": true, "weapon": "broad",
	},
	# 흑혈대 정예: 검붉은 갑주, 두건과 복면, 큰 칼
	"elite": {
		"pal": {"hair": Color("#2a1418"), "hair_hi": Color("#4a242a"), "main": Color("#5a1a22"), "light": Color("#7c2a33"), "dark": Color("#3a0f15"), "band": Color("#e0283a"), "sash": Color("#141015")},
		"head": "hood", "mask": true, "armor": true, "weapon": "great_blade",
	},
	# [보스] 흑혈대 혈위대장: 검붉은 투구와 갑옷, 긴 창
	"blood_guard": {
		"pal": {"hair": Color("#1e1a20"), "hair_hi": Color("#38303a"), "main": Color("#6a1a22"), "light": Color("#8c2a33"), "dark": Color("#420f15"), "band": Color("#e0283a"), "sash": Color("#141015")},
		"head": "helmet", "armor": true, "trim": Color("#e0283a"), "plume": Color("#141015"), "scar": true, "weapon": "spear",
	},
	# [보스] 무영객: 보랏빛 그림자 자객 수령, 쌍단검과 망토
	"shadow_lord": {
		"pal": {"hair": Color("#2a1f3d"), "hair_hi": Color("#47366a"), "main": Color("#3b2c5c"), "light": Color("#56428a"), "dark": Color("#22183a"), "band": Color("#b07cff"), "sash": Color("#8a5ad8")},
		"head": "hood", "mask": true, "trim": Color("#b07cff"), "cape": [Color("#4a2f7a"), Color("#2e1c52")], "weapon": "twin_dagger",
	},
	# [보스] 철벽 관주: 금장 투구와 갑옷, 푸른 망토, 금창
	"iron_general": {
		"pal": {"hair": Color("#2a2a33"), "hair_hi": Color("#40404c"), "main": Color("#2f4a8a"), "light": Color("#4766b0"), "dark": Color("#1f3366"), "band": GOLD, "sash": GOLD},
		"head": "helmet", "armor": true, "trim": GOLD, "beard": true, "plume": GOLD, "cape": [Color("#2a5bd0"), Color("#1a3a8c")], "weapon": "spear_gold",
	},
	# [보스] 흑혈대주 혈마도: 상투, 검붉은 갑주와 망토, 핏빛 대도
	"blood_lord": {
		"pal": {"hair": Color("#1a1216"), "hair_hi": Color("#3a2630"), "main": Color("#3a1016"), "light": Color("#5c1a24"), "dark": Color("#22080c"), "band": Color("#e0283a"), "sash": GOLD},
		"head": "topknot", "beard": true, "scar": true, "armor": true, "trim": Color("#e0283a"), "cape": [Color("#7a0f1a"), Color("#4a0810")], "weapon": "blood_blade",
	},
}


static func has_kind(kind: String) -> bool:
	return SPECS.has(kind)


## ChibiArt.monster()와 같은 형식으로 그림을 만든다.
static func build(kind: String) -> Dictionary:
	var spec: Dictionary = SPECS[kind]
	var normal := _canvas(spec, "normal")
	var ko := _canvas(spec, "ko")
	var weapon := _weapon(String(spec.get("weapon", "broad")))
	var W: int = normal.w
	# 왼쪽을 보도록 반전한다. 손 위치도 반전 (ChibiArt 몬스터와 같은 손 위치)
	var hand := Vector2(W - 1 - 42, 36)
	var wimg: Image = weapon["image"].duplicate()
	wimg.flip_x()
	var piv: Vector2 = weapon["pivot"]
	return {
		"body": ChibiArt._tex(InkArt.ink_image(normal.flipped())),
		"flash": ChibiArt._tex(ChibiArt._silhouette(normal.flipped())),
		"ko": ChibiArt._tex(InkArt.ink_image(ko.flipped(), false)),
		"weapon": ChibiArt._tex(InkArt.ink_image(wimg, false)),
		"weapon_pivot": Vector2(wimg.get_width() - 1 - piv.x, piv.y),
		"size": Vector2(W, normal.h),
		"hand": hand,
	}


static func _canvas(spec: Dictionary, eye_mode: String) -> ChibiArt.Canvas:
	var W := 56
	var H := 56
	var c := ChibiArt.Canvas.new(W, H)
	var hx := 11
	var hy := 6
	var pal: Dictionary = spec["pal"]
	var main: Color = pal["main"]
	var light: Color = pal["light"]
	var dark: Color = pal["dark"]
	var band: Color = pal["band"]
	var sash: Color = pal["sash"]
	var head: String = spec.get("head", "band")
	var trim = spec.get("trim", null)

	# 망토 (몸 뒤) 또는 머리띠 꼬리
	if spec.has("cape"):
		var cape: Array = spec["cape"]
		c.r(hx + 1, hy + 24, hx + 8, hy + 46, cape[0])
		c.r(hx - 2, hy + 32, hx + 3, hy + 47, cape[1])
		c.r(hx - 4, hy + 40, hx, hy + 47, cape[1].darkened(0.2))
	elif head == "band" or head == "hood" or head == "topknot":
		for i in 8:
			c.r(hx - 1 - i, hy + 6 + i / 3, hx + 1 - i, hy + 8 + i / 2, band if i % 3 != 2 else band.darkened(0.25))

	var by := hy + 27
	# 다리와 신발
	var leg := Color("#3a2e2a")
	var shoe := Color("#1f1915")
	if spec.get("armor", false):
		leg = STEEL_DK
		shoe = Color("#2a2e38")
	c.r(hx + 6, by + 13, hx + 12, by + 17, leg)
	c.r(hx + 5, by + 18, hx + 13, by + 20, shoe)
	c.r(hx + 19, by + 13, hx + 25, by + 17, leg)
	c.r(hx + 19, by + 18, hx + 27, by + 20, shoe)
	# 하의
	c.r(hx + 5, by + 8, hx + 26, by + 13, main)
	c.hl(hx + 5, hx + 26, by + 13, dark)
	c.v(hx + 15, by + 10, by + 13, dark)
	# 상의
	c.r(hx + 5, by, hx + 26, by + 8, main)
	c.r(hx + 5, by, hx + 7, by + 7, light)
	c.r(hx + 24, by + 1, hx + 26, by + 8, dark)
	c.line(hx + 11, by, hx + 15, by + 4, light)
	c.line(hx + 20, by, hx + 16, by + 4, light)
	if spec.get("armor", false):
		# 가슴판과 징
		var plate: Color = STEEL if trim == null else STEEL.lerp(trim, 0.25)
		c.r(hx + 9, by + 1, hx + 22, by + 6, plate)
		c.hl(hx + 9, hx + 22, by + 1, STEEL_HI)
		c.hl(hx + 9, hx + 22, by + 6, STEEL_DK)
		c.v(hx + 15, by + 2, by + 5, STEEL_DK)
		for x in [hx + 11, hx + 20]:
			c.p(x, by + 3, STEEL_HI)
	if trim != null:
		c.hl(hx + 5, hx + 26, by, trim)
		c.v(hx + 5, by + 1, by + 7, trim)
	# 허리띠 (매듭)
	c.r(hx + 5, by + 7, hx + 26, by + 8, sash)
	c.r(hx + 14, by + 6, hx + 17, by + 9, GOLD if sash != GOLD else Color("#e0283a"))
	c.r(hx + 21, by + 9, hx + 23, by + 12, sash.darkened(0.2))
	# 팔
	c.r(hx + 1, by + 2, hx + 6, by + 6, dark)
	c.r(hx - 1, by + 3, hx + 1, by + 6, ChibiArt.SKIN)
	c.r(hx + 25, by + 2, hx + 29, by + 6, light)
	c.r(hx + 29, by + 3, hx + 32, by + 6, ChibiArt.SKIN)
	if spec.get("armor", false):
		# 어깨 갑옷
		c.rr(hx + 1, by - 1, hx + 8, by + 3, STEEL, 1)
		c.hl(hx + 2, hx + 7, by - 1, STEEL_HI)
		c.rr(hx + 23, by - 1, hx + 30, by + 3, STEEL, 1)
		c.hl(hx + 24, hx + 29, by - 1, STEEL_HI)
		if trim != null:
			c.hl(hx + 1, hx + 8, by + 3, trim)
			c.hl(hx + 23, hx + 30, by + 3, trim)

	# 머리
	ChibiArt._head_base(c, hx, hy)
	var hair: Color = pal["hair"]
	var hair_hi: Color = pal["hair_hi"]
	match head:
		"hood":
			# 두건이 머리를 덮는다
			c.rr(hx, hy - 1, hx + 31, hy + 10, hair, 3)
			c.r(hx, hy + 8, hx + 4, hy + 25, hair)
			c.r(hx + 27, hy + 8, hx + 31, hy + 25, hair)
			c.hl(hx + 4, hx + 27, hy + 1, hair_hi)
			# 이마 띠
			c.r(hx + 4, hy + 7, hx + 27, hy + 8, band)
		"bamboo":
			_hair_short(c, hx, hy, hair, hair_hi)
			_bamboo_hat(c, hx, hy)
		"helmet":
			_helmet(c, hx, hy, trim, spec.get("plume", Color("#d4303a")))
		"bald":
			# 민머리: 정수리 광택과 옆머리 조금
			c.r(hx, hy + 8, hx + 2, hy + 14, hair)
			c.r(hx + 29, hy + 8, hx + 31, hy + 12, hair)
			c.r(hx + 9, hy + 2, hx + 14, hy + 3, Color.WHITE.lerp(ChibiArt.SKIN, 0.5))
			c.hl(hx + 6, hx + 25, hy + 9, ChibiArt.SKIN_SHADE)
		"topknot":
			_hair_short(c, hx, hy, hair, hair_hi)
			# 상투와 비녀
			c.rr(hx + 12, hy - 6, hx + 20, hy, hair, 2)
			c.hl(hx + 13, hx + 19, hy - 5, hair_hi)
			c.r(hx + 8, hy - 3, hx + 24, hy - 3, GOLD)
			c.r(hx, hy + 4, hx + 31, hy + 5, band)
		_:
			_hair_short(c, hx, hy, hair, hair_hi)
			c.r(hx, hy + 4, hx + 31, hy + 6, band)
			c.hl(hx + 1, hx + 30, hy + 4, band.lightened(0.25))
	if spec.get("mask", false):
		c.r(hx + 2, hy + 18, hx + 29, hy + 25, Color("#1e1c27"))
		c.hl(hx + 4, hx + 27, hy + 18, hair_hi)
		c.r(hx + 15, hy + 21, hx + 16, hy + 21, band)
	elif spec.get("beard", false):
		c.r(hx + 9, hy + 22, hx + 24, hy + 26, hair)
		c.hl(hx + 11, hx + 22, hy + 27, hair)
		c.hl(hx + 12, hx + 21, hy + 21, hair)
	else:
		for x in range(hx + 10, hx + 24, 2):
			c.p(x, hy + 22, Color("#7a4a2e"))
		c.hl(hx + 17, hx + 18, hy + 20, Color("#c4685a"))
	if spec.get("scar", false) and not spec.get("mask", false):
		c.line(hx + 27, hy + 14, hx + 26, hy + 18, Color("#c4485a"))
	ChibiArt._eyes(c, hx, hy, "fierce" if eye_mode == "normal" and head != "bamboo" else ("normal" if eye_mode == "normal" else "ko"))
	c.outline(ChibiArt.OUTLINE, 1)
	return c


## 짧은 머리와 앞머리 (ChibiArt 산적과 같은 모양)
static func _hair_short(c: ChibiArt.Canvas, hx: int, hy: int, hair: Color, hair_hi: Color) -> void:
	c.rr(hx, hy - 1, hx + 31, hy + 7, hair, 3)
	c.r(hx, hy + 6, hx + 4, hy + 19, hair)
	c.r(hx + 28, hy + 6, hx + 31, hy + 13, hair)
	var bangs := [9, 8, 10, 8, 9, 8, 10, 8, 9, 8, 9, 10, 8]
	for i in bangs.size():
		var x0 := hx + 5 + i * 2
		c.r(x0, hy + 7, x0 + 1, hy + bangs[i], hair)
	c.hl(hx + 4, hx + 26, hy + 1, hair_hi)


## 삿갓: 넓은 챙과 뾰족한 꼭대기, 대나무 결
static func _bamboo_hat(c: ChibiArt.Canvas, hx: int, hy: int) -> void:
	var straw := Color("#d2ae62")
	var shade := Color("#9c7a3a")
	var hi := Color("#ecd08e")
	var cx := hx + 16
	# 꼭대기에서 챙까지 넓어지는 원뿔
	for i in 9:
		var y := hy - 5 + i
		var half := 2 + i * 2
		c.r(cx - half, y, cx + half, y, straw)
		c.p(cx - half, y, shade)
	# 챙
	c.r(hx - 7, hy + 4, hx + 38, hy + 5, straw)
	c.hl(hx - 7, hx + 38, hy + 6, shade)
	c.hl(hx - 5, hx + 36, hy + 4, hi)
	# 대나무 결
	for k in [-8, -3, 3, 8]:
		c.line(cx, hy - 4, cx + k * 2, hy + 4, shade)
	# 턱끈
	c.v(hx + 3, hy + 7, hy + 22, Color("#6b4426"))
	c.v(hx + 28, hy + 7, hy + 22, Color("#6b4426"))


## 쇠 투구: 볼가리개와 술 장식. trim이 있으면 금장 테두리
static func _helmet(c: ChibiArt.Canvas, hx: int, hy: int, trim, plume: Color) -> void:
	var metal := STEEL
	c.rr(hx - 1, hy - 2, hx + 32, hy + 9, metal, 3)
	c.hl(hx + 3, hx + 28, hy - 1, STEEL_HI)
	c.r(hx + 3, hy + 1, hx + 6, hy + 5, STEEL_HI)
	c.hl(hx - 1, hx + 32, hy + 9, STEEL_DK)
	# 볼가리개
	c.r(hx - 1, hy + 9, hx + 3, hy + 21, metal)
	c.v(hx + 3, hy + 9, hy + 21, STEEL_DK)
	c.r(hx + 28, hy + 9, hx + 32, hy + 15, metal)
	# 이마 챙
	var rim: Color = trim if trim != null else STEEL_DK
	c.r(hx - 2, hy + 8, hx + 33, hy + 9, rim)
	c.v(hx + 15, hy - 1, hy + 7, rim)
	# 꼭대기 술
	c.r(hx + 13, hy - 5, hx + 18, hy - 3, plume)
	c.r(hx + 15, hy - 6, hx + 16, hy - 6, plume.lightened(0.3))
	c.r(hx + 5, hy - 4, hx + 12, hy - 3, plume.darkened(0.2))


# ---- 무기 (모두 오른쪽을 보고 손잡이가 아래인 방향으로 그린다) ----

static func _weapon(kind: String) -> Dictionary:
	match kind:
		"club":
			return _club()
		"bow":
			return _bow()
		"spear":
			return _spear(false)
		"spear_gold":
			return _spear(true)
		"great_blade":
			return _great_blade(Color("#b8c0d0"), Color("#e0283a"))
		"blood_blade":
			return _great_blade(Color("#8a1a24"), GOLD)
		"twin_dagger":
			return _twin_dagger()
	return _broad()


## 넓은 칼 (흑혈대 졸개)
static func _broad() -> Dictionary:
	var c := ChibiArt.Canvas.new(14, 40)
	var blade := Color("#c9d0de")
	c.r(3, 4, 10, 27, blade)
	c.r(5, 1, 10, 3, blade)
	c.v(3, 6, 27, Color("#8a94aa"))
	c.v(9, 3, 26, Color("#e8ecf4"))
	c.r(1, 28, 12, 30, Color("#b3121f"))
	c.r(5, 31, 8, 37, Color("#2a1a1a"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(6, 34)}


## 징 박힌 나무 몽둥이 (거한)
static func _club() -> Dictionary:
	var c := ChibiArt.Canvas.new(16, 40)
	var wood := Color("#8a5a2e")
	var wood_dk := Color("#5e3a1a")
	c.rr(2, 1, 13, 24, wood, 3)
	c.v(10, 3, 22, Color("#a87440"))
	c.v(4, 3, 22, wood_dk)
	for y in [5, 11, 17]:
		c.p(1, y, STEEL_HI); c.p(14, y + 3, STEEL_HI)
		c.r(6, y, 7, y + 1, STEEL)
	c.r(5, 25, 10, 37, wood_dk)
	c.hl(5, 10, 29, Color("#3a2414"))
	c.hl(5, 10, 33, Color("#3a2414"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(7, 33)}


## 활 (삿갓 궁수). 활대는 휘고 시위는 곧다
static func _bow() -> Dictionary:
	var c := ChibiArt.Canvas.new(14, 44)
	var wood := Color("#7a4a26")
	var wood_hi := Color("#a8703c")
	var pts := [Vector2i(4, 1), Vector2i(7, 6), Vector2i(9, 13), Vector2i(10, 22), Vector2i(9, 31), Vector2i(7, 38), Vector2i(4, 42)]
	for i in pts.size() - 1:
		c.line(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, wood, 2)
	c.line(7, 8, 9, 15, wood_hi)
	# 시위
	c.v(3, 2, 41, Color("#efe6d0"))
	# 손잡이 감개
	c.r(9, 19, 11, 25, Color("#c8323a"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(10, 22)}


## 긴 창 (수문위사). gold면 관주용 금창
static func _spear(gold: bool) -> Dictionary:
	var c := ChibiArt.Canvas.new(10, 64)
	var tip := GOLD if gold else STEEL_HI
	# 창날
	c.r(3, 3, 6, 12, tip)
	c.r(4, 0, 5, 2, tip)
	c.v(3, 4, 12, STEEL_DK if not gold else Color("#c8962a"))
	# 술
	c.r(1, 13, 8, 15, GOLD if not gold else Color("#e0283a"))
	c.r(2, 16, 7, 19, Color("#d4303a") if not gold else Color("#b01c2a"))
	# 자루
	c.r(4, 16, 5, 62, Color("#6b4426"))
	c.v(5, 16, 62, Color("#8c5c34"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(4, 44)}


## 큰 칼 (흑혈대 정예, 혈마도). edge는 날 끝 색
static func _great_blade(blade: Color, edge: Color) -> Dictionary:
	var c := ChibiArt.Canvas.new(18, 50)
	c.r(4, 5, 13, 34, blade)
	c.r(7, 1, 13, 4, blade)
	c.p(12, 0, blade)
	c.v(13, 2, 34, edge)
	c.v(4, 6, 34, blade.darkened(0.3))
	c.r(6, 10, 8, 28, blade.lightened(0.2))
	c.r(1, 35, 16, 37, GOLD)
	c.r(6, 38, 10, 47, Color("#2a1418"))
	c.hl(6, 10, 41, Color("#5a2a30"))
	c.hl(6, 10, 44, Color("#5a2a30"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(8, 43)}


## 쌍단검 (무영객). 두 자루를 엇갈려 쥔다
static func _twin_dagger() -> Dictionary:
	var c := ChibiArt.Canvas.new(16, 26)
	var blade := Color("#d8c8ff")
	for off in [0, 7]:
		c.r(2 + off, 2, 5 + off, 14, blade)
		c.v(2 + off, 3, 14, Color("#8a7ab8"))
		c.r(3 + off, 0, 4 + off, 1, blade)
		c.r(0 + off, 15, 7 + off, 16, Color("#b07cff"))
		c.r(2 + off, 17, 5 + off, 22, Color("#2a1f3d"))
	c.outline(ChibiArt.OUTLINE, 1)
	return {"image": c.img, "pivot": Vector2(7, 20)}
