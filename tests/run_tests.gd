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
	&"_test_stage_data",
	&"_test_stage_data_detects_errors",
	&"_test_stage_manager",
	&"_test_stage_loop",
	&"_test_new_game_martial_arts",
	&"_test_original_scenario_switch_restore",
	&"_test_mastery_and_unlock",
	&"_test_training_rules",
	&"_test_sub_passive_only",
	&"_test_battle_training_single",
	&"_test_battle_training_chain",
	&"_test_save_round_trip",
	&"_test_save_double_slots",
	&"_test_save_corruption_recovery",
	&"_test_save_version_and_migration",
	&"_test_save_restores_stage_in_battle",
	&"_test_chain_toggle_off_returns_to_single",
	&"_test_game_ui_chain_button",
	&"_test_effect_presets",
	&"_test_effect_director_in_battle",
	&"_test_effect_performance_cap",
	&"_test_growth_level_and_exp",
	&"_test_growth_realm_promotion",
	&"_test_growth_in_battle_and_save",
	&"_test_equipment_generate_and_equip",
	&"_test_equipment_enhance",
	&"_test_equipment_synergy",
	&"_test_equipment_in_battle_and_save",
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
	# 테스트 중에는 자동 저장을 끄고, 이전 실행의 저장과 상관없이 새 게임 상태에서 시작한다
	root.get_node("SaveManager").manual_only = true
	root.get_node("GameState").reset_to_new_game()
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


## 오토로드 DataRegistry (스크립트 모드에서는 전역 이름으로 컴파일할 수 없어 노드로 찾는다)
func _reg() -> Node:
	return root.get_node("DataRegistry")


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
	_check(reg.balance.has("combat"), "전투 공통 수치 로드")
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


## 전투 씬을 수동 진행 모드로 띄운다. arts를 주면 그 무공 관리자로 전투를 다시 초기화한다.
func _make_battle(arts: MartialArtManager = null) -> Node2D:
	var battle: Node2D = load("res://scenes/battle/Battle.tscn").instantiate()
	battle.manual_tick = true
	root.add_child(battle)
	if arts != null:
		battle.setup(battle.config, {}, arts)
	battle.rng.seed = 12345
	return battle


## 테스트용 새 무공 관리자 (GameState와 분리된 상태). 매화검법 개방.
func _new_arts() -> MartialArtManager:
	var arts := MartialArtManager.new(MartialArtManager.new_state("plum_blossom_sword"), _reg())
	arts.unlock("plum_blossom_sword")
	return arts


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
	print("[쓰러짐 임시 처리: 스테이지 재시작]")
	var battle := _make_battle()
	var player = battle.player
	battle.stage.kill_count = 20
	player.take_damage(player.max_hp)
	_check(player.is_down(), "체력 0이면 쓰러짐")
	var delay := float(battle.config["knockout"]["recover_delay"])
	battle.tick(delay * 0.5)
	_check(player.is_down(), "회복 대기 중에는 쓰러진 상태 유지")
	battle.tick(delay)
	_check(not player.is_down() and player.hp == player.max_hp, "대기 후 체력 전부 회복")
	_check(battle.alive_count() == 0, "회복 시 몬스터 정리")
	_check(battle.stage.stage_no == 1 and battle.stage.kill_count == 0, "현재 스테이지를 처음부터 다시 시작")
	battle.free()
	_finish()


func _test_stage_data() -> void:
	print("[스테이지 데이터]")
	var region: Dictionary = _reg().get_region("cheongpung_mountain")
	_check(region.get("name") == "청풍산", "청풍산 지역 로드")
	var stages: Array = region.get("stages", [])
	_check(stages.size() > 0 and int(stages[0]["stage_no"]) == 1, "스테이지가 번호순으로 정렬됨")
	var all_50 := true
	var scaling_up := true
	for i in stages.size():
		if int(stages[i]["kills_to_boss"]) != 50:
			all_50 = false
		if i > 0 and float(stages[i]["scaling"]) <= float(stages[i - 1]["scaling"]):
			scaling_up = false
	_check(all_50, "모든 스테이지 보스 등장 조건 50마리")
	_check(scaling_up, "스테이지가 오를수록 배율 증가")
	var boss: Dictionary = _reg().get_monster(stages[0]["boss"])
	_check(boss.get("type") == "boss" and boss.get("patterns", []).size() == 2, "보스 패턴 2개(임시)")
	_finish()


func _test_stage_data_detects_errors() -> void:
	print("[스테이지 데이터 검증]")
	var base := "user://test_stage_data"
	DirAccess.make_dir_recursive_absolute(base.path_join("stages"))
	var f := FileAccess.open(base.path_join("stages/bad_region.json"), FileAccess.WRITE)
	f.store_string('{"region_id": "bad", "name": "잘못된 지역", "stages": [{"stage_no": 1, "kills_to_boss": 50, "spawn_pool": [{"monster": "no_such_monster", "weight": 1}], "scaling": 1.0, "boss": "no_such_boss"}]}')
	f.close()
	var reg = load("res://scripts/autoload/DataRegistry.gd").new()
	var errors: int = reg.load_all(base)
	_check(errors == 2, "없는 몬스터와 보스 참조 감지 (%d건)" % errors)
	_check(not reg.regions.has("bad"), "잘못된 지역은 등록하지 않음")
	reg.free()
	DirAccess.remove_absolute(base.path_join("stages/bad_region.json"))
	_finish()


