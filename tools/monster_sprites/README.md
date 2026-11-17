# 몬스터 디자인 시안 자르기

`sheets/`의 시안 4장(AI 생성, 2752×1536)에서 스테이지별 몬스터·보스 도트 스프라이트를 만든다.

| 파일 | 내용 |
|---|---|
| `sheets/normal_a.png` | 일반 몬스터 1: 스테이지 1~10 (도적, 살수, 승려, 마교도, 빙궁무사/설인) |
| `sheets/normal_b.png` | 일반 몬스터 2: 스테이지 11~20 (마교제자, 검객, 늑대, 천마병, 무림고수/절대강자) |
| `sheets/boss_a.png` | 보스 1: 스테이지 1~10 (5×5 격자) |
| `sheets/boss_b.png` | 보스 2: 스테이지 11~20 |

```
pip install numpy pillow scipy "rembg[cpu]"
python3 tools/monster_sprites/build.py            # → assets/sprites/monsters/<id>.png, <id>_flash.png, monster_sprites.json
PREVIEW=/tmp/prev python3 tools/monster_sprites/build.py   # 발 기준점을 맞춰 늘어놓은 확인용 그림도 만든다
```

- `spec.py`: 스프라이트마다 동작별 프레임 상자(시트 좌표). 시안 한 행에 다른 인물이 섞여 있어 같은 인물로 보이는 칸만 골랐다.
- `matte.py`: 배경 제거. 시안의 체크무늬는 그림에 박혀 있는(불투명) 가짜 투명 배경이라, 체크 두 색으로 배경판을 다시 그려 비교하고
  rembg(isnet-general-use) 마스크로 머리카락처럼 배경과 색이 같은 부분을 살린다.
- `anchors.py`: 자동 발 기준점이 이펙트 쪽으로 끌려가는 프레임의 보정값.
- 시안 오른쪽 아래 생성 도구 로고(반투명 ✦)는 `build.py`의 `WATERMARK`로 걷어 낸다.
- 시안은 모두 오른쪽을 보고 있어 자를 때 좌우 반전한다(게임에서는 몬스터가 오른쪽에서 나와 왼쪽 주인공을 본다).

한계: 어두운 그림자 짐승(마령), 연기처럼 흩어지는 쓰러짐 칸, 체크무늬와 색이 같은 검은 머리카락은 깔끔하게 분리되지 않는다.
그런 칸은 빼고, 게임에서 대신 처리한다(쓰러짐 칸이 없으면 피격 칸이 뒤로 넘어가며 사라짐, 걷기 칸이 없으면 대기 칸이 통통 튐).
