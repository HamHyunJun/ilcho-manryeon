# 10. 저장 데이터 구조

## 1. 저장 원칙 [확정]

- **로컬 저장**만 사용한다. 서버와 계정은 없다.
- 저장 포맷은 **JSON**이며 최상위에 **버전 필드**를 두고 마이그레이션을 고려한다.
- **무공별, 초식별 진행도를 영구 보존**한다. 무공을 바꿔도 진행도는 초기화되지 않는다.
- **이중 저장**: 저장 파일 2개를 번갈아 쓰고, 불러올 때 유효한 최신 파일을 고른다.
- **수동 내보내기/가져오기**로 기기 이전을 지원한다.
- 출시 전 Google Play 게임 서비스 클라우드 저장 추가 여부를 다시 검토한다. 버전 필드가 있는 JSON 구조이므로 나중에 붙이기 쉽다.

## 2. 파일 구성 [가안]

| 파일 | 위치 | 용도 |
|---|---|---|
| `save_a.json` | `user://save/` | 이중 저장 슬롯 A |
| `save_b.json` | `user://save/` | 이중 저장 슬롯 B |
| `settings.json` | `user://` | 설정(사운드, 진동 등). 게임 진행과 분리 |

### 2-1. 이중 저장 절차 [가안]

1. 저장할 때마다 `save_seq`(저장 순번)를 1 올린다.
2. 지난번에 쓰지 않은 슬롯에 임시 파일(`*.tmp`)로 쓴 뒤, 쓰기가 끝나면 이름을 바꿔 교체한다.
3. 본문 해시(`checksum`)를 함께 기록한다.
4. 불러올 때 두 슬롯을 모두 읽고, 해시가 맞는 것 중 `save_seq`가 큰 쪽을 쓴다. 둘 다 깨졌으면 사용자에게 알리고 가져오기를 안내한다.

### 2-2. 저장 시점 [가안]

- 초식 대성, 무공 개방/교체, 장비 변경, 재화 소비 같은 중요 이벤트 직후
- 일정 주기(예: 30초)
- 앱이 백그라운드로 갈 때 (Android 일시 정지 알림)

> **M4 구현 메모** [가안]
> - 파일 형식: `{"format": 1, "checksum": "sha256:…", "payload": "<본문 JSON 문자열>"}`. 본문을 문자열로 담아 쓴 그대로 해시를 검증한다(숫자를 다시 직렬화하면 표기가 달라질 수 있어서). 본문 안의 필드 구조는 3장과 같다.
> - 주기 저장 30초(`SaveManager.autosave_interval`). 이벤트 저장: 초식 대성, 무공 개방, 장착 변경, 스테이지 돌파. 앱 전환: Android 일시 정지, 포커스 잃음, 종료/뒤로 가기 요청.
> - 불러온 스테이지는 처치 수까지 복원한다. 보스 조건(50마리)을 채운 상태였으면 보스 등장부터 다시 한다. 체력은 가득 찬 상태로 시작한다(O-51).
> - 두 슬롯이 모두 깨졌으면 새 게임으로 시작하고 화면 아래에 안내를 띄운다. 깨진 파일은 다음 저장 때 덮어쓴다. 가져오기 안내는 내보내기/가져오기 기능(O-38)과 함께 만든다.

수련 횟수는 매 발동마다 디스크에 쓰지 않고 메모리에서 누적한 뒤 위 시점에 저장한다. 앱이 강제 종료되면 마지막 저장 이후의 수련분은 잃을 수 있으며, 저장 주기로 손실 폭을 제한한다.

### 2-3. 내보내기 / 가져오기 [확정: 기능 / 가안: 방식]

- 내보내기: 현재 저장 데이터를 파일로 저장하거나 공유(Android 공유 기능)한다. 붙여 넣기용 텍스트 코드(압축 + Base64) 방식도 후보다.
- 가져오기: 파일 또는 코드를 불러와 버전 확인 → 마이그레이션 → 해시 검증 → 덮어쓰기 확인 순서로 적용한다.
- 덮어쓰기 전에 현재 데이터를 백업 슬롯에 남긴다.

