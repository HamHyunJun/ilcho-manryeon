extends Node2D
## 플레이어 캐릭터 (왼쪽 고정, 이동 없음).
## 기본 공격은 사거리 안 대상에게 자동 발동한다 (M1).
## 초식은 BattleManager가 TechniqueModeController로 고른 뒤 cast_technique로 발동한다 (M3).
## 그래픽: ChibiArt의 2등신 픽셀 스프라이트. 주력 무공 계열(style)에 따라 복장과 무기가 바뀐다.
## body_size는 사거리·표시 위치 계산용 판정 크기이며 그림 크기와는 별개다.

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
## 장비 특수 효과 (M8): 보스 피해 증가, 받는 피해 감소 (비율)
var boss_damage: float = 0.0
var damage_reduction: float = 0.0

var _attack_cd := 0.0
var _swing := 0.0
var _tech_flash := 0.0
var _tech_color := Color.WHITE
var _hit_flash := 0.0
var _down := false
## 주력 무공 계열 (sword/fist/spell). 복장과 무기를 고른다
var style := "sword"
var _t := 0.0


func _ready() -> void:
	# 4배로 키운 픽셀 텍스처를 선형 필터로 줄여 그려 픽셀 경계를 고르게 한다
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 주력 무공 계열을 바꾼다 (복장/무기 교체)
func set_style(category: String) -> void:
	if category == "":
		category = "sword"
	if style != category:
		style = category
		queue_redraw()


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
	_t += delta
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
	var bonus := boss_damage if target.is_boss() else 0.0
	var dmg := DamageCalculator.compute(atk, attack_coef, target.def, defense_constant, crit, crit_mult, bonus)
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
## tech_bonus: 장비 시너지 등 초식 피해 증가 합계 (M8)
func cast_technique(tech: Dictionary, targets: Array, rng: RandomNumberGenerator, defense_constant: float, color: Color, tech_bonus: float = 0.0) -> Array:
	mp = maxf(0.0, mp - float(tech.get("mp_cost", 0)))
	_tech_flash = 0.3
	_tech_color = color
	var hits: Array = []
	for t in targets:
		var crit := DamageCalculator.roll_crit(rng, crit_rate)
		var bonus := tech_bonus + (boss_damage if t.is_boss() else 0.0)
		var dmg := DamageCalculator.compute(atk, float(tech.get("power_coef", 1.0)), t.def, defense_constant, crit, crit_mult, bonus)
		t.take_damage(dmg)
		hits.append({"target": t, "damage": dmg, "crit": crit})
	queue_redraw()
	return hits


## 피해를 받는다. 장비 피해 감소를 적용하고 실제로 받은 피해를 돌려준다 (최소 1)
func take_damage(amount: int) -> int:
	if _down:
		return 0
	amount = maxi(1, roundi(amount * (1.0 - clampf(damage_reduction, 0.0, 0.9))))
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	queue_redraw()
	if hp == 0:
		_down = true
		knocked_out.emit()
	return amount


## 체력과 내공을 모두 회복한다 (새 스테이지 시작, 쓰러짐 임시 처리 O-06)
func recover() -> void:
	hp = max_hp
	mp = max_mp
	_down = false
	_attack_cd = 0.0
	queue_redraw()


func _draw() -> void:
	var art := ChibiArt.hero(style)
	var sc := ChibiArt.ART_SCALE
	var size: Vector2 = art["size"]
	# 발밑 그림자
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _down:
		# 쓰러짐: 뒤로 누운 자세
		draw_set_transform(Vector2(-10, -6), -PI * 0.5, Vector2.ONE)
		ChibiArt.draw_sprite(self, art["body"], size, Vector2.ZERO, sc, Color(0.7, 0.7, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 공격 준비 자세: 숨쉬듯 들썩이고, 공격·초식 순간 앞으로 내딛는다
	var bob := roundf(sin(_t * 5.0) * 1.2)
	var swing_t := 1.0 - _swing / 0.15 if _swing > 0.0 else 0.0
	var lunge := 0.0
	if _swing > 0.0:
		lunge = 6.0 * sin(swing_t * PI)
	if _tech_flash > 0.0:
		lunge = maxf(lunge, 10.0 * (_tech_flash / 0.3))
	var feet := Vector2(lunge, bob * 0.5)
	# 초식 발동 순간: 계열색 오라
	if _tech_flash > 0.0:
		var c := _tech_color
		c.a = 0.55 * _tech_flash / 0.3
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			ChibiArt.draw_sprite(self, art["flash"], size, feet + o, sc, c)
	var body_tex: Texture2D = art["flash"] if _hit_flash > 0.0 else art["body"]
	ChibiArt.draw_sprite(self, body_tex, size, feet + Vector2(0, bob), sc, InkFx.BONE if _hit_flash > 0.0 else Color.WHITE)
	# 무기: 손 위치에 회전해 그린다
	var hand: Vector2 = feet + Vector2(0, bob) + (Vector2(art["hand"]) - Vector2(size.x * 0.5, size.y)) * sc
	var ang := 0.55
	var off := Vector2.ZERO
	match art["weapon_kind"]:
		"sword":
			ang = 0.55
			if _swing > 0.0:
				ang = lerpf(-0.4, 2.1, swing_t)
			elif _tech_flash > 0.0:
				ang = lerpf(2.3, 0.55, 1.0 - _tech_flash / 0.3)
		"fist":
			ang = 0.0
			off = Vector2(-2, -4)
			if _swing > 0.0 or _tech_flash > 0.0:
				off.x += 12.0 * sin(maxf(swing_t, _tech_flash / 0.3) * PI)
		"talisman":
			ang = 0.15 + sin(_t * 3.0) * 0.05
			off = Vector2(-4, -6)
			if _tech_flash > 0.0:
				ang = -0.35
				off.y -= 8.0 * _tech_flash / 0.3
	ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], hand + off, ang, sc)
	if _swing > 0.0 and art["weapon_kind"] == "sword":
		# 기본 공격 궤적: 먹 초승달 + 붉은 가장자리
		var a := 1.0 - swing_t
		var a1 := lerpf(-1.3, 0.9, minf(swing_t * 1.5, 1.0))
		InkFx.crescent(self, hand + Vector2(4, -6), 46.0, -1.4, a1, 11.0, Color(InkFx.INK, 0.85 * a), 23)
		InkFx.crescent(self, hand + Vector2(4, -6), 52.0, -1.3, a1 - 0.1, 3.5, Color(InkFx.RED, 0.9 * a), 29)
