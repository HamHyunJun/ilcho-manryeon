extends MenuPanel
class_name DungeonPanel
## 던전 화면: 비급/장비/재화 던전 목록과 입장 (docs/09 3. 하단 메뉴).
## 던전마다 난이도 선택, 클리어 조건, 보상 안내, 남은 입장 횟수, 입장·소탕 버튼을 보여 준다.
## 비급 던전에는 천장 진행, 재화 던전에는 오늘 요일 보상과 최고 처치 수를 함께 보여 준다.

signal codex_requested()

var battle: Node2D
var collection: ManualCollection
var message := ""
## 던전 ID → 고른 난이도
var selected_level: Dictionary = {}
## 던전 ID → 상태 Label (진행 중 갱신)
var _status: Dictionary = {}
var _result_label: Label


func _init(battle_manager: Node2D) -> void:
	super._init("던전")
	battle = battle_manager


func on_open() -> void:
	collection = battle.collection
	message = ""
	_rebuild()


func _process(_delta: float) -> void:
	if visible and not _status.is_empty():
		_update_status()


## 던전 ID를 표시 순서(order)대로
func dungeon_ids() -> Array:
	var ids: Array = DataRegistry.dungeons.keys()
	ids.sort_custom(func(a, b):
		var oa := int(DataRegistry.get_dungeon(a).get("order", 99))
		var ob := int(DataRegistry.get_dungeon(b).get("order", 99))
		return oa < ob if oa != ob else String(a) < String(b))
	return ids


## 고른 난이도. 처음에는 열려 있는 가장 높은 난이도
func level_of(id: String) -> int:
	if selected_level.has(id):
		return int(selected_level[id])
	var d: Dictionary = DataRegistry.get_dungeon(id)
	var lv := 1
	if collection:
		for l in range(1, DungeonRules.max_level(d) + 1):
			if collection.level_lock_reason(d, battle.stage.highest_cleared, l) == "":
				lv = l
	return lv


func _rebuild() -> void:
	clear_root()
	_status.clear()
	_result_label = label("", 17, Color(0.75, 0.95, 0.75))
	root.add_child(_result_label)
	if message != "":
		root.add_child(label(message, 18, Color(1, 0.75, 0.5)))
	for id in dungeon_ids():
		_build_card(id)
	var codex := button("무공 도감", 22)
	codex.pressed.connect(func(): codex_requested.emit())
	root.add_child(codex)
	_update_status()


func _build_card(id: String) -> void:
	var base: Dictionary = DataRegistry.get_dungeon(id)
	var lv := level_of(id)
	var d := DungeonRules.resolve(base, lv)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.2, 0.9)
	sb.border_color = Color(0.45, 0.38, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var kind: String = {"manual": "비급 던전", "equipment": "장비 던전", "currency": "재화 던전"}.get(String(base.get("type", "")), "던전")
	box.add_child(label("%s · %s" % [kind, base.get("name", id)], 24, Color(1, 0.9, 0.6)))
	box.add_child(label(base.get("description", ""), 16, Color(0.8, 0.8, 0.88)))

	# 난이도 선택
	if DungeonRules.max_level(base) > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var prev := button("◀", 22)
		prev.custom_minimum_size = Vector2(64, 52)
		prev.disabled = lv <= 1
		prev.pressed.connect(_change_level.bind(id, -1))
		row.add_child(prev)
		var name_label := label("난이도 %d · %s (적 ×%s)" % [lv, d.get("difficulty_name", ""), str(snappedf(float(d["battle"].get("scaling", 1.0)), 0.01))], 20)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var next := button("▶", 22)
		next.custom_minimum_size = Vector2(64, 52)
		next.disabled = lv >= DungeonRules.max_level(base)
		next.pressed.connect(_change_level.bind(id, 1))
		row.add_child(next)
		box.add_child(row)

	box.add_child(label(DungeonRules.clear_text(d), 16))
	box.add_child(label(DungeonRules.reward_preview(d, battle.equipment), 16, Color(0.95, 0.88, 0.65)))
	var status := label("", 16)
	box.add_child(status)
	_status[id] = status

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var enter := button("입장", 24)
	enter.custom_minimum_size = Vector2(0, 64)
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.pressed.connect(_enter.bind(id))
	buttons.add_child(enter)
	if bool(base.get("sweep", false)):
		var sweep := button("소탕", 24)
		sweep.custom_minimum_size = Vector2(0, 64)
		sweep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sweep.disabled = collection == null or collection.best_level_of(id) < lv
		sweep.tooltip_text = "한 번 클리어한 난이도를 전투 없이 클리어 (입장 1회 사용)"
		sweep.pressed.connect(_sweep.bind(id))
		buttons.add_child(sweep)
	box.add_child(buttons)


func _update_status() -> void:
	if collection == null:
		return
	for id in _status.keys():
		var d: Dictionary = DataRegistry.get_dungeon(id)
		var lv := level_of(id)
		var t := "오늘 남은 입장 %d / %d · 클리어 %d회" % [collection.entries_left(d), int(d.get("entry", {}).get("daily_limit", 3)), collection.clears_of(id)]
		var pity: Dictionary = d.get("pity", {})
		if int(pity.get("clears", 0)) > 0:
			t += " · 천장 %d / %d (테스트 수치)" % [collection.pity_of(id), int(pity["clears"])]
		if DungeonRules.clear_type(d) == "time_attack":
			t += " · 최고 처치 %d" % collection.best_kills_of(id, lv)
		var lock := collection.level_lock_reason(d, battle.stage.highest_cleared, lv)
		if lock != "":
			t += "\n잠김: " + lock
		if battle.dungeon != null and battle.dungeon.data.get("id", "") == id:
			t += "\n던전 진행 중 · " + battle.dungeon.progress_text()
		_status[id].text = t
	if _result_label:
		_result_label.text = last_result_text()


## 최근 던전 결과 한 줄 (없으면 빈 문자열)
func last_result_text() -> String:
	var r: Dictionary = battle.last_dungeon_result
	if r.is_empty():
		return ""
	var d: Dictionary = DataRegistry.get_dungeon(String(r.get("dungeon", "")))
	var name := String(d.get("name", "던전"))
	if not r.get("cleared", false):
		return "최근 결과: %s 실패 (%s)" % [name, r.get("reason", "")]
	return "최근 결과: %s %s · %s" % [name, "소탕" if r.get("sweep", false) else "클리어", r.get("text", "")]


func _change_level(id: String, delta: int) -> void:
	var d: Dictionary = DataRegistry.get_dungeon(id)
	selected_level[id] = clampi(level_of(id) + delta, 1, DungeonRules.max_level(d))
	message = ""
	_rebuild()


func _enter(id: String) -> void:
	var r: Dictionary = battle.start_dungeon(id, "", level_of(id))
	if r["ok"]:
		close_requested.emit()
	else:
		message = r["reason"]
		_rebuild()


func _sweep(id: String) -> void:
	var r: Dictionary = battle.sweep_dungeon(id, level_of(id))
	message = ("소탕 완료: " + r["text"]) if r["ok"] else r["reason"]
	_rebuild()