func _test_stage_manager() -> void:
	print("[스테이지 진행 상태]")
	var region: Dictionary = _reg().get_region("cheongpung_mountain")
	var sm := StageManager.new(region, 1)
	_check(sm.stage_no == 1 and sm.remaining_to_boss() == 50, "스테이지 1, 보스까지 50마리")
	_check(sm.needs_more_normals(49) and not sm.needs_more_normals(50), "남은 수만큼만 일반 몬스터 생성")
	var appeared := false
	for i in 50:
		appeared = sm.record_normal_kill()
	_check(appeared and sm.phase == StageManager.Phase.BOSS_INTRO, "50마리 처치 시 보스 등장 단계")
	_check(not sm.record_normal_kill() and sm.kill_count == 50, "보스 단계에서는 처치 수가 늘지 않음")
	sm.begin_boss()
	sm.record_boss_kill()
	_check(sm.phase == StageManager.Phase.CLEARED and int(sm.highest_cleared["cheongpung_mountain"]) == 1, "보스 처치 시 돌파 기록")
	sm.advance()
	_check(sm.stage_no == 2 and sm.kill_count == 0 and sm.phase == StageManager.Phase.NORMAL, "다음 스테이지로 진행")
	sm.start(sm.stage_count())
	sm.advance()
	_check(sm.stage_no == sm.stage_count(), "마지막 스테이지 뒤에는 마지막 스테이지 반복 (가안)")
	var save := sm.to_save()
	_check(save["region"] == "cheongpung_mountain" and save.has("highest_cleared"), "저장 데이터 모양으로 내보내기")
	_finish()


func _test_stage_loop() -> void:
	print("[스테이지 루프 시뮬레이션]")
	var battle := _make_battle()
	var stage: StageManager = battle.stage
	var boss_seen := false
	var normals_left_at_boss := -1
	var max_patterns := 0
	var t := 0.0
	while t < 600.0 and stage.stage_no == 1:
		battle.tick(0.05)
		t += 0.05
		if stage.phase == StageManager.Phase.BOSS_INTRO and normals_left_at_boss < 0:
			normals_left_at_boss = battle.alive_count()
		if is_instance_valid(battle.boss):
			boss_seen = true
			max_patterns = maxi(max_patterns, battle.boss.patterns_used)
	_check(normals_left_at_boss == 0, "일반 몬스터 50마리를 모두 처치한 뒤 보스 등장")
	_check(boss_seen, "보스가 등장함")
	_check(max_patterns >= 2, "보스가 예고 후 패턴 공격을 사용함 (%d회)" % max_patterns)
	_check(stage.stage_no == 2, "보스 처치 후 스테이지 2로 자동 진행 (%.0f초)" % t)
	_check(stage.kill_count == 0 and stage.remaining_to_boss() == 50, "새 스테이지에서 처치 진행도 초기화")
	_check(battle.player.hp == battle.player.max_hp, "새 스테이지 시작 시 체력 회복 (가안)")
	battle.free()
	_finish()


func _test_new_game_martial_arts() -> void:
	print("[새 게임 무공]")
	var arts: MartialArtManager = root.get_node("GameState").arts
	_check(arts.main_art() == "plum_blossom_sword", "시작 무공 매화검법 (확정 사항 29)")
	_check(arts.unlocked_arts() == ["plum_blossom_sword"], "처음에는 매화검법만 개방")
	_check(arts.is_tech_unlocked("plum_blossom_sword.t1") and not arts.is_tech_unlocked("plum_blossom_sword.t2"), "1초식만 해금된 상태로 시작")
	_check(arts.training_target() == "plum_blossom_sword.t1", "수련 중인 초식은 1초식")
	_finish()


## 원문 4-2 예시: 매화검법 수련 → 나한권으로 교체 → 다시 매화검법 복귀 시 기록 복원
func _test_original_scenario_switch_restore() -> void:
	print("[원문 예시: 무공 교체 시 수련 기록 보존]")
	var arts := _new_arts()
	for i in 3:
		arts.debug_set_count("plum_blossom_sword.t%d" % (i + 1), 10000)
	arts.debug_set_count("plum_blossom_sword.t4", 8214)
	_check(arts.training_target() == "plum_blossom_sword.t4", "매화검법 1~3초식 대성, 4초식 수련 중")
	arts.unlock("arhat_fist")
	arts.equip_main("arhat_fist")
	_check(arts.training_target() == "arhat_fist.t1" and arts.count_of("arhat_fist.t1") == 0, "나한권 1초식부터 새로 수련")
	for i in 5:
		arts.record_performed("arhat_fist.t1")
	_check(arts.count_of("arhat_fist.t1") == 5, "나한권 수련 기록 증가")
	_check(arts.count_of("plum_blossom_sword.t4") == 8214, "나한권 수련 중에도 매화검법 기록 유지")
	arts.equip_main("plum_blossom_sword")
	var restored := true
	for i in 3:
		restored = restored and arts.is_mastered("plum_blossom_sword.t%d" % (i + 1))
	_check(restored and arts.count_of("plum_blossom_sword.t4") == 8214, "매화검법 복귀 시 1~3초식 대성과 4초식 8,214회 복원")
	_check(arts.training_target() == "plum_blossom_sword.t4", "복귀 후 4초식부터 이어서 수련")
	_check(arts.count_of("arhat_fist.t1") == 5, "나한권 기록도 그대로 남음")
	_finish()


func _test_mastery_and_unlock() -> void:
	print("[대성과 다음 초식 해금]")
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 9999)
	_check(not arts.is_mastered("plum_blossom_sword.t1"), "9,999회는 아직 대성 아님")
	var mastered := arts.record_performed("plum_blossom_sword.t1")
	_check(mastered and arts.is_mastered("plum_blossom_sword.t1"), "10,000회 달성 시 대성")
	_check(arts.is_tech_unlocked("plum_blossom_sword.t2"), "대성하면 다음 초식 해금")
	_check(arts.training_target() == "plum_blossom_sword.t2", "수련 중인 초식이 다음 초식으로 자동 변경")
	for i in 4:
		arts.debug_set_count("plum_blossom_sword.t%d" % (i + 1), 10000)
	_check(arts.training_target() == "plum_blossom_sword.t4", "모든 초식 대성 후에는 마지막 초식 반복 (확정 사항 26)")
	_finish()


