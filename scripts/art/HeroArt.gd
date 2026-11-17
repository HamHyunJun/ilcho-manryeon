extends RefCounted
class_name HeroArt
## 주인공 캐릭터 그림 (최종 디자인 시안 "무협 픽셀 캐릭터 디자인 시안" 10종).
## - 시안 한 장에서 잘라 낸 투명 배경 PNG를 쓴다 (assets/sprites/heroes).
##   <id>_full.png  : 시안 위쪽의 큰 도트 일러스트 (육성 화면, 전투 대기 모습, 프로필 얼굴)
##   <id>_battle.png: 시안 아래쪽의 속성 이펙트가 들어간 전투 포즈 (초식 발동 순간)
##   자르는 도구: tools/hero_sprite_cutter.py (배경 제거, 흰 테두리·갇힌 배경 정리)
##   <id>_motion.png: 1차 모션 시안(통합 아틀라스)에서 잘라 낸 9칸 동작 시트 (전투·육성 화면 애니메이션)
##   자르는 도구: tools/motion_fx/ (extract.py → build.py). 칸마다 몸 높이와 발 기준점을 맞춰 두었다.
## - 큰 일러스트는 시안 그대로 정면(왼쪽 3/4)을 보고, 전투 포즈는 오른쪽을 본다.
##   전투 화면에서는 몬스터가 오른쪽에 있으므로 큰 일러스트를 좌우 반전해 오른쪽을 보게 한다.
## - 외형은 저장 데이터 character.appearance에 둔다. "" 이면 주력 무공 계열을 따른다
##   (검: 청풍검객, 권: 소림승려, 술: 음양사). 이전의 "계열에 따라 복장이 바뀌는" 동작을 그대로 잇는다.

const DIR := "res://assets/sprites/heroes/"

## 시안 순서 그대로 (위 5명, 아래 5명).
## feet: 큰 일러스트에서 발 기준점, head: 얼굴 중심(프로필용), pose_feet: 전투 포즈에서 발 기준점
## color: 시안 색 점의 대표색 (초식 오라·선택 카드 테두리)
const CHARACTERS := [
	{"id": "cheongpung", "name": "청풍검객", "desc": "무협의 기본,\n검을 다루는 청년", "category": "sword", "color": Color("#4f6fc8"),
		"feet": Vector2(120, 266), "head": Vector2(133, 92), "pose_feet": Vector2(78, 140)},
	{"id": "maehwa", "name": "매화검녀", "desc": "매화처럼 아름다운\n검객", "category": "sword", "color": Color("#e0708e"),
		"feet": Vector2(94, 240), "head": Vector2(130, 70), "pose_feet": Vector2(83, 142)},
	{"id": "sorim", "name": "소림승려", "desc": "불심으로 무장한\n무림의 승려", "category": "fist", "color": Color("#d99a36"),
		"feet": Vector2(99, 227), "head": Vector2(106, 42), "pose_feet": Vector2(88, 130)},
	{"id": "eumyang", "name": "음양사", "desc": "음양의 도를 다루는\n술법의 대가", "category": "spell", "color": Color("#7a5ad8"),
		"feet": Vector2(105, 258), "head": Vector2(146, 78), "pose_feet": Vector2(88, 143)},
	{"id": "hyeolma", "name": "혈마검객", "desc": "핏빛을 두른\n마교의 살수", "category": "sword", "color": Color("#d03a3a"),
		"feet": Vector2(111, 245), "head": Vector2(132, 72), "pose_feet": Vector2(39, 135)},
	{"id": "banghwang", "name": "천하방랑객", "desc": "세상을 떠도는\n무림의 고수", "category": "sword", "color": Color("#8fa6d8"),
		"feet": Vector2(119, 226), "head": Vector2(118, 62), "pose_feet": Vector2(75, 119)},
	{"id": "mudang", "name": "무당제자", "desc": "태극의 경지를 따르는\n무당파 제자", "category": "spell", "color": Color("#a88ae6"),
		"feet": Vector2(97, 214), "head": Vector2(118, 58), "pose_feet": Vector2(81, 113)},
	{"id": "nahan", "name": "나한권사", "desc": "불패의 권법을 쓰는\n소림의 무사", "category": "fist", "color": Color("#c0503a"),
		"feet": Vector2(94, 221), "head": Vector2(92, 64), "pose_feet": Vector2(72, 108)},
	{"id": "cheongang", "name": "천강도사", "desc": "번개를 다루는\n천사도의 도사", "category": "spell", "color": Color("#4a9cf0"),
		"feet": Vector2(96, 229), "head": Vector2(108, 64), "pose_feet": Vector2(69, 124)},
	{"id": "amyeong", "name": "암영살수", "desc": "그림자 속의\n무영의 살수", "category": "sword", "color": Color("#8a50c8"),
		"feet": Vector2(108, 231), "head": Vector2(117, 70), "pose_feet": Vector2(57, 108)},
]

## 외형을 고르지 않았을 때 주력 무공 계열별 기본 주인공
const DEFAULT_BY_CATEGORY := {"sword": "cheongpung", "fist": "sorim", "spell": "eumyang"}
## 전투 포즈 속 캐릭터는 큰 일러스트보다 작게 그려져 있어, 같은 키로 보이도록 키우는 비율
const POSE_RATIO := 1.9

## 동작 시트: 한 칸 크기, 칸 안의 발 기준점, 칸 안의 몸 높이(머리끝~발끝, px)
const MOTION_CELL := Vector2(200, 150)
const MOTION_FEET := Vector2(84, 142)
const MOTION_BODY := 104.0
## 시안 동작 칸 순서: 0~1 대기, 2~4 걷기, 5 공격, 6~8 초식(기술)
const ANIMS := {
	"idle": [0, 1],
	"walk": [2, 3, 4, 3],
	"attack": [5],
	"skill": [6, 7, 8],
}
## 반복 동작의 초당 칸 수
const ANIM_FPS := {"idle": 1.6, "walk": 7.0}

