extends Control
## 전투 위의 조작 화면 (M3 → M5 → 디자인 시안 mock-vector-v30-bigbar 반영).
## - 전투 조작 영역: 수련 중인 초식과 진행도(앱바 위 초식 게이지), 연속초식 토글 (docs/09 2-3, 확정 사항 21·22).
## - 하단 앱바(AppBar, 높이 134): 상점 │ 육성 │ 메인(태극) │ 던전 │ 소환(장비 소환). 장비는 육성 화면의 [장비] 탭에서 다룬다.
## - 오른쪽 위 설정 버튼 (상단 바 가로 중심선에 맞춤).

## 하단 앱바 윗선 (720×1280 기준). 앱바 높이 약 100 → 134px로 키웠다
const BAR_Y := 1146.0
## 연속초식 토글과 수련 문구 줄 (앱바가 커진 만큼 위로)
const CONTROLS_Y := 1036.0

var arts: MartialArtManager
## 장비 관리자 (M8). 없으면 GameState의 것을 쓴다
var equipment: EquipmentManager

var _target_label: Label
var _target_bar: ProgressBar
var _chain_button: Button
var _chain_label: Label
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat
## 메뉴 이름 → MenuPanel
var panels: Dictionary = {}
var _app_bar: AppBar
var _gear_button: Button
var _open_name := ""
## 튜토리얼 안내 (M11)
var tutorial: TutorialGuide


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 전투 화면(상단 바 z 20, 이펙트 z 9~10)보다 위에 그린다. 육성 화면은 상단 바까지 덮는다
	z_index = 40
	if arts == null:
		arts = get_node("/root/GameState").arts
	_build_combat_controls()
	_build_panels()
	_build_app_bar()
	_build_top_buttons()
	_build_tutorial()


func _process(_delta: float) -> void:
	_update_combat_controls()


# ---- 전투 조작 영역 ----

func _build_combat_controls() -> void:
	# 왼쪽: 수련 중인 초식과 진행 문구, 연속초식 발동 순서
	_target_label = MenuPanel.label("", 19, Color(1, 0.95, 0.85))
	_target_label.position = Vector2(20, CONTROLS_Y)
	_target_label.size = Vector2(470, 28)
	_target_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_target_label.clip_text = true
	_outline(_target_label)
	add_child(_target_label)
	_chain_label = MenuPanel.label("", 15, Color(0.85, 0.85, 0.92))
	_chain_label.position = Vector2(20, CONTROLS_Y + 30)
	_chain_label.size = Vector2(470, 24)
	_chain_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chain_label.clip_text = true
	_outline(_chain_label)
	add_child(_chain_label)
	# 수련 진행도: 앱바 바로 위 금색 초식 게이지로 그린다 (AppBar.gauge). 값 보관용 바는 숨긴다
	_target_bar = ProgressBar.new()
	_target_bar.visible = false
	_target_bar.show_percentage = false
	add_child(_target_bar)

	# 오른쪽: "연속초식" 글자 + 스위치 모양 토글
	var cap := MenuPanel.label("연속초식", 20, Color(0.95, 0.92, 0.85))
	cap.position = Vector2(500, CONTROLS_Y + 12)
	cap.size = Vector2(100, 30)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	_outline(cap)
	add_child(cap)
	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0.18, 0.18, 0.24, 0.95)
	_style_off.border_color = Color(0.45, 0.45, 0.55)
	_style_off.set_border_width_all(2)
	_style_off.set_corner_radius_all(22)
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(0.72, 0.48, 0.12, 0.95)
	_style_on.border_color = Color(1.0, 0.85, 0.4)
	_style_on.set_border_width_all(2)
	_style_on.set_corner_radius_all(22)
	_chain_button = MenuPanel.button("OFF", 15)
	_chain_button.toggle_mode = true
	_chain_button.position = Vector2(604, CONTROLS_Y + 6)
	_chain_button.custom_minimum_size = Vector2(96, 44)
	_chain_button.size = Vector2(96, 44)
	_chain_button.toggled.connect(_on_chain_toggled)
	add_child(_chain_button)
	# 스위치 손잡이 (켜면 오른쪽으로)
	var knob := ToggleKnob.new()
	knob.button = _chain_button
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chain_button.add_child(knob)