func _test_training_rules() -> void:
	print("[수련 횟수 규칙]")
	var arts := _new_arts()
	arts.record_performed("plum_blossom_sword.t1", 0.5)
	_check(arts.count_of("plum_blossom_sword.t1") == 0, "배율 0.5 한 번은 정수 횟수 0")
	arts.record_performed("plum_blossom_sword.t1", 0.5)
	_check(arts.count_of("plum_blossom_sword.t1") == 1, "소수점 누적으로 손실 없이 1회")
	arts.record_performed("plum_blossom_sword.t2")
	_check(arts.count_of("plum_blossom_sword.t2") == 0, "잠긴 초식은 수련되지 않음")
	arts.unlock("arhat_fist")
	arts.record_performed("arhat_fist.t1")
	_check(arts.count_of("arhat_fist.t1") == 0, "주력이 아닌 무공의 초식은 수련되지 않음")
	_finish()


func _test_sub_passive_only() -> void:
	print("[보조 무공은 패시브만]")
	var arts := _new_arts()
	_check(not arts.equip_sub(0, "plum_blossom_sword"), "주력과 같은 무공은 보조로 장착 불가 (가안)")
	_check(not arts.equip_sub(0, "arhat_fist"), "개방하지 않은 무공은 장착 불가")
	arts.unlock("arhat_fist")
	_check(arts.equip_sub(0, "arhat_fist"), "나한권 보조 장착")
	var battle := _make_battle(arts)
	var base_def := float(battle.config["player_base"]["def"])
	_check(battle.player.def > base_def, "보조 무공 패시브 적용 (방어력 %.1f → %.1f)" % [base_def, battle.player.def])
	var t := 0.0
	while t < 40.0:
		battle.tick(0.05)
		t += 0.05
	_check(arts.count_of("arhat_fist.t1") == 0, "보조 무공 초식은 발동·수련되지 않음")
	_check(arts.count_of("plum_blossom_sword.t1") > 0, "주력 무공 초식만 수련됨 (%d회)" % arts.count_of("plum_blossom_sword.t1"))
	arts.equip_sub(0, null)
	_check(is_equal_approx(battle.player.def, base_def), "보조 해제 시 패시브 제거")
	battle.free()
	_finish()


func _test_battle_training_single() -> void:
	print("[전투 중 단일 수련]")
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 10000)
	var battle := _make_battle(arts)
	# 대상이 없으면 초식이 발동하지 않고 수련 횟수도 오르지 않는다
	for m in battle.monsters:
		m.free()
	battle.monsters.clear()
	battle._try_cast_technique()
	_check(arts.count_of("plum_blossom_sword.t2") == 0 and battle.techniques_cast == 0, "대상이 없으면 수련 횟수가 오르지 않음")
	var t := 0.0
	while t < 40.0:
		battle.tick(0.05)
		t += 0.05
	var c2 := arts.count_of("plum_blossom_sword.t2")
	_check(c2 > 0 and c2 == battle.techniques_cast, "수련 중인 2초식만 발동하고 발동 수만큼 수련 (%d회)" % c2)
	_check(arts.count_of("plum_blossom_sword.t1") == 10000, "단일 수련에서는 대성한 1초식은 발동하지 않음")
	_check(battle.player.mp <= battle.player.max_mp, "내공 최대치 유지")
	battle.free()
	_finish()


func _test_battle_training_chain() -> void:
	print("[전투 중 연속초식 (디버그 토글)]")
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 10000)
	arts.debug_set_count("plum_blossom_sword.t2", 10000)
	arts.set_chain_mode(true)
	var battle := _make_battle(arts)
	var t := 0.0
	while t < 60.0:
		battle.tick(0.05)
		t += 0.05
	var c1 := arts.count_of("plum_blossom_sword.t1") - 10000
	var c2 := arts.count_of("plum_blossom_sword.t2") - 10000
	var c3 := arts.count_of("plum_blossom_sword.t3")
	_check(c1 > 0 and c2 > 0 and c3 > 0, "해금한 1~3초식이 모두 발동하고 수련됨 (%d, %d, %d)" % [c1, c2, c3])
	_check(absi(c1 - c3) <= 2, "1초식부터 순서대로 돌아가며 발동")
	_check(arts.training_target() == "plum_blossom_sword.t3", "연속초식 중에도 수련 중인 초식은 3초식 유지")
	battle.free()
	_finish()


## 테스트용 저장 관리자 (자동 저장 끔, 별도 폴더)
func _make_save_manager(dir: String) -> Node:
	var sm = load("res://scripts/autoload/SaveManager.gd").new()
	sm.manual_only = true
	sm.save_dir = dir
	root.add_child(sm)
	sm.delete_all()
	return sm


## 진행이 있는 테스트용 게임 상태
func _sample_state() -> Dictionary:
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 10000)
	arts.debug_set_count("plum_blossom_sword.t2", 8214)
	arts.unlock("arhat_fist")
	arts.equip_sub(0, "arhat_fist")
	arts.debug_set_count("arhat_fist.t1", 1532)
	arts.record_performed("plum_blossom_sword.t2", 0.5)
	return {
		"version": 1,
		"martial_arts": arts.state,
		"stage": {"region": "cheongpung_mountain", "stage_no": 3, "kill_count": 37, "highest_cleared": {"cheongpung_mountain": 2}},
	}


func _test_save_round_trip() -> void:
	print("[저장/불러오기 왕복]")
	var sm := _make_save_manager("user://test_save_rt")
	_check(sm.load_game().get("empty", false), "저장이 없으면 빈 상태로 알림")
	_check(sm.save_game(_sample_state()), "저장 성공")
	var sm2 := _make_save_manager_keep("user://test_save_rt")
	var r: Dictionary = sm2.load_game()
	_check(r.get("ok", false), "불러오기 성공")
	var arts := MartialArtManager.new(r["data"]["martial_arts"], _reg())
	_check(arts.main_art() == "plum_blossom_sword" and arts.sub_arts()[0] == "arhat_fist", "장착 정보 복원")
	_check(arts.is_mastered("plum_blossom_sword.t1") and arts.count_of("plum_blossom_sword.t2") == 8214, "무공별·초식별 진행도 복원")
	_check(is_equal_approx(float(arts.progress_of("plum_blossom_sword.t2")["fraction"]), 0.5), "소수점 누적값 복원")
	_check(arts.count_of("arhat_fist.t1") == 1532, "보조 무공 진행도 복원")
	_check(arts.training_target() == "plum_blossom_sword.t2", "수련 중인 초식 다시 계산")
	var st: Dictionary = r["data"]["stage"]
	_check(int(st["stage_no"]) == 3 and int(st["kill_count"]) == 37, "스테이지와 처치 수 복원")
	arts.record_performed("plum_blossom_sword.t2")
	_check(arts.count_of("plum_blossom_sword.t2") == 8215, "불러온 뒤에도 수련 기록이 이어짐")
	sm.queue_free()
	sm2.queue_free()
	_finish()


