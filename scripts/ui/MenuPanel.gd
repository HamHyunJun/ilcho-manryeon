extends PanelContainer
class_name MenuPanel
## 하단 앱바 메뉴(장비, 소환, 던전, 육성)가 여는 상세 화면의 공통 틀 (M5).
## 제목 줄과 닫기 버튼, 세로 스크롤 본문(root)을 만든다. 하위 화면은 build()와 on_open()을 구현한다.
## 각 메뉴 화면에서도 전투는 뒤에서 계속 진행된다 (docs/09, 가안).

signal close_requested()

## 화면 배치 (720×1280 기준): 전투 영역 아래부터 앱바 위까지
const AREA := Rect2(0, 780, 720, 400)

var title_text := ""
var root: VBoxContainer


func _init(title: String = "") -> void:
	title_text = title
	position = AREA.position
	size = AREA.size
	custom_minimum_size = AREA.size
	visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.08, 0.14, 1.0)
	bg.border_color = Color(0.35, 0.32, 0.45)
	bg.border_width_top = 2
	add_theme_stylebox_override("panel", bg)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var close := button("닫기", 22)
	close.pressed.connect(func(): close_requested.emit())
	head.add_child(close)

	root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)


## 화면을 열 때마다 호출된다. 하위 화면에서 내용을 다시 그린다.
func on_open() -> void:
	pass


## 본문을 비운다.
func clear_root() -> void:
	for c in root.get_children():
		c.queue_free()


# ---- 공통 위젯 ----

static func button(text: String, font_size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func label(text: String, font_size: int = 18, color: Color = Color(0.92, 0.92, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
