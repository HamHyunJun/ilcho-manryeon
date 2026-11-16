extends Label
## 피해 숫자. 위로 떠오르며 사라진다.

const LIFETIME := 0.8
const RISE := 60.0

var _age := 0.0
var _start_y := 0.0


func setup(amount: int, world_pos: Vector2, color: Color, is_crit: bool = false) -> void:
	text = str(amount) + ("!" if is_crit else "")
	add_theme_font_size_override("font_size", 34 if is_crit else 26)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 6)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(120, 40)
	position = world_pos - Vector2(60, 40)
	_start_y = position.y


func _process(delta: float) -> void:
	_age += delta
	position.y = _start_y - RISE * (_age / LIFETIME)
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
