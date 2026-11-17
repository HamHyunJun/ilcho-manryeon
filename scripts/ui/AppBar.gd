extends Control
class_name AppBar
## 하단 앱바 (실루엣 + 손그림 질감 스타일).
## 상점 │ 육성 │ (메인 태극 버튼) │ 던전 │ 소환. 높이 134px, 아이콘 56, 글자 24.
## - 먹색 띠의 윗변을 찢긴 종이처럼 들쭉날쭉하게 그리고, 뼈색 붓선을 한 줄 긋는다.
## - 선택된 칸은 주홍 먹물 번짐으로 표시한다 (UI에서 색은 주홍 하나만).
## - 가운데 태극 버튼은 앱바 위로 솟아 있고 누르면 메인(전투 화면)으로 돌아간다.
## - 바로 위에는 초식 수련 게이지(주홍 붓 띠)를 그린다.

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
var _last_id := ""
var _last_ms := -100000


func _init(top: float) -> void:
	set_top(top)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 앱바 윗선 높이를 바꾼다. 컨트롤 영역은 태극 버튼이 솟은 높이부터 화면 아래까지
## (안전 영역 아래로도 앱바 바탕색이 이어지게 400px 더 그린다)
func set_top(top: float) -> void:
	bar_y = top
	position = Vector2(0, top - 70)
	size = Vector2(720, HEIGHT + 70 + 400)
	queue_redraw()


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


## 모바일에서는 손가락을 뗄 때 터치 이벤트와, 터치를 흉내 낸 마우스 이벤트가 둘 다 들어온다
## (input_devices/pointing/emulate_mouse_from_touch 기본값 true).
## 둘 다 처리하면 같은 탭이 두 번 눌려 육성·던전·소환이 열렸다가 바로 닫혔다. 한 번만 처리한다.
func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			accept_event()
			return
		pos = event.position
	elif event is InputEventScreenTouch:
		accept_event()
		# 마우스 흉내가 켜져 있으면 뒤따라오는 마우스 이벤트로 처리한다
		if event.pressed or _touch_emulates_mouse():
			return
		pos = event.position
	else:
		return
	accept_event()
	_press_at(pos)


static func _touch_emulates_mouse() -> bool:
	return bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))


## pos(앱바 컨트롤 안 좌표)에 있는 메뉴를 누른다
## 같은 탭이 아주 짧은 간격(0.2초 안)으로 두 번 들어오면 한 번으로 본다 (기기별 중복 입력 대비)
func _press_at(pos: Vector2) -> void:
	var id: String = "main"
	if pos.distance_to(_taiji_center()) > TAIJI_R + 8.0:
		id = ITEMS[clampi(int(pos.x / 144.0), 0, ITEMS.size() - 1)][0]
	var now := Time.get_ticks_msec()
	if id == _last_id and now - _last_ms < 200:
		return
	_last_id = id
	_last_ms = now
	menu_pressed.emit(id)


func _draw() -> void:
	var top := 70.0
	# 초식 게이지 (앱바 바로 위): 먹색 홈 + 주홍 붓 띠
	var gy := top - 14.0
	UiIcons.torn_band(self, 0, 720, gy, gy + 16, UiIcons.INK, 2.0, 11)
	if gauge > 0.0:
		var gw := 720.0 * clampf(gauge, 0.0, 1.0)
		UiIcons.torn_band(self, 0, gw, gy + 3, gy + 12, UiIcons.ACCENT, 1.5, 12)
		UiIcons.ink_line(self, Vector2(0, gy + 5), Vector2(gw, gy + 5), Color(1, 0.75, 0.6, 0.35), 2.0, 13, 0.6)
	# 앱바 띠: 먹색, 윗변은 찢긴 종이
	UiIcons.torn_band(self, 0, 720, top + 4, top + HEIGHT + 400, UiIcons.INK, 5.0, 21)
	# 종이 결: 옅은 가로 붓자국
	var r := RandomNumberGenerator.new()
	r.seed = 31
	for k in 14:
		var y := top + 18 + r.randf_range(0, HEIGHT - 20)
		var x := r.randf_range(-40, 680)
		UiIcons.ink_line(self, Vector2(x, y), Vector2(x + r.randf_range(60, 180), y + r.randf_range(-2, 2)), Color(1, 1, 1, 0.025), r.randf_range(3, 8), 40 + k, 1.0)
	# 윗변 뼈색 붓선
	UiIcons.ink_line(self, Vector2(-4, top + 12), Vector2(724, top + 10), Color(UiIcons.BONE, 0.55), 2.2, 22, 1.4)
	# 칸 구분선 (짧은 붓 자국)
	for i in [1, 4]:
		var x: float = i * 144.0
		UiIcons.ink_line(self, Vector2(x, top + 30), Vector2(x + 1, top + HEIGHT - 22), Color(UiIcons.BONE, 0.22), 2.0, 50 + i, 1.2)
	for i in ITEMS.size():
		var id: String = ITEMS[i][0]
		if id == "main":
			continue
		var cx := _slot_x(i)
		var on := active == id
		if on:
			UiIcons.ink_smear(self, Vector2(cx, top + 72), 62, 52, Color(UiIcons.ACCENT, 0.55), 60 + i)
			UiIcons.ink_line(self, Vector2(cx - 40, top + 124), Vector2(cx + 40, top + 123), UiIcons.ACCENT, 4.0, 70 + i, 1.2)
		var col := Color(1, 1, 1) if on else UiIcons.BONE
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
		UiIcons.text(self, Vector2(cx - 70, top + 114), ITEMS[i][1], 24, Color(1, 1, 1) if on else UiIcons.BONE_DIM.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140, 4)
	# 가운데 태극 버튼 (앱바 위로 솟음): 먹색 원판 + 거친 뼈색 붓 고리
	var c := _taiji_center()
	var main_on := active == "main"
	UiIcons.ink_smear(self, c, TAIJI_R + 12, TAIJI_R + 12, UiIcons.INK, 81)
	if main_on:
		UiIcons.ink_ring(self, c, TAIJI_R + 9, UiIcons.ACCENT, 4.0, 82, 2.2)
	UiIcons.ink_ring(self, c, TAIJI_R + 3, UiIcons.BONE, 3.0, 83, 1.6)
	UiIcons.taiji(self, c, TAIJI_R - 8, _t * (0.6 if main_on else 0.15))
	UiIcons.text(self, Vector2(c.x - 70, top + 114), "메인", 24, Color(1, 1, 1) if main_on else UiIcons.BONE_DIM.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140, 4)
