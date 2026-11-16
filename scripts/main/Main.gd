extends Control
## M0 진입 화면.
## 완료 기준: 세로 화면에서 실행되고, JSON 데이터를 읽어 화면에 출력한다.
## 전투 화면(M1)이 생기면 이 화면은 화면 전환 담당으로 바뀐다.

@onready var _info: Label = $Margin/VBox/Info


func _ready() -> void:
	_info.text = build_info_text()
	# 헤드리스 확인용으로 같은 내용을 로그에도 남긴다
	print(_info.text)


## 화면에 보여 줄 데이터 요약 문자열을 만든다.
func build_info_text() -> String:
	var lines: PackedStringArray = []
	var size := get_viewport_rect().size
	lines.append("화면 크기: %d × %d" % [size.x, size.y])
	lines.append("")

	if not DataRegistry.errors.is_empty():
		lines.append("데이터 오류 %d건" % DataRegistry.errors.size())
		for e in DataRegistry.errors:
			lines.append("- " + e)
		return "\n".join(lines)

	lines.append("불러온 무공 %d종" % DataRegistry.martial_arts.size())
	var ids := DataRegistry.martial_arts.keys()
	ids.sort()
	for id in ids:
		var art: Dictionary = DataRegistry.martial_arts[id]
		lines.append("· %s (%s) 초식 %d개" % [art["name"], art["category"], art["techniques"].size()])

	var training: Dictionary = DataRegistry.balance.get("training", {})
	lines.append("")
	lines.append("대성 목표: %d회" % int(training.get("default_mastery_target", 0)))
	return "\n".join(lines)
