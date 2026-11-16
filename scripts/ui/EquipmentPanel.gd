extends MenuPanel
class_name EquipmentPanel
## 장비 화면 (M8): 5부위 장착 현황, 선택 장비 상세(기본 능력치, 옵션), 장착/해제, 강화, 버리기, 보관함.
## 디버그: 장비 받기, 재화 받기.
## 임시 UI: 기본 테마를 쓰며, 정식 UI 작업 때 바꾼다.

const STAT_NAMES := {"atk": "공격력", "def": "방어력", "max_hp": "체력", "crit_rate": "치명타 확률", "crit_mult": "치명타 피해", "mp_regen": "내공 회복", "max_mp": "내공"}
const RESULT_TEXT := {0: "강화 성공", 1: "최대 강화 단계입니다", 2: "강화석 또는 은냥이 부족합니다", 3: "장비가 없습니다", 4: "강화 실패"}

var equipment: EquipmentManager
var selected_uid := 0
var message := ""
var _wallet_label: Label
var _rng := RandomNumberGenerator.new()


func _init(equipment_manager: EquipmentManager) -> void:
	super._init("장비")
	equipment = equipment_manager
	_rng.randomize()


func _ready() -> void:
	equipment.inventory_changed.connect(_rebuild)
	equipment.equipment_changed.connect(_rebuild)


func on_open() -> void:
	message = ""
	_rebuild()


func _process(_delta: float) -> void:
	if visible and _wallet_label:
		_wallet_label.text = "은냥 %s · 강화석 %s · 보관함 %d / %d" % [fmt(equipment.silver()), fmt(equipment.stone()), equipment.items().size(), equipment.capacity()]


func _rebuild() -> void:
	if not visible:
		return
	clear_root()
	_wallet_label = label("", 18, Color(1, 0.9, 0.6))
	root.add_child(_wallet_label)
	_build_slots()
	root.add_child(HSeparator.new())
	_build_detail()
	root.add_child(HSeparator.new())
	_build_inventory()
	root.add_child(HSeparator.new())
	if OS.is_debug_build():
		_build_debug()
	_process(0.0)


func _item_button(it: Dictionary, text: String, size: int) -> Button:
	var b := button(text, size)
	if not it.is_empty():
		var c := equipment.grade_color(it["grade"])
		b.add_theme_color_override("font_color", c)
		b.add_theme_color_override("font_hover_color", c.lightened(0.2))
	return b


func _build_slots() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	for slot in equipment.slot_ids():
		var it := equipment.equipped_item(slot)
		var sname: String = equipment.slot_data(slot).get("name", slot)
		var text := "%s\n%s" % [sname, "비어 있음" if it.is_empty() else equipment.item_name(it).trim_suffix(" " + sname)]
		var b := _item_button(it, text, 16)
		b.custom_minimum_size = Vector2(126, 64)
		b.disabled = it.is_empty()
		if not it.is_empty():
			b.pressed.connect(_select.bind(int(it["uid"])))
		row.add_child(b)


func _build_detail() -> void:
	var it := equipment.find(selected_uid)
	if it.is_empty():
		root.add_child(label("장비를 고르면 능력치와 옵션이 나옵니다.", 16, Color(0.75, 0.75, 0.8)))
		if message != "":
			root.add_child(label(message, 16, Color(1, 0.8, 0.5)))
		return
	var name_l := label(equipment.item_name(it) + ("  (장착 중)" if equipment.is_equipped(selected_uid) else ""), 22, equipment.grade_color(it["grade"]))
	root.add_child(name_l)
	var lines: PackedStringArray = []
	var bs := equipment.item_base_stats(it)
	for stat in bs.keys():
		var v := float(bs[stat])
		lines.append("%s +%s" % [STAT_NAMES.get(stat, stat), ("%.1f%%" % (v * 100.0)) if stat == "crit_rate" else str(roundi(v))])
	for o in it.get("options", []):
		lines.append("· " + equipment.option_text(o))
	root.add_child(label("\n".join(lines), 17))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	if equipment.is_equipped(selected_uid):
		var un := button("해제", 18)
		un.pressed.connect(func(): equipment.unequip(it["slot"]))
		row.add_child(un)
	else:
		var eq := button("장착", 18)
		eq.pressed.connect(func(): equipment.equip(selected_uid))
		row.add_child(eq)
	var cost := equipment.enhance_cost(it)
	var enh_text := "강화 (최대)" if int(it["enh"]) >= equipment.max_enhance() else "강화 +%d → +%d\n강화석 %d · 은냥 %s" % [int(it["enh"]), int(it["enh"]) + 1, int(cost["stone"]), fmt(int(cost["silver"]))]
	var en := button(enh_text, 16)
	en.pressed.connect(_enhance)
	row.add_child(en)
	var dis := button("버리기", 18)
	dis.disabled = equipment.is_equipped(selected_uid)
	dis.pressed.connect(func():
		equipment.discard(selected_uid)
		selected_uid = 0)
	row.add_child(dis)
	if message != "":
		root.add_child(label(message, 16, Color(1, 0.8, 0.5)))


func _build_inventory() -> void:
	root.add_child(label("보관함 (등급순)", 20))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	var arr := equipment.sorted_items()
	if arr.is_empty():
		root.add_child(label("아직 장비가 없습니다. 몬스터와 보스가 떨어뜨립니다.", 16, Color(0.75, 0.75, 0.8)))
	for it in arr:
		var mark := "[장착] " if equipment.is_equipped(int(it["uid"])) else ""
		var b := _item_button(it, mark + equipment.item_name(it), 15)
		b.custom_minimum_size = Vector2(160, 44)
		b.pressed.connect(_select.bind(int(it["uid"])))
		grid.add_child(b)


func _select(uid: int) -> void:
	selected_uid = uid
	message = ""
	_rebuild()


func _enhance() -> void:
	var r := equipment.enhance(selected_uid, _rng)
	message = RESULT_TEXT.get(r, "")
	_rebuild()


func _build_debug() -> void:
	root.add_child(label("디버그 도구", 18, Color(1, 0.7, 0.4)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	var give := button("장비 10개 받기", 18)
	give.pressed.connect(_debug_give)
	row.add_child(give)
	var money := button("강화석 +100 · 은냥 +10,000", 18)
	money.pressed.connect(func():
		equipment.add_currency("stone", 100)
		equipment.add_currency("silver", 10000))
	row.add_child(money)


func _debug_give() -> void:
	var slots := equipment.slot_ids()
	for i in 10:
		var grade: String = equipment.cfg["grades"][i % 6]["id"]
		equipment.add_item(equipment.generate(slots[i % slots.size()], grade, 1.0, _rng))
