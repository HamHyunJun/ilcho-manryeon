extends Node2D
class_name EffectDirector
## 이펙트 연출 관리자 (M6).
## - 초식 발동 시 "계열 × 수련 단계" 프리셋으로 연출을 만든다 (docs/03 4장).
## - 단계 상승(입문→초급 등)과 대성 때 알림 연출을 띄운다.
## - 동시에 살아 있는 연출 수를 max_active_effects로 제한해 프레임을 지킨다. 넘치면 가장 오래된 것부터 지운다.
## - 화면 흔들림 세기를 shake_offset으로 내보낸다 (BattleManager가 적용).

const EffectScript := preload("res://scripts/effects/TechniqueEffect.gd")

var presets: Dictionary = {}
var max_active := 6
var ground_y := 760.0
var rng := RandomNumberGenerator.new()
## 이번 프레임 화면 흔들림 (px)
var shake_offset := Vector2.ZERO
## true면 화면 흔들림을 끈다 (설정 화면 연동은 M11)
var shake_enabled := true
## 통계/테스트용
var played_count := 0
var last_params: Dictionary = {}


func setup(effect_presets: Dictionary, ground: float) -> void:
	presets = effect_presets
	ground_y = ground
	max_active = int(presets.get("max_active_effects", 6))


func active_count() -> int:
	return get_child_count()


## 초식 발동 연출. stage는 1~7.
func play_technique(category: String, stage: int, from: Vector2, target_positions: Array, tech: Dictionary = {}) -> Node2D:
	var p := EffectPresets.resolve(presets, category, stage, tech)
	# 초식별 고유 연출 (12초식): 무공 ID와 초식 순서를 넘긴다
	if tech.has("id"):
		p["art_id"] = String(tech["id"]).get_slice(".", 0)
		p["tech_order"] = int(tech.get("order", 1))
	last_params = p
	return _spawn(p, "technique", from, target_positions, "")


## 단계 상승 알림 (예: "1초식 · 초급")
func play_stage_up(category: String, stage: int, at: Vector2, label: String) -> Node2D:
	var p := EffectPresets.resolve(presets, category, stage)
	return _spawn(p, "stage_up", at, [], label)


## 대성 알림
func play_mastery(category: String, at: Vector2, label: String, tech: Dictionary = {}) -> Node2D:
	var p := EffectPresets.resolve(presets, category, EffectPresets.STAGE_COUNT, tech)
	return _spawn(p, "mastery", at, [], label)


func _spawn(p: Dictionary, kind: String, from: Vector2, to: Array, label: String) -> Node2D:
	# 알림 연출은 지우지 않도록 초식 연출부터 정리한다
	while get_child_count() >= max_active:
		var victim: Node = null
		for c in get_children():
			if c.kind == "technique":
				victim = c
				break
		if victim == null:
			victim = get_child(0)
		remove_child(victim)
		victim.queue_free()
	var e: Node2D = EffectScript.new()
	e.setup(p, kind, from, to, ground_y, rng, label)
	add_child(e)
	played_count += 1
	return e


func tick(delta: float) -> void:
	var shake := 0.0
	for c in get_children():
		c.advance(delta)
		if c.is_done():
			remove_child(c)
			c.queue_free()
		else:
			shake = maxf(shake, c.shake_amount())
	if shake_enabled and shake > 0.0:
		shake_offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	else:
		shake_offset = Vector2.ZERO
