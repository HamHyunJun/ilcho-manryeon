extends Node2D
## 전투 관리자 (M1 전투 기본 + M2 스테이지 루프).
## - 왼쪽에 캐릭터를 고정 배치하고, 오른쪽에서 몬스터를 주기적으로 생성한다.
## - 캐릭터 기본 공격, 몬스터 접근/공격, 피해 숫자, 처치를 처리한다.
## - 일반 몬스터 50마리 처치 → 보스 등장 → 보스 처치 → 다음 스테이지 (StageManager).
## - 주력 무공 초식 자동 발동과 수련 기록 (M3, TechniqueModeController + MartialArtManager).
## - 모든 수치는 data/balance/combat.json, data/monsters/*.json, data/stages/*.json에서 읽는다.

const PlayerScript := preload("res://scripts/player/PlayerCharacter.gd")
const MonsterScript := preload("res://scripts/battle/Monster.gd")
const DamageNumberScript := preload("res://scripts/battle/DamageNumber.gd")
const HudScript := preload("res://scripts/ui/BattleHud.gd")

## true면 _process에서 자동으로 진행하지 않는다 (테스트에서 tick을 직접 호출)
@export var manual_tick := false

var config: Dictionary = {}
var player: Node2D
var monsters: Array = []
## 이번 전투에서 처치한 몬스터 총수 (보스 포함). 스테이지 처치 진행도는 stage.kill_count
var kill_count := 0
var rng := RandomNumberGenerator.new()
var stage: StageManager
## 현재 보스 (없으면 null)
var boss: Node2D = null
## 무공 장착/수련 기록 (기본은 GameState.arts)
var arts: MartialArtManager
var techniques: TechniqueModeController
## 마지막으로 발동한 초식 이름과 남은 표시 시간 (화면 표시용)
var last_technique_name := ""
var last_technique_left := 0.0
## 지금까지 발동한 초식 수 (테스트, 통계용)
var techniques_cast := 0
## 화면 가운데 안내 문구와 남은 표시 시간
var banner_text := ""
var banner_left := 0.0
## 마지막으로 얻은 장비 (테스트, 표시용)
var last_drop: Dictionary = {}

var _spawn_cd := 0.0
var _recover_cd := 0.0
var _intro_cd := 0.0
var _clear_cd := 0.0
var _defense_constant := 100.0
var _effects_layer: Node2D
## GameState에 스테이지 진행을 기록하는지
var _persist := false
var _hud: Node2D
## 초식 연출 관리자 (M6)
var effects: EffectDirector
## 캐릭터 레벨/경지 (M7). GameState를 쓰지 않는 전투(테스트)는 따로 만든다
var growth: CharacterGrowth
## 장비와 재화 (M8). GameState를 쓰지 않는 전투(테스트)는 따로 만든다
var equipment: EquipmentManager
## 비급 조각/던전 기록 (M9)
var collection: ManualCollection
## 진행 중인 던전 (없으면 null, M9)
var dungeon: DungeonRun = null
var _dungeon_spawn_cd := 0.0
## 마지막 던전 결과 {cleared, rewards} (테스트, 표시용)
var last_dungeon_result: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	setup(DataRegistry.balance.get("combat", {}))


