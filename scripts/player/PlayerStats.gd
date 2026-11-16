extends RefCounted
class_name PlayerStats
## 캐릭터 능력치 계산 (M3: 기본 능력치 + 보조 무공 패시브).
## 경지, 장비, 소환 보정은 해당 단계(M7, M8 등)에서 같은 방식으로 더한다.

## base(combat.json의 player_base)에 보너스를 적용한 새 Dictionary를 돌려준다.
## bonuses: {능력치: {"flat": n, "percent": n}} → 최종 = (기본 + flat) × (1 + percent)
static func apply(base: Dictionary, bonuses: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for stat in bonuses.keys():
		if not out.has(stat):
			continue
		var b: Dictionary = bonuses[stat]
		var v := (float(out[stat]) + float(b.get("flat", 0.0))) * (1.0 + float(b.get("percent", 0.0)))
		out[stat] = v
	return out
