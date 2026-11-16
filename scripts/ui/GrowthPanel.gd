extends MenuPanel
class_name GrowthPanel
## 육성 화면 (M3 최소 화면 → M5에서 앱바 메뉴로 이동).
## 무공 장착(주력 1, 보조 2), 초식별 수련 횟수와 단계 표시.
## 디버그 도구: 수련 횟수 편집, 시간 배속, 무공 모두 개방, 저장 확인.

var arts: MartialArtManager
## 보고 있는 무공
var selected_art := ""
## 초식 ID → 표시 Label (매 프레임 갱신)
var _tech_labels: Dictionary = {}
var _speed_label: Label
var _save_label: Label
var _char_label: Label


func _init(martial_arts: MartialArtManager) -> void:
	super._init("육성 · 무공")
	arts = martial_arts


func _ready() -> void:
	arts.equipment_changed.connect(_rebuild)
	arts.technique_mastered.connect(func(_id): _rebuild())


func on_open() -> void:
	if selected_art == "":
		selected_art = arts.main_art()
	_rebuild()


func _process(_delta: float) -> void:
	if visible:
		_update_tech_labels()
		_update_save_label()
		_update_character()


func _rebuild() -> void:
	if not visible:
		return
	clear_root()
	_tech_labels.clear()
	_build_character()
	root.add_child(HSeparator.new())
	_build_art_rows()
	root.add_child(HSeparator.new())
	_build_tech_rows()
	root.add_child(HSeparator.new())
	_build_debug()
	_update_tech_labels()


# ---- 캐릭터 레벨과 경지 (M7) ----

func _growth() -> CharacterGrowth:
	var gs = get_node_or_null("/root/GameState")
	return gs.growth if gs else null


