extends Node2D
## 몬스터 (M1: 근접형 기본 동작).
## 오른쪽에서 생성되어 왼쪽(캐릭터)으로 접근하고, 사거리에 들어오면 멈춰서 공격한다.
## 유형별 동작(돌진, 원거리, 방어형 등)은 M2 이후 type 값에 따라 추가한다.
## 임시 그래픽: 사각형과 체력 바를 직접 그린다 (임시 에셋은 이후 스프라이트로 교체).

signal died(monster: Node)

var data: Dictionary = {}
var max_hp: int = 1
var hp: int = 1
var atk: float = 0.0
var def: float = 0.0
var move_speed: float = 0.0
var attack_range: float = 0.0
var attack_interval: float = 1.0
var body_size := Vector2(44, 60)
var body_color := Color.INDIAN_RED

var _attack_cd := 0.0
var _hit_flash := 0.0
var _dead := false


func setup(d: Dictionary) -> void:
	data = d
	max_hp = int(d["max_hp"])
	hp = max_hp
	atk = float(d["atk"])
	def = float(d["def"])
	move_speed = float(d["move_speed"])
	attack_range = float(d["attack_range"])
	attack_interval = float(d["attack_interval"])
	if d.has("size"):
		body_size = Vector2(d["size"][0], d["size"][1])
	if d.has("color"):
		body_color = Color.html(d["color"])
	_attack_cd = attack_interval * 0.5
	queue_redraw()


func half_width() -> float:
	return body_size.x * 0.5


func is_dead() -> bool:
	return _dead


## 한 프레임 진행. player가 사거리 밖이면 다가가고, 안이면 공격한다.
## 반환값: 이번 프레임에 준 피해(없으면 0)
func tick(delta: float, player, defense_constant: float) -> int:
	if _dead:
		return 0
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var gap := TargetSelector.edge_gap(player.position.x, player.half_width(), position.x, half_width())
	var dealt := 0
	if gap > attack_range:
		# 사거리까지 남은 거리만큼만 이동 (지나치지 않게)
		position.x -= minf(move_speed * delta, gap - attack_range)
	elif not player.is_down():
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = attack_interval
			dealt = DamageCalculator.compute(atk, 1.0, player.def, defense_constant)
			player.take_damage(dealt)
	queue_redraw()
	return dealt


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_hit_flash = 0.12
	queue_redraw()
	if hp == 0:
		_dead = true
		died.emit(self)


func _draw() -> void:
	var rect := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	draw_rect(rect, Color.WHITE if _hit_flash > 0.0 else body_color)
	# 체력 바
	var bar_w := body_size.x + 8.0
	var bar_pos := Vector2(-bar_w * 0.5, -body_size.y - 14.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 6)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * float(hp) / float(max_hp), 6)), Color(0.85, 0.2, 0.2))