> [미확정] 내보내기 형식(파일 / 텍스트 코드 / 둘 다)과 저장 데이터 조작 방지 수준(해시만 / 암호화). 서버가 없는 싱글 게임이라 조작 방지는 "실수로 깨진 파일을 걸러 내는 수준"이 현실적이다. → O-38

## 3. 저장 데이터 스키마 예시 (JSON)

아래는 구조 설명용 예시다. 키 이름과 세부 필드는 구현 단계에서 다듬을 수 있지만, **무공 ID → 초식 ID → 진행도** 구조와 장착 정보 분리 원칙은 유지한다.

```json
{
  "version": 1,
  "save_seq": 1284,
  "saved_at_unix": 1794813600,
  "saved_at_monotonic_ms": 86400123,
  "boot_session_id": "b7f2c1",
  "checksum": "sha256:...",

  "player": {
    "level": 23,
    "exp": 4820,
    "realm": "first_rate",
    "hp_current": 1820,
    "stats_bonus": {}
  },

  "currencies": {
    "silver": 125400,
    "elixir": 38,
    "summon_token": 5,
    "enhance_stone": 210,
    "gold_ingot": 0
  },

  "inventory": {
    "manual_fragments": {
      "plum_blossom_sword": 0,
      "arhat_fist": 12,
      "yin_yang_five_elements": 3
    },
    "summon_fragments": {}
  },

  "martial_arts": {
    "equipped": {
      "main": "plum_blossom_sword",
      "sub": ["arhat_fist", null]
    },
    "auto_technique_enabled": true,
    "chain_mode": false,
    "training_target": "plum_blossom_sword.t4",

    "progress": {
      "plum_blossom_sword": {
        "unlocked": true,
        "unlocked_at_unix": 1794000000,
        "techniques": {
          "plum_blossom_sword.t1": { "unlocked": true,  "count": 10000, "fraction": 0.0, "mastered": true,  "mastered_at_unix": 1794100000 },
          "plum_blossom_sword.t2": { "unlocked": true,  "count": 10000, "fraction": 0.0, "mastered": true,  "mastered_at_unix": 1794300000 },
          "plum_blossom_sword.t3": { "unlocked": true,  "count": 10000, "fraction": 0.0, "mastered": true,  "mastered_at_unix": 1794600000 },
          "plum_blossom_sword.t4": { "unlocked": true,  "count": 8214,  "fraction": 0.0, "mastered": false, "mastered_at_unix": null }
        }
      },
      "arhat_fist": {
        "unlocked": true,
        "unlocked_at_unix": 1794700000,
        "techniques": {
          "arhat_fist.t1": { "unlocked": true,  "count": 1532, "fraction": 0.0, "mastered": false, "mastered_at_unix": null },
          "arhat_fist.t2": { "unlocked": false, "count": 0,    "fraction": 0.0, "mastered": false, "mastered_at_unix": null }
        }
      }
    }
  },

  "equipment": {
    "equipped": {
      "weapon": "eq_000123",
      "helmet": null,
      "armor": "eq_000087",
      "boots": null,
      "accessory": null
    },
    "items": {
      "eq_000123": {
        "def_id": "cheongpung_sword_rare",
        "grade": "rare",
        "enhance": 7,
        "options": [
          { "id": "dmg_martial_art", "target": "plum_blossom_sword", "value": 0.08 },
          { "id": "crit_rate", "value": 0.03 }
        ],
        "locked": false
      }
    },
    "next_uid": 124
  },

  "summons": {
    "owned": {},
    "equipped": { "companion": [], "spirit_beast": [], "guardian": [] },
    "pity_counters": {}
  },

  "stage": {
    "region": "cheongpung_mountain",
    "stage_no": 12,
    "kill_count": 37,
    "highest_cleared": { "cheongpung_mountain": 11 }
  },

  "dungeons": {
    "manual_dungeon": { "highest_cleared": 3, "entries_today": 1, "pity_counter": 4 }
  },

  "missions": {
    "daily_reset_at_unix": 1794870000,
    "daily": { "kill_monsters_100": { "progress": 64, "claimed": false } },
    "achievements": { "first_mastery": { "claimed": true } }
  },

  "tutorial": { "auto_battle": true, "manual_button": true, "equip_martial_art": false, "first_training": false },

  "offline": {
    "last_active_unix": 1794813600,
    "last_active_monotonic_ms": 86400123
  },

  "stats": {
    "total_kills": 59321,
    "total_technique_casts": 48120
  }
}
```

