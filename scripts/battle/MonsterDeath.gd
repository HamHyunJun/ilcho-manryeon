extends Node2D
## 몬스터 쓰러짐 연출 (디자인 시안 design-monster-death-v1).
## 8프레임: 1 타격(흰 번쩍) → 2 밀려남 → 3 휘청 → 4 넘어감 → 5 쾅(바닥에 부딪힘, 먼지) → 6 반동(튕김)
##          → 7 기절(X눈, 머리 위 별) → 8 소멸.
## 무기는 2프레임에 손에서 빠져 포물선을 그리며 날아가 바닥에 떨어진다.
## 전투 판정과는 무관한 장식 노드다. 몬스터 노드는 처치 즉시 지우고, 이 노드가 그 자리에서 연출만 한다.

## 프레임별 시작 시각(초). 마지막 값은 전체 길이
const FRAME_TIMES := [0.0, 0.08, 0.18, 0.30, 0.42, 0.52, 0.66, 1.00, 1.30]

var art: Dictionary = {}
var sc := 1.6
var age := 0.0
## 처치 방향 (몬스터는 왼쪽을 보고 있으므로 오른쪽(+1)으로 밀려나 뒤로 넘어진다)
var dir := 1.0

var _weapon_pos := Vector2.ZERO
var _weapon_vel := Vector2.ZERO
var _weapon_ang := 0.0
var _weapon_spin := 0.0
var _weapon_landed := false
var _weapon_released := false
var _dust: Array = []
var _rng := RandomNumberGenerator.new()


func setup(visual: Dictionary) -> void:
	art = visual["art"]
	sc = float(visual["scale"])
	position = visual["position"]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rng.randomize()
	var size: Vector2 = art["size"]
	_weapon_pos = (Vector2(art["hand"]) - Vector2(size.x * 0.5, size.y)) * sc
	_weapon_ang = -0.45


## 현재 프레임 번호 (1~8)
func frame() -> int:
	for i in range(FRAME_TIMES.size() - 1, -1, -1):
		if age >= FRAME_TIMES[i]:
			return mini(i + 1, 8)
	return 1


func is_done() -> bool:
	return age >= FRAME_TIMES[FRAME_TIMES.size() - 1]


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var before := frame()
	age += delta
	var f := frame()
	# 2프레임: 무기가 손에서 빠져 날아간다
	if f >= 2 and not _weapon_released:
		_weapon_released = true
		_weapon_vel = Vector2(dir * _rng.randf_range(-60.0, 140.0), -_rng.randf_range(300.0, 380.0))
		_weapon_spin = dir * _rng.randf_range(10.0, 15.0)
	if _weapon_released and not _weapon_landed:
		_weapon_vel.y += 1100.0 * delta
		_weapon_pos += _weapon_vel * delta
		_weapon_ang += _weapon_spin * delta
		if _weapon_pos.y >= -4.0 and _weapon_vel.y > 0.0:
			# 바닥에 떨어져 비스듬히 눕는다
			_weapon_pos.y = -4.0
			_weapon_landed = true
			_weapon_ang = dir * PI * 0.5 + 0.25
			_puff(_weapon_pos, 3, 0.6)
	# 5프레임: 쾅! 바닥에 부딪히며 먼지
	if before < 5 and f >= 5:
		_puff(Vector2(dir * art["size"].y * sc * 0.45, -6), 7, 1.0)
	for d in _dust:
		d["age"] += delta
		d["pos"] += d["vel"] * delta
		d["vel"] *= 0.9
	_dust = _dust.filter(func(d): return d["age"] < d["life"])
	queue_redraw()
	if is_done():
		queue_free()


func _puff(at: Vector2, n: int, strength: float) -> void:
	for i in n:
		var a := _rng.randf_range(PI * 1.05, PI * 1.95)
		_dust.append({
			"pos": at + Vector2(_rng.randf_range(-16, 16), 0),
			"vel": Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(40, 110) * strength,
			"r": _rng.randf_range(6, 12) * strength,
			"age": 0.0,
			"life": _rng.randf_range(0.35, 0.6),
		})


func _draw() -> void:
	if art.is_empty():
		return
	var f := frame()
	var size: Vector2 = art["size"]
	var offset := Vector2.ZERO
	var rot := 0.0
	var alpha := 1.0
	# 프레임마다 자세를 끊어서 바꾼다 (픽셀 게임식 프레임 애니메이션)
	match f:
		1:
			offset = Vector2(dir * 4, 0)
		2:
			offset = Vector2(dir * 16, -6)
			rot = dir * 0.18
		3:
			offset = Vector2(dir * 26, -2)
			rot = dir * 0.45
		4:
			offset = Vector2(dir * 32, -4)
			rot = dir * 1.1
		5:
			offset = Vector2(dir * 36, 0)
			rot = dir * PI * 0.5
		6:
			offset = Vector2(dir * 38, -10)
			rot = dir * (PI * 0.5 - 0.12)
		7:
			offset = Vector2(dir * 38, 0)
			rot = dir * PI * 0.5
		8:
			offset = Vector2(dir * 38, 0)
			rot = dir * PI * 0.5
			var t := (age - FRAME_TIMES[7]) / (FRAME_TIMES[8] - FRAME_TIMES[7])
			# 깜빡이며 흐려진다
			alpha = clampf(1.0 - t, 0.0, 1.0) * (0.55 if int(age * 30.0) % 2 == 0 else 1.0)
	# 그림자
	draw_set_transform(Vector2(offset.x * 0.8, -2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, size.x * sc * (0.36 if f < 5 else 0.5), Color(0, 0, 0, 0.3 * alpha))
	# 몸 (발 기준으로 회전)
	var tex: Texture2D = art["body"]
	if f == 1:
		tex = art["flash"]
	elif f >= 7:
		tex = art["ko"]
	draw_set_transform(offset, rot, Vector2.ONE)
	ChibiArt.draw_sprite(self, tex, size, Vector2.ZERO, sc, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 1프레임: 타격 순간 흰 충격 별
	if f == 1:
		var c := Vector2(-6, -size.y * sc * 0.55)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * 14, c + Vector2(cos(a), sin(a)) * 30, Color(1, 1, 1, 0.9), 3.0)
	# 무기 (손에 쥔 채 → 날아감 → 바닥)
	if not _weapon_released:
		ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], _weapon_pos + offset, _weapon_ang, sc, Color(3, 3, 3) if f == 1 else Color.WHITE)
	else:
		ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], _weapon_pos, _weapon_ang, sc, Color(1, 1, 1, alpha))
	# 먼지
	for d in _dust:
		var k: float = d["age"] / d["life"]
		draw_circle(d["pos"], d["r"] * (0.6 + k * 0.8), Color(0.78, 0.72, 0.62, 0.55 * (1.0 - k) * alpha))
	# 7프레임: 머리 위를 도는 별 (누운 상태라 머리는 오른쪽)
	if f == 7:
		var head := offset + Vector2(dir * size.y * sc * 0.72, -size.x * sc * 0.25)
		for i in 3:
			var a := age * 9.0 + TAU * i / 3.0
			var p := head + Vector2(cos(a) * 18.0, sin(a) * 6.0 - 6.0)
			_star(p, 6.0, Color(1, 0.9, 0.3))


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.38
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)