## 폴더를 비우지 않고 만드는 저장 관리자 (다시 실행한 앱을 흉내)
func _make_save_manager_keep(dir: String) -> Node:
	var sm = load("res://scripts/autoload/SaveManager.gd").new()
	sm.manual_only = true
	sm.save_dir = dir
	root.add_child(sm)
	return sm


func _test_save_double_slots() -> void:
	print("[이중 저장]")
	var sm := _make_save_manager("user://test_save_ds")
	var state := _sample_state()
	sm.save_game(state)
	var first: String = sm.last_slot
	state["stage"]["kill_count"] = 40
	sm.save_game(state)
	_check(sm.last_slot != first, "저장할 때마다 슬롯을 번갈아 씀")
	_check(FileAccess.file_exists("user://test_save_ds/save_a.json") and FileAccess.file_exists("user://test_save_ds/save_b.json"), "슬롯 2개가 모두 있음")
	_check(not FileAccess.file_exists("user://test_save_ds/save_a.json.tmp") and not FileAccess.file_exists("user://test_save_ds/save_b.json.tmp"), "임시 파일이 남지 않음")
	var r: Dictionary = _make_save_manager_keep("user://test_save_ds").load_game()
	_check(r["ok"] and int(r["data"]["stage"]["kill_count"]) == 40 and int(r["data"]["save_seq"]) == 2, "최신 저장(순번 2)을 불러옴")
	_finish()


func _test_save_corruption_recovery() -> void:
	print("[저장 파일 손상 복구]")
	var dir := "user://test_save_cr"
	var sm := _make_save_manager(dir)
	var state := _sample_state()
	sm.save_game(state)
	state["stage"]["kill_count"] = 45
	sm.save_game(state)
	var newest: String = dir.path_join(sm.last_slot)
	# 최신 파일의 본문 한 글자를 바꾼다 (해시 불일치)
	var text := FileAccess.get_file_as_string(newest)
	var f := FileAccess.open(newest, FileAccess.WRITE)
	f.store_string(text.replace("\\\"kill_count\\\":45", "\\\"kill_count\\\":46"))
	f.close()
	_check(FileAccess.get_file_as_string(newest) != text, "최신 저장 파일을 일부러 깨뜨림")
	var r: Dictionary = _make_save_manager_keep(dir).load_game()
	_check(r["ok"] and int(r["data"]["stage"]["kill_count"]) == 37, "깨진 파일 대신 다른 슬롯에서 복구")
	# 다른 슬롯은 반쯤 잘린 파일로 만든다
	var other := dir.path_join(sm.SLOT_A if sm.last_slot == sm.SLOT_B else sm.SLOT_B)
	var t2 := FileAccess.get_file_as_string(other)
	var f2 := FileAccess.open(other, FileAccess.WRITE)
	f2.store_string(t2.substr(0, t2.length() / 2))
	f2.close()
	var r2: Dictionary = _make_save_manager_keep(dir).load_game()
	_check(not r2["ok"] and not r2.get("empty", false) and r2.get("error", "") != "", "두 파일이 모두 깨지면 오류로 알림 (%s)" % r2.get("error", ""))
	_finish()


func _test_save_version_and_migration() -> void:
	print("[버전 확인과 마이그레이션]")
	var dir := "user://test_save_mg"
	var sm := _make_save_manager(dir)
	sm.save_game(_sample_state())
	# v1 → v2 테스트용 변환: 새 필드를 기본값으로 채운다
	var sm2 := _make_save_manager_keep(dir)
	sm2.target_version = 2
	sm2.migrations[1] = func(d: Dictionary) -> Dictionary:
		d["test_new_field"] = {"filled": true}
		return d
	var r: Dictionary = sm2.load_game()
	_check(r["ok"] and r["migrated"], "낮은 버전 저장을 마이그레이션해 불러옴")
	_check(int(r["data"]["version"]) == 2 and r["data"]["test_new_field"]["filled"], "v1 → v2 변환 적용")
	_check(int(r["data"]["stage"]["stage_no"]) == 3, "변환 후에도 기존 진행 유지")
	var backups := Array(DirAccess.get_files_at(dir)).filter(func(n): return n.begins_with("backup_v1_"))
	_check(backups.size() == 1, "변환 전 원본을 백업으로 보관")
	var sm3 := _make_save_manager_keep(dir)
	sm3.target_version = 3
	_check(not sm3.load_game()["ok"], "중간 변환이 없으면 불러오지 않음")
	# 앱보다 높은 버전
	var sm4 := _make_save_manager(dir + "_hi")
	var hi := _sample_state()
	hi["version"] = 99
	sm4.save_game(hi)
	var r4: Dictionary = _make_save_manager_keep(dir + "_hi").load_game()
	_check(not r4["ok"] and String(r4["error"]).contains("업데이트"), "앱보다 높은 버전은 불러오지 않고 업데이트 안내")
	_finish()


func _test_save_restores_stage_in_battle() -> void:
	print("[불러온 진행을 전투에 적용]")
	var gs := root.get_node("GameState")
	var loaded := _sample_state()
	gs.apply_loaded(loaded.duplicate(true))
	_check(gs.arts.sub_arts()[0] == "arhat_fist" and gs.arts.count_of("plum_blossom_sword.t2") == 8214, "GameState에 무공 진행 적용")
	var battle := _make_battle()
	_check(battle.stage.stage_no == 3 and battle.stage.kill_count == 37, "전투가 저장된 스테이지 3, 처치 37에서 시작")
	_check(battle.player.max_hp > int(battle.config["player_base"]["max_hp"]), "보조 무공 패시브도 적용됨")
	battle.tick(0.05)
	_check(int(gs.data["stage"]["stage_no"]) == 3, "전투 진행이 GameState 스테이지에 기록됨")
	battle.free()
	gs.reset_to_new_game()
	_finish()




