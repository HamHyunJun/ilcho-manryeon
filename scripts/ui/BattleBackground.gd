extends Node2D
class_name BattleBackground
## 전투 배경 (디자인 시안 mock-vector-v29-bg / v30 반영).
## 달빛 후광, 별, 안개 낀 5겹 산, 폭포, 누각, 소나무, 매화 가지, 원근 돌바닥, 떨어지는 꽃잎.
## - 움직이지 않는 부분은 SubViewport에 한 번만 그려 텍스처로 쓰고(매 프레임 다시 그리지 않음),
##   별 반짝임, 떨어지는 꽃잎, 흐르는 안개, 폭포 물빛만 매 프레임 그린다.
## - 상단 정보창(위쪽 약 170px) 아래로 어둡게 깔아 글자가 배경에 묻히지 않게 한다.

const W := 720.0
const H := 1280.0
## 밤하늘 맨 윗색 (StaticPainter._sky 첫 색과 같다)
const SKY_TOP := Color("#070a1f")
## 바닥(돌바닥 윗선) 높이. 전투 ground_y와 맞춘다
var ground_y := 1020.0
## 돌바닥이 끝나는 높이 (하단 앱바 윗선)
var floor_bottom := 1146.0

var _static_vp: SubViewport
## 세로로 긴 화면에서 배경을 아래로 내린 양. 위쪽 빈 곳은 밤하늘로 채운다 (ScreenFit.shift)
var world_shift := 0.0:
	set(v):
		world_shift = v
		position = Vector2(0, v)
		queue_redraw()
var _t := 0.0
var _petals: Array = []
var _twinkles: Array = []
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
	for i in 34:
		_petals.append(_new_petal(true))
	for i in 18:
		_twinkles.append(Vector2(_rng.randf_range(10, W - 10), _rng.randf_range(150, 560)))


func _new_petal(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(_rng.randf_range(-40, W), _rng.randf_range(120, ground_y) if anywhere else _rng.randf_range(100, 260) - minf(world_shift, 200.0)),
		"vel": Vector2(_rng.randf_range(14, 40), _rng.randf_range(26, 60)),
		"rot": _rng.randf_range(0, TAU),
		"spin": _rng.randf_range(-2.5, 2.5),
		"size": _rng.randf_range(3.0, 6.0),
		"phase": _rng.randf_range(0, TAU),
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _petals.size():
		var p: Dictionary = _petals[i]
		p["pos"] += (p["vel"] + Vector2(sin(_t * 1.3 + p["phase"]) * 18.0, 0)) * delta
		p["rot"] += p["spin"] * delta
		if p["pos"].y > ground_y + 60 or p["pos"].x > W + 30:
			_petals[i] = _new_petal(false)
	queue_redraw()


func _draw() -> void:
	# 위로 남는 하늘: 배경 맨 윗색으로 채우고 별을 흩뿌린다 (매번 같은 자리)
	if world_shift > 0.0:
		draw_rect(Rect2(0, -world_shift, W, world_shift + 1), SKY_TOP)
		var r := RandomNumberGenerator.new()
		r.seed = 99
		for i in int(world_shift / 8.0):
			var p := Vector2(r.randf_range(0, W), r.randf_range(-world_shift, 0))
			var s := 1.0 if r.randf() < 0.85 else 2.0
			draw_rect(Rect2(p, Vector2(s, s)), Color(1, 1, 1, r.randf_range(0.25, 0.8)))
	if _static_vp:
		draw_texture(_static_vp.get_texture(), Vector2.ZERO)
	# 상단 정보창 보호: 화면 맨 위를 어둡게 (배경을 내려도 상단 바 자리에 맞춘다)
	for i in 18:
		draw_rect(Rect2(0, -world_shift + i * 10.0, W, 10), Color(0.02, 0.02, 0.06, 0.55 * (1.0 - i / 18.0)))
	# 별 반짝임
	for i in _twinkles.size():
		var tw := 0.5 + 0.5 * sin(_t * (1.5 + i * 0.13) + i)
		var p: Vector2 = _twinkles[i]
		var s := 2.0 + 3.0 * tw
		var c := Color(1, 1, 1, 0.35 + 0.55 * tw)
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), c, 1.2)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), c, 1.2)
	# 폭포 물빛 (흐르는 줄)
	for k in 4:
		var y := 600.0 + fmod(_t * 90.0 + k * 40.0, 160.0)
		draw_line(Vector2(378, y), Vector2(378, y + 18), Color(0.85, 0.95, 1.0, 0.45), 2.0)
	# 흐르는 안개
	for k in 3:
		var x := fmod(_t * (8.0 + k * 4.0) + k * 260.0, W + 400.0) - 400.0
		var y := 760.0 + k * 70.0
		_fog_blob(Vector2(x, y), 260.0, 36.0, 0.10)
	# 떨어지는 매화 꽃잎
	for p in _petals:
		var s: float = p["size"]
		var rot: float = p["rot"]
		var pts := PackedVector2Array()
		for k in 8:
			var a := TAU * k / 8.0
			pts.append(p["pos"] + Vector2(cos(a) * s, sin(a) * s * 0.55).rotated(rot))
		draw_colored_polygon(pts, Color(1.0, 0.75, 0.85, 0.85))