## 배경 위에서도 읽히도록 글자에 외곽선
static func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)


## 연속초식 스위치의 동그란 손잡이
class ToggleKnob extends Control:
	var button: Button

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if button == null:
			return
		var on := button.button_pressed
		var r := size.y * 0.5 - 5.0
		var cx := size.x - r - 5.0 if on else r + 5.0
		draw_circle(Vector2(cx, size.y * 0.5 + 1), r, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(cx, size.y * 0.5), r, Color(1, 0.97, 0.9) if on else Color(0.82, 0.82, 0.88))


func _update_combat_controls() -> void:
	var tid := arts.training_target()
	var tech: Dictionary = arts.registry.get_technique(tid)
	var count := arts.count_of(tid)
	var target := arts.mastery_target_of(tid)
	var state := "대성" if arts.is_mastered(tid) else GrowthPanel.stage_name(arts, count)
	_target_label.text = "%s · %s · %s / %s" % [tech.get("name", "-"), state, MenuPanel.fmt(count), MenuPanel.fmt(target)]
	_target_bar.max_value = target
	_target_bar.value = mini(count, target)
	if _app_bar:
		_app_bar.gauge = float(mini(count, target)) / float(maxi(target, 1))

	var on := arts.is_chain_mode()
	_chain_button.set_pressed_no_signal(on)
	_chain_button.text = "ON" if on else "OFF"
	_chain_button.alignment = HORIZONTAL_ALIGNMENT_LEFT if on else HORIZONTAL_ALIGNMENT_RIGHT
	var style := _style_on if on else _style_off
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_chain_button.add_theme_stylebox_override(s, style)
	_chain_button.add_theme_color_override("font_color", Color(1, 0.95, 0.8) if on else Color(0.75, 0.75, 0.82))
	_chain_button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
	_chain_button.add_theme_color_override("font_hover_pressed_color", Color(1, 0.95, 0.8))
	_chain_button.add_theme_constant_override("h_separation", 0)
	if on:
		var names: PackedStringArray = []
		for t in arts.unlocked_main_techniques():
			names.append(str(int(t.get("order", 0))))
		_chain_label.text = "연속초식: %s초식 순서로 발동 (모두 수련됨)" % " → ".join(names)
	else:
		_chain_label.text = "단일 수련: 수련 중인 초식만 반복"


func _on_chain_toggled(on: bool) -> void:
	arts.set_chain_mode(on)
	if tutorial:
		tutorial.chain_toggled = true
	var battle = get_parent().get_node_or_null("Battle")
	if battle and battle.techniques:
		battle.techniques.reset_chain()


# ---- 하단 앱바와 메뉴 화면 ----

func _build_panels() -> void:
	var gs = get_node_or_null("/root/GameState")
	var eq: EquipmentManager = equipment if equipment != null else (gs.equipment if gs else null)
	var battle = get_parent().get_node_or_null("Battle") if get_parent() else null
	# 육성 화면: 주인공과 장비 슬롯, 능력치, [장비 / 소환수 / 무공] 탭 (무공 탭은 기존 GrowthPanel)
	_add_panel("growth", GrowScreen.new(arts, eq, battle))
	if eq != null:
		_add_panel("equipment", EquipmentPanel.new(eq))
		# 장비 소환 (소환패, 결과에서 바로 장착)
		_add_panel("summon", SummonPanel.new(eq, battle))
	if battle != null:
		var dp := DungeonPanel.new(battle)
		_add_panel("dungeon", dp)
		dp.codex_requested.connect(func(): open_menu("codex"))
		_add_panel("codex", CodexPanel.new(arts, battle))
	if gs != null:
		_add_panel("settings", SettingsPanel.new())
	# 복귀 요약 (M10): 시작할 때 이미 계산된 결과가 있으면 바로, 이후(모바일 복귀)에는 신호로 띄운다
	if gs != null:
		var op := OfflineSummaryPanel.new(gs.get_node("/root/DataRegistry"))
		_add_panel("offline", op)
		gs.offline_summary_ready.connect(_show_offline)
		if not gs.offline_summary.is_empty():
			_show_offline.call_deferred(gs.offline_summary)