func _test_chain_toggle_off_returns_to_single() -> void:
	print("[M5 연속초식 켜고 끄기]")
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 10000)
	arts.debug_set_count("plum_blossom_sword.t2", 10000)
	var battle := _make_battle(arts)
	arts.set_chain_mode(true)
	var t := 0.0
	while t < 30.0:
		battle.tick(0.05)
		t += 0.05
	var on_c1 := arts.count_of("plum_blossom_sword.t1")
	_check(on_c1 > 10000, "켜면 대성한 1초식도 순서대로 발동")
	arts.set_chain_mode(false)
	battle.techniques.reset_chain()
	var c1 := arts.count_of("plum_blossom_sword.t1")
	var c2 := arts.count_of("plum_blossom_sword.t2")
	var c3 := arts.count_of("plum_blossom_sword.t3")
	t = 0.0
	while t < 30.0:
		battle.tick(0.05)
		t += 0.05
	_check(arts.count_of("plum_blossom_sword.t1") == c1 and arts.count_of("plum_blossom_sword.t2") == c2, "끄면 대성한 초식은 발동하지 않음")
	_check(arts.count_of("plum_blossom_sword.t3") > c3, "끄면 수련 중인 3초식만 다시 반복")
	battle.free()
	_finish()


func _test_game_ui_chain_button() -> void:
	print("[M5 연속초식 버튼과 앱바]")
	var arts := _new_arts()
	var ui = load("res://scripts/ui/GameUi.gd").new()
	ui.arts = arts
	root.add_child(ui)
	ui._process(0.0)
	_check(not ui._chain_button.button_pressed and ui._chain_button.text.contains("OFF"), "처음에는 단일 수련(OFF)")
	ui._chain_button.button_pressed = true
	ui._process(0.0)
	_check(arts.is_chain_mode() and ui._chain_button.text.contains("ON"), "버튼을 누르면 연속초식 ON")
	_check(ui._chain_label.text.contains("1"), "켜짐 상태에 발동 순서 표시")
	ui._chain_button.button_pressed = false
	_check(not arts.is_chain_mode(), "다시 누르면 단일 수련으로 돌아감")
	ui.open_menu("growth")
	_check(ui.panels["growth"].visible, "앱바 육성 메뉴가 육성 화면을 엶")
	ui.open_menu("")
	_check(not ui.panels["growth"].visible, "닫기")
	ui.free()
	_finish()


func _test_effect_presets() -> void:
	print("[M6 이펙트 프리셋]")
	var presets: Dictionary = _reg().effects.get("effect_presets", {})
	_check(EffectPresets.validate(presets).is_empty(), "프리셋 데이터 검증 통과 (3계열, 7단계, 단계마다 커짐)")
	var th: Array = _reg().balance["training"]["stage_thresholds"]
	_check(EffectPresets.stage_index_for(0, th) == 1, "0회는 입문(1단계)")
	_check(EffectPresets.stage_index_for(100, th) == 2, "100회는 초급(2단계)")
	_check(EffectPresets.stage_index_for(7500, th) == 6, "7,500회는 절정(6단계)")
	_check(EffectPresets.stage_index_for(10000, th) == 6, "대성 플래그가 없으면 7단계로 올리지 않음")
	_check(EffectPresets.stage_index_for(10000, th, true) == 7, "대성하면 7단계")
	var cats_ok := true
	var grows := true
	for cat in ["sword", "fist", "spell"]:
		var prev: Dictionary = {}
		for st in range(1, 8):
			var p := EffectPresets.resolve(presets, cat, st)
			if p["category"] != cat:
				cats_ok = false
			if not prev.is_empty() and (int(p["particles"]) < int(prev["particles"]) or float(p["scale"]) < float(prev["scale"]) or float(p["duration"]) < float(prev["duration"])):
				grows = false
			prev = p
	_check(cats_ok, "3계열 × 7단계 프리셋이 모두 해석됨")
	_check(grows, "단계가 오를수록 파티클 수, 크기, 지속 시간이 줄지 않음")
	var sw := EffectPresets.resolve(presets, "sword", 1)
	var fi := EffectPresets.resolve(presets, "fist", 1)
	_check(sw["color_primary"] != fi["color_primary"] and sw["particle_shape"] != fi["particle_shape"], "계열마다 색과 파티클 모양이 다름")
	_check(EffectPresets.resolve(presets, "unknown", 3)["category"] == "sword", "모르는 계열은 기본 계열 사용")
	var m := EffectPresets.resolve(presets, "sword", 7, {"mastery_effect": "plum_special"})
	_check(m["mastery_effect"] == "plum_special" and bool(m.get("mastery_burst", false)), "대성 단계는 초식 전용 연출 지정을 받음 (없으면 계열 대성 프리셋)")
	_finish()


func _test_effect_director_in_battle() -> void:
	print("[M6 전투 중 이펙트]")
	var arts := _new_arts()
	var battle := _make_battle(arts)
	var fx: EffectDirector = battle.effects
	_check(fx != null and fx.max_active > 0, "전투에 이펙트 관리자가 붙음")
	arts.debug_set_count("plum_blossom_sword.t1", 95)
	var t := 0.0
	var played_before := fx.played_count
	var stage_up_seen := false
	while t < 40.0 and arts.count_of("plum_blossom_sword.t1") < 102:
		battle.tick(0.05)
		for c in fx.get_children():
			if c.kind == "stage_up":
				stage_up_seen = true
		t += 0.05
	_check(fx.played_count > played_before, "초식 발동 때 연출이 재생됨")
	_check(fx.last_params.get("category", "") == "sword", "매화검법은 검법 계열 연출")
	_check(stage_up_seen, "입문 → 초급으로 오를 때 단계 상승 알림 연출")
	_check(int(fx.last_params.get("stage", 0)) == 2, "초급이 되면 2단계 프리셋으로 바뀜")
	arts.debug_set_count("plum_blossom_sword.t1", 9998)
	var mastery_seen := false
	t = 0.0
	while t < 30.0 and not arts.is_mastered("plum_blossom_sword.t1"):
		battle.tick(0.05)
		t += 0.05
	for c in fx.get_children():
		if c.kind == "mastery":
			mastery_seen = true
	_check(mastery_seen and battle.banner_text.contains("대성"), "대성 순간 대성 알림 연출과 안내")
	battle.free()
	_finish()


