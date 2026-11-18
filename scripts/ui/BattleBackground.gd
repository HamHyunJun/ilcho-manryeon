extends Node2D
class_name BattleBackground
## 전투 배경 (실루엣 + 손그림 질감 스타일).
## 옅은 안개빛 하늘, 먹으로 그린 먼 산 능선, 세 겹의 나무 숲(멀수록 옅게), 양옆을 감싸는 검은 고목,
## 탁한 흙바닥과 먹 풀포기, 앞쪽의 검은 덤불. 색은 무채색에 가깝게 두고 기술 이펙트만 색을 쓴다.
## - 움직이지 않는 부분은 SubViewport에 한 번만 그려 텍스처로 쓰고(매 프레임 다시 그리지 않음),
##   흐르는 안개와 떠다니는 재·나뭇잎만 매 프레임 그린다.
## - 상단 정보창(위쪽 약 170px) 아래로 어둡게 깔아 글자가 배경에 묻히지 않게 한다.

const W := 720.0
const H := 1280.0
## 하늘·숲 색 (위 → 지평선)
const SKY_TOP := Color("#5e746e")
const SKY_MID := Color("#93ab9f")
const SKY_LOW := Color("#c3cfbf")
## 흙바닥 색
const EARTH := Color("#8a8670")
const EARTH_DK := Color("#6f6b58")
const INK := Color("#0e0e0e")

## 바닥(땅 윗선) 높이. 전투 ground_y와 맞춘다
var ground_y := 1020.0
## 바닥이 끝나는 높이 (하단 앱바 윗선)
var floor_bottom := 1146.0

var _static_vp: SubViewport
var _t := 0.0
var _motes: Array = []
var _leaves: Array = []
var _rng := RandomNumberGenerator.new()


func _init(ground: float = 1020.0, bottom: float = 1146.0) -> void:
	ground_y = ground
	floor_bottom = bottom


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rng.seed = 7
	_static_vp = SubViewport.new()
	_static_vp.size = Vector2i(int(W), int(H) + 320)
	_static_vp.transparent_bg = false
	_static_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_static_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_static_vp)
	var painter := StaticPainter.new()
	painter.ground_y = ground_y
	painter.floor_bottom = floor_bottom
	_static_vp.add_child(painter)
	for i in 40:
		_motes.append(_new_mote(true))
	for i in 7:
		_leaves.append(_new_leaf(true))


## 공기 중에 떠다니는 재 (작은 회색 점)
func _new_mote(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(_rng.randf_range(-20, W), _rng.randf_range(180, ground_y) if anywhere else _rng.randf_range(160, 300)),
		"vel": Vector2(_rng.randf_range(4, 16), _rng.randf_range(6, 18)),
		"size": _rng.randf_range(1.0, 2.6),
		"phase": _rng.randf_range(0, TAU),
		"a": _rng.randf_range(0.25, 0.6),
	}