## 전투를 초기화한다. region_data를 주지 않으면 combat.json의 시작 지역을 쓴다.
## martial_arts를 주지 않으면 GameState의 무공 관리자를 쓴다.
func setup(combat_config: Dictionary, region_data: Dictionary = {}, martial_arts: MartialArtManager = null) -> void:
	config = combat_config
	_clear_monsters()
	kill_count = 0
	_defense_constant = float(config.get("defense_constant", 100))

	if region_data.is_empty():
		region_data = DataRegistry.get_region(config.get("stage", {}).get("start_region", ""))
	stage = StageManager.new(region_data, int(config.get("stage", {}).get("start_stage", 1)))

	# 무공 관리자를 따로 주지 않으면 GameState를 쓰고, 스테이지 진행도 GameState에 저장/복원한다 (M4)
	_persist = martial_arts == null and has_node("/root/GameState")
	if _persist:
		martial_arts = get_node("/root/GameState").arts
		_restore_stage(get_node("/root/GameState").data.get("stage", {}))
	if growth != null and growth.leveled_up.is_connected(_on_leveled_up):
		growth.leveled_up.disconnect(_on_leveled_up)
		growth.realm_promoted.disconnect(_on_realm_promoted)
	if _persist:
		growth = get_node("/root/GameState").growth
	else:
		growth = CharacterGrowth.new(CharacterGrowth.new_state(), DataRegistry.balance.get("growth", {}))
	growth.leveled_up.connect(_on_leveled_up)
	growth.realm_promoted.connect(_on_realm_promoted)
	if equipment != null and equipment.equipment_changed.is_connected(_refresh_stats):
		equipment.equipment_changed.disconnect(_refresh_stats)
	if _persist:
		equipment = get_node("/root/GameState").equipment
	else:
		equipment = EquipmentManager.new(EquipmentManager.new_state(), EquipmentManager.new_currencies(), DataRegistry.equipment)
	equipment.equipment_changed.connect(_refresh_stats)
	collection = get_node("/root/GameState").collection if _persist else null
	dungeon = null
	if arts != null and arts.equipment_changed.is_connected(_refresh_stats):
		arts.equipment_changed.disconnect(_refresh_stats)
	arts = martial_arts
	if arts != null:
		if collection == null:
			collection = ManualCollection.new(ManualCollection.new_state(), arts, equipment)
		arts.equipment_changed.connect(_refresh_stats)
		techniques = TechniqueModeController.new(arts, float(config["player_base"].get("technique_interval", 1.0)))

	if player == null:
		player = PlayerScript.new()
		player.name = "Player"
		add_child(player)
		player.knocked_out.connect(_on_player_knocked_out)
	player.setup(_effective_stats())
	_apply_equipment_effects()
	player.position = Vector2(config["layout"]["player_x"], config["layout"]["ground_y"])

	if _effects_layer == null:
		_effects_layer = Node2D.new()
		_effects_layer.name = "Effects"
		_effects_layer.z_index = 10
		add_child(_effects_layer)
	if effects == null:
		effects = EffectDirector.new()
		effects.name = "EffectDirector"
		effects.z_index = 9
		add_child(effects)
	effects.setup(DataRegistry.effects.get("effect_presets", {}), float(config["layout"]["ground_y"]))
	if _hud == null:
		_hud = HudScript.new()
		_hud.name = "Hud"
		_hud.z_index = 20
		_hud.battle = self
		add_child(_hud)

	_spawn_cd = 0.0
	_recover_cd = 0.0
	_start_stage_banner()
	_sync_stage()
	queue_redraw()


## 저장된 스테이지 진행을 복원한다. 처치 수는 유지하고, 보스 조건을 이미 채웠으면 보스 등장부터 다시 한다.
func _restore_stage(saved: Dictionary) -> void:
	if saved.is_empty() or saved.get("region", "") != stage.region_id():
		return
	stage.start(int(saved.get("stage_no", 1)))
	stage.kill_count = int(saved.get("kill_count", 0))
	var hc: Dictionary = saved.get("highest_cleared", {})
	for k in hc.keys():
		stage.highest_cleared[k] = int(hc[k])
	if stage.kill_count >= stage.kills_to_boss():
		stage.kill_count = stage.kills_to_boss()
		stage.phase = StageManager.Phase.BOSS_INTRO
		_intro_cd = _stage_cfg("boss_intro_delay", 1.5)


## 스테이지 진행을 GameState에 기록한다 (저장은 SaveManager가 주기/이벤트로 한다)
func _sync_stage() -> void:
	if _persist:
		get_node("/root/GameState").data["stage"] = stage.to_save()


## 기본 능력치에 보조 무공 패시브, 레벨/경지 보너스를 더한 능력치
func _effective_stats() -> Dictionary:
	var list: Array = []
	if arts != null:
		list.append(arts.sub_passives())
	if growth != null:
		list.append(growth.stat_bonuses())
	if equipment != null:
		list.append(equipment.stat_bonuses())
	return PlayerStats.apply(config["player_base"], PlayerStats.merge(list))


## 장비 특수 효과(보스 피해, 피해 감소)를 캐릭터에 넣는다
func _apply_equipment_effects() -> void:
	if equipment == null or player == null:
		return
	player.boss_damage = equipment.effect_total("boss_damage")
	player.damage_reduction = equipment.effect_total("damage_reduction")


## 전투력 (HUD 표시, 가안 가중합)
func combat_power() -> int:
	var w: Dictionary = DataRegistry.balance.get("growth", {}).get("combat_power", {})
	return CharacterGrowth.combat_power(_effective_stats(), arts.total_mastered() if arts else 0, w)


