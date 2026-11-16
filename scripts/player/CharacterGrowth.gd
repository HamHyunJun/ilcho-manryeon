extends RefCounted
class_name CharacterGrowth
## 캐릭터 성장 (M7, docs/05): 경험치와 레벨, 경지 9단계 승급, 전투력.
## 상태는 저장 데이터의 character 섹션 {level, exp, realm_tier}을 직접 다룬다.
## 수치는 data/balance/growth.json (모두 가안).

signal leveled_up(level: int)
signal realm_promoted(tier: int)

var state: Dictionary
var cfg: Dictionary


func _init(character_state: Dictionary, growth_config: Dictionary) -> void:
	state = character_state
	cfg = growth_config
	if not state.has("level"):
		state["level"] = 1
	if not state.has("exp"):
		state["exp"] = 0
	if not state.has("realm_tier"):
		state["realm_tier"] = 1


static func new_state() -> Dictionary:
	return {"level": 1, "exp": 0, "realm_tier": 1}


func level() -> int:
	return int(state["level"])


func current_exp() -> int:
	return int(state["exp"])


func level_cap() -> int:
	return int(cfg.get("level_cap", 150))


## 현재 레벨에서 다음 레벨까지 필요한 경험치: base × 레벨^exponent (docs/11 5장)
func exp_to_next() -> int:
	var c: Dictionary = cfg.get("exp_curve", {})
	return int(round(float(c.get("base", 100)) * pow(float(level()), float(c.get("exponent", 1.6)))))


## 경험치를 더한다. 반환값: 오른 레벨 수
func add_exp(amount: int) -> int:
	if amount <= 0 or level() >= level_cap():
		return 0
	state["exp"] = current_exp() + amount
	var gained := 0
	while level() < level_cap() and current_exp() >= exp_to_next():
		state["exp"] = current_exp() - exp_to_next()
		state["level"] = level() + 1
		gained += 1
	if level() >= level_cap():
		state["exp"] = 0
	if gained > 0:
		leveled_up.emit(level())
	return gained


# ---- 경지 ----

func realms() -> Array:
	return cfg.get("realms", [])


func realm_tier() -> int:
	return int(state["realm_tier"])


func realm() -> Dictionary:
	for r in realms():
		if int(r["tier"]) == realm_tier():
			return r
	return {}


func next_realm() -> Dictionary:
	for r in realms():
		if int(r["tier"]) == realm_tier() + 1:
			return r
	return {}


## 다음 경지 승급 조건을 채웠는지. mastered_total은 모든 무공의 대성 초식 합계 (docs/05 3-1)
func can_promote(mastered_total: int) -> bool:
	var nx := next_realm()
	if nx.is_empty():
		return false
	return level() >= int(nx["level"]) and mastered_total >= int(nx["mastered"])


## 조건을 채운 만큼 승급한다 (여러 단계 한 번에 가능). 반환값: 오른 단계 수
func try_promote(mastered_total: int) -> int:
	var n := 0
	while can_promote(mastered_total):
		state["realm_tier"] = realm_tier() + 1
		n += 1
	if n > 0:
		realm_promoted.emit(realm_tier())
	return n


# ---- 능력치 ----

## 레벨과 경지 보너스. PlayerStats.apply 형식 {능력치: {"flat", "percent"}}
## 레벨 보너스는 복리(1.03^(레벨-1))를 percent로 바꿔 넣고, 경지 보너스는 percent로 더한다.
func stat_bonuses() -> Dictionary:
	var out := {}
	var pl: Dictionary = cfg.get("per_level_compound", {})
	for stat in pl.keys():
		_add(out, stat, pow(1.0 + float(pl[stat]), level() - 1) - 1.0)
	var rb: Dictionary = realm().get("bonus", {})
	for stat in rb.keys():
		_add(out, stat, float(rb[stat]))
	return out


static func _add(out: Dictionary, stat: String, percent: float) -> void:
	if not out.has(stat):
		out[stat] = {"flat": 0.0, "percent": 0.0}
	out[stat]["percent"] = float(out[stat]["percent"]) + percent


## 전투력 (가안 가중합, docs/05 2장). stats는 최종 능력치
static func combat_power(stats: Dictionary, mastered_total: int, weights: Dictionary) -> int:
	var crit_gain := float(stats.get("crit_rate", 0.0)) * (float(stats.get("crit_mult", 1.5)) - 1.0)
	var v := float(stats.get("atk", 0)) * float(weights.get("atk", 10)) \
		+ float(stats.get("max_hp", 0)) * float(weights.get("max_hp", 1)) \
		+ float(stats.get("def", 0)) * float(weights.get("def", 5)) \
		+ crit_gain * float(weights.get("crit", 1000)) \
		+ mastered_total * float(weights.get("mastered", 100))
	return int(round(v))
