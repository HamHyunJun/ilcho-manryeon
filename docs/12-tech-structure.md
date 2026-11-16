# 12. 개발 기술 및 프로젝트 구조

## 1. 기술 방향 [확정]

1. **Godot 4** (GDScript 기준 [가안]), Android 세로형 화면 기준.
2. 로컬 싱글 플레이, 서버와 계정 시스템 없음.
3. 데이터 중심 구조: 무공, 초식, 몬스터, 장비, 아이템은 코드에 하드코딩하지 않는다.
4. **하이브리드 데이터**: 수치/구조는 **JSON**, 이펙트/씬 연결은 **Godot Resource**(.tres).
5. 저장 데이터는 **JSON**(버전 필드, 마이그레이션).
6. 수련 단계 이펙트는 **파티클/셰이더 파라미터화**.
7. 캐릭터/몬스터 스프라이트는 임시 에셋으로 시작해 점진 교체. (사운드/BGM 제작 방식은 [미확정] O-01)
8. 콘텐츠가 늘어도 기존 구조를 크게 바꾸지 않게 설계하고, 모바일 성능과 실제 Android 빌드/Google Play 출시를 고려한다.

> [미확정] Godot 4의 세부 버전(4.x)과 GDScript / C# 선택. 바이브 코딩과 Android 빌드 편의를 고려하면 GDScript를 [가안]으로 둔다. → O-39

## 2. Godot 폴더 구조 [가안]

원문의 "예상 프로젝트 구조"를 Godot 프로젝트 관례에 맞게 정리했다. 각 매니저는 원문 이름을 유지한다.

```
ilcho-manryeon/
├── project.godot
├── docs/                          # 기획 문서 (이 문서들)
├── data/                          # 수치/구조 데이터 (JSON)
│   ├── martial_arts/              # 무공 1개 = 파일 1개 (초식 포함)
│   │   ├── plum_blossom_sword.json
│   │   ├── arhat_fist.json
│   │   └── yin_yang_five_elements.json
│   ├── monsters/
│   │   └── monsters.json
│   ├── stages/
│   │   └── cheongpung_mountain.json
│   ├── dungeons/
│   │   └── dungeons.json
│   ├── equipment/
│   │   ├── equipment_defs.json
│   │   ├── options.json
│   │   └── sets.json
│   ├── summons/
│   │   └── summons.json
│   ├── items/
│   │   └── items.json             # 비급 조각, 소환 조각 등
│   ├── realms/
│   │   └── realms.json            # 경지 9단계와 승급 조건
│   ├── missions/
│   │   ├── daily.json
│   │   └── achievements.json
│   ├── balance/
│   │   ├── combat.json            # 전투 공통 수치
│   │   ├── training.json          # 수련 배율, 단계 경계, 오프라인 효율/상한
│   │   └── economy.json
│   └── shop/
│       └── products.json          # 결제 상품 정의 (MVP는 비활성)
├── resources/                     # Godot Resource (.tres)
│   ├── effects/
│   │   ├── presets/               # 계열 × 7단계 이펙트 파라미터
│   │   │   ├── sword_stage_1.tres … sword_stage_7.tres
│   │   │   ├── fist_stage_1.tres  … fist_stage_7.tres
│   │   │   └── spell_stage_1.tres … spell_stage_7.tres
│   │   └── unique/                # 초식 전용 대성 연출
│   └── shaders/
├── scenes/
│   ├── main/                      # Main.tscn (진입, 화면 전환)
│   ├── battle/                    # 전투 화면, 캐릭터, 몬스터, 투사체
│   ├── effects/                   # 이펙트 씬 (파티클 노드 묶음)
│   └── ui/                        # HUD, SkillBar, 메뉴 화면들
├── scripts/
│   ├── autoload/                  # 전역 싱글턴
│   │   ├── DataRegistry.gd        # JSON 로드, ID로 조회, 검증
│   │   ├── SaveManager.gd         # 이중 저장, 내보내기/가져오기, 마이그레이션
│   │   ├── GameState.gd           # 런타임 상태 (SaveData 보관)
│   │   ├── EventBus.gd            # 전역 시그널
│   │   └── TimeService.gd         # 기기 시간/단조 시간, 일일 초기화
│   ├── battle/
│   │   ├── BattleManager.gd
│   │   ├── CombatController.gd
│   │   ├── AutoAttackController.gd
│   │   ├── TechniqueModeController.gd # 단일 수련 / 연속초식 전환
│   │   ├── TargetSelector.gd
│   │   ├── DamageCalculator.gd
│   │   └── BattleRewardManager.gd
│   ├── player/
│   │   ├── PlayerCharacter.gd
│   │   ├── PlayerStats.gd
│   │   ├── SkillManager.gd
│   │   ├── EquipmentManager.gd
│   │   └── InternalEnergyManager.gd
│   ├── martial_arts/
│   │   ├── MartialArtManager.gd   # 장착, 해금, 수련 횟수 반영
│   │   ├── MartialArtData.gd      # 무공 정적 데이터 래퍼
│   │   ├── TechniqueData.gd       # 초식 정적 데이터 래퍼
│   │   ├── TechniqueProgress.gd   # 초식 진행도 (count, fraction, mastered)
│   │   ├── MartialArtCollection.gd# 도감, 비급 조각
│   │   └── TrainingCalculator.gd  # 수련 배율, 단계 계산, 오프라인 수련 계산
│   ├── monsters/
│   │   ├── MonsterSpawner.gd
│   │   ├── MonsterManager.gd
│   │   ├── MonsterAI.gd
│   │   └── BossController.gd
│   ├── stage/
│   │   ├── StageManager.gd
│   │   ├── SpawnPattern.gd
│   │   └── BossWave.gd
│   ├── effects/
│   │   └── EffectDirector.gd      # (계열, 단계) → 이펙트 프리셋 선택/재생
│   ├── save/
│   │   ├── SaveData.gd
│   │   └── migrations/            # migrate_v1_to_v2.gd …
│   └── ui/
│       ├── BattleHUD.gd
│       ├── SkillBar.gd
│       ├── StageProgress.gd
│       ├── EquipmentUI.gd
│       ├── SummonUI.gd
│       ├── DungeonUI.gd
│       └── GrowthUI.gd
├── assets/
│   ├── sprites/                   # 임시 에셋 → 점진 교체
│   ├── fonts/
│   └── audio/
└── tests/                         # 수련/저장/마이그레이션 단위 테스트
```

