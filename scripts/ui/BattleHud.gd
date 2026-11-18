extends Node2D
## 전투 상단 바 (M2 → 디자인 시안 mock-vector-v30 반영).
## - 왼쪽: 주인공 얼굴 프로필(경험치 고리, 레벨 표시)과 체력·내공 바
## - 가운데: 지역명 · 스테이지, 진행 바(처치 진행도 / 보스 체력 / 던전 남은 시간)와 보스 표시, 진행 문구
## - 오른쪽: 설정 버튼 자리 (버튼 자체는 GameUi)
## 세 요소는 같은 가로 중심선(CENTER_Y)에 상하 가운데 정렬한다. 위쪽 여백은 이전보다 20px 늘렸다.
## 그 아래 한 줄: 전투력과 은냥. 캐릭터 머리 위 초식 이름, 화면 가운데 안내 문구도 여기서 그린다.

## 표시할 BattleManager
var battle: Node2D

## 상단 바 가로 중심선 (프로필, 스테이지, 설정 공통)
const CENTER_Y := 92.0
const PROFILE_X := 60.0
const PROFILE_R := 36.0


func _draw() -> void:
	if battle == null or battle.stage == null:
		return
	var player = battle.player
	_draw_profile(player)
	_draw_stage_block()
	_draw_sub_row()

	# 캐릭터 머리 위: 방금 발동한 초식 이름
	if battle.last_technique_left > 0.0 and battle.last_technique_name != "":
		var a2 := clampf(battle.last_technique_left / 0.3, 0.0, 1.0)
		var pp: Vector2 = player.position
		UiIcons.text(self, Vector2(pp.x - 100, pp.y - 112), battle.last_technique_name, 22, Color(1, 0.88, 0.95, a2), HORIZONTAL_ALIGNMENT_CENTER, 200)

	# 화면 가운데 안내 문구
	if battle.banner_left > 0.0 and battle.banner_text != "":
		var a := clampf(battle.banner_left / 0.4, 0.0, 1.0)
		UiIcons.text(self, Vector2(0, 560), battle.banner_text, 40, Color(1, 0.92, 0.7, a), HORIZONTAL_ALIGNMENT_CENTER, 720, 8)


func _draw_profile(player) -> void:
	var c := Vector2(PROFILE_X, CENTER_Y)
	var style: String = player.style if "style" in player else "sword"
	var art := ChibiArt.hero(style)
	# 바탕 원과 얼굴
	draw_circle(c, PROFILE_R, UiIcons.INK)
	draw_circle(c, PROFILE_R - 4, Color("#3a3d39"))
	var hr: Rect2 = art["head_rect"]
	var img_scale := float(ChibiArt.UPSCALE)
	var src := Rect2(hr.position * img_scale, hr.size * img_scale)
	var dsize := Vector2(62, 62 * hr.size.y / hr.size.x)
	draw_texture_rect_region(art["body"], Rect2(c - Vector2(dsize.x * 0.5, dsize.y * 0.5 + 2), dsize), src)
	# 경험치 고리 (보라) + 금테
	UiIcons.ink_ring(self, c, PROFILE_R, UiIcons.BONE, 3.5, 5, 1.2)
	var growth = battle.growth
	if growth != null:
		var er := 1.0 if growth.level() >= growth.level_cap() else float(growth.current_exp()) / float(maxi(growth.exp_to_next(), 1))
		if er > 0.0:
			draw_arc(c, PROFILE_R + 4, -PI * 0.5, -PI * 0.5 + TAU * er, 48, Color("#b88cff"), 3.0)
		# 레벨 배지
		var bc := c + Vector2(26, 26)
		draw_circle(bc, 13, UiIcons.ACCENT)
		draw_arc(bc, 13, 0, TAU, 24, Color("#f2e6ff"), 2.0)
		UiIcons.text(self, bc + Vector2(-20, 6), str(growth.level()), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40, 3)
	# 체력 / 내공 바
	var bx := PROFILE_X + PROFILE_R + 12
	var bw := 120.0
	_bar(Rect2(bx, CENTER_Y - 20, bw, 17), float(player.hp) / float(maxi(player.max_hp, 1)), Color("#3fcf5e"), "%d / %d" % [player.hp, player.max_hp])
	_bar(Rect2(bx, CENTER_Y + 3, bw, 17), player.mp / maxf(player.max_mp, 1.0), Color("#4a7dff"), "%d / %d" % [int(player.mp), int(player.max_mp)])


