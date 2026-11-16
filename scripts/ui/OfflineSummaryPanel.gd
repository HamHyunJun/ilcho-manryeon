extends MenuPanel
class_name OfflineSummaryPanel
## 복귀 요약 화면 (M10): 자리를 비운 시간, 인정 시간과 효율, 초식별 오른 수련 횟수, 대성한 초식.
## 시계를 되돌린 것이 감지되면 보상이 없다는 안내를 보여 준다.

var summary: Dictionary = {}
var _registry


func _init(registry) -> void:
	super._init("수련 복귀")
	_registry = registry


func show_summary(s: Dictionary) -> void:
	summary = s
	_rebuild()


func on_open() -> void:
	_rebuild()


func _rebuild() -> void:
	clear_root()
	if summary.get("rollback", false):
		root.add_child(label("기기 시간이 마지막 저장보다 과거로 바뀌어 오프라인 수련을 반영하지 않았습니다.\n시간이 저장 시점을 지나면 다시 정상 계산합니다.", 18, Color(1, 0.75, 0.5)))
	else:
		var raw := float(summary.get("raw_seconds", summary.get("seconds", 0.0)))
		var used := float(summary.get("seconds", 0.0))
		var head := "자리를 비운 시간 %s" % OfflineTraining.format_duration(raw)
		if summary.get("capped", false):
			head += " (최대 %d시간까지 인정)" % int(summary.get("max_hours", 8))
		root.add_child(label(head, 22, Color(1, 0.9, 0.6)))
		root.add_child(label("인정 %s · 효율 %d%% · 단일 수련 기준" % [OfflineTraining.format_duration(used), int(round(float(summary.get("efficiency", 0.5)) * 100))], 17, Color(0.8, 0.8, 0.88)))
		var lines: PackedStringArray = []
		var gains: Dictionary = summary.get("gains", {})
		for tid in gains.keys():
			var t: Dictionary = _registry.get_technique(tid)
			lines.append("%s  +%s회" % [t.get("name", tid), fmt(int(gains[tid]))])
		if lines.is_empty():
			lines.append("오른 수련 횟수가 없습니다.")
		root.add_child(label("\n".join(lines), 20))
		for tid in summary.get("mastered", []):
			root.add_child(label("%s 대성! 다음 초식이 열렸습니다" % _registry.get_technique(tid).get("name", tid), 20, Color(1, 0.85, 0.4)))
	var ok := button("확인", 24)
	ok.custom_minimum_size = Vector2(0, 64)
	ok.pressed.connect(func(): close_requested.emit())
	root.add_child(ok)