원문 구조 대비 추가한 것과 이유:

| 추가 | 이유 |
|---|---|
| `DataRegistry` | JSON 데이터를 한곳에서 읽고 검증해, 데이터 오류를 시작 시점에 잡기 위함 |
| `EventBus` | 전투, 수련, UI가 서로 직접 참조하지 않고 시그널로 연결 (예: 초식 정상 발동 → 수련 반영 → UI 갱신) |
| `TimeService` | 오프라인 보상과 일일 초기화의 시간 판정을 한곳에 모음 |
| `TrainingCalculator` | 수련 규칙(배율, 단계, 오프라인)을 순수 계산 함수로 분리해 테스트하기 쉽게 함 |
| `EffectDirector` | 계열 × 단계 이펙트 선택을 한곳에서 처리 |
| `tests/` | 수련 기록 보존과 저장/마이그레이션은 핵심 자산이므로 자동 테스트 대상 |

## 3. 핵심 흐름: 초식 발동 → 수련 반영 [가안]

```
AutoAttackController + TechniqueModeController
   └ 초식 발동 요청 (단일 수련: 수련 중인 초식 / 연속초식: 1초식부터 해금 초식 순서)
SkillManager
   └ 재사용 대기, 내공 확인 → 실패 시 종료 (수련 없음)
CombatController
   └ TargetSelector로 대상 확인 → 대상 없으면 취소 (수련 없음)
   └ 정상 발동 → DamageCalculator → 피해 적용
   └ EventBus.technique_performed(martial_art_id, technique_id)
MartialArtManager
   └ 주력 무공 초식만 처리 (보조 무공은 패시브만)
   └ 배율 = 기본 1.0 × 가속 배율
   └ TechniqueProgress.add(배율) → 대성 도달 시 다음 초식 해금
   └ EventBus.technique_progressed / technique_mastered
EffectDirector
   └ (계열, 현재 단계)로 이펙트 재생
```

## 4. 데이터 파일 구조 예시 [가안]

### 4-1. 무공 + 초식 (`data/martial_arts/plum_blossom_sword.json`)