### 3-1. 필드 설명 (핵심)

| 필드 | 설명 |
|---|---|
| `version` | 저장 스키마 버전. 구조가 바뀔 때마다 올린다 |
| `martial_arts.equipped` | 현재 장착 정보. **진행도와 분리**되어 있어 교체해도 진행도에 영향 없음 |
| `martial_arts.progress` | **무공 ID → 초식 ID → 진행도**. 한 번 생긴 기록은 삭제하지 않는다 |
| `count` | 정수 수련 횟수 |
| `fraction` | 수련 배율(가속 효과 등)이 소수일 때 생기는 누적값. 1.0 이상이 되면 `count`로 넘긴다 |
| `martial_arts.equipped.sub` | 보조 무공. 패시브만 제공하며, 보조로 장착해도 그 무공의 `progress`는 바뀌지 않는다 |
| `chain_mode` | 연속초식 토글 켜짐 여부. 오프라인 계산에는 쓰지 않는다(항상 단일 수련 기준) |
| `training_target` | 수련 중인 초식 ID. 아직 대성하지 못한 가장 앞 초식으로 자동 지정되며, 진행도에서 다시 계산할 수 있는 캐시 값이다 |
| `mastered` | 대성 여부. `count`가 대성 목표(기본 10,000)에 도달하면 true |
| `saved_at_monotonic_ms`, `boot_session_id` | 오프라인 보상 시계 조작 완화용 |
| `pity_counter` / `pity_counters` | 천장 계산용 누적값 (수치는 미정) |

- 수련 단계(입문~대성)는 `count`에서 계산하므로 따로 저장하지 않는다.
- 데이터 파일(JSON)에서 무공이나 초식이 삭제/이름 변경되어도 저장 기록은 남겨 두고, 매핑 테이블로 옮긴다(마이그레이션).

## 4. 마이그레이션 [가안]

```
불러오기 → version 확인
  version < 현재 → migrate_v1_to_v2(), migrate_v2_to_v3() … 순서대로 적용
  version > 현재 → 앱이 더 오래된 경우. 불러오지 않고 업데이트 안내
  version == 현재 → 그대로 사용
마이그레이션 성공 → 새 버전으로 즉시 저장 (기존 파일은 백업으로 보관)
```

- 마이그레이션 함수는 버전별로 하나씩 쌓아 두고 삭제하지 않는다.
- 누락된 필드는 기본값으로 채운다(새 콘텐츠 추가 시 저장 구조를 크게 바꾸지 않기 위함).

## 5. 오프라인 시간 판정 [확정: 단조 시간 활용 / 가안: 세부]

1. 저장 시 `saved_at_unix`(기기 시간), `saved_at_monotonic_ms`(부팅 후 경과 시간), `boot_session_id`를 함께 기록한다.
2. 복귀 시 같은 부팅 세션이면 단조 시간 차이로 경과 시간을 계산한다(기기 시간 조작 영향 없음).
3. 재부팅 등으로 세션이 바뀌었으면 기기 시간 차이를 쓰되, 음수이면 0으로, 최대 인정 시간(8시간)으로 상한을 둔다.
4. 기기 시간이 저장 시점보다 과거로 돌아간 기록이 있으면, 다음 정상 경과 전까지 오프라인 보상을 주지 않는다.
