extends RefCounted
class_name EffectPresets
## 수련 단계 이펙트 프리셋 해석기 (M6, docs/03 4장).
## data/effects/effect_presets.json의 "계열 색/모양" + "단계 파라미터"를 합쳐 한 번의 연출 파라미터를 만든다.
## 수치는 모두 가안이며 데이터만 바꿔 조정한다.

const STAGE_COUNT := 7


## 수련 횟수 → 단계 번호(1~7). 대성했으면 7. thresholds는 training.json의 stage_thresholds.
static func stage_index_for(count: int, thresholds: Array, mastered: bool = false) -> int:
	if mastered:
		return STAGE_COUNT
	var idx := 1
	for i in thresholds.size():
		if count >= int(thresholds[i].get("min", 0)):
			idx = i + 1
	# 대성(7단계)은 mastered 플래그로만 판정한다 (목표 횟수가 초식마다 다를 수 있음)
	return clampi(idx, 1, STAGE_COUNT - 1)


## 계열과 단계로 연출 파라미터를 만든다. 없는 계열은 default_category를 쓴다.
## tech를 주면 대성 단계에서 초식 전용 연출 지정(mastery_effect)을 반영한다 (없으면 계열 대성 프리셋).
static func resolve(presets: Dictionary, category: String, stage: int, tech: Dictionary = {}) -> Dictionary:
	var cats: Dictionary = presets.get("categories", {})
	var cat_id := category if cats.has(category) else String(presets.get("default_category", "sword"))
	var cat: Dictionary = cats.get(cat_id, {})
	var stages: Array = presets.get("stages", [])
	var st: Dictionary = {}
	for s in stages:
		if int(s.get("stage", 0)) == stage:
			st = s
	if st.is_empty() and not stages.is_empty():
		st = stages[clampi(stage - 1, 0, stages.size() - 1)]
	var out: Dictionary = st.duplicate(true)
	out["stage"] = clampi(stage, 1, STAGE_COUNT)
	out["category"] = cat_id
	out["color_primary"] = Color.html(String(cat.get("color_primary", "#ffffff")))
	out["color_secondary"] = Color.html(String(cat.get("color_secondary", "#ffffff")))
	out["particle_shape"] = cat.get("particle_shape", "petal")
	out["motif"] = cat.get("motif", "slash")
	var elements: Array = []
	for c in cat.get("element_colors", []):
		elements.append(Color.html(String(c)))
	out["element_colors"] = elements
	out["mastery_effect"] = ""
	if stage >= STAGE_COUNT and tech.has("mastery_effect"):
		out["mastery_effect"] = String(tech["mastery_effect"])
	return out


## 데이터 검증: 오류 메시지 목록을 돌려준다
static func validate(presets: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	if presets.is_empty():
		errs.append("effect_presets 없음")
		return errs
	for c in ["sword", "fist", "spell"]:
		if not presets.get("categories", {}).has(c):
			errs.append("계열 프리셋 없음: %s" % c)
	var stages: Array = presets.get("stages", [])
	if stages.size() != STAGE_COUNT:
		errs.append("단계 프리셋은 %d개여야 함 (현재 %d)" % [STAGE_COUNT, stages.size()])
	var prev := -1.0
	for s in stages:
		var p := float(s.get("particles", 0)) + float(s.get("scale", 0)) * 10.0 + float(s.get("duration", 0)) * 10.0
		if p < prev:
			errs.append("단계 %d 파라미터가 이전 단계보다 작음" % int(s.get("stage", 0)))
		prev = p
	return errs