## 메뉴 화면을 등록한다. 이후 단계(장비, 던전)에서도 같은 방식으로 붙인다.
func _add_panel(menu: String, panel: MenuPanel) -> void:
	panels[menu] = panel
	panel.close_requested.connect(func(): open_menu(""))
	add_child(panel)


## 화면 위 보조 버튼: 설정 (docs/09 3장 가안)
func _build_top_buttons() -> void:
	if not panels.has("settings"):
		return
	# 톱니바퀴 버튼: 상단 바 가로 중심선(BattleHud.CENTER_Y)에 맞춘다
	var b := Button.new()
	b.flat = true
	b.tooltip_text = "설정"
	b.custom_minimum_size = Vector2(64, 64)
	b.size = Vector2(64, 64)
	b.position = Vector2(664 - 32, 92 - 32)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): open_menu("" if _open_name == "settings" else "settings"))
	add_child(b)
	_gear_button = b
	var icon := GearIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)


class GearIcon extends Control:
	func _draw() -> void:
		UiIcons.gear(self, size * 0.5 + Vector2(1, 1), 40, Color(0, 0, 0, 0.5))
		UiIcons.gear(self, size * 0.5, 40)


func _build_tutorial() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var steps: Array = gs.get_node("/root/DataRegistry").balance.get("tutorial", {}).get("steps", [])
	if steps.is_empty():
		return
	tutorial = TutorialGuide.new(steps, gs.data["tutorial"], arts)
	# 상단 바 아래, 몬스터와 상단 정보창을 가리지 않는 자리
	tutorial.position = Vector2(24, 186)
	var battle = get_parent().get_node_or_null("Battle") if get_parent() else null
	if battle:
		tutorial.kill_count = func(): return battle.kill_count
	add_child(tutorial)


func _show_offline(summary: Dictionary) -> void:
	if not panels.has("offline") or summary.is_empty():
		return
	panels["offline"].summary = summary
	open_menu("offline")
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.offline_summary = {}


func _build_app_bar() -> void:
	_app_bar = AppBar.new(BAR_Y)
	_app_bar.menu_pressed.connect(_on_menu_pressed)
	add_child(_app_bar)
	_refresh_menu_buttons()


func _on_menu_pressed(menu: String) -> void:
	if menu == "main":
		open_menu("")
		return
	open_menu("" if _open_name == menu else menu)


## 메뉴 화면을 연다. 빈 문자열이면 모두 닫는다. 아직 없는 메뉴는 안내만 띄운다.
func open_menu(menu: String) -> void:
	_open_name = menu if panels.has(menu) or menu == "" else ""
	if tutorial and menu != "":
		tutorial.opened_menus[menu] = true
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
	if _app_bar == null:
		return
	# 장비 상세는 육성, 무공 도감은 던전 아래 화면으로 본다
	# 육성 화면은 상단 바까지 덮으므로 설정 버튼을 숨긴다
	if _gear_button:
		_gear_button.visible = _open_name != "growth"
	_app_bar.active = {"growth": "growth", "equipment": "growth", "dungeon": "dungeon", "codex": "dungeon", "summon": "summon"}.get(_open_name, "main")
	_app_bar.queue_redraw()


func _menu_title(menu: String) -> String:
	return {"equipment": "장비", "summon": "소환", "dungeon": "던전", "growth": "육성", "shop": "상점"}.get(menu, menu)
