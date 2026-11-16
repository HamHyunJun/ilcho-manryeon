extends Control
## 전투 아래쪽 조작 영역과 육성(무공) 최소 화면 (M3).
## - 아래쪽 막대: 수련 중인 초식과 진행도, 연속초식 디버그 토글, 육성 버튼.
##   연속초식의 정식 버튼 UI는 M5에서 만든다. 여기서는 디버그 토글이다.
## - 육성 화면: 무공 장착(주력 1, 보조 2), 초식별 수련 횟수와 단계 표시.
## - 디버그 도구: 수련 횟수 편집, 시간 배속, 무공 모두 개방 (비급 획득은 M9).
## 임시 UI: 기본 테마를 쓰며, 정식 UI 작업 때 바꾼다.

var arts: MartialArtManager

var _target_label: Label
var _target_bar: ProgressBar
var _chain_button: Button
var _panel: PanelContainer
var _art_rows: VBoxContainer
var _tech_rows: VBoxContainer
var _speed_label: Label
var _save_label: Label
## 육성 화면에서 보고 있는 무공
var _selected_art := ""
## 초식 ID → 표시 Label (매 프레임 갱신)
var _tech_labels: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if arts == null:
		arts = get_node("/root/GameState").arts
	_build_bottom_bar()
	_build_panel()
	arts.equipment_changed.connect(_rebuild_panel)
	arts.technique_mastered.connect(func(_id): _rebuild_panel())


func _process(_delta: float) -> void:
	_update_bottom_bar()
	if _panel.visible:
		_update_tech_labels()
		_update_save_label()


# ---- 아래쪽 막대 ----

func _build_bottom_bar() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(32, 800)
	box.size = Vector2(656, 150)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_target_label)

	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(656, 18)
	_target_bar.show_percentage = false
	box.add_child(_target_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_chain_button = _button("연속초식", 26)
	_chain_button.toggle_mode = true
	_chain_button.custom_minimum_size = Vector2(320, 72)
	_chain_button.toggled.connect(_on_chain_toggled)
	row.add_child(_chain_button)
	var growth := _button("육성", 26)
	growth.custom_minimum_size = Vector2(320, 72)
	growth.pressed.connect(func(): _open_panel(true))
	row.add_child(growth)


func _update_bottom_bar() -> void:
	var tid := arts.training_target()
	var tech: Dictionary = arts.registry.get_technique(tid)
	var count := arts.count_of(tid)
	var target := arts.mastery_target_of(tid)
	_target_label.text = "수련 중: %s · %s · %s / %s" % [
		tech.get("name", "-"), _stage_name(count), _fmt(count), _fmt(target)]
	_target_bar.max_value = target
	_target_bar.value = mini(count, target)
	_chain_button.set_pressed_no_signal(arts.is_chain_mode())
	_chain_button.text = "연속초식 켬 (디버그)" if arts.is_chain_mode() else "연속초식 끔 (디버그)"


func _on_chain_toggled(on: bool) -> void:
	arts.set_chain_mode(on)
	var battle = get_parent().get_node_or_null("Battle")
	if battle and battle.techniques:
		battle.techniques.reset_chain()


# ---- 육성 화면 ----

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(0, 790)
	_panel.size = Vector2(720, 490)
	_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.08, 0.14, 1.0)
	bg.border_color = Color(0.35, 0.32, 0.45)
	bg.border_width_top = 2
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "육성 · 무공"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("닫기", 22)
	close.pressed.connect(func(): _open_panel(false))
	head.add_child(close)

	_art_rows = VBoxContainer.new()
	root.add_child(_art_rows)
	root.add_child(HSeparator.new())
	_tech_rows = VBoxContainer.new()
	root.add_child(_tech_rows)
	root.add_child(HSeparator.new())

	# 디버그 도구
	var dbg := Label.new()
	dbg.text = "디버그 도구"
	dbg.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	root.add_child(dbg)
	var speed_row := HBoxContainer.new()
	root.add_child(speed_row)
	_speed_label = Label.new()
	_speed_label.text = "시간 배속 x1"
	_speed_label.custom_minimum_size = Vector2(170, 0)
	speed_row.add_child(_speed_label)
	for s in [1, 5, 20, 50]:
		var b := _button("x%d" % s, 20)
		b.pressed.connect(_set_speed.bind(s))
		speed_row.add_child(b)
	var unlock_all := _button("무공 모두 개방 (비급 획득은 M9)", 20)
	unlock_all.pressed.connect(_unlock_all)
	root.add_child(unlock_all)
	# 저장 확인용 (M4)
	var save_row := HBoxContainer.new()
	root.add_child(save_row)
	var save_now := _button("지금 저장", 20)
	save_now.pressed.connect(func(): get_node("/root/SaveManager").save_game())
	save_row.add_child(save_now)
	var reset := _button("저장 지우고 새 게임", 20)
	reset.pressed.connect(_reset_game)
	save_row.add_child(reset)
	_save_label = Label.new()
	_save_label.add_theme_font_size_override("font_size", 16)
	_save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_save_label)