func _on_leveled_up(level: int) -> void:
	_refresh_stats()
	_set_banner("레벨 업!  Lv %d" % level, 1.2)
	_check_promotion()


func _on_realm_promoted(_tier: int) -> void:
	_refresh_stats()
	var name: String = growth.realm().get("name", "")
	_set_banner("경지 승급!  %s" % name, 2.5)
	if effects:
		effects.play_mastery("spell", player.position + Vector2(0, -player.body_size.y * 0.5), name)


## 레벨과 대성 초식 수가 다음 경지 조건을 채우면 승급한다 (자동 승급, 가안 O-22)
func _check_promotion() -> void:
	if growth == null or arts == null:
		return
	if bool(DataRegistry.balance.get("growth", {}).get("auto_promote", true)):
		growth.try_promote(arts.total_mastered())


## 장착이 바뀌면 능력치를 다시 계산한다 (체력 비율 유지)
func _refresh_stats() -> void:
	player.apply_stats(_effective_stats())
	_apply_equipment_effects()
	if techniques:
		techniques.reset_chain()


func _process(delta: float) -> void:
	if not manual_tick:
		tick(delta)


## 전투를 delta초 진행한다.
func tick(delta: float) -> void:
	banner_left = maxf(0.0, banner_left - delta)
	last_technique_left = maxf(0.0, last_technique_left - delta)
	if techniques:
		techniques.tick(delta)
	if effects:
		if _persist:
			effects.shake_enabled = bool(get_node("/root/GameState").data.get("settings", {}).get("screen_shake", true))
		effects.tick(delta)
		# 화면 흔들림: 전투 화면만 흔들고 HUD는 제자리에 둔다
		position = effects.shake_offset
		if _hud:
			_hud.position = -effects.shake_offset

	if player.is_down():
		_recover_cd -= delta
		if _recover_cd <= 0.0:
			_restart_after_knockout()
		player.tick(delta, [], rng, _defense_constant)
		_redraw_all()
		return

	if dungeon != null:
		_tick_dungeon(delta)
	else:
		_tick_stage(delta)

	var hit: Dictionary = player.tick(delta, monsters, rng, _defense_constant)
	if not hit.is_empty() and is_instance_valid(hit["target"]):
		var color := Color(1.0, 0.85, 0.2) if hit["crit"] else Color.WHITE
		_show_damage(hit["damage"], hit["target"].position + Vector2(0, -hit["target"].body_size.y), color, hit["crit"])

	_try_cast_technique()

	for m in monsters.duplicate():
		if not is_instance_valid(m) or m.is_dead():
			continue
		var dealt: int = m.tick(delta, player, _defense_constant)
		if dealt > 0:
			_show_damage(dealt, player.position + Vector2(0, -player.body_size.y), Color(1.0, 0.4, 0.4))
	_redraw_all()


## 일반 스테이지 진행: 몬스터 생성, 보스 등장, 다음 스테이지
func _tick_stage(delta: float) -> void:
	match stage.phase:
		StageManager.Phase.NORMAL:
			_spawn_cd -= delta
			if _spawn_cd <= 0.0:
				_spawn_cd = float(config["spawn"]["interval"])
				var alive := alive_count()
				if alive < int(config["spawn"]["max_alive"]) and stage.needs_more_normals(alive):
					spawn_monster(_pick_spawn_id())
		StageManager.Phase.BOSS_INTRO:
			_intro_cd -= delta
			if _intro_cd <= 0.0:
				_spawn_boss()
		StageManager.Phase.CLEARED:
			_clear_cd -= delta
			if _clear_cd <= 0.0:
				_go_next_stage()


