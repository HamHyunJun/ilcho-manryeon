extends Control
## 전투 아래쪽 화면 (M3 → M5 정리).
## - 전투 조작 영역: 수련 중인 초식과 진행도, 연속초식 토글 버튼 (docs/09 2-3, 확정 사항 21·22).
## - 하단 앱바: 장비 │ 소환 │ 던전 │ 육성. 각 메뉴는 MenuPanel 화면을 연다.
## 임시 UI: 기본 테마를 쓰며, 정식 UI 작업 때 바꾼다.

const BAR_Y := 1188.0

var arts: MartialArtManager

var _target_label: Label
var _target_bar: ProgressBar
var _chain_button: Button
var _chain_label: Label
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat
## 메뉴 이름 → MenuPanel
var panels: Dictionary = {}
var _menu_buttons: Dictionary = {}
var _open_name := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if arts == null:
		arts = get_node("/root/GameState").arts
	_build_combat_controls()
	_build_panels()
	_build_app_bar()


func _process(_delta: float) -> void:
	_update_combat_controls()


# ---- 전투 조작 영역 ----

func _build_combat_controls() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(32, 796)
	box.size = Vector2(656, 200)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_target_label = MenuPanel.label("", 22)
	box.add_child(_target_label)
	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(656, 18)
	_target_bar.show_percentage = false
	box.add_child(_target_bar)

	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0.16, 0.15, 0.22)
	_style_off.border_color = Color(0.4, 0.38, 0.5)
	_style_off.set_border_width_all(2)
	_style_off.set_corner_radius_all(10)
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(0.55, 0.36, 0.08)
	_style_on.border_color = Color(1.0, 0.82, 0.35)
	_style_on.set_border_width_all(4)
	_style_on.set_corner_radius_all(10)

	_chain_button = MenuPanel.button("연속초식", 30)
	_chain_button.toggle_mode = true
	_chain_button.custom_minimum_size = Vector2(656, 84)
	_chain_button.toggled.connect(_on_chain_toggled)
	box.add_child(_chain_button)
	_chain_label = MenuPanel.label("", 18, Color(0.8, 0.8, 0.88))
	box.add_child(_chain_label)


func _update_combat_controls() -> void:
	var tid := arts.training_target()
	var tech: Dictionary = arts.registry.get_technique(tid)
	var count := arts.count_of(tid)
	var target := arts.mastery_target_of(tid)
	var state := "대성" if arts.is_mastered(tid) else GrowthPanel.stage_name(arts, count)
	_target_label.text = "수련 중: %s · %s · %s / %s" % [tech.get("name", "-"), state, MenuPanel.fmt(count), MenuPanel.fmt(target)]
	_target_bar.max_value = target
	_target_bar.value = mini(count, target)

	var on := arts.is_chain_mode()
	_chain_button.set_pressed_no_signal(on)
	_chain_button.text = "연속초식  ON" if on else "연속초식  OFF"
	var style := _style_on if on else _style_off
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_chain_button.add_theme_stylebox_override(s, style)
	_chain_button.add_theme_color_override("font_color", Color(1, 0.95, 0.8) if on else Color(0.8, 0.8, 0.88))
	_chain_button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
	if on:
		var names: PackedStringArray = []
		for t in arts.unlocked_main_techniques():
			names.append(str(int(t.get("order", 0))))
		_chain_label.text = "해금한 초식을 순서대로 발동: %s초식 (발동한 모든 초식이 수련됩니다)" % " → ".join(names)
	else:
		_chain_label.text = "단일 수련: 수련 중인 초식만 반복합니다"


func _on_chain_toggled(on: bool) -> void:
	arts.set_chain_mode(on)
	var battle = get_parent().get_node_or_null("Battle")
	if battle and battle.techniques:
		battle.techniques.reset_chain()


# ---- 하단 앱바와 메뉴 화면 ----

func _build_panels() -> void:
	_add_panel("growth", GrowthPanel.new(arts))


## 메뉴 화면을 등록한다. 이후 단계(장비, 던전)에서도 같은 방식으로 붙인다.
func _add_panel(menu: String, panel: MenuPanel) -> void:
	panels[menu] = panel
	panel.close_requested.connect(func(): open_menu(""))
	add_child(panel)


func _build_app_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.position = Vector2(0, BAR_Y - 8)
	bg.size = Vector2(720, 1280 - BAR_Y + 8)
	add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(12, BAR_Y)
	row.size = Vector2(696, 80)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for m in [["equipment", "장비"], ["summon", "소환"], ["dungeon", "던전"], ["growth", "육성"]]:
		var b := MenuPanel.button(m[1], 24)
		b.custom_minimum_size = Vector2(168, 76)
		b.toggle_mode = true
		b.pressed.connect(_on_menu_pressed.bind(m[0]))
		row.add_child(b)
		_menu_buttons[m[0]] = b
	_refresh_menu_buttons()


func _on_menu_pressed(menu: String) -> void:
	open_menu("" if _open_name == menu else menu)


## 메뉴 화면을 연다. 빈 문자열이면 모두 닫는다. 아직 없는 메뉴는 안내만 띄운다.
func open_menu(menu: String) -> void:
	_open_name = menu if panels.has(menu) or menu == "" else ""
	for k in panels.keys():
		var p: MenuPanel = panels[k]
		p.visible = k == _open_name
		if p.visible:
			p.on_open()
	if menu != "" and not panels.has(menu):
		var battle = get_parent().get_node_or_null("Battle")
		if battle:
			battle._set_banner("%s: MVP 이후 추가 예정" % _menu_title(menu), 1.5)
	_refresh_menu_buttons()


func _refresh_menu_buttons() -> void:
	for k in _menu_buttons.keys():
		_menu_buttons[k].set_pressed_no_signal(k == _open_name)
		_menu_buttons[k].disabled = false


func _menu_title(menu: String) -> String:
	return {"equipment": "장비", "summon": "소환", "dungeon": "던전", "growth": "육성"}.get(menu, menu)