func _open_panel(open: bool) -> void:
	_panel.visible = open
	if open:
		if _selected_art == "":
			_selected_art = arts.main_art()
		_rebuild_panel()


func _rebuild_panel() -> void:
	if not _panel.visible:
		return
	for c in _art_rows.get_children():
		c.queue_free()
	for c in _tech_rows.get_children():
		c.queue_free()
	_tech_labels.clear()

	var ids: Array = arts.registry.martial_arts.keys()
	ids.sort()
	for art_id in ids:
		var art: Dictionary = arts.registry.get_martial_art(art_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_art_rows.add_child(row)
		var name_btn := _button("%s\n%s" % [art["name"], _equip_state(art_id)], 18)
		name_btn.custom_minimum_size = Vector2(230, 64)
		name_btn.toggle_mode = true
		name_btn.button_pressed = art_id == _selected_art
		name_btn.pressed.connect(func(): _selected_art = art_id; _rebuild_panel())
		row.add_child(name_btn)
		var unlocked := arts.is_unlocked(art_id)
		var main_btn := _button("주력", 18)
		main_btn.disabled = not unlocked or arts.main_art() == art_id
		main_btn.pressed.connect(func(): arts.equip_main(art_id))
		row.add_child(main_btn)
		for slot in MartialArtManager.SUB_SLOTS:
			var sub_btn := _button("보조%d" % (slot + 1), 18)
			var in_slot: bool = arts.sub_arts()[slot] == art_id
			sub_btn.text = "보조%d 해제" % (slot + 1) if in_slot else "보조%d" % (slot + 1)
			sub_btn.disabled = not unlocked or arts.main_art() == art_id
			sub_btn.pressed.connect(func(): arts.equip_sub(slot, null if in_slot else art_id))
			row.add_child(sub_btn)

	# 선택한 무공의 초식별 수련 현황
	var sel: Dictionary = arts.registry.get_martial_art(_selected_art)
	var head := Label.new()
	head.text = "%s 초식 수련 현황" % sel.get("name", "")
	head.add_theme_font_size_override("font_size", 22)
	_tech_rows.add_child(head)
	if not arts.is_unlocked(_selected_art):
		var locked := Label.new()
		locked.text = "아직 개방하지 않은 무공입니다."
		_tech_rows.add_child(locked)
		return
	if arts.main_art() != _selected_art:
		var note := Label.new()
		note.text = "주력이 아니면 초식이 발동하지 않습니다. 보조로 장착하면 패시브만 적용됩니다."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		_tech_rows.add_child(note)
	for t in arts.techniques_of(_selected_art):
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 6)
		_tech_rows.add_child(row2)
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(330, 0)
		lbl.add_theme_font_size_override("font_size", 18)
		row2.add_child(lbl)
		_tech_labels[t["id"]] = lbl
		for d in [["+100", 100], ["+1000", 1000], ["9999", -9999], ["0", -1]]:
			var b := _button(d[0], 16)
			b.pressed.connect(_debug_count.bind(t["id"], d[1]))
			row2.add_child(b)
	_update_tech_labels()


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
			state = _stage_name(count)
		var mark := " ◀" if id == tid and arts.main_art() == _selected_art else ""
		_tech_labels[id].text = "%s · %s\n%s / %s%s" % [t["name"], state, _fmt(count), _fmt(arts.mastery_target_of(id)), mark]


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


# ---- 디버그 ----

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
	_rebuild_panel()


func _update_save_label() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm == null:
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
	_rebuild_panel()


# ---- 공통 ----

func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _stage_name(count: int) -> String:
	var th: Array = arts.registry.balance.get("training", {}).get("stage_thresholds", [])
	return MartialArtManager.stage_name_for(count, th)


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
