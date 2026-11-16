extends Node
## 게임 정적 데이터(JSON)를 한곳에서 읽고 검증하는 레지스트리.
## 무공, 초식, 몬스터, 장비 등은 코드에 하드코딩하지 않고 res://data 아래 JSON으로 관리한다.
## 데이터는 시작 시 한 번 읽어 메모리에 캐시한다.

const DATA_ROOT := "res://data"

## 무공 ID → 무공 데이터(Dictionary). 초식은 무공 데이터 안의 "techniques" 배열에 있다.
var martial_arts: Dictionary = {}
## 초식 ID → 초식 데이터(Dictionary). 빠른 조회용 색인
var techniques: Dictionary = {}
## 몬스터 ID → 몬스터 데이터(Dictionary)
var monsters: Dictionary = {}
## 지역 ID → 지역 스테이지 데이터(Dictionary). data/stages/*.json
var regions: Dictionary = {}
## 공통 수치 파일 이름(확장자 제외) → 내용. 예: "training"
var balance: Dictionary = {}
## 이펙트 데이터 파일 이름(확장자 제외) → 내용. 예: "effect_presets" (M6)
var effects: Dictionary = {}
## 장비 데이터 (data/equipment/equipment.json, M8). 부위, 등급, 옵션, 강화, 드롭
var equipment: Dictionary = {}
## 로드/검증 중 발견한 오류 메시지 목록
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


## 모든 데이터를 다시 읽는다. 반환값은 오류 수.
func load_all(root: String = DATA_ROOT) -> int:
	martial_arts.clear()
	techniques.clear()
	monsters.clear()
	regions.clear()
	balance.clear()
	effects.clear()
	equipment.clear()
	errors.clear()

	for path in _list_json(root.path_join("martial_arts")):
		var data = _read_json(path)
		if data is Dictionary:
			_register_martial_art(data, path)

	for path in _list_json(root.path_join("monsters")):
		var data = _read_json(path)
		if data is Dictionary:
			_register_monsters(data, path)

	# 스테이지는 몬스터 ID를 참조하므로 몬스터 다음에 읽는다
	for path in _list_json(root.path_join("stages")):
		var data = _read_json(path)
		if data is Dictionary:
			_register_region(data, path)

	for path in _list_json(root.path_join("balance")):
		var data = _read_json(path)
		if data is Dictionary:
			balance[path.get_file().get_basename()] = data

	for path in _list_json(root.path_join("effects")):
		var data = _read_json(path)
		if data is Dictionary:
			effects[path.get_file().get_basename()] = data
	# 이펙트 프리셋이 있으면 검증한다 (없으면 연출 없이 동작)
	if effects.has("effect_presets"):
		for e in EffectPresets.validate(effects["effect_presets"]):
			errors.append("effects: " + e)

	for path in _list_json(root.path_join("equipment")):
		var data = _read_json(path)
		if data is Dictionary:
			equipment = data
			_validate_equipment(path)

	for e in errors:
		push_error("[DataRegistry] " + e)

	# EventBus는 오토로드 환경에서만 존재한다 (테스트에서 단독 생성 시 생략)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").data_loaded.emit(errors.size())
	return errors.size()


## 장비 데이터 검증: 5부위, 6등급, 옵션 항목
func _validate_equipment(path: String) -> void:
	var slots: Array = equipment.get("slots", [])
	if slots.size() != 5:
		errors.append("%s: 장비 부위는 5개여야 함 (현재 %d)" % [path, slots.size()])
	var grades: Array = equipment.get("grades", [])
	if grades.size() != 6:
		errors.append("%s: 장비 등급은 6개여야 함 (현재 %d)" % [path, grades.size()])
	for o in equipment.get("options", []):
		if not o.has("id") or not (o.has("stat") or o.has("effect")):
			errors.append("%s: 옵션에 id와 stat/effect가 필요함" % path)
		var tg: Dictionary = o.get("target", {})
		if tg.get("type", "all") == "art" and not martial_arts.has(tg.get("id", "")):
			errors.append("%s: 옵션 %s의 대상 무공 없음: %s" % [path, o.get("id", ""), tg.get("id", "")])


func get_martial_art(id: String) -> Dictionary:
	return martial_arts.get(id, {})


func get_technique(id: String) -> Dictionary:
	return techniques.get(id, {})


func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})


func get_region(id: String) -> Dictionary:
	return regions.get(id, {})


