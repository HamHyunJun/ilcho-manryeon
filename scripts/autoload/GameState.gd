extends Node
## 런타임 게임 상태 보관소.
## 저장 데이터(SaveData) 구조는 docs/10-save-data.md를 따른다.
## M3: 무공 장착/수련 기록(martial_arts)과 무공 관리자(arts).
## M4: 스테이지 진행(stage) 보관, 불러온 데이터 적용, 중요 이벤트 때 저장 요청.
## M7: 캐릭터 레벨/경지(character)와 성장 관리자(growth).

## 저장 스키마 버전. 구조가 바뀔 때마다 올리고 SaveManager.migrations에 변환을 추가한다.
const SAVE_VERSION := 1

## 현재 게임 상태 (저장 데이터와 같은 모양의 Dictionary)
var data: Dictionary = {}
## 무공 장착/수련 기록 관리자. data["martial_arts"]를 직접 다룬다.
var arts: MartialArtManager
## 캐릭터 레벨/경지 관리자 (M7). data["character"]를 직접 다룬다.
var growth: CharacterGrowth


func _ready() -> void:
	reset_to_new_game()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").stage_cleared.connect(func(_r, _s): _request_save())


## 새 게임 상태로 초기화한다. 세부 필드는 이후 단계에서 추가한다.
## 시작 무공은 매화검법이다 (확정 사항 29, data/balance/training.json의 start_martial_art).
func reset_to_new_game() -> void:
	var reg := get_node("/root/DataRegistry")
	var start_art: String = reg.balance.get("training", {}).get("start_martial_art", "plum_blossom_sword")
	data = {
		"version": SAVE_VERSION,
		"martial_arts": MartialArtManager.new_state(start_art),
		"stage": new_stage_state(),
		"character": CharacterGrowth.new_state(),
	}
	_bind_arts()
	_bind_growth()
	arts.unlock(start_art)
	arts.refresh_training_target()


static func new_stage_state() -> Dictionary:
	return {"region": "", "stage_no": 1, "kill_count": 0, "highest_cleared": {}}


## 불러온 저장 데이터를 적용한다. 빠진 필드는 기본값으로 채운다 (docs/10 4장).
func apply_loaded(loaded: Dictionary) -> void:
	data = loaded
	var reg := get_node("/root/DataRegistry")
	if not (data.get("martial_arts") is Dictionary):
		var start_art: String = reg.balance.get("training", {}).get("start_martial_art", "plum_blossom_sword")
		data["martial_arts"] = MartialArtManager.new_state(start_art)
	if not (data.get("stage") is Dictionary):
		data["stage"] = new_stage_state()
	if not (data.get("character") is Dictionary):
		data["character"] = CharacterGrowth.new_state()
	# 저장 메타 정보는 상태에 남기지 않는다 (저장할 때 다시 쓴다)
	for key in ["save_seq", "saved_at_unix", "saved_at_monotonic_ms", "boot_session_id"]:
		data.erase(key)
	_bind_arts()
	_bind_growth()
	if arts.main_art() != "" and not arts.is_unlocked(arts.main_art()):
		arts.unlock(arts.main_art())
	arts.refresh_training_target()


## 저장 직전에 호출된다. 캐시 값을 최신으로 맞춘다.
func before_save() -> void:
	if arts:
		arts.refresh_training_target()


func _bind_arts() -> void:
	arts = MartialArtManager.new(data["martial_arts"], get_node("/root/DataRegistry"))
	# 중요 이벤트 직후 저장 (docs/10 2-2): 초식 대성, 무공 개방/교체
	arts.technique_mastered.connect(func(_id): _request_save())
	arts.equipment_changed.connect(_request_save)
	arts.art_unlocked.connect(func(_id): _request_save())
	arts.chain_mode_changed.connect(func(_on): _request_save())


func _bind_growth() -> void:
	growth = CharacterGrowth.new(data["character"], get_node("/root/DataRegistry").balance.get("growth", {}))
	# 경지 승급은 중요 이벤트로 바로 저장한다
	growth.realm_promoted.connect(func(_t): _request_save())


func _request_save() -> void:
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").request_save()
