extends RefCounted
class_name StageManager
## 스테이지 진행 상태 (M2: 스테이지 루프).
## 일반 몬스터 kills_to_boss마리 처치 → 보스 등장 → 보스 처치 → 다음 스테이지 (docs/02 5장, 확정).
## 화면 연출과 몬스터 생성은 BattleManager가 맡고, 여기서는 순수한 진행 상태만 관리한다.
## 상태는 GameState.data["stage"] 모양(docs/10)으로 내보낼 수 있다. 저장은 M4에서 붙인다.

enum Phase { NORMAL, BOSS_INTRO, BOSS, CLEARED }

## 지역 데이터 (data/stages/*.json 한 파일)
var region: Dictionary = {}
var stage_no := 1
var kill_count := 0
var phase: Phase = Phase.NORMAL
## 지역 ID → 가장 높이 깬 스테이지 번호
var highest_cleared: Dictionary = {}


func _init(region_data: Dictionary = {}, start_stage: int = 1) -> void:
	region = region_data
	if not region.is_empty():
		start(start_stage)


func region_id() -> String:
	return region.get("region_id", "")


func region_name() -> String:
	return region.get("name", "")


func stage_count() -> int:
	return region.get("stages", []).size()


## 현재 스테이지 데이터
func current() -> Dictionary:
	var stages: Array = region.get("stages", [])
	for s in stages:
		if int(s["stage_no"]) == stage_no:
			return s
	return stages.back() if not stages.is_empty() else {}


func kills_to_boss() -> int:
	return int(current().get("kills_to_boss", 50))


## 보스 출현까지 남은 일반 몬스터 수
func remaining_to_boss() -> int:
	return maxi(0, kills_to_boss() - kill_count)


## 스테이지 배율 (몬스터 체력/공격력에 곱한다)
func scaling() -> float:
	return float(current().get("scaling", 1.0))


## 지정한 스테이지를 처음부터 시작한다.
func start(no: int) -> void:
	stage_no = clampi(no, 1, maxi(1, stage_count()))
	kill_count = 0
	phase = Phase.NORMAL


## 현재 스테이지를 처음부터 다시 시작한다 (쓰러짐 임시 처리, O-06).
func restart() -> void:
	start(stage_no)


## 아직 일반 몬스터를 더 생성해야 하는지. alive는 화면에 살아 있는 일반 몬스터 수.
func needs_more_normals(alive: int) -> bool:
	return phase == Phase.NORMAL and kill_count + alive < kills_to_boss()


## 일반 몬스터 처치를 기록한다. 보스 등장 조건을 채우면 true.
func record_normal_kill() -> bool:
	if phase != Phase.NORMAL:
		return false
	kill_count += 1
	if kill_count >= kills_to_boss():
		phase = Phase.BOSS_INTRO
		return true
	return false


## 보스 등장 연출이 끝나 실제 보스전이 시작됨
func begin_boss() -> void:
	phase = Phase.BOSS


## 보스 처치를 기록한다.
func record_boss_kill() -> void:
	if phase != Phase.BOSS:
		return
	phase = Phase.CLEARED
	var rid := region_id()
	highest_cleared[rid] = maxi(int(highest_cleared.get(rid, 0)), stage_no)


## 다음에 진행할 스테이지 번호.
## 마지막 스테이지 이후의 처리(다음 지역 개방 등)는 미확정(O-10)이라, 가안으로 마지막 스테이지를 반복한다.
func next_stage_no() -> int:
	return mini(stage_no + 1, maxi(1, stage_count()))


func advance() -> void:
	start(next_stage_no())


## docs/10 저장 데이터의 "stage" 모양으로 내보낸다.
func to_save() -> Dictionary:
	return {
		"region": region_id(),
		"stage_no": stage_no,
		"kill_count": kill_count,
		"highest_cleared": highest_cleared.duplicate(),
	}
