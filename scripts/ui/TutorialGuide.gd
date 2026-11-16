extends PanelContainer
class_name TutorialGuide
## 첫 스테이지 튜토리얼 안내 (M11, docs/07 7장): 4단계를 차례로 보여 주고, 조건을 채우거나 [확인]을 누르면 넘어간다.
## 완료한 단계는 GameState.data.tutorial에 기록해 다시 띄우지 않는다. 단계 문구와 조건은 data/balance/tutorial.json.

var steps: Array = []
## 저장 데이터 tutorial 섹션 {단계 ID: true}
var progress: Dictionary
var arts: MartialArtManager
## 현재 단계 시작 시점의 기준값 (처치 수 등)
var _base := 0
var _current := -1
var _title: Label
var _text: Label
## 조건 확인용 콜백 (GameUi가 넣어 준다)
var kill_count: Callable = func(): return 0
var chain_toggled := false
var opened_menus: Dictionary = {}


func _init(tutorial_steps: Array, tutorial_progress: Dictionary, martial_arts: MartialArtManager) -> void:
	steps = tutorial_steps
	progress = tutorial_progress
	arts = martial_arts
	position = Vector2(24, 400)
	custom_minimum_size = Vector2(672, 0)
	size = Vector2(672, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	bg.border_color = Color(1.0, 0.82, 0.35)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(14)
	add_theme_stylebox_override("panel", bg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = MenuPanel.label("", 22, Color(1, 0.85, 0.4))
	v.add_child(_title)
	_text = MenuPanel.label("", 18)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(640, 0)
	v.add_child(_text)
	var ok := MenuPanel.button("확인", 18)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(complete_current)
	v.add_child(ok)
	_advance()


func current_id() -> String:
	return steps[_current]["id"] if _current >= 0 and _current < steps.size() else ""


func is_done() -> bool:
	return current_id() == ""


func _advance() -> void:
	_current = -1
	for i in steps.size():
		if not bool(progress.get(steps[i]["id"], false)):
			_current = i
			break
	if _current < 0:
		visible = false
		return
	visible = true
	var s: Dictionary = steps[_current]
	_title.text = "안내 %d / %d · %s" % [_current + 1, steps.size(), s.get("title", "")]
	_text.text = s.get("text", "")
	_base = int(kill_count.call())
	chain_toggled = false
	reset_size()


func complete_current() -> void:
	if _current < 0:
		return
	progress[steps[_current]["id"]] = true
	if has_node("/root/GameState"):
		get_node("/root/GameState")._request_save()
	_advance()


func _process(_delta: float) -> void:
	if _current < 0:
		return
	var c: Dictionary = steps[_current].get("complete", {})
	var done := false
	match c.get("type", ""):
		"kills":
			done = int(kill_count.call()) - _base >= int(c.get("value", 1))
		"chain_toggled":
			done = chain_toggled
		"menu_opened":
			done = opened_menus.has(c.get("value", ""))
		"tech_count":
			done = arts.count_of(arts.training_target()) >= int(c.get("value", 1)) or arts.total_mastered() > 0
	if done:
		complete_current()
