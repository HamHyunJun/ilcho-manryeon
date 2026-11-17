extends RefCounted
class_name MonsterSprites
## 스테이지별 몬스터·보스 그림 (몬스터 디자인 시안 4장에서 잘라 낸 도트 스프라이트).
## - assets/sprites/monsters/<id>.png       : 프레임을 가로로 이어 붙인 시트 (모두 왼쪽 = 주인공 쪽을 본다)
##   assets/sprites/monsters/<id>_flash.png : 같은 배치의 하얀 실루엣 (피격 번쩍임)
##   assets/sprites/monsters/monster_sprites.json : 프레임 위치·기준점·동작 목록
## - 자르는 도구: tools/monster_sprites/ (build.py). 시안은 오른쪽을 보고 있어 자를 때 좌우 반전했다.
## - 동작: idle, walk, attack, hit, death, skill(보스 스킬 자세)
##         fx(공격 이펙트, 주인공 위치 또는 투사체), skill_fx(보스 스킬 이펙트, 주인공 위치)
##   몸 프레임의 기준점은 발, 이펙트 프레임의 기준점은 가운데다.
## - 시안에 없는 동작은 대신 쓸 동작으로 돌린다 (FALLBACK). 피격·쓰러짐이 없으면 그리는 쪽에서 따로 처리한다.

const DIR := "res://assets/sprites/monsters/"
const META_PATH := DIR + "monster_sprites.json"
## 반복 동작의 초당 칸 수
const ANIM_FPS := {"idle": 2.2, "walk": 6.0}
const FALLBACK := {"walk": "idle", "attack": "idle", "skill": "attack", "hit": "", "death": ""}

static var _meta: Dictionary = {}
static var _tex: Dictionary = {}


static func _load_meta() -> void:
	if not _meta.is_empty():
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		push_error("[MonsterSprites] 프레임 정보 없음: " + META_PATH)
		_meta = {"_missing": true}
		return
	var data = JSON.parse_string(f.get_as_text())
	_meta = data.get("sprites", {}) if data is Dictionary else {}
	if _meta.is_empty():
		_meta = {"_missing": true}


static func ids() -> Array:
	_load_meta()
	return _meta.keys().filter(func(k): return not String(k).begins_with("_"))


static func has(id: String) -> bool:
	_load_meta()
	return id != "" and _meta.has(id) and not id.begins_with("_")


static func info(id: String) -> Dictionary:
	_load_meta()
	return _meta.get(id, {})


## 시트 텍스처. flash: 하얀 실루엣
static func texture(id: String, flash: bool = false) -> Texture2D:
	var key := id + ("_flash" if flash else "")
	if not _tex.has(key):
		var path := DIR + key + ".png"
		_tex[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex[key]


## 동작에 들어 있는 프레임 번호 목록 (시안에 없으면 FALLBACK 동작, 그래도 없으면 빈 배열)
static func frames(id: String, anim: String) -> Array:
	var anims: Dictionary = info(id).get("anims", {})
	var a := anim
	for i in 3:
		if anims.has(a) and not anims[a].is_empty():
			return anims[a]
		a = String(FALLBACK.get(a, ""))
		if a == "":
			break
	return []


## 그 동작이 시안에 직접 있는지 (대신 쓸 동작 말고)
static func has_anim(id: String, anim: String) -> bool:
	var anims: Dictionary = info(id).get("anims", {})
	return anims.has(anim) and not anims[anim].is_empty()


## 동작 이름과 시간으로 프레임 번호를 고른다. progress(0~1)를 주면 한 번 재생하는 동작의 진행도로 고른다.
## 없으면 -1
static func frame_at(id: String, anim: String, t: float, progress: float = -1.0) -> int:
	var fr := frames(id, anim)
	if fr.is_empty():
		return -1
	var i := 0
	if progress >= 0.0:
		i = mini(fr.size() - 1, int(clampf(progress, 0.0, 0.999) * fr.size()))
	else:
		i = int(floor(t * float(ANIM_FPS.get(anim, 4.0)))) % fr.size()
	return int(fr[i])


## 대기 첫 칸의 몸 높이(px, 시트 기준)
static func body_px(id: String) -> float:
	return maxf(1.0, float(info(id).get("body_px", 100.0)))


## 화면 몸 높이(height)에 맞추는 배율
static func scale_for(id: String, height: float) -> float:
	return height / body_px(id)


## 프레임의 크기(시트 기준 px)
static func frame_size(id: String, frame: int) -> Vector2:
	var fr: Array = info(id).get("frames", [])
	if frame < 0 or frame >= fr.size():
		return Vector2.ZERO
	var r: Array = fr[frame]["rect"]
	return Vector2(r[2], r[3])


## 프레임 하나를 기준점(at)에 맞춰 그린다. 몸 프레임은 발, 이펙트 프레임은 가운데가 at에 온다.
## flip_x: true면 좌우 반전(오른쪽을 보게), rot: 기준점을 축으로 돌리는 각도
static func draw_frame(ci: CanvasItem, id: String, frame: int, at: Vector2, sc: float, modulate: Color = Color.WHITE, flash: bool = false, flip_x: bool = false, rot: float = 0.0) -> void:
	var fr: Array = info(id).get("frames", [])
	if frame < 0 or frame >= fr.size():
		return
	var tex := texture(id, flash)
	if tex == null:
		tex = texture(id)
	if tex == null:
		return
	var r: Array = fr[frame]["rect"]
	var anc: Array = fr[frame]["anchor"]
	var src := Rect2(r[0], r[1], r[2], r[3])
	ci.draw_set_transform(at, rot, Vector2(-sc if flip_x else sc, sc))
	ci.draw_texture_rect_region(tex, Rect2(-Vector2(anc[0], anc[1]), src.size), src, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