## 자동 초식 발동. 대상이 없거나, 대기 중이거나, 내공이 부족하면 발동하지 않고 수련 횟수도 오르지 않는다.
## 발동하면 빗나가도 수련 1회로 센다 (확정 사항 28). 지금은 회피가 없어 발동 = 적중이다.
func _try_cast_technique() -> void:
	if techniques == null or player.is_down():
		return
	var tech: Dictionary = techniques.pick(player.mp)
	if tech.is_empty():
		return
	var range_px := float(tech.get("range", 0.25)) * float(config["layout"].get("screen_width", 720))
	var targets: Array = player.technique_targets(tech, monsters, range_px)
	if targets.is_empty():
		return
	var art_id := String(tech["id"]).get_slice(".", 0)
	var category: String = DataRegistry.get_martial_art(art_id).get("category", "")
	var color := _category_color(category)
	var tid: String = tech["id"]
	var stage_before := technique_stage(tid)
	# 연출은 발동 시점의 수련 단계로 정한다
	var positions: Array = []
	for t in targets:
		positions.append(t.position)
	effects.play_technique(category, stage_before, player.position + Vector2(player.half_width(), 0), positions, tech)
	var hits: Array = player.cast_technique(tech, targets, rng, _defense_constant, color, equipment.technique_bonus(tid, art_id, category))
	techniques.on_cast(tech)
	techniques_cast += 1
	var multiplier := float(DataRegistry.balance.get("training", {}).get("base_multiplier", 1.0))
	var mastered_now := arts.record_performed(tid, multiplier)
	var stage_after := technique_stage(tid)
	var at := player.position + Vector2(0, -player.body_size.y * 0.5)
	if mastered_now:
		effects.play_mastery(category, at, "%s 대성!" % tech.get("name", ""), tech)
		_set_banner("%s 대성! 다음 초식이 열렸습니다" % tech.get("name", ""), 2.0)
		# 승급 안내가 대성 안내보다 우선한다
		_check_promotion()
	elif stage_after > stage_before:
		var th: Array = DataRegistry.balance.get("training", {}).get("stage_thresholds", [])
		effects.play_stage_up(category, stage_after, at, "%s · %s" % [tech.get("name", ""), MartialArtManager.stage_name_for(arts.count_of(tid), th)])
	last_technique_name = tech.get("name", "")
	last_technique_left = 0.8
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").technique_performed.emit(art_id, tech["id"])
	for h in hits:
		if is_instance_valid(h["target"]):
			var c := color.lightened(0.3) if h["crit"] else color
			_show_damage(h["damage"], h["target"].position + Vector2(0, -h["target"].body_size.y - 30), c, h["crit"])


## 초식의 현재 수련 단계 (1~7, 이펙트 프리셋 선택용)
func technique_stage(tech_id: String) -> int:
	var th: Array = DataRegistry.balance.get("training", {}).get("stage_thresholds", [])
	return EffectPresets.stage_index_for(arts.count_of(tech_id), th, arts.is_mastered(tech_id))


## 계열 기본색 (데미지 숫자, 캐릭터 테두리). 연출 색은 effect_presets.json
func _category_color(category: String) -> Color:
	match category:
		"sword":
			return Color(1.0, 0.55, 0.75)
		"fist":
			return Color(1.0, 0.65, 0.3)
		"spell":
			return Color(0.5, 0.85, 1.0)
	return Color(0.9, 0.9, 0.9)


func alive_count() -> int:
	var n := 0
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead():
			n += 1
	return n


## 몬스터 하나를 화면 오른쪽에 생성한다. 스테이지 배율을 적용한다.
func spawn_monster(monster_id: String, scaling: float = -1.0) -> Node2D:
	var d: Dictionary = DataRegistry.get_monster(monster_id)
	if d.is_empty():
		push_error("[Battle] 알 수 없는 몬스터: " + monster_id)
		return null
	var m: Node2D = MonsterScript.new()
	m.setup(d, stage.scaling() if scaling < 0.0 else scaling)
	m.position = Vector2(config["layout"]["spawn_x"], config["layout"]["ground_y"])
	m.died.connect(_on_monster_died)
	add_child(m)
	monsters.append(m)
	return m


func _pick_spawn_id() -> String:
	var pool: Array = stage.current().get("spawn_pool", [])
	var total := 0
	for e in pool:
		total += int(e["weight"])
	var r := rng.randi_range(1, total)
	for e in pool:
		r -= int(e["weight"])
		if r <= 0:
			return e["monster"]
	return pool[0]["monster"]


func _spawn_boss() -> void:
	stage.begin_boss()
	boss = spawn_monster(stage.current().get("boss", ""))
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").boss_appeared.emit(stage.region_id(), stage.stage_no)


