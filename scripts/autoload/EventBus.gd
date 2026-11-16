extends Node
## 전역 시그널 허브.
## 전투, 수련, UI가 서로를 직접 참조하지 않고 이 시그널로 연결된다.
## M0에서는 데이터 로드 시그널만 쓰고, 나머지는 해당 단계에서 사용한다.

## 데이터 레지스트리가 JSON 로드를 마쳤을 때 (오류 수 포함)
signal data_loaded(error_count: int)

## 몬스터를 처치했을 때 (M1). rewards는 몬스터 데이터의 보상 정보
signal monster_killed(monster_id: String, rewards: Dictionary)

## 캐릭터가 쓰러졌을 때 (M1, 처리 방식은 미확정 O-06)
signal player_knocked_out()

## 초식이 정상 발동했을 때 (M3에서 사용)
signal technique_performed(martial_art_id: String, technique_id: String)

## 초식 수련 횟수가 바뀌었을 때 (M3에서 사용)
signal technique_progressed(technique_id: String, count: int)

## 초식이 대성했을 때 (M3에서 사용)
signal technique_mastered(technique_id: String)

## 저장이 끝났을 때 (M4에서 사용)
signal game_saved()

## 스테이지가 시작됨 (다음 스테이지로 넘어갔을 때)
signal stage_started(region_id: String, stage_no: int)

## 보스가 등장함
signal boss_appeared(region_id: String, stage_no: int)

## 보스를 처치해 스테이지를 돌파함
signal stage_cleared(region_id: String, stage_no: int)
