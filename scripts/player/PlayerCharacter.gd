extends Node2D
## 플레이어 캐릭터 (왼쪽 고정, 이동 없음).
## 기본 공격은 사거리 안 대상에게 자동 발동한다 (M1).
## 초식은 BattleManager가 TechniqueModeController로 고른 뒤 cast_technique로 발동한다 (M3).
## 그래픽: HeroArt의 1차 모션 시안 동작 시트(10종).
## - 대기(2칸): 사거리 안에 대상이 없을 때 / 걷기(3칸): 화면에 몬스터가 하나도 없을 때(다음 무리를 향해 전진)
## - 공격(1칸): 기본 공격 순간 / 초식(3칸): 초식을 쓰는 동안 차례로 재생
## 외형(appearance)을 고르지 않았으면 주력 무공 계열(style)의 기본 주인공을 쓴다.
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
## 고른 외형 (HeroArt id). "" 이면 계열 기본 주인공
var appearance := ""
var _t := 0.0
## 초식 전투 포즈를 보여 줄 남은 시간
var _pose := 0.0
const POSE_TIME := 0.5
## 전투 화면에서 큰 일러스트의 높이(px)
const FULL_HEIGHT := 118.0
## 전투 화면에서 동작 시트 캐릭터의 몸 높이(px). 큰 일러스트(FULL_HEIGHT)와 같은 키로 보이게 맞춘 값
const BODY_HEIGHT := 112.0
## 기본 공격 동작(공격 칸)을 보여 주는 시간
const ATTACK_TIME := 0.24
var _attack_pose := 0.0
## 화면에 살아 있는 몬스터가 없어 걷는 중인지
var _walking := false


func _ready() -> void:
	# 도트 일러스트를 크게 줄여 그리므로 밉맵 + 선형 필터로 고르게 보이게 한다
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## 주력 무공 계열을 바꾼다 (복장/무기 교체)
func set_style(category: String) -> void:
	if category == "":
		category = "sword"
	if style != category:
		style = category
		queue_redraw()


## 외형을 바꾼다 ("" = 계열 기본 주인공)
func set_appearance(id: String) -> void:
	if appearance != id:
		appearance = id
		queue_redraw()


## 지금 그리는 캐릭터 id
func hero_id() -> String:
	return HeroArt.resolve(appearance, style)


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
	_pose = maxf(0.0, _pose - delta)
	_attack_pose = maxf(0.0, _attack_pose - delta)
	_walking = true
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead():
			_walking = false
			break
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
	_attack_pose = ATTACK_TIME
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
	_pose = POSE_TIME
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
	var id := hero_id()
	# 발밑 그림자
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _down:
		# 쓰러짐: 대기 칸을 뒤로 눕혀 그린다
		draw_set_transform(Vector2(-14, -8), -PI * 0.5, Vector2.ONE)
		HeroArt.draw_motion(self, id, HeroArt.anim_frame("idle", 0.0), Vector2.ZERO, BODY_HEIGHT, false, Color(0.7, 0.7, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var flash := _hit_flash > 0.0
	if _pose > 0.0:
		# 초식: 시안의 초식 동작 3칸을 차례로. 처음엔 살짝 앞으로 튀어나왔다가 자리 잡는다
		var k := 1.0 - _pose / POSE_TIME
		var pf := Vector2(10.0 * sin(minf(k * 3.0, 1.0) * PI * 0.5), 0)
		HeroArt.draw_motion(self, id, HeroArt.anim_frame("skill", 0.0, k), pf, BODY_HEIGHT, false, Color.WHITE, flash)
		return
	if _attack_pose > 0.0:
		# 기본 공격: 공격 칸으로 앞으로 내딛는다
		var k := 1.0 - _attack_pose / ATTACK_TIME
		var lunge := 10.0 * sin(k * PI)
		HeroArt.draw_motion(self, id, HeroArt.anim_frame("attack", 0.0, k), Vector2(lunge, 0), BODY_HEIGHT, false, Color.WHITE, flash)
		if _swing > 0.0:
			# 기본 공격 궤적 (캐릭터 대표색)
			var swing_t := 1.0 - _swing / 0.15
			var tint: Color = HeroArt.info(id)["color"].lightened(0.45)
			tint.a = 0.6 * (1.0 - swing_t)
			draw_arc(Vector2(lunge + 30, -BODY_HEIGHT * 0.5), 46.0, -1.3, 0.6 * swing_t + 0.1, 16, tint, 4.0)
		return
	if _walking:
		HeroArt.draw_motion(self, id, HeroArt.anim_frame("walk", _t), Vector2.ZERO, BODY_HEIGHT, false, Color.WHITE, flash)
		return
	# 대기: 시안의 대기 2칸 + 숨쉬듯 살짝 들썩임
	var bob := roundf(sin(_t * 5.0) * 1.2) * 0.5
	HeroArt.draw_motion(self, id, HeroArt.anim_frame("idle", _t), Vector2(0, bob), BODY_HEIGHT, false, Color.WHITE, flash)
