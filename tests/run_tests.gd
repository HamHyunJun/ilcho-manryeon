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
	&"_test_twenty_stages_and_monsters",
	&"_test_ranged_monster",
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
	&"_test_manual_fragments_unlock",
	&"_test_dungeon_entry_and_rewards",
	&"_test_dungeon_run_in_battle",
	&"_test_codex_and_dungeon_ui",
	&"_test_dungeon_data_and_difficulty",
	&"_test_dungeon_levels_and_sweep",
	&"_test_equipment_dungeon_rewards",
	&"_test_currency_dungeon_weekday",
	&"_test_new_dungeons_in_battle",
	&"_test_dungeon_panel_cards",
	&"_test_offline_elapsed_and_clock",
	&"_test_offline_training_apply",
	&"_test_offline_game_flow",
	&"_test_save_export_import",
	&"_test_settings_and_sound",
	&"_test_tutorial_steps",
	&"_test_design_visuals",
	&"_test_equipment_summon_and_level_up",
	&"_test_app_bar_touch_and_tall_screen",
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
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep_width", "가로 720 고정, 세로로 긴 화면은 높이를 늘림")
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
	var group: int = battle.alive_count()
	_check(group >= int(cfg["spawn"]["group_min"]) and group <= int(cfg["spawn"]["group_max"]), "전투 시작 시 몬스터가 무리로 생성됨 (%d마리)" % group)
	var first = battle.monsters[0]
	var all_right := true
	var stops := {}
	for m in battle.monsters:
		if m.position.x < float(cfg["layout"]["spawn_x"]) - 15.0:  # 생성된 프레임에 한 걸음 움직일 수 있다
			all_right = false
		stops[snappedf(m.stop_range, 0.1)] = true
		if m.stop_range > m.attack_range:
			all_right = false
	_check(all_right, "몬스터는 화면 오른쪽에서 생성되고, 멈추는 거리는 사거리 이하")
	_check(stops.size() == group, "무리 안에서 멈추는 거리가 서로 달라 한 점에 겹치지 않음")
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
	_check(boss.get("type") == "boss" and boss.get("patterns", []).size() == 2, "스테이지 1 보스 패턴 2개")
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


## 20스테이지: 구역별 몬스터 구성, 보스 배치, 난이도 상승 (O-10 가안)
func _test_twenty_stages_and_monsters() -> void:
	print("[20스테이지와 스테이지별 몬스터]")
	var reg := _reg()
	var stages: Array = reg.get_region("cheongpung_mountain").get("stages", [])
	_check(stages.size() == 20, "청풍산 스테이지 20개 (%d)" % stages.size())
	# 구역마다 등장하는 일반 몬스터 구성이 다르다
	var area_sets := {}
	var areas_ok := true
	for s in stages:
		var area: String = s.get("area", "")
		if area == "":
			areas_ok = false
		var ids: Array = []
		for e in s["spawn_pool"]:
			ids.append(e["monster"])
		ids.sort()
		if not area_sets.has(area):
			area_sets[area] = {}
		area_sets[area][",".join(ids)] = true
	_check(areas_ok and area_sets.size() == 4, "5스테이지씩 구역 4개 (%s)" % ", ".join(area_sets.keys()))
	# 이웃한 스테이지끼리 생성 구성(비율 포함)이 모두 다르다
	var pools_differ := true
	for i in range(1, stages.size()):
		if JSON.stringify(stages[i]["spawn_pool"]) == JSON.stringify(stages[i - 1]["spawn_pool"]):
			pools_differ = false
	_check(pools_differ, "스테이지마다 몬스터 구성(종류/비율)이 다름")
	var first_ids := {}
	for e in stages[0]["spawn_pool"]:
		first_ids[e["monster"]] = true
	var last_new := true
	for e in stages[19]["spawn_pool"]:
		if first_ids.has(e["monster"]):
			last_new = false
	_check(last_new, "스테이지 20에는 스테이지 1의 몬스터가 나오지 않음")
	# 보스: 2스테이지마다 바뀌고, 5·10·15·20은 구역 대장
	var boss_ids := {}
	for s in stages:
		boss_ids[s["boss"]] = true
	_check(boss_ids.size() == 12, "보스 12종 (%d)" % boss_ids.size())
	var chapter_ok := true
	for no in [10, 15, 20]:
		var b: Dictionary = reg.get_monster(stages[no - 1]["boss"])
		if b.get("patterns", []).size() != 3:
			chapter_ok = false
	_check(chapter_ok, "10·15·20스테이지 구역 대장 보스는 패턴 3개")
	_check(stages[4]["boss"] == "test_boss", "5스테이지 보스는 산채 두목")
	# 난이도: 배율, 일반 몬스터 평균 체력, 보스 체력, 보상이 스테이지마다 오른다
	var prev_hp := 0.0
	var prev_boss := 0.0
	var prev_reward := 0.0
	var hp_up := true
	var boss_up := true
	var reward_up := true
	var ratio_ok := true
	for s in stages:
		var sc := float(s["scaling"])
		var total := 0.0
		var hp := 0.0
		var reward := 0.0
		for e in s["spawn_pool"]:
			var m: Dictionary = reg.get_monster(e["monster"])
			total += float(e["weight"])
			hp += float(m["max_hp"]) * float(e["weight"])
			reward += float(m["rewards"]["silver"]) * float(e["weight"])
		hp = hp / total * sc
		reward = reward / total * sc
		var boss_hp := float(reg.get_monster(s["boss"])["max_hp"]) * sc
		if hp <= prev_hp:
			hp_up = false
		if boss_hp <= prev_boss:
			boss_up = false
		if reward <= prev_reward:
			reward_up = false
		if boss_hp / hp < 15.0 or boss_hp / hp > 50.0:
			ratio_ok = false
		prev_hp = hp
		prev_boss = boss_hp
		prev_reward = reward
	_check(hp_up, "일반 몬스터 평균 체력이 스테이지마다 오름 (20스테이지 %.0f)" % prev_hp)
	_check(boss_up, "보스 체력이 스테이지마다 오름 (20스테이지 %.0f)" % prev_boss)
	_check(reward_up, "일반 몬스터 평균 은냥 보상이 스테이지마다 오름")
	_check(ratio_ok, "보스 체력은 같은 스테이지 일반 몬스터 평균의 15~50배")
	# 모든 몬스터 그림이 만들어진다
	var art_ok := true
	for id in reg.monsters:
		var m: Dictionary = reg.monsters[id]
		var art := ChibiArt.monster(String(m.get("sprite", "bandit")))
		if not (art.get("body") is Texture2D) or not (art.get("weapon") is Texture2D):
			art_ok = false
	_check(art_ok, "모든 몬스터의 2등신 스프라이트 생성 (%d종)" % reg.monsters.size())
	# 스테이지 관리자와 실제 생성
	var sm := StageManager.new(reg.get_region("cheongpung_mountain"), 12)
	_check(sm.area_name() == "철문관", "스테이지 12 구역 이름: 철문관")
	var battle := _make_battle()
	battle.stage.start(17)
	var spawned := {}
	for i in 40:
		spawned[battle._pick_spawn_id()] = true
	var allowed := {}
	for e in battle.stage.current()["spawn_pool"]:
		allowed[e["monster"]] = true
	var only_pool := true
	for id in spawned:
		if not allowed.has(id):
			only_pool = false
	_check(only_pool and spawned.size() >= 2, "스테이지 17에서는 그 스테이지 몬스터만 생성 (%s)" % ", ".join(spawned.keys()))
	battle.free()
	_finish()


