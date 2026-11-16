class_name PixelSprite
extends Node2D
## 픽셀 스프라이트 한 개 (캐릭터, 몬스터 공용).
## data/sprites/sprite_sets.json 의 세트 하나로 시트 그림을 잘라 그린다.
## 동작: idle(반복), attack/hit(한 번 재생 후 idle로), down(마지막 프레임에서 멈춤).
## 프레임이 바뀔 때만 다시 그리므로 모바일에서 가볍다 (노드 하나당 draw 1~2회).
## 그림 파일이 없으면 is_valid()가 false이고, 쓰는 쪽에서 도형으로 대신 그린다.

signal animation_finished(anim_name: String)

## 시트 경로 → 그림 위쪽 여백을 뺀 실제 높이(px, 확대 전). 세트마다 한 번만 계산한다.
static var _top_cache: Dictionary = {}

var set_data: Dictionary = {}
var texture: Texture2D
var frame_size := Vector2i(32, 32)
var pivot := Vector2(16, 31)
var pixel_scale := 2.0
var current := ""
var frame_index := 0
## 피격 순간 하얗게 번쩍이는 남은 시간(초)
var flash_left := 0.0
## 몸 전체에 곱하는 색 (보스 패턴 예고 등). 기본 흰색 = 원래 색
var tint := Color.WHITE

var _anim: Dictionary = {}
var _time := 0.0
var _playing := false


func setup(sprite_set: Dictionary) -> void:
	set_data = sprite_set
	texture = null
	var path: String = sprite_set.get("sheet", "")
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	var fs: Array = sprite_set.get("frame_size", [32, 32])
	frame_size = Vector2i(int(fs[0]), int(fs[1]))
	var pv: Array = sprite_set.get("pivot", [fs[0] / 2, fs[1] - 1])
	pivot = Vector2(float(pv[0]), float(pv[1]))
	pixel_scale = float(sprite_set.get("scale", 2))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play("idle", true)


func is_valid() -> bool:
	return texture != null


## 동작 재생. 같은 동작이 이미 반복 재생 중이면 restart가 아닐 때 그대로 둔다.
func play(anim_name: String, restart: bool = false) -> void:
	var anims: Dictionary = set_data.get("animations", {})
	if not anims.has(anim_name):
		return
	if anim_name == current and _playing and not restart:
		return
	current = anim_name
	_anim = anims[anim_name]
	_time = 0.0
	frame_index = 0
	_playing = true
	queue_redraw()


func flash(sec: float = 0.1) -> void:
	flash_left = sec
	queue_redraw()


func is_playing() -> bool:
	return _playing


## 화면에 보이는 그림 높이(px, 확대 후). 체력 바 위치 계산용
func visual_height() -> float:
	if texture == null:
		return 0.0
	var path: String = set_data.get("sheet", "")
	if not _top_cache.has(path):
		var top := 0
		var img := texture.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used := img.get_region(Rect2i(0, 0, frame_size.x, frame_size.y)).get_used_rect()
			top = used.position.y
		_top_cache[path] = top
	return (pivot.y + 1.0 - float(_top_cache[path])) * pixel_scale


func _process(delta: float) -> void:
	advance(delta)


## 시간 진행 (테스트에서 직접 부를 수 있게 분리)
func advance(delta: float) -> void:
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
		if flash_left == 0.0:
			queue_redraw()
	if not _playing or _anim.is_empty():
		return
	var frames: Array = _anim.get("frames", [0])
	var fps := float(_anim.get("fps", 4.0))
	_time += delta
	var idx := int(_time * fps)
	if idx >= frames.size():
		if bool(_anim.get("loop", false)):
			idx = idx % frames.size()
		else:
			var finished := current
			if finished == "down":
				# 쓰러짐은 마지막 프레임에서 멈춘다
				_playing = false
				frame_index = frames.size() - 1
				queue_redraw()
				animation_finished.emit(finished)
				return
			play("idle", true)
			animation_finished.emit(finished)
			return
	if idx != frame_index:
		frame_index = idx
		queue_redraw()


## 시트에서 지금 그릴 칸 번호
func sheet_frame() -> int:
	var frames: Array = _anim.get("frames", [0])
	if frames.is_empty():
		return 0
	return int(frames[clampi(frame_index, 0, frames.size() - 1)])


func _draw() -> void:
	if texture == null:
		return
	var src := Rect2(Vector2(sheet_frame() * frame_size.x, 0), Vector2(frame_size))
	var dst := Rect2(-pivot * pixel_scale, Vector2(frame_size) * pixel_scale)
	draw_texture_rect_region(texture, dst, src, tint)
	if flash_left > 0.0:
		# 같은 그림을 밝게 한 번 더 겹쳐 하얗게 번쩍이게 한다 (셰이더 없이)
		draw_texture_rect_region(texture, dst, src, Color(1, 1, 1, 0.85) * Color(4, 4, 4, 1))
