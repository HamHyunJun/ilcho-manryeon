extends Node2D
## 몬스터 (M1 근접형 기본 동작 + M2 보스 패턴).
## 오른쪽에서 생성되어 왼쪽(캐릭터)으로 접근하고, 사거리에 들어오면 멈춰서 공격한다.
## 보스(type "boss")는 기본 공격 사이사이에 패턴을 쓴다. 패턴은 예고 시간이 지나면 반드시 맞는다.
## 공격 예고는 플레이어가 피하는 장치가 아니라 연출이다 (docs/02 7장, 가안).
## 유형별 동작(돌진, 방어형 등)은 이후 type 값에 따라 추가한다.
## type "ranged"(원거리형, 삿갓 궁수)는 근접형과 같이 움직이되 사거리가 길고, 공격할 때 화살이 날아가는 연출만 더한다.
## 그래픽: ChibiArt 2등신 픽셀 스프라이트 (data의 sprite: bandit/masked/chief). body_size는 판정 크기다.
## 처치되면 BattleManager가 MonsterDeath 연출(8프레임 쓰러짐)을 따로 띄우고 이 노드는 바로 지운다.

signal died(monster: Node)

var data: Dictionary = {}
var max_hp: int = 1
var hp: int = 1
var atk: float = 0.0
var def: float = 0.0
var move_speed: float = 0.0
var attack_range: float = 0.0
## 다가오다 멈추는 거리 (사거리 이하). 무리로 생성될 때 BattleManager가 조금씩 다르게 정한다
var stop_range: float = 0.0
var attack_interval: float = 1.0
var body_size := Vector2(44, 60)
var body_color := Color.INDIAN_RED

## 보스 패턴 상태
var patterns: Array = []
## 예고 중인 패턴 (없으면 빈 Dictionary)
var telegraph_pattern: Dictionary = {}
var telegraph_left := 0.0
## 지금까지 쓴 패턴 수 (테스트, 연출용)
var patterns_used := 0

var _attack_cd := 0.0
var _hit_flash := 0.0
var _dead := false
var _pattern_cd: Dictionary = {}
var _t := 0.0
var _moving := false
var _attack_anim := 0.0
## 마지막으로 잰 캐릭터와의 거리 (원거리형 화살 연출용)
var _gap := 0.0


## scaling: 스테이지 배율. 체력과 공격력에 곱한다 (docs/11 4장, 가안).
func setup(d: Dictionary, scaling: float = 1.0) -> void:
	data = d
	max_hp = maxi(1, roundi(float(d["max_hp"]) * scaling))
	hp = max_hp
	atk = float(d["atk"]) * scaling
	def = float(d["def"])
	move_speed = float(d["move_speed"])
	attack_range = float(d["attack_range"])
	stop_range = attack_range
	attack_interval = float(d["attack_interval"])
	if d.has("size"):
		body_size = Vector2(d["size"][0], d["size"][1])
	if d.has("color"):
		body_color = Color.html(d["color"])
	patterns = d.get("patterns", [])
	for p in patterns:
		_pattern_cd[p["id"]] = float(p.get("first_delay", p.get("cooldown", 8.0)))
	_attack_cd = attack_interval * 0.5
	queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 스프라이트 종류. 데이터에 sprite가 없으면 유형으로 고른다
func sprite_kind() -> String:
	if data.has("sprite"):
		return String(data["sprite"])
	return "chief" if is_boss() else "bandit"


## 그림 배율. 보스는 1.5배, 데이터의 sprite_scale로 조정할 수 있다
func sprite_scale() -> float:
	return ChibiArt.ART_SCALE * float(data.get("sprite_scale", 1.5 if is_boss() else 1.0))


func is_ranged() -> bool:
	return data.get("type", "") == "ranged" or bool(data.get("ranged", false))


## 화살 연출: 손에서 캐릭터 쪽(왼쪽)으로 날아간다. t: 0~1
func _draw_arrow(from: Vector2, t: float) -> void:
	var x := from.x - (_gap + half_width()) * t
	var p := Vector2(x, from.y - 4.0)
	draw_line(p, p + Vector2(22, 0), Color("#6b4426"), 3.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(1, -4), p + Vector2(1, 4)]), Color("#dfe7f7"))
	draw_line(p + Vector2(18, -4), p + Vector2(24, 0), Color("#f4f1ff"), 2.0)
	draw_line(p + Vector2(18, 4), p + Vector2(24, 0), Color("#f4f1ff"), 2.0)


func is_boss() -> bool:
	return data.get("type", "") == "boss"


func half_width() -> float:
	return body_size.x * 0.5


func is_dead() -> bool:
	return _dead


func is_telegraphing() -> bool:
	return not telegraph_pattern.is_empty()