## 원거리형(삿갓 궁수)은 멀리서 멈춰 공격한다
func _test_ranged_monster() -> void:
	print("[원거리형 몬스터]")
	var battle := _make_battle()
	for m in battle.monsters:
		m.queue_free()
	battle.monsters.clear()
	var archer: Node2D = battle.spawn_monster("archer")
	var hp0: int = battle.player.hp
	var t := 0.0
	while t < 12.0 and battle.player.hp == hp0:
		archer.tick(0.05, battle.player, 100.0)
		t += 0.05
	var gap := TargetSelector.edge_gap(battle.player.position.x, battle.player.half_width(), archer.position.x, archer.half_width())
	_check(archer.is_ranged() and battle.player.hp < hp0, "삿갓 궁수가 공격함 (%.1f초)" % t)
	_check(gap > 100.0 and gap <= float(archer.attack_range) + 1.0, "근접형보다 멀리서 멈춤 (거리 %.0f)" % gap)
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


func _test_manual_fragments_unlock() -> void:
	print("[M9 비급 조각과 무공 개방]")
	var arts := _new_arts()
	var eq := _new_equipment()
	var col := ManualCollection.new(ManualCollection.new_state(), arts, eq)
	_check(col.required_of("arhat_fist") == 30, "나한권 필요 조각 30개 (테스트 수치)")
	_check(not col.add_fragments("arhat_fist", 29) and not arts.is_unlocked("arhat_fist"), "필요 개수 전에는 개방되지 않음")
	_check(col.add_fragments("arhat_fist", 3) and arts.is_unlocked("arhat_fist"), "필요 개수를 채우면 무공 개방")
	_check(col.fragments_of("arhat_fist") == 2, "남는 조각은 보관")
	_check(arts.is_tech_unlocked("arhat_fist.t1") and not arts.is_tech_unlocked("arhat_fist.t2"), "개방하면 1초식만 해금")
	_check(arts.equip_main("arhat_fist") and arts.main_art() == "arhat_fist", "개방한 무공을 주력으로 장착 가능")
	var silver0 := eq.silver()
	col.add_fragments("plum_blossom_sword", 4)
	_check(eq.silver() == silver0 + 200 and col.fragments_of("plum_blossom_sword") == 0, "이미 개방한 무공의 조각은 은냥으로 전환 (가안 조각당 50)")
	_finish()


func _test_dungeon_entry_and_rewards() -> void:
	print("[M9 비급 던전 입장과 보상]")
	var d: Dictionary = _reg().get_dungeon("manual_cave")
	_check(not d.is_empty() and d["waves"].size() == 3, "비급 던전 데이터 (웨이브 3개, 마지막 보스)")
	var arts := _new_arts()
	var eq := _new_equipment()
	var col := ManualCollection.new(ManualCollection.new_state(), arts, eq)
	_check(not col.can_enter(d, {}, "2026-01-01")["ok"], "스테이지 1 돌파 전에는 입장 불가")
	var hc := {"cheongpung_mountain": 1}
	_check(col.can_enter(d, hc, "2026-01-01")["ok"], "스테이지 1 돌파 후 입장 가능")
	for i in 3:
		col.record_entry(d, "2026-01-01")
	_check(not col.can_enter(d, hc, "2026-01-01")["ok"] and col.entries_left(d, "2026-01-01") == 0, "하루 입장 3회 제한 (가안)")
	_check(col.entries_left(d, "2026-01-02") == 3, "날짜가 바뀌면 입장 횟수 초기화")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var res := col.grant_clear(d, rng, "2026-01-02")
	var total := 0
	for f in res["fragments"]:
		total += int(f["amount"])
		_check(f["art"] == "arhat_fist" or f["art"] == "yin_yang_five_elements", "보상 테이블의 무공 조각만 나옴 (%s)" % f["art"])
	_check(res["fragments"].size() == 2 and total >= 4 and total <= 8, "클리어당 2회 × 2~4개 (테스트 수치)")
	_check(eq.silver() >= 200, "클리어 은냥 보상")
	for i in 3:
		col.grant_clear(d, rng, "2026-01-02")
	_check(col.pity_of("manual_cave") == 4, "천장 카운트 누적")
	var r5 := col.grant_clear(d, rng, "2026-01-02")
	_check(not r5["pity_bonus"].is_empty() and col.pity_of("manual_cave") == 0, "클리어 5회째 천장 보너스 지급 후 초기화 (테스트 수치)")
	var guard := 0
	while not (arts.is_unlocked("arhat_fist") and arts.is_unlocked("yin_yang_five_elements")) and guard < 100:
		col.grant_clear(d, rng, "2026-01-02")
		guard += 1
	_check(arts.is_unlocked("arhat_fist") and arts.is_unlocked("yin_yang_five_elements"), "던전을 반복하면 두 무공 모두 개방 (%d회 추가)" % guard)
	_finish()


