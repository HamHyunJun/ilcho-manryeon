class_name DamageCalculator
extends RefCounted
## 피해 계산 (순수 함수).
## 수식은 docs/02-combat.md 4장의 가안을 따른다.
##   최종 피해 = 공격력 × 계수 × (1 + 피해 증가 합계) × 치명타 배율(발생 시) × 방어 보정
##   방어 보정 = K / (K + 대상 방어력)      (K = defense_constant, 가안 100)


## 피해량을 계산한다. 최소 1.
static func compute(atk: float, coef: float, target_def: float, defense_constant: float,
		is_crit: bool = false, crit_mult: float = 1.5, bonus: float = 0.0) -> int:
	var dmg := atk * coef * (1.0 + bonus)
	if is_crit:
		dmg *= crit_mult
	dmg *= defense_constant / (defense_constant + maxf(target_def, 0.0))
	return maxi(1, roundi(dmg))


## 치명타 여부를 굴린다.
static func roll_crit(rng: RandomNumberGenerator, crit_rate: float) -> bool:
	return rng.randf() < crit_rate
