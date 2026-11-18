extends RefCounted
class_name ChibiArt
## 2등신 캐릭터 픽셀 아트 생성기 (디자인 시안 design-chibi-hd, design-weapons-v1 반영).
## - 큰 머리, 작은 몸통, 각진 네모 형태, 굵은 외곽선, 작고 단순한 눈, 큰 무기.
## - 이미지 파일 없이 코드로 픽셀을 찍어 텍스처를 만든다. 결과는 캐시해 한 번만 만든다.
## - 모든 그림은 오른쪽을 보는 방향으로 그리고, 몬스터는 좌우 반전해 왼쪽을 보게 한다.
## - 픽셀을 UPSCALE배로 키운 텍스처를 만든다. 그릴 때 선형 필터 + 축소 배율로 그리면
##   정수 배율이 아니어도 픽셀 경계가 고르게 보인다.

const UPSCALE := 4
## 그림 1픽셀이 화면에서 차지하는 크기 (전체 크기를 이전 시안보다 약 25% 줄인 값)
const ART_SCALE := 1.6

const OUTLINE := Color("#1a1022")
const SKIN := Color("#ffd9b0")
const SKIN_SHADE := Color("#f0b98e")
const BLUSH := Color("#ff9a9a")
const EYE := Color("#2a2140")
const EYE_HI := Color("#8f86b8")
const WHITE := Color("#f4f1ff")

## 무공 계열별 복장 (검: 푸른 도복, 권: 주황 승복, 술: 보라 도복)
const OUTFITS := {
	"sword": {"main": Color("#3f78d8"), "light": Color("#69a0f0"), "dark": Color("#28509c"), "weapon": "sword"},
	"fist": {"main": Color("#f08a24"), "light": Color("#ffb259"), "dark": Color("#b65e10"), "weapon": "fist"},
	"spell": {"main": Color("#7a4bc8"), "light": Color("#a57ae6"), "dark": Color("#52308f"), "weapon": "talisman"},
}

static var _cache: Dictionary = {}


## 주인공 스프라이트. category: sword/fist/spell
## 반환: {body, flash, weapon, size, hand, weapon_pivot, head_rect}
static func hero(category: String) -> Dictionary:
	var key := "hero_" + category
	if not _cache.has(key):
		# 실루엣 + 손그림 질감 스타일 (InkArt). 예전 도트 그림은 _build_hero에 남아 있다
		_cache[key] = InkArt.hero(category if OUTFITS.has(category) else "sword")
	return _cache[key]


## 몬스터 스프라이트. kind: bandit/masked/chief (+ MonsterArt.SPECS의 추가 몬스터)
## 반환: {body, flash, ko, weapon, size, hand, weapon_pivot}
static func monster(kind: String) -> Dictionary:
	var key := "mon_" + kind
	if not _cache.has(key):
		_cache[key] = MonsterArt.build(kind) if MonsterArt.has_kind(kind) else _build_monster(kind)
	return _cache[key]


# ---- 공통 페인터 ----

