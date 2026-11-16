extends Control
## 진입 화면.
## M1~M3: 전투 화면(Battle, 스테이지 루프·초식 수련 포함)과 조작 영역(GameUi)을 띄우고, 아래쪽에 불러온 데이터 요약을 작게 표시한다(개발 확인용).
## 화면 전환과 하단 메뉴는 이후 단계에서 추가한다.

@onready var _info: Label = $Margin/VBox/Info


func _ready() -> void:
	# 조작 영역과 육성 화면 (M3)
	var ui := preload("res://scripts/ui/GameUi.gd").new()
	ui.name = "GameUi"
	add_child(ui)
	_info.text = build_info_text()
	# 헤드리스 확인용으로 같은 내용을 로그에도 남긴다
	print(_info.text)


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
