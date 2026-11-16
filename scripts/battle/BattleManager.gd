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

var _spawn_cd := 0.0
var _recover_cd := 0.0
var _intro_cd := 0.0
var _clear_cd := 0.0
var _defense_constant := 100.0
var _effects_layer: Node2D
var _hud: Node2D


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

	if martial_arts == null and has_node("/root/GameState"):
		martial_arts = get_node("/root/GameState").arts
	if arts != null and arts.equipment_changed.is_connected(_refresh_stats):
		arts.equipment_changed.disconnect(_refresh_stats)
	arts = martial_arts
	if arts != null:
		arts.equipment_changed.connect(_refresh_stats)
		techniques = TechniqueModeController.new(arts, float(config["player_base"].get("technique_interval", 1.0)))

	if player == null:
		player = PlayerScript.new()
		player.name = "Player"
		add_child(player)
		player.knocked_out.connect(_on_player_knocked_out)
	player.setup(_effective_stats())
	player.position = Vector2(config["layout"]["player_x"], config["layout"]["ground_y"])

	if _effects_layer == null:
		_effects_layer = Node2D.new()
		_effects_layer.name = "Effects"
		_effects_layer.z_index = 10
		add_child(_effects_layer)
	if _hud == null:
		_hud = HudScript.new()
		_hud.name = "Hud"
		_hud.z_index = 20
		_hud.battle = self
		add_child(_hud)

	_spawn_cd = 0.0
	_recover_cd = 0.0
	_start_stage_banner()
	queue_redraw()


## 기본 능력치에 보조 무공 패시브를 더한 능력치
func _effective_stats() -> Dictionary:
	var bonuses: Dictionary = arts.sub_passives() if arts != null else {}
	return PlayerStats.apply(config["player_base"], bonuses)


## 장착이 바뀌면 능력치를 다시 계산한다 (체력 비율 유지)
func _refresh_stats() -> void:
	player.apply_stats(_effective_stats())
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

	if player.is_down():
		_recover_cd -= delta
		if _recover_cd <= 0.0:
			_restart_after_knockout()
		player.tick(delta, [], rng, _defense_constant)
		_redraw_all()
		return

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
	var color := _category_color(DataRegistry.get_martial_art(art_id).get("category", ""))
	var hits: Array = player.cast_technique(tech, targets, rng, _defense_constant, color)
	techniques.on_cast(tech)
	techniques_cast += 1
	var multiplier := float(DataRegistry.balance.get("training", {}).get("base_multiplier", 1.0))
	arts.record_performed(tech["id"], multiplier)
	last_technique_name = tech.get("name", "")
	last_technique_left = 0.8
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").technique_performed.emit(art_id, tech["id"])
	for h in hits:
		if is_instance_valid(h["target"]):
			var c := color.lightened(0.3) if h["crit"] else color
			_show_damage(h["damage"], h["target"].position + Vector2(0, -h["target"].body_size.y - 30), c, h["crit"])


## 계열별 임시 색 (계열 이펙트 프리셋은 M6)
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
func spawn_monster(monster_id: String) -> Node2D:
	var d: Dictionary = DataRegistry.get_monster(monster_id)
	if d.is_empty():
		push_error("[Battle] 알 수 없는 몬스터: " + monster_id)
		return null
	var m: Node2D = MonsterScript.new()
	m.setup(d, stage.scaling())
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
	m.queue_free()


func _go_next_stage() -> void:
	_clear_monsters()
	stage.advance()
	player.recover()
	_spawn_cd = 0.0
	_start_stage_banner()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").stage_started.emit(stage.region_id(), stage.stage_no)


## 캐릭터가 쓰러졌을 때의 임시 처리 (미확정 O-06): 잠시 멈춘 뒤 현재 스테이지를 처음부터 다시 시작한다.
func _on_player_knocked_out() -> void:
	_recover_cd = float(config.get("knockout", {}).get("recover_delay", 2.0))
	_set_banner("쓰러짐… 스테이지 재시작", _recover_cd)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").player_knocked_out.emit()


func _restart_after_knockout() -> void:
	_clear_monsters()
	stage.restart()
	player.recover()
	_spawn_cd = float(config["spawn"]["interval"])
	_start_stage_banner()


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
