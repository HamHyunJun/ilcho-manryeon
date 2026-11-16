extends Node
## 런타임 게임 상태 보관소.
## 저장 데이터(SaveData) 구조는 docs/10-save-data.md를 따른다.
## M3: 무공 장착/수련 기록(martial_arts)과 무공 관리자(arts). 저장/불러오기는 M4에서 붙인다.

## 저장 스키마 버전. 구조가 바뀔 때마다 올리고 마이그레이션을 추가한다.
const SAVE_VERSION := 1

## 현재 게임 상태 (저장 데이터와 같은 모양의 Dictionary)
var data: Dictionary = {}
## 무공 장착/수련 기록 관리자. data["martial_arts"]를 직접 다룬다.
var arts: MartialArtManager


func _ready() -> void:
	reset_to_new_game()


## 새 게임 상태로 초기화한다. 세부 필드는 이후 단계에서 추가한다.
## 시작 무공은 매화검법이다 (확정 사항 29, data/balance/training.json의 start_martial_art).
func reset_to_new_game() -> void:
	var reg := get_node("/root/DataRegistry")
	var start_art: String = reg.balance.get("training", {}).get("start_martial_art", "plum_blossom_sword")
	data = {
		"version": SAVE_VERSION,
		"martial_arts": MartialArtManager.new_state(start_art),
	}
	arts = MartialArtManager.new(data["martial_arts"], reg)
	arts.unlock(start_art)
	arts.refresh_training_target()