func _on_monster_died(m: Node) -> void:
	kill_count += 1
	monsters.erase(m)
	var rewards: Dictionary = m.data.get("rewards", {})
	var sc: float = dungeon.scaling() if dungeon != null else stage.scaling()
	var exp_gain := float(rewards.get("exp", 0))
	if bool(DataRegistry.balance.get("growth", {}).get("exp_stage_scaling", true)):
		exp_gain *= sc
	growth.add_exp(int(round(exp_gain)))
	equipment.add_currency("silver", int(round(float(rewards.get("silver", 0)) * sc)))
	if dungeon != null:
		# 던전 몬스터는 장비를 떨어뜨리지 않고 스테이지 진행에도 들어가지 않는다 (보상은 클리어 보상)
		if m == boss:
			boss = null
		dungeon.record_kill()
		if dungeon.state == DungeonRun.State.CLEARED:
			_on_dungeon_cleared()
		m.queue_free()
		return
	# 장비 드롭 (M8, 수치 가안)
	var drop: Dictionary = equipment.roll_drop(m.is_boss(), stage.scaling(), rng)
	if not drop["item"].is_empty():
		last_drop = drop["item"]
		if not drop["added"]:
			_set_banner("보관함이 가득 차 장비를 버렸습니다", 1.5)
		elif equipment.grade_index(drop["item"]["grade"]) >= 2:
			_set_banner("%s 획득!" % equipment.item_name(drop["item"]), 1.5)
			_sound("drop")
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").monster_killed.emit(m.data.get("id", ""), m.data.get("rewards", {}))
	if m == boss:
		boss = null
		stage.record_boss_kill()
		_clear_cd = _stage_cfg("clear_delay", 2.0)
		_set_banner("스테이지 %d 돌파" % stage.stage_no, _clear_cd)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").stage_cleared.emit(stage.region_id(), stage.stage_no)
	elif stage.record_normal_kill():
		_intro_cd = _stage_cfg("boss_intro_delay", 1.5)
		_set_banner("보스 등장", _intro_cd + 0.5)
		if bool(config.get("stage", {}).get("recover_on_boss", false)):
			player.recover()
	_sync_stage()
	m.queue_free()


# ---- 비급 던전 (M9) ----

## 던전에 들어간다. 일반 스테이지 진행(처치 수, 스테이지)은 그대로 두고 돌아온다.
## 반환값: {ok, reason}
func start_dungeon(dungeon_id: String, today: String = "") -> Dictionary:
	var d: Dictionary = DataRegistry.get_dungeon(dungeon_id)
	if d.is_empty():
		return {"ok": false, "reason": "없는 던전"}
	if dungeon != null:
		return {"ok": false, "reason": "이미 던전 진행 중"}
	var check: Dictionary = collection.can_enter(d, stage.highest_cleared, today)
	if not check["ok"]:
		return check
	collection.record_entry(d, today)
	_clear_monsters()
	boss = null
	player.recover()
	dungeon = DungeonRun.new(d)
	_dungeon_spawn_cd = 0.5
	last_dungeon_result = {}
	_set_banner("%s 입장" % d.get("name", ""), 1.5)
	return {"ok": true, "reason": ""}


func _tick_dungeon(delta: float) -> void:
	var was_running := dungeon.state == DungeonRun.State.RUNNING
	dungeon.tick(delta)
	if was_running and dungeon.state == DungeonRun.State.FAILED:
		_on_dungeon_failed()
		return
	if dungeon.state == DungeonRun.State.RUNNING:
		_dungeon_spawn_cd -= delta
		if _dungeon_spawn_cd <= 0.0:
			_dungeon_spawn_cd = float(dungeon.battle_cfg().get("spawn_interval", 1.2))
			if alive_count() < int(dungeon.battle_cfg().get("max_alive", 4)):
				var sp: Dictionary = dungeon.next_spawn()
				if not sp.is_empty():
					var m := spawn_monster(sp["id"], dungeon.scaling())
					if sp["boss"]:
						boss = m
						_set_banner("던전 보스 등장", 1.5)
	elif dungeon.is_finished():
		_leave_dungeon()


func _on_dungeon_cleared() -> void:
	var rng2 := rng
	var res: Dictionary = collection.grant_clear(dungeon.data, rng2)
	last_dungeon_result = {"cleared": true, "rewards": res}
	var parts: PackedStringArray = []
	for f in res["fragments"]:
		parts.append("%s 조각 %d" % [DataRegistry.get_martial_art(f["art"]).get("name", f["art"]), int(f["amount"])])
	if not res["pity_bonus"].is_empty():
		parts.append("천장 보너스 %d" % int(res["pity_bonus"]["amount"]))
	var unlocked := ""
	for f in res["fragments"] + ([res["pity_bonus"]] if not res["pity_bonus"].is_empty() else []):
		if f.get("unlocked", false):
			unlocked = DataRegistry.get_martial_art(f["art"]).get("name", "")
	if unlocked != "":
		_set_banner("%s 개방!" % unlocked, 2.5)
		if effects:
			effects.play_mastery("spell", player.position + Vector2(0, -40), "%s 개방" % unlocked)
	else:
		_set_banner("던전 클리어: " + ", ".join(parts), 2.5)
	_sound("clear")


