extends MenuPanel
class_name DungeonPanel
## 던전 화면 (M9): 비급 던전 입장, 남은 입장 횟수, 천장 진행, 무공 도감 바로가기.
## 장비/재화 던전은 MVP 이후라 안내만 한다.

signal codex_requested()

var battle: Node2D
var collection: ManualCollection
var message := ""
var _status: Label


func _init(battle_manager: Node2D) -> void:
	super._init("던전")
	battle = battle_manager


func on_open() -> void:
	collection = battle.collection
	message = ""
	_rebuild()


func _process(_delta: float) -> void:
	if visible and _status:
		_update_status()


func _rebuild() -> void:
	clear_root()
	var ids: Array = DataRegistry.dungeons.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = DataRegistry.get_dungeon(id)
		root.add_child(label(d.get("name", id), 24, Color(1, 0.9, 0.6)))
		root.add_child(label(d.get("description", ""), 16, Color(0.8, 0.8, 0.88)))
		var names: PackedStringArray = []
		for e in d.get("rewards", {}).get("pool", []):
			names.append(DataRegistry.get_martial_art(e["art"]).get("name", e["art"]))
		root.add_child(label("보상: %s 비급 조각 · 은냥 %s" % [", ".join(names), fmt(int(d.get("rewards", {}).get("silver", 0)))], 16))
		_status = label("", 16)
		root.add_child(_status)
		var enter := button("입장", 24)
		enter.custom_minimum_size = Vector2(0, 64)
		enter.pressed.connect(_enter.bind(id))
		root.add_child(enter)
	if message != "":
		root.add_child(label(message, 18, Color(1, 0.75, 0.5)))
	root.add_child(HSeparator.new())
	var codex := button("무공 도감", 22)
	codex.pressed.connect(func(): codex_requested.emit())
	root.add_child(codex)
	root.add_child(label("장비 던전, 재화 던전은 MVP 이후 추가 예정입니다.", 16, Color(0.7, 0.7, 0.75)))
	_update_status()


func _update_status() -> void:
	if collection == null or DataRegistry.dungeons.is_empty():
		return
	var ids: Array = DataRegistry.dungeons.keys()
	ids.sort()
	var d: Dictionary = DataRegistry.get_dungeon(ids[0])
	var pity: Dictionary = d.get("pity", {})
	var t := "오늘 남은 입장 %d / %d · 클리어 %d회" % [collection.entries_left(d), int(d.get("entry", {}).get("daily_limit", 3)), collection.clears_of(d["id"])]
	if int(pity.get("clears", 0)) > 0:
		t += " · 천장 %d / %d (테스트 수치)" % [collection.pity_of(d["id"]), int(pity["clears"])]
	if battle.dungeon != null:
		t += "\n던전 진행 중"
	_status.text = t


func _enter(id: String) -> void:
	var r: Dictionary = battle.start_dungeon(id)
	if r["ok"]:
		close_requested.emit()
	else:
		message = r["reason"]
		_rebuild()