func _test_effect_performance_cap() -> void:
	print("[M6 이펙트 성능 상한]")
	var fx := EffectDirector.new()
	root.add_child(fx)
	fx.setup(_reg().effects.get("effect_presets", {}), 760.0)
	fx.rng.seed = 1
	var started := Time.get_ticks_usec()
	for i in 200:
		fx.play_technique("fist", 7, Vector2(160, 760), [Vector2(400, 760), Vector2(460, 760)])
		fx.tick(1.0 / 60.0)
	var per_frame_ms := float(Time.get_ticks_usec() - started) / 200.0 / 1000.0
	print("    (참고) 최대 단계 연출 연속 재생 시 프레임당 갱신 %.3f ms" % per_frame_ms)
	_check(fx.active_count() <= fx.max_active, "동시에 살아 있는 연출 수가 상한(%d) 이하" % fx.max_active)
	fx.play_mastery("sword", Vector2(140, 700), "테스트 대성!")
	for i in 20:
		fx.play_technique("sword", 7, Vector2(160, 760), [Vector2(400, 760)])
	var kept := false
	for c in fx.get_children():
		if c.kind == "mastery":
			kept = true
	_check(kept, "상한을 넘겨도 대성 알림은 초식 연출보다 늦게 지움")
	_check(per_frame_ms < 4.0, "연출 갱신 비용이 프레임 예산 안 (4ms 미만, 헤드리스 기준)")
	for i in 200:
		fx.tick(0.05)
	_check(fx.active_count() == 0 and fx.shake_offset == Vector2.ZERO, "연출이 끝나면 모두 정리되고 흔들림도 멈춤")
	fx.free()
	_finish()


func _growth_cfg() -> Dictionary:
	return _reg().balance.get("growth", {})


func _test_growth_level_and_exp() -> void:
	print("[M7 경험치와 레벨]")
	var g := CharacterGrowth.new(CharacterGrowth.new_state(), _growth_cfg())
	_check(g.level() == 1 and g.current_exp() == 0 and g.realm_tier() == 1, "새 캐릭터: Lv 1, 경험치 0, 삼류 무인")
	_check(g.exp_to_next() == 100, "Lv 1 → 2 필요 경험치 100 (100 × 1^1.6)")
	g.state["level"] = 10
	_check(g.exp_to_next() == int(round(100.0 * pow(10.0, 1.6))), "Lv 10 필요 경험치 = 100 × 10^1.6")
	g.state["level"] = 1
	var ups := g.add_exp(99)
	_check(ups == 0 and g.current_exp() == 99, "모자라면 레벨이 오르지 않음")
	ups = g.add_exp(1)
	_check(ups == 1 and g.level() == 2 and g.current_exp() == 0, "채우면 레벨 업, 남는 경험치 이월")
	ups = g.add_exp(100000)
	_check(ups > 1, "많이 얻으면 여러 레벨이 한 번에 오름")
	var b := g.stat_bonuses()
	_check(is_equal_approx(float(b["atk"]["percent"]), pow(1.03, g.level() - 1) - 1.0), "레벨당 공격력 +3% 복리")
	g.state["level"] = g.level_cap() - 1
	g.add_exp(99999999)
	_check(g.level() == g.level_cap() and g.current_exp() == 0 and g.add_exp(100) == 0, "레벨 상한에서 멈춤 (가안 %d)" % g.level_cap())
	_finish()


func _test_growth_realm_promotion() -> void:
	print("[M7 경지 승급]")
	var g := CharacterGrowth.new(CharacterGrowth.new_state(), _growth_cfg())
	_check(g.realms().size() == 9 and g.realm()["name"] == "삼류 무인" and g.realms()[8]["name"] == "무극", "경지 9단계 데이터 (삼류 무인 ~ 무극)")
	g.state["level"] = 10
	_check(not g.can_promote(0), "레벨만 채우고 대성 초식이 없으면 승급 불가")
	g.state["level"] = 9
	_check(not g.can_promote(1), "대성만 채우고 레벨이 모자라면 승급 불가")
	g.state["level"] = 10
	var promoted := [0]
	g.realm_promoted.connect(func(_t): promoted[0] += 1)
	_check(g.try_promote(1) == 1 and g.realm()["name"] == "이류 무인", "Lv 10 + 대성 1개 → 이류 무인")
	g.state["level"] = 35
	_check(g.try_promote(6) == 2 and g.realm()["name"] == "절정 고수", "조건을 넘게 채우면 여러 단계 한 번에 승급")
	_check(promoted[0] == 2, "승급 알림 신호")
	var b := g.stat_bonuses()
	_check(float(b["def"]["percent"]) > 0.3, "경지 보너스가 능력치에 반영 (가안)")
	g.state["level"] = 150
	g.try_promote(100)
	_check(g.realm_tier() == 9 and not g.can_promote(999), "무극이 최고 경지")
	var arts := _new_arts()
	arts.debug_set_count("plum_blossom_sword.t1", 10000)
	arts.debug_set_count("plum_blossom_sword.t2", 10000)
	arts.unlock("arhat_fist")
	arts.debug_set_count("arhat_fist.t1", 10000)
	_check(arts.total_mastered() == 3, "대성 초식 수는 모든 무공 합산")
	_finish()


