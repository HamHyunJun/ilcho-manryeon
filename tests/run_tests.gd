extends SceneTree
## 헤드리스 테스트 실행기.
## 실행: godot --headless --path . -s res://tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_test_project_settings()
	_test_data_registry_loads_mvp_data()
	_test_data_registry_detects_errors()
	_test_time_service()

	print("")
	print("테스트 결과: 통과 %d, 실패 %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  통과: " + name)
	else:
		_failed += 1
		printerr("  실패: " + name)


func _test_project_settings() -> void:
	print("[프로젝트 설정]")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 720, "기준 폭 720")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 1280, "기준 높이 1280")
	# 1 = 세로(Portrait)
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == 1, "세로 고정")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/Main.tscn", "메인 씬 지정")
	for name in ["EventBus", "TimeService", "DataRegistry", "GameState", "SaveManager"]:
		_check(ProjectSettings.has_setting("autoload/" + name), "오토로드 등록: " + name)


func _test_data_registry_loads_mvp_data() -> void:
	print("[데이터 로드]")
	var reg = load("res://scripts/autoload/DataRegistry.gd").new()
	var errors: int = reg.load_all()
	_check(errors == 0, "데이터 오류 없음 (%d건)" % errors)
	for id in ["plum_blossom_sword", "arhat_fist", "yin_yang_five_elements"]:
		_check(reg.martial_arts.has(id), "MVP 무공 존재: " + id)
	var art: Dictionary = reg.get_martial_art("plum_blossom_sword")
	_check(art.get("name") == "매화검법", "매화검법 이름")
	var techs: Array = art.get("techniques", [])
	_check(techs.size() > 0 and int(techs[0]["order"]) == 1, "초식이 해금 순서로 정렬됨")
	_check(reg.get_technique("plum_blossom_sword.t1").get("mastery_target") == 10000, "초식 대성 목표 10,000")
	_check(reg.balance.has("training"), "수련 공통 수치 로드")
	reg.free()


func _test_data_registry_detects_errors() -> void:
	print("[데이터 검증]")
	var dir := "user://test_data/martial_arts"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("bad.json"), FileAccess.WRITE)
	f.store_string('{"id": "bad", "name": "필수 항목 누락"}')
	f.close()
	var reg = load("res://scripts/autoload/DataRegistry.gd").new()
	var errors: int = reg.load_all("user://test_data")
	_check(errors == 1, "필수 항목 누락 감지")
	_check(not reg.martial_arts.has("bad"), "잘못된 무공은 등록하지 않음")
	reg.free()
	DirAccess.remove_absolute(dir.path_join("bad.json"))


func _test_time_service() -> void:
	print("[시간 서비스]")
	var ts = load("res://scripts/autoload/TimeService.gd").new()
	_check(ts.now_unix() > 1700000000, "기기 시간 반환")
	_check(ts.now_monotonic_ms() >= 0, "단조 시간 반환")
	ts.free()
