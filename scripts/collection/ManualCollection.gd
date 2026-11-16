extends RefCounted
class_name ManualCollection
## 비급 조각과 비급 던전 기록 (M9, docs/04, docs/07).
## - 비급 조각은 무공별 아이템이다 (확정 사항 13). 필요 개수를 채우면 무공을 개방한다.
## - 이미 개방한 무공의 조각은 은냥으로 바꾼다 (가안, O-16).
## - 던전 입장 제한(하루 횟수), 천장 장치 자리(클리어 n회마다 추가 조각, 테스트용 수치, O-15).
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
func can_enter(dungeon: Dictionary, highest_cleared: Dictionary, today: String = "") -> Dictionary:
	var req: Dictionary = dungeon.get("entry", {}).get("required_cleared", {})
	if not req.is_empty() and int(highest_cleared.get(req.get("region", ""), 0)) < int(req.get("stage", 0)):
		return {"ok": false, "reason": "스테이지 %d 돌파 후 입장" % int(req.get("stage", 0))}
	if entries_left(dungeon, today) <= 0:
		return {"ok": false, "reason": "오늘 입장 횟수를 모두 썼습니다"}
	return {"ok": true, "reason": ""}


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
