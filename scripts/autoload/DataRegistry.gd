extends Node
## 게임 정적 데이터(JSON)를 한곳에서 읽고 검증하는 레지스트리.
## 무공, 초식, 몬스터, 장비 등은 코드에 하드코딩하지 않고 res://data 아래 JSON으로 관리한다.
## 데이터는 시작 시 한 번 읽어 메모리에 캐시한다.

const DATA_ROOT := "res://data"

## 무공 ID → 무공 데이터(Dictionary). 초식은 무공 데이터 안의 "techniques" 배열에 있다.
var martial_arts: Dictionary = {}
## 초식 ID → 초식 데이터(Dictionary). 빠른 조회용 색인
var techniques: Dictionary = {}
## 공통 수치 파일 이름(확장자 제외) → 내용. 예: "training"
var balance: Dictionary = {}
## 로드/검증 중 발견한 오류 메시지 목록
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


## 모든 데이터를 다시 읽는다. 반환값은 오류 수.
func load_all(root: String = DATA_ROOT) -> int:
	martial_arts.clear()
	techniques.clear()
	balance.clear()
	errors.clear()

	for path in _list_json(root.path_join("martial_arts")):
		var data = _read_json(path)
		if data is Dictionary:
			_register_martial_art(data, path)

	for path in _list_json(root.path_join("balance")):
		var data = _read_json(path)
		if data is Dictionary:
			balance[path.get_file().get_basename()] = data

	for e in errors:
		push_error("[DataRegistry] " + e)

	# EventBus는 오토로드 환경에서만 존재한다 (테스트에서 단독 생성 시 생략)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").data_loaded.emit(errors.size())
	return errors.size()


func get_martial_art(id: String) -> Dictionary:
	return martial_arts.get(id, {})


func get_technique(id: String) -> Dictionary:
	return techniques.get(id, {})


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