func _bar(r: Rect2, ratio: float, col: Color, label: String) -> void:
	UiIcons.round_rect(self, r.grow(2), 9, Color(0.04, 0.04, 0.08, 0.9))
	if ratio > 0.0:
		var fill := Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y))
		UiIcons.round_rect(self, fill, 8, col)
		draw_rect(Rect2(fill.position + Vector2(4, 2), Vector2(maxf(fill.size.x - 8, 0), 3)), Color(1, 1, 1, 0.3))
	UiIcons.text(self, Vector2(r.position.x, r.position.y + 14), label, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 3)


func _draw_stage_block() -> void:
	var stage: StageManager = battle.stage
	var dg = battle.dungeon
	# 구역 이름이 있으면 지역 이름 대신 구역 이름을 보여 준다 (예: 철문관 · 스테이지 12)
	var place := stage.area_name() if stage.area_name() != "" else stage.region_name()
	var title := "%s · 스테이지 %d" % [place, stage.stage_no]
	if dg != null:
		title = "%s · %s" % [dg.data.get("name", "던전"), dg.data.get("difficulty_name", "")]
	var left := 236.0
	var width := 240.0
	# 구역 이름이 붙어 제목이 길어지면 글자를 조금 줄인다
	var title_size := 26 if title.length() <= 10 else 21
	UiIcons.text(self, Vector2(left - 20, CENTER_Y - 18), title, title_size, Color(1, 0.98, 0.92), HORIZONTAL_ALIGNMENT_CENTER, width + 40)
	var bar := Rect2(left, CENTER_Y - 6, width, 12)
	draw_rect(bar.grow(2), Color(0.03, 0.03, 0.07, 0.9))
	draw_rect(bar, Color(0.16, 0.16, 0.24))
	var ratio := 0.0
	var col := Color("#f0b23c")
	var caption := ""
	var boss = battle.boss
	if dg != null and not (dg.is_boss_wave() and is_instance_valid(boss)):
		var tl: float = float(dg.battle_cfg().get("time_limit", 180))
		ratio = clampf(dg.time_left / tl, 0.0, 1.0)
		col = Color("#6fb6ff")
		caption = dg.progress_text() + " · %d초" % ceili(maxf(dg.time_left, 0.0))
	elif (stage.phase == StageManager.Phase.BOSS or dg != null) and is_instance_valid(boss):
		ratio = float(boss.hp) / float(boss.max_hp)
		col = Color("#e8443a")
		caption = "보스 %s  %s / %s" % [boss.data.get("name", ""), MenuPanel.fmt(boss.hp), MenuPanel.fmt(boss.max_hp)]
	else:
		var need := stage.kills_to_boss()
		ratio = float(mini(stage.kill_count, need)) / float(maxi(need, 1))
		caption = "처치 %d / %d" % [stage.kill_count, need]
		if stage.phase == StageManager.Phase.BOSS_INTRO:
			caption = "보스 등장!"
		elif stage.phase == StageManager.Phase.CLEARED:
			caption = "돌파!"
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3)), Color(1, 1, 1, 0.3))
	UiIcons.boss_face(self, Vector2(left + width + 20, CENTER_Y), 34)
	# 보스 이름이 길면(예: 흑혈대주 혈마도) 체력 숫자가 잘리지 않게 글자를 줄인다
	var cap_size := 19 if caption.length() <= 24 else 16
	UiIcons.text(self, Vector2(left - 40, CENTER_Y + 30), caption, cap_size, UiIcons.BONE, HORIZONTAL_ALIGNMENT_CENTER, width + 80, 4)


## 상단 바 아래 한 줄: 전투력(왼쪽), 은냥(오른쪽)
func _draw_sub_row() -> void:
	var y := CENTER_Y + 64
	if battle.growth != null:
		UiIcons.text(self, Vector2(24, y), "%s · 전투력 %s" % [battle.growth.realm().get("name", ""), MenuPanel.fmt(battle.combat_power())], 17, Color(1.0, 0.9, 0.7))
	if battle.equipment != null:
		var s := MenuPanel.fmt(battle.equipment.silver())
		UiIcons.text(self, Vector2(400, y), s, 17, Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 296)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_circle(Vector2(696 - w - 14, y - 6), 8, Color("#d7dbe8"))
		draw_circle(Vector2(696 - w - 14, y - 6), 4, Color("#9aa0b4"))
