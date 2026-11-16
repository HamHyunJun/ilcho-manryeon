extends Node2D
## 전투 관리자 (M1: 전투 기본).
## - 왼쪽에 캐릭터를 고정 배치하고, 오른쪽에서 몬스터를 주기적으로 생성한다.
## - 캐릭터 기본 공격, 몬스터 접근/공격, 피해 숫자, 처치를 처리한다.
## - 모든 수치는 data/balance/combat.json, data/monsters/*.json에서 읽는다.
## 스테이지 루프(50마리 → 보스)는 M2, 초식 발동은 M3에서 추가한다.

const PlayerScript := preload("res://scripts/player/PlayerCharacter.gd")
const MonsterScript := preload("res://scripts/battle/Monster.gd")
const DamageNumberScript := preload("res://scripts/battle/DamageNumber.gd")

## true면 _process에서 자동으로 진행하지 않는다 (테스트에서 tick을 직접 호출)
@export var manual_tick := false

var config: Dictionary = {}
var player: Node2D
var monsters: Array = []
var kill_count := 0
var rng := RandomNumberGenerator.new()

var _spawn_cd := 0.0
var _recover_cd := 0.0
var _defense_constant := 100.0
var _effects_layer: Node2D


func _ready() -> void:
	rng.randomize()
	setup(DataRegistry.balance.get("combat", {}))


## 전투를 초기화한다. 테스트에서 다른 설정으로 다시 호출할 수 있다.
func setup(combat_config: Dictionary) -> void:
	config = combat_config
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()
	kill_count = 0
	_defense_constant = float(config.get("defense_constant", 100))

	if player == null:
		player = PlayerScript.new()
		player.name = "Player"
		add_child(player)
		player.knocked_out.connect(_on_player_knocked_out)
	player.setup(config["player_base"])
	player.position = Vector2(config["layout"]["player_x"], config["layout"]["ground_y"])

	if _effects_layer == null:
		_effects_layer = Node2D.new()
		_effects_layer.name = "Effects"
		_effects_layer.z_index = 10
		add_child(_effects_layer)

	_spawn_cd = 0.0
	_recover_cd = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not manual_tick:
		tick(delta)


## 전투를 delta초 진행한다.
func tick(delta: float) -> void:
	if player.is_down():
		_recover_cd -= delta
		if _recover_cd <= 0.0:
			_recover_from_knockout()
		player.tick(delta, [], rng, _defense_constant)
		queue_redraw()
		return

	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = float(config["spawn"]["interval"])
		if alive_count() < int(config["spawn"]["max_alive"]):
			spawn_monster(_pick_spawn_id())

	var hit: Dictionary = player.tick(delta, monsters, rng, _defense_constant)
	if not hit.is_empty() and is_instance_valid(hit["target"]):
		var color := Color(1.0, 0.85, 0.2) if hit["crit"] else Color.WHITE
		_show_damage(hit["damage"], hit["target"].position + Vector2(0, -hit["target"].body_size.y), color, hit["crit"])

	for m in monsters.duplicate():
		if not is_instance_valid(m) or m.is_dead():
			continue
		var dealt: int = m.tick(delta, player, _defense_constant)
		if dealt > 0:
			_show_damage(dealt, player.position + Vector2(0, -player.body_size.y), Color(1.0, 0.4, 0.4))
	queue_redraw()


func alive_count() -> int:
	var n := 0
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead():
			n += 1
	return n


## 몬스터 하나를 화면 오른쪽에 생성한다.
func spawn_monster(monster_id: String) -> Node2D:
	var d: Dictionary = DataRegistry.get_monster(monster_id)
	if d.is_empty():
		push_error("[Battle] 알 수 없는 몬스터: " + monster_id)
		return null
	var m: Node2D = MonsterScript.new()
	m.setup(d)
	m.position = Vector2(config["layout"]["spawn_x"], config["layout"]["ground_y"])
	m.died.connect(_on_monster_died)
	add_child(m)
	monsters.append(m)
	return m


func _pick_spawn_id() -> String:
	var pool: Array = config["spawn"]["test_pool"]
	var total := 0
	for e in pool:
		total += int(e["weight"])
	var r := rng.randi_range(1, total)
	for e in pool:
		r -= int(e["weight"])
		if r <= 0:
			return e["monster"]
	return pool[0]["monster"]


func _on_monster_died(m: Node) -> void:
	kill_count += 1
	monsters.erase(m)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").monster_killed.emit(m.data.get("id", ""), m.data.get("rewards", {}))
	m.queue_free()


## 캐릭터가 쓰러졌을 때의 임시 처리 (미확정 O-06): 잠시 멈춘 뒤 회복하고 몬스터를 정리한다.
func _on_player_knocked_out() -> void:
	_recover_cd = float(config.get("knockout", {}).get("recover_delay", 2.0))
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").player_knocked_out.emit()


func _recover_from_knockout() -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()
	player.recover()
	_spawn_cd = float(config["spawn"]["interval"])


func _show_damage(amount: int, pos: Vector2, color: Color, crit: bool = false) -> void:
	var label: Label = DamageNumberScript.new()
	label.setup(amount, pos, color, crit)
	_effects_layer.add_child(label)


func _draw() -> void:
	# 바닥선
	var ground_y: float = config["layout"]["ground_y"]
	draw_line(Vector2(0, ground_y), Vector2(720, ground_y), Color(0.35, 0.32, 0.45), 2.0)
	# 임시 상단 표시: 캐릭터 체력 바와 처치 수 (상단 HUD 정식 구현은 M2)
	var bar := Rect2(Vector2(32, 300), Vector2(656, 18))
	draw_rect(bar, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(player.hp) / float(player.max_hp), bar.size.y)), Color(0.3, 0.8, 0.4))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(32, 290), "체력 %d / %d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, Vector2(560, 290), "처치 %d" % kill_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	if player.is_down():
		draw_string(font, Vector2(260, 560), "쓰러짐… 회복 중", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.5, 0.5))
