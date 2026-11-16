extends RefCounted
class_name DungeonRun
## 던전 한 번의 진행 상태 (M9, docs/07 3-2 던전 공통 구조).
## 웨이브 순서대로 몬스터를 내보내고, 모든 웨이브를 처치하면 클리어, 제한 시간이 지나거나 쓰러지면 실패.
## 전투 자체는 BattleManager가 일반 스테이지와 같은 방식으로 처리한다.

enum State {RUNNING, CLEARED, FAILED}

var data: Dictionary
var state: State = State.RUNNING
var wave_index := 0
## 이번 웨이브에서 아직 내보내지 않은 몬스터 ID 목록
var _queue: Array = []
var _alive_in_wave := 0
var time_left := 0.0
var result_left := 0.0
var fail_reason := ""
var rewards: Array = []


func _init(dungeon_data: Dictionary) -> void:
	data = dungeon_data
	time_left = float(battle_cfg().get("time_limit", 180))
	_load_wave()


func battle_cfg() -> Dictionary:
	return data.get("battle", {})


func waves() -> Array:
	return data.get("waves", [])


func wave_count() -> int:
	return waves().size()


func scaling() -> float:
	return float(battle_cfg().get("scaling", 1.0))


func _load_wave() -> void:
	_queue.clear()
	_alive_in_wave = 0
	if wave_index >= wave_count():
		return
	var w: Dictionary = waves()[wave_index]
	if w.has("boss"):
		_queue.append({"id": w["boss"], "boss": true})
	for e in w.get("monsters", []):
		for i in int(e.get("count", 1)):
			_queue.append({"id": e["monster"], "boss": false})


## 다음에 내보낼 몬스터 {id, boss}. 없으면 빈 Dictionary
func next_spawn() -> Dictionary:
	if state != State.RUNNING or _queue.is_empty():
		return {}
	_alive_in_wave += 1
	return _queue.pop_front()


func is_boss_wave() -> bool:
	return wave_index < wave_count() and waves()[wave_index].has("boss")


func remaining_in_wave() -> int:
	return _queue.size() + _alive_in_wave


## 처치 기록. 웨이브를 다 잡으면 다음 웨이브, 마지막 웨이브면 클리어
func record_kill() -> void:
	if state != State.RUNNING:
		return
	_alive_in_wave = maxi(0, _alive_in_wave - 1)
	if remaining_in_wave() == 0:
		wave_index += 1
		if wave_index >= wave_count():
			state = State.CLEARED
			result_left = float(battle_cfg().get("result_delay", 2.5))
		else:
			_load_wave()


func tick(delta: float) -> void:
	if state == State.RUNNING:
		time_left -= delta
		if time_left <= 0.0:
			fail("시간 초과")
	else:
		result_left -= delta


func fail(reason: String) -> void:
	if state != State.RUNNING:
		return
	state = State.FAILED
	fail_reason = reason
	result_left = float(battle_cfg().get("result_delay", 2.5))


func is_finished() -> bool:
	return state != State.RUNNING and result_left <= 0.0