func _sound(name: String) -> void:
	if has_node("/root/Sound"):
		get_node("/root/Sound").play(name)


func _on_dungeon_failed() -> void:
	last_dungeon_result = {"cleared": false, "reason": dungeon.fail_reason}
	_set_banner("던전 실패: %s" % dungeon.fail_reason, 2.0)


## 던전을 나와 일반 스테이지로 돌아간다
func _leave_dungeon() -> void:
	_clear_monsters()
	boss = null
	dungeon = null
	player.recover()
	_spawn_cd = 0.5
	# 보스전 중에 들어갔다면 보스 등장부터 다시
	if stage.phase == StageManager.Phase.BOSS:
		stage.phase = StageManager.Phase.BOSS_INTRO
		_intro_cd = _stage_cfg("boss_intro_delay", 1.5)
	_start_stage_banner()


func _go_next_stage() -> void:
	_clear_monsters()
	stage.advance()
	player.recover()
	_spawn_cd = 0.0
	_start_stage_banner()
	_sync_stage()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").stage_started.emit(stage.region_id(), stage.stage_no)


## 캐릭터가 쓰러졌을 때의 임시 처리 (미확정 O-06): 잠시 멈춘 뒤 현재 스테이지를 처음부터 다시 시작한다.
func _on_player_knocked_out() -> void:
	_recover_cd = float(config.get("knockout", {}).get("recover_delay", 2.0))
	if dungeon != null:
		dungeon.fail("쓰러짐")
		_on_dungeon_failed()
		return
	_set_banner("쓰러짐… 스테이지 재시작", _recover_cd)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").player_knocked_out.emit()


func _restart_after_knockout() -> void:
	# 던전에서 쓰러지면 던전만 실패하고 스테이지로 돌아간다 (스테이지 진행은 유지)
	if dungeon != null:
		_leave_dungeon()
		return
	_clear_monsters()
	stage.restart()
	player.recover()
	_spawn_cd = float(config["spawn"]["interval"])
	_start_stage_banner()
	_sync_stage()


func _clear_monsters() -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()
	boss = null


func _stage_cfg(key: String, default: float) -> float:
	return float(config.get("stage", {}).get(key, default))


func _set_banner(text: String, sec: float) -> void:
	banner_text = text
	banner_left = sec


func _start_stage_banner() -> void:
	_set_banner("%s %d" % [stage.region_name(), stage.stage_no], 1.5)


func _show_damage(amount: int, pos: Vector2, color: Color, crit: bool = false) -> void:
	var label: Label = DamageNumberScript.new()
	label.setup(amount, pos, color, crit)
	_effects_layer.add_child(label)


func _redraw_all() -> void:
	queue_redraw()
	if _hud:
		_hud.queue_redraw()


func _draw() -> void:
	# 바닥선
	var ground_y: float = config["layout"]["ground_y"]
	draw_line(Vector2(0, ground_y), Vector2(720, ground_y), Color(0.35, 0.32, 0.45), 2.0)
	# 보스 공격 예고 (연출). area "line"은 보스에서 캐릭터까지 띠, 그 밖은 캐릭터 발밑 원형 표시
	if is_instance_valid(boss) and boss.is_telegraphing():
		var t: float = boss.telegraph_progress()
		var col := Color(1.0, 0.2, 0.15, 0.25 + 0.45 * t)
		if boss.telegraph_pattern.get("area", "") == "line":
			var x0: float = player.position.x - 50.0
			var x1: float = boss.position.x
			draw_rect(Rect2(Vector2(x0, ground_y - 10), Vector2((x1 - x0) * t, 20)), col)
			draw_rect(Rect2(Vector2(x0, ground_y - 10), Vector2(x1 - x0, 20)), Color(1, 0.3, 0.2, 0.6), false, 2.0)
		else:
			var center := Vector2(player.position.x, ground_y)
			draw_circle(center, 70.0 * t, col)
			draw_arc(center, 70.0, 0.0, TAU, 40, Color(1, 0.3, 0.2, 0.7), 2.0)