func _test_dungeon_run_in_battle() -> void:
	print("[M9 던전 전투]")
	var arts := _new_arts()
	var battle := _make_battle(arts)
	battle.growth.state["level"] = 20
	battle._refresh_stats()
	_check(not battle.start_dungeon("manual_cave", "2026-02-01")["ok"], "스테이지 돌파 전 입장 거부")
	battle.stage.highest_cleared["cheongpung_mountain"] = 1
	battle.stage.kill_count = 17
	var kc0: int = battle.stage.kill_count
	var r: Dictionary = battle.start_dungeon("manual_cave", "2026-02-01")
	_check(r["ok"] and battle.dungeon != null, "입장하면 던전 진행")
	var t := 0.0
	var saw_boss := false
	while t < 400.0 and battle.dungeon != null:
		battle.tick(0.05)
		if is_instance_valid(battle.boss):
			saw_boss = true
		t += 0.05
	_check(saw_boss, "마지막 웨이브에 던전 보스 등장")
	_check(battle.last_dungeon_result.get("cleared", false), "모든 웨이브를 처치해 클리어 (%.0f초)" % t)
	_check(battle.collection.clears_of("manual_cave") == 1, "클리어 기록")
	_check(battle.dungeon == null and battle.stage.kill_count == kc0, "끝나면 스테이지로 돌아가고 스테이지 처치 수는 그대로")
	# 실패: 제한 시간
	var r2: Dictionary = battle.start_dungeon("manual_cave", "2026-02-01")
	battle.dungeon.time_left = 0.1
	t = 0.0
	while t < 10.0 and battle.dungeon != null:
		battle.tick(0.05)
		t += 0.05
	_check(r2["ok"] and not battle.last_dungeon_result.get("cleared", true) and battle.last_dungeon_result.get("reason", "") == "시간 초과", "제한 시간이 지나면 실패")
	# 수련은 던전에서도 오른다
	var c0 := arts.count_of("plum_blossom_sword.t1")
	battle.start_dungeon("manual_cave", "2026-02-01")
	for i in 400:
		battle.tick(0.05)
	_check(arts.count_of("plum_blossom_sword.t1") > c0, "던전에서도 초식 수련 횟수가 오름")
	battle.free()
	_finish()


