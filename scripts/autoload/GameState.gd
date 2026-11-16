extends Node
## 런타임 게임 상태 보관소.
## 저장 데이터(SaveData) 구조는 docs/10-save-data.md를 따른다.
## M0에서는 뼈대만 두고, 실제 필드는 M3(무공/수련)와 M4(저장)에서 채운다.

## 저장 스키마 버전. 구조가 바뀔 때마다 올리고 마이그레이션을 추가한다.
const SAVE_VERSION := 1

## 현재 게임 상태 (저장 데이터와 같은 모양의 Dictionary)
var data: Dictionary = {}


func _ready() -> void:
	reset_to_new_game()


## 새 게임 상태로 초기화한다. 세부 필드는 이후 단계에서 추가한다.
func reset_to_new_game() -> void:
	data = {
		"version": SAVE_VERSION,
		"martial_arts": {
			"equipped": {"main": "", "sub": [null, null]},
			"chain_mode": false,
			"progress": {},
		},
	}
