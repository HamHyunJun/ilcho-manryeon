extends Control
## 진입 화면.
## 배경(BattleBackground), 전투 화면(Battle), 조작 영역·하단 앱바(GameUi)를 띄운다.
## 데이터 요약은 로그에만 남기고, 데이터 오류나 저장 불러오기 오류가 있을 때만 제목 아래에 표시한다.

@onready var _info: Label = $Margin/VBox/Info


func _ready() -> void:
	# 전투 배경: 달빛, 산, 폭포, 누각, 매화, 돌바닥 (Battle보다 뒤)
	var ground := float(DataRegistry.balance.get("combat", {}).get("layout", {}).get("ground_y", 1020))
	var bg := BattleBackground.new(ground, preload("res://scripts/ui/GameUi.gd").BAR_Y)
	bg.name = "BattleBackground"
	add_child(bg)
	move_child(bg, $Background.get_index() + 1)
	# 제목 글자는 상단 바와 겹치므로 숨긴다 (데이터 오류 안내만 남김)
	$Margin/VBox/Title.visible = false
	$Margin/VBox/Subtitle.visible = false
	# 조작 영역과 육성 화면 (M3)
	var ui := preload("res://scripts/ui/GameUi.gd").new()
	ui.name = "GameUi"
	add_child(ui)
	# 여러 화면 비율 대응: 세로로 긴 화면이면 전투 화면과 앱바를 내려 앱바를 맨 아래에 붙인다
	apply_screen_fit()
	get_viewport().size_changed.connect(apply_screen_fit)
	_info.text = build_info_text()
	# 헤드리스 확인용으로 같은 내용을 로그에도 남긴다
	print(_info.text)
	var has_problem: bool = not DataRegistry.errors.is_empty() or (has_node("/root/SaveManager") and get_node("/root/SaveManager").load_error != "")
	_info.visible = has_problem
	if has_problem:
		_info.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
		_info.get_parent().move_child(_info, 2)


## 화면 크기에 맞춰 전투 화면, 배경, 조작 줄, 하단 앱바를 다시 배치한다 (ScreenFit)
func apply_screen_fit() -> void:
	var shift := ScreenFit.shift(get_viewport())
	var battle = get_node_or_null("Battle")
	if battle and "world_offset" in battle:
		battle.world_offset = Vector2(0, shift)
	var bg = get_node_or_null("BattleBackground")
	if bg:
		bg.world_shift = shift
	var ui = get_node_or_null("GameUi")
	if ui:
		ui.apply_layout(shift)


## 화면에 보여 줄 데이터 요약 문자열을 만든다.
func build_info_text() -> String:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.load_error != "":
		return "저장 데이터를 불러오지 못했습니다. 새 게임으로 시작합니다.\n" + sm.load_error
	if not DataRegistry.errors.is_empty():
		var lines: PackedStringArray = ["데이터 오류 %d건" % DataRegistry.errors.size()]
		for e in DataRegistry.errors:
			lines.append("- " + e)
		return "\n".join(lines)

	var names: PackedStringArray = []
	var ids := DataRegistry.martial_arts.keys()
	ids.sort()
	for id in ids:
		names.append(DataRegistry.martial_arts[id]["name"])
	return "[개발 확인] 무공 %d종(%s) · 몬스터 %d종 · 지역 %d곳 · 화면 %d×%d" % [
		DataRegistry.martial_arts.size(), ", ".join(names),
		DataRegistry.monsters.size(),
		DataRegistry.regions.size(),
		get_viewport_rect().size.x, get_viewport_rect().size.y,
	]
