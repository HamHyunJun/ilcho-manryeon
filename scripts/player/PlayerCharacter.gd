extends Node2D
## 플레이어 캐릭터 (왼쪽 고정, 이동 없음).
## M1에서는 기본 공격만 자동 발동한다. 초식 발동과 수련은 M3에서 추가한다.
## 임시 그래픽: 사각형과 공격 표시를 직접 그린다.

signal knocked_out()

var max_hp: int = 1
var hp: int = 1
var atk: float = 0.0
var def: float = 0.0
var crit_rate: float = 0.0
var crit_mult: float = 1.5
var attack_interval: float = 1.0
var attack_coef: float = 1.0
var attack_range: float = 0.0
var body_size := Vector2(48, 80)

var _attack_cd := 0.0
var _swing := 0.0
var _hit_flash := 0.0
var _down := false


func setup(base: Dictionary) -> void:
	max_hp = int(base["max_hp"])
	hp = max_hp
	atk = float(base["atk"])
	def = float(base["def"])
	crit_rate = float(base["crit_rate"])
	crit_mult = float(base["crit_mult"])
	attack_interval = float(base["basic_attack_interval"])
	attack_coef = float(base["basic_attack_coef"])
	attack_range = float(base["attack_range"])
	_attack_cd = 0.0
	queue_redraw()


func half_width() -> float:
	return body_size.x * 0.5


func is_down() -> bool:
	return _down


## 한 프레임 진행. 사거리 안의 가장 가까운 몬스터를 기본 공격한다.
## 반환값: 공격했으면 {target, damage, crit}, 아니면 빈 Dictionary
func tick(delta: float, monsters: Array, rng: RandomNumberGenerator, defense_constant: float) -> Dictionary:
	_swing = maxf(0.0, _swing - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()
	if _down:
		return {}
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _attack_cd > 0.0:
		return {}
	var target = TargetSelector.nearest_in_range(position.x, half_width(), attack_range, monsters)
	if target == null:
		# 대상이 없으면 공격하지 않고 대기 (대기시간도 소모하지 않음)
		return {}
	_attack_cd = attack_interval
	_swing = 0.15
	var crit := DamageCalculator.roll_crit(rng, crit_rate)
	var dmg := DamageCalculator.compute(atk, attack_coef, target.def, defense_constant, crit, crit_mult)
	target.take_damage(dmg)
	return {"target": target, "damage": dmg, "crit": crit}


func take_damage(amount: int) -> void:
	if _down:
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	queue_redraw()
	if hp == 0:
		_down = true
		knocked_out.emit()


## 쓰러진 상태에서 체력을 모두 회복한다 (임시 처리, 미확정 O-06)
func recover() -> void:
	hp = max_hp
	_down = false
	_attack_cd = 0.0
	queue_redraw()


func _draw() -> void:
	var color := Color(0.35, 0.55, 0.95)
	if _down:
		color = Color(0.4, 0.4, 0.45)
	elif _hit_flash > 0.0:
		color = Color.WHITE
	var rect := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	if _down:
		# 쓰러짐: 눕힌 사각형
		rect = Rect2(Vector2(-body_size.y * 0.5, -body_size.x), Vector2(body_size.y, body_size.x))
	draw_rect(rect, color)
	if _swing > 0.0:
		# 기본 공격 표시: 앞쪽으로 뻗는 선
		var reach := 60.0 * (1.0 - _swing / 0.15) + 20.0
		draw_line(Vector2(half_width(), -body_size.y * 0.6), Vector2(half_width() + reach, -body_size.y * 0.5), Color(1, 1, 0.8), 4.0)
