extends Node2D
## 플레이어 캐릭터 (왼쪽 고정, 이동 없음).
## 기본 공격은 사거리 안 대상에게 자동 발동한다 (M1).
## 초식은 BattleManager가 TechniqueModeController로 고른 뒤 cast_technique로 발동한다 (M3).
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
## 내공 (docs/02 3장, 수치 가안)
var max_mp: float = 100.0
var mp: float = 100.0
var mp_regen: float = 5.0
var body_size := Vector2(48, 80)

var _attack_cd := 0.0
var _swing := 0.0
var _tech_flash := 0.0
var _tech_color := Color.WHITE
var _hit_flash := 0.0
var _down := false


func setup(base: Dictionary) -> void:
	_apply(base)
	hp = max_hp
	mp = max_mp
	_attack_cd = 0.0
	queue_redraw()


## 장착이 바뀌었을 때 능력치만 다시 적용한다. 체력 비율은 유지한다.
func apply_stats(base: Dictionary) -> void:
	var ratio := float(hp) / float(maxi(max_hp, 1))
	_apply(base)
	hp = clampi(roundi(max_hp * ratio), 1 if not _down else 0, max_hp)
	mp = minf(mp, max_mp)
	queue_redraw()


func _apply(base: Dictionary) -> void:
	max_hp = maxi(1, roundi(float(base["max_hp"])))
	atk = float(base["atk"])
	def = float(base["def"])
	crit_rate = float(base["crit_rate"])
	crit_mult = float(base["crit_mult"])
	attack_interval = float(base["basic_attack_interval"])
	attack_coef = float(base["basic_attack_coef"])
	attack_range = float(base["attack_range"])
	max_mp = float(base.get("max_mp", 100))
	mp_regen = float(base.get("mp_regen", 5))


func half_width() -> float:
	return body_size.x * 0.5


func is_down() -> bool:
	return _down


## 한 프레임 진행. 내공을 회복하고, 사거리 안의 가장 가까운 몬스터를 기본 공격한다.
## 반환값: 공격했으면 {target, damage, crit}, 아니면 빈 Dictionary
func tick(delta: float, monsters: Array, rng: RandomNumberGenerator, defense_constant: float) -> Dictionary:
	_swing = maxf(0.0, _swing - delta)
	_tech_flash = maxf(0.0, _tech_flash - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()
	if _down:
		return {}
	mp = minf(max_mp, mp + mp_regen * delta)
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


## 초식 사거리(px) 안의 대상을 가까운 순으로 최대 max_targets명 고른다.
func technique_targets(tech: Dictionary, monsters: Array, range_px: float) -> Array:
	var cands: Array = []
	for m in monsters:
		if not is_instance_valid(m) or m.is_dead():
			continue
		var gap := TargetSelector.edge_gap(position.x, half_width(), m.position.x, m.half_width())
		if gap <= range_px:
			cands.append(m)
	cands.sort_custom(func(a, b): return a.position.x < b.position.x)
	return cands.slice(0, maxi(1, int(tech.get("max_targets", 1))))


## 초식을 발동한다. 내공을 쓰고 대상들에게 피해를 준다.
## 반환값: [{target, damage, crit}, ...]
func cast_technique(tech: Dictionary, targets: Array, rng: RandomNumberGenerator, defense_constant: float, color: Color) -> Array:
	mp = maxf(0.0, mp - float(tech.get("mp_cost", 0)))
	_tech_flash = 0.3
	_tech_color = color
	var hits: Array = []
	for t in targets:
		var crit := DamageCalculator.roll_crit(rng, crit_rate)
		var dmg := DamageCalculator.compute(atk, float(tech.get("power_coef", 1.0)), t.def, defense_constant, crit, crit_mult)
		t.take_damage(dmg)
		hits.append({"target": t, "damage": dmg, "crit": crit})
	queue_redraw()
	return hits


func take_damage(amount: int) -> void:
	if _down:
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	queue_redraw()
	if hp == 0:
		_down = true
		knocked_out.emit()


## 체력과 내공을 모두 회복한다 (새 스테이지 시작, 쓰러짐 임시 처리 O-06)
func recover() -> void:
	hp = max_hp
	mp = max_mp
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
	if _tech_flash > 0.0:
		# 초식 발동 표시 (임시): 앞쪽으로 퍼지는 호. 단계별 이펙트는 M6
		var t := 1.0 - _tech_flash / 0.3
		var c := _tech_color
		c.a = 1.0 - t
		draw_arc(Vector2(half_width(), -body_size.y * 0.5), 30.0 + 120.0 * t, -0.9, 0.9, 16, c, 6.0)
