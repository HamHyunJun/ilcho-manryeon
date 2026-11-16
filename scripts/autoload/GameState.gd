extends Node
## 런타임 게임 상태 보관소.
## 저장 데이터(SaveData) 구조는 docs/10-save-data.md를 따른다.
## M3: 무공 장착/수련 기록(martial_arts)과 무공 관리자(arts).
## M4: 스테이지 진행(stage) 보관, 불러온 데이터 적용, 중요 이벤트 때 저장 요청.
## M7: 캐릭터 레벨/경지(character)와 성장 관리자(growth).
## M8: 장비(equipment)와 재화(currencies), 장비 관리자(equipment).
## M9: 비급 조각과 던전 기록(collection).

## 저장 스키마 버전. 구조가 바뀔 때마다 올리고 SaveManager.migrations에 변환을 추가한다.
const SAVE_VERSION := 1

## 현재 게임 상태 (저장 데이터와 같은 모양의 Dictionary)
var data: Dictionary = {}
## 무공 장착/수련 기록 관리자. data["martial_arts"]를 직접 다룬다.
var arts: MartialArtManager
## 캐릭터 레벨/경지 관리자 (M7). data["character"]를 직접 다룬다.
var growth: CharacterGrowth
## 장비와 재화 관리자 (M8). data["equipment"], data["currencies"]를 직접 다룬다.
var equipment: EquipmentManager
## 비급 조각과 던전 기록 (M9). data["collection"]을 직접 다룬다.
var collection: ManualCollection
## 마지막 오프라인 수련 결과 (복귀 요약 화면이 보여 주고 비운다, M10)
var offline_summary: Dictionary = {}
## 복귀 요약이 생기면 알린다
signal offline_summary_ready(summary: Dictionary)


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
		"equipment": EquipmentManager.new_state(),
		"currencies": EquipmentManager.new_currencies(),
		"collection": ManualCollection.new_state(),
		"offline": {"rollback_until_unix": 0},
	}
	_bind_arts()
	_bind_growth()
	_bind_equipment()
	_bind_collection()
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
	if not (data.get("equipment") is Dictionary):
		data["equipment"] = EquipmentManager.new_state()
	if not (data.get("currencies") is Dictionary):
		data["currencies"] = EquipmentManager.new_currencies()
	if not (data.get("collection") is Dictionary):
		data["collection"] = ManualCollection.new_state()
	if not (data.get("offline") is Dictionary):
		data["offline"] = {"rollback_until_unix": 0}
	# 저장 메타 정보는 상태에 남기지 않는다 (저장할 때 다시 쓴다)
	for key in ["save_seq", "saved_at_unix", "saved_at_monotonic_ms", "boot_session_id"]:
		data.erase(key)
	_bind_arts()
	_bind_growth()
	_bind_equipment()
	_bind_collection()
	if arts.main_art() != "" and not arts.is_unlocked(arts.main_art()):
		arts.unlock(arts.main_art())
	arts.refresh_training_target()


## 오프라인 수련을 계산해 적용한다 (M10). saved_meta: 마지막 저장(또는 백그라운드 전환) 시각 {unix, mono_ms, session}
## now를 주지 않으면 TimeService의 현재 시각을 쓴다. 반환값: 요약 (보상이 없으면 빈 Dictionary)
func apply_offline(saved_meta: Dictionary, now: Dictionary = {}) -> Dictionary:
	var reg := get_node("/root/DataRegistry")
	var ocfg: Dictionary = reg.balance.get("training", {}).get("offline", {})
	if now.is_empty() and has_node("/root/TimeService"):
		now = get_node("/root/TimeService").snapshot()
	var off: Dictionary = data["offline"]
	var max_sec := float(ocfg.get("max_hours", 8)) * 3600.0
	var el := OfflineTraining.elapsed(saved_meta, now, max_sec, int(off.get("rollback_until_unix", 0)))
	off["rollback_until_unix"] = int(el["rollback_until"])
	offline_summary = {}
	if el["rollback"]:
		offline_summary = {"rollback": true, "seconds": 0.0}
		offline_summary_ready.emit(offline_summary)
		_request_save()
		return offline_summary
	if float(el["seconds"]) < float(ocfg.get("min_seconds", 60)):
		return {}
	var pb: Dictionary = reg.balance.get("combat", {}).get("player_base", {})
	var cfg := {
		"efficiency": float(ocfg.get("efficiency", 0.5)),
		"multiplier": float(reg.balance.get("training", {}).get("base_multiplier", 1.0)),
		"technique_interval": float(pb.get("technique_interval", 1.0)),
		"mp_regen": float(pb.get("mp_regen", 5.0)),
	}
	var res := OfflineTraining.apply(arts, float(el["seconds"]), cfg)
	res["raw_seconds"] = el["raw_seconds"]
	res["capped"] = el["capped"]
	res["method"] = el["method"]
	res["efficiency"] = cfg["efficiency"]
	res["max_hours"] = float(ocfg.get("max_hours", 8))
	offline_summary = res
	offline_summary_ready.emit(res)
	_request_save()
	return res


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


func _bind_equipment() -> void:
	equipment = EquipmentManager.new(data["equipment"], data["currencies"], get_node("/root/DataRegistry").equipment)
	# 장착 변경과 강화는 중요 이벤트로 저장한다
	equipment.equipment_changed.connect(_request_save)
	equipment.inventory_changed.connect(_request_save)


func _bind_collection() -> void:
	collection = ManualCollection.new(data["collection"], arts, equipment)
	collection.fragments_changed.connect(func(_a, _n): _request_save())


func _request_save() -> void:
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").request_save()
