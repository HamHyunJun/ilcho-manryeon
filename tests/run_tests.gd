extends SceneTree
## 헤드리스 테스트 실행기.
## 실행: godot --headless --path . -s res://tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.

## 스크립트 오류로 중간에 멈춘 테스트도 실패로 세기 위해, 각 테스트는 마지막 줄에서 _finish()를 호출한다.

const TESTS := [
	&"_test_project_settings",
	&"_test_data_registry_loads_mvp_data",
	&"_test_data_registry_detects_errors",
	&"_test_time_service",
	&"_test_damage_calculator",
	&"_test_target_selector",
	&"_test_battle_simulation",
	&"_test_battle_knockout",
]

var _failed := 0
var _passed := 0
var _finished := 0
var _started := false


## 씬 트리가 준비된 첫 프레임에서 실행한다 (_ready 호출과 오토로드가 정상 동작하도록)
func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	for t in TESTS:
		var before := _finished
		call(t)
		if _finished == before:
			_failed += 1
			printerr("  실패: %s 실행 중 오류로 중단됨" % t)

	print("")
	print("테스트 결과: 통과 %d, 실패 %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
	return false


func _finish() -> void:
	_finished += 1


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
	_finish()


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
	_finish()


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
	_finish()


func _test_time_service() -> void:
	print("[시간 서비스]")
	var ts = load("res://scripts/autoload/TimeService.gd").new()
	_check(ts.now_unix() > 1700000000, "기기 시간 반환")
	_check(ts.now_monotonic_ms() >= 0, "단조 시간 반환")
	ts.free()
	_finish()


func _test_damage_calculator() -> void:
	print("[피해 계산]")
	# 20 × 1.0 × 100/(100+5) = 19.05 → 19
	_check(DamageCalculator.compute(20, 1.0, 5, 100) == 19, "기본 피해 = 공격력 × 계수 × 방어 보정")
	# 치명타 1.5배: 28.57 → 29
	_check(DamageCalculator.compute(20, 1.0, 5, 100, true, 1.5) == 29, "치명타 배율 적용")
	_check(DamageCalculator.compute(1, 0.1, 9999, 100) == 1, "최소 피해 1")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_check(not DamageCalculator.roll_crit(rng, 0.0), "치명타 확률 0이면 치명타 없음")
	_check(DamageCalculator.roll_crit(rng, 1.0), "치명타 확률 1이면 항상 치명타")
	_finish()


func _test_target_selector() -> void:
	print("[대상 선택]")
	# 캐릭터 x=100(반폭 20), 대상 x=200(반폭 20) → 가장자리 거리 60
	_check(is_equal_approx(TargetSelector.edge_gap(100, 20, 200, 20), 60.0), "가장자리 거리 계산")
	_check(is_equal_approx(TargetSelector.edge_gap(100, 20, 120, 20), 0.0), "겹치면 거리 0")
	_finish()


## 전투 씬을 수동 진행 모드로 띄운다.
func _make_battle() -> Node2D:
	var battle: Node2D = load("res://scenes/battle/Battle.tscn").instantiate()
	battle.manual_tick = true
	root.add_child(battle)
	battle.rng.seed = 12345
	return battle


func _test_battle_simulation() -> void:
	print("[전투 시뮬레이션]")
	var battle := _make_battle()
	var player = battle.player
	var cfg: Dictionary = battle.config
	_check(is_equal_approx(player.position.x, float(cfg["layout"]["player_x"])), "캐릭터가 왼쪽 고정 위치에 배치됨")
	_check(player.tick(0.1, [], battle.rng, 100.0).is_empty(), "대상이 없으면 기본 공격하지 않음")

	battle.tick(0.05)
	_check(battle.alive_count() == 1, "전투 시작 시 몬스터 생성")
	var first = battle.monsters[0]
	_check(first.position.x >= float(cfg["layout"]["spawn_x"]) - 5.0, "몬스터는 화면 오른쪽에서 생성됨")
	var start_x: float = first.position.x
	for i in 20:
		battle.tick(0.05)
	_check(is_instance_valid(first) and first.position.x < start_x, "몬스터가 캐릭터 쪽(왼쪽)으로 접근함")

	var min_hp: int = player.hp
	var crossed := false
	for i in 600:  # 30초
		battle.tick(0.05)
		min_hp = mini(min_hp, player.hp)
		for m in battle.monsters:
			if is_instance_valid(m) and m.position.x < player.position.x:
				crossed = true
	_check(battle.kill_count > 0, "캐릭터가 자동 공격으로 몬스터를 처치함 (%d마리)" % battle.kill_count)
	_check(min_hp < player.max_hp, "몬스터가 캐릭터를 공격함 (최저 체력 %d)" % min_hp)
	_check(not crossed, "몬스터가 캐릭터를 지나치지 않음")
	_check(battle.alive_count() <= int(cfg["spawn"]["max_alive"]), "동시 생성 수 제한")
	battle.free()
	_finish()


func _test_battle_knockout() -> void:
	print("[쓰러짐 임시 처리]")
	var battle := _make_battle()
	var player = battle.player
	player.take_damage(player.max_hp)
	_check(player.is_down(), "체력 0이면 쓰러짐")
	var delay := float(battle.config["knockout"]["recover_delay"])
	battle.tick(delay * 0.5)
	_check(player.is_down(), "회복 대기 중에는 쓰러진 상태 유지")
	battle.tick(delay)
	_check(not player.is_down() and player.hp == player.max_hp, "대기 후 체력 전부 회복")
	_check(battle.alive_count() == 0, "회복 시 몬스터 정리")
	battle.free()
	_finish()