func _build_character() -> void:
	root.add_child(label("캐릭터 · 경지", 22))
	_char_label = label("", 18)
	root.add_child(_char_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	for d in [["경험치 +1000", 0], ["레벨 +10", 10]]:
		var b := button(d[0], 16)
		b.pressed.connect(_debug_level.bind(d[1]))
		row.add_child(b)
	_update_character()


func _update_character() -> void:
	var g := _growth()
	if g == null or _char_label == null:
		return
	var nx := g.next_realm()
	var next_text := "최고 경지"
	if not nx.is_empty():
		next_text = "다음 %s: Lv %d · 대성 초식 %d개 (현재 Lv %d · 대성 %d개)" % [nx["name"], int(nx["level"]), int(nx["mastered"]), g.level(), arts.total_mastered()]
	var exp_text := "최대 레벨" if g.level() >= g.level_cap() else "%s / %s" % [fmt(g.current_exp()), fmt(g.exp_to_next())]
	_char_label.text = "%s · Lv %d · 경험치 %s\n%s" % [g.realm().get("name", ""), g.level(), exp_text, next_text]


## 디버그: 0이면 경험치 1000, 그 밖에는 레벨을 n만큼 올린다
func _debug_level(levels: int) -> void:
	var g := _growth()
	if g == null:
		return
	if levels == 0:
		g.add_exp(1000)
	else:
		for i in levels:
			g.add_exp(g.exp_to_next() - g.current_exp())
	_update_character()


func _build_art_rows() -> void:
	var ids: Array = arts.registry.martial_arts.keys()
	ids.sort()
	for art_id in ids:
		var art: Dictionary = arts.registry.get_martial_art(art_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		root.add_child(row)
		var name_btn := button("%s\n%s" % [art["name"], _equip_state(art_id)], 18)
		name_btn.custom_minimum_size = Vector2(230, 64)
		name_btn.toggle_mode = true
		name_btn.button_pressed = art_id == selected_art
		name_btn.pressed.connect(_select.bind(art_id))
		row.add_child(name_btn)
		var unlocked := arts.is_unlocked(art_id)
		var main_btn := button("주력", 18)
		main_btn.disabled = not unlocked or arts.main_art() == art_id
		main_btn.pressed.connect(func(): arts.equip_main(art_id))
		row.add_child(main_btn)
		for slot in MartialArtManager.SUB_SLOTS:
			var in_slot: bool = arts.sub_arts()[slot] == art_id
			var sub_btn := button("보조%d 해제" % (slot + 1) if in_slot else "보조%d" % (slot + 1), 18)
			sub_btn.disabled = not unlocked or arts.main_art() == art_id
			sub_btn.pressed.connect(func(): arts.equip_sub(slot, null if in_slot else art_id))
			row.add_child(sub_btn)


func _select(art_id: String) -> void:
	selected_art = art_id
	_rebuild()


func _build_tech_rows() -> void:
	var sel: Dictionary = arts.registry.get_martial_art(selected_art)
	root.add_child(label("%s 초식 수련 현황" % sel.get("name", ""), 22))
	if not arts.is_unlocked(selected_art):
		root.add_child(label("아직 개방하지 않은 무공입니다."))
		return
	if arts.main_art() != selected_art:
		root.add_child(label("주력이 아니면 초식이 발동하지 않습니다. 보조로 장착하면 패시브만 적용됩니다.", 16, Color(0.75, 0.75, 0.8)))
	for t in arts.techniques_of(selected_art):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		root.add_child(row)
		var lbl := label("", 18)
		lbl.custom_minimum_size = Vector2(330, 0)
		row.add_child(lbl)
		_tech_labels[t["id"]] = lbl
		for d in [["+100", 100], ["+1000", 1000], ["9999", -9999], ["0", -1]]:
			var b := button(d[0], 16)
			b.pressed.connect(_debug_count.bind(t["id"], d[1]))
			row.add_child(b)


func _update_tech_labels() -> void:
	var tid := arts.training_target()
	for id in _tech_labels.keys():
		var t: Dictionary = arts.registry.get_technique(id)
		var count := arts.count_of(id)
		var state := ""
		if not arts.is_tech_unlocked(id):
			state = "잠김"
		elif arts.is_mastered(id):
			state = "대성"
		else:
			state = stage_name(arts, count)
		var mark := " ◀" if id == tid and arts.main_art() == selected_art else ""
		_tech_labels[id].text = "%s · %s\n%s / %s%s" % [t["name"], state, fmt(count), fmt(arts.mastery_target_of(id)), mark]


func _equip_state(art_id: String) -> String:
	if not arts.is_unlocked(art_id):
		return "미개방"
	if arts.main_art() == art_id:
		return "주력"
	var subs := arts.sub_arts()
	for i in subs.size():
		if subs[i] == art_id:
			return "보조%d (패시브)" % (i + 1)
	return "미장착"


static func stage_name(martial_arts: MartialArtManager, count: int) -> String:
	var th: Array = martial_arts.registry.balance.get("training", {}).get("stage_thresholds", [])
	return MartialArtManager.stage_name_for(count, th)


# ---- 디버그 ----

func _build_debug() -> void:
	root.add_child(label("디버그 도구", 18, Color(1, 0.7, 0.4)))
	var speed_row := HBoxContainer.new()
	root.add_child(speed_row)
	_speed_label = label("시간 배속 x%d" % int(Engine.time_scale), 18)
	_speed_label.custom_minimum_size = Vector2(170, 0)
	speed_row.add_child(_speed_label)
	for s in [1, 5, 20, 50]:
		var b := button("x%d" % s, 20)
		b.pressed.connect(_set_speed.bind(s))
		speed_row.add_child(b)
	var unlock_all := button("무공 모두 개방 (비급 없이)", 20)
	unlock_all.pressed.connect(_unlock_all)
	root.add_child(unlock_all)
	var save_row := HBoxContainer.new()
	root.add_child(save_row)
	var save_now := button("지금 저장", 20)
	save_now.pressed.connect(func(): get_node("/root/SaveManager").save_game())
	save_row.add_child(save_now)
	var reset := button("저장 지우고 새 게임", 20)
	reset.pressed.connect(_reset_game)
	save_row.add_child(reset)
	_save_label = label("", 16)
	root.add_child(_save_label)


## amount > 0: 더하기, -9999: 대성 직전(목표-1), -1: 0으로
func _debug_count(tech_id: String, amount: int) -> void:
	var n := arts.count_of(tech_id)
	if amount == -9999:
		n = arts.mastery_target_of(tech_id) - 1
	elif amount == -1:
		n = 0
	else:
		n += amount
	arts.debug_set_count(tech_id, n)
	_rebuild()


func _update_save_label() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm == null or _save_label == null:
		return
	var ago := "없음"
	if sm.last_saved_ms >= 0:
		ago = "%d초 전" % int((Time.get_ticks_msec() - sm.last_saved_ms) / 1000)
	var text := "마지막 저장: %s · 저장 순번 %d · %s (30초마다, 대성·장착·스테이지 돌파·앱 전환 때 저장)" % [ago, sm.save_seq, sm.last_slot]
	if sm.load_error != "":
		text += "\n불러오기 오류: " + sm.load_error
	_save_label.text = text


## 저장 파일을 지우고 새 게임으로 다시 시작한다 (디버그)
func _reset_game() -> void:
	Engine.time_scale = 1.0
	var sm = get_node("/root/SaveManager")
	sm.delete_all()
	get_node("/root/GameState").reset_to_new_game()
	sm.save_game()
	get_tree().reload_current_scene()


func _set_speed(s: int) -> void:
	Engine.time_scale = float(s)
	_speed_label.text = "시간 배속 x%d" % s


func _unlock_all() -> void:
	for id in arts.registry.martial_arts.keys():
		arts.unlock(id)
	_rebuild()