## 지역 스테이지 파일을 검증해 등록한다. 참조하는 몬스터/보스가 실제로 있는지도 확인한다.
func _register_region(data: Dictionary, path: String) -> void:
	for key in ["region_id", "name", "stages"]:
		if not data.has(key):
			errors.append("%s: 필수 항목 '%s' 없음" % [path, key])
			return
	if not (data["stages"] is Array) or data["stages"].is_empty():
		errors.append("%s: 스테이지가 하나도 없음" % path)
		return
	if regions.has(data["region_id"]):
		errors.append("%s: 지역 ID 중복 '%s'" % [path, data["region_id"]])
		return
	var ok := true
	var seen := {}
	for s in data["stages"]:
		if not (s is Dictionary):
			errors.append("%s: 스테이지 항목 형식 오류" % path)
			ok = false
			continue
		for key in ["stage_no", "kills_to_boss", "spawn_pool", "scaling", "boss"]:
			if not s.has(key):
				errors.append("%s: 스테이지 %s에 필수 항목 '%s' 없음" % [path, s.get("stage_no", "?"), key])
				ok = false
		if not ok:
			continue
		var no := int(s["stage_no"])
		if seen.has(no):
			errors.append("%s: 스테이지 번호 중복 %d" % [path, no])
			ok = false
		seen[no] = true
		if not (s["spawn_pool"] is Array) or s["spawn_pool"].is_empty():
			errors.append("%s: 스테이지 %d 생성 목록이 비어 있음" % [path, no])
			ok = false
			continue
		for e in s["spawn_pool"]:
			if not monsters.has(e.get("monster", "")):
				errors.append("%s: 스테이지 %d에서 없는 몬스터 '%s' 참조" % [path, no, e.get("monster", "")])
				ok = false
		var boss: Dictionary = monsters.get(s["boss"], {})
		if boss.is_empty() or boss.get("type", "") != "boss":
			errors.append("%s: 스테이지 %d의 보스 '%s'가 없거나 보스 유형이 아님" % [path, no, s["boss"]])
			ok = false
	if not ok:
		return
	data["stages"].sort_custom(func(a, b): return int(a["stage_no"]) < int(b["stage_no"]))
	regions[data["region_id"]] = data


## 몬스터 목록 파일을 검증해 등록한다. 형식: {"monsters": [ {...}, ... ]}
func _register_monsters(data: Dictionary, path: String) -> void:
	if not (data.get("monsters") is Array):
		errors.append("%s: 'monsters' 배열 없음" % path)
		return
	for m in data["monsters"]:
		if not (m is Dictionary):
			errors.append("%s: 몬스터 항목 형식 오류" % path)
			continue
		var missing := false
		for key in ["id", "name", "type", "max_hp", "atk", "def", "move_speed", "attack_range", "attack_interval"]:
			if not m.has(key):
				errors.append("%s: 몬스터 '%s'에 필수 항목 '%s' 없음" % [path, m.get("id", "?"), key])
				missing = true
		if missing:
			continue
		if monsters.has(m["id"]):
			errors.append("%s: 몬스터 ID 중복 '%s'" % [path, m["id"]])
			continue
		monsters[m["id"]] = m


## 무공 데이터를 검증해 등록한다. 필수 항목이 없으면 등록하지 않는다.
func _register_martial_art(data: Dictionary, path: String) -> void:
	for key in ["id", "name", "category", "techniques"]:
		if not data.has(key):
			errors.append("%s: 필수 항목 '%s' 없음" % [path, key])
			return
	var id: String = data["id"]
	if martial_arts.has(id):
		errors.append("%s: 무공 ID 중복 '%s'" % [path, id])
		return
	if not (data["techniques"] is Array) or data["techniques"].is_empty():
		errors.append("%s: 초식이 하나도 없음" % path)
		return

	var orders := {}
	for t in data["techniques"]:
		if not (t is Dictionary) or not t.has("id") or not t.has("order"):
			errors.append("%s: 초식에 id 또는 order 없음" % path)
			return
		if techniques.has(t["id"]):
			errors.append("%s: 초식 ID 중복 '%s'" % [path, t["id"]])
			return
		if orders.has(int(t["order"])):
			errors.append("%s: 초식 순서 중복 %d" % [path, int(t["order"])])
			return
		orders[int(t["order"])] = true

	# 해금 순서대로 정렬해 둔다
	data["techniques"].sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	martial_arts[id] = data
	for t in data["techniques"]:
		techniques[t["id"]] = t


func _read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: 파일을 읽을 수 없거나 비어 있음" % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: JSON 오류 (%d행) %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## 폴더 안의 .json 파일 경로 목록 (이름순)
func _list_json(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for f in dir.get_files():
		if f.ends_with(".json"):
			result.append(dir_path.path_join(f))
	result.sort()
	return result
