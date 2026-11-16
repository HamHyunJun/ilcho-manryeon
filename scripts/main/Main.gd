extends Control
## 진입 화면.
## M1: 전투 화면(Battle)을 띄우고, 아래쪽에 불러온 데이터 요약을 작게 표시한다(개발 확인용).
## 화면 전환과 하단 메뉴는 이후 단계에서 추가한다.

@onready var _info: Label = $Margin/VBox/Info


func _ready() -> void:
	_info.text = build_info_text()
	# 헤드리스 확인용으로 같은 내용을 로그에도 남긴다
	print(_info.text)


## 화면에 보여 줄 데이터 요약 문자열을 만든다.
func build_info_text() -> String:
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
	return "[개발 확인] 무공 %d종(%s) · 몬스터 %d종 · 화면 %d×%d" % [
		DataRegistry.martial_arts.size(), ", ".join(names),
		DataRegistry.monsters.size(),
		get_viewport_rect().size.x, get_viewport_rect().size.y,
	]
