extends RefCounted
class_name TechniqueModeController
## 자동 초식 발동 순서를 정한다 (M3). docs/02 2-2, 2-3.
## - 단일 수련(기본): 수련 중인 초식 1개만 반복한다.
## - 연속초식: 1초식부터 해금한 초식을 순서대로 발동한다. 대기 중이거나 내공이 부족한 초식은 건너뛴다 (가안).
## 자동 초식 발동 간격(interval)마다 한 번 발동을 시도한다. 대상이 없으면 발동하지 않고 기다린다.

var arts: MartialArtManager
## 자동 초식 발동 간격(초, 가안 1.0)
var interval := 1.0

var _interval_cd := 0.0
## 초식 ID → 남은 재사용 대기시간
var _cooldowns: Dictionary = {}
var _chain_index := 0


func _init(martial_arts: MartialArtManager, auto_interval: float = 1.0) -> void:
	arts = martial_arts
	interval = auto_interval


func tick(delta: float) -> void:
	_interval_cd = maxf(0.0, _interval_cd - delta)
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)


func is_ready() -> bool:
	return _interval_cd <= 0.0


func cooldown_of(tech_id: String) -> float:
	return float(_cooldowns.get(tech_id, 0.0))


func can_cast(tech: Dictionary, mp: float) -> bool:
	return cooldown_of(tech["id"]) <= 0.0 and mp >= float(tech.get("mp_cost", 0))


## 이번에 발동할 초식 후보. 확정하지는 않는다 (발동 후 on_cast 호출).
## 발동할 수 있는 초식이 없으면 빈 Dictionary.
func pick(mp: float) -> Dictionary:
	if not is_ready():
		return {}
	if arts.is_chain_mode():
		var list := arts.unlocked_main_techniques()
		var n := list.size()
		for k in n:
			var t: Dictionary = list[(_chain_index + k) % n]
			if can_cast(t, mp):
				return t
		return {}
	var target_id := arts.training_target()
	if target_id == "":
		return {}
	var tech: Dictionary = arts.registry.get_technique(target_id)
	return tech if can_cast(tech, mp) else {}


## 초식이 실제로 발동했을 때 호출한다. 대기시간을 걸고, 연속초식 순서를 다음 초식으로 넘긴다.
func on_cast(tech: Dictionary) -> void:
	_interval_cd = interval
	_cooldowns[tech["id"]] = float(tech.get("cooldown", 0.0))
	if arts.is_chain_mode():
		var list := arts.unlocked_main_techniques()
		for i in list.size():
			if list[i]["id"] == tech["id"]:
				_chain_index = (i + 1) % list.size()
				break


## 연속초식 순서를 1초식부터 다시 시작한다 (모드를 바꿀 때)
func reset_chain() -> void:
	_chain_index = 0