class Canvas:
	var img: Image
	var w: int
	var h: int

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func p(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, c)

	## x0~x1, y0~y1 (양 끝 포함) 사각형 채우기
	func r(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for x in range(mini(x0, x1), maxi(x0, x1) + 1):
				p(x, y, c)

	## 모서리를 cut픽셀 깎은 사각형
	func rr(x0: int, y0: int, x1: int, y1: int, c: Color, cut: int = 2) -> void:
		for y in range(y0, y1 + 1):
			var inset := 0
			var dt := y - y0
			var db := y1 - y
			var d := mini(dt, db)
			if d < cut:
				inset = cut - d
			r(x0 + inset, y, x1 - inset, y, c)

	## 세로줄 (x, y0~y1)
	func v(x: int, y0: int, y1: int, c: Color) -> void:
		r(x, y0, x, y1, c)

	func hl(x0: int, x1: int, y: int, c: Color) -> void:
		r(x0, y, x1, y, c)

	## 두 점 사이 선 (브레젠험)
	func line(x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			r(x0, y0, x0 + thick - 1, y0 + thick - 1, c)
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy

	## 불투명 픽셀 둘레에 외곽선을 thick픽셀 두른다
	func outline(c: Color, thick: int = 1) -> void:
		for _i in thick:
			var src := img.duplicate()
			for y in h:
				for x in w:
					if src.get_pixel(x, y).a > 0.0:
						continue
					var near := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
							near = true
							break
					if near:
						img.set_pixel(x, y, c)

	func flipped() -> Image:
		var c := img.duplicate()
		c.flip_x()
		return c


static func _tex(img: Image) -> ImageTexture:
	var big := img.duplicate()
	big.resize(img.get_width() * UPSCALE, img.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


## 불투명 픽셀을 모두 흰색으로 바꾼 이미지 (피격 번쩍임)
static func _silhouette(img: Image) -> Image:
	var s := img.duplicate()
	for y in s.get_height():
		for x in s.get_width():
			if s.get_pixel(x, y).a > 0.0:
				s.set_pixel(x, y, Color(1, 1, 1, 1))
	return s


# ---- 머리 (주인공과 몬스터 공통 틀) ----

## 큰 네모 머리. 얼굴 피부와 그림자, 볼터치까지 칠한다. 기준 왼쪽 위 (hx, hy), 크기 32×26
static func _head_base(c: Canvas, hx: int, hy: int) -> void:
	c.rr(hx, hy, hx + 31, hy + 25, SKIN, 3)
	# 턱 아래 그림자
	c.hl(hx + 4, hx + 27, hy + 24, SKIN_SHADE)
	c.hl(hx + 6, hx + 25, hy + 25, SKIN_SHADE)
	# 볼터치
	c.r(hx + 9, hy + 18, hx + 11, hy + 19, BLUSH)
	c.r(hx + 25, hy + 18, hx + 27, hy + 19, BLUSH)


## 작고 단순한 눈. mode: normal(기본), fierce(공격 준비, 치켜뜬 눈썹), ko(기절 X눈)
static func _eyes(c: Canvas, hx: int, hy: int, mode: String) -> void:
	var ex := [hx + 13, hx + 22]
	for x in ex:
		if mode == "ko":
			var col := EYE
			c.p(x, hy + 13, col); c.p(x + 3, hy + 13, col)
			c.p(x + 1, hy + 14, col); c.p(x + 2, hy + 14, col)
			c.p(x + 1, hy + 15, col); c.p(x + 2, hy + 15, col)
			c.p(x, hy + 16, col); c.p(x + 3, hy + 16, col)
			continue
		c.r(x, hy + 13, x + 2, hy + 16, EYE)
		c.p(x + 2, hy + 13, WHITE)
		c.p(x, hy + 16, EYE_HI)
	if mode == "fierce":
		# 치켜 올라간 눈썹
		c.hl(ex[0] - 1, ex[0] + 2, hy + 11, EYE)
		c.p(ex[0] + 3, hy + 10, EYE)
		c.hl(ex[1], ex[1] + 3, hy + 11, EYE)
		c.p(ex[1] - 1, hy + 10, EYE)
	elif mode == "normal":
		c.hl(ex[0], ex[0] + 2, hy + 11, EYE.lightened(0.15))
		c.hl(ex[1], ex[1] + 2, hy + 11, EYE.lightened(0.15))


# ---- 주인공 ----

static func _build_hero(o: Dictionary) -> Dictionary:
	var W := 60
	var H := 56
	var c := Canvas.new(W, H)
	var hx := 12
	var hy := 5
	var hair := Color("#2b2558")
	var hair_hi := Color("#463f86")
	var main: Color = o["main"]
	var light: Color = o["light"]
	var dark: Color = o["dark"]

	# 은빛 머리끈 꼬리 (머리 뒤쪽으로 휘날림)
	var ribbon := Color("#dfe6f5")
	var ribbon_sh := Color("#9aa6c4")
	for i in 9:
		c.r(hx - 2 - i, hy + 4 + i / 2, hx + 1 - i, hy + 6 + i / 2 + (1 if i < 5 else 0), ribbon if i % 3 != 2 else ribbon_sh)
	for i in 7:
		c.r(hx - 1 - i, hy + 11 + i / 2, hx + 1 - i, hy + 12 + i / 2, ribbon_sh if i % 2 == 0 else ribbon)

	# 몸통 (머리보다 훨씬 작게): 공격 준비 자세로 앞으로 살짝 기울인다
	var by := hy + 27
	# 뒷다리 (뒤로 뻗음)
	c.r(hx + 3, by + 13, hx + 9, by + 18, Color("#3a3150"))
	c.r(hx + 1, by + 18, hx + 9, by + 20, Color("#221c33"))
	# 앞다리 (앞으로 크게 내딛음)
	c.r(hx + 20, by + 13, hx + 26, by + 17, Color("#3a3150"))
	c.r(hx + 21, by + 18, hx + 30, by + 20, Color("#221c33"))
	# 도복 아랫단 (펄럭임)
	c.r(hx + 4, by + 8, hx + 25, by + 13, main)
	c.r(hx + 2, by + 11, hx + 6, by + 14, dark)
	c.hl(hx + 7, hx + 24, by + 13, dark)
	c.p(hx + 12, by + 12, dark); c.p(hx + 18, by + 12, dark)
	# 상의
	c.r(hx + 6, by, hx + 24, by + 8, main)
	c.r(hx + 6, by, hx + 8, by + 7, light)
	c.r(hx + 22, by + 1, hx + 24, by + 8, dark)
	# 흰 깃 (V자)
	c.line(hx + 12, by, hx + 15, by + 4, WHITE)
	c.line(hx + 18, by, hx + 15, by + 4, WHITE)
	c.v(hx + 15, by + 4, by + 6, WHITE)
	# 허리띠와 금장 버클
	c.r(hx + 6, by + 7, hx + 25, by + 8, Color("#2a2240"))
	c.r(hx + 14, by + 6, hx + 17, by + 9, Color("#ffcf4a"))
	c.p(hx + 15, by + 7, Color("#b8861c"))
	# 뒷팔 (뒤로 당김)
	c.r(hx + 1, by + 2, hx + 6, by + 6, dark)
	c.r(hx - 1, by + 3, hx + 1, by + 6, SKIN)
	# 앞팔 (무기를 쥔 손)
	c.r(hx + 23, by + 2, hx + 28, by + 6, light)
	c.r(hx + 28, by + 3, hx + 31, by + 6, SKIN)

	# 머리
	_head_base(c, hx, hy)
	# 머리카락: 윗머리와 들쭉날쭉한 앞머리
	c.rr(hx, hy - 1, hx + 31, hy + 8, hair, 3)
	c.r(hx, hy + 6, hx + 4, hy + 18, hair)  # 뒷머리 (왼쪽)
	c.r(hx + 1, hy + 18, hx + 3, hy + 20, hair)
	var bangs := [9, 11, 8, 12, 9, 13, 8, 11, 9, 10, 12, 8, 10]
	for i in bangs.size():
		var x0 := hx + 5 + i * 2
		c.r(x0, hy + 8, x0 + 1, hy + bangs[i], hair)
	c.r(hx + 29, hy + 6, hx + 31, hy + 14, hair)  # 옆머리 (앞쪽)
	c.hl(hx + 4, hx + 26, hy + 1, hair_hi)
	c.hl(hx + 8, hx + 18, hy + 2, hair_hi)
	# 상투와 금 머리띠, 붉은 보석
	c.rr(hx + 10, hy - 6, hx + 21, hy, hair, 2)
	c.hl(hx + 12, hx + 19, hy - 5, hair_hi)
	c.r(hx + 11, hy - 2, hx + 20, hy - 1, Color("#ffcf4a"))
	c.r(hx + 15, hy - 2, hx + 16, hy - 1, Color("#e0283a"))
	_eyes(c, hx, hy, "fierce")
	# 입
	c.hl(hx + 18, hx + 19, hy + 20, Color("#c4685a"))

	c.outline(OUTLINE, 1)
	var hand := Vector2(hx + 30, by + 4)

	# 무기
	var weapon: Dictionary
	match o["weapon"]:
		"fist":
			weapon = _weapon_fist()
		"talisman":
			weapon = _weapon_talisman()
		_:
			weapon = _weapon_sword()
	return {
		"body": _tex(c.img),
		"flash": _tex(_silhouette(c.img)),
		"image": c.img,
		"weapon": weapon["tex"],
		"weapon_pivot": weapon["pivot"],
		"weapon_kind": o["weapon"],
		"size": Vector2(W, H),
		"hand": hand,
		## 상단 프로필용 얼굴 영역 (그림 픽셀 단위)
		"head_rect": Rect2(hx - 2, hy - 7, 36, 34),
	}


## 큰 검: 은빛 칼날, 금색 코등이, 붉은 수술. 손잡이 위치를 pivot으로 돌려준다
static func _weapon_sword() -> Dictionary:
	var c := Canvas.new(12, 44)
	var blade := Color("#dfe7f7")
	var blade_sh := Color("#9fb0cc")
	var blade_hi := Color.WHITE
	# 칼날 (위쪽이 칼끝)
	c.r(4, 3, 7, 30, blade)
	c.v(4, 3, 30, blade_sh)
	c.v(6, 4, 29, blade_hi)
	c.r(5, 1, 6, 2, blade)
	c.p(5, 0, blade_hi)
	# 코등이
	c.r(1, 31, 10, 33, Color("#ffcf4a"))
	c.r(4, 31, 7, 33, Color("#e0283a"))
	c.p(5, 32, Color("#ffd8a0"))
	# 손잡이
	c.r(4, 34, 7, 39, Color("#7a3a22"))
	c.hl(4, 7, 36, Color("#a65a33"))
	c.hl(4, 7, 38, Color("#a65a33"))
	c.r(4, 40, 7, 41, Color("#ffcf4a"))
	# 붉은 수술
	c.v(6, 42, 43, Color("#e0283a"))
	c.p(7, 43, Color("#e0283a"))
	c.outline(OUTLINE, 1)
	return {"tex": _tex(c.img), "pivot": Vector2(6, 37), "image": c.img}


## 철가시 붕대 주먹
static func _weapon_fist() -> Dictionary:
	var c := Canvas.new(22, 18)
	var band := Color("#f3ead8")
	var band_sh := Color("#cbbd9f")
	var iron := Color("#b9c2d0")
	var iron_dk := Color("#6f7a8c")
	# 주먹 (붕대 감은 둥근 덩어리)
	c.rr(2, 6, 18, 16, band, 3)
	for x in [5, 9, 13]:
		c.v(x, 7, 15, band_sh)
	c.hl(3, 17, 11, band_sh)
	# 철판과 가시
	c.r(4, 4, 17, 6, iron)
	c.hl(4, 17, 6, iron_dk)
	for x in [5, 9, 13, 17]:
		c.r(x, 1, x + 1, 3, iron)
		c.p(x, 0, Color.WHITE)
	# 손목 붕대 꼬리
	c.r(0, 12, 2, 14, band)
	c.p(0, 15, band_sh)
	c.outline(OUTLINE, 1)
	return {"tex": _tex(c.img), "pivot": Vector2(4, 12), "image": c.img}


## 부적 다발 (노란 부적 3장, 붉은 부문)
static func _weapon_talisman() -> Dictionary:
	var c := Canvas.new(22, 22)
	var paper := Color("#ffe25a")
	var paper_sh := Color("#e3b52c")
	var ink := Color("#d42a2a")
	var cards := [[1, 4], [8, 1], [15, 4]]
	for cd in cards:
		var x0: int = cd[0]
		var y0: int = cd[1]
		c.r(x0, y0, x0 + 5, y0 + 13, paper)
		c.v(x0 + 5, y0, y0 + 13, paper_sh)
		c.hl(x0 + 1, x0 + 4, y0 + 2, ink)
		c.v(x0 + 2, y0 + 3, y0 + 10, ink)
		c.p(x0 + 3, y0 + 5, ink)
		c.p(x0 + 1, y0 + 7, ink)
		c.p(x0 + 3, y0 + 9, ink)
	# 쥔 손
	c.rr(7, 15, 14, 20, SKIN, 1)
	c.outline(OUTLINE, 1)
	return {"tex": _tex(c.img), "pivot": Vector2(10, 18), "image": c.img}


# ---- 몬스터 ----

static func _build_monster(kind: String) -> Dictionary:
	var normal := _monster_canvas(kind, "normal")
	var ko := _monster_canvas(kind, "ko")
	var weapon: Dictionary
	match kind:
		"masked":
			weapon = _weapon_dagger()
		"chief":
			weapon = _weapon_broad(true)
		_:
			weapon = _weapon_broad(false)
	var W: int = normal.w
	# 왼쪽을 보도록 반전한다. 손 위치도 반전
	var hand := Vector2(W - 1 - 42, 36)
	var wimg: Image = weapon["image"].duplicate()
	wimg.flip_x()
	var piv: Vector2 = weapon["pivot"]
	return {
		"body": _tex(InkArt.ink_image(normal.flipped())),
		"flash": _tex(_silhouette(normal.flipped())),
		"ko": _tex(InkArt.ink_image(ko.flipped(), false)),
		"weapon": _tex(InkArt.ink_image(wimg, false)),
		"weapon_pivot": Vector2(wimg.get_width() - 1 - piv.x, piv.y),
		"size": Vector2(W, normal.h),
		"hand": hand,
	}


static func _monster_canvas(kind: String, eye_mode: String) -> Canvas:
	var W := 56
	var H := 56
	var c := Canvas.new(W, H)
	var hx := 11
	var hy := 6
	var pal: Dictionary = {
		"bandit": {"hair": Color("#6b4426"), "hair_hi": Color("#8c5c34"), "main": Color("#9a6a3e"), "light": Color("#b8854f"), "dark": Color("#6e4826"), "band": Color("#e8302f"), "sash": Color("#c8323a")},
		"masked": {"hair": Color("#25222f"), "hair_hi": Color("#3d3950"), "main": Color("#3a3748"), "light": Color("#4f4b62"), "dark": Color("#24222f"), "band": Color("#d42a35"), "sash": Color("#c8323a")},
		"chief": {"hair": Color("#4a2c18"), "hair_hi": Color("#6e4524"), "main": Color("#7a2f2f"), "light": Color("#a04040"), "dark": Color("#541e1e"), "band": Color("#ffcf4a"), "sash": Color("#ffcf4a")},
	}.get(kind, {})
	if pal.is_empty():
		pal = {"hair": Color("#6b4426"), "hair_hi": Color("#8c5c34"), "main": Color("#9a6a3e"), "light": Color("#b8854f"), "dark": Color("#6e4826"), "band": Color("#e8302f"), "sash": Color("#c8323a")}
	var main: Color = pal["main"]
	var light: Color = pal["light"]
	var dark: Color = pal["dark"]

	# 머리띠 꼬리 / 두건 꼬리 (뒤로 휘날림)
	var band: Color = pal["band"]
	if kind != "chief":
		for i in 8:
			c.r(hx - 1 - i, hy + 6 + i / 3, hx + 1 - i, hy + 8 + i / 2, band if i % 3 != 2 else band.darkened(0.25))
	else:
		# 두목: 붉은 망토
		c.r(hx + 2, hy + 26, hx + 8, hy + 44, Color("#b82a2a"))
		c.r(hx, hy + 34, hx + 4, hy + 46, Color("#8c1c1c"))

	var by := hy + 27
	# 다리와 신발
	c.r(hx + 6, by + 13, hx + 12, by + 17, Color("#3a2e2a"))
	c.r(hx + 5, by + 18, hx + 13, by + 20, Color("#1f1915"))
	c.r(hx + 19, by + 13, hx + 25, by + 17, Color("#3a2e2a"))
	c.r(hx + 19, by + 18, hx + 27, by + 20, Color("#1f1915"))
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
	if kind == "chief":
		# 금장 테두리
		c.hl(hx + 5, hx + 26, by, Color("#ffcf4a"))
		c.v(hx + 15, by + 1, by + 7, Color("#ffcf4a"))
	# 허리띠 (붉은 띠, 매듭)
	var sash: Color = pal["sash"]
	c.r(hx + 5, by + 7, hx + 26, by + 8, sash)
	c.r(hx + 14, by + 6, hx + 17, by + 9, Color("#ffcf4a") if kind != "chief" else Color("#e0283a"))
	c.r(hx + 21, by + 9, hx + 23, by + 12, sash.darkened(0.2))
	# 팔
	c.r(hx + 1, by + 2, hx + 6, by + 6, dark)
	c.r(hx - 1, by + 3, hx + 1, by + 6, SKIN)
	c.r(hx + 25, by + 2, hx + 29, by + 6, light)
	c.r(hx + 29, by + 3, hx + 32, by + 6, SKIN)

	# 머리
	_head_base(c, hx, hy)
	var hair: Color = pal["hair"]
	var hair_hi: Color = pal["hair_hi"]
	match kind:
		"masked":
			# 검은 두건이 머리 전체를 덮고, 아래 얼굴은 복면으로 가린다
			c.rr(hx, hy - 1, hx + 31, hy + 10, hair, 3)
			c.r(hx, hy + 8, hx + 4, hy + 25, hair)
			c.r(hx + 27, hy + 8, hx + 31, hy + 25, hair)
			c.hl(hx + 4, hx + 27, hy + 1, hair_hi)
			c.r(hx + 2, hy + 18, hx + 29, hy + 25, Color("#1e1c27"))
			c.hl(hx + 4, hx + 27, hy + 18, hair_hi)
			c.r(hx + 15, hy + 21, hx + 16, hy + 21, Color("#d42a35"))
		_:
			c.rr(hx, hy - 1, hx + 31, hy + 7, hair, 3)
			c.r(hx, hy + 6, hx + 4, hy + 19, hair)
			c.r(hx + 28, hy + 6, hx + 31, hy + 13, hair)
			var bangs := [9, 8, 10, 8, 9, 8, 10, 8, 9, 8, 9, 10, 8]
			for i in bangs.size():
				var x0 := hx + 5 + i * 2
				c.r(x0, hy + 7, x0 + 1, hy + bangs[i], hair)
			c.hl(hx + 4, hx + 26, hy + 1, hair_hi)
			# 머리띠
			c.r(hx, hy + 4, hx + 31, hy + 6, band)
			c.hl(hx + 1, hx + 30, hy + 4, band.lightened(0.25))
			# 수염 점과 흉터
			for x in range(hx + 10, hx + 24, 2):
				c.p(x, hy + 22, Color("#7a4a2e"))
			if kind == "chief":
				c.r(hx + 9, hy + 22, hx + 24, hy + 26, hair)
				c.hl(hx + 11, hx + 22, hy + 27, hair)
			else:
				c.line(hx + 27, hy + 14, hx + 26, hy + 18, Color("#c4485a"))
	_eyes(c, hx, hy, "normal" if eye_mode == "normal" else "ko")
	if kind != "masked" and kind != "chief":
		c.hl(hx + 17, hx + 18, hy + 20, Color("#c4685a"))
	c.outline(OUTLINE, 1)
	return c


## 넓은 칼 (산적 도). gold면 두목용 금장
static func _weapon_broad(gold: bool) -> Dictionary:
	var c := Canvas.new(14, 40)
	var blade := Color("#d5dcea")
	var sh := Color("#98a3ba")
	c.r(3, 4, 10, 27, blade)
	c.r(5, 1, 10, 3, blade)
	c.p(9, 0, blade)
	c.v(3, 6, 27, sh)
	c.v(9, 3, 26, Color.WHITE)
	if gold:
		c.r(4, 10, 6, 22, Color("#ffcf4a"))
	c.r(1, 28, 12, 30, Color("#ffcf4a") if gold else Color("#8a6a3a"))
	c.r(5, 31, 8, 37, Color("#5a3020"))
	c.hl(5, 8, 33, Color("#7a4a30"))
	c.hl(5, 8, 35, Color("#7a4a30"))
	c.outline(OUTLINE, 1)
	return {"tex": _tex(c.img), "pivot": Vector2(6, 34), "image": c.img}


## 단검 (복면 자객)
static func _weapon_dagger() -> Dictionary:
	var c := Canvas.new(8, 24)
	c.r(2, 2, 5, 14, Color("#dfe7f7"))
	c.v(2, 3, 14, Color("#98a3ba"))
	c.r(3, 0, 4, 1, Color("#dfe7f7"))
	c.r(0, 15, 7, 16, Color("#ffcf4a"))
	c.r(2, 17, 5, 21, Color("#3a2a3a"))
	c.outline(OUTLINE, 1)
	return {"tex": _tex(c.img), "pivot": Vector2(3, 19), "image": c.img}


# ---- 그리기 도우미 ----

## 스프라이트 텍스처를 그림 픽셀 기준 위치에 그린다. feet: 발 기준점(캔버스 아래 가운데)
static func draw_sprite(ci: CanvasItem, tex: Texture2D, size: Vector2, at: Vector2, scale: float = ART_SCALE, modulate: Color = Color.WHITE) -> void:
	var draw_size := size * scale
	ci.draw_texture_rect(tex, Rect2(at - Vector2(draw_size.x * 0.5, draw_size.y), draw_size), false, modulate)


## 무기를 손 위치에 회전해 그린다. hand_pos: 화면 좌표, pivot: 무기 그림 픽셀 기준 손잡이
static func draw_weapon(ci: CanvasItem, tex: Texture2D, pivot: Vector2, hand_pos: Vector2, angle: float, scale: float = ART_SCALE, modulate: Color = Color.WHITE) -> void:
	var tsize := tex.get_size() / UPSCALE
	ci.draw_set_transform(hand_pos, angle, Vector2(scale, scale))
	ci.draw_texture_rect(tex, Rect2(-pivot, tsize), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
