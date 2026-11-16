extends Node
## 저장/불러오기 관리자.
## 이중 저장, 해시 검증, 내보내기/가져오기, 마이그레이션은 M4에서 구현한다.
## M0에서는 저장 위치 상수와 빈 인터페이스만 정의한다.

const SAVE_DIR := "user://save"
const SLOT_A := "save_a.json"
const SLOT_B := "save_b.json"


## 현재 GameState를 저장한다. (M4에서 구현)
func save_game() -> bool:
	push_warning("[SaveManager] save_game은 M4에서 구현 예정")
	return false


## 저장 데이터를 불러온다. (M4에서 구현)
func load_game() -> bool:
	push_warning("[SaveManager] load_game은 M4에서 구현 예정")
	return false