static var _cache: Dictionary = {}


static func ids() -> Array:
	var out := []
	for c in CHARACTERS:
		out.append(c["id"])
	return out


static func info(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]


static func has(id: String) -> bool:
	return ids().has(id)


## 저장된 외형 설정과 주력 무공 계열로 실제로 그릴 캐릭터를 정한다
static func resolve(appearance: String, category: String) -> String:
	if has(appearance):
		return appearance
	return String(DEFAULT_BY_CATEGORY.get(category, "cheongpung"))


## 그림 묶음: {full, full_flash, battle, info}
static func art(id: String) -> Dictionary:
	if not has(id):
		id = "cheongpung"
	if not _cache.has(id):
		var full: Texture2D = load(DIR + id + "_full.png")
		var battle: Texture2D = load(DIR + id + "_battle.png")
		var motion: Texture2D = load(DIR + id + "_motion.png") if ResourceLoader.exists(DIR + id + "_motion.png") else null
		_cache[id] = {"full": full, "full_flash": _silhouette(full), "battle": battle, "motion": motion, "info": info(id)}
	return _cache[id]


## 피격 순간 하얗게 번쩍이는 실루엣
static func _silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## 큰 일러스트를 발 기준점(feet) 위에 그린다. height: 화면에서의 그림 전체 높이.
## flip: true면 좌우 반전(오른쪽을 보게)
static func draw_full(ci: CanvasItem, id: String, feet: Vector2, height: float, flip: bool = false, modulate: Color = Color.WHITE, flash: bool = false) -> void:
	var a := art(id)
	var tex: Texture2D = a["full_flash"] if flash else a["full"]
	if tex == null:
		return
	var sz := tex.get_size()
	var sc := height / sz.y
	var f: Vector2 = a["info"]["feet"]
	_draw_at(ci, tex, f, feet, sc, flip, modulate)


## 전투 포즈(이펙트 포함)를 발 기준점 위에 그린다. full_height: 같은 캐릭터 큰 일러스트의 화면 높이
static func draw_pose(ci: CanvasItem, id: String, feet: Vector2, full_height: float, modulate: Color = Color.WHITE) -> void:
	var a := art(id)
	var tex: Texture2D = a["battle"]
	var full: Texture2D = a["full"]
	if tex == null or full == null:
		return
	var sc := full_height / full.get_size().y * POSE_RATIO
	_draw_at(ci, tex, a["info"]["pose_feet"], feet, sc, false, modulate)


static func _draw_at(ci: CanvasItem, tex: Texture2D, anchor: Vector2, at: Vector2, sc: float, flip: bool, modulate: Color) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(-sc if flip else sc, sc))
	ci.draw_texture(tex, -anchor, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 얼굴 부분만 원 안에 그린다 (프로필). size: 화면에서 얼굴 칸 한 변
static func draw_face(ci: CanvasItem, id: String, center: Vector2, size: float) -> void:
	var a := art(id)
	var tex: Texture2D = a["full"]
	if tex == null:
		return
	var h: Vector2 = a["info"]["head"]
	var side := tex.get_size().y * 0.36
	var src := Rect2(h - Vector2(side, side) * 0.5, Vector2(side, side))
	src = src.intersection(Rect2(Vector2.ZERO, tex.get_size()))
	var sc := size / side
	ci.draw_texture_rect_region(tex, Rect2(center + (src.position - h) * sc, src.size * sc), src)


## 동작 이름과 경과 시간으로 시트 칸 번호를 고른다. 반복 동작(idle, walk)은 ANIM_FPS로 돈다.
## progress(0~1)를 주면 한 번만 재생하는 동작(attack, skill)의 진행도로 칸을 고른다.
static func anim_frame(anim: String, t: float, progress: float = -1.0) -> int:
	var frames: Array = ANIMS.get(anim, ANIMS["idle"])
	var i := 0
	if progress >= 0.0:
		i = mini(frames.size() - 1, int(clampf(progress, 0.0, 0.999) * frames.size()))
	else:
		i = int(floor(t * float(ANIM_FPS.get(anim, 4.0)))) % frames.size()
	return int(frames[i])


## 동작 시트가 있는지 (없으면 큰 일러스트로 대신 그린다)
static func has_motion(id: String) -> bool:
	return art(id)["motion"] != null


## 동작 시트의 한 칸을 발 기준점 위에 그린다. body_height: 화면에서의 몸 높이(머리끝~발끝)
## 시안 동작은 오른쪽(몬스터 쪽)을 보고 있다. flip: true면 좌우 반전
static func draw_motion(ci: CanvasItem, id: String, frame: int, feet: Vector2, body_height: float, flip: bool = false, modulate: Color = Color.WHITE, flash: bool = false) -> void:
	var a := art(id)
	var tex: Texture2D = a["motion"]
	if tex == null:
		draw_full(ci, id, feet, body_height * 1.12, not flip, modulate, flash)
		return
	if flash:
		if not a.has("motion_flash"):
			a["motion_flash"] = _silhouette(tex)
		tex = a["motion_flash"]
	var sc := body_height / MOTION_BODY
	var src := Rect2(Vector2(MOTION_CELL.x * frame, 0), MOTION_CELL)
	ci.draw_set_transform(feet, 0.0, Vector2(-sc if flip else sc, sc))
	ci.draw_texture_rect_region(tex, Rect2(-MOTION_FEET, MOTION_CELL), src, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
