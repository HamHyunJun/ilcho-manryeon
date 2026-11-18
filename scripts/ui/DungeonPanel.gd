extends MenuPanel
class_name DungeonPanel
## 던전 화면: 비급/장비/재화 던전 목록과 입장 (docs/09 3. 하단 메뉴).
## 카드는 짧게: 던전 이름, 남은 입장, 난이도 선택, 입장·소탕 버튼만 보여 준다.
## 잠긴 난이도는 입장 버튼에 "잠김"으로, 진행 중이면 "진행 중"으로 표시한다.

signal codex_requested()

var battle: Node2D
var collection: ManualCollection
var message := ""
## 던전 ID → 고른 난이도
var selected_level: Dictionary = {}
## 던전 ID → 상태 Label (진행 중 갱신)
var _status: Dictionary = {}
## 던전 ID → 입장 버튼 (잠김/진행 중이면 글자를 바꾼다)
var _enter_buttons: Dictionary = {}
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
	_enter_buttons.clear()
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
	var sb := InkBox.new()
	sb.bg_color = Color(0.1, 0.1, 0.095, 0.92)
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

	# 첫 줄: 던전 이름(왼쪽) + 남은 입장(오른쪽)
	var head := HBoxContainer.new()
	var title := label(display_name(base, id), 28, Color(1, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var status := label("", 20)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(status)
	box.add_child(head)
	_status[id] = status

	# 난이도 선택: ◀ 초급 ▶
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var many := DungeonRules.max_level(base) > 1
	var prev := button("◀", 22)
	prev.custom_minimum_size = Vector2(64, 52)
	prev.disabled = not many or lv <= 1
	prev.pressed.connect(_change_level.bind(id, -1))
	row.add_child(prev)
	var name_label := label(String(d.get("difficulty_name", "")), 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var next := button("▶", 22)
	next.custom_minimum_size = Vector2(64, 52)
	next.disabled = not many or lv >= DungeonRules.max_level(base)
	next.pressed.connect(_change_level.bind(id, 1))
	row.add_child(next)
	box.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var enter := button("입장", 24)
	enter.custom_minimum_size = Vector2(0, 64)
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.pressed.connect(_enter.bind(id))
	_enter_buttons[id] = enter
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
		_status[id].text = "입장 %d/%d" % [collection.entries_left(d), int(d.get("entry", {}).get("daily_limit", 3))]
		if _enter_buttons.has(id):
			var enter: Button = _enter_buttons[id]
			var running: bool = battle.dungeon != null and battle.dungeon.data.get("id", "") == id
			if running:
				enter.text = "진행 중"
			elif collection.level_lock_reason(d, battle.stage.highest_cleared, lv) != "":
				enter.text = "잠김"
			else:
				enter.text = "입장"
	if _result_label:
		_result_label.text = last_result_text()


## 카드에 보일 이름: 뒤의 "(임시)" 같은 꼬리표를 뗀다
static func display_name(d: Dictionary, id: String) -> String:
	var n := String(d.get("name", id))
	var i := n.find(" (")
	return n.substr(0, i) if i > 0 else n


## 최근 던전 결과 한 줄 (없으면 빈 문자열)
func last_result_text() -> String:
	var r: Dictionary = battle.last_dungeon_result
	if r.is_empty():
		return ""
	var d: Dictionary = DataRegistry.get_dungeon(String(r.get("dungeon", "")))
	var name := display_name(d, "던전")
	if not r.get("cleared", false):
		return "최근: %s 실패" % name
	return "최근: %s %s" % [name, "소탕" if r.get("sweep", false) else "클리어"]


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