func _test_growth_in_battle_and_save() -> void:
	print("[M7 전투 경험치, HUD, 저장]")
	var arts := _new_arts()
	var battle := _make_battle(arts)
	var g: CharacterGrowth = battle.growth
	var cp0: int = battle.combat_power()
	var atk0: float = battle.player.atk
	var t := 0.0
	while t < 120.0 and g.level() < 2:
		battle.tick(0.05)
		t += 0.05
	_check(g.level() >= 2, "몬스터를 처치하면 경험치가 쌓여 레벨 업")
	_check(battle.player.atk > atk0 and battle.combat_power() > cp0, "레벨 업하면 공격력과 전투력이 오름")
	_check(battle.banner_text.contains("레벨") or battle.banner_text != "", "레벨 업 안내")
	g.state["level"] = 10
	arts.debug_set_count("plum_blossom_sword.t1", 9999)
	t = 0.0
	while t < 30.0 and g.realm_tier() == 1:
		battle.tick(0.05)
		t += 0.05
	_check(g.realm()["name"] == "이류 무인", "Lv 10에서 첫 초식을 대성하면 이류 무인으로 자동 승급")
	_check(battle.banner_text.contains("이류"), "승급 안내가 HUD에 뜸")
	battle.free()
	# 저장/불러오기
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	gs.growth.add_exp(5000)
	gs.growth.state["realm_tier"] = 2
	var lv: int = gs.growth.level()
	var sm = _make_save_manager("user://test_m7_save")
	sm.save_game()
	gs.reset_to_new_game()
	var r: Dictionary = sm.load_game()
	gs.apply_loaded(r["data"])
	_check(gs.growth.level() == lv and gs.growth.realm_tier() == 2, "레벨과 경지가 저장/불러오기로 유지")
	var old: Dictionary = r["data"].duplicate(true)
	old.erase("character")
	gs.apply_loaded(old)
	_check(gs.growth.level() == 1, "예전 저장(캐릭터 항목 없음)도 기본값으로 불러옴")
	sm.delete_all()
	sm.free()
	gs.reset_to_new_game()
	_finish()


func _new_equipment() -> EquipmentManager:
	return EquipmentManager.new(EquipmentManager.new_state(), EquipmentManager.new_currencies(), _reg().equipment)


func _test_equipment_generate_and_equip() -> void:
	print("[M8 장비 생성, 드롭, 장착]")
	var eq := _new_equipment()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_check(eq.slot_ids().size() == 5 and eq.cfg["grades"].size() == 6, "5부위, 6등급 데이터")
	var common := eq.generate("weapon", "common", 1.0, rng)
	var mythic := eq.generate("weapon", "mythic", 1.0, rng)
	_check(float(mythic["base"]["atk"]) > float(common["base"]["atk"]) * 3.5, "등급이 높을수록 기본 능력치 배율이 큼 (신화 x4.0)")
	_check(common["options"].size() == 0 and mythic["options"].size() == 4, "추가 옵션 수: 일반 0, 신화 3 + 고정 시너지 1")
	var fixed := false
	for o in mythic["options"]:
		if o.get("fixed", false) and eq.option_data(o["id"]).get("synergy", false):
			fixed = true
	_check(fixed, "신화는 무공 시너지 옵션 1개 고정")
	var far := eq.generate("weapon", "common", 2.0, rng)
	_check(is_equal_approx(float(far["base"]["atk"]), float(common["base"]["atk"]) * 2.0), "스테이지 배율이 기본 능력치에 곱해짐")
	var acc := eq.generate("accessory", "common", 2.0, rng)
	_check(is_equal_approx(float(acc["base"]["crit_rate"]), 0.02), "치명타 확률은 스테이지 배율을 받지 않음")
	var counts := {}
	for i in 5000:
		var g := eq.roll_grade(rng)
		counts[g] = int(counts.get(g, 0)) + 1
	_check(int(counts.get("common", 0)) > int(counts.get("rare", 0)) and int(counts.get("rare", 0)) > int(counts.get("legendary", 0)), "드롭 등급 가중치 (일반 > 희귀 > 전설)")
	var boss_drop := eq.roll_drop(true, 1.0, rng)
	_check(not boss_drop["item"].is_empty() and boss_drop["added"] and eq.stone() == 3, "보스는 장비 1개와 강화석 3개 확정 (가안)")
	eq.add_item(common)
	_check(eq.equip(int(common["uid"])) and eq.equipped_uid("weapon") == int(common["uid"]), "장착")
	_check(not eq.discard(int(common["uid"])), "장착 중인 장비는 버릴 수 없음")
	eq.add_item(far)
	eq.equip(int(far["uid"]))
	_check(eq.equipped_uid("weapon") == int(far["uid"]), "같은 부위에 장착하면 교체")
	_check(is_equal_approx(float(eq.stat_bonuses()["atk"]["flat"]), float(far["base"]["atk"])), "장착 장비 기본 능력치가 보너스로 들어감")
	eq.unequip("weapon")
	_check(eq.equipped_item("weapon").is_empty() and eq.discard(int(common["uid"])), "해제 후 버리기")
	eq.state["inventory"].clear()
	for i in eq.capacity():
		eq.add_item(eq.generate("shoes", "common", 1.0, rng))
	_check(not eq.add_item(eq.generate("shoes", "common", 1.0, rng)) and eq.items().size() == eq.capacity(), "보관함이 가득 차면 더 넣지 않음 (가안 %d칸)" % eq.capacity())
	_finish()