func _fog_blob(c: Vector2, rx: float, ry: float, a: float) -> void:
	if rx <= 0.0:
		return
	for i in 4:
		var k := 1.0 - i * 0.22
		draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx * k, Color(0.75, 0.8, 0.95, a * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 움직이지 않는 배경을 한 번 그리는 노드 (SubViewport 안)
class StaticPainter extends Node2D:
	var ground_y := 1020.0
	var floor_bottom := 1146.0
	var rng := RandomNumberGenerator.new()

	func _draw() -> void:
		rng.seed = 2026
		_sky()
		_stars()
		_moon(Vector2(520, 250), 64.0)
		# 안개 낀 5겹 산 (멀수록 밝고 푸르게)
		var layers := [
			{"base": 520.0, "amp": 70.0, "col": Color("#434c78"), "seed": 11},
			{"base": 600.0, "amp": 80.0, "col": Color("#363e69"), "seed": 12},
			{"base": 690.0, "amp": 70.0, "col": Color("#2b3259"), "seed": 13},
			{"base": 790.0, "amp": 60.0, "col": Color("#20264a"), "seed": 14},
			{"base": 900.0, "amp": 50.0, "col": Color("#161b38"), "seed": 15},
		]
		for i in layers.size():
			var L: Dictionary = layers[i]
			_mountain(L["base"], L["amp"], L["col"], L["seed"])
			if i == 2:
				_waterfall(Vector2(378, 600), 160.0)
				_pagoda(Vector2(104, 712))
			if i == 3:
				for x in [40.0, 160.0, 610.0, 680.0]:
					_pine(Vector2(x, 818 + rng.randf_range(-10, 10)), rng.randf_range(46, 64), Color("#121731"))
			if i == 4:
				for x in [250.0, 300.0, 560.0, 640.0]:
					_pine(Vector2(x, 930 + rng.randf_range(-6, 6)), rng.randf_range(36, 48), Color("#0e1228"))
			# 산 사이 안개 띠
			_fog_band(L["base"] + 30.0, 70.0, 0.16 - i * 0.02)
		_plum_branch_left()
		_plum_branch_right()
		_floor()
		# 상단 정보창 보호(위쪽 어둡게)는 바깥 _draw에서 화면 맨 위 기준으로 그린다

	func _sky() -> void:
		var stops := [[0.0, Color("#070a1f")], [0.25, Color("#11173a")], [0.5, Color("#1f2752")], [0.75, Color("#2e3866")], [1.0, Color("#262d52")]]
		var h := ground_y
		for y in range(0, int(h), 4):
			var u := y / h
			var c: Color = stops[0][1]
			for i in range(1, stops.size()):
				if u <= stops[i][0]:
					var k: float = (u - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0])
					c = (stops[i - 1][1] as Color).lerp(stops[i][1], k)
					break
			draw_rect(Rect2(0, y, 720, 4), c)

	func _stars() -> void:
		for i in 240:
			var p := Vector2(rng.randf_range(0, 720), rng.randf_range(0, 640))
			var b := rng.randf_range(0.25, 0.9) * (1.0 - p.y / 900.0)
			var s := 1.0 if rng.randf() < 0.85 else 2.0
			draw_rect(Rect2(p, Vector2(s, s)), Color(1, 1, 1, b))

	func _moon(c: Vector2, r: float) -> void:
		# 달빛 후광: 여러 겹의 옅은 원
		for i in 10:
			var rr := r * (3.6 - i * 0.28)
			draw_circle(c, rr, Color(1.0, 0.95, 0.75, 0.035))
		draw_circle(c, r, Color("#f5ebc2"))
		draw_circle(c + Vector2(10, 8), r * 0.86, Color("#efe2b0"))
		# 달 표면 무늬
		for m in [[Vector2(-18, -10), 10.0], [Vector2(14, 18), 13.0], [Vector2(22, -20), 7.0], [Vector2(-8, 26), 6.0]]:
			draw_circle(c + m[0], m[1], Color(0.85, 0.8, 0.62, 0.35))

	func _mountain(base: float, amp: float, col: Color, seed_v: int) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		var pts := PackedVector2Array()
		var ridge := PackedVector2Array()
		pts.append(Vector2(-10, ground_y + 10))
		var x := -10.0
		var phase := r.randf_range(0, TAU)
		while x <= 730.0:
			var y := base - amp * (0.55 + 0.45 * sin(x * 0.012 + phase)) - absf(sin(x * 0.045 + phase * 2.0)) * amp * 0.5 - r.randf_range(0, amp * 0.18)
			ridge.append(Vector2(x, y))
			pts.append(Vector2(x, y))
			x += r.randf_range(10, 22)
		pts.append(Vector2(730, ground_y + 10))
		draw_colored_polygon(pts, col)
		# 달빛을 받는 능선 하이라이트
		draw_polyline(ridge, col.lightened(0.28), 1.5)
		# 아래로 갈수록 안개에 잠긴다
		for i in 6:
			draw_rect(Rect2(0, base + 10 + i * 14, 720, 14), Color(col.lightened(0.2), 0.05))

	func _fog_band(y: float, h: float, a: float) -> void:
		if a <= 0.0:
			return
		for i in 8:
			var k := 1.0 - absf(i - 3.5) / 4.0
			draw_rect(Rect2(0, y + i * h / 8.0, 720, h / 8.0), Color(0.72, 0.78, 0.95, a * k * 0.6))

	func _waterfall(top: Vector2, h: float) -> void:
		for i in 6:
			draw_rect(Rect2(top.x - 6 + i * 0.5, top.y, 12 - i, h), Color(0.75, 0.88, 1.0, 0.12))
		draw_line(top, top + Vector2(0, h), Color(0.9, 0.97, 1.0, 0.55), 2.0)
		for i in 5:
			draw_set_transform(top + Vector2(0, h + 4), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, 50.0 - i * 9.0, Color(0.7, 0.85, 1.0, 0.08))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _pagoda(base: Vector2) -> void:
		# 등불이 켜진 누각 (3층 지붕)
		for i in 6:
			draw_circle(base + Vector2(0, -50), 70.0 - i * 10.0, Color(1.0, 0.7, 0.35, 0.05))
		var dark := Color("#141a33")
		var roof := Color("#1c2343")
		var y := base.y
		var widths := [44.0, 36.0, 28.0]
		for i in 3:
			var w: float = widths[i]
			draw_rect(Rect2(base.x - w * 0.35, y - 22, w * 0.7, 22), dark)
			for k in 3:
				draw_rect(Rect2(base.x - w * 0.28 + k * w * 0.2, y - 17, w * 0.1, 10), Color(1.0, 0.75, 0.35, 0.95))
			var rp := PackedVector2Array([Vector2(base.x - w * 0.75, y - 20), Vector2(base.x + w * 0.75, y - 20), Vector2(base.x + w * 0.4, y - 32), Vector2(base.x - w * 0.4, y - 32)])
			draw_colored_polygon(rp, roof)
			draw_line(Vector2(base.x - w * 0.78, y - 22), Vector2(base.x - w * 0.72, y - 18), roof, 3.0)
			y -= 32
		draw_line(Vector2(base.x, y), Vector2(base.x, y - 18), roof, 2.0)
		draw_rect(Rect2(base.x - 26, base.y, 52, 8), dark)

	func _pine(base: Vector2, h: float, col: Color) -> void:
		draw_rect(Rect2(base.x - 2, base.y - h * 0.3, 4, h * 0.3), col)
		for i in 4:
			var y := base.y - h * 0.25 - i * h * 0.2
			var w := h * (0.42 - i * 0.08)
			draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y), Vector2(base.x + w, y), Vector2(base.x, y - h * 0.3)]), col)

	func _branch(pts: PackedVector2Array, width: float) -> void:
		var col := Color("#2a1a1e")
		for i in pts.size() - 1:
			var w := lerpf(width, width * 0.35, float(i) / maxf(1.0, pts.size() - 2))
			draw_line(pts[i], pts[i + 1], col, w)
			draw_circle(pts[i + 1], w * 0.5, col)

	func _blossoms(around: Vector2, n: int, spread: float) -> void:
		for i in n:
			var p := around + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.6, spread * 0.6))
			var s := rng.randf_range(2.5, 5.0)
			var c := Color(1.0, rng.randf_range(0.62, 0.8), rng.randf_range(0.75, 0.85), rng.randf_range(0.75, 1.0))
			for k in 5:
				var a := TAU * k / 5.0
				draw_circle(p + Vector2(cos(a), sin(a)) * s * 0.7, s * 0.6, c)
			draw_circle(p, s * 0.35, Color(1, 0.9, 0.6))

	func _plum_branch_left() -> void:
		var main := PackedVector2Array([Vector2(-10, 190), Vector2(90, 205), Vector2(170, 236), Vector2(240, 250), Vector2(300, 290)])
		_branch(main, 9.0)
		_branch(PackedVector2Array([Vector2(170, 236), Vector2(200, 300), Vector2(250, 340)]), 4.0)
		_branch(PackedVector2Array([Vector2(90, 205), Vector2(120, 250), Vector2(110, 300)]), 4.0)
		_branch(PackedVector2Array([Vector2(240, 250), Vector2(280, 215), Vector2(320, 205)]), 3.0)
		for p in [Vector2(290, 285), Vector2(250, 335), Vector2(110, 295), Vector2(310, 208), Vector2(200, 245), Vector2(150, 230)]:
			_blossoms(p, 14, 26.0)

	func _plum_branch_right() -> void:
		var main := PackedVector2Array([Vector2(730, 170), Vector2(640, 190), Vector2(590, 230), Vector2(540, 270), Vector2(480, 320)])
		_branch(main, 8.0)
		_branch(PackedVector2Array([Vector2(590, 230), Vector2(560, 190), Vector2(520, 180)]), 3.5)
		_branch(PackedVector2Array([Vector2(540, 270), Vector2(560, 320), Vector2(540, 360)]), 3.5)
		for p in [Vector2(485, 318), Vector2(525, 182), Vector2(545, 355), Vector2(610, 205), Vector2(570, 255)]:
			_blossoms(p, 13, 24.0)

	func _floor() -> void:
		# 원근 돌바닥: 아래로 갈수록 돌 줄 높이가 커지고, 세로 줄눈은 소실점으로 모인다
		var top := ground_y - 14.0
		draw_rect(Rect2(0, top, 720, floor_bottom + 400 - top), Color("#2a2d36"))
		var vp := Vector2(360, top - 260)
		var y := top
		var row := 0
		var hgt := 14.0
		while y < floor_bottom + 60:
			var shade := Color("#33363f").lerp(Color("#24262e"), float(row) / 8.0)
			draw_rect(Rect2(0, y, 720, hgt - 2), shade)
			draw_line(Vector2(0, y + hgt - 1), Vector2(720, y + hgt - 1), Color("#15161c"), 2.0)
			draw_line(Vector2(0, y), Vector2(720, y), Color(1, 1, 1, 0.05), 1.0)
			# 세로 줄눈 (엇갈림)
			var off := 0.5 if row % 2 else 0.0
			for k in range(-6, 8):
				var bx := (k + off) * 90.0 + 0.0
				var t0 := (y - vp.y) / (top - vp.y)
				var t1 := (y + hgt - vp.y) / (top - vp.y)
				var x0 := vp.x + (bx - vp.x) * t0 * 0.75
				var x1 := vp.x + (bx - vp.x) * t1 * 0.75
				draw_line(Vector2(x0, y), Vector2(x1, y + hgt - 2), Color("#17181e"), 2.0)
			y += hgt
			hgt *= 1.18
			row += 1
		# 바닥 위쪽 가장자리 (돌 턱)
		draw_rect(Rect2(0, top - 4, 720, 6), Color("#43474f"))
		draw_line(Vector2(0, top - 4), Vector2(720, top - 4), Color(1, 1, 1, 0.12), 1.0)
		# 바닥에 깔린 옅은 안개
		for i in 6:
			draw_rect(Rect2(0, top - 30 + i * 8, 720, 8), Color(0.7, 0.75, 0.9, 0.035 * (6 - i)))
