# 1차 모션·이펙트 시안 자르기

`master_atlas.png`(1536×1024, 1차 캐릭터/무공 이펙트 시안 통합본)에서 게임용 그림을 만든다.
시안은 반투명 배경 안개(알파 1~40)가 깔려 있고 칸마다 캐릭터 크기·위치가 달라, 아래 순서로 정리한다.

```
python3 extract.py master_atlas.png cut/          # 행(캐릭터) × 9칸 동작, 이펙트 조각 자르기
python3 build.py cut/ out/                         # 동작 9칸을 같은 몸 높이·같은 발 위치로 맞춘 <id>_motion.png
python3 fx.py master_atlas.png out/fx/             # 초식 12개 이펙트 그림
```

- 동작 칸: 0~1 대기, 2~4 걷기, 5 공격, 6~8 초식. 시트 한 칸 200×150, 발 기준점 (84, 142), 몸 높이 104px.
- 각 행의 캐릭터 순서는 HeroArt.CHARACTERS 순서와 같다.
- 개별 행 미리보기 PNG(01_character_motion_preview 등)는 아래쪽이 잘려 발끝이 없으므로 쓰지 않는다.