func _test_equipment_enhance() -> void:
	print("[M8 강화]")
	var eq := _new_equipment()
	var rng := RandomNumberGenerator.new()
	var it := eq.generate("armor", "rare", 1.0, rng)
	eq.add_item(it)
	var uid := int(it["uid"])
	_check(eq.enhance(uid) == EquipmentManager.EnhanceResult.NOT_ENOUGH and int(it["enh"]) == 0, "재화가 없으면 강화 불가")
	eq.add_currency("stone", 1000)
	eq.add_currency("silver", 1000000)
	var c0 := eq.enhance_cost(it)
	var def0 := float(eq.item_base_stats(it)["def"])
	_check(eq.enhance(uid) == EquipmentManager.EnhanceResult.OK and int(it["enh"]) == 1, "강화석과 은냥으로 강화 (가안: 항상 성공)")
	_check(eq.stone() == 1000 - int(c0["stone"]) and eq.silver() == 1000000 - int(c0["silver"]), "강화 비용 차감")
	_check(is_equal_approx(float(eq.item_base_stats(it)["def"]), def0 * 1.05), "강화 1단계당 기본 능력치 +5%")
	_check(int(eq.enhance_cost(it)["silver"]) > int(c0["silver"]), "강화 단계가 오를수록 비용 증가")
	for i in 30:
		eq.enhance(uid)
	_check(int(it["enh"]) == eq.max_enhance() and eq.enhance(uid) == EquipmentManager.EnhanceResult.MAX_LEVEL, "최대 강화 단계에서 멈춤 (가안 +%d)" % eq.max_enhance())
	_check(eq.item_name(it).ends_with("+%d" % eq.max_enhance()), "이름에 강화 단계 표시")
	_finish()


func _test_equipment_synergy() -> void:
	print("[M8 무공 시너지 옵션]")
	var eq := _new_equipment()
	var rng := RandomNumberGenerator.new()
	var it := eq.generate("weapon", "common", 1.0, rng)
	it["options"] = [{"id": "plum_damage", "value": 0.2}, {"id": "sword_damage", "value": 0.1}, {"id": "plum_t1_damage", "value": 0.3}, {"id": "boss_damage", "value": 0.1}, {"id": "crit_rate", "value": 0.02}]
	eq.add_item(it)
	eq.equip(int(it["uid"]))
	_check(is_equal_approx(eq.technique_bonus("plum_blossom_sword.t1", "plum_blossom_sword", "sword"), 0.6), "매화검법 1초식: 무공 + 계열 + 초식 시너지 합산")
	_check(is_equal_approx(eq.technique_bonus("plum_blossom_sword.t2", "plum_blossom_sword", "sword"), 0.3), "매화검법 2초식: 초식 전용 옵션은 빠짐")
	_check(is_equal_approx(eq.technique_bonus("arhat_fist.t1", "arhat_fist", "fist"), 0.0), "매화검법 시너지는 나한권 초식에 적용되지 않음")
	_check(is_equal_approx(eq.effect_total("boss_damage"), 0.1), "보스 피해 옵션")
	_check(is_equal_approx(float(eq.stat_bonuses()["crit_rate"]["flat"]), 0.02), "능력치 옵션은 능력치 보너스로")
	_check(eq.option_text({"id": "plum_damage", "value": 0.2}).contains("20.0%"), "옵션 설명 문구")
	# 실제 피해 비교
	var arts := _new_arts()
	var battle := _make_battle(arts)
	battle.equipment.add_item(it.duplicate(true))
	var dummy = battle.spawn_monster("test_brute")
	dummy.position.x = battle.player.position.x + 60
	var tech: Dictionary = _reg().get_technique("plum_blossom_sword.t1")
	var rng2 := RandomNumberGenerator.new()
	battle.player.crit_rate = 0.0
	var plain: int = battle.player.cast_technique(tech, [dummy], rng2, 100.0, Color.WHITE, 0.0)[0]["damage"]
	var boosted: int = battle.player.cast_technique(tech, [dummy], rng2, 100.0, Color.WHITE, 0.6)[0]["damage"]
	_check(boosted > plain, "시너지 보너스가 초식 피해를 올림 (%d → %d)" % [plain, boosted])
	battle.player.damage_reduction = 0.5
	var hp0: int = battle.player.hp
	var taken: int = battle.player.take_damage(100)
	_check(taken == 50 and battle.player.hp == hp0 - 50, "피해 감소 옵션이 받는 피해를 줄임")
	battle.free()
	_finish()


func _test_equipment_in_battle_and_save() -> void:
	print("[M8 전투 드롭, 장착 반영, 저장]")
	var arts := _new_arts()
	var battle := _make_battle(arts)
	var eq: EquipmentManager = battle.equipment
	var t := 0.0
	while t < 900.0 and eq.items().is_empty():
		battle.tick(0.05)
		t += 0.05
	_check(eq.silver() > 0, "몬스터 처치로 은냥 획득")
	_check(not eq.items().is_empty(), "스테이지 진행 중 장비 드롭")
	var atk0: float = battle.player.atk
	var cp0: int = battle.combat_power()
	var w := eq.generate("weapon", "legendary", 1.0, battle.rng)
	eq.add_item(w)
	eq.equip(int(w["uid"]))
	_check(battle.player.atk > atk0 and battle.combat_power() > cp0, "장착하면 캐릭터 공격력과 전투력이 바로 오름")
	battle.free()
	var ui = load("res://scripts/ui/GameUi.gd").new()
	ui.arts = arts
	ui.equipment = eq
	root.add_child(ui)
	ui.open_menu("equipment")
	_check(ui.panels.has("equipment") and ui.panels["equipment"].visible, "앱바 장비 메뉴가 장비 화면을 엶")
	ui.free()
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var it: Dictionary = gs.equipment.generate("helmet", "epic", 1.5, RandomNumberGenerator.new())
	gs.equipment.add_item(it)
	gs.equipment.equip(int(it["uid"]))
	gs.equipment.add_currency("silver", 1234)
	gs.equipment.add_currency("stone", 7)
	var sm = _make_save_manager("user://test_m8_save")
	sm.save_game()
	gs.reset_to_new_game()
	gs.apply_loaded(sm.load_game()["data"])
	var back: Dictionary = gs.equipment.equipped_item("helmet")
	_check(not back.is_empty() and back["grade"] == "epic" and back["options"].size() == it["options"].size(), "장착 장비와 옵션이 저장/불러오기로 유지")
	_check(gs.equipment.silver() == 1234 and gs.equipment.stone() == 7, "은냥과 강화석 유지")
	var nx: Dictionary = gs.equipment.generate("shoes", "common", 1.0, RandomNumberGenerator.new())
	_check(int(nx["uid"]) > int(it["uid"]), "불러온 뒤에도 장비 고유 번호가 겹치지 않음")
	sm.delete_all()
	sm.free()
	gs.reset_to_new_game()
	_finish()
