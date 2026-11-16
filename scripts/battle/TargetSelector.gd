class_name TargetSelector
extends RefCounted
## 공격 대상 선택 (순수 함수).
## 캐릭터는 왼쪽에 고정이고 몬스터는 오른쪽에서 오므로, 앞쪽 가장자리 사이 거리가 가장 가까운 몬스터를 고른다.


## 두 대상의 가장자리 사이 가로 거리 (겹치면 0)
static func edge_gap(attacker_x: float, attacker_half: float, target_x: float, target_half: float) -> float:
	return maxf(0.0, absf(target_x - attacker_x) - attacker_half - target_half)


## 사거리 안에서 가장 가까운 살아 있는 몬스터. 없으면 null.
static func nearest_in_range(from_x: float, from_half: float, attack_range: float, candidates: Array):
	var best = null
	var best_gap := INF
	for m in candidates:
		if not is_instance_valid(m) or m.is_dead():
			continue
		var gap := edge_gap(from_x, from_half, m.position.x, m.half_width())
		if gap <= attack_range and gap < best_gap:
			best = m
			best_gap = gap
	return best