## 예고 진행도 0~1
func telegraph_progress() -> float:
	if not is_telegraphing():
		return 0.0
	var total := float(telegraph_pattern.get("telegraph_sec", 1.0))
	return clampf(1.0 - telegraph_left / maxf(total, 0.001), 0.0, 1.0)


## 한 프레임 진행. player가 사거리 밖이면 다가가고, 안이면 공격한다.
## 반환값: 이번 프레임에 준 피해(없으면 0)
func tick(delta: float, player, defense_constant: float) -> int:
	if _dead:
		return 0
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	_t += delta
	var gap := TargetSelector.edge_gap(player.position.x, player.half_width(), position.x, half_width())
	var dealt := 0
	_gap = gap
	_moving = gap > stop_range
	if gap > stop_range:
		# 멈출 거리까지 남은 만큼만 이동 (지나치지 않게)
		position.x -= minf(move_speed * delta, gap - stop_range)
	elif not player.is_down():
		if not patterns.is_empty():
			dealt = _tick_patterns(delta, player, defense_constant)
		if not is_telegraphing() and dealt == 0:
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = attack_interval
				_attack_anim = 0.25
				dealt = player.take_damage(DamageCalculator.compute(atk, 1.0, player.def, defense_constant))
	queue_redraw()
	return dealt


## 보스 패턴: 쿨타임이 찬 패턴을 예고하고, 예고가 끝나면 피해를 준다.
func _tick_patterns(delta: float, player, defense_constant: float) -> int:
	if is_telegraphing():
		telegraph_left -= delta
		if telegraph_left > 0.0:
			return 0
		var coef := float(telegraph_pattern.get("power_coef", 1.0))
		var dmg: int = player.take_damage(DamageCalculator.compute(atk, coef, player.def, defense_constant))
		_pattern_cd[telegraph_pattern["id"]] = float(telegraph_pattern.get("cooldown", 8.0))
		telegraph_pattern = {}
		patterns_used += 1
		return dmg
	for p in patterns:
		_pattern_cd[p["id"]] = float(_pattern_cd[p["id"]]) - delta
	for p in patterns:
		if float(_pattern_cd[p["id"]]) <= 0.0:
			telegraph_pattern = p
			telegraph_left = float(p.get("telegraph_sec", 1.0))
			break
	return 0


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	queue_redraw()
	if hp == 0:
		_dead = true
		telegraph_pattern = {}
		died.emit(self)


func _draw() -> void:
	var art := ChibiArt.monster(sprite_kind())
	var sc := sprite_scale()
	var size: Vector2 = art["size"]
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, size.x * sc * 0.36, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 걸을 때는 통통 튀고, 공격할 때는 앞으로 내민다
	var hop := -absf(sin(_t * 9.0)) * 3.0 if _moving else roundf(sin(_t * 4.0))
	var lunge := 0.0
	if _attack_anim > 0.0:
		lunge = -8.0 * sin((1.0 - _attack_anim / 0.25) * PI)
	var feet := Vector2(lunge, hop)
	var tint := Color.WHITE
	if is_telegraphing():
		# 패턴 준비 중: 붉게 깜빡인다
		var a := 0.5 + 0.5 * absf(sin(telegraph_progress() * PI * 4.0))
		tint = Color(1.0, 1.0 - 0.6 * a, 1.0 - 0.6 * a)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, size.x * sc * 0.5, 0.0, TAU, 32, Color(1, 0.3, 0.2, a), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ChibiArt.draw_sprite(self, art["flash"] if _hit_flash > 0.0 else art["body"], size, feet, sc, tint)
	var hand: Vector2 = feet + (Vector2(art["hand"]) - Vector2(size.x * 0.5, size.y)) * sc
	var ang := -0.45
	if _attack_anim > 0.0:
		ang = lerpf(0.5, -1.9, 1.0 - _attack_anim / 0.25)
	ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], hand, ang, sc, tint)
	if is_ranged() and _attack_anim > 0.0:
		_draw_arrow(hand, 1.0 - _attack_anim / 0.25)
	if is_boss():
		return  # 보스 체력은 상단 바의 보스 체력 바로 표시한다
	# 체력 바 (머리 위)
	var top := -size.y * sc + 2.0
	var bar_w := 44.0
	var bar_pos := Vector2(-bar_w * 0.5, top - 10.0)
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, 7)), Color(0.05, 0.03, 0.06, 0.9))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * float(hp) / float(max_hp), 5)), Color(0.9, 0.22, 0.22))


## 쓰러짐 연출에 넘길 정보 (MonsterDeath)
func death_visual() -> Dictionary:
	return {"art": ChibiArt.monster(sprite_kind()), "scale": sprite_scale(), "position": position}