func _test_codex_and_dungeon_ui() -> void:
	print("[M9 도감과 던전 화면]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	ui.open_menu("dungeon")
	_check(ui.panels.has("dungeon") and ui.panels["dungeon"].visible, "앱바 던전 메뉴가 던전 화면을 엶")
	ui.panels["dungeon"]._enter("manual_cave")
	_check(ui.panels["dungeon"].message.contains("돌파"), "입장 조건 미달 안내")
	ui.open_menu("codex")
	var codex = ui.panels["codex"]
	_check(codex.visible and codex.root.get_child_count() > 0, "무공 도감 화면")
	var texts := ""
	for c in codex.root.get_children():
		if c is Label:
			texts += c.text + "\n"
	_check(texts.contains("매화검법") and texts.contains("습득") and texts.contains("0 / 30"), "도감에 습득 여부와 조각 수 표시")
	_check(texts.contains("화산파") and texts.contains("검법"), "도감에 문파와 계열 표시")
	main.free()
	gs.reset_to_new_game()
	_finish()


func _test_dungeon_data_and_difficulty() -> void:
	print("[던전 3종 데이터와 난이도]")
	var reg := _reg()
	_check(reg.get_dungeon("manual_cave").get("type", "") == "manual", "비급 던전 데이터")
	_check(reg.get_dungeon("equipment_vault").get("type", "") == "equipment", "장비 던전 데이터")
	_check(reg.get_dungeon("silver_valley").get("type", "") == "currency", "재화 던전 데이터")
	var d: Dictionary = reg.get_dungeon("manual_cave")
	_check(DungeonRules.max_level(d) == 3, "난이도 3단계 (가안)")
	var r1 := DungeonRules.resolve(d, 1)
	var r2 := DungeonRules.resolve(d, 2)
	_check(int(r1["rewards"]["fragment_rolls"]) == 2 and int(r2["rewards"]["fragment_rolls"]) == 3, "난이도 보상 덮어쓰기")
	_check(float(r2["battle"]["scaling"]) > float(r1["battle"]["scaling"]) and int(r2["battle"]["time_limit"]) == 180, "난이도 배율 반영, 나머지 전투 값은 유지")
	_check(int(r2["entry"]["required_cleared"]["stage"]) == 4 and int(r2["entry"]["daily_limit"]) == 3, "난이도 입장 조건")
	_check(int(d["rewards"]["fragment_rolls"]) == 2, "resolve는 원본을 바꾸지 않음")
	_check(DungeonRules.max_level({"id": "x"}) == 1, "난이도가 없으면 1단계")
	var bad := {"id": "bad", "type": "nope", "clear": {"type": "time_attack"}, "spawn_pool": [{"monster": "ghost"}],
		"difficulties": [{"level": 2}], "weekday": [{}], "rewards": {"min_grade": "gold"}}
	var errs := DungeonRules.validate(bad, "bad.json", reg.monsters, reg.martial_arts, reg.equipment)
	var joined := "\n".join(errs)
	_check(joined.contains("던전 종류") and joined.contains("ghost") and joined.contains("level") and joined.contains("요일표") and joined.contains("gold"),
		"잘못된 던전 데이터 검출 (%d건)" % errs.size())
	for id in reg.dungeons.keys():
		_check(DungeonRules.validate(reg.get_dungeon(id), id, reg.monsters, reg.martial_arts, reg.equipment).is_empty(), "%s 데이터 검증 통과" % id)
	_finish()


func _test_dungeon_levels_and_sweep() -> void:
	print("[던전 난이도 해금과 소탕]")
	var arts := _new_arts()
	var eq := _new_equipment()
	var col := ManualCollection.new(ManualCollection.new_state(), arts, eq)
	var d: Dictionary = _reg().get_dungeon("manual_cave")
	var hc := {"cheongpung_mountain": 9}
	_check(col.can_enter(d, hc, "2026-03-01", 1)["ok"], "난이도 1 입장 가능")
	var r2 := col.can_enter(d, hc, "2026-03-01", 2)
	_check(not r2["ok"] and r2["reason"].contains("초급"), "난이도 2는 난이도 1 클리어 후 (%s)" % r2["reason"])
	_check(col.level_lock_reason(d, {"cheongpung_mountain": 1}, 2).contains("돌파"), "난이도별 스테이지 조건")
	_check(not col.can_sweep(d, hc, "2026-03-01", 1)["ok"], "클리어 전에는 소탕 불가")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	DungeonRules.grant(DungeonRules.resolve(d, 1), 0, col, eq, rng, "2026-03-01")
	_check(col.best_level_of("manual_cave") == 1 and col.clears_of("manual_cave") == 1, "클리어하면 최고 난이도 기록")
	_check(col.can_enter(d, hc, "2026-03-01", 2)["ok"], "난이도 1 클리어 후 난이도 2 개방")
	_check(col.can_sweep(d, hc, "2026-03-01", 1)["ok"] and not col.can_sweep(d, hc, "2026-03-01", 2)["ok"], "클리어한 난이도만 소탕 가능")
	var res := DungeonRules.grant(DungeonRules.resolve(d, 2), 0, col, eq, rng, "2026-03-01")
	_check(res["fragments"].size() == 3, "난이도 2 보상: 조각 3회 (가안)")
	_check(col.best_level_of("manual_cave") == 2, "최고 난이도 갱신")
	_finish()


func _test_equipment_dungeon_rewards() -> void:
	print("[장비 던전 보상]")
	var arts := _new_arts()
	var eq := _new_equipment()
	var col := ManualCollection.new(ManualCollection.new_state(), arts, eq)
	var d: Dictionary = _reg().get_dungeon("equipment_vault")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var res := DungeonRules.grant(DungeonRules.resolve(d, 1), 0, col, eq, rng, "2026-03-01")
	_check(int(res["stone"]) >= 4 and int(res["stone"]) <= 6 and eq.stone() == int(res["stone"]), "강화석 4~6개 (가안)")
	_check(res["items"].size() == 1 and eq.items().size() == 1, "장비 1개가 보관함에 들어감")
	_check(eq.grade_index(res["items"][0]["grade"]) >= eq.grade_index("uncommon"), "최소 등급 고급 이상")
	_check(col.clears_of("equipment_vault") == 1 and col.best_level_of("equipment_vault") == 1, "클리어 기록")
	var low := DungeonRules.resolve(d, 1)
	var high := DungeonRules.resolve(d, 3)
	var res3 := DungeonRules.grant(high, 0, col, eq, rng, "2026-03-01")
	var ok3: bool = res3["items"].size() == 2
	for it in res3["items"]:
		ok3 = ok3 and eq.grade_index(it["grade"]) >= eq.grade_index("rare")
	_check(ok3 and int(res3["stone"]) >= 11, "난이도 3: 장비 2개 희귀 이상, 강화석 11~15")
	var atk_low := float(eq.generate("weapon", "rare", float(low["battle"]["scaling"]), rng)["base"].get("atk", 0))
	var atk_high := float(eq.generate("weapon", "rare", float(high["battle"]["scaling"]), rng)["base"].get("atk", 0))
	_check(atk_high > atk_low, "높은 난이도 장비일수록 기본 능력치가 큼")
	# 보관함이 가득 차면 장비는 버린다 (O-27 가안과 같은 처리)
	while eq.items().size() < eq.capacity():
		eq.add_item(eq.generate("weapon", "common", 1.0, rng))
	var res_full := DungeonRules.grant(low, 0, col, eq, rng, "2026-03-01")
	_check(int(res_full["discarded"]) == 1 and res_full["items"].is_empty() and int(res_full["stone"]) > 0, "보관함이 가득 차면 장비는 버리고 강화석은 지급")
	_check(DungeonRules.result_text(res_full, eq).contains("버림"), "결과 문구에 버린 장비 안내")
	_finish()


func _test_currency_dungeon_weekday() -> void:
	print("[재화 던전 요일제]")
	_check(DungeonRules.weekday_of("2026-11-16") == 1 and DungeonRules.weekday_of("2026-11-15") == 0, "요일 계산 (2026-11-16 월요일)")
	var d: Dictionary = _reg().get_dungeon("silver_valley")
	_check(DungeonRules.weekday_bonus(d, "2026-11-16")["mult"] == 1.0, "평일 1배")
	_check(DungeonRules.weekday_bonus(d, "2026-11-21")["mult"] == 1.5 and DungeonRules.weekday_bonus(d, "2026-11-22")["mult"] == 1.5, "토·일 1.5배 (가안)")
	var arts := _new_arts()
	var eq := _new_equipment()
	var col := ManualCollection.new(ManualCollection.new_state(), arts, eq)
	var rng := RandomNumberGenerator.new()
	var r := DungeonRules.resolve(d, 1)
	var res := DungeonRules.grant(r, 20, col, eq, rng, "2026-11-16")
	_check(int(res["silver"]) == 300 + 25 * 20 and eq.silver() == 800, "평일 은냥 = 300 + 처치 20 × 25")
	var res2 := DungeonRules.grant(r, 20, col, eq, rng, "2026-11-22")
	_check(int(res2["silver"]) == 1200, "일요일은 1.5배 (1200)")
	_check(col.best_kills_of("silver_valley", 1) == 20, "난이도별 최고 처치 수 기록")
	_check(DungeonRules.reward_preview(r, eq, "2026-11-22").contains("일요일"), "보상 안내에 오늘 요일 표시")
	_finish()


func _test_new_dungeons_in_battle() -> void:
	print("[장비·재화 던전 전투와 소탕]")
	var arts := _new_arts()
	var battle := _make_battle(arts)
	battle.growth.state["level"] = 20
	battle._refresh_stats()
	battle.stage.highest_cleared["cheongpung_mountain"] = 3
	var today := ManualCollection.today_key()
	# 재화 던전: 제한 시간 동안 처치
	var silver0: int = battle.equipment.silver()
	_check(battle.start_dungeon("silver_valley", today, 1)["ok"], "재화 던전 입장")
	_check(battle.dungeon.is_time_attack() and battle.dungeon.progress_text().contains("처치"), "시간 제한 처치 모드")
	var t := 0.0
	while t < 80.0 and battle.dungeon != null:
		battle.tick(0.05)
		t += 0.05
	var kills: int = int(battle.last_dungeon_result.get("kills", 0))
	_check(battle.last_dungeon_result.get("cleared", false) and kills >= 10, "60초가 지나면 클리어 (처치 %d)" % kills)
	_check(battle.equipment.silver() > silver0 + 300, "처치 수에 비례한 은냥 지급")
	_check(battle.collection.best_kills_of("silver_valley", 1) == kills, "최고 처치 수 기록")
	_check(battle.dungeon == null and battle.alive_count() >= 0, "끝나면 스테이지로 복귀")
	# 처치 수 부족이면 실패
	battle.start_dungeon("silver_valley", today, 1)
	battle.dungeon.time_left = 0.05
	battle.tick(0.1)
	_check(not battle.last_dungeon_result.get("cleared", true) and String(battle.last_dungeon_result.get("reason", "")).contains("처치 수 부족"), "최소 처치 수를 못 채우면 실패")
	while battle.dungeon != null:
		battle.tick(0.1)
	# 입장 2회를 다 썼으므로 소탕도 불가
	_check(not battle.sweep_dungeon("silver_valley", 1, today)["ok"], "입장 횟수가 없으면 소탕 불가")
	# 장비 던전: 웨이브 클리어 후 장비 획득
	var n0: int = battle.equipment.items().size()
	_check(not battle.start_dungeon("equipment_vault", today, 2)["ok"], "장비 던전 난이도 2는 잠김")
	_check(battle.start_dungeon("equipment_vault", today, 1)["ok"], "장비 던전 입장")
	t = 0.0
	while t < 400.0 and battle.dungeon != null:
		battle.tick(0.05)
		t += 0.05
	_check(battle.last_dungeon_result.get("cleared", false), "장비 던전 클리어 (%.0f초)" % t)
	_check(battle.equipment.items().size() == n0 + 1, "장비 던전 보상 장비 획득")
	var sw: Dictionary = battle.sweep_dungeon("equipment_vault", 1, today)
	_check(sw["ok"] and battle.equipment.items().size() == n0 + 2 and battle.collection.entries_left(_reg().get_dungeon("equipment_vault"), today) == 0, "소탕: 바로 보상, 입장 1회 사용")
	_check(battle.last_dungeon_result.get("sweep", false), "소탕 결과 기록")
	battle.free()
	_finish()


func _test_dungeon_panel_cards() -> void:
	print("[던전 화면 3종]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	ui.open_menu("dungeon")
	var panel = ui.panels["dungeon"]
	_check(panel.dungeon_ids() == ["manual_cave", "equipment_vault", "silver_valley"], "비급 → 장비 → 재화 순서")
	_check(panel._status.size() == 3, "던전 카드 3개")
	var texts := ""
	for c in panel.root.find_children("*", "Label", true, false):
		texts += c.text + "\n"
	_check(texts.contains("장비 던전") and texts.contains("재화 던전") and texts.contains("강화석") and texts.contains("요일"), "장비·재화 던전 보상 안내")
	_check(not texts.contains("MVP 이후"), "MVP 이후 안내 문구 제거")
	panel._change_level("manual_cave", 1)
	_check(panel.level_of("manual_cave") == 2, "난이도 선택")
	panel._sweep("manual_cave")
	_check(panel.message.contains("소탕") or panel.message.contains("클리어"), "소탕 불가 안내 (%s)" % panel.message)
	main.get_node("Battle").stage.highest_cleared["cheongpung_mountain"] = 3
	panel._enter("equipment_vault")
	_check(main.get_node("Battle").dungeon != null and not panel.visible, "입장하면 던전 시작, 화면 닫힘")
	main.free()
	gs.reset_to_new_game()
	_finish()


func _test_offline_elapsed_and_clock() -> void:
	print("[M10 경과 시간과 시계 조작 완화]")
	var max_sec := 8.0 * 3600.0
	var saved := {"unix": 1000000, "mono_ms": 5000, "session": "A"}
	var e := OfflineTraining.elapsed(saved, {"unix": 1003600, "mono_ms": 999999999, "session": "B"}, max_sec)
	_check(e["method"] == "device" and is_equal_approx(float(e["seconds"]), 3600.0), "다른 실행(재시작)이면 기기 시간 차이 사용")
	e = OfflineTraining.elapsed(saved, {"unix": 9999999, "mono_ms": 5000 + 600000, "session": "A"}, max_sec)
	_check(e["method"] == "monotonic" and is_equal_approx(float(e["seconds"]), 600.0), "같은 실행이면 단조 시간 차이 사용 (기기 시간을 앞당겨도 영향 없음)")
	e = OfflineTraining.elapsed(saved, {"unix": 1000000 + 20 * 3600, "mono_ms": 0, "session": "B"}, max_sec)
	_check(is_equal_approx(float(e["seconds"]), max_sec) and e["capped"], "최대 8시간까지만 인정")
	e = OfflineTraining.elapsed(saved, {"unix": 1000000 - 3600, "mono_ms": 0, "session": "B"}, max_sec)
	_check(e["rollback"] and float(e["seconds"]) == 0.0 and int(e["rollback_until"]) == 1000000, "기기 시간이 과거로 가면 보상 0, 되돌림 기준 시각 기록")
	# 되돌린 시각으로 저장된 뒤 시간을 원래대로 돌려도, 원래 저장 시점부터 센다
	var saved_back := {"unix": 1000000 - 3600, "mono_ms": 0, "session": "C"}
	e = OfflineTraining.elapsed(saved_back, {"unix": 1000000 - 1800, "mono_ms": 0, "session": "D"}, max_sec, 1000000)
	_check(e["rollback"] and float(e["seconds"]) == 0.0, "되돌림 기준 시각을 지나기 전까지 계속 0")
	e = OfflineTraining.elapsed(saved_back, {"unix": 1000000 + 600, "mono_ms": 0, "session": "D"}, max_sec, 1000000)
	_check(not e["rollback"] and is_equal_approx(float(e["seconds"]), 600.0) and int(e["rollback_until"]) == 0, "기준 시각을 지나면 그 시각부터 정상 계산 (되돌린 만큼 이득 없음)")
	e = OfflineTraining.elapsed({}, {"unix": 1000000, "mono_ms": 0, "session": "A"}, max_sec)
	_check(float(e["seconds"]) == 0.0, "저장 기록이 없으면 0")
	_check(OfflineTraining.format_duration(3 * 3600 + 12 * 60) == "3시간 12분", "경과 시간 표시 형식")
	_finish()


func _test_offline_training_apply() -> void:
	print("[M10 오프라인 수련 계산]")
	var cfg := {"efficiency": 0.5, "multiplier": 1.0, "technique_interval": 1.0, "mp_regen": 5.0}
	var arts := _new_arts()
	var tech: Dictionary = _reg().get_technique("plum_blossom_sword.t1")
	_check(is_equal_approx(OfflineTraining.casts_per_second(tech, 1.0, 5.0), 1.0), "초당 발동 수 1회 (초식 간격 1초, 내공 5/초, 소모 5, 가안)")
	var r := OfflineTraining.apply(arts, 3600.0, cfg)
	_check(arts.count_of("plum_blossom_sword.t1") == 1800 and int(r["gains"]["plum_blossom_sword.t1"]) == 1800, "1시간 → 3,600회 × 효율 50% = 1,800회")
	arts.set_chain_mode(true)
	arts.debug_set_count("plum_blossom_sword.t1", 9000)
	r = OfflineTraining.apply(arts, 8.0 * 3600.0, cfg)
	_check(arts.is_mastered("plum_blossom_sword.t1"), "오프라인 중 대성")
	_check(arts.is_mastered("plum_blossom_sword.t2") and arts.count_of("plum_blossom_sword.t3") == 14400 - 1000 - 10000, "남은 횟수는 다음 초식으로 이월 (2초식 대성 후 3초식까지)")
	_check(int(r["gains"]["plum_blossom_sword.t1"]) == 1000 and r["mastered"].has("plum_blossom_sword.t1"), "대성까지 필요한 만큼만 1초식에 반영")
	_check(arts.count_of("plum_blossom_sword.t4") == 0 and arts.count_of("plum_blossom_sword.t1") == 10000, "연속초식을 켜 두었어도 단일 수련 기준 (대성한 초식은 더 쌓지 않음)")
	# 모두 대성한 경우: 마지막 초식 반복
	var arts2 := _new_arts()
	for t in arts2.techniques_of("plum_blossom_sword"):
		arts2.debug_set_count(t["id"], 10000)
	var last: String = arts2.techniques_of("plum_blossom_sword").back()["id"]
	var c0 := arts2.count_of(last)
	OfflineTraining.apply(arts2, 600.0, cfg)
	_check(arts2.count_of(last) == c0 + 300, "모두 대성했으면 마지막 초식에 계속 쌓임")
	var arts3 := _new_arts()
	r = OfflineTraining.apply(arts3, 0.0, cfg)
	_check(r["gains"].is_empty(), "경과 0이면 변화 없음")
	_finish()


func _test_offline_game_flow() -> void:
	print("[M10 저장 → 복귀 흐름과 요약 화면]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var sm = _make_save_manager("user://test_m10_save")
	sm.save_game()
	var r: Dictionary = sm.load_game()
	var meta: Dictionary = sm.saved_time_of(r["data"])
	_check(int(meta["unix"]) > 0 and String(meta["session"]) != "", "저장 파일에 기기 시간, 단조 시간, 세션 기록")
	gs.apply_loaded(r["data"])
	var now := {"unix": int(meta["unix"]) + 2 * 3600, "mono_ms": 0, "session": "다른 실행"}
	var res: Dictionary = gs.apply_offline(meta, now)
	_check(gs.arts.count_of("plum_blossom_sword.t1") == 1980 and int(res["gains"]["plum_blossom_sword.t1"]) == 1980, "2시간 뒤 재실행: 1초식 +1,980회 (7,200초 × 발동 비율 55% × 효율 50%)")
	_check(not gs.offline_summary.is_empty(), "복귀 요약이 만들어짐")
	var short: Dictionary = gs.apply_offline(meta, {"unix": int(meta["unix"]) + 30, "mono_ms": 0, "session": "다른 실행"})
	_check(short.is_empty(), "60초 미만은 무시 (가안)")
	var back: Dictionary = gs.apply_offline(meta, {"unix": int(meta["unix"]) - 100, "mono_ms": 0, "session": "다른 실행"})
	_check(back.get("rollback", false) and int(gs.data["offline"]["rollback_until_unix"]) == int(meta["unix"]), "시계를 되돌리면 보상 없이 기준 시각 저장")
	var ui = load("res://scripts/ui/GameUi.gd").new()
	ui.arts = gs.arts
	root.add_child(ui)
	gs.apply_offline({"unix": int(meta["unix"]), "mono_ms": 0, "session": "x"}, {"unix": int(meta["unix"]) + 4 * 3600, "mono_ms": 0, "session": "y"})
	_check(ui.panels.has("offline") and ui.panels["offline"].visible, "복귀 요약 화면이 뜸")
	var texts := ""
	for c in ui.panels["offline"].root.get_children():
		if c is Label:
			texts += c.text
	_check(texts.contains("효율 50%") and texts.contains("+3,960회"), "요약에 효율과 오른 횟수 표시")
	ui.free()
	sm.delete_all()
	sm.free()
	gs.reset_to_new_game()
	_finish()


func _test_save_export_import() -> void:
	print("[M11 저장 내보내기/가져오기]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	gs.arts.debug_set_count("plum_blossom_sword.t1", 4321)
	gs.growth.add_exp(3000)
	gs.equipment.add_currency("silver", 777)
	var sm = _make_save_manager("user://test_m11_save")
	var code: String = sm.export_code()
	_check(code.begins_with("ILCHO1:") and code.length() > 100, "텍스트 코드로 내보내기")
	var lv: int = gs.growth.level()
	gs.reset_to_new_game()
	var parsed: Dictionary = sm.parse_code(code)
	_check(parsed["ok"] and String(parsed["summary"]).contains("Lv %d" % lv), "코드 검사와 가져오기 전 요약 (%s)" % parsed.get("summary", ""))
	var r: Dictionary = sm.import_code(code)
	_check(r["ok"] and gs.arts.count_of("plum_blossom_sword.t1") == 4321 and gs.growth.level() == lv and gs.equipment.silver() == 777, "가져오면 수련, 레벨, 재화가 그대로 옮겨짐")
	var again: Dictionary = sm.load_game()
	_check(again["ok"] and int(again["data"]["martial_arts"]["progress"]["plum_blossom_sword"]["techniques"]["plum_blossom_sword.t1"]["count"]) == 4321, "가져온 진행이 바로 저장됨")
	var broken := code.substr(0, code.length() - 12) + "AAAAAAAAAAAA"
	_check(not sm.parse_code(broken)["ok"], "깨진 코드는 거부")
	_check(not sm.parse_code("아무 글자")["ok"], "다른 글자는 거부")
	_check(sm.parse_code("  " + code.substr(0, 50) + "\n" + code.substr(50) + "  ")["ok"], "앞뒤 공백, 줄바꿈이 섞여도 읽음")
	var newer: Dictionary = gs.data.duplicate(true)
	newer["version"] = 99
	_check(not sm.parse_code(sm.export_code(newer))["ok"], "더 새 버전 앱의 코드는 거부")
	sm.delete_all()
	sm.free()
	gs.reset_to_new_game()
	_finish()


func _test_settings_and_sound() -> void:
	print("[M11 설정과 임시 효과음]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var st: Dictionary = gs.data["settings"]
	_check(st.has("sfx_volume") and st.has("bgm_volume") and st.has("vibration") and st.has("screen_shake"), "설정 기본값 (효과음, 배경음, 진동, 화면 흔들림)")
	var old: Dictionary = gs.data.duplicate(true)
	old.erase("settings")
	gs.apply_loaded(old)
	_check(gs.data["settings"]["sfx_volume"] == 0.8, "예전 저장에는 설정 기본값을 채움")
	var snd = root.get_node("Sound")
	var n0: int = snd.play_count
	snd.play("mastery")
	_check(snd.play_count == n0 + 1, "임시 효과음 재생 (코드로 만든 파형)")
	snd._last_play_ms.erase("technique")
	snd.play("technique", 1000)
	snd.play("technique", 1000)
	_check(snd.play_count == n0 + 2, "짧은 간격의 같은 소리는 건너뜀")
	gs.data["settings"]["sfx_volume"] = 0.0
	snd.play("levelup")
	_check(snd.play_count == n0 + 2, "효과음 음량 0이면 재생하지 않음")
	gs.data["settings"]["sfx_volume"] = 0.8
	var panel := SettingsPanel.new()
	root.add_child(panel)
	panel.visible = true
	panel.on_open()
	panel._export()
	_check(panel._code_edit.text.begins_with("ILCHO1:"), "설정 화면 내보내기 버튼이 코드를 보여 줌")
	panel._check_import()
	_check(panel._status.text.contains("가져올 진행"), "설정 화면 가져오기는 먼저 요약을 보여 줌")
	panel.free()
	var arts := _new_arts()
	var battle := _make_battle(arts)
	_check(battle.effects.shake_enabled, "화면 흔들림 기본 켜짐")
	battle.free()
	gs.reset_to_new_game()
	_finish()


func _test_tutorial_steps() -> void:
	print("[M11 튜토리얼 4단계]")
	var steps: Array = _reg().balance.get("tutorial", {}).get("steps", [])
	_check(steps.size() == 4, "튜토리얼 4단계 데이터")
	var progress := {}
	var arts := _new_arts()
	var kills := [0]
	var guide := TutorialGuide.new(steps, progress, arts)
	guide.kill_count = func(): return kills[0]
	guide._advance()
	root.add_child(guide)
	_check(guide.visible and guide.current_id() == "auto_battle", "1단계 자동 전투 안내")
	kills[0] = 3
	guide._process(0.0)
	_check(guide.current_id() == "chain_button" and progress.get("auto_battle", false), "몬스터 3마리 처치로 2단계")
	guide.chain_toggled = true
	guide._process(0.0)
	_check(guide.current_id() == "equip_martial_art", "연속초식 버튼을 누르면 3단계")
	guide.opened_menus["growth"] = true
	guide._process(0.0)
	_check(guide.current_id() == "first_training", "육성을 열면 4단계")
	guide.complete_current()
	_check(guide.is_done() and not guide.visible, "확인을 누르면 마침")
	guide.free()
	var guide2 := TutorialGuide.new(steps, progress, arts)
	_check(guide2.is_done() and not guide2.visible, "끝낸 튜토리얼은 다시 뜨지 않음")
	guide2.free()
	# 전체 화면 연결
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	_check(ui.tutorial != null and ui.tutorial.visible, "새 게임 첫 화면에 튜토리얼이 뜸")
	_check(ui.panels.has("settings"), "설정 화면 등록 (화면 위 설정 버튼)")
	main.free()
	gs.reset_to_new_game()
	_finish()


func _test_design_visuals() -> void:
	print("[디자인 반영: 스프라이트, 쓰러짐 연출, 앱바, 육성 화면]")
	# 무공 계열마다 복장·무기가 다른 2등신 스프라이트
	var sw := ChibiArt.hero("sword")
	var fi := ChibiArt.hero("fist")
	_check(sw["weapon_kind"] == "sword" and fi["weapon_kind"] == "fist" and sw["body"] != fi["body"], "무공 계열별 복장과 무기")
	var mon := ChibiArt.monster("bandit")
	_check(mon.has("ko") and mon.has("weapon"), "몬스터 스프라이트에 기절(X눈) 그림과 무기")
	# 쓰러짐 연출 8프레임
	var DeathScript = load("res://scripts/battle/MonsterDeath.gd")
	var d = DeathScript.new()
	root.add_child(d)
	d.setup({"art": mon, "scale": ChibiArt.ART_SCALE, "position": Vector2(400, 1020)})
	var frames := {}
	for i in 80:
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			break
		frames[d.frame()] = true
		d.advance(1.0 / 60.0)
	_check(frames.size() == 8, "쓰러짐 연출이 8프레임을 모두 거침")
	_check(d.is_done(), "연출이 끝나면 스스로 사라짐")
	# 전투에서 처치하면 쓰러짐 연출이 뜨고, 판정용 몬스터 노드는 바로 빠짐
	var arts := _new_arts()
	var battle := _make_battle(arts)
	var m: Node2D = battle.spawn_monster("test_bandit")
	m.take_damage(99999)
	_check(not battle.monsters.has(m) and battle._death_layer.get_child_count() == 1, "처치 시 쓰러짐 연출 생성")
	# 주력 무공을 바꾸면 복장이 바뀜
	arts.unlock("arhat_fist")
	arts.equip_main("arhat_fist")
	_check(battle.player.style == "fist", "주력 무공이 나한권이면 주황 승복·주먹")
	battle.free()
	# 하단 앱바: 메인 버튼은 열린 화면을 닫고, 육성 화면은 탭을 가진다
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	_check(main.has_node("BattleBackground"), "전투 배경이 붙음")
	ui._on_menu_pressed("growth")
	var grow = ui.panels["growth"]
	_check(grow is GrowScreen and grow.visible and ui._app_bar.active == "growth", "앱바 육성 → 육성 화면, 육성 활성")
	grow._set_tab("arts")
	_check(grow._arts_panel.visible and grow._arts_panel.root.get_child_count() > 0, "무공 탭에 무공 장착·수련 화면")
	grow._set_tab("equip")
	var it: Dictionary = gs.equipment.generate("weapon", "rare", 1.0, RandomNumberGenerator.new())
	gs.equipment.add_item(it)
	grow._open_detail(int(it["uid"]))
	_check(grow._detail.visible, "보유 장비를 누르면 상세 창")
	ui._on_menu_pressed("main")
	_check(not grow.visible and ui._app_bar.active == "main", "메인(태극) 버튼은 화면을 닫고 전투로")
	main.free()
	gs.reset_to_new_game()
	_finish()


func _test_equipment_summon_and_level_up() -> void:
	print("[장비 소환과 장비 레벨업]")
	var eq := _new_equipment()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var starter := int(_reg().equipment.get("summon", {}).get("starter_tickets", 0))
	_check(eq.tickets() == starter and starter > 0, "새 게임 시작 소환패 지급 (%d장)" % starter)
	var r1: Dictionary = eq.summon(1, 1.0, rng)
	_check(r1["ok"] and r1["items"].size() == 1 and eq.tickets() == starter - 1, "1회 소환: 소환패 1장 소모, 장비 1개")
	var r2: Dictionary = eq.summon(10, 1.0, rng)
	_check(not r2["ok"] and eq.tickets() == starter - 1, "소환패가 모자라면 소환하지 않음")
	eq.add_currency("ticket", 1)
	var r3: Dictionary = eq.summon(10, 1.0, rng)
	var best := 0
	for it in r3["items"]:
		best = maxi(best, eq.grade_index(it["grade"]))
	_check(r3["ok"] and r3["items"].size() == 10 and best >= eq.grade_index("rare"), "10회 소환은 희귀 이상 1개 보장")
	_check(eq.auto_equip_best(r3["items"]) > 0 and not eq.equipped_item("weapon").is_empty() or not eq.equipped_item("armor").is_empty(), "자동 장착이 부위별로 장비를 등록")
	# 보스 처치 소환패
	var t0 := eq.tickets()
	eq.roll_drop(true, 1.0, rng)
	_check(eq.tickets() == t0 + int(_reg().equipment["summon"].get("boss_tickets", 0)), "보스 처치로 소환패 획득")
	# 레벨업: 같은 부위·같은 등급 중복 장비를 재료로
	var eq2 := _new_equipment()
	var a: Dictionary = eq2.generate("helmet", "rare", 1.0, rng)
	var b: Dictionary = eq2.generate("helmet", "rare", 1.0, rng)
	var c: Dictionary = eq2.generate("helmet", "epic", 1.0, rng)
	var d: Dictionary = eq2.generate("armor", "rare", 1.0, rng)
	for it in [a, b, c, d]:
		eq2.add_item(it)
	eq2.equip(int(a["uid"]))
	_check(eq2.level_up_materials(int(a["uid"])).size() == 1, "재료는 같은 부위·같은 등급의 장착하지 않은 장비만")
	_check(eq2.level_up(int(a["uid"])) == EquipmentManager.LevelUpResult.NOT_ENOUGH, "은냥이 없으면 레벨업 불가")
	eq2.add_currency("silver", 100000)
	var def0: float = float(eq2.item_base_stats(a)["def"])
	var bonus0: float = float(eq2.stat_bonuses()["def"]["flat"])
	_check(eq2.level_up(int(a["uid"])) == EquipmentManager.LevelUpResult.OK and eq2.item_level(a) == 2, "레벨업 성공: Lv 2")
	_check(eq2.find(int(b["uid"])).is_empty() and not eq2.find(int(c["uid"])).is_empty(), "재료 장비만 사라짐")
	_check(float(eq2.item_base_stats(a)["def"]) > def0 and float(eq2.stat_bonuses()["def"]["flat"]) > bonus0, "레벨이 오르면 장착 능력치도 오름")
	_check(eq2.level_up(int(a["uid"])) == EquipmentManager.LevelUpResult.NO_MATERIAL, "재료가 없으면 레벨업 불가")
	_check(eq2.item_name(a).contains("Lv2"), "장비 이름에 레벨 표시")
	# 소환 화면과 육성 화면 연결
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	ui._on_menu_pressed("summon")
	var sp = ui.panels["summon"]
	_check(sp.visible and ui._app_bar.active == "summon", "앱바 소환 → 장비 소환 화면")
	var res: Dictionary = sp.do_summon(10)
	_check(res["ok"] and sp.last_results.size() == 10, "소환 화면에서 10회 소환")
	ui._on_menu_pressed("growth")
	var grow = ui.panels["growth"]
	grow._slot_buttons["shoes"].pressed.emit()
	if gs.equipment.equipped_item("shoes").is_empty():
		_check(grow.slot_filter == "shoes", "빈 슬롯을 누르면 그 부위 장비만 보여 줌")
	else:
		_check(grow._detail.visible, "장착된 슬롯을 누르면 상세 창")
	main.free()
	gs.reset_to_new_game()
	_finish()


## 하단 앱바: 모바일 터치(터치 + 흉내 낸 마우스 이벤트)로 한 번 눌러도 메뉴가 열린 채로 남는지,
## 세로로 긴 화면(1080×2400 → 720×1600)에서 앱바가 맨 아래로 내려가는지
func _test_app_bar_touch_and_tall_screen() -> void:
	print("[하단 앱바 터치와 세로로 긴 화면]")
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var ui = main.get_node("GameUi")
	var bar: AppBar = ui._app_bar
	# 모바일에서 손가락 한 번 = 터치 누름/뗌 + 마우스 누름/뗌
	var tap := func(x: float):
		var pos := Vector2(x, 70.0 + 60.0)
		for pressed in [true, false]:
			var t := InputEventScreenTouch.new()
			t.position = pos
			t.pressed = pressed
			bar._gui_input(t)
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.position = pos
			m.pressed = pressed
			bar._gui_input(m)
	for case in [[1, "growth"], [3, "dungeon"], [4, "summon"]]:
		tap.call(bar._slot_x(case[0]))
		_check(ui.panels[case[1]].visible and bar.active == case[1], "터치 한 번으로 %s 화면이 열린 채로 남음" % case[1])
	tap.call(360.0)
	_check(ui._open_name == "" and bar.active == "main", "태극 버튼 터치 → 메인으로 돌아옴")
	# 720×1600 화면: 남는 320px만큼 전투 화면과 앱바를 내린다
	ui.apply_layout(320.0)
	main.get_node("Battle").world_offset = Vector2(0, 320)
	_check(is_equal_approx(bar.bar_y, 1146.0 + 320.0), "앱바 윗선이 화면 맨 아래 기준으로 내려감")
	_check(is_equal_approx(ui.panels["growth"].size.y, 1466.0), "육성 화면이 앱바 윗선까지 늘어남")
	_check(is_equal_approx(ui.panels["dungeon"].size.y, MenuPanel.AREA.size.y + 320.0), "던전 화면이 앱바 윗선까지 늘어남")
	_check(is_equal_approx(main.get_node("Battle/Hud").position.y + main.get_node("Battle").position.y, 0.0), "상단 바는 화면 맨 위에 그대로")
	main.free()
	gs.reset_to_new_game()
	_finish()
