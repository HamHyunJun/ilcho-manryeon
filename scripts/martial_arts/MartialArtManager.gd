extends RefCounted
class_name MartialArtManager
## 무공 장착, 개방, 초식 수련 기록을 관리한다 (M3).
## 저장 데이터의 "martial_arts" Dictionary(docs/10 3장)를 직접 읽고 쓴다.
##
## 핵심 규칙 (확정):
## - 수련 기록은 무공 ID → 초식 ID → 진행도 구조로 저장하고, 장착 정보와 분리한다.
##   무공을 바꿔도 기록은 절대 초기화되지 않는다 (docs/03 2장).
## - 초식은 주력 무공의 것만 발동·수련한다. 보조 무공은 패시브만 준다 (확정 사항 20).
## - 수련 중인 초식 = 아직 대성하지 못한 가장 앞 초식. 모두 대성했으면 마지막 초식 (확정 사항 22, 26).
## - 정상 발동 1회마다 +1 × 수련 배율. 빗나가도 발동했으면 센다 (확정 사항 28). 소수는 fraction에 누적.
## - 대성 목표에 도달하면 대성, 다음 초식 해금.

signal technique_progressed(technique_id: String, count: int)
signal technique_mastered(technique_id: String)
signal equipment_changed()

const SUB_SLOTS := 2

## 저장 데이터의 martial_arts 부분 (참조로 공유)
var state: Dictionary
## DataRegistry (오토로드 또는 테스트용 인스턴스)
var registry


func _init(martial_arts_state: Dictionary, data_registry) -> void:
	state = martial_arts_state
	registry = data_registry
	if not state.has("equipped"):
		state["equipped"] = {"main": "", "sub": [null, null]}
	if not state.has("progress"):
		state["progress"] = {}
	if not state.has("chain_mode"):
		state["chain_mode"] = false


## 새 게임 상태를 만든다. start_art는 처음 지급하는 무공 (매화검법, 확정 사항 29).
static func new_state(start_art: String) -> Dictionary:
	return {
		"equipped": {"main": start_art, "sub": [null, null]},
		"chain_mode": false,
		"training_target": "",
		"progress": {},
	}


# ---- 개방 ----

func is_unlocked(art_id: String) -> bool:
	return bool(state["progress"].get(art_id, {}).get("unlocked", false))


## 무공을 개방한다. 처음 개방하면 1초식만 해금된 상태로 시작한다 (docs/03 3장 가안).
## 이미 기록이 있으면 아무것도 바꾸지 않는다.
func unlock(art_id: String) -> bool:
	var art: Dictionary = registry.get_martial_art(art_id)
	if art.is_empty():
		return false
	var prog: Dictionary = state["progress"].get(art_id, {})
	if prog.is_empty():
		prog = {"unlocked": true, "unlocked_at_unix": int(Time.get_unix_time_from_system()), "techniques": {}}
		state["progress"][art_id] = prog
	prog["unlocked"] = true
	var techs: Array = art["techniques"]
	for t in techs:
		_tech_progress(art_id, t["id"])
	state["progress"][art_id]["techniques"][techs[0]["id"]]["unlocked"] = true
	return true


func unlocked_arts() -> Array:
	var ids: Array = []
	for id in state["progress"].keys():
		if is_unlocked(id):
			ids.append(id)
	ids.sort()
	return ids


# ---- 장착 ----

func main_art() -> String:
	return state["equipped"].get("main", "")


func sub_arts() -> Array:
	return state["equipped"]["sub"]


## 주력 무공으로 장착한다. 보조에 있던 무공이면 보조 칸에서 뺀다 (같은 무공 동시 장착 불가, 가안).
func equip_main(art_id: String) -> bool:
	if not is_unlocked(art_id):
		return false
	var subs: Array = state["equipped"]["sub"]
	for i in subs.size():
		if subs[i] == art_id:
			subs[i] = null
	state["equipped"]["main"] = art_id
	refresh_training_target()
	equipment_changed.emit()
	return true


## 보조 칸(0, 1)에 장착한다. null이면 비운다. 주력과 같은 무공은 장착할 수 없다 (가안).
func equip_sub(slot: int, art_id) -> bool:
	if slot < 0 or slot >= SUB_SLOTS:
		return false
	if art_id != null:
		if not is_unlocked(art_id) or art_id == main_art():
			return false
		var subs: Array = state["equipped"]["sub"]
		for i in subs.size():
			if subs[i] == art_id:
				subs[i] = null
	state["equipped"]["sub"][slot] = art_id
	equipment_changed.emit()
	return true


## 보조 무공 패시브 합계. {능력치: {"flat": n, "percent": n}}
## 패시브 값은 무공 데이터의 passive_as_sub (무공별 고정값, 가안 O-09)
func sub_passives() -> Dictionary:
	var total := {}
	for art_id in sub_arts():
		if art_id == null:
			continue
		for p in registry.get_martial_art(art_id).get("passive_as_sub", []):
			var stat: String = p["stat"]
			if not total.has(stat):
				total[stat] = {"flat": 0.0, "percent": 0.0}
			var kind: String = p.get("type", "flat")
			total[stat][kind] = float(total[stat][kind]) + float(p["value"])
	return total


