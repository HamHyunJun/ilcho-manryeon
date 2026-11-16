extends RefCounted
class_name ManualCollection
## 비급 조각과 비급 던전 기록 (M9, docs/04, docs/07).
## - 비급 조각은 무공별 아이템이다 (확정 사항 13). 필요 개수를 채우면 무공을 개방한다.
## - 이미 개방한 무공의 조각은 은냥으로 바꾼다 (가안, O-16).
## - 던전 입장 제한(하루 횟수), 천장 장치 자리(클리어 n회마다 추가 조각, 테스트용 수치, O-15).
## - 모든 던전(비급/장비/재화)의 기록: 입장 횟수, 클리어 수, 최고 난이도, 난이도별 최고 처치 수, 소탕 가능 여부.
##   저장 키는 M9 그대로 collection.dungeons.<던전 ID>를 쓴다 (새 칸은 없으면 0으로 읽어 마이그레이션 불필요).
## 상태는 저장 데이터의 collection 섹션을 직접 다룬다.

signal fragments_changed(art_id: String, count: int)

var state: Dictionary
var arts: MartialArtManager
var equipment: EquipmentManager


func _init(collection_state: Dictionary, martial_arts: MartialArtManager, equipment_manager: EquipmentManager = null) -> void:
	state = collection_state
	arts = martial_arts
	equipment = equipment_manager
	if not state.has("fragments"):
		state["fragments"] = {}
	if not state.has("dungeons"):
		state["dungeons"] = {}


static func new_state() -> Dictionary:
	return {"fragments": {}, "dungeons": {}}


static func today_key() -> String:
	return Time.get_date_string_from_system()


# ---- 비급 조각 ----

func fragments_of(art_id: String) -> int:
	return int(state["fragments"].get(art_id, 0))


func required_of(art_id: String) -> int:
	return int(arts.registry.get_martial_art(art_id).get("acquire", {}).get("required", 0))


## 조각을 더한다. 필요 개수를 채우면 무공을 개방하고 true.
## 이미 개방한 무공이면 조각 대신 은냥으로 바꾼다 (silver_per_fragment, 가안 O-16)
func add_fragments(art_id: String, n: int, silver_per_fragment: int = 50) -> bool:
	if n <= 0:
		return false
	if arts.is_unlocked(art_id):
		if equipment:
			equipment.add_currency("silver", n * silver_per_fragment)
		return false
	state["fragments"][art_id] = fragments_of(art_id) + n
	fragments_changed.emit(art_id, fragments_of(art_id))
	if fragments_of(art_id) >= required_of(art_id):
		state["fragments"][art_id] = fragments_of(art_id) - required_of(art_id)
		arts.unlock(art_id)
		return true
	return false


# ---- 던전 입장 ----

func _record(dungeon_id: String, today: String) -> Dictionary:
	if not state["dungeons"].has(dungeon_id):
		state["dungeons"][dungeon_id] = {"day": today, "entries": 0, "clears": 0, "pity": 0}
	var r: Dictionary = state["dungeons"][dungeon_id]
	# 날짜가 바뀌면 입장 횟수 초기화
	if r.get("day", "") != today:
		r["day"] = today
		r["entries"] = 0
	return r


func entries_left(dungeon: Dictionary, today: String = "") -> int:
	if today == "":
		today = today_key()
	var r := _record(dungeon["id"], today)
	return maxi(0, int(dungeon.get("entry", {}).get("daily_limit", 3)) - int(r["entries"]))


## 입장 가능 여부. highest_cleared는 StageManager.highest_cleared {지역: 최고 돌파 스테이지}
## level은 난이도 단계: 그 난이도의 스테이지 조건과, 2단계부터는 바로 아래 난이도 클리어가 필요하다.
func can_enter(dungeon: Dictionary, highest_cleared: Dictionary, today: String = "", level: int = 1) -> Dictionary:
	var lock := level_lock_reason(dungeon, highest_cleared, level)
	if lock != "":
		return {"ok": false, "reason": lock}
	if entries_left(dungeon, today) <= 0:
		return {"ok": false, "reason": "오늘 입장 횟수를 모두 썼습니다"}
	return {"ok": true, "reason": ""}


## 난이도가 잠겨 있으면 이유, 열려 있으면 빈 문자열 (입장 횟수는 보지 않음)
func level_lock_reason(dungeon: Dictionary, highest_cleared: Dictionary, level: int = 1) -> String:
	if level < 1 or level > DungeonRules.max_level(dungeon):
		return "없는 난이도"
	var req: Dictionary = DungeonRules.resolve(dungeon, level).get("entry", {}).get("required_cleared", {})
	if not req.is_empty() and int(highest_cleared.get(req.get("region", ""), 0)) < int(req.get("stage", 0)):
		return "스테이지 %d 돌파 후 입장" % int(req.get("stage", 0))
	if level > 1 and best_level_of(dungeon["id"]) < level - 1:
		return "%s 클리어 후 입장" % String(DungeonRules.difficulty(dungeon, level - 1).get("name", "이전 난이도"))
	return ""


