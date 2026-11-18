extends MenuPanel
class_name SettingsPanel
## 설정 화면 (M11, docs/09 5장): 효과음/배경음 음량, 진동, 화면 흔들림, 언어(한국어만), 저장 내보내기/가져오기.
## 자동 초식 on/off는 두지 않는다 (O-47 해결: 연속초식 버튼으로 대체).

var _code_edit: TextEdit
var _status: Label
var _pending_import: Dictionary = {}
var _confirm_box: VBoxContainer


func _init() -> void:
	super._init("설정")


func on_open() -> void:
	_pending_import = {}
	_rebuild()


func _gs():
	return get_node("/root/GameState")


func _settings() -> Dictionary:
	return _gs().data["settings"]


func _rebuild() -> void:
	clear_root()
	var st := _settings()
	_add_slider("효과음", "sfx_volume", st)
	_add_slider("배경음 (임시 배경음 없음)", "bgm_volume", st)
	_add_check("진동", "vibration", st)
	_add_check("화면 흔들림", "screen_shake", st)
	root.add_child(label("언어: 한국어", 18))
	root.add_child(HSeparator.new())
	root.add_child(label("저장 옮기기", 22))
	root.add_child(label("내보내기로 받은 코드를 다른 기기의 가져오기에 붙여 넣으면 진행이 옮겨집니다.\n가져오면 이 기기의 진행을 덮어씁니다 (덮기 전 진행은 백업으로 남깁니다).", 15, Color(0.8, 0.8, 0.88)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	var ex := button("내보내기 (복사)", 20)
	ex.pressed.connect(_export)
	row.add_child(ex)
	var im := button("가져오기", 20)
	im.pressed.connect(_check_import)
	row.add_child(im)
	_code_edit = TextEdit.new()
	_code_edit.custom_minimum_size = Vector2(640, 120)
	_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_edit.placeholder_text = "여기에 저장 코드를 붙여 넣으세요"
	root.add_child(_code_edit)
	_status = label("", 16, Color(1, 0.8, 0.5))
	root.add_child(_status)
	_confirm_box = VBoxContainer.new()
	root.add_child(_confirm_box)


func _add_slider(text: String, key: String, st: Dictionary) -> void:
	var row := HBoxContainer.new()
	root.add_child(row)
	var l := label(text, 18)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(st.get(key, 0.8))
	s.custom_minimum_size = Vector2(320, 40)
	s.value_changed.connect(func(v):
		_settings()[key] = v
		_gs()._request_save())
	row.add_child(s)


func _add_check(text: String, key: String, st: Dictionary) -> void:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", InkTheme.px(18))
	c.button_pressed = bool(st.get(key, true))
	c.toggled.connect(func(on):
		_settings()[key] = on
		_gs()._request_save())
	root.add_child(c)


func _export() -> void:
	var code: String = get_node("/root/SaveManager").export_code()
	_code_edit.text = code
	DisplayServer.clipboard_set(code)
	_status.text = "저장 코드를 클립보드에 복사했습니다 (%d자). 메모장 등에 보관해 주세요." % code.length()


func _check_import() -> void:
	var text := _code_edit.text
	if text.strip_edges() == "":
		text = DisplayServer.clipboard_get()
		_code_edit.text = text
	var r: Dictionary = get_node("/root/SaveManager").parse_code(text)
	for c in _confirm_box.get_children():
		c.queue_free()
	if not r["ok"]:
		_status.text = r["error"]
		return
	_pending_import = r
	_status.text = "가져올 진행: " + r["summary"]
	var yes := button("이 진행으로 덮어쓰기", 20)
	yes.pressed.connect(_do_import)
	_confirm_box.add_child(yes)


func _do_import() -> void:
	var r: Dictionary = get_node("/root/SaveManager").import_code(_code_edit.text)
	if not r["ok"]:
		_status.text = r["error"]
		return
	get_tree().reload_current_scene()