```json
{
  "id": "plum_blossom_sword",
  "name": "매화검법",
  "category": "sword",
  "sect": "hwasan",
  "alignment": "orthodox",
  "description": "화산파의 검법. 빠른 연속 공격과 치명타, 검기가 특징이다.",
  "acquire": { "type": "fragments", "fragment_item": "frag_plum_blossom_sword", "required": 0 },
  "sources": ["manual_dungeon", "stage_boss"],
  "passive_as_sub": [ { "stat": "crit_rate", "value": 0.0 } ],
  "techniques": [
    {
      "id": "plum_blossom_sword.t1",
      "name": "매화낙엽",
      "order": 1,
      "mastery_target": 10000,
      "trainable": true,
      "power_coef": 1.2,
      "range": 0.25,
      "max_targets": 1,
      "mp_cost": 5,
      "cooldown": 1.5,
      "element": "none",
      "status_effects": [],
      "special": [],
      "animation": "sword_slash_01",
      "effect_override": null
    }
  ]
}
```

- `acquire.required`와 수치들은 테스트용 자리 값이다. 실제 값은 밸런스 단계에서 정한다.
- 초식 이름(예: 매화낙엽)은 예시이며, 무공별 초식 이름과 구성은 콘텐츠 작업에서 정한다. → [미확정] O-11

### 4-2. 수련 공통 수치 (`data/balance/training.json`)

```json
{
  "default_mastery_target": 10000,
  "stage_thresholds": [
    { "stage": 1, "name": "입문", "min": 0 },
    { "stage": 2, "name": "초급", "min": 100 },
    { "stage": 3, "name": "중급", "min": 1000 },
    { "stage": 4, "name": "고급", "min": 3000 },
    { "stage": 5, "name": "숙련", "min": 5000 },
    { "stage": 6, "name": "절정", "min": 7500 },
    { "stage": 7, "name": "대성", "min": 10000 }
  ],
  "base_multiplier": 1.0,
  "offline": { "efficiency": 0.5, "max_hours": 8 }
}
```

### 4-3. 몬스터 (`data/monsters/monsters.json`)

```json
[
  {
    "id": "cp_bandit",
    "name": "산적",
    "type": "melee",
    "hp": 100, "atk": 10, "def": 5,
    "move_speed": 60, "attack_range": 40, "attack_interval": 1.5,
    "sprite": "res://assets/sprites/monsters/bandit.png",
    "rewards": { "exp": 5, "silver": 3 }
  },
  {
    "id": "cp_boss_tiger",
    "name": "청풍산 호랑이",
    "type": "boss",
    "hp": 4000, "atk": 30, "def": 15,
    "patterns": [
      { "id": "pounce", "telegraph_sec": 1.0, "power_coef": 2.0 },
      { "id": "roar", "telegraph_sec": 1.5, "status": "stun" }
    ]
  }
]
```

### 4-4. 스테이지 (`data/stages/cheongpung_mountain.json`)

```json
{
  "region_id": "cheongpung_mountain",
  "name": "청풍산",
  "stages": [
    {
      "stage_no": 1,
      "kills_to_boss": 50,
      "spawn_pool": [ { "monster": "cp_bandit", "weight": 70 }, { "monster": "cp_wolf", "weight": 30 } ],
      "scaling": 1.0,
      "boss": "cp_boss_tiger"
    }
  ]
}
```

### 4-5. 이펙트 프리셋 (Resource, 개념)

```
EffectPreset (Resource)
  category: "sword"
  stage: 4
  particle_amount: 48
  scale: 1.6
  color_primary: #ffd0e0
  afterimage: true
  shockwave_radius: 120
  screen_shake: 0.2
  scene: res://scenes/effects/sword_effect.tscn
```

초식 데이터(JSON)는 계열과 단계만 알면 되고, 실제 이펙트는 `EffectDirector`가 `resources/effects/presets/{category}_stage_{n}.tres`를 찾아 재생한다. 대성 전용 연출은 `effect_override`에 Resource 경로를 적는다.

## 5. 성능 고려 [가안]

- 몬스터, 투사체, 피해 숫자, 파티클은 **오브젝트 풀**로 재사용한다.
- 파티클은 모바일 렌더러(Compatibility 또는 Mobile)에서 테스트하고, 동시 이펙트 수 상한을 둔다.
- 수련 횟수는 메모리에서 누적하고 저장은 주기/이벤트 단위로 한다.
- JSON은 시작 시 한 번 읽어 메모리에 캐시한다.

## 6. 빌드와 출시 준비 [가안]

- Android 내보내기 템플릿, 세로 고정, 최소 SDK 버전 설정.
- Google Play 출시용 AAB 빌드, 서명 키 관리.
- 광고/결제 SDK는 MVP 이후 플러그인으로 추가하고, 그 전까지는 인터페이스(빈 구현)만 둔다.

> [미확정] 지원할 최소 Android 버전과 목표 기기 사양. → O-40