## 소탕(자동 클리어) 가능 여부: 데이터에서 허용하고, 그 난이도를 한 번 클리어했고, 입장 횟수가 남아 있어야 한다 (가안 O-31)
func can_sweep(dungeon: Dictionary, highest_cleared: Dictionary, today: String = "", level: int = 1) -> Dictionary:
	if not bool(dungeon.get("sweep", false)):
		return {"ok": false, "reason": "소탕할 수 없는 던전"}
	if best_level_of(dungeon["id"]) < level:
		return {"ok": false, "reason": "한 번 클리어한 난이도만 소탕할 수 있습니다"}
	return can_enter(dungeon, highest_cleared, today, level)


## 입장 횟수 기록 (입장할 때 차감, 실패해도 돌려주지 않음: 가안 O-31)
func record_entry(dungeon: Dictionary, today: String = "") -> void:
	if today == "":
		today = today_key()
	var r := _record(dungeon["id"], today)
	r["entries"] = int(r["entries"]) + 1


func pity_of(dungeon_id: String) -> int:
	return int(state["dungeons"].get(dungeon_id, {}).get("pity", 0))


func clears_of(dungeon_id: String) -> int:
	return int(state["dungeons"].get(dungeon_id, {}).get("clears", 0))


## 클리어한 가장 높은 난이도 (없으면 0)
func best_level_of(dungeon_id: String) -> int:
	return int(state["dungeons"].get(dungeon_id, {}).get("best_level", 0))


## 난이도별 최고 처치 수 (시간 제한 처치 던전의 소탕 기준)
func best_kills_of(dungeon_id: String, level: int) -> int:
	return int(state["dungeons"].get(dungeon_id, {}).get("best_kills", {}).get(str(level), 0))


## 클리어 횟수만 올린다 (비급 던전은 grant_clear가 직접 올림)
func add_clear(dungeon_id: String, today: String = "") -> void:
	if today == "":
		today = today_key()
	var r := _record(dungeon_id, today)
	r["clears"] = int(r["clears"]) + 1


## 클리어 결과 기록: 최고 난이도와 난이도별 최고 처치 수
func note_result(dungeon_id: String, level: int, kills: int) -> void:
	var r: Dictionary = state["dungeons"][dungeon_id] if state["dungeons"].has(dungeon_id) else _record(dungeon_id, today_key())
	r["best_level"] = maxi(int(r.get("best_level", 0)), level)
	if not (r.get("best_kills") is Dictionary):
		r["best_kills"] = {}
	r["best_kills"][str(level)] = maxi(int(r["best_kills"].get(str(level), 0)), kills)


# ---- 보상 ----

## 보상 테이블에서 조각을 뽑는다. 반환값: [{art, amount}]
func roll_fragments(dungeon: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rw: Dictionary = dungeon.get("rewards", {})
	var pool: Array = rw.get("pool", [])
	var out: Array = []
	if pool.is_empty():
		return out
	var total := 0.0
	for e in pool:
		total += float(e.get("weight", 1))
	var amt: Array = rw.get("fragments_per_roll", [1, 1])
	for i in int(rw.get("fragment_rolls", 1)):
		var r := rng.randf() * total
		var pick: Dictionary = pool[0]
		for e in pool:
			r -= float(e.get("weight", 1))
			if r <= 0.0:
				pick = e
				break
		out.append({"art": pick["art"], "amount": rng.randi_range(int(amt[0]), int(amt[1]))})
	return out


## 클리어 보상을 지급한다. 반환값: {fragments: [{art, amount, unlocked}], silver, pity_bonus: {art, amount} 또는 {}}
func grant_clear(dungeon: Dictionary, rng: RandomNumberGenerator, today: String = "") -> Dictionary:
	if today == "":
		today = today_key()
	var rw: Dictionary = dungeon.get("rewards", {})
	var dup := int(rw.get("duplicate_silver_per_fragment", 50))
	var result := {"fragments": [], "silver": int(rw.get("silver", 0)), "pity_bonus": {}}
	for f in roll_fragments(dungeon, rng):
		var unlocked := add_fragments(f["art"], int(f["amount"]), dup)
		result["fragments"].append({"art": f["art"], "amount": f["amount"], "unlocked": unlocked})
	if equipment and int(result["silver"]) > 0:
		equipment.add_currency("silver", int(result["silver"]))
	var r := _record(dungeon["id"], today)
	r["clears"] = int(r["clears"]) + 1
	# 천장 장치 자리: 클리어 n회마다 개방에 가장 가까운 미개방 무공 조각 추가 (테스트용 수치)
	var pity: Dictionary = dungeon.get("pity", {})
	if int(pity.get("clears", 0)) > 0:
		r["pity"] = int(r["pity"]) + 1
		if int(r["pity"]) >= int(pity["clears"]):
			r["pity"] = 0
			var target := _closest_locked(rw.get("pool", []))
			if target != "":
				var amount := int(pity.get("bonus_fragments", 0))
				var unlocked := add_fragments(target, amount, dup)
				result["pity_bonus"] = {"art": target, "amount": amount, "unlocked": unlocked}
	return result


func _closest_locked(pool: Array) -> String:
	var best := ""
	var best_left := 1 << 30
	for e in pool:
		var a: String = e["art"]
		if arts.is_unlocked(a):
			continue
		var left := required_of(a) - fragments_of(a)
		if left < best_left:
			best_left = left
			best = a
	return best
