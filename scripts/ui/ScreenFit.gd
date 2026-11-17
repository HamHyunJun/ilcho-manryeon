extends RefCounted
class_name ScreenFit
## 여러 화면 비율에 맞춘 배치 계산.
## 화면은 가로 720 기준으로 늘린다(project.godot stretch aspect = keep_width).
## 세로로 긴 휴대폰(예: 1080×2400 → 720×1600)에서는 기준 높이 1280보다 남는 높이가 생기는데,
## 그만큼 전투 화면과 하단 앱바를 아래로 내려 앱바가 화면 맨 아래(안전 영역 위)에 붙게 한다.
## 상단 바(프로필, 스테이지, 설정)는 화면 맨 위에 그대로 둔다.

## 기준 해상도
const BASE_W := 720.0
const BASE_H := 1280.0
## 안전 영역(제스처 바, 내비게이션 바)으로 앱바를 올리는 최대 높이 (기준 좌표)
const MAX_BOTTOM_INSET := 120.0


## 기준 높이보다 남는 세로 길이 (기준 좌표). 짧은 화면이면 0
static func extra_height(vp: Viewport) -> float:
	if vp == null:
		return 0.0
	return maxf(0.0, vp.get_visible_rect().size.y - BASE_H)


## 화면 아래쪽 안전 영역 높이 (기준 좌표). 모바일에서만 계산하고 PC·헤드리스에서는 0
static func bottom_inset(vp: Viewport) -> float:
	if vp == null or not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	var px := float(win.y - safe.end.y)
	if px <= 0.0:
		return 0.0
	return clampf(px * vp.get_visible_rect().size.y / float(win.y), 0.0, MAX_BOTTOM_INSET)


## 전투 화면과 하단 앱바를 아래로 내리는 양 (기준 좌표)
static func shift(vp: Viewport) -> float:
	return extra_height(vp) - bottom_inset(vp)
