extends Node2D
## 몬스터 (M1 근접형 기본 동작 + M2 보스 패턴).
## 오른쪽에서 생성되어 왼쪽(캐릭터)으로 접근하고, 사거리에 들어오면 멈춰서 공격한다.
## 보스(type "boss")는 기본 공격 사이사이에 패턴을 쓴다. 패턴은 예고 시간이 지나면 반드시 맞는다.
## 공격 예고는 플레이어가 피하는 장치가 아니라 연출이다 (docs/02 7장, 가안).
## 유형별 동작(돌진, 원거리, 방어형 등)은 이후 type 값에 따라 추가한다.
## 그래픽: 데이터의 sprite(없으면 유형별 기본값) 세트로 픽셀 스프라이트를 그린다.
## 그림 파일이 없으면 예전처럼 사각형으로 그린다. 체력 바는 직접 그린다.

signal died(monster: Node)

var data: Dictionary = {}
var max_hp: int = 1
var hp: int = 1
var atk: float = 0.0
var def: float = 0.0
var move_speed: float = 0.0
var attack_range: float = 0.0
var attack_interval: float = 1.0
var body_size := Vector2(44, 60)
var body_color := Color.INDIAN_RED

## 보스 패턴 상태
var patterns: Array = []
## 예고 중인 패턴 (없으면 빈 Dictionary)
var telegraph_pattern: Dictionary = {}
var telegraph_left := 0.0
## 지금까지 쓴 패턴 수 (테스트, 연출용)
var patterns_used := 0

var _attack_cd := 0.0
var _hit_flash := 0.0
var _dead := false
var _pattern_cd: Dictionary = {}
## 픽셀 스프라이트 (그림이 없으면 null)
var sprite: PixelSprite


## scaling: 스테이지 배율. 체력과 공격력에 곱한다 (docs/11 4장, 가안).
func setup(d: Dictionary, scaling: float = 1.0) -> void:
	data = d
	max_hp = maxi(1, roundi(float(d["max_hp"]) * scaling))
	hp = max_hp
	atk = float(d["atk"]) * scaling
	def = float(d["def"])
	move_speed = float(d["move_speed"])
	attack_range = float(d["attack_range"])
	attack_interval = float(d["attack_interval"])
	if d.has("size"):
		body_size = Vector2(d["size"][0], d["size"][1])
	if d.has("color"):
		body_color = Color.html(d["color"])
	patterns = d.get("patterns", [])
	for p in patterns:
		_pattern_cd[p["id"]] = float(p.get("first_delay", p.get("cooldown", 8.0)))
	_attack_cd = attack_interval * 0.5
	_setup_sprite()
	queue_redraw()


func _setup_sprite() -> void:
	var reg := get_node_or_null("/root/DataRegistry") if is_inside_tree() else null
	if reg == null:
		reg = Engine.get_main_loop().root.get_node_or_null("DataRegistry") if Engine.get_main_loop() is SceneTree else null
	if reg == null:
		return
	var set_data: Dictionary = reg.monster_sprite_set(data)
	if set_data.is_empty():
		return
	if sprite == null:
		sprite = PixelSprite.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.setup(set_data)
	if not sprite.is_valid():
		sprite.queue_free()
		sprite = null


## 화면에 보이는 몸 높이 (체력 바 위치). 스프라이트가 있으면 그림 높이를 쓴다
func visual_height() -> float:
	if sprite != null:
		return maxf(sprite.visual_height(), 1.0)
	return body_size.y

func is_boss() -> bool:
	return data.get("type", "") == "boss"


func half_width() -> float:
	return body_size.x * 0.5


func is_dead() -> bool:
	return _dead


func is_telegraphing() -> bool:
	return not telegraph_pattern.is_empty()


## 예고 진행도 0~1
func telegraph_progress() -> float:
	if not is_telegraphing():
		return 0.0
	var total := float(telegraph_pattern.get("telegraph_sec", 1.0))
	return clampf(1.0 - telegraph_left / maxf(total, 0.001), 0.0, 1.0)


## 한 프레임 진행. player가 사거리 밖이면 다가가고, 안이면 공격한다.
## 반환값: 이번 프레임에 준 피해(없으면 0)
func tick(delta: float, player, defense_constant: float) -> int:
	if _dead:
		return 0
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var gap := TargetSelector.edge_gap(player.position.x, player.half_width(), position.x, half_width())
	var dealt := 0
	if gap > attack_range:
		# 사거리까지 남은 거리만큼만 이동 (지나치지 않게)
		position.x -= minf(move_speed * delta, gap - attack_range)
	elif not player.is_down():
		if not patterns.is_empty():
			dealt = _tick_patterns(delta, player, defense_constant)
		if not is_telegraphing() and dealt == 0:
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = attack_interval
				_play("attack")
				dealt = player.take_damage(DamageCalculator.compute(atk, 1.0, player.def, defense_constant))
	queue_redraw()
	return dealt


## 보스 패턴: 쿨타임이 찬 패턴을 예고하고, 예고가 끝나면 피해를 준다.
func _tick_patterns(delta: float, player, defense_constant: float) -> int:
	if is_telegraphing():
		telegraph_left -= delta
		if telegraph_left > 0.0:
			return 0
		_play("attack")
		var coef := float(telegraph_pattern.get("power_coef", 1.0))
		var dmg: int = player.take_damage(DamageCalculator.compute(atk, coef, player.def, defense_constant))
		_pattern_cd[telegraph_pattern["id"]] = float(telegraph_pattern.get("cooldown", 8.0))
		telegraph_pattern = {}
		patterns_used += 1
		return dmg
	for p in patterns:
		_pattern_cd[p["id"]] = float(_pattern_cd[p["id"]]) - delta
	for p in patterns:
		if float(_pattern_cd[p["id"]]) <= 0.0:
			telegraph_pattern = p
			telegraph_left = float(p.get("telegraph_sec", 1.0))
			break
	return 0


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	if sprite != null:
		sprite.flash(0.1)
		# 공격 동작 중에는 동작을 끊지 않고 번쩍임만 준다
		if sprite.current != "attack":
			sprite.play("hit", true)
	queue_redraw()
	if hp == 0:
		_dead = true
		telegraph_pattern = {}
		died.emit(self)


func _play(anim_name: String) -> void:
	if sprite != null:
		sprite.play(anim_name, true)


func _draw() -> void:
	var rect := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	if sprite != null:
		# 패턴 예고 중에는 몸을 붉게 깜빡인다
		var t := Color.WHITE
		if is_telegraphing():
			var k := absf(sin(telegraph_progress() * PI * 4.0))
			t = Color(1.0, 1.0 - 0.6 * k, 1.0 - 0.6 * k)
		if sprite.tint != t:
			sprite.tint = t
			sprite.queue_redraw()
	else:
		draw_rect(rect, Color.WHITE if _hit_flash > 0.0 else body_color)
	if is_telegraphing() and sprite == null:
		# 패턴 준비 중: 몸 테두리를 깜빡인다
		var a := 0.4 + 0.6 * absf(sin(telegraph_progress() * PI * 4.0))
		draw_rect(rect.grow(4), Color(1.0, 0.3, 0.2, a), false, 3.0)
	if is_boss():
		return  # 보스 체력은 상단 HUD의 보스 체력 바로 표시한다
	# 체력 바
	var bar_w := body_size.x + 8.0
	var bar_pos := Vector2(-bar_w * 0.5, -visual_height() - 10.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 6)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * float(hp) / float(max_hp), 6)), Color(0.85, 0.2, 0.2))
