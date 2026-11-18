extends RefCounted
class_name InkTheme
## 화면 전체 테마 (실루엣 + 손그림 질감 스타일).
## - 글꼴: 본문은 손글씨체(개구 굵게), 제목·큰 글자는 붓글씨체(동해 독도). 둘 다 SIL OFL 1.1 (assets/fonts/OFL-*.txt).
## - 버튼·창·진행 막대·스크롤 손잡이는 붓 테두리 상자(InkBox).
## - 색은 먹색·뼈색에 강조 주홍 하나.

const BODY_FONT := "res://assets/fonts/Gaegu-Bold.ttf"
const TITLE_FONT := "res://assets/fonts/EastSeaDokdo-Regular.ttf"
## 이 크기 이상 글자는 붓글씨체로 쓴다
const TITLE_SIZE := 26

static var _body: Font
static var _title: Font
static var _theme: Theme


static func body_font() -> Font:
	if _body == null:
		_body = load(BODY_FONT) if ResourceLoader.exists(BODY_FONT) else ThemeDB.fallback_font
	return _body


static func title_font() -> Font:
	if _title == null:
		_title = load(TITLE_FONT) if ResourceLoader.exists(TITLE_FONT) else body_font()
	return _title


## 손글씨체는 같은 크기에서 글자가 작게 보여서, 기존 글자 크기 값을 이 배율로 키워 쓴다
const BODY_SCALE := 1.25
const TITLE_SCALE := 1.35


## 기존 글자 크기 값 → 실제로 쓸 크기
static func px(size: int) -> int:
	return int(round(size * (TITLE_SCALE if size >= TITLE_SIZE else BODY_SCALE)))


## 글자 크기에 맞는 글꼴 (큰 글자는 붓글씨체)
static func font_for(size: int) -> Font:
	return title_font() if size >= TITLE_SIZE else body_font()


static func box(bg: Color, border: Color, bw: int = 2, radius: int = 10, margin_x: float = 12.0, margin_y: float = 6.0) -> InkBox:
	var b := InkBox.new()
	b.bg_color = bg
	b.border_color = border
	b.set_content_margin(SIDE_LEFT, margin_x)
	b.set_content_margin(SIDE_RIGHT, margin_x)
	b.set_content_margin(SIDE_TOP, margin_y)
	b.set_content_margin(SIDE_BOTTOM, margin_y)
	b.set_border_width_all(bw)
	b.set_corner_radius_all(radius)
	return b


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = px(20)
	var ink := Color(0.075, 0.075, 0.07, 0.95)
	var bone := UiIcons.BONE
	# 버튼
	t.set_stylebox("normal", "Button", box(ink, Color(bone, 0.5)))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.14, 0.13, 0.95), Color(bone, 0.75)))
	t.set_stylebox("pressed", "Button", box(Color(UiIcons.ACCENT, 0.9), bone))
	t.set_stylebox("hover_pressed", "Button", box(Color(UiIcons.ACCENT, 0.95), bone))
	t.set_stylebox("disabled", "Button", box(Color(0.06, 0.06, 0.06, 0.7), Color(bone, 0.18)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", bone)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", bone)
	t.set_color("font_disabled_color", "Button", Color(UiIcons.BONE_DIM, 0.6))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 3)
	# 글자
	t.set_color("font_color", "Label", bone)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	# 창
	t.set_stylebox("panel", "PanelContainer", box(Color(0.055, 0.055, 0.05, 0.96), Color(bone, 0.4), 2, 12, 10, 10))
	t.set_stylebox("panel", "Panel", box(Color(0.055, 0.055, 0.05, 0.96), Color(bone, 0.4), 2, 12, 10, 10))
	# 진행 막대
	t.set_stylebox("background", "ProgressBar", box(Color(0.04, 0.04, 0.04, 0.9), Color(bone, 0.35), 2, 6, 2, 2))
	t.set_stylebox("fill", "ProgressBar", box(Color(UiIcons.ACCENT, 0.95), Color(0, 0, 0, 0), 0, 6, 2, 2))
	# 스크롤 손잡이
	var grab := box(Color(bone, 0.35), Color(0, 0, 0, 0), 0, 6, 3, 3)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(bone, 0.55), Color(0, 0, 0, 0), 0, 6, 3, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Color(bone, 0.7), Color(0, 0, 0, 0), 0, 6, 3, 3))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 6, 3, 3))
	# 슬라이더
	t.set_stylebox("slider", "HSlider", box(Color(0.04, 0.04, 0.04, 0.9), Color(bone, 0.4), 2, 6, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", box(Color(UiIcons.ACCENT, 0.9), Color(0, 0, 0, 0), 0, 6, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color(UiIcons.ACCENT, 1.0), Color(0, 0, 0, 0), 0, 6, 0, 4))
	_theme = t
	return t