# ---- 초식 ----

## 무공의 초식 데이터 목록 (해금 순서)
func techniques_of(art_id: String) -> Array:
	return registry.get_martial_art(art_id).get("techniques", [])


func progress_of(tech_id: String) -> Dictionary:
	var art_id := tech_id.get_slice(".", 0)
	return state["progress"].get(art_id, {}).get("techniques", {}).get(tech_id, {})


func count_of(tech_id: String) -> int:
	return int(progress_of(tech_id).get("count", 0))


func is_mastered(tech_id: String) -> bool:
	return bool(progress_of(tech_id).get("mastered", false))


func is_tech_unlocked(tech_id: String) -> bool:
	return bool(progress_of(tech_id).get("unlocked", false))


## 주력 무공의 해금된 초식 데이터 목록 (해금 순서)
func unlocked_main_techniques() -> Array:
	var result: Array = []
	for t in techniques_of(main_art()):
		if is_tech_unlocked(t["id"]):
			result.append(t)
	return result


## 수련 중인 초식 ID: 주력 무공에서 아직 대성하지 못한 가장 앞 해금 초식.
## 모두 대성했으면 마지막 초식 (확정 사항 26).
func training_target() -> String:
	var techs := techniques_of(main_art())
	if techs.is_empty():
		return ""
	for t in techs:
		if is_tech_unlocked(t["id"]) and not is_mastered(t["id"]):
			return t["id"]
	return techs.back()["id"]


## 저장 데이터의 training_target 캐시를 다시 계산한다.
func refresh_training_target() -> void:
	state["training_target"] = training_target()


func mastery_target_of(tech_id: String) -> int:
	return int(registry.get_technique(tech_id).get("mastery_target", 10000))


## 초식이 정상 발동했음을 기록한다. 주력 무공 초식만 센다.
## multiplier: 수련 배율 (기본 1.0, 가속 효과 등은 곱해서 넘긴다)
## 반환값: 이번에 대성했으면 true
func record_performed(tech_id: String, multiplier: float = 1.0) -> bool:
	var art_id := tech_id.get_slice(".", 0)
	if art_id != main_art() or not is_tech_unlocked(tech_id):
		return false
	var p := _tech_progress(art_id, tech_id)
	var total := float(p["fraction"]) + multiplier
	var whole := int(floor(total))
	p["fraction"] = total - whole
	p["count"] = int(p["count"]) + whole
	technique_progressed.emit(tech_id, int(p["count"]))
	return _check_mastery(art_id, tech_id)


## 디버그: 수련 횟수를 직접 정한다. 대성/해금 상태를 다시 계산한다.
func debug_set_count(tech_id: String, count: int) -> void:
	var art_id := tech_id.get_slice(".", 0)
	if not is_unlocked(art_id):
		unlock(art_id)
	var p := _tech_progress(art_id, tech_id)
	p["count"] = maxi(0, count)
	p["fraction"] = 0.0
	p["unlocked"] = true
	if int(p["count"]) < mastery_target_of(tech_id):
		p["mastered"] = false
		p["mastered_at_unix"] = null
	technique_progressed.emit(tech_id, int(p["count"]))
	_check_mastery(art_id, tech_id)
	refresh_training_target()


func _check_mastery(art_id: String, tech_id: String) -> bool:
	var p := _tech_progress(art_id, tech_id)
	if bool(p["mastered"]) or int(p["count"]) < mastery_target_of(tech_id):
		return false
	p["mastered"] = true
	p["mastered_at_unix"] = int(Time.get_unix_time_from_system())
	# 다음 초식 해금
	var techs := techniques_of(art_id)
	for i in techs.size():
		if techs[i]["id"] == tech_id and i + 1 < techs.size():
			_tech_progress(art_id, techs[i + 1]["id"])["unlocked"] = true
	refresh_training_target()
	technique_mastered.emit(tech_id)
	return true


## 초식 진행도 항목을 가져온다. 없으면 기본값으로 만든다 (누락 필드는 기본값, docs/10 4장).
func _tech_progress(art_id: String, tech_id: String) -> Dictionary:
	var prog: Dictionary = state["progress"].get(art_id, {})
	if prog.is_empty():
		prog = {"unlocked": false, "unlocked_at_unix": null, "techniques": {}}
		state["progress"][art_id] = prog
	if not prog.has("techniques"):
		prog["techniques"] = {}
	if not prog["techniques"].has(tech_id):
		prog["techniques"][tech_id] = {"unlocked": false, "count": 0, "fraction": 0.0, "mastered": false, "mastered_at_unix": null}
	return prog["techniques"][tech_id]


# ---- 연속초식 ----

func is_chain_mode() -> bool:
	return bool(state.get("chain_mode", false))


func set_chain_mode(on: bool) -> void:
	state["chain_mode"] = on


## 수련 단계 이름 (입문~대성). 단계는 count에서 계산하고 따로 저장하지 않는다 (docs/10).
static func stage_name_for(count: int, thresholds: Array) -> String:
	var name := ""
	for s in thresholds:
		if count >= int(s["min"]):
			name = s["name"]
	return name
