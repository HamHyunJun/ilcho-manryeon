extends Control
class_name AppBar
## 하단 앱바 (디자인 시안 mock-vector-v30-bigbar).
## 상점 │ 육성 │ (메인 태극 버튼) │ 던전 │ 소환. 높이 134px, 아이콘 1.4배, 글자 24.
## 가운데 태극 버튼은 앱바 위로 솟아 있고 누르면 메인(전투 화면)으로 돌아간다.
## 바로 위에는 초식 수련 게이지(금색 바)를 그린다.

signal menu_pressed(menu: String)

const HEIGHT := 134.0
const ICON := 56.0
const ITEMS := [["shop", "상점"], ["growth", "육성"], ["main", "메인"], ["dungeon", "던전"], ["summon", "소환"]]
const TAIJI_R := 56.0

## 지금 열려 있는 메뉴 ("main"이면 전투 화면)
var active := "main"
## 초식 게이지 (0~1): 수련 중인 초식의 대성 진행도
var gauge := 0.0
var _t := 0.0
var bar_y := 1146.0


func _init(top: float) -> void:
	bar_y = top
	# 컨트롤 영역은 태극 버튼이 솟은 높이부터 화면 아래까지
	position = Vector2(0, top - 70)
	size = Vector2(720, HEIGHT + 70 + 400)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## 앱바 띠와 솟은 태극 버튼 안쪽만 누를 수 있다 (위쪽 빈 곳은 전투 화면으로 통과)
func _has_point(point: Vector2) -> bool:
	if point.y >= 70.0 - 14.0:
		return true
	return point.distance_to(_taiji_center()) <= TAIJI_R + 8.0


func _taiji_center() -> Vector2:
	return Vector2(360, 70.0 + 14.0)


func _slot_x(i: int) -> float:
	return 72.0 + i * 144.0


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	accept_event()
	if pos.distance_to(_taiji_center()) <= TAIJI_R + 8.0:
		menu_pressed.emit("main")
		return
	var i := clampi(int(pos.x / 144.0), 0, ITEMS.size() - 1)
	menu_pressed.emit(ITEMS[i][0])


func _draw() -> void:
	var top := 70.0
	# 초식 게이지 (앱바 바로 위)
	var gy := top - 14.0
	draw_rect(Rect2(0, gy, 720, 14), Color(0.05, 0.03, 0.04, 0.95))
	if gauge > 0.0:
		draw_rect(Rect2(0, gy + 2, 720 * clampf(gauge, 0.0, 1.0), 10), Color("#e2a93a"))
		draw_rect(Rect2(0, gy + 2, 720 * clampf(gauge, 0.0, 1.0), 3), Color(1, 0.95, 0.7, 0.6))
	# 앱바 띠: 짙은 붉은 갈색 그라데이션 + 금테
	for i in 12:
		var k := i / 11.0
		draw_rect(Rect2(0, top + HEIGHT * k, 720, HEIGHT / 11.0 + 1), Color("#4a1a17").lerp(Color("#230b0c"), k))
	draw_rect(Rect2(0, top + HEIGHT, 720, 400), Color("#230b0c"))
	draw_line(Vector2(0, top + 1), Vector2(720, top + 1), Color("#d9a441"), 3.0)
	draw_line(Vector2(0, top + 6), Vector2(720, top + 6), Color(0.85, 0.64, 0.25, 0.35), 1.0)
	# 칸 구분선
	for i in [1, 4]:
		var x: float = i * 144.0
		draw_line(Vector2(x, top + 18), Vector2(x, top + HEIGHT - 16), Color(0.85, 0.64, 0.25, 0.35), 2.0)
	for i in ITEMS.size():
		var id: String = ITEMS[i][0]
		if id == "main":
			continue
		var cx := _slot_x(i)
		var on := active == id
		if on:
			UiIcons.round_rect(self, Rect2(cx - 64, top + 10, 128, HEIGHT - 18), 14, Color(0.55, 0.33, 0.12, 0.45), Color("#e8b94e"), 2.0)
		var col := Color("#ffd977") if on else UiIcons.GOLD
		var ic := Vector2(cx, top + 50)
		match id:
			"shop":
				UiIcons.coins(self, ic, ICON, col)
			"growth":
				UiIcons.lotus(self, ic, ICON, col)
			"dungeon":
				UiIcons.gate(self, ic, ICON, col)
			"summon":
				UiIcons.pentagram(self, ic, ICON, col)
		UiIcons.text(self, Vector2(cx - 70, top + 114), ITEMS[i][1], 24, Color(1, 0.96, 0.88) if on else Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 140, 4)
	# 가운데 태극 버튼 (확대, 앱바 위로 솟음)
	var c := _taiji_center()
	var main_on := active == "main"
	for i in 6:
		draw_circle(c, TAIJI_R + 18 - i * 3, Color(1.0, 0.75, 0.3, 0.05 + (0.04 if main_on else 0.0)))
	draw_circle(c, TAIJI_R + 6, Color("#2a0f0e"))
	draw_arc(c, TAIJI_R + 6, 0, TAU, 64, Color("#e8b94e"), 4.0)
	draw_arc(c, TAIJI_R - 1, 0, TAU, 64, Color("#8a5a1c"), 2.0)
	UiIcons.taiji(self, c, TAIJI_R - 8, _t * (0.6 if main_on else 0.15))
	UiIcons.text(self, Vector2(c.x - 70, top + 114), "메인", 24, Color(1, 0.88, 0.5) if main_on else Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 140, 4)
