extends RefCounted
class_name OfflineTraining
## 오프라인 수련 계산 (M10, docs/07 4장, docs/10 5장).
## - 경과 시간: 같은 실행 세션이면 단조 시간 차이, 아니면 기기 시간 차이(음수면 0). 최대 인정 시간으로 자른다.
## - 시계 조작 완화: 기기 시간이 저장 시점보다 과거로 가면 보상 0, 그 시점을 지나기 전까지 계속 0.
##   돌아온 뒤에도 "되돌린 시점"이 아니라 원래 저장 시점부터 센다.
## - 횟수: 항상 단일 수련 기준(확정 사항 23). 추정 발동 수 = 경과 초 × 초당 발동 수(가안 O-33) × 수련 배율 × 효율.
## - 대성하면 다음 초식으로 남은 횟수를 이어서 반영한다.
## - 오프라인 중 경험치, 재화, 스테이지 진행은 주지 않는다(가안, O-32).


## 경과 시간 판정.
## saved/now: {unix, mono_ms, session}. rollback_until: 이전에 감지한 시계 되돌림 기준 시각(없으면 0)
## 반환값: {seconds, method, rollback, capped, raw_seconds, rollback_until}
static func elapsed(saved: Dictionary, now: Dictionary, max_seconds: float, rollback_until: int = 0) -> Dictionary:
	var out := {"seconds": 0.0, "method": "", "rollback": false, "capped": false, "raw_seconds": 0.0, "rollback_until": rollback_until}
	var now_unix := int(now.get("unix", 0))
	var saved_unix := int(saved.get("unix", 0))
	if saved_unix <= 0:
		return out
	# 되돌림이 감지된 적 있으면, 그 시각을 지나야 보상을 다시 준다
	var ref_unix := maxi(saved_unix, rollback_until)
	if now_unix < ref_unix:
		out["rollback"] = true
		out["rollback_until"] = ref_unix
		out["method"] = "rollback"
		return out
	out["rollback_until"] = 0
	var raw := 0.0
	if saved.get("session", "") != "" and saved.get("session", "") == now.get("session", "") \
			and int(now.get("mono_ms", -1)) >= int(saved.get("mono_ms", 0)):
		raw = float(int(now["mono_ms"]) - int(saved["mono_ms"])) / 1000.0
		out["method"] = "monotonic"
	else:
		raw = float(now_unix - ref_unix)
		out["method"] = "device"
	raw = maxf(raw, 0.0)
	out["raw_seconds"] = raw
	out["seconds"] = minf(raw, max_seconds)
	out["capped"] = raw > max_seconds
	return out


## 초당 발동 수 (가안 O-33): 초식 간격과 내공 회복 중 느린 쪽
static func casts_per_second(tech: Dictionary, technique_interval: float, mp_regen: float) -> float:
	var rate := 1.0 / maxf(technique_interval, 0.01)
	var cooldown := float(tech.get("cooldown", 0.0))
	if cooldown > 0.0:
		rate = minf(rate, 1.0 / cooldown)
	var cost := float(tech.get("mp_cost", 0.0))
	if cost > 0.0:
		rate = minf(rate, mp_regen / cost)
	return rate


## 오프라인 수련을 적용한다. 항상 단일 수련(수련 중인 초식 1개 반복)으로 계산하고, 대성하면 다음 초식으로 이월한다.
## 반환값: {seconds, casts, gains: {초식 ID: 오른 횟수}, mastered: [초식 ID]}
static func apply(arts: MartialArtManager, seconds: float, cfg: Dictionary) -> Dictionary:
	var result := {"seconds": seconds, "casts": 0, "gains": {}, "mastered": []}
	if seconds <= 0.0 or arts.main_art() == "":
		return result
	var efficiency := float(cfg.get("efficiency", 0.5))
	var multiplier := float(cfg.get("multiplier", 1.0))
	var interval := float(cfg.get("technique_interval", 1.0))
	var mp_regen := float(cfg.get("mp_regen", 5.0))
	var tid := arts.training_target()
	var tech: Dictionary = arts.registry.get_technique(tid)
	var budget := seconds * casts_per_second(tech, interval, mp_regen) * multiplier * efficiency
	result["casts"] = int(floor(budget))
	var guard := 0
	while budget >= 1.0 and guard < 64:
		guard += 1
		tid = arts.training_target()
		if tid == "" or not arts.is_tech_unlocked(tid):
			break
		var before := arts.count_of(tid)
		var need := budget
		if not arts.is_mastered(tid):
			need = minf(budget, float(arts.mastery_target_of(tid) - before))
		var mastered_now := arts.record_performed(tid, need)
		var gained := arts.count_of(tid) - before
		result["gains"][tid] = int(result["gains"].get(tid, 0)) + gained
		budget -= need
		if mastered_now:
			result["mastered"].append(tid)
		elif arts.is_mastered(tid) and arts.training_target() == tid:
			# 모두 대성: 마지막 초식에 남은 횟수를 모두 넣고 끝
			if budget >= 1.0:
				var b2 := arts.count_of(tid)
				arts.record_performed(tid, budget)
				result["gains"][tid] = int(result["gains"][tid]) + arts.count_of(tid) - b2
			break
		if gained <= 0:
			break
	return result


## 경과 시간을 "3시간 12분" 형식으로
static func format_duration(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d시간 %d분" % [h, m]
	if m > 0:
		return "%d분 %d초" % [m, s % 60]
	return "%d초" % s
