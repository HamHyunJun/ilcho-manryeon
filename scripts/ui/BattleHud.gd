extends Node2D
## 전투 상단 HUD (M2).
## 지역명 · 스테이지 번호, 처치 진행도(예: 37 / 50), 보스까지 남은 몬스터 수, 캐릭터 체력,
## 보스전에서는 보스 체력 바를 표시한다 (docs/09 2-1).
## M3에서 내공 바와 발동한 초식 이름, M7에서 경지·레벨·전투력·경험치 바를 추가했다. 재화는 M8.
## 임시 UI: 폰트와 색은 정식 UI 작업 때 바꾼다.

## 표시할 BattleManager
var battle: Node2D

const LEFT := 32.0
const WIDTH := 656.0
const TOP := 200.0


func _draw() -> void:
	if battle == null or battle.stage == null:
		return
	var font := ThemeDB.fallback_font
	var stage: StageManager = battle.stage
	var player = battle.player

	# 1줄: 지역명 · 스테이지
	draw_string(font, Vector2(LEFT, TOP), "%s · 스테이지 %d" % [stage.region_name(), stage.stage_no],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.9, 0.75))
	if battle.equipment != null:
		draw_string(font, Vector2(LEFT, TOP), "은냥 %s" % MenuPanel.fmt(battle.equipment.silver()),
			HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 22, Color(0.95, 0.85, 0.5))

	# 2줄: 처치 진행도 또는 보스 체력
	var bar := Rect2(Vector2(LEFT, TOP + 44), Vector2(WIDTH, 16))
	draw_rect(bar, Color(0.15, 0.15, 0.15))
	var boss = battle.boss
	if stage.phase == StageManager.Phase.BOSS and is_instance_valid(boss):
		var r := float(boss.hp) / float(boss.max_hp)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * r, bar.size.y)), Color(0.85, 0.25, 0.2))
		draw_string(font, Vector2(LEFT, TOP + 36), "보스 %s" % boss.data.get("name", ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.6, 0.55))
		draw_string(font, Vector2(LEFT, TOP + 36), "%d / %d" % [boss.hp, boss.max_hp],
			HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 20)
	else:
		var need := stage.kills_to_boss()
		var r2 := float(mini(stage.kill_count, need)) / float(maxi(need, 1))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * r2, bar.size.y)), Color(0.9, 0.7, 0.3))
		draw_string(font, Vector2(LEFT, TOP + 36), "처치 %d / %d" % [stage.kill_count, need],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var right_text := "보스까지 %d마리" % stage.remaining_to_boss()
		if stage.phase == StageManager.Phase.BOSS_INTRO:
			right_text = "보스 등장!"
		elif stage.phase == StageManager.Phase.CLEARED:
			right_text = "돌파!"
		draw_string(font, Vector2(LEFT, TOP + 36), right_text, HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 20)

	# 3줄: 캐릭터 체력
	var hp_bar := Rect2(Vector2(LEFT, TOP + 100), Vector2(WIDTH, 14))
	draw_rect(hp_bar, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * float(player.hp) / float(player.max_hp), hp_bar.size.y)),
		Color(0.3, 0.8, 0.4))
	draw_string(font, Vector2(LEFT, TOP + 92), "체력 %d / %d" % [player.hp, player.max_hp],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

	# 4줄: 내공
	var mp_bar := Rect2(Vector2(LEFT, TOP + 120), Vector2(WIDTH, 8))
	draw_rect(mp_bar, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(mp_bar.position, Vector2(mp_bar.size.x * player.mp / maxf(player.max_mp, 1.0), mp_bar.size.y)),
		Color(0.35, 0.55, 1.0))
	draw_string(font, Vector2(LEFT, TOP + 92), "내공 %d / %d" % [int(player.mp), int(player.max_mp)],
		HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 20, Color(0.7, 0.8, 1.0))

	# 5줄: 경지 · 레벨 · 전투력과 경험치 (M7)
	var growth = battle.growth
	if growth != null:
		draw_string(font, Vector2(LEFT, TOP + 160), "%s · Lv %d" % [growth.realm().get("name", ""), growth.level()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.55))
		draw_string(font, Vector2(LEFT, TOP + 160), "전투력 %s" % MenuPanel.fmt(battle.combat_power()),
			HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 22, Color(1.0, 0.95, 0.8))
		var exp_bar := Rect2(Vector2(LEFT, TOP + 170), Vector2(WIDTH, 6))
		draw_rect(exp_bar, Color(0.15, 0.15, 0.15))
		var er := 1.0 if growth.level() >= growth.level_cap() else float(growth.current_exp()) / float(maxi(growth.exp_to_next(), 1))
		draw_rect(Rect2(exp_bar.position, Vector2(exp_bar.size.x * er, exp_bar.size.y)), Color(0.75, 0.6, 1.0))

	# 캐릭터 머리 위: 방금 발동한 초식 이름
	if battle.last_technique_left > 0.0 and battle.last_technique_name != "":
		var a2 := clampf(battle.last_technique_left / 0.3, 0.0, 1.0)
		var pp: Vector2 = player.position
		draw_string(font, Vector2(pp.x - 80, pp.y - player.body_size.y - 20), battle.last_technique_name,
			HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(1, 0.85, 0.9, a2))

	# 화면 가운데 안내 문구
	if battle.banner_left > 0.0 and battle.banner_text != "":
		var a := clampf(battle.banner_left / 0.4, 0.0, 1.0)
		draw_string(font, Vector2(0, 520), battle.banner_text, HORIZONTAL_ALIGNMENT_CENTER, 720, 40,
			Color(1, 0.92, 0.7, a))