## 떨어지는 검은 나뭇잎
func _new_leaf(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(_rng.randf_range(-40, W), _rng.randf_range(180, ground_y) if anywhere else _rng.randf_range(140, 220)),
		"vel": Vector2(_rng.randf_range(16, 36), _rng.randf_range(30, 55)),
		"rot": _rng.randf_range(0, TAU),
		"spin": _rng.randf_range(-2.0, 2.0),
		"size": _rng.randf_range(4.0, 7.0),
		"phase": _rng.randf_range(0, TAU),
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		m["pos"] += (m["vel"] + Vector2(sin(_t * 0.8 + m["phase"]) * 8.0, 0)) * delta
		if m["pos"].y > ground_y + 40 or m["pos"].x > W + 20:
			_motes[i] = _new_mote(false)
	for i in _leaves.size():
		var p: Dictionary = _leaves[i]
		p["pos"] += (p["vel"] + Vector2(sin(_t * 1.3 + p["phase"]) * 22.0, 0)) * delta
		p["rot"] += p["spin"] * delta
		if p["pos"].y > ground_y + 40 or p["pos"].x > W + 30:
			_leaves[i] = _new_leaf(false)
	queue_redraw()


func _draw() -> void:
	if _static_vp:
		draw_texture(_static_vp.get_texture(), Vector2.ZERO)
	# 흐르는 안개 (숲 사이)
	for k in 3:
		var x := fmod(_t * (6.0 + k * 3.0) + k * 260.0, W + 400.0) - 400.0
		var y := 760.0 + k * 75.0
		_fog_blob(Vector2(x, y), 280.0, 34.0, 0.12)
	# 떠다니는 재
	for m in _motes:
		draw_circle(m["pos"], m["size"], Color(0.12, 0.12, 0.11, m["a"]))
	# 떨어지는 검은 나뭇잎
	for p in _leaves:
		var s: float = p["size"]
		var rot: float = p["rot"]
		var pts := PackedVector2Array()
		for k in 8:
			var a := TAU * k / 8.0
			var rr := s * (1.0 if k % 4 == 0 else 0.45)
			pts.append(p["pos"] + Vector2(cos(a) * rr, sin(a) * rr * 0.6).rotated(rot))
		draw_colored_polygon(pts, Color(0.06, 0.06, 0.06, 0.85))


func _fog_blob(c: Vector2, rx: float, ry: float, a: float) -> void:
	if rx <= 0.0:
		return
	for i in 4:
		var k := 1.0 - i * 0.22
		draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx * k, Color(0.88, 0.9, 0.85, a * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 움직이지 않는 배경을 한 번 그리는 노드 (SubViewport 안)
class StaticPainter extends Node2D:
	var ground_y := 1020.0
	var floor_bottom := 1146.0
	var rng := RandomNumberGenerator.new()

	func _draw() -> void:
		rng.seed = 2026
		_sky()
		_grain(Rect2(0, 0, 720, ground_y), 900, 0.05)
		# 먼 산 능선 두 겹 (안개에 잠긴 먹빛)
		_ridge(640.0, 120.0, Color("#7f978c"), 11)
		_fog_band(600.0, 120.0, 0.18)
		_ridge(760.0, 90.0, Color("#6a8076"), 23)
		_fog_band(730.0, 110.0, 0.16)
		# 숲 세 겹: 멀수록 옅고 가늘다
		_forest(Color("#8aa298"), 26, 2.0, 5.0, 300.0, 980.0, 31)
		_fog_band(820.0, 140.0, 0.14)
		_forest(Color("#566a62"), 14, 4.0, 9.0, 220.0, 1000.0, 47)
		_fog_band(900.0, 110.0, 0.12)
		# 양옆을 감싸는 검은 고목 (가운데 전투 공간은 비워 둔다)
		_old_tree(48.0, 26.0, true, 61)
		_old_tree(676.0, 22.0, false, 73)
		_old_tree(150.0, 10.0, true, 79)
		_floor()
		# 앞쪽 검은 덤불 (화면 가장자리)
		_bush(Vector2(30, ground_y + 4), 48.0, 91)
		_bush(Vector2(700, ground_y + 2), 54.0, 93)
		_bush(Vector2(610, ground_y + 10), 26.0, 95)
		_bush(Vector2(120, ground_y + 12), 20.0, 97)
		# 상단 정보창 보호: 위쪽을 어둡게
		for i in 18:
			var y := i * 10.0
			draw_rect(Rect2(0, y, 720, 10), Color(0.04, 0.04, 0.04, 0.6 * (1.0 - i / 18.0)))

	func _sky() -> void:
		var h := ground_y
		for y in range(0, int(h), 4):
			var u := y / h
			var c := SKY_TOP.lerp(SKY_MID, u / 0.55) if u < 0.55 else SKY_MID.lerp(SKY_LOW, (u - 0.55) / 0.45)
			draw_rect(Rect2(0, y, 720, 4), c)

	## 종이 결: 아주 옅은 밝고 어두운 점
	func _grain(r: Rect2, n: int, a: float) -> void:
		for i in n:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			var dark := rng.randf() < 0.6
			draw_rect(Rect2(p, Vector2(rng.randf_range(1, 3), 1)), Color(0, 0, 0, a) if dark else Color(1, 1, 1, a * 0.8))

	## 들쭉날쭉한 산 능선 (붓으로 그은 듯 잔떨림)
	func _ridge(base: float, amp: float, col: Color, seed_v: int) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		var pts := PackedVector2Array()
		pts.append(Vector2(-10, ground_y + 10))
		var x := -10.0
		var phase := r.randf_range(0, TAU)
		while x <= 730.0:
			var y := base - amp * (0.5 + 0.5 * sin(x * 0.009 + phase)) - absf(sin(x * 0.03 + phase * 2.0)) * amp * 0.35 - r.randf_range(0, 6)
			pts.append(Vector2(x, y))
			x += r.randf_range(4, 9)
		pts.append(Vector2(730, ground_y + 10))
		draw_colored_polygon(pts, col)

	func _fog_band(y: float, h: float, a: float) -> void:
		if a <= 0.0:
			return
		for i in 8:
			var k := 1.0 - absf(i - 3.5) / 4.0
			draw_rect(Rect2(0, y + i * h / 8.0, 720, h / 8.0), Color(0.86, 0.89, 0.84, a * k * 0.7))

	## 가늘고 곧게 뻗은 나무 기둥 여러 그루
	func _forest(col: Color, n: int, w0: float, w1: float, top_min: float, bottom: float, seed_v: int) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		for i in n:
			var x := (i + r.randf_range(0.1, 0.9)) * 720.0 / n
			var w := r.randf_range(w0, w1)
			var top := r.randf_range(top_min - 120, top_min + 80)
			_trunk(x, top, bottom, w, col, r)
			# 가는 곁가지 몇 개
			for k in r.randi_range(1, 3):
				var y := r.randf_range(top + 40, bottom - 260)
				var dir := -1.0 if r.randf() < 0.5 else 1.0
				_twig(Vector2(x, y), Vector2(x + dir * r.randf_range(20, 60), y - r.randf_range(20, 50)), maxf(1.0, w * 0.4), col, r)

	## 줄기 하나: 아래가 굵고 위로 갈수록 가늘며 가장자리가 잔떨림
	func _trunk(x: float, top: float, bottom: float, w: float, col: Color, r: RandomNumberGenerator) -> void:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var y := top
		var lean := r.randf_range(-0.02, 0.02)
		while y <= bottom:
			var t := (y - top) / maxf(1.0, bottom - top)
			var ww := lerpf(w * 0.35, w, t)
			var cx := x + (bottom - y) * lean
			left.append(Vector2(cx - ww * 0.5 + r.randf_range(-0.6, 0.6), y))
			right.append(Vector2(cx + ww * 0.5 + r.randf_range(-0.6, 0.6), y))
			y += r.randf_range(10, 18)
		right.reverse()
		var pts := left
		pts.append_array(right)
		if pts.size() >= 3:
			draw_colored_polygon(pts, col)

	## 가지: 네 마디로 꺾이며 끝으로 갈수록 가늘어진다
	func _twig(a: Vector2, b: Vector2, w: float, col: Color, r: RandomNumberGenerator) -> void:
		var bend := (b - a).orthogonal().normalized() * (b - a).length() * r.randf_range(-0.12, 0.12)
		var prev := a
		for k in range(1, 5):
			var t := k / 4.0
			var p := a.lerp(b, t) + bend * sin(t * PI) + Vector2(r.randf_range(-2, 2), r.randf_range(-2, 2))
			var ww := maxf(1.0, w * (1.0 - t * 0.75))
			draw_line(prev, p, col, ww)
			draw_circle(p, ww * 0.5, col)
			prev = p

	## 화면 가장자리의 검은 고목: 굵은 줄기와 뒤틀린 가지
	func _old_tree(x: float, w: float, lean_right: bool, seed_v: int) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		_trunk(x, -20.0, ground_y + 8.0, w, INK, r)
		var dir := 1.0 if lean_right else -1.0
		for k in 5:
			var y := r.randf_range(80.0, ground_y - 300.0)
			var len := r.randf_range(70.0, 170.0) * (w / 24.0 + 0.4)
			var a := Vector2(x, y)
			var b := a + Vector2(dir * len, -len * r.randf_range(0.3, 0.9))
			_twig(a, b, maxf(2.0, w * 0.28), INK, r)
			# 잔가지
			for m in 3:
				var p := a.lerp(b, r.randf_range(0.4, 0.95))
				_twig(p, p + Vector2(dir * r.randf_range(14, 40), -r.randf_range(10, 40)), maxf(1.0, w * 0.1), INK, r)
		# 뿌리 쪽 퍼짐
		draw_colored_polygon(PackedVector2Array([Vector2(x - w * 1.4, ground_y + 10), Vector2(x - w * 0.4, ground_y - 30), Vector2(x + w * 0.4, ground_y - 30), Vector2(x + w * 1.4, ground_y + 10)]), INK)

	## 흙바닥: 탁한 황토 + 먹 풀포기와 갈라진 금
	func _floor() -> void:
		var top := ground_y - 10.0
		var bottom := floor_bottom + 400.0
		for i in 10:
			var y := top + (bottom - top) * i / 10.0
			draw_rect(Rect2(0, y, 720, (bottom - top) / 10.0 + 1), EARTH.lerp(EARTH_DK, i / 9.0))
		_grain(Rect2(0, top, 720, floor_bottom - top + 40), 700, 0.08)
		# 땅 윗선: 거친 먹선
		var r := RandomNumberGenerator.new()
		r.seed = 501
		var pts := PackedVector2Array()
		var x := -10.0
		while x <= 730.0:
			pts.append(Vector2(x, top + r.randf_range(-2.5, 2.5)))
			x += r.randf_range(6, 14)
		draw_polyline(pts, Color(0.06, 0.06, 0.06, 0.8), 3.0)
		# 땅에 드리운 숲 그림자
		for i in 5:
			draw_rect(Rect2(0, top + 2 + i * 6, 720, 6), Color(0, 0, 0, 0.06 * (5 - i)))
		# 풀포기
		for i in 70:
			var p := Vector2(r.randf_range(0, 720), r.randf_range(top + 8, floor_bottom - 6))
			var s := r.randf_range(3.0, 7.0) * (0.7 + (p.y - top) / 200.0)
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.45 + r.randf_range(-0.15, 0.15)
				draw_line(p, p + Vector2(cos(a), sin(a)) * s, Color(0.08, 0.08, 0.07, 0.7), 1.3)
		# 갈라진 금
		for i in 9:
			var p := Vector2(r.randf_range(0, 720), r.randf_range(top + 20, floor_bottom - 10))
			var q := p
			for k in 4:
				var n := q + Vector2(r.randf_range(6, 16), r.randf_range(-3, 3))
				draw_line(q, n, Color(0.1, 0.09, 0.08, 0.35), 1.2)
				q = n

	## 검은 덤불: 작은 원을 겹치고 가장자리에 가시 같은 붓 끝
	func _bush(c: Vector2, rad: float, seed_v: int) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		for i in int(rad * 0.9):
			var a := r.randf_range(PI, TAU)
			var d := r.randf_range(0, rad)
			draw_circle(c + Vector2(cos(a) * d, sin(a) * d * 0.8), r.randf_range(rad * 0.15, rad * 0.32), INK)
		for i in int(rad * 0.8):
			var a := r.randf_range(PI * 1.02, TAU * 0.99)
			var p := c + Vector2(cos(a) * rad * 0.95, sin(a) * rad * 0.78)
			draw_line(p, p + Vector2(cos(a), sin(a)) * r.randf_range(4, 10), INK, 1.5)
